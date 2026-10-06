-- Wick's UI
-- Modules/Minimap/Minimap.lua: a flat square minimap with its own text.
--
-- The minimap stays where Edit Mode puts it; moving Blizzard's cluster
-- ourselves would fight the layout editor for it. What changes is the
-- look: a square mask, our border and brackets in place of the ring, and zone, clock,
-- coordinates and mail drawn by us on top.
--
-- Addon minimap buttons (LibDBIcon's, the suite's own, hand-made ones) are
-- gathered into a small flyout so they stop crowding the edge. Those are
-- other addons' frames, not Blizzard's, so moving them taints nothing of
-- the game's.

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
    strip = true,                -- the Classic layout's own buttons in a row under the map
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

-- Classic is the game's own minimap: round in its ring, with its zone
-- header, clock, zoom buttons and mail icon, where the game puts them.
-- What the module adds besides the look, the flyout that gathers addon
-- buttons, stays. The settings page still shows the player's own values,
-- for the other looks.
local GAME = { square = false, ring = true, fill = false, hideZoom = false, hideBlizzardText = false,
    zone = false, clock = false, coords = false, mail = false, strip = false }
local function opts()
    local d = db()
    if not ns:Game() then return d end
    return setmetatable({}, { __index = function(_, k)
        local v = GAME[k]
        if v ~= nil then return v end
        return d[k]
    end })
end

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
    local d = opts()
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
    local d = opts()
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
    -- Classic: the game's ring is the border; ours would be a square round it.
    if ns:Game() then ns:SetBorderColor(self.chrome, { 0, 0, 0 }, 0) end
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
        if not self:Strip() then
            pin("MiniMapTracking", "TOPLEFT", 2, -22)
            pin("GameTimeFrame", "TOPRIGHT", -2, -24)
            pin("MiniMapBattlefieldFrame", "BOTTOMLEFT", 2, 2)
        end
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
        if elapsed >= 0.5 then elapsed = 0; MM:Tick(); MM:Fill(); MM:Strip() end
    end)
end

function MM:LayoutText()
    local d = opts()
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
-- Every named button parented to the map is gathered, except Blizzard's
-- own pieces, ours, and the pins addons draw on the map itself.
local KEEP = {
    MinimapBackdrop = true, MinimapZoomIn = true, MinimapZoomOut = true, MinimapToggleButton = true,
    MinimapZoneTextButton = true, MiniMapMailFrame = true, MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true,
    LFGMinimapFrame = true, MiniMapWorldMapButton = true, MiniMapTracking = true, MiniMapTrackingButton = true,
    MiniMapTrackingFrame = true, GameTimeFrame = true, TimeManagerClockButton = true, MiniMapInstanceDifficulty = true,
    GuildInstanceDifficulty = true, MiniMapChallengeMode = true, MiniMapVoiceChatFrame = true,
    QueueStatusMinimapButton = true, QueueStatusButton = true, GarrisonLandingPageMinimapButton = true,
    ExpansionLandingPageMinimapButton = true, AddonCompartmentFrame = true,
    WickCoreMinimapButton = true,
}
local PINS = { "^WicksUI_", "^Minimap", "^MiniMap", "^QuestieFrame", "^HandyNotes", "^GatherMate", "^GatherNote",
    "^Gatherer", "^MapNotes", "^Routes", "^TomTom", "^Archy", "^DugisArrow", "^FWGMinimapPOI", "^poiMinimap",
    "^MiniNotePOI", "^RecipeRadar", "^Cartographer", "^NxMap", "^WestPointer", "^ZGVMarker", "^Spy_MapNoteList",
    "^Nauticus", "^GuildMap3Mini", "^TDial_", "^ZOrbMinimap", "^MBB_", "^MinimapButtonBag" }
-- Other collectors; two would pull the same buttons apart.
local COLLECTORS = { "MBB", "MinimapButtonButton", "SexyMap", "MinimapButtonBag" }
-- The round border, backdrop and highlight LibDBIcon and most hand-made
-- buttons draw, by path and by file id.
local RING = {
    [136430] = true, ["interface\\minimap\\minimap-trackingborder"] = true,
    [136467] = true, ["interface\\minimap\\ui-minimap-background"] = true,
    [136477] = true, ["interface\\minimap\\ui-minimap-zoombutton-highlight"] = true,
}
local CELL, TILE, PER_ROW = 28, 24, 8

