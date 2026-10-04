-- Remembers what is in the bank, so it can be looked at from anywhere.
-- The game only answers questions about bank slots while the bank is open, so every visit
-- takes a snapshot: the character's bank per character, the account bank account wide.
-- Snapshot shape:
--   { updated = time(), tabs = { { name, icon, size, items = { [slot] = item } } } }
--   item = { id, count, quality, icon, link }

local _, ns = ...

local Bank = {}
ns.Bank = Bank

local isOpen = false
local snapshotQueued = false

-- Reads one bank type (character or account). Returns nil when it can't be read right now,
-- so an earlier snapshot is kept instead of being replaced by an empty one.
local function Read(bankType)
	if C_Bank.CanViewBank and not C_Bank.CanViewBank(bankType) then
		return nil
	end
	local tabs, totalSize = {}, 0
	for index, tab in ipairs(C_Bank.FetchPurchasedBankTabData(bankType) or {}) do
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
		tabs[index] = { name = tab.name, icon = tab.icon, size = size, items = items }
		totalSize = totalSize + size
	end
	if #tabs > 0 and totalSize == 0 then
		return nil -- tabs known but their slots not loaded yet
	end
	return { updated = time(), tabs = tabs }
end

local function Snapshot()
	snapshotQueued = false
	if not (isOpen and C_Bank and Enum.BankType) then
		return
	end
	ns.charDB.bank = Read(Enum.BankType.Character) or ns.charDB.bank
	if Enum.BankType.Account then
		ns.db.accountBank = Read(Enum.BankType.Account) or ns.db.accountBank
	end
	ns.BankFrame.Refresh()
end

-- Snapshots are batched like redraws: many events in one frame cause one snapshot.
function Bank.RequestSnapshot()
	if isOpen and not snapshotQueued then
		snapshotQueued = true
		C_Timer.After(0, Snapshot)
	end
end

function Bank.OnOpened()
	isOpen = true
	Bank.RequestSnapshot()
end

function Bank.OnClosed()
	isOpen = false
	ns.BankFrame.Refresh()
end

-- True while the player is at the bank, so the viewer shows what's there right now.
function Bank.IsOpen()
	return isOpen
end

-- The snapshots to show: the character's bank, then the account bank.
-- Returns a list of { kind = "character" | "account", data = snapshot }.
function Bank.GetSnapshots(charDB, db)
	local list = {}
	if charDB.bank then
		table.insert(list, { kind = "character", data = charDB.bank })
	end
	if db.accountBank then
		table.insert(list, { kind = "account", data = db.accountBank })
	end
	return list
end

-- Free and total slots across snapshots.
function Bank.CountFree(snapshots)
	local free, total = 0, 0
	for _, snapshot in ipairs(snapshots) do
		for _, tab in ipairs(snapshot.data.tabs) do
			total = total + tab.size
			for slot = 1, tab.size do
				if not tab.items[slot] then
					free = free + 1
				end
			end
		end
	end
	return free, total
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
