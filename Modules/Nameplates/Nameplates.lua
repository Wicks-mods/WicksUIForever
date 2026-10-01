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
    healthColor = "look",             -- look: the look's own pair where it has one, else class
                                      -- and reaction; class; or dark
    lookMigrated = false,
    threat = false,                   -- colour by threat, for tanks
    nameSize = 11, levelShown = true,
    percent = true, percentSize = 10,
    castbar = true, castHeight = 10, castIcon = true,
    debuffs = true, debuffSize = 22, debuffCount = 5,
    buffs = false, buffSize = 18,
    raidIcon = true, quest = true,
    targetBorder = true, targetScale = 1.1,
    nonTargetAlpha = 0.6,
    targetMarker = "arrows",          -- arrows, glow or none
    focusMarker = true,               -- your focus marked the same way, in its own colour
    focusColor = { 0.40, 0.65, 1.00, 1 },
    classMarker = true,               -- a diamond on the bar for elites and rares
    lockMark = true,                  -- a lock on casts you cannot interrupt
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

-- The bar's border sits wholly outside it at the look's thickness. Rebel
-- draws two pixels; with the backdrop one pixel out, the bar covered half.
local function edge()
    local st = Chrome.StyleDef and Chrome:StyleDef()
    if st and st.family == "og" then return ns.mult * (st.borderPx or 1) end
    return ns.mult
end

-- Wick Modern and the looks like it draw a plate the way they draw a unit
-- frame: the bar inset in a rounded card on a rounded track, and the cast
-- bar a thin line with the spell above it and no icon. The card reaches
-- this far past the bar, enough for a square bar end to sit inside its
-- rounded corner. It has no soft shadow: plates crowd, and their shadows
-- would pool. The OG family keeps the bordered bar.
local CARD_PAD, CAST_LINE = 3, 5
local function cardPad() return ns:Modern() and CARD_PAD or 0 end
NP.CardPad = cardPad
local function cardInset() return ns:Modern() and CARD_PAD or edge() end
NP.CardInset = cardInset

-- A rounded track, faintly lighter than the card it sits on, as the unit
-- frames draw one; flat in the OG family.
local function track(bar, alpha)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if ns:Modern() then
        bg:SetTexture(ns.Media.rounded)
        if bg.SetTextureSliceMargins then bg:SetTextureSliceMargins(3, 3, 3, 3) end
        bg:SetVertexColor(1, 1, 1, 0.07)
    else
        bg:SetColorTexture(C.void[1], C.void[2], C.void[3], alpha)
    end
    return bg
end

-- The look's own health colours, where it has them: one for friends, one
-- for anything you can attack, the pair the unit frames use.
local function lookColor(unit)
    local st = Chrome.StyleDef and Chrome:StyleDef()
    local h = st and st.health
    if not h then return nil end
    local want = plain(UnitCanAttack("player", unit)) and h.enemy or h.friend
    local c = C[want]
    if not c and type(want) == "string" and #want == 6 then
        c = { tonumber(want:sub(1, 2), 16) / 255, tonumber(want:sub(3, 4), 16) / 255, tonumber(want:sub(5, 6), 16) / 255 }
    end
    return c or C.text
end
NP.LookColor = lookColor

-- The elite diamond's colour: gold for elites and bosses, silver for rares.
local CLASSMARK = {
    elite = { 0.95, 0.78, 0.35 }, worldboss = { 0.95, 0.78, 0.35 },
    rare = { 0.78, 0.81, 0.85 }, rareelite = { 0.78, 0.81, 0.85 },
}

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
    return ns:TrackStatusBar(sb)
end

