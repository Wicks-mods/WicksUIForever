-- Wick's UI
-- Modules/ActionBars/ActionBars.lua: the action bars.
--
-- Built on LibActionButton-1.0, which owns the secure side: paging,
-- click handling, drag and drop, cooldowns passed through as secrets.
-- This file owns layout, looks, fading, keybinds and the settings.
--
-- Bars map to action pages the way the game numbers them, and each bar
-- answers to the game's own keybinding for that page where there is one.
-- A player's existing binds on the bottom left bar keep working on the
-- bar that shows page 6, and so on, so switching the addon on does not
-- mean binding everything again.

local ADDON, ns = ...

local LAB = ns.LAB
local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local AB = ns:NewModule("actionbars", { title = "Action bars", order = 10 })
ns.ActionBars = AB

-- The bars and the page each one shows. 7 to 10 are the pages the game
-- uses for stances and forms, so they are free for a mage and not for a
-- warrior. 13 to 15 are the three extra pages retail added.
AB.BAR_IDS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }

-- The game's binding for each page, where it has one.
local BIND_PREFIX = {
    [1]  = "ACTIONBUTTON",
    [3]  = "MULTIACTIONBAR3BUTTON",   -- right bar
    [4]  = "MULTIACTIONBAR4BUTTON",   -- right bar 2
    [5]  = "MULTIACTIONBAR2BUTTON",   -- bottom right
    [6]  = "MULTIACTIONBAR1BUTTON",   -- bottom left
    [13] = "MULTIACTIONBAR5BUTTON",
    [14] = "MULTIACTIONBAR6BUTTON",
    [15] = "MULTIACTIONBAR7BUTTON",
}
local function bindPrefix(id) return BIND_PREFIX[id] or ("WICKSUIBAR" .. id .. "BUTTON") end
AB.bindPrefix = bindPrefix

-- Binding names for the bars the game has no binding for.
_G.BINDING_HEADER_WICKSUI = "Wick's UI"
for _, id in ipairs({ 2, 7, 8, 9, 10 }) do
    for i = 1, 12 do
        _G["BINDING_NAME_WICKSUIBAR" .. id .. "BUTTON" .. i] = ("Bar %d button %d"):format(id, i)
    end
end

-- ============================================================
-- Paging
-- ============================================================
local function barIndex(fnName, fallback)
    local ab = rawget(_G, "C_ActionBar")
    local fn = (ab and ab[fnName]) or rawget(_G, fnName)
    local ok, v = pcall(function() return fn and fn() end)
    if ok and type(v) == "number" and v > 0 then return v end
    return fallback
end

AB.VEHICLE_PAGE  = barIndex("GetVehicleBarIndex", 12)
AB.OVERRIDE_PAGE = barIndex("GetOverrideBarIndex", 14)
AB.SHAPE_PAGE    = barIndex("GetTempShapeshiftBarIndex", 13)

-- Stances and forms move the main bar to their own page.
AB.CLASS_PAGING = {
    WARRIOR = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;",
    DRUID   = "[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 8; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;",
    ROGUE   = "[bonusbar:1] 7;",
    PRIEST  = "[bonusbar:1] 7;",
}

function AB:DefaultPaging(id)
    if id ~= 1 then return tostring(id) end
    return ("[overridebar] %d; [vehicleui][possessbar] %d; [shapeshift] %d; %s [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1")
        :format(self.OVERRIDE_PAGE, self.VEHICLE_PAGE, self.SHAPE_PAGE, self.CLASS_PAGING[ns.myClass] or "")
end

-- The main bar keeps showing in a vehicle, since that is where the
-- vehicle's own buttons go. Every other bar steps aside.
local VIS_MAIN  = "show"
local VIS_OTHER = "[overridebar][vehicleui][possessbar] hide; show"
AB.VIS_MAIN, AB.VIS_OTHER = VIS_MAIN, VIS_OTHER

-- ============================================================
-- Defaults
-- ============================================================
local function barDefaults(id, o)
    local d = {
        enable       = false,
        buttons      = 12,
        perRow       = 12,
        size         = 34,
        keepRatio    = true,
        height       = 34,
        spacing      = 2,
        padding      = 2,
        backdrop     = false,
        growth       = "BOTTOMLEFT",    -- the corner the first button sits in
        alpha        = 1,
        mouseover    = false,
        mouseoverAlpha = 0,
        globalFade   = false,
        showGrid     = false,
        showHotkey   = true,
        showMacro    = true,
        showCount    = true,
        flyout       = "UP",
        visibility   = id == 1 and VIS_MAIN or VIS_OTHER,
        paging       = nil,             -- nil means the default for the bar
        point        = nil,
    }
    for k, v in pairs(o or {}) do d[k] = v end
    return d
end

