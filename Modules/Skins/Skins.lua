-- Wick's UI
-- Modules/Skins/Skins.lua: the Blizzard pieces we restyle but do not replace.
--
-- The rule on this client is to call methods on Blizzard's frames and
-- never write into their tables. So a skin here fades a frame's own
-- textures by alpha, sets fonts, and lays a Wick panel of ours behind it.
-- Only a frame's own regions are touched, never its descendants' by
-- default: the damage meter's bars draw secret combat numbers, and a
-- recursive strip would reach them.
--
-- Positions stay with Edit Mode throughout.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local SK = ns:NewModule("skins", { title = "Blizzard frames", order = 95 })
ns.Skins = SK

ns.defaults.profile.skins = {
    enable = true,
    tracker = true, trackerFontSize = 14,
    damageMeter = true,
    meterAlign = true,           -- the meter as wide as the right info panel, sat on it
    meterHeight = 150,           -- its height while lined up (0 leaves it to Edit Mode)
    microMenu = "mouseover",     -- show, mouseover, hide
    bagsBar = "mouseover",
    swingTimers = true,          -- the game's swing timers in the look
}

local function db() return SK:db() end
local panels = setmetatable({}, { __mode = "k" })

-- Fade a frame's own textures, keep its text.
local function strip(frame, keep)
    if not frame or not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and not (keep and keep[r]) then
            r:SetAlpha(0)
        end
    end
end

local function panelBehind(frame, template, inset, brackets)
    local p = panels[frame]
    if p then return p end
    p = CreateFrame("Frame", nil, frame)
    local o = inset or 0
    p:SetPoint("TOPLEFT", -o, o)
    p:SetPoint("BOTTOMRIGHT", o, -o)
    p:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    ns:SetTemplate(p, template or "Transparent", { brackets = brackets })
    panels[frame] = p
    return p
end

-- ============================================================
-- Objective tracker
-- ============================================================
local TRACKERS = { "ObjectiveTrackerFrame", "QuestObjectiveTracker", "CampaignQuestObjectiveTracker",
    "AchievementObjectiveTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
    "ScenarioObjectiveTracker", "ProfessionsRecipeTracker", "MonthlyActivitiesObjectiveTracker",
    "AdventureObjectiveTracker", "InitiativeTasksObjectiveTracker", "UIWidgetObjectiveTracker" }

function SK:Tracker()
    if not db().tracker then return end
    -- The default went from 12 to 14; a profile still on the old default
    -- moves up once, and a size picked after that stands.
    local g = ns:G()
    if not g.trackerSize14 then
        g.trackerSize14 = true
        if db().trackerFontSize == 12 then db().trackerFontSize = 14 end
    end
    local font = ns.Media:Font()
    local size = db().trackerFontSize
    for _, name in ipairs(TRACKERS) do
        local t = _G[name]
        local h = t and t.Header
        if h then
            strip(h)
            local text = h.Text
            if text then
                text:SetFont(font, size + 2, "OUTLINE")
                text:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
                Chrome:Register(text, C.fel, "text")
            end
            -- A thin fel rule under each header in place of the gold bar.
            local p = panels[h]
            if not p then
                p = h:CreateTexture(nil, "ARTWORK")
                p:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.6)
                p:SetHeight(ns.mult or 1)
                p:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 2)
                p:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 2)
                Chrome:Register(p, "fel", "texture", 0.6)
                panels[h] = p
            end
        end
    end
    -- The lines are drawn with shared font objects; setting those restyles
    -- every line, including ones made later.
    for _, fo in ipairs({ "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont", "ObjectiveFont" }) do
        local f = rawget(_G, fo)
        if f and f.SetFont then
            local _, s = f:GetFont()
            f:SetFont(font, fo == "ObjectiveTrackerHeaderFont" and (size + 1) or size, "OUTLINE")
            if f.SetShadowOffset then f:SetShadowOffset(0, 0) end
        end
    end
end

