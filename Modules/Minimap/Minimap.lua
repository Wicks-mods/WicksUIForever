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
    hideZoom = true,
    hideBlizzardText = true,     -- Blizzard's zone header, replaced by ours
    zone = true, zoneSize = 12, zoneInside = true,
    clock = true, clockSize = 12, clock24 = true, clockLocal = true,
    coords = true, coordsSize = 11,
    mail = true,
    collect = true,              -- gather addon buttons into a flyout
}

local SQUARE = "Interface\\BUTTONS\\WHITE8X8"
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
function MM:Shape()
    local d = db()
    if d.square then
        if Minimap.SetMaskTexture then pcall(Minimap.SetMaskTexture, Minimap, SQUARE) end
        blob(0)
        for _, t in ipairs(ringArt()) do t:SetAlpha(0) end
        self.chrome:Show()
        local c = MinimapCluster and MinimapCluster.MinimapContainer
        if c then
            local w, h = Minimap:GetSize()
            if w and w > 0 then c:SetSize(w, h) end
        end
    else
        self.chrome:Hide()
    end
    local zoom = { Minimap.ZoomIn, Minimap.ZoomOut, rawget(_G, "MinimapZoomIn"), rawget(_G, "MinimapZoomOut") }
    for _, b in pairs(zoom) do if b then b:SetAlpha(d.hideZoom and 0 or 1); b:EnableMouse(not d.hideZoom) end end
    local zt = MinimapCluster and MinimapCluster.ZoneTextButton
    if zt then zt:SetAlpha(d.hideBlizzardText and 0 or 1); zt:EnableMouse(not d.hideBlizzardText) end
    local clock = rawget(_G, "TimeManagerClockButton")
    if clock then clock:SetAlpha((d.clock and d.hideBlizzardText) and 0 or 1) end
end

-- ============================================================
-- Text on the map
-- ============================================================
local function pvpColor()
    local pvp = GetZonePVPInfo and GetZonePVPInfo()
    if pvp == "sanctuary" then return 0.41, 0.8, 0.94 end
    if pvp == "friendly" then return 0.1, 1, 0.1 end
    if pvp == "hostile" then return 1, 0.1, 0.1 end
    if pvp == "contested" then return 1, 0.7, 0 end
    return C.text[1], C.text[2], C.text[3]
end

function MM:UpdateZone()
    local z = self.zone
    if not z then return end
    z:SetText(GetMinimapZoneText and GetMinimapZoneText() or "")
    z:SetTextColor(pvpColor())
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
        if elapsed >= 0.5 then elapsed = 0; MM:Tick() end
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
function MM:Initialize()
    if not Minimap then return end
    local chrome = CreateFrame("Frame", "WicksUI_MinimapChrome", Minimap)
    chrome:SetAllPoints(Minimap)
    chrome:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    ns:SetTemplate(chrome, "None", { brackets = true })
    self.chrome = chrome
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
    L:Note("The minimap stays where Edit Mode puts it.")
    L:Toggle("Square", "square", { tooltip = "Switching back to round takes a reload." })
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
