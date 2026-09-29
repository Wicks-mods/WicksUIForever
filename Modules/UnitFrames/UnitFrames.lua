-- Wick's UI
-- Modules/UnitFrames/UnitFrames.lua: the unit frames, built on oUF.
--
-- One style function builds every widget a frame could use. Configure
-- then applies the settings for that unit: sizes, what is shown, where
-- the text sits and what it says. Configure runs again on any settings
-- change, out of combat, so nothing needs a reload except the aura
-- filters, which the client's aura container takes at creation.
--
-- On this client health is always secret. Bars are fed straight from the
-- client by oUF and our code never reads a health number. Colours that
-- would need a comparison (low-health red) come from the client's own
-- colour curves instead.

local ADDON, ns = ...

local oUF = ns.oUF
local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local UF = ns:NewModule("unitframes", { title = "Unit Frames", order = 20 })
ns.UnitFrames = UF
UF.frames = {}
UF.PostStyle = {}
UF.all = setmetatable({}, { __mode = "k" })

-- ============================================================
-- Defaults
-- ============================================================
local function text(tag, point, x, y, size, enable)
    return { enable = enable ~= false, tag = tag, point = point, x = x or 0, y = y or 0, size = size or 12 }
end

local function auras(o)
    local d = {
        enable = false, size = 26, perRow = 8, rows = 1, spacing = 2,
        anchor = "TOPLEFT", attach = "TOP", x = 0, y = 4,
        growthX = "RIGHT", growthY = "UP",
        onlyMine = false, showDuration = true, showCount = true,
        filter = "HELPFUL",
    }
    for k, v in pairs(o or {}) do d[k] = v end
    return d
end

local function unit(o)
    local d = {
        enable = true,
        width = 220, height = 40,
        power = true, powerHeight = 8, powerGap = 1,
        portrait = "none",        -- none, left, right
        portraitWidth = 40,
        texts = {
            left  = text("[wui:namecolor][name]", "LEFT", 4, 0),
            right = text("[wui:health]", "RIGHT", -4, 0),
            power = text("", "RIGHT", -4, 0, 10, false),
        },
        castbar = {
            enable = false, width = 220, height = 18, icon = true, latency = false,
            detach = false, x = 0, y = -4, showName = true, showTime = true,
        },
        buffs = auras({ filter = "HELPFUL" }),
        debuffs = auras({ filter = "HARMFUL", attach = "TOP", y = 4 }),
        classPower = false,
        raidIcon = true, leader = true, combat = false, resting = false,
        role = false, readyCheck = false, phase = false, resurrect = false, summon = false,
        rangeFade = false,
        point = "CENTER,UIParent,CENTER,0,0",
    }
    for k, v in pairs(o or {}) do
        if type(v) == "table" and type(d[k]) == "table" then
            for k2, v2 in pairs(v) do d[k][k2] = v2 end
        else
            d[k] = v
        end
    end
    return d
end
UF.unitDefaults = unit

local defaults = {
    enable = true,
    healthColor   = "class",       -- class, dark, gradient
    font          = "Wick",           -- PT Sans Narrow Bold
    fontOutline   = "OUTLINE",
    darkColor     = { 0.13, 0.12, 0.17, 1 },
    classBackdrop = true,          -- health background in the class colour, dim
    bgAlpha       = 0.25,
    colorStrength = 0.85,          -- 1 is the game's colour as it is
    castColor     = { 0.31, 0.78, 0.47, 1 },
    castLocked    = { 0.45, 0.42, 0.50, 1 },
    smooth        = true,
    rangeAlpha    = 0.45,
    targetBorder  = true,          -- fel border on the frame of whatever you target
    threatBorder  = true,
    units = {
        player = unit({
            point = "BOTTOM,UIParent,BOTTOM,-300,210",
            castbar = { enable = true, detach = true, width = 260, height = 22, latency = true, point = "BOTTOM,UIParent,BOTTOM,0,160" },
            debuffs = { enable = true, perRow = 8, size = 26 },
            classPower = true, combat = true, resting = true,
            classPowerX = 0, classPowerY = 3, classPowerHeight = 6, classPowerGap = 2,
            texts = { right = text("[wui:health]", "RIGHT", -4, 0) },
        }),
        target = unit({
            point = "BOTTOM,UIParent,BOTTOM,300,210",
            castbar = { enable = true, width = 220, height = 18, y = -4 },
            buffs = { enable = true, perRow = 8, size = 22, attach = "TOP", y = 4, anchor = "TOPLEFT" },
            debuffs = { enable = true, perRow = 8, size = 26, onlyMine = true, attach = "TOP", y = 30 },
            texts = { left = text("[wui:level] [wui:namecolor][name]", "LEFT", 4, 0) },
        }),
        targettarget = unit({
            point = "BOTTOM,UIParent,BOTTOM,300,160",
            width = 120, height = 26, power = false,
            texts = { left = text("[wui:namecolor][name]", "CENTER", 0, 0, 11), right = text("", "RIGHT", -4, 0, 11, false) },
        }),
        focus = unit({
            point = "LEFT,UIParent,LEFT,300,-100",
            width = 180, height = 32,
            castbar = { enable = true, width = 180, height = 16 },
            debuffs = { enable = true, perRow = 6, size = 22, onlyMine = true },
        }),
        focustarget = unit({
            enable = false,
            point = "LEFT,UIParent,LEFT,490,-100",
            width = 120, height = 26, power = false,
            texts = { left = text("[wui:namecolor][name]", "CENTER", 0, 0, 11), right = text("", "RIGHT", -4, 0, 11, false) },
        }),
        pet = unit({
            point = "BOTTOM,UIParent,BOTTOM,-300,160",
            width = 120, height = 26, powerHeight = 5,
            texts = { left = text("[name]", "LEFT", 4, 0, 11), right = text("[wui:perhp]", "RIGHT", -4, 0, 11) },
        }),
        boss = unit({
            point = "RIGHT,UIParent,RIGHT,-120,120",
            width = 190, height = 36,
            castbar = { enable = true, width = 190, height = 14 },
            debuffs = { enable = true, perRow = 5, size = 24, onlyMine = true, attach = "LEFT", anchor = "RIGHT", growthX = "LEFT", x = -4, y = 0 },
            spacing = 30,
        }),
    },
}
ns.defaults.profile.unitframes = defaults

