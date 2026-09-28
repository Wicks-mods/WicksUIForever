-- Wick's UI
-- Core/Skin.lua: the flat Wick panel, built one way everywhere.
--
-- Void fill, a single physical-pixel muted-purple border, fel-green
-- L-bracket corners on the panels big enough to carry them. No gradients
-- and no Blizzard dialog art. Colours come from WickCore's palette and are
-- registered with it, so a theme change repaints every panel in place.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local BLANK = "Interface\\Buttons\\WHITE8X8"

local TEMPLATES = {
    Default     = { bg = "void",   alpha = 0.92 },
    Transparent = { bg = "void",   alpha = 0.65 },
    Shadow      = { bg = "shadow", alpha = 1 },
    None        = { bg = nil },
}

local function paint(tex, token, alpha)
    local c = C[token] or C.void
    tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
    Chrome:Register(tex, token, "texture", alpha)
end

-- Four edges, one physical pixel each, drawn outside nothing: they sit on
-- the frame's own edge so two panels placed side by side share a line.
local function makeBorder(f)
    local b = {}
    for i, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = f:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(BLANK)
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
        b[side] = t
    end
    f.wuiBorder = b
    return b
end

local function layoutBorder(f)
    local b = f.wuiBorder
    local px = ns.mult or 1
    b.top:ClearAllPoints();    b.top:SetPoint("TOPLEFT");     b.top:SetPoint("TOPRIGHT");     b.top:SetHeight(px)
    b.bottom:ClearAllPoints(); b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT"); b.bottom:SetHeight(px)
    b.left:ClearAllPoints();   b.left:SetPoint("TOPLEFT");    b.left:SetPoint("BOTTOMLEFT");  b.left:SetWidth(px)
    b.right:ClearAllPoints();  b.right:SetPoint("TOPRIGHT");  b.right:SetPoint("BOTTOMRIGHT"); b.right:SetWidth(px)
end

-- Paint a frame as a Wick panel. template: Default, Transparent, Shadow
-- or None (border only).
function ns:SetTemplate(f, template, opts)
    opts = opts or {}
    local t = TEMPLATES[template or "Default"] or TEMPLATES.Default
    if not f.wuiBG then
        f.wuiBG = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        f.wuiBG:SetAllPoints()
    end
    if t.bg then
        paint(f.wuiBG, t.bg, opts.alpha or t.alpha)
        f.wuiBG:Show()
    else
        f.wuiBG:Hide()
    end
    if not f.wuiBorder then makeBorder(f) end
    layoutBorder(f)
    ns:SetBorderColor(f, opts.border or "border")
    if opts.brackets and ns:G().brackets and not f.brackets then
        Chrome:AddBrackets(f)
    end
    f.wuiTemplate = template or "Default"
    ns.skinned = ns.skinned or setmetatable({}, { __mode = "k" })
    ns.skinned[f] = true
    return f
end

-- A token name ("border", "fel") or an { r, g, b } table.
function ns:SetBorderColor(f, color, alpha)
    local b = f.wuiBorder
    if not b then return end
    for _, t in pairs(b) do
        if type(color) == "string" then
            paint(t, color, alpha)
        else
            t:SetColorTexture(color[1] or color.r, color[2] or color.g, color[3] or color.b, alpha or color[4] or 1)
        end
    end
end

-- A backdrop as a separate child frame, one level below the host. This is
-- what secure buttons and status bars want: the host keeps its own draw
-- layers for its own art, and the panel can sit outside it by an inset.
function ns:CreateBackdrop(host, template, inset, opts)
    if host.backdrop then return host.backdrop end
    local bd = CreateFrame("Frame", nil, host)
    local o = inset or 0
    bd:SetPoint("TOPLEFT", host, "TOPLEFT", -o, o)
    bd:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", o, -o)
    bd:SetFrameLevel(math.max(0, host:GetFrameLevel() - 1))
    ns:SetTemplate(bd, template, opts)
    host.backdrop = bd
    return bd
end

-- Re-lay every border after the pixel size changes (UI scale, resolution).
function ns:RefreshBorders()
    if not ns.skinned then return end
    for f in pairs(ns.skinned) do
        if f.wuiBorder then layoutBorder(f) end
    end
end

-- ============================================================
-- Widgets built on the template
-- ============================================================

-- Icon cropped to lose Blizzard's baked-in border.
function ns:CropIcon(tex, zoom)
    local z = zoom or 0.08
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
end

function ns:CreateText(parent, size, justify, outline, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    ns.Media:SetFont(fs, size, outline)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    local c = C.text
    fs:SetTextColor(c[1], c[2], c[3], 1)
    return fs
end

function ns:CreateStatusBar(parent, template)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetStatusBarTexture(ns.Media:Statusbar())
    local tex = sb:GetStatusBarTexture()
    if tex and tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
    if template ~= false then ns:CreateBackdrop(sb, template or "Default", ns.mult) end
    ns.statusbars = ns.statusbars or setmetatable({}, { __mode = "k" })
    ns.statusbars[sb] = true
    return sb
end

-- Repaint every bar we made with the texture from settings.
function ns:RefreshStatusbars()
    local path = ns.Media:Statusbar()
    if ns.statusbars then
        for sb in pairs(ns.statusbars) do sb:SetStatusBarTexture(path) end
    end
end
