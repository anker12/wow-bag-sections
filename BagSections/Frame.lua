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

local main, content
local headers, overlays = {}, {}
local lastSlots = {}

-- Information about the item on the cursor, or nil. Used to show drop targets.
local cursorState

local function GroupTitle(group)
	if group.kind == "section" then
		return ("%s %s |cff999999(%d)|r"):format(group.collapsed and "+" or "-", group.name, group.count)
	elseif group.kind == "rest" then
		return ("%s |cff999999(%d)|r"):format(L.REST, #group.slots)
	elseif group.kind == "reagent" then
		return L.REAGENTS
	end
	return L.KEYRING
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

	local y = 0
	for index, group in ipairs(groups) do
		local top = y
		local header = headers[index] or CreateHeader(index)
		header.group = group
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		header:SetWidth(gridWidth)
		header.Text:SetText(GroupTitle(group))
		header:Show()
		y = y + HEADER_HEIGHT + 2

		local shown = group.kind ~= "section" or not group.collapsed
		if shown then
			local sectionName = group.kind == "section" and group.name or nil
			for i, slot in ipairs(group.slots) do
				local column = (i - 1) % columns
				local row = math.floor((i - 1) / columns)
				local button = ItemButtons.Get(slot.bag, slot.slot)
				button.bsSectionName = sectionName
				used[button] = true
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", content, "TOPLEFT", column * (BUTTON_SIZE + SPACING), -(y + row * (BUTTON_SIZE + SPACING)))
				button:Show()
			end
			local rows = math.ceil(#group.slots / columns)
			if rows == 0 and group.kind == "section" then
				-- Empty section: leave a row so it can still receive drops.
				rows = 1
			end
			y = y + rows * (BUTTON_SIZE + SPACING)
		end

		if IsDropTarget(group) then
			local overlay = overlays[index] or CreateOverlay(index)
			overlay.group = group
			overlay:ClearAllPoints()
			overlay:SetPoint("TOPLEFT", content, "TOPLEFT", -3, -top + 2)
			overlay:SetSize(gridWidth + 6, y - top + 1)
			overlay:SetFrameLevel(content:GetFrameLevel() + 30)
			overlay.Text:SetText(group.kind == "rest" and L.DROP_REST or L.DROP_HERE:format(group.name))
			overlay:Show()
		end

		y = y + GROUP_GAP
	end

	ItemButtons.HideExcept(used)

	if #ns.charDB.sections == 0 and not cursorState then
		-- Hint row above Rest when no sections exist yet.
		headers[1].Text:SetText(GroupTitle(groups[1]) .. "   |cff777777" .. L.NO_SECTIONS .. " - " .. L.NEW_SECTION .. "|r")
	end

	local contentHeight = y - GROUP_GAP
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