local defaults = {
    enable = true,
    -- Playing on a controller (Core/Pad.lua, Pad.lua here).
    pad = { hideBars = true, skin = true, clearFrames = true, kitsTop = true },
    -- Text on buttons
    font          = "Wick",
    hotkeySize    = 12,
    macroSize     = 10,
    countSize     = 14,
    fontOutline   = "OUTLINE",
    hotkeyColor   = nil,        -- nil: the look's text colour
    colorsMigrated = false,
    abbreviate    = true,       -- SHIFT-5 becomes S5, Mouse Button 4 becomes M4
    -- Behaviour
    rangeColoring = "button",   -- button, hotkey or none
    rangeColor    = { 0.85, 0.20, 0.20, 1 },
    manaColor     = { 0.35, 0.45, 1.00, 1 },
    tooltips      = "enabled",  -- enabled, nocombat, disabled
    cooldownText  = true,
    lockBars      = true,       -- the game's own Lock Action Bars
    keyDown       = true,       -- cast on key down, the game's own setting
    autoRank      = true,       -- a newly learned rank replaces the older ones on the bars
    procGlow      = true,
    matchedGame   = false,      -- set once the bars have been matched to the game's
    -- Fade
    fadeAlpha     = 0,          -- alpha of bars that follow the global fade
    fadeIn        = "combat,target,casting,mouseover",
    bars = {
        [1]  = barDefaults(1,  { enable = true, point = "BOTTOM,UIParent,BOTTOM,0,40" }),
        [2]  = barDefaults(2,  { enable = true, point = "BOTTOM,UIParent,BOTTOM,0,76" }),
        [3]  = barDefaults(3,  { enable = true, perRow = 1, growth = "TOPRIGHT", point = "RIGHT,UIParent,RIGHT,-4,0" }),
        [4]  = barDefaults(4,  { enable = false, perRow = 1, growth = "TOPRIGHT", point = "RIGHT,UIParent,RIGHT,-40,0" }),
        [5]  = barDefaults(5,  { enable = true, perRow = 6, point = "BOTTOMRIGHT,UIParent,BOTTOM,-222,28" }),
        [6]  = barDefaults(6,  { enable = true, perRow = 6, point = "BOTTOMLEFT,UIParent,BOTTOM,222,28" }),
        [7]  = barDefaults(7,  { point = "BOTTOM,UIParent,BOTTOM,0,112" }),
        [8]  = barDefaults(8,  { point = "BOTTOM,UIParent,BOTTOM,0,148" }),
        [9]  = barDefaults(9,  { point = "BOTTOM,UIParent,BOTTOM,0,184" }),
        [10] = barDefaults(10, { point = "BOTTOM,UIParent,BOTTOM,0,220" }),
        [13] = barDefaults(13, { point = "LEFT,UIParent,LEFT,4,0", perRow = 1, growth = "TOPLEFT" }),
        [14] = barDefaults(14, { point = "LEFT,UIParent,LEFT,40,0", perRow = 1, growth = "TOPLEFT" }),
        [15] = barDefaults(15, { point = "LEFT,UIParent,LEFT,76,0", perRow = 1, growth = "TOPLEFT" }),
    },
}
ns.defaults.profile.actionbars = defaults
AB.barDefaults = barDefaults

-- ============================================================
-- Hiding the game's bars
-- ============================================================
local BLIZZARD_BARS = {
    "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7",
    "StanceBar", "PetActionBar", "PossessActionBar", "OverrideActionBar",
    "MainMenuBarArtFrame", "MainActionBarArtFrame",
}

function AB:DisableBlizzard()
    for _, name in ipairs(BLIZZARD_BARS) do
        local f = _G[name]
        if f then ns:Kill(f, { roleset = false }) end
    end
    -- The controller drives paging for the bars we just removed. It keeps
    -- the two events the extra action button needs, and nothing else.
    local ctrl = _G.ActionBarController
    if ctrl and ctrl.UnregisterAllEvents then
        ctrl:UnregisterAllEvents()
        pcall(ctrl.RegisterEvent, ctrl, "SETTINGS_LOADED")
        pcall(ctrl.RegisterEvent, ctrl, "UPDATE_EXTRA_ACTIONBAR")
    end
    local events = _G.ActionBarActionEventsFrame
    if events and events.UnregisterAllEvents then events:UnregisterAllEvents() end
end

-- ============================================================
-- Fading
-- ============================================================
-- Bars that follow the global fade are parented to one frame whose alpha
-- changes. Alpha is not protected, so this works in combat, which is the
-- whole point of it.
local fader = CreateFrame("Frame", "WicksUIActionBarFader", UIParent)
fader:SetAllPoints()
AB.fader = fader

local fadeReasons = {}
local function fadeTarget()
    for _ in pairs(fadeReasons) do return 1 end
    return AB:db().fadeAlpha or 0
end

local function fadeTo(frame, to, dur)
    frame.wuiFadeTo = to
    local from = frame:GetAlpha()
    if math.abs(from - to) < 0.01 then frame:SetAlpha(to) return end
    frame.wuiFadeFrom, frame.wuiFadeStart, frame.wuiFadeDur = from, GetTime(), dur or 0.2
    frame:SetScript("OnUpdate", function(self)
        local t = (GetTime() - self.wuiFadeStart) / self.wuiFadeDur
        if t >= 1 then
            self:SetAlpha(self.wuiFadeTo)
            self:SetScript("OnUpdate", nil)
        else
            self:SetAlpha(self.wuiFadeFrom + (self.wuiFadeTo - self.wuiFadeFrom) * t)
        end
    end)
end
AB.FadeTo = fadeTo

function AB:SetFadeReason(reason, on)
    fadeReasons[reason] = on or nil
    fadeTo(fader, fadeTarget(), on and 0.15 or 0.4)
end

local function fadeWants(reason)
    local list = AB:db().fadeIn or ""
    list = "," .. list:gsub("%s", "") .. ","
    return list:find("," .. reason .. ",", 1, true) ~= nil
end

local function evalFade()
    if not fadeWants("combat") then fadeReasons.combat = nil else fadeReasons.combat = UnitAffectingCombat("player") or nil end
    if not fadeWants("target") then fadeReasons.target = nil else fadeReasons.target = UnitExists("target") or nil end
    if not fadeWants("focus") then fadeReasons.focus = nil else fadeReasons.focus = UnitExists("focus") or nil end
    if not fadeWants("casting") then fadeReasons.casting = nil else
        fadeReasons.casting = (UnitCastingInfo("player") or UnitChannelInfo("player")) and true or nil
    end
    fadeTo(fader, fadeTarget(), 0.25)
end
AB.EvalFade = evalFade

-- ============================================================
-- Buttons
-- ============================================================
local BLANK = "Interface\\Buttons\\WHITE8X8"

