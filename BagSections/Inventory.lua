-- Reads the player's bags into a flat list of slots in physical order.

local _, ns = ...

local Inventory = {}
ns.Inventory = Inventory

local REAGENT_BAG = Enum.BagIndex.ReagentBag
local KEYRING = Enum.BagIndex.Keyring

local function NumBagSlots()
	return (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots) or NUM_BAG_SLOTS or 4
end

-- Bags shown in the window: backpack and the normal bag slots.
function Inventory.IsSectionBag(bag)
	return bag >= Enum.BagIndex.Backpack and bag <= NumBagSlots()
end

-- Every bag ID this addon's window takes over from the default UI.
function Inventory.IsHandledBag(bag)
	return Inventory.IsSectionBag(bag) or bag == REAGENT_BAG or bag == KEYRING
end

local function KeyringSize()
	if not (C_ActionBar and C_ActionBar.ShouldShowKeyring and C_ActionBar.ShouldShowKeyring()) then
		return 0
	end
	if GetKeyRingSize then
		return GetKeyRingSize() or 0
	end
	return C_Container.GetContainerNumSlots(KEYRING) or 0
end

-- Item identity used for section rules. Returns nil for an empty slot.
function Inventory.GetItem(bag, slot)
	local itemID = C_Container.GetContainerItemID(bag, slot)
	if not itemID then
		return nil
	end
	local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
	local guid = C_Item.DoesItemExist(location) and C_Item.GetItemGUID(location) or nil
	return {
		itemID = itemID,
		guid = guid,
		equippable = C_Item.IsEquippableItem(itemID),
		maxStack = C_Item.GetItemMaxStackSizeByID(itemID),
	}
end

-- Same as GetItem, but for any ItemLocation (cursor, equipment slot, bank).
function Inventory.GetItemFromLocation(location)
	if not (location and location:IsValid() and C_Item.DoesItemExist(location)) then
		return nil
	end
	local itemID = C_Item.GetItemID(location)
	if not itemID then
		return nil
	end
	return {
		itemID = itemID,
		guid = C_Item.GetItemGUID(location),
		equippable = C_Item.IsEquippableItem(itemID),
		maxStack = C_Item.GetItemMaxStackSizeByID(itemID),
	}
end

local function AddBag(slots, bag, area, numSlots)
	for slot = 1, numSlots do
		table.insert(slots, {
			bag = bag,
			slot = slot,
			area = area,
			item = Inventory.GetItem(bag, slot),
		})
	end
end

function Inventory.Scan()
	local slots = {}
	for bag = Enum.BagIndex.Backpack, NumBagSlots() do
		AddBag(slots, bag, "bags", C_Container.GetContainerNumSlots(bag) or 0)
	end
	AddBag(slots, REAGENT_BAG, "reagent", C_Container.GetContainerNumSlots(REAGENT_BAG) or 0)
	AddBag(slots, KEYRING, "keyring", KeyringSize())
	return slots
end

-- Finds an empty slot in the section bags that can hold the given item.
function Inventory.FindFreeSlotFor(itemID)
	local itemFamily = C_Item.GetItemFamily(itemID) or 0
	-- Prefer general-purpose bags so profession bags stay free for their own items.
	for pass = 1, 2 do
		for bag = Enum.BagIndex.Backpack, NumBagSlots() do
			local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
			bagFamily = bagFamily or 0
			local fits = (pass == 1 and bagFamily == 0)
				or (pass == 2 and bagFamily ~= 0 and bit.band(bagFamily, itemFamily) ~= 0)
			if free and free > 0 and fits then
				local freeSlots = C_Container.GetContainerFreeSlots(bag)
				if freeSlots and freeSlots[1] then
					return bag, freeSlots[1]
				end
			end
		end
	end
end