-- ============================================================
-- Damage meter
-- ============================================================
-- The small buttons in a meter window's header: Blizzard's yellow and red
-- squares greyed, each on a black tile of ours.
local tiled = setmetatable({}, { __mode = "k" })
local function tileButton(b, fadeKey)
    if not b or tiled[b] then return end
    tiled[b] = true
    if fadeKey and b[fadeKey] then b[fadeKey]:SetAlpha(0) end
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetDrawLayer() ~= "HIGHLIGHT" and r ~= b[fadeKey or ""] and r.SetDesaturated then
            r:SetDesaturated(true)
            r:SetVertexColor(0.85, 0.85, 0.85)
        end
    end
    local t = CreateFrame("Frame", nil, b)
    t:SetPoint("CENTER", 0, 0)
    t:SetSize(20, 20)
    t:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    ns:SetTemplate(t, "Default", { alpha = 0.9, shadow = false })
end

-- Blizzard sets the three header buttons a few pixels apart in height and
-- size; with our tiles on them that shows. They go on one line from the
-- header's right edge, 20 px apart plus a gap, centred on the header.
function SK:AlignMeterHeader(win)
    local h = win.Header
    local mb, sd, ss = win.MinimizeButton, win.SettingsDropdown, win.SessionDropdown
    if not (h and mb and sd and ss) or InCombatLockdown() then return end
    local function put(b, point, rel, relPoint, x, y)
        local p, r, rp, px, py = b:GetPoint(1)
        if p ~= point or r ~= rel or rp ~= relPoint or math.abs((px or 0) - x) > 0.5 or math.abs((py or 0) - y) > 0.5 then
            b:ClearAllPoints()
            b:SetPoint(point, rel, relPoint, x, y)
        end
    end
    put(mb, "RIGHT", h, "RIGHT", -6, 0)
    put(sd, "CENTER", mb, "CENTER", -24, 0)
    put(ss, "CENTER", sd, "CENTER", -24, 0)
end

-- The first meter window lined up with the right info panel: as wide as
-- it and sat a few pixels above it. The meter is Edit Mode's, so this is
-- held out of combat rather than set once.
function SK:AlignMeter()
    if not db().meterAlign or InCombatLockdown() then return end
    local win = rawget(_G, "DamageMeterSessionWindow1")
    local info = ns.DataTexts and ns.DataTexts.panels and ns.DataTexts.panels.right
    if not (win and info and info:IsShown() and win:IsShown()) then return end
    local w = info:GetWidth()
    if not (w and w > 20) then return end
    if math.abs((win:GetWidth() or 0) - w) > 0.5 then win:SetWidth(w) end
    local h = db().meterHeight or 0
    if h > 0 and math.abs((win:GetHeight() or 0) - h) > 0.5 then win:SetHeight(h) end
    local p, rel, rp, x, y = win:GetPoint(1)
    if p ~= "BOTTOMRIGHT" or rel ~= info or rp ~= "TOPRIGHT" or math.abs(x or 0) > 0.5
        or math.abs((y or 0) - 4) > 0.5 or win:GetNumPoints() ~= 1 then
        win:ClearAllPoints()
        win:SetPoint("BOTTOMRIGHT", info, "TOPRIGHT", 0, 4)
    end
end

-- The meter's panel takes the chat panel's see-through setting, so the two
-- always match; Panel alpha on the Chat page sets both.
function SK:MatchChat(p)
    local chat = ns.A and ns.A.db and ns.A.db.profile and ns.A.db.profile.chat
    local a = chat and chat.panelAlpha or 0.65
    if p and p.wuiBG then p.wuiBG:SetAlpha(a / 0.65) end
end

-- The meter's text in the Wick font (the style's own, where it has one),
-- a size up as in the skinned windows. The bars are recycled as the list
-- changes, so a light pass goes over every string once a second, out of
-- combat only: in a fight the client may lock the bars away, and a font is
-- never worth an error. Setting a font never reads the bar's numbers,
-- which the client keeps secret. A string already in our font is left.
local meterFonts = setmetatable({}, { __mode = "k" })
local function meterFont(fs)
    local ok, path, size, flags = pcall(fs.GetFont, fs)
    if not ok or not path or not size or size < 1 or size > 64 then return end
    local want = ns.Media:Font()
    if path:lower():gsub("/", "\\") == want:lower():gsub("/", "\\") then return end
    local target = meterFonts[fs] or math.floor(size + 1.5)
    if pcall(fs.SetFont, fs, want, target, flags or "") then
        pcall(fs.SetShadowOffset, fs, 1, -1)
        pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.8)
        meterFonts[fs] = target
    end
