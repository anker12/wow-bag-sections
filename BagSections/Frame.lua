-- The combined bag window: title bar, one block per section, Rest, Reagents, footer.

local _, ns = ...
local L = ns.L
local Rules = ns.Rules
local ItemButtons = ns.ItemButtons

local Frame = {}
ns.Frame = Frame

local PADDING = 10
-- The Blizzard border is thicker than the plain one; keep content (and compact outlines,
-- which sit just outside the slots) clear of it.
local BLIZZARD_BORDER_EXTRA = 6
local SPACING = 4
local MIN_HEADER_HEIGHT = 20
local GROUP_GAP = 6
local TITLE_HEIGHT = 30
-- Footer: free slots on the left, gold on the right, tracked currencies left of the gold
-- (or on lines of their own above it when they don't fit).
local FOOTER_BOTTOM = 8 -- space below the footer's bottom line
local FOOTER_LINE_GAP = 4 -- space between footer lines
local MIN_FOOTER_LINE = 14
local CURRENCY_GAP = 10 -- space between currencies, and between them and the gold
local MAX_CURRENCIES = 20 -- safety cap when reading tracked currencies
local REARRANGE_BAR_HEIGHT = 22
local BUTTON_SIZE = ItemButtons.SIZE
local CELL = BUTTON_SIZE + SPACING

-- Compact layout: every group runs through one shared grid, outlined in its colour.
-- Slots keep a strict grid (same columns on every row); the gap between all slots is wider
-- than in the default layout so outlines fit between neighbouring sections.
local COMPACT_GAP = 10 -- space between slots, in every direction
local COMPACT_CELL = BUTTON_SIZE + COMPACT_GAP
local OUTLINE_PADDING = 3 -- space between a section's items and its outline, on every side
local MIN_NAME_HEIGHT = 12 -- height of a section's name label on its outline
-- Compact layout names use a font this much smaller than section headers.
local COMPACT_NAME_SHRINK = 2
local NAME_RAISE = 3 -- names sit this far above their outline, clear of the item icons
local LINE = 1 -- outline thickness
-- Outline opacity comes from the "Outline opacity" setting (ns.db.outlineAlpha).
local REFLOW_AFTER_SORT = 3 -- seconds the compact layout keeps updating after a sort

-- Outline colours for the built-in groups in the compact layout.
local BUILTIN_COLORS = {
	rest = { r = 0.65, g = 0.65, b = 0.65 },
	reagent = { r = 0.40, g = 0.80, b = 0.45 },
	keyring = { r = 0.95, g = 0.80, b = 0.35 },
}

-- Blizzard's blue for "this item can go here".
local DROP_COLOR = { r = 0.3, g = 0.7, b = 1 }
local DROP_GLOW_SIZE = 8 -- how far the drop highlight's glow reaches in from the edge
local DROP_GLOW_ALPHA = 0.35

local main, content, dropWatcher
-- Font sizes come from Settings (see Frame.ApplyFonts); heights follow the font size.
local fonts = {}
local headerHeight, nameHeight = MIN_HEADER_HEIGHT, MIN_NAME_HEIGHT
local currencies = {}
local bodyHeight -- window height without the footer, from the last render
local headers, overlays = {}, {}
local labels, placeholders, lineTextures = {}, {}, {}
local lineFrame, measure, dividerLine

-- Compact layout keeps its arrangement while the window is open, so items don't jump
-- around when things are looted or used up. It's rebuilt on open, on any change the
-- player makes (assigning, sorting, section changes) and when the bags themselves change.
local frozen
local reflowUntil = 0
local lastSlots = {}

-- Information about the item on the cursor, or nil. Used to show drop targets.
local cursorState

-- Rearranging (semi-compact): while unlocked, section names can be dragged to move the
-- section to another row or position. Locked again on every /reload, so the window can be
-- moved without accidentally moving sections.
local rearranging = false
local sectionDrag -- { key, target } while a section is being dragged
local dragGhost, dropLine

function Frame.IsRearranging()
	return rearranging and ns.db.layout == "semicompact"
end

function Frame.SetRearranging(on)
	rearranging = on and true or false
	ns.RequestRefresh()
end

local function CanDrag(group)
	return group and (group.kind == "section" or group.kind == "rest")
end

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
	-- C_Cursor.GetCursorItem can keep answering with the last item after the cursor is empty
	-- (e.g. after cancelling a bind-on-equip prompt, or dropping gear back on the character
	-- pane), so first check there really is an item on the cursor.
	if GetCursorInfo() ~= "item" then
		return nil
	end
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
		if CursorHasItem() or not ns.db.sectionTooltips then
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
		if Frame.IsRearranging() and CanDrag(self.group) then
			GameTooltip_AddInstructionLine(GameTooltip, L.HEADER_DRAG)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateHeader(index)
	local header = CreateFrame("Button", nil, content)
	header:SetHeight(headerHeight)
	header.Text = header:CreateFontString(nil, "OVERLAY")
	header.Text:SetFontObject(fonts.section)
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
	header:SetScript("OnDragStart", function(self) Frame.BeginSectionDrag(self.group) end)
	header:SetScript("OnDragStop", function() Frame.EndSectionDrag() end)
	headers[index] = header
	return header
end

-- Note: drop targets are stored at their group's position, so this pool can have gaps;
-- always loop over it with pairs, not ipairs (ipairs stops at the first gap).

-- Drop targets while an item is on the cursor: a blue highlight like the one Blizzard
-- shows on slots an item can go into. They carry no text; hovering shows a tooltip.
local function CreateOverlay(index)
	local overlay = CreateFrame("Button", nil, content)
	overlay:RegisterForClicks("LeftButtonUp")
	-- Like Blizzard's slot hover: a thin blue edge with a glow fading in towards the middle.
	overlay.Border = CreateFrame("Frame", nil, overlay)
	overlay.Border:SetAllPoints()
	local c = DROP_COLOR
	local strong, clear = CreateColor(c.r, c.g, c.b, DROP_GLOW_ALPHA), CreateColor(c.r, c.g, c.b, 0)
	-- Per side: the two corners it spans, gradient direction, and its min/max colours
	-- (VERTICAL runs bottom -> top, HORIZONTAL left -> right), so each side is strongest at
	-- the outer edge and clear towards the middle.
	local sides = {
		{ "TOPLEFT", "TOPRIGHT", "VERTICAL", clear, strong, true },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", strong, clear, true },
		{ "TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", strong, clear, false },
		{ "TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", clear, strong, false },
	}
	for _, side in ipairs(sides) do
		local fromPoint, toPoint, orientation, minColor, maxColor, horizontalEdge = unpack(side)
		local fade = overlay.Border:CreateTexture(nil, "ARTWORK")
		fade:SetColorTexture(1, 1, 1, 1)
		fade:SetGradient(orientation, minColor, maxColor)
		fade:SetPoint(fromPoint)
		fade:SetPoint(toPoint)
		local line = overlay.Border:CreateTexture(nil, "OVERLAY")
		line:SetColorTexture(c.r, c.g, c.b, 0.9)
		line:SetPoint(fromPoint)
		line:SetPoint(toPoint)
		if horizontalEdge then
			fade:SetHeight(DROP_GLOW_SIZE)
			line:SetHeight(1)
		else
			fade:SetWidth(DROP_GLOW_SIZE)
			line:SetWidth(1)
		end
	end
	overlay:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
	overlay:GetHighlightTexture():SetVertexColor(DROP_COLOR.r, DROP_COLOR.g, DROP_COLOR.b, 0.15)
	overlay:SetScript("OnClick", function(self) HandleDrop(self.group) end)
	overlay:SetScript("OnReceiveDrag", function(self) HandleDrop(self.group) end)
	overlay:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip_SetTitle(GameTooltip, L.DROP_HERE:format(self.group.name))
		GameTooltip:Show()
	end)
	overlay:SetScript("OnLeave", GameTooltip_Hide)
	overlays[index] = overlay
	return overlay
