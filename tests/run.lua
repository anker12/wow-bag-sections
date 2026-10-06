-- Unit tests for the game-independent modules (Rules, Layout).
-- Run from the repo root: lua tests/run.lua

local ns = {}
for _, file in ipairs({ "BagSections/Rules.lua", "BagSections/Rows.lua", "BagSections/Share.lua", "BagSections/Layout.lua", "BagSections/Bank.lua" }) do
	assert(loadfile(file))("BagSections", ns)
end
local Rules, Layout, Rows = ns.Rules, ns.Layout, ns.Rows

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL " .. name .. "\n  " .. tostring(err))
	end
end

local function eq(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label or "value", tostring(expected), tostring(actual)), 2)
	end
end

local HEARTHSTONE = { itemID = 6948, guid = "Item-1-0-HS", maxStack = 1 }
local PICK = { itemID = 2901, guid = "Item-1-0-PICK", maxStack = 1, equippable = false }
local SWORD_A = { itemID = 100, guid = "Item-1-0-SWA", maxStack = 1, equippable = true }
local SWORD_B = { itemID = 100, guid = "Item-1-0-SWB", maxStack = 1, equippable = true }
local POTION = { itemID = 200, guid = "Item-1-0-POT", maxStack = 20 }

local function Slots(list)
	local slots = {}
	for i, entry in ipairs(list) do
		slots[i] = { bag = entry.bag or 0, slot = i, area = entry.area or "bags", item = entry.item }
	end
	return slots
end

local function SlotItems(group)
	local items = {}
	for _, slot in ipairs(group.slots) do
		table.insert(items, slot.item and slot.item.guid or "empty")
	end
	return table.concat(items, ",")
end

test("new sections get unique ids and keep order", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "Essentials")
	local b = Rules.CreateSection(db, "Weapon swap")
	eq(a.id, "s1")
	eq(b.id, "s2")
	eq(db.sections[1].name, "Essentials")
	eq(db.sections[2].name, "Weapon swap")
end)

test("default rule kind: exact item for gear, item type otherwise", function()
	eq(Rules.DefaultKind(SWORD_A, nil), Rules.KIND_GUID)
	eq(Rules.DefaultKind(POTION, nil), Rules.KIND_ITEMID)
	eq(Rules.DefaultKind(HEARTHSTONE, nil), Rules.KIND_ITEMID)
	eq(Rules.DefaultKind(SWORD_A, { equippableRule = Rules.KIND_ITEMID, stackableRule = Rules.KIND_ITEMID }), Rules.KIND_ITEMID)
end)

test("item-type rule matches every copy, exact rule matches one", function()
	local db = Rules.NewCharDB()
	local s = Rules.CreateSection(db, "Gear")
	Rules.Assign(db, SWORD_A, s.id, Rules.KIND_GUID)
	eq(Rules.Classify(db, SWORD_A), s.id)
	eq(Rules.Classify(db, SWORD_B), Rules.REST)

	Rules.Assign(db, SWORD_A, s.id, Rules.KIND_ITEMID)
	eq(Rules.Classify(db, SWORD_B), s.id)
end)

test("exact-item rule wins over item-type rule", function()
	local db = Rules.NewCharDB()
	local all = Rules.CreateSection(db, "All swords")
	local one = Rules.CreateSection(db, "Main sword")
	Rules.Assign(db, SWORD_B, all.id, Rules.KIND_ITEMID)
	Rules.Assign(db, SWORD_A, one.id, Rules.KIND_GUID)
	eq(Rules.Classify(db, SWORD_A), one.id)
	eq(Rules.Classify(db, SWORD_B), all.id)
	eq(Rules.MatchedKind(db, SWORD_A), Rules.KIND_GUID)
	eq(Rules.MatchedKind(db, SWORD_B), Rules.KIND_ITEMID)
end)

test("moving an item between sections replaces its rule", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "A")
	local b = Rules.CreateSection(db, "B")
	Rules.Assign(db, POTION, a.id, Rules.KIND_ITEMID)
	Rules.Assign(db, POTION, b.id, Rules.KIND_ITEMID)
	eq(Rules.Classify(db, POTION), b.id)
end)

test("unassign returns the item to Rest", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "A")
	Rules.Assign(db, SWORD_A, a.id, Rules.KIND_GUID)
	Rules.Unassign(db, SWORD_A)
	eq(Rules.Classify(db, SWORD_A), Rules.REST)
end)

test("deleting a section removes its rules", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "A")
	local b = Rules.CreateSection(db, "B")
	Rules.Assign(db, POTION, a.id, Rules.KIND_ITEMID)
	Rules.Assign(db, SWORD_A, a.id, Rules.KIND_GUID)
	Rules.Assign(db, HEARTHSTONE, b.id, Rules.KIND_ITEMID)
	Rules.DeleteSection(db, a.id)
	eq(Rules.Classify(db, POTION), Rules.REST)
	eq(Rules.Classify(db, SWORD_A), Rules.REST)
	eq(Rules.Classify(db, HEARTHSTONE), b.id)
	eq(db.rules.byItemID[POTION.itemID], nil)
	eq(db.rules.byGUID[SWORD_A.guid], nil)
end)