local function abbreviate(text)
    if not text or text == "" or text == RANGE_INDICATOR then return text end
    local t = text:upper()
    t = t:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A"):gsub("META%-", "M")
    t = t:gsub("MOUSE BUTTON ", "M"):gsub("MIDDLE MOUSE", "M3"):gsub("BUTTON", "M")
    t = t:gsub("MOUSE WHEEL UP", "WU"):gsub("MOUSE WHEEL DOWN", "WD"):gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
    t = t:gsub("NUM PAD ", "N"):gsub("NUMPAD", "N"):gsub("PAGE UP", "PU"):gsub("PAGE DOWN", "PD")
    t = t:gsub("SPACEBAR", "SP"):gsub("SPACE", "SP"):gsub("BACKSPACE", "BS"):gsub("INSERT", "INS")
    t = t:gsub("DELETE", "DEL"):gsub("HOME", "HM"):gsub("CAPSLOCK", "CL"):gsub("CAPS LOCK", "CL")
    return t
end
AB.Abbreviate = abbreviate

-- What every button gets whatever its look: the keybind text through the
-- abbreviation, whoever sets it, and the bar's mouseover fade, which reads
-- whether the pointer is on any button of the bar.
local function buttonHooks(button)
    local hk = button.HotKey
    if hk then
        local busy
        hooksecurefunc(hk, "SetText", function(fs, text)
            if busy or not AB:db().abbreviate then return end
            local short = abbreviate(text)
            if short ~= text then busy = true; fs:SetText(short); busy = false end
        end)
    end
    button:HookScript("OnEnter", function(self) AB:BarEnter(self.header) end)
    button:HookScript("OnLeave", function(self) AB:BarLeave(self.header) end)
end

-- Classic: the template's art is drawn for the template's own size (45 on
-- Forever, 36 on TBC Anniversary), much of it at fixed sizes and offsets,
-- so at any other size the frame ran past the button onto the next one.
-- Each piece is scaled with the button instead: its size and offsets, from
-- what they were when the button was made. Text is left to the bar's own
-- settings, and the icon, which fills the button, needs nothing.
function AB.FitGameArt(button)
    -- WickCore's, shared with the suite's other buttons made from the
    -- game's templates; this copy is for a WickCore without it.
    if Chrome.FitGameArt then
        local fit = Chrome:FitGameArt(button)
        if fit then button.wuiGameArt = fit end
        return
    end
    local w0, h0 = button:GetSize()
    if not (w0 and h0 and w0 > 0 and h0 > 0) or button.wuiGameArt then return end
    local pieces, seen = {}, {}
    local icon = button.icon or button.Icon
    local function take(r)
        if not r or seen[r] or r == icon then return end
        seen[r] = true
        if r.GetObjectType and r:GetObjectType() == "FontString" then return end
        local n = r.GetNumPoints and r:GetNumPoints() or 0
        if n == 0 then return end
        local pts = {}
        for i = 1, n do pts[i] = { r:GetPoint(i) } end
        local w, h = r:GetSize()
        pieces[#pieces + 1] = { r = r, pts = pts, w = w, h = h }
    end
    for _, r in ipairs({ button:GetRegions() }) do take(r) end
    take(button.IconMask)
    for _, c in ipairs({ button:GetChildren() }) do take(c) end
    local function fit()
        local w, h = button:GetSize()
        if not (w and h and w > 0 and h > 0) then return end
        local kx, ky = w / w0, h / h0
        for _, p in ipairs(pieces) do
            local r = p.r
            r:ClearAllPoints()
            for _, pt in ipairs(p.pts) do r:SetPoint(pt[1], pt[2], pt[3], (pt[4] or 0) * kx, (pt[5] or 0) * ky) end
            -- One point: the piece has a size of its own, scaled too. Two
            -- or more stretch it, and the size follows.
            if #p.pts == 1 and p.w and p.w > 0 then r:SetSize(p.w * kx, p.h * ky) end
        end
    end
    button.wuiGameArt = fit
    button:HookScript("OnSizeChanged", fit)
end

-- Take the button's art over. Setting MasqueSkinned tells the library not
-- to put its own frame art back on every update.
function AB:StyleButton(button)
    if button.wuiStyled then return end
    button.wuiStyled = true
    button.MasqueSkinned = true
    if ns:Game() then
        -- Classic: the button as the game's own template draws it on this
        -- client, scaled to the bar's size. Marked skinned all the same, so
        -- the library does not lay its art for another client over the
        -- template's.
        AB.FitGameArt(button)
        buttonHooks(button)
        return
    end

    local icon = button.icon or button.Icon
    if button.IconMask and icon.RemoveMaskTexture then icon:RemoveMaskTexture(button.IconMask) end
    -- The library can put Blizzard's mask back as the button updates; that
    -- mask is cut to the old bevelled frame and left a dark edge round the
    -- icon. Given our own rounded shape, it matches ours wherever it lands.
    if button.IconMask and button.IconMask.SetTexture then
        -- Rounded in the modern style, plain square in the crisp one.
        local shape = ns:Modern() and ns.Media.iconmask or ns.Media:Statusbar("Wick Flat")
        button.IconMask:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        button.IconMask:ClearAllPoints()
        button.IconMask:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        button.IconMask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    end
    for _, key in ipairs({ "SlotArt", "SlotBackground", "FloatingBG", "RightDivider", "BottomDivider" }) do
        local t = button[key]
        if t then t:SetAlpha(0); t:Hide() end
    end
    if button.ClearNormalTexture then button:ClearNormalTexture() else button:SetNormalTexture(BLANK); button:GetNormalTexture():SetAlpha(0) end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end

    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    -- In a look with an icon tab (Arena) the icon is drawn shorter under
    -- the tile's shaped top; its masks then cover all of it.
    local tabbed = Chrome.TabIcon and Chrome:TabIcon(icon, button)
    ns:CropIcon(icon, nil, tabbed)
    icon:SetDrawLayer("BACKGROUND", 7)

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(C.void[1], C.void[2], C.void[3], 0.6)
    button.wuiEmpty = bg

    -- The border sits on the button itself, one physical pixel.
    -- Crisp: a border line only. Modern: a rounded glass tile with a lift.
    if ns:Modern() then
        ns:SetTemplate(button, "Default")
        bg:Hide()
    else
        ns:SetTemplate(button, "None")
        button.wuiBG:Hide()
    end

    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:Fill(hl, 1, 1, 1, 0.12)
    button:SetHighlightTexture(hl)

    local pushed = button:CreateTexture(nil, "ARTWORK", nil, 2)
    pushed:SetPoint("TOPLEFT", 1, -1)
    pushed:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:Fill(pushed, C.fel[1], C.fel[2], C.fel[3], 0.35)
    button:SetPushedTexture(pushed)

    local checked = button:CreateTexture(nil, "ARTWORK", nil, 1)
    checked:SetPoint("TOPLEFT", 1, -1)
    checked:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:Fill(checked, C.fel[1], C.fel[2], C.fel[3], 0.25)
    if button.SetCheckedTexture then button:SetCheckedTexture(checked) end

    local cd = button.cooldown
    if cd then
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", 1, -1)
        cd:SetPoint("BOTTOMRIGHT", -1, 1)
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.75) end
    end
    for _, key in ipairs({ "chargeCooldown", "lossOfControlCooldown" }) do
        local f = button[key]
        if f then f:ClearAllPoints(); f:SetPoint("TOPLEFT", 1, -1); f:SetPoint("BOTTOMRIGHT", -1, 1) end
    end
    for _, key in ipairs({ "Flash", "NewActionTexture", "SpellHighlightTexture", "Border", "AutoCastOverlay", "AutoCastable" }) do
        local t = button[key]
        if t and t.ClearAllPoints then t:ClearAllPoints(); t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1) end
    end
    if button.Flash and button.Flash.SetColorTexture then button.Flash:SetColorTexture(0.9, 0.2, 0.2, 0.35) end
    if button.Border and button.Border.SetTexture then
        -- The equipped-item marker, redrawn as a fel frame.
        button.Border:SetTexture(nil)
    end

    buttonHooks(button)
