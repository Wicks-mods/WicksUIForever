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
    noFog = false, noGlow = false, noDeathGrey = false,
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
    { key = "noGlow",      cvars = { ffxGlow = "0" } },
    { key = "noDeathGrey", cvars = { ffxDeath = "0" } },
    { key = "noNether",    cvars = { ffxNether = "0" } },
    { key = "noWeather",   cvars = { weatherDensity = "0", RAIDweatherDensity = "0" } },
    { key = "moreGrass",   cvars = { groundEffectDensity = "256", groundEffectFade = "370", groundEffectDist = "500" } },
    { key = "sharpen",     cvars = { ResampleAlwaysSharpen = "1" } },
    { key = "bestShots",   cvars = { screenshotQuality = "10" } },
}
VX.OPTIONS = OPTIONS

-- Taken out: volumetric fog. With volumeFog, its level and the indoor
-- switch all held at 0 the fog still fades back in; the client draws it
-- whatever they say. What the option changed is put back once.
local RETIRED = { volumeFog = "0", volumeFogLevel = "0", volumeFogInterior = "0", RAIDVolumeFog = "0", RAIDVolumeFogLevel = "0" }

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
    for name, ours in pairs(RETIRED) do
        if was[name] ~= nil then
            if usable(name) and get(name) == ours then set(name, was[name]) end
            was[name] = nil
        end
    end
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
    toggle(L, "noGlow", "No screen glow", "The soft bloom laid over the whole picture.")
    toggle(L, "noDeathGrey", "No grey screen when you die", "The world keeps its colour while you are dead.")
    toggle(L, "noNether", "No haze while invisible", "The shimmer laid over the screen by invisibility effects.")
    toggle(L, "noWeather", "No weather", "No rain, snow or sandstorms.")
    L:Heading("Picture")
    toggle(L, "moreGrass", "More grass, drawn further out", "Grass and ground clutter thicker and further away than the game's Ground Clutter slider goes. It costs frame rate.")
    toggle(L, "sharpen", "Sharpen at full resolution", "The game only sharpens when the render scale is below 100%. This sharpens at 100% too; Sharpness in the game's Graphics settings sets how much.")
    toggle(L, "bestShots", "Best screenshot quality", "Screenshots are saved at the highest quality the game has.")
end, { onChange = function() VX:Apply() end, order = 91 })

-- ============================================================
-- Combat text
-- ============================================================
-- The game's floating combat text: the numbers over what you hit, and the
-- scrolling text around your own character. Most of it the game's own
-- settings leave out. Every control here reads and writes the game's own
-- setting, so the choices are account-wide and hold without Wick's UI; a
-- setting this client locks shows greyed out.
local function cvOn(name) return function() return get(name) == "1" end end
local function cvSetOn(...)
    local names = { ... }
    return function(v)
        for _, n in ipairs(names) do
            if usable(n) then set(n, v and "1" or "0") end
        end
    end
end
local function cvNum(name) return function() return tonumber(get(name) or "") or 0 end end
local function cvSetNum(name) return function(v) if usable(name) then set(name, tostring(v)) end end end
local function locked(name) return function() return not usable(name) end end
local SELF = "enableFloatingCombatText"

