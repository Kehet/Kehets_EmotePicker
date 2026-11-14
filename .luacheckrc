std = "lua51" -- WoW runs Lua 5.1
max_line_length = false
unused_args = false -- event handler and callback signatures are fixed by the API

exclude_files = {
    "Libs/**",
}

-- WoW API, FrameXML and libraries
read_globals = {
    "C_XMLUtil",
    "CreateFrame",
    "DoEmote",
    "GameTooltip",
    "GameTooltip_Hide",
    "GetCursorPosition",
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
    "wipe",
}
