-- Wick's UI
-- Modules/Nameplates/Classic.lua: the nameplates in the game's own shape.
--
-- The Classic look draws each plate as the game draws its own, from each
-- client's nameplate source:
--   TBC Anniversary, the Classic style: the bar in the game's nameplate
--   border with the level in its box at the right end, the name above in
--   white, and the cast bar in its own border with the spell's icon in a
--   box at the left.
--   Forever, the Thin style: a slim bar on its dark backing with the level
--   on a badge beside it, a yellow outline round the target and a shade on
--   the rest, and the cast bar a thin line with the icon and spell under it.
-- Health is in the game's colours: the unit's reaction, grey when it is
-- someone else's to kill or offline. What Wick's UI adds stays: your
-- threat as a percent, quest marks, hit numbers, your debuffs on it,
-- friendly plates as names only. Sizes are the game's, whatever the plate
-- settings say.

local ADDON, ns = ...

local NP = ns.Nameplates
local Chrome = ns.Core.Chrome
local issecret = rawget(_G, "issecretvalue")
local function plain(v) if issecret and issecret(v) then return nil end return v end

local function tbc() return ns.Core.Client and ns.Core.Client.isTBC end

local TF = "Interface\\TargetingFrame\\"
local TT = "Interface\\Tooltips\\"

-- ============================================================
-- Layouts
-- ============================================================
-- Offsets are from the health bar, which the plate centres.
local TBC = {
    health = { w = 103.75, h = 10, fill = TF .. "UI-TargetingFrame-BarFill" },
    -- The border is centred on the bar's container, 8.625 right of the bar's
    -- own centre (the bar sits 3.5 in at the left and 20.75 at the right,
    -- leaving the level's box).
    border = { file = TT .. "Nameplate-Border", w = 128, h = 16, x = 8.625 },
    level = { x = 61.625, size = 10 },
    name = { x = 8.625, y = 4, size = 10 },
    cast = { w = 103.75, h = 10, x = 17.25, y = -4, fill = TF .. "UI-StatusBar",
        border = { file = TT .. "Nameplate-Border-Castbar", w = 128, h = 16, x = -8.625 },
        icon = { s = 14, x = -9.25 }, text = 10,
        shield = "Interface\\CastingBar\\UI-CastingBar-Small-Shield" },
    raid = { s = 22, x = -3.5 },
    highlight = true,
}
local FOREVER = {
    health = { w = 97.1, h = 10.4, atlas = "UI-HUD-CoolDownManager-Bar",
        bg = { atlas = "UI-HUD-CoolDownManager-Bar-BG", l = -2, t = 3, r = 6, b = -6 } },
    badge = { atlas = "ui-hud-nameplates-levelindicator", w = 22.4, h = 12.8, gap = 5, size = 8,
        ring = "ui-hud-nameplates-levelindicator-rectangle-selected" },
    name = { y = 1.6, size = 11, outline = "OUTLINE" },
    cast = { w = 124.5, h = 4.8, y = -1.6,
        atlas = { cast = "ui-castingbar-filling-standard", channel = "ui-castingbar-filling-channel" },
        bg = "ui-castingbar-background", icon = { s = 8 }, text = 8,
        shieldAtlas = "nameplates-InterruptShield" },
    raid = { s = 22, x = 0 },
    selected = { atlas = "UI-HUD-CoolDownManager-Selected-yellow", l = -3, t = 2, r = 0, b = 2 },
    deselected = "ui-hud-nameplates-deselected-overlay",
    focus = { 1, 0.49, 0.039 },
}

function NP:GameLayout()
    if not ns:Game() then return nil end
    return tbc() and TBC or FOREVER
end

-- ============================================================
-- Debuffs on the plate, as the game draws its own
-- ============================================================
-- 25 square at the game's own plate size (TBC Anniversary's Medium plates),
-- three quarters of that on Forever's Small ones.
function NP:GameAuraSize()
    if not ns:Game() then return nil end
    return tbc() and 25 or 19
end

