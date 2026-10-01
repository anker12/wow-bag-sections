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

	local layoutSetting = Settings.RegisterAddOnSetting(category, "BagSections_layout", "layout", ns.db, Settings.VarType.String, L.LAYOUT, ns.DEFAULTS.layout)
	layoutSetting:SetValueChangedCallback(Refresh)
	Settings.CreateDropdown(category, layoutSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("default", L.LAYOUT_DEFAULT)
		container:Add("semicompact", L.LAYOUT_SEMICOMPACT)
		container:Add("compact", L.LAYOUT_COMPACT)
		return container:GetData()
	end, L.OPT_LAYOUT_DESC)

	local restSetting = Settings.RegisterAddOnSetting(category, "BagSections_restPosition", "restPosition", ns.db, Settings.VarType.String, L.REST_POSITION, ns.DEFAULTS.restPosition)
	Settings.CreateDropdown(category, restSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("bottom", L.REST_POSITION_BOTTOM)
		container:Add("top", L.REST_POSITION_TOP)
		return container:GetData()
	end, L.OPT_REST_POSITION_DESC)

	AddSlider("columns", L.OPT_COLUMNS, L.OPT_COLUMNS_DESC, ns.DEFAULTS.columns, 6, 24, 1, nil, Refresh)
	AddSlider("scale", L.OPT_SCALE, L.OPT_SCALE_DESC, ns.DEFAULTS.scale, 0.6, 1.5, 0.05, function(value)
		return ("%d%%"):format(math.floor(value * 100 + 0.5))
	end, function() ns.Frame.ApplyScale() end)
	AddCheckbox("showEmptySections", L.SHOW_EMPTY, L.OPT_SHOW_EMPTY_DESC, ns.DEFAULTS.showEmptySections, Refresh)
	AddCheckbox("showKeyring", L.SHOW_KEYRING, L.OPT_SHOW_KEYRING_DESC, ns.DEFAULTS.showKeyring, Refresh)

	-- Stored as a rule kind, shown as a checkbox.
	local Rules = ns.Rules
	local gearSetting = Settings.RegisterProxySetting(category, "BagSections_gearExact", Settings.VarType.Boolean,
		L.OPT_GEAR_EXACT, true,
		function() return ns.db.equippableRule == Rules.KIND_GUID end,
		function(value) ns.db.equippableRule = value and Rules.KIND_GUID or Rules.KIND_ITEMID end)
	Settings.CreateCheckbox(category, gearSetting, L.OPT_GEAR_EXACT_DESC)

	-- Per character, so it reads from the character's saved data.
	local questSetting = Settings.RegisterProxySetting(category, "BagSections_autoQuest", Settings.VarType.Boolean,
		L.QUEST_SECTION, false,
		function() return ns.charDB.autoQuest end,
		function(value)
			Rules.SetAutoQuest(ns.charDB, value, L.QUEST_ITEMS, ns.NewSectionsBelowRest())
			Refresh()
		end)
	Settings.CreateCheckbox(category, questSetting, L.OPT_QUEST_SECTION_DESC)

	AddCheckbox("takeOverBags", L.OPT_TAKEOVER, L.OPT_TAKEOVER_DESC, ns.DEFAULTS.takeOverBags)

	if layout then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.PROFILES, L.PROFILES_DESC))
		layout:AddInitializer(CreateSettingsButtonInitializer(L.PROFILES, L.PROFILES_BUTTON, function(button)
			ns.Menu.OpenProfileMenu(button)
		end, L.PROFILES_DESC, true))
	end

	Settings.RegisterAddOnCategory(category)
end

function Options.Open()
	if category then
		Settings.OpenToCategory(category:GetID())
	end
end
