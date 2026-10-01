-- Turns a scanned list of bag slots into display groups (sections, Rest, Reagents, Keyring).
-- Pure logic: no WoW API calls, so it can be unit tested outside the game.

local _, ns = ...

local Layout = {}
ns.Layout = Layout

-- slots: array in physical order of
--   { bag = n, slot = n, area = "bags" | "reagent" | "keyring", item = { itemID, guid, ... } | nil }
-- opts: { showEmpty = bool }
-- Returns an array of groups:
--   { key, kind = "section" | "rest" | "reagent" | "keyring", name, collapsed, color, below, slots = {...}, count }
-- Order: sections above Rest, Rest, sections below Rest, Reagents, Keyring.
-- Only "bags" area items are classified into sections; empty slots always go to Rest.
function Layout.Build(db, slots, opts)
	opts = opts or {}
	local Rules = ns.Rules

	local sectionGroups = {}
	local groups = {}
	for _, section in ipairs(db.sections) do
		local group = {
			key = section.id,
			kind = "section",
			name = section.name,
			collapsed = section.collapsed,
			color = section.color,
			below = section.below or false,
			slots = {},
			count = 0,
		}
		sectionGroups[section.id] = group
		table.insert(groups, group)
	end

	local collapsed = db.collapsedBuiltin or {}
	local rest = { key = Rules.REST, kind = "rest", slots = {}, count = 0, collapsed = collapsed.rest or false }
	local restEmpty = {}
	local reagent = { key = "reagent", kind = "reagent", slots = {}, count = 0, collapsed = collapsed.reagent or false }
	local keyring = { key = "keyring", kind = "keyring", slots = {}, count = 0, collapsed = collapsed.keyring or false }

	for _, slot in ipairs(slots) do
		if slot.area == "reagent" then
			table.insert(reagent.slots, slot)
			if slot.item then reagent.count = reagent.count + 1 end
		elseif slot.area == "keyring" then
			table.insert(keyring.slots, slot)
			if slot.item then keyring.count = keyring.count + 1 end
		elseif not slot.item then
			table.insert(restEmpty, slot)
		else
			local sectionId = Rules.Classify(db, slot.item)
			local group = sectionGroups[sectionId] or rest
			table.insert(group.slots, slot)
			group.count = group.count + 1
		end
	end

	for _, slot in ipairs(restEmpty) do
		table.insert(rest.slots, slot)
	end

	local result = {}
	local function AddSections(below)
		for _, group in ipairs(groups) do
			if group.below == below and (group.count > 0 or opts.showEmpty) then
				table.insert(result, group)
			end
		end
	end
	AddSections(false)
	table.insert(result, rest)
	AddSections(true)
	if #reagent.slots > 0 then
		table.insert(result, reagent)
	end
	if #keyring.slots > 0 then
		table.insert(result, keyring)
	end
	return result
end

-- Compact ("flow") layout geometry. All groups share one grid of `columns` columns, like
-- Blizzard's combined bag: each group is a run of cells that starts right after the
-- previous one and wraps onto the next row. Cells are numbered from 0 in reading order.

-- sizes[i] = number of cells group i takes. Returns runs[i] = { start, length } and the
-- total number of cells.
function Layout.Flow(sizes)
	local runs, start = {}, 0
	for i, size in ipairs(sizes) do
		runs[i] = { start = start, length = size }
		start = start + size
	end
	return runs, start
end

local function RunEnds(run, columns)
	local last = run.start + run.length - 1
	return math.floor(run.start / columns), run.start % columns, math.floor(last / columns), last % columns
end

-- Rectangles covering a run, in grid units: { col, row, cols, rows }.
function Layout.RunRects(run, columns)
	if run.length <= 0 then
		return {}
	end
	local r0, c0, r1, c1 = RunEnds(run, columns)
	if r0 == r1 then
		return { { col = c0, row = r0, cols = c1 - c0 + 1, rows = 1 } }
	end
	local rects = { { col = c0, row = r0, cols = columns - c0, rows = 1 } }
	if r1 - r0 > 1 then
		table.insert(rects, { col = 0, row = r0 + 1, cols = columns, rows = r1 - r0 - 1 })
	end
	table.insert(rects, { col = 0, row = r1, cols = c1 + 1, rows = 1 })
	return rects
end

local function RectPolygon(c0, r0, c1, r1)
	return { { x = c0, y = r0 }, { x = c1, y = r0 }, { x = c1, y = r1 }, { x = c0, y = r1 } }
end

-- Outline of a run as clockwise polygons of grid corners { x = column line, y = row line }.
-- Usually one polygon; two when a run wraps without its rows overlapping.
function Layout.RunPolygons(run, columns)
	if run.length <= 0 then
		return {}
	end
	local r0, c0, r1, c1 = RunEnds(run, columns)
	if r0 == r1 then
		return { RectPolygon(c0, r0, c1 + 1, r0 + 1) }
	end
	if r1 == r0 + 1 and c1 < c0 then
		return { RectPolygon(c0, r0, columns, r0 + 1), RectPolygon(0, r1, c1 + 1, r1 + 1) }
	end
	local points = {}
	local function Add(x, y) table.insert(points, { x = x, y = y }) end
	Add(c0, r0)
	Add(columns, r0)
	if c1 == columns - 1 then
		Add(columns, r1 + 1)
	else
		Add(columns, r1)
		Add(c1 + 1, r1)
		Add(c1 + 1, r1 + 1)
	end
	Add(0, r1 + 1)
	if c0 > 0 then
		Add(0, r0 + 1)
		Add(c0, r0 + 1)
	end
	return { points }
end

-- Where a run's name label goes: the longest stretch of the run's top edge.
-- Returns { row, col, cols } in grid units.
function Layout.LabelSegment(run, columns)
	local r0, c0, r1, c1 = RunEnds(run, columns)
	local first = { row = r0, col = c0, cols = (r0 == r1 and c1 or columns - 1) - c0 + 1 }
	if r1 > r0 and c0 > 0 then
		local secondEnd = math.min(c0 - 1, r1 == r0 + 1 and c1 or columns - 1)
		local second = { row = r0 + 1, col = 0, cols = secondEnd + 1 }
		if second.cols > first.cols then
			return second
		end
	end
	return first
end

-- Moves every edge of a clockwise orthogonal polygon (screen coordinates, y down) inwards
-- by d, so neighbouring outlines sit side by side instead of on top of each other.
function Layout.InsetPolygon(points, d)
	local n = #points
	local result = {}
	local function Normal(a, b)
		local dx, dy = b.x - a.x, b.y - a.y
		local len = math.abs(dx) + math.abs(dy)
		return -dy / len, dx / len
	end
	for i = 1, n do
		local prev, cur, nxt = points[(i - 2) % n + 1], points[i], points[i % n + 1]
		local nx1, ny1 = Normal(prev, cur)
		local nx2, ny2 = Normal(cur, nxt)
		result[i] = { x = cur.x + d * (nx1 + nx2), y = cur.y + d * (ny1 + ny2) }
	end
	return result
end

-- Counts free and total slots for the footer.
function Layout.CountFree(slots)
	local free, total = 0, 0
	for _, slot in ipairs(slots) do
		total = total + 1
		if not slot.item then
			free = free + 1
		end
	end
	return free, total
end
