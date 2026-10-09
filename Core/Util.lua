-- Wick's UI
-- Core/Util.lua: events, the combat queue, hiding Blizzard frames, pixels.

local ADDON, ns = ...

local InCombatLockdown = InCombatLockdown
local floor = math.floor

-- ============================================================
-- Events
-- ============================================================
-- One frame for the whole addon. Handlers are protected so one bad
-- handler cannot stop the others hearing the event.
local handlers = {}
local events = CreateFrame("Frame", "WicksUIEvents")
events:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        ns:Begin(event)
        local ok, err = pcall(list[i], event, ...)
        ns:End()
        if not ok then
            ns.errors = ns.errors or {}
            ns.errors[#ns.errors + 1] = event .. ": " .. tostring(err)
            if ns.A then ns.A:Debug(event .. ": " .. tostring(err)) end
        end
    end
end)

-- ============================================================
-- Run-time watch
-- ============================================================
-- Forever stops an addon whose code runs too long at once and names only
-- the addon. Longer pieces of work mark themselves with ns:Begin and
-- ns:End: one that finishes slow is noted with its time, and one the
-- client stops part way leaves its mark, which the next frame finds and
-- notes as stopped. /wui errors lists them.
local SLOW_MS = 12
local marks = {}
local clock = rawget(_G, "debugprofilestop")
local seen = {}
local function note(text)
    ns.errors = ns.errors or {}
    if seen[text] then
        local e = ns.errors[seen[text]]
        if e then ns.errors[seen[text]] = e:gsub(" %(x%d+%)$", "") .. (" (x%d)"):format((tonumber(e:match("%(x(%d+)%)$")) or 1) + 1) end
        return
    end
    ns.errors[#ns.errors + 1] = text
    seen[text] = #ns.errors
end
function ns:Begin(label)
    marks[#marks + 1] = { label = label, t = clock and clock() or 0 }
end
function ns:End()
    local m = table.remove(marks)
    if not (m and clock) then return end
    local ms = clock() - m.t
    if ms > SLOW_MS then note(("slow: %s, %d ms"):format(m.label, ms)) end
end
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    if #marks == 0 then return end
    for _, m in ipairs(marks) do note("stopped part way: " .. m.label) end
    for i = #marks, 1, -1 do marks[i] = nil end
end)

function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(events.RegisterEvent, events, event)
    end
    local list = handlers[event]
    list[#list + 1] = fn
    return fn
end

function ns:Off(event, fn)
    local list = handlers[event]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
    if #list == 0 then
        handlers[event] = nil
        pcall(events.UnregisterEvent, events, event)
    end
end

-- ============================================================
-- The combat queue
-- ============================================================
-- Secure frames cannot be moved, shown, hidden or given attributes in
-- combat. Anything that has to do that asks here: it runs now if it can,
-- or once the fight ends. Keyed, so ten setting changes in a fight turn
-- into one rebuild afterwards rather than ten.
local queue, queueOrder = {}, {}

function ns:InCombat() return InCombatLockdown() end

function ns:AfterCombat(key, fn, ...)
    if not InCombatLockdown() then
        return fn(...)
    end
    if not queue[key] then queueOrder[#queueOrder + 1] = key end
    queue[key] = { fn = fn, n = select("#", ...), ... }
    return nil
end

ns:On("PLAYER_REGEN_ENABLED", function()
    local keys = queueOrder
    queueOrder = {}
    for _, key in ipairs(keys) do
        local job = queue[key]
        queue[key] = nil
        if job then
            local ok, err = pcall(job.fn, unpack(job, 1, job.n))
            if not ok and ns.A then ns.A:Print("after combat, " .. tostring(key) .. ": " .. tostring(err)) end
        end
    end
end)

-- ============================================================
-- Hiding Blizzard frames
-- ============================================================
-- A hidden parent, never shown. Reparenting a frame to it hides the frame
-- and everything under it without calling Hide, which Blizzard code tends
-- to undo on the next event.
ns.hider = CreateFrame("Frame", "WicksUIHider", UIParent)
ns.hider:Hide()

-- Take a Blizzard frame out of the picture. Only ever out of combat, and
-- only what the matching module replaces: a module that is switched off
-- must leave the game's frame alone.
--
-- This client taints anything an addon writes into a Blizzard table, so
-- this never sets a field on the frame. It reparents, silences events and,
-- where the client supports it, tags the frame with the always-blocked
-- roleset that Blizzard's own UI mode system uses to keep frames down.
function ns:Kill(frame, opts)
    if type(frame) == "string" then frame = _G[frame] end
    if type(frame) ~= "table" then return false end
    opts = opts or {}
    return ns:AfterCombat(frame, function()
        if not opts.keepEvents and frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
        if opts.roleset ~= false and frame.SetRolesets then pcall(frame.SetRolesets, frame, "alwaysBlocked") end
        if frame.SetParent then frame:SetParent(ns.hider) end
        return true
    end)
end

-- ============================================================
-- Pixels
-- ============================================================
-- One physical pixel in UIParent units. Borders drawn at this size stay
-- one pixel at any scale, which is most of what makes a flat UI look
-- crisp rather than smudged.
function ns:UpdatePixel()
    local _, h = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    if not h or h == 0 or not scale or scale == 0 then
        ns.mult = 1
    else
        ns.mult = 768 / h / scale
    end
    if not ns:G().pixelPerfect then ns.mult = 1 end
    return ns.mult
end
ns.mult = 1

-- Round a size to whole physical pixels.
function ns:Px(v)
    local m = ns.mult or 1
    if v == 0 then return 0 end
    return m * floor(v / m + 0.5)
end

-- ============================================================
-- Points
-- ============================================================
-- Positions are saved as "POINT,relativeTo,relPoint,x,y". Plain strings,
-- so a profile export is readable and a hand edit is possible.
function ns:PointToString(frame)
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    local relName = rel and rel.GetName and rel:GetName() or "UIParent"
    return ("%s,%s,%s,%d,%d"):format(point, relName, relPoint or point, floor((x or 0) + 0.5), floor((y or 0) + 0.5))
end

function ns:StringToPoint(s)
    if type(s) ~= "string" then return nil end
    local point, rel, relPoint, x, y = strsplit(",", s)
    return point, (rel and _G[rel]) or UIParent, relPoint or point, tonumber(x) or 0, tonumber(y) or 0
end

-- ============================================================
-- Small things
-- ============================================================
function ns:Round(v, places)
    local m = 10 ^ (places or 0)
    return floor(v * m + 0.5) / m
end

function ns:Copy(t) return ns.Core.copy(t) end

-- Whether a saved colour is still the given one, to the precision a
-- colour picker or a saved variable keeps.
local RGB = { "r", "g", "b" }
function ns:SameColor(c, ref)
    if type(c) ~= "table" or type(ref) ~= "table" then return false end
    for i = 1, 3 do
        local v = c[i] or c[RGB[i]]
        if type(v) ~= "number" or math.abs(v - ref[i]) > 0.002 then return false end
    end
    return true
end

-- Class colour, through WickCore so the player's colour-set choice holds.
function ns:ClassColor(class)
    local Chrome = ns.Core.Chrome
    if Chrome and Chrome.ClassColor then
        -- WickCore hands back r, g, b as numbers; accept a colour table too.
        local c, g, b = Chrome:ClassColor(class)
        if type(c) == "number" then return c, g or 1, b or 1 end
        if type(c) == "table" then return c[1] or c.r, c[2] or c.g, c[3] or c.b end
    end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

ns.myClass = select(2, UnitClass("player"))
ns.myName = UnitName("player")

-- Split "a, b ,c" into { "a", "b", "c" }.
function ns:List(s)
    local out = {}
    for piece in tostring(s or ""):gmatch("[^,]+") do
        piece = piece:match("^%s*(.-)%s*$")
        if piece ~= "" then out[#out + 1] = piece end
    end
    return out
end
