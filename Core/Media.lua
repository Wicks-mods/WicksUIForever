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

M.statusbars = {
    ["Wick Flat"]    = "Interface\\Buttons\\WHITE8X8",
    ["Wick Shaded"]  = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Blizzard"]     = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Raid"]         = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}

M.blank = "Interface\\Buttons\\WHITE8X8"

-- The modern style's pieces, generated for Wick's UI: a rounded panel and
-- an outline ring (9-sliced, 8 px margins, so corners keep their size at
-- any frame size), a soft shadow (9-sliced, 28 px margins) and a rounded
-- mask for icons.
local TEX = "Interface\\AddOns\\WicksUI\\Media\\Textures\\"
M.rounded   = TEX .. "rounded.png"
M.ring      = TEX .. "ring.png"
M.shadow    = TEX .. "shadow.png"
M.roundmask = TEX .. "roundmask.png"

M.outlines = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROMEOUTLINE" }

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
    local all = merged(self.fonts, "font")
    return all[name] or self.fonts["Wick"]
end

function M:Statusbar(name)
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
-- wants an empty string for no outline.
function M:SetFont(fs, size, outline, face)
    local g = ns:G()
    outline = outline or g.fontOutline
    if outline == "NONE" then outline = "" end
    fs:SetFont(self:Font(face), size or g.fontSize, outline)
    if outline == "" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
end