-- The game's aura art on a button the client's container made: the icon
-- in its rounded mask, the ring over it, the cooldown's own sweep, the
-- count at the corner in the game's number font. Method calls on the
-- button only; nothing is written into it.
function NP:GameAura(button, size)
    -- A button the client makes mid-fight is locked until it is over.
    if InCombatLockdown() then
        ns:AfterCombat("gameaura:" .. tostring(button), function() NP:GameAura(button, size) end)
        return
    end
    local k = (size or 25) / 25
    local icon = button.Icon
    if icon and button.CreateMaskTexture and icon.AddMaskTexture then
        local m = button:CreateMaskTexture()
        m:SetAtlas("UI-HUD-CoolDownManager-Mask")
        m:SetAllPoints(icon)
        icon:AddMaskTexture(m)
    end
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    ring:SetPoint("TOPLEFT", button, "TOPLEFT", -6 * k, 5 * k)
    ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6 * k, -5 * k)
    local cd = button.Cooldown
    if cd and cd.SetSwipeTexture then
        pcall(cd.SetSwipeTexture, cd, "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe")
        if cd.SetReverse then cd:SetReverse(true) end
    end
    local count = button.Count
    if count and count.SetFont then
        count:SetFont("Fonts\\ARIALN.TTF", math.max(9, math.floor(12 * k + 0.5)), "OUTLINE")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3 * k, -2 * k)
    end
    -- The time is the cooldown's own countdown, as on the game's plates
    -- (ours is switched off on the row: showDuration), set a little
    -- smaller than the client draws it, so it sits inside the icon.
    if button.Time and button.Time.Hide then button.Time:Hide() end
    local fs = cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs and fs.SetFont then
        fs:SetFont("Fonts\\ARIALN.TTF", math.max(8, math.floor((size or 25) * 0.45 + 0.5)), "OUTLINE")
    end
end

-- ============================================================
-- Colours
-- ============================================================
-- The game's: the unit's reaction (its own colour for it), grey for a mob
-- someone else has tapped or a unit offline.
local function gameHealthColor(h, unit)
    if not unit then return end
    if plain(UnitIsConnected(unit)) == false then h:SetStatusBarColor(0.5, 0.5, 0.5) return end
    if not plain(UnitPlayerControlled(unit)) and plain(UnitIsTapDenied(unit)) then
        h:SetStatusBarColor(0.9, 0.9, 0.9)
        return
    end
    local r, g, b = UnitSelectionColor(unit, not tbc())
    r, g, b = plain(r), plain(g), plain(b)
    if r and g and b then h:SetStatusBarColor(r, g, b) end
end