local SINGLES = { "player", "target", "targettarget", "focus", "focustarget", "pet" }
UF.SINGLES = SINGLES
local LABELS = {
    player = "Player", target = "Target", targettarget = "Target of target", focus = "Focus",
    focustarget = "Focus target", pet = "Pet", boss = "Boss", party = "Party", raid = "Raid",
}
UF.LABELS = LABELS

function UF:UnitDB(key)
    local d = self:db()
    return d.units[key]
end

-- ============================================================
-- Colours
-- ============================================================
function UF:ApplyColors()
    local d = self:db()
    local c = d.darkColor
    oUF.colors.health = oUF:CreateColor(c[1], c[2], c[3])
    -- The client evaluates this curve against the secret health percent,
    -- so a gradient never touches the number in our code.
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and oUF.colors.health.SetCurve then
        local curve = C_CurveUtil.CreateColorCurve()
        curve:AddPoint(0, CreateColor(0.80, 0.20, 0.20))
        curve:AddPoint(0.5, CreateColor(0.90, 0.75, 0.25))
        curve:AddPoint(1, CreateColor(C.fel[1], C.fel[2], C.fel[3]))
        pcall(oUF.colors.health.SetCurve, oUF.colors.health, curve)
    end
    oUF.colors.disconnected = oUF:CreateColor(0.45, 0.45, 0.45)
    oUF.colors.tapped = oUF:CreateColor(0.50, 0.50, 0.50)
    -- Power in tones that sit with the dark panels. oUF's stock set is the
    -- game's pure primaries, which glare on a flat bar.
    local P = Enum.PowerType or {}
    local power = {
        MANA = { 0.31, 0.45, 0.78, P.Mana }, RAGE = { 0.78, 0.25, 0.25, P.Rage },
        ENERGY = { 0.85, 0.78, 0.32, P.Energy }, FOCUS = { 0.78, 0.50, 0.28, P.Focus },
        RUNIC_POWER = { 0.00, 0.72, 0.86, P.RunicPower },
    }
    for token, c in pairs(power) do
        local color = oUF:CreateColor(c[1], c[2], c[3])
        oUF.colors.power[token] = color
        if c[4] then oUF.colors.power[c[4]] = color end
    end
end

local issecretUF = rawget(_G, "issecretvalue")

local function postUpdateHealthColor(health, unit, color)
    local bg = health.bg
    if not bg then return end
    local d = UF:db()
    -- Colour strength: the game's class colours are light tones, and on a
    -- flat fill a pale one (hunter, priest, rogue) reads nearly white.
    -- Scaling the colour down keeps the hue and loses the glare. A colour
    -- worked out from secret health (the gradient) is left as it is.
    local m = d.colorStrength or 1
    if color and m < 1 then
        local r, g, b = color:GetRGB()
        if not (issecretUF and (issecretUF(r) or issecretUF(g) or issecretUF(b))) then
            health:SetStatusBarColor(r * m, g * m, b * m)
        end
    end
    if d.classBackdrop and color then
        local r, g, b = color:GetRGB()
        bg:SetVertexColor(r, g, b, d.bgAlpha or 0.25)
    else
        bg:SetVertexColor(C.void[1], C.void[2], C.void[3], 1)
    end
