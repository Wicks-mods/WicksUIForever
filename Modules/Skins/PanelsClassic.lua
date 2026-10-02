-- Wick's UI
-- Modules/Skins/PanelsClassic.lua: the windows of the Classic kind.
--
-- TBC Classic Anniversary draws most of its windows the old way: a 384
-- by 512 frame with four quarters of painted art on it, a round portrait
-- in the corner, the title written on the art, a row of tabs hanging
-- under it, and clear padding round the lot. None of the portrait
-- template's parts (NineSlice, Inset, TitleContainer) are there for the
-- pass in Panels.lua to undress, and a panel cut to the frame's rect
-- would stand proud of the art. This file knows those shapes: where the
-- art sits inside each window, which text is its title, and the old
-- widget templates whose pieces are named rather than keyed (tabs, scroll
-- bars, text boxes, spell and item slots, list rows).
--
-- The same rule as Panels.lua: method calls on their frames and frames
-- of our own, their art faded by alpha, nothing written into their
-- tables, no script replaced. It loads on every client and does nothing
-- on one whose windows are the newer kind: Panels.lua hands a window
-- over only when the client's windows are of this kind
-- (Client.classicWindows), and asks it to look over the old widgets
-- inside the portrait-template windows such a client still has.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local PS = ns.PanelSkins
local H = PS.H

local PSC = {}
PS.Classic = PSC

-- ============================================================
-- The windows
-- ============================================================
-- Where the painted art sits inside the frame: offsets of our panel's
-- top left and bottom right corners from the frame's own. The 384 by
-- 512 windows share one set (measured on the character window, and the
-- same on every window drawn from the same quarters); the rest are
-- measured on their own art.
local BOOK = { 11, -12, -32, 76 }
local FULL = { 0, 0, 0, 0 }

-- title: the font string that names the window (default <name>TitleText).
-- portrait: the round picture in the corner, where it is not <name>Portrait.
-- fields: boxes drawn in border art (a count, a key list) that take a field of ours.
-- depth: how far down the plain frames' art is stripped (default 4).
-- slots: the character sheet's gear slots, with their quality colours.
-- page: a page that fills another listed window; no panel of its own.
-- special: the handler Panels.lua keeps for the same frame applies here
--   too (the group finder is the same Blizzard addon on both clients).
PSC.WINDOWS = {
    CharacterFrame      = { inset = BOOK, title = "CharacterNameText", slots = true },
    SpellBookFrame      = { inset = BOOK, title = "SpellBookTitleText" },
    PlayerTalentFrame   = { inset = BOOK, title = "PlayerTalentFrameTitleText" },
    QuestLogFrame       = { inset = { 8, -10, -28, 42 }, title = "QuestLogTitleText", fields = { "QuestLogCount" } },
    TaxiFrame           = { inset = BOOK, title = "TaxiMerchant", portrait = "TaxiPortrait" },
    ClassTrainerFrame   = { inset = BOOK, title = "ClassTrainerNameText" },
    TradeSkillFrame     = { inset = BOOK, title = "TradeSkillFrameTitleText" },
    CraftFrame          = { inset = BOOK, title = "CraftFrameTitleText" },
    BankFrame           = { inset = { 12, 0, 10, 80 }, title = "BankFrameTitleText", portrait = "BankPortraitTexture" },
    PetStableFrame      = { inset = { 10, -11, -32, 71 }, title = "PetStableTitleLabel" },
    BattlefieldFrame    = { inset = BOOK },
    ArenaFrame          = { inset = BOOK },
    ArenaRegistrarFrame = { inset = BOOK, title = "ArenaRegistrarFrameNpcNameText" },
    PVPBannerFrame      = { inset = BOOK, title = "PVPBannerFrameNameText" },
    LFGParentFrame      = { inset = { 11, -12, -30, 72 }, special = true },
    LFGListingFrame     = { page = true, special = true },
    LFGBrowseFrame      = { page = true, special = true },
    AuctionFrame        = { inset = { 10, 0, 0, 0 }, portrait = "AuctionPortraitTexture" },
    GuildBankFrame      = { inset = { 4, 0, 0, 0 } },
    WorldStateScoreFrame = { inset = { 0, -5, -107, 25 } },
    KeyBindingFrame     = { inset = FULL, fields = { "header", "categoryList", "bindingsContainer" }, depth = 2 },
    ChatConfigFrame     = { inset = FULL, depth = 0 },
    ReadyCheckListenerFrame = { inset = FULL, portrait = "ReadyCheckPortrait" },
    StackSplitFrame     = { inset = FULL },
}
for i = 1, 13 do
    PSC.WINDOWS["ContainerFrame" .. i] = { inset = { 9, -4, -4, 2 }, title = "ContainerFrame" .. i .. "Name" }