-- ============================================================
-- Building, once a plate is made
-- ============================================================
function NP:GameStyle(self)
    local L = NP:GameLayout()
    if not L then return end
    self.wuiGameNP = L
    local h, cb = self.Health, self.wuiCastbar
    -- Wick's own pieces stand down: the bordered card, its glows, the
    -- pointers and the elite diamond; the game marks a target its own way.
    if h.backdrop then h.backdrop:Hide() end
    local cbd = ns:BackdropOf(cb)
    if cbd then cbd:Hide() end
    if ns.statusbars then ns.statusbars[h] = nil; ns.statusbars[cb] = nil end
    h.PostUpdateColor = gameHealthColor
    h.colorTapping, h.colorDisconnected = true, true

    local overlay = CreateFrame("Frame", nil, self)
    overlay:SetAllPoints(h)
    overlay:SetFrameLevel(h:GetFrameLevel() + 4)
    self.wuiGameOverlay = overlay

    if L == TBC then
        h:SetStatusBarTexture(L.health.fill)
        local border = overlay:CreateTexture(nil, "ARTWORK", nil, 1)
        border:SetTexture(L.border.file)
        border:SetTexCoord(0, 1, 0.5, 1)
        self.wuiGameBorder = border
        -- The target's bar, lit as the game lights it.
        local hl = h:CreateTexture(nil, "ARTWORK", nil, 3)
        hl:SetTexture(L.health.fill)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.25)
        hl:SetAllPoints(h:GetStatusBarTexture())
        hl:Hide()
        self.wuiGameHighlight = hl
        cb:SetStatusBarTexture(L.cast.fill)
        local cborder = cb:CreateTexture(nil, "OVERLAY", nil, -1)
        cborder:SetTexture(L.cast.border.file)
        cborder:SetTexCoord(0, 1, 0.5, 1)
        self.wuiGameCastBorder = cborder
        local shield = cb:CreateTexture(nil, "OVERLAY", nil, 1)
        shield:SetTexture(L.cast.shield)
        shield:SetAlpha(0)
        cb.wuiGameShield = shield
    else
        h:SetStatusBarTexture(L.health.atlas)
        local bg = h:CreateTexture(nil, "BACKGROUND", nil, -2)
        bg:SetAtlas(L.health.bg.atlas)
        self.wuiGameBG = bg
        local sel = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
        sel:SetAtlas(L.selected.atlas)
        sel:Hide()
        self.wuiGameSelected = sel
        local shade = overlay:CreateTexture(nil, "ARTWORK", nil, 1)
        shade:SetAtlas(L.deselected)
        shade:Hide()
        self.wuiGameShade = shade
        local badge = CreateFrame("Frame", nil, overlay)
        local bt = badge:CreateTexture(nil, "BACKGROUND")
        bt:SetAtlas(L.badge.atlas)
        bt:SetAllPoints()
        local ring = badge:CreateTexture(nil, "OVERLAY")
        ring:SetAtlas(L.badge.ring)
        ring:SetPoint("TOPLEFT", -3, 4)
        ring:SetPoint("BOTTOMRIGHT", 3, -4)
        ring:Hide()
        badge.ring = ring
        self.wuiGameBadge = badge
        cb:SetStatusBarTexture(L.cast.atlas.cast)
        local cbg = cb:CreateTexture(nil, "BACKGROUND", nil, -2)
        cbg:SetAtlas(L.cast.bg)
        cbg:SetPoint("TOPLEFT", -1, 0)
        cbg:SetPoint("BOTTOMRIGHT", 1, 0)
        local shield = cb:CreateTexture(nil, "OVERLAY", nil, 1)
        shield:SetAtlas(L.cast.shieldAtlas)
        shield:SetAlpha(0)
        cb.wuiGameShield = shield
    end
    -- Our dark tracks: the game's black under the TBC bars, at half; none
    -- under Forever's, whose backing is its art.
    for _, t in ipairs({ h.wuiTrack, cb.wuiTrack }) do
        if t then
            if L == TBC then
                t:SetTexture("Interface\\Buttons\\WHITE8X8")
                t:SetVertexColor(0, 0, 0, 0.5)
            else
                t:Hide()
            end
        end
    end

    -- The level, on its own string.
    self.wuiGameLevel = (self.wuiGameBadge or overlay):CreateFontString(nil, "OVERLAY")

    -- The cast bar: its fill coloured as the game's (a cast filling gold, a
    -- channel green), its shield over a cast you cannot interrupt. Whether
    -- one can be is a secret the client applies; it is never read here.
    cb.PostCastStart = function(el, _, _, flag)
        if el.wuiGameShield and el.wuiGameShield.SetAlphaFromBoolean then el.wuiGameShield:SetAlphaFromBoolean(flag, 1, 0) end
        if L == TBC then
            if el.channeling then el:SetStatusBarColor(0, 1, 0, 1) else el:SetStatusBarColor(1, 0.702, 0, 1) end
        else
            el:SetStatusBarTexture(el.channeling and L.cast.atlas.channel or L.cast.atlas.cast)
            el:SetStatusBarColor(1, 1, 1, 1)
        end
    end
    cb.PostCastInterruptible = function(el, _, _, flag)
        if el.wuiGameShield and el.wuiGameShield.SetAlphaFromBoolean then el.wuiGameShield:SetAlphaFromBoolean(flag, 1, 0) end
    end
end