local function otherCollector()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not loaded then return false end
    for _, name in ipairs(COLLECTORS) do
        if loaded(name) then return true end
    end
    return false
end

local function wanted(child)
    local name = child.GetName and child:GetName()
    if not name or KEEP[name] then return false end
    for _, p in ipairs(PINS) do
        if name:find(p) then return false end
    end
    if child.IsForbidden and child:IsForbidden() then return false end
    if child.IsProtected and child:IsProtected() then return false end
    local kind = child:GetObjectType()
    if kind == "Button" or kind == "CheckButton" then return true end
    -- A plain frame standing in for a button: small, takes the mouse, has art.
    if kind == "Frame" and child.IsMouseEnabled and child:IsMouseEnabled() then
        local w = child:GetWidth() or 0
        if w > 0 and w <= 48 then
            for _, r in ipairs({ child:GetRegions() }) do
                if r:GetObjectType() == "Texture" then return true end
            end
        end
    end
    return false
end

local function artOf(r)
    local t = r:GetTexture()
    if type(t) == "string" then return t:lower() end
    return t
end

local function defaultCoords(r)
    local ulx, uly, llx, lly, urx, ury, lrx, lry = r:GetTexCoord()
    return ulx == 0 and uly == 0 and llx == 0 and lly == 1 and urx == 1 and ury == 0 and lrx == 1 and lry == 1
end

function MM:Place(button)
    local st = self.collected[button]
    if not st or not st.index then return end
    st.placing = true
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", self.flyout, "TOPLEFT",
        4 + ((st.index - 1) % PER_ROW) * CELL, -4 - math.floor((st.index - 1) / PER_ROW) * CELL)
    st.placing = false
end

