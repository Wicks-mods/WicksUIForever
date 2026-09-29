-- Wick's UI
-- Modules/Auras/Auras.lua: your buffs and debuffs, top right.
--
-- The game's own buff frame is replaced by two of the client's aura
-- containers. The client fills them, times them and cancels a buff on
-- right-click itself, so all of it keeps working in combat, where this
-- client does not let addons read auras at all.
--
-- The containers hang off a hidden oUF frame for the player, because oUF
-- already wraps the container API; the frame itself takes no clicks and
-- shows nothing.

local ADDON, ns = ...

local oUF = ns.oUF
local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local AU = ns:NewModule("auras", { title = "Buffs", order = 40 })
ns.Auras = AU

local function group(o)
    local d = { enable = true, size = 32, perRow = 12, rows = 3, spacing = 4, rowSpacing = 14,
        growthX = "LEFT", growthY = "DOWN", showDuration = true, showCount = true }
    for k, v in pairs(o) do d[k] = v end
    return d
end

ns.defaults.profile.auras = {
    enable = true,
    buffs   = group({ point = "TOPRIGHT,UIParent,TOPRIGHT,-220,-8" }),
    debuffs = group({ size = 40, perRow = 8, rows = 1, point = "TOPRIGHT,UIParent,TOPRIGHT,-220,-150" }),
}

local function db() return AU:db() end

local function postCreate(size, showTime)
    return function(_, button)
        ns:AuraCountdown(button, size, showTime)
        if button.Icon then ns:CropIcon(button.Icon) end
        ns:CreateBackdrop(button, "Default", ns.mult)
        if button.Count then ns.Media:SetFont(button.Count, math.max(10, math.floor(size * 0.38)), "OUTLINE") end
        if button.Duration then
            ns.Media:SetFont(button.Duration, math.max(9, math.floor(size * 0.32)), "OUTLINE")
            button.Duration:ClearAllPoints()
            button.Duration:SetPoint("TOP", button, "BOTTOM", 0, -2)
        end
    end
end

local function build(self, which, d)
    local width = d.perRow * (d.size + d.spacing)
    local a = self:CreateAuras({
        initialAnchor = d.growthX == "LEFT" and "TOPRIGHT" or "TOPLEFT",
        growthX = d.growthX, growthY = d.growthY,
        layoutLimit = width,
    })
    a.size = d.size
    a.elementSpacing = d.spacing
    a.lineSpacing = d.rowSpacing
    a.showCount = d.showCount
    -- The time is the client's countdown (see ns:AuraCountdown), not ours.
    a.showDuration = false
    a.showDebuffBorder = which == "debuffs"
    a.cancelButton = which == "buffs" and "RightButtonUp" or nil
    a.tooltipAnchor = "ANCHOR_BOTTOMLEFT"
    a.PostCreateButton = postCreate(d.size, d.showDuration)
    a:AddGroup(which == "buffs" and "HELPFUL" or "HARMFUL", { maxFrameCount = d.perRow * d.rows })
    a:SetSize(width, d.rows * (d.size + d.rowSpacing))

    -- A plain holder carries the mover; the container hangs from it.
    local holder = CreateFrame("Frame", "WicksUI_" .. which .. "Holder", UIParent)
    holder:SetSize(width, d.rows * (d.size + d.rowSpacing))
    a:SetParent(holder)
    a:ClearAllPoints()
    a:SetPoint(d.growthX == "LEFT" and "TOPRIGHT" or "TOPLEFT", holder)
    ns:CreateMover(holder, "auras_" .. which, which == "buffs" and "Buffs" or "Debuffs", d.point,
        { groups = "auras", config = "auras" })
    AU[which] = a
    AU[which .. "Holder"] = holder
end

local function style(self)
    self:EnableMouse(false)
    self:SetSize(1, 1)
    local d = db()
    build(self, "buffs", d.buffs)
    build(self, "debuffs", d.debuffs)
end

function AU:Initialize()
    ns:Kill(_G.BuffFrame)
    ns:Kill(_G.DebuffFrame)
    oUF:RegisterStyle("WicksUI_Auras", style)
    oUF:SetActiveStyle("WicksUI_Auras")
    local f = oUF:Spawn("player", "WicksUI_AuraHost")
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
    -- A mouse-transparent host should never target you on a click.
    f:SetAttribute("*type1", nil)
    f:SetAttribute("*type2", nil)
    self.host = f
    oUF:SetActiveStyle("WicksUI")
    self:Update()
end

function AU:Update()
    ns:AfterCombat("auras:update", function()
        local d = db()
        for _, which in ipairs({ "buffs", "debuffs" }) do
            local a, holder, g = self[which], self[which .. "Holder"], d[which]
            if a then
                holder:SetShown(g.enable)
                ns.Movers:SetEnabled("auras_" .. which, g.enable)
            end
        end
    end)
end

ns.Config:AddPage("auras", "Buffs", function(L)
    L:Note("Your buffs and debuffs, drawn by the client so they keep their timers in combat. Right-click a buff to cancel it. Sizes and counts are handed to the client when the display is made, so those take effect after a reload.")
    for _, which in ipairs({ "buffs", "debuffs" }) do
        L:Heading(which == "buffs" and "Buffs" or "Debuffs")
        L:DB(function() return db()[which] end)
        L:Toggle("Show", "enable")
        L:Toggle("Time left", "showDuration")
        L:Slider("Icon size", "size", 16, 64, 1)
        L:Slider("Per row", "perRow", 1, 24, 1)
        L:Slider("Rows", "rows", 1, 6, 1)
        L:Slider("Spacing", "spacing", 0, 20, 1)
        L:Slider("Row spacing", "rowSpacing", 0, 30, 1)
        L:Dropdown("Grow across", "growthX", { { "LEFT", "Left" }, { "RIGHT", "Right" } })
        L:Dropdown("Grow down or up", "growthY", { { "DOWN", "Down" }, { "UP", "Up" } })
    end
end, { onChange = function() AU:Update() end, order = 40 })
