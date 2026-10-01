local _, ns = ...

-- Missing keys fall back to the key itself, so English strings can be used directly.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L.ADDON_NAME = "BagSections"
L.BAGS = "Bags"
L.REST = "Rest"
L.REAGENTS = "Reagents"
L.KEYRING = "Keyring"
L.FREE_SLOTS = "%d free / %d"
L.SORT = "Sort bags"
L.SORT_DESC = "Sorts every section separately, using Blizzard's bag sorting."
L.SORT_REVERSE = "Right-click: toggle sort direction"
L.SORT_QUEUED = "Can't sort in combat. Sorting when combat ends."
L.SORT_DIRECTION = "Sort direction: %s"
L.SORT_LEFT_TO_RIGHT = "left to right"
L.SORT_RIGHT_TO_LEFT = "right to left"
L.MENU = "Options"
L.NEW_SECTION = "New section..."
L.NEW_SECTION_PROMPT = "Name of the new section:"
L.RENAME_SECTION = "Rename..."
L.RENAME_SECTION_PROMPT = "New name for \"%s\":"
L.DELETE_SECTION = "Delete"
L.DELETE_SECTION_CONFIRM = "Delete section \"%s\"? Its items go back to Rest."
L.CLEAR_SECTION = "Remove all items"
L.MOVE_UP = "Move up"
L.MOVE_DOWN = "Move down"
L.COLLAPSE = "Collapse"
L.EXPAND = "Expand"
L.SHOW_EMPTY = "Show empty sections"
L.SETTINGS = "Settings..."
L.ASSIGN_TO = "Add to section"
L.REMOVE_FROM_SECTION = "Remove from section"
L.MATCH = "Match"
L.MATCH_GUID = "This exact item"
L.MATCH_ITEMID = "Every item of this kind"
L.NO_SECTIONS = "No sections yet"
L.DROP_HERE = "Drop to add to %s"
L.DROP_REST = "Drop to remove from section"
L.TOOLTIP_SECTION = "Section: %s"
L.BAGS_FULL = "No free bag slot for that item."
L.NOT_ASSIGNABLE = "Items in the reagent bag or keyring can't be added to sections."
L.SECTION_NOT_FOUND = "No section named \"%s\"."
L.NO_ITEM_UNDER_MOUSE = "Hover over an item in your bags first."
L.ADDED_TO = "%s added to %s."

L.OPT_COLUMNS = "Columns"
L.OPT_COLUMNS_DESC = "Number of item slots per row."
L.OPT_SCALE = "Scale"
L.OPT_SCALE_DESC = "Size of the bag window."
L.OPT_SHOW_EMPTY_DESC = "Show sections that have no items in your bags. Empty sections are always shown while you drag an item."
L.OPT_GEAR_EXACT = "Gear: match the exact item"
L.OPT_GEAR_EXACT_DESC = "When you add gear to a section, only that exact piece goes there. Turn off to add every copy of it."
L.OPT_TAKEOVER = "Replace the default bags"
L.OPT_TAKEOVER_DESC = "Open this window instead of Blizzard's bags. Needs /reload to take effect."

L.HELP = {
	"/bs - open or close the bags",
	"/bs sort - sort the bags",
	"/bs new <name> - create a section",
	"/bs add <section> - add the item under the mouse to a section",
	"/bs config - open settings",
}
