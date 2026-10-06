-- Wick's UI
-- Modules/UnitFrames/Classic.lua: the unit frames in the game's own shape.
--
-- The Classic look draws the player, the target, the focus, their targets
-- and the pet as the game draws its own: the portrait set into the frame
-- art, the name, level, health and power where the game puts them, an
-- elite's dragon and a target's name band in its reaction colour. Each
-- client's own art and layout, read off its frame XML (TBC Anniversary's
-- gold frames; Forever's newer ones, whose bars sit over the art and are
-- clipped to its shape by masks). What Wick's UI adds stays with them:
-- fade, range, threat, cast bars, auras, and every setting that is not
-- about the frame's shape. Party and raid frames keep Wick's layout.
--
-- Positions below are from each frame's top left corner, as the game
-- places them; cx, cy is a centre.

local ADDON, ns = ...

local UF = ns.UnitFrames
local Chrome = ns.Core.Chrome
local issecret = rawget(_G, "issecretvalue")
local function plain(v) if issecret and issecret(v) then return nil end return v end

local TF = "Interface\\TargetingFrame\\"
local STATE = "Interface\\CharacterFrame\\UI-StateIcon"

-- ============================================================
-- TBC Anniversary: Classic FrameXML
-- ============================================================
local TBC_TARGET = {
    w = 232, h = 100,
    art = { file = TF .. "UI-TargetingFrame", x = 19.5, y = -4.5, w = 230, h = 99,
        coords = { 0.1015625, 1.0, 0.0078125, 0.78125 },
        classif = { elite = TF .. "UI-TargetingFrame-Elite", worldboss = TF .. "UI-TargetingFrame-Elite",
            rareelite = TF .. "UI-TargetingFrame-Rare-Elite", rare = TF .. "UI-TargetingFrame-Rare",
            minus = TF .. "UI-TargetingFrame-Minus" } },
    portrait = { x = 144, y = -16, s = 64 },
    health = { x = 23, y = -45, w = 119, h = 12 },
    power = { x = 23, y = -56, w = 119, h = 12 },
    band = { file = TF .. "UI-TargetingFrame-LevelBackground", x = 23, y = -26, w = 119, h = 19 },
    name = { cx = 82, cy = -35, w = 100 },
    level = { cx = 196.75, cy = -70 },
    healthText = { cx = 83, cy = -51 },
    powerText = { cx = 83, cy = -62 },
    leader = { x = 188, y = -14, s = 16 },
    raidIcon = { cx = 175, cy = -18, s = 26 },
    flash = { file = TF .. "UI-TargetingFrame-Flash", x = -6, y = -3, w = 242, h = 93,
        coords = { 0, 0.9453125, 0, 0.181640625 } },
    auras = { x = 21, y = -72 },
}
local TBC_TOT = {
    w = 93, h = 45,
    art = { file = TF .. "UI-TargetofTargetFrame", x = 0, y = 0, w = 93, h = 45,
        coords = { 0.015625, 0.7265625, 0, 0.703125 } },
    portrait = { x = 6, y = -6, s = 35 },
    health = { x = 45, y = -15, w = 46, h = 7 },
    power = { x = 45, y = -23, w = 46, h = 7 },
    name = { point = "BOTTOMLEFT", rel = "BOTTOMLEFT", x = 42, y = 2, w = 100, justify = "LEFT" },
    raidIcon = { cx = 23, cy = -4, s = 18 },
}
local TBC = {
    player = {
        w = 232, h = 100,
        art = { file = TF .. "UI-TargetingFrame", x = 19.5, y = -11.5, w = 193, h = 77,
            coords = { 0.85546875, 0.1015625, 0.0625, 0.6640625 } },
        portrait = { x = 24, y = -16, s = 64 },
        health = { x = 90, y = -45, w = 119, h = 12 },
        power = { x = 90, y = -56, w = 119, h = 12 },
        name = { cx = 150, cy = -35, w = 100 },
        level = { cx = 35.25, cy = -70, gold = true },
        healthText = { cx = 150, cy = -51 },
        powerText = { cx = 150, cy = -62 },
        leader = { x = 28, y = -14, s = 16 },
        combat = { x = 20.5, y = -52, w = 32, h = 32, file = STATE, coords = { 0.5, 1, 0, 0.484375 } },
        resting = { x = 19.5, y = -52, w = 31, h = 33, file = STATE, coords = { 0, 0.5, 0, 0.421875 } },
        raidIcon = { cx = 56, cy = -16, s = 26 },
        flash = { file = TF .. "UI-TargetingFrame-Flash", x = -3, y = -4, w = 242, h = 93,
            coords = { 0.9453125, 0, 0, 0.181640625 } },
    },
    target = TBC_TARGET,
    focus = TBC_TARGET,
    targettarget = TBC_TOT,
    focustarget = TBC_TOT,
    pet = {
        w = 128, h = 53,
        art = { file = TF .. "UI-SmallTargetingFrame", noPower = TF .. "UI-SmallTargetingFrame-NoMana",
            x = 0, y = -2, w = 128, h = 64 },
        portrait = { x = 7, y = -6, s = 37 },
        health = { x = 47, y = -22, w = 69, h = 8 },
        power = { x = 47, y = -29, w = 69, h = 8 },
        name = { point = "BOTTOMLEFT", rel = "BOTTOMLEFT", x = 52, y = 33, w = 100, justify = "LEFT" },
        healthText = { cx = 82, cy = -26, size = 9 },
        powerText = { cx = 82, cy = -33, size = 9 },
        flash = { file = TF .. "UI-PartyFrame-Flash", x = -4, y = 11, w = 128, h = 64, coords = { 0, 1, 1, 0 } },
    },
}

