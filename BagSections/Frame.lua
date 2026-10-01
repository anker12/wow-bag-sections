-- The combined bag window: title bar, one block per section, Rest, Reagents, footer.

local _, ns = ...
local L = ns.L
local Rules = ns.Rules
local ItemButtons = ns.ItemButtons

local Frame = {}
ns.Frame = Frame

local PADDING = 10
local SPACING = 4
local HEADER_HEIGHT = 20
local GROUP_GAP = 6
local TITLE_HEIGHT = 30
local FOOTER_HEIGHT = 22
local BUTTON_SIZE = ItemButtons.SIZE
local CELL = BUTTON_SIZE + SPACING

-- Compact layout: every group runs through one shared grid, outlined in its colour.
-- Slots keep a strict grid (same columns on every row); the gap between all slots is wider
-- than in the default layout so outlines fit between neighbouring sections.
local COMPACT_GAP = 10 -- space between slots, in every direction
local COMPACT_CELL = BUTTON_SIZE + COMPACT_GAP
local OUTLINE_PADDING = 3 -- space between a section's items and its outline, on every side
local NAME_HEIGHT = 14 -- height of a section's name label on its outline
local LINE = 1 -- outline thickness
local LINE_ALPHA = 0.7
local REFLOW_AFTER_SORT = 3 -- seconds the compact layout keeps updating after a sort

-- Outline colours for the built-in groups in the compact layout.
local BUILTIN_COLORS = {
	rest = { r = 0.65, g = 0.65, b = 0.65 },
	reagent = { r = 0.40, g = 0.80, b = 0.45 },
	keyring = { r = 0.95, g = 0.80, b = 0.35 },
}

local main, content
local headers, overlays = {}, {}
local labels, placeholders, lineTextures = {}, {}, {}
local lineFrame, measure

-- Compact layout keeps its arrangement while the window is open, so items don't jump
-- around when things are looted or used up. It's rebuilt on open, on any change the
-- player makes (assigning, sorting, section changes) and when the bags themselves change.
local frozen
local reflowUntil = 0
local lastSlots = {}

-- Information about the item on the cursor, or nil. Used to show drop targets.
local cursorState

