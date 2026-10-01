-- Turns a scanned list of bag slots into display groups (sections, Rest, Reagents, Keyring).
-- Pure logic: no WoW API calls, so it can be unit tested outside the game.

local _, ns = ...

local Layout = {}
ns.Layout = Layout

-- slots: array in physical order of
--   { bag = n, slot = n, area = "bags" | "reagent" | "keyring", item = { itemID, guid, ... } | nil }
-- opts: { showEmpty = bool, hideKeyring = bool }
-- Returns an array of groups:
--   { key, kind = "section" | "rest" | "reagent" | "keyring", name, collapsed, color, below, slots = {...}, count }
-- Order: sections above Rest, Rest, sections below Rest, Reagents, Keyring.
-- Only "bags" area items are classified into sections; empty slots always go to Rest, in
-- physical bag order among Rest's items.
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
			-- Empty slots stay where they physically are, so items can be dropped into any
			-- of them and appear right there.
			table.insert(rest.slots, slot)
		else
			local sectionId = Rules.Classify(db, slot.item)
			local group = sectionGroups[sectionId] or rest
			table.insert(group.slots, slot)
			group.count = group.count + 1
		end
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
	if #keyring.slots > 0 and not opts.hideKeyring then
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
-- Outline edges around a group's padded row strips { l, r, t, b } (pixels, y down), as
-- straight segments { x1, y1, x2, y2 }. Simple rules, one strip at a time:
--   * every strip has a line at its left and right end (start/end of the section, or
--     start/end of the bag row);
--   * top and bottom lines are drawn wherever the row above/below isn't the same section;
--   * where the row above/below continues the section, the end lines reach across the
--     gap between rows so the outline stays joined.
function Layout.StripEdges(boxes)
	local edges = {}
	local function Add(x1, y1, x2, y2)
		if x1 ~= x2 or y1 ~= y2 then
			table.insert(edges, { x1 = x1, y1 = y1, x2 = x2, y2 = y2 })
		end
	end
	local function Covers(other, x)
		return other and other.l <= x and x <= other.r
	end
	for i, box in ipairs(boxes) do
		local above = boxes[i - 1]
		local below = boxes[i + 1]
		if above and not Overlaps(above, box) then above = nil end
		if below and not Overlaps(below, box) then below = nil end

		-- Ends, stretched to meet the neighbouring row where it continues past this end.
		for _, x in ipairs({ box.l, box.r }) do
			local top = Covers(above, x) and above.b or box.t
			local bottom = Covers(below, x) and below.t or box.b
			Add(x, top, x, bottom)
		end

		-- Top: the parts not covered by the row above.
		if above then
			Add(box.l, box.t, math.min(box.r, above.l), box.t)
			Add(math.max(box.l, above.r), box.t, box.r, box.t)
		else
			Add(box.l, box.t, box.r, box.t)
		end
		-- Bottom: the parts not covered by the row below.
		if below then
			Add(box.l, box.b, math.min(box.r, below.l), box.b)
			Add(math.max(box.l, below.r), box.b, box.r, box.b)
		else
			Add(box.l, box.b, box.r, box.b)
		end
	end
	-- Drop zero-length or inverted pieces left by the min/max clipping above.
	local result = {}
	for _, e in ipairs(edges) do
		if e.x2 >= e.x1 and e.y2 >= e.y1 then
			table.insert(result, e)
		end
	end
	return result
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