end

-- Show the empty-slot fill only when the slot is shown empty.
LAB.RegisterCallback(AB, "OnButtonUpdate", function(_, button)
    if not button.wuiEmpty then return end
    button.wuiEmpty:SetShown(not ns:Modern())
    if button.wuiBorder then
        local equipped = button.IsEquipped and button:IsEquipped()
        ns:SetBorderColor(button, equipped and "fel" or "border")
    end
end)

-- ============================================================
-- Bars
-- ============================================================
AB.bars = {}

-- The keybind text: the colour the player picked, or the look's text
-- colour. Read as it is painted, so a theme change only has to paint again.
function AB:HotkeyColor()
    -- Classic: the game's grey, as its own keybinds are.
    if not self:db().hotkeyColor and ns:Game() then return AB.GAME_HOTKEY end
    return self:db().hotkeyColor or C.text
end
AB.GAME_HOTKEY = { 0.6, 0.6, 0.6 }

-- Classic's button text: the game's number font for keybinds and counts,
-- its own small outlined face for macro names.
AB.GAME_NUMBER_FONT = "Fonts\\ARIALN.TTF"
AB.GAME_MACRO_FONT = "Fonts\\FRIZQT__.TTF"

-- The button text outline as a font flag. "look" is the look's own (an
-- outline in Rebel, none elsewhere), the way Media:SetFont reads it; the
-- library hands its flags to the client untouched, so it must be a flag.
function AB:OutlineFlag()
    local o = self:db().fontOutline
    if o == "look" then
        local st = Chrome.StyleDef and Chrome:StyleDef()
        o = st and st.textOutline or "NONE"
    end
    return (o == nil or o == "NONE") and "" or o
end

-- A profile keeps every default it was made with, so one made before the
-- keybinds followed the look still holds the old copy of the text colour.
-- That copy is let go once, per profile; a colour the player picked stays.
local OLD_HOTKEY = { 0.83, 0.78, 0.63 }
function AB:MigrateColors()
    local d = self:db()
    if d.colorsMigrated then return end
    if ns:SameColor(d.hotkeyColor, OLD_HOTKEY) then d.hotkeyColor = nil end
    d.colorsMigrated = true
end

local function buttonConfig(db, bar)
    local g = AB:db()
    local font = ns.Media:Font(g.font)
    local outline = AB:OutlineFlag()
    local hk = AB:HotkeyColor()
    local cfg = {
        outOfRangeColoring = g.rangeColoring,
        tooltip = g.tooltips,
        showGrid = bar.showGrid,
        colors = {
            range = { g.rangeColor[1], g.rangeColor[2], g.rangeColor[3] },
            mana  = { g.manaColor[1], g.manaColor[2], g.manaColor[3] },
        },
        hideElements = {
            macro = not bar.showMacro,
            hotkey = not bar.showHotkey,
            equipped = false,
            border = true,
            borderIfEmpty = true,
        },
        keyBoundTarget = false,
        keyBoundClickButton = "LeftButton",
        cooldownCount = g.cooldownText,
        flyoutDirection = bar.flyout or "UP",
        actionButtonUI = false,
        text = {
            hotkey = {
                font = { font = font, size = g.hotkeySize, flags = outline },
                color = { hk[1], hk[2], hk[3] },
                position = { anchor = "TOPRIGHT", relAnchor = "TOPRIGHT", offsetX = -1, offsetY = -3 },
                justifyH = "RIGHT",
            },
            count = {
                font = { font = font, size = g.countSize, flags = outline },
                color = { 1, 1, 1 },
                position = { anchor = "BOTTOMRIGHT", relAnchor = "BOTTOMRIGHT", offsetX = -1, offsetY = 2 },
                justifyH = "RIGHT",
            },
            macro = {
                font = { font = font, size = g.macroSize, flags = outline },
                color = { 1, 1, 1 },
                position = { anchor = "BOTTOM", relAnchor = "BOTTOM", offsetX = 0, offsetY = 2 },
                justifyH = "CENTER",
            },
        },
    }
    if ns:Game() then
        local t = cfg.text
        t.hotkey.font = { font = AB.GAME_NUMBER_FONT, size = g.hotkeySize, flags = "OUTLINE" }
        t.count.font = { font = AB.GAME_NUMBER_FONT, size = g.countSize, flags = "OUTLINE" }
        t.macro.font = { font = AB.GAME_MACRO_FONT, size = g.macroSize, flags = "OUTLINE" }
    end
    return cfg