-- ============================================================
-- Sizes and places, every Configure
-- ============================================================
function NP:ConfigureGame(self)
    local L = self.wuiGameNP
    if not L then return end
    local h, cb = self.Health, self.wuiCastbar
    h:SetSize(L.health.w, L.health.h)
    h.colorClass, h.colorReaction, h.colorHealth = false, false, true
    if h.SetColorThreat and h.__owner then h:SetColorThreat(false) else h.colorThreat = false end

    local name, lv = self.wuiName, self.wuiGameLevel
    local face = Chrome.FONT
    if L == TBC then
        local b = self.wuiGameBorder
        b:SetSize(L.border.w, L.border.h)
        b:ClearAllPoints()
        b:SetPoint("CENTER", h, "CENTER", L.border.x, 0)
        lv:SetFont(face, L.level.size, "OUTLINE")
        lv:ClearAllPoints()
        lv:SetPoint("CENTER", h, "CENTER", L.level.x, 0)
        name:SetFont(face, L.name.size, "")
        -- Cast bar under the bar, in its border, the icon in the border's box.
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", h, "BOTTOMLEFT", L.cast.x, L.cast.y)
        cb:SetSize(L.cast.w, L.cast.h)
        local cbr = self.wuiGameCastBorder
        cbr:SetSize(L.cast.border.w, L.cast.border.h)
        cbr:ClearAllPoints()
        cbr:SetPoint("CENTER", cb, "CENTER", L.cast.border.x, 0)
        local ih = cb.wuiIconHolder
        ih:ClearAllPoints()
        ih:SetSize(L.cast.icon.s, L.cast.icon.s)
        ih:SetPoint("CENTER", cb, "LEFT", L.cast.icon.x, 0)
        cb.wuiGameShield:ClearAllPoints()
        cb.wuiGameShield:SetPoint("TOPLEFT", cb, "TOPLEFT", -20, 11)
        cb.wuiGameShield:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", 13, -13)
        cb.Text:ClearAllPoints()
        cb.Text:SetPoint("CENTER", cb, "CENTER", 0, -1)
        cb.Text:SetFont(face, L.cast.text, "OUTLINE")
        cb.Text:SetJustifyH("CENTER")
    else
        local bg = self.wuiGameBG
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", h, "TOPLEFT", L.health.bg.l, L.health.bg.t)
        bg:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", L.health.bg.r, L.health.bg.b)
        local sel = self.wuiGameSelected
        sel:ClearAllPoints()
        sel:SetPoint("TOPLEFT", bg, "TOPLEFT", L.selected.l, L.selected.t)
        sel:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", L.selected.r, L.selected.b)
        local shade = self.wuiGameShade
        shade:ClearAllPoints()
        shade:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 1)
        shade:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, -1)
        local badge = self.wuiGameBadge
        badge:SetSize(L.badge.w, L.badge.h)
        badge:ClearAllPoints()
        badge:SetPoint("LEFT", h, "RIGHT", L.badge.gap, 0)
        lv:SetFont(face, L.badge.size, "")
        lv:ClearAllPoints()
        lv:SetPoint("CENTER", badge, "CENTER", 0, 0)
        name:SetFont(face, L.name.size, L.name.outline)
        -- The thin cast line under the bar, the icon and spell under it.
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, L.cast.y)
        cb:SetSize(L.cast.w, L.cast.h)
        local ih = cb.wuiIconHolder
        ih:ClearAllPoints()
        ih:SetSize(L.cast.icon.s, L.cast.icon.s)
        ih:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, 0)
        cb.wuiGameShield:ClearAllPoints()
        cb.wuiGameShield:SetSize(8, 9.6)
        cb.wuiGameShield:SetPoint("RIGHT", ih, "RIGHT", 0, 0)
        cb.Text:ClearAllPoints()
        cb.Text:SetPoint("LEFT", ih, "RIGHT", 2, 0)
        cb.Text:SetFont(face, L.cast.text, "OUTLINE")
        cb.Text:SetJustifyH("LEFT")
    end
    name:SetShadowOffset(0, 0)
    ns:TextColor(name, { 1, 1, 1 })
    -- The spell's icon fills its box; Wick's tile round it stands down.
    local ih = cb.wuiIconHolder
    if ih.wuiBG then ih.wuiBG:SetAlpha(0) end
    ns:SetBorderColor(ih, { 0, 0, 0 }, 0)
    cb.Icon:ClearAllPoints()
    cb.Icon:SetAllPoints(ih)
    cb.Icon:SetTexCoord(0, 1, 0, 1)
    ih:SetShown(true)
    cb.Time:Hide()
    if cb.wuiLockHolder then cb.wuiLockHolder:Hide() end

    -- The name in white with no level in it; the level on its own string.
    if self.wuiNameTag then self:Untag(name) end
    self.wuiNameTag = "[name]"
    self:Tag(name, self.wuiNameTag)
    if lv.wuiTagged then self:Untag(lv) end
    self:Tag(lv, "[wui:gamelevel]")
    lv.wuiTagged = true

    -- Your debuffs in a row from the bar's left end, straight above the name.
    if self.wuiDebuffs then
        local above = (L == TBC and L.name.y or FOREVER.name.y) + ((L == TBC and L.name.size) or FOREVER.name.size) + 1
        self.wuiDebuffs:ClearAllPoints()
        self.wuiDebuffs:SetPoint("BOTTOMLEFT", h, "TOPLEFT", L == TBC and -3.5 or 0, above)
    end

    -- The raid mark to the bar's left, as the game puts it.
    local raid = self.RaidTargetIndicator
    if raid then
        raid:SetSize(L.raid.s, L.raid.s)
        raid:ClearAllPoints()
        raid:SetPoint("RIGHT", h, "LEFT", L.raid.x, 0)
    end
    -- The quest mark past the level's box.
    local quest = self.QuestIndicator
    if quest then
        quest:ClearAllPoints()
        if L == TBC then
            quest:SetPoint("LEFT", self.wuiGameBorder, "RIGHT", 2, 0)
        else
            quest:SetPoint("LEFT", self.wuiGameBadge, "RIGHT", 3, 0)
        end
    end
