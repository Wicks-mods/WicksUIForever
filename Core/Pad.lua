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

function Pad:Changed()
    local on = self:Active()
    for _, fn in ipairs(self.listeners) do
        local ok, err = pcall(fn, on)
        if not ok then
            ns.errors = ns.errors or {}
            ns.errors[#ns.errors + 1] = "controller: " .. tostring(err)
        end
    end
end

ns:On("INPUT_DEVICE_INTERFACE_TRANSITION", function() Pad:Changed() end)
