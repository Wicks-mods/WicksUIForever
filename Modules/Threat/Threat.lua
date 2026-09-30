-- Wick's UI
-- Modules/Threat/Threat.lua: who a mob is on, and how close you are to it.
--
-- Three parts, each can be switched off:
--   the glow   unit frames and nameplates glow in Blizzard's threat
--              colours (built in UnitFrames and Nameplates, on oUF's own
--              threat element; switched from here)
--   the meter  you, your pet and your group on your target, highest
--              threat first, the tank marked
--   the bar    your own threat on your target, slim, with a warning as
--              you close on pulling it (for a tank: when it is not on you)
--
-- This client hands threat over plainly in combat (probed 2026-09-29), so
-- the meter can sort and warn. The values are still checked for secrecy
-- before anything compares them, in case a later build changes that.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local TH = ns:NewModule("threat", { title = "Threat", order = 45, defaults = {
    enable = true,
    frameGlow = true,       -- unit frames glow with threat
    plateGlow = true,       -- nameplates glow with your threat on the mob
    meter = true,
    meterShow = "combat",   -- combat, group, always
    meterRows = 6,
    meterWidth = 220,
    rowHeight = 16,
    personal = true,
    personalWidth = 220,
    personalHeight = 8,
    warnAt = 90,            -- percent of the pull at which you are warned
    warnFlash = true,
    warnSound = true,       -- a sound as the warning starts
    warnSoundKit = "raid",  -- raid, alarm, ready, bell
} })
ns.Threat = TH

local function db() return TH:db() end
local issecret = rawget(_G, "issecretvalue")
local function plain(v) if issecret and issecret(v) then return nil end return v end

-- ============================================================
-- Reading threat
-- ============================================================
local function isTankRole()
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if role == "TANK" then return true end
    if GetSpecialization and GetSpecializationRole then
        local ok, spec = pcall(GetSpecialization)
        if ok and spec then
            local ok2, r = pcall(GetSpecializationRole, spec)
            if ok2 and r == "TANK" then return true end
        end
    end
    return false
end

