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
    Default     = { bg = "void",   alpha = 1 },
    Transparent = { bg = "void",   alpha = 0.82 },
    Shadow      = { bg = "shadow", alpha = 1 },
    None        = { bg = nil },
}

-- The modern style: rounded glass panels lifted by a soft shadow, no
-- border lines, and a rounded fel ring where the crisp style would colour
-- its border. The style is read once at load; switching it reloads.
-- The suite's style is WickCore's (Wick Modern or Wick OG, account-wide),
-- so Wick's UI and every other Wick addon always agree; Wick's UI's own
-- setting is only the fallback for a WickCore without it.
function ns:Modern()
    local Chrome = ns.Core and ns.Core.Chrome
    if Chrome and Chrome.Modern then return Chrome:Modern() end
    return ns:G().style == "modern"
end

local MODERN = {
    Default     = { bg = "void",   alpha = 0.74 },
    Transparent = { bg = "void",   alpha = 0.52 },
    Shadow      = { bg = "shadow", alpha = 0.92 },
    None        = { bg = nil },
}

local function slice(tex, m)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(m, m, m, m)
        if tex.SetTextureSliceMode then pcall(tex.SetTextureSliceMode, tex, 0) end
    end
end

-- WickCore's theme repaint sets a flat colour on what it knows about,
-- which would wipe a rounded texture, so modern panels keep their own
-- list and are repainted by vertex colour instead.
local glass = setmetatable({}, { __mode = "k" })
local function paintGlass(tex, token, alpha)
    local c = C[token] or C.void
    tex:SetVertexColor(c[1], c[2], c[3], alpha or 1)
    glass[tex] = { token = token, alpha = alpha }
end
if Chrome.OnThemeChanged then
    Chrome:OnThemeChanged(function()
        for tex, g in pairs(glass) do
            local c = C[g.token] or C.void
            tex:SetVertexColor(c[1], c[2], c[3], g.alpha or 1)
        end
    end)
end

local function modernTemplate(f, template, opts)
    local t = MODERN[template or "Default"] or MODERN.Default
    if not f.wuiBG then
        f.wuiBG = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        f.wuiBG:SetAllPoints()
    end
    f.wuiBG:SetTexture(ns.Media.rounded)
    slice(f.wuiBG, 8)
    if t.bg then
        paintGlass(f.wuiBG, t.bg, opts.alpha or t.alpha)
        f.wuiBG:Show()
    else
        f.wuiBG:Hide()
    end
    -- The lift: a soft shadow reaching past the frame's edges.
    local lifted = opts.shadow == true or (opts.shadow ~= false and (template == nil or template == "Default" or template == "Transparent"))
    if lifted and t.bg and not f.wuiShadow then
        local s = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        s:SetTexture(ns.Media.shadow)
        slice(s, 28)
        s:SetPoint("TOPLEFT", f, "TOPLEFT", -12, 10)
        s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 12, -14)
        s:SetVertexColor(0, 0, 0, 0.6)
        f.wuiShadow = s
    end
    -- The ring stands in for a coloured border: hidden at rest.
    if not f.wuiRing then
        local r = f:CreateTexture(nil, "BORDER", nil, 2)
        r:SetTexture(ns.Media.ring)
        slice(r, 8)
        r:SetAllPoints()
        r:Hide()
        f.wuiRing = r
    end
    f.wuiBorder = f.wuiBorder or {}
    ns:SetBorderColor(f, opts.border or "border")
    f.wuiTemplate = template or "Default"
    f.wuiModern = true
    ns.skinned = ns.skinned or setmetatable({}, { __mode = "k" })
    ns.skinned[f] = true
    return f
end

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
    -- A black edge one pixel outside the border. It is what makes a flat
    -- panel read as a solid object against the world rather than as an
    -- outline drawn on it. Kept apart from the border, which recolours.
    local e = {}
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local t = f:CreateTexture(nil, "BORDER", nil, 0)
        t:SetColorTexture(0, 0, 0, 1)
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
        e[side] = t
    end
    f.wuiEdge = e
    return b
end

