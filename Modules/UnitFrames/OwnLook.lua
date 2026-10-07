-- Wick's UI
-- Modules/UnitFrames/OwnLook.lua: the unit frames in a look of their own.
--
-- The suite's look is one choice for everything; a player can give the
-- unit frames (and the nameplates, which follow them) another: the whole
-- interface in Classic with Wick Modern frames, or the other way about.
-- Colours stay the suite's theme.
--
-- Every drawing call reads the look in force (Chrome:StyleDef), so the
-- frames are made, laid out and refreshed with WickCore's forced look set
-- to theirs, the way the setup window draws in Wick OG whatever the suite
-- is in. That covers each way into them: the style function oUF calls when
-- a frame is made (a party member joining, a plate appearing), the
-- module's own calls, and the health colour oUF asks for as it updates.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local oUF = ns.oUF

-- The unit frames' own look, or nil when they follow the suite's. A
-- profile setting, kept in general.
function ns:UFLook()
    local ok, g = pcall(ns.G, ns)
    local id = ok and g and g.unitFrameLook
    if id and Chrome.StyleByID and Chrome.StyleByID[id] then return id end
    return nil
end

-- fn, drawn in the unit frames' look. A look already forced (the setup's
-- own) stands; with none of their own it is a plain call.
function ns:InUFLook(fn, ...)
    local id = ns:UFLook()
    if not id or Chrome.forceStyle then return fn(...) end
    Chrome.forceStyle = id
    local function finish(ok, ...)
        Chrome.forceStyle = nil
        if not ok then error((...), 0) end
        return ...
    end
    return finish(pcall(fn, ...))
end

-- A method, run in the unit frames' look.
local function inLook(object, name)
    local f = object and object[name]
    if type(f) ~= "function" then return end
    object[name] = function(...) return ns:InUFLook(f, ...) end
end

-- The health colour oUF asks for at every update reads the look (a look's
-- own pair of colours), so it is wrapped once the frame is made.
local function wrapColor(frame)
    local h = frame and frame.Health
    if h and h.PostUpdateColor and not h.wuiInLook then
        local f = h.PostUpdateColor
        h.PostUpdateColor = function(...) return ns:InUFLook(f, ...) end
        h.wuiInLook = true
    end
end

-- The style functions, as oUF is handed them: a frame made later (a party
-- member, a plate) is made in the frames' look too.
local register = oUF.RegisterStyle
oUF.RegisterStyle = function(self, name, func)
    if name == "WicksUI" or name == "WicksUI_Nameplate" then
        local inner = func
        func = function(frame, ...)
            local r = ns:InUFLook(inner, frame, ...)
            wrapColor(frame)
            return r
        end
    end
    return register(self, name, func)
end

local UF, NP, G = ns.UnitFrames, ns.Nameplates, ns.UnitGroups
for _, name in ipairs({ "Initialize", "Update", "Configure", "ApplyColors", "UpdateBorders", "SpawnSingle",
    "SpawnBoss", "LayoutBoss", "EvalFade", "ApplyFade" }) do inLook(UF, name) end
for _, name in ipairs({ "Initialize", "Update", "Configure", "Refresh", "RefreshAll", "PlaceMarks" }) do inLook(NP, name) end
for _, name in ipairs({ "Initialize", "Update", "Spawn", "Layout", "SetTestMode" }) do inLook(G, name) end
