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
-- scrolling text around your own character. Which lines show, and how the
-- numbers move, are the game's own settings, most of them left out of its
-- options: every control for those reads and writes the game's setting,
-- so the choices are account-wide and hold without Wick's UI; a setting
-- this client locks shows greyed out. The game reads them through a cache
-- that an addon's change does not clear, so they show after a reload, and
-- ask for one.
-- Your own text as Wick's UI draws it (Modules/Extras/CombatText.lua) has
-- settings of the profile's, which change at once.
local function askReload(text)
    local Chrome = ns.Core.Chrome
    if Chrome.ReloadPrompt then Chrome:ReloadPrompt(text or "Combat text changes show after a reload.") end
end
local function cvOn(name) return function() return get(name) == "1" end end
local function cvSetOn(...)
    local names = { ... }
    return function(v)
        for _, n in ipairs(names) do
            if usable(n) then set(n, v and "1" or "0") end
        end
        askReload()
    end
end
local function cvNum(name) return function() return tonumber(get(name) or "") or 0 end end
local function cvSetNum(name) return function(v) if usable(name) then set(name, tostring(v)); askReload() end end end
local function locked(name) return function() return not usable(name) end end
local SELF = "enableFloatingCombatText"
local FLOAT = "floatingCombatTextFloatMode_v2"

-- Blizzard's own combat text is an addon of its own. It loads at startup
-- when this is on, or when it is switched through the game's settings,
-- and it starts and stops listening the same way: switched from here, it
-- takes a reload. Loading it from here instead would run it tainted, and
-- it handles numbers the client keeps secret in a fight.
local function setSelf(v)
    if not usable(SELF) then return end
    set(SELF, v and "1" or "0")
    askReload(v and "Your own combat text starts after a reload." or "Your own combat text stops after a reload.")
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
local function cvSlider(L, label, name, lo, hi, step, tip)
    L:Slider(label, name, lo, hi, step, {
        get = cvNum(name), setter = cvSetNum(name), disabled = locked(name), tooltip = tip,
    })
end

