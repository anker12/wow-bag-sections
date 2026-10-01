-- Loads the whole addon against a minimal mock of the WoW API and drives the main flows
-- (open bags, render, drag an item into a section, sort, slash commands).
-- It catches Lua errors and wrong globals; it can't check how anything looks in game.
-- Run from the repo root: lua tests/smoke.lua

local realPrint = print

-- Mock frames: any unknown method is a no-op returning nil.
local frames = {}
local function NewFrame(frameType, name, parent, template)
	local frame = { _type = frameType, _name = name, _parent = parent, _template = template, _shown = true, _scripts = {}, _attrs = {}, _level = 1 }
	if frameType == "Frame" and parent == nil then frame._shown = true end
	local methods = {
		GetName = function(self) return self._name end,
		Show = function(self) local was = self._shown; self._shown = true; if not was and self._scripts.OnShow then self._scripts.OnShow(self) end end,
		Hide = function(self) local was = self._shown; self._shown = false; if was and self._scripts.OnHide then self._scripts.OnHide(self) end end,
		SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end,
		IsShown = function(self) return self._shown end,
		IsVisible = function(self) return self._shown end,
		SetScript = function(self, script, fn) self._scripts[script] = fn end,
		GetScript = function(self, script) return self._scripts[script] end,
		HookScript = function(self, script, fn) local old = self._scripts[script]; self._scripts[script] = function(...) if old then old(...) end fn(...) end end,
		GetFrameLevel = function(self) return self._level end,
		SetPoint = function(self, point, rel, relPoint, x, y) self._point = { point, rel, relPoint, x, y } end,
		ClearAllPoints = function(self) self._point = nil end,
		SetFrameLevel = function(self, level) self._level = level end,
		GetPoint = function() return "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -60, 100 end,
		CreateFontString = function() return NewFrame("FontString") end,
		CreateTexture = function() return NewFrame("Texture") end,
		GetHighlightTexture = function(self) self._hl = self._hl or NewFrame("Texture"); return self._hl end,
		SetText = function(self, text) self._text = text end,
		GetText = function(self) return self._text end,
		SetAttribute = function(self, key, value) self._attrs[key] = value; if self.OnAttributeChanged then self:OnAttributeChanged(key, value) end end,
		SetID = function(self, id) self._id = id end,
		GetID = function(self) return self._id or 0 end,
		GetParent = function(self) return self._parent end,
		RegisterEvent = function(self, event) self._events = self._events or {}; self._events[event] = true end,
	}
	setmetatable(frame, { __index = function(_, key)
		-- Widget methods are capitalised; anything else is a plain field that is just unset.
		if methods[key] then return methods[key] end
		if type(key) == "string" and key:match("^%u") then return function() end end
	end })
	if template == "ContainerFrameItemButtonTemplate" then
		-- The bits of ContainerFrameItemButtonMixin the addon calls.
		frame.OnAttributeChanged = function(self, key, value) if key == "bagid" then self.bagID = value end end
		frame.SetBagID = function(self, bag) self:SetAttribute("bagid", bag) end
		frame.GetBagID = function(self) return self.bagID end
		frame.SetHasItem = function(self, has) self.hasItem = has and 1 or nil end
		frame.HasItem = function(self) return self.hasItem end
		frame._shown = false
	end
	table.insert(frames, frame)
	return frame
end

-- Mock inventory: backpack with 16 slots, bag 1 with 4 slots, reagent bag with 2.
local ITEMS = {
	["0:1"] = { itemID = 6948, name = "Hearthstone", stack = 1 },
	["0:2"] = { itemID = 2901, name = "Mining Pick", stack = 1 },
	["0:3"] = { itemID = 100, name = "Sword", stack = 1, equip = true },
	["0:5"] = { itemID = 200, name = "Potion", stack = 5, maxStack = 20 },
	["1:2"] = { itemID = 300, name = "Campfire Kit", stack = 1 },
	["5:1"] = { itemID = 400, name = "Herb", stack = 10, maxStack = 200 },
	["1:3"] = { itemID = 600, name = "Bloody Tooth", stack = 1, quest = true },
}
local NUM_SLOTS = { [0] = 16, [1] = 4, [2] = 0, [3] = 0, [4] = 0, [5] = 2, [-1] = 0 }
local cursor -- { bag, slot }
local sortCalls = 0

