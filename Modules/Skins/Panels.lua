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
    "BattlefieldMapFrame", "OpacityFrame",
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
    -- The newer three-slice buttons use Left, Center and Right and swap
    -- their atlases on press, the old ones Left, Middle and Right. Their
    -- atlas swaps leave alpha alone, so fading them holds.
    -- Named pieces only: a button's icon is a texture too, and must stay.
    for _, k in ipairs({ "Left", "Middle", "Center", "Right", "LeftSeparator", "RightSeparator", "Background" }) do fade(b[k]) end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    -- Our own hover, on the highlight layer so the client shows it itself.
    local e = extras[b] or {}
    extras[b] = e
    if not e.hover then
        local hover = b:CreateTexture(nil, "HIGHLIGHT")
        hover:SetPoint("TOPLEFT", 2, -2)
        hover:SetPoint("BOTTOMRIGHT", -2, 2)
        hover:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.18)
        Chrome:Register(hover, "fel", "texture", 0.18)
        e.hover = hover
    end
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
-- ============================================================
-- Windows that are not built from the common template
-- ============================================================
PS.SPECIAL = {}

-- A frame's art and its border's art, by alpha on the pieces rather than
-- on the frame, for frames whose own alpha Blizzard drives.
local function fadeFrameArt(f)
    if not f then return end
    fade(f.NineSlice); fade(f.Bg); fade(f.TopTileStreaks); fade(f.PortraitContainer)
    fadeRegions(f)
end

-- The full world map. Its border, title and close button live on a
-- BorderFrame of their own; the quest log beside it has its own art.
PS.SPECIAL.WorldMapFrame = function(frame)
    local bf = frame.BorderFrame
    fadeRegions(frame)
    if bf then
        fadeFrameArt(bf)
        styleText(bf.TitleContainer and bf.TitleContainer.TitleText, 14, C.fel)
        styleClose(bf.CloseButton)
        if bf.Tutorial then fade(bf.Tutorial) end
    end
    local bd = backdrop(frame, "Default", db().brackets)
    if bf then bd:SetParent(bf); bd:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1)) end
    local nav = frame.NavBar
    if nav then
        fadeRegions(nav)
        if nav.overlay then fadeRegions(nav.overlay) end
        for _, k in ipairs({ "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" }) do fade(nav[k]) end
        local home = nav.homeButton or nav.home
        if home then
            fadeRegions(home)
            backdrop(home, "Shadow", false, 1)
            styleText(home.text or home.Text or (home.GetFontString and home:GetFontString()))
        end
    end
    local ql = frame.QuestLog or rawget(_G, "QuestMapFrame")
    if ql then
        fadeRegions(ql)
        fade(ql.Background)
        fade(ql.VerticalSeparator)
        if ql.DetailsFrame then fadeRegions(ql.DetailsFrame); fade(ql.DetailsFrame.BackFrame) end
        scanButtons(ql, 1)
    end
    if frame.SidePanelToggle then scanButtons(frame.SidePanelToggle, 1) end
end

-- The small zone map (Shift-M). Blizzard sets its BorderFrame's alpha
-- from the opacity slider, so the border's pieces are faded instead of
-- the border, and our panel hangs off the border so the slider fades it.
PS.SPECIAL.BattlefieldMapFrame = function(frame)
    local bf = frame.BorderFrame
    fadeRegions(frame)
    if bf then
        fadeFrameArt(bf)
        styleClose(bf.CloseButton)
        for _, child in ipairs({ bf:GetChildren() }) do
            if child ~= bf.CloseButton and child.GetRegions then fadeRegions(child) end
        end
    end
    local bd = backdrop(frame, "Default", false)
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
    bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    if bf then bd:SetParent(bf); bd:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1)) end
    local tab = rawget(_G, "BattlefieldMapTab")
    if tab then
        fadeRegions(tab)
        for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do fade(tab[k]) end
        backdrop(tab, "Shadow", false, 2)
        styleText(tab.Text)
    end
end