end
local function walkMeter(f, depth)
    if depth > 9 or (f.IsForbidden and f:IsForbidden()) then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then meterFont(r) end
    end
    for _, c in ipairs({ f:GetChildren() }) do walkMeter(c, depth + 1) end
end
-- The bars in the look's colours (ns:MeterBarColor), where the theme is not
-- the class colours. Blizzard paints a bar only when its colour changes
-- (it keeps the last one), so ours stays on; ns:Follow watches the bar's
-- colour and puts ours back whenever Blizzard paints, in a fight too.
-- Method calls only: nothing is written into the meter's own rows.
local meterBars = setmetatable({}, { __mode = "k" })
local painting = false

-- The bar's colour as one number, for ns:Follow; nil while any part of
-- it is a secret.
local function barColour(entry)
    local tex = entry.GetStatusBarTexture and entry:GetStatusBarTexture()
    if not tex then return nil end
    local r, g, b = tex:GetVertexColor()
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return nil end
    return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5)
end
local function paintBar(entry, tex)
    if painting then return end
    local mine = entry.isLocalPlayer
    if issecretvalue and issecretvalue(mine) then mine = false end
    local c = ns:MeterBarColor(mine and true or false)
    if not c then return end
    painting = true
    pcall(tex.SetVertexColor, tex, c[1], c[2], c[3])
    painting = false
end
local function hookBar(entry)
    local tex = entry.GetStatusBarTexture and entry:GetStatusBarTexture()
    if not tex then return end
    if not meterBars[tex] then
        meterBars[tex] = entry
        ns:Follow(entry, barColour, function(e) paintBar(e, e:GetStatusBarTexture()) end)
    end
    paintBar(entry, tex)
end
SK.MeterBars = meterBars
local function meterBarsPass(dm)
    for _, win in ipairs({ dm:GetChildren() }) do
        local box = win.GetScrollBox and win:GetScrollBox()
        if box and box.ForEachFrame then
            box:ForEachFrame(function(entry) if entry.isClassColorDesired ~= nil or entry.StatusBar then hookBar(entry) end end)
        end
    end
end

function SK:MeterFonts()
    if not db().damageMeter or InCombatLockdown() then return end
    local dm = rawget(_G, "DamageMeter")
    if dm then
        pcall(walkMeter, dm, 1)
        pcall(meterBarsPass, dm)
    end
end
if Chrome.OnThemeChanged then
    Chrome:OnThemeChanged(function() for tex, entry in pairs(meterBars) do paintBar(entry, tex) end end)
end
do
    local acc = 0
    local t = CreateFrame("Frame")
    t:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 1 then return end
        acc = 0
        SK:MeterFonts()
    end)
end
ns:On("PLAYER_REGEN_ENABLED", function() SK:MeterFonts() end)

function SK:DamageMeter()
    if not db().damageMeter then return end
    local dm = rawget(_G, "DamageMeter")
    if not dm then return end
    strip(dm)
    for _, win in ipairs({ dm:GetChildren() }) do
        -- Session windows: the frame's own art only. Their bars live in a
        -- scroll box further down and are left exactly as they are.
        strip(win)
        if win.Header then strip(win.Header) end
        if win.NineSlice then win.NineSlice:SetAlpha(0) end
        -- Blizzard's brown backing (on the window's MinimizeContainer) is
        -- what tinted the meter; without it the meter is our glass, the
        -- colour of the chat panel.
        if win.MinimizeContainer then strip(win.MinimizeContainer) end
        if win:IsShown() then
            -- The OG style's fel corners on the meter, as on every panel.
            local p = panelBehind(win, "Transparent", nil, not ns:Modern())
            SK:MatchChat(p)
        end
        ns:Glyph(win.MinimizeButton, "minus", { tileSize = 20 })
        ns:Glyph(win.SettingsDropdown, "gear", { tileSize = 20 })
        tileButton(win.SessionDropdown, "Background")
        ns:Glyph(win.DamageMeterTypeDropdown, "down", { tileSize = 20 })
        SK:AlignMeterHeader(win)
        if win.SessionDropdown and win.SessionDropdown.SessionName then
            win.SessionDropdown.SessionName:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