-- ============================================================
-- Forever: the Mainline frames with Forever's small level circle
-- ============================================================
local HUD = "UI-HUD-UnitFrame-"
local F_TARGET = {
    w = 232, h = 100, under = true,
    art = { atlas = HUD .. "Target-PortraitOn", x = 20, y = -16.5, w = 192, h = 67,
        classif = { rare = HUD .. "Target-Rare-PortraitOn", rareelite = HUD .. "Target-Rare-PortraitOn",
            minus = HUD .. "Target-MinusMob-PortraitOn" } },
    dragon = { boss = { atlas = HUD .. "Target-PortraitOn-Boss-Gold-Winged", x = 11, y = -4 },
        worldboss = { atlas = HUD .. "Target-PortraitOn-Boss-Gold-Winged", x = 11, y = -4 },
        rare = { atlas = HUD .. "Target-PortraitOn-Boss-Rare-Silver-Winged", x = 8, y = -7 },
        rareelite = { atlas = HUD .. "Target-PortraitOn-Boss-Rare-Silver-Winged", x = 8, y = -7 },
        elite = { atlas = HUD .. "Target-PortraitOn-Boss-Gold", x = 0, y = 1 } },
    portrait = { x = 148, y = -19, s = 58, mask = true },
    health = { x = 23, y = -40, w = 126, h = 20, atlas = HUD .. "Target-PortraitOn-Bar-Health",
        mask = { atlas = HUD .. "Target-PortraitOn-Bar-Health-Mask", x = 22, y = -34, w = 128, h = 32 } },
    power = { x = 23, y = -61, w = 134, h = 10, atlas = HUD .. "Target-PortraitOn-Bar-",
        mask = { atlas = HUD .. "Target-PortraitOn-Bar-Mana-Mask", x = -38, y = -58, w = 256, h = 16 } },
    band = { atlas = HUD .. "Target-PortraitOn-Type", x = 22, y = -25, w = 135, h = 18 },
    name = { point = "TOPLEFT", rel = "TOPLEFT", x = 24, y = -27, w = 117, justify = "LEFT" },
    circle = { x = 180, y = -54, s = 39 },
    level = { cx = 199.5, cy = -74, white = true },
    healthText = { cx = 86, cy = -50 },
    powerText = { cx = 86, cy = -66 },
    leader = { x = 131, y = -8, s = 16, atlas = HUD .. "Player-Group-LeaderIcon" },
    raidIcon = { cx = 177, cy = -19, s = 26 },
    flash = { atlas = HUD .. "Target-PortraitOn-InCombat", x = 22, y = -14.5, w = 188, h = 67 },
    auras = { x = 25, y = -74.5 },
}
local F_TOT = {
    w = 120, h = 49, under = true,
    art = { atlas = HUD .. "TargetofTarget-PortraitOn", x = 0, y = 0, w = 120, h = 49 },
    portrait = { x = 5, y = -5, s = 37, mask = true },
    health = { x = 44, y = -17, w = 70, h = 10, atlas = HUD .. "TargetofTarget-PortraitOn-Bar-Health",
        mask = { atlas = HUD .. "Party-PortraitOn-Bar-Health-Mask", x = 15, y = -14, w = 128, h = 16 } },
    power = { x = 40, y = -28, w = 74, h = 7, atlas = HUD .. "TargetofTarget-PortraitOn-Bar-",
        mask = { atlas = HUD .. "Party-PortraitOn-Bar-Mana-Mask", x = 13, y = -24, w = 128, h = 16 } },
    name = { point = "TOPLEFT", rel = "TOPLEFT", x = 44, y = -5, w = 68, justify = "LEFT" },
    raidIcon = { cx = 23, cy = -5, s = 18 },
    flash = { atlas = HUD .. "TargetofTarget-PortraitOn-InCombat", x = 0, y = 0, w = 120, h = 49 },
}
local F_PET = setmetatable({
    healthText = { cx = 79, cy = -22, size = 9 },
    powerText = { cx = 79, cy = -31.5, size = 8 },
}, { __index = F_TOT })
local FOREVER = {
    player = {
        w = 232, h = 100, under = true,
        art = { atlas = HUD .. "Player-PortraitOn", x = 17, y = -14.5, w = 198, h = 71 },
        portrait = { x = 24, y = -19, s = 60, mask = true },
        health = { x = 85, y = -41, w = 124, h = 19, atlas = HUD .. "Player-PortraitOn-Bar-Health",
            mask = { atlas = HUD .. "Player-PortraitOn-Bar-Health-Mask", x = 83, y = -35, w = 128, h = 31 } },
        power = { x = 85, y = -61, w = 124, h = 10, atlas = HUD .. "Player-PortraitOn-Bar-",
            mask = { atlas = HUD .. "Player-PortraitOn-Bar-Mana-Mask", x = 83, y = -59, w = 128, h = 16 } },
        name = { point = "TOPLEFT", rel = "TOPLEFT", x = 88, y = -27, w = 96, justify = "LEFT" },
        circle = { x = 13, y = -54, s = 39 },
        level = { cx = 32.5, cy = -74, white = true },
        healthText = { cx = 147, cy = -50.5 },
        powerText = { cx = 147, cy = -66 },
        leader = { x = 86, y = -10, s = 16, atlas = HUD .. "Player-Group-LeaderIcon" },
        combat = { x = 64, y = -62, w = 16, h = 16, atlas = HUD .. "Player-CombatIcon" },
        resting = { x = 64, y = -6, w = 20, h = 20, file = STATE, coords = { 0, 0.5, 0, 0.421875 } },
        raidIcon = { cx = 54, cy = -19, s = 26 },
        flash = { atlas = HUD .. "Player-PortraitOn-InCombat", x = 18.5, y = -13.5, w = 192, h = 71 },
    },
    target = F_TARGET,
    focus = F_TARGET,
    targettarget = F_TOT,
    focustarget = F_TOT,
    pet = F_PET,
}

