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
    alignToInfo = true,       -- the chat's panel as wide as the info panel under it, sat on it
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

-- Tab labels in the look's colours: the chosen tab in the accent, the
-- rest in the text colour. Blizzard paints them gold and marks the chosen
-- one with art we clear, so they all read alike. A tab Blizzard gives a
-- colour of its own (a whisper window's) keeps it. Set after Blizzard's
-- own colouring, from a post-hook: a method call on the label, nothing
-- written into the tab.
local function tabColour(tab, selected)
    if not tab or tab.selectedColorTable then return end
    local fs = tab.GetFontString and tab:GetFontString()
    if not fs then return end
    local c = selected and C.fel or C.text
    fs:SetTextColor(c[1], c[2], c[3])
end
CH.TabColour = tabColour

local function isSelected(tab)
    local sel = rawget(_G, "SELECTED_CHAT_FRAME")
    return sel ~= nil and tab.GetID and _G["ChatFrame" .. tab:GetID()] == sel
end

-- Blizzard sizes a docked tab for its label in Blizzard's font, and a tab
-- after the first two at a fixed width of at most 90: a look's wider face
-- then cuts the label short ("Loot / Tra..."). A tab whose label does not
-- fit is widened to fit it, after Blizzard has laid the tabs out. Method
-- calls on the tab only. Left alone: a whisper tab, whose name can be a
-- secret and which Blizzard holds at a fixed width for that reason, and a
-- dock already full enough to show its overflow arrow.
local TAB_SIDES = 20   -- Blizzard's padding either side of a tab's label
local function fitTab(tab)
    local fs = tab and tab.Text
    if not (fs and fs.GetUnboundedStringWidth) then return end
    local cf = tab.GetID and _G["ChatFrame" .. tab:GetID()]
    if cf and cf.chatTarget and (cf.chatType == "WHISPER" or cf.chatType == "BN_WHISPER") then return end
    local dock = rawget(_G, "GeneralDockManager")
    if dock and dock.overflowButton and dock.overflowButton:IsShown() then return end
    local tw = fs:GetUnboundedStringWidth()
    if type(tw) ~= "number" or (issecretvalue and issecretvalue(tw)) then return end
    local want = math.ceil(tw) + TAB_SIDES + (tab.sizePadding or 0)
    if (tab:GetWidth() or 0) + 0.5 < want then
        fs:SetWidth(math.ceil(tw) + 1)
        tab:SetWidth(want)
    end
end

local function fitTabs()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and tab:IsShown() then fitTab(tab) end
    end
end

local function styleTab(tab)
    if not tab then return end
    local name = tab:GetName()
    for _, part in ipairs(TAB_PARTS) do
        clear(tab[part])
        if name then clear(_G[name .. part]) end
    end
    local text = tab.Text or (name and _G[name .. "Text"])
    if text then ns.Media:SetFont(text, db().tabFontSize, "look", db().font) end
    tabColour(tab, isSelected(tab))
    fitTab(tab)
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
    -- This client has its own jump-to-bottom arrow: it gets our chevron (in
    -- the text colour, the accent on hover) and ours is not made. It shows
    -- and hides itself as the chat scrolls, as before.
    local own = frame.ScrollToBottomButton
    if own then
        ns:Glyph(own, "down", { tile = false, size = 12 })
        if own.Flash then own.Flash:SetAlpha(0) end
        o.scroll = own
        return own
    end
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
    local outline = d.fontOutline
    if outline == "look" then outline = Chrome:StyleDef().textOutline or "NONE" end
    frame:SetFont(ns.Media:Font(d.font), d.fontSize or size or 13, outline == "NONE" and "" or outline)
    if frame.SetShadowOffset then frame:SetShadowOffset(1, -1) end
    if frame.SetFading then frame:SetFading(d.fade) end
    if frame.SetTimeVisible then frame:SetTimeVisible(d.fadeAfter) end
    if frame.SetMaxLines and (frame:GetMaxLines() or 0) < d.maxLines then frame:SetMaxLines(d.maxLines) end

    styleTab(_G[name .. "Tab"])
    styleEditBox(frame)
    scrollButton(frame)
    -- The chat's scroll bar in the look every other one has.
    ns:StyleScrollBar(frame.ScrollBar)
    styled[frame] = true
end

-- ============================================================
-- The panel
-- ============================================================
-- Lined up with the info panel under it: the chat's panel reaches the
-- panel's two edges and sits a few pixels above it. The chat window is
-- Blizzard's and Edit Mode places it, so this is held (out of combat, a
-- few times a second) rather than set once; turning it off hands the chat
-- back to Edit Mode after a reload.
local GAP = 4
-- Inside the panel the text keeps margins of its own, not the Edit Mode
-- box's padding, which left it well in from the panel's left edge and a
-- wide empty strip down the right: a few pixels in on the left, to the
-- right edge less room for the scroll bar, and a little lower than the
-- box's padding would sit it.
local LEFT_PAD = 4
local RIGHT_PAD = 4
local SCROLL_ROOM = 12
local DROP = 6

