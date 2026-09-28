-- Wick's UI
-- Core/Init.lua: the addon object, the module registry and the defaults.
--
-- Every part of the interface is a module. A module declares its defaults
-- at file scope, before the saved variable is read, and is given an
-- Initialize at login and an Update whenever a setting or the profile
-- changes. A module that is switched off never builds anything, so the
-- matching Blizzard frame is left exactly as the game made it.

local ADDON, ns = ...

local Core = WickCore
ns.Core = Core
ns.name = ADDON
ns.title = "Wick's UI"
ns.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "0.1.0"

-- The embedded oUF names itself from our TOC (X-oUF) and lives in ns.oUF.
-- Everything else reaches the libraries through LibStub.
ns.LAB = LibStub("LibActionButton-1.0")

-- ============================================================
-- Defaults
-- ============================================================
-- Modules add their own table under profile[key] as their file loads.
-- Profiles apply these once, at ADDON_LOADED, so the order of files in
-- the TOC only has to put this one first.
ns.defaults = {
    profile = {
        general = {
            uiScale      = 0,        -- 0 means leave the game's own setting alone
            pixelPerfect = true,
            font         = "Wick",
            fontSize     = 12,
            fontOutline  = "OUTLINE",
            statusbar    = "Wick Flat",
            brackets     = true,     -- fel-green corners on the bigger panels
            edges        = true,     -- a black pixel outside every border
            style        = "modern", -- "modern" = Wick Modern (default), "wick" = Wick OG; the ids are saved, the names are labels
            classColors  = true,
            moversLocked = true,
            installed    = false,
        },
        movers = {},                 -- mover name -> "POINT,relativeTo,relPoint,x,y"
    },
    global = {
        configPos = nil,
    },
    char = {},
}

-- ============================================================
-- Modules
-- ============================================================
ns.modules = {}
ns.moduleOrder = {}

local ModuleProto = {}
ModuleProto.__index = ModuleProto

-- The module's settings, always from the live profile. Never cache the
-- returned table past a single call: a profile switch replaces it.
function ModuleProto:db()
    local p = ns.A and ns.A.db and ns.A.db.profile
    return (p and p[self.key]) or ns.defaults.profile[self.key]
end

function ModuleProto:Enabled()
    local d = self:db()
    return d and d.enable ~= false
end

function ModuleProto:Print(msg) ns.A:Print(msg) end

-- ns:NewModule("actionbars", { title = "Action Bars", defaults = {...} })
function ns:NewModule(key, opts)
    opts = opts or {}
    local m = setmetatable({ key = key, title = opts.title or key, order = opts.order or 100 }, ModuleProto)
    if opts.defaults then
        ns.defaults.profile[key] = opts.defaults
    end
    ns.modules[key] = m
    ns.moduleOrder[#ns.moduleOrder + 1] = m
    return m
end

function ns:GetModule(key) return ns.modules[key] end

local function sortedModules()
    table.sort(ns.moduleOrder, function(a, b)
        local ao, bo = tonumber(a.order) or 100, tonumber(b.order) or 100
        if ao ~= bo then return ao < bo end
        return a.key < b.key
    end)
    return ns.moduleOrder
end

-- Run a module method, protected, and say which module failed. A broken
-- module must never take the rest of the interface down with it.
function ns:Call(m, method, ...)
    local fn = m[method]
    if not fn then return end
    local ok, err = pcall(fn, m, ...)
    if not ok then
        ns.errors = ns.errors or {}
        ns.errors[#ns.errors + 1] = ("%s:%s %s"):format(m.key, method, tostring(err))
        ns.A:Print(("|cffff6060%s failed in %s|r: %s"):format(m.title, method, tostring(err)))
    end
    return ok
end

-- Initialize is called once. Update runs on every settings change, and
-- the module decides whether it can apply now or after combat.
function ns:InitializeModules()
    for _, m in ipairs(sortedModules()) do
        if m:Enabled() and not m.initialized then
            m.initialized = ns:Call(m, "Initialize")
        end
    end
end

function ns:UpdateAll()
    for _, m in ipairs(sortedModules()) do
        if m.initialized then
            ns:Call(m, "Update")
        elseif m:Enabled() then
            m.initialized = ns:Call(m, "Initialize")
        end
    end
end

-- ============================================================
-- The WickCore addon object
-- ============================================================
local A = Core:NewAddon(ADDON, {
    title    = ns.title,
    version  = ns.version,
    savedVar = "WicksUIDB",
    defaults = ns.defaults,
})
ns.A = A
_G.WicksUI = ns   -- for /dump and the offline harness

-- Settings, general section.
function ns:G() return (A.db and A.db.profile.general) or ns.defaults.profile.general end
