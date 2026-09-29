-- Wick's UI
-- Core/Load.lua: startup, the general and profile pages, slash commands.
--
-- Last in the TOC, so every module has registered its defaults and its
-- settings pages by the time anything here runs.

local ADDON, ns = ...

local A = ns.A
local Core = ns.Core
local Chrome = Core.Chrome
local W = ns.Widgets

-- ============================================================
-- UI scale
-- ============================================================
-- The game's own scale setting, set from here. Below 0.64 the game will
-- not go, so a pixel-perfect scale on a 1440p or 4k screen stops there,
-- and the borders stay one pixel anyway because they are drawn at the
-- physical pixel size rather than a fixed one.
local function cvar(name, value)
    local CV = rawget(_G, "C_CVar")
    if CV and CV.SetCVar then return pcall(CV.SetCVar, name, value) end
end

function ns:PixelPerfectScale()
    local _, h = GetPhysicalScreenSize()
    if not h or h == 0 then return 1 end
    return math.max(0.64, math.min(1.15, 768 / h))
end

function ns:ApplyScale()
    local s = ns:G().uiScale or 0
    if s > 0 then
        ns:AfterCombat("uiscale", function()
            cvar("useUiScale", "1")
            cvar("uiScale", tostring(s))
        end)
    end
    ns:UpdatePixel()
    ns:RefreshBorders()
end

ns:On("UI_SCALE_CHANGED", function() ns:UpdatePixel(); ns:RefreshBorders() end)
ns:On("DISPLAY_SIZE_CHANGED", function() ns:UpdatePixel(); ns:RefreshBorders() end)

-- ============================================================
-- Style presets
-- ============================================================
-- A style needs its own spacing: the modern look is airier, with larger
-- buttons and room for the name above each bar. Applied once when a
-- profile first meets the style, or on request; sizes only, never
-- positions, and afterwards the player's own sizes stand.
local PRESETS = {
    modern = {
        bars = { size = 38, spacing = 6 },
        units = { player = 50, target = 50, focus = 44, focustarget = 34, targettarget = 34, pet = 34, boss = 44, party = 46, raid = 44 },
    },
    wick = {
        bars = { size = 34, spacing = 2 },
        units = { player = 40, target = 40, focus = 32, focustarget = 26, targettarget = 26, pet = 26, boss = 36, party = 40, raid = 42 },
    },
}

-- The key a style's sizes are kept under. Wick OG predates the others and
-- is saved as "wick"; the rest by their own id.
local function styleKey()
    local Chrome = ns.Core and ns.Core.Chrome
    local id = Chrome and Chrome.StyleID and Chrome:StyleID() or (ns:Modern() and "modern" or "og")
    return id == "og" and "wick" or id
end

local function presetFor(key)
    if PRESETS[key] then return PRESETS[key] end
    return ns:Modern() and PRESETS.modern or PRESETS.wick
end

-- Each style keeps the player's own sizes, frame positions, health colours
-- and the minimap's shape (round
-- suits one style, square the other): leaving a style saves what it had
-- (general settings are per profile), and coming back to it puts them
-- back. The preset is only for a style this profile has never been in, or
-- on request, and it never touches the minimap.
local MINIMAP_KEYS = { "square", "ring", "fill" }
local function takeSizes(prof)
    local out = { bars = {}, units = {} }
    for id, d in pairs(prof.actionbars and prof.actionbars.bars or {}) do
        out.bars[id] = { size = d.size, spacing = d.spacing }
    end
    for key, u in pairs(prof.unitframes and prof.unitframes.units or {}) do
        out.units[key] = { width = u.width, height = u.height }
    end
    out.healthColor = prof.unitframes and prof.unitframes.healthColor
    -- Where the frames sit: a style's shadows and borders can need a frame
    -- a few pixels off where another style had it.
    if prof.movers then
        out.movers = {}
        for name, point in pairs(prof.movers) do out.movers[name] = point end
    end
    local mm = prof.minimap
    if mm then
        out.minimap = {}
        for _, k in ipairs(MINIMAP_KEYS) do out.minimap[k] = mm[k] end
    end
    return out
