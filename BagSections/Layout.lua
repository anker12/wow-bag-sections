-- Turns a scanned list of bag slots into display groups (sections, Rest, Reagents, Keyring).
-- Pure logic: no WoW API calls, so it can be unit tested outside the game.

local _, ns = ...

local Layout = {}
ns.Layout = Layout

-- slots: array in physical order of
--   { bag = n, slot = n, area = "bags" | "reagent" | "keyring", item = { itemID, guid, ... } | nil }
-- opts: { showEmpty = bool }
-- Returns an array of groups:
--   { key, kind = "section" | "rest" | "reagent" | "keyring", name, collapsed, slots = {...}, count }
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
			slots = {},
			count = 0,
		}
		sectionGroups[section.id] = group
		table.insert(groups, group)
	end

	local rest = { key = Rules.REST, kind = "rest", slots = {}, count = 0 }
	local restEmpty = {}
	local reagent = { key = "reagent", kind = "reagent", slots = {}, count = 0 }
	local keyring = { key = "keyring", kind = "keyring", slots = {}, count = 0 }

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
	for _, group in ipairs(groups) do
		if group.count > 0 or opts.showEmpty then
			table.insert(result, group)
		end
	end
	table.insert(result, rest)
	if #reagent.slots > 0 then
		table.insert(result, reagent)
	end
	if #keyring.slots > 0 then
		table.insert(result, keyring)
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
