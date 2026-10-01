-- Startup, saved variables, events and slash commands.

local addonName, ns = ...
local L = ns.L
local Rules = ns.Rules

ns.DEFAULTS = {
	frame = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -60, y = 100 },
	columns = 10,
	scale = 1,
	showEmptySections = false,
	stackableRule = Rules.KIND_ITEMID,
	equippableRule = Rules.KIND_GUID,
	takeOverBags = true,
}

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
local refreshQueued, fullRefresh = false, false

local function RunRefresh()
	refreshQueued = false
	if fullRefresh then
		fullRefresh = false
		ns.Frame.Render()
	else
		ns.Frame.UpdateButtons()
	end
end

-- full = true rescans the bags and rebuilds the layout; false only updates button state.
function ns.RequestRefresh(full)
	if full == nil or full then
		fullRefresh = true
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
	BAG_UPDATE_DELAYED = true,
	BAG_CONTAINER_UPDATE = true,
	GET_ITEM_INFO_RECEIVED = true,
	CURSOR_CHANGED = true,
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

local events = CreateFrame("Frame")

local function OnAddonLoaded()
	BagSectionsDB = ApplyDefaults(type(BagSectionsDB) == "table" and BagSectionsDB or {}, ns.DEFAULTS)
	BagSectionsCharDB = Rules.Upgrade(BagSectionsCharDB)
	ns.db = BagSectionsDB
	ns.charDB = BagSectionsCharDB

	ns.Frame.Init()
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
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
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
	elseif FULL_REFRESH_EVENTS[event] then
		ns.RequestRefresh(true)
	elseif BUTTON_REFRESH_EVENTS[event] then
		ns.RequestRefresh(false)
	elseif event == "BAG_UPDATE_COOLDOWN" then
		if ns.Frame.IsShown() then
			ns.ItemButtons.UpdateCooldowns()
		end
	elseif event == "PLAYER_MONEY" then
		ns.Frame.UpdateMoney()
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
		Rules.CreateSection(ns.charDB, rest)
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
	elseif command == "config" or command == "options" then
		ns.Options.Open()
	else
		for _, line in ipairs(L.HELP) do
			ns.Print(line)
		end
	end
end
