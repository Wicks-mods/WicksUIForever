-- Wick's UI
-- Modules/Chat/Chat.lua: flat chat windows.
--
-- Chat is where taint hurts most on this client: during an encounter a
-- message can arrive carrying secret values, and Blizzard's chat code
-- compares them. It may do that only while it runs untainted. So this
-- file never writes a field into a chat frame, never hooks AddMessage and
-- never adds a message filter. Everything here is a method call on their
-- widgets (clear a texture, set a font, set a point) or a frame of our own.
--
-- Positions stay with Edit Mode, which owns the chat frame on this client.
-- Our panel follows the frame wherever Edit Mode puts it.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local CH = ns:NewModule("chat", { title = "Chat", order = 50 })
ns.Chat = CH

ns.defaults.profile.chat = {
    enable = true,
    panel = true,             -- a Wick panel behind the main chat window
    panelAlpha = 0.65,
    font = "Wick", fontSize = 13, fontOutline = "NONE",
    tabFontSize = 12,
    fade = true, fadeAfter = 30,
    editBoxTop = false,
    hideButtons = true,
    copyButton = true,
    maxLines = 500,
}

local function db() return CH:db() end
local styled = setmetatable({}, { __mode = "k" })
local ours = setmetatable({}, { __mode = "k" })   -- our additions, keyed by their frame

local TEXTURES = {
    "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
    "ButtonFrameBackground", "ButtonFrameTopLeftTexture", "ButtonFrameBottomLeftTexture",
    "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
    "ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture",
}
local TAB_PARTS = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "HighlightLeft", "HighlightMiddle", "HighlightRight", "LeftTexture", "MiddleTexture", "RightTexture",
    "LeftHighlightTexture", "MiddleHighlightTexture", "RightHighlightTexture",
    "LeftSelectedTexture", "MiddleSelectedTexture", "RightSelectedTexture" }
local EDIT_PARTS = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }

-- Blizzard fades these by alpha, so clearing the texture is what sticks.
local function clear(tex)
    if tex and tex.SetTexture then tex:SetTexture(nil) end
    if tex and tex.SetAtlas then pcall(tex.SetAtlas, tex, nil) end
end

local function styleTab(tab)
    if not tab then return end
    local name = tab:GetName()
    for _, part in ipairs(TAB_PARTS) do
        clear(tab[part])
        if name then clear(_G[name .. part]) end
    end
    local text = tab.Text or (name and _G[name .. "Text"])
    if text then ns.Media:SetFont(text, db().tabFontSize, "OUTLINE", db().font) end
end

local function styleEditBox(frame)
    local eb = frame.editBox or _G[frame:GetName() .. "EditBox"]
    if not eb then return end
    local name = eb:GetName()
    for _, part in ipairs(EDIT_PARTS) do
        clear(eb[part])
        if name then clear(_G[name .. part]) end
    end
    local o = ours[eb] or {}
    ours[eb] = o
    if not o.backdrop then
        local bd = CreateFrame("Frame", nil, eb)
        bd:SetPoint("TOPLEFT", 2, -2)
        bd:SetPoint("BOTTOMRIGHT", -2, 2)
        bd:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
        ns:SetTemplate(bd, "Default")
        o.backdrop = bd
    end
    local d = db()
    eb:ClearAllPoints()
    if d.editBoxTop then
        eb:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -4, 24)
        eb:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 4, 24)
    else
        eb:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -4, -4)
        eb:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    end
end

local function scrollButton(frame)
    local o = ours[frame] or {}
    ours[frame] = o
    if o.scroll then return o.scroll end
    local b = W:Button(UIParent, "v", 20, function() frame:ScrollToBottom() end)
    b:SetParent(frame)
    b:SetFrameLevel(frame:GetFrameLevel() + 10)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    b:Hide()
    local t = 0
    b:SetScript("OnUpdate", nil)
    local ticker = CreateFrame("Frame", nil, b:GetParent())
    ticker:SetScript("OnUpdate", function(_, e)
        t = t + e
        if t < 0.25 then return end
        t = 0
        local atBottom = frame.AtBottom and frame:AtBottom()
        b:SetShown(frame:IsShown() and not atBottom)
    end)
    o.scroll = b
    return b
end

function CH:StyleFrame(frame)
    if not frame then return end
    local d = db()
    local name = frame:GetName()
    for _, t in ipairs(TEXTURES) do clear(_G[name .. t]) end
    local bf = frame.buttonFrame or _G[name .. "ButtonFrame"]
    if bf and d.hideButtons then bf:SetAlpha(0); bf:EnableMouse(false) end

    local _, size = frame:GetFont()
    frame:SetFont(ns.Media:Font(d.font), d.fontSize or size or 13, d.fontOutline == "NONE" and "" or d.fontOutline)
    if frame.SetShadowOffset then frame:SetShadowOffset(1, -1) end
    if frame.SetFading then frame:SetFading(d.fade) end
    if frame.SetTimeVisible then frame:SetTimeVisible(d.fadeAfter) end
    if frame.SetMaxLines and (frame:GetMaxLines() or 0) < d.maxLines then frame:SetMaxLines(d.maxLines) end

    styleTab(_G[name .. "Tab"])
    styleEditBox(frame)
    scrollButton(frame)
    styled[frame] = true
