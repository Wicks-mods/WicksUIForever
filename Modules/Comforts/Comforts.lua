-- Wick's UI
-- Modules/Comforts/Comforts.lua: Wick's Comforts, folded in.
--
-- Everything Wick's Comforts does that Wick's UI did not already: richer
-- tooltips, looting, the vendor, quests, the camera and client settings,
-- the proc glow and the client's own errors. Its minimap and unit frame
-- comforts are not here, because Wick's UI has its own of both.
--
-- The feature files beside this one are Comforts' own, carried over with
-- one line changed at the top, so they behave exactly as they do there.
-- This file gives them what Comforts' core gave them (register, settings,
-- events, console variables), with the settings kept in Wick's UI's
-- profile.
--
-- Wick's Comforts stays a product of its own. While it is switched on as
-- well, this copy stands aside (every setting reads as off here), so
-- nothing happens twice, and a prompt at login offers to switch Comforts
-- off, bringing its settings across first. If Comforts is on when Wick's
-- UI is first installed, its settings are copied in straight away.

local ADDON, ns = ...

local Core = ns.Core
local W = ns.Widgets

local DEFAULTS = {
    enable = true,
    -- Tooltips
    tipItemLevel = false,
    tipIDs = false,
    tipClassColor = false,
    tipTarget = false,
    -- Loot
    autoLoot = false,
    confirmBoP = false,
    -- Vendor
    autoRepair = false,
    guildRepair = false,
    sellJunk = false,
    -- Quests
    autoAcceptQuests = false,
    autoTurnInQuests = false,
    -- The client's own settings, surfaced
    maxCameraZoom = false,
    soundInBackground = false,
    chatArrowKeys = false,
    hideProcGlow = false,
    -- A workaround for the client's own errors, which is not a preference.
    clientFixes = true,
}

local CM = ns:NewModule("comforts", { title = "Comforts", order = 97, defaults = DEFAULTS })
ns.ComfortsModule = CM

-- ============================================================
-- What Comforts' core gave its feature files
-- ============================================================
local CF = { Core = Core, modules = {} }
ns.Comforts = CF

CF.A = {
    Print = function(_, msg) ns.A:Print(msg) end,
    Debug = function(_, msg) if ns.A.Debug then ns.A:Debug(msg) end end,
}

function CF:Register(name, module)
    self.modules[name] = module
    return module
end

-- While Wick's Comforts runs as well, every setting reads as off here, so
-- the two never both act.
local OFF = {}
for k in pairs(DEFAULTS) do OFF[k] = false end
function CF.db()
    if CF.dormant then return OFF end
    return CM:db()
end

local events = {}
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    if CF.dormant or not events[event] then return end
    for _, fn in ipairs(events[event]) do
        local ok, err = pcall(fn, event, ...)
        if not ok then CF.A:Debug(("comforts: error in %s: %s"):format(event, tostring(err))) end
    end
end)
function CF:On(event, fn)
    events[event] = events[event] or {}
    table.insert(events[event], fn)
end
function CF.RegisterEvents(list)
    for _, ev in ipairs(list) do pcall(frame.RegisterEvent, frame, ev) end
end
CF.eventFrame = frame

local CV = rawget(_G, "C_CVar")
function CF.cvGet(name)
    if CV and CV.GetCVar then return CV.GetCVar(name) end
    local f = rawget(_G, "GetCVar")
    return f and f(name) or nil
end
function CF.cvSet(name, value)
    if CV and CV.SetCVar then return pcall(CV.SetCVar, name, value) end
    local f = rawget(_G, "SetCVar")
    if f then return pcall(f, name, value) end
end

function CF.IsAddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
    return f and f(name) and true or false
end
-- Wick's UI always has the minimap here.
function CF.wicksUIOwnsMinimap() return true end

function CF.Apply()
    if CF.dormant then return end
    for _, m in pairs(CF.modules) do
        if m.Apply then Core.safe(m.Apply, m) end
    end
end

-- ============================================================
-- Wick's Comforts alongside
-- ============================================================
local function comfortsOn() return CF.IsAddOnLoaded("WicksComforts") end

-- The profile Wick's Comforts is using on this character, read through
-- its own addon object, so its profile keying is respected.
local function comfortsProfile()
    for _, A in Core:IterateAddons() do
        if A ~= Core.self and (A.name == "WicksComforts" or A.title == "Wick's Comforts") then
            return A.db and A.db.profile
        end
    end
end

-- Comforts' settings into this profile. Its minimap and health bar
-- choices map onto Wick's UI's own where they ask for something.
function CM:CopyFromComforts()
    local cp = comfortsProfile()
    if type(cp) ~= "table" then return false end
    local prof = ns.A.db.profile
    prof.comforts = prof.comforts or {}
    for k in pairs(DEFAULTS) do
        if k ~= "enable" and cp[k] ~= nil then prof.comforts[k] = cp[k] end
    end
    if prof.minimap then
        if cp.squareMinimap == true then prof.minimap.square = true end
        if cp.hideMinimapZoom == true then prof.minimap.hideZoom = true end
    end
    if cp.classColorHealth == true and prof.unitframes then prof.unitframes.healthColor = "class" end
    ns:G().comfortsCopied = true
    return true