end

local function putSizes(prof, saved)
    for id, s in pairs(saved.bars or {}) do
        local d = prof.actionbars and prof.actionbars.bars and prof.actionbars.bars[id]
        if d then d.size, d.spacing = s.size, s.spacing end
    end
    for key, s in pairs(saved.units or {}) do
        local u = prof.unitframes and prof.unitframes.units and prof.unitframes.units[key]
        if u then u.width, u.height = s.width or u.width, s.height or u.height end
    end
    if saved.healthColor and prof.unitframes then prof.unitframes.healthColor = saved.healthColor end
    if saved.movers and prof.movers then
        for name in pairs(prof.movers) do prof.movers[name] = nil end
        for name, point in pairs(saved.movers) do prof.movers[name] = point end
    end
    if saved.minimap and prof.minimap then
        for _, k in ipairs(MINIMAP_KEYS) do
            if saved.minimap[k] ~= nil then prof.minimap[k] = saved.minimap[k] end
        end
    end
end

-- Health colours. A look with colours of its own starts in them, once per
-- profile, even for a profile already in that look before it had them;
-- after that the player's choice stands, kept per style like the sizes. A
-- style without them never keeps the setting, which would mean nothing.
local function lookHealth(g, style)
    local uf = ns.A.db.profile.unitframes
    local Chrome = ns.Core and ns.Core.Chrome
    local st = Chrome and Chrome.StyleDef and Chrome:StyleDef()
    if not uf then return end
    g.lookHealth = g.lookHealth or {}
    if st and st.health then
        if not g.lookHealth[style] then
            uf.healthColor = "look"
            g.lookHealth[style] = true
        end
    elseif uf.healthColor == "look" then
        uf.healthColor = "class"
    end
end

function ns:ApplyStylePreset(force)
    local g = ns:G()
    local style = styleKey()
    if not force and g.presetFor == style then lookHealth(g, style) return end
    local p = presetFor(style)
    if not p then return end
    local prof = ns.A.db.profile
    g.styleSizes = g.styleSizes or {}
    -- What the style being left had, kept for coming back to it.
    if g.presetFor and g.presetFor ~= style then
        g.styleSizes[g.presetFor] = takeSizes(prof)
    end
    local saved = g.styleSizes[style]
    if saved and not force then
        putSizes(prof, saved)
    else
        if prof.actionbars and prof.actionbars.bars then
            for _, d in pairs(prof.actionbars.bars) do
                d.size, d.spacing = p.bars.size, p.bars.spacing
            end
        end
        local uf = prof.unitframes and prof.unitframes.units
        if uf then
            for key, h in pairs(p.units) do
                if uf[key] then uf[key].height = h end
            end
        end
    end
    g.presetFor = style
    -- After the style left behind was saved and this one's put back.
    lookHealth(g, style)
end

-- ============================================================
-- Profile changes
-- ============================================================
local function onProfileChanged()
    ns:AfterCombat("profile", function()
        ns:ApplyScale()
        ns.Movers:PlaceAll()
        ns:RefreshStatusbars()
        ns:UpdateAll()
        for key in pairs(ns.Config.pages) do ns.Config:Rebuild(key) end
    end)
end

-- ============================================================
-- Lifecycle
-- ============================================================
function A:OnInitialize()
    self.db:On("OnProfileChanged", onProfileChanged)
    self.db:On("OnProfileReset", onProfileChanged)
end

