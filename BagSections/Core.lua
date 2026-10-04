-- Startup, saved variables, events and slash commands.

local addonName, ns = ...
local L = ns.L
local Rules = ns.Rules

ns.DEFAULTS = {
	frame = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -60, y = 100 },
	layout = "default", -- "default" | "semicompact" | "compact"
	-- Where Rest sits relative to newly created sections: "bottom" puts new sections above
	-- Rest, "top" puts them below it. Existing sections keep their place.
	restPosition = "bottom",
	columns = 10,
	scale = 1,
	-- On by default so a newly created (still empty) section shows up straight away.
	showEmptySections = true,
	showKeyring = true,
	stackableRule = Rules.KIND_ITEMID,
	equippableRule = Rules.KIND_GUID,
	takeOverBags = true,
	-- Appearance
	outlineAlpha = 0.7, -- compact layout section outlines
	backgroundAlpha = 0.94,
	backgroundStyle = "dark", -- "dark" | "blizzard"
	blizzardBorder = true, -- Blizzard's bronze frame border around the window
	sectionTooltips = true, -- tooltips when hovering section names
	-- Font sizes (Settings only, not the gear menu)
	sectionFontSize = 12, -- section names; compact layout names are 2 smaller
	moneyFontSize = 12, -- gold and tracked currencies
	slotsFontSize = 10, -- free slots (x / y)
	-- Saved section lists: name -> { sections = { { name, color, below, collapsed, auto } } }
	profiles = {},
}

function ns.NewSectionsBelowRest()
	return ns.db.restPosition == "top"
end

function ns.Print(...)
	print("|cff33ff99" .. L.ADDON_NAME .. "|r:", ...)
end

local function ApplyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			ApplyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
	return target
end

-- Redraws are batched: any number of events in one frame cause a single redraw.
-- Modes, strongest first:
--   "layout"  - something the player did (assign, sort, section change): rebuild everything
--   "items"   - bag contents changed: rescan; the compact layout keeps its arrangement
--   "buttons" - only button state changed (locks, search, quest marks)
local MODE_RANK = { buttons = 1, items = 2, layout = 3 }
local refreshQueued, pendingMode = false, nil

local function RunRefresh()
	refreshQueued = false
	local mode = pendingMode
	pendingMode = nil
	if mode == "buttons" then
		ns.Frame.UpdateButtons()
	elseif mode then
		ns.Frame.Render(mode)
	end
end

-- mode: "layout" (default; also true or nil), "items", or "buttons" (also false).
function ns.RequestRefresh(mode)
	if mode == nil or mode == true then
		mode = "layout"
	elseif mode == false then
		mode = "buttons"
	end
	if not pendingMode or MODE_RANK[mode] > MODE_RANK[pendingMode] then
		pendingMode = mode
	end
	if not ns.Frame.IsShown() then
		return
	end
	if not refreshQueued then
		refreshQueued = true
		C_Timer.After(0, RunRefresh)
	end
end

local FULL_REFRESH_EVENTS = {
	BAG_UPDATE_DELAYED = "items",
	BAG_CONTAINER_UPDATE = "layout",
	GET_ITEM_INFO_RECEIVED = "items",
	CURSOR_CHANGED = "items",
}

local BUTTON_REFRESH_EVENTS = {
	ITEM_LOCK_CHANGED = true,
	INVENTORY_SEARCH_UPDATE = true,
	BAG_NEW_ITEMS_UPDATED = true,
	QUEST_ACCEPTED = true,
	UNIT_QUEST_LOG_CHANGED = true,
	MERCHANT_SHOW = true,
	MERCHANT_CLOSED = true,
}

-- Bank contents are remembered on every visit (see Bank.lua).
local BANK_EVENTS = {
	BANKFRAME_OPENED = true,
	BANKFRAME_CLOSED = true,
	PLAYERBANKSLOTS_CHANGED = true,
	BANK_TABS_CHANGED = true,
	BANK_TAB_SETTINGS_UPDATED = true,
}

local events = CreateFrame("Frame")

