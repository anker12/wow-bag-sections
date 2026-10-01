-- Row arrangement for the semi-compact layout: which sections (and Rest) share each row, in
-- which order. Pure logic: no WoW API calls, so it can be unit tested outside the game.
--
-- db.rows is a list of rows, each a list of keys (section ids, or "rest"). While db.rows is
-- nil the arrangement is automatic (Rows.Auto); the first time the player moves something it
-- is saved and from then on kept in step with the section list (Rows.Sync).

local _, ns = ...

local Rows = {}
ns.Rows = Rows

Rows.REST = "rest"

-- Sections above Rest in rows of perRow, Rest on its own row, then sections below Rest.
function Rows.Auto(db, perRow)
	perRow = math.max(1, perRow or 3)
	local rows, current = {}, nil
	local function Add(key)
		if not current or #current >= perRow then
			current = {}
			table.insert(rows, current)
		end
		table.insert(current, key)
	end
	for _, section in ipairs(db.sections) do
		if not section.below then
			Add(section.id)
		end
	end
	current = nil
	table.insert(rows, { Rows.REST })
	for _, section in ipairs(db.sections) do
		if section.below then
			Add(section.id)
		end
	end
	return rows
end

local function RowOf(rows, key)
	for i, row in ipairs(rows) do
		for j, k in ipairs(row) do
			if k == key then
				return i, j
			end
		end
	end
end

-- Keeps db.rows in step with the section list: drops deleted sections, duplicates and empty
-- rows, and gives sections that aren't placed yet a row of their own: just above Rest's row,
-- or at the end for sections set to sit below Rest.
function Rows.Sync(db)
	if not db.rows then
		return
	end
	local valid = { [Rows.REST] = true }
	for _, section in ipairs(db.sections) do
		valid[section.id] = true
	end
	local rows, seen = {}, {}
	for _, row in ipairs(db.rows) do
		local kept = {}
		for _, key in ipairs(row) do
			if valid[key] and not seen[key] then
				seen[key] = true
				table.insert(kept, key)
			end
		end
		if #kept > 0 then
			table.insert(rows, kept)
		end
	end
	if not seen[Rows.REST] then
		table.insert(rows, { Rows.REST })
	end
	for _, section in ipairs(db.sections) do
		if not seen[section.id] then
			if section.below then
				table.insert(rows, { section.id })
			else
				table.insert(rows, (RowOf(rows, Rows.REST)), { section.id })
			end
		end
	end
	db.rows = rows
end

-- The arrangement to draw: the saved one, or the automatic one.
function Rows.Get(db, perRow)
	if db.rows then
		Rows.Sync(db)
		return db.rows
	end
	return Rows.Auto(db, perRow)
end

-- Makes the section list follow the rows' reading order, and marks sections after Rest as
-- below it, so the other layouts show the same order.
function Rows.ApplyOrder(db)
	local byId = {}
	for _, section in ipairs(db.sections) do
		byId[section.id] = section
	end
	local ordered, afterRest = {}, false
	for _, row in ipairs(db.rows) do
		for _, key in ipairs(row) do
			if key == Rows.REST then
				afterRest = true
			elseif byId[key] then
				byId[key].below = afterRest
				table.insert(ordered, byId[key])
				byId[key] = nil
			end
		end
	end
	for _, section in ipairs(db.sections) do
		if byId[section.id] then
			table.insert(ordered, section)
		end
	end
	db.sections = ordered
end

-- Moves `key` (a section id or "rest"). target is either
--   { row = i, before = key-or-nil } to join row i before that key (nil: at the end), or
--   { newRow = i } to become a new row at position i (#rows + 1 for the end).
-- maxPerRow stops rows getting more sections than fit. Returns true if anything changed.
function Rows.Move(db, key, target, perRow, maxPerRow)
	if not db.rows then
		db.rows = Rows.Auto(db, perRow)
	end
	Rows.Sync(db)
	local rows = db.rows
	local fromRow, fromIndex = RowOf(rows, key)
	if not fromRow or key == target.before then
		return false
	end

	local targetRow = target.row and rows[target.row]
	if target.row and not targetRow then
		return false
	end
	if targetRow and maxPerRow then
		local others = #targetRow - (targetRow == rows[fromRow] and 1 or 0)
		if others >= maxPerRow then
			return false
		end
	end

	table.remove(rows[fromRow], fromIndex)
	local newRowAt = target.newRow
	if #rows[fromRow] == 0 then
		if targetRow == rows[fromRow] then
			-- Dropped back onto the row it was alone in: nothing changes.
			table.insert(rows[fromRow], key)
			return false
		end
		table.remove(rows, fromRow)
		if newRowAt and newRowAt > fromRow then
			newRowAt = newRowAt - 1
		end
	end

	if targetRow then
		local position = #targetRow + 1
		for j, k in ipairs(targetRow) do
			if k == target.before then
				position = j
			end
		end
		table.insert(targetRow, position, key)
	else
		newRowAt = math.max(1, math.min(newRowAt or #rows + 1, #rows + 1))
		table.insert(rows, newRowAt, { key })
	end
	Rows.ApplyOrder(db)
	return true
end

-- Back to the automatic arrangement.
function Rows.Reset(db)
	db.rows = nil
end

-- Profiles store rows by section name, since ids differ between characters.
function Rows.Export(db)
	if not db.rows then
		return nil
	end
	local names = {}
	for _, section in ipairs(db.sections) do
		names[section.id] = section.name
	end
	local rows = {}
	for _, row in ipairs(db.rows) do
		local named = {}
		for _, key in ipairs(row) do
			table.insert(named, key == Rows.REST and { rest = true } or { name = names[key] })
		end
		table.insert(rows, named)
	end
	return rows
end

function Rows.Import(db, saved)
	if not saved then
		db.rows = nil
		return
	end
	local ids = {}
	for _, section in ipairs(db.sections) do
		ids[section.name:lower()] = section.id
	end
	local rows = {}
	for _, row in ipairs(saved) do
		local keys = {}
		for _, entry in ipairs(row) do
			local key = entry.rest and Rows.REST or (entry.name and ids[entry.name:lower()])
			if key then
				table.insert(keys, key)
			end
		end
		table.insert(rows, keys)
	end
	db.rows = rows
	Rows.Sync(db)
end
