-- Context menus and name prompts.

local _, ns = ...
local L = ns.L
local Rules = ns.Rules

local Menu = {}
ns.Menu = Menu

local function Changed()
	ns.RequestRefresh()
end

StaticPopupDialogs["BAGSECTIONS_SECTION_NAME"] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 40,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog, data)
		local editBox = dialog:GetEditBox()
		editBox:SetText(data and data.name or "")
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	OnAccept = function(dialog, data)
		local name = strtrim(dialog:GetEditBox():GetText() or "")
		if name ~= "" and data and data.onAccept then
			data.onAccept(name)
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		if dialog:GetButton1():IsEnabled() then
			dialog:GetButton1():Click()
		end
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
}

StaticPopupDialogs["BAGSECTIONS_CONFIRM"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(_, data)
		data.onAccept()
	end,
}

StaticPopupDialogs["BAGSECTIONS_DELETE_SECTION"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(_, data)
		Rules.DeleteSection(ns.charDB, data.id)
		Changed()
	end,
}

function Menu.PromptNewSection(onCreated)
	StaticPopup_Show("BAGSECTIONS_SECTION_NAME", L.NEW_SECTION_PROMPT, nil, {
		onAccept = function(name)
			local section = Rules.CreateSection(ns.charDB, name, ns.NewSectionsBelowRest())
			Changed()
			if onCreated then
				onCreated(section)
			end
		end,
	})
end

function Menu.PromptRename(section)
	StaticPopup_Show("BAGSECTIONS_SECTION_NAME", L.RENAME_SECTION_PROMPT:format(section.name), nil, {
		name = section.name,
		onAccept = function(name)
			Rules.RenameSection(ns.charDB, section.id, name)
			Changed()
		end,
	})
end

function Menu.DeleteSection(section, itemCount)
	if itemCount and itemCount > 0 then
		StaticPopup_Show("BAGSECTIONS_DELETE_SECTION", L.DELETE_SECTION_CONFIRM:format(section.name), nil, { id = section.id })
	else
		Rules.DeleteSection(ns.charDB, section.id)
		Changed()
	end
end

-- Right-click on a section header.
function Menu.OpenSectionMenu(owner, group)
	local section = Rules.GetSection(ns.charDB, group.key)
	if not section then
		return
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(section.name)
		root:CreateButton(L.RENAME_SECTION, function() Menu.PromptRename(section) end)
		root:CreateButton(section.collapsed and L.EXPAND or L.COLLAPSE, function()
			section.collapsed = not section.collapsed
			Changed()
		end)
		if ns.db.layout == "semicompact" then
			-- Semi-compact places sections by dragging them (see Rearrange sections).
			root:CreateButton(L.REARRANGE_UNLOCK, function() ns.Frame.SetRearranging(true) end)
		else
			root:CreateButton(L.MOVE_UP, function()
				Rules.MoveSection(ns.charDB, section.id, -1)
				Changed()
			end)
			root:CreateButton(L.MOVE_DOWN, function()
				Rules.MoveSection(ns.charDB, section.id, 1)
				Changed()
			end)
			root:CreateButton(section.below and L.MOVE_ABOVE_REST or L.MOVE_BELOW_REST, function()
				Rules.SetSectionBelow(ns.charDB, section.id, not section.below)
				Changed()
			end)
		end
		root:CreateButton(L.COLOUR, function() Menu.PickColour(section) end)
		root:CreateDivider()
		root:CreateButton(L.CLEAR_SECTION, function()
			Rules.ClearSection(ns.charDB, section.id)
			Changed()
		end)
		root:CreateButton(L.DELETE_SECTION, function() Menu.DeleteSection(section, group.count) end)
	end)
end

-- Opens Blizzard's colour picker for a section's outline colour (compact layout).
function Menu.PickColour(section)
	local c = section.color or Rules.PALETTE[1]
	local id = section.id
	ColorPickerFrame:SetupColorPickerAndShow({
		r = c.r, g = c.g, b = c.b,
		hasOpacity = false,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			Rules.SetSectionColor(ns.charDB, id, r, g, b)
			Changed()
		end,
		cancelFunc = function(previous)
			Rules.SetSectionColor(ns.charDB, id, previous.r, previous.g, previous.b)
			Changed()
		end,
	})
end

-- Profiles (account wide): saved section lists that any character can load.

local function ProfileNames()
	local names = {}
	for name in pairs(ns.db.profiles) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

function Menu.PromptSaveProfile()
	StaticPopup_Show("BAGSECTIONS_SECTION_NAME", L.PROFILE_SAVE_PROMPT, nil, {
		onAccept = function(name)
			local function Save()
				ns.db.profiles[name] = Rules.ExportProfile(ns.charDB)
				ns.Print(L.PROFILE_SAVED:format(name))
			end
			if ns.db.profiles[name] then
				StaticPopup_Show("BAGSECTIONS_CONFIRM", L.PROFILE_OVERWRITE:format(name), nil, { onAccept = Save })
			else
				Save()
			end
		end,
	})
