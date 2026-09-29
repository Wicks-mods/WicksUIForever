-- Wick's UI (from Wick's Comforts)
-- Vendor.lua: repair on arrival and sell the grey items.
--
-- Selling is deliberately narrow. Only poor quality items are ever sold,
-- never anything the player might have wanted, and the total is reported
-- so a mistake is visible rather than silent.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local D = Core.Dialect
local V = ns:Register("vendor", {})

local POOR = 0

local function money(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, c) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return ("%dc"):format(c)
end

function V:Repair()
    local db = ns.db()
    if not db.autoRepair then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    -- Split, not guarded inline: `local a, b = fn and fn()` keeps only the
    -- first return, so canRepair came back nil every time and the guard
    -- below sent us home before anything was repaired.
    if not GetRepairAllCost then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if db.guildRepair and CanGuildBankRepair and CanGuildBankRepair() then
        local funds = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        if funds == -1 or funds >= cost then
            Core.safe(RepairAllItems, true)
            ns.A:Print(("repaired for %s from guild funds."):format(money(cost)))
            return
        end
    end

    if (GetMoney and GetMoney() or 0) < cost then
        ns.A:Print(("repairs cost %s and you cannot afford it."):format(money(cost)))
        return
    end
    Core.safe(RepairAllItems, false)
    ns.A:Print(("repaired for %s."):format(money(cost)))
end

function V:SellJunk()
    if not ns.db().sellJunk then return end
    local sold, worth = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = D.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = D.GetContainerItemInfo(bag, slot)
            if info and info.itemID and info.quality == POOR then
                local it = D.GetItemInfo(info.itemID)
                -- A grey with no sell price cannot be sold; skip rather
                -- than click at it.
                if it and (it.sellPrice or 0) > 0 then
                    worth = worth + (it.sellPrice * (info.stackCount or 1))
                    sold = sold + 1
                    D.UseContainerItem(bag, slot)
                end
            end
        end
    end
    if sold > 0 then
        ns.A:Print(("sold %d junk item%s for about %s."):format(sold, sold == 1 and "" or "s", money(worth)))
    end
end

function V:Apply()
    -- Nothing standing: both actions happen when a merchant opens.
end

function V:Init()
    ns.RegisterEvents({ "MERCHANT_SHOW" })
    ns:On("MERCHANT_SHOW", function()
        Core.safe(V.Repair, V)
        Core.safe(V.SellJunk, V)
    end)
end
