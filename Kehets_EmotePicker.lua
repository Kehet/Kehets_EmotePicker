local EmotePicker = LibStub("AceAddon-3.0"):NewAddon("Kehet's EmotePicker", "AceConsole-3.0")

-- Shown first, in this order. Tokens missing from the client are skipped.
local POPULAR_TOKENS = {
    "WAVE", "HELLO", "BYE", "THANK", "LAUGH", "CHEER", "DANCE", "BOW",
    "APPLAUD", "SALUTE", "HUG", "CRY", "ROAR", "FLEX", "CHICKEN", "POINT",
    "FACEPALM", "SHRUG", "SIGH", "KISS", "RUDE", "SIT", "SLEEP", "KNEEL",
}

-- Emotes that play a character voice line. The client's own list is used when it exists.
local VOICE_TOKENS = TextEmoteSpeechList or {
    "HELP", "INCOMING", "CHARGE", "FLEE", "ATTACKMYTARGET", "OOM", "FOLLOW", "WAIT",
    "HEALME", "CHEER", "OPENFIRE", "RASP", "HELLO", "BYE", "NOD", "NO", "THANK",
    "WELCOME", "CONGRATULATE", "FLIRT", "JOKE", "TRAIN",
}

local ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"
local COLUMNS = 3
local BUTTON_WIDTH = 124
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 4

local STAT_ROW_HEIGHT = 18

local emotes
local emotesByToken
local frame
local buttons = {}
local filtered = {}
local statRows = {}

-- Builds the emote list from the client's EMOTE<n>_TOKEN / EMOTE<n>_CMD<m> globals
local function CollectEmotes()
    local byToken = {}
    local list = {}

    for i = 1, (MAXEMOTEINDEX or 1000) do
        local token = _G["EMOTE" .. i .. "_TOKEN"]
        local command = _G["EMOTE" .. i .. "_CMD1"]

        if token and command and not byToken[token] then
            local search = { token:lower() }
            local m = 1
            while _G["EMOTE" .. i .. "_CMD" .. m] do
                table.insert(search, (_G["EMOTE" .. i .. "_CMD" .. m]:gsub("^/", "")):lower())
                m = m + 1
            end

            local name = command:gsub("^/", "")
            local emote = {
                token = token,
                name = name:sub(1, 1):upper() .. name:sub(2),
                command = command,
                search = table.concat(search, " "),
            }
            byToken[token] = emote
            table.insert(list, emote)
        end
    end

    for _, token in ipairs(VOICE_TOKENS) do
        if byToken[token] then
            byToken[token].voice = true
        end
    end

    local popularRank = {}
    for rank, token in ipairs(POPULAR_TOKENS) do
        popularRank[token] = rank
        if byToken[token] then
            byToken[token].popular = true
        end
    end

    -- Voice lines first, then popular emotes in POPULAR_TOKENS order, then alphabetical
    table.sort(list, function(a, b)
        if a.voice ~= b.voice then
            return a.voice == true
        end
        local rankA = popularRank[a.token] or math.huge
        local rankB = popularRank[b.token] or math.huge
        if rankA ~= rankB then
            return rankA < rankB
        end
        return a.name:lower() < b.name:lower()
    end)

    for index, emote in ipairs(list) do
        emote.defaultIndex = index
    end

    emotesByToken = byToken
    return list
end

-- Most recently used emotes first, the rest keep their default order
local function SortEmotes()
    local lastUsed = EmotePicker.db.profile.lastUsed
    table.sort(emotes, function(a, b)
        local usedA = lastUsed[a.token] or 0
        local usedB = lastUsed[b.token] or 0
        if usedA ~= usedB then
            return usedA > usedB
        end
        return a.defaultIndex < b.defaultIndex
    end)
end

local function PerformEmote(emote)
    if EmotePicker.db.profile.requireTarget and not UnitExists("target") then
        EmotePicker:Print("|cFFFF0000You need a target to use " .. emote.command .. "|r")
        return
    end

    -- A counter instead of time() so two emotes in the same second still keep their order
    local profile = EmotePicker.db.profile
    profile.useCounter = profile.useCounter + 1
    profile.lastUsed[emote.token] = profile.useCounter
    profile.useCount[emote.token] = (profile.useCount[emote.token] or 0) + 1

    frame:Hide()
    DoEmote(emote.token)
end

