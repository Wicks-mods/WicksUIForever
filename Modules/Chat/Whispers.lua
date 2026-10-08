-- Wick's UI
-- Modules/Chat/Whispers.lua: each whisper conversation in a window of its own.
--
-- A window per person, opened as a whisper comes in or goes out, with the
-- conversation kept between sessions. The game's own chat is left alone:
-- the line still lands in the chat window, the game's reply key still
-- answers the last whisper, and a line typed here goes out through the
-- game's own send from the key press that typed it, which is the one way
-- an addon may send. A slash command typed here is handed to the game's
-- chat box. Nothing here hooks the chat frames or filters a message.
--
-- Forever can hand a whisper over as secret text during an encounter. Such
-- a line is shown as the game hands it over and never kept, and a sender
-- the client keeps secret gets no window (the chat window still shows it).

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local W = ns.Widgets

local WH = ns:NewModule("whispers", { title = "Whispers", order = 51, defaults = {
    enable = true,
    popup = true,          -- open the window as a whisper comes in
    openOnSend = true,     -- and as one goes out
    history = true,        -- keep conversations between sessions
    keep = 200,            -- lines kept per person
    timestamps = true,
    width = 340,
    height = 220,
} })
ns.Whispers = WH

local issecret = rawget(_G, "issecretvalue") or function() return false end
local function db() return WH:db() end

-- Conversations live with the account: a whisper is the same talk on any
-- character.
local function store()
    local g = ns.A.db.global
    g.whispers = g.whispers or {}
    g.whispers.convos = g.whispers.convos or {}
    return g.whispers
end

local MAX_CONVOS = 40

local function prune(s)
    local n, oldest, oldestKey = 0
    for key, c in pairs(s.convos) do
        n = n + 1
        if not oldest or (c.last or 0) < oldest then oldest, oldestKey = c.last or 0, key end
    end
    if n > MAX_CONVOS and oldestKey then
        s.convos[oldestKey] = nil
        local win = WH.windows[oldestKey]
        if win then win:Hide() end
    end
end

local function convo(key, name, kind, id, class)
    local s = store()
    local c = s.convos[key]
    if not c then
        c = { name = name, kind = kind, id = id, lines = {} }
        s.convos[key] = c
        prune(s)
    end
    if class then c.class = class end
    if name then c.name = name end
    c.last = time()
    return c
end

