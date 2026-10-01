-- Sorting for "virtual" sections.
-- Sections only exist in this addon's window, and items in each section are drawn in
-- physical bag order. A normal Blizzard sort therefore leaves every section sorted.
-- A physical move engine can replace this later behind the same Sort() call.

local _, ns = ...
local L = ns.L

local Sorter = {}
ns.Sorter = Sorter

local pending = false
local pendingCallbacks = {}

function Sorter.Sort(onDone)
	if onDone then
		table.insert(pendingCallbacks, onDone)
	end
	if InCombatLockdown() then
		if not pending then
			ns.Print(L.SORT_QUEUED)
		end
		pending = true
		return
	end
	pending = false

	PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
	-- Items move over the next moments; let the compact layout follow them.
	ns.Frame.AllowReflow()
	C_Container.SortBags()

	local callbacks = pendingCallbacks
	pendingCallbacks = {}
	for _, callback in ipairs(callbacks) do
		callback()
	end
end

function Sorter.IsPending()
	return pending
end

function Sorter.OnCombatEnded()
	if pending then
		Sorter.Sort()
	end
end

function Sorter.ToggleDirection()
	local rightToLeft = not C_Container.GetSortBagsRightToLeft()
	C_Container.SetSortBagsRightToLeft(rightToLeft)
	ns.Print(L.SORT_DIRECTION:format(rightToLeft and L.SORT_RIGHT_TO_LEFT or L.SORT_LEFT_TO_RIGHT))
end
