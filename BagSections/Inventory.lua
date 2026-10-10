-- Reads the player's bags into a flat list of slots in physical order.

local _, ns = ...

local Inventory = {}
ns.Inventory = Inventory

local REAGENT_BAG = Enum.BagIndex.ReagentBag
local KEYRING = Enum.BagIndex.Keyring

local function NumBagSlots()
	return (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots) or NUM_BAG_SLOTS or 4
end

local function IsEquippedBag(bag)
	return bag >= Enum.BagIndex.Backpack and bag <= NumBagSlots()
end

-- Item family bits of the bags that only take ammo: quivers (arrows) and ammo pouches
-- (bullets).
local AMMO_FAMILY = 0x0001 + 0x0002

-- A quiver or ammo pouch in one of the normal bag slots. Like the reagent bag, its slots
-- get an Ammo group of their own and are never part of sections or Rest.
function Inventory.IsAmmoBag(bag)
	if bag <= Enum.BagIndex.Backpack or not IsEquippedBag(bag) then
		return false
	end
	local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
	return bit.band(bagFamily or 0, AMMO_FAMILY) ~= 0
end

-- Bags whose items are sorted into sections: backpack and the normal bag slots, apart from
-- quivers and ammo pouches.
function Inventory.IsSectionBag(bag)
	return IsEquippedBag(bag) and not Inventory.IsAmmoBag(bag)
end

-- The section bags' IDs, in order.
function Inventory.SectionBags()
	local bags = {}
	for bag = Enum.BagIndex.Backpack, NumBagSlots() do
		if Inventory.IsSectionBag(bag) then
			table.insert(bags, bag)
		end
	end
	return bags
end

-- Every bag ID this addon's window takes over from the default UI.
function Inventory.IsHandledBag(bag)
	return IsEquippedBag(bag) or bag == REAGENT_BAG or bag == KEYRING
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

-- Crafting reagents: the items Blizzard's reagent bag accepts. Unknown until the item's
-- info is loaded (a redraw follows GET_ITEM_INFO_RECEIVED).
local function IsReagent(itemID)
	return select(17, C_Item.GetItemInfo(itemID)) == true
end
Inventory.IsReagent = IsReagent

local function IsQuestClass(itemID)
	local classID = select(6, C_Item.GetItemInfoInstant(itemID))
	return classID == Enum.ItemClass.Questitem
end

-- Item identity used for section rules. Returns nil for an empty slot.
function Inventory.GetItem(bag, slot)
	local itemID = C_Container.GetContainerItemID(bag, slot)
	if not itemID then
		return nil
	end
	local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
	local guid = C_Item.DoesItemExist(location) and C_Item.GetItemGUID(location) or nil
	local questInfo = C_Container.GetContainerItemQuestInfo(bag, slot)
	return {
		itemID = itemID,
		guid = guid,
		equippable = C_Item.IsEquippableItem(itemID),
		maxStack = C_Item.GetItemMaxStackSizeByID(itemID),
		isQuest = (questInfo and (questInfo.isQuestItem or questInfo.questID ~= nil)) or IsQuestClass(itemID),
		isReagent = IsReagent(itemID),
	}
end

-- Whether a location (e.g. the cursor's) points at an item that can be looked up. Some
-- can't: a bag picked up from the bank's bag slots makes Blizzard's own IsValid raise an
-- error, so ask carefully and treat those as unknown.
function Inventory.IsKnownLocation(location)
	if not location then
		return false
	end
	local ok, exists = pcall(function()
		return location:IsValid() and C_Item.DoesItemExist(location)
	end)
	return ok and exists or false
end

-- Same as GetItem, but for any ItemLocation (cursor, equipment slot, bank).
function Inventory.GetItemFromLocation(location)
	if not Inventory.IsKnownLocation(location) then
		return nil
	end
	local itemID = C_Item.GetItemID(location)
	if not itemID then
		return nil
	end
	if location:IsBagAndSlot() then
		return Inventory.GetItem(location:GetBagAndSlot())
	end
	return {
		itemID = itemID,
		guid = C_Item.GetItemGUID(location),
		equippable = C_Item.IsEquippableItem(itemID),
		maxStack = C_Item.GetItemMaxStackSizeByID(itemID),
		isQuest = IsQuestClass(itemID),
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
		local area = Inventory.IsAmmoBag(bag) and "ammo" or "bags"
		AddBag(slots, bag, area, C_Container.GetContainerNumSlots(bag) or 0)
	end
	AddBag(slots, REAGENT_BAG, "reagent", C_Container.GetContainerNumSlots(REAGENT_BAG) or 0)
	AddBag(slots, KEYRING, "keyring", KeyringSize())
	return slots
end

-- Character bank tabs are bags of their own (CharacterBankTab_1 .. 9).
local FIRST_BANK_TAB = Enum.BagIndex.CharacterBankTab_1
local LAST_BANK_TAB = Enum.BagIndex.CharacterBankTab_9 or (FIRST_BANK_TAB and FIRST_BANK_TAB + 8)

function Inventory.IsBankBag(bag)
	return FIRST_BANK_TAB ~= nil and bag >= FIRST_BANK_TAB and bag <= LAST_BANK_TAB
end

-- The character bank's purchased tabs: { { ID = bag, name, icon } }. Only answers while the
-- bank is open.
function Inventory.BankTabs()
	if not (C_Bank and C_Bank.FetchPurchasedBankTabData and Enum.BankType) then
		return {}
	end
	return C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character) or {}
end

-- The character bank's slots, live (while at the bank), in tab order.
function Inventory.ScanBank()
	local slots = {}
	for _, tab in ipairs(Inventory.BankTabs()) do
		AddBag(slots, tab.ID, "bank", C_Container.GetContainerNumSlots(tab.ID) or 0)
	end
	return slots
end

function Inventory.FindFreeBankSlot()
	for _, tab in ipairs(Inventory.BankTabs()) do
		local freeSlots = C_Container.GetContainerFreeSlots(tab.ID)
		if freeSlots and freeSlots[1] then
			return tab.ID, freeSlots[1]
		end
	end
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
