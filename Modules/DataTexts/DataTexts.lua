-- Wick's UI
-- Modules/DataTexts/DataTexts.lua: info panels.
--
-- Thin bars with slots; each slot shows one piece of information and does
-- something on a click. A datatext is a small table:
--   { label, events = {...}, interval = seconds, text = fn() -> string,
--     tooltip = fn(tt), click = fn(button) }
-- Nothing here touches combat state, so every one of them works anywhere.
-- Clicks that open a Blizzard panel are refused in combat, which the
-- client would refuse anyway.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local DT = ns:NewModule("datatexts", { title = "Info panels", order = 80 })
ns.DataTexts = DT
DT.registry = {}
DT.keys = {}

-- Values in the look's accent, read as they are drawn so every look and
-- theme has its own; the labels are in the look's text colour.
local function hl(s) return Chrome:Esc("fel") .. tostring(s) .. "|r" end

function DT:Register(key, def)
    def.key = key
    self.registry[key] = def
    self.keys[#self.keys + 1] = key
end

ns.defaults.profile.datatexts = {
    enable = true,
    panels = {
        left  = { enable = true, width = 420, height = 20, slots = "fps,durability,bags", point = "BOTTOMLEFT,UIParent,BOTTOMLEFT,4,4" },
        right = { enable = true, width = 420, height = 20, slots = "gold,friends,time", point = "BOTTOMRIGHT,UIParent,BOTTOMRIGHT,-4,4" },
        top   = { enable = false, width = 420, height = 20, slots = "coords,zone,xp", point = "TOP,UIParent,TOP,0,-4" },
    },
    fontSize = 18,
    backdrop = true,
}

local function db() return DT:db() end

-- Slots are kept as "a,b,c": a list in the saved profile would have
-- missing entries filled back in from the defaults at every load.
local function slotList(key) return ns:List(db().panels[key].slots) end
local function setSlots(key, list) db().panels[key].slots = table.concat(list, ",") end

-- ============================================================
-- The datatexts
-- ============================================================
local function panelToggle(fn, ...)
    if InCombatLockdown() then return end
    local f = rawget(_G, fn)
    if f then pcall(f, ...) end
end

DT:Register("time", {
    label = "Time", interval = 1,
    text = function()
        local t = date("*t")
        return ("%s%02d:%02d|r"):format(Chrome:Esc("fel"), t.hour, t.min)
    end,
    tooltip = function(tt)
        local h, m = GetGameTime()
        tt:AddDoubleLine("Realm time", ("%02d:%02d"):format(h, m), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("Your time", date("%H:%M"), 1, 1, 1, 1, 1, 1)
        tt:AddLine("Click for the calendar.", 0.6, 0.6, 0.6)
    end,
    click = function() panelToggle("ToggleCalendar") end,
})

DT:Register("fps", {
    label = "FPS and latency", interval = 1,
    text = function()
        local _, _, home, world = GetNetStats()
        return ("%s fps  %s ms"):format(hl(math.floor(GetFramerate() + 0.5)), hl(math.max(home or 0, world or 0)))
    end,
    tooltip = function(tt)
        local down, up, home, world = GetNetStats()
        tt:AddDoubleLine("Home latency", home .. " ms", 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("World latency", world .. " ms", 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("Bandwidth", ("%.1f / %.1f KB/s"):format(down, up), 1, 1, 1, 1, 1, 1)
    end,
})

local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
DT:Register("durability", {
    label = "Durability", events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
    text = function()
        local low = 100
        for _, s in ipairs(SLOTS) do
            local cur, max = GetInventoryItemDurability(s)
            if cur and max and max > 0 then low = math.min(low, cur / max * 100) end
        end
        local color = low < 25 and "|cffff4040" or low < 50 and "|cffffcc40" or Chrome:Esc("fel")
        return ("Armour %s%d%%|r"):format(color, low)
    end,
    tooltip = function(tt)
        for _, s in ipairs(SLOTS) do
            local cur, max = GetInventoryItemDurability(s)
            local link = GetInventoryItemLink("player", s)
            if cur and max and max > 0 and link then
                tt:AddDoubleLine(link, ("%d%%"):format(cur / max * 100), 1, 1, 1, 1, 1, 1)
            end
        end
        tt:AddLine("Click for your character.", 0.6, 0.6, 0.6)
    end,
    click = function() panelToggle("ToggleCharacter", "PaperDollFrame") end,
})

DT:Register("bags", {
    label = "Bag space", events = { "BAG_UPDATE" },
    text = function()
        local free, total = 0, 0
        for bag = 0, 4 do
            local n = C_Container.GetContainerNumSlots(bag) or 0
            total = total + n
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
        return ("Bags %s/%d"):format(hl(free), total)
    end,
    click = function() panelToggle("ToggleAllBags") end,
})

local function coins(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor(copper % 10000 / 100)
    local c = copper % 100
    return ("%s|cffffd700g|r %d|cffc7c7cfs|r %d|cffeda55fc|r"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, s, c)
end

DT:Register("gold", {
    label = "Gold", events = { "PLAYER_MONEY" },
    text = function() return coins(GetMoney()) end,
    tooltip = function(tt)
        local g = DT.sessionStart and (GetMoney() - DT.sessionStart) or 0
        tt:AddDoubleLine("This session", (g < 0 and "-" or "") .. coins(math.abs(g)), 1, 1, 1, 1, 1, 1)
        tt:AddLine("Click for your bags.", 0.6, 0.6, 0.6)
    end,
    click = function() panelToggle("ToggleAllBags") end,
})

DT:Register("friends", {
    label = "Friends", events = { "FRIENDLIST_UPDATE", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE" },
    text = function()
        local online = C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends() or 0
        local bn = BNGetNumFriends and select(2, BNGetNumFriends()) or 0
        return ("Friends %s"):format(hl(online + (bn or 0)))
    end,
    click = function() panelToggle("ToggleFriendsFrame", 1) end,
})

DT:Register("guild", {
    label = "Guild", events = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE" },
    text = function()
        if not IsInGuild() then return "No guild" end
        local _, online = GetNumGuildMembers()
        return ("Guild %s"):format(hl(online or 0))
    end,
    click = function() panelToggle("ToggleGuildFrame") end,
})

DT:Register("xp", {
    label = "Experience", events = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION" },
    text = function()
        local max = UnitXPMax("player")
        if not max or max == 0 then return "Max level" end
        local cur = UnitXP("player")
        local rested = GetXPExhaustion() or 0
        return ("XP %s%%%s"):format(hl(math.floor(cur / max * 100)), rested > 0 and ("  |cff5c9cffR %d%%|r"):format(rested / max * 100) or "")
    end,
    tooltip = function(tt)
        local cur, max = UnitXP("player"), UnitXPMax("player")
        if max and max > 0 then
            tt:AddDoubleLine("Experience", ("%d / %d"):format(cur, max), 1, 1, 1, 1, 1, 1)
            tt:AddDoubleLine("To go", tostring(max - cur), 1, 1, 1, 1, 1, 1)
            local r = GetXPExhaustion()
            if r then tt:AddDoubleLine("Rested", tostring(r), 1, 1, 1, 0.36, 0.61, 1) end
        end
    end,
})

DT:Register("coords", {
    label = "Coordinates", interval = 0.2,
    text = function()
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition(map, "player")
        if not pos then return Chrome:Esc("muted") .. "--|r" end
        local x, y = pos:GetXY()
        return ("%s, %s"):format(hl(("%.1f"):format(x * 100)), hl(("%.1f"):format(y * 100)))
    end,
    click = function() panelToggle("ToggleWorldMap") end,
})

DT:Register("zone", {
    label = "Zone", events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    text = function() return GetMinimapZoneText() or "" end,
})

DT:Register("loadout", {
    label = "Talent loadout", events = { "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_TALENT_UPDATE" },
    text = function()
        local CT = rawget(_G, "C_ClassTalents")
        local id = CT and CT.GetLastSelectedSavedConfigID and CT.GetLastSelectedSavedConfigID(PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID() or 0)
        local info = id and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(id)
        return "Talents " .. hl(info and info.name or "default")
    end,
    click = function()
        if InCombatLockdown() then return end
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then pcall(PlayerSpellsUtil.ToggleClassTalentFrame) end
    end,
})

DT:Register("none", { label = "Nothing", text = function() return "" end })

-- ============================================================
-- Panels and slots
-- ============================================================
DT.panels = {}
DT.slots = {}

local function slotUpdate(slot)
    local def = slot.def
    if not def then slot.text:SetText("") return end
    local ok, s = pcall(def.text)
    slot.text:SetText(ok and s or "")
end

local function makeSlot(panel)
    local s = CreateFrame("Button", nil, panel)
    s.text = ns:CreateText(s, db().fontSize, "CENTER")
    s.text:SetAllPoints()
    s.text:SetJustifyH("CENTER")
    s.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    Chrome:Register(s.text, C.text, "text")
    s:RegisterForClicks("AnyUp")
    s:SetScript("OnClick", function(self, button) if self.def and self.def.click then pcall(self.def.click, button) end end)
    s:SetScript("OnEnter", function(self)
        local def = self.def
        if not def or not def.tooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
        GameTooltip:AddLine(def.label, C.fel[1], C.fel[2], C.fel[3])
        pcall(def.tooltip, GameTooltip)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    s:SetScript("OnUpdate", function(self, e)
        local def = self.def
        if not def or not def.interval then return end
        self.acc = (self.acc or 0) + e
        if self.acc >= def.interval then self.acc = 0; slotUpdate(self) end
    end)
    DT.slots[#DT.slots + 1] = s
    return s
end

function DT:BuildPanel(key)
    local p = CreateFrame("Frame", "WicksUI_Info_" .. key, UIParent)
    p:SetFrameStrata("BACKGROUND")
    ns:SetTemplate(p, "Transparent")
    p.slots = {}
    self.panels[key] = p
    local d = db().panels[key]
    ns:CreateMover(p, "info_" .. key, "Info panel, " .. key, d.point, { groups = "datatexts", config = "datatexts" })
    return p
end

function DT:LayoutPanel(key)
    local p, d = self.panels[key], db().panels[key]
    p:SetSize(d.width, d.height)
    ns.Movers:Resize("info_" .. key)
    local list = slotList(key)
    local n = #list
    for i = 1, math.max(n, #p.slots) do
        local s = p.slots[i]
        if i <= n then
            s = s or makeSlot(p)
            p.slots[i] = s
            s:ClearAllPoints()
            s:SetSize(d.width / n, d.height)
            s:SetPoint("LEFT", p, "LEFT", (i - 1) * d.width / n, 0)
            ns.Media:SetFont(s.text, db().fontSize)
            s.def = self.registry[list[i]]
            s:Show()
            slotUpdate(s)
        elseif s then
            s.def = nil
            s:Hide()
        end
    end
    -- Modern info panels are floating text: no bar, no lift.
    local bar = db().backdrop and not ns:Modern()
    p.wuiBG:SetShown(bar)
    if p.wuiShadow then p.wuiShadow:SetShown(bar) end
    p:SetShown(d.enable)
    ns.Movers:SetEnabled("info_" .. key, d.enable)
end

-- Events fan out to whichever slots show a datatext that wants them.
local function onEvent(event)
    for _, s in ipairs(DT.slots) do
        local def = s.def
        if def and def.events and s:IsVisible() then
            for _, e in ipairs(def.events) do
                if e == event then slotUpdate(s) break end
            end
        end
    end
end

function DT:Initialize()
    self.sessionStart = GetMoney()
    for key in pairs(db().panels) do self:BuildPanel(key) end
    local seen = {}
    for _, def in pairs(self.registry) do
        for _, e in ipairs(def.events or {}) do
            if not seen[e] then seen[e] = true; ns:On(e, onEvent) end
        end
    end
    ns:On("PLAYER_ENTERING_WORLD", function() for _, s in ipairs(DT.slots) do slotUpdate(s) end end)
    -- The values carry their colour in the text: drawn again for a new theme.
    if Chrome.OnThemeChanged then
        Chrome:OnThemeChanged(function() for _, s in ipairs(DT.slots) do slotUpdate(s) end end)
    end
    if C_FriendList and C_FriendList.ShowFriends then pcall(C_FriendList.ShowFriends) end
    self:Update()
end

function DT:Update()
    for key in pairs(self.panels) do self:LayoutPanel(key) end
end

-- ============================================================
-- Settings
-- ============================================================
ns.Config:AddPage("datatexts", "Info panels", function(L)
    local choices = {}
    for _, k in ipairs(DT.keys) do choices[#choices + 1] = { k, DT.registry[k].label } end
    L:DB(db)
    L:Toggle("Panel backgrounds", "backdrop")
    L:Slider("Text size", "fontSize", 8, 18, 1)
    for _, key in ipairs({ "left", "right", "top" }) do
        L:Heading(("The %s panel"):format(key))
        L:DB(function() return db().panels[key] end)
        L:Toggle("Show", "enable")
        L:Slider("Width", "width", 100, 1200, 2)
        L:Slider("Height", "height", 12, 40, 1)
        L:Slider("Slots", "slotCount", 1, 6, 1, {
            get = function() return #slotList(key) end,
            setter = function(v)
                local s = slotList(key)
                while #s < v do s[#s + 1] = "none" end
                while #s > v do s[#s] = nil end
                setSlots(key, s)
                ns.Config:Rebuild("datatexts")
            end,
        })
        for i = 1, #slotList(key) do
            L:Dropdown(("Slot %d"):format(i), i, choices, {
                get = function() return slotList(key)[i] end,
                setter = function(v) local s = slotList(key); s[i] = v; setSlots(key, s) end,
            })
        end
    end
end, { onChange = function() DT:Update() end, order = 80 })