end

-- ============================================================
-- Swing timers
-- ============================================================
-- The game's own swing timers (main hand, off hand, ranged), which Edit
-- Mode places. Their art is cleared rather than faded: Blizzard dims the
-- background and frame by alpha when you are out of range, which would
-- bring a faded texture back. The bar takes our texture in the look's
-- accent (the off hand a darker shade of it, so the two read apart) over
-- a panel of ours that dims with it; the labels take the look's font and
-- keep Blizzard's out-of-range colour. Method calls on their regions;
-- the bar's texture and alpha, which Blizzard sets again as it lays the
-- bar out and as you go in and out of range, are followed with ns:Follow.
local SWING = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }
local swingDone = setmetatable({}, { __mode = "k" })

local function clearTex(t)
    if not t then return end
    if t.SetAtlas then pcall(t.SetAtlas, t, nil) end
    if t.SetTexture then t:SetTexture(nil) end
end

local function swingColour(f)
    local sb = f.StatusBar
    if not sb then return end
    local c = C.fel
    if f:GetName() == "SwingTimerOffHandFrame" then
        local v = C.void
        c = { c[1] * 0.6 + v[1] * 0.4, c[2] * 0.6 + v[2] * 0.4, c[3] * 0.6 + v[3] * 0.4 }
    end
    sb:SetStatusBarTexture(ns.Media:Statusbar())
    sb:SetStatusBarColor(c[1], c[2], c[3], 1)
end

local function swingDim(f)
    local e = swingDone[f]
    local sb = f.StatusBar
    if e and e.backdrop and sb then e.backdrop:SetAlpha(sb:GetAlpha() or 1) end
end

local function skinSwing(f)
    if not f or swingDone[f] then return end
    local sb = f.StatusBar
    if not sb then return end
    local e = {}
    swingDone[f] = e
    clearTex(f.Background)
    clearTex(f.Border)
    clearTex(sb.TypeLabelShadow)
    e.backdrop = ns:CreateBackdrop(sb, "Default", ns.mult)
    -- A bar texture picked in the settings reaches it at once.
    ns:TrackStatusBar(sb)
    for _, fs in ipairs({ sb.TypeLabel, sb.TimeLabel }) do
        if fs and fs.GetFont then
            local _, size = fs:GetFont()
            ns.Media:SetFont(fs, math.floor((size or 10) + 0.5), "look")
        end
    end
    swingColour(f)
    ns:Follow(f, function(fr)
        local bar = fr.StatusBar
        local t = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        return t and t.GetTexture and t:GetTexture() or nil
    end, swingColour)
    ns:Follow(f, function(fr) return fr.StatusBar and fr.StatusBar:GetAlpha() or nil end, swingDim)
    swingDim(f)
end

function SK:SwingTimers()
    if not db().swingTimers then return end
    for _, name in ipairs(SWING) do
        local f = rawget(_G, name)
        if f then skinSwing(f) end
    end
end
if Chrome.OnThemeChanged then
    Chrome:OnThemeChanged(function() for f in pairs(swingDone) do swingColour(f) end end)
end

-- ============================================================
-- Micro menu and bag bar
-- ============================================================
local faders = {}

local function fade(frame, mode)
    if not frame then return end
    if mode == "hide" then
        frame:SetAlpha(0)
        faders[frame] = nil
    elseif mode == "mouseover" then
        frame:SetAlpha(0)
        faders[frame] = true
    else
        frame:SetAlpha(1)
        faders[frame] = nil
    end
end

