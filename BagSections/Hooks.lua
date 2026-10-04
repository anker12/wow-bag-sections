-- Shows this window instead of Blizzard's bags, without replacing or calling into any of
-- Blizzard's bag code.
--
-- Blizzard's bag frames keep working exactly as normal (B, the backpack button, merchants,
-- the bank and Escape all open and close them, and Blizzard keeps track of what opened them),
-- but they're moved into a hidden parent so they're never seen. This window opens and
-- closes along with them (IsAnyBagOpen, which checks IsShown, not visibility).
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

-- The window normally shows exactly when Blizzard considers its bags open. `flipped` is
-- set when they differ because of something done in this window (its close button, /bs):
-- the window is closed while Blizzard's hidden bags are still open, or the other way
-- round. Closing Blizzard's bags from addon code would run Blizzard's bag code "tainted",
-- which later blocked right-clicking consumables, so instead the next B press simply
-- toggles what's on screen.
local flipped, wasOpen = false, false

local function Apply()
	TuckAll()
	local open = IsAnyBagOpen()
	wasOpen = open
	if open ~= flipped then
		Frame.Show()
	else
		Frame.Hide()
	end
end

-- B, the backpack button and bag buttons: toggle what's on screen.
local function OnToggle()
	Apply()
end

-- Merchants, the bank, mail and so on open and close the bags on purpose: follow them.
local function OnOpenOrClose()
	flipped = false
	Apply()
end

-- Anything else that opens or closes Blizzard's bags (Escape, its close button) doesn't
-- always go through a function that can be hooked, so check every frame for changes.
local function Watch()
	if IsAnyBagOpen() ~= wasOpen then
		OnOpenOrClose()
	end
end

-- Called when the window is shown or hidden, by anything.
function Hooks.OnWindowShownChanged()
	if installed then
		flipped = Frame.IsShown() ~= IsAnyBagOpen()
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
	TuckAll()

	-- Only global functions are hooked: hooksecurefunc runs after Blizzard's code and
	-- separately from it. Nothing of Blizzard's bag code is called, replaced or hooked by
	-- frame method, so it never runs tainted.
	for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
		if _G[name] then
			hooksecurefunc(name, OnToggle)
		end
	end
	for _, name in ipairs({ "OpenAllBags", "CloseAllBags" }) do
		if _G[name] then
			hooksecurefunc(name, OnOpenOrClose)
		end
	end
	local watcher = CreateFrame("Frame")
	watcher:SetScript("OnUpdate", Watch)

	-- Blizzard re-parents its bag frames when a full-screen panel opens or closes.
	if ContainerFrame_SetFullScreenFrame then
		hooksecurefunc("ContainerFrame_SetFullScreenFrame", TuckAll)
	end
	if ContainerFrame_ClearFullScreenFrame then
		hooksecurefunc("ContainerFrame_ClearFullScreenFrame", TuckAll)
	end
end