end

-- border: draw the blue border (default layout; compact turns the outline blue instead).
-- Rest's highlight never takes the mouse: dropping on any Rest slot places the item there
-- (see Frame.OnItemButtonDrop).
local function ShowOverlay(index, group, x, y, width, height, border)
	local overlay = overlays[index] or CreateOverlay(index)
	overlay.group = group
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	overlay:SetSize(width, height)
	overlay:SetFrameLevel(content:GetFrameLevel() + 30)
	overlay.Border:SetShown(border)
	overlay:EnableMouse(group.kind == "section")
	overlay:Show()
end

local function PlaceButton(group, slot, x, y, used)
	local button = ItemButtons.Get(slot.bag, slot.slot)
	button.bsSectionName = group.kind == "section" and group.name or nil
	button.bsGroupKind = group.kind
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
	if Frame.IsRearranging() and CanDrag(group) then
		header:RegisterForDrag("LeftButton")
	else
		header:RegisterForDrag()
	end
	header:Show()
	return header
end

-- Draws one group the default way (header, then a grid of `columns` slots) in a box at
-- (x, y) that is `width` pixels wide. Returns the height used.
local function DrawGroup(index, group, x, y, width, columns, gridWidth, used)
	local top = y
	local header = SetupHeader(index, group)
	header:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	header:SetSize(width, headerHeight)
	-- Narrower than the window (semi-compact): shorten long names, full name on hover.
	header.Text:SetWidth(0)
	if width < gridWidth then
		header.Text:SetWidth(math.min(header.Text:GetStringWidth() or 0, width - 20))
	end
	header.showTitleInTooltip = width < gridWidth
	y = y + headerHeight + 2

	if not group.collapsed then
		for i, slot in ipairs(group.slots) do
			local column = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			PlaceButton(group, slot, x + column * CELL, y + row * CELL, used)
		end
		local rows = math.ceil(#group.slots / columns)
		if rows == 0 and group.kind == "section" then
			-- Empty section: leave a row so it can still receive drops.
			rows = 1
		end
		y = y + rows * CELL
	end

	if IsDropTarget(group) then
		ShowOverlay(index, group, x - 3, top - 2, width + 6, y - top + 1, true)
	end
	return y - top
end

-- Default layout: groups stacked top to bottom at full width.
local function RenderDefault(groups, columns, gridWidth, used)
	local y = 0
	for index, group in ipairs(groups) do
		y = y + DrawGroup(index, group, 0, y, gridWidth, columns, gridWidth, used) + GROUP_GAP
	end
	return y - GROUP_GAP
end

-- Semi-compact layout: like the default, but your sections sit side by side, a number per
-- row (AUTO_PER_ROW until the player arranges rows), each growing downwards. Rest,
-- Reagents and Keyring stay full width.
-- Space between rows of sections, and between sections side by side, from Settings.
-- Never below these minimums: they keep a row's items clear of the section names below,
-- and the drop highlights of neighbouring sections (3 px past each side) from touching.
local SEMI_MIN_ROW_GAP = 4
local SEMI_MIN_COLUMN_GAP = 6

local function SemiRowGap()
	return math.max(SEMI_MIN_ROW_GAP, ns.db.semiRowSpacing or ns.DEFAULTS.semiRowSpacing)
end

local function SemiColumnGap()
	return math.max(SEMI_MIN_COLUMN_GAP, ns.db.semiColumnSpacing or ns.DEFAULTS.semiColumnSpacing)
end
-- Sections per row in the automatic arrangement (before the player drags anything, or
-- after Reset rows).
local AUTO_PER_ROW = 3

-- The most sections that fit side by side with each at least one slot wide.
function Frame.MaxSectionsPerRow(columns)
	local gridWidth = columns * BUTTON_SIZE + (columns - 1) * SPACING
	local gap = SemiColumnGap()
	return math.max(1, math.floor((gridWidth + gap) / (BUTTON_SIZE + gap)))
end

-- Where each drawn row sits, for dragging sections around: { y, height, dataRow, boxes =
-- { { x, width, key } } }. Filled by RenderSemiCompact.
local rowGeometry = {}

local function RenderSemiCompact(groups, columns, gridWidth, used)
	local maxPerRow = Frame.MaxSectionsPerRow(columns)
	local perRow = math.min(AUTO_PER_ROW, maxPerRow)
	local rows = ns.Rows.Get(ns.charDB, perRow)

	local byKey, indexOf = {}, {}
	for index, group in ipairs(groups) do
		byKey[group.key] = group
		indexOf[group.key] = index
	end

	local rowGap, columnGap = SemiRowGap(), SemiColumnGap()
	local y = 0
	rowGeometry = {}
	local function DrawRow(entries, dataRow)
		local count = #entries
		local boxWidth = (gridWidth - (count - 1) * columnGap) / count
		local boxColumns = math.max(1, math.floor((boxWidth + SPACING) / CELL))
		local geometry = { y = y, dataRow = dataRow, boxes = {} }
		local rowHeight = 0
		for i, key in ipairs(entries) do
			local x = math.floor((i - 1) * (boxWidth + columnGap) + 0.5)
			local width = count == 1 and gridWidth or boxWidth
			local columnsHere = count == 1 and columns or boxColumns
			rowHeight = math.max(rowHeight, DrawGroup(indexOf[key], byKey[key], x, y, width, columnsHere, gridWidth, used))
			table.insert(geometry.boxes, { x = x, width = width, key = key })
		end
		geometry.height = rowHeight
		table.insert(rowGeometry, geometry)
		y = y + rowHeight + rowGap
	end

	for dataRow, row in ipairs(rows) do
		-- Only groups that are showing (empty sections may be hidden); rows that hold more
		-- than fit (e.g. after lowering Columns) wrap onto extra lines.
		local visible = {}
		for _, key in ipairs(row) do
			if byKey[key] then
				table.insert(visible, key)
			end
		end
		for first = 1, #visible, maxPerRow do
			local chunk = {}
			for i = first, math.min(first + maxPerRow - 1, #visible) do
				table.insert(chunk, visible[i])
			end
			DrawRow(chunk, dataRow)
		end
	end
	-- Reagents and Keyring: full width at the bottom.
	for index, group in ipairs(groups) do
		if group.kind == "reagent" or group.kind == "keyring" then
			y = y + DrawGroup(index, group, 0, y, gridWidth, columns, gridWidth, used) + rowGap
		end
	end
	return y - rowGap
end

local function CursorInContent()
	local x, y = GetCursorPosition()
	local scale = content:GetEffectiveScale()
	return x / scale - content:GetLeft(), content:GetTop() - y / scale
end

-- Where a dragged section would land. Returns a Rows.Move target and where to draw the
-- blue line, or nil when the spot can't take it (e.g. the row is full).
local function FindSectionDropTarget(key)
	if #rowGeometry == 0 then
		return nil
	end
	local columns = ns.db.columns or 10
	local maxPerRow = Frame.MaxSectionsPerRow(columns)
	local rows = ns.Rows.Get(ns.charDB, math.min(AUTO_PER_ROW, maxPerRow))
	local gridWidth = columns * BUTTON_SIZE + (columns - 1) * SPACING
	local cx, cy = CursorInContent()
	local rowGap, columnGap = SemiRowGap(), SemiColumnGap()

	for i, row in ipairs(rowGeometry) do
		if cy < row.y + 10 then
			-- Above this row, or in the gap before it: start a new row here.
			return { newRow = row.dataRow }, { x = 0, y = row.y - rowGap / 2 - 1, width = gridWidth, height = 2 }
		end
		if cy <= row.y + row.height then
			-- Inside the row: join it at the nearest gap between sections.
			local others = 0
			for _, k in ipairs(rows[row.dataRow] or {}) do
				if k ~= key then others = others + 1 end
			end
			if others >= maxPerRow then
				return nil
			end
			local before, lineX
			for _, box in ipairs(row.boxes) do
				if cx < box.x + box.width / 2 then
					before, lineX = box.key, box.x - columnGap / 2
					break
				end
			end
			if not before then
				local last = row.boxes[#row.boxes]
				lineX = last.x + last.width + columnGap / 2
				local nextRow = rowGeometry[i + 1]
				if nextRow and nextRow.dataRow == row.dataRow then
					before = nextRow.boxes[1].key -- the row wraps onto another line
				end
			end
			return { row = row.dataRow, before = before }, { x = lineX - 1, y = row.y, width = 2, height = row.height }
		end
	end
	local last = rowGeometry[#rowGeometry]
	return { newRow = #rows + 1 }, { x = 0, y = last.y + last.height + rowGap / 2 - 1, width = gridWidth, height = 2 }
end

local function UpdateSectionDrag()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	dragGhost:ClearAllPoints()
	dragGhost:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 8)

	local target, line = FindSectionDropTarget(sectionDrag.key)
	sectionDrag.target = target
	if line then
		dropLine:ClearAllPoints()
		dropLine:SetPoint("TOPLEFT", content, "TOPLEFT", line.x, -line.y)
		dropLine:SetSize(line.width, line.height)
		dropLine:Show()
	else
		dropLine:Hide()
	end
end

function Frame.BeginSectionDrag(group)
	if not (Frame.IsRearranging() and CanDrag(group)) then
		return
	end
	sectionDrag = { key = group.key }
	dragGhost.Text:SetText(group.kind == "rest" and L.REST or group.name)
	dragGhost:SetWidth((dragGhost.Text:GetStringWidth() or 60) + 16)
	dragGhost:Show()
	UpdateSectionDrag()
end

function Frame.EndSectionDrag()
	if not sectionDrag then
		return
	end
	local key, target = sectionDrag.key, sectionDrag.target
	sectionDrag = nil
	dragGhost:Hide()
	dropLine:Hide()
	if target then
		local columns = ns.db.columns or 10
		local maxPerRow = Frame.MaxSectionsPerRow(columns)
		if ns.Rows.Move(ns.charDB, key, target, math.min(AUTO_PER_ROW, maxPerRow), maxPerRow) then
			ns.RequestRefresh()
		end
	end
end

local function CreateLabel(index)
	local label = CreateFrame("Button", nil, content)
	label:SetHeight(nameHeight)
	label.Background = label:CreateTexture(nil, "BACKGROUND")
	label.Background:SetAllPoints()
	label.Background:SetColorTexture(0.05, 0.05, 0.07, 1)
	label.Text = label:CreateFontString(nil, "OVERLAY")
	label.Text:SetFontObject(fonts.sectionSmall)
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
-- Draws one flowing grid of groups starting at y = top. `counters` carries pool indexes
-- across calls so several grids can share the label/line/placeholder/overlay pools.
local function RenderFlow(groups, columns, used, top, counters)
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
	local rowTop, y = {}, top
	for r = 0, rows - 1 do
		local gap = r == 0 and (P + LINE) or COMPACT_GAP
		if nameRow[r] then
			-- The name is centred on the top outline; leave room above it, clear of the
			-- outline of whatever sits in the row above.
			local above = r == 0 and 1 or (P + LINE + 2)
			gap = math.max(gap, P + NAME_RAISE + nameHeight / 2 + above)
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

	local lineIndex, placeholderIndex, overlayIndex = counters.lines, counters.placeholders, counters.overlays
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

		-- While this group can take the item on the cursor, its outline turns blue.
		local dropTarget = IsDropTarget(group)
		local lineColor = dropTarget and DROP_COLOR or c
		local lineAlpha = dropTarget and 1 or (ns.db.outlineAlpha or 0.7)

		-- Lines are placed on whole pixels and are at least one screen pixel thick, so none
		-- get rounded away at any UI scale.
		for _, edge in ipairs(Layout.StripEdges(boxes)) do
			lineIndex = lineIndex + 1
			local texture = GetLineTexture(lineIndex)
			local ex, ey = math.floor(edge.x1 + 0.5), math.floor(edge.y1 + 0.5)
			local w = math.floor(edge.x2 + 0.5) - ex
			local h = math.floor(edge.y2 + 0.5) - ey
			texture:ClearAllPoints()
			PixelUtil.SetPoint(texture, "TOPLEFT", content, "TOPLEFT", ex, -ey)
			PixelUtil.SetSize(texture, w + LINE, h + LINE, 1, 1)
			texture:SetColorTexture(lineColor.r, lineColor.g, lineColor.b, lineAlpha)
			texture:Show()
		end

		for _, name in ipairs(names) do
			if name.group == index then
				counters.labels = counters.labels + 1
				local labelIndex = counters.labels
				local label = labels[labelIndex] or CreateLabel(labelIndex)
				label.group = group
				label:SetHeight(nameHeight)
				label.Text:SetText(CompactTitle(group))
				label.Text:SetTextColor(c.r, c.g, c.b)
				label.Text:SetWidth(0)
				local textWidth = math.min(label.Text:GetStringWidth() or 0, NameRoom(name))
				label.Text:SetWidth(textWidth)
				label:SetWidth(textWidth + 8)
				label:ClearAllPoints()
				label:SetPoint("LEFT", content, "TOPLEFT", name.left, -(boxes[name.strip].t - NAME_RAISE))
				label:SetFrameLevel(lineFrame:GetFrameLevel() + 2)
				label:Show()
			end
		end

		if dropTarget and group.kind == "section" then
			for _, box in ipairs(boxes) do
				overlayIndex = overlayIndex + 1
				ShowOverlay(overlayIndex, group, box.l, box.t, box.r - box.l, box.b - box.t, false)
			end
		end
	end
	counters.lines, counters.placeholders, counters.overlays = lineIndex, placeholderIndex, overlayIndex
	return height, width
end

-- Compact layout: sections and Rest flow through one grid; the reagent bag and keyring sit
-- in a second grid below a divider, like the default layout keeps them separate.
local COMPACT_DIVIDER_GAP = 10

local function RenderCompact(groups, columns, used)
	local bagGroups, extra = {}, {}
	for _, group in ipairs(groups) do
		if group.kind == "reagent" or group.kind == "keyring" then
			table.insert(extra, group)
		else
			table.insert(bagGroups, group)
		end
	end
	local counters = { labels = 0, lines = 0, placeholders = 0, overlays = 0 }
	local height, width = RenderFlow(bagGroups, columns, used, 0, counters)
	if #extra > 0 then
		local dividerY = height + COMPACT_DIVIDER_GAP / 2
		dividerLine:ClearAllPoints()
		dividerLine:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -dividerY)
		dividerLine:SetSize(width, 1)
		dividerLine:Show()
		height = RenderFlow(extra, columns, used, height + COMPACT_DIVIDER_GAP, counters)
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
	main.CloseButton = CreateFrame("Button", nil, main, "UIPanelCloseButton")
	main.CloseButton:SetPoint("TOPRIGHT", 1, 1)

	-- The title (and the search box next to it) are centred on the same line as the close,
	-- options and sort buttons, inside the border's top band.
	main.buttonRowY = 1 - (main.CloseButton:GetHeight() or 24) / 2
	main.Title = main.Chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	main.Title:SetPoint("LEFT", main.Chrome, "TOPLEFT", PADDING, main.buttonRowY)
	main.Title:SetText(L.BAGS)
	-- Right-click the title to look at the bank from anywhere. Dragging it still moves
	-- the window, as the rest of the title row does.
	main.TitleButton = CreateFrame("Button", nil, main.Chrome)
	main.TitleButton:SetAllPoints(main.Title)
	main.TitleButton:RegisterForClicks("RightButtonUp")
	main.TitleButton:RegisterForDrag("LeftButton")
	main.TitleButton:SetScript("OnClick", function() ns.BankFrame.Toggle() end)
	main.TitleButton:SetScript("OnDragStart", function() main:StartMoving() end)
	main.TitleButton:SetScript("OnDragStop", function()
		main:StopMovingOrSizing()
		SavePosition()
	end)
	main.TitleButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L.BAGS)
		GameTooltip_AddInstructionLine(GameTooltip, L.VIEW_BANK_HINT)
		GameTooltip:Show()
	end)
	main.TitleButton:SetScript("OnLeave", GameTooltip_Hide)

	main.MenuButton = CreateFrame("Button", nil, main.Chrome)
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

	main.SortButton = CreateFrame("Button", nil, main.Chrome)
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

	main.SearchBox = CreateFrame("EditBox", "BagSectionsSearchBox", main.Chrome, "BagSearchBoxTemplate")
	main.SearchBox:SetHeight(20)
	main.SearchBox:SetPoint("LEFT", main.Title, "RIGHT", 14, 0)
	main.SearchBox:SetPoint("RIGHT", main.SortButton, "LEFT", -8, 0)
end

-- Background and border for a window (the bags, and the bank viewer). The look follows the
-- appearance settings; see Frame.StyleWindow.
function Frame.CreateWindowArt(window)
	window:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	-- Optional Blizzard look: the bronze Forever frame border and Blizzard's panel
	-- background.
	window.BlizzardBackground = CreateFrame("Frame", nil, window, "FlatPanelBackgroundTemplate")
	window.BlizzardBackground:SetPoint("TOPLEFT", 2, -2)
	window.BlizzardBackground:SetPoint("BOTTOMRIGHT", -2, 2)
	window.BlizzardBackground:SetFrameLevel(window:GetFrameLevel())
	window.BlizzardBorder = CreateFrame("Frame", nil, window, "NineSlicePanelTemplate")
	NineSliceUtil.ApplyLayoutByName(window.BlizzardBorder, "ButtonFrameTemplateNoPortrait")

	-- Title row and footer sit on their own layer above the border art, which Blizzard
	-- draws very high up (frame level 500) and would otherwise cover them. The close button
	-- stays a direct child of the window so it hides the window, and is already above it.
	window.Chrome = CreateFrame("Frame", nil, window)
	window.Chrome:SetAllPoints()
	window.Chrome:SetFrameLevel(window.BlizzardBorder:GetFrameLevel() + 5)
end

-- Background style and opacity, and which border to use, from Settings.
function Frame.StyleWindow(window)
	local alpha = ns.db.backgroundAlpha or 0.94
	if ns.db.backgroundStyle == "blizzard" then
		window.BlizzardBackground:Show()
		window.BlizzardBackground:SetAlpha(alpha)
		window:SetBackdropColor(0, 0, 0, 0)
	else
		window.BlizzardBackground:Hide()
		window:SetBackdropColor(0.05, 0.05, 0.07, alpha)
	end
	local blizzardBorder = ns.db.blizzardBorder ~= false
	window.BlizzardBorder:SetShown(blizzardBorder)
	window:SetBackdropBorderColor(0.5, 0.5, 0.5, blizzardBorder and 0 or 1)
end

function Frame.GetFont(key)
	return fonts[key]
end

-- Height of a section header, which follows the section name size.
function Frame.HeaderHeight()
	return headerHeight
end

-- Our own copies of Blizzard's fonts, so their size can follow the settings without
-- changing Blizzard's.
local FONT_BASES = {
	section = "GameFontNormal", -- section headers
	sectionSmall = "GameFontNormalSmall", -- compact layout names
	money = "GameFontHighlight", -- gold and currencies
	slots = "GameFontHighlightSmall", -- free slots
}

local function CreateFonts()
	for key, base in pairs(FONT_BASES) do
		local font = CreateFont("BagSectionsFont_" .. key)
		font:CopyFontObject(base)
		fonts[key] = font
	end
end

local function CreateFooter()
	main.Money = main.Chrome:CreateFontString(nil, "OVERLAY")
	main.Money:SetFontObject(fonts.money)
	main.FreeSlots = main.Chrome:CreateFontString(nil, "OVERLAY")
	main.FreeSlots:SetFontObject(fonts.slots)
end

-- One tracked currency in the footer: its amount, then its icon, like Blizzard's bags.
local function CreateCurrency(index)
	local currency = CreateFrame("Frame", nil, main.Chrome)
	currency.Count = currency:CreateFontString(nil, "OVERLAY")
	currency.Count:SetFontObject(fonts.money)
	currency.Count:SetPoint("LEFT")
	currency.Icon = currency:CreateTexture(nil, "ARTWORK")
	currency.Icon:SetPoint("RIGHT")
	currency:EnableMouse(true)
	currency:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetBackpackToken(self.index)
		GameTooltip:Show()
	end)
	currency:SetScript("OnLeave", GameTooltip_Hide)
	currencies[index] = currency
	return currency