-- Polled rather than hooked: hooking their OnEnter would put our code in
-- their handler, and the pointer is usually over a child button anyway.
local poll = CreateFrame("Frame")
local acc = 0
poll:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.1 then return end
    acc = 0
    SK:AlignMeter()
    -- The bag bar's fold arrow turns as it is clicked.
    local toggle = rawget(_G, "BagBarExpandToggle")
    if toggle and ns.glyphs and ns.glyphs[toggle] and toggle:IsVisible() then
        ns:Glyph(toggle, ns:ArrowDirection(toggle) or "left", { tile = false, size = 12 })
    end
    for f in pairs(faders) do
        local over = f:IsVisible() and f:IsMouseOver(4, -4, -4, 4)
        local target = over and 1 or 0
        local a = f:GetAlpha()
        if math.abs(a - target) > 0.01 then f:SetAlpha(a + (target - a) * 0.5) end
    end
end)

-- The micro menu's buttons: Blizzard's button backing and gold hover go;
-- each icon (their normal art, which is the picture) sits on a black tile
-- with a fel hover. The pieces are named on most builds and looked for by
-- name; whatever this build lacks is simply skipped.
local skinnedMenu = setmetatable({}, { __mode = "k" })
local MICRO_FADE = { "Background", "PushedBackground", "FlashBorder", "FlashContent", "Flash" }
local function styleMicro(b)
    if skinnedMenu[b] then return end
    skinnedMenu[b] = true
    for _, k in ipairs(MICRO_FADE) do
        local t = b[k]
        if t and t.SetAlpha then t:SetAlpha(0) end
    end
    -- Blizzard's own mouseover art; ours is the fel wash below.
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "HIGHLIGHT" then
            local a = r:GetAtlas()
            if a and a:find("Mouseover") then r:SetAlpha(0) end
        end
    end
    -- No tile of its own: the buttons overlap (Blizzard spaces them closer
    -- than they are wide), so the menu gets one card behind them all.
    local h = b:CreateTexture(nil, "HIGHLIGHT")
    h:SetPoint("TOPLEFT", 3, -3)
    h:SetPoint("BOTTOMRIGHT", -3, 3)
    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.18)
end

-- The bag bar's slots: like the character sheet's gear slots, a cropped
-- icon on a black tile, Blizzard's slot frame gone; the arrow that folds
-- the bags away wears our chevron.
local function styleBagSlot(b)
    if skinnedMenu[b] then return end
    skinnedMenu[b] = true
    local icon = b.icon or b.Icon or (b.GetName and b:GetName() and _G[b:GetName() .. "IconTexture"])
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    if b.SlotHighlightTexture then b.SlotHighlightTexture:SetAlpha(0) end
    for _, k in ipairs({ "Background", "CircleMask" }) do
        local x = b[k]
        if x and x.GetObjectType and x:GetObjectType() == "Texture" then x:SetAlpha(0) end
    end
    local hl = b.GetHighlightTexture and b:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    if icon then
        if b.CircleMask and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, b.CircleMask) end
        -- Blizzard's square mask is cut to the bevelled frame; given our
        -- shape it matches our tile, attached or not.
        local sm = b.SquareMask
        if sm and sm.SetTexture then
            local shape = ns:Modern() and ns.Media.iconmask or ns.Media:Statusbar("Wick Flat")
            sm:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            if ns:Modern() and Chrome.PlaceIconMask then
                Chrome:PlaceIconMask(sm, icon)
            else
                sm:ClearAllPoints()
                sm:SetAllPoints(icon)
            end
        end
        -- The key ring's picture is Blizzard's empty-slot art, not an item.
        if not (icon.GetAtlas and icon:GetAtlas()) then ns:CropIcon(icon) end
    end
    local h = b:CreateTexture(nil, "HIGHLIGHT")
    h:SetAllPoints(icon or b)
    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.18)
    local t = CreateFrame("Frame", nil, b)
    t:SetPoint("TOPLEFT", -1, 1)
    t:SetPoint("BOTTOMRIGHT", 1, -1)
    t:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    ns:SetTemplate(t, "Default", { alpha = 0.9, shadow = false })
end