function MM:Layout()
    local bar = self.flyout
    if not bar then return end
    local order = {}
    for b in pairs(self.collected) do order[#order + 1] = b end
    table.sort(order, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
    local n = 0
    for _, b in ipairs(order) do
        local st = self.collected[b]
        if b:IsShown() then
            n = n + 1
            st.index = n
            self:Place(b)
        else
            st.index = nil
        end
    end
    local rows = math.max(1, math.ceil(n / PER_ROW))
    bar:SetSize(8 + math.min(math.max(n, 1), PER_ROW) * CELL, 8 + rows * CELL)
    self.toggle:SetShown(n > 0)
    if n == 0 then bar:Hide() end
end

-- A gathered button loses its round border and backdrop, fills a square
-- tile with its icon, takes the look's border, and stands its own drag
-- down: the flyout places it.
function MM:Dress(button)
    local st = self.collected[button]
    if not st or st.dressed then return end
    st.dressed = true
    for _, r in ipairs({ button:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local art = artOf(r)
            if art and RING[art] then
                r:SetAlpha(0)
            elseif r:GetDrawLayer() ~= "HIGHLIGHT" then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
                r:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
                -- Squared off, unless the addon cut its own coordinates.
                if defaultCoords(r) then r:SetTexCoord(0.1, 0.9, 0.1, 0.9) end
            end
        end
    end
    button:SetSize(TILE, TILE)
    if button.SetHighlightTexture then
        button:SetHighlightTexture(SQUARE)
        local hl = button:GetHighlightTexture()
        if hl then
            hl:SetAllPoints()
            hl:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 0.25)
            Chrome:Register(hl, C.fel, "vertex", 0.25)
        end
    end
    ns:SetTemplate(button, "Default")
    if button.RegisterForDrag then button:RegisterForDrag() end
    button:SetScript("OnDragStart", nil)
    button:SetScript("OnDragStop", nil)
    -- An addon that puts its button back on the map's edge (LibDBIcon does
    -- on every refresh) is answered by putting it back in its cell.
    hooksecurefunc(button, "SetPoint", function(b)
        if not st.placing then MM:Place(b) end
    end)
    hooksecurefunc(button, "SetParent", function(b, p)
        if p ~= MM.flyout and not st.placing then
            st.placing = true
            b:SetParent(MM.flyout)
            st.placing = false
            MM:Layout()
        end
    end)
    button:HookScript("OnShow", function() MM:Layout() end)
    button:HookScript("OnHide", function() MM:Layout() end)
end

function MM:Collect()
    if not db().collect or otherCollector() then return end
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
        -- LibDBIcon says when it makes a button; the rest are caught by
        -- the passes after entering the world.
        local lib = LibStub and LibStub("LibDBIcon-1.0", true)
        if lib and lib.RegisterCallback then
            pcall(lib.RegisterCallback, self, "LibDBIcon_IconCreated", function()
                C_Timer.After(0, function() MM:Collect() end)
            end)
        end
    end
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if not self.collected[child] and wanted(child) then
            local st = { placing = true }
            self.collected[child] = st
            child:SetParent(bar)
            st.placing = false
            self:Dress(child)
        end
    end
    self:Layout()
end

-- ============================================================
-- Button strip
-- ============================================================
-- The Classic layout's own buttons (tracking, the group finder's eye, the
-- battleground queue, the day and night dial) and WickCore's launcher sit
-- in a row under the square map, and the new-mail mark takes the row's
-- right end. They stay in view, where the flyout would hide them, so a
-- queue or what you track still shows. Their round borders are faded and
-- their pictures squared to the row; nothing of ours is written onto the
-- game's frames. Forever's pieces belong to Edit Mode's minimap and stay.
local STRIP = { "MiniMapTracking", "MiniMapTrackingFrame", "LFGMinimapFrame", "MiniMapLFGFrame",
    "MiniMapBattlefieldFrame", "GameTimeFrame", "WickCoreMinimapButton" }
local STRIP_PAD, STRIP_GAP = 3, 2

local function classicPieces()
    return rawget(_G, "MiniMapTracking") ~= nil or rawget(_G, "MiniMapTrackingFrame") ~= nil
end
MM.ClassicPieces = classicPieces

-- A piece made to fill its tile, looked at again on every pass: Blizzard
-- moves a pressed button's picture and puts it back on release. The
-- tracking frame keeps its button as a child; children cover the tile.
local function fitRegions(f, tile)
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local art = artOf(r)
            if art and RING[art] then
                if r:GetAlpha() > 0 then r:SetAlpha(0) end
            elseif r:GetDrawLayer() == "HIGHLIGHT" then
                r:ClearAllPoints()
                r:SetAllPoints(tile)
            else
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
                r:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 2)
                if defaultCoords(r) then r:SetTexCoord(0.1, 0.9, 0.1, 0.9) end
            end
        end
    end
end

-- A dropdown hung on a piece (the tracking menu's) is not part of its
-- picture and keeps its own place.
local function isMenu(c)
    local n = c.GetName and c:GetName()
    return (n and n:lower():find("dropdown", 1, true)) or (c.Left and c.Middle and c.Right and c.Text) and true or false
end

local function fit(b)
    fitRegions(b, b)
    for _, c in ipairs({ b:GetChildren() }) do
        if not isMenu(c) then
            c:ClearAllPoints()
            c:SetAllPoints(b)
            fitRegions(c, b)
        end
    end
end

function MM:BuildStrip()
    if self.strip then return self.strip end
    local s = CreateFrame("Frame", "WicksUI_MinimapStrip", Minimap)
    s:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -4)
    s:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -4)
    s:SetHeight(TILE + STRIP_PAD * 2)
    ns:SetTemplate(s, "Default")
    self.strip = s
    return s
end