-- The layout for a frame in Classic, or nil (a frame the game has none
-- for, or another look).
function UF:GameLayout(key)
    if not ns:Game() then return nil end
    local set = (ns.Core.Client and ns.Core.Client.isTBC) and TBC or FOREVER
    return set[key]
end

-- ============================================================
-- Drawing
-- ============================================================
local function art(tex, a)
    if a.atlas then
        tex:SetAtlas(a.atlas)
    else
        tex:SetTexture(a.file)
        if a.coords then tex:SetTexCoord(unpack(a.coords)) else tex:SetTexCoord(0, 1, 0, 1) end
    end
end

local function at(region, host, p)
    region:ClearAllPoints()
    if p.cx then
        region:SetPoint("CENTER", host, "TOPLEFT", p.cx, p.cy)
    elseif p.point then
        region:SetPoint(p.point, host, p.rel or p.point, p.x or 0, p.y or 0)
    else
        region:SetPoint("TOPLEFT", host, "TOPLEFT", p.x or 0, p.y or 0)
    end
end

local POWER_ATLAS = { MANA = "Mana", RAGE = "Rage", ENERGY = "Energy", FOCUS = "Focus", RUNIC_POWER = "RunicPower" }

-- Health in the game's colour: green on TBC Anniversary, the art's own on
-- Forever (its bar is drawn green); grey for a unit that is offline or
-- someone else's to kill.
local function gameHealthColor(health, unit)
    local L = health.wuiGameLayout
    if not L then return end
    local grey = unit and (plain(UnitIsConnected(unit)) == false or plain(UnitIsTapDenied and UnitIsTapDenied(unit)) == true)
    if grey then
        health:SetStatusBarColor(0.5, 0.5, 0.5)
    elseif L.under then
        health:SetStatusBarColor(1, 1, 1)
    else
        health:SetStatusBarColor(0, 1, 0)
    end