local function GroupTitle(group)
	local marker = group.collapsed and "+" or "-"
	if group.kind == "section" then
		return ("%s %s |cff999999(%d)|r"):format(marker, group.name, group.count)
	elseif group.kind == "rest" then
		return ("%s %s |cff999999(%d)|r"):format(marker, L.REST, #group.slots)
	elseif group.kind == "reagent" then
		return ("%s %s"):format(marker, L.REAGENTS)
	end
	return ("%s %s"):format(marker, L.KEYRING)
end

-- Shorter title for the compact layout's name labels: no collapse marker.
local function CompactTitle(group)
	if group.kind == "section" then
		return ("%s |cff999999(%d)|r"):format(group.name, group.count)
	elseif group.kind == "rest" then
		return ("%s |cff999999(%d)|r"):format(L.REST, #group.slots)
	end
	return group.kind == "reagent" and L.REAGENTS or L.KEYRING
end

local function GroupColor(group)
	return group.color or BUILTIN_COLORS[group.key] or BUILTIN_COLORS.rest
end

local function ReadCursor()
	local location = C_Cursor.GetCursorItem()
	if not (location and location:IsValid()) then
		return nil
	end
	local item = ns.Inventory.GetItemFromLocation(location)
	if not item then
		return nil
	end
	local state = { location = location, item = item, source = "external" }
	if location:IsBagAndSlot() then
		local bag, slot = location:GetBagAndSlot()
		state.bag, state.slot = bag, slot
		if ns.Inventory.IsSectionBag(bag) then
			state.source = "bags"
			state.section = Rules.Classify(ns.charDB, item)
		elseif bag == Enum.BagIndex.ReagentBag or bag == Enum.BagIndex.Keyring then
			state.source = "locked"
		end
	end
	return state
end

local function IsDropTarget(group)
	if not cursorState or cursorState.source == "locked" then
		return false
	end
	if group.kind == "section" then
		return cursorState.section ~= group.key
	elseif group.kind == "rest" then
		return cursorState.source == "bags" and cursorState.section ~= Rules.REST
	end
	return false
end

-- Assigns the cursor item to the group it was dropped on.
local function HandleDrop(group)
	local state = ReadCursor()
	if not state then
		return
	end
	local db = ns.charDB

	if state.source == "locked" then
		UIErrorsFrame:AddMessage(L.NOT_ASSIGNABLE, RED_FONT_COLOR:GetRGBA())
		ClearCursor()
		return
	end

	if group.kind == "rest" then
		Rules.Unassign(db, state.item)
		ClearCursor()
	elseif group.kind == "section" then
		local kind = Rules.MatchedKind(db, state.item) or Rules.DefaultKind(state.item, ns.db)
		if state.source == "external" then
			-- From the character sheet, bank etc.: put it into a free bag slot first.
			local bag, slot = ns.Inventory.FindFreeSlotFor(state.item.itemID)
			if not bag then
				UIErrorsFrame:AddMessage(L.BAGS_FULL, RED_FONT_COLOR:GetRGBA())
				return
			end
			C_Container.PickupContainerItem(bag, slot)
		else
			ClearCursor()
		end
		Rules.Assign(db, state.item, group.key, kind)
	end
	ns.RequestRefresh()
end

-- Click, drop and tooltip behaviour shared by default-layout headers and compact labels.
local function SetGroupScripts(button)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(self, mouseButton)
		local group = self.group
		if CursorHasItem() then
			HandleDrop(group)
			return
		end
		if group.kind ~= "section" then
			if mouseButton == "LeftButton" then
				Rules.ToggleBuiltinCollapsed(ns.charDB, group.key)
				ns.RequestRefresh()
			end
			return
		end
		if mouseButton == "RightButton" then
			ns.Menu.OpenSectionMenu(self, group)
		else
			local section = Rules.GetSection(ns.charDB, group.key)
			if section then
				section.collapsed = not section.collapsed
				ns.RequestRefresh()
			end
		end
	end)
	button:SetScript("OnReceiveDrag", function(self) HandleDrop(self.group) end)
	button:SetScript("OnEnter", function(self)
		if CursorHasItem() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if self.showTitleInTooltip then
			GameTooltip_SetTitle(GameTooltip, GroupTitle(self.group))
		end
		GameTooltip_AddNormalLine(GameTooltip, self.group.collapsed and L.HEADER_EXPAND or L.HEADER_COLLAPSE)
		if self.group.kind == "section" then
			GameTooltip_AddNormalLine(GameTooltip, L.HEADER_MENU)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateHeader(index)
	local header = CreateFrame("Button", nil, content)
	header:SetHeight(HEADER_HEIGHT)
	header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.Text:SetPoint("LEFT", 2, 0)
	header.Text:SetJustifyH("LEFT")
	header.Line = header:CreateTexture(nil, "ARTWORK")
	header.Line:SetColorTexture(1, 1, 1, 0.15)
	header.Line:SetHeight(1)
	header.Line:SetPoint("LEFT", header.Text, "RIGHT", 6, 0)
	header.Line:SetPoint("RIGHT")
	header:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	header:GetHighlightTexture():SetAlpha(0.25)

	SetGroupScripts(header)
	headers[index] = header
	return header
end

local function CreateOverlay(index)
	local overlay = CreateFrame("Button", nil, content)
	overlay:RegisterForClicks("LeftButtonUp")
	overlay.Background = overlay:CreateTexture(nil, "BACKGROUND")
	overlay.Background:SetAllPoints()
	overlay.Background:SetColorTexture(0.2, 0.6, 1, 0.18)
	overlay.Border = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
	overlay.Border:SetAllPoints()
	overlay.Border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	overlay.Border:SetBackdropBorderColor(0.3, 0.7, 1, 0.8)
	overlay.Text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	overlay.Text:SetPoint("CENTER")
	overlay:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
	overlay:GetHighlightTexture():SetVertexColor(0.3, 0.7, 1, 0.2)
	overlay:SetScript("OnClick", function(self) HandleDrop(self.group) end)
	overlay:SetScript("OnReceiveDrag", function(self) HandleDrop(self.group) end)
	overlays[index] = overlay
	return overlay
end

local function ShowOverlay(index, group, x, y, width, height, text)
	local overlay = overlays[index] or CreateOverlay(index)
	overlay.group = group
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	overlay:SetSize(width, height)
	overlay:SetFrameLevel(content:GetFrameLevel() + 30)
	if text == nil then
		text = group.kind == "rest" and L.DROP_REST or L.DROP_HERE:format(group.name)
	end
	overlay.Text:SetText(text)
	overlay:Show()
end

local function PlaceButton(group, slot, x, y, used)
	local button = ItemButtons.Get(slot.bag, slot.slot)
	button.bsSectionName = group.kind == "section" and group.name or nil
	used[button] = true
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	button:Show()
end

local function SetupHeader(index, group)
	local header = headers[index] or CreateHeader(index)
	header.group = group
	header:ClearAllPoints()
	header.Text:SetText(GroupTitle(group))
	header:Show()
	return header
end

-- Default layout: groups stacked top to bottom at full width.
local function RenderDefault(groups, columns, gridWidth, used)
	local y = 0
	for index, group in ipairs(groups) do
		local top = y
		local header = SetupHeader(index, group)
		header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		header:SetSize(gridWidth, HEADER_HEIGHT)
		y = y + HEADER_HEIGHT + 2

		if not group.collapsed then
			for i, slot in ipairs(group.slots) do
				local column = (i - 1) % columns
				local row = math.floor((i - 1) / columns)
				PlaceButton(group, slot, column * CELL, y + row * CELL, used)
			end
			local rows = math.ceil(#group.slots / columns)
			if rows == 0 and group.kind == "section" then
				-- Empty section: leave a row so it can still receive drops.
				rows = 1
			end
			y = y + rows * CELL
		end

		if IsDropTarget(group) then
			ShowOverlay(index, group, -3, top - 2, gridWidth + 6, y - top + 1)
		end

		y = y + GROUP_GAP
	end
	return y - GROUP_GAP
end

local function CreateLabel(index)
	local label = CreateFrame("Button", nil, content)
	label:SetHeight(14)
	label.Background = label:CreateTexture(nil, "BACKGROUND")
	label.Background:SetAllPoints()
	label.Background:SetColorTexture(0.05, 0.05, 0.07, 1)
	label.Text = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label.Text:SetPoint("LEFT", 4, 0)
	label.Text:SetJustifyH("LEFT")
	label.Text:SetWordWrap(false)
	label:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	label:GetHighlightTexture():SetAlpha(0.3)
	label.showTitleInTooltip = true
	SetGroupScripts(label)
	labels[index] = label
	return label
end

local function CreatePlaceholder(index)
	local placeholder = CreateFrame("Frame", nil, content)
	placeholder.Fill = placeholder:CreateTexture(nil, "BACKGROUND")
	placeholder.Fill:SetAllPoints()
	placeholder.Text = placeholder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	placeholder.Text:SetPoint("CENTER")
	placeholders[index] = placeholder
	return placeholder
end

local function GetLineTexture(index)
	local texture = lineTextures[index]
	if not texture then
		texture = lineFrame:CreateTexture(nil, "ARTWORK")
		lineTextures[index] = texture
	end
	return texture
end

-- Cells a collapsed or empty group takes up, so its name has room.
local function LabelCells(group, columns)
	measure:SetText(CompactTitle(group))
	local width = measure:GetStringWidth() or 0
	return math.max(2, math.min(columns, math.ceil((width + 16) / COMPACT_CELL)))
end

-- Compact layout: all groups run through one grid of `columns` columns, one after the
-- other with no gaps, each outlined in its colour with its name on its top edge.
local function RenderCompact(groups, columns, used)
	local Layout = ns.Layout
	local P = OUTLINE_PADDING
	local width = columns * COMPACT_CELL - COMPACT_GAP

	local sizes = {}
	for i, group in ipairs(groups) do
		group.placeholder = group.collapsed or #group.slots == 0
		sizes[i] = group.placeholder and LabelCells(group, columns) or #group.slots
	end
	-- No extra gap between sections: every row holds the same slots in the same columns.
	local cells, rows = Layout.FlowRows(sizes, width, BUTTON_SIZE, COMPACT_CELL, 0)

	local strips = {}
	for i in ipairs(groups) do
		strips[i] = Layout.Strips(cells[i], BUTTON_SIZE)
	end

	-- Name rows are known once rows exist; work out each group's top edge using
	-- provisional row positions (row gaps only shift whole rows, not x positions).
	local function Boxes(i, rowTop)
		local boxes = {}
		for _, strip in ipairs(strips[i]) do
			table.insert(boxes, {
				l = strip.left - P, r = strip.right + P,
				t = rowTop[strip.row] - P, b = rowTop[strip.row] + BUTTON_SIZE + P,
				row = strip.row,
			})
		end
		return boxes
	end
	local provisional = {}
	for r = 0, rows - 1 do
		provisional[r] = r * 100
	end
	-- One name per group, on the longest stretch of top edge. Wrapped parts are tied
	-- together by the outline colour, so they don't repeat the name.
	local nameRow, names = {}, {}
	for i in ipairs(groups) do
		local boxes = Boxes(i, provisional)
		local best
		for _, edge in ipairs(Layout.TopEdges(boxes)) do
			if not best or edge.r - edge.l > best.r - best.l then
				best = edge
			end
		end
		if best then
			local row = boxes[best.index].row
			nameRow[row] = true
			table.insert(names, { group = i, strip = best.index, row = row, left = best.l + 6 })
		end
	end

	-- Row positions: the same gap between all rows, a little more where a row carries names.
	local rowTop, y = {}, 0
	for r = 0, rows - 1 do
		local gap = r == 0 and (P + LINE) or COMPACT_GAP
		if nameRow[r] then
			-- The name is centred on the top outline; leave room above it, clear of the
			-- outline of whatever sits in the row above.
			local above = r == 0 and 1 or (P + LINE + 2)
			gap = math.max(gap, P + NAME_HEIGHT / 2 + above)
		end
		rowTop[r] = y + gap
		y = rowTop[r] + BUTTON_SIZE
	end
	local height = y + P + LINE

	-- Names may run past their own top edge, up to where the next name on that row starts.
	local function NameRoom(name)
		local right = width + P
		for _, other in ipairs(names) do
			if other ~= name and other.row == name.row and other.left > name.left then
				right = math.min(right, other.left - 6)
			end
		end
		return math.max(right - name.left - 8, 20)
	end

	local lineIndex, placeholderIndex, overlayIndex = 0, 0, 0
	for index, group in ipairs(groups) do
		local c = GroupColor(group)
		local boxes = Boxes(index, rowTop)

		if group.placeholder then
			for _, strip in ipairs(strips[index]) do
				placeholderIndex = placeholderIndex + 1
				local placeholder = placeholders[placeholderIndex] or CreatePlaceholder(placeholderIndex)
				placeholder:ClearAllPoints()
				placeholder:SetPoint("TOPLEFT", content, "TOPLEFT", strip.left, -rowTop[strip.row])
				placeholder:SetSize(strip.right - strip.left, BUTTON_SIZE)
				placeholder.Fill:SetColorTexture(c.r, c.g, c.b, 0.12)
				placeholder.Text:SetText(group.collapsed and group.count > 0 and ("+" .. group.count) or "")
				placeholder:Show()
			end
		else
			for i, slot in ipairs(group.slots) do
				local cell = cells[index][i]
				PlaceButton(group, slot, cell.x, rowTop[cell.row], used)
			end
		end

		for _, polygon in ipairs(Layout.StripPolygons(boxes)) do
			for i, a in ipairs(polygon) do
				local b = polygon[i % #polygon + 1]
				lineIndex = lineIndex + 1
				local texture = GetLineTexture(lineIndex)
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", content, "TOPLEFT", math.min(a.x, b.x) - LINE / 2, -(math.min(a.y, b.y) - LINE / 2))
				texture:SetSize(math.abs(b.x - a.x) + LINE, math.abs(b.y - a.y) + LINE)
				texture:SetColorTexture(c.r, c.g, c.b, LINE_ALPHA)
				texture:Show()
			end
		end

		for nameIndex, name in ipairs(names) do
			if name.group == index then
				local label = labels[nameIndex] or CreateLabel(nameIndex)
				label.group = group
				label.Text:SetText(CompactTitle(group))
				label.Text:SetTextColor(c.r, c.g, c.b)
				label.Text:SetWidth(0)
				local textWidth = math.min(label.Text:GetStringWidth() or 0, NameRoom(name))
				label.Text:SetWidth(textWidth)
				label:SetWidth(textWidth + 8)
				label:ClearAllPoints()
				label:SetPoint("LEFT", content, "TOPLEFT", name.left, -boxes[name.strip].t)
				label:SetFrameLevel(lineFrame:GetFrameLevel() + 2)
				label:Show()
			end
		end

		if IsDropTarget(group) then
			local biggest = 1
			for i, box in ipairs(boxes) do
				if box.r - box.l > boxes[biggest].r - boxes[biggest].l then
					biggest = i
				end
			end
			for i, box in ipairs(boxes) do
				overlayIndex = overlayIndex + 1
				ShowOverlay(overlayIndex, group, box.l, box.t, box.r - box.l, box.b - box.t, i ~= biggest and "" or nil)
			end
		end
	end
	return height, width
end

-- Compact layout: reuse the arrangement from when it was last built, as long as the same
-- bag slots exist. Item counts are refreshed so section titles stay correct.
local function SlotKey(slot)
	return slot.bag * 1000 + slot.slot
end

local function ReuseFrozen(slots)
	if not frozen or #slots ~= frozen.slotCount or (ns.db.columns or 10) ~= frozen.columns then
		return nil
	end
	local fresh = {}
	for _, slot in ipairs(slots) do
		local key = SlotKey(slot)
		if not frozen.keys[key] then
			return nil
		end
		fresh[key] = slot
	end
	for _, group in ipairs(frozen.groups) do
		local count = 0
		for i, slot in ipairs(group.slots) do
			local current = fresh[SlotKey(slot)]
			group.slots[i] = current
			if current.item then
				count = count + 1
			end
		end
		group.count = count
	end
	return frozen.groups
end

local function Freeze(groups, slots)
	local keys = {}
	for _, slot in ipairs(slots) do
		keys[SlotKey(slot)] = true
	end
	frozen = { groups = groups, keys = keys, slotCount = #slots, columns = ns.db.columns or 10 }
end

-- Lets the compact layout follow the bags for a few seconds, e.g. while a sort runs.
function Frame.AllowReflow(seconds)
	reflowUntil = GetTime() + (seconds or REFLOW_AFTER_SORT)
end

local function SavePosition()
	local point, _, relativePoint, x, y = main:GetPoint(1)
	ns.db.frame.point, ns.db.frame.relativePoint, ns.db.frame.x, ns.db.frame.y = point, relativePoint, x, y
end

local function RestorePosition()
	local pos = ns.db.frame
	main:ClearAllPoints()
	main:SetPoint(pos.point or "BOTTOMRIGHT", UIParent, pos.relativePoint or pos.point or "BOTTOMRIGHT", pos.x or -60, pos.y or 100)
end

local function CreateTitleBar()
	main.Title = main:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	main.Title:SetPoint("TOPLEFT", PADDING, -9)
	main.Title:SetText(L.BAGS)

	main.CloseButton = CreateFrame("Button", nil, main, "UIPanelCloseButton")
	main.CloseButton:SetPoint("TOPRIGHT", 1, 1)

	main.MenuButton = CreateFrame("Button", nil, main)
	main.MenuButton:SetSize(20, 20)
	main.MenuButton:SetPoint("RIGHT", main.CloseButton, "LEFT", -2, 0)
	main.MenuButton:SetNormalAtlas("GM-icon-settings")
	main.MenuButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	main.MenuButton:SetScript("OnClick", function(self) ns.Menu.OpenMainMenu(self) end)
	main.MenuButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L.MENU)
		GameTooltip:Show()
	end)
	main.MenuButton:SetScript("OnLeave", GameTooltip_Hide)

	main.SortButton = CreateFrame("Button", nil, main)
	main.SortButton:SetSize(24, 23)
	main.SortButton:SetPoint("RIGHT", main.MenuButton, "LEFT", -4, 0)
	main.SortButton:SetNormalAtlas("bags-button-autosort-up")
	main.SortButton:SetPushedAtlas("bags-button-autosort-down")
	main.SortButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	main.SortButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	main.SortButton:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			ns.Sorter.ToggleDirection()
		else
			ns.Sorter.Sort()
		end
	end)
	main.SortButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L.SORT)
		GameTooltip_AddNormalLine(GameTooltip, L.SORT_DESC)
		GameTooltip_AddInstructionLine(GameTooltip, L.SORT_REVERSE)
		GameTooltip:Show()
	end)
	main.SortButton:SetScript("OnLeave", GameTooltip_Hide)

	main.SearchBox = CreateFrame("EditBox", "BagSectionsSearchBox", main, "BagSearchBoxTemplate")
	main.SearchBox:SetHeight(20)
	main.SearchBox:SetPoint("LEFT", main.Title, "RIGHT", 14, 0)
	main.SearchBox:SetPoint("RIGHT", main.SortButton, "LEFT", -8, 0)
