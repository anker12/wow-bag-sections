-- Section definitions and item -> section assignment rules.
-- Pure logic: no WoW API calls, so it can be unit tested outside the game.

local _, ns = ...

local Rules = {}
ns.Rules = Rules

Rules.REST = "rest"

Rules.KIND_ITEMID = "itemID"
Rules.KIND_GUID = "guid"

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

function Rules.CreateSection(db, name)
	local section = {
		id = "s" .. db.nextId,
		name = name,
		collapsed = false,
		below = false,
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
	local _, index = Rules.GetSection(db, id)
	if not index then
		return false
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

-- key is "rest", "reagent" or "keyring".
function Rules.ToggleBuiltinCollapsed(db, key)
	db.collapsedBuiltin[key] = not db.collapsedBuiltin[key] or nil
end

-- Drops rules that point at sections which no longer exist.
function Rules.Prune(db)
	local valid = {}
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

-- Returns the section id an item belongs to, or Rules.REST. Exact-item rules win.
function Rules.Classify(db, item)
	if not item then
		return Rules.REST
	end
	local sectionId = item.guid and db.rules.byGUID[item.guid]
	if sectionId and Rules.GetSection(db, sectionId) then
		return sectionId
	end
	sectionId = item.itemID and db.rules.byItemID[item.itemID]
	if sectionId and Rules.GetSection(db, sectionId) then
		return sectionId
	end
	return Rules.REST
end

-- Which rule currently places this item, if any: Rules.KIND_GUID, Rules.KIND_ITEMID or nil.
function Rules.MatchedKind(db, item)
	if item.guid and db.rules.byGUID[item.guid] and Rules.GetSection(db, db.rules.byGUID[item.guid]) then
		return Rules.KIND_GUID
	end
	if item.itemID and db.rules.byItemID[item.itemID] and Rules.GetSection(db, db.rules.byItemID[item.itemID]) then
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
	end
end