local function style(self, unit)
    NP.plates[self] = true
    local d = db()

    local health = newBar(self)
    health:SetPoint("CENTER")
    health.backdrop = ns:CreateBackdrop(health, "Default", cardInset(), ns:Modern() and { shadow = false } or nil)
    track(health, 0.9)
    health.colorTapping = true
    health.colorDisconnected = true
    health.PostUpdate = function(h) updateExecute(h) end
    -- In the look's colours, after oUF has picked; a tapped mob and a
    -- tank's threat colour keep what oUF gave them.
    health.PostUpdateColor = function(h, unit)
        if db().healthColor ~= "look" or not unit then return end
        local controlled = plain(UnitPlayerControlled(unit))
        if h.colorTapping and not controlled and plain(UnitIsTapDenied(unit)) then return end
        if h.colorThreat and not controlled and plain(UnitThreatSituation("player", unit)) then return end
        local c = lookColor(unit)
        if c then h:SetStatusBarColor(c[1], c[2], c[3]) end
    end
    self.Health = health

    -- Over the fill only, so the health that is left turns the colour and
    -- the part already lost stays dark.
    local exec = health:CreateTexture(nil, "ARTWORK", nil, 2)
    exec:SetAllPoints(health:GetStatusBarTexture())
    ns:BarTexture(exec)
    exec:SetBlendMode("BLEND")
    exec:Hide()
    health.wuiExecute = exec

    local overlay = CreateFrame("Frame", nil, self)
    overlay:SetAllPoints(health)
    overlay:SetFrameLevel(health:GetFrameLevel() + 5)

    self.wuiName = ns:CreateText(overlay, d.nameSize, "CENTER")
    self.wuiName:SetPoint("BOTTOM", health, "TOP", 0, 3 + cardPad())
    self.wuiPercent = ns:CreateText(overlay, d.percentSize, "RIGHT")
    self.wuiPercent:SetPoint("RIGHT", health, "RIGHT", -2, 0)

    -- Cast bar. Placed under the bar here; Modern places its thin line in
    -- Configure, once the size of the text above it is known.
    local cb = newBar(self)
    cb:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -3)
    cb:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -3)
    ns:CreateBackdrop(cb, "Default", edge(), ns:Modern() and { shadow = false } or nil)
    local cbg = track(cb, 0.9)
    -- The unit frames' thin cast line runs over a dark track.
    if ns:Modern() then
        cbg:SetVertexColor(C.void[1], C.void[2], C.void[3], 1)
        Chrome:Register(cbg, "void", "vertex", 1)
    end
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
    ns:BarTexture(locked)
    locked:SetAlpha(0)
    cb.Shield = locked
    cb.wuiLocked = locked
    cb.timeToHold = 0.4

    -- Casts you cannot interrupt: the icon darkened under a lock (or a lock
    -- at the bar's end with no icon). Whether a cast can be interrupted is
    -- a secret; the client sets these alphas from it and we never read it.
    local lockHolder = CreateFrame("Frame", nil, cb)
    lockHolder:SetFrameLevel(iconHolder:GetFrameLevel() + 2)
    local wash = lockHolder:CreateTexture(nil, "ARTWORK")
    wash:SetColorTexture(0, 0, 0, 0.55)
    local lock = lockHolder:CreateTexture(nil, "OVERLAY")
    lock:SetTexture(ns.Media:Glyph("lock"))
    wash:SetAlpha(0)
    lock:SetAlpha(0)
    cb.wuiLockHolder, cb.wuiLockWash, cb.wuiLockGlyph = lockHolder, wash, lock
    local function lockFrom(el, flag)
        local on = db().lockMark
        for _, t in ipairs({ el.wuiLockWash, el.wuiLockGlyph }) do
            if on and t.SetAlphaFromBoolean then t:SetAlphaFromBoolean(flag, 1, 0) else t:SetAlpha(0) end
        end
    end
    cb.PostCastStart = function(el, _, _, flag) lockFrom(el, flag) end
    cb.PostCastInterruptible = function(el, _, _, flag) lockFrom(el, flag) end
    -- The target's pointers step out past the spell icon while it shows.
    cb:HookScript("OnShow", function() NP:PlaceMarks(self) end)
    cb:HookScript("OnHide", function() NP:PlaceMarks(self) end)
    self.wuiCastbar = cb

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
            ns:CreateBackdrop(button, "Default", edge())
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
            ns:CreateBackdrop(button, "Default", edge())
        end
        b:AddGroup("HELPFUL|RAID", { maxFrameCount = 4 })
        b:SetSize(4 * (d.buffSize + 2), d.buffSize)
        self.wuiBuffs = b
    end

    local raid = overlay:CreateTexture(nil, "OVERLAY")
    raid:SetSize(18, 18)
    raid:SetPoint("RIGHT", health, "LEFT", -4 - cardPad(), 0)
    raid.PostUpdate = function() NP:PlaceMarks(self) end
    self.RaidTargetIndicator = raid

    -- Threat: a glow round the bar with your threat on this mob. Under the
    -- bar's border, whose edge it starts from (the glow's own geometry
    -- wants 16), so the target's border shows over it and only a soft
    -- halo reaches outside.
    local glow = ns:Glow(health.backdrop, 16, { under = true, alpha = 0.6 })
    glow.feedbackUnit = "player"
    self.wuiThreatGlow = glow

    local quest = overlay:CreateTexture(nil, "OVERLAY")
    quest:SetSize(14, 14)
    quest:SetPoint("LEFT", health, "RIGHT", 4 + cardPad(), 0)
    quest.PostUpdate = function() NP:PlaceMarks(self) end
    self.QuestIndicator = quest

    -- Target and focus: a pointer each side of the bar, or a glow round it
    -- (its own, apart from the threat glow).
    local markL = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    markL:SetTexture(ns.Media:Glyph("pointer-right"))
    markL:Hide()
    local markR = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    markR:SetTexture(ns.Media:Glyph("pointer-left"))
    markR:Hide()
    self.wuiMarkL, self.wuiMarkR = markL, markR

    -- Elites and rares: a diamond at the bar's left end, over a dark one a
    -- little larger so it reads on any health colour. A texture, not text:
    -- the client does not draw an addon's own PNG inside a string.
    local cmBack = overlay:CreateTexture(nil, "OVERLAY", nil, 3)
    cmBack:SetTexture(ns.Media:Glyph("diamond"))
    cmBack:SetVertexColor(0, 0, 0, 0.85)
    cmBack:Hide()
    local cm = overlay:CreateTexture(nil, "OVERLAY", nil, 4)
    cm:SetTexture(ns.Media:Glyph("diamond"))
    cm:SetPoint("CENTER", cmBack, "CENTER", 0, 0)
    cm:Hide()
    self.wuiClassMark, self.wuiClassBack = cm, cmBack
    local tglow = ns:Glow(health.backdrop, 16, { under = true, alpha = 0.75 })
    tglow.Override = nil
    self.wuiTargetGlow = tglow

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

    -- The look's colours start from class and reaction, repainted after.
    local byUnit = d.healthColor ~= "dark"
    h.colorClass, h.colorReaction, h.colorHealth = byUnit, byUnit, not byUnit
    -- Threat colours are for tanks, as the setting says: while you tank, a
    -- mob that is not on you stands out. Anyone else keeps class and
    -- reaction, where a mob your pet or the tank holds would otherwise go
    -- grey. The threat glow and meter still warn them.
    local tank = ns.Threat and ns.Threat.IsTank and ns.Threat.IsTank() or false
    local byThreat = d.threat and tank and true or false
    if self.wuiStyled and h.SetColorThreat and h.__owner then h:SetColorThreat(byThreat) else h.colorThreat = byThreat end

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

    local cb = self.wuiCastbar
    -- Like the threat glow: assigned while styling, switched afterwards.
    if not self.wuiStyled then
        self.Castbar = d.castbar and cb or nil
    elseif d.castbar then
        self.Castbar = cb
        if not self:IsElementEnabled("Castbar") then self:EnableElement("Castbar") end
    elseif self.Castbar and self:IsElementEnabled("Castbar") then
        self:DisableElement("Castbar")
        cb:Hide()
    end
    -- Modern's cast bar is a thin line with no icon, whatever the height
    -- and icon settings say; those are the OG family's.
    local modern = ns:Modern()
    local showIcon = d.castIcon and not modern
    cb:SetHeight(modern and CAST_LINE or d.castHeight)
    cb.wuiIconHolder:ClearAllPoints()
    local iconSize = d.height + d.castHeight + 3
    cb.wuiIconHolder:SetSize(iconSize, iconSize)
    cb.wuiIconHolder:SetPoint("TOPRIGHT", h, "TOPLEFT", -3, 0)
    cb.wuiIconHolder:SetShown(showIcon)
    local lh, lw, lg = cb.wuiLockHolder, cb.wuiLockWash, cb.wuiLockGlyph
    lh:ClearAllPoints()
    lg:ClearAllPoints()
    if showIcon then
        lh:SetAllPoints(cb.wuiIconHolder)
        lw:ClearAllPoints()
        lw:SetPoint("TOPLEFT", 1, -1)
        lw:SetPoint("BOTTOMRIGHT", -1, 1)
        lw:Show()
        local ls = math.max(10, math.floor(iconSize * 0.62 + 0.5))
        lg:SetSize(ls, ls)
        lg:SetPoint("CENTER", lh, "CENTER", 0, 0)
    else
        -- With no icon the lock sits at the bar's left end.
        local ls = modern and 10 or d.castHeight + 4
        lh:SetSize(ls, ls)
        lh:SetPoint("RIGHT", cb, "LEFT", modern and -3 or -2, 0)
        lw:Hide()
        lg:SetAllPoints(lh)
    end
    lg:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
    -- The unit frames' cast colours, the look's accent unless one was picked.
    if ns.UnitFrames and ns.UnitFrames.PaintCast then ns.UnitFrames:PaintCast(cb) end

    -- The unit frames' face and outline, so a look's lettering (Rebel's
    -- heavy outline) reaches the plates too.
    local ufd = ns.UnitFrames and ns.UnitFrames.db and ns.UnitFrames:db()
    local face, outline = ufd and ufd.font, ufd and ufd.fontOutline
    ns.Media:SetFont(self.wuiName, d.nameSize, outline, face, true)
    ns.Media:SetFont(self.wuiPercent, d.percentSize, outline, face, true)
    ns.Media:SetFont(cb.Text, 9, outline, face, true)
    ns.Media:SetFont(cb.Time, 9, outline, face, true)
    self.wuiName:SetWidth(d.width + 40)
    -- Modern: the line hangs under the card, the spell name and its time
    -- in a row above it, as on the unit frames.
    if modern then
        local _, ts = cb.Text:GetFont()
        local drop = CARD_PAD + 2 + (tonumber(ts) or 9) + 4
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -drop)
        cb:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, -drop)
        cb.Text:ClearAllPoints()
        cb.Text:SetPoint("BOTTOMLEFT", cb, "TOPLEFT", 0, 3)
        cb.Text:SetPoint("RIGHT", cb.Time, "LEFT", -6, 0)
        cb.Time:ClearAllPoints()
        cb.Time:SetPoint("BOTTOMRIGHT", cb, "TOPRIGHT", 0, 3)
    end

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
        self.wuiDebuffs:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, d.nameSize + 6 + cardPad())
        self.wuiDebuffs:SetShown(d.debuffs)
    end
    if self.wuiBuffs then
        self.wuiBuffs:ClearAllPoints()
        self.wuiBuffs:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", 0, d.nameSize + 6 + cardPad())
        self.wuiBuffs:SetShown(d.buffs)
    end

    local cs = math.max(7, d.height - 3)
    self.wuiClassBack:SetSize(cs + 3, cs + 3)
    self.wuiClassBack:ClearAllPoints()
    self.wuiClassBack:SetPoint("LEFT", h, "LEFT", 2, 0)
    self.wuiClassMark:SetSize(cs, cs)

    local ms = math.max(10, d.height + 4)
    self.wuiMarkL:SetSize(ms * 0.75, ms)
    self.wuiMarkR:SetSize(ms * 0.75, ms)
    NP:PlaceMarks(self)
