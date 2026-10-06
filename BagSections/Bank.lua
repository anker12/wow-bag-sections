-- Remembers what is in the character's bank, so it can be looked at from anywhere, and
-- lets the bank window take over from Blizzard's while at a banker.
-- The game only answers questions about bank slots while the bank is open, so every visit
-- takes a snapshot, saved per character. (Forever has no account bank in use; it's ignored.)
-- Snapshot shape:
--   { updated = time(), tabs = { { bag, name, icon, size, items = { [slot] = item } } } }
--   item = { id, count, quality, icon, link }

local _, ns = ...

local Bank = {}
ns.Bank = Bank

local isOpen = false
local snapshotQueued = false

-- Returns nil when the bank can't be read right now, so an earlier snapshot is kept instead
-- of being replaced by an empty one.
local function Read()
	if C_Bank.CanViewBank and not C_Bank.CanViewBank(Enum.BankType.Character) then
		return nil
	end
	local tabs, totalSize = {}, 0
	for index, tab in ipairs(ns.Inventory.BankTabs()) do
		local size = C_Container.GetContainerNumSlots(tab.ID) or 0
		local items = {}
		for slot = 1, size do
			local info = C_Container.GetContainerItemInfo(tab.ID, slot)
			if info and info.itemID then
				items[slot] = {
					id = info.itemID,
					count = info.stackCount,
					quality = info.quality,
					icon = info.iconFileID,
					link = info.hyperlink,
				}
			end
		end
		tabs[index] = { bag = tab.ID, name = tab.name, icon = tab.icon, size = size, items = items }
		totalSize = totalSize + size
	end
	if #tabs > 0 and totalSize == 0 then
		return nil -- tabs known but their slots not loaded yet
	end
	return { updated = time(), tabs = tabs, bagSlots = Bank.ReadBagSlots() }
end

local function Snapshot()
	snapshotQueued = false
	if not (isOpen and C_Bank and Enum.BankType) then
		return
	end
	ns.charDB.bank = Read() or ns.charDB.bank
end

-- Snapshots are batched like redraws: many events in one frame cause one snapshot.
function Bank.RequestSnapshot()
	if isOpen and not snapshotQueued then
		snapshotQueued = true
		C_Timer.After(0, Snapshot)
	end
end

-- Blizzard's bank window stays open while at the banker, so its deposit and withdraw code
-- keeps working (right-click in the bags puts items in the bank), but inside a frame scaled
-- down to nothing, so it's never seen. It's moved there after Blizzard shows it: a
-- hooksecurefunc runs after Blizzard's code and separately from it.
local tiny
local function HideBlizzardBank(panel)
	if panel == BankFrame and ns.db.replaceBank then
		if not tiny then
			tiny = CreateFrame("Frame", nil, UIParent)
			tiny:SetScale(0.001)
		end
		BankFrame:SetParent(tiny)
	end
end

function Bank.Init()
	if ShowUIPanel then
		hooksecurefunc("ShowUIPanel", HideBlizzardBank)
	end
end

function Bank.OnOpened()
	isOpen = true
	Bank.RequestSnapshot()
	if ns.db.replaceBank then
		ns.BankFrame.Show()
		-- First visit (including the first since bank sections came in): offer to set them up.
		if not ns.charDB.bankSetupDone then
			ns.Menu.StartBankSetup()
		end
	end
	ns.BankFrame.RequestRefresh()
end

function Bank.OnClosed()
	Snapshot()
	isOpen = false
	ns.BankFrame.Hide()
end

-- The bank's bag slots, like Blizzard's bank shows them: slot 1 is the bank itself, slots
-- 2 to max take a bag once bought. Only answers at the bank.
-- Returns { max = n, slots = { [slot] = { bought, icon, link } } }.
function Bank.ReadBagSlots()
	local bankType = Enum.BankType.Character
	local max = C_Bank.FetchMaxNumBankTabs and C_Bank.FetchMaxNumBankTabs(bankType) or 0
	local bought = #(C_Bank.FetchPurchasedBankTabData and C_Bank.FetchPurchasedBankTabData(bankType) or {})
	local slots = {}
	for index = 2, max do
		local slot = { bought = index <= bought }
		local location = ItemLocation:CreateFromBagAndSlot(Enum.BagIndex.Characterbanktab, index)
		if slot.bought and C_Item.DoesItemExist(location) then
			slot.icon = C_Item.GetItemIcon(location)
			slot.link = C_Item.GetItemLink(location)
		end
		slots[index] = slot
	end
	return { max = max, slots = slots }
end

-- True while the player is at the bank, so the bank window shows what's there right now.
function Bank.IsOpen()
	return isOpen
end

-- The last snapshot as slots, like Inventory.ScanBank's, with the saved item details in
-- slot.cached. Items carry their itemID, so item rules still sort them into sections.
function Bank.SnapshotSlots(snapshot)
	local slots = {}
	for index, tab in ipairs(snapshot and snapshot.tabs or {}) do
		local bag = tab.bag or (1000 + index) -- snapshots from before 1.3 didn't save the bag
		for slot = 1, tab.size do
			local cached = tab.items[slot]
			table.insert(slots, {
				bag = bag,
				slot = slot,
				area = "bank",
				cached = cached or false,
				item = cached and { itemID = cached.id } or nil,
			})
		end
	end
	return slots
end

-- "just now", "5 min ago", "3 h ago", "2 days ago".
function Bank.FormatAge(seconds, L)
	if seconds < 60 then
		return L.AGE_NOW
	elseif seconds < 3600 then
		return L.AGE_MINUTES:format(math.floor(seconds / 60))
	elseif seconds < 86400 then
		return L.AGE_HOURS:format(math.floor(seconds / 3600))
	end
	return L.AGE_DAYS:format(math.floor(seconds / 86400))
end