end

function Menu.LoadProfile(name)
	local profile = ns.db.profiles[name]
	if not profile then
		return
	end
	local function Load()
		Rules.ApplyProfile(ns.charDB, profile)
		-- The profile places the Quest Items section; whether it exists is account wide.
		ns.SyncAutoQuest()
		ns.Print(L.PROFILE_LOADED:format(name))
		Changed()
	end
	local removed = Rules.CountRemovedByProfile(ns.charDB, profile)
	if removed > 0 then
		StaticPopup_Show("BAGSECTIONS_CONFIRM", L.PROFILE_LOAD_CONFIRM:format(name, removed), nil, { onAccept = Load })
	else
		Load()
	end
end

function Menu.DeleteProfile(name)
	StaticPopup_Show("BAGSECTIONS_CONFIRM", L.PROFILE_DELETE_CONFIRM:format(name), nil, {
		onAccept = function() ns.db.profiles[name] = nil end,
	})
end

-- Share codes: copy a profile as text, or paste one in.
StaticPopupDialogs["BAGSECTIONS_SHARE_CODE"] = {
	text = "%s",
	button1 = OKAY,
	hasEditBox = 1,
	maxLetters = 0,
	editBoxWidth = 320,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog, data)
		local editBox = dialog:GetEditBox()
		editBox:SetText(data.code)
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	EditBoxOnTextChanged = function(editBox, data)
		-- Keep the code intact if a key is pressed by accident.
		if editBox:GetText() ~= data.code then
			editBox:SetText(data.code)
			editBox:HighlightText()
		end
	end,
	EditBoxOnEnterPressed = function(editBox) editBox:GetParent():Hide() end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
}

StaticPopupDialogs["BAGSECTIONS_IMPORT_CODE"] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 0,
	editBoxWidth = 320,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog)
		dialog:GetEditBox():SetText("")
		dialog:GetEditBox():SetFocus()
	end,
	OnAccept = function(dialog)
		Menu.ImportCode(dialog:GetEditBox():GetText())
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		Menu.ImportCode(editBox:GetText())
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
}

function Menu.ShareProfile(name)
	local profile = ns.db.profiles[name]
	if profile then
		StaticPopup_Show("BAGSECTIONS_SHARE_CODE", L.PROFILE_SHARE_PROMPT:format(name), nil, { code = ns.Share.Encode(name, profile) })
	end
end

-- Saves a pasted code as a profile (renamed if that name is taken). Returns the name used.
function Menu.ImportCode(code)
	local name, profile = ns.Share.Decode(code)
	if not name then
		ns.Print(profile == "damaged" and L.PROFILE_IMPORT_DAMAGED or L.PROFILE_IMPORT_INVALID)
		return nil
	end
	local unique, n = name, 2
	while ns.db.profiles[unique] do
		unique = ("%s (%d)"):format(name, n)
		n = n + 1
	end
	ns.db.profiles[unique] = profile
	ns.Print(L.PROFILE_IMPORTED:format(unique))
	return unique
end

-- Adds Save / Load / Share / Import / Delete entries to a menu description.
function Menu.AddProfileEntries(root)
	root:CreateButton(L.PROFILE_SAVE, function() Menu.PromptSaveProfile() end)
	local names = ProfileNames()
	local load = root:CreateButton(L.PROFILE_LOAD)
	local share = root:CreateButton(L.PROFILE_SHARE)
	root:CreateButton(L.PROFILE_IMPORT, function()
		StaticPopup_Show("BAGSECTIONS_IMPORT_CODE", L.PROFILE_IMPORT_PROMPT)
	end)
	local delete = root:CreateButton(L.PROFILE_DELETE)
	if #names == 0 then
		load:SetEnabled(false)
		share:SetEnabled(false)
		delete:SetEnabled(false)
	end
	for _, name in ipairs(names) do
		load:CreateButton(name, function() Menu.LoadProfile(name) end)
		share:CreateButton(name, function() Menu.ShareProfile(name) end)
		delete:CreateButton(name, function() Menu.DeleteProfile(name) end)
	end
end

function Menu.OpenProfileMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L.PROFILES)
		Menu.AddProfileEntries(root)
	end)
end

function Menu.SetLayout(layout)
	ns.db.layout = layout
	Changed()
end

