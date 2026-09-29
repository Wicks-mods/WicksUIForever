-- Wick's UI (from Wick's Comforts)
-- Glow.lua: turn off the proc glow on action buttons.
--
-- The yellow spinning overlay that appears when a spell becomes free or
-- a proc lights up. Some people read it, some people find it the single
-- most distracting thing on the screen; it has no setting of its own.
--
-- Nothing is hooked destructively. The show call is wrapped so that it
-- hides instead, and the original stays in the upvalue so switching the
-- option back off restores the game exactly.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local G = ns:Register("glow", {})

-- The overlay has moved between UI versions, so take whichever of these
-- the client actually has. Each is { show, hide }.
local PAIRS = {
    { "ActionButton_ShowOverlayGlow", "ActionButton_HideOverlayGlow" },
    { "ActionButtonSpellAlertManager", nil },
}

G.wrapped = {}

local function wrapGlobal(showName, hideName)
    if G.wrapped[showName] then return true end
    local show = rawget(_G, showName)
    local hide = hideName and rawget(_G, hideName)
    if type(show) ~= "function" then return false end
    G.wrapped[showName] = show
    _G[showName] = function(button, ...)
        if ns.db().hideProcGlow then
            if hide then return hide(button) end
            return
        end
        return show(button, ...)
    end
    return true
end

local function unwrap()
    for name, original in pairs(G.wrapped) do
        _G[name] = original
        G.wrapped[name] = nil
    end
end

-- Retail's newer path goes through a manager object rather than a global
-- function, so reach the method on it when it is there.
local function wrapManager()
    local mgr = rawget(_G, "ActionButtonSpellAlertManager")
    if not mgr or type(mgr.ShowAlert) ~= "function" then return false end
    if G.managerShow then return true end
    G.managerShow = mgr.ShowAlert
    mgr.ShowAlert = function(self, button, ...)
        if ns.db().hideProcGlow then
            if self.HideAlert then return self:HideAlert(button) end
            return
        end
        return G.managerShow(self, button, ...)
    end
    return true
end

local function unwrapManager()
    local mgr = rawget(_G, "ActionButtonSpellAlertManager")
    if mgr and G.managerShow then
        mgr.ShowAlert = G.managerShow
        G.managerShow = nil
    end
end

-- Whatever is already glowing when the option goes on has to be told to
-- stop; the wrapper only catches the next one.
local function hideCurrent()
    local hide = rawget(_G, "ActionButton_HideOverlayGlow")
    if not hide then return end
    for i = 1, 12 do
        for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton",
            "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }) do
            local b = rawget(_G, prefix .. i)
            if b and b.overlay then Core.safe(hide, b) end
        end
    end
end

function G:Apply()
    if ns.db().hideProcGlow then
        local any = false
        for _, p in ipairs(PAIRS) do
            if p[2] and wrapGlobal(p[1], p[2]) then any = true end
        end
        if wrapManager() then any = true end
        self.active = any
        hideCurrent()
    else
        unwrap()
        unwrapManager()
        self.active = false
    end
end

function G:Init()
    self:Apply()
end
