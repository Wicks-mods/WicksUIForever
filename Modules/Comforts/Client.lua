-- Wick's UI (from Wick's Comforts)
-- Client.lua: settings the game has but does not put in its own panel.
--
-- Both of these are console variables. Driving the variable rather than
-- reimplementing the behaviour means they survive this addon being
-- disabled, and nothing here fights Blizzard's own options.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local C = ns:Register("client", {})

-- Mainline calls it cameraDistanceMaxZoomFactor and the Classic line
-- calls it cameraDistanceMaxFactor. This client is Mainline-shaped but
-- Classic-descended, so take whichever one it actually answers to
-- rather than assuming.
local ZOOM_NAMES = { "cameraDistanceMaxZoomFactor", "cameraDistanceMaxFactor" }
local SOUND = "Sound_EnableSoundWhenGameIsInBG"

-- The chat boxes on this client come up in the old alt arrow mode: the
-- arrows steer your character and it takes Alt and an arrow to move the
-- cursor or walk back through what you typed. Every other text box in
-- the game, and every text box outside it, does the opposite.
--
-- This is not a console variable, it is a property of each edit box, so
-- it has to be set on every one of them and set again for any window
-- opened later.
local function eachChatBox(fn)
    local n = rawget(_G, "NUM_CHAT_WINDOWS") or 10
    for i = 1, n do
        local box = rawget(_G, "ChatFrame" .. i .. "EditBox")
        if box and box.SetAltArrowKeyMode then pcall(fn, box) end
    end
end

-- The client refuses a factor above its own ceiling, and the ceiling has
-- moved between expansions. Walk down from the highest any build has
-- allowed and keep the first one that sticks.
local CANDIDATES = { 4.0, 3.4, 2.6, 1.9 }

-- Which of the names this client has, and what it was set to before we
-- touched it.
function C:ZoomCVar()
    -- Only a hit is remembered. Caching a miss meant that if the first
    -- look happened before the console variables were readable we gave
    -- up for the rest of the session and the option did nothing.
    if self.zoomName then return self.zoomName end
    for _, name in ipairs(ZOOM_NAMES) do
        if ns.cvGet(name) ~= nil then
            self.zoomName = name
            self.zoomWas = ns.cvGet(name)
            return name
        end
    end
    return nil
end

function C:MaxZoom()
    local name = self:ZoomCVar()
    if not name then return nil end
    if self.found then return self.found end
    for _, v in ipairs(CANDIDATES) do
        ns.cvSet(name, tostring(v))
        local got = tonumber(ns.cvGet(name) or "")
        if got and math.abs(got - v) < 0.01 then
            self.found = v
            return v
        end
    end
    -- Nothing took. Put back whatever was there rather than leaving the
    -- last rejected attempt sitting in the variable.
    if self.zoomWas then ns.cvSet(name, self.zoomWas) end
    return nil
end

-- Raising the ceiling does not move the camera; it only allows the next
-- scroll to go further. Pushing it out once is the difference between
-- "nothing happened" and "there it is".
function C:PushOut()
    local out = rawget(_G, "CameraZoomOut")
    if out then pcall(out, 50) end
end

function C:Apply()
    local db = ns.db()

    local name = self:ZoomCVar()
    if db.maxCameraZoom then
        local v = self:MaxZoom()
        if v and name and tonumber(ns.cvGet(name) or "") ~= v then
            ns.cvSet(name, tostring(v))
        end
        if v and not self.pushed then
            self.pushed = true
            self:PushOut()
        end
    elseif self.found and name then
        -- Only put it back if we were the one who moved it.
        ns.cvSet(name, self.zoomWas or "1")
        self.found, self.pushed = nil, nil
    end

    if db.soundInBackground then
        if ns.cvGet(SOUND) ~= "1" then ns.cvSet(SOUND, "1") end
    end

    -- Off puts the client default back rather than leaving our state
    -- behind: switching a comfort off should leave no trace of it.
    local alt = not db.chatArrowKeys
    eachChatBox(function(box) box:SetAltArrowKeyMode(alt) end)
end

function C:Init()
    -- The camera factor is reset on some loading screens, so put it back
    -- once the world is there rather than only at login. The camera
    -- itself is only pushed out once, not on every zone change.
    ns.RegisterEvents({ "PLAYER_ENTERING_WORLD", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS" })
    ns:On("PLAYER_ENTERING_WORLD", function() Core.safe(C.Apply, C) end)
    -- A chat window opened or docked after login comes up with the
    -- client default, so catch it rather than only doing this at login.
    ns:On("UPDATE_CHAT_WINDOWS", function() Core.safe(C.Apply, C) end)
    ns:On("UPDATE_FLOATING_CHAT_WINDOWS", function() Core.safe(C.Apply, C) end)
end

-- Said out loud, because a camera setting that does nothing looks the
-- same as one that is not there.
function C:Report()
    local name = self:ZoomCVar()
    if not name then
        ns.A:Print("camera: this client has neither cameraDistanceMaxZoomFactor nor cameraDistanceMaxFactor.")
        return
    end
    ns.A:Print(("camera: %s is %s, was %s before we touched it, highest this client accepted %s.")
        :format(name, tostring(ns.cvGet(name)), tostring(self.zoomWas), tostring(self.found)))
    ns.A:Print("if the view did not change, scroll out: the setting raises the limit, it does not move the camera.")
end