end

-- The vehicle exit, on the last button of the main bar while in a vehicle.
local exitButton = {
    func = function()
        if UnitExists("vehicle") and VehicleExit then VehicleExit() elseif PetDismiss then PetDismiss() end
    end,
    texture = "Interface\\Icons\\Spell_Shadow_SacrificialShield",
    tooltip = LEAVE_VEHICLE or "Leave",
}

function AB:CreateBar(id)
    local name = "WicksUI_Bar" .. id
    local bar = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    bar.id = id
    bar:SetSize(1, 1)
    bar:SetFrameStrata("LOW")
    bar.buttons = {}
    bar.backdrop = ns:CreateBackdrop(bar, "Transparent")
    bar.backdrop:Hide()

    for i = 1, 12 do
        local b = LAB:CreateButton(i, name .. "Button" .. i, bar, nil)
        b.header = bar
        b.keyBoundTarget = bindPrefix(id) .. i
        self:StyleButton(b)
        bar.buttons[i] = b
    end

    -- Paging: the state driver hands a page number, or "possess" for the
    -- game's temporary bars, and every button is told.
    bar:SetAttribute("_onstate-page", [[
        if newstate == "possess" or newstate == "11" then
            if HasVehicleActionBar() then newstate = GetVehicleBarIndex()
            elseif HasOverrideActionBar() then newstate = GetOverrideBarIndex()
            elseif HasTempShapeshiftActionBar() then newstate = GetTempShapeshiftBarIndex()
            elseif HasBonusActionBar() then newstate = GetBonusBarIndex()
            else newstate = 12 end
        end
        newstate = tonumber(newstate) or 1
        self:SetAttribute("state", newstate)
        control:ChildUpdate("state", newstate)
    ]])

    bar:SetScript("OnEnter", function(self) AB:BarEnter(self) end)
    bar:SetScript("OnLeave", function(self) AB:BarLeave(self) end)

    local d = self:db().bars[id]
    ns:CreateMover(bar, "bar" .. id, self:Label(id), (d and d.point) or "CENTER,UIParent,CENTER,0,0",
        { groups = "actionbars", config = "actionbars.bar" .. id })
    self.bars[id] = bar
    return bar
end

-- Settings for a bar by its id: a number for the action bars, or
-- "stance" / "pet" for the two special ones.
function AB:BarDB(id)
    local g = self:db()
    return g.bars[id] or g[id]
end

function AB:BarEnter(bar)
    if not bar or not bar.id then return end
    local d = self:BarDB(bar.id)
    if d and d.mouseover then fadeTo(bar, d.alpha or 1, 0.1) end
    if d and d.globalFade and fadeWants("mouseover") then self:SetFadeReason("mouseover", true) end
end

function AB:BarLeave(bar)
    if not bar or not bar.id then return end
    local d = self:BarDB(bar.id)
    -- Only fade out once the pointer has left the bar and all its buttons.
    C_Timer.After(0.05, function()
        if bar:IsMouseOver() then return end
        if d and d.mouseover then fadeTo(bar, d.mouseoverAlpha or 0, 0.3) end
        if fadeReasons.mouseover then self:SetFadeReason("mouseover", false) end
    end)
end

-- Pages that a paging string can land on, so each button knows what to
-- show on every one of them.
local function activePages(paging)
    local pages = {}
    local clean = paging:gsub("%[.-%]", "")
    for piece in clean:gmatch("[^;]+") do
        local n = tonumber(piece:match("^%s*(%d+)%s*$"))
        if n then pages[n] = true end
    end
    return pages
end

-- A bar's visibility condition, or hide while the game's controller bars
-- are up in its place.
function AB:Visibility(cond)
    if ns.Pad and ns.Pad:HideBars() then return "hide" end
    local s = (cond or "show"):gsub("[\r\n]", " ")
    return s
end

-- Only the bars' show and hide, for the interface changing between the
-- controller and the mouse and keyboard.
function AB:ApplyVisibility()
    ns:AfterCombat("ab:visibility", function()
        local g = self:db()
        for _, id in ipairs(self.BAR_IDS) do
            local bar, d = self.bars[id], g.bars[id]
            if bar and d and d.enable then
                RegisterStateDriver(bar, "visibility", self:Visibility(d.visibility or VIS_OTHER))
            end
        end
        if ns.Special and ns.Special.ApplyVisibility then ns.Special:ApplyVisibility() end
    end)
end

