-- Section definitions and item -> section assignment rules.
-- Pure logic: no WoW API calls, so it can be unit tested outside the game.

local _, ns = ...

local Rules = {}
ns.Rules = Rules

Rules.REST = "rest"

Rules.KIND_ITEMID = "itemID"
Rules.KIND_GUID = "guid"

-- Automatic sections fill themselves from item properties instead of explicit rules.
Rules.AUTO_QUEST = "quest"
Rules.AUTO_REAGENT = "reagent" -- the bank's automatic Reagents section

-- Which db flag turns each automatic section on, and which items it takes.
local AUTO_FLAG = { [Rules.AUTO_QUEST] = "autoQuest", [Rules.AUTO_REAGENT] = "autoReagent" }
local AUTO_TAKES = {
	[Rules.AUTO_QUEST] = function(item) return item.isQuest end,
	[Rules.AUTO_REAGENT] = function(item) return item.isReagent end,
}

-- Outline colours handed out to new sections in turn (used by the compact layout).
Rules.PALETTE = {
	{ r = 0.30, g = 0.65, b = 1.00 },
	{ r = 1.00, g = 0.60, b = 0.20 },
	{ r = 0.45, g = 0.85, b = 0.35 },
	{ r = 0.85, g = 0.40, b = 0.90 },
	{ r = 1.00, g = 0.85, b = 0.25 },
	{ r = 0.95, g = 0.35, b = 0.40 },
	{ r = 0.30, g = 0.85, b = 0.80 },
	{ r = 0.95, g = 0.55, b = 0.75 },
}

