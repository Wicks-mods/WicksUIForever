-- Wick's UI
-- Modules/Extras/Extras.lua: the small things.
--
--   Raid marker bar: secure macro buttons, so marking works in combat.
--     Left-click marks your target, right-click drops the world marker.
--   Error filter: the red "not enough rage" text stays quiet in combat.
--   AFK screen: the interface steps aside while you are away.
--   Loot rolls: the need/greed popups go where you put them.
--   Quest tracker: the same, on a client where Edit Mode cannot move it.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local EX = ns:NewModule("extras", { title = "Extras", order = 90 })
ns.Extras = EX

ns.defaults.profile.extras = {
    enable = true,
    markers = true, markerSize = 24, markerVertical = false, markerVisibility = "[group] show; hide",
    markerPoint = "TOP,UIParent,TOP,0,-60",
    quietErrors = true,
    afk = false,
    lootRolls = true,       -- the roll popups sit on a mover of ours
    questTracker = true,    -- so does the quest tracker, where Edit Mode has none for it
}

local function db() return EX:db() end

-- ============================================================
-- Raid markers
-- ============================================================
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"

function EX:BuildMarkers()
    local bar = CreateFrame("Frame", "WicksUI_MarkerBar", UIParent, "SecureHandlerStateTemplate")
    bar:SetSize(1, 1)
    ns:CreateBackdrop(bar, "Transparent")
    bar.buttons = {}
    for i = 1, 9 do
        local b = CreateFrame("Button", "WicksUI_Marker" .. i, bar, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "macro")
        if i <= 8 then
            b:SetAttribute("macrotext1", "/tm " .. i)
            b:SetAttribute("macrotext2", "/wm " .. i)
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 2, -2)
            t:SetPoint("BOTTOMRIGHT", -2, 2)
            t:SetTexture(ICON:format(i))
        else
            -- The last one clears: your target's marker, or every world marker.
            b:SetAttribute("macrotext1", "/tm 0")
            b:SetAttribute("macrotext2", "/cwm all")
            local t = ns:CreateText(b, 14, "CENTER")
            t:SetPoint("CENTER")
            t:SetText("x")
        end
        ns:SetTemplate(b, "Shadow")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.15)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(i <= 8 and "Left-click: mark your target. Right-click: world marker." or "Left-click: clear your target's marker. Right-click: clear every world marker.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar.buttons[i] = b
    end
    ns:CreateMover(bar, "markers", "Raid markers", db().markerPoint, { groups = "misc", config = "extras" })
    self.markers = bar
end

function EX:LayoutMarkers()
    local bar, d = self.markers, db()
    local s, sp = d.markerSize, 2
    for i, b in ipairs(bar.buttons) do
        b:SetSize(s, s)
        b:ClearAllPoints()
        if d.markerVertical then
            b:SetPoint("TOP", bar, "TOP", 0, -sp - (i - 1) * (s + sp))
        else
            b:SetPoint("LEFT", bar, "LEFT", sp + (i - 1) * (s + sp), 0)
        end
    end
    if d.markerVertical then bar:SetSize(s + sp * 2, 9 * (s + sp) + sp) else bar:SetSize(9 * (s + sp) + sp, s + sp * 2) end
    ns.Movers:Resize("markers")
    if d.markers then
        RegisterStateDriver(bar, "visibility", d.markerVisibility)
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
    end
    ns.Movers:SetEnabled("markers", d.markers)
end

-- ============================================================
-- Quiet errors in combat
-- ============================================================
local function quiet(on)
    local f = rawget(_G, "UIErrorsFrame")
    if not f then return end
    if on then f:UnregisterEvent("UI_ERROR_MESSAGE") else f:RegisterEvent("UI_ERROR_MESSAGE") end
end

-- ============================================================
-- AFK screen
-- ============================================================
function EX:AFKFrame()
    local f = self.afkFrame
    if f then return f end
    f = CreateFrame("Frame", "WicksUI_AFK", WorldFrame)
    f:SetAllPoints()
    f:SetFrameStrata("FULLSCREEN")
    f:Hide()
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetHeight(90)
    ns:SetTemplate(bar, "Default", { brackets = true })
    local name = ns:CreateText(bar, 22, "LEFT", "NONE")
    name:SetPoint("LEFT", 30, 12)
    local r, g, b = ns:ClassColor(ns.myClass)
    name:SetText(("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, ns.myName))
    local sub = ns:CreateText(bar, 13, "LEFT", "NONE")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    local brand = ns:CreateText(bar, 16, "RIGHT", "NONE")
    brand:SetPoint("RIGHT", -30, 0)
    brand:SetText(Chrome:TitleMarkup("Wick's UI"))
    f.sub = sub
    f:SetScript("OnUpdate", function(self, e)
        self.acc = (self.acc or 0) + e
        if self.acc < 1 then return end
        self.acc = 0
        local secs = math.floor(GetTime() - (self.since or GetTime()))
        self.sub:SetText(("Away for %d:%02d   " .. Chrome:Esc("muted") .. "move or type to come back|r"):format(math.floor(secs / 60), secs % 60))
    end)
    self.afkFrame = f
    return f
end

function EX:SetAFK(on)
    local f = self:AFKFrame()
    if on and not InCombatLockdown() then
        f.since = GetTime()
        f:Show()
        UIParent:Hide()
        if MoveViewLeftStart then MoveViewLeftStart(0.05) end
        self.afkOn = true
    elseif self.afkOn then
        self.afkOn = nil
        f:Hide()
        if MoveViewLeftStop then MoveViewLeftStop() end
        if not InCombatLockdown() then UIParent:Show() else ns:AfterCombat("afk", function() UIParent:Show() end) end
    end
end

-- ============================================================
-- Loot rolls
-- ============================================================
-- Blizzard stacks the need/greed popups in GroupLootContainer, which its
-- bottom frame manager re-parents and lays out every time it shows. The
-- container is pinned to a frame of ours instead, and that frame gets the
-- mover (/wui move, "Loot rolls"). The mover is not given Blizzard's frame
-- itself: CreateMover writes a field onto its frame, and nothing is written
-- onto theirs. Nor is any of their methods hooked; this client punishes
-- that. A watcher checks the container every frame and puts it back on our
-- anchor when the manager has moved it. It runs after the event that
-- showed the popup and before the frame is drawn, so it never shows in the
-- old place. Toasts (loot won, achievements) are anchored to the container
-- by Blizzard's alert system, so they follow it up the screen too.
function EX:BuildLootRollAnchor()
    local a = CreateFrame("Frame", "WicksUI_LootRollAnchor", UIParent)
    a:SetSize(256, 100)     -- one popup: Blizzard reserves 100 per roll
    ns:CreateMover(a, "lootrolls", "Loot rolls", "BOTTOM,UIParent,BOTTOM,0,320", { groups = "misc", config = "extras" })
    self.rollAnchor = a
end

local function pinLootRolls()
    local c, a = rawget(_G, "GroupLootContainer"), EX.rollAnchor
    if not (c and a and db().enable and db().lootRolls and c:IsShown()) then return end
    -- If anything secure ever hangs off the container, moving it in a
    -- fight would be refused; then it waits for the fight to end.
    if InCombatLockdown() and c:IsProtected() then return end
    local p, rel, rp, x, y = c:GetPoint(1)
    if c:GetNumPoints() == 1 and p == "BOTTOM" and rel == a and rp == "BOTTOM" and x == 0 and y == 0 then return end
    c:ClearAllPoints()
    c:SetPoint("BOTTOM", a, "BOTTOM", 0, 0)
end
EX.PinLootRolls = pinLootRolls

-- The quest tracker on a client with the Classic layout (TBC Anniversary):
-- QuestWatchFrame is placed by Blizzard under the minimap, and Edit Mode
-- does not list it. It is held the way the loot rolls are: our anchor takes
-- the mover ("Quest tracker"), and the tracker is pinned to the anchor's top
-- right corner whenever Blizzard lays it out again, so it grows down from
-- where it was put. On Forever the tracker is an Edit Mode system.
function EX:BuildQuestAnchor()
    if not rawget(_G, "QuestWatchFrame") or rawget(_G, "ObjectiveTrackerFrame") then return end
    local a = CreateFrame("Frame", "WicksUI_QuestTrackerAnchor", UIParent)
    a:SetSize(204, 120)
    ns:CreateMover(a, "questtracker", "Quest tracker", "TOPRIGHT,UIParent,TOPRIGHT,-24,-300", { groups = "misc", config = "extras" })
    self.questAnchor = a
end

local function pinQuestTracker()
    local q, a = rawget(_G, "QuestWatchFrame"), EX.questAnchor
    if not (q and a and db().enable and db().questTracker) then return end
    if InCombatLockdown() and q:IsProtected() then return end
    local p, rel, rp, x, y = q:GetPoint(1)
    if q:GetNumPoints() == 1 and p == "TOPRIGHT" and rel == a and rp == "TOPRIGHT" and x == 0 and y == 0 then return end
    q:ClearAllPoints()
    q:SetPoint("TOPRIGHT", a, "TOPRIGHT", 0, 0)
end
EX.PinQuestTracker = pinQuestTracker

-- ============================================================
-- Lifecycle
-- ============================================================
function EX:Initialize()
    self:BuildMarkers()
    self:BuildLootRollAnchor()
    self:BuildQuestAnchor()
    local watch = CreateFrame("Frame")
    watch:SetScript("OnUpdate", function() pinLootRolls(); pinQuestTracker() end)
    ns:On("PLAYER_REGEN_DISABLED", function() if db().quietErrors then quiet(true) end end)
    ns:On("PLAYER_REGEN_ENABLED", function() quiet(false) end)
    ns:On("PLAYER_FLAGS_CHANGED", function(_, unit)
        if unit ~= "player" then return end
        EX:SetAFK(db().afk and UnitIsAFK("player"))
    end)
    ns:On("PLAYER_REGEN_DISABLED", function() if EX.afkOn then EX:SetAFK(false) end end)
    self:Update()
end

function EX:Update()
    ns:AfterCombat("extras", function() EX:LayoutMarkers() end)
end

ns.Config:AddPage("extras", "Extras", function(L)
    L:DB(db)
    L:Heading("Raid markers")
    L:Toggle("Marker bar", "markers")
    L:Toggle("Upright", "markerVertical")
    L:Slider("Button size", "markerSize", 14, 48, 1)
    L:Input("When it shows", "markerVisibility", { tooltip = "A macro condition. The default shows it in any group." })
    L:Heading("Loot rolls")
    L:Toggle("Movable loot rolls", "lootRolls", { tooltip = "The need, greed and pass popups sit where you put them: move them with /wui move (\"Loot rolls\"). Loot toasts follow them. Off gives them back to Blizzard from the next roll." })
    if EX.questAnchor then
        L:Heading("Quest tracker")
        L:Toggle("Movable quest tracker", "questTracker", { tooltip = "The quest tracker sits where you put it and grows down from there: move it with /wui move (\"Quest tracker\"). Off gives it back to Blizzard the next time the game places it." })
    end
    L:Heading("Other")
    L:Toggle("No red error text in combat", "quietErrors", { tooltip = "The \"not enough rage\" and \"out of range\" lines. They come back when the fight ends." })
    L:Toggle("AFK screen", "afk", { tooltip = "Hides the interface and turns the camera slowly while you are away. Ends at once if a fight starts." })
end, { onChange = function() EX:Update() end, order = 90 })
