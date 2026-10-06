-- The bank window: the same window as the bags (layouts, drag and drop, rearranging), with
-- its own layout setting, the bank's stone background and the bank's bag slots at the
-- bottom like Blizzard's bank. At the banker it replaces Blizzard's bank and works like
-- it (deposit and withdraw by right-click, drag and drop, sort, buy tabs). Anywhere else
-- it shows the last snapshot (see Bank.lua), read only.

local _, ns = ...
local L = ns.L

local TAB_BUTTON_SIZE = 30 -- the bank's bag slots in the footer
local TAB_ROW_GAP = 6

local window -- set below
local tabButtons = {}
local bankBackground, buyTab, tabDivider

-- Snapshot slots get plain item buttons that only show the saved item: there's no live
-- item behind them to click or drag. (Forever has no ItemButtonTemplate; the plain
-- ItemButton widget already has an icon, count, quality border and highlight.)
local function CachedButtons(content)
	local pool = {}
	local set = {}
	local function Create()
		local button = CreateFrame("ItemButton", nil, content)
		button:SetSize(ns.ItemButtons.SIZE, ns.ItemButtons.SIZE)
		button:SetFrameLevel(content:GetFrameLevel() + 2)
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
		return button
	end
	function set.ForSlot(slot)
		local key = slot.bag * 1000 + slot.slot
		local button = pool[key]
		if not button then
			button = Create()
			pool[key] = button
		end
		local item = slot.cached or nil
		button.link = item and item.link
		button:SetItemButtonTexture(item and item.icon)
		SetItemButtonQuality(button, item and item.quality, item and item.link)
		SetItemButtonCount(button, item and item.count or 0)
		return button
	end
	function set.HideExcept(keep)
		for _, button in pairs(pool) do
			if not keep[button] then
				button:Hide()
			end
		end
	end
	return set
end

-- Live item buttons at the bank, snapshot buttons anywhere else.
local function CreateButtons(content, win)
	local live = ns.ItemButtons.NewSet(content, win)
	local cached = CachedButtons(content)
	return {
		ForSlot = function(slot)
			if slot.cached ~= nil then
				return cached.ForSlot(slot)
			end
			return live.ForSlot(slot)
		end,
		HideExcept = function(keep)
			live.HideExcept(keep)
			cached.HideExcept(keep)
		end,
		UpdateShown = live.UpdateShown,
		UpdateCooldowns = live.UpdateCooldowns,
		Precreate = live.Precreate,
	}
end

-- The bank's stone background, like Blizzard's bank. Opacity and border follow Settings.
local function Style(main)
	ns.Frame.StyleWindow(main)
	if not bankBackground then
		bankBackground = main.BlizzardBackground:CreateTexture(nil, "BACKGROUND", nil, 1)
		bankBackground:SetPoint("TOPLEFT", main, "TOPLEFT", 3, -3)
		bankBackground:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -3, 3)
		bankBackground:SetAtlas("bank-frame-background")
		bankBackground:SetHorizTile(true)
		bankBackground:SetVertTile(true)
	end
	main.BlizzardBackground:Show()
	main.BlizzardBackground:SetAlpha(ns.db.backgroundAlpha or 0.94)
	main:SetBackdropColor(0, 0, 0, 0)
end

-- Tabs to show as bag slots: live at the bank, else from the snapshot.
local function CurrentTabs()
	if ns.Bank.IsOpen() then
		local tabs = {}
		for _, tab in ipairs(ns.Inventory.BankTabs()) do
			table.insert(tabs, { bag = tab.ID, name = tab.name, icon = tab.icon, size = C_Container.GetContainerNumSlots(tab.ID) or 0 })
		end
		return tabs
	end
	return ns.charDB.bank and ns.charDB.bank.tabs or {}
end

local function CreateTabButton(main, index)
	local button = CreateFrame("Button", nil, main.Chrome)
	button:SetSize(TAB_BUTTON_SIZE, TAB_BUTTON_SIZE)
	button.Background = button:CreateTexture(nil, "BACKGROUND")
	button.Background:SetAllPoints()
	button.Background:SetAtlas("bank-frame-bag-slot-bg")
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetPoint("TOPLEFT", 3, -3)
	button.Icon:SetPoint("BOTTOMRIGHT", -3, 3)
	button.Frame = button:CreateTexture(nil, "OVERLAY")
	button.Frame:SetAllPoints()
	button.Frame:SetAtlas("bank-frame-bag-slotframe")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, self.tabName)
		GameTooltip_AddNormalLine(GameTooltip, L.BANK_TAB_SLOTS:format(self.size or 0))
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	tabButtons[index] = button
	return button
end

local function CanBuyTab()
	return ns.Bank.IsOpen() and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(Enum.BankType.Character)
		and C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(Enum.BankType.Character)
end

StaticPopupDialogs["BAGSECTIONS_BUY_BANK_TAB"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		C_Bank.PurchaseBankTab(Enum.BankType.Character)
	end,
}