-- Blizzard's Edit Mode box for the chat (its Selection frame) is larger
-- than the chat's text area, padded on every side. The panel fills that
-- box, so a box pushed into the corner puts the panel there too, as the
-- minimap does. Where this build has no Selection frame the panel keeps
-- to the text area with our own margins.
local function box(cf)
    local sel = cf and cf.Selection
    if sel and sel.GetLeft and sel:GetLeft() and cf:GetLeft() then return sel end
end
CH.ChatBox = box

-- The panel takes the box's sides and bottom, so no gap shows beside the
-- chat, but its top stays just over the tabs: the box's own padding above
-- them was empty space.
function CH:FitPanel()
    local p, cf = self.panel, _G.ChatFrame1
    if not (p and cf) then return end
    local l, r, bt = 6, 6, 8
    local sel = box(cf)
    if sel then
        l = cf:GetLeft() - sel:GetLeft()
        r = sel:GetRight() - cf:GetRight()
        bt = cf:GetBottom() - sel:GetBottom()
    end
    local info = ns.DataTexts and ns.DataTexts.panels and ns.DataTexts.panels.left
    local aligned = db().alignToInfo and info and info:IsShown() and info:GetTop() and cf:GetTop()
    -- How far above the info panel the panel's top sits: just over the tabs.
    local topOff = aligned and math.floor(cf:GetTop() + 30 - info:GetTop() + 0.5) or 0
    local key = ("%s,%.1f,%.1f,%.1f,%d"):format(tostring(aligned and true), l, r, bt, topOff)
    if key == self.fitKey then return end
    self.fitKey = key
    p:ClearAllPoints()
    if aligned then
        -- The panel is the info panel's width, sat on it; the chat inside
        -- is nudged left (see CH:Align), the panel is not.
        p:SetPoint("TOPLEFT", info, "TOPLEFT", 0, topOff)
        p:SetPoint("BOTTOMRIGHT", info, "TOPRIGHT", 0, GAP)
    else
        p:SetPoint("TOPLEFT", cf, "TOPLEFT", -l, 30)
        p:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", r, -bt)
    end
end

function CH:Align()
    local d = db()
    if not d.alignToInfo or InCombatLockdown() then return end
    local cf = _G.ChatFrame1
    local info = ns.DataTexts and ns.DataTexts.panels and ns.DataTexts.panels.left
    if not (cf and info and info:IsShown()) then return end
    local w = info:GetWidth()
    if not (w and w > 20) then return end
    -- How far the box reaches past the text area on each side (our own
    -- margins where there is no box).
    local l, r, bt = 6, 6, 8
    local sel = box(cf)
    if sel then
        l = cf:GetLeft() - sel:GetLeft()
        r = sel:GetRight() - cf:GetRight()
        bt = cf:GetBottom() - sel:GetBottom()
    end
    -- Edit Mode keeps the chat's box on screen by holding the chat as far
    -- in from the screen's edges as the box is padded (its clamp insets).
    -- Beside an info panel at the screen's edge that held the chat well in
    -- from where it was put. The chat itself is still kept on screen.
    if cf.GetClampRectInsets and cf.SetClampRectInsets then
        local a, b, c, e = cf:GetClampRectInsets()
        if (a or 0) ~= 0 or (b or 0) ~= 0 or (c or 0) ~= 0 or (e or 0) ~= 0 then cf:SetClampRectInsets(0, 0, 0, 0) end
    end
    local left = LEFT_PAD
    local up = GAP + math.max(0, bt - DROP)
    local p, rel, rp, x, y = cf:GetPoint(1)
    if p ~= "BOTTOMLEFT" or rel ~= info or rp ~= "TOPLEFT" or math.abs((x or 0) - left) > 0.5
        or math.abs((y or 0) - up) > 0.5 or cf:GetNumPoints() ~= 1 then
        cf:ClearAllPoints()
        cf:SetPoint("BOTTOMLEFT", info, "TOPLEFT", left, up)
    end
    -- The width from where the chat really is, so whatever holds it in, its
    -- text stops inside the panel rather than running past its right side.
    local cl, ir = cf:GetLeft(), info:GetRight()
    local want = (cl and ir) and (ir - RIGHT_PAD - SCROLL_ROOM - cl) or (w - left - RIGHT_PAD - SCROLL_ROOM)
    if want > 50 and math.abs((cf:GetWidth() or 0) - want) > 0.5 then cf:SetWidth(want) end
