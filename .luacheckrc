std = "lua51" -- WoW runs Lua 5.1
max_line_length = false
unused_args = false -- event handler and callback signatures are fixed by the API

exclude_files = {
    "Libs/**",
}

-- Saved variables and the slash command
globals = {
    "EmotePickerDB",
    "KehetsEmotePicker_OnAddonCompartmentClick",
    "KehetsEmotePicker_OnAddonCompartmentEnter",
    "KehetsEmotePicker_OnAddonCompartmentLeave",
    "SLASH_KEHETSEMOTEPICKER1",
    "SLASH_KEHETSEMOTEPICKER2",
    "SlashCmdList",
}

-- WoW API, FrameXML and libraries
read_globals = {
    "AddonCompartmentFrame",
    "ButtonFrameTemplate_HideButtonBar",
    "ButtonFrameTemplate_ShowButtonBar",
    "C_XMLUtil",
    "CreateFrame",
    "DoEmote",
    "GameTooltip",
    "GameTooltip_Hide",
    "GetCursorPosition",
    "GetRealmName",
    "LibStub",
    "MAXEMOTEINDEX",
    "Minimap",
    "PanelTemplates_SetNumTabs",
    "PanelTemplates_SetTab",
    "PanelTemplates_TabResize",
    "TextEmoteSpeechList",
    "UIParent",
    "UISpecialFrames",
    "UnitExists",
    "UnitName",
    "wipe",
}
