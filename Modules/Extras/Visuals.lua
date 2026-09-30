-- Wick's UI
-- Modules/Extras/Visuals.lua: picture settings the game hides.
--
-- Console variables this client has but its options panel leaves out: the
-- fog, the screen glow, the grey death screen and the like. Every one is
-- off until the player turns it on. On sets the game's own variable; off
-- puts back whatever it held before we changed it, and only while it still
-- holds our value, so a change made by hand at the console is left alone.
-- What it held is kept account-wide: the variables are the client's, not a
-- profile's, and a character whose profile has an option off must still be
-- able to put back what another character's profile changed.

local ADDON, ns = ...

local VX = ns:NewModule("visuals", { title = "Visuals", order = 91 })
ns.Visuals = VX

ns.defaults.profile.visuals = {
    enable = true,
    noFog = false, noVolumeFog = false, noGlow = false, noDeathGrey = false,
    noNether = false, noWeather = false,
    moreGrass = false, sharpen = false, bestShots = false,
}

local function db() return VX:db() end

-- Each option and the variables it sets while on. The names are from this
-- client's own console list (Wick's Probe, /wp cvars); the game's settings
-- panel offers none of them. Raids and battlegrounds keep copies of some
-- (RAID...), set with them so the option holds there too.
local OPTIONS = {
    -- showFog is not a variable on this client; this is its "full fog" distance.
    { key = "noFog",       cvars = { disableHorizonStart = "1" } },
    -- The level as well: with it above 0 the client puts volumeFog back.
    { key = "noVolumeFog", cvars = { volumeFog = "0", volumeFogLevel = "0", RAIDVolumeFog = "0", RAIDVolumeFogLevel = "0" } },
    { key = "noGlow",      cvars = { ffxGlow = "0" } },
    { key = "noDeathGrey", cvars = { ffxDeath = "0" } },
    { key = "noNether",    cvars = { ffxNether = "0" } },
    { key = "noWeather",   cvars = { weatherDensity = "0", RAIDweatherDensity = "0" } },
    { key = "moreGrass",   cvars = { groundEffectDensity = "256", groundEffectFade = "370", groundEffectDist = "500" } },
    { key = "sharpen",     cvars = { ResampleAlwaysSharpen = "1" } },
    { key = "bestShots",   cvars = { screenshotQuality = "10" } },
}
VX.OPTIONS = OPTIONS

local CV = rawget(_G, "C_CVar")
local function get(name)
    if CV and CV.GetCVar then return CV.GetCVar(name) end
    return GetCVar and GetCVar(name)
end
local function set(name, value)
    if CV and CV.SetCVar then return pcall(CV.SetCVar, name, value) end
end

-- Whether this client has the variable and lets an addon change it.
local function usable(name)
    if CV and CV.GetCVarInfo then
        local ok, value, _, _, _, locked, _, readOnly = pcall(CV.GetCVarInfo, name)
        if not ok or value == nil or locked or readOnly then return false end
        return true
    end
    return get(name) ~= nil
end

-- An option can be offered when any variable it sets is there to set; the
-- rest are skipped.
function VX:Available(key)
    for _, o in ipairs(OPTIONS) do
        if o.key == key then
            for name in pairs(o.cvars) do
                if usable(name) then return true end
            end
            return false
        end
    end
    return false
end

function VX:Apply()
    if InCombatLockdown() then
        ns:AfterCombat("visuals", function() VX:Apply() end)
        return
    end
    local d = db()
    local g = ns.A.db.global
    g.visualsWas = g.visualsWas or {}
    local was = g.visualsWas
    for _, o in ipairs(OPTIONS) do
        for name, on in pairs(o.cvars) do
            if usable(name) then
                local cur = get(name)
                if d.enable and d[o.key] then
                    if cur ~= on then
                        if was[name] == nil then was[name] = cur end
                        set(name, on)
                    end
                elseif was[name] ~= nil then
                    if cur == on then set(name, was[name]) end
                    was[name] = nil
                end
            end
        end
    end
end

function VX:Initialize()
    -- Some of these are put back by a loading screen, so again once the
    -- world is there.
    ns:On("PLAYER_ENTERING_WORLD", function() VX:Apply() end)
    self:Apply()
end

function VX:Update() self:Apply() end

-- ============================================================
-- Settings
-- ============================================================
local LOCKED = "This client does not let addons change it."

local function toggle(L, key, label, tip)
    L:Toggle(label, key, {
        disabled = function() return not VX:Available(key) end,
        tooltip = VX:Available(key) and tip or (tip .. " " .. LOCKED),
    })
end

ns.Config:AddPage("visuals", "Visuals", function(L)
    L:DB(db)
    L:Note("Picture settings the game has but leaves out of its options. Each one changes the game's own setting, so it holds with Wick's UI switched off. Switching it off here puts back what was there.")
    L:Heading("Screen effects")
    toggle(L, "noFog", "No distance fog", "Far land and sky stay clear instead of fading into haze.")
    toggle(L, "noVolumeFog", "No volumetric fog", "The low fog that fills valleys, caves and some dungeons.")
    toggle(L, "noGlow", "No screen glow", "The soft bloom laid over the whole picture.")
    toggle(L, "noDeathGrey", "No grey screen when you die", "The world keeps its colour while you are dead.")
    toggle(L, "noNether", "No haze while invisible", "The shimmer laid over the screen by invisibility effects.")
    toggle(L, "noWeather", "No weather", "No rain, snow or sandstorms.")
    L:Heading("Picture")
    toggle(L, "moreGrass", "More grass, drawn further out", "Grass and ground clutter thicker and further away than the game's Ground Clutter slider goes. It costs frame rate.")
    toggle(L, "sharpen", "Sharpen at full resolution", "The game only sharpens when the render scale is below 100%. This sharpens at 100% too; Sharpness in the game's Graphics settings sets how much.")
    toggle(L, "bestShots", "Best screenshot quality", "Screenshots are saved at the highest quality the game has.")
end, { onChange = function() VX:Apply() end, order = 91 })
