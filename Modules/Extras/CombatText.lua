-- Wick's UI
-- Modules/Extras/CombatText.lua: your own combat text, drawn by us.
--
-- The game's scrolling text round your character (what hits you, heals you
-- and happens to you) is Blizzard_CombatText. Its colours, sizes and places
-- come from tables of its own, and changing those from here would run it
-- tainted, which breaks it in a fight: it formats numbers the client keeps
-- secret. So it is left to do all of that, and every line it makes is drawn
-- again here, where the player puts it, in the font, size and colours they
-- pick, while its own lines are faded out. A post-hook on its AddMessage
-- hands over the finished text, the colour the game gave it and whether it
-- is a crit. The text can be a secret; it is only ever handed on to
-- SetText, which takes one, and never compared or measured.
-- What shows is still the game's choice, through its own settings (the
-- toggles under Combat text). A line's kind is told by the colour the game
-- gives it, the one thing about a line that is never secret.

local ADDON, ns = ...

local CT = ns:NewModule("combattext", { title = "Combat text", order = 92 })
ns.CombatText = CT

ns.defaults.profile.combattext = {
    enable = true,        -- drawn by us; off gives it back to the game
    font = "Wick",
    outline = "OUTLINE",  -- over the world, an outline reads best
    size = 18, critSize = 26,
    scale = 1,
    direction = "up",     -- up, down or arc
    distance = 220,       -- how far a line travels
    duration = 1.9,       -- seconds on screen, the game's own speed
    fade = 0.6,           -- fading over its last this many seconds, as the game's do
    stagger = true,       -- damage lines a little apart sideways, as the game draws them
    colors = {},          -- kind -> { r, g, b }; a kind with none keeps the game's colour
    dimFades = true,      -- an aura's "fades" line darker than the line when it lands
    fadesBright = 0.5,    -- how bright, against the landing line's full colour
    numbersFont = "Wick", -- the numbers over what you hit; Wick is the look's
    -- Numbers rising off each mob's nameplate, from what the client says it
    -- was hit for (UNIT_COMBAT): everyone's hits on it, not only yours.
    plates = false,
    platesTarget = false, -- only on your target's plate
    platesHeals = false,
    platesMisses = true,  -- misses, dodges, parries and the rest
    platesSize = 14, platesCritSize = 20,
    platesRise = 40,      -- how far up they go
    platesDuration = 1.2,
}

local function db() return CT:db() end

-- The kinds, by the colour the game gives each (its CombatTextTypeInfo).
-- Power gains come in their power's own colour (mana, rage, energy), so
-- any of the game's power bar colours is a power gain.
CT.KINDS = {
    { key = "damage", label = "Damage and warnings", color = { 1, 0.1, 0.1 },
      tip = "Melee damage that hits you, dodges and misses, harmful auras, low health and entering combat." },
    { key = "spell", label = "Spell damage", color = { 0.79, 0.3, 0.85 },
      tip = "Spell damage that hits you, and what of it is resisted or absorbed." },
    { key = "heal", label = "Heals and buffs", color = { 0.1, 1, 0.1 },
      tip = "Heals, shields, and buffs you gain and lose." },
    { key = "power", label = "Power gains", color = { 0, 0, 1 },
      tip = "Mana, rage, energy and the rest. Each comes in its own colour until you pick one, then all of them in that." },
    { key = "rep", label = "Reputation and honor", color = { 0.1, 0.1, 1 },
      tip = "Reputation and honor you gain." },
    { key = "alert", label = "Spell alerts", color = { 1, 0.82, 0 },
      tip = "An ability that needs a moment, Execute or Overpower, becoming usable." },
    { key = "other", label = "Everything else", color = { 1, 1, 1 },
      tip = "Interrupts, your spells missing, dispels and extra attacks." },
}