-- The bank's bag slots along the bottom, like Blizzard's bank, and a button to buy the
-- next tab while at the bank. Returns the height used.
local function FooterExtra(main, pad, bottom)
	if not buyTab then
		buyTab = CreateFrame("Button", nil, main.Chrome, "UIPanelButtonTemplate")
		buyTab:SetSize(110, 22)
		buyTab:SetText(L.BANK_BUY_TAB)
		buyTab:SetScript("OnClick", function()
			local data = CanBuyTab()
			if data then
				StaticPopup_Show("BAGSECTIONS_BUY_BANK_TAB", L.BANK_BUY_TAB_CONFIRM:format(GetMoneyString(data.tabCost or 0, true)))
			end
		end)
		tabDivider = main.Chrome:CreateTexture(nil, "ARTWORK")
		tabDivider:SetColorTexture(1, 1, 1, 0.12)
		tabDivider:SetHeight(1)
	end
	local tabs = CurrentTabs()
	for index, tab in ipairs(tabs) do
		local button = tabButtons[index] or CreateTabButton(main, index)
		button.tabName = (tab.name and tab.name ~= "") and tab.name or L.BANK_TAB:format(index)
		button.size = tab.size
		button.Icon:SetTexture(tab.icon)
		button:ClearAllPoints()
		button:SetPoint("BOTTOMLEFT", main.Chrome, "BOTTOMLEFT", pad + (index - 1) * (TAB_BUTTON_SIZE + 4), bottom)
		button:Show()
	end
	for index = #tabs + 1, #tabButtons do
		tabButtons[index]:Hide()
	end
	buyTab:SetShown(CanBuyTab() and true or false)
	buyTab:ClearAllPoints()
	buyTab:SetPoint("BOTTOMRIGHT", main.Chrome, "BOTTOMRIGHT", -pad, bottom + (TAB_BUTTON_SIZE - 22) / 2)
	local height = TAB_BUTTON_SIZE + TAB_ROW_GAP
	tabDivider:ClearAllPoints()
	tabDivider:SetPoint("BOTTOMLEFT", main.Chrome, "BOTTOMLEFT", pad, bottom + height - TAB_ROW_GAP / 2)
	tabDivider:SetPoint("BOTTOMRIGHT", main.Chrome, "BOTTOMRIGHT", -pad, bottom + height - TAB_ROW_GAP / 2)
	return height
end

-- Right side of the footer: "Live" at the bank, else how old the snapshot is.
local function FooterRightText()
	if ns.Bank.IsOpen() then
		return L.BANK_LIVE
	end
	local snapshot = ns.charDB.bank
	if not snapshot then
		return L.BANK_EMPTY
	end
	return L.BANK_UPDATED:format(ns.Bank.FormatAge(math.max(time() - (snapshot.updated or 0), 0), L))
end

local function Sort()
	if not ns.Bank.IsOpen() then
		return
	end
	PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
	window.AllowReflow()
	if C_Container.SortBank then
		C_Container.SortBank(Enum.BankType.Character)
	elseif C_Container.SortBankBags then
		C_Container.SortBankBags()
	end
end

window = ns.Frame.NewWindow({
	name = "BagSectionsBankFrame",
	title = L.BANK,
	layoutKey = "bankLayout",
	positionKey = "bankFrame",
	-- Until it's moved: next to the bags if they're open, else where Blizzard's bank opens.
	PlaceByDefault = function(main)
		if BagSectionsFrame and BagSectionsFrame:IsShown() then
			main:SetPoint("TOPRIGHT", BagSectionsFrame, "TOPLEFT", -12, 0)
		else
			main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
		end
	end,
	GetDB = function() return ns.charDB.bankSections end,
	Scan = function()
		if ns.Bank.IsOpen() then
			return ns.Inventory.ScanBank()
		end
		local slots = ns.Bank.SnapshotSlots(ns.charDB.bank)
		for _, slot in ipairs(slots) do
			if slot.item then
				slot.item.isReagent = ns.Inventory.IsReagent(slot.item.itemID)
			end
		end
		return slots
	end,
	BuildOptions = function() return {} end,
	IsOwnBag = function(bag) return ns.Inventory.IsBankBag(bag) end,
	IsLockedBag = function() return false end,
	FindFreeSlotFor = function()
		if ns.Bank.IsOpen() then
			return ns.Inventory.FindFreeBankSlot()
		end
	end,
	fullMessage = L.BANK_FULL,
	isBank = true,
	-- Items can only be moved into the bank while at it.
	AcceptsDrops = function() return ns.Bank.IsOpen() end,
	noSectionsHint = true,
	CreateButtons = CreateButtons,
	OpenMenu = function(owner) ns.Menu.OpenBankMenu(owner) end,
	Sort = Sort,
	sortTitle = L.SORT_BANK,
	sortDesc = L.SORT_BANK_DESC,
	-- Closing the window at the bank ends the banker conversation, like Blizzard's bank.
	OnHide = function()
		if ns.Bank.IsOpen() and C_Bank.CloseBankFrame then
			C_Bank.CloseBankFrame()
		end
	end,
	Style = Style,
	FooterRightText = FooterRightText,
	FooterExtra = FooterExtra,
})
ns.BankFrame = window

-- Right-click on the bags' title, or /bs bank.
function window.Toggle()
	if window.IsShown() then
		window.Hide()
	else
		window.Show()
	end
end

-- Until it's been moved, it opens next to the bags each time.
local showWindow = window.Show
function window.Show()
	if not ns.db.bankFrame then
		window.RestorePosition()
	end
	showWindow()
end

-- Kept for callers from before the bank window shared the bags' code.
window.Refresh = window.RequestRefresh
