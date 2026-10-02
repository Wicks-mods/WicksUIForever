-- Wick's UI
-- Modules/Auras/Auras.lua: your buffs and debuffs, top right.
--
-- On a client with the aura container (Forever) the game's own buff frame
-- is replaced by two of the client's containers. The client fills them,
-- times them and cancels a buff on right-click itself, so all of it keeps
-- working in combat, where that client does not let addons read auras at
-- all. The containers hang off a hidden oUF frame for the player, because
-- oUF already wraps the container API; the frame itself takes no clicks
-- and shows nothing.
--
-- On a client without the container (TBC Anniversary) the same two
-- displays are secure aura headers. The client's own secure code sorts
-- the auras and places a button per aura, in combat too, and a
-- right-click cancels a buff through the protected cancelaura action.
-- The buttons come from our template (AuraButton.xml) and are drawn
-- here: icon, count, time left, the dispel colour on a debuff's border.

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

-- Our dress on an aura button, whichever code made it: the time text
-- centred in our font (the client's countdown hidden), the icon cropped,
-- our border round it, the count in our font.
local function dress(button, size, showTime)
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

local function postCreate(size, showTime)
    return function(_, button) dress(button, size, showTime) end
end

-- The corner the first icon sits in: the rows grow away from it, so
-- growing left and up starts at the bottom right.
local function startCorner(d)
    return (d.growthY == "UP" and "BOTTOM" or "TOP") .. (d.growthX == "LEFT" and "RIGHT" or "LEFT")
end

-- A plain holder carries the mover; the display hangs from it.
local function holderFor(which, d, width, height, display, corner)
    local holder = CreateFrame("Frame", "WicksUI_" .. which .. "Holder", UIParent)
    holder:SetSize(width, height)
    display:SetParent(holder)
    display:ClearAllPoints()
    display:SetPoint(corner, holder)
    ns:CreateMover(holder, "auras_" .. which, which == "buffs" and "Buffs" or "Debuffs", d.point,
        { groups = "auras", config = "auras" })
    AU[which] = display
    AU[which .. "Holder"] = holder
end

-- ============================================================
-- The client's aura containers
-- ============================================================
local function build(self, which, d)
    local width = d.perRow * (d.size + d.spacing)
    local corner = startCorner(d)
    local a = self:CreateAuras({
        initialAnchor = corner,
        growthX = d.growthX, growthY = d.growthY,
        layoutLimit = width,
    })
    a.size = d.size
    a.elementSpacing = d.spacing
    a.lineSpacing = d.rowSpacing
    a.showCount = d.showCount
    -- Our own time text (the client's countdown is hidden: ns:AuraCountdown).
    a.showDuration = true
    a.showDebuffBorder = which == "debuffs"
    a.cancelButton = which == "buffs" and "RightButtonUp" or nil
    a.tooltipAnchor = "ANCHOR_BOTTOMLEFT"
    a.PostCreateButton = postCreate(d.size, d.showDuration)
    a:AddGroup(which == "buffs" and "HELPFUL" or "HARMFUL", { maxFrameCount = d.perRow * d.rows })
    a:SetSize(width, d.rows * (d.size + d.rowSpacing))
    holderFor(which, d, width, d.rows * (d.size + d.rowSpacing), a, corner)
end

local function style(self)
    self:EnableMouse(false)
    self:SetSize(1, 1)
    local d = db()
    build(self, "buffs", d.buffs)
    build(self, "debuffs", d.debuffs)
end

-- ============================================================
-- Secure aura headers
-- ============================================================
-- The buttons a header makes from WicksUI_AuraButtonTemplate call these.
-- The button belongs to the client's secure code, so everything we draw
-- sits on a frame of our own over it, and what we know about the button
-- is kept beside it rather than on it.
WicksUI_AuraButtonMixin = {}
local M = WicksUI_AuraButtonMixin
local state = setmetatable({}, { __mode = "k" })
function AU:StateOf(button) return state[button] end

-- Where GetWeaponEnchantInfo keeps each weapon's time left: main hand,
-- off hand, ranged.
local ENCHANT_POS = { [16] = 2, [17] = 6, [18] = 10 }
local MAX_BUTTONS = 40

local function formatTime(left)
    if left >= 3600 then return string.format("%dh", math.floor(left / 3600 + 0.5)) end
    if left >= 60 then return string.format("%dm", math.floor(left / 60 + 0.5)) end
    return string.format("%d", math.ceil(left))
end

local function tickTime(st)
    if st.expires then
        st.art.Time:SetText(formatTime(math.max(0, st.expires - GetTime())))
    else
        st.art.Time:SetText("")
    end
end

-- A debuff's border in its dispel colour; a buff's, and a debuff of no
-- kind, in the look's.
local function dispel(st, name)
    local bd = ns:BackdropOf(st.art)
    if not bd then return end
    local c = st.which == "debuffs" and name and DebuffTypeColor and DebuffTypeColor[name]
    if c then ns:SetBorderColor(bd, { c.r, c.g, c.b }) else ns:SetBorderColor(bd, "border") end
end

local function update(button)
    local st = state[button]
    if not st then return end
    local art = st.art
    if st.slot then
        -- A weapon's temporary enchant: the weapon's icon, the time
        -- GetWeaponEnchantInfo gives, in milliseconds.
        art.Icon:SetTexture(GetInventoryItemTexture("player", st.slot))
        local pos = ENCHANT_POS[st.slot]
        local ms = pos and select(pos, GetWeaponEnchantInfo())
        st.expires = (type(ms) == "number" and ms > 0) and (GetTime() + ms / 1000) or nil
        if art.Count then art.Count:SetText("") end
        dispel(st, nil)
    elseif st.index then
        local unit = st.header:GetAttribute("unit") or "player"
        local filter = button:GetAttribute("filter") or st.filter
        local data = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit, st.index, filter)
        if not data then
            st.expires = nil
            art.Time:SetText("")
            return
        end
        art.Icon:SetTexture(data.icon)
        if art.Count then
            local n = data.applications or 0
            art.Count:SetText(n > 1 and n or "")
        end
        local timed = (data.duration or 0) > 0 and (data.expirationTime or 0) > 0
        st.expires = timed and data.expirationTime or nil
        dispel(st, data.dispelName)
    else
        return
    end
    tickTime(st)
end

function M:OnLoad()
    local header = self:GetParent()
    local which = header and header.wuiWhich or "buffs"
    local d = db()[which]
    local art = CreateFrame("Frame", nil, self)
    art:SetAllPoints()
    art.Icon = art:CreateTexture(nil, "BORDER")
    art.Icon:SetAllPoints()
    if d.showCount then
        art.Count = art:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        art.Count:SetPoint("BOTTOMRIGHT", -1, 0)
    end
    art.Time = art:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    dress(art, d.size, d.showDuration)
    state[self] = {
        header = header, art = art, which = which, elapsed = 0,
        filter = header and header:GetAttribute("filter") or (which == "buffs" and "HELPFUL" or "HARMFUL"),
    }
end

-- The header hands each button its aura by index, or a weapon's slot.
function M:OnAttributeChanged(name, value)
    local st = state[self]
    if not st then return end
    if name == "index" then
        st.index, st.slot = value, nil
        update(self)
    elseif name == "target-slot" then
        st.slot, st.index = tonumber(value), nil
        update(self)
    end
end

function M:OnUpdate(elapsed)
    local st = state[self]
    if not st then return end
    st.elapsed = st.elapsed + elapsed
    if st.elapsed < 0.1 then return end
    st.elapsed = 0
    if st.slot then
        -- The enchant's time is only ever read whole; twice a second.
        st.enchantElapsed = (st.enchantElapsed or 0) + 0.1
        if st.enchantElapsed >= 0.5 then
            st.enchantElapsed = 0
            update(self)
            return
        end
    end
    tickTime(st)
end

function M:OnEnter()
    local st = state[self]
    if not st then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if st.slot then
        GameTooltip:SetInventoryItem("player", st.slot)
    elseif st.index then
        GameTooltip:SetUnitAura(st.header:GetAttribute("unit") or "player", st.index, self:GetAttribute("filter") or st.filter)
    end
end

function M:OnLeave()
    GameTooltip:Hide()
end

-- Run in the client's restricted environment for each button the header
-- makes, in combat too: the size the header was told.
local INITIAL_CONFIG = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("config-width"))
    self:SetHeight(header:GetAttribute("config-height"))
]]