-- The opacity slider the zone map opens beside itself.
PS.SPECIAL.OpacityFrame = function(frame)
    fadeFrameArt(frame)
    if frame.Border then fade(frame.Border) end
    backdrop(frame, "Default", false)
    local s = rawget(_G, "OpacityFrameSlider")
    if s then
        fadeRegions(s)
        local thumb = s.GetThumbTexture and s:GetThumbTexture()
        if thumb then
            thumb:SetAlpha(1)
            thumb:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
            Chrome:Register(thumb, "fel", "texture")
            thumb:SetSize(14, 6)
        end
        local e = extras[s] or {}
        extras[s] = e
        if not e.track then
            local track = s:CreateTexture(nil, "BACKGROUND")
            track:SetPoint("TOP", 0, -4)
            track:SetPoint("BOTTOM", 0, 4)
            track:SetWidth(4)
            track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            Chrome:Register(track, "border", "texture")
            e.track = track
        end
    end
    for _, n in ipairs({ "OpacityFrameText", "OpacityFrameLow", "OpacityFrameHigh" }) do
        styleText(rawget(_G, n), nil, n == "OpacityFrameText" and C.fel or nil)
    end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "FontString" then styleText(r, nil, C.text) end
    end
end

-- The spellbook, inside the player spells window. The book is parchment
-- and its text is dark ink for it, so taking the parchment away means
-- lighting the text. Entries are pooled and redrawn on every page turn,
-- and Blizzard recolours them as it goes, so while the book is open a
-- light poll puts the look back on whatever is showing. Only text too
-- dark to read on our panel is changed; the grey of an unlearned spell
-- and the other meaningful colours stay.
local styledEntry = setmetatable({}, { __mode = "k" })

local function darkText(fs)
    local r, g, b = fs:GetTextColor()
    return r and (r * 0.3 + g * 0.59 + b * 0.11) < 0.4
end

local function lighten(fs, color)
    if fs and fs.GetTextColor and darkText(fs) then
        local c = color or C.text
        fs:SetTextColor(c[1], c[2], c[3])
    end
end

local function styleEntry(f)
    if f.Button and f.Button.Icon and f.Name then
        lighten(f.Name)
        lighten(f.SubName, C.muted)
        lighten(f.RequiredLevel, C.muted)
        if not styledEntry[f] then
            styledEntry[f] = true
            fade(f.Backplate)
            fade(f.Button.Border)
            fade(f.Button.TrainableBackplate)
            local e = extras[f.Button] or {}
            extras[f.Button] = e
            if not e.backdrop then
                local bd = CreateFrame("Frame", nil, f.Button)
                bd:SetAllPoints(f.Button.Icon)
                bd:SetFrameLevel(f.Button:GetFrameLevel() + 1)
                ns:SetTemplate(bd, "None")
                e.backdrop = bd
            end
        end
        return true
    end
    -- A category header: its text, and the scrollwork under it.
    if f.Text and f.GetRegions and f.Init and not f.Button then
        lighten(f.Text, C.fel)
        if not styledEntry[f] then
            styledEntry[f] = true
            for _, r in ipairs({ f:GetRegions() }) do
                if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
            end
            local e = extras[f] or {}
            extras[f] = e
            if not e.rule then
                local rule = f:CreateTexture(nil, "ARTWORK")
                rule:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.5)
                rule:SetHeight(ns.mult or 1)
                rule:SetPoint("TOPLEFT", f.Text, "BOTTOMLEFT", 0, -4)
                rule:SetPoint("RIGHT", f, "RIGHT", -10, 0)
                Chrome:Register(rule, "fel", "texture", 0.5)
                e.rule = rule
            end
        end
        return true
    end
end

local function walkBook(frame, depth)
    if depth > 6 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() and not styleEntry(child) then walkBook(child, depth + 1) end
    end
end

local function skinSpellBook(sb)
    if not sb or done[sb] then return end
    done[sb] = true
    fadeRegions(sb)
    fade(sb.BookCornerFlipbook)
    fade(sb.BackgroundBorder)
    local paged = sb.PagedSpellsFrame
    if paged then
        fadeRegions(paged)
        if paged.PagingControls then
            for _, r in ipairs({ paged.PagingControls:GetRegions() }) do
                if r:GetObjectType() == "FontString" then styleText(r, nil, C.text) end
            end
        end
    end
    if sb.TopBar then fadeRegions(sb.TopBar) end
    local poll = CreateFrame("Frame", nil, sb)
    local acc = 0.3
    poll:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.3 then return end
        acc = 0
        walkBook(paged or sb, 1)
    end)
end

PS.SPECIAL.PlayerSpellsFrame = function(frame)
    skinSpellBook(frame.SpellBookFrame)
    return "generic"
end

function PS:Skin(frame)
    if not frame or done[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    local name = frame:GetName()
    if name and excluded(name) then return end
    done[frame] = true
    local d = db()
    if name and PS.SPECIAL[name] then
        if PS.SPECIAL[name](frame) ~= "generic" then return end
    end

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