local issecret = rawget(_G, "issecretvalue")
local function near(r, g, b, c)
    return math.abs(r - c[1]) < 0.02 and math.abs(g - c[2]) < 0.02 and math.abs(b - c[3]) < 0.02
end
function CT.KindOf(r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return "other" end
    if issecret and (issecret(r) or issecret(g) or issecret(b)) then return "other" end
    for _, k in ipairs(CT.KINDS) do
        if k.key ~= "power" and near(r, g, b, k.color) then return k.key end
    end
    local pbc = rawget(_G, "PowerBarColor")
    if type(pbc) == "table" then
        for _, c in pairs(pbc) do
            if type(c) == "table" and type(c.r) == "number" and near(r, g, b, { c.r, c.g, c.b }) then return "power" end
        end
    end
    return "other"
end

-- The game's colour for a kind, for the swatch while it is not changed.
-- Power has one per power; mana's stands for them.
function CT:GameColor(kind)
    if kind == "power" then
        local pbc = rawget(_G, "PowerBarColor")
        local m = type(pbc) == "table" and pbc.MANA
        if type(m) == "table" and type(m.r) == "number" then return { m.r, m.g, m.b } end
    end
    for _, k in ipairs(CT.KINDS) do
        if k.key == kind then return k.color end
    end
    return { 1, 1, 1 }
end

-- The colour a kind is drawn in: the player's pick, or nil for the game's.
function CT:Picked(kind)
    local c = db().colors
    return c and c[kind]
end

-- ============================================================
-- Drawing
-- ============================================================
local frame
local active, free = {}, {}
local MAX_LINES = 24
local STAGGER = 12       -- how far apart sideways a staggered line can start
local GAP = 4            -- between lines that would touch
local MAX_BACK = 130     -- how far behind the start a crowded line may wait
local SHIFT = 80         -- past that, how far aside it starts, as the game's do
local POP_UP, POP_DOWN, POP = 0.05, 0.2, 1.6   -- a crit's pop: the game's timing

CT.lines = active   -- for /dump and the offline harness

local function release(i)
    local line = table.remove(active, i)
    if line then
        line.fs:Hide()
        free[#free + 1] = line.fs
    end
end

function CT:Clear()
    for i = #active, 1, -1 do release(i) end
end

-- p runs from 0 to 1 over a line's life.
local function place(line, p)
    local d = db()
    local fs, dist = line.fs, d.distance
    fs:ClearAllPoints()
    if line.hold then p = 0 end   -- a crit holds where it lands, as the game's do
    if d.direction == "down" then
        fs:SetPoint("TOP", frame, "TOP", line.x, -(line.back + dist * p))
    elseif d.direction == "arc" then
        local q = p * math.pi / 2
        local x = line.x + line.side * dist * 0.7 * (1 - math.cos(q))
        fs:SetPoint("BOTTOM", frame, "BOTTOM", x, line.back + dist * math.sin(q))
    else
        fs:SetPoint("BOTTOM", frame, "BOTTOM", line.x, line.back + dist * p)
    end
end

local function life()
    return math.max(0.2, db().duration or 1.9)
end

-- While the frames are unlocked, a sample plays now and then, so the box
-- is seen with the text running in it.
local DEMO_EVERY = 2.5
local demo = 0
local function onUpdate(_, elapsed)
    local m = frame and frame.mover
    if m and m:IsShown() and ns.Movers:IsUnlocked() then
        demo = demo - elapsed
        if demo <= 0 then
            demo = DEMO_EVERY
            CT:Sample()
        end
    else
        demo = 0
    end
    if #active == 0 then return end
    local d = db()
    local span = life()
    local fade = math.min(span, math.max(0.05, d.fade or 0.6))
    for i = #active, 1, -1 do
        local line = active[i]
        line.t = line.t + elapsed
        if line.t >= span then
            release(i)
        else
            place(line, line.t / span)
            if line.t > span - fade then
                line.fs:SetAlpha(math.max(0, (span - line.t) / fade) * (line.alpha or 1))
            end
            if line.pop then
                local t, h = line.t, line.height
                if t <= POP_UP then
                    line.fs:SetTextHeight(math.floor(h + h * (POP - 1) * t / POP_UP))
                elseif t <= POP_DOWN then
                    line.fs:SetTextHeight(math.floor(h * POP - h * (POP - 1) * (t - POP_UP) / (POP_DOWN - POP_UP)))
                else
                    line.fs:SetTextHeight(h)
                    line.pop = nil
                end
            end
        end
    end
end

-- How far behind the start a new line has to begin so it sits clear of
-- every line still near the start, as the game queues its own. A line
-- that holds counts where it holds.
local function startBack(height)
    local d = db()
    local span = life()
    local back = 0
    for _, line in ipairs(active) do
        local at = line.back + (line.hold and 0 or d.distance * (line.t / span))
        local need = at - (line.height + height) / 2 - GAP
        if back > need then back = need end
    end
    return back
end

local side, aside = 1, 1
-- message: the game's finished text, possibly a secret.
-- kind of line: "crit" pops and holds, "sticky" holds.
-- fading: the line is an aura fading.
function CT:Add(message, r, g, b, displayType, staggered, fading)
    if not (frame and self:Drawing()) then return end
    local d = db()
    if #active >= MAX_LINES then release(1) end
    local fs = table.remove(free) or frame:CreateFontString(nil, "OVERLAY")
    local crit = displayType == "crit"
    local size = crit and d.critSize or d.size
    ns.Media:SetFont(fs, size, d.outline, d.font)
    local path, h = fs:GetFont()
    if not path then
        -- A font that would not load (a shared one since removed): the Wick
        -- one, or the line cannot take text at all.
        fs:SetFont(ns.Media.fonts.Wick, size, "OUTLINE")
        path, h = fs:GetFont()
    end
    -- The size the font came out at: a look can set the Wick font larger.
    h = tonumber(h) or size
    fs:SetTextHeight(h)
    fs:SetText(message)
    local pick = self:Picked(CT.KindOf(r, g, b))
    if pick then r, g, b = pick[1], pick[2], pick[3] end
    if type(r) ~= "number" then r, g, b = 1, 1, 1 end
    -- An aura fading comes in the same colour as when it landed; drawn
    -- darker, a buff going stands apart from one coming.
    local alpha = 1
    if fading and d.dimFades ~= false and not (issecret and (issecret(r) or issecret(g) or issecret(b))) then
        local k = math.max(0.1, math.min(1, d.fadesBright or 0.5))
        r, g, b = r * k, g * k, b * k
        alpha = 0.5 + k / 2
    end
    fs:SetTextColor(r, g, b, 1)
    fs:SetAlpha(alpha)
    fs:Show()
    local line = { fs = fs, t = 0, height = h, side = side, crit = crit, alpha = alpha,
        hold = crit or displayType == "sticky", pop = crit or nil,
        x = (staggered and d.stagger) and math.random(-STAGGER, STAGGER) or 0 }
    side = -side
    local back = startBack(h)
    if back < -MAX_BACK then
        -- Crowded: a crit goes where it lands anyway, the rest start aside,
        -- one side and then the other.
        if line.hold then
            back = 0
        else
            back = -MAX_BACK
            line.x = line.x + aside * SHIFT
            aside = -aside
        end
    end
    line.back = back
    active[#active + 1] = line
    place(line, 0)
    return line
end

-- Lines to show what the settings look like, without a fight.
local SAMPLES = {
    { "-1,284", 1, 0.1, 0.1, nil, true },
    { "+862", 0.1, 1, 0.1 },
    { "-3,571", 1, 0.1, 0.1, "crit" },
    { "-917", 0.79, 0.3, 0.85 },
    { "+120 Mana", 0, 0, 1 },
    { "<Overpower>", 1, 0.82, 0, "crit" },
    { "(Stormwind +25)", 0.1, 0.1, 1 },
    { "Interrupted", 1, 1, 1 },
    { "<Renew>", 0.1, 1, 0.1 },
    { "<Renew> fades", 0.1, 1, 0.1, nil, nil, true },
}
function CT:Sample()
    local after = C_Timer and C_Timer.After
    for i, s in ipairs(SAMPLES) do
        local function add() CT:Add(s[1], s[2], s[3], s[4], s[5], s[6], s[7]) end
        if after and i > 1 then after((i - 1) * 0.25, add) else add() end
    end
end

-- Ours to draw: switched on, and not left to another combat text addon.
function CT:Drawing()
    return db().enable ~= false and ns:G().combatTextFont ~= false
end

-- ============================================================
-- The game's own
-- ============================================================
-- Its lines go on running, unseen: the frame they sit on is faded. Hidden,
-- it would stop: it drops every line while it is not visible. Only ours to
-- fade, so only put back if we faded it.
local watching, faded
local function fadeGame()
    local bz = rawget(_G, "CombatText")
    if not (bz and bz.SetAlpha) then return end
    if watching and frame and CT:Drawing() then
        bz:SetAlpha(0)
        faded = true
    elseif faded then
        bz:SetAlpha(1)
        faded = nil
    end
end
CT.FadeGame = fadeGame

-- The game's lines are read off its own frame every frame, not taken from a
-- post-hook on CombatText:AddMessage. On the Forever client the game's own
-- call through that hook fails ("attempt to call a nil value" at
-- CombatText.lua, 2026-10-02), and its lines carry secret text. AddMessage
-- puts each line on a pooled font string, sets its scrollTime to 0 and adds
-- it to activeFontStrings, so a font string not seen before, or one whose
-- time has gone back, holds a new line. Nothing is written onto the game's
-- font strings; what was seen is kept here.
local seen = setmetatable({}, { __mode = "k" })

-- Which of the game's lines are auras fading. Nothing on a line says so:
-- an aura's start and its end come in the same colour, and on Forever the
-- text is a secret (the aura's name comes from C_CombatText.GetCurrentEventInfo,
-- whose returns are all secret). Plain text says so itself, in the game's
-- own words (AURA_END, "<%s> fades"). Otherwise the event that made the
-- line does: COMBAT_TEXT_UPDATE names the kind of line, plainly, and the
-- game draws that line as the event comes in. Each kind that would show is
-- noted with its colour, in order, and each new line takes the oldest
-- note in its colour.
local notes = {}
local NOTE_LIFE, NOTE_MAX = 1, 40
local function typeInfo()
    return rawget(_G, "CombatTextTypeInfo") or rawget(_G, "COMBAT_TEXT_TYPE_INFO")
end
local function noteLine(_, kind)
    if type(kind) ~= "string" or (issecret and issecret(kind)) then return end
    local all = typeInfo()
    local info = type(all) == "table" and all[kind]
    if not (type(info) == "table" and info.show and type(info.r) == "number") then return end
    if #notes >= NOTE_MAX then table.remove(notes, 1) end
    notes[#notes + 1] = { info.r, info.g, info.b, fading = kind:find("AURA_END", 1, true) ~= nil, at = GetTime() }
end
CT.NoteLine = noteLine

local fadesPattern
local function fadesText(text)
    if not fadesPattern then
        local f = rawget(_G, "AURA_END")
        if type(f) ~= "string" then return false end
        local p = f:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")
        fadesPattern = "^" .. p:gsub("%%%%s", ".+") .. "$"
    end
    return text:match(fadesPattern) ~= nil
end

local function isFading(text, r, g, b)
    local now = GetTime()
    for i = #notes, 1, -1 do
        if now - notes[i].at > NOTE_LIFE then table.remove(notes, i) end
    end
    -- The note is taken even when the text answers, so the next line in
    -- that colour finds its own.
    local note
    if type(r) == "number" and type(g) == "number" and type(b) == "number"
        and not (issecret and (issecret(r) or issecret(g) or issecret(b))) then
        for i, n in ipairs(notes) do
            if near(r, g, b, n) then note = table.remove(notes, i) break end
        end
    end
    if type(text) == "string" and not (issecret and issecret(text)) then
        return fadesText(text)
    end
    return note and note.fading or false
end
CT.IsFading = isFading

local function readGame()
    local bz = rawget(_G, "CombatText")
    local list = bz and bz.activeFontStrings
    if type(list) ~= "table" then return end
    local at = bz.textLocations
    for _, fs in ipairs(list) do
        local t = fs.scrollTime
        if type(t) == "number" then
            local last = seen[fs]
            if last == nil or t < last then
                local r, g, b = fs:GetTextColor()
                local kind = (fs.isCrit and "crit") or (at and fs.endY == at.startY and "sticky") or nil
                local text = fs:GetText()
                CT:Add(text, r, g, b, kind, at and fs.startX ~= at.startX, isFading(text, r, g, b))
            end
            seen[fs] = t
        end
    end
end
CT.ReadGame = readGame

function CT:Hook()
    local bz = rawget(_G, "CombatText")
    if watching or not (bz and type(bz.activeFontStrings) == "table") then return end
    watching = CreateFrame("Frame")
    watching:SetScript("OnUpdate", readGame)
end

-- ============================================================
-- Lifecycle
-- ============================================================
local DEFAULT_POINT = "BOTTOM,UIParent,CENTER,0,-20"

function CT:Layout()
    if not frame then return end
    local d = db()
    frame:SetScale(math.max(0.3, d.scale or 1))
    -- The mover is the room the text runs in.
    local w = d.direction == "arc" and math.max(220, d.distance * 1.4 + 120) or 220
    frame:SetSize(w, d.distance + d.critSize + 10)
    ns.Movers:Resize("combattext")
    ns.Movers:SetEnabled("combattext", self:Drawing())
    -- Lines already up take the new font and size.
    for _, line in ipairs(active) do
        local size = line.crit and d.critSize or d.size
        ns.Media:SetFont(line.fs, size, d.outline, d.font)
        local _, h = line.fs:GetFont()
        line.height = tonumber(h) or size
        line.fs:SetTextHeight(line.height)
    end
    if not self:Drawing() then self:Clear() end
end

function CT:Initialize()
    frame = CreateFrame("Frame", "WicksUI_CombatText", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:SetSize(220, 256)
    frame:SetScript("OnUpdate", onUpdate)
    ns:CreateMover(frame, "combattext", "Your combat text", DEFAULT_POINT, { groups = "misc", config = "combattext" })
    self.frame = frame
    self:Hook()
    -- The game loads its combat text at login when it is switched on, or
    -- later when it is switched on in the game's settings.
    ns:On("ADDON_LOADED", function(_, addon)
        if addon == "Blizzard_CombatText" then CT:Hook(); fadeGame() end
    end)
    ns:On("COMBAT_TEXT_UPDATE", noteLine)
    self:Layout()
    fadeGame()
end

function CT:Update()
    self:Layout()
    fadeGame()
end

-- From the settings page: built the first time it is switched on, if it
-- was off at login.
function CT:Refresh()
    if self.initialized then
        ns:Call(self, "Update")
    elseif self:Enabled() then
        self.initialized = ns:Call(self, "Initialize")
    end
end

-- ============================================================
-- Numbers on the nameplates
-- ============================================================
-- The client tells addons what a unit was hit for (UNIT_COMBAT), plainly
-- even in a fight (probed 2026-10-05), but not who hit it; the combat log
-- that would say is closed to addons. So these are every hit on a mob,
-- yours and your pet's alone when you fight on your own. Each one rises
-- off the mob's plate in the font and outline above, crits larger with a
-- pop, coloured by the school of the hit. When a plate goes (the mob died,
-- or went out of sight) its numbers stay where they were and finish.
local plateFrame
local plateLines, plateFree = {}, {}
local PLATE_MAX, PER_PLATE = 40, 6
CT.plateLines = plateLines   -- for the offline harness

local SCHOOL = {
    { 2, { 1, 0.9, 0.5 } },    -- holy
    { 4, { 1, 0.5, 0 } },      -- fire
    { 8, { 0.3, 1, 0.3 } },    -- nature
    { 16, { 0.5, 1, 1 } },     -- frost
    { 32, { 0.6, 0.5, 1 } },   -- shadow
    { 64, { 1, 0.5, 1 } },     -- arcane
}
local WHITE, HEAL, MISS = { 1, 1, 1 }, { 0.2, 1, 0.2 }, { 0.7, 0.7, 0.7 }
local MISSES = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true, ABSORB = true,
    IMMUNE = true, EVADE = true, DEFLECT = true, REFLECT = true }

local band = bit and bit.band
local function schoolColor(school)
    if type(school) ~= "number" or not band or (issecret and issecret(school)) then return WHITE end
    for _, s in ipairs(SCHOOL) do
        if band(school, s[1]) ~= 0 then return s[2] end
    end
    return WHITE
end

local function short(n)
    if n >= 1e6 then return ("%.1fm"):format(n / 1e6) end
    if n >= 1e4 then return ("%.1fk"):format(n / 1e3) end
    return tostring(math.floor(n + 0.5))
end

local function plateFor(unit)
    local NP = ns.Nameplates
    if not (NP and NP.plates) then return nil end
    for f in pairs(NP.plates) do
        if ns:UnitOf(f) == unit and f:IsVisible() then return f end
    end
end

local function plateRelease(i)
    local line = table.remove(plateLines, i)
    if line then
        line.fs:Hide()
        plateFree[#plateFree + 1] = line.fs
    end
end

local function platePlace(line, p)
    local d = db()
    local fs = line.fs
    local y = (line.hold and math.min(p, 0.25) or p) * (d.platesRise or 40)
    fs:ClearAllPoints()
    if line.anchor then
        fs:SetPoint("BOTTOM", line.anchor, "TOP", line.x, 4 + y)
    else
        fs:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", line.fx + line.x, line.fy + 4 + y)
    end
end

local function plateUpdate(_, elapsed)
    if #plateLines == 0 then return end
    local span = math.max(0.3, db().platesDuration or 1.2)
    for i = #plateLines, 1, -1 do
        local line = plateLines[i]
        line.t = line.t + elapsed
        if line.t >= span then
            plateRelease(i)
        else
            local p = line.t / span
            platePlace(line, p)
            if p > 0.6 then line.fs:SetAlpha(math.max(0, (1 - p) / 0.4)) end
            if line.pop then
                local t, h = line.t, line.height
                if t <= POP_UP then
                    line.fs:SetTextHeight(math.floor(h + h * (POP - 1) * t / POP_UP))
                elseif t <= POP_DOWN then
                    line.fs:SetTextHeight(math.floor(h * POP - h * (POP - 1) * (t - POP_UP) / (POP_DOWN - POP_UP)))
                else
                    line.fs:SetTextHeight(h)
                    line.pop = nil
                end
            end
        end
    end
end

-- One number off a plate. text may be a secret, handed on to SetText.
function CT:PlateNumber(unit, plate, text, color, crit)
    if not plateFrame then
        plateFrame = CreateFrame("Frame", "WicksUI_PlateText", UIParent)
        plateFrame:SetFrameStrata("HIGH")
        plateFrame:EnableMouse(false)
        plateFrame:SetAllPoints()
        plateFrame:SetScript("OnUpdate", plateUpdate)
    end
    local d = db()
    -- A crowded plate drops its oldest; so does a crowded screen.
    local n = 0
    for i = #plateLines, 1, -1 do
        if plateLines[i].unit == unit then
            n = n + 1
            if n >= PER_PLATE then plateRelease(i) end
        end
    end
    if #plateLines >= PLATE_MAX then plateRelease(1) end
    local fs = table.remove(plateFree) or plateFrame:CreateFontString(nil, "OVERLAY")
    local size = crit and d.platesCritSize or d.platesSize or 14
    ns.Media:SetFont(fs, size, d.outline, d.font)
    local _, h = fs:GetFont()
    h = tonumber(h) or size
    fs:SetTextHeight(h)
    fs:SetText(text)
    fs:SetTextColor(color[1], color[2], color[3], 1)
    fs:SetAlpha(1)
    fs:Show()
    local line = { fs = fs, t = 0, unit = unit, height = h, anchor = plate.Health or plate,
        x = math.random(-14, 14), hold = crit or nil, pop = crit or nil, crit = crit }
    plateLines[#plateLines + 1] = line
    platePlace(line, 0)
    return line
end

local function onUnitCombat(_, unit, action, flag, amount, school)
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    local d = db()
    if not d.plates or ns:G().combatTextFont == false then return end
    if d.platesTarget and not (UnitIsUnit and UnitIsUnit(unit, "target")) then return end
    if UnitIsFriend and (function() local f = UnitIsFriend("player", unit) return f and not (issecret and issecret(f)) end)() then return end
    local plate = plateFor(unit)
    if not plate then return end
    if issecret and issecret(action) then return end
    local secretAmount = issecret and issecret(amount)
    if action == "WOUND" then
        if not secretAmount and (type(amount) ~= "number" or amount <= 0) then return end
        local crit = flag == "CRITICAL" and not (issecret and issecret(flag))
        CT:PlateNumber(unit, plate, secretAmount and amount or short(amount), schoolColor(school), crit)
    elseif action == "HEAL" then
        if not d.platesHeals then return end
        if not secretAmount and (type(amount) ~= "number" or amount <= 0) then return end
        CT:PlateNumber(unit, plate, secretAmount and amount or ("+" .. short(amount)), HEAL, false)
    elseif MISSES[action] then
        if not d.platesMisses then return end
        local word = rawget(_G, action)
        CT:PlateNumber(unit, plate, type(word) == "string" and word or action:lower(), MISS, false)
    end
end
CT.OnUnitCombat = onUnitCombat

-- A plate that goes leaves its numbers where they were, to finish there.
local function onPlateRemoved(_, unit)
    for _, line in ipairs(plateLines) do
        if line.unit == unit and line.anchor then
            local a = line.anchor
            local x, top = a:GetCenter(), a:GetTop()
            local s = (a:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
            line.fx, line.fy = (x or 0) * s, (top or 0) * s
            line.anchor = nil
        end
    end
end

CT.OnPlateRemoved = onPlateRemoved

ns:On("UNIT_COMBAT", onUnitCombat)
ns:On("NAME_PLATE_UNIT_REMOVED", onPlateRemoved)

-- Off your target's plate, a few of each kind, to see the settings.
function CT:PlateSample()
    local plate
    for f in pairs(ns.Nameplates and ns.Nameplates.plates or {}) do
        local u = ns:UnitOf(f)
        if u and f:IsVisible() and UnitIsUnit and UnitIsUnit(u, "target") then plate = f break end
    end
    if not plate then
        ns.A:Print("target something with a nameplate showing to see a sample.")
        return
    end
    local u = ns:UnitOf(plate)
    CT:PlateNumber(u, plate, "1,284", WHITE, false)
    CT:PlateNumber(u, plate, "3,571", SCHOOL[2][2], true)
    if db().platesMisses then CT:PlateNumber(u, plate, rawget(_G, "DODGE") or "dodge", MISS, false) end
    if db().platesHeals then CT:PlateNumber(u, plate, "+862", HEAL, false) end
end
