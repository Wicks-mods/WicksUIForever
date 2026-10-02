-- Wick's UI
-- Modules/Tooltip/Tooltip.lua: flat tooltips, and where they appear.
--
-- Our panel sits behind the tooltip and Blizzard's frame art is faded out
-- by alpha. No field is written into a tooltip: what we add lives in our
-- own table keyed by the tooltip. Hooks are post-hooks on Blizzard's
-- functions (hooksecurefunc) and TooltipDataProcessor post-calls, which is
-- the route this client provides for exactly this.
--
-- Item IDs, item level and the other tooltip extras belong to Wick's
-- Comforts; this module is the look and the placement.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local TT = ns:NewModule("tooltip", { title = "Tooltips", order = 70 })
ns.Tooltip = TT

ns.defaults.profile.tooltip = {
    enable = true,
    anchor = "default",      -- default (Edit Mode), cursor
    cursorX = 20, cursorY = 20,
    classBorder = true,      -- class colour on the border for players
    qualityBorder = true,    -- quality colour on the border for items
    hideUnitsInCombat = false,
    healthBar = true,
    fontSize = 12,
}

local function db() return TT:db() end
local issecret = rawget(_G, "issecretvalue")
local function plain(v) if issecret and issecret(v) then return nil end return v end

local extras = setmetatable({}, { __mode = "k" })

local function panelFor(tt)
    local e = extras[tt]
    if e then return e end
    e = {}
    local bd = CreateFrame("Frame", nil, tt)
    bd:SetAllPoints(tt)
    bd:SetFrameLevel(math.max(0, tt:GetFrameLevel() - 1))
    ns:SetTemplate(bd, "Default")
    e.backdrop = bd
    extras[tt] = e
    return e
end

function TT:Skin(tt)
    if not tt or (tt.IsForbidden and tt:IsForbidden()) then return end
    local e = panelFor(tt)
    if tt.NineSlice then tt.NineSlice:SetAlpha(0) end
    ns:SetBorderColor(e.backdrop, "border")
end

local function setBorder(tt, r, g, b)
    local e = extras[tt]
    if not e then return end
    if r then
        ns:SetBorderColor(e.backdrop, { r, g, b })
    else
        ns:SetBorderColor(e.backdrop, "border")
    end
end

-- ============================================================
-- Per type
-- ============================================================
local function onUnit(tt)
    if tt ~= GameTooltip or tt:IsForbidden() then return end
    local d = db()
    local _, unit = tt:GetUnit()
    if d.hideUnitsInCombat and InCombatLockdown() then tt:Hide() return end
    -- The unit token itself can be secret (world tooltips in combat or an
    -- instance), and unit API calls refuse a secret from addon code. Then
    -- there is nothing to read: the plain border stays.
    unit = plain(unit)
    if not unit then setBorder(tt) return end
    if d.classBorder and plain(UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        class = plain(class)
        if class then setBorder(tt, ns:ClassColor(class)) return end
    end
    setBorder(tt)
end

local function onItem(tt, data)
    if tt.IsForbidden and tt:IsForbidden() then return end
    if not db().qualityBorder then setBorder(tt) return end
    local id = data and data.id
    local q = id and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if q and q >= 2 and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        setBorder(tt, r, g, b)
    else
        setBorder(tt)
    end
end

-- ============================================================
-- Health bar
-- ============================================================
function TT:StyleHealthBar()
    local bar = rawget(_G, "GameTooltipStatusBar")
    if not bar then return end
    local e = extras[bar] or {}
    extras[bar] = e
    bar:SetStatusBarTexture(ns.Media:Statusbar())
    ns:TrackStatusBar(bar)
    bar:SetHeight(5)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -3)
    bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -3)
    if not e.backdrop then
        local bd = CreateFrame("Frame", nil, bar)
        bd:SetPoint("TOPLEFT", -1, 1)
        bd:SetPoint("BOTTOMRIGHT", 1, -1)
        bd:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
        ns:SetTemplate(bd, "Default")
        e.backdrop = bd
    end
    bar:SetAlpha(db().healthBar and 1 or 0)
end

-- ============================================================
-- Lifecycle
-- ============================================================
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
    "WorldMapTooltip", "FriendsTooltip", "QuickKeybindTooltip", "SmallTextTooltip" }

function TT:Initialize()
    for _, n in ipairs(TIPS) do
        local tt = _G[n]
        if tt then self:Skin(tt) end
    end
    -- Blizzard re-applies its frame art whenever a tooltip is styled.
    if SharedTooltip_SetBackdropStyle then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tt) TT:Skin(tt) end)
    end
    if GameTooltip_SetDefaultAnchor then
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
            if tt:IsForbidden() then return end
            local d = db()
            if d.anchor == "cursor" then
                tt:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", d.cursorX, d.cursorY)
            end
        end)
    end
    local TDP = rawget(_G, "TooltipDataProcessor")
    if ns.Core.Client.hasTooltipData and TDP and TDP.AddTooltipPostCall and Enum.TooltipDataType then
        TDP.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnit)
        TDP.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
        -- Everything that is not a unit or an item gets the plain border.
        -- Through the tooltip data callbacks rather than HookScript: hooking a
        -- script on GameTooltip would make Blizzard's own handler run tainted.
        if TDP.AllTypes then
            TDP.AddTooltipPostCall(TDP.AllTypes, function(tt, data)
                local t = data and data.type
                if t ~= Enum.TooltipDataType.Unit and t ~= Enum.TooltipDataType.Item then setBorder(tt) end
            end)
        end
    else
        -- A client whose tooltips carry no data table (TBC Anniversary: the
        -- processor exists and never runs). Script hooks are the way there,
        -- and safe: nothing in a tooltip is secret, so a tainted handler
        -- costs nothing. Cleared puts the plain border back before the next
        -- unit or item colours it.
        for _, n in ipairs(TIPS) do
            local tt = _G[n]
            if tt and tt.HookScript and tt.HasScript then
                if tt:HasScript("OnTooltipCleared") then
                    tt:HookScript("OnTooltipCleared", function(t) setBorder(t) end)
                end
                if tt:HasScript("OnTooltipSetUnit") then
                    tt:HookScript("OnTooltipSetUnit", function(t) onUnit(t) end)
                end
                if tt:HasScript("OnTooltipSetItem") then
                    tt:HookScript("OnTooltipSetItem", function(t)
                        local _, link = t:GetItem()
                        local id = link and tonumber(link:match("item:(%d+)"))
                        onItem(t, id and { id = id } or nil)
                    end)
                end
            end
        end
    end
    self:StyleHealthBar()
end

function TT:Update()
    self:StyleHealthBar()
end

ns.Config:AddPage("tooltip", "Tooltips", function(L)
    L:DB(db)
    L:Dropdown("Where tooltips appear", "anchor", { { "default", "Where Edit Mode puts them" }, { "cursor", "At the cursor" } })
    L:Slider("Across from the cursor", "cursorX", -100, 100, 1, { disabled = function() return db().anchor ~= "cursor" end })
    L:Slider("Up from the cursor", "cursorY", -100, 100, 1, { disabled = function() return db().anchor ~= "cursor" end })
    L:Toggle("Class colour border on players", "classBorder")
    L:Toggle("Quality colour border on items", "qualityBorder")
    L:Toggle("Health bar under unit tooltips", "healthBar")
    L:Toggle("No unit tooltips in combat", "hideUnitsInCombat")
    L:Note("Item level, IDs and the other tooltip extras are in Wick's Comforts.")
end, { onChange = function() TT:Update() end, order = 70 })
