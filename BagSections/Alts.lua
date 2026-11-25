-- Remembers every character's bags, bank and sections account-wide, so they can be looked
-- at from any other character (see AltFrame.lua).
-- Each character's own data is per character (BagSectionsCharDB), which other characters
-- can't read, so a copy is kept in BagSectionsDB.characters[key], key = "Name-Ruleset":
--   { name, realm, class, money, updated,
--     bags = { updated, tabs = { { bag, area, size, items = { [slot] = item } } } },
--     bank = <the bank snapshot, see Bank.lua>,
--     sections = <bag sections and rules>, bankSections = <bank sections and rules> }
--   item = { id, guid, isQuest, count, quality, icon, link }, the same as the bank's.
-- Copied at login and as the bags and gold change; at logout only the sections and bank. Only the parts of the section data
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

-- Older versions saved each character a second time at logout, under the other ruleset name
-- the game gives while logging out, so they showed twice (e.g. in item tooltips). Those
-- copies were only ever saved at logout, so they have no bags. Each one is merged into the
-- one character with the same name and class that does have bags: its bank and section data
-- are kept if they're newer, and the copy is removed. Returns how many were merged.
function Alts.MergeLogoutCopies(characters)
	if type(characters) ~= "table" then
		return 0
	end
	local withBags = {}
	for key, entry in pairs(characters) do
		if type(entry) == "table" and entry.bags and entry.name then
			local id = entry.name .. "|" .. (entry.class or "")
			withBags[id] = withBags[id] or {}
			table.insert(withBags[id], key)
		end
	end
	local merged = 0
	for key, entry in pairs(characters) do
		if type(entry) == "table" and not entry.bags and entry.name then
			local targets = withBags[entry.name .. "|" .. (entry.class or "")]
			-- With two such characters (one name on two rulesets) it's unclear which one it is.
			if targets and #targets == 1 then
				local target = characters[targets[1]]
				if (entry.updated or 0) > (target.updated or 0) then
					target.bank = entry.bank or target.bank
					target.sections = entry.sections or target.sections
					target.bankSections = entry.bankSections or target.bankSections
					target.updated = entry.updated
				end
				characters[key] = nil
				merged = merged + 1
			end
		end
	end
	return merged
end

-- Removes every saved character except `keepKey`. Returns how many were removed.
function Alts.ForgetOthers(characters, keepKey)
	local removed = 0
	for key in pairs(characters or {}) do
		if key ~= keepKey then
			characters[key] = nil
			removed = removed + 1
		end
	end
	return removed
end

-- Game-dependent part below.

-- Worked out once, at login: while logging out the game can give a different ruleset name,
-- which would save the character a second time under another key.
local playerKey, playerRuleset
local copiesMerged = false

function Alts.OnLogin()
	playerKey, playerRuleset = nil, nil
	Alts.Save()
end

function Alts.PlayerKey()
	if not playerKey then
		local realm = GetRealmName()
		playerKey = Alts.Key(UnitName("player"), realm)
		if playerKey then
			playerRuleset = realm
		end
	end
	return playerKey
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
	if #tabs == 0 then
		return nil -- bags not loaded (e.g. while logging out): keep the last copy
	end
	return { updated = time(), tabs = tabs }
end

-- atLogout: the bags and gold can no longer be read while logging out (the game answers
-- with no bag slots and 0 gold), so only the section data and bank are refreshed then.
function Alts.Save(atLogout)
	saveQueued = false
	local key = Alts.PlayerKey()
	if not (key and ns.db and ns.charDB) then
		return
	end
	ns.db.characters = ns.db.characters or {}
	if not copiesMerged and atLogout ~= true then
		copiesMerged = true
		Alts.MergeLogoutCopies(ns.db.characters)
	end
	local entry = ns.db.characters[key] or {}
	entry.name = UnitName("player")
	entry.realm = playerRuleset
	entry.class = select(2, UnitClass("player"))
	if atLogout ~= true then
		local bags = ReadBags()
		if bags then
			entry.bags = bags
			entry.money = GetMoney()
		end
	end
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

-- Forgets every other character, e.g. stale copies left when a ruleset was renamed, and
-- saves this one again. Each comes back the next time it's logged in to.
function Alts.ForgetAllOthers()
	local removed = Alts.ForgetOthers(ns.db.characters, Alts.PlayerKey())
	Alts.Save()
	return removed
end

-- "Name", or "Name (Ruleset)" for characters on another ruleset, in their class colour.
function Alts.DisplayName(entry, withRealm)
	local name = entry.name or "?"
	Alts.PlayerKey()
	if withRealm and entry.realm and entry.realm ~= playerRuleset then
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