local function ItemAt(bag, slot) return ITEMS[bag .. ":" .. slot] end

local function MakeLocation(bag, slot)
	return {
		bag = bag, slot = slot,
		IsValid = function() return true end,
		IsBagAndSlot = function() return true end,
		GetBagAndSlot = function(self) return self.bag, self.slot end,
	}
end

_G.Enum = {
	BagIndex = { Keyring = -1, Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5 },
	TooltipDataType = { Item = 0 },
	ItemClass = { Questitem = 12 },
}
_G.Constants = { InventoryConstants = { NumBagSlots = 4 } }
_G.C_Container = {
	GetContainerNumSlots = function(bag) return NUM_SLOTS[bag] or 0 end,
	GetContainerItemID = function(bag, slot) local i = ItemAt(bag, slot); return i and i.itemID end,
	GetContainerItemInfo = function(bag, slot)
		local i = ItemAt(bag, slot)
		if not i then return nil end
		return { iconFileID = 1, stackCount = i.stack, isLocked = false, quality = 1, isReadable = false, hyperlink = "link", isFiltered = false, hasNoValue = false, itemID = i.itemID, isBound = false }
	end,
	GetContainerItemQuestInfo = function(bag, slot) local i = ItemAt(bag, slot); return { isQuestItem = i and i.quest or false } end,
	GetContainerNumFreeSlots = function(bag)
		local free = 0
		for slot = 1, NUM_SLOTS[bag] or 0 do if not ItemAt(bag, slot) then free = free + 1 end end
		return free, 0
	end,
	GetContainerFreeSlots = function(bag)
		local list = {}
		for slot = 1, NUM_SLOTS[bag] or 0 do if not ItemAt(bag, slot) then table.insert(list, slot) end end
		return list
	end,
	HasContainerItem = function(bag, slot) return ItemAt(bag, slot) ~= nil end,
	PickupContainerItem = function(bag, slot)
		if cursor then
			ITEMS[bag .. ":" .. slot], ITEMS[cursor.bag .. ":" .. cursor.slot] = ITEMS[cursor.bag .. ":" .. cursor.slot], ITEMS[bag .. ":" .. slot]
			cursor = nil
		elseif ItemAt(bag, slot) then
			cursor = { bag = bag, slot = slot }
		end
	end,
	SortBags = function() sortCalls = sortCalls + 1 end,
	GetSortBagsRightToLeft = function() return false end,
	SetSortBagsRightToLeft = function() end,
}
_G.C_Cursor = { GetCursorItem = function() return cursor and MakeLocation(cursor.bag, cursor.slot) or nil end }
_G.C_Item = {
	DoesItemExist = function(loc) return ItemAt(loc.bag, loc.slot) ~= nil end,
	GetItemGUID = function(loc) return "Item-" .. loc.bag .. "-" .. loc.slot .. "-" .. ItemAt(loc.bag, loc.slot).itemID end,
	GetItemID = function(loc) local i = ItemAt(loc.bag, loc.slot); return i and i.itemID end,
	IsEquippableItem = function(itemID) for _, i in pairs(ITEMS) do if i.itemID == itemID then return i.equip or false end end return false end,
	GetItemMaxStackSizeByID = function(itemID) for _, i in pairs(ITEMS) do if i.itemID == itemID then return i.maxStack or 1 end end end,
	GetItemFamily = function() return 0 end,
	GetItemInfoInstant = function(itemID) return itemID, "", "", "", 1, itemID == 600 and 12 or 0 end,
	GetItemNameByID = function(itemID) for _, i in pairs(ITEMS) do if i.itemID == itemID then return i.name end end end,
}
_G.C_Timer = { After = function(_, fn) fn() end }
_G.C_ActionBar = { ShouldShowKeyring = function() return false end }
_G.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return MakeLocation(bag, slot) end }
_G.CreateFrame = NewFrame
_G.UIParent = NewFrame("Frame", "UIParent")
_G.GameTooltip = NewFrame("GameTooltip", "GameTooltip")
_G.UIErrorsFrame = NewFrame("Frame")
_G.RED_FONT_COLOR = { GetRGBA = function() return 1, 0, 0, 1 end }
_G.SOUNDKIT = {}
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
_G.SlashCmdList = {}
for _, name in ipairs({ "GameTooltip_Hide", "GameTooltip_SetTitle", "GameTooltip_AddNormalLine", "GameTooltip_AddInstructionLine",
	"ClearItemButtonOverlay", "SetItemButtonQuality", "SetItemButtonCount", "SetItemButtonDesaturated", "PlaySound",
	"StaticPopup_StandardEditBoxOnEscapePressed", "ContainerFrame_AllowedToOpenBags" }) do
	_G[name] = function() return true end