local function GetButton(index)
    if buttons[index] then
        return buttons[index]
    end

    local button = CreateFrame("Button", nil, frame.emotesTab.content, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetScript("OnClick", function(self)
        PerformEmote(self.emote)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.emote.name)
        GameTooltip:AddLine(self.emote.command, 1, 1, 1)
        if self.emote.voice then
            GameTooltip:AddLine("Has voice line", 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    local column = (index - 1) % COLUMNS
    local row = math.floor((index - 1) / COLUMNS)
    button:SetPoint("TOPLEFT", column * (BUTTON_WIDTH + BUTTON_GAP), -row * (BUTTON_HEIGHT + BUTTON_GAP))

    buttons[index] = button
    return button
end

local function Refresh()
    local tab = frame.emotesTab
    local query = tab.search:GetText():lower():gsub("^%s+", ""):gsub("%s+$", "")

    wipe(filtered)
    for _, emote in ipairs(emotes) do
        if query == "" or emote.search:find(query, 1, true) then
            table.insert(filtered, emote)
        end
    end

    for i, emote in ipairs(filtered) do
        local button = GetButton(i)
        button.emote = emote
        local label = emote.voice and ("|TInterface\\Common\\VoiceChat-Speaker:14|t " .. emote.name) or emote.name
        button:SetText(emote.popular and ("|cFFFFD100" .. label .. "|r") or label)
        button:Show()
    end
    for i = #filtered + 1, #buttons do
        buttons[i]:Hide()
    end

    local rows = math.ceil(#filtered / COLUMNS)
    tab.content:SetHeight(math.max(1, rows * (BUTTON_HEIGHT + BUTTON_GAP)))
    tab.scroll:SetVerticalScroll(0)
    tab.empty:SetShown(#filtered == 0)
end

local function GetStatRow(index)
    if statRows[index] then
        return statRows[index]
    end

    local content = frame.statsTab.content
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(STAT_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 4, -(index - 1) * STAT_ROW_HEIGHT)
    row:SetPoint("RIGHT", content, "RIGHT", -4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT")
    row.name:SetJustifyH("LEFT")

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.count:SetPoint("RIGHT")
    row.count:SetJustifyH("RIGHT")

    statRows[index] = row
    return row
end

local function RefreshStatistics()
    local tab = frame.statsTab
    local stats = {}
    local total = 0

    for token, count in pairs(EmotePicker.db.profile.useCount) do
        local emote = emotesByToken[token]
        table.insert(stats, { name = emote and emote.name or token, count = count })
        total = total + count
    end

    table.sort(stats, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name:lower() < b.name:lower()
    end)

    for i, stat in ipairs(stats) do
        local row = GetStatRow(i)
        row.name:SetText(i .. ". " .. stat.name)
        row.count:SetText(stat.count)
        row:Show()
    end
    for i = #stats + 1, #statRows do
        statRows[i]:Hide()
    end

    tab.total:SetText(string.format("Total: %d emotes, %d different", total, #stats))
    tab.content:SetHeight(math.max(1, #stats * STAT_ROW_HEIGHT))
    tab.scroll:SetVerticalScroll(0)
    tab.empty:SetShown(#stats == 0)
end

local function SelectTab(index)
    for i, button in ipairs(frame.tabButtons) do
        if i == index then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
        button.panel:SetShown(i == index)
    end

    if index == 1 then
        frame.emotesTab.search:SetFocus()
    else
        frame.emotesTab.search:ClearFocus()
        RefreshStatistics()
    end
end

local function CreatePickerFrame()
    frame = CreateFrame("Frame", "KehetsEmotePickerFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(COLUMNS * (BUTTON_WIDTH + BUTTON_GAP) + 44, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Close with Escape
    table.insert(UISpecialFrames, frame:GetName())

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Kehet's EmotePicker")

    frame.tabButtons = {}
    for i, label in ipairs({ "Emotes", "Statistics" }) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(100, 22)
        button:SetPoint("TOPLEFT", 12 + (i - 1) * 104, -28)
        button:SetText(label)
        button:SetScript("OnClick", function()
            SelectTab(i)
        end)

        -- Each tab's widgets live on their own panel so switching only toggles the panel
        button.panel = CreateFrame("Frame", nil, frame)
        button.panel:SetPoint("TOPLEFT", 0, -54)
        button.panel:SetPoint("BOTTOMRIGHT")

        frame.tabButtons[i] = button
    end

    -- Emotes tab
    local tab = frame.tabButtons[1].panel
    frame.emotesTab = tab

    tab.search = CreateFrame("EditBox", nil, tab, "SearchBoxTemplate")
    tab.search:SetPoint("TOPLEFT", 16, -4)
    tab.search:SetPoint("TOPRIGHT", -12, -4)
    tab.search:SetHeight(20)
    tab.search:SetAutoFocus(false)
    tab.search:HookScript("OnTextChanged", Refresh)
    tab.search:SetScript("OnEnterPressed", function()
        if filtered[1] then
            PerformEmote(filtered[1])
        end
    end)
    tab.search:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)

    tab.scroll = CreateFrame("ScrollFrame", nil, tab, "UIPanelScrollFrameTemplate")
    tab.scroll:SetPoint("TOPLEFT", 12, -32)
    tab.scroll:SetPoint("BOTTOMRIGHT", -32, 38)

    tab.content = CreateFrame("Frame", nil, tab.scroll)
    tab.content:SetSize(COLUMNS * (BUTTON_WIDTH + BUTTON_GAP), 1)
    tab.scroll:SetScrollChild(tab.content)

    tab.empty = tab:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    tab.empty:SetPoint("TOP", tab.scroll, "TOP", 0, -20)
    tab.empty:SetText("No emotes found")

    tab.requireTarget = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
    tab.requireTarget:SetSize(24, 24)
    tab.requireTarget:SetPoint("BOTTOMLEFT", 12, 8)
    tab.requireTarget.label = tab.requireTarget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.requireTarget.label:SetPoint("LEFT", tab.requireTarget, "RIGHT", 2, 0)
    tab.requireTarget.label:SetText("Require target")
    tab.requireTarget:SetScript("OnClick", function(self)
        EmotePicker.db.profile.requireTarget = self:GetChecked()
    end)

    -- Statistics tab
    tab = frame.tabButtons[2].panel
    frame.statsTab = tab

    tab.total = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.total:SetPoint("TOPLEFT", 16, -8)

    tab.scroll = CreateFrame("ScrollFrame", nil, tab, "UIPanelScrollFrameTemplate")
    tab.scroll:SetPoint("TOPLEFT", 12, -32)
    tab.scroll:SetPoint("BOTTOMRIGHT", -32, 10)

    tab.content = CreateFrame("Frame", nil, tab.scroll)
    tab.content:SetSize(COLUMNS * (BUTTON_WIDTH + BUTTON_GAP), 1)
    tab.scroll:SetScrollChild(tab.content)

    tab.empty = tab:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    tab.empty:SetPoint("TOP", tab.scroll, "TOP", 0, -20)
    tab.empty:SetText("No emotes used yet")

    frame:SetScript("OnShow", function()
        frame.emotesTab.search:SetText("")
        frame.emotesTab.requireTarget:SetChecked(EmotePicker.db.profile.requireTarget)
        SortEmotes()
        Refresh()
        SelectTab(1)
    end)
    frame:SetScript("OnHide", function()
        frame.emotesTab.search:ClearFocus()
    end)
end

function EmotePicker:Toggle()
    if not frame then
        emotes = CollectEmotes()
        CreatePickerFrame()
    end
    frame:SetShown(not frame:IsShown())
end

local function UpdateMinimapButtonPosition(button, angle)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function EmotePicker:CreateMinimapButton()
    local button = CreateFrame("Button", "KehetsEmotePickerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function()
        self:Toggle()
    end)

    button:SetScript("OnDragStart", function(b)
        b:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local angle = math.atan2(cy / scale - my, cx / scale - mx)
            self.db.profile.minimap.angle = angle
            UpdateMinimapButtonPosition(b, angle)
        end)
    end)
    button:SetScript("OnDragStop", function(b)
        b:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        GameTooltip:SetText("Kehet's EmotePicker")
        GameTooltip:AddLine("Click to pick an emote", 1, 1, 1)
        GameTooltip:AddLine("Drag to move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    UpdateMinimapButtonPosition(button, self.db.profile.minimap.angle)
    button:SetShown(not self.db.profile.minimap.hide)
    self.minimapButton = button
end

local defaults = {
    profile = {
        requireTarget = false,
        useCounter = 0,
        lastUsed = {},
        useCount = {},
        minimap = {
            hide = false,
            angle = math.rad(200),
        },
    },
}

function EmotePicker:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("EmotePickerDB", defaults, true)
    self:CreateMinimapButton()
    self:RegisterChatCommand("ep", "SlashCommand")
    self:RegisterChatCommand("emotepicker", "SlashCommand")
end

function EmotePicker:SlashCommand(msg)
    msg = msg and msg:trim():lower() or ""

    if msg == "" then
        self:Toggle()
    elseif msg == "minimap" then
        self.db.profile.minimap.hide = not self.db.profile.minimap.hide
        self.minimapButton:SetShown(not self.db.profile.minimap.hide)
        self:Print(self.db.profile.minimap.hide and "Minimap button hidden" or "Minimap button shown")
    else
        self:Print("Usage: /ep - open the picker, /ep minimap - show or hide the minimap button")
    end
end
