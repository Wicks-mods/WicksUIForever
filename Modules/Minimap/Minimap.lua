-- Wick's UI
-- Modules/Minimap/Minimap.lua: a flat square minimap with its own text.
--
-- The minimap stays where Edit Mode puts it; moving Blizzard's cluster
-- ourselves would fight the layout editor for it. What changes is the
-- look: a square mask, our border and brackets in place of the ring, and zone, clock,
-- coordinates and mail drawn by us on top.
--
-- Addon minimap buttons (anything LibDBIcon made) are gathered into a
-- small flyout so they stop crowding the edge. Those are other addons'
-- frames, not Blizzard's, so moving them taints nothing of the game's.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local MM = ns:NewModule("minimap", { title = "Minimap", order = 60 })
ns.Minimap = MM

ns.defaults.profile.minimap = {
    enable = true,
    square = true,
    ring = false,                -- the round map's gold ring and north marker
    fill = true,                 -- the map fills Blizzard's minimap box, to its top right corner
    hideZoom = true,
    hideBlizzardText = true,     -- Blizzard's zone header, replaced by ours
    zone = true, zoneSize = 12, zoneInside = true,
    clock = true, clockSize = 12, clock24 = true, clockLocal = true,
    coords = true, coordsSize = 11,
    mail = true,
    collect = true,              -- gather addon buttons into a flyout
}

local SQUARE = "Interface\\BUTTONS\\WHITE8X8"
-- Each client's own round mask: Forever's scalable circle, and the portrait
-- mask the Classic layout has always used. Forever ships the compass ring;
-- its absence means the Classic layout.
local function roundMask()
    if rawget(_G, "MinimapCompassTexture") then return "Interface\\Masks\\CircleMaskScalable" end
    return "Interface\\CharacterFrame\\TempPortraitAlphaMask"
end
local function db() return MM:db() end