-- After the header has sorted and placed its buttons on UNIT_AURA: a
-- button whose index did not change may still show a changed aura (a
-- stack added, a refresh), so every shown button is read again.
local function refresh(header)
    for i = 1, MAX_BUTTONS do
        local b = header:GetAttribute("child" .. i)
        if not b then break end
        if b:IsShown() then update(b) end
    end
    for i = 1, 2 do
        local b = header:GetAttribute("tempEnchant" .. i)
        if b and b:IsShown() then update(b) end
    end
end

local function buildHeader(which, d)
    local width, height = d.perRow * (d.size + d.spacing), d.rows * (d.size + d.rowSpacing)
    local corner = startCorner(d)
    local h = CreateFrame("Frame", "WicksUI_" .. which .. "Header", UIParent, "SecureAuraHeaderTemplate")
    h.wuiWhich = which
    h:SetAttribute("unit", "player")
    h:SetAttribute("filter", which == "buffs" and "HELPFUL" or "HARMFUL")
    h:SetAttribute("template", "WicksUI_AuraButtonTemplate")
    if which == "buffs" then
        h:SetAttribute("weaponTemplate", "WicksUI_AuraButtonTemplate")
        h:SetAttribute("includeWeapons", 1)
    end
    h:SetAttribute("sortMethod", "INDEX")
    h:SetAttribute("sortDirection", "+")
    h:SetAttribute("point", corner)
    h:SetAttribute("wrapAfter", d.perRow)
    h:SetAttribute("maxWraps", d.rows)
    h:SetAttribute("xOffset", (d.growthX == "LEFT" and -1 or 1) * (d.size + d.spacing))
    h:SetAttribute("yOffset", 0)
    h:SetAttribute("wrapXOffset", 0)
    h:SetAttribute("wrapYOffset", (d.growthY == "UP" and 1 or -1) * (d.size + d.rowSpacing))
    h:SetAttribute("minWidth", width)
    h:SetAttribute("minHeight", height)
    h:SetAttribute("config-width", d.size)
    h:SetAttribute("config-height", d.size)
    h:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
    h:HookScript("OnEvent", function(self, event)
        if event == "UNIT_AURA" then refresh(self) end
    end)
    holderFor(which, d, width, height, h, corner)
    h:Show()