end

-- Power on Forever: the art for the unit's kind of power, untinted.
local function gamePowerColor(power, unit)
    local L = power.wuiGameLayout
    if not (L and L.under and L.power.atlas and unit) then return end
    local _, token = UnitPowerType(unit)
    token = plain(token)
    power:SetStatusBarTexture(L.power.atlas .. (POWER_ATLAS[token or ""] or "Mana"))
    power:SetStatusBarColor(1, 1, 1)
end

-- What changes with the unit: the art for its classification, an elite's
-- dragon, the name band in its reaction colour, the pet's art without a
-- power bar.
function UF:GameUpdate(self)
    local L = self.wuiGameUF
    local unit = self.unit
    if not (L and unit) then return end
    local c = plain(UnitClassification(unit)) or "normal"
    local a = L.art
    local swap = a.classif and a.classif[c]
    if swap then
        if a.atlas then self.wuiGameArt:SetAtlas(swap) else self.wuiGameArt:SetTexture(swap) end
    elseif a.noPower then
        local pmax = plain(UnitPowerMax(unit))
        self.wuiGameArt:SetTexture((pmax == 0) and a.noPower or a.file)
    else
        art(self.wuiGameArt, a)
    end
    local dragon = self.wuiGameDragon
    if dragon then
        local d = L.dragon[c]
        if d then
            dragon:SetAtlas(d.atlas, true)
            dragon:ClearAllPoints()
            dragon:SetPoint("TOPRIGHT", self.wuiGameArt, "TOPRIGHT", d.x, d.y)
            dragon:Show()
        else
            dragon:Hide()
        end
    end
    local band = self.wuiGameBand
    if band then
        local r, g, b = UnitSelectionColor(unit)
        r, g, b = plain(r), plain(g), plain(b)
        if plain(UnitIsTapDenied and UnitIsTapDenied(unit)) then r, g, b = 0.5, 0.5, 0.5 end
        if r and g and b then band:SetVertexColor(r, g, b, 1); band:Show() else band:Hide() end
    end
