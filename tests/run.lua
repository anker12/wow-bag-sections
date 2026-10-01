-- Unit tests for the game-independent modules (Rules, Layout).
-- Run from the repo root: lua tests/run.lua

local ns = {}
for _, file in ipairs({ "BagSections/Rules.lua", "BagSections/Layout.lua" }) do
	assert(loadfile(file))("BagSections", ns)
end
local Rules, Layout = ns.Rules, ns.Layout

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
	eq(SlotItems(groups[2]):sub(1, 27), "Item-1-0-POT,Item-1-0-SWA,e", "items before empty slots")
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

test("flow: runs follow each other with no gaps", function()
	local runs, total = Layout.Flow({ 3, 5, 0, 2 })
	eq(runs[1].start, 0); eq(runs[2].start, 3); eq(runs[3].start, 8); eq(runs[4].start, 8)
	eq(runs[3].length, 0)
	eq(total, 10)
end)

local function PolygonArea(points)
	local area = 0
	for i, a in ipairs(points) do
		local b = points[i % #points + 1]
		area = area + (a.x * b.y - b.x * a.y)
	end
	return area / 2
end

test("flow: run outlines cover exactly the run's cells, clockwise", function()
	local columns = 10
	for start = 0, 25 do
		for length = 1, 32 do
			local area = 0
			for _, polygon in ipairs(Layout.RunPolygons({ start = start, length = length }, columns)) do
				local a = PolygonArea(polygon)
				assert(a > 0, ("run %d+%d: polygon not clockwise (y down)"):format(start, length))
				area = area + a
				for i, p in ipairs(polygon) do
					local q = polygon[i % #polygon + 1]
					assert(p.x == q.x or p.y == q.y, "edges are horizontal or vertical")
					assert(not (p.x == q.x and p.y == q.y), "no repeated corners")
				end
			end
			eq(area, length, ("run %d+%d area"):format(start, length))
			local cells = 0
			for _, rect in ipairs(Layout.RunRects({ start = start, length = length }, columns)) do
				cells = cells + rect.cols * rect.rows
			end
			eq(cells, length, ("run %d+%d rects"):format(start, length))
		end
	end
end)

test("flow: wrapping run that doesn't overlap itself gives two shapes", function()
	-- starts at column 8 of row 0, ends at column 1 of row 1
	eq(#Layout.RunPolygons({ start = 8, length = 4 }, 10), 2)
	-- starts at column 8, ends at column 9 of row 1: one connected shape
	eq(#Layout.RunPolygons({ start = 8, length = 12 }, 10), 1)
end)

test("flow: name goes on the longest stretch of top edge", function()
	-- one slot at the end of row 2, then 7 on row 3: the name goes on row 3
	local seg = Layout.LabelSegment({ start = 29, length = 8 }, 10)
	eq(seg.row, 3); eq(seg.col, 0); eq(seg.cols, 7)
	-- starts at column 2 with lots of room on row 0
	seg = Layout.LabelSegment({ start = 2, length = 15 }, 10)
	eq(seg.row, 0); eq(seg.col, 2); eq(seg.cols, 8)
	-- fits in one row
	seg = Layout.LabelSegment({ start = 13, length = 3 }, 10)
	eq(seg.row, 1); eq(seg.col, 3); eq(seg.cols, 3)
end)

test("flow: inset moves outlines inwards", function()
	local square = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } }
	local inset = Layout.InsetPolygon(square, 1)
	eq(inset[1].x, 1); eq(inset[1].y, 1)
	eq(inset[3].x, 9); eq(inset[3].y, 9)
	-- concave corner of an L shape moves outward from the corner
	local l = Layout.RunPolygons({ start = 8, length = 12 }, 10)[1]
	local scaled = {}
	for i, p in ipairs(l) do scaled[i] = { x = p.x * 10, y = p.y * 10 } end
	local area = PolygonArea(Layout.InsetPolygon(scaled, 1))
	assert(area < PolygonArea(scaled), "inset shape is smaller")
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

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
