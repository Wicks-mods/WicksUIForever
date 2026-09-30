-- Wick's UI
-- Core/Media.lua: fonts and bar textures.
--
-- The built-in set is what the game ships, so nothing here needs a
-- licence. If another addon has loaded LibSharedMedia, everything it
-- knows about is offered too, and our own entries are registered with it
-- so other addons can pick the Wick textures.

local ADDON, ns = ...

local M = {}
ns.Media = M

local FONTS = "Interface\\AddOns\\WicksUI\\Media\\Fonts\\"

M.fonts = {
    -- PT Sans Narrow (ParaType, SIL Open Font License 1.1, bundled
    -- unmodified; licence in Media/Fonts). The bold cut is the default.
    ["Wick"]                = FONTS .. "PT_Sans-Narrow-Web-Bold.ttf",
    ["PT Sans Narrow"]      = FONTS .. "PT_Sans-Narrow-Web-Regular.ttf",
    ["PT Sans Narrow Bold"] = FONTS .. "PT_Sans-Narrow-Web-Bold.ttf",
    ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Morpheus"]     = "Fonts\\MORPHEUS.TTF",
    ["Skurri"]       = "Fonts\\SKURRI.TTF",
}

-- The faces WickCore bundles for its looks (SIL OFL 1.1, licences in
-- WickCore/Media/Fonts), offered in every font list.
do
    local WF = "Interface\\AddOns\\WickCore\\Media\\Fonts\\"
    for name, file in pairs({
        ["Anton"] = "Anton-Regular", ["Archivo Narrow"] = "ArchivoNarrow-Bold",
        ["Barlow Condensed"] = "BarlowCondensed-SemiBold", ["Cormorant"] = "CormorantGaramond-SemiBold",
        ["Cormorant SC"] = "CormorantSC-SemiBold", ["Exo 2"] = "Exo2-Medium", ["Italiana"] = "Italiana-Regular", ["Jost"] = "Jost-Medium",
        ["Michroma"] = "Michroma-Regular", ["Rajdhani"] = "Rajdhani-SemiBold",
        ["Saira Semi Condensed"] = "SairaSemiCondensed-Medium", ["Tektur"] = "Tektur-Medium",
    }) do M.fonts[name] = WF .. file .. ".ttf" end
end

M.statusbars = {
    ["Wick Flat"]    = "Interface\\Buttons\\WHITE8X8",
    ["Wick Shaded"]  = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Wick Glass"]   = "Interface\\AddOns\\WickCore\\Media\\Textures\\bar-glass.png",
    ["Blizzard"]     = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Raid"]         = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}

M.blank = "Interface\\Buttons\\WHITE8X8"

-- The modern style's pieces, generated for Wick's UI: a rounded panel and
-- an outline ring (9-sliced, 8 px margins, so corners keep their size at
-- any frame size), a soft shadow (9-sliced, 28 px margins) and a rounded
-- mask for icons.
local TEX = "Interface\\AddOns\\WicksUI\\Media\\Textures\\"
-- These follow the suite's style (WickCore's Chrome.Media): each style has
-- its own panel, ring and masks, and its own 9-slice margin. Read when a
-- frame is drawn, so they are always the style in use.
local STYLED = { rounded = true, ring = true, shadow = true, roundmask = true, iconmask = true, slice = true, glow = true }
setmetatable(M, { __index = function(_, k)
    if not STYLED[k] then return nil end
    local Chrome = ns.Core and ns.Core.Chrome
    if Chrome and Chrome.Media then return Chrome.Media[k] end
    if k == "slice" then return 8 end
    return TEX .. (k == "iconmask" and "roundmask" or k) .. ".png"
end })
-- Flat white marks for small buttons, tinted as they are drawn.
function M:Glyph(name) return TEX .. "glyph-" .. name .. ".png" end

M.outlines = { "look", "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROMEOUTLINE" }
-- "look": the look's own, a hard outline in a look that has one (Rebel),
-- else none and a soft shadow, the way WickCore's windows draw text.
M.outlineLabels = { look = "The look's own", NONE = "None, soft shadow", OUTLINE = "Outline",
    THICKOUTLINE = "Thick outline", MONOCHROMEOUTLINE = "Monochrome outline" }

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    for name, path in pairs(M.fonts) do
        if name:find("^Wick") or name:find("^PT Sans") then pcall(LSM.Register, LSM, "font", name, path) end
    end
    for name, path in pairs(M.statusbars) do
        if name:find("^Wick") then pcall(LSM.Register, LSM, "statusbar", name, path) end
    end
end

local function merged(own, kind)
    local out = {}
    for k, v in pairs(own) do out[k] = v end
    if LSM then
        for _, name in ipairs(LSM:List(kind) or {}) do
            if not out[name] then out[name] = LSM:Fetch(kind, name) end
        end
    end
    return out
end