end

-- Built once, at spawn, for a frame the game has a layout for.
function UF:StyleGame(self, key, L)
    self.wuiGameUF = L
    -- No Wick panel: the game's frames are their art. The mouseover wash
    -- covered the whole frame, art and empty corners alike.
    if self.wuiHighlight then self.wuiHighlight:SetAlpha(0) end
    -- TBC's art sits over the bars, on a frame of its own; Forever's under
    -- them, the bars clipped to its shape.
    local host = self
    if not L.under then
        host = CreateFrame("Frame", nil, self)
        host:SetAllPoints()
        host:SetFrameLevel(self:GetFrameLevel() + 4)
        self.wuiGameArtFrame = host
    end
    local a = host:CreateTexture(nil, L.under and "BACKGROUND" or "BORDER", nil, L.under and 2 or 0)
    self.wuiGameArt = a
    if L.dragon then
        self.wuiGameDragon = host:CreateTexture(nil, L.under and "BACKGROUND" or "BORDER", nil, L.under and 3 or 1)
        self.wuiGameDragon:Hide()
    end
    if L.band then
        local band = self:CreateTexture(nil, "BACKGROUND", nil, L.under and 3 or 1)
        art(band, L.band)
        self.wuiGameBand = band
    end
    if L.circle then
        local circle = host:CreateTexture(nil, "BACKGROUND", nil, 4)
        circle:SetAtlas("UI-HUD-UnitFrame-SmallCircle")
        self.wuiGameCircle = circle
    end
    -- The threat flash in the game's art, under the frame.
    if L.flash then
        local f = self:CreateTexture(nil, "BACKGROUND", nil, -2)
        art(f, L.flash)
        f:SetBlendMode("ADD")
        f:Hide()
        f.Override = ns.ThreatGlowUpdate
        if self.wuiThreatGlow and self.wuiThreatGlow.Hide then self.wuiThreatGlow:Hide() end
        self.wuiThreatGlow = f
    end
    -- The level, on the text layer.
    if L.level then
        local lv = self.wuiOverlay:CreateFontString(nil, "OVERLAY")
        self.wuiGameLevel = lv
    end
    -- The bars take the game's art and colour, and leave the list of bars
    -- that take the texture from settings.
    for _, which in ipairs({ "Health", "Power" }) do
        local sb = self[which]
        if sb then
            sb.wuiGameLayout = L
            if ns.statusbars then ns.statusbars[sb] = nil end
        end
    end
    local health = self.Health
    for _, sub in ipairs({ health.HealingAll, health.DamageAbsorb, health.HealAbsorb }) do
        if sub and ns.statusbars then ns.statusbars[sub] = nil end
    end
    health.PostUpdateColor = gameHealthColor
    local hpPost = health.PostUpdate
    health.PostUpdate = function(h, unit, ...)
        if hpPost then hpPost(h, unit, ...) end
        UF:GameUpdate(self)
    end
    self.Power.PostUpdateColor = gamePowerColor
    -- Forever: the bars clipped to the art's shape.
    if L.under then
        local function clip(sb, m, subs)
            if not (sb and m) then return end
            local mask = self:CreateMaskTexture()
            mask:SetAtlas(m.atlas)
            mask:SetSize(m.w, m.h)
            mask:SetPoint("TOPLEFT", self, "TOPLEFT", m.x, m.y)
            sb:GetStatusBarTexture():AddMaskTexture(mask)
            for _, s in ipairs(subs or {}) do
                if s and s.GetStatusBarTexture then s:GetStatusBarTexture():AddMaskTexture(mask) end
            end
            if sb.bg then sb.bg:Hide() end
        end
        clip(health, L.health.mask, { health.HealingAll, health.DamageAbsorb, health.HealAbsorb })
        clip(self.Power, L.power.mask)
        if L.health.atlas then health:SetStatusBarTexture(L.health.atlas) end
    else
        local bar = TF .. "UI-StatusBar"
        health:SetStatusBarTexture(bar)
        self.Power:SetStatusBarTexture(bar)
        -- The game's dark backing under the bars, half see-through.
        for _, sb in ipairs({ health, self.Power }) do
            if sb.bg then sb.bg:SetTexture("Interface\\Buttons\\WHITE8X8"); sb.bg:SetVertexColor(0, 0, 0, 0.5) end
        end
    end
    -- The resting mark is the game's, not Wick's glyph on a tile.
    if L.resting then
        local r = self.wuiOverlay:CreateTexture(nil, "OVERLAY")
        self.wuiIcons.resting = r
        r:Hide()
    end