function A:OnEnable()
    -- WickCore runs this protected and keeps quiet about failures unless
    -- its debug is on. A UI that fails to start must say so.
    -- A short-lived build moved profiles to the shaded texture. Flat is
    -- the default again, with colour strength taking the glare off, so
    -- that move is undone once.
    local g = ns:G()
    if g.shadedDefault and not g.flatRestored then
        if g.statusbar == "Wick Shaded" then g.statusbar = "Wick Flat" end
        g.flatRestored = true
    end
    ns:ApplyStylePreset(false)
    -- Unit frames spent a day on Friz Quadrata while no good narrow face
    -- was bundled. Profiles still on that default move to the bundled one.
    local uf = ns.A.db.profile.unitframes
    if uf and not g.ptSans then
        if uf.font == "Friz Quadrata" then uf.font = "Wick" end
        g.ptSans = true
    end
    local ok, err = xpcall(function()
        ns:UpdatePixel()
        ns:ApplyScale()
        ns:InitializeModules()
        ns.Movers:PlaceAll()
    end, function(e) return tostring(e) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "") end)
    if not ok then
        ns.errors = ns.errors or {}
        ns.errors[#ns.errors + 1] = "startup: " .. tostring(err)
        self:Print("|cffff6060failed to start|r: " .. tostring(err):match("^[^\n]*"))
    end

    self:RegisterLauncher({
        onClick = function(_, button)
            if button == "RightButton" then ns.Movers:Toggle() else ns.Config:Toggle() end
        end,
        tooltip = function(tt)
            tt:AddLine(Chrome:TitleMarkup("Wick's UI"))
            tt:AddLine("Click for the settings.", 0.5, 0.5, 0.5)
            tt:AddLine("Right-click to move frames.", 0.5, 0.5, 0.5)
        end,
    })

    -- One line in WickCore's own panel, pointing here.
    self:RegisterOptions(function(page, addon)
        local O = Core.Options
        local y = O:Heading(page, "Wick's UI", 0)
        y = O:Note(page, "Wick's UI has its own settings window, with a page for every part of the interface.", y)
        y = O:Button(page, "Open the settings", function() ns.Config:Open() end, y - 2, 150)
        y = O:Button(page, "Move frames", function() ns.Movers:Unlock() end, y - 2, 150)
    end)

    if not ns:G().installed and ns.Install then
        C_Timer.After(2, function() ns:AfterCombat("install", function() ns.Install:Show(1) end) end)
    end
end

-- ============================================================
-- Slash command
-- ============================================================
local HELP = {
    "/wui  settings",
    "/wui move  unlock frames to drag them",
    "/wui kb  hover keybinding",
    "/wui reset  put every frame back where it started",
    "/wui errors  anything a module reported",
    "/wui install  run the first-time setup again",
    "/wui skin  skin the window under the pointer, and keep skinning it",
    "/wui inspect  list what is under the pointer, for fixing a skin",
    "/wui inspect Name.Key  the same for a frame by the name /fstack shows",
    "/wui inspect auras  the first aura on your target's frame (auras:player for yours)",
    "/wui unskin [name]  undo the last /wui skin, or the named one",
}

local function slash(_, msg)
    local cmd = (msg or ""):lower()
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.Config:Toggle()
    elseif cmd == "move" or cmd == "moveui" or cmd == "unlock" then
        ns.Movers:Toggle()
    elseif cmd == "kb" or cmd == "bind" or cmd == "keybind" then
        if ns.Keybind then ns.Keybind:Toggle() end
    elseif cmd == "reset" then
        W:Confirm("Put every frame back where it started?", function() ns.Movers:ResetAll() end, "Reset")
    elseif cmd:match("^inspect") then
        if ns.Inspect then ns.Inspect:Run((msg or ""):match("^%S+%s+(%S+)")) end
    elseif cmd == "skin" then
        if ns.PanelSkins then ns.PanelSkins:SkinUnderMouse() end
    elseif cmd:match("^unskin") then
        if ns.PanelSkins then ns.PanelSkins:Unskin((msg or ""):match("^%S+%s+(%S+)")) end
    elseif cmd == "install" or cmd == "setup" then
        if ns.Install then ns.Install:Show(1) end
    elseif cmd == "errors" then
        if not ns.errors or #ns.errors == 0 then
            A:Print("nothing reported.")
        else
            for _, e in ipairs(ns.errors) do A:Print(e) end
        end
    else
        for _, line in ipairs(HELP) do A:Print(line) end
    end
end

-- WickCore's slash wrapper keeps quiet about an error unless its debug is
-- on, which made a failing command look like one that did nothing. Ours
-- says so.
A:RegisterSlash(function(self, msg)
    local ok, err = pcall(slash, self, msg)
    if not ok then
        A:Print("|cffff6060that command failed:|r " .. tostring(err))
        ns.errors = ns.errors or {}
        ns.errors[#ns.errors + 1] = "slash: " .. tostring(err)
    end
end, "/wui", "/wicksui")

-- ElvUI players type these from habit.
if not SlashCmdList["MOVEUI"] then
    _G.SLASH_WICKSUIMOVE1 = "/moveui"
    SlashCmdList["WICKSUIMOVE"] = function() ns.Movers:Toggle() end
end
if not SlashCmdList["KEYBIND"] and not rawget(_G, "SLASH_KB1") then
    _G.SLASH_WICKSUIKB1 = "/kb"
    SlashCmdList["WICKSUIKB"] = function() if ns.Keybind then ns.Keybind:Toggle() end end
end

-- ============================================================
-- The General page
-- ============================================================
ns.Config:AddPage("general", "General", function(L)
    L:DB(function() return ns:G() end)
    L:Heading("Scale")
    L:Note("The game's own interface scale. 0 leaves it alone. Pixel perfect picks the scale that makes one interface pixel one screen pixel, as near as the game allows.")
    L:Slider("Interface scale", "uiScale", 0, 1.15, 0.01, { set = function() ns:ApplyScale() end })
    L:Button("Pixel perfect", function()
        ns:G().uiScale = ns:Round(ns:PixelPerfectScale(), 4)
        ns:ApplyScale()
    end)
    L:Toggle("Crisp borders", "pixelPerfect", { tooltip = "Draw borders one physical pixel wide at any scale.", set = function() ns:UpdatePixel(); ns:RefreshBorders() end })
    L:Toggle("Black edge around panels", "edges", { tooltip = "A one-pixel black line outside every border, which is what makes flat panels look solid.", set = function() ns:RefreshBorders() end })
    L:Toggle("Fel corners on panels", "brackets", { tooltip = "The Wick L-bracket corners on the larger panels. Takes effect after a reload." })

    L:Heading("Appearance")
    L:Note("Shared by the whole suite: every Wick addon follows these, and they are the same settings WickCore's own panel shows.")
    L:Dropdown("Style", "style", function()
        local out = {}
        for _, st in ipairs(Chrome.Styles or {}) do out[#out + 1] = { st.id, st.name } end
        return out
    end, {
        get = function() return Chrome.StyleID and Chrome:StyleID() or "modern" end,
        setter = function(v)
            if v == Chrome:StyleID() then return end
            local st = Chrome.StyleByID[v]
            ns.Widgets:Confirm(("%s: %s\n\nChanging the style rebuilds every frame, and every Wick addon follows it, so the interface reloads. Reload now?"):format(st.name, st.blurb), function()
                -- The suite's style lives in WickCore; the whole suite follows.
                Chrome:SetStyle(v)
                ReloadUI()
            end, "Reload")
        end,
        tooltip = "The shape everything is drawn in, across the suite. Each style keeps its own frame positions, button sizes, frame heights, health colours and minimap shape.",
    })
    L:Dropdown("Class colours", "classColorSet", {
        { "client", "The game's own" }, { "classic", "Classic era" },
    }, {
        get = function() return Chrome.classColorSet or "client" end,
        setter = function(v) if Chrome.SetClassColorSet then Chrome:SetClassColorSet(v) end end,
        tooltip = "The Classic set is the one the original game used.",
    })
    L:Button("Apply the style's spacing again", function()
        ns:ApplyStylePreset(true)
        ns:UpdateAll()
    end, { tooltip = "Button sizes, gaps and frame heights to suit the style, for this profile only. Your positions are kept." })
    -- The theme picker is WickCore's own, so the two panels can never
    -- show different things.
    local O = ns.Core and ns.Core.Options
    if O and O.ThemeSection then
        local holder = CreateFrame("Frame", nil, L.content)
        holder:SetWidth(524)
        local h = -O:ThemeSection(holder, 0, 0, { width = 524, noExtras = true })
        holder:SetHeight(math.max(20, h))
        L:Custom(holder)
    end

    L:Heading("Look")
    L:Dropdown("Font", "font", function()
        local out = {}
        for _, name in ipairs(ns.Media:List("font")) do out[#out + 1] = { name, name, name } end
        return out
    end)
    L:Dropdown("Outline", "fontOutline", W.Values(ns.Media.outlines))
    L:Slider("Font size", "fontSize", 8, 20, 1)
    L:Dropdown("Bar texture", "statusbar", function() return W.Values(ns.Media:List("statusbar")) end,
        { set = function() ns:RefreshStatusbars() end })

    L:Heading("Frames")
    L:Button("Move frames", function() ns.Config:Hide(); ns.Movers:Unlock() end)
    L:Button("Keybind mode", function() ns.Config:Hide(); if ns.Keybind then ns.Keybind:Activate() end end)
    L:Button("Reset every position", function()
        W:Confirm("Put every frame back where it started?", function() ns.Movers:ResetAll() end, "Reset")
    end)
    L:Button("Edit Mode", function()
        if EditModeManagerFrame and ShowUIPanel then ShowUIPanel(EditModeManagerFrame) end
    end, { tooltip = "The game's own layout editor, for the frames Wick's UI leaves to the game: the extra action button, the vehicle exit, the micro menu, the objective tracker and so on." })
end, { onChange = function() ns:UpdateAll() end, order = 1 })

-- ============================================================
-- Profiles
-- ============================================================
ns.Config:AddPage("profiles", "Profiles", function(L)
    local db = A.db
    L:Note("Profiles hold every setting and every frame position. Several characters can share one.")
    L:Dropdown("Current profile", "profile", function() return W.Values(db:GetProfiles()) end, {
        get = function() return db:GetCurrentProfile() end,
        setter = function(v) db:SetProfile(v) end,
    })
    L:Dropdown("One profile per", "keyMode", {
        { "char", "Character" }, { "spec", "Specialization" }, { "class", "Class" }, { "mode", "Game mode" },
    }, {
        get = function() return db:GetKeyMode() end,
        setter = function(v) db:SetKeyMode(v) end,
        tooltip = "Specialization switches profile when you change spec, so a healing layout and a damage layout can live side by side.",
    })
    L:Input("New profile", "new", {
        get = function() return "" end,
        setter = function(v) if v and v ~= "" then db:SetProfile(v) end end,
        tooltip = "Type a name and press Enter. It starts from the defaults.",
    })
    L:Dropdown("Copy from", "copy", function() return W.Values(db:GetProfiles()) end, {
        get = function() return "" end,
        setter = function(v)
            W:Confirm(("Copy everything from %s into %s?"):format(v, db:GetCurrentProfile()), function() db:CopyProfile(v) end, "Copy")
        end,
    })
    L:Button("Reset this profile", function()
        W:Confirm("Put every setting in this profile back to its default?", function() db:ResetProfile() end, "Reset")
    end)
    L:Dropdown("Delete a profile", "delete", function()
        local out = {}
        for _, n in ipairs(db:GetProfiles()) do
            if n ~= db:GetCurrentProfile() and n ~= "Default" then out[#out + 1] = { n, n } end
        end
        return out
    end, {
        get = function() return "" end,
        setter = function(v) W:Confirm(("Delete the profile %s?"):format(v), function() db:DeleteProfile(v) end, "Delete") end,
    })
    L:Heading("Share")
    L:Note("An export string carries the whole profile, positions included, and can be pasted into another account or posted for other players.")
    L:Button("Export", function()
        local text = db:Export()
        Core.Options:ShowExport(A, text, function(str)
            local ok, err = db:Import(str)
            if ok then A:Print("profile imported.") else A:Print("that string did not import: " .. tostring(err)) end
        end)
    end)
end, { onChange = function() end, order = 900 })
