-- Remembers every character's bags, bank and sections account-wide, so they can be looked
-- at from any other character (see AltFrame.lua).
-- Each character's own data is per character (BagSectionsCharDB), which other characters
-- can't read, so a copy is kept in BagSectionsDB.characters[key], key = "Name-Ruleset":
--   { name, realm, class, money, updated,
--     bags = { updated, tabs = { { bag, area, size, items = { [slot] = item } } } },
--     bank = <the bank snapshot, see Bank.lua>,
--     sections = <bag sections and rules>, bankSections = <bank sections and rules> }
--   item = { id, guid, isQuest, count, quality, icon, link }, the same as the bank's.
-- Copied at login, as the bags change, and at logout. Only the parts of the section data
-- that sort items are kept (no bank snapshot inside, no profiles).

local _, ns = ...

local Alts = {}
ns.Alts = Alts

local saveQueued = false

-- The parts of a section db that decide where items go and how they're shown.
local SECTION_FIELDS = { "version", "sections", "rules", "collapsedBuiltin", "rows", "autoQuest", "autoReagent", "nextId" }

function Alts.TrimSections(db)
	if type(db) ~= "table" then
		return nil
	end
	local copy = {}
	for _, field in ipairs(SECTION_FIELDS) do
		copy[field] = db[field]
	end
	return copy
end

function Alts.Key(name, realm)
	if not name or name == "" then
		return nil
	end
	return name .. "-" .. (realm or "")
end

-- The saved characters other than `currentKey`, sorted by ruleset (the current one first),
-- then name. Returns a list of { key, entry }.
function Alts.List(characters, currentKey)
	local current = characters and currentKey and characters[currentKey]
	local currentRealm = current and current.realm
	local list = {}
	for key, entry in pairs(characters or {}) do
		if key ~= currentKey and type(entry) == "table" then
			table.insert(list, { key = key, entry = entry })
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = a.entry.realm or "", b.entry.realm or ""
		if ra ~= rb then
			if ra == currentRealm then return true end
			if rb == currentRealm then return false end
			return ra < rb
		end
		return (a.entry.name or a.key) < (b.entry.name or b.key)
	end)
	return list
end

-- A saved character's slots for the viewer: their bags or their bank, with item details in
-- slot.cached and enough about each item for the section rules.
function Alts.Slots(entry, view, IsReagent)
	local snapshot
	if entry then
		if view == "bank" then
			snapshot = entry.bank
		else
			snapshot = entry.bags
		end
	end
	local slots = ns.Bank.SnapshotSlots(snapshot)
	for _, slot in ipairs(slots) do
		if slot.item and IsReagent then
			slot.item.isReagent = IsReagent(slot.item.itemID)
		end
	end
	return slots
end

-- Section data for the viewer, upgraded once so older or partial copies still work.
function Alts.SectionDB(entry, view)
	local field = view == "bank" and "bankSections" or "sections"
	entry[field] = ns.Rules.Upgrade(entry[field])
	return entry[field]
end

-- Game-dependent part below.

function Alts.PlayerKey()
	return Alts.Key(UnitName("player"), GetRealmName())
end

-- The bags as saved slots, in the same shape as the bank snapshot.
local function ReadBags()
	local tabs, byBag = {}, {}
	for _, slot in ipairs(ns.Inventory.Scan()) do
		local tab = byBag[slot.bag]
		if not tab then
			tab = { bag = slot.bag, area = slot.area, size = 0, items = {} }
			byBag[slot.bag] = tab
			table.insert(tabs, tab)
		end
		tab.size = math.max(tab.size, slot.slot)
		local info = slot.item and C_Container.GetContainerItemInfo(slot.bag, slot.slot)
		if info then
			tab.items[slot.slot] = {
				id = slot.item.itemID,
				guid = slot.item.guid,
				isQuest = slot.item.isQuest or nil,
				count = info.stackCount,
				quality = info.quality,
				icon = info.iconFileID,
				link = info.hyperlink,
			}
		end
	end
	return { updated = time(), tabs = tabs }
end

function Alts.Save()
	saveQueued = false
	local key = Alts.PlayerKey()
	if not (key and ns.db and ns.charDB) then
		return
	end
	ns.db.characters = ns.db.characters or {}
	local entry = ns.db.characters[key] or {}
	entry.name = UnitName("player")
	entry.realm = GetRealmName()
	entry.class = select(2, UnitClass("player"))
	entry.money = GetMoney()
	entry.bags = ReadBags()
	entry.bank = ns.charDB.bank
	entry.sections = Alts.TrimSections(ns.charDB)
	entry.bankSections = Alts.TrimSections(ns.charDB.bankSections)
	entry.updated = time()
	ns.db.characters[key] = entry
end

-- Batched like redraws: many bag events in one frame cause one save.
function Alts.RequestSave()
	if not saveQueued then
		saveQueued = true
		C_Timer.After(0, Alts.Save)
	end
end

function Alts.Forget(key)
	if ns.db.characters and key ~= Alts.PlayerKey() then
		ns.db.characters[key] = nil
	end
end

-- "Name", or "Name (Ruleset)" for characters on another ruleset, in their class colour.
function Alts.DisplayName(entry, withRealm)
	local name = entry.name or "?"
	if withRealm and entry.realm and entry.realm ~= GetRealmName() then
		name = name .. " (" .. entry.realm .. ")"
	end
	local color = entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
	if color and color.colorStr then
		return "|c" .. color.colorStr .. name .. "|r"
	end
	return name
end

function Alts.GetAll()
	return Alts.List(ns.db.characters, Alts.PlayerKey())
end
