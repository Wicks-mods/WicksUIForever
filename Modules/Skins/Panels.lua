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
    include = "",           -- windows added with /wui skin
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
    "BattlefieldMapFrame", "OpacityFrame", "LFGListingFrame", "LFGBrowseFrame",
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4", "ReadyCheckFrame", "ReadyCheckListenerFrame",
    "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4", "LFGDungeonReadyDialog",
    "LFDRoleCheckPopup", "RolePollPopup", "GuildInviteFrame", "PVPReadyDialog", "LFGInvitePopup",
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

local textButtons = setmetatable({}, { __mode = "k" })
local function styleButton(b)
    if not b or done[b] or not db().buttons then return end
    done[b] = true
    textButtons[b] = true
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
    -- A close button with a word on it ("Close") is an ordinary button;
    -- our X on top of it would sit on the word.
    local fs = b.Text or (b.GetFontString and b:GetFontString())
    local word = fs and fs.GetText and fs:GetText()
    if word and word ~= "" then styleButton(b) return end
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
    -- The hover colour is a second X on the highlight layer, which the
    -- client shows on mouseover itself; no hook on their scripts.
    local xh = b:CreateFontString(nil, "HIGHLIGHT")
    ns.Media:SetFont(xh, 14, "NONE")
    xh:SetPoint("CENTER", 0, 1)
    xh:SetText("x")
    xh:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
    e.xh = xh
end

local function styleTab(tab)
    if not tab or done[tab] or not db().tabs then return end
    done[tab] = true
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
        "LeftHighlight", "MiddleHighlight", "RightHighlight", "Background", "Border", "SelectedTexture" }) do fade(tab[k]) end
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
-- Text and search boxes: three-piece art, faded, with our field behind.
local function styleEditBox(eb)
    if done[eb] then return end
    done[eb] = true
    for _, k in ipairs({ "Left", "Middle", "Right", "Mid", "Center", "left", "right", "middle" }) do fade(eb[k]) end
    -- Text boxes framed with a NineSlice (popups), and money boxes whose
    -- middle piece is only reachable by its global name.
    fade(eb.NineSlice)
    local name = eb:GetName()
    if name then fade(_G[name .. "Middle"]); fade(_G[name .. "Left"]); fade(_G[name .. "Right"]) end
    backdrop(eb, "Shadow", false, 0)
end

-- Modern scroll bars: a track and a thumb, each Begin/Middle/End.
local function styleScrollBar(sb)
    if done[sb] then return end
    done[sb] = true
    local track = sb.Track
    for _, k in ipairs({ "Begin", "Middle", "End" }) do fade(track[k]) end
    fadeRegions(track)
    local e = extras[sb] or {}
    extras[sb] = e
    if not e.line then
        local line = track:CreateTexture(nil, "BACKGROUND")
        line:SetPoint("TOP"); line:SetPoint("BOTTOM")
        line:SetWidth(2)
        line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        Chrome:Register(line, "border", "texture")
        e.line = line
    end
    local thumb = track.Thumb
    if thumb then
        for _, k in ipairs({ "Begin", "Middle", "End" }) do fade(thumb[k]) end
        fadeRegions(thumb)
        local te = extras[thumb] or {}
        extras[thumb] = te
        if not te.fill then
            local fill = thumb:CreateTexture(nil, "ARTWORK")
            fill:SetPoint("TOPLEFT", 2, 0)
            fill:SetPoint("BOTTOMRIGHT", -2, 0)
            fill:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.8)
            Chrome:Register(fill, "fel", "texture", 0.8)
            te.fill = fill
        end
    end
    -- The arrow steppers keep their arrows, greyed to sit with the rest.
    for _, k in ipairs({ "Back", "Forward" }) do
        local b = sb[k]
        if b then
            for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
                local t = b[get] and b[get](b)
                if t and t.SetDesaturated then t:SetDesaturated(true) end
            end
        end
    end
end

-- Dropdown boxes: a background piece and an arrow.
local function styleDropdown(dd)
    if done[dd] then return end
    done[dd] = true
    fade(dd.Background)
    for _, k in ipairs({ "Left", "Middle", "Right" }) do fade(dd[k]) end
    backdrop(dd, "Shadow", false, 0)
    if dd.Arrow and dd.Arrow.SetDesaturated then dd.Arrow:SetDesaturated(true) end
    styleText(dd.Text)
end

-- ============================================================
-- The common widgets, found wherever they sit in a window
-- ============================================================

-- Blizzard's gold label text reads as the old look on glass; it becomes
-- the Wick text colour. Other colours (quality, red warnings, greys)
-- carry meaning and stay.
local function isGold(fs)
    local r, g, b = fs:GetTextColor()
    return r and r > 0.85 and g > 0.6 and g < 0.9 and b < 0.3
end
-- Every window's text in the Wick font, a size up (PT Sans Narrow runs
-- small next to Friz), with the soft shadow the unit frames use. Blizzard
-- swaps font objects back on some state changes, so this runs on every
-- pass; it only touches strings not already in our font.
local ourFont
local function isOurs(path)
    if not ourFont then ourFont = ns.Media:Font():lower():gsub("/", "\\") end
    return path and path:lower():gsub("/", "\\") == ourFont
