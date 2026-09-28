-- Wick's UI
-- Modules/Skins/Panels.lua: the game's windows in the Wick look.
--
-- Character, spellbook and talents, friends, the game menu, map, quests,
-- vendors, mail, settings and the rest. One generic skin covers them,
-- because nearly all of them are built from the same few templates: a
-- NineSlice border, a background, a title, a close button, an inset and
-- a row of tabs.
--
-- The same rule as every other skin here: method calls on their frames
-- and frames of our own, nothing written into their tables, no script
-- replaced. Their art is faded by alpha, which their own Show and Hide
-- calls leave alone, so the skin survives tab switches and refreshes.
-- Hooks are post-hooks on Blizzard's functions, which run after theirs.
--
-- Windows that load on demand (talents, professions, the auction house,
-- the calendar) are skinned when their addon loads.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local PS = ns:NewModule("panelskins", { title = "Windows", order = 96 })
ns.PanelSkins = PS

ns.defaults.profile.panelskins = {
    enable = true,
    alpha = 0.95,
    brackets = true,
    buttons = true,
    tabs = true,
    exclude = "",           -- window names to leave alone, comma separated
}

local function db() return PS:db() end

-- Frame name -> nothing. Load-on-demand windows are in the same list;
-- they are simply absent until their addon loads.
PS.WINDOWS = {
    "CharacterFrame", "GameMenuFrame", "PlayerSpellsFrame", "SpellBookFrame", "ProfessionsBookFrame",
    "FriendsFrame", "WorldMapFrame", "QuestFrame", "GossipFrame", "MerchantFrame", "MailFrame",
    "OpenMailFrame", "SettingsPanel", "CollectionsJournal", "DressUpFrame", "AddonList", "LootFrame",
    "TradeFrame", "TaxiFrame", "ClassTrainerFrame", "AuctionHouseFrame", "InspectFrame", "CalendarFrame",
    "ItemTextFrame", "CommunitiesFrame", "EncounterJournal", "PVEFrame", "LFGParentFrame",
    "GroupFinderFrame", "QuestLogPopupDetailFrame", "TimeManagerFrame", "HelpFrame", "StableFrame",
    "BankFrame", "ChatConfigFrame", "LegacyFrame", "StatisticsFrame", "TabardFrame", "PetitionFrame",
    "GuildRegistrarFrame", "ProfessionsFrame", "ItemSocketingFrame", "MacroFrame", "KeyBindingFrame",
    "BarberShopFrame", "TransmogFrame", "WardrobeFrame", "GuildFrame",
}

local done = setmetatable({}, { __mode = "k" })
local extras = setmetatable({}, { __mode = "k" })

local function excluded(name)
    for _, n in ipairs(ns:List(db().exclude)) do if n == name then return true end end
    return false
end

-- A frame's own textures only, never its children's.
local function fadeRegions(frame)
    if not frame or not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
end

local function fade(frame)
    if frame and frame.SetAlpha then frame:SetAlpha(0) end
end

local function backdrop(frame, template, brackets, inset)
    local e = extras[frame] or {}
    extras[frame] = e
    if e.backdrop then return e.backdrop end
    local bd = CreateFrame("Frame", nil, frame)
    local o = inset or 0
    bd:SetPoint("TOPLEFT", o, -o)
    bd:SetPoint("BOTTOMRIGHT", -o, o)
    bd:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    ns:SetTemplate(bd, template or "Default", { brackets = brackets, alpha = template == "Default" and db().alpha or nil })
    e.backdrop = bd
    return bd
end

-- ============================================================
-- Pieces
-- ============================================================
local function styleText(fs, size, color)
    if not fs or not fs.SetFont then return end
    local _, cur = fs:GetFont()
    fs:SetFont(ns.Media:Font(), size or cur or 12, "")
    fs:SetShadowOffset(1, -1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

local function styleButton(b)
    if not b or done[b] or not db().buttons then return end
    done[b] = true
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do fade(b[k]) end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    local hl = b.GetHighlightTexture and b:GetHighlightTexture()
    if hl then hl:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.18); hl:SetAllPoints() end
    backdrop(b, "Shadow", false, 1)
    local text = b.Text or (b.GetFontString and b:GetFontString())
    styleText(text)
end

