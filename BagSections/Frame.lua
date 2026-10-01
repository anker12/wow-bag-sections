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

-- Compact layout: each group is an outlined block, and blocks are packed side by side.
local BLOCK_PADDING = 5
local BLOCK_GAP = 6
local LABEL_HEIGHT = 18

-- Outline colours for the built-in groups in the compact layout.
local BUILTIN_COLORS = {
	rest = { r = 0.65, g = 0.65, b = 0.65 },
	reagent = { r = 0.40, g = 0.80, b = 0.45 },
	keyring = { r = 0.95, g = 0.80, b = 0.35 },
}

local main, content
local headers, overlays, outlines = {}, {}, {}
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

local function CreateHeader(index)
	local header = CreateFrame("Button", nil, content)
	header:SetHeight(HEADER_HEIGHT)
	header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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

	header:SetScript("OnClick", function(self, mouseButton)
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
	header:SetScript("OnReceiveDrag", function(self) HandleDrop(self.group) end)
	header:SetScript("OnEnter", function(self)
		if CursorHasItem() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_AddNormalLine(GameTooltip, self.group.collapsed and L.HEADER_EXPAND or L.HEADER_COLLAPSE)
		if self.group.kind == "section" then
			GameTooltip_AddNormalLine(GameTooltip, L.HEADER_MENU)
		end
		GameTooltip:Show()
	end)
	header:SetScript("OnLeave", GameTooltip_Hide)
	-- Coloured label strip, only shown in the compact layout.
	header.Background = header:CreateTexture(nil, "BACKGROUND")
	header.Background:SetAllPoints()
	header.Background:Hide()
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

local function CreateOutline(index)
	local outline = CreateFrame("Frame", nil, content, "BackdropTemplate")
	outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	outline:SetFrameLevel(content:GetFrameLevel() + 1)
	outlines[index] = outline
	return outline
end

local function ShowOverlay(index, group, x, y, width, height)
	local overlay = overlays[index] or CreateOverlay(index)
	overlay.group = group
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	overlay:SetSize(width, height)
	overlay:SetFrameLevel(content:GetFrameLevel() + 30)
	overlay.Text:SetText(group.kind == "rest" and L.DROP_REST or L.DROP_HERE:format(group.name))
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

local function SetupHeader(index, group, style)
	local header = headers[index] or CreateHeader(index)
	header.group = group
	header:ClearAllPoints()
	header.Text:SetText(GroupTitle(group))
	header.Text:ClearAllPoints()
	if style == "compact" then
		local c = GroupColor(group)
		header.Text:SetPoint("LEFT", 5, 0)
		header.Text:SetTextColor(c.r, c.g, c.b)
		header.Background:SetColorTexture(c.r, c.g, c.b, 0.18)
		header.Background:Show()
		header.Line:Hide()
	else
		header.Text:SetPoint("LEFT", 2, 0)
		header.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
		header.Background:Hide()
		header.Line:Show()
	end
	header:Show()
	return header
end

-- Default layout: groups stacked top to bottom at full width.
local function RenderDefault(groups, columns, gridWidth, used)
	local y = 0
	for index, group in ipairs(groups) do
		local top = y
		local header = SetupHeader(index, group, "default")
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

-- Compact layout: each group is an outlined block sized to its items, packed side by side
-- within the same window width as the default layout.
local function RenderCompact(groups, gridWidth, used)
	local maxColumns = math.max(1, math.floor((gridWidth - 2 * BLOCK_PADDING + SPACING) / CELL))
	local blocks = {}
	for index, group in ipairs(groups) do
		local header = SetupHeader(index, group, "compact")
		local labelWidth = (header.Text:GetStringWidth() or 0) + 12
		local count = #group.slots
		if count == 0 and group.kind == "section" then
			count = 1 -- empty section keeps one slot of space as a drop target
		end
		local itemColumns = group.collapsed and 0 or math.min(maxColumns, count)
		local width = math.max(itemColumns * CELL - SPACING + 2 * BLOCK_PADDING, labelWidth)
		width = math.min(width, gridWidth)
		local columns = math.max(1, math.min(maxColumns, math.floor((width - 2 * BLOCK_PADDING + SPACING) / CELL)))
		local rows = group.collapsed and 0 or math.ceil(count / columns)
		local height = LABEL_HEIGHT + (rows > 0 and (BLOCK_PADDING + rows * CELL - SPACING) or 0) + BLOCK_PADDING
		blocks[index] = { width = width, height = height, columns = columns }
	end

	local positions, totalHeight = ns.Layout.Pack(blocks, gridWidth, BLOCK_GAP)

	for index, group in ipairs(groups) do
		local block, pos = blocks[index], positions[index]
		local c = GroupColor(group)

		local outline = outlines[index] or CreateOutline(index)
		outline:ClearAllPoints()
		outline:SetPoint("TOPLEFT", content, "TOPLEFT", pos.x, -pos.y)
		outline:SetSize(block.width, block.height)
		outline:SetBackdropBorderColor(c.r, c.g, c.b, 0.9)
		outline:Show()

		local header = headers[index]
		header:SetPoint("TOPLEFT", content, "TOPLEFT", pos.x + 1, -(pos.y + 1))
		header:SetSize(block.width - 2, LABEL_HEIGHT)
		header:SetFrameLevel(outline:GetFrameLevel() + 1)

		if not group.collapsed then
			local top = pos.y + LABEL_HEIGHT + BLOCK_PADDING
			for i, slot in ipairs(group.slots) do
				local column = (i - 1) % block.columns
				local row = math.floor((i - 1) / block.columns)
				PlaceButton(group, slot, pos.x + BLOCK_PADDING + column * CELL, top + row * CELL, used)
			end
		end

		if IsDropTarget(group) then
			ShowOverlay(index, group, pos.x, pos.y, block.width, block.height)
		end
	end
	return totalHeight
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
	main.Money = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
		Frame.Render()
	end)
	main:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
		ns.Hooks.OnWindowHidden()
	end)
	tinsert(UISpecialFrames, main:GetName())

	content = CreateFrame("Frame", nil, main)
	content:SetPoint("TOPLEFT", PADDING, -TITLE_HEIGHT)
	ItemButtons.SetParent(content)

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

-- Full redraw: rescan bags, rebuild groups, reposition everything.
function Frame.Render()
	if not (main and main:IsShown()) then
		return
	end

	cursorState = ReadCursor()
	local slots = ns.Inventory.Scan()
	lastSlots = slots
	local groups = ns.Layout.Build(ns.charDB, slots, {
		showEmpty = ns.db.showEmptySections or (cursorState ~= nil and cursorState.source ~= "locked"),
	})

	local columns = ns.db.columns or 10
	local gridWidth = columns * BUTTON_SIZE + (columns - 1) * SPACING
	content:SetWidth(gridWidth)

	local used = {}
	for _, header in ipairs(headers) do header:Hide() end
	for _, overlay in ipairs(overlays) do overlay:Hide() end
	for _, outline in ipairs(outlines) do outline:Hide() end

	local contentHeight
	if ns.db.layout == "compact" then
		contentHeight = RenderCompact(groups, gridWidth, used)
	else
		contentHeight = RenderDefault(groups, columns, gridWidth, used)
	end

	ItemButtons.HideExcept(used)

	if #ns.charDB.sections == 0 and not cursorState and ns.db.layout ~= "compact" then
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
