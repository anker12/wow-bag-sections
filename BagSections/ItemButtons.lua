-- Item buttons built from Blizzard's ContainerFrameItemButtonTemplate.
-- One button per physical bag slot, reused across redraws. Blizzard's own click, drag and
-- tooltip scripts are left untouched so item use works the same as in the default bags.

local _, ns = ...

local ItemButtons = {}
ns.ItemButtons = ItemButtons

ItemButtons.SIZE = 37

local buttonsBySlot = {}
local count = 0
local parentFrame

local function Key(bag, slot)
	return bag * 1000 + slot
end

function ItemButtons.SetParent(frame)
	parentFrame = frame
end

local function OnClickHook(button, mouseButton)
	if mouseButton == "RightButton" and IsAltKeyDown() and button:HasItem() then
		ns.Menu.OpenItemMenu(button)
	end
end

local function Create(bag, slot)
	count = count + 1
	local button = CreateFrame("ItemButton", "BagSectionsItemButton" .. count, parentFrame, "ContainerFrameItemButtonTemplate")
	-- SetBagID stores the bag in an attribute, which Blizzard does to keep item interaction untainted.
	button:SetBagID(bag)
	button:SetID(slot)
	-- The template pins a fixed frame level; keep buttons above the window background.
	button:SetFrameLevel(parentFrame:GetFrameLevel() + 2)

	button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
	button.ItemSlotBackground:SetAllPoints(button)

	button:HookScript("OnClick", OnClickHook)
	return button
end

function ItemButtons.Get(bag, slot)
	local key = Key(bag, slot)
	local button = buttonsBySlot[key]
	if not button then
		button = Create(bag, slot)
		buttonsBySlot[key] = button
	end
	return button
end

-- Creates buttons for every current slot up front, so none need creating later in combat.
function ItemButtons.Precreate(slots)
	for _, slot in ipairs(slots) do
		ItemButtons.Get(slot.bag, slot.slot)
	end
end

-- Hides every button not in the given set. Buttons that stay visible are not hidden
-- and re-shown, so their OnHide/OnShow scripts don't run on every redraw.
function ItemButtons.HideExcept(keep)
	for _, button in pairs(buttonsBySlot) do
		if not keep[button] then
			button:Hide()
		end
	end
end

function ItemButtons.Enumerate()
	return pairs(buttonsBySlot)
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

function ItemButtons.UpdateShown()
	local tooltipOwner = GameTooltip:GetOwner()
	for _, button in pairs(buttonsBySlot) do
		if button:IsShown() then
			ItemButtons.Update(button, tooltipOwner)
		end
	end
end

function ItemButtons.UpdateCooldowns()
	for _, button in pairs(buttonsBySlot) do
		if button:IsShown() then
			button:UpdateCooldown(C_Container.HasContainerItem(button:GetBagID(), button:GetID()))
		end
	end
end