end
_G.StaticPopup_Show = function(which, _, _, data) _G._lastPopup = { which = which, data = data } end
_G.ClearCursor = function() cursor = nil end
_G.CursorHasItem = function() return cursor ~= nil end
_G.InCombatLockdown = function() return _G._inCombat end
_G.IsAltKeyDown = function() return false end
_G.GetMoney = function() return 12345 end
_G.PixelUtil = {
	SetPoint = function(region, ...) region:SetPoint(...) end,
	SetSize = function(region, w, h) region:SetSize(w, h) end,
}
_G._now = 100
_G.GetTime = function() return _G._now end
_G.GetMoneyString = function(m) return tostring(m) end
_G.GetMouseFoci = function() return {} end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.tinsert = table.insert
_G.bit = { band = function() return 0 end }
_G.ACCEPT, _G.CANCEL, _G.YES, _G.NO = "Accept", "Cancel", "Yes", "No"
_G.NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82, 0 end }
_G.ColorPickerFrame = {
	SetupColorPickerAndShow = function(self, info) self.info = info end,
	GetColorRGB = function() return 0.1, 0.2, 0.3 end,
}
_G.MinimalSliderWithSteppersMixin = { Label = { Right = 2 } }
_G.MenuUtil = { CreateContextMenu = function(owner, fn)
	local function Description()
		local d = {}
		setmetatable(d, { __index = function() return function() return Description() end end })
		return d
	end
	fn(owner, Description())
end }
_G.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) _G._tooltipPostCall = fn end }
local function MockSetting() return { SetValueChangedCallback = function() end } end
_G.Settings = {
	VarType = { Boolean = "boolean", Number = "number" },
	RegisterVerticalLayoutCategory = function() return { GetID = function() return 1 end }, { AddInitializer = function(_, init) _G._settingsButtons = _G._settingsButtons or {}; table.insert(_G._settingsButtons, init) end } end,
	RegisterAddOnSetting = MockSetting,
	RegisterProxySetting = MockSetting,
	CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
	CreateSlider = function() end,
	CreateCheckbox = function() end,
	CreateDropdown = function(_, _, optionsFn) optionsFn() end,
	CreateControlTextContainer = function() return { Add = function() end, GetData = function() return {} end } end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() end,
}
_G.CreateSettingsListSectionHeaderInitializer = function() return {} end
_G.CreateSettingsButtonInitializer = function(_, _, onClick) return { onClick = onClick } end
local closeHooks = {}
_G.hooksecurefunc = function(name, fn) closeHooks[name] = fn end
for _, name in ipairs({ "ToggleBackpack", "ToggleAllBags", "OpenBackpack", "OpenAllBags", "ToggleBag", "OpenBag", "CloseAllBags", "CloseBackpack", "CloseBag" }) do
	_G[name] = function() _G._blizzardCalled = name end
end
local printed = {}
_G.print = function(...) table.insert(printed, table.concat({ ... }, " ")) end