function AB:LayoutBar(id)
    local bar = self.bars[id]
    local d = self:db().bars[id]
    if not bar or not d then return end

    local paging = (d.paging and d.paging ~= "") and d.paging or self:DefaultPaging(id)
    local pages = activePages(paging)
    if id == 1 then
        pages[self.VEHICLE_PAGE] = true; pages[self.OVERRIDE_PAGE] = true
        pages[self.SHAPE_PAGE] = true; pages[12] = true
    end

    local w = d.size
    local h = d.keepRatio and d.size or (d.height or d.size)
    local n = math.max(1, math.min(12, d.buttons))
    local perRow = math.max(1, math.min(n, d.perRow))
    local rows = math.ceil(n / perRow)
    local sp, pad = d.spacing, d.padding
    local growth = d.growth or "BOTTOMLEFT"
    local up = growth:find("BOTTOM") ~= nil
    local left = growth:find("LEFT") ~= nil

    for i, b in ipairs(bar.buttons) do
        b:SetSize(w, h)
        b:ClearAllPoints()
        local row = math.floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        local x = pad + col * (w + sp)
        local y = pad + row * (h + sp)
        b:SetPoint(growth, bar, growth, left and x or -x, up and y or -y)

        -- What the button shows on each page.
        for state = 1, 18 do
            if pages[state] then
                b:SetState(state, "action", (state - 1) * 12 + i)
            else
                b:SetState(state, "empty")
            end
        end
        if id == 1 and i == 12 then b:SetState(self.VEHICLE_PAGE, "custom", exitButton) end
        -- LAB's state 0 is "no header yet"; keep it on the bar's own page.
        b:SetState(0, "action", (math.max(1, tonumber(paging:match("(%d+)%s*$")) or id) - 1) * 12 + i)

        -- The library draws the keybind text from the binding named here,
        -- so each button carries the game's binding for its page and slot.
        local cfg = buttonConfig(d, d)
        cfg.keyBoundTarget = b.keyBoundTarget
        b:UpdateConfig(cfg)
        if i > n then b:Hide(); b:SetAttribute("statehidden", true) else b:SetAttribute("statehidden", nil); b:Show() end
    end

    bar:SetSize(pad * 2 + perRow * w + (perRow - 1) * sp, pad * 2 + rows * h + (rows - 1) * sp)
    bar.backdrop:SetShown(d.backdrop)
    ns.Movers:Resize("bar" .. id)

    RegisterStateDriver(bar, "page", paging)
    bar:SetAttribute("page", paging)

    -- Fading: a bar on the global fade takes its alpha from the fader.
    bar:SetParent(d.globalFade and fader or UIParent)
    bar:SetFrameStrata("LOW")
    if d.mouseover and not bar:IsMouseOver() then
        bar:SetAlpha(d.mouseoverAlpha or 0)
    else
        bar:SetAlpha(d.alpha or 1)
    end

    if d.enable then
        RegisterStateDriver(bar, "visibility", AB:Visibility(d.visibility or VIS_OTHER))
        ns.Movers:SetEnabled("bar" .. id, true)
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
        ns.Movers:SetEnabled("bar" .. id, false)
    end
end

-- ============================================================
-- Keybinds
-- ============================================================
-- Override bindings aim each key bound to a page's binding at our button.
-- They belong to the bar frame and are rebuilt whenever bindings change.
function AB:UpdateBindings()
    ns:AfterCombat("ab:binds", function()
        for id, bar in pairs(self.bars) do
            ClearOverrideBindings(bar)
            local d = self:db().bars[id]
            if d and d.enable then
                for i, b in ipairs(bar.buttons) do
                    if i <= d.buttons then
                        for _, key in ipairs({ GetBindingKey(b.keyBoundTarget) }) do
                            if key and key ~= "" then SetOverrideBindingClick(bar, false, key, b:GetName()) end
                        end
                    end
                end
            end
        end
        if ns.Special then ns.Special:UpdateBindings() end
    end)
end

-- ============================================================
-- Game settings this module surfaces
-- ============================================================
local function cvar(name, value)
    local CV = rawget(_G, "C_CVar")
    if CV and CV.SetCVar then pcall(CV.SetCVar, name, value) end
end

function AB:ApplyCVars()
    local g = self:db()
    cvar("lockActionBars", g.lockBars and "1" or "0")
    cvar("ActionButtonUseKeyDown", g.keyDown and "1" or "0")
    cvar("countdownForCooldowns", g.cooldownText and "1" or "0")
end

-- ============================================================
-- Lifecycle
-- ============================================================
-- ============================================================
-- Matching the game's bars
-- ============================================================
-- The game numbers its bars in a different order from the pages they
-- show: its Action Bar 2 is page 6, the bottom left bar of old. Our bars
-- are keyed by page, since that is what decides the spells on them and
-- the keybinds they answer to, and they are named the way the game names
-- them so "bar 2" means the same thing in both places.
AB.GAME_NUMBER = { [1] = 1, [6] = 2, [5] = 3, [3] = 4, [4] = 5, [13] = 6, [14] = 7, [15] = 8 }

function AB:Label(id)
    local n = self.GAME_NUMBER[id]
    if n then return "Action Bar " .. n end
    return ("Extra bar, page %d"):format(id)
end

-- Which of the game's bars are switched on, from the game's own settings.
local function gameShows(n)
    if n == 1 then return true end
    local S = rawget(_G, "Settings")
    if not (S and S.GetValue) then return n <= 3 end
    local ok, v = pcall(S.GetValue, "PROXY_SHOW_ACTIONBAR_" .. n)
    if not ok or v == nil then return n <= 3 end
    return v and true or false
end

-- Switch on the bars the game had on, name them its way and stack them
-- the way its default layout does: 1, 2 and 3 up from the bottom, 4 and
-- 5 down the right, 6 to 8 above. Runs once on its own; the Action Bars
-- page can run it again.
function AB:MatchGame()
    local g = self:db()
    local y, step = 40, 36
    local stackTop = y
    local order = { 1, 6, 5, 13, 14, 15 }
    for _, id in ipairs(order) do
        local d = g.bars[id]
        local on = gameShows(self.GAME_NUMBER[id])
        d.enable = on
        d.perRow, d.buttons, d.growth = 12, 12, "BOTTOMLEFT"
        if on then
            d.point = ("BOTTOM,UIParent,BOTTOM,0,%d"):format(stackTop)
            stackTop = stackTop + step
        else
            d.point = ("BOTTOM,UIParent,BOTTOM,0,%d"):format(stackTop)
        end
    end
    for i, id in ipairs({ 3, 4 }) do
        local d = g.bars[id]
        d.enable = gameShows(self.GAME_NUMBER[id])
        d.perRow, d.buttons, d.growth = 1, 12, "TOPRIGHT"
        d.point = ("RIGHT,UIParent,RIGHT,%d,0"):format(-4 - (i - 1) * 36)
    end
    for _, id in ipairs({ 2, 7, 8, 9, 10 }) do g.bars[id].enable = false end
    -- Stance and pet bars sit on top of the stack.
    if g.stance then g.stance.point = ("BOTTOMLEFT,UIParent,BOTTOM,-216,%d"):format(stackTop + 4) end
    if g.pet then g.pet.point = ("BOTTOMRIGHT,UIParent,BOTTOM,216,%d"):format(stackTop + 4) end

    local movers = ns.A.db.profile.movers
    local function reset(name, point)
        movers[name] = nil
        local m = ns.Movers.list[name]
        if m then m.default = point end
    end
    for id, d in pairs(g.bars) do reset("bar" .. id, d.point) end
    if g.stance then reset("stancebar", g.stance.point) end
    if g.pet then reset("petbar", g.pet.point) end
    g.matchedGame = true
    ns.Movers:PlaceAll()