local function roster()
    local out = { "player" }
    if UnitExists("pet") then out[#out + 1] = "pet" end
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then out[#out + 1] = u end
            local p = "raidpet" .. i
            if UnitExists(p) and not UnitIsUnit(p, "pet") then out[#out + 1] = p end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            if UnitExists("party" .. i) then out[#out + 1] = "party" .. i end
            if UnitExists("partypet" .. i) then out[#out + 1] = "partypet" .. i end
        end
    end
    return out
end

-- Everyone with threat on the target, highest first.
local entries = {}
local function read()
    wipe(entries)
    if not (UnitExists("target") and UnitCanAttack("player", "target")) then return entries end
    for _, u in ipairs(roster()) do
        local ok, tanking, status, scaled, raw, value = pcall(UnitDetailedThreatSituation, u, "target")
        value, scaled, status = plain(value), plain(scaled), plain(status)
        if ok and value and status then
            local _, class = UnitClass(u)
            entries[#entries + 1] = {
                unit = u, name = UnitName(u) or u, class = class, pet = u:find("pet") ~= nil,
                tanking = plain(tanking) and true or false, status = status,
                scaled = scaled or 0, value = value,
            }
        end
    end
    table.sort(entries, function(a, b) return a.value > b.value end)
    return entries
end

local function classColor(e)
    if e.pet or not e.class then return C.muted end
    if Chrome.ClassColor then
        local r, g, b = Chrome:ClassColor(e.class)
        if r then return { r, g, b } end
    end
    local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
    return t and { t.r, t.g, t.b } or C.text
end

local function threatColor(status)
    if GetThreatStatusColor then
        local ok, r, g, b = pcall(GetThreatStatusColor, status)
        if ok and r then return { r, g, b } end
    end
    return C.fel
end

-- The warning: for a tank, the mob is not on you; for anyone else, your
-- threat is past warnAt percent of what pulls it.
local function warning(mine)
    if not mine or not UnitAffectingCombat("player") then return false end
    if isTankRole() then return not mine.tanking end
    return (not mine.tanking) and (mine.scaled or 0) >= (db().warnAt or 90)
end

-- The warning's sound: the game's own alerts, on the master channel so it
-- is heard with the effects turned down. Once as the warning starts, not
-- again until it has cleared, and never more than once in three seconds.
local SK = rawget(_G, "SOUNDKIT") or {}
local SOUNDS = {
    raid  = { "Raid warning", SK.RAID_WARNING or 8959 },
    alarm = { "Alarm", SK.ALARM_CLOCK_WARNING_3 or 12889 },
    ready = { "Ready check", SK.READY_CHECK or 8960 },
    bell  = { "Bell", SK.UI_BNET_TOAST or 18019 },
}
TH.SOUNDS = SOUNDS
-- It plays as the warning starts, and, for anyone but a tank, as a mob
-- that was on someone else (your pet, the tank) turns to you: you pulled
-- it. A fight you open alone with no one else on the list is not a pull.
local warnedBefore, lastSound, hadIt, targetBefore = false, 0, false, nil
local function soundCheck(list)
    local d = db()
    local mine
    for _, e in ipairs(list) do if e.unit == "player" then mine = e break end end
    local warn = warning(mine)
    local target = UnitGUID and UnitGUID("target")
    if target ~= targetBefore then hadIt = mine and mine.tanking or false; targetBefore = target end
    local pulled = mine and mine.tanking and not hadIt and #list > 1 and not isTankRole()
        and UnitAffectingCombat("player")
    if (pulled or (warn and not warnedBefore)) and d.warnSound and GetTime() - lastSound > 3 then
        local snd = SOUNDS[d.warnSoundKit] or SOUNDS.raid
        if PlaySound then pcall(PlaySound, snd[2], "Master") end
        lastSound = GetTime()
    end
    warnedBefore = warn and true or false
    hadIt = mine and mine.tanking or false
end
TH.SoundCheck = soundCheck

-- ============================================================
-- The meter
-- ============================================================
local meter
local function buildMeter()
    local d = db()
    local f = CreateFrame("Frame", "WicksUI_ThreatMeter", UIParent)
    f:SetSize(d.meterWidth, 24 + d.meterRows * (d.rowHeight + 2))
    f:SetFrameStrata("MEDIUM")
    ns:SetTemplate(f, "Transparent", { brackets = true })
    f.title = ns:CreateText(f, 12, "LEFT")
    ns:HeadingFont(f.title, 12)
    f.title:SetPoint("TOPLEFT", 8, -6)
    if Chrome.SetHeadingText then Chrome:SetHeadingText(f.title, "Threat") else f.title:SetText("Threat") end
    f.title:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
    Chrome:Register(f.title, C.fel, "text")
    f.target = ns:CreateText(f, 11, "RIGHT")
    f.target:SetPoint("TOPRIGHT", -8, -7)
    f.target:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.target:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    f.rows = {}
    f:Hide()
    ns:CreateMover(f, "threatmeter", "Threat meter", "BOTTOMRIGHT,UIParent,BOTTOMRIGHT,-10,300",
        { groups = "extras", config = "threat" })
    return f
end

local function row(i)
    local r = meter.rows[i]
    if r then return r end
    local d = db()
    r = ns:CreateStatusBar(meter)
    r:SetMinMaxValues(0, 1)
    r:SetHeight(d.rowHeight)
    r.name = ns:CreateText(r, 11, "LEFT")
    r.name:SetPoint("LEFT", 4, 0)
    r.pct = ns:CreateText(r, 11, "RIGHT")
    r.pct:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.pct, "LEFT", -4, 0)
    meter.rows[i] = r
    return r
end

local function layoutMeter()
    local d = db()
    meter:SetSize(d.meterWidth, 24 + d.meterRows * (d.rowHeight + 2))
    for i, r in ipairs(meter.rows) do
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", meter, "TOPLEFT", 4, -22 - (i - 1) * (d.rowHeight + 2))
        r:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -4, -22 - (i - 1) * (d.rowHeight + 2))
        r:SetHeight(d.rowHeight)
    end
end

local flash = 0
local function drawMeter(list)
    local d = db()
    local show
    local unlocked = ns.Movers and ns.Movers.IsUnlocked and ns.Movers:IsUnlocked()
    if not d.meter then
        show = false
    elseif d.meterShow == "always" or unlocked then
        show = true
    elseif d.meterShow == "group" then
        show = (IsInGroup and IsInGroup()) and UnitAffectingCombat("player") and #list > 0
    else
        show = UnitAffectingCombat("player") and #list > 0
    end
    meter:SetShown(show and true or false)
    if not show then return end

    meter.target:SetText(UnitExists("target") and (UnitName("target") or "") or "no target")
    local top = list[1] and list[1].value or 1
    if top <= 0 then top = 1 end
    for i = 1, d.meterRows do
        local e = list[i]
        local r = row(i)
        if e then
            local c = classColor(e)
            r:SetStatusBarColor(c[1], c[2], c[3], e.pet and 0.6 or 0.9)
            r:SetValue(math.min(1, e.value / top))
            local mine = e.unit == "player"
            r.name:SetText((mine and "|cff" .. (Chrome.Hex and Chrome.Hex.fel or "4FC778") or "|cffffffff") .. e.name .. "|r")
            r.pct:SetText(e.tanking and "tank" or ("%d%%"):format(math.floor((e.scaled or 0) + 0.5)))
            -- The tank's row is ringed in the accent; a warning in the
            -- threat colour, pulsing when it flashes.
            local bd = r.backdrop
            if bd then
                if mine and warning(e) then
                    ns:SetBorderColor(bd, threatColor(e.tanking and 3 or 1))
                elseif e.tanking then
                    ns:SetBorderColor(bd, "fel")
                else
                    ns:SetBorderColor(bd, "border")
                end
            end
            r:SetAlpha((mine and warning(e) and d.warnFlash) and (0.6 + 0.4 * math.abs(math.sin(flash * 4))) or 1)
            r:Show()
        else
            r:Hide()
        end
    end
    layoutMeter()
end

-- ============================================================
-- The personal bar
-- ============================================================
local bar
local function buildBar()
    local d = db()
    local b = ns:CreateStatusBar(UIParent)
    b:SetSize(d.personalWidth, d.personalHeight)
    b:SetMinMaxValues(0, 100)
    b.text = ns:CreateText(b, 11, "CENTER")
    b.text:SetPoint("BOTTOM", b, "TOP", 0, 2)
    b:Hide()
    ns:CreateMover(b, "threatbar", "Threat bar", "BOTTOM,UIParent,BOTTOM,0,380", { groups = "extras", config = "threat" })
    return b
end

local function drawBar(list)
    local d = db()
    local mine
    for _, e in ipairs(list) do if e.unit == "player" then mine = e break end end
    local unlocked = ns.Movers and ns.Movers.IsUnlocked and ns.Movers:IsUnlocked()
    local show = d.personal and (unlocked or (mine and UnitAffectingCombat("player")))
    bar:SetShown(show and true or false)
    if not show then return end
    bar:SetSize(d.personalWidth, d.personalHeight)
    if not mine then
        bar:SetValue(0)
        bar.text:SetText("Threat")
        return
    end
    local warn = warning(mine)
    local c = warn and threatColor(mine.tanking and 3 or 1) or (mine.tanking and C.fel) or threatColor(mine.status > 0 and mine.status or 0)
    if not warn and not mine.tanking and mine.status == 0 then c = C.fel end
    bar:SetStatusBarColor(c[1], c[2], c[3], 1)
    bar:SetValue(math.min(100, mine.scaled or 0))
    if isTankRole() then
        bar.text:SetText(mine.tanking and "on you" or "|cffff5050not on you|r")
    else
        bar.text:SetText(mine.tanking and "it is on you" or ("%d%%"):format(math.floor((mine.scaled or 0) + 0.5)))
    end
    bar:SetAlpha((warn and d.warnFlash) and (0.55 + 0.45 * math.abs(math.sin(flash * 4))) or 1)
end

-- ============================================================
-- Driving it
-- ============================================================
local dirty = true
local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, e)
    if not TH.initialized or not db().enable then return end
    flash = flash + e
    acc = acc + e
    -- A fresh read four times a second in a fight, or when something
    -- changed; the flash is redrawn every frame from the last read.
    local fighting = UnitAffectingCombat("player")
    if dirty or (fighting and acc >= 0.25) or acc >= 1 then
        acc, dirty = 0, false
        TH.list = read()
        soundCheck(TH.list)
    end
    local list = TH.list or entries
    if meter then drawMeter(list) end
    if bar then drawBar(list) end
end)
for _, ev in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_PET" }) do
    pcall(driver.RegisterEvent, driver, ev)