end

local function CreateFooter()
	main.Money = main:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	main.Money:SetPoint("BOTTOMRIGHT", -PADDING, 8)
	main.FreeSlots = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.FreeSlots:SetPoint("BOTTOMLEFT", PADDING, 8)
end

function Frame.Init()
	main = CreateFrame("Frame", "BagSectionsFrame", UIParent, "BackdropTemplate")
	main:Hide()
	main:SetFrameStrata("MEDIUM")
	main:SetToplevel(true)
	main:SetClampedToScreen(true)
	main:SetMovable(true)
	main:EnableMouse(true)
	main:RegisterForDrag("LeftButton")
	main:SetScript("OnDragStart", main.StartMoving)
	main:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	main:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	main:SetBackdropColor(0.05, 0.05, 0.07, 0.94)
	main:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	main:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		Frame.Render("layout")
	end)
	main:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		frozen = nil
		ns.Hooks.OnWindowHidden()
	end)
	tinsert(UISpecialFrames, main:GetName())

	content = CreateFrame("Frame", nil, main)
	content:SetPoint("TOPLEFT", PADDING, -TITLE_HEIGHT)
	ItemButtons.SetParent(content)

	-- Compact-layout outlines draw below the item buttons; names draw above them.
	lineFrame = CreateFrame("Frame", nil, content)
	lineFrame:SetAllPoints()
	lineFrame:SetFrameLevel(content:GetFrameLevel() + 1)
	measure = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	measure:Hide()

	CreateTitleBar()
	CreateFooter()
	RestorePosition()
	Frame.ApplyScale()