end

function AB:Initialize()
    self:MigrateColors()
    -- Before the bars exist, so their movers start where this puts them.
    if not self:db().matchedGame then self:MatchGame() end
    self:DisableBlizzard()
    for _, id in ipairs(self.BAR_IDS) do self:CreateBar(id) end
    self:Update()

    ns:On("UPDATE_BINDINGS", function() AB:UpdateBindings() end)
    ns:On("PLAYER_REGEN_DISABLED", evalFade)
    ns:On("PLAYER_REGEN_ENABLED", evalFade)
    ns:On("PLAYER_TARGET_CHANGED", evalFade)
    ns:On("PLAYER_FOCUS_CHANGED", evalFade)
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        ns:On(e, function(_, unit) if unit == "player" then evalFade() end end)
    end
    if Chrome.OnThemeChanged then Chrome:OnThemeChanged(function() AB:PaintHotkeys() end) end
end

-- Keybind text in the look's colours again after a theme change. The
-- library keeps a copy of the config it was given, so the buttons are
-- handed a fresh one; that sets attributes, so it waits out a fight.
function AB:PaintHotkeys()
    ns:AfterCombat("ab:hotkeys", function()
        for _, id in ipairs(self.BAR_IDS) do
            local bar, d = self.bars[id], self:db().bars[id]
            if bar and d then
                for _, b in ipairs(bar.buttons) do
                    local cfg = buttonConfig(d, d)
                    cfg.keyBoundTarget = b.keyBoundTarget
                    b:UpdateConfig(cfg)
                end
            end
        end
        if ns.Special and ns.Special.PaintHotkeys then ns.Special:PaintHotkeys() end
    end)
end

function AB:Update()
    ns:AfterCombat("ab:update", function()
        self:MigrateColors()
        self:ApplyCVars()
        for _, id in ipairs(self.BAR_IDS) do
            if self.bars[id] then self:LayoutBar(id) end
        end
        self:UpdateBindings()
        evalFade()
        if ns.Special then ns.Special:Update() end
    end)
end

-- ============================================================
-- Settings pages
-- ============================================================
local function onChange() AB:Update() end

local GROWTH = {
    { "BOTTOMLEFT", "Up and right" }, { "BOTTOMRIGHT", "Up and left" },
    { "TOPLEFT", "Down and right" }, { "TOPRIGHT", "Down and left" },
}
local FLYOUT = { { "UP", "Up" }, { "DOWN", "Down" }, { "LEFT", "Left" }, { "RIGHT", "Right" } }

