-- Wick's UI (from Wick's Comforts)
-- Loot.lua: auto loot and the bind on pickup prompt.
--
-- Auto loot is the game's own setting rather than anything clever. Driving
-- the console variable means it keeps working if this addon is disabled,
-- and it never fights the checkbox in Blizzard's own options.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local L = ns:Register("loot", {})

local CV = rawget(_G, "C_CVar")
local function cvGet(n) if CV and CV.GetCVar then return CV.GetCVar(n) end local f = rawget(_G, "GetCVar"); return f and f(n) end
local function cvSet(n, v) if CV and CV.SetCVar then return CV.SetCVar(n, v) end local f = rawget(_G, "SetCVar"); if f then return f(n, v) end end

function L:Apply()
    local db = ns.db()
    -- Only write when it differs, so a player who prefers the game's own
    -- checkbox is not fought over every settings change.
    if db.autoLoot then
        if cvGet("autoLootDefault") ~= "1" then cvSet("autoLootDefault", "1") end
    end
end

function L:Init()
    ns.RegisterEvents({ "LOOT_BIND_CONFIRM", "CONFIRM_LOOT_ROLL" })

    ns:On("LOOT_BIND_CONFIRM", function(_, slot)
        if not ns.db().confirmBoP then return end
        -- Confirming is an ordinary call. The dialog the game raises
        -- alongside it is the game's to close, which it does as the loot
        -- window goes: hiding a game dialog from an addon taints the
        -- game's list of shown dialogs, and on the controller its focus
        -- code then ran past the client's time limit in our name.
        if ConfirmLootSlot then Core.safe(ConfirmLootSlot, slot) end
    end)
end
