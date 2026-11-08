-- Item buttons built from Blizzard's ContainerFrameItemButtonTemplate.
-- One button per physical bag slot per window, reused across redraws. Blizzard's own click, drag and
-- tooltip scripts are left untouched so item use works the same as in the default bags.

local _, ns = ...

local ItemButtons = {}
ns.ItemButtons = ItemButtons

ItemButtons.SIZE = 37

local count = 0 -- buttons made so far, across every window, for unique names

local function Key(bag, slot)
	return bag * 1000 + slot
end

-- The empty slot art behind an item button. Set directly rather than through Blizzard's
-- ItemSlotBackgroundCombinedBagsTemplate, which Forever removed; the plain backpack slot
-- texture stands in if the atlas goes too.
function ItemButtons.AddSlotBackground(button)
	local background = button:CreateTexture(nil, "BACKGROUND", nil, -6)
	if not background:SetAtlas("bags-item-slot64") then
		background:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	end
	background:SetAllPoints(button)
	button.ItemSlotBackground = background
end

-- Mirrors ContainerFrameMixin:UpdateItems from Blizzard's bag code.
function ItemButtons.Update(button, tooltipOwner)
	local bag, slot = button:GetBagID(), button:GetID()
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local texture = info and info.iconFileID
	local itemCount = info and info.stackCount
	local locked = info and info.isLocked
	local quality = info and info.quality
	local readable = info and info.isReadable
	local itemLink = info and info.hyperlink
	local isFiltered = info and info.isFiltered
	local noValue = info and info.hasNoValue
	local isBound = info and info.isBound
	local questInfo = C_Container.GetContainerItemQuestInfo(bag, slot)

	ClearItemButtonOverlay(button)
	button:SetHasItem(texture)
	button:SetItemButtonTexture(texture)
	SetItemButtonQuality(button, quality, itemLink, false, isBound)
	SetItemButtonCount(button, itemCount)
	SetItemButtonDesaturated(button, locked)

	button:UpdateExtended()
	button:UpdateQuestItem(questInfo.isQuestItem, questInfo.questID, questInfo.isActive)
	button:UpdateNewItem(quality)
	button:UpdateJunkItem(quality, noValue)
	button:UpdateItemContextMatching()
	button:UpdateCooldown(texture)
	button:SetReadable(readable)
	button:CheckUpdateTooltip(tooltipOwner)
	button:SetMatchesSearch(not isFiltered)
end

-- Saved slots (the bank away from a banker, an alt's bags and bank) get plain item buttons
-- that only show the saved item: there's no live item behind them to click or drag. (Forever has no ItemButtonTemplate; the plain
-- ItemButton widget already has an icon, count, quality border and highlight.)
function ItemButtons.NewCachedSet(content)
	local pool = {}
	local set = {}
	local function Create()
		local button = CreateFrame("ItemButton", nil, content)
		button:SetSize(ItemButtons.SIZE, ItemButtons.SIZE)
		button:SetFrameLevel(content:GetFrameLevel() + 2)
		ItemButtons.AddSlotBackground(button)
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

-- A set of buttons for one window (the bags, the bank). `window` gets OnItemButtonDrop
-- calls, and Alt+Right-click opens the item menu for that window.
function ItemButtons.NewSet(parentFrame, window)
	local set = {}
	local buttonsBySlot = {}

	local function OnClickHook(button, mouseButton)
		if mouseButton == "RightButton" and IsAltKeyDown() and button:HasItem() then
			ns.Menu.OpenItemMenu(button, window)
		elseif mouseButton == "LeftButton" then
			window.OnItemButtonDrop(button)
		end
	end

	local function OnReceiveDragHook(button)
		window.OnItemButtonDrop(button)
	end

	-- One invisible frame per bag, whose ID is the bag number. Blizzard's item button reads
	-- its bag from its parent's ID when none is set on the button itself. A bag number
	-- written onto the button by addon code would be "tainted", and Blizzard's click code
	-- reading it would then be blocked from protected actions such as moving items to and
	-- from the bank.
	local bagFrames = {}

	local function BagFrame(bag)
		local frame = bagFrames[bag]
		if not frame then
			frame = CreateFrame("Frame", nil, parentFrame)
			frame:SetID(bag)
			frame:SetAllPoints(parentFrame)
			bagFrames[bag] = frame
		end
		return frame
	end

	local function Create(bag, slot)
		count = count + 1
		local button = CreateFrame("ItemButton", "BagSectionsItemButton" .. count, BagFrame(bag), "ContainerFrameItemButtonTemplate")
		button:SetID(slot)
		-- The template pins a fixed frame level; keep buttons above the window background.
		button:SetFrameLevel(parentFrame:GetFrameLevel() + 2)

		ItemButtons.AddSlotBackground(button)

		button:HookScript("OnClick", OnClickHook)
		button:HookScript("OnReceiveDrag", OnReceiveDragHook)
		return button
	end

	function set.Get(bag, slot)
		local key = Key(bag, slot)
		local button = buttonsBySlot[key]
		if not button then
			button = Create(bag, slot)
			buttonsBySlot[key] = button
		end
		return button
	end

	-- Creates buttons for every current slot up front, so none need creating later in combat.
	function set.Precreate(slots)
		for _, slot in ipairs(slots) do
			set.Get(slot.bag, slot.slot)
		end
	end

	-- Hides every button not in the given set. Buttons that stay visible are not hidden
	-- and re-shown, so their OnHide/OnShow scripts don't run on every redraw.
	function set.HideExcept(keep)
		for _, button in pairs(buttonsBySlot) do
			if not keep[button] then
				button:Hide()
			end
		end
	end

	function set.ForSlot(slot)
		return set.Get(slot.bag, slot.slot)
	end

	function set.Enumerate()
		return pairs(buttonsBySlot)
	end

	function set.UpdateShown()
		local tooltipOwner = GameTooltip:GetOwner()
		for _, button in pairs(buttonsBySlot) do
			if button:IsShown() then
				ItemButtons.Update(button, tooltipOwner)
			end
		end
	end

	function set.UpdateCooldowns()
		for _, button in pairs(buttonsBySlot) do
			if button:IsShown() then
				button:UpdateCooldown(C_Container.HasContainerItem(button:GetBagID(), button:GetID()))
			end
		end
	end

	return set
end

-- The bag window's set, which the rest of the addon uses through ItemButtons.Get etc.
function ItemButtons.SetParent(frame)
	local bags = ItemButtons.NewSet(frame, ns.Frame)
	for _, name in ipairs({ "Get", "Precreate", "HideExcept", "Enumerate", "UpdateShown", "UpdateCooldowns" }) do
		ItemButtons[name] = bags[name]
	end
	return bags
end
