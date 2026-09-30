-- Wick's UI
-- Modules/Nameplates/Nameplates.lua: nameplates, on oUF's nameplate driver.
--
-- Blizzard's driver keeps running underneath, because nameplates carry
-- widgets and soft-target icons that addons cannot recreate, and it is
-- what handles the forbidden plates in dungeons. oUF lays our frame over
-- each plate and silences Blizzard's own drawing.
--
-- The execute highlight is the interesting part. Health is secret, so
-- "below 20%" cannot be tested. Instead a colour curve with a hard step at
-- the threshold is handed to the client, which evaluates it against the
-- real health and hands back a colour whose alpha is either 0 or 1. We
-- paint an overlay with it and never learn the number.

local ADDON, ns = ...

local oUF = ns.oUF
local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local NP = ns:NewModule("nameplates", { title = "Nameplates", order = 30 })
ns.Nameplates = NP
NP.plates = setmetatable({}, { __mode = "k" })

local issecret = rawget(_G, "issecretvalue")
local function plain(v) if issecret and issecret(v) then return nil end return v end

ns.defaults.profile.nameplates = {
    enable = true,
    width = 150, height = 12,
    healthColor = "class",            -- class (players) and reaction (NPCs), or dark
    threat = false,                   -- colour by threat, for tanks
    nameSize = 11, levelShown = true,
    percent = true, percentSize = 10,
    castbar = true, castHeight = 10, castIcon = true,
    debuffs = true, debuffSize = 22, debuffCount = 5,
    buffs = false, buffSize = 18,
    raidIcon = true, quest = true,
    targetBorder = true, targetScale = 1.1,
    nonTargetAlpha = 0.6,
    friendlyNameOnly = true,
    execute = 0,                      -- percent; 0 is off
    executeColor = { 0.95, 0.25, 0.25, 1 },
    -- The game's own settings, surfaced.
    maxDistance = 41,
    stacking = true,
    showFriends = false,
    clickThroughFriendly = true,
}

local function db() return NP:db() end

-- ============================================================
-- Execute curve
-- ============================================================
local function executeCurve(pct)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
    local c = db().executeColor
    local curve = C_CurveUtil.CreateColorCurve()
    if curve.SetType and Enum.LuaCurveType then pcall(curve.SetType, curve, Enum.LuaCurveType.Step) end
    local t = pct / 100
    curve:AddPoint(0, CreateColor(c[1], c[2], c[3], 1))
    curve:AddPoint(t, CreateColor(c[1], c[2], c[3], 1))
    curve:AddPoint(math.min(1, t + 0.0001), CreateColor(c[1], c[2], c[3], 0))
    curve:AddPoint(1, CreateColor(c[1], c[2], c[3], 0))
    return curve
end

local function updateExecute(health)
    local ov = health.wuiExecute
    if not ov then return end
    local curve = NP.curve
    if not curve or not health.values or not health.values.EvaluateCurrentHealthPercent then
        ov:Hide()
        return
    end
    local color = health.values:EvaluateCurrentHealthPercent(curve)
    if color then
        ov:SetVertexColor(color:GetRGBA())
        ov:Show()
    end
end

-- ============================================================
-- Style
-- ============================================================
local function newBar(parent)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetStatusBarTexture(ns.Media:Statusbar())
    ns.statusbars = ns.statusbars or setmetatable({}, { __mode = "k" })
    ns.statusbars[sb] = true
    return sb
end

