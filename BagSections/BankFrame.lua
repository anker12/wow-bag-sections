-- Read-only bank window: shows the last bank snapshot (see Bank.lua) from anywhere.
-- Opened by right-clicking the bag window's title, or /bs bank. Items can't be moved from
-- here; hovering shows the tooltip and Shift-click links an item in chat, like the bags.

local _, ns = ...
local L = ns.L

local BankFrame = {}
ns.BankFrame = BankFrame

local SPACING = 4
local TITLE_HEIGHT = 30
local FOOTER_HEIGHT = 22
local GROUP_GAP = 6
local BUTTON_SIZE = ns.ItemButtons.SIZE
local CELL = BUTTON_SIZE + SPACING

local window, content
local buttons, headers = {}, {}

local function SavePosition()
	local point, _, relativePoint, x, y = window:GetPoint(1)
	ns.db.bankFrame = { point = point, relativePoint = relativePoint, x = x, y = y }
end

-- Until it has been moved, the bank window opens just left of the bags.
local function PlaceWindow()
	local pos = ns.db.bankFrame
	window:ClearAllPoints()
	if pos then
		window:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
	elseif BagSectionsFrame and BagSectionsFrame:IsShown() then
		window:SetPoint("TOPRIGHT", BagSectionsFrame, "TOPLEFT", -12, 0)
	else
		window:SetPoint("CENTER", UIParent, "CENTER")
	end
end

local function CreateButton(index)
	-- The plain ItemButton widget already has an icon, count, quality border and highlight.
	-- (Forever has no ItemButtonTemplate, and the bag slot template would try to use the
	-- live item in that bank slot when clicked.)
	local button = CreateFrame("ItemButton", nil, content)
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
	button.ItemSlotBackground:SetAllPoints(button)
	button:SetScript("OnEnter", function(self)
		if self.link then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.link)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnClick", function(self)
		if self.link then
			HandleModifiedItemClick(self.link)
		end
	end)
	buttons[index] = button
	return button
end

local function CreateHeader(index)
	local header = content:CreateFontString(nil, "OVERLAY")
	header:SetFontObject(ns.Frame.GetFont("section"))
	header:SetJustifyH("LEFT")
	headers[index] = header
	return header
end

-- Title of one bank tab: the account bank's tabs say which bank they're in.
local function TabTitle(kind, tab, index)
	local name = (tab.name and tab.name ~= "") and tab.name or L.BANK_TAB:format(index)
	if kind == "account" then
		return L.ACCOUNT_BANK_TAB:format(name)
	end
	return name
end

-- Draws every tab of every snapshot, one block each like the default layout.
-- Returns the content height.
local function DrawTabs(snapshots, columns)
	local y, buttonIndex, headerIndex = 0, 0, 0
	local headerHeight = ns.Frame.HeaderHeight()
	for _, snapshot in ipairs(snapshots) do
		for tabIndex, tab in ipairs(snapshot.data.tabs) do
			headerIndex = headerIndex + 1
			local header = headers[headerIndex] or CreateHeader(headerIndex)
			header:ClearAllPoints()
			header:SetPoint("LEFT", content, "TOPLEFT", 2, -(y + headerHeight / 2))
			header:SetText(TabTitle(snapshot.kind, tab, tabIndex))
			header:Show()
			y = y + headerHeight + 2

			for slot = 1, tab.size do
				buttonIndex = buttonIndex + 1
				local button = buttons[buttonIndex] or CreateButton(buttonIndex)
				local item = tab.items[slot]
				local column = (slot - 1) % columns
				local row = math.floor((slot - 1) / columns)
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", content, "TOPLEFT", column * CELL, -(y + row * CELL))
				button.link = item and item.link
				button:SetItemButtonTexture(item and item.icon)
				SetItemButtonQuality(button, item and item.quality, item and item.link)
				SetItemButtonCount(button, item and item.count or 0)
				button:Show()
			end
			y = y + math.ceil(tab.size / columns) * CELL + GROUP_GAP
		end
	end
	for i = buttonIndex + 1, #buttons do
		buttons[i]:Hide()
	end
	for i = headerIndex + 1, #headers do
		headers[i]:Hide()
	end
	return math.max(y - GROUP_GAP, 0)
end

-- Redraws the window from the latest snapshot.
function BankFrame.Refresh()
	if not (window and window:IsShown()) then
		return
	end
	local snapshots = ns.Bank.GetSnapshots(ns.charDB, ns.db)
	local columns = ns.db.columns or 10
	local gridWidth = columns * BUTTON_SIZE + (columns - 1) * SPACING
	local pad = ns.Frame.SidePadding()

	window.Empty:SetShown(#snapshots == 0)
	local contentHeight = DrawTabs(snapshots, columns)
	if #snapshots == 0 then
		contentHeight = 40
	end
	content:SetSize(gridWidth, math.max(contentHeight, 1))
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", pad, -TITLE_HEIGHT)
	window:SetSize(gridWidth + pad * 2, TITLE_HEIGHT + contentHeight + FOOTER_HEIGHT + 6)

	window.Title:SetPoint("LEFT", window.Chrome, "TOPLEFT", pad, window.buttonRowY)
	window.FreeSlots:SetPoint("BOTTOMLEFT", pad, 8)
	window.Updated:SetPoint("BOTTOMRIGHT", -pad, 8)
	if #snapshots == 0 then
		window.FreeSlots:SetText("")
	else
		window.FreeSlots:SetText(L.FREE_SLOTS:format(ns.Bank.CountFree(snapshots)))
	end

	-- How old the snapshot is: "Live" while at the bank, else when the character's bank
	-- was last seen.
	local updated = snapshots[1] and snapshots[1].data.updated
	if ns.Bank.IsOpen() then
		window.Updated:SetText(L.BANK_LIVE)
	elseif updated then
		window.Updated:SetText(L.BANK_UPDATED:format(ns.Bank.FormatAge(math.max(time() - updated, 0), L)))
	else
		window.Updated:SetText("")
	end
end

function BankFrame.ApplyAppearance()
	if window then
		ns.Frame.StyleWindow(window)
		BankFrame.Refresh()
	end
end

function BankFrame.Init()
	window = CreateFrame("Frame", "BagSectionsBankFrame", UIParent, "BackdropTemplate")
	window:Hide()
	window:SetFrameStrata("MEDIUM")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	ns.Frame.CreateWindowArt(window)
	window:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
		BankFrame.Refresh()
	end)
	window:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
	end)

	window.CloseButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	window.CloseButton:SetPoint("TOPRIGHT", 1, 1)
	window.buttonRowY = 1 - (window.CloseButton:GetHeight() or 24) / 2
	window.Title = window.Chrome:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	window.Title:SetText(L.BANK)

	content = CreateFrame("Frame", nil, window)
	window.Empty = window.Chrome:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	window.Empty:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -12)
	window.Empty:SetText(L.BANK_EMPTY)

	window.FreeSlots = window.Chrome:CreateFontString(nil, "OVERLAY")
	window.FreeSlots:SetFontObject(ns.Frame.GetFont("slots"))
	window.Updated = window.Chrome:CreateFontString(nil, "OVERLAY")
	window.Updated:SetFontObject(ns.Frame.GetFont("slots"))

	BankFrame.ApplyAppearance()
end

function BankFrame.IsShown()
	return window and window:IsShown()
end

function BankFrame.Toggle()
	if window:IsShown() then
		window:Hide()
	else
		PlaceWindow()
		window:Show()
	end
end
