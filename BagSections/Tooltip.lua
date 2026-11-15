-- Lines BagSections adds to item tooltips:
--   * the section a bag item is in;
--   * while Shift is held, how many of that item each character has in their bags and
--     bank, from the copies Alts.lua saves. Works for any item tooltip, including the
--     reagents and results in profession windows.

local _, ns = ...

local Tooltip = {}
ns.Tooltip = Tooltip

-- How many of an item a saved bags or bank snapshot holds (see Bank.lua for the shape).
function Tooltip.CountInSnapshot(snapshot, itemID)
	local total = 0
	for _, tab in ipairs(snapshot and snapshot.tabs or {}) do
		for _, item in pairs(tab.items or {}) do
			if item.id == itemID then
				total = total + (item.count or 1)
			end
		end
	end
	return total
end

-- Every character's counts of an item: the current character first (always, even with
-- none), then the others that have some, in the alt list's order. `currentBank` is the
-- current character's latest bank snapshot, which can be newer than the saved copy.
-- Returns a list of { key, entry, bags, bank, bankSeen }.
function Tooltip.Counts(characters, currentKey, itemID, currentBank)
	local list = {}
	local current = characters and currentKey and characters[currentKey]
	if current then
		local bank = currentBank or current.bank
		table.insert(list, {
			key = currentKey, entry = current,
			bags = Tooltip.CountInSnapshot(current.bags, itemID),
			bank = Tooltip.CountInSnapshot(bank, itemID),
			bankSeen = bank ~= nil,
		})
	end
	for _, alt in ipairs(ns.Alts.List(characters, currentKey)) do
		local bags = Tooltip.CountInSnapshot(alt.entry.bags, itemID)
		local bank = Tooltip.CountInSnapshot(alt.entry.bank, itemID)
		if bags + bank > 0 then
			table.insert(list, { key = alt.key, entry = alt.entry, bags = bags, bank = bank, bankSeen = alt.entry.bank ~= nil })
		end
	end
	return list
end

-- "Bags: 12  Bank: 40", leaving out what's 0. "None" when both are.
function Tooltip.CountText(count, L)
	local parts = {}
	if count.bags > 0 then
		table.insert(parts, L.COUNT_BAGS:format(count.bags))
	end
	if count.bank > 0 then
		table.insert(parts, L.COUNT_BANK:format(count.bank))
	elseif not count.bankSeen then
		table.insert(parts, L.COUNT_BANK_UNSEEN)
	end
	if #parts == 0 then
		return L.COUNT_NONE
	end
	return table.concat(parts, "  ")
end

-- Game-dependent part below.

local function ItemIDFrom(tooltip, data)
	if data and type(data.id) == "number" then
		return data.id
	end
	local _, link = tooltip:GetItem()
	local id = link and link:match("item:(%d+)")
	return id and tonumber(id)
end

-- The item the counts were last added for, so they're not added twice (see OnShift).
local countsShown

local function AddCounts(tooltip, itemID)
	local L = ns.L
	if not (ns.db and ns.db.tooltipCounts and itemID) then
		return
	end
	local counts = Tooltip.Counts(ns.db.characters, ns.Alts.PlayerKey(), itemID, ns.charDB and ns.charDB.bank)
	if #counts == 0 then
		return
	end
	tooltip:AddLine(" ")
	local total = 0
	for _, count in ipairs(counts) do
		tooltip:AddDoubleLine(ns.Alts.DisplayName(count.entry, true), Tooltip.CountText(count, L), 1, 1, 1, 1, 1, 1)
		total = total + count.bags + count.bank
	end
	if #counts > 1 then
		tooltip:AddDoubleLine(L.COUNT_TOTAL, tostring(total), 1, 0.82, 0, 1, 0.82, 0)
	end
	countsShown = itemID
end

local lastItemID

local function OnItemTooltip(tooltip, data)
	local L = ns.L
	if tooltip ~= GameTooltip then
		return
	end
	local owner = tooltip:GetOwner()
	if owner and owner.bsSectionName and owner:IsVisible() then
		tooltip:AddLine(L.TOOLTIP_SECTION:format(owner.bsSectionName), 0.4, 0.8, 1)
	end
	lastItemID = ItemIDFrom(tooltip, data)
	if IsShiftKeyDown() then
		AddCounts(tooltip, lastItemID)
	end
end

-- Pressing or letting go of Shift over an item that's already showing. Tooltips that can
-- rebuild themselves (all of them on clients with tooltip data) are rebuilt, which adds or
-- removes the counts; otherwise the counts are added to the one showing.
local function OnShift(down)
	if not (GameTooltip:IsShown() and lastItemID) then
		return
	end
	if GameTooltip.RefreshData then
		GameTooltip:RefreshData()
	elseif down and countsShown ~= lastItemID then
		AddCounts(GameTooltip, lastItemID)
		GameTooltip:Show()
	end
end

function Tooltip.Init()
	if TooltipDataProcessor and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	else
		GameTooltip:HookScript("OnTooltipSetItem", OnItemTooltip)
	end
	GameTooltip:HookScript("OnTooltipCleared", function()
		countsShown = nil
		lastItemID = nil
	end)
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
	watcher:SetScript("OnEvent", function(_, _, key, down)
		if key == "LSHIFT" or key == "RSHIFT" then
			OnShift(down == 1)
		end
	end)
end