end
local fontSet = setmetatable({}, { __mode = "k" })
local function styleFont(fs)
    local path, size, flags = fs:GetFont()
    -- A string with no font yet reports nil and a garbage height; leave it.
    if not path or not size or size < 1 or size > 64 or isOurs(path) then return end
    local want = fontSet[fs] and fontSet[fs] or math.floor(size + 1.5)
    fs:SetFont(ns.Media:Font(), want, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fontSet[fs] = want
end
local function recolorText(frame)
    if not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "FontString" then
            styleFont(r)
            local cr, cg, cb = r:GetTextColor()
            local darkInk = cr and (cr * 0.3 + cg * 0.59 + cb * 0.11) < 0.35
            if isGold(r) or darkInk then r:SetTextColor(C.text[1], C.text[2], C.text[3]) end
        end
    end
end

local function tex(b, get) return b[get] and b[get](b) end

-- Small check boxes: our field, a rounded fel fill when checked.
local function styleCheck(cb)
    if done[cb] then return end
    done[cb] = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = tex(cb, get); if t then t:SetAlpha(0) end
    end
    local bd = backdrop(cb, "Shadow", false, 0)
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT", 3, -3)
    bd:SetPoint("BOTTOMRIGHT", -3, 3)
    for _, get in ipairs({ "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
        local t = tex(cb, get)
        if t then
            t:SetDesaturated(false)
            ns:Fill(t, C.fel[1], C.fel[2], C.fel[3], get == "GetCheckedTexture" and 1 or 0.4)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", 6, -6)
            t:SetPoint("BOTTOMRIGHT", -6, 6)
        end
    end
end

-- Sliders: a thin track and a fel handle.
local function styleSlider(sl)
    if done[sl] then return end
    done[sl] = true
    local thumb = sl.GetThumbTexture and sl:GetThumbTexture()
    for _, r in ipairs({ sl:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= thumb then r:SetAlpha(0) end
    end
    if thumb then
        ns:Fill(thumb, C.fel[1], C.fel[2], C.fel[3], 1)
        thumb:SetSize(10, 14)
    end
    local e = extras[sl] or {}
    extras[sl] = e
    if not e.track then
        local track = sl:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT", 2, 0)
        track:SetPoint("RIGHT", -2, 0)
        track:SetHeight(3)
        ns:Fill(track, C.border[1], C.border[2], C.border[3], 1)
        e.track = track
    end
end

-- Status bars in windows (skill bars and the like): our texture, their
-- colour, their frame art gone.
local function styleBar(sb)
    if done[sb] then return end
    done[sb] = true
    local fill = sb:GetStatusBarTexture()
    for _, r in ipairs({ sb:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= fill then r:SetAlpha(0) end
    end
    for _, child in ipairs({ sb:GetChildren() }) do
        if child:GetObjectType() == "Frame" then fadeRegions(child) end
    end
    local r, g, b = sb:GetStatusBarColor()
    sb:SetStatusBarTexture(ns.Media:Statusbar())
    -- Bars whose colour was in their art come out white on a flat texture.
    if not r or (r > 0.95 and g > 0.95 and b > 0.95) then r, g, b = C.fel[1], C.fel[2], C.fel[3] end
    sb:SetStatusBarColor(r, g, b)
    backdrop(sb, "Shadow", false, 1)
end

-- Icon tabs and icon buttons (the character and profession side tabs,
-- the spellbook's category icons): the gold frame goes, the icon gets our
-- corners, and a checked tab wears the fel ring.
local function styleIconButton(b)
    if done[b] then return end
    done[b] = true
    for _, k in ipairs({ "Border", "Background", "Glow", "BorderSelected", "SelectedTexture", "IconOverlay",
        "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow", "SquareBorder",
        -- Icon tabs built on the tab template also carry its three pieces.
        "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
        "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do fade(b[k]) end
    -- Art that lives on an unnamed inner frame of the button (the
    -- spellbook's category tabs keep their frame there). Our own panels
    -- carry wuiBG and are left alone.
    for _, child in ipairs({ b:GetChildren() }) do
        if child:GetObjectType() == "Frame" and not child.wuiBG then fadeRegions(child) end
    end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = tex(b, get); if t then t:SetAlpha(0) end
    end
    local icon = b.Icon or b.icon
    -- An icon from Blizzard's UI art (an atlas: a dropdown arrow, a cog) is
    -- a control glyph, not a spell or item picture. Cropping would cut it,
    -- so it is greyed instead, like the other small controls.
    local atlas = icon and icon.GetAtlas and icon:GetAtlas()
    if icon and atlas then
        icon:SetDesaturated(true)
        icon:SetVertexColor(0.85, 0.85, 0.85)
    elseif icon then
        -- Blizzard's own icon mask trims the picture to a smaller, off-centre
        -- shape; with ours on top the icon sits askew in our tile. Theirs
        -- comes off, ours gives the corners.
        if b.IconMask and icon.RemoveMaskTexture then icon:RemoveMaskTexture(b.IconMask) end
        if b.IconMask then b.IconMask:Hide() end
        -- Square it inside the button: some templates draw the icon taller
        -- than the button it sits in (the spellbook tabs: 36x35 on 44x32).
        local bw, bh = b:GetSize()
        if bw and bh and bw > 0 and bh > 0 then
            local side = math.floor(math.min(bw, bh) - 4)
            local iw, ih = icon:GetSize()
            if (iw or 0) > side or (ih or 0) > side or (iw ~= ih) then
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", b, "CENTER", 0, 0)
                icon:SetSize(side, side)
            end
        end
        ns:CropIcon(icon)
    end
    local bd = backdrop(b, "Default", false, 0)
    -- Hug the icon, not the button: on many icon tabs the icon is smaller
    -- than the button and sits off centre, and a tile the button's size
    -- would stick out from it.
    if icon and not atlas then
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        bd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    end
    local ct = tex(b, "GetCheckedTexture")
    if ct then
        ct:SetTexture(ns.Media.ring)
        if ct.SetTextureSliceMargins then ct:SetTextureSliceMargins(8, 8, 8, 8) end
        ct:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        ct:SetAllPoints(icon or b)
    end
    local e = extras[b] or {}
    extras[b] = e
    if not e.hover then
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetAllPoints(icon or b)
        ns:Fill(h, 1, 1, 1, 0.12)
        e.hover = h
    end
end

-- Small arrow and toggle buttons: their gold or red art greyed to sit
-- with the rest. Their shapes stay; they are how the button is read.
local function styleArrow(b)
    if done[b] then return end
    done[b] = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local t = tex(b, get)
        if t and t.SetDesaturated then t:SetDesaturated(true); t:SetVertexColor(0.85, 0.85, 0.85) end
    end
end

-- List rows (settings categories, map breadcrumbs): their bar art goes;
-- our hover takes its place.
local function styleRow(b)
    if done[b] then return end
    done[b] = true
    fadeRegions(b)
    local hl = tex(b, "GetHighlightTexture")
    if hl then hl:SetAlpha(0) end
    local e = extras[b] or {}
    extras[b] = e
    if not e.hover then
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetPoint("TOPLEFT", 2, -1)
        h:SetPoint("BOTTOMRIGHT", -2, 1)
        ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.12)
        e.hover = h
    end
end

-- Filter buttons (the dropdown with a reset cross beside it): all of their
-- art but the arrow goes, on every pass as their state art swaps; our card
-- and hover take its place.
local function isFilter(b)
    if b.ResetButton then return true end
    local p = b:GetParent()
    return p and (p.FilterDropdown == b or p.FilterButton == b) or false
end
local function styleFilter(b)
    local e = extras[b] or {}
    extras[b] = e
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= e.hover and r:GetAlpha() > 0 then
            local a = r:GetAtlas()
            if (a and a:lower():find("arrow")) or r == b.Arrow or r == b.Icon then
                if r.SetDesaturated then r:SetDesaturated(true) end
            else
                r:SetAlpha(0)
            end
        end
    end
    if not done[b] then
        done[b] = true
        backdrop(b, "Shadow", false, 0)
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetPoint("TOPLEFT", 2, -2)
        h:SetPoint("BOTTOMRIGHT", -2, 2)
        ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.15)
        e.hover = h
    end
    local fs = b.Text or (b.GetFontString and b:GetFontString())
    if fs and fs.SetTextColor then fs:SetTextColor(C.text[1], C.text[2], C.text[3]) end
end

local function hasText(b)
    local fs = b.Text or b.Label or b.text or (b.GetFontString and b:GetFontString())
    if not (fs and fs.GetText) then return false end
    local t = fs:GetText()
    return t ~= nil and t ~= ""
end

local function scanButtons(frame, depth)
    if depth > 7 or not frame.GetChildren then return end
    recolorText(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        local kind = child:GetObjectType()
        local w, h = child:GetSize()
        w, h = w or 0, h or 0
        local isButton = kind == "Button" or kind == "CheckButton"
        if kind == "Button" and isFilter(child) then
            styleFilter(child)
        elseif isButton and (child.Icon or child.icon) and not hasText(child) and not child.Name
            and not (child:GetParent() and child:GetParent().Button == child) then
            -- Icon tabs first: many are built on the tab template and carry
            -- Left, Middle and Right, which would otherwise make them buttons.
            styleIconButton(child)
        elseif kind == "Button" and child.Left and child.Right and (child.Middle or child.Center) then
            styleButton(child)
        elseif kind == "EditBox" and ((child.Left and child.Right) or (child.left and child.right) or child.NineSlice) then
            styleEditBox(child)
        elseif child.Track and child.Track.Thumb and child.Back and child.Forward then
            styleScrollBar(child)
        elseif child.Arrow and child.Background and child.Text then
            styleDropdown(child)
        elseif kind == "Slider" then
            styleSlider(child)
        elseif kind == "StatusBar" then
            styleBar(child)
        elseif kind == "CheckButton" and w <= 36 and h <= 36 and not (child.Icon or child.icon) then
            styleCheck(child)
        elseif isButton and (child.Icon or child.icon) and not child.Left and not child.Name
            and not (child:GetParent() and child:GetParent().Button == child) then
            styleIconButton(child)
        elseif isButton and w <= 32 and h <= 32 and not hasText(child) then
            styleArrow(child)
        elseif kind == "Button" and w >= 110 and h <= 36 and hasText(child) and not child.CollapseButton then
            styleRow(child)
        end
        if kind ~= "ScrollFrame" then
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

-- Deeper strip for windows whose art sits on inner frames. Textures on
-- plain Frames only, two levels down; buttons, check boxes, bars, models
-- and scroll lists are content and are left alone, so icons and pictures
-- survive.
local CONTENT = { Button = true, CheckButton = true, EditBox = true, Slider = true, StatusBar = true,
    ScrollFrame = true, ModelScene = true, PlayerModel = true, DressUpModel = true, Model = true,
    Cooldown = true, SimpleHTML = true, MessageFrame = true, ScrollingMessageFrame = true }
local function deepStrip(frame, depth, limit)
    if depth > (limit or 2) or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local kind = child:GetObjectType()
        if not CONTENT[kind] and not child.ScrollTarget and not child.ScrollBar then
            fadeRegions(child)
            fade(child.NineSlice)
            deepStrip(child, depth + 1, limit)
        end
    end
end
PS.DEEP = { LFGParentFrame = 2, LFGListingFrame = 2, LFGBrowseFrame = 2,
    CharacterFrame = 4, ProfessionsBookFrame = 4, SettingsPanel = 3 }

-- Quest log zone headers: pooled buttons with a collapse button. Their
-- bar art goes, the text is lit; quest rows are left alone, since their
-- textures are the tracked tick and the quest icons.
local function styleQuestHeaders(root, depth)
    if depth > 6 or not root.GetChildren then return end
    for _, child in ipairs({ root:GetChildren() }) do
        if child:IsShown() then
            if child.CollapseButton and child:GetObjectType() == "Button" then
                if not done[child] then
                    done[child] = true
                    fadeRegions(child)
                    local hl = child.GetHighlightTexture and child:GetHighlightTexture()
                    if hl then hl:SetAlpha(0) end
                    backdrop(child, "Shadow", false, 0)
                end
                local text = child.ButtonText or child.Text or (child.GetFontString and child:GetFontString())
                if text then text:SetTextColor(C.fel[1], C.fel[2], C.fel[3]) end
            else
                styleQuestHeaders(child, depth + 1)
            end
        end
    end
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
    -- Our panel stays under the map: the border frame draws above the map
    -- canvas, so a panel on it would cover the map.
    backdrop(frame, "Default", db().brackets)
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
        deepStrip(ql, 1)
        scanButtons(ql, 1)
        local qf = ql.QuestsFrame
        if qf then
            fadeRegions(qf)
            if qf.ScrollFrame then fadeRegions(qf.ScrollFrame) end
        end
        local poll = CreateFrame("Frame", nil, ql)
        local acc = 0.4
        poll:SetScript("OnUpdate", function(_, e)
            acc = acc + e
            if acc < 0.4 then return end
            acc = 0
            styleQuestHeaders(ql, 1)
        end)
    end
    local mm = bf and bf.MaximizeMinimizeFrame
    if mm then
        for _, b in ipairs({ mm:GetChildren() }) do
            for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
                local t = b[get] and b[get](b)
                if t and t.SetDesaturated then t:SetDesaturated(true) end
            end
        end
    end
    if frame.SidePanelToggle then scanButtons(frame.SidePanelToggle, 1) end
end

-- The small zone map (Shift-M). Blizzard sets its BorderFrame's alpha
-- from the opacity slider, so the border's pieces are faded instead of
-- the border, and our panel copies the border's alpha.
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
    -- Under the map, like the world map's, and following the border's
    -- alpha so the opacity slider fades our panel with it.
    if bf then
        local acc = 0
        bd:SetScript("OnUpdate", function(self, e)
            acc = acc + e
            if acc < 0.1 then return end
            acc = 0
            local a = bf:GetAlpha()
            if math.abs(self:GetAlpha() - a) > 0.01 then self:SetAlpha(a) end
        end)
    end
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
        -- Every pass, not once: switching category (to the pet's spells,
        -- say) redraws the icon frame and shows it again.
        fade(f.Backplate)
        fade(f.Button.Border)
        fade(f.Button.TrainableBackplate)
        fade(f.Button.TrainableShadow)
        if not styledEntry[f] then
            styledEntry[f] = true
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

-- Our panel hugs the book: it ends a margin below the page controls and
-- just outside the leftmost and rightmost pieces along the top, instead of
-- filling the whole window, which Blizzard sizes for its book art. On the
-- other tabs (talents) it covers the window again. Only our panel moves;
-- their window keeps its size.
local function fitBook(host, sb)
    local e = host and extras[host]
    local bd = e and e.backdrop
    if not bd then return end
    local paged = sb.PagedSpellsFrame
    local pc = paged and paged.PagingControls
    local hl, hr, hb = host:GetLeft(), host:GetRight(), host:GetBottom()
    local key = "full"
    local l, r, b = 0, 0, 0
    if sb:IsVisible() and pc and pc:IsVisible() and hl and pc:GetBottom() then
        local left = hl
        local tabs = sb.CategoryTabSystem
        if tabs and tabs:IsVisible() and tabs:GetLeft() then left = tabs:GetLeft() - 18 end
        local right = hr
        local close = host.CloseButton or host.ClosePanelButton
        if close and close:IsVisible() and close:GetRight() then right = close:GetRight() + 8 end
        l = math.max(0, math.floor(left - hl))
        r = math.min(0, math.floor(right - hr))
        b = math.max(0, math.floor(pc:GetBottom() - 16 - hb))
        key = l .. "," .. r .. "," .. b
    end
    if e.fit == key then return end
    e.fit = key
    bd:ClearAllPoints()
    bd:SetPoint("TOPLEFT", host, "TOPLEFT", l, 0)
    bd:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", r, b)
end

local function skinSpellBook(sb, host)
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
        fitBook(host, sb)
        -- The selected category tab: Blizzard shows its active square only
        -- on that one, so its visibility says which, and ours rings it.
        local ts = sb.CategoryTabSystem
        if ts then
            for _, tab in ipairs({ ts:GetChildren() }) do
                local ex = extras[tab]
                if ex and ex.backdrop then
                    local act = tab.SquareBackgroundActive
                    local active = act and act:IsShown()
                    -- Every piece of the tab's own art but the icon, each
                    -- pass: Blizzard switches pieces on as the selection
                    -- moves. Our hover (the highlight layer) stays.
                    for _, r in ipairs({ tab:GetRegions() }) do
                        if r:GetObjectType() == "Texture" and r ~= tab.Icon and r ~= ex.hover
                            and r:GetDrawLayer() ~= "HIGHLIGHT" then
                            r:SetAlpha(0)
                        end
                    end
                    ns:SetBorderColor(ex.backdrop, active and "fel" or "border")
                end
            end
        end
    end)
    -- The talents tab hides the book, and with it this poll: put the
    -- panel back to the whole window then.
    poll:SetScript("OnHide", function() fitBook(host, sb) end)
end

-- Gear slots: the slot frame goes, the icon gets our corners, and the
-- quality the game drew as a coloured frame becomes a rounded ring in that
-- colour, read while the window is open.
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }

local function styleSlot(b)
    if done[b] then return end
    done[b] = true
    local name = b:GetName()
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local t = tex(b, get); if t then t:SetAlpha(0) end
    end
    fade(b.IconBorder)
    fade(_G[name .. "Frame"])
    fade(b.IconOverlay)
    local icon = b.icon or b.Icon or _G[name .. "IconTexture"]
    if icon then ns:CropIcon(icon) end
    backdrop(b, "Default", false, 0)
end

local function paintSlots()
    for _, s in ipairs(SLOTS) do
        local b = _G["Character" .. s .. "Slot"]
        local e = b and extras[b]
        if e and e.backdrop then
            -- Every piece of the slot's own art but the item icon, each
            -- pass: Blizzard redraws slot frames and quality borders as
            -- gear changes. The HIGHLIGHT layer (hover) stays.
            local icon = b.icon or b.Icon or _G[b:GetName() .. "IconTexture"]
            for _, r in ipairs({ b:GetRegions() }) do
                if r:GetObjectType() == "Texture" and r ~= icon and r:GetDrawLayer() ~= "HIGHLIGHT" then
                    r:SetAlpha(0)
                end
            end
            -- Forever draws the slot's frame on a BorderFrame child.
            if b.BorderFrame then b.BorderFrame:SetAlpha(0) end
            local q = GetInventoryItemQuality("player", b:GetID())
            if q and q >= 2 and C_Item and C_Item.GetItemQualityColor then
                local r, g, bl = C_Item.GetItemQualityColor(q)
                ns:SetBorderColor(e.backdrop, { r, g, bl })
            else
                ns:SetBorderColor(e.backdrop, "border")
            end
        end
    end
end

-- The stats panel is a scroll list, which the deeper strip leaves alone
-- on purpose, so its pieces are named here: the panel's own frame, and
-- each section header's bar (pooled entries with a Background and a Title).
local function styleStats()
    local sb = rawget(_G, "CharacterStatsPaneScrollBox")
    if not sb then return end
    fade(sb.Border); fade(sb.ClassBackground); fade(sb.Background)
    if sb.ScrollBox and sb.ScrollBox.Shadows then fadeRegions(sb.ScrollBox.Shadows) end
    local host = rawget(_G, "CharacterFrameRightPaneHost")
    if host then fadeRegions(host) end
    local target = sb.ScrollBox and sb.ScrollBox.ScrollTarget
    if not target then return end
    for _, row in ipairs({ target:GetChildren() }) do
        if row.Title and row.Background then
            row.Background:SetAlpha(0)
            local e = extras[row] or {}
            extras[row] = e
            if not e.rule then
                local rule = row:CreateTexture(nil, "ARTWORK")
                rule:SetHeight(ns.mult or 1)
                rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 2)
                rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 2)
                ns:Fill(rule, C.fel[1], C.fel[2], C.fel[3], 0.5)
                e.rule = rule
            end
            row.Title:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
        end
    end
end

PS.SPECIAL.CharacterFrame = function(frame)
    -- The race backdrop behind the model stays: Wick likes it. (It is
    -- CharacterModelFrameBackground* plus BackgroundOverlay on the model
    -- scene, should that ever change.)
    for _, s in ipairs(SLOTS) do
        local b = _G["Character" .. s .. "Slot"]
        if b then styleSlot(b) end
    end
    local poll = CreateFrame("Frame", nil, frame)
    local acc = 0.5
    poll:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.5 then return end
        acc = 0
        paintSlots()
        styleStats()
    end)
    return "generic"
end

-- Professions: the illustrations behind each profession stay (Wick likes
-- them); the frames around them go. Every skill bar is the same fel bar on
-- a glass track, like the rest of the UI. All of it is redone on every
-- pass: Blizzard redraws bars on each skill-up and swaps pages as tabs
-- change.

-- The rank bars are frames, not status bars: a textured Fill seen through
-- a sliding Mask, the Fill drawn wider than the bar and clipped. Pinning to
-- that art proved unreliable, so ours reads the skill from the bar's own
-- text ("Mining 88/150") and draws a plain fel bar on a glass track that
-- ends where the bar frame does.
local function rankIn(frame)
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if t and not (issecretvalue and issecretvalue(t)) then
                local cur, max = t:match("(%d+)%s*/%s*(%d+)")
                if cur then return tonumber(cur), tonumber(max), t, r end
            end
        end
    end
end

-- The label may sit on the bar, on a child of it, or beside it on the
-- panel; look in that order.
local function barText(bar)
    local cur, max, t, fs = rankIn(bar)
    if cur then return cur, max, t, fs end
    for _, child in ipairs({ bar:GetChildren() }) do
        cur, max, t, fs = rankIn(child)
        if cur then return cur, max, t, fs end
    end
    local parent = bar:GetParent()
    if parent then return rankIn(parent) end
end

local rankBars = setmetatable({}, { __mode = "k" })

-- A rank bar is drawn the way a unit frame is: a rounded card, a row of
-- text across its top (name left, numbers right, Wick font, soft shadow),
-- and a flat class-coloured fill inset below it. Blizzard's own label is
-- hidden and read for the numbers.
local PAD, ROW = 3, 15
local function flatRankBar(bar)
    rankBars[bar] = true
    local fill = bar.Fill
    local e = extras[bar] or {}
    extras[bar] = e
    for _, r in ipairs({ bar:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= e.bar and r:GetAlpha() > 0 then r:SetAlpha(0) end
    end
    for _, child in ipairs({ bar:GetChildren() }) do
        if child ~= e.track and child ~= e.text and child:GetObjectType() == "Frame" then fadeRegions(child) end
    end
    if not done[bar] then
        done[bar] = true
        local bd = backdrop(bar, "Default", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", -PAD, -PAD)
        e.track = bd
        local t = bar:CreateTexture(nil, "ARTWORK", nil, 3)
        t:SetTexture(ns.Media:Statusbar())
        t:SetPoint("TOPLEFT", bd, "TOPLEFT", PAD, -PAD - ROW)
        t:SetPoint("BOTTOMLEFT", bd, "BOTTOMLEFT", PAD, PAD)
        e.bar = t
        local tf = CreateFrame("Frame", nil, bar)
        tf:SetAllPoints(bd)
        tf:SetFrameLevel(bar:GetFrameLevel() + 3)
        e.text = tf
        e.name = ns:CreateText(tf, 12, "LEFT", "NONE")
        e.name:SetPoint("TOPLEFT", PAD + 3, -PAD - 1)
        e.name:SetShadowOffset(1, -1)
        e.value = ns:CreateText(tf, 12, "RIGHT", "NONE")
        e.value:SetPoint("TOPRIGHT", -PAD - 3, -PAD - 1)
        e.value:SetShadowOffset(1, -1)
    end
    local width
    local l, r = fill:GetLeft(), bar:GetRight()
    if l and r and r > l then
        width = r - l + PAD * 2
        -- The fill keeps Blizzard's height less a little, the text row
        -- rises above it.
        e.track:SetSize(width, math.min(fill:GetHeight() or 18, 12) + PAD * 2 + ROW)
    end
    width = width or e.track:GetWidth() or 0
    local cur, max, label, fs = barText(bar)
    if fs and fs:GetAlpha() > 0 then fs:SetAlpha(0) end
    local frac
    if cur and max and max > 0 then
        frac = math.min(1, cur / max)
        e.name:SetText((label:gsub("%s*%d+%s*/%s*%d+.*$", "")))
        e.value:SetText(("%d | %d"):format(cur, max))
    else
        -- No label means no skill line loaded (a ghost opening the window,
        -- say): an empty bar, not a guess from Blizzard's hidden art.
        e.name:SetText("")
        e.value:SetText("")
        frac = 0
    end
    e.bar:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
    local inner = width - PAD * 2
    if frac > 0 and inner > 0 then
        e.bar:SetWidth(inner * frac)
        e.bar:Show()
    else
        e.bar:Hide()
    end
end

local function flatBar(sb)
    local fill = sb:GetStatusBarTexture()
    for _, r in ipairs({ sb:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= fill then r:SetAlpha(0) end
    end
    for _, child in ipairs({ sb:GetChildren() }) do
        if child:GetObjectType() == "Frame" and not child.wuiBG then fadeRegions(child) end
    end
    local path = ns.Media:Statusbar()
    if fill and fill:GetTexture() ~= path then sb:SetStatusBarTexture(path) end
    sb:SetStatusBarColor(C.fel[1], C.fel[2], C.fel[3])
    if not done[sb] then
        done[sb] = true
        backdrop(sb, "Shadow", false, 1)
    end
end

local function flatIcon(b, icon)
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= icon and r:GetDrawLayer() ~= "HIGHLIGHT" then r:SetAlpha(0) end
    end
    if not done[b] then
        done[b] = true
        ns:CropIcon(icon)
        local bd = backdrop(b, "Default", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        bd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    end
end

-- Nothing of Blizzard's art is kept: every texture on a plain frame goes
-- (buttons, bars and boxes are the scanner's), except icons and our own.
-- Where a large piece of art sat (a profession's illustrated panel, the
-- recipe list, the recipe detail) a rounded card takes its place, so the
-- window reads as cards on glass, like the unit frames.
local cards = setmetatable({}, { __mode = "k" })
local ICON_KEYS = { Icon = true, icon = true, IconTexture = true }

local function isOwn(frame, r)
    local e = extras[frame]
    if e then for _, v in pairs(e) do if v == r then return true end end end
    return false
end

local function isIcon(frame, r)
    for k, v in pairs(frame) do
        if v == r and ICON_KEYS[k] then return true end
    end
    local n = r:GetName()
    return n and (n:find("Icon$") or n:find("IconTexture$")) and true or false
end

local function stripArt(frame, root)
    if frame.wuiBG or rankBars[frame] then return end
    local rw, rh = root:GetSize()
    for _, r in ipairs({ frame:GetRegions() }) do
        local n = r:GetName()
        if r:GetObjectType() == "Texture" and r:GetAlpha() > 0 and not isOwn(frame, r) and not isIcon(frame, r)
            and not (n and n:find("BlackFilter$")) then
            r:SetAlpha(0)
            local w, h = r:GetSize()
            if frame ~= root and w and h and w >= 120 and h >= 60 and not (w >= rw * 0.9 and h >= rh * 0.85) and not cards[r] then
                local card = CreateFrame("Frame", nil, frame)
                card:SetAllPoints(r)
                card:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
                ns:SetTemplate(card, "Default", { alpha = 0.9, shadow = false })
                cards[r] = card
            end
        end
    end
    for r, card in pairs(cards) do
        if r:GetParent() == frame then card:SetShown(r:IsShown()) end
    end
end

-- The quantity box: its white-edged frame (unnamed atlas pieces as well as
-- the named ones) goes for a black field, and the stepper arrows become
-- small grey tiles with our own marks.
-- Their own guard: the scanner has usually been through these already.
local spun = setmetatable({}, { __mode = "k" })
local function styleStepper(b, mark)
    if not b or spun[b] then return end
    spun[b] = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
    end
    backdrop(b, "Shadow", false, 1)
    local fs = ns:CreateText(b, 12, "CENTER", "NONE")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(mark)
    local h = b:CreateTexture(nil, "HIGHLIGHT")
    h:SetPoint("TOPLEFT", 2, -2)
    h:SetPoint("BOTTOMRIGHT", -2, 2)
    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.18)
end

local function styleNumberBox(eb)
    for _, r in ipairs({ eb:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetAlpha() > 0 and r:GetDrawLayer() == "BACKGROUND" then r:SetAlpha(0) end
    end
    if not spun[eb] then
        spun[eb] = true
        local bd = backdrop(eb, "Default", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", -6, 2)
        bd:SetPoint("BOTTOMRIGHT", 2, -2)
        ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
    end
end

local function styleSpinner(f)
    local eb = f:GetObjectType() == "EditBox" and f or f.EditBox or f
    if eb and eb.GetRegions then styleNumberBox(eb) end
    styleStepper(f.DecrementButton, "<")
    styleStepper(f.IncrementButton, ">")
end

local function walkProfessions(frame, depth, root)
    if depth > 8 or not frame.GetChildren then return end
    root = root or frame
    local fk = frame:GetObjectType()
    if fk == "Frame" or fk == "ScrollFrame" then stripArt(frame, root) end
    if textButtons[frame] then
        local bd = extras[frame] and extras[frame].backdrop
        if bd and bd.wuiTemplate ~= "Default" then ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false }) end
    end
    fade(frame.NineSlice)
    recolorText(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() then
            local kind = child:GetObjectType()
            local fill = child.Fill
            if kind == "StatusBar" then
                flatBar(child)
            elseif fill and fill.GetObjectType and fill:GetObjectType() == "Texture"
                and (child.Border or child.Background or child.Mask) then
                flatRankBar(child)
            elseif child.IncrementButton or child.DecrementButton or (kind == "EditBox" and (child.IncrementButton or frame.IncrementButton)) then
                styleSpinner(child)
            elseif kind == "Button" and child.ButtonText and child.CollapseButton then
                -- A recipe list category heading: its brown bar (one unnamed
                -- atlas, drawn again on the highlight layer) goes, a card
                -- takes it, with our hover; the collapse mark stays.
                for _, r in ipairs({ child:GetRegions() }) do
                    if r:GetObjectType() == "Texture" and r:GetAtlas() and r:GetAlpha() > 0 then r:SetAlpha(0) end
                end
                child.ButtonText:SetTextColor(C.text[1], C.text[2], C.text[3])
                if not done[child] then
                    done[child] = true
                    local h = child:CreateTexture(nil, "HIGHLIGHT")
                    h:SetPoint("TOPLEFT", 2, -2)
                    h:SetPoint("BOTTOMRIGHT", -2, 2)
                    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.12)
                end
            elseif kind == "Button" and child.Label and child.SelectedOverlay then
                -- A recipe row: the chosen one gets a fel wash in place of
                -- Blizzard's gold, which the row scanner faded.
                local sel = child.SelectedOverlay
                if not done[sel] or sel:GetAtlas() then
                    done[sel] = true
                    sel:ClearAllPoints()
                    sel:SetPoint("TOPLEFT", 2, -1)
                    sel:SetPoint("BOTTOMRIGHT", -2, 1)
                    ns:Fill(sel, C.fel[1], C.fel[2], C.fel[3], 1)
                end
                if math.abs(sel:GetAlpha() - 0.2) > 0.01 then sel:SetAlpha(0.2) end
                if child.HighlightOverlay then child.HighlightOverlay:SetAlpha(0) end
            elseif kind == "Button" and child.IconBorder and not (child.Icon or child.icon) and child:GetWidth() <= 64 then
                -- An item slot that shows its item as its normal texture: the
                -- slot art (unnamed, on the background layer) goes for a tile.
                for _, r in ipairs({ child:GetRegions() }) do
                    if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "BACKGROUND" and r:GetAlpha() > 0 then r:SetAlpha(0) end
                end
                if not done[child] then
                    done[child] = true
                    local bd = backdrop(child, "Default", false, 0)
                    ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
                end
            elseif (kind == "Button" or kind == "CheckButton") and child:GetWidth() <= 64 and child:GetHeight() <= 64 then
                local name = child.GetName and child:GetName()
                local icon = child.Icon or child.icon or child.IconTexture
                    or (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
                if icon and icon.GetObjectType and icon:GetObjectType() == "Texture" and not (icon.GetAtlas and icon:GetAtlas()) then
                    flatIcon(child, icon)
                end
            end
            walkProfessions(child, depth + 1, root)
        end
    end
end

-- The side tabs down the right edge are plain frames, not buttons, so the
-- scanner passes them by. Each becomes a grey tile the colour of the
-- window with a smaller icon in it. At rest the icon is greyed and dimmed,
-- so the column reads as part of the window; the open tab and the one
-- under the pointer show their colour, and the open one wears the ring.
local function styleSideTab(tab)
    fade(tab.Background); fade(tab.TabGlow); fade(tab.HighlightTexture)
    local e = extras[tab] or {}
    extras[tab] = e
    local icon = tab.Icon
    if not done[tab] then
        done[tab] = true
        local bd = backdrop(tab, "Shadow", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("LEFT", tab, "LEFT", 1, 0)
        bd:SetSize(38, 38)
        if icon then
            if tab.Mask and icon.RemoveMaskTexture then icon:RemoveMaskTexture(tab.Mask) end
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", bd, "CENTER", 0, 0)
            icon:SetSize(28, 28)
            ns:CropIcon(icon)
        end
        local ring = tab:CreateTexture(nil, "OVERLAY", nil, 2)
        ring:SetTexture(ns.Media.ring)
        if ring.SetTextureSliceMargins then ring:SetTextureSliceMargins(8, 8, 8, 8) end
        ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        ring:SetAllPoints(bd)
        e.ring = ring
    end
    local sel = tab.SelectedTexture
    if sel then sel:SetAlpha(0) end
    local open = sel and sel:IsShown() or false
    e.ring:SetShown(open)
    if icon then
        local awake = open or tab:IsMouseOver()
        icon:SetDesaturated(not awake)
        icon:SetAlpha(awake and 1 or 0.55)
    end
end

local function styleProfTabs(frame)
    local tab = frame.ProfessionsOverviewTab
    if tab then styleSideTab(tab) end
    for i = 1, 12 do
        tab = frame["Professions" .. i .. "Tab"]
        if not tab then break end
        styleSideTab(tab)
    end
end

-- The full skin, for windows done in the unit-frame style: nothing of
-- Blizzard's art is kept, the window is the grey panel and its cards are
-- black. The walk runs twice a second, and at once whenever the set of
-- open pages changes; `each` runs every frame for pieces that must follow
-- Blizzard without a lag.
local function fullSkin(frame, each)
    local poll = CreateFrame("Frame", nil, frame)
    local acc, last = 0.5, nil
    poll:SetScript("OnUpdate", function(_, e)
        local win = extras[frame] and extras[frame].backdrop
        if win and win.wuiTemplate ~= "Shadow" then ns:SetTemplate(win, "Shadow", { shadow = true }) end
        if each then each(frame) end
        local sig = ""
        for _, child in ipairs({ frame:GetChildren() }) do
            sig = sig .. (child:IsShown() and "1" or "0")
        end
        acc = acc + e
        if sig ~= last or acc >= 0.5 then
            last, acc = sig, 0
            walkProfessions(frame, 1)
        end
    end)
end
PS.fullSkin = fullSkin

-- A black card of our own over a region Blizzard leaves bare.
local function card(parent, key, a1, r1, a2, r2, x1, y1, x2, y2)
    local e = extras[parent] or {}
    extras[parent] = e
    if e[key] then return e[key] end
    local c = CreateFrame("Frame", nil, parent)
    c:SetPoint(a1, r1, a1, x1 or 0, y1 or 0)
    c:SetPoint(a2, r2, a2, x2 or 0, y2 or 0)
    c:SetFrameLevel(math.max(0, parent:GetFrameLevel() - 1))
    ns:SetTemplate(c, "Default", { alpha = 0.9, shadow = false })
    e[key] = c
    return c
end

PS.SPECIAL.ProfessionsFrame = function(frame)
    -- Bars already found follow their label every frame, so a tab or page
    -- change shows the right fill at once.
    fullSkin(frame, function(f)
        for bar in pairs(rankBars) do
            if bar:IsVisible() then flatRankBar(bar) end
        end
        styleProfTabs(f)
    end)
    return "generic"
end

-- Mail: the parchment behind the inbox and the stationery behind a letter
-- go; the list of mail and the letter become black cards, each row parted
-- from the next by a fine line, the page arrows small tiles.
PS.SPECIAL.MailFrame = function(frame)
    local inbox = frame.InboxFrame or _G.InboxFrame
    fullSkin(frame, function()
        local first, last = _G.MailItem1, _G.MailItem7
        if inbox and first and last then
            card(inbox, "wuiList", "TOPLEFT", first, "BOTTOMRIGHT", last, -4, 4, 4, -4)
            for i = 1, 7 do
                local row = _G["MailItem" .. i]
                local e = row and (extras[row] or {})
                if row and not e.line and i < 7 then
                    extras[row] = e
                    local l = row:CreateTexture(nil, "ARTWORK")
                    l:SetHeight(1)
                    l:SetPoint("BOTTOMLEFT", 2, 0)
                    l:SetPoint("BOTTOMRIGHT", -2, 0)
                    l:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.8)
                    e.line = l
                end
            end
        end
        styleStepper(inbox and inbox.PrevPageButton, "<")
        styleStepper(inbox and inbox.NextPageButton, ">")
        local money = _G.SendMailMoneyBg
        if money then card(money, "wuiMoney", "TOPLEFT", money, "BOTTOMRIGHT", money, 0, 0, 0, 0) end
    end)
    return "generic"
end

-- An opened letter: the same full skin. Its stationery (a large texture on
-- the scroll frame) is stripped by the walk and becomes a black card.
PS.SPECIAL.OpenMailFrame = function(frame)
    -- The letter is written in parchment ink; Blizzard sets it as each
    -- letter opens, so it is put back to our text colour every frame.
    fullSkin(frame, function()
        local body = _G.OpenMailBodyText
        if not body or not body:IsVisible() then return end
        local c = C.text
        if body:GetObjectType() == "SimpleHTML" then
            for _, tag in ipairs({ "P", "H1", "H2", "H3" }) do body:SetTextColor(tag, c[1], c[2], c[3]) end
        else
            body:SetTextColor(c[1], c[2], c[3])
        end
    end)
    return "generic"
end

-- The talents tab. The painting behind the trees (ClassBackground) stays,
-- as Wick wants; the brown frame around it (BackgroundBorder, with the gold
-- bar across the top and the edge along the bottom) goes, the tree headers
-- lose their scrollwork and ring, and the Primary and Secondary tabs go
-- flat. Headers are pooled, so this runs while the tab is open.
local function styleTalents(tf)
    fade(tf.BackgroundBorder)
    -- The window-wide backing the painting sits on; its top 70 px are the
    -- gold bar across the top. The painting itself is ClassBackground.
    fade(tf.Background)
    fade(tf.DividerHorizontalLeft)
    fade(tf.DividerHorizontalRight)
    -- The unspent-talents count: its ornate box becomes a glass tile.
    local cur = tf.ClassCurrencyDisplay
    if cur and cur.Border then
        cur.Border:SetAlpha(0)
        if not done[cur] then
            done[cur] = true
            local bd = backdrop(cur, "Default", false, 0)
            bd:ClearAllPoints()
            bd:SetPoint("TOPLEFT", cur.Border, "TOPLEFT", 60, -8)
            bd:SetPoint("BOTTOMRIGHT", cur.Border, "BOTTOMRIGHT", -4, 8)
        end
    end
    -- The search results dropdown under the search box.
    local sp = tf.SearchPreviewContainer
    if sp and sp:IsShown() then
        fadeRegions(sp)
        if not done[sp] then done[sp] = true; backdrop(sp, "Default", false, 0) end
    end
    local ts = tf.TabSystem
    if ts and type(ts.tabs) == "table" then
        for _, t in ipairs(ts.tabs) do styleTab(t) end
    end
    for _, child in ipairs({ tf:GetChildren() }) do
        if child.Name and child.Icon and child.Text and child:IsShown() then
            for _, r in ipairs({ child:GetRegions() }) do
                if r:GetObjectType() == "Texture" and r ~= child.Icon then r:SetAlpha(0) end
            end
            if not done[child] then
                done[child] = true
                ns:CropIcon(child.Icon)
                local bd = backdrop(child, "Default", false, 0)
                bd:ClearAllPoints()
                bd:SetPoint("TOPLEFT", child.Icon, "TOPLEFT", -2, 2)
                bd:SetPoint("BOTTOMRIGHT", child.Icon, "BOTTOMRIGHT", 2, -2)
            end
        end
    end
end

PS.SPECIAL.PlayerSpellsFrame = function(frame)
    local tf = frame.TalentsFrame
    if tf then
        local poll = CreateFrame("Frame", nil, tf)
        local acc = 0.5
        poll:SetScript("OnUpdate", function(_, e)
            acc = acc + e
            if acc < 0.5 then return end
            acc = 0
            styleTalents(tf)
        end)
    end
    skinSpellBook(frame.SpellBookFrame, frame)
    return "generic"
end

-- Holders the game keeps its windows in are the size of the screen and
-- have no look of their own. A panel behind one blacks out the screen.
local function screenSized(f)
    local w, h = f:GetSize()
    local W, H = UIParent:GetSize()
    return w and h and W and H and w >= W * 0.9 and h >= H * 0.9
end
PS.screenSized = screenSized

function PS:Skin(frame)
    if not frame or done[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    if screenSized(frame) then return end
    local name = frame:GetName()
    if name and excluded(name) then return end
    done[frame] = true
    local d = db()
    if name and PS.SPECIAL[name] then
        if PS.SPECIAL[name](frame) ~= "generic" then return end
    end

    fade(frame.NineSlice)
    fade(frame.Bg)
    fade(frame.BG)            -- popups keep their dialog art on a BG child
    fade(frame.Background)
    fade(frame.TopTileStreaks)
    fade(frame.Border)
    fade(frame.BorderFrame and frame.BorderFrame.NineSlice)
    if frame.PortraitContainer then fade(frame.PortraitContainer) end
    if frame.portrait then fade(frame.portrait) end
    if name and _G[name .. "Portrait"] then fade(_G[name .. "Portrait"]) end
    fadeRegions(frame)
    if name and PS.DEEP[name] then deepStrip(frame, 1, PS.DEEP[name]) end
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

local function allNames()
    local out = {}
    for _, n in ipairs(PS.WINDOWS) do out[#out + 1] = n end
    for _, n in ipairs(ns:List(db().include)) do out[#out + 1] = n end
    return out
end

function PS:SkinAll()
    if not db().enable then return end
    for _, n in ipairs(allNames()) do
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
-- /wui skin: the window under the pointer, found by walking up to the
-- frame that sits directly on UIParent, skinned and remembered.
function PS:SkinUnderMouse()
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    local f = foci and foci[1]
    -- Up to the window, but never into a screen-sized holder: stop at the
    -- last named frame below one.
    local pick
    while f and f ~= UIParent and f ~= WorldFrame do
        if screenSized(f) then break end
        if f.GetName and f:GetName() then pick = f end
        local p = f.GetParent and f:GetParent()
        if not p or p == UIParent then break end
        f = p
    end
    f = pick
    local name = f and f:GetName()
    if not f then
        ns.A:Print("point at a window first, then type /wui skin.")
        return
    end
    if not name then
        ns.A:Print("that window has no name, so it cannot be remembered. Send a screenshot to Wick.")
        return
    end
    local list = ns:List(db().include)
    local have = false
    for _, n in ipairs(list) do if n == name then have = true end end
    if not have then list[#list + 1] = name; db().include = table.concat(list, ",") end
    done[f] = nil
    self:Skin(f)
    self.lastAdded = name
    ns.A:Print(("skinned %s, and it will be skinned from now on. |cff4FC778/wui unskin|r takes it back off."):format(name))
end

-- /wui unskin [name]: take a window off the list, the last one added by
-- default. Our panel goes at once; the game's own art comes back on reload.
function PS:Unskin(name)
    local list = ns:List(db().include)
    name = (name and name ~= "") and name or self.lastAdded or list[#list]
    if not name then ns.A:Print("nothing has been added with /wui skin.") return end
    local kept, found = {}, false
    for _, n in ipairs(list) do if n == name then found = true else kept[#kept + 1] = n end end
    db().include = table.concat(kept, ",")
    local f = _G[name]
    local e = f and extras[f]
    if e and e.backdrop then e.backdrop:Hide() end
    self.lastAdded = nil
    if found then
        ns.A:Print(("%s taken off the list. Reload to bring back the game's own look for it."):format(name))
    else
        ns.A:Print(("%s was not on the list."):format(name))
    end
end

function PS:Initialize()
    -- Drop anything screen-sized that an earlier /wui skin let through.
    local kept = {}
    for _, n in ipairs(ns:List(db().include)) do
        local f = _G[n]
        if not (f and f.GetSize and screenSized(f)) then kept[#kept + 1] = n end
    end
    db().include = table.concat(kept, ",")
    self:SkinAll()
    -- Widgets a window makes after it first opens (list rows, dropdowns,
    -- scroll bars) are caught by a rescan of whichever windows are open.
    -- Hooking their OnShow instead would make Blizzard's own handler run
    -- tainted, which this client punishes.
    -- A window that has just opened is scanned the same frame it shows
    -- (OnUpdate runs after the event that opened it, before the frame is
    -- drawn), again on the next two frames as Blizzard fills it in, and
    -- then once a second like the rest.
    local tick = CreateFrame("Frame")
    local acc, names = 1, allNames()
    local shown, fresh = {}, {}
    tick:SetScript("OnUpdate", function(_, e)
        if not db().enable then return end
        acc = acc + e
        local full = acc >= 1
        if full then acc = 0; names = allNames() end
        for _, n in ipairs(names) do
            local f = _G[n]
            local on = f and f.IsShown and f:IsShown() or false
            if on and not shown[n] then
                fresh[n] = 3
                if not done[f] then pcall(PS.Skin, PS, f) end
            end
            shown[n] = on
            if on and done[f] and (full or fresh[n]) then scanButtons(f, 1) end
            if fresh[n] then fresh[n] = fresh[n] > 1 and fresh[n] - 1 or nil end
        end
    end)
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
    L:Note("Found a window still in the game's own look? Point at it and type |cff4FC778/wui skin|r. It is skinned on the spot and every time after.")
    L:Input("Skinned with /wui skin", "include", { width = 520, span = 2,
        tooltip = "Windows added with /wui skin. Remove a name to stop skinning it; takes effect after a reload." })
    L:Input("Leave these alone", "exclude", { width = 520, span = 2,
        tooltip = "Frame names separated by commas, for example  WorldMapFrame, AuctionHouseFrame. /fstack in game shows a frame's name. Takes effect after a reload." })
end, { parent = "skins", onChange = function() PS:Update() end, order = 96 })