local function PaletteColor(n)
	local c = Rules.PALETTE[(n - 1) % #Rules.PALETTE + 1]
	return { r = c.r, g = c.g, b = c.b }
end

function Rules.NewCharDB()
	return {
		version = 1,
		sections = {},
		rules = { byItemID = {}, byGUID = {} },
		-- Collapsed state of the built-in groups: rest, reagent, keyring.
		collapsedBuiltin = {},
		autoQuest = false,
		nextId = 1,
	}
end

-- Fills in missing fields so older or partial saved data keeps working.
function Rules.Upgrade(db)
	db = type(db) == "table" and db or Rules.NewCharDB()
	db.version = db.version or 1
	db.sections = type(db.sections) == "table" and db.sections or {}
	db.rules = type(db.rules) == "table" and db.rules or {}
	db.rules.byItemID = type(db.rules.byItemID) == "table" and db.rules.byItemID or {}
	db.rules.byGUID = type(db.rules.byGUID) == "table" and db.rules.byGUID or {}
	db.collapsedBuiltin = type(db.collapsedBuiltin) == "table" and db.collapsedBuiltin or {}
	if type(db.rows) ~= "table" then
		db.rows = nil
	end
	db.autoQuest = db.autoQuest and true or false
	db.autoReagent = db.autoReagent and true or false
	db.nextId = tonumber(db.nextId) or 1
	for index, section in ipairs(db.sections) do
		local n = tonumber(section.id and section.id:match("^s(%d+)$"))
		if n and n >= db.nextId then
			db.nextId = n + 1
		end
		if type(section.color) ~= "table" then
			section.color = PaletteColor(n or index)
		end
	end
	Rules.Prune(db)
	return db
end

function Rules.GetSection(db, id)
	for index, section in ipairs(db.sections) do
		if section.id == id then
			return section, index
		end
	end
end

-- below = true places the new section below Rest.
function Rules.CreateSection(db, name, below)
	local section = {
		id = "s" .. db.nextId,
		name = name,
		collapsed = false,
		below = below and true or false,
		color = PaletteColor(db.nextId),
	}
	db.nextId = db.nextId + 1
	table.insert(db.sections, section)
	return section
end

function Rules.RenameSection(db, id, name)
	local section = Rules.GetSection(db, id)
	if section then
		section.name = name
		return true
	end
	return false
end

-- Removes the section and every rule pointing at it; its items fall back to Rest.
function Rules.DeleteSection(db, id)
	local section, index = Rules.GetSection(db, id)
	if not index then
		return false
	end
	if AUTO_FLAG[section.auto] then
		db[AUTO_FLAG[section.auto]] = false
	end
	table.remove(db.sections, index)
	Rules.ClearSection(db, id)
	return true
end

function Rules.ClearSection(db, id)
	for key, sectionId in pairs(db.rules.byItemID) do
		if sectionId == id then
			db.rules.byItemID[key] = nil
		end
	end
	for key, sectionId in pairs(db.rules.byGUID) do
		if sectionId == id then
			db.rules.byGUID[key] = nil
		end
	end
end

-- delta is -1 (up) or 1 (down). Swaps with the nearest section on the same side of Rest,
-- so moving always has a visible effect.
function Rules.MoveSection(db, id, delta)
	local section, index = Rules.GetSection(db, id)
	if not index then
		return false
	end
	local target = index + delta
	while target >= 1 and target <= #db.sections do
		if (db.sections[target].below or false) == (section.below or false) then
			db.sections[index], db.sections[target] = db.sections[target], db.sections[index]
			return true
		end
		target = target + delta
	end
	return false
end

-- Places the section above (below = false) or below (below = true) Rest.
function Rules.SetSectionBelow(db, id, below)
	local section = Rules.GetSection(db, id)
	if not section then
		return false
	end
	section.below = below and true or false
	return true
end

function Rules.SetSectionColor(db, id, r, g, b)
	local section = Rules.GetSection(db, id)
	if not section then
		return false
	end
	section.color = { r = r, g = g, b = b }
	return true
end

-- key is "rest", "reagent", "bagreagent" or "keyring".
function Rules.ToggleBuiltinCollapsed(db, key)
	db.collapsedBuiltin[key] = not db.collapsedBuiltin[key] or nil
end

-- Drops rules that point at sections which no longer exist. Rules pointing at Rest are
-- kept: they stop an automatic section from taking an item the player moved out.
function Rules.Prune(db)
	local valid = { [Rules.REST] = true }
	for _, section in ipairs(db.sections) do
		valid[section.id] = true
	end
	for key, sectionId in pairs(db.rules.byItemID) do
		if not valid[sectionId] then
			db.rules.byItemID[key] = nil
		end
	end
	for key, sectionId in pairs(db.rules.byGUID) do
		if not valid[sectionId] then
			db.rules.byGUID[key] = nil
		end
	end
end

-- item: { itemID = number, guid = string?, equippable = bool?, maxStack = number? }
-- settings: { stackableRule = kind, equippableRule = kind }
function Rules.DefaultKind(item, settings)
	local stackable = (item.maxStack or 1) > 1
	if item.equippable and not stackable then
		return settings and settings.equippableRule or Rules.KIND_GUID
	end
	return settings and settings.stackableRule or Rules.KIND_ITEMID
end

-- The automatic section an item would go to, ignoring explicit rules.
function Rules.AutoSection(db, item)
	for _, section in ipairs(db.sections) do
		local auto = section.auto
		if auto and db[AUTO_FLAG[auto]] and AUTO_TAKES[auto](item) then
			return section.id
		end
	end
end

local function RuleTarget(db, sectionId)
	if sectionId == Rules.REST or (sectionId and Rules.GetSection(db, sectionId)) then
		return sectionId
	end
end

-- Returns the section id an item belongs to, or Rules.REST.
-- Order: exact-item rule, item-type rule, automatic section, Rest.
function Rules.Classify(db, item)
	if not item then
		return Rules.REST
	end
	local target = item.guid and RuleTarget(db, db.rules.byGUID[item.guid])
	if target then
		return target
	end
	target = item.itemID and RuleTarget(db, db.rules.byItemID[item.itemID])
	if target then
		return target
	end
	return Rules.AutoSection(db, item) or Rules.REST
end

-- Which explicit rule currently places this item in a section: Rules.KIND_GUID,
-- Rules.KIND_ITEMID or nil.
function Rules.MatchedKind(db, item)
	local byGUID = item.guid and db.rules.byGUID[item.guid]
	if byGUID and byGUID ~= Rules.REST and Rules.GetSection(db, byGUID) then
		return Rules.KIND_GUID
	end
	local byItemID = item.itemID and db.rules.byItemID[item.itemID]
	if byItemID and byItemID ~= Rules.REST and Rules.GetSection(db, byItemID) then
		return Rules.KIND_ITEMID
	end
end

function Rules.Assign(db, item, sectionId, kind)
	if not Rules.GetSection(db, sectionId) then
		return false
	end
	if kind == Rules.KIND_GUID then
		if not item.guid then
			return false
		end
		db.rules.byGUID[item.guid] = sectionId
	else
		if not item.itemID then
			return false
		end
		if item.guid then
			db.rules.byGUID[item.guid] = nil
		end
		db.rules.byItemID[item.itemID] = sectionId
	end
	return true
end

function Rules.Unassign(db, item)
	if item.guid then
		db.rules.byGUID[item.guid] = nil
	end
	if item.itemID then
		db.rules.byItemID[item.itemID] = nil
		-- Keep it out of an automatic section it would otherwise fall back into.
		if Rules.AutoSection(db, item) then
			db.rules.byItemID[item.itemID] = Rules.REST
		end
	end
end

-- Keeps an item in Rest even though an automatic group (Quest Items, Reagents (bags))
-- would take it.
function Rules.KeepInRest(db, item)
	if item.guid then
		db.rules.byGUID[item.guid] = nil
	end
	if item.itemID then
		db.rules.byItemID[item.itemID] = Rules.REST
	end
end

function Rules.IsKeptInRest(db, item)
	return (item.guid and db.rules.byGUID[item.guid] == Rules.REST)
		or (item.itemID and db.rules.byItemID[item.itemID] == Rules.REST) or false
end

local function HasRules(db, id)
	for _, sectionId in pairs(db.rules.byItemID) do
		if sectionId == id then return true end
	end
	for _, sectionId in pairs(db.rules.byGUID) do
		if sectionId == id then return true end
	end
	return false
end

-- Turns an automatic section (Rules.AUTO_QUEST, Rules.AUTO_REAGENT) on or off. Turning it on
-- reuses an existing one or creates one called `name`. Turning it off deletes that section
-- if nothing was added to it by hand; otherwise it stays as a normal section.
function Rules.SetAuto(db, auto, enabled, name, below)
	local existing
	for _, section in ipairs(db.sections) do
		if section.auto == auto then
			existing = section
		end
	end
	if enabled then
		db[AUTO_FLAG[auto]] = true
		if not existing then
			existing = Rules.CreateSection(db, name, below)
			existing.auto = auto
		end
		return existing
	end
	db[AUTO_FLAG[auto]] = false
	if existing then
		if HasRules(db, existing.id) then
			existing.auto = nil
		else
			Rules.DeleteSection(db, existing.id)
		end
	end
end

-- Sections in `from` that `to` doesn't have yet (by name), not counting automatic ones.
function Rules.MissingSections(from, to)
	local have = {}
	for _, section in ipairs(to.sections) do
		have[section.name:lower()] = true
	end
	local missing = {}
	for _, section in ipairs(from.sections) do
		if not section.auto and not have[section.name:lower()] then
			table.insert(missing, section)
		end
	end
	return missing
end

-- Copies sections (name, colour, above/below Rest, in order) from one section list to
-- another, e.g. the bags' to the bank's. Items stay where they are. `sections` is a list
-- of sections from `from`, or nil for all that `to` doesn't have yet. Returns the new ones.
function Rules.CopySections(from, to, sections)
	local created = {}
	for _, source in ipairs(sections or Rules.MissingSections(from, to)) do
		local copy = Rules.CreateSection(to, source.name, source.below)
		if source.color then
			copy.color = { r = source.color.r, g = source.color.g, b = source.color.b }
		end
		table.insert(created, copy)
	end
	return created
end

-- The automatic "Quest Items" section.
function Rules.SetAutoQuest(db, enabled, name, below)
	return Rules.SetAuto(db, Rules.AUTO_QUEST, enabled, name, below)
end

-- Profiles store the section list only (names, order, colours, placement), not which
-- items are in them.
function Rules.ExportProfile(db)
	local profile = { sections = {} }
	for _, section in ipairs(db.sections) do
		local c = section.color
		table.insert(profile.sections, {
			name = section.name,
			below = section.below or false,
			collapsed = section.collapsed or false,
			auto = section.auto,
			color = c and { r = c.r, g = c.g, b = c.b } or nil,
		})
	end
	-- Semi-compact row arrangement, by section name (nil while it's automatic).
	profile.rows = ns.Rows.Export(db)
	return profile
end

-- Sections in the profile that match an existing section by name keep that section, and
-- the items already in it. Sections not in the profile are removed (their items go to
-- Rest). Returns how many sections were removed.
function Rules.ApplyProfile(db, profile)
	local byName = {}
	for _, section in ipairs(db.sections) do
		byName[section.name:lower()] = byName[section.name:lower()] or section
	end

	local newList, kept = {}, {}
	for _, saved in ipairs(profile.sections or {}) do
		local section = byName[saved.name:lower()]
		if section and not kept[section] then
			kept[section] = true
		else
			section = { id = "s" .. db.nextId }
			db.nextId = db.nextId + 1
		end
		section.name = saved.name
		section.below = saved.below or false
		section.collapsed = saved.collapsed or false
		section.auto = saved.auto
		if saved.color then
			section.color = { r = saved.color.r, g = saved.color.g, b = saved.color.b }
		elseif not section.color then
			section.color = PaletteColor(#newList + 1)
		end
		table.insert(newList, section)
	end

	local removed = 0
	for _, section in ipairs(db.sections) do
		if not kept[section] then
			removed = removed + 1
		end
	end

	db.sections = newList
	db.autoQuest = false
	for _, section in ipairs(newList) do
		if section.auto == Rules.AUTO_QUEST then
			db.autoQuest = true
		end
	end
	Rules.Prune(db)
	ns.Rows.Import(db, profile.rows)
	return removed
end

-- How many current sections loading this profile would remove.
function Rules.CountRemovedByProfile(db, profile)
	local names = {}
	for _, saved in ipairs(profile.sections or {}) do
		names[saved.name:lower()] = true
	end
	local removed = 0
	for _, section in ipairs(db.sections) do
		if not names[section.name:lower()] then
			removed = removed + 1
		end
	end
	return removed
end
