-- Wick's UI
-- Core/Pad.lua: playing on a controller.
--
-- Forever runs its interface in one of two styles, mouse and keyboard or
-- controller, and moves between them as the player takes up one or the
-- other. On the controller the game shows its own controller bars (the
-- D-pad and face button clusters) and puts away its usual bars, micro
-- menu and bag bar. Wick's UI follows: its action bars stand aside for
-- the controller bars, the frames along the bottom keep clear of them,
-- and the controller bars wear the look (Modules/ActionBars/Pad.lua).
-- TBC Anniversary has no controller interface; nothing here acts there.

local ADDON, ns = ...

local Pad = { listeners = {} }
ns.Pad = Pad

-- What the player chose, on the Action bars page.
function Pad:Settings()
    local p = ns.A and ns.A.db and ns.A.db.profile
    local ab = p and p.actionbars
    return (ab and ab.pad) or {}
end

-- True while the interface is in its controller style.
function Pad:Active()
    local S = rawget(_G, "C_InputInterfaceStyle")
    local E = rawget(_G, "Enum") and Enum.InputDeviceInterfaceType
    if not (S and S.GetCurrentStyle and E and E.Gamepad) then return false end
    local ok, style = pcall(S.GetCurrentStyle)
    return (ok and style == E.Gamepad) and true or false
end

-- The game's controller bars, where this client has them.
function Pad:Bars() return rawget(_G, "GamepadMainActionBarFrame") end

-- Wick's bars stand aside while the controller is in use, unless the
-- player keeps them.
function Pad:HideBars() return self:Active() and self:Settings().hideBars ~= false end

-- fn(active) runs whenever the interface changes style.
function Pad:OnChange(fn) self.listeners[#self.listeners + 1] = fn end

-- Whether Wick's UI stands aside on the controller: at a login on the
-- controller it builds nothing and the game's own interface runs, and a
-- change of interface asks for a reload. The client's controller
-- interface is new, and it watches, walks and tears down frames in ways
-- an addon's frames and taint trip; until those are all found, this is
-- the safe way to play on a controller. On by default.
function Pad:StandAside() return self:Settings().standAside ~= false end

-- True for this session when it logged in standing aside.
Pad.standingAside = false

local function reloadPrompt(text)
    local Chrome = ns.Core and ns.Core.Chrome
    if Chrome and Chrome.ReloadPrompt then Chrome:ReloadPrompt(text) end
end

-- The style last acted on. The interface loads in the mouse and keyboard
-- style's layout; a controller already in use is acted on as it enters
-- the world.
Pad.applied = false

function Pad:Apply()
    local on = self:Active()
    if on == self.applied then return end
    self.applied = on
    if self.standingAside then
        -- Nothing of ours is built. Back on the mouse and keyboard, a
        -- reload brings it back.
        if not on then reloadPrompt("Wick's UI comes back with a reload.") end
        return
    end
    if on and self:StandAside() then
        reloadPrompt("Wick's UI stands aside on the controller. Reload for the game's own interface, or switch that off under Action bars, Controller.")
    end
    for _, fn in ipairs(self.listeners) do
        local ok, err = pcall(fn, on)
        if not ok then
            ns.errors = ns.errors or {}
            ns.errors[#ns.errors + 1] = "controller: " .. tostring(err)
        end
    end
end

-- With a controller in hand and the keyboard in use (typing), the
-- interface can change style many times a second. Acting on each change
-- went past the client's limit on how long an addon may run at once, and
-- the game lagged and then closed. So a change is acted on once the style
-- has held for a moment, and only if it differs from the one last acted
-- on.
local SETTLE = 0.4
local gen = 0
function Pad:Changed()
    gen = gen + 1
    local mine = gen
    C_Timer.After(SETTLE, function() if mine == gen then Pad:Apply() end end)
end

ns:On("INPUT_DEVICE_INTERFACE_TRANSITION", function() Pad:Changed() end)
ns:On("PLAYER_ENTERING_WORLD", function() Pad:Changed() end)