end

-- Currencies ticked "Show on Backpack" in the Currency tab, in Blizzard's order.
local function ReadCurrencies()
	local list = {}
	if not (C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo) then
		return list
	end
	for index = 1, MAX_CURRENCIES do
		local info = C_CurrencyInfo.GetBackpackCurrencyInfo(index)
		if not info then
			break
		end
		table.insert(list, { index = index, icon = info.iconFileID, quantity = info.quantity })
	end
	return list
end

-- Same number format as Blizzard's bags: 12,345, or 123K once that gets too long.
local function FormatQuantity(quantity)
	local text = BreakUpLargeNumbers and BreakUpLargeNumbers(quantity) or tostring(quantity)
	if #text > 5 and AbbreviateNumbers then
		text = AbbreviateNumbers(quantity)
	end
	return text
end

function Frame.Init()
	CreateFonts()
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
	Frame.CreateWindowArt(main)
	main:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		ns.Hooks.OnWindowShownChanged()
		Frame.Render("layout")
	end)
	main:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		frozen = nil
		Frame.EndSectionDrag()
		ns.Hooks.OnWindowShownChanged()
	end)
	-- When it replaces the default bags, Escape closes Blizzard's (hidden) bags, which closes
	-- this window too. Only add it to Escape's list when it doesn't, since addon frames in
	-- that list can taint the Escape/game-menu path.
	if not ns.db.takeOverBags then
		tinsert(UISpecialFrames, main:GetName())
	end

	-- Safety net for drop targets: as soon as nothing is on the cursor any more, however the
	-- drag ended, clear them. Only runs while drop targets are showing.
	dropWatcher = CreateFrame("Frame", nil, main)
	dropWatcher:Hide()
	dropWatcher:SetScript("OnUpdate", function(self)
		if GetCursorInfo() ~= "item" then
			self:Hide()
			cursorState = nil
			for _, overlay in pairs(overlays) do overlay:Hide() end
			ns.RequestRefresh("items")
		end
	end)

	content = CreateFrame("Frame", nil, main)
	content:SetPoint("TOPLEFT", PADDING, -TITLE_HEIGHT)
	ItemButtons.SetParent(content)

	-- Compact-layout outlines draw above the item buttons: the buttons' slot art is larger
	-- than the slot and would otherwise cover parts of the outlines. Outlines only sit in
	-- the gaps between slots, so they never cover an icon. Names draw above the outlines.
	lineFrame = CreateFrame("Frame", nil, content)
	lineFrame:SetAllPoints()
	lineFrame:SetFrameLevel(content:GetFrameLevel() + 10)
	dividerLine = lineFrame:CreateTexture(nil, "ARTWORK")
	dividerLine:SetColorTexture(1, 1, 1, 0.15)
	dividerLine:Hide()
	measure = content:CreateFontString(nil, "OVERLAY")
	measure:SetFontObject(fonts.sectionSmall)
	measure:Hide()

	-- Rearranging: blue line where a dragged section will land, its name following the
	-- cursor, and a bar under the title while unlocked (click it to lock).
	dropLine = lineFrame:CreateTexture(nil, "OVERLAY")
	dropLine:SetColorTexture(DROP_COLOR.r, DROP_COLOR.g, DROP_COLOR.b, 1)
	dropLine:Hide()
	dragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	dragGhost:SetFrameStrata("TOOLTIP")
	dragGhost:SetHeight(20)
	dragGhost:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	dragGhost:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
	dragGhost:SetBackdropBorderColor(DROP_COLOR.r, DROP_COLOR.g, DROP_COLOR.b, 1)
	dragGhost.Text = dragGhost:CreateFontString(nil, "OVERLAY")
	dragGhost.Text:SetFontObject(fonts.section)
	dragGhost.Text:SetPoint("CENTER")
	dragGhost:Hide()
	dragGhost:SetScript("OnUpdate", function()
		if sectionDrag then
			UpdateSectionDrag()
		end
	end)

	main.RearrangeBar = CreateFrame("Button", nil, main.Chrome)
	main.RearrangeBar:SetHeight(REARRANGE_BAR_HEIGHT - 4)
	main.RearrangeBar:SetPoint("TOPLEFT", PADDING, -TITLE_HEIGHT + 2)
	main.RearrangeBar:SetPoint("TOPRIGHT", -PADDING, -TITLE_HEIGHT + 2)
	main.RearrangeBar.Background = main.RearrangeBar:CreateTexture(nil, "BACKGROUND")
	main.RearrangeBar.Background:SetAllPoints()
	main.RearrangeBar.Background:SetColorTexture(DROP_COLOR.r, DROP_COLOR.g, DROP_COLOR.b, 0.2)
	main.RearrangeBar.Text = main.RearrangeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.RearrangeBar.Text:SetPoint("CENTER")
	main.RearrangeBar.Text:SetText(L.REARRANGE_BAR)
	main.RearrangeBar:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
	main.RearrangeBar:GetHighlightTexture():SetVertexColor(DROP_COLOR.r, DROP_COLOR.g, DROP_COLOR.b, 0.15)
	main.RearrangeBar:SetScript("OnClick", function() Frame.SetRearranging(false) end)
	main.RearrangeBar:Hide()

	CreateTitleBar()
	CreateFooter()
	RestorePosition()
	Frame.ApplyFonts()
	Frame.ApplyScale()
	Frame.ApplyAppearance()