local function style(self, unit)
    NP.plates[self] = true
    local d = db()

    local health = newBar(self)
    health:SetPoint("CENTER")
    ns:CreateBackdrop(health, "Default", ns.mult)
    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(C.void[1], C.void[2], C.void[3], 0.9)
    health.colorTapping = true
    health.colorDisconnected = true
    health.PostUpdate = function(h) updateExecute(h) end
    self.Health = health

    local exec = health:CreateTexture(nil, "ARTWORK", nil, 2)
    exec:SetAllPoints(health)
    exec:SetTexture(ns.Media:Statusbar())
    exec:SetBlendMode("BLEND")
    exec:Hide()
    health.wuiExecute = exec

    local overlay = CreateFrame("Frame", nil, self)
    overlay:SetAllPoints(health)
    overlay:SetFrameLevel(health:GetFrameLevel() + 5)

    self.wuiName = ns:CreateText(overlay, d.nameSize, "CENTER")
    self.wuiName:SetPoint("BOTTOM", health, "TOP", 0, 3)
    self.wuiPercent = ns:CreateText(overlay, d.percentSize, "RIGHT")
    self.wuiPercent:SetPoint("RIGHT", health, "RIGHT", -2, 0)

    -- Cast bar
    local cb = newBar(self)
    cb:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -3)
    cb:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -3)
    ns:CreateBackdrop(cb, "Default", ns.mult)
    local cbg = cb:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    cbg:SetColorTexture(C.void[1], C.void[2], C.void[3], 0.9)
    cb.Text = ns:CreateText(cb, 9, "LEFT")
    cb.Text:SetPoint("LEFT", 2, 0)
    cb.Text:SetPoint("RIGHT", -24, 0)
    cb.Time = ns:CreateText(cb, 9, "RIGHT")
    cb.Time:SetPoint("RIGHT", -2, 0)
    local iconHolder = CreateFrame("Frame", nil, cb)
    ns:SetTemplate(iconHolder, "Default")
    local icon = iconHolder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:CropIcon(icon)
    cb.Icon = icon
    cb.wuiIconHolder = iconHolder
    local locked = cb:CreateTexture(nil, "ARTWORK", nil, 1)
    locked:SetAllPoints(cb:GetStatusBarTexture())
    locked:SetTexture(ns.Media:Statusbar())
    locked:SetAlpha(0)
    cb.Shield = locked
    cb.wuiLocked = locked
    cb.timeToHold = 0.4
    self.Castbar = cb

    -- Your debuffs on it, above the name.
    if self.CreateAuras then
        local a = self:CreateAuras({ initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP",
            layoutLimit = d.debuffCount * (d.debuffSize + 2) })
        a.size = d.debuffSize
        a.elementSpacing = 2
        a.showCount = true
        -- Our own time text (the client's countdown is hidden: ns:AuraCountdown).
        a.showDuration = true
        a.disableMouse = true
        -- Before AddGroup, so the buttons it makes get it.
        a.PostCreateButton = function(_, button)
            ns:AuraCountdown(button, d.debuffSize, true)
            if button.Icon then ns:CropIcon(button.Icon) end
            ns:CreateBackdrop(button, "Default", ns.mult)
        end
        a:AddGroup("HARMFUL|PLAYER", { maxFrameCount = d.debuffCount })
        a:SetSize(d.debuffCount * (d.debuffSize + 2), d.debuffSize)
        self.wuiDebuffs = a

        -- Buffs worth knowing about on an enemy: stealable or purgeable.
        local b = self:CreateAuras({ initialAnchor = "BOTTOMRIGHT", growthX = "LEFT", growthY = "UP",
            layoutLimit = 4 * (d.buffSize + 2) })
        b.size = d.buffSize
        b.elementSpacing = 2
        b.showStealableBorder = true
        b.disableMouse = true
        -- Before AddGroup, so the buttons it makes get it.
        b.PostCreateButton = function(_, button)
        ns:AuraCountdown(button, nil, false)
            if button.Icon then ns:CropIcon(button.Icon) end
            ns:CreateBackdrop(button, "Default", ns.mult)
        end
        b:AddGroup("HELPFUL|RAID", { maxFrameCount = 4 })
        b:SetSize(4 * (d.buffSize + 2), d.buffSize)
        self.wuiBuffs = b
    end

    local raid = overlay:CreateTexture(nil, "OVERLAY")
    raid:SetSize(18, 18)
    raid:SetPoint("RIGHT", health, "LEFT", -4, 0)
    self.RaidTargetIndicator = raid

    -- Threat: a glow round the bar with your threat on this mob.
    local glow = health:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(ns.Media.shadow)
    if glow.SetTextureSliceMargins then glow:SetTextureSliceMargins(28, 28, 28, 28) end
    glow:SetPoint("TOPLEFT", health, "TOPLEFT", -9, 9)
    glow:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 9, -9)
    glow:SetAlpha(0.9)
    glow:Hide()
    glow.feedbackUnit = "player"
    self.wuiThreatGlow = glow

    local quest = overlay:CreateTexture(nil, "OVERLAY")
    quest:SetSize(14, 14)
    quest:SetPoint("LEFT", health, "RIGHT", 4, 0)
    self.QuestIndicator = quest

    NP:Configure(self)
    self.wuiStyled = true
end