end

local NAME_GOLD = { 1, 0.82, 0 }

-- Every Configure, after Wick's own: the game's sizes and places, which
-- the frame's settings do not reach.
function UF:ConfigureGame(self)
    local L = self.wuiGameUF
    if not L then return end
    local d = UF:UnitDB(self.wuiKey)
    if not InCombatLockdown() and not self.wuiHeaderChild then self:SetSize(L.w, L.h) end

    local a = self.wuiGameArt
    a:SetSize(L.art.w, L.art.h)
    at(a, self, L.art)
    art(a, L.art)
    if self.wuiGameBand then
        self.wuiGameBand:SetSize(L.band.w, L.band.h)
        at(self.wuiGameBand, self, L.band)
    end
    if self.wuiGameCircle then
        self.wuiGameCircle:SetSize(L.circle.s, L.circle.s)
        at(self.wuiGameCircle, self, L.circle)
    end
    if L.flash and self.wuiThreatGlow then
        self.wuiThreatGlow:SetSize(L.flash.w, L.flash.h)
        at(self.wuiThreatGlow, self, L.flash)
    end

    -- Portrait, always shown: it is the frame's middle.
    local p = self.wuiPortrait
    p:ClearAllPoints()
    p:SetSize(L.portrait.s, L.portrait.s)
    p:SetPoint("TOPLEFT", self, "TOPLEFT", L.portrait.x, L.portrait.y)
    p:SetTexCoord(0, 1, 0, 1)
    if L.under then
        p:SetDrawLayer("BACKGROUND", 1)
        if L.portrait.mask and not p.wuiGameMask and self.CreateMaskTexture then
            local m = self:CreateMaskTexture()
            m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(p)
            p:AddMaskTexture(m)
            p.wuiGameMask = m
        end
    else
        p:SetDrawLayer("ARTWORK")
    end
    self.Portrait = p
    UF.SetElement(self, "Portrait", true)
    p:Show()

    -- Bars where the game has them; power always shown, as the game does.
    local health, power = self.Health, self.Power
    health:ClearAllPoints()
    health:SetPoint("TOPLEFT", self, "TOPLEFT", L.health.x, L.health.y)
    health:SetSize(L.health.w, L.health.h)
    for _, sub in ipairs({ health.HealingAll, health.DamageAbsorb, health.HealAbsorb }) do
        if sub then sub:SetWidth(L.health.w) end
    end
    health.colorClass, health.colorReaction, health.colorClassPet = false, false, false
    health.colorSmooth, health.colorHealth = false, true
    power:ClearAllPoints()
    power:SetPoint("TOPLEFT", self, "TOPLEFT", L.power.x, L.power.y)
    power:SetSize(L.power.w, L.power.h)
    power:Show()
    UF.SetElement(self, "Power", true)
    if power.wuiBorder then power.wuiBorder:Hide() end

    -- Texts: the name in the game's gold, the level, and the values on
    -- their bars, in the game's own fonts.
    local t = self.wuiTexts
    local function retag(fs, tag)
        if fs.wuiTag then self:Untag(fs); fs.wuiTag = nil end
        if tag then
            self:Tag(fs, tag)
            fs.wuiTag = tag
            fs:Show()
            if fs.UpdateTag then fs:UpdateTag() end
        else
            fs:Hide()
        end
    end
    local name = t.left
    name:SetFont(Chrome.FONT, 10, "")
    name:SetShadowOffset(1, -1)
    name:SetShadowColor(0, 0, 0, 1)
    ns:TextColor(name, NAME_GOLD)
    name:SetWidth(L.name.w)
    name:SetJustifyH(L.name.justify or "CENTER")
    at(name, self, L.name)
    if UF.NameTag then UF:NameTag(name, false, L.name.w, self.wuiOverlay) end
    retag(name, "[name]")

    local numFont = (ns.Core.Client and ns.Core.Client.isTBC) and "Fonts\\ARIALN.TTF" or Chrome.FONT
    for slot, place in pairs({ right = L.healthText, power = L.powerText }) do
        local fs = t[slot]
        local td = d and d.texts and d.texts[slot]
        if place and (slot == "right" or (td and td.enable)) then
            fs:SetFont(numFont, place.size or 10, "OUTLINE")
            ns:TextColor(fs, { 1, 1, 1 })
            fs:SetWidth(0)
            fs:SetJustifyH("CENTER")
            at(fs, self, place)
            retag(fs, slot == "right" and "[wui:curmax]" or "[wui:curpp]")
        else
            retag(fs, nil)
        end
    end
    local lv = self.wuiGameLevel
    if lv then
        if L.level.white then
            lv:SetFont(Chrome.FONT, 14, "")
        else
            lv:SetFont(Chrome.FONT, 10, "")
        end
        lv:SetShadowOffset(1, -1)
        lv:SetShadowColor(0, 0, 0, 1)
        if L.level.gold then lv:SetTextColor(1, 0.82, 0) else lv:SetTextColor(1, 1, 1) end
        at(lv, self, L.level)
        if self.wuiKey == "player" then retag(lv, "[wui:levelplain]") else retag(lv, "[wui:gamelevel]") end
    end

    -- Icons where the game has them, in its art.
    local icons = self.wuiIcons
    local function icon(tex, p)
        if not (tex and p) then return end
        tex:ClearAllPoints()
        tex:SetSize(p.w or p.s, p.h or p.s)
        at(tex, self, p)
        if p.atlas then tex:SetAtlas(p.atlas)
        elseif p.file then
            tex:SetTexture(p.file)
            if p.coords then tex:SetTexCoord(unpack(p.coords)) end
        end
    end
    icon(icons.leader, L.leader)
    icon(icons.assistant, L.leader)
    icon(icons.combat, L.combat)
    icon(icons.resting, L.resting)
    icon(icons.raidIcon, L.raidIcon)

    -- Auras start under the frame, where the game's start.
    if L.auras then
        local y = L.auras.y
        for _, which in ipairs({ "buffs", "debuffs" }) do
            local au = self["wui" .. which]
            local ad = d and d[which]
            if au and ad and ad.enable then
                au:ClearAllPoints()
                au:SetPoint("TOPLEFT", self, "TOPLEFT", L.auras.x, y)
                y = y - ((ad.size or 21) + 4) * math.max(1, ad.rows or 1)
            end
        end
    end

    UF:GameUpdate(self)
end

-- The level as the game writes it: the number in its difficulty colour
-- (nothing for a skull, which the art shows), with no marks for elites,
-- which the dragon shows.
local M, E = ns.oUF.Tags.Methods, ns.oUF.Tags.Events
M["wui:gamelevel"] = function(u)
    local l = plain(UnitEffectiveLevel and UnitEffectiveLevel(u) or UnitLevel(u))
    if not l or l <= 0 then return "??" end
    local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(l)
    if color then
        return ("|cff%02x%02x%02x%d|r"):format(color.r * 255, color.g * 255, color.b * 255, l)
    end
    return tostring(l)
end
E["wui:gamelevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP"
