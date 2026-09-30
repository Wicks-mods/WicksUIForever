-- Wick's UI
-- Modules/ActionBars/Keybind.lua: hover a button, press a key.
--
-- /wui kb (or the Keybinds button in the settings). While it is on, a
-- catcher frame sits over whichever button the pointer is on and takes
-- the next key, mouse button or wheel turn as that button's binding.
-- Escape clears the button. Nothing is kept until Save; Discard puts the
-- bindings back the way they were.
--
-- Binds go to the game's own binding for the button (ACTIONBUTTON3,
-- SHAPESHIFTBUTTON2 and so on), so they show in the game's keybinding
-- menu and survive the addon being switched off.

local ADDON, ns = ...

local AB = ns.ActionBars
local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local K = {}
ns.Keybind = K

local IGNORE = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true,
}
local MOUSE = {
    LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3",
    Button4 = "BUTTON4", Button5 = "BUTTON5",
}

local active = false
local current
local catcher, panel

local function targetOf(b)
    return b.wuiBindTarget or b.keyBoundTarget
end

local function keysFor(target)
    local out = {}
    if not target then return out end
    for _, k in ipairs({ GetBindingKey(target) }) do
        if k and k ~= "" then out[#out + 1] = GetBindingText and GetBindingText(k, 1) or k end
    end
    return out
end

local function showTip(b)
    local target = b and targetOf(b)
    if not target then return end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:AddLine(target, C.fel[1], C.fel[2], C.fel[3])
    local keys = keysFor(target)
    if #keys == 0 then
        GameTooltip:AddLine("No key bound.", 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine(table.concat(keys, ", "), 1, 1, 1)
    end
    GameTooltip:AddLine("Press a key to bind it. Escape clears the button.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function modifiers()
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
end

local function bind(key)
    if not current or InCombatLockdown() then return end
    local target = targetOf(current)
    if not target then return end
    if key == "ESCAPE" then
        for _, k in ipairs({ GetBindingKey(target) }) do
            if k and k ~= "" then SetBinding(k) end
        end
        ns.A:Print("cleared " .. target .. ".")
    else
        local full = modifiers() .. key
        -- One key, one action: whatever had it loses it.
        SetBinding(full, target)
        ns.A:Print(("%s bound to %s."):format(full, target))
    end
    K.dirty = true
    showTip(current)
end

local function makeCatcher()
    catcher = CreateFrame("Button", "WicksUIBindCatcher", UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:EnableKeyboard(true)
    catcher:EnableMouseWheel(true)
    catcher:RegisterForClicks("AnyUp")
    local t = catcher:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.3)
    catcher:SetScript("OnKeyDown", function(_, key)
        if IGNORE[key] then return end
        bind(key)
    end)
    catcher:SetScript("OnClick", function(_, button)
        local k = MOUSE[button]
        -- A plain left or right click would unbind the mouse itself, so
        -- those two only bind with a modifier held.
        if (button == "LeftButton" or button == "RightButton") and modifiers() == "" then return end
        if k then bind(k) end
    end)
    catcher:SetScript("OnMouseWheel", function(_, delta)
        bind(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)
    catcher:SetScript("OnLeave", function(self)
        self:Hide()
        current = nil
        GameTooltip:Hide()
    end)
    catcher:Hide()
end

function K:Hover(b)
    if not active or not b or not targetOf(b) or InCombatLockdown() then return end
    current = b
    catcher:ClearAllPoints()
    catcher:SetAllPoints(b)
    catcher:Show()
    -- The button's own tip: the catcher over it has nothing to bind.
    showTip(b)
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookAll()
    for _, bar in pairs(AB.bars) do
        for i, b in ipairs(bar.buttons or {}) do
            if bar.id == "stance" then b.wuiBindTarget = "SHAPESHIFTBUTTON" .. i end
            if bar.id == "pet" then b.wuiBindTarget = "BONUSACTIONBUTTON" .. i end
            if not hooked[b] then
                hooked[b] = true
                b:HookScript("OnEnter", function(self) K:Hover(self) end)
            end
        end
    end
end

local function makePanel()
    panel = CreateFrame("Frame", "WicksUIBindPanel", UIParent)
    panel:SetSize(360, 120)
    panel:SetPoint("TOP", 0, -120)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    ns:SetTemplate(panel, "Default", { brackets = true })
    local title = ns:CreateText(panel, 13, "CENTER", "NONE")
    title:SetPoint("TOP", 0, -10)
    title:SetText(Chrome:TitleMarkup("Wick's UI") .. "  " .. Chrome:Esc("muted") .. "keybind mode|r")
    local note = ns:CreateText(panel, 11, "CENTER", "NONE")
    note:SetWordWrap(true)
    note:SetPoint("TOPLEFT", 14, -30)
    note:SetPoint("TOPRIGHT", -14, -30)
    note:SetText("Point at a button and press a key, a mouse button or turn the wheel. Escape clears the button. Left and right click only bind with a modifier held.")
    note:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

    panel.perChar = W:Check(panel, "Save for this character only", function()
        return GetCurrentBindingSet and GetCurrentBindingSet() == 2
    end, function(v) K.perChar = v end, { width = 220 })
    panel.perChar:SetPoint("BOTTOMLEFT", 12, 34)

    local save = W:Button(panel, "Save", 90, function() K:Deactivate(true) end)
    save:SetPoint("BOTTOMRIGHT", -12, 10)
    local discard = W:Button(panel, "Discard", 90, function() K:Deactivate(false) end)
    discard:SetPoint("RIGHT", save, "LEFT", -6, 0)
end

function K:Activate()
    if InCombatLockdown() then
        ns.A:Print("keybinds cannot change in combat.")
        return
    end
    if not catcher then makeCatcher() end
    if not panel then makePanel() end
    hookAll()
    active = true
    K.dirty = false
    K.perChar = GetCurrentBindingSet and GetCurrentBindingSet() == 2
    panel.perChar:Refresh()
    panel:Show()
end

function K:Deactivate(save)
    active = false
    current = nil
    if catcher then catcher:Hide() end
    if panel then panel:Hide() end
    GameTooltip:Hide()
    if save then
        local set = K.perChar and 2 or 1
        SaveBindings(set)
        ns.A:Print("keybinds saved" .. (K.perChar and " for this character." or "."))
    elseif K.dirty and LoadBindings and GetCurrentBindingSet then
        LoadBindings(GetCurrentBindingSet())
        ns.A:Print("keybind changes discarded.")
    end
end

function K:Toggle() if active then self:Deactivate(true) else self:Activate() end end

ns:On("PLAYER_REGEN_DISABLED", function()
    if active then
        K:Deactivate(true)
        ns.A:Print("keybind mode closed for combat, changes kept.")
    end
end)
