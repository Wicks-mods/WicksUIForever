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
    tracker = true, trackerFontSize = 12,
    damageMeter = true,
    microMenu = "mouseover",     -- show, mouseover, hide
    bagsBar = "mouseover",
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

local function panelBehind(frame, template, inset)
    local p = panels[frame]
    if p then return p end
    p = CreateFrame("Frame", nil, frame)
    local o = inset or 0
    p:SetPoint("TOPLEFT", -o, o)
    p:SetPoint("BOTTOMRIGHT", o, -o)
    p:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    ns:SetTemplate(p, template or "Transparent")
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
        if win:IsShown() then panelBehind(win, "Transparent") end
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
    for f in pairs(faders) do
        local over = f:IsVisible() and f:IsMouseOver(4, -4, -4, 4)
        local target = over and 1 or 0
        local a = f:GetAlpha()
        if math.abs(a - target) > 0.01 then f:SetAlpha(a + (target - a) * 0.5) end
    end
end)

function SK:Menus()
    local d = db()
    fade(rawget(_G, "MicroMenuContainer") or rawget(_G, "MicroMenu"), d.microMenu)
    fade(rawget(_G, "BagsBar"), d.bagsBar)
end

-- ============================================================
-- Lifecycle
-- ============================================================
function SK:Initialize()
    self:Update()
    local function later() C_Timer.After(0.2, function() SK:Tracker(); SK:DamageMeter() end) end
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
        "TRACKED_ACHIEVEMENT_UPDATE", "SCENARIO_UPDATE", "GROUP_ROSTER_UPDATE" }) do
        ns:On(e, later)
    end
    ns:On("ADDON_LOADED", function(_, name)
        if name == "Blizzard_DamageMeter" or name == "Blizzard_ObjectiveTracker" then later() end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", later, SK)
    end
end

function SK:Update()
    self:Tracker()
    self:DamageMeter()
    self:Menus()
end

ns.Config:AddPage("skins", "Blizzard frames", function(L)
    L:DB(db)
    L:Note("Frames the game keeps and Edit Mode places, restyled in the Wick look. Switching a skin off fully takes a reload.")
    L:Toggle("Objective tracker", "tracker")
    L:Slider("Tracker text size", "trackerFontSize", 8, 18, 1)
    L:Toggle("Damage meter window", "damageMeter", { tooltip = "The window only. The bars show combat numbers the client keeps secret, and are left exactly as the game draws them." })
    L:Dropdown("Micro menu", "microMenu", { { "show", "Always" }, { "mouseover", "When moused over" }, { "hide", "Hidden" } })
    L:Dropdown("Bag bar", "bagsBar", { { "show", "Always" }, { "mouseover", "When moused over" }, { "hide", "Hidden" } })
end, { onChange = function() SK:Update() end, order = 95 })