local function layoutBorder(f)
    local b = f.wuiBorder
    local px = ns.mult or 1
    b.top:ClearAllPoints();    b.top:SetPoint("TOPLEFT");     b.top:SetPoint("TOPRIGHT");     b.top:SetHeight(px)
    b.bottom:ClearAllPoints(); b.bottom:SetPoint("BOTTOMLEFT"); b.bottom:SetPoint("BOTTOMRIGHT"); b.bottom:SetHeight(px)
    b.left:ClearAllPoints();   b.left:SetPoint("TOPLEFT");    b.left:SetPoint("BOTTOMLEFT");  b.left:SetWidth(px)
    b.right:ClearAllPoints();  b.right:SetPoint("TOPRIGHT");  b.right:SetPoint("BOTTOMRIGHT"); b.right:SetWidth(px)
    local e = f.wuiEdge
    if e then
        e.top:ClearAllPoints();    e.top:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -px, 0);      e.top:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", px, 0);      e.top:SetHeight(px)
        e.bottom:ClearAllPoints(); e.bottom:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -px, 0);   e.bottom:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", px, 0);   e.bottom:SetHeight(px)
        e.left:ClearAllPoints();   e.left:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0);         e.left:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 0, 0);    e.left:SetWidth(px)
        e.right:ClearAllPoints();  e.right:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, 0);        e.right:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, 0);   e.right:SetWidth(px)
        local show = ns:G().edges ~= false
        for _, t in pairs(e) do t:SetShown(show) end
    end
end

-- Paint a frame as a Wick panel. template: Default, Transparent, Shadow
-- or None (border only).
function ns:SetTemplate(f, template, opts)
    opts = opts or {}
    if ns:Modern() then return modernTemplate(f, template, opts) end
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
    -- Modern: the resting border is no line at all; any other colour is
    -- the rounded ring in that colour.
    if f.wuiModern then
        local r = f.wuiRing
        if not r then return end
        if color == "border" or color == nil then
            r:Hide()
        else
            local c = type(color) == "string" and (C[color] or C.fel) or color
            r:SetVertexColor(c[1] or c.r, c[2] or c.g, c[3] or c.b, alpha or 1)
            r:Show()
        end
        return
    end
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
        if f.wuiBorder and not f.wuiModern then layoutBorder(f) end
    end
end

-- ============================================================
-- Widgets built on the template
-- ============================================================

-- A plain colour fill: flat in the crisp style, rounded in the modern one,
-- so hover, press and active overlays follow the button's corners.
function ns:Fill(tex, r, g, b, a)
    if ns:Modern() then
        tex:SetTexture(ns.Media.rounded)
        if tex.SetTextureSliceMargins then tex:SetTextureSliceMargins(8, 8, 8, 8) end
        tex:SetVertexColor(r, g, b, a or 1)
    else
        tex:SetColorTexture(r, g, b, a or 1)
    end
end

