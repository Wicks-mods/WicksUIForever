-- Wick's UI
-- Modules/ActionBars/AutoRank.lua: a newly learned spell rank takes the
-- place of the older ranks on the action bars.
--
-- Forever keeps Classic's spell ranks, and an action slot holds one rank's
-- spell ID, so a button stays on Rank 1 after Rank 2 is trained. Here the
-- spellbook is read on every SPELLS_CHANGED and the best known rank of each
-- spell remembered; when a spell's best rank goes up, every slot holding a
-- lower rank of it gets the new one. Only on a rank going up: a button the
-- player sets back to a low rank on purpose is left alone until the next
-- rank is learned. Placing actions is not allowed in combat, so a change
-- found mid-fight waits for the fight to end.

local ADDON, ns = ...

local AB = ns.ActionBars
local D = ns.Core.Dialect

local AR = {}
ns.AutoRank = AR

local MAX_SLOT = 180

local function rankOf(text)
    return tonumber(text and tostring(text):match("(%d+)")) or 0
end

local function subtext(id)
    local fn = C_Spell and C_Spell.GetSpellSubtext
    if fn then
        local ok, t = pcall(fn, id)
        if ok then return t end
    end
end

-- name -> { id, rank } for the best rank the book holds of each spell.
local function bestKnown()
    local best = {}
    for _, s in ipairs(D.SpellBookSpells() or {}) do
        if s.spellID and s.name and not s.isPassive then
            local r = rankOf(s.rank)
            local b = best[s.name]
            if not b or r > b.rank then best[s.name] = { id = s.spellID, rank = r } end
        end
    end
    return best
end

local function pickup(id)
    if C_Spell and C_Spell.PickupSpell then return pcall(C_Spell.PickupSpell, id) end
    if PickupSpell then return pcall(PickupSpell, id) end
    return false
end

-- Every slot holding a lower rank of `name` gets `id`.
local function upgrade(name, id, rank)
    local done = 0
    for slot = 1, MAX_SLOT do
        local kind, sid = GetActionInfo(slot)
        if kind == "spell" and sid and sid ~= id then
            local n = D.GetSpellName(sid)
            if n == name and rankOf(subtext(sid)) < rank then
                -- Never while the player is dragging something of their own.
                if GetCursorInfo() then return done end
                pickup(id)
                if GetCursorInfo() then
                    PlaceAction(slot)
                    ClearCursor()
                    done = done + 1
                end
            end
        end
    end
    return done
end

function AR:Scan()
    if not (AB and AB:db().autoRank) then
        self.known = nil
        return
    end
    local best = bestKnown()
    local prev = self.known
    self.known = best
    -- The first read after login is the baseline; nothing is replaced then,
    -- so bars set up by hand before this addon arrived stay as they are.
    if not prev then return end
    local changed = {}
    for name, b in pairs(best) do
        local p = prev[name]
        if p and b.rank > p.rank then changed[#changed + 1] = { name = name, id = b.id, rank = b.rank } end
    end
    if #changed == 0 then return end
    ns:AfterCombat("autorank", function()
        local n = 0
        for _, c in ipairs(changed) do n = n + upgrade(c.name, c.id, c.rank) end
        if n > 0 then
            ns.A:Print(("new rank%s put on %d button%s."):format(#changed > 1 and "s" or "", n, n > 1 and "s" or ""))
        end
    end)
end

ns:On("PLAYER_LOGIN", function() C_Timer.After(2, function() AR:Scan() end) end)
ns:On("SPELLS_CHANGED", function()
    -- SPELLS_CHANGED comes in bursts; one read after the last of them.
    if AR.pending then return end
    AR.pending = true
    C_Timer.After(0.5, function() AR.pending = false; AR:Scan() end)
end)
