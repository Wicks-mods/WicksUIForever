-- Wick's UI
-- Modules/UnitFrames/Tags.lua: text tags for unit frames.
--
-- Health and power are secret on this client, always for health, so a tag
-- can never compare or do arithmetic on them. Every tag here hands the
-- secret straight to something the client allows to take one:
-- AbbreviateLargeNumbers, string.format, UnitHealthPercent with a curve,
-- C_StringUtil.TruncateWhenZero. Status checks (dead, offline, AFK) are
-- plain booleans and are safe to branch on.
--
-- Tag names start with wui: so they never collide with another layout's.

local ADDON, ns = ...

local oUF = ns.oUF
local Tags = oUF.Tags
local M, E = Tags.Methods, Tags.Events

-- Enemy identity (level, classification, class) can be secret inside an
-- instance. A secret becomes nil here, so the tag falls back instead of
-- raising when it compares.
local issecret = rawget(_G, "issecretvalue")
local function plain(v)
    if issecret and issecret(v) then return nil end
    return v
end

local function status(u)
    if not UnitIsConnected(u) then return "Offline" end
    if UnitIsGhost(u) then return "Ghost" end
    if UnitIsDead(u) then return "Dead" end
end

local function abbr(v)
    return AbbreviateLargeNumbers(v)
end

local function perhp(u)
    return string.format("%d", UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
end

local function perpp(u)
    return string.format("%d", UnitPowerPercent(u, nil, true, CurveConstants.ScaleTo100))
end

local HEALTH_EVENTS = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION UNIT_FLAGS PLAYER_FLAGS_CHANGED"
local POWER_EVENTS = "UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_CONNECTION"

-- 12.4k
M["wui:curhp"] = function(u) return status(u) or abbr(UnitHealth(u)) end
E["wui:curhp"] = HEALTH_EVENTS

-- 18.2k
M["wui:maxhp"] = function(u) return abbr(UnitHealthMax(u)) end
E["wui:maxhp"] = "UNIT_MAXHEALTH"

-- 68%
M["wui:perhp"] = function(u) return status(u) or string.format("%s%%", perhp(u)) end
E["wui:perhp"] = HEALTH_EVENTS

-- 12.4k | 68%
M["wui:health"] = function(u)
    return status(u) or string.format("%s | %s%%", abbr(UnitHealth(u)), perhp(u))
end
E["wui:health"] = HEALTH_EVENTS

-- 12.4k / 18.2k
M["wui:curmax"] = function(u)
    return status(u) or string.format("%s / %s", abbr(UnitHealth(u)), abbr(UnitHealthMax(u)))
end
E["wui:curmax"] = HEALTH_EVENTS

-- Missing health, blank when full. Healers read this one.
M["wui:deficit"] = function(u)
    return status(u) or C_StringUtil.TruncateWhenZero(UnitHealthMissing(u))
end
E["wui:deficit"] = HEALTH_EVENTS

M["wui:curpp"] = function(u) return abbr(UnitPower(u)) end
E["wui:curpp"] = POWER_EVENTS

M["wui:perpp"] = function(u) return string.format("%s%%", perpp(u)) end
E["wui:perpp"] = POWER_EVENTS

M["wui:power"] = function(u) return string.format("%s | %s%%", abbr(UnitPower(u)), perpp(u)) end
E["wui:power"] = POWER_EVENTS

-- Mana while shapeshifted, for druids.
M["wui:mana"] = function(u)
    return abbr(UnitPower(u, Enum.PowerType.Mana))
end
E["wui:mana"] = "UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER"

M["wui:status"] = function(u)
    local s = status(u)
    if s then return s end
    if UnitIsAFK(u) then return "AFK" end
    if UnitIsDND(u) then return "DND" end
end
E["wui:status"] = "UNIT_HEALTH UNIT_CONNECTION PLAYER_FLAGS_CHANGED UNIT_FLAGS"

-- Level in the difficulty colour, "??" for a skull, "+" for elites.
M["wui:level"] = function(u)
    local l = plain(UnitEffectiveLevel and UnitEffectiveLevel(u) or UnitLevel(u))
    local c = plain(UnitClassification(u))
    local plus = (c == "elite" or c == "worldboss" or c == "rareelite") and "+" or ""
    if c == "rare" or c == "rareelite" then plus = plus .. " R" end
    if not l or l <= 0 then return "|cffff4040??|r" end
    local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(l)
    if color then
        return ("|cff%02x%02x%02x%d%s|r"):format(color.r * 255, color.g * 255, color.b * 255, l, plus)
    end
    return l .. plus
end
E["wui:level"] = "UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED"

-- Name in the class colour for players and the reaction colour otherwise.
M["wui:namecolor"] = function(u)
    if plain(UnitIsPlayer(u)) then
        local _, class = UnitClass(u)
        class = plain(class)
        if class then
            local r, g, b = ns:ClassColor(class)
            return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
        end
    end
    local reaction = plain(UnitReaction(u, "player"))
    local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
    return "|cffd4c8a1"
end
E["wui:namecolor"] = "UNIT_NAME_UPDATE UNIT_FACTION"

-- The tags offered in the settings, in the order a player would want them.
ns.TagList = {
    { "[wui:namecolor][name]", "Name, coloured" },
    { "[name]", "Name" },
    { "[wui:level] [wui:namecolor][name]", "Level and name" },
    { "[wui:health]", "Health and percent" },
    { "[wui:curhp]", "Health" },
    { "[wui:perhp]", "Health percent" },
    { "[wui:curmax]", "Health of max" },
    { "[wui:deficit]", "Missing health" },
    { "[wui:power]", "Power and percent" },
    { "[wui:curpp]", "Power" },
    { "[wui:perpp]", "Power percent" },
    { "[wui:status]", "Dead, offline, AFK" },
    { "", "Nothing" },
}