end

-- Portrait-template windows whose pages carry old art of their own
-- (quads: frames whose textures go, and are kept off the full skin's
-- cards).
PSC.ATTACH = {
    InspectFrame = { quads = { "InspectTalentFrame", "InspectPVPFrame", "InspectPaperDollFrame", "InspectModelFrame" } },
}

-- Windows the generic list does not name, so the ticker in Panels.lua
-- looks for them on this client.
if ns.Core.Client.classicWindows then
    local listed = {}
    for _, n in ipairs(PS.WINDOWS) do listed[n] = true end
    local add = {}
    for n in pairs(PSC.WINDOWS) do
        if not listed[n] then add[#add + 1] = n end
    end
    table.sort(add)
    for _, n in ipairs(add) do PS.WINDOWS[#PS.WINDOWS + 1] = n end
end

-- ============================================================
-- What is content, not art
-- ============================================================
-- Frames whose textures mean something: resistance icons, a pet's mood,
-- the flight map's routes, the talent tree's branches, the scoreboard's
-- faction tints. Their textures stay, and so do their buttons (the flight
-- map's nodes), which the scanner would otherwise grey as arrows.
local KEEP = { TaxiRouteMap = true, PetPaperDollPetInfo = true, PetStablePetInfo = true, QuestLogTrack = true,
    PlayerTalentFrameScrollChildFrame = true, InspectTalentFrameScrollChildFrame = true }
local KEEP_PATTERNS = { "^MagicResFrame%d+$", "^PetMagicResFrame%d+$", "^InspectMagicResFrame%d+$", "^WorldStateScoreButton%d+$" }
local KEEP_TEX = { TaxiMap = true }

local function keepFrame(f)
    local n = f.GetName and f:GetName()
    if not n then return false end
    if KEEP[n] then return true end
    for _, p in ipairs(KEEP_PATTERNS) do
        if n:find(p) then return true end
    end
    return false
end

-- Kinds that are content and keep their textures; the scanners have
-- handlers of their own for those that take any.
local CONTENT = { Button = true, CheckButton = true, ItemButton = true, EditBox = true, Slider = true, StatusBar = true,
    ScrollFrame = true, ModelScene = true, PlayerModel = true, DressUpModel = true, Model = true,
    Cooldown = true, SimpleHTML = true, MessageFrame = true, ScrollingMessageFrame = true }

-- A spell or item picture, as against a piece of the interface's art: a
-- file id, or a path under the icons folder.
local function iconLike(tex)
    if type(tex) == "number" then return true end
    return type(tex) == "string" and tex:lower():find("interface\\icons", 1, true) ~= nil
end

-- A frame's own textures faded, all but the ones that are content (an
-- icon, a map) and the ones we drew.
local function fadeArt(f)
    if not f or not f.GetRegions then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetAlpha() > 0 and not H.isOwn(f, r) and not H.isIcon(f, r) then
            local n = r:GetName()
            if not (n and KEEP_TEX[n]) then r:SetAlpha(0) end
        end
    end
end

-- The bar Blizzard moves under the chosen row of an old list (the quest
-- log's, a profession's, the trainer's) is a frame of its own with one
-- texture: a wash in the accent.
local function tintSelection(f)
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" and not H.done[r] then
            H.done[r] = true
            ns:Fill(r, C.fel[1], C.fel[2], C.fel[3], 0.25)
        end
    end
end

-- Art on the plain frames inside a window (a page's quarters, a stat
-- block's backing, a sort tab, a rule across the page), down to the given
-- depth. Content kinds and the frames listed above are left alone.
local function stripArt(frame, depth, limit)
    if depth > limit or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local kind = child:GetObjectType()
        if not CONTENT[kind] and not child.wuiBG and not child.ScrollTarget and not PS.notOurs(child) and not keepFrame(child) then
            local n = child.GetName and child:GetName()
            if n and n:find("HighlightFrame$") then
                tintSelection(child)
            else
                fadeArt(child)
                H.fade(child.NineSlice)
            end
            stripArt(child, depth + 1, limit)
        end
    end
end

-- ============================================================
-- The old widgets
-- ============================================================
local tiled = setmetatable({}, { __mode = "k" })
local items = setmetatable({}, { __mode = "k" })
local ctabs = setmetatable({}, { __mode = "k" })
local rows = setmetatable({}, { __mode = "k" })
local bars = setmetatable({}, { __mode = "k" })
local marked = setmetatable({}, { __mode = "k" })

local function hasText(b)
    local fs = b.Text or (b.GetFontString and b:GetFontString())
    local t = fs and fs.GetText and fs:GetText()
    return t ~= nil and t ~= ""
end

local function iconOf(b, n)
    local icon = b.icon or b.Icon or b.IconTexture or (n and rawget(_G, n .. "IconTexture"))
    if icon and icon.GetObjectType and icon:GetObjectType() == "Texture" then return icon end
end

-- An icon on a tile: a spell in the book, a talent, a stabled pet, a
-- profession's side tab, an item in an old slot. Every piece of the
-- button's own art but the icon goes, each pass (Blizzard redraws slot
-- art as its contents change); the tile, the ring on a chosen one and the
-- hover are made once. hug: the tile fits the icon rather than the button
-- (a reward row whose icon sits at one end).
local function tileIcon(b, icon, hug)
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    local ct = b.GetCheckedTexture and b:GetCheckedTexture()
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= icon and r ~= ct and r:GetDrawLayer() ~= "HIGHLIGHT"
            and r:GetAlpha() > 0 and not H.isOwn(b, r) then
            r:SetAlpha(0)
        end
    end
    for _, get in ipairs({ "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t and t ~= icon and t:GetAlpha() > 0 then t:SetAlpha(0) end
    end
    if nt and nt ~= icon and nt:GetAlpha() > 0 then nt:SetAlpha(0) end
    if tiled[b] then return end
    tiled[b] = true
    H.done[b] = true
    if icon then ns:CropIcon(icon) end
    local bd = H.backdrop(b, "Default", false, 0)
    ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
    if hug and icon then
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        bd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    end
    if ct then
        ns:SetRing(ct, icon or b)
        ct:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ct, "fel", "vertex", 1)
        ct:SetAllPoints(icon or b)
    end
    local e = H.extras[b]
    if not e.hover then
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetAllPoints(icon or b)
        ns:Fill(h, 1, 1, 1, 0.12)
        e.hover = h
    end
end

-- Tabs built from named pieces (the character window's kind, and the
-- help frame's tab template): the pieces go, a tile of ours takes their
-- place, and the tab joins the ones Panels.lua spaces. Blizzard disables
-- the chosen tab, which is how the chosen one is told apart each pass;
-- it also drops the chosen tab's text and lifts the others', which on a
-- flat tile reads as misaligned, so the text is held centred.
local TAB_PIECES = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftHighlight", "MiddleHighlight", "RightHighlight", "HighlightTexture" }
local function tabText(tab)
    return tab.Text or (tab.GetFontString and tab:GetFontString())
end
local function markTab(tab, host)
    local e = H.extras[tab]
    local bd = e and e.backdrop
    local selected = (tab.IsEnabled and not tab:IsEnabled()) and true or false
    if bd then ns:SetBorderColor(bd, selected and "fel" or "border") end
    local fs = tabText(tab)
    if not fs then return end
    local c = selected and C.fel or C.text
    fs:SetTextColor(c[1], c[2], c[3])
    if InCombatLockdown() then return end
    host = host or tab
    local p, rel, _, x, y = fs:GetPoint(1)
    if p ~= "CENTER" or rel ~= host or math.abs(x or 0) > 0.1 or math.abs(y or 0) > 0.1 then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", host, "CENTER", 0, 0)
    end
end
local function classicTab(tab)
    if not ctabs[tab] then
        ctabs[tab] = true
        H.done[tab] = true
        PS.skinnedTabs[tab] = true
        local n = tab:GetName()
        for _, k in ipairs(TAB_PIECES) do
            H.fade(tab[k])
            if n then H.fade(rawget(_G, n .. k)) end
        end
        local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
        if hl then hl:SetAlpha(0) end
        local bd = H.backdrop(tab, "Shadow", false, 3)
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", 6, -3)
        bd:SetPoint("BOTTOMRIGHT", -6, 3)
        H.styleText(tabText(tab))
    end
    markTab(tab)
end

-- The spellbook's own tabs along its bottom: one wide texture each (at
-- rest, chosen as the disabled state, a highlight), with the visible tab
-- in the middle of a 128 by 64 button.
local function bookTab(tab)
    if not ctabs[tab] then
        ctabs[tab] = true
        H.done[tab] = true
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
            local t = tab[get] and tab[get](tab)
            if t then t:SetAlpha(0) end
        end
        fadeArt(tab)
        local bd = H.backdrop(tab, "Shadow", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", 14, -14)
        bd:SetPoint("BOTTOMRIGHT", -14, 22)
        H.styleText(tabText(tab))
    end
    markTab(tab, H.extras[tab] and H.extras[tab].backdrop)
end

-- The old scroll bar (a slider with an arrow button at each end and a
-- knob) takes the look every other scroll bar here has: a slim track in
-- the border colour and a thumb in the accent, no arrows drawn (they
-- stay clickable).
local function scrollBar(sb)
    if bars[sb] then return end
    bars[sb] = true
    H.done[sb] = true
    local n = sb:GetName()
    local up = sb.ScrollUpButton or (n and rawget(_G, n .. "ScrollUpButton"))
    local down = sb.ScrollDownButton or (n and rawget(_G, n .. "ScrollDownButton"))
    local thumb = sb.GetThumbTexture and sb:GetThumbTexture()
    for _, r in ipairs({ sb:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= thumb then r:SetAlpha(0) end
    end
    if up and up.SetAlpha then up:SetAlpha(0); H.done[up] = true end
    if down and down.SetAlpha then down:SetAlpha(0); H.done[down] = true end
    if thumb then
        ns:Fill(thumb, C.fel[1], C.fel[2], C.fel[3], 0.8)
        thumb:SetSize(6, 24)
    end
    local e = H.extras[sb] or {}
    H.extras[sb] = e
    if not e.track then
        local line = sb:CreateTexture(nil, "BACKGROUND")
        line:SetPoint("TOP", 0, 0)
        line:SetPoint("BOTTOM", 0, 0)
        line:SetWidth(4)
        ns:Fill(line, C.border[1], C.border[2], C.border[3], 0.6)
        e.track = line
    end
end

-- An old scroll frame: the gold scroll-bar backing drawn on it goes, its
-- bar is restyled, and in a window of ours a list or a page of text sits
-- on a card.
local function scrollFrame(sf, n, own)
    fadeArt(sf)
    local sb = sf.ScrollBar or (n and rawget(_G, n .. "ScrollBar"))
    if sb and sb.GetObjectType and sb:GetObjectType() == "Slider" then scrollBar(sb) end
    if own then
        local w, h = sf:GetSize()
        if (w or 0) >= 150 and (h or 0) >= 80 then
            H.card(sf, "wuiCard", "TOPLEFT", sf, "BOTTOMRIGHT", sf, -3, 3, 3, -3)
        end
    end
end

-- A row of an old list (a quest, a recipe, a skill, a faction, a who
-- result): the plate behind it goes, its highlight becomes an accent
-- wash, and the plus or minus on a heading (the row's normal texture,
-- swapped by Blizzard as sections open and close) is greyed each pass.
-- all: every piece of art goes, not only the plate (a collapse-all button
-- wearing a sort tab's art).
local function row(b, all)
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if not rows[b] then
        rows[b] = true
        H.done[b] = true
        for _, r in ipairs({ b:GetRegions() }) do
            if r:GetObjectType() == "Texture" and r ~= nt and r:GetDrawLayer() ~= "HIGHLIGHT" and not H.isIcon(b, r) then
                local rn = r:GetName()
                if all or (r:GetDrawLayer() == "BACKGROUND" and ((r:GetWidth() or 0) > 20 or (rn and rn:find("Lines$")))) then
                    r:SetAlpha(0)
                end
            end
        end
        local hl = b.GetHighlightTexture and b:GetHighlightTexture()
        if hl then
            hl:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 0.5)
            Chrome:Register(hl, "fel", "vertex", 0.5)
        end
    end
    local file = nt and nt:GetTexture()
    if nt and file and file ~= "" and (nt:GetWidth() or 0) <= 20 then
        nt:SetDesaturated(true)
        nt:SetVertexColor(C.text[1], C.text[2], C.text[3])
    end
end

-- The gold frame round an old status bar (a skill's, a profession's) is
-- a button of its own with the art as its normal texture.
local function barBorder(b)
    if H.done[b] then return end
    H.done[b] = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    fadeArt(b)
end

-- Stretch buttons built from nine silver pieces (invite, decline, a key
-- binding), and buttons whose three pieces are named rather than keyed
-- (column headers, the auction house's sort tabs): their pieces go, and
-- they become the buttons every window has.
local NINE = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight",
    "BottomMiddle", "MiddleMiddle" }
local function nineButton(b)
    if H.done[b] then return end
    for _, k in ipairs(NINE) do H.fade(b[k]) end
    H.styleButton(b)
end
local function namedButton(b, n)
    if H.done[b] then return end
    for _, k in ipairs({ "Left", "Middle", "Right" }) do H.fade(rawget(_G, n .. k)) end
    H.styleButton(b)
end

-- A box drawn in border art (the quest count, a key list): a field.
local function field(f)
    if not f or H.done[f] then return end
    H.done[f] = true
    fadeArt(f)
    H.backdrop(f, "Shadow", false, 0)
end

-- The close button of a window that gives it no name: a square button in
-- the top right corner with no word on it.
local function closeChild(frame)
    for _, c in ipairs({ frame:GetChildren() }) do
        if c:GetObjectType() == "Button" then
            local w, h = c:GetSize()
            local p = c:GetPoint(1)
            if w and h and w >= 28 and w <= 36 and h >= 28 and h <= 36 and p == "TOPRIGHT" and not hasText(c) then return c end
        end
    end
end

-- Buttons the scanner must leave as they are: the flight map's nodes.
local function protect(frame)
    if not frame.GetChildren then return end
    for _, c in ipairs({ frame:GetChildren() }) do
        local k = c:GetObjectType()
        if k == "Button" or k == "CheckButton" then H.done[c] = true end
    end
end

-- ============================================================
-- The walk
-- ============================================================
local function button(b, kind, n, w, h)
    local parent = b:GetParent()
    local icon = iconOf(b, n)
    local plate = b.NameFrame or (n and rawget(_G, n .. "NameFrame"))
    if n and n:find("CloseButton$") and w <= 36 and h <= 36 and not hasText(b) then
        H.styleClose(b)
    elseif b.LeftDisabled or (n and rawget(_G, n .. "LeftDisabled")) then
        classicTab(b)
    elseif n and n:find("^SpellBookFrameTabButton%d+$") then
        bookTab(b)
    elseif n and (n:find("RotateLeftButton$") or n:find("RotateRightButton$")) then
        if not ns.glyphs[b] then
            H.done[b] = true
            ns:Glyph(b, n:find("Left") and "left" or "right", { size = 12 })
        end
    elseif n and n:find("CollapseAllButton$") then
        row(b, true)
    elseif n and n:find("Border$") and parent and parent.GetObjectType and parent:GetObjectType() == "StatusBar" then
        barBorder(b)
    elseif icon and n and rawget(_G, n .. "RankBorder") then
        -- A talent: its slot and rank frame go; the rank stays, in our font.
        if tiled[b] or not H.done[b] then
            tileIcon(b, icon, false)
            if not marked[b] then
                marked[b] = true
                H.styleText(rawget(_G, n .. "Rank"), 12)
            end
        end
    elseif b.IconBorder and (b.icon or b.Icon) and w <= 64 and h <= 64 then
        -- An item slot (a bag's, the bank's, a vendor's): the look items have
        -- in every window.
        if items[b] or not H.done[b] then
            items[b] = true
            H.styleItemButton(b)
        end
    elseif icon and (plate or (w <= 64 and h <= 64)) then
        if tiled[b] or not H.done[b] then
            tileIcon(b, icon, plate ~= nil or w > 64 or h > 64)
            if plate then H.fade(plate) end
            -- A spell in the book: a card behind its icon and name.
            if n and n:find("^SpellButton%d+$") then
                H.card(b, "wuiRow", "TOPLEFT", b, "BOTTOMRIGHT", b, -6, 6, 112, -6)
            end
        end
    else
        local nt = b.GetNormalTexture and b:GetNormalTexture()
        if nt and w <= 40 and h <= 40 and not hasText(b) and iconLike(nt:GetTexture()) then
            -- A picture drawn as the button's own face (a profession's side
            -- tab, the skill an old trainer shows): the tile round it.
            if tiled[b] or not H.done[b] then tileIcon(b, nt, false) end
        elseif b.TopLeft and b.BottomRight and b.MiddleMiddle then
            nineButton(b)
        elseif n and rawget(_G, n .. "Left") and rawget(_G, n .. "Right") and not b.Left then
            if h >= 28 and hasText(b) then classicTab(b) else namedButton(b, n) end
        elseif kind == "Button" and w >= 150 and h <= 40 and not (b.Left or b.Center or b.Arrow or b.Track) then
            row(b)
        end
    end
end

local function scan(frame, depth, own, inScroll)
    if depth > 8 or not frame.GetChildren or PS.notOurs(frame) then return end
    -- Text inside a scroll frame (a quest's story, a talent's words) is
    -- inked for parchment, and the scanner in Panels.lua never enters one.
    if inScroll then H.recolorText(frame) end
    for _, child in ipairs({ frame:GetChildren() }) do
        if not child.wuiBG and not PS.notOurs(child) then
            local kind = child:GetObjectType()
            local n = child.GetName and child:GetName()
            local w, h = child:GetSize()
            w, h = w or 0, h or 0
            local keep = keepFrame(child)
            if keep then
                protect(child)
            elseif kind == "ScrollFrame" then
                scrollFrame(child, n, own)
            elseif kind == "Slider" and (child.ScrollUpButton or (n and rawget(_G, n .. "ScrollUpButton"))) then
                scrollBar(child)
            elseif kind == "EditBox" then
                if child.NineSlice or child.Left or (n and rawget(_G, n .. "Left")) then H.styleEditBox(child) end
            elseif kind == "Frame" and child.Left and child.Middle and child.Right and child.Button and child.Text then
                PS.styleOldDropdown(child)
            elseif (kind == "PlayerModel" or kind == "DressUpModel" or kind == "Model") and own and w >= 100 then
                -- A model shows the window through itself: a card behind it.
                H.card(child, "wuiCard", "TOPLEFT", child, "BOTTOMRIGHT", child, -2, 2, 2, -2)
            elseif (kind == "Button" or kind == "CheckButton" or kind == "ItemButton") and w >= 1 and h >= 1 then
                button(child, kind, n, w, h)
            end
            if not keep then scan(child, depth + 1, own, inScroll or kind == "ScrollFrame") end
        end
    end
end

-- ============================================================
-- A window
-- ============================================================
local polls = setmetatable({}, { __mode = "k" })

function PSC:Pass(frame, spec)
    if spec and spec.quads then
        for _, n in ipairs(spec.quads) do
            local f = rawget(_G, n)
            if f then
                fadeArt(f)
                for _, r in ipairs({ f:GetRegions() }) do
                    if r:GetObjectType() == "Texture" then H.noCard[r] = true end
                end
            end
        end
    end
    local own = spec and spec.own or false
    if own then stripArt(frame, 1, spec.depth or 4) end
    scan(frame, 1, own, false)
    if own and spec.slots then H.paintSlots() end
end

-- Watched while it shows: the old widgets are looked over again as the
-- window's pages change (a tab chosen, a list scrolled) and twice a
-- second besides, the way Panels.lua watches the newer windows. Called
-- for every skinned window on this client; a window of the old kind
-- brings its own description, a portrait-template window takes what is
-- listed for it above, if anything.
function PSC:Attach(frame, spec)
    spec = spec or PSC.ATTACH[frame:GetName() or ""]
    if polls[frame] then return end
    local poll = CreateFrame("Frame", nil, frame)
    polls[frame] = poll
    local acc, last = 0, nil
    poll:SetScript("OnUpdate", function(_, e)
        if not PS:db().enable then return end
        acc = acc + e
        local parts = {}
        for _, c in ipairs({ frame:GetChildren() }) do parts[#parts + 1] = c:IsShown() and "1" or "0" end
        local sig = table.concat(parts)
        if sig ~= last or acc >= 0.5 then
            last, acc = sig, 0
            PSC:Pass(frame, spec)
        end
    end)
    self:Pass(frame, spec)
end

local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }

function PSC:Skin(frame, spec)
    local name = frame:GetName()
    local d = PS:db()
    spec.own = true
    -- The quarters of art and the portrait in the corner.
    fadeArt(frame)
    H.fade(spec.portrait and rawget(_G, spec.portrait) or (name and rawget(_G, name .. "Portrait")) or frame.Portrait or frame.portrait)
    stripArt(frame, 1, spec.depth or 4)
    if not spec.page then
        local i = spec.inset or BOOK
        local bd = H.backdrop(frame, "Default", d.brackets, 0)
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", frame, "TOPLEFT", i[1], i[2])
        bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", i[3], i[4])
        H.styleText(spec.title and rawget(_G, spec.title) or (name and rawget(_G, name .. "TitleText")), 14, C.fel)
        H.styleClose(frame.CloseButton or (name and rawget(_G, name .. "CloseButton")) or closeChild(frame))
    end
    for _, k in ipairs(spec.fields or {}) do field(frame[k] or rawget(_G, k)) end
    if spec.slots then
        for _, s in ipairs(SLOTS) do
            local b = rawget(_G, "Character" .. s .. "Slot")
            if b then H.styleSlot(b) end
        end
    end
    if spec.special and name and PS.SPECIAL[name] then PS.SPECIAL[name](frame) end
    self:Attach(frame, spec)
    H.scanButtons(frame, 1)
end

-- Panels.lua asks before it skins a window without the portrait
-- template's parts: true when this file knows the window and has taken it.
function PSC:Claim(frame, name)
    local spec = name and self.WINDOWS[name]
    if not spec then return false end
    self:Skin(frame, spec)
    return true
end