end

-- ============================================================
-- The module
-- ============================================================
function AU:Initialize()
    ns:Kill(_G.BuffFrame)
    ns:Kill(_G.DebuffFrame)
    local d = db()
    if ns.Core.Client.hasAuraContainer then
        oUF:RegisterStyle("WicksUI_Auras", style)
        oUF:SetActiveStyle("WicksUI_Auras")
        local f = oUF:Spawn("player", "WicksUI_AuraHost")
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
        -- A mouse-transparent host should never target you on a click.
        f:SetAttribute("*type1", nil)
        f:SetAttribute("*type2", nil)
        self.host = f
        oUF:SetActiveStyle("WicksUI")
    else
        buildHeader("buffs", d.buffs)
        buildHeader("debuffs", d.debuffs)
    end
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
    L:Note("Your buffs and debuffs, kept by the client so they keep their timers in combat. Right-click a buff to cancel it. Sizes and counts are handed to the client when the display is made, so those take effect after a reload.")
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
        L:Dropdown("Grow across", "growthX", { { "LEFT", "Left" }, { "RIGHT", "Right" } },
            { tooltip = "Which way a row fills. Left starts on the right side of the mover." })
        L:Dropdown("Grow down or up", "growthY", { { "DOWN", "Down" }, { "UP", "Up" } },
            { tooltip = "Which way new rows go. Up starts at the bottom of the mover, so left and up begins in its bottom right corner." })
    end
end, { onChange = function() AU:Update() end, order = 40 })