-- Blizzard's own combat text is an addon of its own. It loads at startup
-- when this is on, or when it is switched through the game's settings,
-- and it starts and stops listening the same way: switched from here, it
-- takes a reload. Loading it from here instead would run it tainted, and
-- it handles numbers the client keeps secret in a fight. The other
-- options are read as each line is shown, so they apply at once.
local function combatTextLoaded()
    local CA = rawget(_G, "C_AddOns")
    local fn = (CA and CA.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
    return fn and fn("Blizzard_CombatText") and true or false
end
local function setSelf(v)
    if not usable(SELF) then return end
    set(SELF, v and "1" or "0")
    if v ~= combatTextLoaded() then
        local Chrome = ns.Core.Chrome
        local text = v and "Your own combat text starts after a reload." or "Your own combat text stops after a reload."
        if Chrome.ReloadPrompt then Chrome:ReloadPrompt(text) end
    end
end
local function selfOff(name) return function() return not usable(name) or get(SELF) ~= "1" end end

local function cvToggle(L, label, name, tip, ...)
    local extra = { ... }
    L:Toggle(label, name, {
        get = cvOn(name), setter = cvSetOn(name, unpack(extra)),
        disabled = locked(name), tooltip = tip,
    })
end
local function selfToggle(L, label, name, tip)
    L:Toggle(label, name, {
        get = cvOn(name), setter = cvSetOn(name),
        disabled = selfOff(name), tooltip = tip,
    })
end

ns.Config:AddPage("combattext", "Combat text", function(L)
    L:Note("The game's floating combat text. These are the game's own settings, so they are account-wide and hold with Wick's UI switched off. The font follows the look.")
    L:Heading("Numbers over what you hit")
    cvToggle(L, "Damage", "floatingCombatTextCombatDamage_v2", "Your damage over the creatures and players you hit.")
    cvToggle(L, "Damage over time", "floatingCombatTextCombatLogPeriodicSpells_v2", "The ticks of your periodic spells.")
    cvToggle(L, "Your pet's damage", "floatingCombatTextPetMeleeDamage_v2", "Its melee and its spells.", "floatingCombatTextPetSpellDamage_v2")
    cvToggle(L, "Every auto attack", "floatingCombatTextCombatDamageAllAutos_v2", "Off shows only the auto attacks worth noticing.")
    cvToggle(L, "Healing", "floatingCombatTextCombatHealing_v2", "Your healing over the one you heal.")
    cvToggle(L, "Shields you put up", "floatingCombatTextCombatHealingAbsorbTarget_v2")
    L:Slider("Size", "WorldTextScale_v2", 0.5, 2.5, 0.05, {
        get = cvNum("WorldTextScale_v2"), setter = cvSetNum("WorldTextScale_v2"), disabled = locked("WorldTextScale_v2"),
        tooltip = "How big the numbers are.",
    })
    L:Slider("Numbers fly outward", "floatingCombatTextCombatDamageDirectionalScale_v2", 0, 3, 0.1, {
        get = cvNum("floatingCombatTextCombatDamageDirectionalScale_v2"),
        setter = cvSetNum("floatingCombatTextCombatDamageDirectionalScale_v2"),
        disabled = locked("floatingCombatTextCombatDamageDirectionalScale_v2"),
        tooltip = "How far the numbers travel away from where they land. 0 keeps them rising straight up.",
    })
    cvToggle(L, "Float the way Classic did", "classicStyleWorldText", "The older way the numbers rise and fade.")
    cvToggle(L, "Threat changes", "threatWorldText", "The threat notes that float up in a fight.")

    L:Heading("Your own combat text")
    L:Toggle("Show it", SELF, {
        get = cvOn(SELF), setter = setSelf, disabled = locked(SELF),
        tooltip = "The text that scrolls round your character: what hits you, heals you and happens to you. Switching it on or off takes a reload.",
    })
    L:Dropdown("Direction", "floatingCombatTextFloatMode_v2", { { 1, "Up" }, { 2, "Down" }, { 3, "Arc" } }, {
        get = cvNum("floatingCombatTextFloatMode_v2"), setter = cvSetNum("floatingCombatTextFloatMode_v2"),
        disabled = selfOff("floatingCombatTextFloatMode_v2"),
    })
    selfToggle(L, "Dodges, parries and misses", "floatingCombatTextDodgeParryMiss_v2")
    selfToggle(L, "Damage reduction", "floatingCombatTextDamageReduction_v2", "Resists, blocks and absorbs of what hits you.")
    selfToggle(L, "Auras gained and lost", "floatingCombatTextAuras_v2")
    selfToggle(L, "Entering and leaving combat", "floatingCombatTextCombatState_v2")
    selfToggle(L, "Low health and mana", "floatingCombatTextLowManaHealth_v2")
    selfToggle(L, "Power gains", "floatingCombatTextEnergyGains_v2", "Mana, rage and energy you gain.")
    selfToggle(L, "Spell alerts", "floatingCombatTextReactives_v2", "When an ability that needs a moment (Execute, Overpower) becomes usable.")
    selfToggle(L, "Combo points", "floatingCombatTextComboPoints_v2")
    selfToggle(L, "Heals from others", "floatingCombatTextFriendlyHealers_v2", "Who healed you, not only how much.")
    selfToggle(L, "Shields put on you", "floatingCombatTextCombatHealingAbsorbSelf_v2")
    selfToggle(L, "Reputation", "floatingCombatTextRepChanges_v2")
    selfToggle(L, "Honor", "floatingCombatTextHonorGains_v2")
end, { order = 92 })
