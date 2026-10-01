std = "lua51"
max_line_length = false
self = false
exclude_files = { "tests/lib/**" }

-- Globals this addon defines.
globals = {
	"BagSectionsDB", "BagSectionsCharDB",
	"SLASH_BAGSECTIONS1", "SLASH_BAGSECTIONS2",
	"SlashCmdList", "StaticPopupDialogs", "UISpecialFrames",
}

-- WoW API used by the addon.
read_globals = {
	"C_ActionBar", "C_Container", "C_Cursor", "C_Item", "C_Timer",
	"Constants", "Enum", "ItemLocation", "Settings", "MenuUtil", "TooltipDataProcessor", "SOUNDKIT",
	"CreateFrame", "UIParent", "GameTooltip", "UIErrorsFrame", "RED_FONT_COLOR",
	"GameTooltip_Hide", "GameTooltip_SetTitle", "GameTooltip_AddNormalLine", "GameTooltip_AddInstructionLine",
	"ClearItemButtonOverlay", "SetItemButtonQuality", "SetItemButtonCount", "SetItemButtonDesaturated",
	"MinimalSliderWithSteppersMixin", "GetCursorInfo", "IsAnyBagOpen",
	"ContainerFrameCombinedBags", "NUM_CONTAINER_FRAMES",
	"ContainerFrame_SetFullScreenFrame", "ContainerFrame_ClearFullScreenFrame",
	"StaticPopup_Show", "StaticPopup_StandardEditBoxOnEscapePressed",
	"ClearCursor", "CursorHasItem", "GetMouseFoci", "GetMoney", "GetMoneyString", "GetKeyRingSize",
	"InCombatLockdown", "GetTime", "PixelUtil", "GetCursorPosition", "CreateSettingsButtonInitializer", "CreateSettingsListSectionHeaderInitializer", "ColorPickerFrame", "NORMAL_FONT_COLOR", "IsAltKeyDown", "PlaySound", "hooksecurefunc", "strtrim", "tinsert", "bit",
	"ACCEPT", "CANCEL", "YES", "NO", "NUM_BAG_SLOTS",
}

files["tests/**"] = { std = "lua51" }
