-- Wick's UI
-- Modules/Extras/Extras.lua: the small things.
--
--   Raid marker bar: secure macro buttons, so marking works in combat.
--     Left-click marks your target, right-click drops the world marker.
--   Error filter: the red "not enough rage" text stays quiet in combat.
--   AFK screen: the interface steps aside while you are away.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local EX = ns:NewModule("extras", { title = "Extras", order = 90 })
ns.Extras = EX

ns.defaults.profile.extras = {
    enable = true,
    markers = true, markerSize = 24, markerVertical = false, markerVisibility = "[group] show; hide",
    markerPoint = "TOP,UIParent,TOP,0,-60",
    quietErrors = true,
    afk = false,
}

local function db() return EX:db() end

-- ============================================================
-- Raid markers
-- ============================================================
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"

function EX:BuildMarkers()
    local bar = CreateFrame("Frame", "WicksUI_MarkerBar", UIParent, "SecureHandlerStateTemplate")
    bar:SetSize(1, 1)
    ns:CreateBackdrop(bar, "Transparent")
    bar.buttons = {}
    for i = 1, 9 do
        local b = CreateFrame("Button", "WicksUI_Marker" .. i, bar, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "macro")
        if i <= 8 then
            b:SetAttribute("macrotext1", "/tm " .. i)
            b:SetAttribute("macrotext2", "/wm " .. i)
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 2, -2)
            t:SetPoint("BOTTOMRIGHT", -2, 2)
            t:SetTexture(ICON:format(i))
        else
            -- The last one clears: your target's marker, or every world marker.
            b:SetAttribute("macrotext1", "/tm 0")
            b:SetAttribute("macrotext2", "/cwm all")
            local t = ns:CreateText(b, 14, "CENTER")
            t:SetPoint("CENTER")
            t:SetText("x")
        end
        ns:SetTemplate(b, "Shadow")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.15)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(i <= 8 and "Left-click: mark your target. Right-click: world marker." or "Left-click: clear your target's marker. Right-click: clear every world marker.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar.buttons[i] = b
    end
    ns:CreateMover(bar, "markers", "Raid markers", db().markerPoint, { groups = "misc", config = "extras" })
    self.markers = bar
end

function EX:LayoutMarkers()
    local bar, d = self.markers, db()
    local s, sp = d.markerSize, 2
    for i, b in ipairs(bar.buttons) do
        b:SetSize(s, s)
        b:ClearAllPoints()
        if d.markerVertical then
            b:SetPoint("TOP", bar, "TOP", 0, -sp - (i - 1) * (s + sp))
        else
            b:SetPoint("LEFT", bar, "LEFT", sp + (i - 1) * (s + sp), 0)
        end
    end
    if d.markerVertical then bar:SetSize(s + sp * 2, 9 * (s + sp) + sp) else bar:SetSize(9 * (s + sp) + sp, s + sp * 2) end
    ns.Movers:Resize("markers")
    if d.markers then
        RegisterStateDriver(bar, "visibility", d.markerVisibility)
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
    end
    ns.Movers:SetEnabled("markers", d.markers)
end

-- ============================================================
-- Quiet errors in combat
-- ============================================================
local function quiet(on)
    local f = rawget(_G, "UIErrorsFrame")
    if not f then return end
    if on then f:UnregisterEvent("UI_ERROR_MESSAGE") else f:RegisterEvent("UI_ERROR_MESSAGE") end
end

-- ============================================================
-- AFK screen
-- ============================================================
function EX:AFKFrame()
    local f = self.afkFrame
    if f then return f end
    f = CreateFrame("Frame", "WicksUI_AFK", WorldFrame)
    f:SetAllPoints()
    f:SetFrameStrata("FULLSCREEN")
    f:Hide()
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetHeight(90)
    ns:SetTemplate(bar, "Default", { brackets = true })
    local name = ns:CreateText(bar, 22, "LEFT", "NONE")
    name:SetPoint("LEFT", 30, 12)
    local r, g, b = ns:ClassColor(ns.myClass)
    name:SetText(("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, ns.myName))
    local sub = ns:CreateText(bar, 13, "LEFT", "NONE")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    local brand = ns:CreateText(bar, 16, "RIGHT", "NONE")
    brand:SetPoint("RIGHT", -30, 0)
    brand:SetText(Chrome:TitleMarkup("Wick's UI"))
    f.sub = sub
    f:SetScript("OnUpdate", function(self, e)
        self.acc = (self.acc or 0) + e
        if self.acc < 1 then return end
        self.acc = 0
        local secs = math.floor(GetTime() - (self.since or GetTime()))
        self.sub:SetText(("Away for %d:%02d   |cff8f8770move or type to come back|r"):format(math.floor(secs / 60), secs % 60))
    end)
    self.afkFrame = f
    return f
end

function EX:SetAFK(on)
    local f = self:AFKFrame()
    if on and not InCombatLockdown() then
        f.since = GetTime()
        f:Show()
        UIParent:Hide()
        if MoveViewLeftStart then MoveViewLeftStart(0.05) end
        self.afkOn = true
    elseif self.afkOn then
        self.afkOn = nil
        f:Hide()
        if MoveViewLeftStop then MoveViewLeftStop() end
        if not InCombatLockdown() then UIParent:Show() else ns:AfterCombat("afk", function() UIParent:Show() end) end
    end
end

-- ============================================================
-- Lifecycle
-- ============================================================
function EX:Initialize()
    self:BuildMarkers()
    ns:On("PLAYER_REGEN_DISABLED", function() if db().quietErrors then quiet(true) end end)
    ns:On("PLAYER_REGEN_ENABLED", function() quiet(false) end)
    ns:On("PLAYER_FLAGS_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        EX:SetAFK(db().afk and UnitIsAFK("player"))
    end)
    ns:On("PLAYER_REGEN_DISABLED", function() if EX.afkOn then EX:SetAFK(false) end end)
    self:Update()
end

function EX:Update()
    ns:AfterCombat("extras", function() EX:LayoutMarkers() end)
end

ns.Config:AddPage("extras", "Extras", function(L)
    L:DB(db)
    L:Heading("Raid markers")
    L:Toggle("Marker bar", "markers")
    L:Toggle("Upright", "markerVertical")
    L:Slider("Button size", "markerSize", 14, 48, 1)
    L:Input("When it shows", "markerVisibility", { tooltip = "A macro condition. The default shows it in any group." })
    L:Heading("Other")
    L:Toggle("No red error text in combat", "quietErrors", { tooltip = "The \"not enough rage\" and \"out of range\" lines. They come back when the fight ends." })
    L:Toggle("AFK screen", "afk", { tooltip = "Hides the interface and turns the camera slowly while you are away. Ends at once if a fight starts." })
end, { onChange = function() EX:Update() end, order = 90 })