end
driver:SetScript("OnEvent", function() dirty = true end)

-- For the offline harness.
TH.Read, TH.Warning = read, warning

function TH:Initialize()
    meter = meter or buildMeter()
    bar = bar or buildBar()
    dirty = true
end

function TH:Update()
    if meter then layoutMeter() end
    dirty = true
    -- Switched off: the meter and the bar go, rather than freeze.
    if not db().enable then
        if meter then meter:Hide() end
        if bar then bar:Hide() end
    end
    -- The glow lives on the unit frames and nameplates; they read these
    -- settings when they lay themselves out.
    if ns.UnitFrames and ns.UnitFrames.Update then pcall(ns.UnitFrames.Update, ns.UnitFrames) end
    if ns.Nameplates and ns.Nameplates.Update then pcall(ns.Nameplates.Update, ns.Nameplates) end
end

-- ============================================================
-- Settings
-- ============================================================
ns.Config:AddPage("threat", "Threat", function(L)
    L:DB(db)
    L:Note("Who a mob is on, and how close you are to pulling it. This client shows addons threat plainly, so the meter can rank everyone and warn you before you pull.")
    L:Toggle("Threat", "enable")
    L:Heading("Glow")
    L:Toggle("On unit frames", "frameGlow", { tooltip = "Your frame, your pet's and the group's glow when a mob is on them; a target, focus or boss frame glows with your threat on that mob." })
    L:Toggle("On nameplates", "plateGlow", { tooltip = "Wick's UI nameplates glow with your threat on each mob. The game's own nameplates show threat themselves." })
    L:Heading("Meter")
    L:Toggle("Threat meter", "meter")
    L:Dropdown("Show it", "meterShow", { { "combat", "In a fight" }, { "group", "In a fight, in a group" }, { "always", "Always" } })
    L:Slider("Rows", "meterRows", 2, 15, 1)
    L:Slider("Width", "meterWidth", 140, 400, 2)
    L:Slider("Row height", "rowHeight", 10, 28, 1)
    L:Heading("Your bar")
    L:Toggle("Personal threat bar", "personal")
    L:Slider("Width", "personalWidth", 80, 400, 2)
    L:Slider("Height", "personalHeight", 3, 24, 1)
    L:Heading("Warning")
    L:Slider("Warn at (percent of the pull)", "warnAt", 50, 100, 1,
        { tooltip = "When your threat passes this share of what pulls the mob, your bar and your row turn the warning colour. A tank is warned when a mob is not on them instead." })
    L:Toggle("Flash when warned", "warnFlash")
    L:Toggle("Sound when warned", "warnSound", { tooltip = "Once as the warning starts, not again until it clears, and never more than once in three seconds. Plays on the master channel." })
    L:Dropdown("Sound", "warnSoundKit", function()
        local out = {}
        for _, key in ipairs({ "raid", "alarm", "ready", "bell" }) do out[#out + 1] = { key, SOUNDS[key][1] } end
        return out
    end, { disabled = function() return not db().warnSound end,
           set = function() local snd = SOUNDS[db().warnSoundKit]; if snd and PlaySound then pcall(PlaySound, snd[2], "Master") end end,
           tooltip = "Plays as you pick it." })
    L:Note("Move the meter and the bar with /wui move.")
end, { onChange = function() TH:Update() end, order = 45 })
