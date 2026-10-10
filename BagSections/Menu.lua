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
	OnCancel = function(_, data)
		if data and data.onCancel then
			data.onCancel()
		end
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
		Rules.DeleteSection(data.db, data.id)
		Changed()
	end,
}

-- The window a menu was opened from (the bags unless given), and its section data.
local function DB(window)
	return (window or ns.Frame).GetDB()
end

function Menu.PromptNewSection(onCreated, window)
	local db = DB(window)
	StaticPopup_Show("BAGSECTIONS_SECTION_NAME", L.NEW_SECTION_PROMPT, nil, {
		onAccept = function(name)
			local section = Rules.CreateSection(db, name, ns.NewSectionsBelowRest())
			Changed()
			if onCreated then
				onCreated(section)
			end
		end,
	})
end

function Menu.PromptRename(section, window)
	local db = DB(window)
	StaticPopup_Show("BAGSECTIONS_SECTION_NAME", L.RENAME_SECTION_PROMPT:format(section.name), nil, {
		name = section.name,
		onAccept = function(name)
			Rules.RenameSection(db, section.id, name)
			Changed()
		end,
	})
end

function Menu.DeleteSection(section, itemCount, window)
	local db = DB(window)
	if itemCount and itemCount > 0 then
		StaticPopup_Show("BAGSECTIONS_DELETE_SECTION", L.DELETE_SECTION_CONFIRM:format(section.name), nil, { id = section.id, db = db })
	else
		Rules.DeleteSection(db, section.id)
		Changed()
	end
end

-- Right-click on a section header.
function Menu.OpenSectionMenu(owner, group, window)
	window = window or ns.Frame
	local db = window.GetDB()
	local section = Rules.GetSection(db, group.key)
	if not section then
		return
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(section.name)
		root:CreateButton(L.RENAME_SECTION, function() Menu.PromptRename(section, window) end)
		root:CreateButton(section.collapsed and L.EXPAND or L.COLLAPSE, function()
			section.collapsed = not section.collapsed
			Changed()
		end)
		if ns.db[window.isBank and "bankLayout" or "layout"] == "semicompact" then
			-- Semi-compact places sections by dragging them (see Rearrange sections).
			root:CreateButton(L.REARRANGE_UNLOCK, function() window.SetRearranging(true) end)
		else
			root:CreateButton(L.MOVE_UP, function()
				Rules.MoveSection(db, section.id, -1)
				Changed()
			end)
			root:CreateButton(L.MOVE_DOWN, function()
				Rules.MoveSection(db, section.id, 1)
				Changed()
			end)
			root:CreateButton(section.below and L.MOVE_ABOVE_REST or L.MOVE_BELOW_REST, function()
				Rules.SetSectionBelow(db, section.id, not section.below)
				Changed()
			end)
		end
		root:CreateButton(L.COLOUR, function() Menu.PickColour(section, window) end)
		root:CreateDivider()
		Menu.AddMoveAllEntry(root, group, window)
		root:CreateButton(L.CLEAR_SECTION, function()
			Rules.ClearSection(db, section.id)
			Changed()
		end)
		root:CreateButton(L.DELETE_SECTION, function() Menu.DeleteSection(section, group.count, window) end)
	end)
end

-- At the bank (not looking at a past visit): move the whole group across.
function Menu.AddMoveAllEntry(root, group, window)
	if ns.Bank.IsOpen() and group.count > 0 then
		local move = root:CreateButton(window.isBank and L.MOVE_ALL_TO_BAGS or L.MOVE_ALL_TO_BANK, function()
			ns.Mover.MoveGroup(group, not window.isBank)
		end)
		move:SetEnabled(not ns.Mover.IsBusy())
	end
end

-- Right-click on the bags' Reagents header (the reagent bag, and reagents gathered from
-- the bags). It isn't a section, so there's only collapsing it and, at the bank, Move all.
function Menu.OpenReagentMenu(owner, group, window)
	window = window or ns.Frame
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L.REAGENTS)
		root:CreateButton(group.collapsed and L.EXPAND or L.COLLAPSE, function()
			Rules.ToggleBuiltinCollapsed(window.GetDB(), group.key)
			Changed()
		end)
		Menu.AddMoveAllEntry(root, group, window)
	end)