ns.Config:AddPage("actionbars", "Action bars", function(L)
    local W = ns.Widgets
    L:DB(function() return AB:db() end)
    L:Heading("Behaviour")
    L:Toggle("Lock the bars", "lockBars", { tooltip = "The game's own Lock Action Bars. Hold Shift to drag a spell off a locked bar." })
    L:Toggle("Put new spell ranks on your bars", "autoRank", { tooltip = "When you learn a higher rank of a spell, every button holding an older rank of it takes the new one. Buttons you set to an older rank afterwards are left alone until the next rank comes. Waits until the fight is over." })
    L:Toggle("Cast on key down", "keyDown", { tooltip = "Casts as the key goes down rather than when it comes back up. Fractionally faster, and the game's own setting." })
    L:Toggle("Cooldown numbers", "cooldownText", { tooltip = "The game's countdown numbers on cooldowns. Drawn by the client, so they keep working in combat." })
    L:Toggle("Shorten keybind text", "abbreviate", { tooltip = "SHIFT-5 shows as S5, Mouse Button 4 as M4." })
    L:Dropdown("Out of range", "rangeColoring", { { "button", "Colour the icon" }, { "hotkey", "Colour the keybind" }, { "none", "Do nothing" } })
    L:Dropdown("Tooltips", "tooltips", { { "enabled", "Always" }, { "nocombat", "Out of combat" }, { "disabled", "Never" } })
    L:Color("Out of range colour", "rangeColor")
    L:Color("Not enough power colour", "manaColor")

    L:Button("Match the game's bars", function()
        ns.Widgets:Confirm("Switch on the bars the game has switched on and stack them the way the game does? Your spells and keybinds stay as they are.", function()
            AB:MatchGame()
            AB:Update()
        end, "Match")
    end, { width = 180, tooltip = "Turns on the same bars as the game's own Action Bars settings and puts them back in the game's order." })

    L:Heading("Text")
    L:Dropdown("Font", "font", function()
        local out = {}
        for _, name in ipairs(ns.Media:List("font")) do out[#out + 1] = { name, name, name } end
        return out
    end)
    L:Dropdown("Outline", "fontOutline", W.Values(ns.Media.outlines, ns.Media.outlineLabels))
    L:Slider("Keybind size", "hotkeySize", 6, 24, 1)
    L:Slider("Macro name size", "macroSize", 6, 24, 1)
    L:Slider("Stack count size", "countSize", 6, 24, 1)
    L:Color("Keybind colour", "hotkeyColor", { fallback = function() return AB:HotkeyColor() end,
        tooltip = "Until you pick one, the look's text colour. Right-click to follow the look again." })

    L:Heading("Global fade")
    L:Note("Bars set to follow the global fade sit at the opacity below, and come up together when any of the reasons you pick is true. Health cannot be one of the reasons: this client keeps your health from addons.")
    L:Slider("Faded opacity", "fadeAlpha", 0, 1, 0.05)
    L:Input("Come up for", "fadeIn", { tooltip = "Any of: combat, target, focus, casting, mouseover. Separate with commas." })

    -- Only where the client has a controller interface.
    if rawget(_G, "C_InputInterfaceStyle") then
        local function pad() return AB:db().pad end
        local function flag(key) return {
            get = function() return pad()[key] ~= false end,
            setter = function(v) pad()[key] = v and true or false end,
        } end
        L:Heading("Controller")
        L:Note("When you play on a controller the game shows its own controller bars, the D-pad and face button clusters, in place of its usual bars. These follow it, and go back the moment you take up the mouse and keyboard.")
        local o = flag("hideBars")
        o.tooltip = "Wick's action, stance and pet bars stand aside while the controller is in use, so the game's controller bars are the only ones on screen."
        L:Toggle("Make way for the controller bars", nil, o)
        o = flag("skin")
        o.tooltip = "The controller buttons on tiles in the look, square on the D-pad side and round on the face buttons, with the game's ornate backings gone. The marks for which controller button fires what stay. The Classic look keeps the game's own. Switching it off takes a reload."
        L:Toggle("Controller bars in the look", nil, o)
        o = flag("clearFrames")
        o.tooltip = "The player frame and anything else over the controller bars' width near the bottom goes up together, just clear of them. A frame you move while on the controller keeps that place for the controller only."
        L:Toggle("Keep frames clear of them", nil, o)
        o = flag("kitsTop")
        o.tooltip = "The bars other Wick addons put on screen (a class kit's strip) go to the top middle of the screen, one under the next, leaving the bottom to the controller bars. One you move while on the controller keeps that place instead."
        L:Toggle("Kit bars to the top", nil, o)
    end
end, { onChange = function() onChange(); ns.Movers:PlaceAll() end, order = 10 })

local function barPage(id)
    ns.Config:AddPage("actionbars.bar" .. id, AB:Label(id), function(L)
        L:DB(function() return AB:db().bars[id] end)
        -- Settings copied from another bar. The page it shows and whether
        -- it is on are this bar's own.
        L:CopyFrom({
            sources = function()
                local out = {}
                for _, other in ipairs(AB.BAR_IDS) do
                    if other ~= id then out[#out + 1] = { other, AB:Label(other) } end
                end
                return out
            end,
            table = function(other) return AB:db().bars[other] end,
            skip = { enable = true, paging = true },
        })
        if AB.GAME_NUMBER[id] then
            L:Note(("The game's Action Bar %d: the same spells and the same keybinds. It shows action page %d."):format(AB.GAME_NUMBER[id], id))
        elseif id >= 7 and id <= 10 then
            L:Note("An extra bar the game does not have. It shows action page " .. id .. ", which the game also uses for stances and forms, so warriors, druids, rogues and priests will see their stance buttons here.")
        else
            L:Note("An extra bar the game does not have. It shows action page 2, the page the main bar turns to with Shift and the mouse wheel.")
        end
        L:Toggle("Enable", "enable")
        L:Toggle("Backdrop", "backdrop")
        L:Slider("Buttons", "buttons", 1, 12, 1)
        L:Slider("Buttons per row", "perRow", 1, 12, 1)
        L:Slider("Button size", "size", 14, 80, 1)
        L:Toggle("Square buttons", "keepRatio")
        L:Slider("Button height", "height", 10, 80, 1, { disabled = function() return AB:db().bars[id].keepRatio end })
        L:Slider("Spacing", "spacing", -1, 20, 1)
        L:Slider("Padding", "padding", 0, 20, 1)
        L:Dropdown("Grow", "growth", GROWTH)
        L:Dropdown("Flyouts open", "flyout", FLYOUT)

        L:Heading("Fading")
        L:Slider("Opacity", "alpha", 0, 1, 0.05)
        L:Toggle("Fade until moused over", "mouseover")
        L:Slider("Opacity until moused over", "mouseoverAlpha", 0, 1, 0.05, { disabled = function() return not AB:db().bars[id].mouseover end })
        L:Toggle("Follow the global fade", "globalFade")

        L:Heading("Buttons")
        L:Toggle("Show empty buttons", "showGrid")
        L:Toggle("Keybind text", "showHotkey")
        L:Toggle("Macro names", "showMacro")

        L:Heading("Conditions")
        L:TextArea("Visibility", "visibility", {
            tooltip = "A macro condition that ends in show or hide, for example  [combat] show; hide  or  [mod:shift] show; hide.",
            default = function() return id == 1 and VIS_MAIN or VIS_OTHER end,
        })
        L:TextArea("Paging", "paging", {
            get = function() local p = AB:db().bars[id].paging; return (p and p ~= "") and p or AB:DefaultPaging(id) end,
            tooltip = "Which action page the bar shows, as a macro condition. The last number is the page when nothing else matches.",
            default = function() return AB:DefaultPaging(id) end,
        })
        L:Button("Reset this bar", function()
            local fresh = ns:Copy(ns.defaults.profile.actionbars.bars[id])
            local t = AB:db().bars[id]
            for k in pairs(t) do t[k] = nil end
            for k, v in pairs(fresh) do t[k] = v end
            ns.Movers:Reset("bar" .. id)
        end)
    end, { parent = "actionbars", onChange = onChange, order = AB.GAME_NUMBER[id] or (20 + id) })
end
for _, id in ipairs(AB.BAR_IDS) do barPage(id) end