test("assigning to a missing section fails", function()
	local db = Rules.NewCharDB()
	eq(Rules.Assign(db, POTION, "s99", Rules.KIND_ITEMID), false)
	eq(Rules.Classify(db, POTION), Rules.REST)
end)

test("move section up and down within bounds", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "A")
	local b = Rules.CreateSection(db, "B")
	eq(Rules.MoveSection(db, a.id, -1), false)
	eq(Rules.MoveSection(db, a.id, 1), true)
	eq(db.sections[1].id, b.id)
	eq(Rules.MoveSection(db, a.id, 1), false)
end)

test("upgrade repairs partial data and prunes dangling rules", function()
	local db = Rules.Upgrade({ sections = { { id = "s4", name = "X" } }, rules = { byItemID = { [1] = "s4", [2] = "s9" } } })
	eq(db.nextId, 5)
	eq(db.rules.byItemID[1], "s4")
	eq(db.rules.byItemID[2], nil)
	eq(type(db.rules.byGUID), "table")
	eq(Rules.CreateSection(db, "Y").id, "s5")
	eq(type(Rules.Upgrade(nil).sections), "table")
end)

test("layout: 20 slots, 3 essentials -> Essentials(3) and Rest(17)", function()
	local db = Rules.NewCharDB()
	local ess = Rules.CreateSection(db, "Essentials")
	local campfire = { itemID = 300, guid = "Item-1-0-CF", maxStack = 1 }
	for _, item in ipairs({ HEARTHSTONE, PICK, campfire }) do
		Rules.Assign(db, item, ess.id, Rules.KIND_ITEMID)
	end
	local list = {
		{ item = POTION }, { item = HEARTHSTONE }, {}, { item = PICK }, { item = SWORD_A },
		{}, { item = campfire },
	}
	for _ = #list + 1, 20 do
		table.insert(list, {})
	end
	local groups = Layout.Build(db, Slots(list))
	eq(#groups, 2)
	eq(groups[1].name, "Essentials")
	eq(groups[1].count, 3)
	eq(#groups[1].slots, 3, "no empty slots in a section")
	eq(SlotItems(groups[1]), "Item-1-0-HS,Item-1-0-PICK,Item-1-0-CF", "physical order kept")
	eq(groups[2].kind, "rest")
	eq(#groups[2].slots, 17)
	eq(groups[2].count, 2)
	eq(SlotItems(groups[2]):sub(1, 37), "Item-1-0-POT,empty,Item-1-0-SWA,empty", "Rest keeps physical bag order")
end)

test("layout: empty sections hidden unless asked", function()
	local db = Rules.NewCharDB()
	Rules.CreateSection(db, "Empty")
	local slots = Slots({ { item = POTION }, {} })
	eq(#Layout.Build(db, slots), 1)
	local groups = Layout.Build(db, slots, { showEmpty = true })
	eq(#groups, 2)
	eq(groups[1].count, 0)
end)

test("layout: reagent bag and keyring stay separate and are never classified", function()
	local db = Rules.NewCharDB()
	local s = Rules.CreateSection(db, "Potions")
	Rules.Assign(db, POTION, s.id, Rules.KIND_ITEMID)
	local slots = Slots({
		{ item = POTION },
		{ bag = 5, area = "reagent", item = POTION },
		{ bag = 5, area = "reagent" },
		{ bag = -1, area = "keyring", item = HEARTHSTONE },
	})
	local groups = Layout.Build(db, slots)
	eq(#groups, 4)
	eq(groups[1].count, 1)
	eq(groups[3].kind, "reagent")
	eq(#groups[3].slots, 2)
	eq(groups[3].count, 1)
	eq(groups[4].kind, "keyring")
end)

test("layout: keyring can be hidden", function()
	local db = Rules.NewCharDB()
	local slots = Slots({ { item = POTION }, { bag = -1, area = "keyring" } })
	eq(Layout.Build(db, slots)[2].kind, "keyring")
	eq(#Layout.Build(db, slots, { hideKeyring = true }), 1)
end)

test("free slot count", function()
	local free, total = Layout.CountFree(Slots({ { item = POTION }, {}, {} }))
	eq(free, 2)
	eq(total, 3)
end)

test("new sections get a colour and start above Rest", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "A")
	local b = Rules.CreateSection(db, "B")
	eq(a.below, false)
	eq(type(a.color), "table")
	eq(a.color.r, Rules.PALETTE[1].r)
	eq(b.color.r, Rules.PALETTE[2].r)
	Rules.SetSectionColor(db, a.id, 0.1, 0.2, 0.3)
	eq(a.color.g, 0.2)
end)

test("upgrade gives old sections a colour and collapsedBuiltin table", function()
	local db = Rules.Upgrade({ sections = { { id = "s2", name = "Old" } } })
	eq(type(db.sections[1].color), "table")
	eq(type(db.collapsedBuiltin), "table")
end)

test("layout: sections below Rest come after Rest, before Reagents", function()
	local db = Rules.NewCharDB()
	local above = Rules.CreateSection(db, "Above")
	local below = Rules.CreateSection(db, "Below")
	Rules.Assign(db, HEARTHSTONE, above.id, Rules.KIND_ITEMID)
	Rules.Assign(db, POTION, below.id, Rules.KIND_ITEMID)
	Rules.SetSectionBelow(db, below.id, true)
	local groups = Layout.Build(db, Slots({ { item = POTION }, { item = HEARTHSTONE }, {}, { bag = 5, area = "reagent" } }))
	eq(groups[1].key, above.id)
	eq(groups[2].kind, "rest")
	eq(groups[3].key, below.id)
	eq(groups[3].below, true)
	eq(groups[4].kind, "reagent")
end)

test("move up/down skips sections on the other side of Rest", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "A")
	local b = Rules.CreateSection(db, "B")
	local c = Rules.CreateSection(db, "C")
	Rules.SetSectionBelow(db, b.id, true)
	eq(Rules.MoveSection(db, c.id, -1), true)
	eq(db.sections[1].id, c.id, "C jumped over B to swap with A")
	eq(db.sections[3].id, a.id)
	eq(Rules.MoveSection(db, b.id, 1), false, "B is the only section below Rest")
end)

test("built-in groups can be collapsed", function()
	local db = Rules.NewCharDB()
	Rules.ToggleBuiltinCollapsed(db, "rest")
	local groups = Layout.Build(db, Slots({ { item = POTION }, { bag = 5, area = "reagent" } }))
	eq(groups[1].collapsed, true)
	eq(groups[2].collapsed, false)
	Rules.ToggleBuiltinCollapsed(db, "rest")
	eq(db.collapsedBuiltin.rest, nil)
end)

-- 10 columns of 37px buttons with 4px spacing: 406px wide; 14px extra before a section
-- that starts partway along a row.
local W, BTN, STEP, GAP = 406, 37, 41, 14

test("flow rows: a lone section fills the full width", function()
	local cells, rows = Layout.FlowRows({ 25 }, W, BTN, STEP, GAP)
	eq(rows, 3)
	eq(cells[1][10].row, 0); eq(cells[1][10].x, 369)
	eq(cells[1][11].row, 1); eq(cells[1][11].x, 0)
end)

test("flow rows: sections follow each other with a gap, wrapping when full", function()
	local cells, rows = Layout.FlowRows({ 3, 5, 0, 9 }, W, BTN, STEP, GAP)
	eq(cells[2][1].row, 0)
	eq(cells[2][1].x, 3 * STEP + GAP, "gap before a section that starts mid-row")
	eq(#cells[3], 0)
	-- empty section adds no gap; the last section starts at 356 and its 2nd cell wraps
	eq(cells[4][1].row, 0); eq(cells[4][1].x, 8 * STEP + 2 * GAP)
	eq(cells[4][2].row, 1); eq(cells[4][2].x, 0, "no gap at the start of a row")
	eq(rows, 2)
end)

test("flow rows: with no section gap, every row uses the same columns", function()
	local cells = Layout.FlowRows({ 3, 1, 7, 12, 2 }, 460, 37, 47, 0)
	local n = 0
	for _, group in ipairs(cells) do
		for _, cell in ipairs(group) do
			eq(cell.row, math.floor(n / 10), "row")
			eq(cell.x, (n % 10) * 47, "column")
			n = n + 1
		end
	end
end)

test("flow rows: cells never overflow the width or overlap", function()
	for _, sizes in ipairs({ { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, { 7, 2, 11, 3, 1, 20 }, { 0, 40 } }) do
		local cells = Layout.FlowRows(sizes, W, BTN, STEP, GAP)
		local seen = {}
		for _, group in ipairs(cells) do
			for _, cell in ipairs(group) do
				assert(cell.x >= 0 and cell.x + BTN <= W, "cell inside width")
				local key = cell.row .. ":" .. cell.x
				assert(not seen[key], "cells overlap")
				seen[key] = true
			end
		end
	end
end)

local function Boxes(strips, rowHeight, pad)
	local boxes = {}
	for _, strip in ipairs(strips) do
		local top = strip.row * rowHeight
		table.insert(boxes, { l = strip.left - pad, r = strip.right + pad, t = top - pad, b = top + BTN + pad })
	end
	return boxes
end

-- Is the point (x, y) on any of the segments?
local function OnEdge(edges, x, y)
	for _, e in ipairs(edges) do
		if x >= e.x1 and x <= e.x2 and y >= e.y1 and y <= e.y2 then
			return true
		end
	end
	return false
end

test("outline: single row is a box with equal padding", function()
	local cells = Layout.FlowRows({ 3 }, W, BTN, STEP, GAP)
	local edges = Layout.StripEdges(Boxes(Layout.Strips(cells[1], BTN), 50, 5))
	eq(#edges, 4)
	local right = 2 * STEP + BTN + 5
	assert(OnEdge(edges, -5, -5) and OnEdge(edges, right, -5), "top corners")
	assert(OnEdge(edges, -5, BTN + 5) and OnEdge(edges, right, BTN + 5), "bottom corners")
	assert(OnEdge(edges, -5, 10), "left side")
	assert(OnEdge(edges, right, 10), "right side")
end)

test("outline: every row piece has a line at its start and end", function()
	-- strict grid (no gap between sections), 10 columns of 47px, rows 60px apart
	for start = 0, 9 do
		for size = 1, 25 do
			local cells = Layout.FlowRows({ start, size }, 460, 37, 47, 0)
			local boxes = Boxes(Layout.Strips(cells[2], 37), 60, 3)
			local edges = Layout.StripEdges(boxes)
			for i, box in ipairs(boxes) do
				local mid = (box.t + box.b) / 2
				assert(OnEdge(edges, box.l, mid), ("start %d size %d row %d: left end"):format(start, size, i))
				assert(OnEdge(edges, box.r, mid), ("start %d size %d row %d: right end"):format(start, size, i))
				-- top line wherever the row above doesn't continue the section
				local above = boxes[i - 1]
				local x = box.l + 1
				if not (above and above.l <= x and x <= above.r) then
					assert(OnEdge(edges, x, box.t), ("start %d size %d row %d: top"):format(start, size, i))
				end
			end
			for _, e in ipairs(edges) do
				assert(e.x1 == e.x2 or e.y1 == e.y2, "straight lines only")
			end
		end
	end
end)

test("outline: wrapped section is joined across the gap between rows", function()
	-- starts at column 6 of row 0, fills row 1: the right end crosses the row gap
	local cells = Layout.FlowRows({ 6, 14 }, 460, 37, 47, 0)
	local boxes = Boxes(Layout.Strips(cells[2], 37), 60, 3)
	local edges = Layout.StripEdges(boxes)
	local gapY = (boxes[1].b + boxes[2].t) / 2
	assert(OnEdge(edges, boxes[1].r, gapY), "right side continues between rows")
	assert(OnEdge(edges, boxes[1].l, gapY), "row 0's start line reaches down to row 1")
	-- no line between the rows where the section continues
	assert(not OnEdge(edges, boxes[1].l + 20, boxes[2].t), "no top line under the section's own row")
end)

test("outline: name goes on the longest stretch of top edge", function()
	-- one cell at the end of row 0, then a full row: the name goes on row 1
	local cells = Layout.FlowRows({ 8, 12 }, W, BTN, STEP, GAP)
	local strips = Layout.Strips(cells[2], BTN)
	local edges = Layout.TopEdges(Boxes(strips, 50, 5))
	eq(#edges, 1)
	eq(strips[edges[1].index].row, 1)
	-- fits in one row: the name goes on it
	cells = Layout.FlowRows({ 2, 3 }, W, BTN, STEP, GAP)
	edges = Layout.TopEdges(Boxes(Layout.Strips(cells[2], BTN), 50, 5))
	eq(edges[1].index, 1)
	eq(edges[1].l, 2 * STEP + GAP - 5)
	-- two separate parts: each gets a name
	cells = Layout.FlowRows({ 7, 6 }, W, BTN, STEP, GAP)
	edges = Layout.TopEdges(Boxes(Layout.Strips(cells[2], BTN), 50, 5))
	eq(#edges, 2)
end)

local QUEST = { itemID = 500, guid = "Item-1-0-Q", maxStack = 1, isQuest = true }

test("quest section: off by default, quest items go to Rest", function()
	local db = Rules.NewCharDB()
	eq(db.autoQuest, false)
	eq(Rules.Classify(db, QUEST), Rules.REST)
end)

test("quest section: turning on creates it and catches quest items", function()
	local db = Rules.NewCharDB()
	local section = Rules.SetAutoQuest(db, true, "Quest Items")
	eq(section.name, "Quest Items")
	eq(section.auto, Rules.AUTO_QUEST)
	eq(Rules.Classify(db, QUEST), section.id)
	eq(Rules.Classify(db, POTION), Rules.REST)
	eq(Rules.SetAutoQuest(db, true, "Quest Items").id, section.id, "no duplicate section")
	eq(#db.sections, 1)
end)

test("quest section: explicit rules beat it, and dragging to Rest keeps item out", function()
	local db = Rules.NewCharDB()
	local quest = Rules.SetAutoQuest(db, true, "Quest Items")
	local other = Rules.CreateSection(db, "Other")
	Rules.Assign(db, QUEST, other.id, Rules.KIND_ITEMID)
	eq(Rules.Classify(db, QUEST), other.id)
	Rules.Unassign(db, QUEST)
	eq(Rules.Classify(db, QUEST), Rules.REST, "stays in Rest after being dragged out")
	eq(Rules.MatchedKind(db, QUEST), nil)
	Rules.Assign(db, QUEST, quest.id, Rules.KIND_ITEMID)
	eq(Rules.Classify(db, QUEST), quest.id, "can be put back")
end)

test("quest section: turning off deletes it unless items were added by hand", function()
	local db = Rules.NewCharDB()
	Rules.SetAutoQuest(db, true, "Quest Items")
	Rules.SetAutoQuest(db, false)
	eq(#db.sections, 0)
	eq(db.autoQuest, false)

	local section = Rules.SetAutoQuest(db, true, "Quest Items")
	Rules.Assign(db, POTION, section.id, Rules.KIND_ITEMID)
	Rules.SetAutoQuest(db, false)
	eq(#db.sections, 1, "kept because it has a hand-added item")
	eq(section.auto, nil)
	eq(Rules.Classify(db, QUEST), Rules.REST)
end)

test("quest section: deleting it turns the option off", function()
	local db = Rules.NewCharDB()
	local section = Rules.SetAutoQuest(db, true, "Quest Items")
	Rules.DeleteSection(db, section.id)
	eq(db.autoQuest, false)
end)

test("profiles: export keeps names, order, colours and placement only", function()
	local db = Rules.NewCharDB()
	local a = Rules.CreateSection(db, "Essentials")
	local b = Rules.CreateSection(db, "Gear")
	Rules.SetSectionBelow(db, b.id, true)
	Rules.Assign(db, POTION, a.id, Rules.KIND_ITEMID)
	local profile = Rules.ExportProfile(db)
	eq(#profile.sections, 2)
	eq(profile.sections[1].name, "Essentials")
	eq(profile.sections[2].below, true)
	eq(profile.sections[1].id, nil, "no ids")
	eq(profile.rules, nil, "no item rules")
	a.color.r = 0
	eq(profile.sections[1].color.r, Rules.PALETTE[1].r, "colour copied, not shared")
end)

test("profiles: loading keeps items in same-named sections and removes others", function()
	local source = Rules.NewCharDB()
	Rules.CreateSection(source, "Gear")
	Rules.CreateSection(source, "Essentials")
	Rules.SetAutoQuest(source, true, "Quest Items")
	local profile = Rules.ExportProfile(source)

	local db = Rules.NewCharDB()
	local ess = Rules.CreateSection(db, "essentials")
	local junk = Rules.CreateSection(db, "Junk")
	Rules.Assign(db, HEARTHSTONE, ess.id, Rules.KIND_ITEMID)
	Rules.Assign(db, POTION, junk.id, Rules.KIND_ITEMID)

	eq(Rules.CountRemovedByProfile(db, profile), 1)
	eq(Rules.ApplyProfile(db, profile), 1)
	eq(#db.sections, 3)
	eq(db.sections[1].name, "Gear")
	eq(db.sections[2].id, ess.id, "matching section kept")
	eq(db.sections[2].name, "Essentials", "name taken from profile")
	eq(Rules.Classify(db, HEARTHSTONE), ess.id, "its items kept")
	eq(Rules.Classify(db, POTION), Rules.REST, "removed section's items go to Rest")
	eq(db.autoQuest, true, "quest section restored")
	eq(Rules.Classify(db, QUEST), db.sections[3].id)
	local ids = {}
	for _, section in ipairs(db.sections) do
		assert(not ids[section.id], "duplicate id " .. section.id)
		ids[section.id] = true
	end
end)

local function RowsString(rows, db)
	local names = { rest = "Rest" }
	for _, section in ipairs(db.sections) do names[section.id] = section.name end
	local parts = {}
	for _, row in ipairs(rows) do
		local keys = {}
		for _, key in ipairs(row) do table.insert(keys, names[key] or key) end
		table.insert(parts, table.concat(keys, ","))
	end
	return table.concat(parts, " | ")
end

local function SectionsDB(names, belowFrom)
	local db = Rules.NewCharDB()
	for i, name in ipairs(names) do
		Rules.CreateSection(db, name, belowFrom and i >= belowFrom)
	end
	return db
end

local function Id(db, name)
	for _, section in ipairs(db.sections) do
		if section.name == name then return section.id end
	end
end

test("rows: automatic arrangement uses sections per row around Rest", function()
	local db = SectionsDB({ "A", "B", "C", "D", "E" }, 5)
	eq(RowsString(Rows.Get(db, 3), db), "A,B,C | D | Rest | E")
	eq(db.rows, nil, "nothing saved until something is moved")
end)

test("rows: move a section into another row, at a position", function()
	local db = SectionsDB({ "A", "B", "C", "D" })
	-- A,B,C | D | Rest  ->  move D into row 1 before B
	eq(Rows.Move(db, Id(db, "D"), { row = 1, before = Id(db, "B") }, 3, 8), true)
	eq(RowsString(db.rows, db), "A,D,B,C | Rest")
	eq(db.sections[2].name, "D", "section list follows the rows")
end)

test("rows: start a new row anywhere, and build Rest-on-top, 2, 3, 1", function()
	local db = SectionsDB({ "A", "B", "C", "D", "E", "F" })
	-- A,B,C | D,E,F | Rest. Move Rest to the top.
	Rows.Move(db, "rest", { newRow = 1 }, 3, 8)
	eq(RowsString(db.rows, db), "Rest | A,B,C | D,E,F")
	-- Move C down into D's row: A,B | C,D,E,F would exceed nothing (cap 8).
	Rows.Move(db, Id(db, "C"), { row = 3, before = Id(db, "D") }, 3, 8)
	eq(RowsString(db.rows, db), "Rest | A,B | C,D,E,F")
	-- F to its own row at the end.
	Rows.Move(db, Id(db, "F"), { newRow = 4 }, 3, 8)
	eq(RowsString(db.rows, db), "Rest | A,B | C,D,E | F")
	for _, section in ipairs(db.sections) do
		eq(section.below, true, section.name .. " is below Rest")
	end
end)

test("rows: a full row refuses more sections", function()
	local db = SectionsDB({ "A", "B", "C", "D" })
	Rows.Move(db, Id(db, "D"), { row = 1 }, 3, 3)
	eq(RowsString(db.rows, db), "A,B,C | D | Rest", "row 1 already has 3 of max 3")
	-- moving within the full row is still fine
	eq(Rows.Move(db, Id(db, "C"), { row = 1, before = Id(db, "A") }, 3, 3), true)
	eq(RowsString(db.rows, db), "C,A,B | D | Rest")
end)

test("rows: moving the only section of a row removes the empty row", function()
	local db = SectionsDB({ "A", "B", "C", "D" })
	Rows.Move(db, Id(db, "D"), { row = 1, before = Id(db, "A") }, 3, 8)
	eq(RowsString(db.rows, db), "D,A,B,C | Rest")
	eq(Rows.Move(db, Id(db, "A"), { row = 1, before = Id(db, "A") }, 3, 8), false, "dropping on itself does nothing")
end)

test("rows: new and deleted sections stay in step", function()
	local db = SectionsDB({ "A", "B" })
	Rows.Move(db, "rest", { newRow = 1 }, 3, 8) -- Rest | A,B
	Rules.CreateSection(db, "Above", false)
	Rules.CreateSection(db, "Below", true)
	Rules.DeleteSection(db, Id(db, "A"))
	eq(RowsString(Rows.Get(db, 3), db), "Above | Rest | B | Below")
end)

test("rows: saved in profiles by name", function()
	local source = SectionsDB({ "Gear", "Food", "Quest" })
	Rows.Move(source, "rest", { newRow = 1 }, 3, 8)
	Rows.Move(source, Id(source, "Quest"), { newRow = 3 }, 3, 8)
	eq(RowsString(source.rows, source), "Rest | Gear,Food | Quest")
	local profile = Rules.ExportProfile(source)

	local db = SectionsDB({ "Food" })
	Rules.ApplyProfile(db, profile)
	eq(RowsString(db.rows, db), "Rest | Gear,Food | Quest")

	local auto = Rules.ExportProfile(SectionsDB({ "X" }))
	eq(auto.rows, nil, "automatic rows aren't saved")
	Rules.ApplyProfile(db, auto)
	eq(db.rows, nil, "loading a profile without rows goes back to automatic")
end)

local Share = ns.Share

local function SampleProfile()
	local db = SectionsDB({ "Essentials", "Gear | Swap", "Ünïcødé ✓ 100%" })
	Rules.SetAutoQuest(db, true, "Quest Items")
	Rules.SetSectionColor(db, Id(db, "Essentials"), 0.25, 0.5, 1)
	Rows.Move(db, "rest", { newRow = 1 }, 3, 8)
	return Rules.ExportProfile(db)
end

test("share: code round-trips a profile, rows and odd names included", function()
	local profile = SampleProfile()
	local code = Share.Encode("Raid setup", profile)
	assert(not code:find("|", 1, true), "no pipe characters (WoW edit boxes treat | specially)")
	assert(not code:find("%s"), "no spaces or line breaks")
	local name, decoded = Share.Decode(code)
	eq(name, "Raid setup")
	eq(#decoded.sections, 4)
	eq(decoded.sections[2].name, "Gear | Swap")
	eq(decoded.sections[3].name, "Ünïcødé ✓ 100%")
	eq(decoded.sections[1].color.b, 1)
	eq(decoded.sections[4].auto, "quest")
	eq(decoded.rows[1][1].rest, true)
	-- loads like a saved profile
	local db = Rules.NewCharDB()
	Rules.ApplyProfile(db, decoded)
	eq(#db.sections, 4)
	eq(db.autoQuest, true)
	eq(db.rows[1][1], "rest")
end)

test("share: same profile gives the same code; whitespace from pasting is ignored", function()
	local profile = SampleProfile()
	local code = Share.Encode("X", profile)
	eq(Share.Encode("X", profile), code)
	local spaced = code:sub(1, 20) .. "\n  " .. code:sub(21)
	eq((Share.Decode(spaced)), "X")
end)

test("share: rejects other text, cut-off and edited codes", function()
	local code = Share.Encode("X", SampleProfile())
	local _, err = Share.Decode("hello")
	eq(err, "format")
	_, err = Share.Decode(code:sub(1, #code - 10))
	assert(err == "format" or err == "damaged", "cut-off code rejected")
	local tampered = code:gsub("Essentials", "Essentialz")
	_, err = Share.Decode(tampered)
	eq(err, "damaged", "edited code fails its checksum")
	eq(Share.Decode(nil), nil)
end)

test("share: a well-formed code with the wrong shape is rejected", function()
	-- Valid encoding and checksum, but sections isn't a list of named tables.
	local bad = Share.Encode("X", { sections = { { name = "" } } })
	local name = Share.Decode(bad)
	eq(name, nil)
	bad = Share.Encode("X", { sections = { { name = "A", color = { r = 5, g = 0, b = 0 } } } })
	eq((Share.Decode(bad)), nil, "colour out of range")
	bad = Share.Encode("X", { sections = { { name = "A", auto = "evil" } } })
	eq((Share.Decode(bad)), nil, "unknown automatic section")
end)

test("share: unknown extra fields are dropped", function()
	local code = Share.Encode("X", { sections = { { name = "A", junk = "x", below = true } }, extra = 1 })
	local _, profile = Share.Decode(code)
	eq(profile.extra, nil)
	eq(profile.sections[1].junk, nil)
	eq(profile.sections[1].below, true)
end)

test("footer currencies: fit next to the gold", function()
	local footer = Layout.FooterCurrencies({ 40, 30 }, 100, 300, 10)
	eq(footer.extraLines, 0)
	eq(footer.places[1].line, 0)
	eq(footer.places[1].right, 0, "first currency right next to the gold")
	eq(footer.places[2].right, 50, "second one left of the first")
end)

test("footer currencies: too wide for the gold's line get their own line", function()
	local footer = Layout.FooterCurrencies({ 40, 30, 50 }, 100, 300, 10)
	eq(footer.extraLines, 1)
	eq(footer.places[1].line, 1)
	eq(footer.places[1].right, 0, "starts at the right edge")
	eq(footer.places[3].right, 90)
end)

test("footer currencies: wrap onto more lines instead of overflowing", function()
	local footer = Layout.FooterCurrencies({ 60, 60, 60, 60 }, 50, 150, 10)
	eq(footer.extraLines, 2)
	eq(footer.places[2].line, 1)
	eq(footer.places[3].line, 2, "third doesn't fit on the first line")
	eq(footer.places[3].right, 0)
	eq(footer.places[4].line, 2)
end)

test("footer currencies: none tracked", function()
	local footer = Layout.FooterCurrencies({}, -20, 100, 10)
	eq(footer.extraLines, 0)
	eq(#footer.places, 0)
end)

test("bank: a snapshot becomes slots with the saved items", function()
	local Bank = ns.Bank
	local snapshot = { updated = 1, tabs = {
		{ bag = 6, size = 3, items = { [2] = { id = 700, count = 1, icon = 9, link = "robe" } } },
		{ size = 1, items = {} }, -- saved before snapshots kept the bag
	} }
	local slots = Bank.SnapshotSlots(snapshot)
	eq(#slots, 4)
	eq(slots[2].bag, 6)
	eq(slots[2].item.itemID, 700, "item rules still apply to saved items")
	eq(slots[2].cached.link, "robe")
	eq(slots[1].item, nil, "empty slots stay empty")
	eq(slots[1].cached, false)
	eq(slots[4].bag, 1002, "old snapshots get a stand-in bag number")
	local free, total = Layout.CountFree(slots)
	eq(free, 3)
	eq(total, 4)
	eq(#Bank.SnapshotSlots(nil), 0, "never visited")
end)

test("bank: snapshot age reads naturally", function()
	local L = { AGE_NOW = "now", AGE_MINUTES = "%d min", AGE_HOURS = "%d h", AGE_DAYS = "%d d" }
	local Bank = ns.Bank
	eq(Bank.FormatAge(30, L), "now")
	eq(Bank.FormatAge(5 * 60 + 10, L), "5 min")
	eq(Bank.FormatAge(3 * 3600 + 5, L), "3 h")
	eq(Bank.FormatAge(2 * 86400 + 5, L), "2 d")
end)

test("layout: bag reagents join the reagent bag's group only when turned on", function()
	local db = Rules.NewCharDB()
	local CLOTH = { itemID = 500, guid = "Item-1-0-CLOTH", maxStack = 200, isReagent = true }
	local slots = Slots({ { item = CLOTH }, { item = POTION }, {}, { area = "reagent", bag = 5 }, { area = "reagent", bag = 5, item = { itemID = 400, isReagent = true } } })
	local groups = Layout.Build(db, slots, {})
	eq(groups[1].kind, "rest")
	eq(#groups[1].slots, 3, "off: the cloth stays in Rest")
	groups = Layout.Build(db, slots, { bagReagents = true })
	eq(#groups, 2, "one Reagents group, no separate one")
	eq(groups[2].kind, "reagent")
	eq(groups[2].gathers, true)
	eq(groups[2].slots[1].item.itemID, 400, "the reagent bag's items first")
	eq(groups[2].slots[2].item, CLOTH, "then the bag reagents")
	eq(groups[2].slots[3].area, "reagent", "then the reagent bag's empty slots")
	eq(groups[2].slots[3].item, nil)
	eq(groups[2].count, 2)
	eq(#groups[1].slots, 2, "Rest keeps the potion and the empty slot")
	Rules.KeepInRest(db, CLOTH)
	eq(Layout.GroupKey(db, CLOTH, { bagReagents = true }), Rules.REST, "kept in Rest")
	-- Without a reagent bag the bag reagents make a group of their own.
	local noBag = Slots({ { item = CLOTH }, { item = POTION }, {} })
	eq(#Layout.Build(db, noBag, { bagReagents = true }), 1, "empty bag reagent group hidden")
	eq(#Layout.Build(db, noBag, { bagReagents = true, showEmpty = true }), 2, "shown empty while dragging")
	Rules.Unassign(db, CLOTH)
	eq(Layout.Build(db, noBag, { bagReagents = true })[2].kind, "bagreagent")
	eq(Layout.GroupKey(db, CLOTH, { bagReagents = true }), "bagreagent", "back once the Rest rule is gone")
	local section = Rules.CreateSection(db, "Cloth")
	Rules.Assign(db, CLOTH, section.id, Rules.KIND_ITEMID)
	eq(Layout.GroupKey(db, CLOTH, { bagReagents = true }), section.id, "sections win")
end)

test("sections: copy to another list (bags to bank)", function()
	local bags, bank = Rules.NewCharDB(), Rules.NewCharDB()
	local a = Rules.CreateSection(bags, "Gear")
	a.color = { r = 1, g = 0, b = 0 }
	Rules.CreateSection(bags, "Herbs", true)
	Rules.SetAutoQuest(bags, true, "Quest Items")
	Rules.CreateSection(bank, "herbs")
	local missing = Rules.MissingSections(bags, bank)
	eq(#missing, 1, "automatic sections and names already there are skipped")
	eq(missing[1].name, "Gear")
	local created = Rules.CopySections(bags, bank)
	eq(#created, 1)
	eq(bank.sections[2].name, "Gear")
	eq(bank.sections[2].color.r, 1)
	bank.sections[2].color.r = 0
	eq(a.color.r, 1, "colours are copied, not shared")
	eq(#bags.sections, 3, "the source is unchanged")
	eq(#Rules.CopySections(bags, bank), 0, "copying again adds nothing")
end)

test("rules: automatic Reagents section", function()
	local db = Rules.NewCharDB()
	local CLOTH = { itemID = 500, isReagent = true }
	eq(Rules.Classify(db, CLOTH), Rules.REST)
	local section = Rules.SetAuto(db, Rules.AUTO_REAGENT, true, "Reagents")
	eq(db.autoReagent, true)
	eq(Rules.Classify(db, CLOTH), section.id)
	eq(Rules.Classify(db, POTION), Rules.REST, "non-reagents stay out")
	Rules.Unassign(db, CLOTH)
	eq(Rules.Classify(db, CLOTH), Rules.REST, "taken out stays out")
	Rules.SetAuto(db, Rules.AUTO_REAGENT, false)
	eq(db.autoReagent, false)
	eq(Rules.GetSection(db, section.id), nil, "unused section removed when turned off")
	local quest = Rules.SetAutoQuest(db, true, "Quest Items")
	eq(Rules.Classify(db, { itemID = 1, isQuest = true }), quest.id, "quest section still works")
end)

test("linked sections: linking merges items assigned before", function()
	local bags, bank = Rules.NewCharDB(), Rules.NewCharDB()
	local gear = Rules.CreateSection(bags, "Gear")
	Rules.Assign(bags, SWORD_A, gear.id, Rules.KIND_GUID)
	Rules.Assign(bags, POTION, gear.id, Rules.KIND_ITEMID)
	local bankGear = Rules.CreateSection(bank, "gear")
	Rules.Assign(bank, PICK, bankGear.id, Rules.KIND_ITEMID)
	Rules.LinkByName(bags, bank)
	eq(gear.link, bankGear.link)
	eq(Rules.Classify(bank, SWORD_A), bankGear.id, "the bags' items carry over to the bank")
	eq(Rules.Classify(bank, POTION), bankGear.id)
	eq(Rules.Classify(bags, PICK), gear.id, "and the bank's to the bags")
	eq(Rules.Classify(bank, SWORD_B), Rules.REST, "exact-item rules stay exact")
end)

test("linked sections: own rules win when linking", function()
	local bags, bank = Rules.NewCharDB(), Rules.NewCharDB()
	local a = Rules.CreateSection(bags, "A")
	local bankA = Rules.CreateSection(bank, "A")
	local bankB = Rules.CreateSection(bank, "B")
	Rules.Assign(bags, POTION, a.id, Rules.KIND_ITEMID)
	Rules.Assign(bank, POTION, bankB.id, Rules.KIND_ITEMID)
	Rules.Link(bags, a, bank, bankA)
	eq(Rules.Classify(bank, POTION), bankB.id, "the bank's own choice is kept")
end)

test("linked sections: assign and remove keep both sides in step", function()
	local bags, bank = Rules.NewCharDB(), Rules.NewCharDB()
	local herbs = Rules.CreateSection(bags, "Herbs")
	local copies = Rules.CopySections(bags, bank)
	eq(#copies, 1)
	eq(copies[1].link, herbs.link, "copies are linked")
	Rules.AssignLinked(bags, bank, POTION, herbs.id, Rules.KIND_ITEMID)
	eq(Rules.Classify(bank, POTION), copies[1].id)
	Rules.UnassignLinked(bank, bags, POTION)
	eq(Rules.Classify(bags, POTION), Rules.REST)
	eq(Rules.Classify(bank, POTION), Rules.REST)
	-- Moved to an unlinked section on one side: the other side keeps its own.
	Rules.AssignLinked(bags, bank, POTION, herbs.id, Rules.KIND_ITEMID)
	local other = Rules.CreateSection(bags, "Other")
	Rules.AssignLinked(bags, bank, POTION, other.id, Rules.KIND_ITEMID)
	eq(Rules.Classify(bags, POTION), other.id)
	eq(Rules.Classify(bank, POTION), copies[1].id)
	-- Deleting one side leaves the other, and copying again re-links it.
	Rules.DeleteSection(bank, copies[1].id)
	eq(#Rules.MissingSections(bags, bank), 2)
	local again = Rules.CopySections(bags, bank, { herbs })
	eq(again[1].link, herbs.link)
end)

test("linked sections: link ids are unique on both sides", function()
	local bags, bank = Rules.NewCharDB(), Rules.NewCharDB()
	Rules.CreateSection(bags, "A")
	Rules.CreateSection(bags, "B")
	local copies = Rules.CopySections(bags, bank)
	assert(copies[1].link ~= copies[2].link, "different links")
	local c = Rules.CreateSection(bank, "C")
	local back = Rules.CopySections(bank, bags, { c })
	assert(back[1].link ~= copies[1].link and back[1].link ~= copies[2].link, "a link made from the bank side is new too")
end)

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