local function ringArt()
    local out = {}
    for _, name in ipairs({ "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapBorder", "MinimapBorderTop" }) do
        local t = rawget(_G, name)
        if t then out[#out + 1] = t end
    end
    local cl = rawget(_G, "MinimapCluster")
    if cl and cl.BorderTop then out[#out + 1] = cl.BorderTop end
    return out
end

local function blob(scalar)
    for _, m in ipairs({ "SetQuestBlobRingScalar", "SetArchBlobRingScalar", "SetTaskBlobRingScalar" }) do
        if Minimap[m] then pcall(Minimap[m], Minimap, scalar) end
    end
end

-- ============================================================
-- Shape
-- ============================================================
-- Blizzard's minimap box (the cluster Edit Mode moves) is larger than the
-- map, with a strip along the top for the zone header. Filling it puts the
-- map in the box's top right corner at the box's full width, so a box
-- pushed into the screen's corner puts the map there too. Blizzard lays
-- the cluster out again after Edit Mode, so this is checked each tick.
-- Blizzard's own size and place for the map, taken before we first touch
-- it, so round mode (whose ring is drawn for that size) can have them back.
local original
local function remember()
    if original or not Minimap then return end
    local w, h = Minimap:GetSize()
    original = { w = w, h = h, points = {} }
    for i = 1, Minimap:GetNumPoints() do original.points[i] = { Minimap:GetPoint(i) } end
end

-- WickCore's own button rides on the map's edge; it is placed again
-- whenever the map changes size or shape.
local function placeLauncher()
    local L = ns.Core and ns.Core.Launcher
    if L and L.PlaceMinimapButton then pcall(L.PlaceMinimapButton) end
end

local function restore()
    if not original or not original.moved or InCombatLockdown() then return end
    Minimap:SetSize(original.w, original.h)
    Minimap:ClearAllPoints()
    for _, pt in ipairs(original.points) do Minimap:SetPoint(unpack(pt)) end
    local diel = MinimapCluster and MinimapCluster.DielFrame
    if diel and original.diel then
        diel:ClearAllPoints()
        for _, pt in ipairs(original.diel) do diel:SetPoint(unpack(pt)) end
    end
    original.moved = false
    placeLauncher()
end

function MM:Fill()
    local d = db()
    local cl = rawget(_G, "MinimapCluster")
    if not cl or InCombatLockdown() then return end
    remember()
    -- The round map keeps Blizzard's size while its ring shows, since the
    -- ring is drawn for that size; without the ring it fills the box too.
    if not (d.fill and (d.square or not d.ring)) then restore() return end
    original.moved = true
    local w, h = cl:GetSize()
    if not (w and w > 0) then return end
    local size = math.floor(math.min(w, h))
    if math.abs((Minimap:GetWidth() or 0) - size) > 0.5 then
        Minimap:SetSize(size, size)
        placeLauncher()
    end
    local p, rel = Minimap:GetPoint(1)
    if p ~= "TOPRIGHT" or rel ~= cl or Minimap:GetNumPoints() ~= 1 then
        Minimap:ClearAllPoints()
        Minimap:SetPoint("TOPRIGHT", cl, "TOPRIGHT", 0, 0)
    end
    -- The day and night dial is pinned to the middle of the box by a fixed
    -- offset, so it stays inside a map that has grown; it goes to the
    -- map's right edge, under the calendar.
    local diel = cl.DielFrame
    if diel then
        local dp, drel = diel:GetPoint(1)
        if dp ~= "TOPRIGHT" or drel ~= Minimap then
            if not original.diel then
                original.diel = {}
                for i = 1, diel:GetNumPoints() do original.diel[i] = { diel:GetPoint(i) } end
            end
            diel:ClearAllPoints()
            diel:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -40)
        end
    end
end

function MM:Shape()
    local d = db()
    self:Fill()
    if d.square then
        -- Modern rounds the square's corners with the same mask the icons use.
        local mask = ns:Modern() and ns.Media.roundmask or SQUARE
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, mask) end
        blob(0)
        for _, t in ipairs(ringArt()) do t:SetAlpha(0) end
    else
        -- Round again, Blizzard's own mask and ring back, at once.
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, roundMask()) end
        blob(1)
        for _, t in ipairs(ringArt()) do t:SetAlpha(d.ring and 1 or 0) end
    end
    -- The text bands follow the map's shape.
    if self.bandMask then
        if d.square then
            self.bandMask:SetTexture(ns.Media.roundmask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        else
            self.bandMask:SetTexture(roundMask(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
    end
    -- Our text shows on either shape; the corner brackets only suit the
    -- square one.
    self.chrome:Show()
    for _, pair in pairs(self.chrome.brackets or {}) do
        for _, t in ipairs(pair) do t:SetShown(d.square and ns:G().brackets ~= false) end
    end
    placeLauncher()
    -- The soft lift is square-cornered; it only belongs under the square map.
    if self.chrome.wuiLift then self.chrome.wuiLift:SetShown(d.square) end
    local zoom = { Minimap.ZoomIn, Minimap.ZoomOut, rawget(_G, "MinimapZoomIn"), rawget(_G, "MinimapZoomOut") }
    for _, b in pairs(zoom) do if b then b:SetAlpha(d.hideZoom and 0 or 1); b:EnableMouse(not d.hideZoom) end end
    local zt = MinimapCluster and MinimapCluster.ZoneTextButton
    if zt then zt:SetAlpha(d.hideBlizzardText and 0 or 1); zt:EnableMouse(not d.hideBlizzardText) end
    -- The Classic layout keeps its pieces as globals placed round the old
    -- ring: the zone text, the mail icon, and the buttons. On the square
    -- they move to the map's corners, under our own "+" and mail marks.
    local czt = rawget(_G, "MinimapZoneTextButton")
    if czt then czt:SetAlpha(d.hideBlizzardText and 0 or 1); czt:EnableMouse(not d.hideBlizzardText) end
    local bmail = rawget(_G, "MiniMapMailFrame")
    if bmail then bmail:SetAlpha(d.mail and 0 or 1); bmail:EnableMouse(not d.mail) end
    if d.square then
        local function pin(name, point, x, y)
            local b = rawget(_G, name)
            if not b then return end
            b:ClearAllPoints()
            b:SetPoint(point, Minimap, point, x, y)
        end
        pin("MiniMapTracking", "TOPLEFT", 2, -22)
        pin("GameTimeFrame", "TOPRIGHT", -2, -24)
        pin("MiniMapBattlefieldFrame", "BOTTOMLEFT", 2, 2)
        -- The world map is a key and a micro button; the ring's copy goes.
        local wm = rawget(_G, "MiniMapWorldMapButton")
        if wm then wm:SetAlpha(0); wm:EnableMouse(false) end
    end
    -- This client draws its own coordinates under the map; ours replace them.
    local bc = MinimapCluster and MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords
    if bc then bc:SetAlpha((d.coords and d.hideBlizzardText) and 0 or 1) end
    local clock = rawget(_G, "TimeManagerClockButton")
    if clock then clock:SetAlpha((d.clock and d.hideBlizzardText) and 0 or 1) end
end

-- ============================================================
-- Text on the map
-- ============================================================
-- A zone's PvP colour, or the text colour where it has none (which then
-- follows a theme change).
local function pvpColor()
    local pvp = GetZonePVPInfo and GetZonePVPInfo()
    if pvp == "sanctuary" then return { 0.41, 0.8, 0.94 } end
    if pvp == "friendly" then return { 0.1, 1, 0.1 } end
    if pvp == "hostile" then return { 1, 0.1, 0.1 } end
    if pvp == "contested" then return { 1, 0.7, 0 } end
    return "text"
end

function MM:UpdateZone()
    local z = self.zone
    if not z then return end
    z:SetText(GetMinimapZoneText and GetMinimapZoneText() or "")
    ns:TextColor(z, pvpColor())
end

local function clockText()
    local d = db()
    local h, m
    if d.clockLocal then
        local t = date("*t")
        h, m = t.hour, t.min
    else
        h, m = GetGameTime()
    end
    if d.clock24 then return ("%02d:%02d"):format(h, m) end
    local suffix = h >= 12 and "pm" or "am"
    h = h % 12
    if h == 0 then h = 12 end
    return ("%d:%02d%s"):format(h, m, suffix)
end

function MM:Tick()
    local d = db()
    if self.clock and d.clock then self.clock:SetText(clockText()) end
    if self.coords and d.coords then
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
        -- Inside instances the position is withheld; show nothing then.
        if pos and pos.x then
            local x, y = pos:GetXY()
            self.coords:SetText(("%.1f, %.1f"):format(x * 100, y * 100))
        else
            self.coords:SetText("")
        end
    end
    if self.mail then
        self.mail:SetShown(d.mail and HasNewMail and HasNewMail())
    end
end

function MM:BuildText()
    local chrome = self.chrome
    -- Soft dark bands behind the text at the top and bottom, so it reads
    -- over sand and snow as well as over water.
    local top = chrome:CreateTexture(nil, "ARTWORK", nil, -1)
    top:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 0, 0)
    top:SetHeight(22)
    top:SetTexture(SQUARE)
    top:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.6))
    self.topBand = top
    local bottom = chrome:CreateTexture(nil, "ARTWORK", nil, -1)
    bottom:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(36)
    bottom:SetTexture(SQUARE)
    bottom:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0))
    self.bottomBand = bottom
    -- In the modern style the map's corners are rounded; the bands follow.
    if ns:Modern() and chrome.CreateMaskTexture then
        local m = chrome:CreateMaskTexture()
        m:SetTexture(ns.Media.roundmask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(Minimap)
        top:AddMaskTexture(m)
        bottom:AddMaskTexture(m)
        self.bandMask = m
    end
    self.zone = ns:CreateText(chrome, 12, "CENTER")
    self.zone:SetWordWrap(false)
    self.clock = ns:CreateText(chrome, 12, "CENTER")
    self.coords = ns:CreateText(chrome, 11, "CENTER")
    local mail = chrome:CreateTexture(nil, "OVERLAY")
    mail:SetSize(20, 14)
    mail:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
    mail:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -4, -4)
    self.mail = mail

    local elapsed = 0
    chrome:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed >= 0.5 then elapsed = 0; MM:Tick(); MM:Fill() end
    end)