-- ============================================================
-- Configure
-- ============================================================
function NP:Configure(self)
    local d = db()
    local h = self.Health
    h:SetSize(d.width, d.height)

    h.colorClass, h.colorReaction, h.colorHealth = d.healthColor == "class", d.healthColor == "class", d.healthColor ~= "class"
    h.colorThreat = d.threat

    -- While the plate is first being styled, oUF has not set it up yet and
    -- switching an element fails; the widget alone is enough then, oUF
    -- enables it itself. Afterwards, a settings change switches it.
    local th = ns.A and ns.A.db and ns.A.db.profile.threat
    local want = th and th.enable and th.plateGlow and self.wuiThreatGlow and true or false
    if not self.wuiStyled then
        self.ThreatIndicator = want and self.wuiThreatGlow or nil
    elseif want then
        self.ThreatIndicator = self.wuiThreatGlow
        if not self:IsElementEnabled("ThreatIndicator") then self:EnableElement("ThreatIndicator") end
    elseif self.ThreatIndicator and self:IsElementEnabled("ThreatIndicator") then
        self:DisableElement("ThreatIndicator")
        self.wuiThreatGlow:Hide()
    end

    local cb = self.Castbar
    cb:SetHeight(d.castHeight)
    cb.wuiIconHolder:ClearAllPoints()
    local iconSize = d.height + d.castHeight + 3
    cb.wuiIconHolder:SetSize(iconSize, iconSize)
    cb.wuiIconHolder:SetPoint("TOPRIGHT", h, "TOPLEFT", -3, 0)
    cb.wuiIconHolder:SetShown(d.castIcon)
    local g = ns.UnitFrames and ns.UnitFrames:db()
    local cc = g and g.castColor or { C.fel[1], C.fel[2], C.fel[3] }
    local lc = g and g.castLocked or { 0.45, 0.42, 0.5 }
    cb:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
    cb.wuiLocked:SetVertexColor(lc[1], lc[2], lc[3], 1)

    ns.Media:SetFont(self.wuiName, d.nameSize)
    ns.Media:SetFont(self.wuiPercent, d.percentSize)
    self.wuiName:SetWidth(d.width + 40)

    if self.wuiNameTag then self:Untag(self.wuiName) end
    self.wuiNameTag = d.levelShown and "[wui:level] [wui:namecolor][name]" or "[wui:namecolor][name]"
    self:Tag(self.wuiName, self.wuiNameTag)
    if self.wuiPctTagged then self:Untag(self.wuiPercent); self.wuiPctTagged = nil end
    if d.percent then
        self:Tag(self.wuiPercent, "[wui:perhp]")
        self.wuiPctTagged = true
        self.wuiPercent:Show()
    else
        self.wuiPercent:Hide()
    end

    if self.wuiDebuffs then
        self.wuiDebuffs:ClearAllPoints()
        self.wuiDebuffs:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, d.nameSize + 6)
        self.wuiDebuffs:SetShown(d.debuffs)
    end
    if self.wuiBuffs then
        self.wuiBuffs:ClearAllPoints()
        self.wuiBuffs:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", 0, d.nameSize + 6)
        self.wuiBuffs:SetShown(d.buffs)
    end
end

-- Things that depend on the unit as well as the settings: friendly
-- name-only plates, whether this is the target.
function NP:Refresh(self)
    local unit = self.unit
    if not unit then return end
    local d = db()
    local hasTarget = UnitExists("target")
    local isTarget = hasTarget and UnitIsUnit(unit, "target")

    local friendly = plain(UnitIsFriend("player", unit))
    local nameOnly = d.friendlyNameOnly and friendly
    self.Health:SetShown(not nameOnly)
    self.Castbar:SetAlpha(nameOnly and 0 or 1)
    self.wuiName:ClearAllPoints()
    if nameOnly then
        self.wuiName:SetPoint("CENTER", self, "CENTER", 0, 0)
    else
        self.wuiName:SetPoint("BOTTOM", self.Health, "TOP", 0, 3)
    end

    if self.Health.backdrop then
        ns:SetBorderColor(self.Health.backdrop, (isTarget and d.targetBorder) and "fel" or "border")
    end
    self:SetAlpha((not hasTarget or isTarget or nameOnly) and 1 or d.nonTargetAlpha)
    self.Health:SetScale((isTarget and d.targetBorder) and d.targetScale or 1)
end

function NP:RefreshAll()
    for f in pairs(self.plates) do
        if f.unit and f:IsShown() then self:Refresh(f) end
    end
end

