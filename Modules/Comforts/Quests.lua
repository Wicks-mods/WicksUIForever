-- Wick's UI (from Wick's Comforts)
-- Quests.lua: accept and hand in without the clicking.
--
-- Two deliberate limits. Holding the modifier key always gives you the
-- normal dialogs back, because sooner or later you want to read one. And
-- a quest that offers a choice of rewards is never handed in for you:
-- picking the wrong item is not a comfort, it is a loss, and there is no
-- way for an addon to know which one you wanted.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local Q = ns:Register("quests", {})

-- Hold this and everything behaves as the game intends.
local function overridden()
    local f = rawget(_G, "IsShiftKeyDown")
    return f and f() and true or false
end

local function on(key) return ns.db()[key] == true and not overridden() end

local gossip = rawget(_G, "C_GossipInfo")

-- The quest APIs are ordinary calls on this build, but the client is a
-- beta and a missing one should be a quiet no, not an error in the chat.
local function callGame(name, ...)
    local f = rawget(_G, name)
    if type(f) ~= "function" then return false end
    return Core.safe(f, ...)
end

function Q:Accept()
    if not on("autoAcceptQuests") then return end
    callGame("AcceptQuest")
end

-- An escort or a shared quest asks in a dialog of the game's own, and
-- that one is left for you to answer. Accepting through the API left the
-- dialog up, and hiding a game dialog from an addon taints the game's
-- list of shown dialogs (on the controller its focus code then ran past
-- the client's time limit in our name).
function Q:ConfirmAccept() end

-- The npc is telling you what it still wants. If you have it, ask for
-- the reward screen; if you do not, there is nothing to do.
function Q:Progress()
    if not on("autoTurnInQuests") then return end
    local complete = rawget(_G, "IsQuestCompletable")
    if complete and not complete() then return end
    callGame("CompleteQuest")
end

function Q:Complete()
    if not on("autoTurnInQuests") then return end
    local choices = rawget(_G, "GetNumQuestChoices")
    local n = 0
    if choices then
        local ok, v = Core.safe(choices)
        if ok and type(v) == "number" then n = v end
    end
    -- More than one reward on offer means the decision is yours.
    if n > 1 then return end
    -- Blizzard's own button passes the chosen index, and zero when there
    -- was nothing to choose.
    callGame("GetQuestReward", n)
end

-- Npcs that talk first. The quest is behind a gossip line, so the line
-- has to be picked before any of the above fires.
function Q:Gossip()
    if not gossip then return end
    if on("autoAcceptQuests") and gossip.GetAvailableQuests then
        local ok, list = pcall(gossip.GetAvailableQuests)
        if ok and type(list) == "table" and #list == 1 then
            Core.safe(gossip.SelectAvailableQuest, list[1].questID or 1)
            return
        end
    end
    if on("autoTurnInQuests") and gossip.GetActiveQuests then
        local ok, list = pcall(gossip.GetActiveQuests)
        if ok and type(list) == "table" then
            for _, q in ipairs(list) do
                if q.isComplete then
                    Core.safe(gossip.SelectActiveQuest, q.questID or 1)
                    return
                end
            end
        end
    end
end

function Q:Init()
    local map = {
        QUEST_DETAIL          = function() Q:Accept() end,
        QUEST_ACCEPT_CONFIRM  = function() Q:ConfirmAccept() end,
        QUEST_PROGRESS        = function() Q:Progress() end,
        QUEST_COMPLETE        = function() Q:Complete() end,
        GOSSIP_SHOW           = function() Q:Gossip() end,
    }
    local names = {}
    for event, fn in pairs(map) do
        names[#names + 1] = event
        ns:On(event, fn)
    end
    ns.RegisterEvents(names)
end
