-- Wick's UI (from Wick's Comforts)
-- Fixes.lua: quiet a couple of the beta client's own errors.
--
-- These are not preferences and they are not our bugs. They are places
-- where Blizzard's own code on this build reaches for something that was
-- never created, throws, and spams the error frame every reload. Each fix
-- here is conditional: it only acts when the fault is actually present,
-- so it does nothing on a client where the code is correct and it retires
-- itself the moment Blizzard patches it.
--
-- This is the one part of the addon that starts switched on, because an
-- error you did not cause and cannot act on is not a preference.

local ADDON, uns = ...
-- Carried over from Wick's Comforts unchanged but for these lines: it
-- runs on Modules/Comforts/Comforts.lua in place of Comforts' core.
-- Keep it in step with Wick's Comforts' own copy.
local ns = uns.Comforts
if not ns then return end
if not WickCore then return end   -- said once in Core.lua
local Core = ns.Core
local F = ns:Register("fixes", {})

local GROUP_FINDER = "Blizzard_GroupFinder_VanillaStyle"

local function addonLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
    if not f then return false end
    local ok, loaded = pcall(f, name)
    return ok and loaded and true or false
end

-- Blizzard_GroupFinder_VanillaStyle shares one tab handler between its
-- Classic and Mainline variants, and on this build the tab handler can
-- reach LFGWhoListFrame before anything has created it, which throws.
-- Standing a plain hidden frame under that name is enough to quiet it:
-- their code only calls SetShown and IsShown on it.
--
-- The timing is the whole fix, and getting it wrong is worse than not
-- having it. The group finder is load on demand. An earlier version
-- checked only that the addon *existed*, which is true at login, and so
-- claimed the global name before Blizzard's own code had ever run. When
-- the player opened /who the real frame could not be created, and the
-- panel came up with its close button and side tabs drawn and nothing
-- in the middle.
--
-- So: never before their addon has loaded. Once it has loaded and still
-- has no frame of that name, the fault is real and the stub is safe.
function F:GroupFinderWhoList()
    if self.stubbedWhoList then return false end
    if rawget(_G, "LFGWhoListFrame") then return false end
    if not addonLoaded(GROUP_FINDER) then return false end
    local f = CreateFrame("Frame", "LFGWhoListFrame", UIParent)
    f:Hide()
    f.wicksStub = true
    self.stubbedWhoList = true
    return true
end

-- What the client actually has, so this can be diagnosed from a report
-- rather than guessed at twice.
function F:WhoReport()
    local out = {}
    out[#out + 1] = ("%s loaded: %s"):format(GROUP_FINDER, tostring(addonLoaded(GROUP_FINDER)))
    local list = rawget(_G, "LFGWhoListFrame")
    out[#out + 1] = ("LFGWhoListFrame: %s%s"):format(
        list and "present" or "absent",
        list and (list.wicksStub and " (ours)" or " (Blizzard's)") or "")
    if list and list.IsShown then
        out[#out + 1] = ("  shown %s, size %dx%d"):format(tostring(list:IsShown()),
            math.floor(list:GetWidth() or 0), math.floor(list:GetHeight() or 0))
    end
    for _, name in ipairs({ "WhoFrame", "FriendsFrame", "LFGBrowseFrame", "LFGParentFrame", "SocialFrame" }) do
        local f = rawget(_G, name)
        if f then
            out[#out + 1] = ("%s: present, shown %s"):format(name, tostring(f.IsShown and f:IsShown()))
        end
    end
    out[#out + 1] = "if the who panel is empty, try /wcomfort fixes off then /reload."
    return out
end

function F:Apply()
    if ns.db().clientFixes == false then return end
    Core.safe(F.GroupFinderWhoList, F)
end

function F:Init()
    self:Apply()
    -- Their addon is load on demand, so the moment that matters is when
    -- it loads, not when we do.
    ns.RegisterEvents({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED" })
    ns:On("PLAYER_ENTERING_WORLD", function() F:Apply() end)
    ns:On("ADDON_LOADED", function(_, name)
        if name == GROUP_FINDER then F:Apply() end
    end)
end