end

function Frame.ApplyScale()
	main:SetScale(ns.db.scale or 1)
end

function Frame.IsShown()
	return main and main:IsShown()
end

function Frame.Show()
	main:Show()
end

function Frame.Hide()
	main:Hide()
end

function Frame.Toggle()
	main:SetShown(not main:IsShown())
end

function Frame.UpdateMoney()
	if main then
		main.Money:SetText(GetMoneyString(GetMoney(), true))
	end
end

-- Redraw: rescan bags, then place everything.
-- mode "layout" always rebuilds the arrangement. Mode "items" (bag contents changed) does
-- too in the default layout, but the compact layout keeps its frozen arrangement.
function Frame.Render(mode)
	if not (main and main:IsShown()) then
		return
	end

	local compact = ns.db.layout == "compact"
	cursorState = ReadCursor()
	local slots = ns.Inventory.Scan()
	lastSlots = slots

	local groups
	if compact and mode == "items" and GetTime() >= reflowUntil then
		groups = ReuseFrozen(slots)
	end
	if not groups then
		groups = ns.Layout.Build(ns.charDB, slots, {
			-- Compact always shows empty sections, so dragging an item never moves anything.
			showEmpty = compact or ns.db.showEmptySections or (cursorState ~= nil and cursorState.source ~= "locked"),
		})
		frozen = nil
		if compact then
			Freeze(groups, slots)
		end
	end

	local columns = ns.db.columns or 10
	local gridWidth = columns * BUTTON_SIZE + (columns - 1) * SPACING
	content:SetWidth(gridWidth)

	local used = {}
	for _, header in ipairs(headers) do header:Hide() end
	for _, overlay in ipairs(overlays) do overlay:Hide() end
	for _, label in ipairs(labels) do label:Hide() end
	for _, placeholder in ipairs(placeholders) do placeholder:Hide() end
	for _, texture in ipairs(lineTextures) do texture:Hide() end

	local contentHeight
	if compact then
		contentHeight, gridWidth = RenderCompact(groups, columns, used)
		content:SetWidth(gridWidth)
	else
		contentHeight = RenderDefault(groups, columns, gridWidth, used)
	end

	ItemButtons.HideExcept(used)

	if #ns.charDB.sections == 0 and not cursorState and not compact then
		-- Hint next to Rest when no sections exist yet.
		headers[1].Text:SetText(GroupTitle(groups[1]) .. "   |cff777777" .. L.NO_SECTIONS .. " - " .. L.NEW_SECTION .. "|r")
	end

	content:SetHeight(math.max(contentHeight, 1))
	main:SetSize(gridWidth + PADDING * 2, TITLE_HEIGHT + contentHeight + FOOTER_HEIGHT + 6)

	local bagSlots = {}
	for _, slot in ipairs(slots) do
		if slot.area ~= "keyring" then
			table.insert(bagSlots, slot)
		end
	end
	main.FreeSlots:SetText(L.FREE_SLOTS:format(ns.Layout.CountFree(bagSlots)))
	Frame.UpdateMoney()
	ItemButtons.UpdateShown()
end

-- Light update for lock/cooldown/search changes that don't change the layout.
function Frame.UpdateButtons()
	if main and main:IsShown() then
		ItemButtons.UpdateShown()
	end
end

function Frame.GetLastSlots()
	return lastSlots
end
