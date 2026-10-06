-- Settings panel under Options > AddOns > BagSections.

local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local category

local function AddCheckbox(key, name, tooltip, default, onChange)
	local setting = Settings.RegisterAddOnSetting(category, "BagSections_" .. key, key, ns.db, type(default), name, default)
	if onChange then
		setting:SetValueChangedCallback(onChange)
	end
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddSlider(key, name, tooltip, default, minValue, maxValue, step, formatter, onChange)
	local setting = Settings.RegisterAddOnSetting(category, "BagSections_" .. key, key, ns.db, type(default), name, default)
	setting:SetValueChangedCallback(onChange)
	local options = Settings.CreateSliderOptions(minValue, maxValue, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
	Settings.CreateSlider(category, setting, options, tooltip)
end

function Options.Init()
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_NAME)

	local function Refresh() ns.RequestRefresh() end
	local function Appearance() ns.ApplyAppearance() end
	local function Fonts() ns.Frame.ApplyFonts() end
	local percent = function(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end
	-- Settings are listed in the order they're added, so each group starts with a header.
	local function Header(title, tooltip)
		if layout then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title, tooltip))
		end
	end

	-- Layout: how the window is arranged.
	Header(L.GROUP_LAYOUT)
	local layoutSetting = Settings.RegisterAddOnSetting(category, "BagSections_layout", "layout", ns.db, Settings.VarType.String, L.LAYOUT, ns.DEFAULTS.layout)
	layoutSetting:SetValueChangedCallback(Refresh)
	Settings.CreateDropdown(category, layoutSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("default", L.LAYOUT_DEFAULT)
		container:Add("semicompact", L.LAYOUT_SEMICOMPACT)
		container:Add("compact", L.LAYOUT_COMPACT)
		return container:GetData()
	end, L.OPT_LAYOUT_DESC)
	local bankLayoutSetting = Settings.RegisterAddOnSetting(category, "BagSections_bankLayout", "bankLayout", ns.db, Settings.VarType.String, L.BANK_LAYOUT, ns.DEFAULTS.bankLayout)
	bankLayoutSetting:SetValueChangedCallback(Refresh)
	Settings.CreateDropdown(category, bankLayoutSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("default", L.LAYOUT_DEFAULT)
		container:Add("semicompact", L.LAYOUT_SEMICOMPACT)
		container:Add("compact", L.LAYOUT_COMPACT)
		return container:GetData()
	end, L.OPT_BANK_LAYOUT_DESC)
	AddSlider("columns", L.OPT_COLUMNS, L.OPT_COLUMNS_DESC, ns.DEFAULTS.columns, 6, 24, 1, nil, Refresh)
	AddSlider("scale", L.OPT_SCALE, L.OPT_SCALE_DESC, ns.DEFAULTS.scale, 0.6, 1.5, 0.05, percent, function() ns.ApplyScale() end)
	AddSlider("semiRowSpacing", L.OPT_SEMI_ROW_SPACING, L.OPT_SEMI_ROW_SPACING_DESC, ns.DEFAULTS.semiRowSpacing, 4, 30, 1, nil, Refresh)
	AddSlider("semiColumnSpacing", L.OPT_SEMI_COLUMN_SPACING, L.OPT_SEMI_COLUMN_SPACING_DESC, ns.DEFAULTS.semiColumnSpacing, 6, 40, 1, nil, Refresh)

	-- Sections: what goes where.
	Header(L.GROUP_SECTIONS)
	local Rules = ns.Rules
	local questSetting = Settings.RegisterProxySetting(category, "BagSections_autoQuest", Settings.VarType.Boolean,
		L.QUEST_SECTION, ns.DEFAULTS.autoQuest,
		function() return ns.db.autoQuest end,
		function(value) ns.SetAutoQuest(value) end)
	Settings.CreateCheckbox(category, questSetting, L.OPT_QUEST_SECTION_DESC)
	AddCheckbox("bagReagents", L.OPT_BAG_REAGENTS, L.OPT_BAG_REAGENTS_DESC, ns.DEFAULTS.bagReagents, Refresh)
	local restSetting = Settings.RegisterAddOnSetting(category, "BagSections_restPosition", "restPosition", ns.db, Settings.VarType.String, L.REST_POSITION, ns.DEFAULTS.restPosition)
	Settings.CreateDropdown(category, restSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("bottom", L.REST_POSITION_BOTTOM)
		container:Add("top", L.REST_POSITION_TOP)
		return container:GetData()
	end, L.OPT_REST_POSITION_DESC)
	-- Stored as a rule kind, shown as a checkbox.
	local gearSetting = Settings.RegisterProxySetting(category, "BagSections_gearExact", Settings.VarType.Boolean,
		L.OPT_GEAR_EXACT, true,
		function() return ns.db.equippableRule == Rules.KIND_GUID end,
		function(value) ns.db.equippableRule = value and Rules.KIND_GUID or Rules.KIND_ITEMID end)
	Settings.CreateCheckbox(category, gearSetting, L.OPT_GEAR_EXACT_DESC)
	AddCheckbox("showEmptySections", L.SHOW_EMPTY, L.OPT_SHOW_EMPTY_DESC, ns.DEFAULTS.showEmptySections, Refresh)
	AddCheckbox("showKeyring", L.SHOW_KEYRING, L.OPT_SHOW_KEYRING_DESC, ns.DEFAULTS.showKeyring, Refresh)
	AddCheckbox("sectionTooltips", L.OPT_SECTION_TOOLTIPS, L.OPT_SECTION_TOOLTIPS_DESC, ns.DEFAULTS.sectionTooltips)

	-- Appearance: background, border, outlines.
	Header(L.GROUP_APPEARANCE)
	local backgroundSetting = Settings.RegisterAddOnSetting(category, "BagSections_backgroundStyle", "backgroundStyle", ns.db, Settings.VarType.String, L.OPT_BACKGROUND, ns.DEFAULTS.backgroundStyle)
	backgroundSetting:SetValueChangedCallback(Appearance)
	Settings.CreateDropdown(category, backgroundSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("dark", L.OPT_BACKGROUND_DARK)
		container:Add("blizzard", L.OPT_BACKGROUND_BLIZZARD)
		return container:GetData()
	end, L.OPT_BACKGROUND_DESC)
	AddSlider("backgroundAlpha", L.OPT_BACKGROUND_ALPHA, L.OPT_BACKGROUND_ALPHA_DESC, ns.DEFAULTS.backgroundAlpha, 0, 1, 0.05, percent, Appearance)
	AddCheckbox("blizzardBorder", L.OPT_BLIZZARD_BORDER, L.OPT_BLIZZARD_BORDER_DESC, ns.DEFAULTS.blizzardBorder, Appearance)
	AddSlider("outlineAlpha", L.OPT_OUTLINE_ALPHA, L.OPT_OUTLINE_ALPHA_DESC, ns.DEFAULTS.outlineAlpha, 0.1, 1, 0.05, percent, Refresh)

	-- Text size.
	Header(L.GROUP_TEXT)
	AddSlider("sectionFontSize", L.OPT_SECTION_FONT, L.OPT_SECTION_FONT_DESC, ns.DEFAULTS.sectionFontSize, 8, 20, 1, nil, Fonts)
	AddSlider("moneyFontSize", L.OPT_MONEY_FONT, L.OPT_MONEY_FONT_DESC, ns.DEFAULTS.moneyFontSize, 8, 20, 1, nil, Fonts)
	AddSlider("slotsFontSize", L.OPT_SLOTS_FONT, L.OPT_SLOTS_FONT_DESC, ns.DEFAULTS.slotsFontSize, 8, 20, 1, nil, Fonts)

	-- General.
	Header(L.GROUP_GENERAL)
	AddCheckbox("takeOverBags", L.OPT_TAKEOVER, L.OPT_TAKEOVER_DESC, ns.DEFAULTS.takeOverBags)
	AddCheckbox("replaceBank", L.OPT_REPLACE_BANK, L.OPT_REPLACE_BANK_DESC, ns.DEFAULTS.replaceBank)

	Header(L.PROFILES, L.PROFILES_DESC)
	if layout then
		layout:AddInitializer(CreateSettingsButtonInitializer(L.PROFILES, L.PROFILES_BUTTON, function(button)
			ns.Menu.OpenProfileMenu(button)
		end, L.PROFILES_DESC, true))
	end

	Settings.RegisterAddOnCategory(category)

	-- Show the bags as a live preview while this settings page is open (see
	-- Frame.SetPreview). Only reads the panel's state; nothing of Blizzard's is hooked.
	if SettingsPanel then
		local watcher = CreateFrame("Frame")
		watcher:SetScript("OnUpdate", function()
			local onOurPage = SettingsPanel:IsShown() and SettingsPanel:GetCurrentCategory() == category
			ns.Frame.SetPreview(onOurPage and true or false)
		end)
	end
end

function Options.Open()
	if category then
		Settings.OpenToCategory(category:GetID())
	end
end
