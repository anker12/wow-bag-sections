-- Shows this window instead of Blizzard's bags, without replacing any Blizzard function.
--
-- Blizzard's bag frames keep working exactly as normal (B, the backpack button, merchants,
-- the bank and Escape all open and close them, and Blizzard keeps track of what opened them),
-- but they're moved into a hidden parent so they're never seen. This window simply shows
-- whenever Blizzard considers the bags open.
--
-- Replacing Blizzard's global bag functions (as older bag addons do) "taints" whatever
-- Blizzard code calls them. The bank calls OpenAllBags when it opens, so a replaced
-- OpenAllBags tainted the bank, and moving items between bank and bags was then blocked.

local _, ns = ...

local Hooks = {}
ns.Hooks = Hooks

local Inventory = ns.Inventory
local Frame = ns.Frame
local installed = false
local hiddenParent

local function IsHandledFrame(frame)
	if frame == ContainerFrameCombinedBags then
		return true
	end
	local bag = frame.GetBagID and frame:GetBagID()
	return bag ~= nil and Inventory.IsHandledBag(bag)
end

-- Moves a Blizzard bag frame out of sight if it shows bags this window shows; anything
-- else (e.g. a bank bag) is put back where Blizzard expects it.
local function Tuck(frame)
	if IsHandledFrame(frame) then
		if frame:GetParent() ~= hiddenParent then
			frame:SetParent(hiddenParent)
		end
	elseif frame:GetParent() == hiddenParent then
		frame:SetParent(UIParent)
	end
end

local function BlizzardBagFrames()
	local frames = { ContainerFrameCombinedBags }
	for i = 1, NUM_CONTAINER_FRAMES or 0 do
		local frame = _G["ContainerFrame" .. i]
		if frame then
			table.insert(frames, frame)
		end
	end
	return frames
end

local function TuckAll()
	for _, frame in ipairs(BlizzardBagFrames()) do
		Tuck(frame)
	end
end

-- Match this window to Blizzard's open/closed state, once per frame.
local syncQueued = false
local function Sync()
	syncQueued = false
	if IsAnyBagOpen() then
		Frame.Show()
	else
		Frame.Hide()
	end
end

local function QueueSync()
	if not syncQueued then
		syncQueued = true
		C_Timer.After(0, Sync)
	end
end

-- This window was closed (close button, Escape): close Blizzard's hidden bag frames too, so
-- the next B press opens the bags again instead of closing them.
function Hooks.OnWindowHidden()
	if not installed then
		return
	end
	for _, frame in ipairs(BlizzardBagFrames()) do
		if frame:IsShown() and IsHandledFrame(frame) then
			frame:Hide()
		end
	end
end

function Hooks.IsInstalled()
	return installed
end

function Hooks.Install()
	if installed then
		return
	end
	installed = true

	hiddenParent = CreateFrame("Frame")
	hiddenParent:Hide()

	for _, frame in ipairs(BlizzardBagFrames()) do
		frame:HookScript("OnShow", function(self)
			Tuck(self)
			QueueSync()
		end)
		frame:HookScript("OnHide", QueueSync)
	end
	TuckAll()

	-- Blizzard re-parents its bag frames when a full-screen panel opens or closes.
	if ContainerFrame_SetFullScreenFrame then
		hooksecurefunc("ContainerFrame_SetFullScreenFrame", TuckAll)
	end
	if ContainerFrame_ClearFullScreenFrame then
		hooksecurefunc("ContainerFrame_ClearFullScreenFrame", TuckAll)
	end
end