local function OnAddonLoaded()
	BagSectionsDB = ApplyDefaults(type(BagSectionsDB) == "table" and BagSectionsDB or {}, ns.DEFAULTS)
	BagSectionsCharDB = Rules.Upgrade(BagSectionsCharDB)
	ns.db = BagSectionsDB
	ns.charDB = BagSectionsCharDB

	ns.Frame.Init()
	ns.BankFrame.Init()
	ns.Options.Init()
	if ns.db.takeOverBags then
		ns.Hooks.Install()
	end

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
		if tooltip ~= GameTooltip then
			return
		end
		local owner = tooltip:GetOwner()
		if owner and owner.bsSectionName and owner:IsVisible() then
			tooltip:AddLine(L.TOOLTIP_SECTION:format(owner.bsSectionName), 0.4, 0.8, 1)
		end
	end)

	for event in pairs(FULL_REFRESH_EVENTS) do
		events:RegisterEvent(event)
	end
	for event in pairs(BUTTON_REFRESH_EVENTS) do
		events:RegisterEvent(event)
	end
	events:RegisterEvent("BAG_UPDATE_COOLDOWN")
	events:RegisterEvent("PLAYER_MONEY")
	events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	-- Ticking or unticking "Show on Backpack" in the Currency tab.
	if EventRegistry then
		EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", function() ns.Frame.UpdateFooter() end, events)
	end
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	for event in pairs(BANK_EVENTS) do
		events:RegisterEvent(event)
	end
	events:RegisterEvent("PLAYER_LOGIN")
end

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			events:UnregisterEvent("ADDON_LOADED")
			OnAddonLoaded()
		end
	elseif event == "PLAYER_LOGIN" then
		ns.ItemButtons.Precreate(ns.Inventory.Scan())
	elseif event == "BANKFRAME_OPENED" then
		ns.Bank.OnOpened()
	elseif event == "BANKFRAME_CLOSED" then
		ns.Bank.OnClosed()
	elseif BANK_EVENTS[event] then
		ns.Bank.RequestSnapshot()
	elseif FULL_REFRESH_EVENTS[event] then
		ns.RequestRefresh(FULL_REFRESH_EVENTS[event])
		if event == "BAG_UPDATE_DELAYED" then
			ns.Bank.RequestSnapshot()
		end
	elseif BUTTON_REFRESH_EVENTS[event] then
		ns.RequestRefresh("buttons")
	elseif event == "BAG_UPDATE_COOLDOWN" then
		if ns.Frame.IsShown() then
			ns.ItemButtons.UpdateCooldowns()
		end
	elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
		ns.Frame.UpdateFooter()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.Sorter.OnCombatEnded()
	end
end)
events:RegisterEvent("ADDON_LOADED")

-- Finds the bag item button under the mouse, if any.
local function ItemUnderMouse()
	for _, region in ipairs(GetMouseFoci and GetMouseFoci() or {}) do
		if region.GetBagID and region.GetID and region.HasItem and region:HasItem() then
			local bag = region:GetBagID()
			if bag and ns.Inventory.IsSectionBag(bag) then
				return ns.Inventory.GetItem(bag, region:GetID())
			end
		end
	end
end

local function FindSectionByName(name)
	local lower = name:lower()
	for _, section in ipairs(ns.charDB.sections) do
		if section.name:lower() == lower then
			return section
		end
	end
end

SLASH_BAGSECTIONS1 = "/bagsections"
SLASH_BAGSECTIONS2 = "/bs"
SlashCmdList.BAGSECTIONS = function(input)
	local command, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	command = command:lower()

	if command == "" then
		ns.Frame.Toggle()
	elseif command == "sort" then
		ns.Sorter.Sort()
	elseif command == "new" and rest ~= "" then
		Rules.CreateSection(ns.charDB, rest, ns.NewSectionsBelowRest())
		ns.RequestRefresh()
	elseif command == "add" and rest ~= "" then
		local section = FindSectionByName(rest)
		if not section then
			ns.Print(L.SECTION_NOT_FOUND:format(rest))
			return
		end
		local item = ItemUnderMouse()
		if not item then
			ns.Print(L.NO_ITEM_UNDER_MOUSE)
			return
		end
		Rules.Assign(ns.charDB, item, section.id, Rules.MatchedKind(ns.charDB, item) or Rules.DefaultKind(item, ns.db))
		ns.Print(L.ADDED_TO:format(C_Item.GetItemNameByID(item.itemID) or item.itemID, section.name))
		ns.RequestRefresh()
	elseif command == "bank" then
		ns.BankFrame.Toggle()
	elseif command == "config" or command == "options" then
		ns.Options.Open()
	else
		for _, line in ipairs(L.HELP) do
			ns.Print(line)
		end
	end
end
