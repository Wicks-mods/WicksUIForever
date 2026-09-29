-- Wick's UI (from Wick's Comforts)
-- Tooltips.lua: a few extra lines on item and unit tooltips.
--
-- Two clients, two mechanisms. Forever has the tooltip data processor,
-- which is the supported way to append to a tooltip. TBC has none, so the
-- old OnTooltipSetItem hook is used there. Each line is opt in.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local D, R = Core.Dialect, Core.Restrict
local T = ns:Register("tooltips", {})

local DIM = { 0.55, 0.52, 0.62 }

local function itemLevelOf(link)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, ilvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and type(ilvl) == "number" and ilvl > 0 then return ilvl end
    end
    local info = D.GetItemInfo(link)
    return info and info.itemLevel
end

-- Equippable things only. An item level on a stack of cloth is noise.
local function isGear(link)
    local info = D.GetItemInfoInstant(link)
    return info and info.equipLoc and info.equipLoc ~= "" and info.equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

function T:DecorateItem(tt, link)
    local db = ns.db()
    if not link then return end
    if db.tipItemLevel and isGear(link) then
        local ilvl = itemLevelOf(link)
        if ilvl then tt:AddDoubleLine("Item level", tostring(ilvl), DIM[1], DIM[2], DIM[3], 1, 1, 1) end
    end
    if db.tipIDs then
        local id = tonumber(tostring(link):match("item:(%d+)"))
        if id then tt:AddDoubleLine("Item ID", tostring(id), DIM[1], DIM[2], DIM[3], 1, 1, 1) end
    end
end

function T:DecorateSpell(tt, spellID)
    if not ns.db().tipIDs or not spellID then return end
    tt:AddDoubleLine("Spell ID", tostring(spellID), DIM[1], DIM[2], DIM[3], 1, 1, 1)
end

function T:DecorateUnit(tt, unit)
    local db = ns.db()
    if not unit or not UnitExists(unit) then return end

    if db.tipClassColor and UnitIsPlayer(unit) then
        local _, token = UnitClass(unit)
        local colors = rawget(_G, "RAID_CLASS_COLORS")
        local c = token and colors and colors[token]
        if c then
            local name = UnitName(unit)
            local line = rawget(_G, "GameTooltipTextLeft1")
            if name and line then line:SetTextColor(c.r, c.g, c.b) end
        end
    end

    if db.tipTarget then
        local target = unit .. "target"
        if UnitExists(target) then
            local name = UnitName(target)
            if name then
                -- Unit identity goes secret under some of this client's
                -- restrictions, and a secret cannot be tested for truth:
                -- doing it anyway was blocked two hundred times in one
                -- taint log. When we cannot tell, say the name, which is
                -- true either way.
                local isYou = false
                local ok, same = pcall(UnitIsUnit, target, "player")
                if ok and not R:IsSecret(same) then isYou = same == true end
                if isYou then
                    tt:AddDoubleLine("Targeting", "you", DIM[1], DIM[2], DIM[3], 0.85, 0.3, 0.3)
                else
                    tt:AddDoubleLine("Targeting", name, DIM[1], DIM[2], DIM[3], 1, 1, 1)
                end
            end
        end
    end
end

function T:Apply()
    -- Nothing to reapply: the hooks read the settings each time they run.
end

function T:Init()
    if self.hooked then return end
    self.hooked = true

    local TDP = rawget(_G, "TooltipDataProcessor")
    if TDP and TDP.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TDP.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt ~= GameTooltip and tt ~= rawget(_G, "ItemRefTooltip") then return end
            local _, link = tt:GetItem()
            Core.safe(T.DecorateItem, T, tt, link or (data and data.hyperlink))
        end)
        if Enum.TooltipDataType.Spell then
            TDP.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tt, data)
                Core.safe(T.DecorateSpell, T, tt, data and data.id)
            end)
        end
        if Enum.TooltipDataType.Unit then
            TDP.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
                local _, unit = tt:GetUnit()
                -- The token can be secret (world tooltips in combat or an
                -- instance); unit calls refuse it, so there is nothing to add.
                if not unit or R:IsSecret(unit) then return end
                Core.safe(T.DecorateUnit, T, tt, unit)
            end)
        end
        return
    end

    -- TBC and anything else without the processor.
    if GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tt)
            local _, link = tt:GetItem()
            Core.safe(T.DecorateItem, T, tt, link)
        end)
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt)
            local _, unit = tt:GetUnit()
            Core.safe(T.DecorateUnit, T, tt, unit)
        end)
    end
end