-- Load the addon in TOC order.
local ns = {}
local toc = io.open("BagSections/BagSections.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
	if not line:match("^#") and line:match("%S") then
		local path = "BagSections/" .. line:gsub("\\", "/")
		assert(loadfile(path))("BagSections", ns)
	end
end

local eventFrame
for _, frame in ipairs(frames) do
	if frame._scripts.OnEvent then eventFrame = frame end
end
local function Fire(event, ...) eventFrame._scripts.OnEvent(eventFrame, event, ...) end

local function check(cond, msg) if not cond then error(msg, 2) end end

-- Startup.
Fire("ADDON_LOADED", "BagSections")
Fire("PLAYER_LOGIN")
check(type(BagSectionsDB) == "table" and type(BagSectionsCharDB) == "table", "saved variables initialized")
check(not ns.Frame.IsShown(), "window starts hidden")

-- Opening bags goes to the addon window, not Blizzard's.
_G._blizzardCalled = nil
ToggleAllBags()
check(ns.Frame.IsShown(), "ToggleAllBags opens the window")
check(_G._blizzardCalled == nil, "Blizzard bags not opened")
ToggleBackpack()
check(not ns.Frame.IsShown(), "ToggleBackpack closes it again")
ToggleBag(8)
check(_G._blizzardCalled == "ToggleBag", "bank bags still go to Blizzard")

-- Merchant opens bags, closing the merchant closes them; another frame does not.
local merchant = NewFrame("Frame", "MerchantFrame")
local mail = NewFrame("Frame", "MailFrame")
OpenAllBags(merchant)
check(ns.Frame.IsShown(), "OpenAllBags opens")
closeHooks.CloseAllBags(mail)
check(ns.Frame.IsShown(), "other frame doesn't close bags")
closeHooks.CloseAllBags(merchant)
check(not ns.Frame.IsShown(), "opener closes bags")

-- Sections: create, drag the hearthstone in.
OpenBackpack()
SlashCmdList.BAGSECTIONS("new Essentials")
local db = BagSectionsCharDB
check(#db.sections == 1 and db.sections[1].name == "Essentials", "section created by slash command")

local function FindGroupFrame(kind, key)
	for _, frame in ipairs(frames) do
		if frame.group and frame.group.kind == kind and (not key or frame.group.key == key) and frame._shown and rawget(frame, "Border") and frame._scripts.OnReceiveDrag then
			return frame
		end
	end
end

C_Container.PickupContainerItem(0, 1) -- pick up the Hearthstone
Fire("CURSOR_CHANGED")
local target = FindGroupFrame("section", db.sections[1].id)
check(target, "empty section shown as drop target while dragging")
target._scripts.OnReceiveDrag(target)
check(cursor == nil, "cursor cleared after drop")
check(db.rules.byItemID[6948] == db.sections[1].id, "hearthstone assigned by item type")
check(ItemAt(0, 1).itemID == 6948, "nothing moved physically")

-- Gear is assigned by exact item.
C_Container.PickupContainerItem(0, 3)
Fire("CURSOR_CHANGED")
target = FindGroupFrame("section", db.sections[1].id)
target._scripts.OnReceiveDrag(target)
check(db.rules.byGUID["Item-0-3-100"] == db.sections[1].id, "sword assigned by exact item")

-- Layout after assignment.
local groups = ns.Layout.Build(db, ns.Inventory.Scan())
check(groups[1].count == 2 and #groups[1].slots == 2, "Essentials has 2 items and no empty slots")
check(groups[2].kind == "rest" and #groups[2].slots == 18, "Rest has the other 18 slots")
check(groups[3].kind == "reagent", "reagent bag shown separately")

-- Dropping a sectioned item on any empty Rest slot puts it there and takes it out of
-- its section (Blizzard's button moves it; the addon's hook unassigns it).
C_Container.PickupContainerItem(0, 1)
Fire("CURSOR_CHANGED")
target = FindGroupFrame("rest")
check(target, "Rest is highlighted for a sectioned item")
local restSlot = ns.ItemButtons.Get(0, 9)
check(restSlot.bsGroupKind == "rest", "slot 0:9 is an empty Rest slot")
C_Container.PickupContainerItem(0, 9) -- what Blizzard's button does on drop
restSlot._scripts.OnReceiveDrag(restSlot)
check(db.rules.byItemID[6948] == nil, "hearthstone unassigned")
check(ITEMS["0:9"] and ITEMS["0:9"].itemID == 6948, "hearthstone placed in the slot it was dropped on")
ITEMS["0:1"], ITEMS["0:9"] = ITEMS["0:9"], nil
Fire("BAG_UPDATE_DELAYED")

-- A drag that ends without any cursor event still clears the drop targets.
C_Container.PickupContainerItem(0, 5)
Fire("CURSOR_CHANGED")
check(FindGroupFrame("section"), "drop targets shown while dragging")
cursor = nil -- the drag ends somewhere the addon doesn't hear about
local watcher
for _, frame in ipairs(frames) do
	if frame._scripts.OnUpdate and frame._shown then watcher = frame end
end
check(watcher, "drop-target watcher runs while dragging")
watcher._scripts.OnUpdate(watcher)
check(FindGroupFrame("section") == nil, "drop targets cleared once the cursor is empty")

-- Reagent bag items can't be assigned.
C_Container.PickupContainerItem(5, 1)
Fire("CURSOR_CHANGED")
check(FindGroupFrame("section") == nil, "no section drop targets for reagent-bag items")
ClearCursor()
Fire("CURSOR_CHANGED")

-- Menus build without errors.
local header
for _, frame in ipairs(frames) do
	if frame.group and frame.group.kind == "section" and frame._shown and frame._scripts.OnClick and rawget(frame, "Line") then header = frame end
end
check(header, "section header shown")
header._scripts.OnClick(header, "RightButton")
ns.Menu.OpenMainMenu(header)
local swordButton = ns.ItemButtons.Get(0, 3)
swordButton.hasItem = 1
ns.Menu.OpenItemMenu(swordButton)

-- Collapse via left click.
header._scripts.OnClick(header, "LeftButton")
check(db.sections[1].collapsed, "left click collapses")

-- Tooltip line.
_G.GameTooltip.GetOwner = function() return swordButton end
swordButton.bsSectionName = "Essentials"
swordButton._shown = true
local added
_G.GameTooltip.AddLine = function(_, text) added = text end
_G._tooltipPostCall(GameTooltip)
check(added and added:find("Essentials"), "tooltip shows section")

-- Built-in groups collapse on left click.
local restHeader
for _, frame in ipairs(frames) do
	if frame.group and frame.group.kind == "rest" and frame._shown and rawget(frame, "Line") then restHeader = frame end
end
restHeader._scripts.OnClick(restHeader, "LeftButton")
check(db.collapsedBuiltin.rest == true, "Rest collapses")
restHeader._scripts.OnClick(restHeader, "LeftButton")
check(db.collapsedBuiltin.rest == nil, "Rest expands")

-- Move a section below Rest.
local section = db.sections[1]
ns.Rules.SetSectionBelow(db, section.id, true)
ns.RequestRefresh()
groups = ns.Layout.Build(db, ns.Inventory.Scan())
check(groups[1].kind == "rest" and groups[2].key == section.id, "section drawn below Rest")

-- Colour picker sets the section colour.
ns.Menu.PickColour(section)
ColorPickerFrame.info.swatchFunc()
check(section.color.r == 0.1 and section.color.b == 0.3, "colour picked")
ColorPickerFrame.info.cancelFunc({ r = 0.5, g = 0.5, b = 0.5 })
check(section.color.r == 0.5, "colour restored on cancel")

-- Compact layout: one grid, outlines and names drawn; switching back keeps default working.
section.collapsed = false
ns.Menu.SetLayout("compact")
check(BagSectionsDB.layout == "compact", "layout saved")
local function CountShown(predicate)
	local n = 0
	for _, frame in ipairs(frames) do
		if frame._shown and predicate(frame) then n = n + 1 end
	end
	return n
end
local function IsLabel(frame) return frame.showTitleInTooltip and frame.group ~= nil end
check(CountShown(IsLabel) >= 3, "compact layout shows a name for each group")
local function ButtonPos(bag, slot)
	local p = ns.ItemButtons.Get(bag, slot)._point
	return p and (p[4] .. "," .. p[5])
end

-- Nothing moves while the window is open: use up an item, layout stays.
-- (the sword is in a section; without freezing, its emptied slot would jump to Rest)
local swordPos = ButtonPos(0, 3)
local sword = ITEMS["0:3"]
ITEMS["0:3"] = nil
Fire("BAG_UPDATE_DELAYED")
check(ButtonPos(0, 3) == swordPos, "slot keeps its place when its item is used up")
ITEMS["0:3"] = sword
Fire("BAG_UPDATE_DELAYED")

-- Drag into a section in compact: it reflows.
C_Container.PickupContainerItem(0, 2)
Fire("CURSOR_CHANGED")
target = FindGroupFrame("section", section.id)
check(target, "compact layout shows drop targets")
target._scripts.OnReceiveDrag(target)
check(db.rules.byItemID[2901] == section.id, "drop works in compact layout")

-- Sorting lets the layout follow items for a few seconds.
-- (the sort moves the sectioned Mining Pick into an empty Rest slot)
local emptyPos = ButtonPos(0, 8)
SlashCmdList.BAGSECTIONS("sort")
ITEMS["0:8"], ITEMS["0:2"] = ITEMS["0:2"], nil
Fire("BAG_UPDATE_DELAYED")
check(ButtonPos(0, 8) ~= emptyPos, "layout follows the sort")
sortCalls = 0
ITEMS["0:2"], ITEMS["0:8"] = ITEMS["0:8"], nil
_G._now = _G._now + 10

-- Collapsed section in compact keeps a placeholder with its name.
db.sections[1].collapsed = true
ns.RequestRefresh()
check(CountShown(IsLabel) >= 3, "collapsed section still has its name")
db.sections[1].collapsed = false

ns.Menu.SetLayout("default")
check(CountShown(IsLabel) == 0, "no compact names in default layout")

-- Quest Items section: off by default, then catches the quest item automatically.
groups = ns.Layout.Build(db, ns.Inventory.Scan())
local function GroupOf(bag, slot)
	for _, group in ipairs(groups) do
		for _, s in ipairs(group.slots) do
			if s.bag == bag and s.slot == slot then return group end
		end
	end
end
check(GroupOf(1, 3).kind == "rest", "quest item in Rest while option is off")
ns.Rules.SetAutoQuest(db, true, ns.L.QUEST_ITEMS)
groups = ns.Layout.Build(db, ns.Inventory.Scan())
check(GroupOf(1, 3).name == "Quest Items", "quest item goes to Quest Items section")

-- Profiles: save, change sections, load back.
for _, init in ipairs(_G._settingsButtons) do
	if init.onClick then init.onClick(NewFrame("Button")) end
end
ns.Menu.PromptSaveProfile()
_G._lastPopup.data.onAccept("Raiding")
check(BagSectionsDB.profiles.Raiding and #BagSectionsDB.profiles.Raiding.sections == #db.sections, "profile saved")
local savedCount = #db.sections
SlashCmdList.BAGSECTIONS("new Temporary")
ns.Menu.LoadProfile("Raiding")
check(_G._lastPopup.which == "BAGSECTIONS_CONFIRM", "loading asks before removing a section")
_G._lastPopup.data.onAccept()
check(#db.sections == savedCount, "profile loaded")
ns.Menu.OpenMainMenu(header)
ns.Menu.DeleteProfile("Raiding")
_G._lastPopup.data.onAccept()
check(BagSectionsDB.profiles.Raiding == nil, "profile deleted")

-- Sorting, and sorting queued in combat.
SlashCmdList.BAGSECTIONS("sort")
check(sortCalls == 1, "sort calls SortBags")
_G._inCombat = true
ns.Sorter.Sort()
check(sortCalls == 1, "no sort in combat")
_G._inCombat = false
Fire("PLAYER_REGEN_ENABLED")
check(sortCalls == 2, "queued sort runs after combat")

-- Delete with items asks for confirmation; without items deletes directly.
local before = #db.sections
ns.Menu.DeleteSection(db.sections[1], 1)
check(_G._lastPopup and _G._lastPopup.which == "BAGSECTIONS_DELETE_SECTION", "confirmation shown")
StaticPopupDialogs.BAGSECTIONS_DELETE_SECTION.OnAccept(nil, _G._lastPopup.data)
check(#db.sections == before - 1, "section deleted")
check(next(db.rules.byGUID) == nil, "rules removed with section")

-- Every event handler runs without error.
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY", "INVENTORY_SEARCH_UPDATE", "GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW" }) do
	Fire(event)
end

SlashCmdList.BAGSECTIONS("help")
check(#printed > 0, "help printed")

realPrint("smoke test passed")