end

-- ============================================================
-- The panel
-- ============================================================
function CH:Panel()
    local p = self.panel
    if not p then
        p = CreateFrame("Frame", "WicksUI_ChatPanel", UIParent)
        p:SetFrameStrata("BACKGROUND")
        ns:SetTemplate(p, "Transparent", { brackets = true })
        self.panel = p

        local copy = W:Button(p, "Copy", 44, function() CH:ShowCopy(SELECTED_CHAT_FRAME or ChatFrame1) end)
        copy:SetHeight(16)
        copy:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
        copy.text:SetText("|cff8f8770copy|r")
        p.copy = copy
    end
    local cf = _G.ChatFrame1
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cf, "TOPLEFT", -6, 30)
    p:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 6, -8)
    local d = db()
    p.wuiBG:SetAlpha(d.panelAlpha / 0.65)
    p:SetShown(d.panel)
    p.copy:SetShown(d.copyButton)
end

-- ============================================================
-- Copy chat
-- ============================================================
local issecret = rawget(_G, "issecretvalue")
function CH:ShowCopy(frame)
    local win = self.copyWin
    if not win then
        win = CreateFrame("Frame", "WicksUI_ChatCopy", UIParent)
        win:SetSize(620, 360)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        win:EnableMouse(true)
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
        ns:SetTemplate(win, "Default", { brackets = true })
        local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -30)
        sf:SetPoint("BOTTOMRIGHT", -30, 10)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetWidth(570)
        ns.Media:SetFont(eb, 12, "NONE")
        eb:SetScript("OnEscapePressed", function() win:Hide() end)
        sf:SetScrollChild(eb)
        win.eb = eb
        local title = ns:CreateText(win, 12, "LEFT", "NONE")
        title:SetPoint("TOPLEFT", 10, -9)
        title:SetText(Chrome:TitleMarkup("Wick's UI") .. "  |cff8f8770copy chat. Select and press Ctrl-C.|r")
        local close = W:Button(win, "x", 20, function() win:Hide() end)
        close:SetPoint("TOPRIGHT", -4, -4)
        Chrome:CloseOnEscape(win)
        self.copyWin = win
    end
    local lines = {}
    local n = frame.GetNumMessages and frame:GetNumMessages() or 0
    local skipped = 0
    for i = 1, n do
        local text = frame:GetMessageInfo(i)
        if text and not (issecret and issecret(text)) then
            lines[#lines + 1] = text
        elseif text then
            skipped = skipped + 1
        end
    end
    if skipped > 0 then
        lines[#lines + 1] = ("|cff8f8770(%d line%s from an encounter left out: the client keeps them from addons.)|r"):format(skipped, skipped == 1 and "" or "s")
    end
    win.eb:SetText(table.concat(lines, "\n"))
    win:Show()
    win.eb:SetFocus()
    win.eb:HighlightText()
end

-- ============================================================
-- Lifecycle
-- ============================================================
local HIDE = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }

function CH:StyleAll()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f then self:StyleFrame(f) end
    end
    if CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do
            local f = _G[name]
            if f and not styled[f] then self:StyleFrame(f) end
        end
    end
end

function CH:Initialize()
    if db().hideButtons then
        for _, n in ipairs(HIDE) do
            local f = _G[n]
            if f then ns:Kill(f, { keepEvents = true }) end
        end
    end
    self:StyleAll()
    self:Panel()
    ns:On("UPDATE_CHAT_WINDOWS", function() CH:StyleAll() end)
    ns:On("UPDATE_FLOATING_CHAT_WINDOWS", function() CH:StyleAll() end)
    -- Whisper windows are made on the fly.
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function() C_Timer.After(0, function() CH:StyleAll() end) end)
    end
end

function CH:Update()
    for f in pairs(styled) do self:StyleFrame(f) end
    self:Panel()
end

ns.Config:AddPage("chat", "Chat", function(L)
    L:DB(db)
    L:Note("The chat windows stay where Edit Mode puts them. Everything here is the look. Nothing in this module touches the messages themselves, which this client can hand over as secrets during an encounter.")
    L:Toggle("Wick panel behind the chat", "panel")
    L:Slider("Panel alpha", "panelAlpha", 0, 1, 0.05)
    L:Toggle("Copy button on the panel", "copyButton")
    L:Toggle("Hide the chat buttons", "hideButtons", { tooltip = "The menu, channel and social buttons beside the chat. Takes effect after a reload." })
    L:Heading("Text")
    L:Dropdown("Font", "font", function()
        local out = {}
        for _, name in ipairs(ns.Media:List("font")) do out[#out + 1] = { name, name, name } end
        return out
    end)
    L:Slider("Size", "fontSize", 8, 24, 1)
    L:Dropdown("Outline", "fontOutline", W.Values(ns.Media.outlines))
    L:Slider("Tab text size", "tabFontSize", 8, 20, 1)
    L:Heading("Behaviour")
    L:Toggle("Fade old lines", "fade")
    L:Slider("Fade after, seconds", "fadeAfter", 5, 300, 5)
    L:Toggle("Type above the chat", "editBoxTop")
    L:Slider("Lines kept", "maxLines", 128, 2000, 16)
end, { onChange = function() CH:Update() end, order = 50 })