end

-- ============================================================
-- With the unit: the target's marks, the shade, the name's place
-- ============================================================
function NP:RefreshGame(self, isTarget, isFocus, nameOnly)
    local L = self.wuiGameNP
    if not L then return end
    local d = NP:db()
    -- No pointers, glows or diamond: the game's marks are its own.
    self.wuiMarkL:Hide()
    self.wuiMarkR:Hide()
    if self.wuiTargetGlow then self.wuiTargetGlow:Hide() end
    self.wuiClassMark:Hide()
    self.wuiClassBack:Hide()
    local name, h = self.wuiName, self.Health
    name:ClearAllPoints()
    if nameOnly then
        name:SetPoint("CENTER", self, "CENTER", 0, 0)
    elseif L == TBC then
        name:SetPoint("BOTTOM", h, "TOP", L.name.x, L.name.y)
    else
        name:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, L.name.y)
        name:SetPoint("RIGHT", self.wuiGameBadge, "RIGHT", 0, 0)
    end
    self.wuiGameLevel:SetShown(not nameOnly)
    if self.wuiGameBorder then self.wuiGameBorder:SetShown(not nameOnly) end
    if self.wuiGameHighlight then self.wuiGameHighlight:SetShown(isTarget and not nameOnly) end
    if self.wuiGameBadge then
        self.wuiGameBadge:SetShown(not nameOnly)
        local ring = self.wuiGameBadge.ring
        if isTarget or isFocus then
            local c = isFocus and L.focus or { 1, 1, 1 }
            ring:SetVertexColor(c[1], c[2], c[3], 1)
            ring:Show()
        else
            ring:Hide()
        end
    end
    if self.wuiGameSelected then
        if isTarget or isFocus then
            local c = isFocus and L.focus or { 1, 1, 1 }
            self.wuiGameSelected:SetVertexColor(c[1], c[2], c[3], 1)
        end
        self.wuiGameSelected:SetShown((isTarget or isFocus) and not nameOnly)
        self.wuiGameShade:SetShown(not (isTarget or isFocus) and not nameOnly)
    end
    -- The client scales and fades plates itself; ours only takes the
    -- player's own opacity.
    self:SetAlpha(d.plateAlpha or 1)
    h:SetScale(1)
end
