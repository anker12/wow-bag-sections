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

-- Packs blocks into a fixed width, left to right and top to bottom (bottom-left packing),
-- so small blocks sit next to each other. Used by the compact layout.
-- blocks: array of { width, height } in pixels. Returns positions { x, y } and total height.
function Layout.Pack(blocks, totalWidth, gap)
	local placed, positions = {}, {}
	local totalHeight = 0
	for i, block in ipairs(blocks) do
		local width = math.min(block.width, totalWidth)
		local candidates = { 0 }
		for _, p in ipairs(placed) do
			table.insert(candidates, p.x + p.width + gap)
		end
		local bestX, bestY
		for _, x in ipairs(candidates) do
			if x + width <= totalWidth then
				local y = 0
				for _, p in ipairs(placed) do
					if x < p.x + p.width + gap and p.x < x + width + gap then
						y = math.max(y, p.y + p.height + gap)
					end
				end
				if not bestY or y < bestY or (y == bestY and x < bestX) then
					bestX, bestY = x, y
				end
			end
		end
		table.insert(placed, { x = bestX, y = bestY, width = width, height = block.height })
		positions[i] = { x = bestX, y = bestY, width = width }
		totalHeight = math.max(totalHeight, bestY + block.height)
	end
	return positions, totalHeight
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