end

function MM:LayoutText()
    local d = db()
    self.zone:ClearAllPoints()
    if d.zoneInside then
        self.zone:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)
        self.zone:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -24, -4)
    else
        self.zone:SetPoint("BOTTOMLEFT", Minimap, "TOPLEFT", 0, 4)
        self.zone:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, 4)
    end
    ns.Media:SetFont(self.zone, d.zoneSize)
    self.zone:SetShown(d.zone)
    for _, fs in ipairs({ self.zone, self.clock, self.coords }) do
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    end
    self.topBand:SetShown(d.zone and d.zoneInside)
    self.bottomBand:SetShown(d.clock or d.coords)
    ns.Media:SetFont(self.clock, d.clockSize)
    self.clock:ClearAllPoints()
    self.clock:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 4)
    self.clock:SetShown(d.clock)
    ns.Media:SetFont(self.coords, d.coordsSize)
    self.coords:ClearAllPoints()
    self.coords:SetPoint("BOTTOM", self.clock, "TOP", 0, 2)
    self.coords:SetShown(d.coords)
    self:UpdateZone()
    self:Tick()
end

-- ============================================================
-- Button collector
-- ============================================================
function MM:Collect()
    if not db().collect then return end
    local bar = self.flyout
    if not bar then
        local toggle = W:Button(self.chrome, "+", 16, function() MM.flyout:SetShown(not MM.flyout:IsShown()) end)
        toggle:SetHeight(16)
        toggle:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -2)
        toggle:SetFrameLevel(self.chrome:GetFrameLevel() + 2)
        self.toggle = toggle
        bar = CreateFrame("Frame", "WicksUI_MinimapButtons", UIParent)
        bar:SetFrameStrata("MEDIUM")
        bar:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -4, 0)
        ns:SetTemplate(bar, "Default")
        bar:Hide()
        self.flyout = bar
        self.collected = {}
    end
    local n = 0
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child.GetName and child:GetName()
        if name and name:find("^LibDBIcon10_") then
            if not self.collected[child] then
                self.collected[child] = true
                child:SetParent(bar)
            end
        end
    end
    for child in pairs(self.collected) do
        if child:GetParent() == bar then
            n = n + 1
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", bar, "TOPLEFT", 4 + ((n - 1) % 6) * 32, -4 - math.floor((n - 1) / 6) * 32)
        end
    end
    local rows = math.max(1, math.ceil(n / 6))
    bar:SetSize(8 + math.min(n, 6) * 32, 8 + rows * 32)
    self.toggle:SetShown(n > 0)