-- The small X in the corner, redrawn as ours.
local function styleClose(b)
    if not b or done[b] then return end
    done[b] = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    fadeRegions(b)
    local e = extras[b] or {}
    extras[b] = e
    local x = b:CreateFontString(nil, "OVERLAY")
    ns.Media:SetFont(x, 14, "NONE")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("x")
    x:SetTextColor(C.text[1], C.text[2], C.text[3])
    e.x = x
    b:HookScript("OnEnter", function() x:SetTextColor(C.fel[1], C.fel[2], C.fel[3]) end)
    b:HookScript("OnLeave", function() x:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
end

local function styleTab(tab)
    if not tab or done[tab] or not db().tabs then return end
    done[tab] = true
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
        "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do fade(tab[k]) end
    local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    local bd = backdrop(tab, "Shadow", false, 3)
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT", 6, -3)
    bd:SetPoint("BOTTOMRIGHT", -6, 3)
    styleText(tab.Text)
end

local function markTab(tab, selected)
    local e = extras[tab]
    if not e or not e.backdrop then return end
    ns:SetBorderColor(e.backdrop, selected and "fel" or "border")
    if tab.Text then
        local c = selected and C.fel or C.text
        tab.Text:SetTextColor(c[1], c[2], c[3])
    end
end

local function tabsOf(frame)
    local out = {}
    local name = frame:GetName()
    if type(frame.Tabs) == "table" then for _, t in ipairs(frame.Tabs) do out[#out + 1] = t end end
    local ts = frame.TabSystem
    if ts and type(ts.tabs) == "table" then for _, t in ipairs(ts.tabs) do out[#out + 1] = t end end
    if name then
        for i = 1, 12 do
            local t = _G[name .. "Tab" .. i]
            if not t then break end
            out[#out + 1] = t
        end
    end
    return out
end

-- Buttons one or two levels down that use the classic three-piece art.
local function scanButtons(frame, depth)
    if depth > 3 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:GetObjectType() == "Button" and child.Left and child.Right and child.Middle then
            styleButton(child)
        end
        if not child.isTopTab and not (child.GetObjectType and child:GetObjectType() == "ScrollFrame") then
            scanButtons(child, depth + 1)
        end
    end
end

-- ============================================================
-- A window
-- ============================================================
function PS:Skin(frame)
    if not frame or done[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    local name = frame:GetName()
    if name and excluded(name) then return end
    done[frame] = true
    local d = db()

    fade(frame.NineSlice)
    fade(frame.Bg)
    fade(frame.Background)
    fade(frame.TopTileStreaks)
    fade(frame.Border)
    fade(frame.BorderFrame and frame.BorderFrame.NineSlice)
    if frame.PortraitContainer then fade(frame.PortraitContainer) end
    if frame.portrait then fade(frame.portrait) end
    fadeRegions(frame)
    if frame.Inset then
        fade(frame.Inset.NineSlice)
        fade(frame.Inset.Bg)
        fadeRegions(frame.Inset)
    end
    if frame.Header then
        fadeRegions(frame.Header)
        styleText(frame.Header.Text, 14, C.fel)
    end

    backdrop(frame, "Default", d.brackets)

    local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
        or (name and _G[name .. "TitleText"])
    styleText(title, 14, C.fel)

    styleClose(frame.CloseButton or frame.ClosePanelButton or (name and _G[name .. "CloseButton"]))
    for _, t in ipairs(tabsOf(frame)) do styleTab(t) end
    scanButtons(frame, 1)
    if frame.buttons and type(frame.buttons) == "table" then
        for _, b in ipairs(frame.buttons) do styleButton(b) end
    end
end

function PS:SkinAll()
    if not db().enable then return end
    for _, n in ipairs(self.WINDOWS) do
        local f = _G[n]
        if f then
            local ok, err = pcall(self.Skin, self, f)
            if not ok then ns.errors = ns.errors or {}; ns.errors[#ns.errors + 1] = "skin " .. n .. ": " .. tostring(err) end
        end
    end
end

-- ============================================================
-- Lifecycle
-- ============================================================
function PS:Initialize()
    self:SkinAll()
    -- Load-on-demand windows appear with their addon.
    ns:On("ADDON_LOADED", function(_, addon)
        if type(addon) == "string" and addon:find("^Blizzard_") then
            C_Timer.After(0, function() PS:SkinAll() end)
        end
    end)
    -- Tabs: mark the selected one after Blizzard has done its part.
    if PanelTemplates_SelectTab then
        hooksecurefunc("PanelTemplates_SelectTab", function(tab) markTab(tab, true) end)
        hooksecurefunc("PanelTemplates_DeselectTab", function(tab) markTab(tab, false) end)
    end
    -- The game menu rebuilds its buttons every time it opens.
    local gm = rawget(_G, "GameMenuFrame")
    if gm and gm.InitButtons then
        hooksecurefunc(gm, "InitButtons", function(self)
            if not db().enable then return end
            for _, b in ipairs(self.buttons or {}) do styleButton(b) end
        end)
    end
end

function PS:Update()
    self:SkinAll()
    for f, e in pairs(extras) do
        if e.backdrop and e.backdrop.wuiBG and e.backdrop.wuiTemplate == "Default" then
            e.backdrop.wuiBG:SetAlpha(db().alpha)
        end
    end
end

ns.Config:AddPage("panelskins", "Windows", function(L)
    L:DB(db)
    L:Note("The game's own windows (character, spellbook and talents, friends, the game menu, the map, vendors, mail, settings and the rest) in the Wick look. Only their art changes: nothing about how they work is touched. Switching this off fully takes a reload.")
    L:Toggle("Skin the windows", "enable")
    L:Slider("Background alpha", "alpha", 0.3, 1, 0.05)
    L:Toggle("Fel corners", "brackets", { tooltip = "Takes effect after a reload." })
    L:Toggle("Buttons", "buttons")
    L:Toggle("Tabs", "tabs")
    L:Input("Leave these alone", "exclude", { width = 520, span = 2,
        tooltip = "Frame names separated by commas, for example  WorldMapFrame, AuctionHouseFrame. /fstack in game shows a frame's name. Takes effect after a reload." })
end, { parent = "skins", onChange = function() PS:Update() end, order = 96 })