-- ============================================================
-- Game settings
-- ============================================================
function NP:CVars()
    local d = db()
    return {
        nameplateMaxDistance = tostring(d.maxDistance),
        nameplateMotion = d.stacking and "1" or "0",
        nameplateShowFriends = d.showFriends and "1" or "0",
    }
end

-- ============================================================
-- Lifecycle
-- ============================================================
function NP:Initialize()
    local d = db()
    self.curve = (d.execute or 0) > 0 and executeCurve(d.execute) or nil
    oUF:RegisterStyle("WicksUI_Nameplate", style)
    oUF:SetActiveStyle("WicksUI_Nameplate")
    local driver = oUF:SpawnNamePlates("WicksUI_")
    self.driver = driver
    if driver then
        driver:SetSize(d.width + 10, d.height + 20)
        driver:SetFriendlyInteractible(not d.clickThroughFriendly)
        driver:SetCVars(self:CVars())
        driver:SetAddedCallback(function(frame) NP:Refresh(frame) end)
        driver:SetTargetCallback(function() NP:RefreshAll() end)
    end
    -- Unit frames spawned before us; put their style back as the active one
    -- for anything spawned later.
    if ns.UnitFrames and ns.UnitFrames.initialized then oUF:SetActiveStyle("WicksUI") end
    ns:On("PLAYER_TARGET_CHANGED", function() NP:RefreshAll() end)
    ns:On("UNIT_FACTION", function() NP:RefreshAll() end)
end

function NP:Update()
    ns:AfterCombat("np:update", function()
        local d = db()
        self.curve = (d.execute or 0) > 0 and executeCurve(d.execute) or nil
        if self.driver then
            self.driver:SetSize(d.width + 10, d.height + 20)
            self.driver:SetFriendlyInteractible(not d.clickThroughFriendly)
            self.driver:SetCVars(self:CVars())
        end
        for f in pairs(self.plates) do
            self:Configure(f)
            if f.unit then
                self:Refresh(f)
                if f.UpdateAllElements then f:UpdateAllElements("WicksUI_Configure") end
            end
        end
    end)
end

-- ============================================================
-- Settings
-- ============================================================
ns.Config:AddPage("nameplates", "Nameplates", function(L)
    L:DB(db)
    L:Toggle("Enable", "enable", { tooltip = "Takes effect after a reload." })
    L:Slider("Width", "width", 60, 300, 1)
    L:Slider("Height", "height", 4, 40, 1)
    L:Dropdown("Health colour", "healthColor", { { "class", "Class and reaction" }, { "dark", "Dark" } })
    L:Toggle("Colour by threat", "threat", { tooltip = "For tanks: the bar shows whether you hold the mob." })

    L:Heading("Execute")
    L:Note("Lights the bar under a health percentage you choose. The client does the comparison against health it keeps from addons, so this works in combat. 0 switches it off.")
    L:Slider("Below this percent", "execute", 0, 50, 1)
    L:Color("Colour", "executeColor")

    L:Heading("Targeting")
    L:Toggle("Fel border and a size bump on your target", "targetBorder")
    L:Slider("Target size", "targetScale", 1, 1.5, 0.05)
    L:Slider("Everything else, alpha", "nonTargetAlpha", 0.1, 1, 0.05)

    L:Heading("Text")
    L:Slider("Name size", "nameSize", 6, 20, 1)
    L:Toggle("Level before the name", "levelShown")
    L:Toggle("Health percent", "percent")
    L:Slider("Percent size", "percentSize", 6, 20, 1)
    L:Toggle("Friendly plates show the name only", "friendlyNameOnly")

    L:Heading("Cast bar and auras")
    L:Toggle("Cast bar", "castbar")
    L:Slider("Cast bar height", "castHeight", 4, 24, 1)
    L:Toggle("Spell icon", "castIcon")
    L:Toggle("Your debuffs", "debuffs")
    L:Toggle("Buffs you can steal or purge", "buffs")
    L:Note("Aura sizes and counts are set when a plate is first made, so they take effect after a reload.")
    L:Slider("Debuff size", "debuffSize", 10, 40, 1)
    L:Slider("Debuffs shown", "debuffCount", 1, 10, 1)

    L:Heading("The game's settings")
    L:Slider("How far away plates show", "maxDistance", 20, 41, 1)
    L:Toggle("Stack plates instead of overlapping", "stacking")
    L:Toggle("Friendly player plates", "showFriends")
    L:Toggle("Click through friendly plates", "clickThroughFriendly")
end, { onChange = function() NP:Update() end, order = 30 })
