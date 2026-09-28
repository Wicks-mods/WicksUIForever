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
    ns:UpdatePixel()
    ns:ApplyScale()
    ns:InitializeModules()
    ns.Movers:PlaceAll()

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

    if not ns:G().installed then
        self:Print("loaded. Type |cff4FC778/wui|r for the settings, |cff4FC778/wui move|r to place frames, |cff4FC778/wui kb|r to bind keys.")
        ns:G().installed = true
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
}

A:RegisterSlash(function(_, msg)
    local cmd = (msg or ""):lower()
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns.Config:Toggle()
    elseif cmd == "move" or cmd == "moveui" or cmd == "unlock" then
        ns.Movers:Toggle()
    elseif cmd == "kb" or cmd == "bind" or cmd == "keybind" then
        if ns.Keybind then ns.Keybind:Toggle() end
    elseif cmd == "reset" then
        W:Confirm("Put every frame back where it started?", function() ns.Movers:ResetAll() end, "Reset")
    elseif cmd == "errors" then
        if not ns.errors or #ns.errors == 0 then
            A:Print("nothing reported.")
        else
            for _, e in ipairs(ns.errors) do A:Print(e) end
        end
    else
        for _, line in ipairs(HELP) do A:Print(line) end
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
    L:Toggle("Fel corners on panels", "brackets", { tooltip = "The Wick L-bracket corners on the larger panels. Takes effect after a reload." })

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
    L:Dropdown("Class colours", "classColorSet", {
        { "client", "The game's own" }, { "classic", "Classic era" },
    }, {
        get = function() return Chrome.classColorSet or "client" end,
        setter = function(v) if Chrome.SetClassColorSet then Chrome:SetClassColorSet(v) end end,
        tooltip = "Shared with every Wick addon. The Classic set is the one the original game used.",
    })

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