end

-- ============================================================
-- Building
-- ============================================================
local function newBar(parent, layer)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetStatusBarTexture(ns.Media:Statusbar())
    local t = sb:GetStatusBarTexture()
    if t and t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
    ns.statusbars = ns.statusbars or setmetatable({}, { __mode = "k" })
    ns.statusbars[sb] = true
    return sb
end

local function barBG(sb)
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if ns:Modern() then
        -- A rounded track, faintly lighter than the glass it sits on.
        bg:SetTexture(ns.Media.rounded)
        if bg.SetTextureSliceMargins then bg:SetTextureSliceMargins(3, 3, 3, 3) end
        bg:SetVertexColor(1, 1, 1, 0.07)
    else
        bg:SetTexture(ns.Media:Statusbar())
        bg:SetVertexColor(C.void[1], C.void[2], C.void[3], 1)
    end
    sb.bg = bg
    return bg
end

local function keyFor(unit)
    unit = unit or ""
    if unit:match("^boss%d") then return "boss" end
    if unit:match("^party") then return unit:match("pet") and "partypet" or "party" end
    if unit:match("^raid") then return "raid" end
    return unit
end
UF.KeyFor = keyFor

local function buildCastbar(self, key)
    local cb = newBar(self)
    cb:SetFrameLevel(self:GetFrameLevel() + 5)
    ns:CreateBackdrop(cb, "Default", ns.mult)
    barBG(cb)
    cb.bg:SetVertexColor(C.void[1], C.void[2], C.void[3], 1)
    local g = ns:G()

    cb.Text = ns:CreateText(cb, 11, "LEFT")
    cb.Text:SetPoint("LEFT", 4, 0)
    cb.Time = ns:CreateText(cb, 11, "RIGHT")
    cb.Time:SetPoint("RIGHT", -4, 0)
    cb.Text:SetPoint("RIGHT", cb.Time, "LEFT", -4, 0)

    local spark = cb:CreateTexture(nil, "OVERLAY")
    spark:SetSize(2, 1)
    spark:SetColorTexture(1, 1, 1, 0.8)
    spark:SetBlendMode("ADD")
    spark:SetPoint("TOP", cb:GetStatusBarTexture(), "TOPRIGHT")
    spark:SetPoint("BOTTOM", cb:GetStatusBarTexture(), "BOTTOMRIGHT")
    cb.Spark = spark

    -- The icon sits outside the bar on the left, in its own border.
    local iconHolder = CreateFrame("Frame", nil, cb)
    ns:SetTemplate(iconHolder, "Default")
    local icon = iconHolder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:CropIcon(icon)
    cb.Icon = icon
    cb.wuiIconHolder = iconHolder

    if key == "player" then
        local safe = cb:CreateTexture(nil, "ARTWORK")
        safe:SetColorTexture(0.8, 0.2, 0.2, 0.5)
        cb.SafeZone = safe
    end

    -- The "cannot interrupt" state is a secret boolean for enemy casts.
    -- The client sets this overlay's alpha from it, so we never read it.
    local locked = cb:CreateTexture(nil, "ARTWORK", nil, 1)
    locked:SetAllPoints(cb:GetStatusBarTexture())
    locked:SetTexture(ns.Media:Statusbar())
    locked:SetAlpha(0)
    cb.Shield = locked
    cb.wuiLocked = locked

    cb.timeToHold = 0.4
    cb.hideTradeSkills = false
    self.Castbar = cb

    -- A castbar can be placed on its own, with a mover of its own.
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(200, 18)
    cb.wuiHolder = holder
    return cb
end

local function buildAuras(self, which, d)
    if not self.CreateAuras then return end
    local a = self:CreateAuras({
        layout = AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Horizontal or nil,
        initialAnchor = d.anchor,
        growthX = d.growthX,
        growthY = d.growthY,
        layoutLimit = d.perRow * (d.size + d.spacing),
    })
    a.size = d.size
    a.elementSpacing = d.spacing
    a.lineSpacing = d.spacing
    a.showCount = d.showCount
    -- The time is the client's countdown (see ns:AuraCountdown), not ours.
    a.showDuration = false
    a.showDebuffBorder = which == "debuffs"
    a.showStealableBorder = which == "buffs"
    a.tooltipAnchor = "ANCHOR_BOTTOMRIGHT"
    local filter = d.filter or (which == "buffs" and "HELPFUL" or "HARMFUL")
    if d.onlyMine and not filter:find("PLAYER") then filter = filter .. "|PLAYER" end
    a:AddGroup(filter, { maxFrameCount = d.perRow * math.max(1, d.rows) })
    a:SetSize(d.perRow * (d.size + d.spacing), math.max(1, d.rows) * (d.size + d.spacing))
    a.PostCreateButton = function(_, button)
        ns:AuraCountdown(button, d.size, d.showDuration)
        -- Our border on the client's button: a backdrop child a level down.
        if button.Icon then ns:CropIcon(button.Icon) end
        ns:CreateBackdrop(button, "Default", ns.mult)
        if button.Count then ns.Media:SetFont(button.Count, math.max(9, math.floor(d.size * 0.42)), "OUTLINE") end
    end
    self["wui" .. which] = a
    return a
