-- The alt viewer: another character's bags and bank side by side, read only, each sorted
-- into that character's own sections. Opened from the character button in the bags' title
-- bar (or /bs alts). Two windows made with the same code as the bags and bank: the bags
-- column (ns.AltFrame), which can be moved and remembers where it was, and the bank column
-- (ns.AltBankFrame), docked to its left like Blizzard's bank sits left of the bags. They
-- open, close and move together. Each uses your own bags' or bank's layout settings. Click
-- either title to pick another character.

local _, ns = ...
local L = ns.L
local Alts = ns.Alts

local currentKey -- the character shown
local bagsColumn, bankColumn -- set below

local function Entry()
	return currentKey and ns.db.characters and ns.db.characters[currentKey]
end

local NO_DB = ns.Rules.NewCharDB()

-- One column: view is "bags" or "bank".
local function NewColumn(view, settings)
	local isBank = view == "bank"
	local function FooterRightText()
		local entry = Entry()
		if not entry then
			return ""
		end
		if isBank then
			if not entry.bank then
				return L.ALT_BANK_EMPTY
			end
			return L.BANK_UPDATED:format(ns.Bank.FormatAge(math.max(time() - (entry.bank.updated or 0), 0), L))
		end
		return GetMoneyString(entry.money or 0, true)
	end
	local cfg = {
		title = L.ALTS,
		-- Bags and bank follow your own layout and column settings for each.
		layoutKey = isBank and "bankLayout" or "layout",
		columnsKey = isBank and "bankColumns" or "columns",
		scaleKey = "scale",
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
			if isBank then
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
		-- Closing either column closes both.
		OnHide = function()
			local other = isBank and bagsColumn or bankColumn
			if other.IsShown() then
				other.Hide()
			end
		end,
	}
	for key, value in pairs(settings) do
		cfg[key] = value
	end
	local column = ns.Frame.NewWindow(cfg)
	function column.UpdateTitle()
		local entry = Entry()
		if not entry then
			column.SetTitle(L.ALTS)
			return
		end
		column.SetTitle((isBank and L.ALT_BANK_TITLE or L.ALT_BAGS_TITLE):format(Alts.DisplayName(entry, true)))
	end
	return column
end

bagsColumn = NewColumn("bags", {
	name = "BagSectionsAltFrame",
	positionKey = "altFrame",
	-- Until it's moved: left of the bags if they're open (with room for the bank column).
	PlaceByDefault = function(main)
		if BagSectionsFrame and BagSectionsFrame:IsShown() then
			main:SetPoint("BOTTOMRIGHT", BagSectionsFrame, "BOTTOMLEFT", -12, 0)
		else
			main:SetPoint("TOPLEFT", UIParent, "CENTER", 0, 200)
		end
	end,
})

bankColumn = NewColumn("bank", {
	name = "BagSectionsAltBankFrame",
	-- Never saved: it always sits docked to the bags column, and dragging it moves both.
	positionKey = "altBankFrameDocked",
	PlaceByDefault = function(main)
		main:SetPoint("TOPRIGHT", bagsColumn.GetMainFrame(), "TOPLEFT", -6, 0)
	end,
	MoveWith = function() return bagsColumn end,
})

local window = bagsColumn
ns.AltFrame = window
ns.AltBankFrame = bankColumn

local initBags = window.Init
function window.Init()
	initBags()
	bankColumn.Init()
end

-- Shows `key`'s bags and bank.
function window.ShowCharacter(key)
	currentKey = key
	for _, column in ipairs({ bagsColumn, bankColumn }) do
		column.UpdateTitle()
		if column.IsShown() then
			column.RequestRefresh()
		else
			column.Show()
		end
	end
end

local hideBags = window.Hide
function window.Hide()
	hideBags()
	bankColumn.Hide()
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