end

-- Its settings across and Comforts switched off, then WickCore's reload
-- prompt: once an addon has been switched off, the client refuses an
-- addon's own reload, so this is one the game counts as the player's.
function CM:TurnComfortsOff()
    self:CopyFromComforts()
    -- For this character only, as the setup does it.
    if ns.Install and ns.Install.disableAddOn then
        ns.Install.disableAddOn("WicksComforts")
    else
        local disable = (C_AddOns and C_AddOns.DisableAddOn) or rawget(_G, "DisableAddOn")
        local who = UnitGUID and UnitGUID("player")
        if disable and who then pcall(disable, "WicksComforts", who) end
    end
    C_Timer.After(0.1, function()
        if Core.Chrome.ReloadPrompt then
            Core.Chrome:ReloadPrompt("Wick's Comforts is switched off and its settings are in Wick's UI. Reload to finish.")
        else
            ns.A:Print("Wick's Comforts is switched off. Type /reload to finish.")
        end
    end)
end

function CM:OfferToTurnComfortsOff()
    if not comfortsOn() then return end
    W:Confirm("Wick's UI now does everything Wick's Comforts does: the tooltips, looting, the vendor, quests, the camera and the client fixes. While both are on, Wick's UI leaves those to Comforts.\n\nTurn Wick's Comforts off? Your Comforts settings come across first, and the interface reloads.",
        function() CM:TurnComfortsOff() end, "Turn it off", "Keep both")
end

-- ============================================================
-- Lifecycle
-- ============================================================
function CM:Initialize()
    CF.dormant = comfortsOn()
    -- The first time Wick's UI is set up with Comforts already running,
    -- its settings are copied in.
    local g = ns:G()
    if CF.dormant and not g.installed and not g.comfortsCopied then self:CopyFromComforts() end
    for _, m in pairs(CF.modules) do
        if m.Init then Core.safe(m.Init, m) end
    end
    CF.Apply()
    -- Which of the two keeps it is a question in the setup (Core/Install),
    -- asked at the next login while it is open; the settings page still
    -- offers to turn Comforts off.
end

function CM:Update()
    CF.Apply()
end

-- ============================================================
-- Settings
-- ============================================================
ns.Config:AddPage("comforts", "Comforts", function(L)
    L:DB(function() return CM:db() end)
    L:Note("The small comforts from Wick's Comforts, built in. Everything starts off except the client fixes.")
    if comfortsOn() then
        L:Note("|cffff9040Wick's Comforts is switched on too, so these stand aside while it runs, and its own settings (/wcomfort) are the ones in use.|r")
        L:Button("Turn Wick's Comforts off", function() CM:OfferToTurnComfortsOff() end,
            { tooltip = "Brings its settings across, switches it off and reloads the interface." })
    end

    L:Heading("Tooltips")
    L:Toggle("Item level on items", "tipItemLevel")
    L:Toggle("Item and spell IDs", "tipIDs")
    L:Toggle("Class colour on player names", "tipClassColor")
    L:Toggle("Show what a unit is targeting", "tipTarget")

    L:Heading("Looting")
    L:Toggle("Auto loot", "autoLoot", { tooltip = "Sets the game's own auto loot setting, so it keeps working when this is off." })
    L:Toggle("Confirm bind on pickup loot", "confirmBoP")

    L:Heading("At a vendor")
    L:Toggle("Repair automatically", "autoRepair")
    L:Toggle("Use guild funds to repair when allowed", "guildRepair")
    L:Toggle("Sell junk automatically", "sellJunk", { tooltip = "Grey quality items only. Nothing else is ever sold." })

    L:Heading("Quests")
    L:Toggle("Accept quests automatically", "autoAcceptQuests")
    L:Toggle("Hand quests in automatically", "autoTurnInQuests")
    L:Note("Hold Shift at any npc to get the normal dialogs back. A quest that offers a choice of rewards is never handed in for you, because there is no way to know which one you wanted.")

    L:Heading("The camera and the client")
    L:Toggle("Zoom the camera out further", "maxCameraZoom", { tooltip = "Raises the game's own maximum zoom setting to the highest this client accepts." })
    L:Toggle("Keep sound playing in the background", "soundInBackground")
    L:Toggle("Arrow keys move the cursor in chat", "chatArrowKeys",
        { tooltip = "This client hands the chat box the old behaviour, where the arrows steer your character. This gives the arrows to the text box, the way every other text box works." })
    L:Toggle("Hide the proc glow on action buttons", "hideProcGlow",
        { tooltip = "The spinning yellow overlay when a spell lights up. The button still changes as it always did; only the overlay goes." })

    L:Heading("Client errors")
    L:Toggle("Quiet errors the game itself throws", "clientFixes",
        { tooltip = "Only acts where the fault is present, such as a frame the group finder expects and this build never creates. Switching this off takes effect after a reload." })
end, { onChange = function() CM:Update() end, order = 97 })