local function remember(c, line)
    if not db().history then return end
    if issecret(line.text) then return end
    local lines = c.lines
    lines[#lines + 1] = line
    local keep = db().keep or 200
    while #lines > keep do table.remove(lines, 1) end
end

-- ============================================================
-- The window
-- ============================================================
WH.windows = {}

local function hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function colorCode(class)
    if class and Chrome.ClassColor then
        local ok, r, g, b = pcall(Chrome.ClassColor, Chrome, class)
        if ok and r then return hex(r, g, b) end
    end
    return Chrome:Esc("fel")
end

-- "Bob-Realm" reads as "Bob"; a Battle.net name is shown as it came.
local function shortName(c)
    if c.kind == "bn" then return c.name or "?" end
    local name = c.name or "?"
    return name:match("^([^%-]+)") or name
end

local function fontFor(msg)
    local cd = ns.A.db.profile.chat
    local face = cd and cd.font or "Wick"
    local size = cd and cd.fontSize or 13
    local outline = cd and cd.fontOutline or "NONE"
    if outline == "look" then outline = Chrome:StyleDef().textOutline or "NONE" end
    msg:SetFont(ns.Media:Font(face), size, outline == "NONE" and "" or outline)
    if msg.SetShadowOffset then msg:SetShadowOffset(1, -1) end
end

local function place(win, c)
    win:ClearAllPoints()
    local p = c.point
    if p and p.p then
        win:SetPoint(p.p, UIParent, p.p, p.x, p.y)
        return
    end
    -- Windows without a place of their own step down from the centre.
    local n = 0
    for _, w in pairs(WH.windows) do
        if w ~= win and w:IsShown() then n = n + 1 end
    end
    win:SetPoint("CENTER", UIParent, "CENTER", 40 * n, -30 * n)
end

local function savePoint(win)
    local p, _, _, x, y = win:GetPoint(1)
    if p and win.convo then win.convo.point = { p = p, x = x, y = y } end
end

local function stamp(t)
    if not db().timestamps then return "" end
    return Chrome:Esc("muted") .. date("%H:%M", t) .. "|r "
end

-- A line into the window. The text can be secret on Forever, in which case
-- it is given to the message frame on its own, as the game hands it over.
local function show(win, line, c)
    local who = line.out and (Chrome:Esc("text") .. "You|r") or (colorCode(c.class) .. shortName(c) .. "|r")
    local ok = pcall(function()
        win.msg:AddMessage(string.format("%s%s: %s", stamp(line.t), who, line.text))
    end)
    if not ok then
        win.msg:AddMessage(stamp(line.t) .. who .. ":")
        win.msg:AddMessage(line.text)
    end
end

local function newWindow(key, c)
    local d = db()
    local win = CreateFrame("Frame", nil, UIParent)
    win.key, win.convo = key, c
    win:SetSize(d.width or 340, d.height or 220)
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePoint(self) end)
    ns:SetTemplate(win, "Default", { brackets = true })
    Chrome:CloseOnEscape(win)

    local title = ns:CreateText(win, 12, "LEFT", "NONE")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetPoint("RIGHT", win, "RIGHT", -30, 0)
    win.title = title
    local close = W:Button(win, "x", 20, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -4, -4)

    -- The line you type. Enter sends and keeps the box for the next line;
    -- Escape lets go of it. The widget's own commit on focus loss is not
    -- wanted here, so none is given.
    local eb = W:EditBox(win, nil, 100, nil)
    eb:SetHeight(22)
    eb:ClearAllPoints()
    eb:SetPoint("BOTTOMLEFT", 8, 8)
    eb:SetPoint("BOTTOMRIGHT", -8, 8)
    eb:SetMaxLetters(255)
    eb:SetScript("OnEnterPressed", function(self) WH:Send(win, self:GetText()) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    win.eb = eb

    local msg = CreateFrame("ScrollingMessageFrame", nil, win)
    msg:SetPoint("TOPLEFT", 10, -30)
    msg:SetPoint("BOTTOMRIGHT", -10, 36)
    msg:SetJustifyH("LEFT")
    msg:SetFading(false)
    msg:SetMaxLines(d.keep or 200)
    if msg.SetIndentedWordWrap then msg:SetIndentedWordWrap(true) end
    if msg.SetHyperlinksEnabled then msg:SetHyperlinksEnabled(true) end
    msg:SetScript("OnHyperlinkClick", function(_, link, text, button)
        if ChatFrame_OnHyperlinkShow then pcall(ChatFrame_OnHyperlinkShow, ChatFrame1, link, text, button) end
    end)
    msg:EnableMouseWheel(true)
    msg:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    msg:SetScript("OnMouseDown", function() eb:SetFocus() end)
    fontFor(msg)
    win.msg = msg

    WH.windows[key] = win
    return win
end

function WH:Window(key, c, create)
    local win = self.windows[key]
    if not win and create then
        win = newWindow(key, c)
        for _, line in ipairs(c.lines) do show(win, line, c) end
    end
    return win
end

function WH:Open(key, c)
    local win = self:Window(key, c, true)
    win.convo = c
    win.title:SetText(colorCode(c.class) .. shortName(c) .. "|r")
    if not win:IsShown() then
        place(win, c)
        win:Show()
    end
    win.msg:ScrollToBottom()
    return win
end

-- ============================================================
-- Whispers in and out
-- ============================================================
local function whisper(out, text, who, kind, id, guid)
    if not db().enable then return end
    if issecret(who) or (id ~= nil and issecret(id)) then return end
    local key = kind == "bn" and ("bn:" .. tostring(id)) or who
    local class
    if not out and guid and not issecret(guid) and GetPlayerInfoByGUID then
        local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
        if ok and type(cls) == "string" then class = cls end
    end
    local c = convo(key, who, kind, id, class)
    local d = db()
    local open = out and d.openOnSend or (not out and d.popup)
    -- The window first, so the kept lines it draws stop short of this one.
    local win = WH.windows[key]
    if open and not win then win = WH:Window(key, c, true) end
    local line = { t = time(), out = out, text = text }
    remember(c, line)
    if win then show(win, line, c) end
    if open then WH:Open(key, c) elseif win and win:IsShown() then win.msg:ScrollToBottom() end
end

function WH:Send(win, text)
    text = tostring(text or "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        win.eb:ClearFocus()
        return
    end
    local c = win.convo
    win.eb:SetText("")
    -- A slash command belongs to the game's chat box, not to the whisper.
    if text:sub(1, 1) == "/" then
        if ChatFrame_OpenChat then ChatFrame_OpenChat(text, ChatFrame1) end
        return
    end
    -- While the client has chat locked down (Forever, during an encounter)
    -- the send is not called at all: a refused protected call raises the
    -- game's blocked-action warning, which no pcall catches.
    local R = ns.Core.Restrict
    local blocked = R and R.ChatBlocked and R:ChatBlocked()
    local ok = false
    if not blocked then
        if c.kind == "bn" then
            ok = pcall(BNSendWhisper, c.id, text)
        else
            ok = pcall(SendChatMessage, text, "WHISPER", nil, c.name)
        end
    end
    if not ok and c.kind ~= "bn" and ChatFrame_OpenChat then
        -- The client would not take the send from here; the line goes to
        -- the game's own box with the whisper filled in.
        ChatFrame_OpenChat("/w " .. tostring(c.name) .. " " .. text, ChatFrame1)
    elseif not ok then
        win.eb:SetText(text)
    end
end

function WH:OpenAll()
    for key, c in pairs(store().convos) do self:Open(key, c) end
end

function WH:Clear()
    for _, win in pairs(self.windows) do win:Hide() end
    wipe(store().convos)
end

-- ============================================================
-- Lifecycle
-- ============================================================
function WH:Initialize()
    -- Event payloads: text, who, ... and the sender's GUID twelfth, the
    -- Battle.net account thirteenth. For a line of yours, "who" is the
    -- person it went to.
    ns:On("CHAT_MSG_WHISPER", function(_, text, sender, ...)
        whisper(false, text, sender, "char", nil, (select(10, ...)))
    end)
    ns:On("CHAT_MSG_WHISPER_INFORM", function(_, text, target)
        whisper(true, text, target, "char")
    end)
    ns:On("CHAT_MSG_BN_WHISPER", function(_, text, sender, ...)
        whisper(false, text, sender, "bn", (select(11, ...)))
    end)
    ns:On("CHAT_MSG_BN_WHISPER_INFORM", function(_, text, target, ...)
        whisper(true, text, target, "bn", (select(11, ...)))
    end)
end

function WH:Update()
    local d = db()
    for _, win in pairs(self.windows) do
        win:SetSize(d.width or 340, d.height or 220)
        win.msg:SetMaxLines(d.keep or 200)
        fontFor(win.msg)
    end
end

ns.Config:AddPage("whispers", "Whispers", function(L)
    L:DB(db)
    L:Note("Each person you whisper with gets a window of their own, kept between sessions. The line still shows in the chat window, and the game's reply key still answers the last whisper. Enter sends from the window. A slash command typed there goes to the game's own chat box.")
    L:Toggle("Whisper windows", "enable")
    L:Toggle("Open as a whisper comes in", "popup")
    L:Toggle("Open as one goes out", "openOnSend")
    L:Toggle("Keep conversations between sessions", "history")
    L:Slider("Lines kept per person", "keep", 20, 1000, 10)
    L:Toggle("Time on each line", "timestamps")
    L:Slider("Window width", "width", 200, 800, 10)
    L:Slider("Window height", "height", 120, 600, 10)
    L:Button("Open every kept conversation", function() WH:OpenAll() end)
    L:Button("Forget every conversation", function() WH:Clear() end)
    L:Note("The game's own Whisper Mode, under Social in its settings, can open whispers in tabs of its own as well. Inline there leaves whispers to these windows.")
end, { onChange = function() WH:Update() end, order = 51 })