end

-- Space between the window edge and its contents on the left and right.
function Frame.SidePadding()
	return ns.db.blizzardBorder ~= false and PADDING + BLIZZARD_BORDER_EXTRA or PADDING
end

-- Appearance settings, for the bag window and the bank viewer.
function Frame.ApplyAppearance()
	if not main then
		return
	end
	local pad = Frame.SidePadding()
	main.Title:SetPoint("LEFT", main.Chrome, "TOPLEFT", pad, main.buttonRowY)
	main.RearrangeBar:SetPoint("TOPLEFT", pad, -TITLE_HEIGHT + 2)
	main.RearrangeBar:SetPoint("TOPRIGHT", -pad, -TITLE_HEIGHT + 2)
	ns.RequestRefresh()
	Frame.StyleWindow(main)
	ns.BankFrame.ApplyAppearance()
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

-- Font sizes from Settings.
function Frame.ApplyFonts()
	local sectionSize = ns.db.sectionFontSize or ns.DEFAULTS.sectionFontSize
	local sizes = {
		section = sectionSize,
		sectionSmall = sectionSize - COMPACT_NAME_SHRINK,
		money = ns.db.moneyFontSize or ns.DEFAULTS.moneyFontSize,
		slots = ns.db.slotsFontSize or ns.DEFAULTS.slotsFontSize,
	}
	for key, base in pairs(FONT_BASES) do
		local path, _, flags = _G[base]:GetFont()
		fonts[key]:SetFont(path, sizes[key], flags or "")
	end
	headerHeight = math.max(MIN_HEADER_HEIGHT, sizes.section + 8)
	nameHeight = math.max(MIN_NAME_HEIGHT, sizes.sectionSmall + 2)
	ns.RequestRefresh()
	ns.BankFrame.Refresh()
