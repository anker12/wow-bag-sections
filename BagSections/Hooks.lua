-- Makes the game open this window instead of Blizzard's bags.
--
-- Open/toggle functions are replaced (the approach long used by Bagnon), but only for the
-- bags this window shows; bank bags still go to Blizzard's code. Close functions are only
-- post-hooked with hooksecurefunc, so Blizzard code that closes windows (Escape, the game
-- menu, cinematics) never runs addon code in its own call path.

local _, ns = ...

local Hooks = {}
ns.Hooks = Hooks

local Inventory = ns.Inventory
local Frame = ns.Frame
local installed = false

-- Name of the frame (merchant, mailbox, bank...) that opened the bags, if any. The bags only
-- close automatically when that same frame closes, matching Blizzard's behaviour.
local openedBy

local function AllowedToOpen()
	return not ContainerFrame_AllowedToOpenBags or ContainerFrame_AllowedToOpenBags()
end

local function Open()
	if AllowedToOpen() then
		Frame.Show()
	end
end

local function Toggle()
	if Frame.IsShown() then
		Frame.Hide()
	elseif AllowedToOpen() then
		Frame.Show()
	end
end

function Hooks.OnWindowHidden()
	openedBy = nil
end

function Hooks.IsInstalled()
	return installed
end

function Hooks.Install()
	if installed then
		return
	end
	installed = true

	local origToggleBag = ToggleBag
	local origOpenBag = OpenBag

	ToggleBackpack = Toggle
	ToggleAllBags = Toggle
	OpenBackpack = Open

	OpenAllBags = function(frame)
		if frame and not Frame.IsShown() and not openedBy then
			openedBy = frame:GetName()
		end
		Open()
	end

	ToggleBag = function(id, ...)
		if Inventory.IsHandledBag(id) then
			Toggle()
		else
			return origToggleBag(id, ...)
		end
	end

	OpenBag = function(id, ...)
		if Inventory.IsHandledBag(id) then
			Open()
		else
			return origOpenBag(id, ...)
		end
	end

	hooksecurefunc("CloseAllBags", function(frame)
		if frame and frame:GetName() ~= openedBy then
			return
		end
		Frame.Hide()
	end)

	hooksecurefunc("CloseBackpack", function()
		Frame.Hide()
	end)

	hooksecurefunc("CloseBag", function(id)
		if id == Enum.BagIndex.Backpack then
			Frame.Hide()
		end
	end)
end