-- Options button in the title bar.
function Menu.OpenMainMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L.ADDON_NAME)
		root:CreateButton(L.NEW_SECTION, function() Menu.PromptNewSection() end)
		root:CreateCheckbox(L.SHOW_EMPTY, function()
			return ns.db.showEmptySections
		end, function()
			ns.db.showEmptySections = not ns.db.showEmptySections
			Changed()
		end)
		root:CreateCheckbox(L.QUEST_SECTION, function()
			return ns.db.autoQuest
		end, function()
			ns.SetAutoQuest(not ns.db.autoQuest)
		end)
		root:CreateCheckbox(L.SHOW_KEYRING, function()
			return ns.db.showKeyring
		end, function()
			ns.db.showKeyring = not ns.db.showKeyring
			Changed()
		end)
		local function IsLayout(name) return (ns.db.layout or "default") == name end
		if IsLayout("semicompact") then
			root:CreateCheckbox(L.REARRANGE, function()
				return ns.Frame.IsRearranging()
			end, function()
				ns.Frame.SetRearranging(not ns.Frame.IsRearranging())
			end)
		end
		local layout = root:CreateButton(L.LAYOUT)
		layout:CreateRadio(L.LAYOUT_DEFAULT, function() return IsLayout("default") end, function() Menu.SetLayout("default") end)
		layout:CreateRadio(L.LAYOUT_SEMICOMPACT, function() return IsLayout("semicompact") end, function() Menu.SetLayout("semicompact") end)
		layout:CreateRadio(L.LAYOUT_COMPACT, function() return IsLayout("compact") end, function() Menu.SetLayout("compact") end)
		if IsLayout("semicompact") then
			layout:CreateDivider()
			layout:CreateButton(L.RESET_ROWS, function()
				ns.Rows.Reset(ns.charDB)
				Changed()
			end)
		end
		Menu.AddProfileEntries(root:CreateButton(L.PROFILES))
		root:CreateDivider()
		root:CreateButton(L.SETTINGS, function() ns.Options.Open() end)
	end)
end

-- Options button in the bank window's title bar.
function Menu.OpenBankMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L.BANK)
		local function IsLayout(name) return (ns.db.bankLayout or "default") == name end
		local function SetLayout(name)
			ns.db.bankLayout = name
			ns.BankFrame.RequestRefresh()
		end
		local layout = root:CreateButton(L.LAYOUT)
		layout:CreateRadio(L.LAYOUT_DEFAULT, function() return IsLayout("default") end, function() SetLayout("default") end)
		layout:CreateRadio(L.LAYOUT_SEMICOMPACT, function() return IsLayout("semicompact") end, function() SetLayout("semicompact") end)
		layout:CreateRadio(L.LAYOUT_COMPACT, function() return IsLayout("compact") end, function() SetLayout("compact") end)
		root:CreateDivider()
		root:CreateButton(L.SETTINGS, function() ns.Options.Open() end)
	end)
end

-- Alt+Right-click on an item.
function Menu.OpenItemMenu(button)
	local bag, slot = button:GetBagID(), button:GetID()
	if not ns.Inventory.IsSectionBag(bag) then
		return
	end
	local item = ns.Inventory.GetItem(bag, slot)
	if not item then
		return
	end
	local db = ns.charDB
	local current = Rules.Classify(db, item)
	local matched = Rules.MatchedKind(db, item)

	MenuUtil.CreateContextMenu(button, function(_, root)
		local name = C_Item.GetItemNameByID(item.itemID)
		root:CreateTitle(name or L.ADDON_NAME)

		local assign = root:CreateButton(L.ASSIGN_TO)
		for _, section in ipairs(db.sections) do
			assign:CreateRadio(section.name, function()
				return current == section.id
			end, function()
				Rules.Assign(db, item, section.id, matched or Rules.DefaultKind(item, ns.db))
				Changed()
			end)
		end
		if #db.sections > 0 then
			assign:CreateDivider()
		end
		assign:CreateButton(L.NEW_SECTION, function()
			Menu.PromptNewSection(function(section)
				Rules.Assign(db, item, section.id, Rules.DefaultKind(item, ns.db))
				Changed()
			end)
		end)

		if current ~= Rules.REST then
			root:CreateButton(L.REMOVE_FROM_SECTION, function()
				Rules.Unassign(db, item)
				Changed()
			end)

			local match = root:CreateButton(L.MATCH)
			local function SetKind(kind)
				Rules.Assign(db, item, current, kind)
				if kind == Rules.KIND_GUID and db.rules.byItemID[item.itemID] == current then
					db.rules.byItemID[item.itemID] = nil
				end
				Changed()
			end
			if item.guid then
				match:CreateRadio(L.MATCH_GUID, function() return matched == Rules.KIND_GUID end, function() SetKind(Rules.KIND_GUID) end)
			end
			match:CreateRadio(L.MATCH_ITEMID, function() return matched == Rules.KIND_ITEMID end, function() SetKind(Rules.KIND_ITEMID) end)
		end
	end)
end