function SK:SkinMenus()
    local mm = rawget(_G, "MicroMenu") or rawget(_G, "MicroMenuContainer")
    if mm then
        -- Blizzard's bar frame and its backing behind the buttons.
        if mm.BorderArt then mm.BorderArt:SetAlpha(0) end
        if mm.BackgroundArt then mm.BackgroundArt:SetAlpha(0) end
        if not skinnedMenu[mm] then
            skinnedMenu[mm] = true
            local c = CreateFrame("Frame", nil, mm)
            c:SetPoint("TOPLEFT", -3, 3)
            c:SetPoint("BOTTOMRIGHT", 3, -3)
            c:SetFrameLevel(math.max(0, mm:GetFrameLevel() - 1))
            ns:SetTemplate(c, "Default")
        end
        for _, b in ipairs({ mm:GetChildren() }) do
            if b:GetObjectType() == "Button" then styleMicro(b) end
        end
    end
    local bags = rawget(_G, "BagsBar")
    if bags then
        -- Blizzard's bar frame, and the thin divider frames it stands
        -- between the bags.
        if bags.BorderArt then bags.BorderArt:SetAlpha(0) end
        for _, c in ipairs({ bags:GetChildren() }) do
            if c:GetObjectType() == "Frame" and c.GetRegions then
                for _, r in ipairs({ c:GetRegions() }) do
                    local a = r:GetObjectType() == "Texture" and r:GetAtlas()
                    if a and a:find("Divider") then r:SetAlpha(0) end
                end
            end
        end
        for _, b in ipairs({ bags:GetChildren() }) do
            local kind = b:GetObjectType()
            if (kind == "ItemButton" or kind == "Button" or kind == "CheckButton") and (b.icon or b.Icon) then
                styleBagSlot(b)
            end
        end
    end
    local toggle = rawget(_G, "BagBarExpandToggle")
    if toggle then ns:Glyph(toggle, ns:ArrowDirection(toggle) or "left", { tile = false, size = 12 }) end
end

function SK:Menus()
    local d = db()
    if d.microMenu ~= "hide" or d.bagsBar ~= "hide" then pcall(SK.SkinMenus, SK) end
    fade(rawget(_G, "MicroMenuContainer") or rawget(_G, "MicroMenu"), d.microMenu)
    fade(rawget(_G, "BagsBar"), d.bagsBar)
end

-- ============================================================
-- Lifecycle
-- ============================================================
function SK:Initialize()
    self:Update()
    local function later() C_Timer.After(0.2, function() SK:Tracker(); SK:DamageMeter(); SK:SwingTimers() end) end
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
        "TRACKED_ACHIEVEMENT_UPDATE", "SCENARIO_UPDATE", "GROUP_ROSTER_UPDATE" }) do
        ns:On(e, later)
    end
    ns:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_DamageMeter" or name == "Blizzard_ObjectiveTracker" or name == "Blizzard_SwingTimer" then later() end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", later, SK)
    end
end

function SK:Update()
    self:Tracker()
    self:DamageMeter()
    self:SwingTimers()
    self:Menus()
end

ns.Config:AddPage("skins", "Blizzard frames", function(L)
    L:DB(db)
    L:Note("Frames the game keeps and Edit Mode places, restyled in the Wick look. Switching a skin off fully takes a reload.")
    L:Toggle("Objective tracker", "tracker")
    L:Slider("Tracker text size", "trackerFontSize", 8, 18, 1)
    L:Toggle("Damage meter window", "damageMeter", { tooltip = "The window, and its text in the Wick font. The bars show combat numbers the client keeps secret; those are never read, and nothing on the meter is touched in combat." })
    L:Toggle("Line the meter up with the info panel", "meterAlign", { tooltip = "The meter's window is made as wide as the right info panel and sits just above it. Off leaves it to Edit Mode (after a reload)." })
    L:Slider("Damage meter height", "meterHeight", 0, 400, 5, { disabled = function() return not db().meterAlign end,
        tooltip = "Its height while it is lined up with the info panel. 0 leaves the height to Edit Mode." })
    L:Toggle("Swing timers", "swingTimers", { tooltip = "The game's main hand, off hand and ranged timers in the look: its bar in the accent, the off hand a darker shade. Edit Mode still places them." })
    L:Dropdown("Micro menu", "microMenu", { { "show", "Always" }, { "mouseover", "When moused over" }, { "hide", "Hidden" } })
    L:Dropdown("Bag bar", "bagsBar", { { "show", "Always" }, { "mouseover", "When moused over" }, { "hide", "Hidden" } })
end, { onChange = function() SK:Update() end, order = 95 })