end

-- ============================================================
-- Lifecycle
-- ============================================================
-- Addons that place buttons around the minimap (LibDBIcon and most others)
-- ask this to know whether to follow a circle or the square's edge.
function GetMinimapShape()
    local p = MM.db and MM:db()
    return (p and p.square) and "SQUARE" or "ROUND"
end

function MM:Initialize()
    if not Minimap then return end
    local chrome = CreateFrame("Frame", "WicksUI_MinimapChrome", Minimap)
    chrome:SetAllPoints(Minimap)
    chrome:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    ns:SetTemplate(chrome, "None", { brackets = true })
    self.chrome = chrome
    -- Modern: no border line or corners, a soft lift under the map instead.
    if ns:Modern() then
        -- On a frame of its own one level under the map: our overlay draws
        -- above the map, and a shadow there would darken the map itself.
        local under = CreateFrame("Frame", nil, Minimap:GetParent() or UIParent)
        under:SetFrameStrata(Minimap:GetFrameStrata())
        under:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))
        under:SetAllPoints(Minimap)
        local s = under:CreateTexture(nil, "BACKGROUND", nil, -8)
        s:SetTexture(ns.Media.shadow)
        if s.SetTextureSliceMargins then s:SetTextureSliceMargins(28, 28, 28, 28) end
        s:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -12, 10)
        s:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 12, -14)
        s:SetVertexColor(0, 0, 0, 0.6)
        chrome.wuiLift = s
    end
    self:BuildText()
    self:Update()

    local function reshape() if db().square then MM:Shape() end end
    ns:On("PLAYER_ENTERING_WORLD", function() reshape(); MM:UpdateZone(); C_Timer.After(2, function() MM:Collect() end) end)
    ns:On("MINIMAP_UPDATE_ZOOM", reshape)
    ns:On("CVAR_UPDATE", function(_, name) if name == "rotateMinimap" then reshape() end end)
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
        ns:On(e, function() MM:UpdateZone() end)
    end
end

function MM:Update()
    self:Shape()
    self:LayoutText()
    self:Collect()
end

ns.Config:AddPage("minimap", "Minimap", function(L)
    L:DB(db)
    L:Note("Move the minimap with Edit Mode. Its shape, ring and fill are kept for each look: set them in Wick Modern and in Wick OG, and each look comes back with its own.")
    L:Toggle("Square", "square", { tooltip = "Off gives back Blizzard's round map and its ring." })
    L:Toggle("Ring around the round map", "ring", { tooltip = "Blizzard's gold ring and north marker, on the round map only. With the ring the map keeps Blizzard's size so the ring fits; without it the map fills the box." })
    L:Toggle("Fill the minimap box", "fill", { tooltip = "The map grows to the full width of Blizzard's minimap box and sits in its top right corner, so it can go right into the corner of the screen. Move the box with Edit Mode. The round map keeps Blizzard's size, so its ring fits." })
    L:Toggle("Hide the zoom buttons", "hideZoom")
    L:Toggle("Hide Blizzard's zone header and clock", "hideBlizzardText")
    L:Toggle("Gather addon buttons into a flyout", "collect", { tooltip = "Buttons made by LibDBIcon, which is most of them. Takes effect after a reload when switched off." })
    L:Heading("Text on the map")
    L:Toggle("Zone", "zone")
    L:Toggle("Zone inside the map", "zoneInside")
    L:Slider("Zone size", "zoneSize", 8, 20, 1)
    L:Toggle("Clock", "clock")
    L:Toggle("24 hour clock", "clock24")
    L:Toggle("Your own time, not the realm's", "clockLocal")
    L:Slider("Clock size", "clockSize", 8, 20, 1)
    L:Toggle("Coordinates", "coords", { tooltip = "Blank inside instances, where the client does not give out your position." })
    L:Slider("Coordinates size", "coordsSize", 8, 20, 1)
    L:Toggle("New mail", "mail")
end, { onChange = function() MM:Update() end, order = 60 })
