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
			local section = Rules.CreateSection(ns.charDB, name)
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
		root:CreateButton(L.MOVE_UP, function()
			Rules.MoveSection(ns.charDB, section.id, -1)
			Changed()
		end)
		root:CreateButton(L.MOVE_DOWN, function()
			Rules.MoveSection(ns.charDB, section.id, 1)
			Changed()
		end)
		root:CreateDivider()
		root:CreateButton(L.CLEAR_SECTION, function()
			Rules.ClearSection(ns.charDB, section.id)
			Changed()
		end)
		root:CreateButton(L.DELETE_SECTION, function() Menu.DeleteSection(section, group.count) end)
	end)
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
