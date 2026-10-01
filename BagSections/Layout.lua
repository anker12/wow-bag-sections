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

-- Compact ("flow") layout geometry. All groups run through one set of rows, like
-- Blizzard's combined bag: each group's cells follow straight after the previous group's,
-- wrapping onto the next row. A group that starts partway along a row is shifted right by
-- `groupGap` extra pixels so neighbouring outlines get breathing room.

-- sizes[i]: cells in group i. width: row width in pixels. button: cell size. step: cell
-- size plus spacing. Returns cells[i] = { { row, x }, ... } and the number of rows.
function Layout.FlowRows(sizes, width, button, step, groupGap)
	local cells = {}
	local row, x, rowUsed = 0, 0, false
	for i, size in ipairs(sizes) do
		cells[i] = {}
		if rowUsed and size > 0 then
			x = x + groupGap
		end
		for _ = 1, size do
			if x + button > width then
				row, x = row + 1, 0
			end
			table.insert(cells[i], { row = row, x = x })
			x = x + step
			rowUsed = true
		end
	end
	return cells, rowUsed and row + 1 or 0
end

-- Per-row horizontal extent of a group's cells: { row, left, right } in reading order.
function Layout.Strips(groupCells, button)
	local strips = {}
	for _, cell in ipairs(groupCells) do
		local last = strips[#strips]
		if last and last.row == cell.row then
			last.right = cell.x + button
		else
			table.insert(strips, { row = cell.row, left = cell.x, right = cell.x + button })
		end
	end
	return strips
end

local function Overlaps(a, b)
	return a.l < b.r and b.l < a.r
end

-- Splits padded strips { l, r, t, b } (pixels, y down) into chains of strips that touch
-- horizontally on consecutive rows. Each chain is outlined as one shape.
local function Chains(boxes)
	local chains = {}
	for i, box in ipairs(boxes) do
		local chain = chains[#chains]
		if i > 1 and Overlaps(boxes[i - 1], box) then
			table.insert(chain, box)
		else
			table.insert(chains, { box })
		end
	end
	return chains
end

local function AddPoint(points, x, y)
	local last = points[#points]
	if last and last.x == x and last.y == y then
		return
	end
	table.insert(points, { x = x, y = y })
end

-- Removes points that sit in the middle of a straight edge.
local function Simplify(points)
	local result = {}
	local n = #points
	for i = 1, n do
		local prev, cur, nxt = points[(i - 2) % n + 1], points[i], points[i % n + 1]
		local straight = (prev.x == cur.x and cur.x == nxt.x) or (prev.y == cur.y and cur.y == nxt.y)
		if not straight then
			table.insert(result, cur)
		end
	end
	return result
end

-- Outline polygons (clockwise, pixels, y down) around padded strips { l, r, t, b }.
-- Steps between rows sit on the edge of whichever row is wider, so the padding around the
-- items is the same on every side.
function Layout.StripPolygons(boxes)
	local polygons = {}
	for _, chain in ipairs(Chains(boxes)) do
		local points = {}
		local k = #chain
		AddPoint(points, chain[1].l, chain[1].t)
		AddPoint(points, chain[1].r, chain[1].t)
		for i = 1, k - 1 do
			local a, b = chain[i], chain[i + 1]
			if a.r > b.r then
				AddPoint(points, a.r, a.b)
				AddPoint(points, b.r, a.b)
			elseif a.r < b.r then
				AddPoint(points, a.r, b.t)
				AddPoint(points, b.r, b.t)
			end
		end
		AddPoint(points, chain[k].r, chain[k].b)
		AddPoint(points, chain[k].l, chain[k].b)
		for i = k - 1, 1, -1 do
			local below, above = chain[i + 1], chain[i]
			if below.l < above.l then
				AddPoint(points, below.l, below.t)
				AddPoint(points, above.l, below.t)
			elseif below.l > above.l then
				AddPoint(points, below.l, above.b)
				AddPoint(points, above.l, above.b)
			end
		end
		table.insert(polygons, Simplify(points))
	end
	return polygons
end

-- Where a group's name goes: the longest stretch of top edge of each separate part of
-- the group (a wrapped group whose rows don't touch has two parts, each gets a name).
-- Returns a list of { index, l, r }, index being the strip the stretch belongs to.
function Layout.TopEdges(boxes)
	local edges, best = {}, nil
	local function Consider(index, l, r)
		if r > l and (not best or r - l > best.r - best.l) then
			best = { index = index, l = l, r = r }
		end
	end
	for i, box in ipairs(boxes) do
		local above = boxes[i - 1]
		if i == 1 or not Overlaps(above, box) then
			if best then
				table.insert(edges, best)
				best = nil
			end
			Consider(i, box.l, box.r)
		else
			Consider(i, box.l, math.min(box.r, above.l))
			Consider(i, math.max(box.l, above.r), box.r)
		end
	end
	if best then
		table.insert(edges, best)
	end
	return edges
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