end

-- Gold, tracked currencies and free slots, and the window height that depends on them.
-- Currencies go left of the gold when they fit between it and the free slots; otherwise
-- they get lines of their own above it, wrapping so they never run past the window edge.
function Frame.UpdateFooter()
	if not (main and main:IsShown() and bodyHeight) then
		return
	end
	main.Money:SetText(GetMoneyString(GetMoney(), true))

	local moneySize = ns.db.moneyFontSize or ns.DEFAULTS.moneyFontSize
	local slotsSize = ns.db.slotsFontSize or ns.DEFAULTS.slotsFontSize
	local lineHeight = math.max(MIN_FOOTER_LINE, moneySize + 2, slotsSize + 2)
	local pad = Frame.SidePadding()
	local innerWidth = (main:GetWidth() or 0) - pad * 2

	local list = ReadCurrencies()
	local widths = {}
	for i, info in ipairs(list) do
		local currency = currencies[i] or CreateCurrency(i)
		currency.index = info.index
		currency.Icon:SetTexture(info.icon)
		currency.Icon:SetSize(moneySize, moneySize)
		currency.Count:SetText(FormatQuantity(info.quantity))
		widths[i] = (currency.Count:GetStringWidth() or 0) + 2 + moneySize
		currency:SetSize(widths[i], lineHeight)
	end
	for i = #list + 1, #currencies do
		currencies[i]:Hide()
	end

	local moneyWidth = main.Money:GetStringWidth() or 0
	local inlineWidth = innerWidth - moneyWidth - (main.FreeSlots:GetStringWidth() or 0) - CURRENCY_GAP * 2
	local footer = ns.Layout.FooterCurrencies(widths, inlineWidth, innerWidth, CURRENCY_GAP)

	local function LineY(line)
		return FOOTER_BOTTOM + line * (lineHeight + FOOTER_LINE_GAP) + lineHeight / 2
	end
	main.Money:ClearAllPoints()
	main.Money:SetPoint("RIGHT", main.Chrome, "BOTTOMRIGHT", -pad, LineY(0))
	main.FreeSlots:ClearAllPoints()
	main.FreeSlots:SetPoint("LEFT", main.Chrome, "BOTTOMLEFT", pad, LineY(0))
	for i, place in ipairs(footer.places) do
		local right = pad + place.right + (place.line == 0 and moneyWidth + CURRENCY_GAP or 0)
		local currency = currencies[i]
		currency:ClearAllPoints()
		currency:SetPoint("RIGHT", main.Chrome, "BOTTOMRIGHT", -right, LineY(place.line))
		currency:Show()
	end

	local lines = 1 + footer.extraLines
	local footerHeight = FOOTER_BOTTOM + lines * lineHeight + (lines - 1) * FOOTER_LINE_GAP
	main:SetHeight(bodyHeight + footerHeight + 6)
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
			hideKeyring = not ns.db.showKeyring,
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
	for _, header in pairs(headers) do header:Hide() end
	for _, overlay in pairs(overlays) do overlay:Hide() end
	for _, label in pairs(labels) do label:Hide() end
	for _, placeholder in pairs(placeholders) do placeholder:Hide() end
	for _, texture in pairs(lineTextures) do texture:Hide() end
	dividerLine:Hide()

	local contentHeight
	if compact then
		contentHeight, gridWidth = RenderCompact(groups, columns, used)
		content:SetWidth(gridWidth)
	elseif ns.db.layout == "semicompact" then
		contentHeight = RenderSemiCompact(groups, columns, gridWidth, used)
	else
		contentHeight = RenderDefault(groups, columns, gridWidth, used)
	end

	ItemButtons.HideExcept(used)
	dropWatcher:SetShown(cursorState ~= nil)

	if #ns.charDB.sections == 0 and not cursorState and not compact then
		-- Hint next to Rest when no sections exist yet.
		headers[1].Text:SetText(GroupTitle(groups[1]) .. "   |cff777777" .. L.NO_SECTIONS .. " - " .. L.NEW_SECTION .. "|r")
	end

	content:SetHeight(math.max(contentHeight, 1))
	-- While rearranging, a bar under the title pushes the content down a little.
	local barHeight = Frame.IsRearranging() and REARRANGE_BAR_HEIGHT or 0
	main.RearrangeBar:SetShown(barHeight > 0)
	content:ClearAllPoints()
	local pad = Frame.SidePadding()
	content:SetPoint("TOPLEFT", pad, -(TITLE_HEIGHT + barHeight))
	bodyHeight = TITLE_HEIGHT + barHeight + contentHeight
	main:SetWidth(gridWidth + pad * 2)

	local bagSlots = {}
	for _, slot in ipairs(slots) do
		if slot.area ~= "keyring" then
			table.insert(bagSlots, slot)
		end
	end
	main.FreeSlots:SetText(L.FREE_SLOTS:format(ns.Layout.CountFree(bagSlots)))
	Frame.UpdateFooter()
	ItemButtons.UpdateShown()
end

-- Light update for lock/cooldown/search changes that don't change the layout.
function Frame.UpdateButtons()
	if main and main:IsShown() then
		ItemButtons.UpdateShown()
	end
end

-- Called after Blizzard's own click/drop handling on an item button. Dropping an item
-- from a section onto any Rest slot places it there (Blizzard moves it) and takes it out
-- of its section.
function Frame.OnItemButtonDrop(button)
	local state = cursorState -- what was on the cursor before this click
	if not state or button.bsGroupKind ~= "rest" or state.source ~= "bags" or state.section == Rules.REST then
		return
	end
	local now = C_Cursor.GetCursorItem()
	local nowItem = now and ns.Inventory.GetItemFromLocation(now)
	if nowItem and nowItem.guid == state.item.guid then
		return -- still holding the same item: nothing was dropped
	end
	Rules.Unassign(ns.charDB, state.item)
	ns.RequestRefresh()
end

function Frame.GetLastSlots()
	return lastSlots
end