-- Icon cropped to lose Blizzard's baked-in border. In the modern style
-- the icon also gets the rounded mask, so its corners follow the panel.
function ns:CropIcon(tex, zoom)
    local z = zoom or 0.08
    tex:SetTexCoord(z, 1 - z, z, 1 - z)
    if ns:Modern() and tex.AddMaskTexture and tex.GetParent then
        local parent = tex:GetParent()
        if parent and parent.CreateMaskTexture and not tex.wuiMask then
            local m = parent:CreateMaskTexture()
            m:SetTexture(ns.Media.roundmask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            m:SetAllPoints(tex)
            tex:AddMaskTexture(m)
            tex.wuiMask = m
        end
    end
end

-- Aura icons carry their own time-left text. The game's cooldown numbers
-- (switched on for the action bars) would draw a second countdown on the
-- swirl, so they are hidden on every aura button.
-- A font object whose text is fully transparent. The aura container
-- re-shows the countdown text whenever it redraws an icon, which undoes a
-- hide or an alpha; the font it draws in is left alone, so the countdown
-- goes on drawing, invisibly.
local noCountdown
local function invisibleFont()
    if noCountdown then return noCountdown end
    noCountdown = CreateFont("WicksUI_NoCountdown")
    noCountdown:SetFont("Fonts\\ARIALN.TTF", 8, "")
    noCountdown:SetTextColor(0, 0, 0, 0)
    noCountdown:SetShadowColor(0, 0, 0, 0)
    return noCountdown
end

-- An aura's time is the client's own countdown on its cooldown, centred
-- and in our font. Ours (the aura library's duration text) is not made:
-- the client's aura container keeps its countdown on however often it is
-- switched off, so two timers showed. One, the client's, it is.
local countdownFonts = {}
local function countdownFont(size)
    size = math.max(8, math.floor(size + 0.5))
    local f = countdownFonts[size]
    if not f then
        f = CreateFont("WicksUI_AuraCountdown" .. size)
        f:SetFont(ns.Media:Font(), size, "OUTLINE")
        f:SetTextColor(1, 1, 1, 1)
        countdownFonts[size] = f
    end
    return f
end

-- The font handed over at creation does not hold (the container sets its
-- own back), so the countdown's text is set directly and looked at again
-- every frame: our font, sized to the icon.
local countdowns = setmetatable({}, { __mode = "k" })
local auraButtons = setmetatable({}, { __mode = "k" })
local function sizeText(fs, path, size)
    local f, sz = fs:GetFont()
    if f ~= path or not sz or math.abs(sz - size) > 0.5 then
        fs:SetFont(path, size, "OUTLINE")
        fs:SetShadowOffset(0, 0)
    end
end
-- Every piece of text on an aura button, and on the frames just inside it
-- (the cooldown's countdown, the container's own time), in our font at the
-- icon's size: whichever of them the client draws the time with.
local function sizeAll(frame, path, size, depth)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "FontString" then sizeText(r, path, size) end
    end
    if depth < 2 then
        for _, c in ipairs({ frame:GetChildren() }) do sizeAll(c, path, size, depth + 1) end
    end
end
local cdTicker = CreateFrame("Frame")
cdTicker:SetScript("OnUpdate", function()
    local path = ns.Media:Font()
    for cd, size in pairs(countdowns) do
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        if fs then sizeText(fs, path, size) end
    end
    for b, size in pairs(auraButtons) do sizeAll(b, path, size, 0) end
end)

function ns:AuraCountdown(button, iconSize, show)
    local cd = button and button.Cooldown
    if not cd then return end
    cd.noCooldownCount = true   -- OmniCC-style addons stay off it
    if show == false then return ns:QuietAuraCooldown(button) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    local size = math.max(8, math.floor((iconSize or 24) * 0.42 + 0.5))
    if cd.SetCountdownFont then pcall(cd.SetCountdownFont, cd, countdownFont(size):GetName()) end
    countdowns[cd] = size
    auraButtons[button] = size
end

function ns:QuietAuraCooldown(button)
    local cd = button and button.Cooldown
    if not cd then return end
    if cd.SetCountdownFont then pcall(cd.SetCountdownFont, cd, invisibleFont():GetName()) end
    -- The aura container turns the numbers back on when it redraws the
    -- button, so the switch alone does not hold. The countdown's own text
    -- is faded as well, which the container leaves alone.
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
    if fs then fs:SetAlpha(0) end
    cd.noCooldownCount = true   -- and OmniCC-style addons stay off it too
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

-- ============================================================
-- Glyph buttons
-- ============================================================
-- Blizzard's small buttons (page arrows, dropdown arrows, minimise, gear)
-- carry their mark inside a bevelled square of their own art; on our tiles
-- that reads as a box in a box. glyph() puts the button's art away and
-- draws one of our flat marks on a black tile instead: the mark in the text
-- colour, a second copy in the accent on the highlight layer, which the
-- client shows on mouseover by itself (no hook on Blizzard's scripts).
-- Called again, it only swaps the mark, so a toggle can change direction.
local glyphs = setmetatable({}, { __mode = "k" })
ns.glyphs = glyphs

function ns:Glyph(b, name, opts)
    if not b then return end
    opts = opts or {}
    local g = glyphs[b]
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t and t:GetAlpha() > 0 then t:SetAlpha(0) end
    end
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetAlpha() > 0 and not (g and (r == g.mark or r == g.hover)) then
            r:SetAlpha(0)
        end
    end
    if not g then
        g = {}
        glyphs[b] = g
        local size = opts.size or 14
        if opts.tile ~= false then
            local t = CreateFrame("Frame", nil, b)
            t:SetPoint("CENTER", 0, 0)
            t:SetSize(opts.tileSize or math.min(22, math.max(16, (b:GetWidth() or 20) - 2)), opts.tileSize or math.min(22, math.max(16, (b:GetHeight() or 20) - 2)))
            t:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
            ns:SetTemplate(t, "Default", { alpha = 0.9, shadow = false })
            g.tile = t
        end
        local mark = b:CreateTexture(nil, "OVERLAY", nil, 6)
        mark:SetSize(size, size)
        mark:SetPoint("CENTER", 0, 0)
        mark:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
        g.mark = mark
        local hover = b:CreateTexture(nil, "HIGHLIGHT", nil, 6)
        hover:SetSize(size, size)
        hover:SetPoint("CENTER", 0, 0)
        hover:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        g.hover = hover
    end
    if g.name ~= name then
        g.name = name
        g.mark:SetTexture(ns.Media:Glyph(name))
        g.hover:SetTexture(ns.Media:Glyph(name))
    end
    return g
end

-- Which way a Blizzard arrow button points, read from its art: the old page
-- arrows by file, the newer ones by atlas name. nil when it cannot tell.
local ARROW_FILES = {
    [130869] = "left", [130868] = "left", [130867] = "left",
    [130866] = "right", [130865] = "right", [130864] = "right",
}
function ns:ArrowDirection(b)
    for _, get in ipairs({ "GetNormalTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then
            local a = t.GetAtlas and t:GetAtlas()
            if a then
                a = a:lower()
                for _, dir in ipairs({ "left", "right", "down", "up" }) do
                    if a:find(dir) then return dir end
                end
                if a:find("prev") or a:find("back") then return "left" end
                if a:find("next") or a:find("forward") then return "right" end
                if a:find("collapse") then return "minus" end
                if a:find("expand") then return "plus" end
            end
            local f = t.GetTexture and t:GetTexture()
            if type(f) == "number" and ARROW_FILES[f] then return ARROW_FILES[f] end
            if type(f) == "string" then
                local l = f:lower()
                if l:find("prevpage") then return "left" end
                if l:find("nextpage") then return "right" end
                if l:find("scrollup") then return "up" end
                if l:find("scrolldown") then return "down" end
            end
        end
    end
end

-- ============================================================
-- Scroll bars
-- ============================================================
-- One look for every scroll bar, the one the options panel draws: a slim
-- track in the border colour and a thumb in the accent, both 4 px, and no
-- arrow buttons (they stay clickable, drawn by nothing). Blizzard's modern
-- scroll bars carry Track, Track.Thumb, Back and Forward.
local scrolled = setmetatable({}, { __mode = "k" })
function ns:StyleScrollBar(sb)
    if not sb or scrolled[sb] then return end
    local track = sb.Track
    if not track then return end
    scrolled[sb] = true
    for _, r in ipairs({ track:GetRegions() }) do
        if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
    for _, k in ipairs({ "Begin", "Middle", "End" }) do
        if track[k] and track[k].SetAlpha then track[k]:SetAlpha(0) end
    end
    local line = track:CreateTexture(nil, "BACKGROUND")
    line:SetPoint("TOP", 0, 0)
    line:SetPoint("BOTTOM", 0, 0)
    line:SetWidth(4)
    ns:Fill(line, C.border[1], C.border[2], C.border[3], 0.6)
    local thumb = track.Thumb
    if thumb then
        for _, r in ipairs({ thumb:GetRegions() }) do
            if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
        end
        for _, k in ipairs({ "Begin", "Middle", "End" }) do
            if thumb[k] and thumb[k].SetAlpha then thumb[k]:SetAlpha(0) end
        end
        local fill = thumb:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOP", 0, 0)
        fill:SetPoint("BOTTOM", 0, 0)
        fill:SetWidth(4)
        ns:Fill(fill, C.fel[1], C.fel[2], C.fel[3], 0.8)
    end
    for _, k in ipairs({ "Back", "Forward" }) do
        local b = sb[k]
        if b and b.SetAlpha then b:SetAlpha(0) end
    end
end
