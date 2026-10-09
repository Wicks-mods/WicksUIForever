-- Wick's UI
-- Modules/ActionBars/Pad.lua: the game's controller bars, in the look.
--
-- On the controller (see Core/Pad.lua) Wick's bars stand aside and the
-- game's controller bars take the bottom of the screen. Two things here:
--
-- The relay. Wick's UI switches off the game's action button event relay
-- (ActionBarActionEventsFrame) when it replaces the game's bars. The
-- controller bars are built from the same buttons and need it for their
-- casts, charges and glows, so it listens again while the controller is
-- in use, and goes quiet again on the mouse and keyboard.
--
-- The skin. Each controller button loses the game's ring, drop shadow and
-- border for a tile in the look: square on the D-pad side, round on the
-- face buttons, as the game shapes them. The marks that say which
-- controller button fires what stay, as do the chosen ring (tinted to the
-- accent), the cooldown and the glows. The ornate shoulder and stance
-- backings go. Method calls on the game's regions and frames of our own
-- only; nothing is written into the game's frames. The Classic look keeps
-- the game's art.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local AB = ns.ActionBars
local Pad = ns.Pad

local PadBars = {}
ns.PadBars = PadBars

-- ============================================================
-- The relay
-- ============================================================
-- The events ActionBarActionEventsFrame registers for itself (its OnLoad).
local RELAY = { "SPELL_UPDATE_CHARGES", "UPDATE_INVENTORY_ALERTS", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "ARCHAEOLOGY_CLOSED", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL",
    "STOP_AUTOREPEAT_SPELL", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "COMPANION_UPDATE",
    "UNIT_INVENTORY_CHANGED", "UNIT_SPELLCAST_SENT", "LEARNED_SPELL_IN_SKILL_LINE", "PET_STABLE_UPDATE",
    "PET_STABLE_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "UPDATE_SUMMONPETS_ACTION", "SPELL_UPDATE_ICON" }
local RELAY_PLAYER = { "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_RETICLE_TARGET", "UNIT_SPELLCAST_RETICLE_CLEAR", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" }

function PadBars:Relay(on)
    local f = rawget(_G, "ActionBarActionEventsFrame")
    if not (f and f.RegisterEvent) then return end
    if on then
        for _, e in ipairs(RELAY) do pcall(f.RegisterEvent, f, e) end
        for _, e in ipairs(RELAY_PLAYER) do pcall(f.RegisterUnitEvent, f, e, "player") end
    else
        f:UnregisterAllEvents()
    end
    self.relaying = on
end

-- ============================================================
-- The skin
-- ============================================================
local tiles = setmetatable({}, { __mode = "k" })     -- ours, by the game's button
local CIRCLE = "Interface\\Masks\\CircleMaskScalable"
local FADE = { "Border", "CircleShadow", "SquareShadow", "CircleShadowFocus", "SquareShadowFocus" }
local BAR_ART = { "LeftButtonFrame", "RightButtonFrame", "BackgroundWatermark" }
local PAGE_ART = { "LeftShoulderBackground", "RightShoulderBackground" }

local function off(t)
    if t and t.GetAlpha and t:GetAlpha() > 0 then t:SetAlpha(0) end
end

local function isButton(f)
    local kind = f.GetObjectType and f:GetObjectType()
    return (kind == "CheckButton" or kind == "Button") and f.icon ~= nil and (f.CircleMask ~= nil or f.SlotArt ~= nil)
end

-- The buttons and bars under the controller frame, looked for again now
-- and then: the possess and stance bars come and go.
local function collect(f, depth, buttons, bars)
    if depth > 7 or not f.GetChildren then return end
    for _, c in ipairs({ f:GetChildren() }) do
        if isButton(c) then
            buttons[#buttons + 1] = c
        else
            if c.LeftButtonFrame or c.BackgroundWatermark then bars[#bars + 1] = c end
            collect(c, depth + 1, buttons, bars)
        end
    end
end

-- A round tile: a disc in the border colour with a smaller one in the
-- panel colour on it, under the game's round icon.
local function disc(tile, layer, sub, inset, token)
    local t = tile:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(CIRCLE)
    t:SetPoint("TOPLEFT", inset, -inset)
    t:SetPoint("BOTTOMRIGHT", -inset, inset)
    local c = C[token]
    t:SetVertexColor(c[1], c[2], c[3], 1)
    Chrome:Register(t, token, "vertex", 1)
    return t
end

function PadBars.TileOf(b) return tiles[b] end

local function tileFor(b)
    local e = tiles[b]
    if e then return e end
    e = {}
    local square = CreateFrame("Frame", nil, b)
    square:SetPoint("TOPLEFT", -2, 2)
    square:SetPoint("BOTTOMRIGHT", 2, -2)
    square:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    ns:SetTemplate(square, "Default", { shadow = false })
    e.square = square
    local round = CreateFrame("Frame", nil, b)
    round:SetPoint("TOPLEFT", -2, 2)
    round:SetPoint("BOTTOMRIGHT", 2, -2)
    round:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    e.ring = disc(round, "BACKGROUND", 1, 0, "border")
    e.fill = disc(round, "BACKGROUND", 2, 1.5, "void")
    e.round = round
    for _, k in ipairs({ "Count", "Name" }) do
        local fs = b[k]
        if fs and fs.SetFont then ns.Media:SetFont(fs, k == "Count" and 13 or 10, "look") end
    end
    tiles[b] = e
    return e
end

local function skinButton(b)
    local e = tileFor(b)
    for _, k in ipairs(FADE) do off(b[k]) end
    off(b.GetNormalTexture and b:GetNormalTexture())
    off(b.GetPushedTexture and b:GetPushedTexture())
    off(b.GetHighlightTexture and b:GetHighlightTexture())
    -- The chosen ring stays (a stance, auto attack), in the accent.
    local checked = b.GetCheckedTexture and b:GetCheckedTexture()
    if checked and not e.checked then
        e.checked = true
        checked:SetDesaturated(true)
        checked:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(checked, "fel", "vertex", 1)
    end
    -- The game shapes each button as its style says; the tile follows.
    local round = b.CircleMask and b.CircleMask.IsShown and b.CircleMask:IsShown() or false
    e.square:SetShown(not round)
    e.round:SetShown(round)
end

function PadBars:Skin()
    local root = Pad:Bars()
    if not root then return end
    local now = GetTime()
    if not self.buttons or now - (self.scanned or 0) > 2 then
        self.buttons, self.bars = {}, {}
        collect(root, 1, self.buttons, self.bars)
        self.scanned = now
    end
    for _, b in ipairs(self.buttons) do skinButton(b) end
    for _, bar in ipairs(self.bars) do
        for _, k in ipairs(BAR_ART) do off(bar[k]) end
    end
    local page = root.PageUnit
    if page then for _, k in ipairs(PAGE_ART) do off(page[k]) end end
end

function PadBars:Skinning()
    return Pad:Active() and Pad:Settings().skin ~= false and not ns:Game() and AB.initialized and true or false
end

-- Every frame while the controller bars show: the game moves, sizes and
-- reshapes its buttons as they are pressed and as a bar takes focus.
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    local root = Pad:Bars()
    if not (root and root:IsVisible() and PadBars:Skinning()) then return end
    local ok, err = pcall(PadBars.Skin, PadBars)
    if not ok and not PadBars.failed then
        PadBars.failed = true
        ns.errors = ns.errors or {}
        ns.errors[#ns.errors + 1] = "controller bars: " .. tostring(err)
    end
end)

-- ============================================================
-- Switching
-- ============================================================
local function allBars()
    local out = {}
    for _, bar in pairs(AB.bars or {}) do out[#out + 1] = bar end
    local S = ns.Special
    if S then
        if S.stance then out[#out + 1] = S.stance end
        if S.pet then out[#out + 1] = S.pet end
    end
    return out
end

function PadBars:Changed(on)
    if not AB.initialized then return end
    self:Relay(on)
    -- In a fight the bars cannot be hidden, only faded; the hiding waits.
    if on and Pad:HideBars() and InCombatLockdown() then
        for _, bar in ipairs(allBars()) do bar:SetAlpha(0) end
    end
    AB:Update()
    if ns.Special and ns.Special.Update then ns.Special:Update() end
end

Pad:OnChange(function(on) PadBars:Changed(on) end)
-- Already on the controller when the interface loads.
ns:On("PLAYER_ENTERING_WORLD", function()
    if Pad:Active() and not PadBars.relaying then PadBars:Changed(true) end
end)
