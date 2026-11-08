-- The alt viewer: another character's bags or bank, read only, sorted into that
-- character's own sections. Opened from the character button in the bags' title bar (or
-- /bs alts). Uses the same window code as the bags and bank, with the bags' or the bank's
-- layout settings depending on which it shows. Click the title to pick another character;
-- the Bags and Bank buttons at the bottom switch between the two.

local _, ns = ...
local L = ns.L
local Alts = ns.Alts

local window -- set below
local cfg -- the window's config; its layout keys follow the view
local currentKey -- the character shown
local view = "bags" -- "bags" | "bank"
local bagsTab, bankTab, tabDivider

local TAB_WIDTH = 70
local TAB_HEIGHT = 22
local TAB_ROW_GAP = 6

local function Entry()
	return currentKey and ns.db.characters and ns.db.characters[currentKey]
end

local function UpdateTitle()
	local entry = Entry()
	if not entry then
		window.SetTitle(L.ALTS)
		return
	end
	local name = Alts.DisplayName(entry, true)
	window.SetTitle((view == "bank" and L.ALT_BANK_TITLE or L.ALT_BAGS_TITLE):format(name))
end

-- Bags and bank follow your own layout and column settings for each.
local function ApplyView()
	cfg.layoutKey = view == "bank" and "bankLayout" or "layout"
	cfg.columnsKey = view == "bank" and "bankColumns" or "columns"
	UpdateTitle()
end

local function SelectTab(button, selected)
	if selected then
		button:Disable()
	else
		button:Enable()
	end
end

-- Footer row: Bags and Bank buttons.
local function FooterExtra(main, pad, bottom)
	if not bagsTab then
		local function MakeTab(text, which)
			local button = CreateFrame("Button", nil, main.Chrome, "UIPanelButtonTemplate")
			button:SetSize(TAB_WIDTH, TAB_HEIGHT)
			button:SetText(text)
			button:SetScript("OnClick", function() window.SetView(which) end)
			return button
		end
		bagsTab = MakeTab(L.BAGS, "bags")
		bankTab = MakeTab(L.BANK, "bank")
		tabDivider = main.Chrome:CreateTexture(nil, "ARTWORK")
		tabDivider:SetColorTexture(1, 1, 1, 0.12)
		tabDivider:SetHeight(1)
	end
	bagsTab:ClearAllPoints()
	bagsTab:SetPoint("BOTTOMLEFT", main.Chrome, "BOTTOMLEFT", pad, bottom)
	bankTab:ClearAllPoints()
	bankTab:SetPoint("LEFT", bagsTab, "RIGHT", 4, 0)
	SelectTab(bagsTab, view == "bags")
	SelectTab(bankTab, view == "bank")
	local height = TAB_HEIGHT + TAB_ROW_GAP
	tabDivider:ClearAllPoints()
	tabDivider:SetPoint("BOTTOMLEFT", main.Chrome, "BOTTOMLEFT", pad, bottom + height - TAB_ROW_GAP / 2)
	tabDivider:SetPoint("BOTTOMRIGHT", main.Chrome, "BOTTOMRIGHT", -pad, bottom + height - TAB_ROW_GAP / 2)
	return height
end

-- Right side of the footer: the character's gold with their bags, how old the bank
-- snapshot is with their bank.
local function FooterRightText()
	local entry = Entry()
	if not entry then
		return ""
	end
	if view == "bank" then
		if not entry.bank then
			return L.ALT_BANK_EMPTY
		end
		return L.BANK_UPDATED:format(ns.Bank.FormatAge(math.max(time() - (entry.bank.updated or 0), 0), L))
	end
	return GetMoneyString(entry.money or 0, true)
end

local NO_DB = ns.Rules.NewCharDB()

cfg = {
	name = "BagSectionsAltFrame",
	title = L.ALTS,
	layoutKey = "layout",
	columnsKey = "columns",
	scaleKey = "scale",
	positionKey = "altFrame",
	PlaceByDefault = function(main)
		if BagSectionsFrame and BagSectionsFrame:IsShown() then
			main:SetPoint("BOTTOMRIGHT", BagSectionsFrame, "BOTTOMLEFT", -12, 0)
		else
			main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	end,
	GetDB = function()
		local entry = Entry()
		return entry and Alts.SectionDB(entry, view) or NO_DB
	end,
	GetPartnerDB = function() return nil end,
	Scan = function()
		local entry = Entry()
		if not entry then
			return {}
		end
		return Alts.Slots(entry, view, ns.Inventory.IsReagent)
	end,
	BuildOptions = function()
		if view == "bank" then
			return {}
		end
		return { hideKeyring = not ns.db.showKeyring, bagReagents = ns.db.bagReagents }
	end,
	-- Nothing on the cursor ever belongs to the character being looked at.
	IsOwnBag = function() return false end,
	IsLockedBag = function() return true end,
	FindFreeSlotFor = function() end,
	fullMessage = "",
	readOnly = true,
	noSearch = true,
	AcceptsDrops = function() return false end,
	CreateButtons = function(content)
		local cached = ns.ItemButtons.NewCachedSet(content)
		return {
			ForSlot = cached.ForSlot,
			HideExcept = cached.HideExcept,
			UpdateShown = function() end,
			Enumerate = function() return pairs({}) end,
			UpdateCooldowns = function() end,
		}
	end,
	OpenMenu = function(owner) ns.Menu.OpenAltViewerMenu(owner) end,
	OnTitleClick = function(owner) ns.Menu.OpenAltsMenu(owner) end,
	titleHint = L.ALT_TITLE_HINT,
	Style = function(main) ns.Frame.StyleWindow(main) end,
	FooterRightText = FooterRightText,
	FooterExtra = FooterExtra,
}

window = ns.Frame.NewWindow(cfg)
ns.AltFrame = window

-- Shows `key`'s bags (or bank, for view "bank").
function window.ShowCharacter(key, newView)
	currentKey = key
	if newView then
		view = newView
	end
	ApplyView()
	if window.IsShown() then
		window.RequestRefresh()
	else
		window.Show()
	end
end

function window.SetView(newView)
	view = newView
	ApplyView()
	window.RequestRefresh()
end

function window.GetView()
	return view
end

function window.GetCharacter()
	return currentKey
end

-- After a character is forgotten: show another one, or close.
function window.CharacterForgotten(key)
	if key ~= currentKey then
		return
	end
	local first = Alts.GetAll()[1]
	if first then
		window.ShowCharacter(first.key)
	else
		currentKey = nil
		window.Hide()
	end
end