end

-- The pointers hug the bar (its card, in Modern), stepping out past
-- whatever else sits beside it: the spell icon while a cast shows, a raid
-- mark, a quest icon.
function NP:PlaceMarks(self)
    local L, R, h = self.wuiMarkL, self.wuiMarkR, self.Health
    if not (L and h) then return end
    local d = db()
    local left, right = 0, 0
    local cb = self.wuiCastbar
    if d.castIcon and not ns:Modern() and cb and self.Castbar and cb:IsShown() then
        left = math.max(left, d.height + d.castHeight + 3 + 3)
    end
    local raid = self.RaidTargetIndicator
    if raid and raid:IsShown() then left = math.max(left, 18 + 4) end
    local quest = self.QuestIndicator
    if quest and quest:IsShown() then right = math.max(right, 14 + 4) end
    local pad = cardPad()
    L:ClearAllPoints()
    L:SetPoint("RIGHT", h, "LEFT", -(3 + pad + left), 0)
    R:ClearAllPoints()
    R:SetPoint("LEFT", h, "RIGHT", 3 + pad + right, 0)
end

-- Things that depend on the unit as well as the settings: friendly
-- name-only plates, whether this is the target.
function NP:Refresh(self)
    local unit = ns:UnitOf(self)
    if not unit or not UnitExists(unit) then return end
    local d = db()
    local hasTarget = UnitExists("target")
    local isTarget = hasTarget and UnitIsUnit(unit, "target")
    local isFocus = d.focusMarker and not isTarget and UnitExists("focus") and plain(UnitIsUnit(unit, "focus"))

    local friendly = plain(UnitIsFriend("player", unit))
    local nameOnly = d.friendlyNameOnly and friendly
    self.Health:SetShown(not nameOnly)
    self.wuiCastbar:SetAlpha(nameOnly and 0 or 1)
    -- The percent and the aura rows hang off the plate, not the bar, so
    -- hiding the bar leaves them behind; a name-only plate is the name.
    self.wuiPercent:SetShown(d.percent and not nameOnly)
    if self.wuiDebuffs then self.wuiDebuffs:SetShown(d.debuffs and not nameOnly) end
    if self.wuiBuffs then self.wuiBuffs:SetShown(d.buffs and not nameOnly) end
    local cls = d.classMarker and not nameOnly and CLASSMARK[plain(UnitClassification(unit)) or ""]
    if cls then self.wuiClassMark:SetVertexColor(cls[1], cls[2], cls[3], 1) end
    self.wuiClassMark:SetShown(cls and true or false)
    self.wuiClassBack:SetShown(cls and true or false)

    self.wuiName:ClearAllPoints()
    if nameOnly then
        self.wuiName:SetPoint("CENTER", self, "CENTER", 0, 0)
    else
        self.wuiName:SetPoint("BOTTOM", self.Health, "TOP", 0, 3 + cardPad())
    end

    if self.Health.backdrop then
        local border = "border"
        if isTarget and d.targetBorder then border = "fel" elseif isFocus then border = d.focusColor end
        ns:SetBorderColor(self.Health.backdrop, border)
    end

    -- Pointers or a glow, fel for the target and the focus colour for the
    -- focus; none on a name-only plate.
    local mark = (not nameOnly) and ((isTarget and "target") or (isFocus and "focus")) or nil
    local style = mark and d.targetMarker or "none"
    local c = mark == "focus" and d.focusColor or C.fel
    local arrows, glow = style == "arrows", style == "glow"
    if arrows then
        self.wuiMarkL:SetVertexColor(c[1], c[2], c[3], 1)
        self.wuiMarkR:SetVertexColor(c[1], c[2], c[3], 1)
        NP:PlaceMarks(self)
    end
    self.wuiMarkL:SetShown(arrows)
    self.wuiMarkR:SetShown(arrows)
    if self.wuiTargetGlow then
        if glow then self.wuiTargetGlow:SetVertexColor(c[1], c[2], c[3], self.wuiTargetGlow.wuiAlpha or 0.75) end
        self.wuiTargetGlow:SetShown(glow)
    end

    self:SetAlpha((not hasTarget or isTarget or isFocus or nameOnly) and 1 or d.nonTargetAlpha)
    self.Health:SetScale((isTarget and d.targetBorder) and d.targetScale or 1)