end

local holder = CreateFrame("Frame")
local holdAcc = 0
holder:SetScript("OnUpdate", function(_, e)
    holdAcc = holdAcc + e
    if holdAcc < 0.25 then return end
    holdAcc = 0
    if CH.initialized and db().enable then CH:Align(); CH:FitPanel() end
end)
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
        copy.text:SetText(Chrome:Esc("muted") .. "copy|r")
        p.copy = copy
    end
    local cf = _G.ChatFrame1
    self:Align()
    -- Placed afresh: the fit is skipped when nothing has changed, and a
    -- panel whose points were cleared has nowhere to be.
    self.fitKey = nil
    self:FitPanel()
    local d = db()
    p.wuiBG:SetAlpha(d.panelAlpha / 0.65)
    -- The damage meter's panel follows this one.
    if ns.Skins and ns.Skins.DamageMeter then pcall(ns.Skins.DamageMeter, ns.Skins) end
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
        title:SetText(Chrome:TitleMarkup("Wick's UI") .. "  " .. Chrome:Esc("muted") .. "copy chat. Select and press Ctrl-C.|r")
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
        lines[#lines + 1] = (Chrome:Esc("muted") .. "(%d line%s from an encounter left out: the client keeps them from addons.)|r"):format(skipped, skipped == 1 and "" or "s")
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
    -- Blizzard lays the docked tabs out again as windows come and go.
    if rawget(_G, "FCFDock_UpdateTabs") then
        hooksecurefunc("FCFDock_UpdateTabs", function() fitTabs() end)
    end
    -- Blizzard colours a tab each time the chosen one changes.
    if rawget(_G, "FCFTab_UpdateColors") then
        hooksecurefunc("FCFTab_UpdateColors", function(tab, selected) tabColour(tab, selected) end)
    end
    if Chrome.OnThemeChanged then
        Chrome:OnThemeChanged(function()
            for i = 1, (NUM_CHAT_WINDOWS or 10) do
                local tab = _G["ChatFrame" .. i .. "Tab"]
                if tab then tabColour(tab, isSelected(tab)) end
            end
        end)
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
    L:Toggle("Line up with the info panel", "alignToInfo", { tooltip = "The chat window is made as wide as the info panel under it and sits just above it. Off leaves it to Edit Mode (after a reload)." })
    L:Slider("Panel opacity", "panelAlpha", 0, 1, 0.05, { tooltip = "How solid the chat panel is. The damage meter's panel follows it, so the two match." })
    L:Toggle("Copy button on the panel", "copyButton")
    L:Toggle("Hide the chat buttons", "hideButtons", { tooltip = "The menu, channel and social buttons beside the chat. Takes effect after a reload." })
    L:Heading("Text")
    L:Dropdown("Font", "font", function()
        local out = {}
        for _, name in ipairs(ns.Media:List("font")) do out[#out + 1] = { name, name, name } end
        return out
    end)
    L:Slider("Size", "fontSize", 8, 24, 1)
    L:Dropdown("Outline", "fontOutline", W.Values(ns.Media.outlines, ns.Media.outlineLabels))
    L:Slider("Tab text size", "tabFontSize", 8, 20, 1)
    L:Heading("Behaviour")
    L:Toggle("Fade old lines", "fade")
    L:Slider("Fade after, seconds", "fadeAfter", 5, 300, 5)
    L:Toggle("Type above the chat", "editBoxTop")
    L:Slider("Lines kept", "maxLines", 128, 2000, 16)
end, { onChange = function() CH:Update() end, order = 50 })