function M:Font(name)
    name = name or ns:G().font
    -- The Wick font is the style's own where the style has one.
    if name == "Wick" then
        local Chrome = ns.Core and ns.Core.Chrome
        local st = Chrome and Chrome.StyleDef and Chrome:StyleDef()
        if st and st.uiFont then return st.uiFont end
    end
    local all = merged(self.fonts, "font")
    return all[name] or self.fonts["Wick"]
end

function M:Statusbar(name)
    -- A look with a bar texture of its own (Frost's glass) draws in it
    -- while the player's choice is still the default flat one.
    if not name and (ns:G().statusbar or "Wick Flat") == "Wick Flat" then
        local Chrome = ns.Core and ns.Core.Chrome
        local st = Chrome and Chrome.StyleDef and Chrome:StyleDef()
        if st and st.statusbar then return st.statusbar end
    end
    name = name or ns:G().statusbar
    local all = merged(self.statusbars, "statusbar")
    return all[name] or self.statusbars["Wick Flat"]
end

-- Sorted names for a dropdown.
function M:List(kind)
    local all = merged(kind == "font" and self.fonts or self.statusbars, kind)
    local names = {}
    for name in pairs(all) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- Apply a font to a FontString. "NONE" is not a real flag, the client
-- wants an empty string for no outline. unit: unit frame and nameplate
-- text, which a look can give a face and size of its own (Rebel's heavy
-- condensed capitals) apart from the rest of the UI.
function M:SetFont(fs, size, outline, face, unit)
    local g = ns:G()
    local Chrome = ns.Core and ns.Core.Chrome
    local st = Chrome and Chrome.StyleDef and Chrome:StyleDef()
    outline = outline or g.fontOutline
    if outline == "look" then outline = st and st.textOutline or "NONE" end
    if outline == "NONE" then outline = "" end
    size = size or g.fontSize
    local path
    if st and (face or g.font) == "Wick" then
        if unit and st.unitFont then
            path, size = st.unitFont, size + (st.unitBump or 0)
        elseif st.uiBump then
            -- A look whose face runs small sets the Wick font a little larger.
            size = size + st.uiBump
        end
    end
    fs:SetFont(path or self:Font(face), size, outline)
    if outline == "" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

-- The text the game draws over the world in the look's fonts:
--   names over units and the damage numbers over enemies: two globals
--     the client reads at login (a relog shows a change, a reload does
--     not); Blizzard's own code only ever sets them.
--   the zone name as you enter (in the look's heading face, it is a title),
--     the subzone, the PvP line under them and your own scrolling combat
--     text: shared font objects, so the text using them follows at once.
--     Their sizes and thick outlines stay: they sit over the world.
-- Latin alphabets only: the look fonts carry no Cyrillic, Chinese or
-- Korean, so those clients keep the game's. Colours are the game's own.
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }
local function face(name, path)
    local fo = rawget(_G, name)
    if not (fo and fo.GetFont and fo.SetFont) then return end
    local _, size, flags = fo:GetFont()
    if size and size > 0 then fo:SetFont(path, size, flags or "") end
end
-- The game's own combat text fonts, as they were before we touched them,
-- and what we set: with another combat text addon kept in the setup,
-- ours go back, unless that addon has set its own since.
local GAME_DAMAGE = rawget(_G, "DAMAGE_TEXT_FONT")
local GAME_COMBAT = (function()
    local fo = rawget(_G, "CombatTextFont")
    return fo and fo.GetFont and (fo:GetFont()) or nil
end)()
local oursDamage, oursCombat
local function combatTextOurs()
    local A = ns.A
    local g = A and A.db and A.db.profile and A.db.profile.general
    return not g or g.combatTextFont ~= false
end
function M:WorldFonts()
    if not LATIN[(GetLocale and GetLocale()) or "enUS"] then return end
    local Chrome = ns.Core and ns.Core.Chrome
    if not (Chrome and Chrome.Font) then return end
    local body = Chrome:Font()
    local head = Chrome.HeadingFont and Chrome:HeadingFont() or body
    UNIT_NAME_FONT = body
    face("ZoneTextFont", head)
    face("SubZoneTextFont", head)
    face("PVPInfoTextFont", body)
    local ct = rawget(_G, "CombatTextFont")
    if combatTextOurs() then
        DAMAGE_TEXT_FONT, oursDamage = body, body
        face("CombatTextFont", body)
        oursCombat = body
    else
        if oursDamage and DAMAGE_TEXT_FONT == oursDamage and GAME_DAMAGE then DAMAGE_TEXT_FONT = GAME_DAMAGE end
        if oursCombat and GAME_COMBAT and ct and ct.GetFont and (ct:GetFont()) == oursCombat then
            face("CombatTextFont", GAME_COMBAT)
        end
        oursDamage, oursCombat = nil, nil
    end
end
M.UnitNameFont = M.WorldFonts
M:WorldFonts()
-- Again at login, once the character (and so its look) is known.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function() M:WorldFonts() end)
end