end

local function buildClassPower(self)
    local max = 10
    local bars = {}
    for i = 1, max do
        local b = newBar(self)
        ns:CreateBackdrop(b, "Default", ns.mult)
        barBG(b)
        bars[i] = b
    end
    bars.PostUpdate = function(element, cur, maxNum, changed)
        if changed then UF:LayoutClassPower(self, maxNum) end
    end
    self.ClassPower = bars
    self.wuiClassPower = bars
end

-- Our own tooltip handlers. Blizzard's UnitFrame_OnEnter leaves a refresh
-- timer on the tooltip that re-reads the unit from the frame and throws
-- when a header child has none at that moment. This asks once, only for
-- a unit that exists, and refreshes by being asked again on OnEnter.
function UF.OnEnter(self)
    local unit = self.unit or (self.GetAttribute and self:GetAttribute("unit"))
    if not unit or not UnitExists(unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
    self.wuiTooltip = true
end

function UF.OnLeave(self)
    if self.wuiTooltip then
        self.wuiTooltip = nil
        GameTooltip:Hide()
    end
end

local function style(self, unit)
    local key = keyFor(unit)
    self.wuiKey = key
    UF.all[self] = true

    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", UF.OnEnter)
    self:SetScript("OnLeave", UF.OnLeave)

    ns:SetTemplate(self, "Default")
    if not ns:Modern() then
        self.wuiBG:SetColorTexture(C.void[1], C.void[2], C.void[3], 1)
        Chrome:Register(self.wuiBG, "void", "texture")
    end

    -- Health
    local health = newBar(self)
    barBG(health)
    health.PostUpdateColor = postUpdateHealthColor
    health.colorDisconnected = true
    health.colorTapping = true
    if key == "pet" then health.colorHappiness = true end
    if Enum.StatusBarInterpolation then
        health.smoothing = UF:db().smooth and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
    end
    self.Health = health

    -- Incoming heals and absorbs, drawn by the client from its own numbers.
    local heal = newBar(health)
    heal:SetPoint("TOP"); heal:SetPoint("BOTTOM")
    heal:SetPoint("LEFT", health:GetStatusBarTexture(), "RIGHT")
    heal:SetStatusBarColor(C.fel[1], C.fel[2], C.fel[3], 0.4)
    health.HealingAll = heal
    local absorb = newBar(health)
    absorb:SetPoint("TOP"); absorb:SetPoint("BOTTOM")
    absorb:SetPoint("LEFT", heal:GetStatusBarTexture(), "RIGHT")
    absorb:SetStatusBarColor(1, 1, 1, 0.35)
    health.DamageAbsorb = absorb
    local healAbsorb = newBar(health)
    healAbsorb:SetPoint("TOP"); healAbsorb:SetPoint("BOTTOM")
    healAbsorb:SetPoint("RIGHT", health:GetStatusBarTexture())
    healAbsorb:SetReverseFill(true)
    healAbsorb:SetStatusBarColor(0.7, 0.1, 0.1, 0.5)
    health.HealAbsorb = healAbsorb

    -- Power
    local power = newBar(self)
    barBG(power)
    power.colorPower = true
    power.colorDisconnected = true
    power.frequentUpdates = true
    self.Power = power
    local powerBorder = CreateFrame("Frame", nil, power)
    powerBorder:SetPoint("TOPLEFT", -ns.mult, ns.mult)
    powerBorder:SetPoint("BOTTOMRIGHT", ns.mult, -ns.mult)
    powerBorder:SetFrameLevel(power:GetFrameLevel())
    ns:SetTemplate(powerBorder, "None")
    power.wuiBorder = powerBorder

    -- Druid mana while in a form.
    if key == "player" and ns.myClass == "DRUID" then
        local add = newBar(self)
        barBG(add)
        add.colorPower = true
        ns:CreateBackdrop(add, "Default", ns.mult)
        self.AdditionalPower = add
    end

    -- Portrait
    local portrait = self:CreateTexture(nil, "ARTWORK")
    ns:CropIcon(portrait, 0.12)
    self.wuiPortrait = portrait

    -- Text lives on a frame above the bars so it is never covered.
    local overlay = CreateFrame("Frame", nil, self)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(self:GetFrameLevel() + 8)
    self.wuiOverlay = overlay
    self.wuiTexts = {}
    for _, slot in ipairs({ "left", "right", "power" }) do
        self.wuiTexts[slot] = ns:CreateText(overlay, 12, "LEFT")
    end

    -- Indicators
    local function icon(size)
        local t = overlay:CreateTexture(nil, "OVERLAY")
        t:SetSize(size, size)
        return t
    end
    self.wuiIcons = {
        raidIcon = icon(18), leader = icon(14), assistant = icon(14), combat = icon(16), resting = icon(16),
        role = icon(14), readyCheck = icon(20), phase = icon(20), resurrect = icon(22), summon = icon(22),
    }
    self.wuiIcons.raidIcon:SetPoint("CENTER", self, "TOP", 0, 0)
    self.wuiIcons.leader:SetPoint("CENTER", self, "TOPLEFT", 8, 0)
    self.wuiIcons.assistant:SetPoint("CENTER", self, "TOPLEFT", 8, 0)
    self.wuiIcons.combat:SetPoint("CENTER", self, "TOPRIGHT", -4, 0)
    self.wuiIcons.resting:SetPoint("CENTER", self, "TOPLEFT", 0, 0)
    self.wuiIcons.role:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)
    self.wuiIcons.readyCheck:SetPoint("CENTER", self, "CENTER")
    self.wuiIcons.phase:SetPoint("CENTER", self, "CENTER")
    self.wuiIcons.resurrect:SetPoint("CENTER", self, "CENTER")
    self.wuiIcons.summon:SetPoint("CENTER", self, "CENTER")

    -- Castbar and auras
    local d = UF:UnitDB(key)
    if d and d.castbar then buildCastbar(self, key) end
    if d and d.buffs then buildAuras(self, "buffs", d.buffs) end
    if d and d.debuffs then buildAuras(self, "debuffs", d.debuffs) end
    if key == "player" and (ns.myClass == "ROGUE" or ns.myClass == "DRUID") then buildClassPower(self) end

    -- Highlight on mouseover.
    local hl = overlay:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(self)
    hl:SetColorTexture(1, 1, 1, 0.06)

    self.Range = { insideAlpha = 1, outsideAlpha = UF:db().rangeAlpha }

    -- Group frames add their own pieces (dispel slot, HoT corners).
    if UF.PostStyle[key] then UF.PostStyle[key](self, d) end

    -- oUF finishes setting a frame up after this function returns, and
    -- elements cannot be switched on or off before that. Single frames
    -- are configured by Update straight after spawning. Group members
    -- appear whenever someone joins, in combat too, so they configure on
    -- the next frame; nothing Configure does to them is protected, since
    -- their size comes from the header's own secure setup.
    if key == "party" or key == "raid" or key == "partypet" then
        self.wuiHeaderChild = true
        C_Timer.After(0, function()
            local ok, err = pcall(UF.Configure, UF, self)
            if not ok then ns.errors = ns.errors or {}; ns.errors[#ns.errors + 1] = "group frame: " .. tostring(err) end
        end)
    end
end

-- ============================================================
-- Configure: settings onto an existing frame
-- ============================================================
local function place(region, parent, point, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, point, x or 0, y or 0)
end

local function justifyFor(point)
    if point:find("LEFT") then return "LEFT" end
    if point:find("RIGHT") then return "RIGHT" end
    return "CENTER"
end

local function setElement(self, name, on)
    if on then
        if not self:IsElementEnabled(name) then self:EnableElement(name) end
    elseif self:IsElementEnabled(name) then
        self:DisableElement(name)
    end
end

function UF:LayoutClassPower(self, maxNum)
    local bars = self.wuiClassPower
    if not bars then return end
    maxNum = maxNum or 5
    local d = UF:UnitDB(self.wuiKey)
    local w = self:GetWidth()
    local h = d.classPowerHeight or 6
    local gap = d.classPowerGap or 2
    local each = (w - gap * (maxNum - 1)) / maxNum
    for i, b in ipairs(bars) do
        b:ClearAllPoints()
        b:SetSize(each, h)
        b:SetPoint("BOTTOMLEFT", self, "TOPLEFT", (d.classPowerX or 0) + (i - 1) * (each + gap), d.classPowerY or 3)
        b:SetShown(i <= maxNum and d.classPower)
    end
end

function UF:Configure(self)
    local key = self.wuiKey
    local d = UF:UnitDB(key)
    if not d then return end
    local g = UF:db()
    local px = ns.mult or 1

    if not InCombatLockdown() and not self.wuiHeaderChild then self:SetSize(d.width, d.height) end
    local w, h = d.width, d.height

    -- Portrait takes a strip off one side.
    local pl, pr = 0, 0
    local portrait = self.wuiPortrait
    if d.portrait == "left" or d.portrait == "right" then
        portrait:ClearAllPoints()
        portrait:SetWidth(d.portraitWidth)
        portrait:SetPoint("TOP", self, "TOP", 0, -px)
        portrait:SetPoint("BOTTOM", self, "BOTTOM", 0, px)
        if d.portrait == "left" then
            portrait:SetPoint("LEFT", self, "LEFT", px, 0); pl = d.portraitWidth + px
        else
            portrait:SetPoint("RIGHT", self, "RIGHT", -px, 0); pr = d.portraitWidth + px
        end
        self.Portrait = portrait
        setElement(self, "Portrait", true)
        portrait:Show()
    else
        if self.Portrait then setElement(self, "Portrait", false) end
        portrait:Hide()
    end

    -- Crisp: health above, power below, one pixel apart, text in the bar.
    -- Modern: the frame is a glass panel with padding, the name and health
    -- text sit in a row above a slim bar, and power is a thin line under
    -- it. Raid frames keep their text on the bar, having no room above it.
    local modern = ns:Modern() and key ~= "raid"
    local health, power = self.Health, self.Power
    local pad, nameRow = px, 0
    if modern then
        pad = h < 36 and 5 or 7
        local lt = d.texts and d.texts.left
        nameRow = ((lt and lt.size) or 12) + (h < 36 and 3 or 5)
    end
    local ph = d.power and (modern and math.min(d.powerHeight, 3) or d.powerHeight) or 0
    local gap = d.power and (modern and 3 or (d.powerGap or 1)) or 0
    health:ClearAllPoints()
    health:SetPoint("TOPLEFT", self, "TOPLEFT", pad + pl, -(pad + nameRow))
    health:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad - pr, -(pad + nameRow))
    health:SetHeight(math.max(2, h - 2 * pad - nameRow - ph - gap))
    for _, sub in ipairs({ health.HealingAll, health.DamageAbsorb, health.HealAbsorb }) do
        if sub then sub:SetWidth(math.max(1, w - pl - pr)) end
    end

    if g.healthColor == "class" then
        health.colorClass, health.colorReaction, health.colorClassPet = true, true, true
        health.colorSmooth, health.colorHealth = false, false
    elseif g.healthColor == "gradient" then
        health.colorClass, health.colorReaction, health.colorClassPet = false, false, false
        health.colorSmooth, health.colorHealth = true, true
    else
        health.colorClass, health.colorReaction, health.colorClassPet = false, false, false
        health.colorSmooth, health.colorHealth = false, true
    end

    if d.power then
        power:ClearAllPoints()
        power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -gap)
        power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -gap)
        power:SetHeight(ph)
        power:Show()
        setElement(self, "Power", true)
    else
        setElement(self, "Power", false)
        power:Hide()
    end

    if self.AdditionalPower then
        local add = self.AdditionalPower
        add:ClearAllPoints()
        add:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
        add:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -3)
        add:SetHeight(5)
    end

    -- Texts
    for slot, fs in pairs(self.wuiTexts) do
        local td = d.texts and d.texts[slot]
        if fs.wuiTag then self:Untag(fs); fs.wuiTag = nil end
        if td and td.enable and td.tag and td.tag ~= "" then
            ns.Media:SetFont(fs, td.size, g.fontOutline, g.font)
            local anchorTo = (slot == "power" and d.power) and power or health
            if modern and slot ~= "power" then
                -- The row above the bar: name on the left, health on the right.
                fs:ClearAllPoints()
                local left = slot == "left" and not td.point:find("RIGHT")
                fs:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT", health, left and "TOPLEFT" or "TOPRIGHT", td.x or 0, 3)
                fs:SetJustifyH(left and "LEFT" or "RIGHT")
            else
                place(fs, anchorTo, td.point, td.x, td.y)
                fs:SetJustifyH(justifyFor(td.point))
            end
            -- Names are cut to the frame, not by counting letters, since
            -- an enemy's name can be secret and so cannot be measured.
            if slot == "left" then fs:SetWidth(math.max(20, (w - pl - pr) * 0.62)) else fs:SetWidth(0) end
            -- On a class-coloured bar a class-coloured name disappears, so
            -- the name colour is dropped there and the name shows white.
            local tag = td.tag
            if g.healthColor == "class" then tag = tag:gsub("%[wui:namecolor%]", "") end
            self:Tag(fs, tag)
            fs.wuiTag = td.tag
            fs:Show()
            if fs.UpdateTag then fs:UpdateTag() end
        else
            fs:Hide()
        end
    end

    -- Indicators
    local icons = self.wuiIcons
    local map = {
        raidIcon = "RaidTargetIndicator", leader = "LeaderIndicator", combat = "CombatIndicator",
        resting = "RestingIndicator", role = "GroupRoleIndicator", readyCheck = "ReadyCheckIndicator",
        phase = "PhaseIndicator", resurrect = "ResurrectIndicator", summon = "SummonIndicator",
    }
    for opt, element in pairs(map) do
        if d[opt] then
            self[element] = icons[opt]
            setElement(self, element, true)
        elseif self[element] then
            setElement(self, element, false)
            icons[opt]:Hide()
        end
    end
    if d.leader then
        self.AssistantIndicator = icons.assistant
        setElement(self, "AssistantIndicator", true)
    end

    -- Range
    if d.rangeFade then
        self.Range.outsideAlpha = g.rangeAlpha
        setElement(self, "Range", true)
    elseif self:IsElementEnabled("Range") then
        self:DisableElement("Range")
        self:SetAlpha(1)
    end

    -- Castbar
    local cb = self.Castbar
    if cb and d.castbar then
        local cd = d.castbar
        local cw, ch = cd.width, cd.height
        local iconSize = ch
        cb:ClearAllPoints()
        if cd.detach then
            local holder = cb.wuiHolder
            holder:SetSize(cw, ch)
            if not holder.mover then
                ns:CreateMover(holder, "castbar_" .. key, (LABELS[key] or key) .. " castbar", cd.point or "BOTTOM,UIParent,BOTTOM,0,160",
                    { groups = "unitframes", config = "unitframes." .. key })
            end
            ns.Movers:SetEnabled("castbar_" .. key, cd.enable)
            ns.Movers:Resize("castbar_" .. key)
            cb:SetPoint("TOPRIGHT", holder, "TOPRIGHT")
            cb:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", cd.icon and (iconSize + 3) or 0, 0)
        else
            if cb.wuiHolder.mover then ns.Movers:SetEnabled("castbar_" .. key, false) end
            cb:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", cd.x or 0, (cd.y or -4) - (self.AdditionalPower and 8 or 0))
            cb:SetSize(math.max(10, cw - (cd.icon and (iconSize + 3) or 0)), ch)
        end
        cb.wuiIconHolder:ClearAllPoints()
        cb.wuiIconHolder:SetSize(iconSize, iconSize)
        cb.wuiIconHolder:SetPoint("RIGHT", cb, "LEFT", -3, 0)
        cb.wuiIconHolder:SetShown(cd.icon)
        cb.Text:SetShown(cd.showName)
        cb.Time:SetShown(cd.showTime)
        local cs = cd.fontSize or math.max(9, math.min(14, ch - 6))
        ns.Media:SetFont(cb.Text, cs, g.fontOutline, g.font)
        ns.Media:SetFont(cb.Time, cs, g.fontOutline, g.font)
        cb.Spark:SetHeight(ch)
        local cc, lc = g.castColor, g.castLocked
        cb:SetStatusBarColor(cc[1], cc[2], cc[3], 1)
        cb.wuiLocked:SetVertexColor(lc[1], lc[2], lc[3], 1)
        if cb.SafeZone then cb.SafeZone:SetShown(cd.latency) end
        -- Modern: a thin line with the spell name and time above it.
        if ns:Modern() then
            local line = 5
            cb.wuiIconHolder:Hide()
            cb.Text:ClearAllPoints()
            cb.Text:SetPoint("BOTTOMLEFT", cb, "TOPLEFT", 0, 4)
            cb.Text:SetPoint("RIGHT", cb.Time, "LEFT", -6, 0)
            cb.Time:ClearAllPoints()
            cb.Time:SetPoint("BOTTOMRIGHT", cb, "TOPRIGHT", 0, 4)
            cb.Spark:SetHeight(line)
            cb:ClearAllPoints()
            if cd.detach then
                local holder = cb.wuiHolder
                holder:SetSize(cw, cs + 4 + line)
                ns.Movers:Resize("castbar_" .. key)
                cb:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT")
                cb:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT")
                cb:SetHeight(line)
            else
                cb:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", cd.x or 0, (cd.y or -4) - cs - 8 - (self.AdditionalPower and 8 or 0))
                cb:SetSize(cw, line)
            end
        end
        setElement(self, "Castbar", cd.enable)
        if not cd.enable then cb:Hide() end
    end

    -- Auras: position and whether they show. Size and filter are fixed at
    -- creation by the client's container.
    for _, which in ipairs({ "buffs", "debuffs" }) do
        local a = self["wui" .. which]
        local ad = d[which]
        if a and ad then
            a:ClearAllPoints()
            local attach = ad.attach or "TOP"
            local opposite = ({ TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" })[attach]
            local anchorPoint = (ad.anchor or "TOPLEFT")
            if attach == "TOP" or attach == "BOTTOM" then
                local horiz = anchorPoint:find("RIGHT") and "RIGHT" or "LEFT"
                -- Auras on top start above the combo points, so they never sit
                -- on them; the player's own offset applies on top of that.
                local lift = 0
                if attach == "TOP" and self.wuiClassPower and d.classPower then
                    lift = (d.classPowerY or 3) + (d.classPowerHeight or 6) + 2
                end
                a:SetPoint(opposite .. horiz, self, attach .. horiz, ad.x or 0, (ad.y or 0) + lift)
            else
                a:SetPoint(opposite, self, attach, ad.x or 0, ad.y or 0)
            end
            a:SetShown(ad.enable)
            if a.SetEnabled then pcall(a.SetEnabled, a, ad.enable) end
        end
    end

    if self.wuiClassPower then UF:LayoutClassPower(self) end

    if self.UpdateAllElements then self:UpdateAllElements("WicksUI_Configure") end
end

-- ============================================================
-- Target and threat borders
-- ============================================================
function UF:UpdateBorders()
    local g = self:db()
    for f in pairs(self.all) do
        local color = "border"
        local u = f.unit
        if u and UnitExists(u) then
            if g.targetBorder and f.wuiKey ~= "target" and f.wuiKey ~= "player" and UnitIsUnit(u, "target") then
                color = "fel"
            end
        end
        ns:SetBorderColor(f, color)
    end
end

-- ============================================================
-- Spawning
-- ============================================================
function UF:DisableBlizzard(key)
    if key == "boss" then
        for i = 1, 5 do oUF:DisableBlizzard("boss" .. i) end
    else
        pcall(oUF.DisableBlizzard, oUF, key)
    end
end

function UF:SpawnSingle(key)
    local d = self:UnitDB(key)
    local f = oUF:Spawn(key, "WicksUI_" .. key:gsub("^%l", string.upper))
    self.frames[key] = f
    ns:CreateMover(f, "uf_" .. key, LABELS[key] .. " frame", d.point, { groups = "unitframes", config = "unitframes." .. key })
    return f
end

function UF:SpawnBoss()
    local d = self:UnitDB("boss")
    local holder = CreateFrame("Frame", "WicksUI_BossHolder", UIParent)
    self.bossHolder = holder
    self.frames.boss = {}
    for i = 1, 5 do
        local f = oUF:Spawn("boss" .. i, "WicksUI_Boss" .. i)
        f:SetParent(holder)
        self.frames.boss[i] = f
    end
    ns:CreateMover(holder, "uf_boss", "Boss frames", d.point, { groups = "unitframes", config = "unitframes.boss" })
end

function UF:LayoutBoss()
    local d = self:UnitDB("boss")
    local holder = self.bossHolder
    if not holder then return end
    local sp = d.spacing or 30
    holder:SetSize(d.width, d.height * 5 + sp * 4)
    for i, f in ipairs(self.frames.boss) do
        f:ClearAllPoints()
        f:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * (d.height + sp))
    end
    ns.Movers:Resize("uf_boss")
end

function UF:ApplyEnabled(key, f)
    local d = self:UnitDB(key)
    if d.enable then
        f:Enable()
        ns.Movers:SetEnabled("uf_" .. key, true)
    else
        f:Disable()
        ns.Movers:SetEnabled("uf_" .. key, false)
    end
end

function UF:Initialize()
    self:ApplyColors()
    oUF:RegisterStyle("WicksUI", style)
    oUF:SetActiveStyle("WicksUI")

    for _, key in ipairs(SINGLES) do
        self:DisableBlizzard(key)
        self:SpawnSingle(key)
    end
    self:DisableBlizzard("boss")
    self:SpawnBoss()
    if ns.UnitGroups then ns.UnitGroups:Initialize() end

    ns:On("PLAYER_TARGET_CHANGED", function() UF:UpdateBorders() end)
    ns:On("GROUP_ROSTER_UPDATE", function() UF:UpdateBorders() end)
    self:Update()
end

function UF:Update()
    ns:AfterCombat("uf:update", function()
        self:ApplyColors()
        for _, key in ipairs(SINGLES) do
            local f = self.frames[key]
            if f then
                self:Configure(f)
                ns.Movers:Resize("uf_" .. key)
                self:ApplyEnabled(key, f)
            end
        end
        if self.frames.boss then
            for _, f in ipairs(self.frames.boss) do
                self:Configure(f)
                if self:UnitDB("boss").enable then f:Enable() else f:Disable() end
            end
            self:LayoutBoss()
            ns.Movers:SetEnabled("uf_boss", self:UnitDB("boss").enable)
        end
        if ns.UnitGroups then ns.UnitGroups:Update() end
        self:UpdateBorders()
    end)
end