-- Lays the row out; false when there is no row (a round map, the option
-- off, or Forever), so the caller places the pieces the old way.
function MM:Strip()
    local d = opts()
    local launcher = rawget(_G, "WickCoreMinimapButton")
    if not (d.enable and d.square and d.strip and classicPieces()) then
        if self.strip and self.strip:IsShown() then
            self.strip:Hide()
            if launcher then
                launcher:SetSize(28, 28)
                if launcher.RegisterForDrag then launcher:RegisterForDrag("LeftButton") end
                placeLauncher()
            end
            self.mail:ClearAllPoints()
            self.mail:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -4, -4)
        end
        return false
    end
    local s = self:BuildStrip()
    s:Show()
    local level = s:GetFrameLevel() + 2
    local n = 0
    for _, name in ipairs(STRIP) do
        local b = rawget(_G, name)
        if b and b:IsShown() and not (b.IsForbidden and b:IsForbidden()) then
            n = n + 1
            local x = STRIP_PAD + (n - 1) * (TILE + STRIP_GAP)
            if math.abs((b:GetWidth() or 0) - TILE) > 0.5 or math.abs((b:GetHeight() or 0) - TILE) > 0.5 then
                b:SetSize(TILE, TILE)
            end
            local p, rel, _, px = b:GetPoint(1)
            if not (b:GetNumPoints() == 1 and p == "LEFT" and rel == s and px == x) then
                b:ClearAllPoints()
                b:SetPoint("LEFT", s, "LEFT", x, 0)
            end
            if b:GetFrameLevel() < level then b:SetFrameLevel(level) end
            if b == launcher then
                -- Ours: its own tile and corners stay; the row places it,
                -- so its drag round the map's edge stands down.
                if launcher.RegisterForDrag then launcher:RegisterForDrag() end
                if launcher.icon then
                    launcher.icon:ClearAllPoints()
                    launcher.icon:SetPoint("TOPLEFT", 4, -4)
                    launcher.icon:SetPoint("BOTTOMRIGHT", -4, 4)
                end
            else
                fit(b)
            end
        end
    end
    local mp, mrel = self.mail:GetPoint(1)
    if mp ~= "RIGHT" or mrel ~= s then
        self.mail:ClearAllPoints()
        self.mail:SetPoint("RIGHT", s, "RIGHT", -STRIP_PAD - 2, 0)
    end
    return true
end

-- ============================================================
-- Lifecycle
-- ============================================================
-- Addons that place buttons around the minimap (LibDBIcon and most others)
-- ask this to know whether to follow a circle or the square's edge.
function GetMinimapShape()
    local p = MM.db and opts()
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

    local function reshape() if opts().square then MM:Shape() end end
    ns:On("PLAYER_ENTERING_WORLD", function()
        reshape(); MM:UpdateZone()
        -- Addons make their buttons at login and for a while after.
        C_Timer.After(2, function() MM:Collect() end)
        C_Timer.After(10, function() MM:Collect() end)
    end)
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
    if ns:Game() then
        L:Note(Chrome:Esc("fel") .. "The Classic look keeps the game's own minimap: round in its ring, with its zone, clock, zoom and mail. Gathering addon buttons still works.|r")
    end
    L:Toggle("Square", "square", { tooltip = "Off gives back Blizzard's round map and its ring." })
    L:Toggle("Ring around the round map", "ring", { tooltip = "Blizzard's gold ring and north marker, on the round map only. With the ring the map keeps Blizzard's size so the ring fits; without it the map fills the box." })
    L:Toggle("Fill the minimap box", "fill", { tooltip = "The map grows to the full width of Blizzard's minimap box and sits in its top right corner, so it can go right into the corner of the screen. Move the box with Edit Mode. The round map keeps Blizzard's size, so its ring fits." })
    L:Toggle("Hide the zoom buttons", "hideZoom")
    L:Toggle("Hide Blizzard's zone header and clock", "hideBlizzardText")
    L:Toggle("Gather addon buttons into a flyout", "collect", { tooltip = "Every addon's button round the map, under a + at the map's corner; pins drawn on the map itself are left alone. Stands down when another collector (MBB) is running. Takes effect after a reload when switched off." })
    if MM.ClassicPieces() then
        L:Toggle("The game's buttons in a row under the map", "strip", { tooltip = "Tracking, the group finder, a battleground queue, the day and night dial and Wick's launcher, in a row under the square map, with new mail at its end. Other addons' buttons stay in the flyout. Switched off, the buttons go back to the map's corners after a reload." })
    end
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
