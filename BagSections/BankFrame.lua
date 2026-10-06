-- The bank window: the same window as the bags (layouts, drag and drop, rearranging), with
-- its own layout setting, the bank's stone background and the bank's bag slots at the
-- bottom like Blizzard's bank. At the banker it replaces Blizzard's bank and works like
-- it (deposit and withdraw by right-click, drag and drop, sort, buy tabs). Anywhere else
-- it shows the last snapshot (see Bank.lua), read only.

local _, ns = ...
local L = ns.L

-- The bank's bag slots in the footer: item buttons at Blizzard's bank sizes
-- (BankItemButtonBagTemplate: scale 0.75, one every 50 units), with the slot frame art
-- sized to sit around the button instead of the item button's default 64x64.
local TAB_BUTTON_SCALE = 0.75
local TAB_STEP = 50 -- from one slot to the next, in the buttons' own units
local TAB_FRAME_SIZE = 46 -- the slot frame art
local TAB_ROW_GAP = 6
local BUY_BUTTON_WIDTH = 100

local window -- set below
local tabButtons = {}
local bankBackground, buyTab, buyCost, slotsLabel, tabDivider

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

-- Blizzard's bank look: its stone background, and its border with the round portrait corner
-- (the banker's face at the bank, a bank icon elsewhere). Opacity follows Settings; with
-- the Blizzard border turned off it uses the plain thin border like the bags.
local PORTRAIT_SIZE = 62
local BANK_ICON = "Interface\\Icons\\INV_Misc_Bag_10_Blue"
local portraitFrame, portrait

local function Style(main)
	ns.Frame.StyleWindow(main)
	if not bankBackground then
		bankBackground = main.BlizzardBackground:CreateTexture(nil, "BACKGROUND", nil, 1)
		bankBackground:SetPoint("TOPLEFT", main, "TOPLEFT", 3, -3)
		bankBackground:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -3, 3)
		bankBackground:SetAtlas("bank-frame-background")
		bankBackground:SetHorizTile(true)
		bankBackground:SetVertTile(true)
		NineSliceUtil.ApplyLayoutByName(main.BlizzardBorder, "PortraitFrameTemplate")
		-- Same size and place as Blizzard's portrait frames (PortraitFrameBaseTemplate).
		portraitFrame = CreateFrame("Frame", nil, main)
		portraitFrame:SetSize(1, 1)
		portraitFrame:SetPoint("TOPLEFT")
		portraitFrame:SetFrameLevel(main.BlizzardBorder:GetFrameLevel() - 1)
		portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
		portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait:SetPoint("TOPLEFT", -5, 7)
		local mask = portraitFrame:CreateMaskTexture()
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, 0)
		mask:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 4)
		portrait:AddMaskTexture(mask)
	end
	main.BlizzardBackground:Show()
	main.BlizzardBackground:SetAlpha(ns.db.backgroundAlpha or 0.94)
	main:SetBackdropColor(0, 0, 0, 0)
	portraitFrame:SetShown(ns.db.blizzardBorder ~= false)
end

local function UpdatePortrait()
	if not portrait then
		return
	end
	if ns.Bank.IsOpen() and UnitExists and UnitExists("npc") then
		SetPortraitTexture(portrait, "npc")
	else
		portrait:SetTexture(BANK_ICON)
	end
end