-- How the numbers over what you hit move, each with the game's own value
-- (this client's console list) for when it cannot say.
local NUMBERS = {
    WorldTextScale_v2 = "1",
    floatingCombatTextCombatDamageDirectionalScale_v2 = "0",
    floatingCombatTextCombatDamageDirectionalOffset_v2 = "1",
    WorldTextGravity_v2 = "0.5",
    WorldTextRandomXY_v2 = "0",
    WorldTextStartPosRandomness_v2 = "1",
    WorldTextNonRandomZ_v2 = "2",
    WorldTextMinAlpha_v2 = "0.5",
    WorldTextScreenY_v2 = "0",
    WorldTextCritScreenY_v2 = "0",
}
VX.NUMBERS = NUMBERS

function VX:ResetNumbers()
    for name, value in pairs(NUMBERS) do
        if usable(name) then
            local game
            if CV and CV.GetCVarDefault then
                local ok, v = pcall(CV.GetCVarDefault, name)
                if ok and type(v) == "string" then game = v end
            end
            set(name, game or value)
        end
    end
    askReload()
end

-- Your own text's direction is ours while Wick's UI draws it, the game's
-- otherwise. Ours is set with the game's, so the game runs the same way if
-- it draws again.
local DIRS = { "up", "down", "arc" }
local DIR_NUM = { up = 1, down = 2, arc = 3 }
local function drawn() return ns.CombatText and ns.CombatText:Drawing() end

local function fontValues()
    local out = {}
    for _, name in ipairs(ns.Media:List("font")) do out[#out + 1] = { name, name, name } end
    return out
end

ns.Config:AddPage("combattext", "Combat text", function(L)
    local CT = ns.CombatText
    local W = ns.Widgets
    local notOurs = function() return ns:G().combatTextFont == false end
    local selfIsOff = function() return get(SELF) ~= "1" end

    L:Note("The game's floating combat text: the numbers over what you hit, and the text round your own character. Which lines show and how the numbers move are the game's own settings, so they are account-wide, hold with Wick's UI switched off and show after a reload. Your own text as Wick's UI draws it changes at once.")
    L:Toggle("Wick's UI keeps the combat text", "combatTextFont", {
        get = function() return ns:G().combatTextFont ~= false end,
        setter = function(v)
            ns:G().combatTextFont = v and true or false
            if ns.Media and ns.Media.WorldFonts then ns.Media:WorldFonts() end
            ns.A:Print("the numbers over what you hit change font after a relog; your own combat text changes now.")
        end,
        tooltip = "Your own combat text drawn by Wick's UI, and the numbers over what you hit in the font picked below. Off leaves both to the game, or to a combat text addon.",
    })

    L:Heading("Your own combat text")
    L:Toggle("Show it", SELF, {
        get = cvOn(SELF), setter = setSelf, disabled = locked(SELF),
        tooltip = "The text that scrolls round your character: what hits you, heals you and happens to you. Wick's UI draws it from the game's, so it needs this on.",
    })
    L:Toggle("Drawn by Wick's UI", "drawn", {
        get = function() return CT:db().enable ~= false end,
        setter = function(v) CT:db().enable = v and true or false end,
        disabled = function() return notOurs() or selfIsOff() end,
        tooltip = "Where you put it, in the font, size and colours below. Off leaves it to the game, in the middle of the screen in its own font and colours.",
    })
    L:Dropdown("Direction", FLOAT, { { 1, "Up" }, { 2, "Down" }, { 3, "Arc" } }, {
        get = function()
            if drawn() then return DIR_NUM[CT:db().direction] or 1 end
            return cvNum(FLOAT)()
        end,
        setter = function(v)
            if drawn() then
                CT:db().direction = DIRS[v] or "up"
                if usable(FLOAT) then set(FLOAT, tostring(v)) end
            else
                cvSetNum(FLOAT)(v)
            end
        end,
        disabled = selfOff(FLOAT),
        tooltip = "Which way your text runs. Drawn by Wick's UI it changes at once; left to the game, after a reload.",
    })
    L:DB(function() return CT:db() end)
    L:DisabledWhen(function() return not drawn() or selfIsOff() end)
    L:Toggle("Spread damage sideways", "stagger", {
        tooltip = "Damage lines start a little apart from side to side, as the game draws them.",
    })
    L:Dropdown("Font", "font", fontValues, { tooltip = "Wick is the look's own." })
    L:Dropdown("Outline", "outline", W.Values(ns.Media.outlines, ns.Media.outlineLabels))
    L:Slider("Text size", "size", 10, 36, 1)
    L:Slider("Crit size", "critSize", 12, 48, 1, {
        tooltip = "A crit pops out larger for a moment, then holds at this size where it landed.",
    })
    L:Slider("Scale", "scale", 0.5, 2, 0.05, { tooltip = "All of it at once: the text, how far it travels and the gaps." })
    L:Slider("Distance it travels", "distance", 60, 500, 10)
    L:Slider("Time on screen", "duration", 0.5, 5, 0.1, { tooltip = "Seconds. The game's own is 1.9." })
    L:Slider("Fades over its last", "fade", 0.1, 5, 0.1, {
        tooltip = "Seconds. The game's own is 0.6. It can be no longer than the time on screen.",
    })
    L:Button("Show a sample", function() CT:Sample() end, {
        tooltip = "A line of each kind, to see your settings without a fight.",
    })
    L:Button("Move it", function() ns.Config:Hide(); ns.Movers:Unlock() end, {
        tooltip = "Unlocks the frames. Drag the box marked Your combat text; the text runs inside it, and a sample plays while it is unlocked.",
    })
    L:Heading("Colours of your own text")
    for _, k in ipairs(CT.KINDS) do
        L:Color(k.label, k.key, {
            get = function() local c = CT:db().colors; return c and c[k.key] end,
            setter = function(v)
                local d = CT:db()
                d.colors = d.colors or {}
                d.colors[k.key] = v
            end,
            fallback = function() return CT:GameColor(k.key) end,
            follows = "the game's",
            tooltip = k.tip .. " Right-click to go back to the game's colour.",
        })
    end
    L:DisabledWhen(nil)

    L:Heading("What your own text shows")
    selfToggle(L, "Dodges, parries and misses", "floatingCombatTextDodgeParryMiss_v2")
    selfToggle(L, "Damage reduction", "floatingCombatTextDamageReduction_v2", "Resists, blocks and absorbs of what hits you.")
    selfToggle(L, "Auras gained and lost", "floatingCombatTextAuras_v2")
    selfToggle(L, "Entering and leaving combat", "floatingCombatTextCombatState_v2")
    selfToggle(L, "Low health and mana", "floatingCombatTextLowManaHealth_v2")
    selfToggle(L, "Power gains", "floatingCombatTextEnergyGains_v2", "Mana, rage and energy you gain.")
    selfToggle(L, "Power gains over time", "floatingCombatTextPeriodicEnergyGains_v2", "Mana and energy that comes in ticks.")
    selfToggle(L, "Spell alerts", "floatingCombatTextReactives_v2", "When an ability that needs a moment (Execute, Overpower) becomes usable.")
    selfToggle(L, "Combo points", "floatingCombatTextComboPoints_v2")
    selfToggle(L, "Heals from others", "floatingCombatTextFriendlyHealers_v2", "Who healed you, not only how much.")
    selfToggle(L, "Shields put on you", "floatingCombatTextCombatHealingAbsorbSelf_v2")
    selfToggle(L, "Reputation", "floatingCombatTextRepChanges_v2")
    selfToggle(L, "Honor", "floatingCombatTextHonorGains_v2")

    L:Heading("Numbers over what you hit")
    cvToggle(L, "Damage", "floatingCombatTextCombatDamage_v2", "Your damage over the creatures and players you hit.")
    cvToggle(L, "Damage over time", "floatingCombatTextCombatLogPeriodicSpells_v2", "The ticks of your periodic spells.")
    cvToggle(L, "Your pet's damage", "floatingCombatTextPetMeleeDamage_v2", "Its melee and its spells.", "floatingCombatTextPetSpellDamage_v2")
    cvToggle(L, "Every auto attack", "floatingCombatTextCombatDamageAllAutos_v2", "Off shows only the auto attacks worth noticing.")
    cvToggle(L, "Healing", "floatingCombatTextCombatHealing_v2", "Your healing over the one you heal.")
    cvToggle(L, "Shields you put up", "floatingCombatTextCombatHealingAbsorbTarget_v2")
    cvToggle(L, "Float the way Classic did", "classicStyleWorldText", "The older way the numbers rise and fade.")
    cvToggle(L, "Threat changes", "threatWorldText", "The threat notes that float up in a fight.")
    L:Dropdown("Font", "numbersFont", fontValues, {
        get = function() return CT:db().numbersFont or "Wick" end,
        setter = function(v)
            CT:db().numbersFont = v
            if ns.Media and ns.Media.WorldFonts then ns.Media:WorldFonts() end
            ns.A:Print("the numbers over what you hit change font after a relog.")
        end,
        disabled = notOurs,
        tooltip = "Wick is the look's own. A new font shows after a relog, not a reload: the game reads it once, at login.",
    })
    L:Break()
    cvSlider(L, "Size", "WorldTextScale_v2", 0.5, 2.5, 0.05, "How big the numbers are.")
    cvSlider(L, "Numbers fly outward", "floatingCombatTextCombatDamageDirectionalScale_v2", 0, 3, 0.1,
        "How far the numbers travel away from where they land. 0 keeps them rising straight up.")
    cvSlider(L, "Start further out", "floatingCombatTextCombatDamageDirectionalOffset_v2", 0, 3, 0.1,
        "How far from where they land the outward numbers start. Only while they fly outward.")
    cvSlider(L, "Gravity", "WorldTextGravity_v2", 0, 2, 0.05, "How hard the numbers are pulled back down as they rise.")
    cvSlider(L, "Scatter sideways", "WorldTextRandomXY_v2", 0, 3, 0.1, "How far apart the numbers drift from side to side.")
    cvSlider(L, "Start spread", "WorldTextStartPosRandomness_v2", 0, 3, 0.1,
        "How far from one spot the numbers start. 0 starts each one in the same place.")
    cvSlider(L, "How high they rise", "WorldTextNonRandomZ_v2", 0, 6, 0.1, "How far up the numbers go before they fade.")
    cvSlider(L, "Faintest before they go", "WorldTextMinAlpha_v2", 0, 1, 0.05, "How faint the numbers fade to before they go.")
    cvSlider(L, "Higher on the screen", "WorldTextScreenY_v2", -0.5, 0.5, 0.01, "Moves the numbers up the screen, or down below 0.")
    cvSlider(L, "Crits higher on the screen", "WorldTextCritScreenY_v2", -0.5, 0.5, 0.01, "The same for crits alone.")
    L:Button("Put back the game's numbers", function() VX:ResetNumbers() end, {
        tooltip = "Size and movement back to the game's own. Which numbers show is kept.",
    })
end, { order = 92, onChange = function() if ns.CombatText then ns.CombatText:Refresh() end end })
