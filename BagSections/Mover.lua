-- "Move all to bank" / "Move all to bags": moves every item of a section across, while at
-- the bank. The game has no call for this, so it does what a player would: pick an item up,
-- put it down on the other side, one item at a time. Each move waits until the server has
-- finished the previous one (both slots unlocked), so nothing is moved onto a busy slot.

local _, ns = ...
local L = ns.L

local Mover = {}
ns.Mover = Mover

local STEP = 0.05 -- seconds between checks
local TIMEOUT = 2 -- give up waiting for a move after this long
local MAX_TRIES = 3 -- per item, e.g. when the server refuses the move

local job

local function IsLocked(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	return info and info.isLocked or false
end

local REAGENT_BAG = Enum.BagIndex.ReagentBag

-- Reagents coming out of the bank go to the reagent bag first, like Blizzard's withdraw.
local function UsesReagentBag(itemID, toBank)
	return not toBank and REAGENT_BAG ~= nil and ns.Inventory.IsReagent(itemID)
		and (C_Container.GetContainerNumSlots(REAGENT_BAG) or 0) > 0
end

local function TargetBags(itemID, toBank)
	local bags = {}
	if toBank then
		for _, tab in ipairs(ns.Inventory.BankTabs()) do
			table.insert(bags, tab.ID)
		end
		return bags
	end
	if UsesReagentBag(itemID, toBank) then
		table.insert(bags, REAGENT_BAG)
	end
	for _, bag in ipairs(ns.Inventory.SectionBags()) do
		table.insert(bags, bag)
	end
	return bags
end

-- A stack of the same item with room left, else an empty slot that can hold it.
local function FindTarget(itemID, toBank)
	local maxStack = C_Item.GetItemMaxStackSizeByID(itemID) or 1
	if maxStack > 1 then
		for _, bag in ipairs(TargetBags(itemID, toBank)) do
			for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and info.itemID == itemID and (info.stackCount or 0) < maxStack and not info.isLocked then
					return bag, slot
				end
			end
		end
	end
	if toBank then
		return ns.Inventory.FindFreeBankSlot()
	end
	if UsesReagentBag(itemID, toBank) then
		local free = C_Container.GetContainerFreeSlots(REAGENT_BAG)
		if free and free[1] then
			return REAGENT_BAG, free[1]
		end
	end
	return ns.Inventory.FindFreeSlotFor(itemID)
end

local function Finish()
	local left, noRoom = 0, false
	for _, source in ipairs(job.sources) do
		if C_Container.GetContainerItemID(source.bag, source.slot) == source.itemID then
			left = left + 1
			noRoom = noRoom or source.noRoom
		end
	end
	local moved = #job.sources - left
	local toBank = job.toBank
	job = nil
	if not ns.Bank.IsOpen() then
		ns.Print(L.MOVE_STOPPED:format(moved))
	elseif left > 0 then
		ns.Print((noRoom and (toBank and L.MOVE_BANK_FULL or L.MOVE_BAGS_FULL) or L.MOVE_SOME_LEFT):format(moved, left))
	end
end

local Step

local function Continue()
	C_Timer.After(STEP, Step)
end

function Step()
	if not job then
		return
	end
	if not ns.Bank.IsOpen() then
		Finish()
		return
	end
	local pending = job.pending
	if pending then
		local busy = IsLocked(pending.bag, pending.slot) or IsLocked(pending.toBag, pending.toSlot)
		if busy and GetTime() - pending.at < TIMEOUT then
			Continue()
			return
		end
		job.pending = nil
	end
	-- Something the player picked up stays theirs; wait until it's put down.
	if CursorHasItem() then
		Continue()
		return
	end
	for _, source in ipairs(job.sources) do
		if source.tries < MAX_TRIES and C_Container.GetContainerItemID(source.bag, source.slot) == source.itemID then
			if IsLocked(source.bag, source.slot) then
				-- Still settling from another move; an item that stays locked is left alone.
				source.lockedSince = source.lockedSince or GetTime()
				if GetTime() - source.lockedSince < TIMEOUT then
					Continue()
					return
				end
				source.tries = MAX_TRIES
			else
				local toBag, toSlot = FindTarget(source.itemID, job.toBank)
				if toBag then
					source.tries = source.tries + 1
					C_Container.PickupContainerItem(source.bag, source.slot)
					C_Container.PickupContainerItem(toBag, toSlot)
					-- A refused move (or the rest of a stack that didn't fit) goes back where it was.
					if CursorHasItem() then
						ClearCursor()
					end
					job.pending = { bag = source.bag, slot = source.slot, toBag = toBag, toSlot = toSlot, at = GetTime() }
					Continue()
					return
				end
				source.tries, source.noRoom = MAX_TRIES, true
			end
		end
	end
	Finish()
end

function Mover.IsBusy()
	return job ~= nil
end

-- Moves the items of a section's group (as drawn in its window) to the bank, or from the
-- bank to the bags. Only while at the bank.
function Mover.MoveGroup(group, toBank)
	if job or not ns.Bank.IsOpen() then
		return
	end
	local sources = {}
	for _, slot in ipairs(group.slots) do
		if slot.item and not slot.cached then
			table.insert(sources, { bag = slot.bag, slot = slot.slot, itemID = slot.item.itemID, tries = 0 })
		end
	end
	if #sources == 0 then
		return
	end
	job = { sources = sources, toBank = toBank }
	Step()
end