-- The bank's bag slots, like Blizzard's bank: slot 1 is the bank itself, slots 2 and up
-- take a bag once bought. { max = n, slots = { [slot] = { bought, icon, link } } }, live at
-- the bank, else from the snapshot.
local function BagSlots()
	if ns.Bank.IsOpen() then
		return ns.Bank.ReadBagSlots()
	end
	local snapshot = ns.charDB.bank
	if not snapshot then
		return { max = 0, slots = {} }
	end
	if snapshot.bagSlots then
		return snapshot.bagSlots
	end
	-- Snapshots from before bag slots were saved: what was bought, without the bags.
	local slots = {}
	for index = 2, #snapshot.tabs do
		slots[index] = { bought = true }
	end
	return { max = #snapshot.tabs, slots = slots }
end

local function NextSlotPrice()
	if not (ns.Bank.IsOpen() and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(Enum.BankType.Character)) then
		return nil
	end
	return C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(Enum.BankType.Character)
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

local function AskToBuySlot()
	local data = NextSlotPrice()
	if data then
		StaticPopup_Show("BAGSECTIONS_BUY_BANK_TAB", L.BANK_BUY_SLOT_CONFIRM:format(GetMoneyString(data.tabCost or 0, true)))
	end
end

-- A bag slot: pick up the bag in it, or drop a bag in, like Blizzard's bank bag slots.
local function PickupBagSlot(self)
	if self.bought and ns.Bank.IsOpen() then
		C_Container.PickupContainerItem(Enum.BagIndex.Characterbanktab, self.slotIndex)
	elseif not self.bought then
		AskToBuySlot()
	end
end

local function CreateBagSlotButton(main, index)
	local button = CreateFrame("ItemButton", nil, main.Chrome)
	button:SetScale(TAB_BUTTON_SCALE)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button.Background = button:CreateTexture(nil, "BACKGROUND")
	button.Background:SetAllPoints()
	button.Background:SetAtlas("bank-frame-bag-slot-bg")
	button:SetNormalAtlas("bank-frame-bag-slotframe")
	local frameArt = button:GetNormalTexture()
	frameArt:ClearAllPoints()
	frameArt:SetPoint("CENTER")
	frameArt:SetSize(TAB_FRAME_SIZE, TAB_FRAME_SIZE)
	button.Lock = button:CreateTexture(nil, "ARTWORK", nil, 1)
	button.Lock:SetAllPoints()
	button.Lock:SetAtlas("bankslot-icon-lock")
	button:SetScript("OnClick", PickupBagSlot)
	button:SetScript("OnDragStart", PickupBagSlot)
	button:SetScript("OnReceiveDrag", PickupBagSlot)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if not self.bought then
			GameTooltip:SetText(BANK_BAG_PURCHASE or L.BANK_SLOT_LOCKED)
		elseif ns.Bank.IsOpen() and self.hasBag then
			GameTooltip:SetBagItem(Enum.BagIndex.Characterbanktab, self.slotIndex)
		elseif self.link then
			GameTooltip:SetHyperlink(self.link)
		else
			GameTooltip:SetText(BANK_BAG or L.BANK_SLOT_EMPTY)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	tabButtons[index] = button
	return button
end

-- Footer row: "Bag slots:" and every bag slot (bought or locked), then the price of the
-- next slot and a Buy slot button, like Blizzard's bank. When it's too narrow for both,
-- the price and button get a line of their own above the slots. Returns the height used.
local function FooterExtra(main, pad, bottom)
	if not buyTab then
		buyTab = CreateFrame("Button", nil, main.Chrome, "UIPanelButtonTemplate")
		buyTab:SetSize(BUY_BUTTON_WIDTH, 22)
		buyTab:SetText(L.BANK_BUY_SLOT)
		buyTab:SetScript("OnClick", AskToBuySlot)
		buyCost = main.Chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		slotsLabel = main.Chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		slotsLabel:SetText(BAGSLOTTEXT_COLON or L.BANK_BAG_SLOTS)
		tabDivider = main.Chrome:CreateTexture(nil, "ARTWORK")
		tabDivider:SetColorTexture(1, 1, 1, 0.12)
		tabDivider:SetHeight(1)
	end
	local innerWidth = (main:GetWidth() or 0) - pad * 2
	local info = BagSlots()
	-- On screen: how far apart the slots are, and the height their frames need.
	local step = TAB_STEP * TAB_BUTTON_SCALE
	local slotSize = TAB_FRAME_SIZE * TAB_BUTTON_SCALE
	local labelWidth = (slotsLabel:GetStringWidth() or 0) + 8
	local count = math.max(info.max - 1, 0)
	local slotsWidth = labelWidth + count * step

	local price = NextSlotPrice()
	if price then
		local money = GetMoneyString(price.tabCost or 0, true)
		if price.canAfford == false then
			money = RED_FONT_COLOR_CODE and (RED_FONT_COLOR_CODE .. money .. "|r") or money
		end
		buyCost:SetText((COSTS_LABEL or L.BANK_COST) .. " " .. money)
	end
	local buyWidth = price and ((buyCost:GetStringWidth() or 0) + 8 + BUY_BUTTON_WIDTH) or 0
	local twoLines = price and slotsWidth + 12 + buyWidth > innerWidth
	local rowHeight = slotSize + 6
	local slotsBottom = bottom

	slotsLabel:SetShown(count > 0)
	slotsLabel:ClearAllPoints()
	slotsLabel:SetPoint("LEFT", main.Chrome, "BOTTOMLEFT", pad, slotsBottom + rowHeight / 2)
	for index = 2, info.max do
		local slot = info.slots[index] or {}
		local button = tabButtons[index] or CreateBagSlotButton(main, index)
		button.slotIndex = index
		button.bought = slot.bought or false
		button.hasBag = slot.icon ~= nil
		button.link = slot.link
		button:SetItemButtonTexture(slot.icon)
		button.Lock:SetShown(not button.bought)
		button:ClearAllPoints()
		-- Points are in the button's own (scaled) units.
		-- Centred in its step, in the button's own (scaled) units.
		local centreX = pad + labelWidth + (index - 2) * step + step / 2
		local centreY = slotsBottom + rowHeight / 2
		button:SetPoint("CENTER", main.Chrome, "BOTTOMLEFT", centreX / TAB_BUTTON_SCALE, centreY / TAB_BUTTON_SCALE)
		button:Show()
	end
	for index, button in pairs(tabButtons) do
		if index > info.max then
			button:Hide()
		end
	end

	local buyBottom = twoLines and (slotsBottom + rowHeight + 4) or slotsBottom
	buyTab:SetShown(price and true or false)
	buyCost:SetShown(price and true or false)
	buyTab:ClearAllPoints()
	buyTab:SetPoint("BOTTOMRIGHT", main.Chrome, "BOTTOMRIGHT", -pad, buyBottom + (rowHeight - 22) / 2)
	buyCost:ClearAllPoints()
	buyCost:SetPoint("RIGHT", buyTab, "LEFT", -8, 0)

	local height = (twoLines and (rowHeight * 2 + 4) or rowHeight) + TAB_ROW_GAP
	if count == 0 and not price then
		height = 0
	end
	tabDivider:SetShown(height > 0)
	tabDivider:ClearAllPoints()
	tabDivider:SetPoint("BOTTOMLEFT", main.Chrome, "BOTTOMLEFT", pad, bottom + height - TAB_ROW_GAP / 2)
	tabDivider:SetPoint("BOTTOMRIGHT", main.Chrome, "BOTTOMRIGHT", -pad, bottom + height - TAB_ROW_GAP / 2)
	UpdatePortrait()
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
	columnsKey = "bankColumns",
	scaleKey = "bankScale",
	positionKey = "bankFrame",
	-- Room for the portrait corner, like Blizzard's bank.
	titleHeight = 58,
	titleInset = 52,
	-- Until it's moved: next to the bags if they're open, else where Blizzard's bank opens.
	PlaceByDefault = function(main)
		if BagSectionsFrame and BagSectionsFrame:IsShown() then
			main:SetPoint("TOPRIGHT", BagSectionsFrame, "TOPLEFT", -12, 0)
		else
			main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)
		end
	end,
	GetDB = function() return ns.charDB.bankSections end,
	GetPartnerDB = function() return ns.charDB end,
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
