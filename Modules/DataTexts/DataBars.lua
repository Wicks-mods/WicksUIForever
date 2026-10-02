-- Wick's UI
-- Modules/DataTexts/DataBars.lua: experience and reputation bars.
--
-- Thin flat bars with the numbers on hover, each with its own mover. They
-- replace Blizzard's status tracking bars, which Edit Mode otherwise
-- stacks under the action bars we have already taken away.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local DB = ns:NewModule("databars", { title = "XP and reputation", order = 81 })
ns.DataBars = DB

ns.defaults.profile.databars = {
    enable = true,
    xp  = { enable = true, width = 420, height = 8, textOnHover = true, point = "BOTTOM,UIParent,BOTTOM,0,26" },
    rep = { enable = true, width = 420, height = 8, textOnHover = true, point = "BOTTOM,UIParent,BOTTOM,0,16" },
    hideAtMax = true,
}

local function db() return DB:db() end

local function makeBar(key, label)
    local d = db()[key]
    local b = ns:CreateStatusBar(UIParent, "Default")
    b:SetFrameStrata("LOW")
    b.rested = CreateFrame("StatusBar", nil, b)
    b.rested:SetAllPoints()
    b.rested:SetStatusBarTexture(ns.Media:Statusbar())
    ns:TrackStatusBar(b.rested)
    b.rested:SetStatusBarColor(0.36, 0.61, 1, 0.35)
    b.rested:SetFrameLevel(b:GetFrameLevel())
    b:SetFrameLevel(b:GetFrameLevel() + 1)
    b.text = ns:CreateText(b, 10, "CENTER")
    b.text:SetPoint("CENTER")
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
        if db()[key].textOnHover then self.text:Show() end
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
            GameTooltip:AddLine(label, C.fel[1], C.fel[2], C.fel[3])
            self.tip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        if db()[key].textOnHover then self.text:Hide() end
        GameTooltip:Hide()
    end)
    ns:CreateMover(b, "bar_" .. key, label .. " bar", d.point, { groups = "datatexts", config = "databars" })
    return b
end

function DB:UpdateXP()
    local b = self.xp
    if not b then return end
    local d = db()
    local max = UnitXPMax("player") or 0
    local atMax = max == 0 or (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel())
    local show = d.xp.enable and not (atMax and d.hideAtMax)
    b:SetShown(show)
    if not show then return end
    local cur = UnitXP("player") or 0
    local rested = GetXPExhaustion() or 0
    b:SetMinMaxValues(0, math.max(1, max))
    b:SetValue(cur)
    b:SetStatusBarColor(0.58, 0.36, 0.86)
    b.rested:SetMinMaxValues(0, math.max(1, max))
    b.rested:SetValue(math.min(max, cur + rested))
    b.text:SetText(("%d / %d  (%d%%)%s"):format(cur, max, max > 0 and cur / max * 100 or 0,
        rested > 0 and ("  rested %d%%"):format(rested / max * 100) or ""))
    b.tip = function(tt)
        tt:AddDoubleLine("Experience", ("%d / %d"):format(cur, max), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("To level", tostring(max - cur), 1, 1, 1, 1, 1, 1)
        if rested > 0 then tt:AddDoubleLine("Rested", tostring(rested), 1, 1, 1, 0.36, 0.61, 1) end
    end
end

function DB:UpdateRep()
    local b = self.rep
    if not b then return end
    local d = db()
    local data = C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
    if not data and rawget(_G, "GetWatchedFactionInfo") then
        -- The older call, on a client without C_Reputation: the same facts
        -- as separate returns.
        local name, reaction, lo, hi, val = GetWatchedFactionInfo()
        if name then
            data = { name = name, reaction = reaction, currentReactionThreshold = lo,
                     nextReactionThreshold = hi, currentStanding = val }
        end
    end
    local show = d.rep.enable and data and data.name
    b:SetShown(show and true or false)
    if not show then return end
    local lo, hi, val = data.currentReactionThreshold or 0, data.nextReactionThreshold or 1, data.currentStanding or 0
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[data.reaction or 4] or { r = 0, g = 0.6, b = 0.1 }
    b:SetMinMaxValues(0, math.max(1, hi - lo))
    b:SetValue(val - lo)
    b:SetStatusBarColor(c.r, c.g, c.b)
    local standing = _G["FACTION_STANDING_LABEL" .. (data.reaction or 4)] or ""
    b.text:SetText(("%s  %s  %d / %d"):format(data.name, standing, val - lo, hi - lo))
    b.tip = function(tt)
        tt:AddLine(data.name, 1, 1, 1)
        tt:AddDoubleLine(standing, ("%d / %d"):format(val - lo, hi - lo), c.r, c.g, c.b, 1, 1, 1)
    end
end

function DB:Initialize()
    -- Only the manager: the two containers call their parent (the manager)
    -- from Edit Mode, so they must stay its children. Hiding the parent
    -- hides them.
    for _, n in ipairs({ "StatusTrackingBarManager" }) do
        local f = _G[n]
        if f then ns:Kill(f) end
    end
    self.xp = makeBar("xp", "Experience")
    self.rep = makeBar("rep", "Reputation")
    for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD" }) do
        ns:On(e, function() DB:UpdateXP() end)
    end
    for _, e in ipairs({ "UPDATE_FACTION", "PLAYER_ENTERING_WORLD", "QUEST_FINISHED" }) do
        ns:On(e, function() DB:UpdateRep() end)
    end
    self:Update()
end

function DB:Update()
    local d = db()
    for _, key in ipairs({ "xp", "rep" }) do
        local b = self[key]
        b:SetSize(d[key].width, d[key].height)
        ns.Movers:Resize("bar_" .. key)
        b.text:SetShown(not d[key].textOnHover)
        ns.Movers:SetEnabled("bar_" .. key, d[key].enable)
    end
    self:UpdateXP()
    self:UpdateRep()
end

ns.Config:AddPage("databars", "XP and reputation", function(L)
    L:DB(db)
    L:Toggle("Hide the XP bar at max level", "hideAtMax")
    for _, key in ipairs({ "xp", "rep" }) do
        L:Heading(key == "xp" and "Experience" or "Reputation")
        L:DB(function() return db()[key] end)
        L:Toggle("Show", "enable")
        L:Toggle("Numbers only on hover", "textOnHover")
        L:Slider("Width", "width", 50, 1200, 2)
        L:Slider("Height", "height", 2, 30, 1)
    end
    L:Note("The reputation bar follows whichever faction you have set to watch in the reputation panel.")
end, { parent = "datatexts", onChange = function() DB:Update() end, order = 81 })