end

-- Opens Blizzard's colour picker for a section's outline colour (compact layout).
function Menu.PickColour(section, window)
	local db = DB(window)
	local c = section.color or Rules.PALETTE[1]
	local id = section.id
	ColorPickerFrame:SetupColorPickerAndShow({
		r = c.r, g = c.g, b = c.b,
		hasOpacity = false,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			Rules.SetSectionColor(db, id, r, g, b)
			Changed()
		end,
		cancelFunc = function(previous)
			Rules.SetSectionColor(db, id, previous.r, previous.g, previous.b)
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
		ns.SyncAutoSections()
		-- Bank sections with the same names as the profile's are linked to them.
		Rules.LinkByName(ns.charDB, ns.charDB.bankSections)
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
		Menu.AddNewSectionEntry(root, ns.Frame)
		root:CreateCheckbox(L.SHOW_EMPTY, function()
			return ns.db.showEmptySections
		end, function()
			ns.db.showEmptySections = not ns.db.showEmptySections
			Changed()
		end)
		root:CreateCheckbox(L.SHOW_KEYRING, function()
			return ns.db.showKeyring
		end, function()
			ns.db.showKeyring = not ns.db.showKeyring
			Changed()
		end)
		local function IsLayout(name) return (ns.db.layout or "semicompact") == name end
		if IsLayout("semicompact") then
			root:CreateCheckbox(L.REARRANGE, function()
				return ns.Frame.IsRearranging()
			end, function()
				ns.Frame.SetRearranging(not ns.Frame.IsRearranging())
			end)
		end
		local layout = root:CreateButton(L.LAYOUT)
		layout:CreateRadio(L.LAYOUT_STACKED, function() return IsLayout("default") end, function() Menu.SetLayout("default") end)
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

-- Bank sections: separate from the bags'; these copy and set them up.

function Menu.CopyBagSections(sections)
	local created = Rules.CopySections(ns.charDB, ns.charDB.bankSections, sections)
	if #created > 0 then
		ns.Print(L.BANK_COPIED:format(#created))
	end
	Changed()
	return created
end

-- "New section": an empty one, or (when the other side has sections this side doesn't)
-- a linked copy of one of those, or all of them.
function Menu.AddNewSectionEntry(root, window)
	local db, partner = window.GetDB(), window.GetPartnerDB()
	local missing = partner and Rules.MissingSections(partner, db) or {}
	if #missing == 0 then
		root:CreateButton(L.NEW_SECTION, function() Menu.PromptNewSection(nil, window) end)
		return
	end
	local new = root:CreateButton(L.NEW_SECTION_MENU)
	new:CreateButton(L.NEW_EMPTY_SECTION, function() Menu.PromptNewSection(nil, window) end)
	new:CreateDivider()
	new:CreateTitle(window.isBank and L.FROM_BAGS or L.FROM_BANK)
	local function Copy(sections)
		Rules.CopySections(partner, db, sections)
		Changed()
	end
	for _, section in ipairs(missing) do
		new:CreateButton(section.name, function() Copy({ section }) end)
	end
	if #missing > 1 then
		new:CreateButton(L.BANK_COPY_ALL:format(#missing), function() Copy(missing) end)
	end
end

-- First visit to a banker (and "Set up bank sections..." in the bank's gear menu): asks
-- whether to use sections in the bank, then whether to copy the bag sections. Each question
-- is its own small Yes/No dialog. (The Reagents and Quest Items sections are settings.)
function Menu.StartBankSetup()
	ns.charDB.bankSetupDone = true
	local function Ask(text, onYes, onNo)
		-- Next frame, so the previous dialog has finished closing.
		C_Timer.After(0, function()
			StaticPopup_Show("BAGSECTIONS_CONFIRM", text, nil, { onAccept = onYes, onCancel = onNo })
		end)
	end
	local function AskCopy()
		local missing = Rules.MissingSections(ns.charDB, ns.charDB.bankSections)
		if #missing == 0 then
			return
		end
		local names = {}
		for i, section in ipairs(missing) do
			if i > 4 then
				names[#names + 1] = "..."
				break
			end
			names[#names + 1] = section.name
		end
		Ask(L.BANK_SETUP_COPY:format(#missing, table.concat(names, ", ")), function()
			Menu.CopyBagSections(missing)
		end)
	end
	Ask(L.BANK_SETUP_INTRO, AskCopy)
end

-- Options button in the bank window's title bar.
function Menu.OpenBankMenu(owner)
	local bank = ns.BankFrame
	local db = ns.charDB.bankSections
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L.BANK)
		Menu.AddNewSectionEntry(root, bank)
		local copy = root:CreateButton(L.BANK_COPY_SECTIONS)
		local missing = Rules.MissingSections(ns.charDB, db)
		for _, section in ipairs(missing) do
			copy:CreateButton(section.name, function() Menu.CopyBagSections({ section }) end)
		end
		if #missing > 1 then
			copy:CreateDivider()
			copy:CreateButton(L.BANK_COPY_ALL:format(#missing), function() Menu.CopyBagSections(missing) end)
		end
		copy:SetEnabled(#missing > 0)
		root:CreateCheckbox(L.SHOW_EMPTY, function()
			return ns.db.showEmptySections
		end, function()
			ns.db.showEmptySections = not ns.db.showEmptySections
			Changed()
		end)
		local function IsLayout(name) return (ns.db.bankLayout or "semicompact") == name end
		if IsLayout("semicompact") then
			root:CreateCheckbox(L.REARRANGE, function()
				return bank.IsRearranging()
			end, function()
				bank.SetRearranging(not bank.IsRearranging())
			end)
		end
		local function SetLayout(name)
			ns.db.bankLayout = name
			Changed()
		end
		local layout = root:CreateButton(L.LAYOUT)
		layout:CreateRadio(L.LAYOUT_STACKED, function() return IsLayout("default") end, function() SetLayout("default") end)
		layout:CreateRadio(L.LAYOUT_SEMICOMPACT, function() return IsLayout("semicompact") end, function() SetLayout("semicompact") end)
		layout:CreateRadio(L.LAYOUT_COMPACT, function() return IsLayout("compact") end, function() SetLayout("compact") end)
		if IsLayout("semicompact") then
			layout:CreateDivider()
			layout:CreateButton(L.RESET_ROWS, function()
				ns.Rows.Reset(db)
				Changed()
			end)
		end
		root:CreateDivider()
		root:CreateButton(L.BANK_SETUP_AGAIN, function() Menu.StartBankSetup() end)
		root:CreateButton(L.SETTINGS, function() ns.Options.Open() end)
	end)
end

-- Alt+Right-click on an item.
function Menu.OpenItemMenu(button, window)
	window = window or ns.Frame
	local bag, slot = button:GetBagID(), button:GetID()
	if not window.IsOwnBag(bag) then
		return
	end
	local item = ns.Inventory.GetItem(bag, slot)
	if not item then
		return
	end
	local db, partner = window.GetDB(), window.GetPartnerDB()
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
				Rules.AssignLinked(db, partner, item, section.id, matched or Rules.DefaultKind(item, ns.db))
				Changed()
			end)
		end
		if #db.sections > 0 then
			assign:CreateDivider()
		end
		assign:CreateButton(L.NEW_SECTION, function()
			Menu.PromptNewSection(function(section)
				Rules.AssignLinked(db, partner, item, section.id, Rules.DefaultKind(item, ns.db))
				Changed()
			end, window)
		end)

		if current ~= Rules.REST then
			root:CreateButton(L.REMOVE_FROM_SECTION, function()
				Rules.UnassignLinked(db, partner, item)
				Changed()
			end)

			local match = root:CreateButton(L.MATCH)
			local function SetKind(kind)
				Rules.AssignLinked(db, partner, item, current, kind)
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