end

function NP:RefreshAll()
    for f in pairs(self.plates) do
        -- Visible, not just shown: a plate that has gone keeps its last unit.
        if ns:UnitOf(f) and f:IsVisible() then self:Refresh(f) end
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
    -- Profiles made before the look's colours were offered had "class"
    -- saved; that becomes the look's, which is class and reaction anyway
    -- in a look without a pair of its own.
    if not d.lookMigrated then
        if d.healthColor == "class" then d.healthColor = "look" end
        d.lookMigrated = true
    end
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
    ns:On("PLAYER_FOCUS_CHANGED", function() NP:RefreshAll() end)
    ns:On("UNIT_CLASSIFICATION_CHANGED", function() NP:RefreshAll() end)
    -- Tanking or not decides the threat colours.
    ns:On("PLAYER_ROLES_ASSIGNED", function() NP:Update() end)
    ns:On("PLAYER_SPECIALIZATION_CHANGED", function(unit) if unit == nil or unit == "player" then NP:Update() end end)
    -- A theme change repaints the plates in the new colours: cast bars in
    -- the accent, the look's health colours, the target's pointers.
    if Chrome.OnThemeChanged then
        Chrome:OnThemeChanged(function()
            for plate in pairs(NP.plates) do
                if ns.UnitFrames and ns.UnitFrames.PaintCast then ns.UnitFrames:PaintCast(rawget(plate, "wuiCastbar")) end
                local hb = rawget(plate, "Health")
                if hb and hb.ForceUpdate and ns:UnitOf(plate) and plate:IsVisible() then pcall(hb.ForceUpdate, hb) end
            end
            NP:RefreshAll()
        end)
    end
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
            if ns:UnitOf(f) and f:IsVisible() then
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
    -- The looks that draw the full cast bar, by name, for the settings that
    -- only apply in them.
    local og = {}
    for _, st in ipairs(Chrome.Styles or {}) do
        if st.family == "og" then og[#og + 1] = st.name end
    end
    local ogNames = table.concat(og, " and ")
    L:Toggle("Enable", "enable", { tooltip = "Takes effect after a reload." })
    L:Slider("Width", "width", 60, 300, 1)
    L:Slider("Height", "height", 4, 40, 1)
    L:Dropdown("Health colour", "healthColor", { { "look", "The look's colours" }, { "class", "Class and reaction" }, { "dark", "Dark" } },
        { tooltip = "The look's colours are the pair the unit frames use in that look, one for friends and one for enemies. A look without its own uses class and reaction." })
    L:Toggle("Colour by threat while you tank", "threat", { tooltip = "In a tank role or spec, the bar shows whether you hold the mob. In any other role plates keep their class and reaction colours; the threat glow and meter warn you instead." })

    L:Heading("Execute")
    L:Note("Lights the bar under a health percentage you choose. The client does the comparison against health it keeps from addons, so this works in combat. 0 switches it off.")
    L:Slider("Below this percent", "execute", 0, 50, 1)
    L:Color("Colour", "executeColor")

    L:Heading("Targeting")
    L:Dropdown("Mark your target with", "targetMarker", { { "arrows", "Pointers either side" }, { "glow", "A glow" }, { "none", "Nothing" } })
    L:Toggle("Accent border and a size bump on your target", "targetBorder")
    L:Slider("Target size", "targetScale", 1, 1.5, 0.05, { disabled = function() return not db().targetBorder end })
    L:Toggle("Mark your focus too", "focusMarker", { tooltip = "The same mark and a border in the focus colour. It stays bright while you target something else." })
    L:Color("Focus colour", "focusColor", { disabled = function() return not db().focusMarker end })
    L:Slider("Everything else, opacity", "nonTargetAlpha", 0.1, 1, 0.05)

    L:Heading("Text")
    L:Slider("Name size", "nameSize", 6, 20, 1)
    L:Toggle("Level before the name", "levelShown")
    L:Toggle("A diamond for elites and rares", "classMarker", { tooltip = "Gold for elites and bosses, silver for rares, at the left end of the bar." })
    L:Toggle("Health percent", "percent")
    L:Slider("Percent size", "percentSize", 6, 20, 1, { disabled = function() return not db().percent end })
    L:Toggle("Friendly plates show the name only", "friendlyNameOnly")

    L:Heading("Cast bar and auras")
    -- A greyed-out setting takes no pointer, so cannot say why it is grey.
    if ns:Modern() then
        L:Note(("This look draws the cast bar as a thin line with the spell name above it, as on the unit frames. Its height and spell icon apply in %s."):format(ogNames))
    end
    L:Toggle("Cast bar", "castbar")
    local noCast = function() return not db().castbar end
    L:Slider("Cast bar height", "castHeight", 4, 24, 1, {
        disabled = function() return noCast() or ns:Modern() end,
        tooltip = ("Applies in %s. The other looks draw the cast bar as a thin line with the spell name above it."):format(ogNames),
    })
    L:Toggle("Spell icon", "castIcon", {
        disabled = function() return noCast() or ns:Modern() end,
        tooltip = ("Applies in %s. The other looks leave the icon off, as their unit frames do."):format(ogNames),
    })
    L:Toggle("A lock on casts you cannot interrupt", "lockMark", { disabled = noCast,
        tooltip = "Over the spell icon, or at the bar's end without one, on top of the bar's own cannot-interrupt colour." })
    L:Toggle("Your debuffs", "debuffs")
    L:Toggle("Buffs you can steal or purge", "buffs")
    L:Note("Aura sizes and counts are set when a plate is first made, so they take effect after a reload.")
    L:Slider("Debuff size", "debuffSize", 10, 40, 1, { disabled = function() return not db().debuffs end })
    L:Slider("Debuffs shown", "debuffCount", 1, 10, 1, { disabled = function() return not db().debuffs end })

    L:Heading("The game's settings")
    L:Slider("How far away plates show", "maxDistance", 20, 41, 1)
    L:Toggle("Stack plates instead of overlapping", "stacking")
    L:Toggle("Friendly player plates", "showFriends")
    L:Toggle("Click through friendly plates", "clickThroughFriendly")
end, { onChange = function() NP:Update() end, order = 30 })
