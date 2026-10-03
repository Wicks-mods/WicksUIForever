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
    mapWindowed = true,     -- the map opens at its windowed size, not fullscreen
    mapScale = 1,           -- the windowed map's size, set with its corner grip
    mapPos = false,         -- where the windowed map was dragged: { left, top } on screen
    moveWindows = true,     -- drag a window by its title bar
    bagsClearMeter = true,  -- the game's bags sit above the damage meter, not over it
    qualityGlow = true,     -- a soft halo in the item's quality colour round each gear slot
    windowPos = {},         -- window name -> { left, top } on screen, where it was dragged
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
    "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
    "ContainerFrame5", "ContainerFrame6", "CompactRaidFrameManager", "PetStableFrame",
    "ClickBindingFrame", "LegacySystemFrame", "StackSplitFrame",
}

local done = setmetatable({}, { __mode = "k" })
local extras = setmetatable({}, { __mode = "k" })
-- What we added to a frame, read by the offline harness.
function PS.extrasOf(f) return extras[f] end

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

-- ============================================================
-- Pieces
-- ============================================================
local function styleText(fs, size, color)
    if not fs or not fs.SetFont then return end
    local _, cur = fs:GetFont()
    fs:SetFont(ns.Media:Font(), size or cur or 12, "")
    fs:SetShadowOffset(1, -1)
    if color then
        fs:SetTextColor(color[1], color[2], color[3])
        -- A palette colour (a window title in the accent) follows the
        -- theme; it is set once, so without this a theme change left it
        -- in the old accent.
        for _, c in pairs(C) do
            if c == color then Chrome:Register(fs, color, "text"); break end
        end
    end
end

local textButtons = setmetatable({}, { __mode = "k" })

-- A button the game has switched off (Complete Quest before the items are
-- in your bags, Add Binding while one waits) reads as off: its pill
-- dimmed and its text faded. Blizzard's disabled art goes with the rest,
-- and the grey of its disabled text alone read like the buttons beside it.
-- Painted when styled, then whenever ns:Follow sees Blizzard switch it.
local function paintEnabled(b)
    local e = extras[b]
    local on = not (b.IsEnabled and not b:IsEnabled())
    if e and e.backdrop then e.backdrop:SetAlpha(on and 1 or 0.4) end
    local fs = b.Text or (b.GetFontString and b:GetFontString())
    if fs and fs.SetAlpha then fs:SetAlpha(on and 1 or 0.6) end
end

local function styleButton(b)
    if not b or done[b] or not db().buttons then return end
    done[b] = true
    textButtons[b] = true
    -- The newer three-slice buttons use Left, Center and Right and swap
    -- their atlases on press, the old ones Left, Middle and Right. Their
    -- atlas swaps leave alpha alone, so fading them holds.
    -- Named pieces only: a button's icon is a texture too, and must stay.
    for _, k in ipairs({ "Left", "Middle", "Center", "Right", "LeftSeparator", "RightSeparator", "Background",
        "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do fade(b[k]) end
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
    paintEnabled(b)
    ns:Follow(b, ns.EnabledOf, paintEnabled)
end
PS.styleButton = styleButton

-- The small X in the corner, redrawn as ours.
-- Its own guard: the scanner may already have greyed it as an arrow.
local closed = setmetatable({}, { __mode = "k" })
local function styleClose(b)
    if not b or closed[b] then return end
    closed[b] = true
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
    ns:Glyph(b, "close", { tile = false, size = 12 })
end

-- Bottom tabs: Blizzard drops a chosen tab's text 3 px and lifts the
-- others' 2 px, which on our flat tiles reads as misaligned, and spaces the
-- tabs for its own wide art. Each tab we skin has its text held centred
-- and sits a few pixels from the one before it, checked every frame (the
-- text moves as tabs are chosen).
local skinnedTabs = setmetatable({}, { __mode = "k" })
local TAB_GAP = -8   -- tiles are inset 6 each side; this leaves a 4 px gap
local function holdTab(tab)
    local t = tab.Text
    if t then
        local p, rel, rp, x, y = t:GetPoint(1)
        if p ~= "CENTER" or rel ~= tab or math.abs(x or 0) > 0.1 or math.abs(y or 0) > 0.1 then
            t:ClearAllPoints()
            t:SetPoint("CENTER", tab, "CENTER", 0, 0)
        end
    end
    -- The next tab along, anchored to this one by Blizzard: closer.
    local p, rel, rp, x, y = tab:GetPoint(1)
    if rel and skinnedTabs[rel] and (p == "TOPLEFT" or p == "LEFT") and (rp == "TOPRIGHT" or rp == "RIGHT")
        and math.abs((x or 0) - TAB_GAP) > 0.5 and not InCombatLockdown() then
        tab:ClearAllPoints()
        tab:SetPoint(p, rel, rp, TAB_GAP, y or 0)
    end
end
PS.holdTab = holdTab
PS.skinnedTabs = skinnedTabs

local function styleTab(tab)
    if not tab or done[tab] or not db().tabs then return end
    done[tab] = true
    skinnedTabs[tab] = true
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
-- Every scroll bar in a window takes the options panel's look.
local function styleScrollBar(sb)
    if done[sb] then return end
    done[sb] = true
    ns:StyleScrollBar(sb)
end

-- Dropdown boxes: a background piece and an arrow.
local function styleDropdown(dd)
    if done[dd] then return end
    done[dd] = true
    fade(dd.Background)
    for _, k in ipairs({ "Left", "Middle", "Right" }) do fade(dd[k]) end
    backdrop(dd, "Shadow", false, 0)
    -- Blizzard's boxed arrow goes for our chevron, in the text colour and
    -- the accent on hover. Its art is swapped on hover and press, which
    -- keeps the alpha, so it stays gone.
    local arrow = dd.Arrow
    if arrow then
        arrow:SetAlpha(0)
        local mark = dd:CreateTexture(nil, "OVERLAY", nil, 6)
        mark:SetTexture(ns.Media:Glyph("down"))
        mark:SetSize(12, 12)
        mark:SetPoint("RIGHT", dd, "RIGHT", -7, 0)
        mark:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
        Chrome:Register(mark, C.text, "vertex", 1)
        local hover = dd:CreateTexture(nil, "HIGHLIGHT", nil, 6)
        hover:SetTexture(ns.Media:Glyph("down"))
        hover:SetAllPoints(mark)
        hover:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(hover, C.fel, "vertex", 1)
    end
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
-- The brown and gold rules Blizzard lays across its windows (under a list,
-- beside a heading, between panes) are a handful of textures used over
-- and over; any of them, in any skinned window, goes.
local RULES = { "scrollline", "divider", "separator", "horizontalbar", "headerline", "filigree" }
local function isRule(atlas)
    local a = atlas:lower()
    for _, w in ipairs(RULES) do
        if a:find(w, 1, true) then return true end
    end
    return false
end

-- Text Blizzard inks for parchment inside the string itself (a quest title
-- in gossip is "|cff000000Name|r"): a colour code beats SetTextColor, so a
-- dark code at the front is swapped for our text colour.
local function lum(r, g, b) return r * 0.3 + g * 0.59 + b * 0.11 end

-- A colour that is one of the theme's own (a heading in the accent, a
-- muted note) is never parchment ink, however dark a custom theme makes
-- it: lightening it fought whatever paints it, and the text flickered.
-- The colours our own text is drawn in, which the dark-ink pass leaves
-- alone: the light ones, and the darks we set on accent pills. Never the
-- border: no text is drawn in it, and a look whose border is pure black
-- (Crisp) would otherwise take the game's black ink for its own.
local PALETTE = { "fel", "text", "muted", "shadow", "void" }
local function inPalette(r, g, b)
    for _, k in ipairs(PALETTE) do
        local c = C[k]
        if c and math.abs(r - c[1]) < 0.02 and math.abs(g - c[2]) < 0.02 and math.abs(b - c[3]) < 0.02 then return true end
    end
    return false
end
local function lightenInline(fs)
    local t = fs:GetText()
    if type(t) ~= "string" or (issecretvalue and issecretvalue(t)) or t:sub(1, 2) ~= "|c" then return end
    local hex = t:match("^|c%x%x(%x%x%x%x%x%x)")
    if not hex then return end
    local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    if lum(r, g, b) >= 0.35 or inPalette(r, g, b) then return end
    local c = C.text
    local ours = ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
    fs:SetText(ours .. t:sub(11))
end

local function recolorText(frame)
    if not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local a = r:GetAtlas()
            local al = r:GetAlpha()
            if a and not (issecretvalue and issecretvalue(al)) and al > 0 and isRule(a) then r:SetAlpha(0) end
        elseif r:GetObjectType() == "FontString" then
            styleFont(r)
            local cr, cg, cb = r:GetTextColor()
            local darkInk = cr and (cr * 0.3 + cg * 0.59 + cb * 0.11) < 0.35 and not inPalette(cr, cg, cb)
            local gold = isGold(r) and not (cr and inPalette(cr, cg, cb))
            if gold or darkInk then r:SetTextColor(C.text[1], C.text[2], C.text[3]) end
            lightenInline(r)
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
-- Some bars (the character sheet's skills and reputations) show progress
-- through a Fill piece of their own, sized by Blizzard and seen through a
-- mask; the bar's own texture spans it all. Blizzard's Fill is repainted
-- flat on a slim dark track, with the numbers left on it. Its colour is
-- deepened so white text reads: a skill's is the accent, a reputation's the
-- standing colour Blizzard gives it (read back whenever Blizzard sets it
-- again). Rows are reused as the list scrolls, so this runs on every pass.
local fillBars = setmetatable({}, { __mode = "k" })
local DEEP = 0.5
local function paintFill(sb)
    local fill = sb.Fill
    local e = extras[sb] or {}
    extras[sb] = e
    if sb.Mask and fill.RemoveMaskTexture and not fillBars[sb] then fill:RemoveMaskTexture(sb.Mask) end
    fillBars[sb] = true
    local st = sb.GetStatusBarTexture and sb:GetStatusBarTexture()
    if st and st ~= fill and st:GetAlpha() > 0 then st:SetAlpha(0) end
    local atlas = fill:GetAtlas()
    if atlas then
        -- White art is tinted by Blizzard (reputation standing); keep that.
        e.tinted = atlas:lower():find("white") ~= nil
        fill:SetTexture(ns.Media:Statusbar())
    end
    if fill:GetAlpha() < 1 then fill:SetAlpha(1) end
    if e.tinted then
        local r, g, b = fill:GetVertexColor()
        if not e.set or math.abs(r - e.set[1]) > 0.01 or math.abs(g - e.set[2]) > 0.01 or math.abs(b - e.set[3]) > 0.01 then
            -- Blizzard set its colour again: deepen that one.
            e.set = { r * DEEP, g * DEEP, b * DEEP }
            fill:SetVertexColor(e.set[1], e.set[2], e.set[3], 1)
        end
    else
        fill:SetVertexColor(C.fel[1] * DEEP, C.fel[2] * DEEP, C.fel[3] * DEEP, 1)
    end
    for _, r in ipairs({ sb:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= fill and r:GetAlpha() > 0 then r:SetAlpha(0) end
    end
    if not e.track then
        local bd = backdrop(sb, "Shadow", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("LEFT", sb, "LEFT", -1, 0)
        bd:SetPoint("RIGHT", sb, "RIGHT", 1, 0)
        bd:SetHeight((fill:GetHeight() or 15) + 2)
        e.track = bd
    end
end
PS.paintFill = paintFill
PS.fillBars = fillBars

local function styleBar(sb)
    if sb.Fill and sb.Fill.GetObjectType and sb.Fill:GetObjectType() == "Texture" then
        paintFill(sb)
        return
    end
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
    ns:TrackStatusBar(sb)
    -- Bars whose colour was in their art come out white on a flat texture.
    -- They get the accent, deepened so the numbers Blizzard writes on the
    -- bar in white still read against it.
    if not r or (r > 0.95 and g > 0.95 and b > 0.95) then
        r, g, b = C.fel[1] * 0.5, C.fel[2] * 0.5, C.fel[3] * 0.5
    end
    sb:SetStatusBarColor(r, g, b)
    backdrop(sb, "Shadow", false, 1)
end

-- Icon tabs and icon buttons (the character and profession side tabs,
-- the spellbook's category icons): the gold frame goes, the icon gets our
-- corners, and a checked tab wears the fel ring.
local function styleIconButton(b)
    if done[b] then return end
    -- A recipe's skill-up chevrons: their colour (orange, yellow, green) is
    -- the chance of a skill point, so they are not greyed like a control.
    local parent = b:GetParent()
    if parent and parent.SkillUps == b then return end
    -- Only ever an icon-sized button: a list row caught mid-layout, while it
    -- was briefly small, must not have its icon moved to its middle.
    local bw0, bh0 = b:GetSize()
    if not (bw0 and bh0) or bw0 < 1 or bh0 < 1 or bw0 > 64 or bh0 > 64 then return end
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
        ns:SetRing(ct, icon or b)
        ct:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ct, "fel", "vertex", 1)
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
-- Arrow buttons whose direction can be read wear our glyph, looked at again
-- on each scan in case the arrow turns (a pane that folds away).
local arrowGlyphs = setmetatable({}, { __mode = "k" })
local function styleArrow(b)
    local parent = b:GetParent()
    if parent and parent.SkillUps == b then return end   -- coloured on purpose
    if arrowGlyphs[b] then
        local dir = ns:ArrowDirection(b)
        if dir then ns:Glyph(b, dir) end
        return
    end
    if done[b] then return end
    done[b] = true
    local dir = ns:ArrowDirection(b)
    if dir then
        arrowGlyphs[b] = true
        ns:Glyph(b, dir)
        return
    end
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
                local al = a and a:lower() or ""
                local dir = (al:find("right") or al:find("next")) and "right"
                    or ((al:find("down") or al:find("dropdown")) and "down") or "right"
                r:SetTexture(ns.Media:Glyph(dir))
                r:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
                r:SetSize(12, 12)
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

-- Rows of the pet and mount lists (an icon, a name, Blizzard's bar behind
-- and its gold selection frame): a grey pill, the icon on a black tile at
-- the left where Blizzard puts it, and the selection drawn as our accent
-- ring. The ring is Blizzard's own selection texture repainted, so it
-- shows and hides with the selection at once.
local function styleListRow(b)
    if done[b] then return end
    done[b] = true
    fade(b.background); fade(b.iconBorder)
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "HIGHLIGHT" then
            local a = r:GetAtlas()
            if a and a:find("Highlight") then r:SetAlpha(0) end
        end
    end
    local lvl = b:GetFrameLevel()
    local bd = backdrop(b, "Shadow", false, 2)
    bd:SetFrameLevel(math.max(0, lvl - 2))
    local sel = b.selectedTexture
    ns:SetRing(sel, bd)
    sel:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
    Chrome:Register(sel, "fel", "vertex", 1)
    sel:ClearAllPoints()
    sel:SetAllPoints(bd)
    local h = b:CreateTexture(nil, "HIGHLIGHT")
    h:SetAllPoints(bd)
    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.1)
    local icon = b.icon
    ns:CropIcon(icon)
    local tile = CreateFrame("Frame", nil, b)
    tile:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
    tile:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
    -- Under the row's own art (the icon), over the pill.
    tile:SetFrameLevel(math.max(0, lvl - 1))
    ns:SetTemplate(tile, "Default", { alpha = 0.9, shadow = false })
    if b.dragButton then
        for _, r in ipairs({ b.dragButton:GetRegions() }) do
            if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "HIGHLIGHT" then r:SetAlpha(0) end
        end
    end
end

local function hasText(b)
    local fs = b.Text or b.Label or b.text or (b.GetFontString and b:GetFontString())
    if not (fs and fs.GetText) then return false end
    local t = fs:GetText()
    return t ~= nil and t ~= ""
end

-- Frames that are not Blizzard's and must be left as their addon drew them:
-- an add-on's page in the Settings window (the canvas it is shown on), and
-- any Wick panel (WickCore marks those).
-- A unit frame inside a window (the raid frame settings' preview) is
-- content, and a live one hands back secret alphas and sizes.
local function isUnitFrame(f)
    return f.healthBar ~= nil and f.displayedUnit ~= nil
end

local function notOurs(frame)
    if frame.wickPanel then return true end
    if isUnitFrame(frame) then return true end
    local sp = rawget(_G, "SettingsPanel")
    local canvas = sp and sp.Container and sp.Container.SettingsCanvas
    return canvas ~= nil and frame == canvas
end
PS.notOurs = notOurs

local function scanButtons(frame, depth)
    if depth > 7 or not frame.GetChildren or notOurs(frame) then return end
    recolorText(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if not isUnitFrame(child) then
            local kind = child:GetObjectType()
            local w, h = child:GetSize()
            w, h = w or 0, h or 0
            local isButton = kind == "Button" or kind == "CheckButton"
            if isButton and (w < 1 or h < 1) then
                -- Not laid out yet (a list row the moment it is made): judged
                -- by its size it would pass for a small icon button. Left for a
                -- later pass, once it has one.
            elseif kind == "Button" and isFilter(child) then
                styleFilter(child)
            elseif kind == "Button" and child.StateIcon and child.Name then
                -- A collapsible heading (skills, currencies): its brown bar,
                -- drawn again as its hover, goes for a grey pill.
                for _, r in ipairs({ child:GetRegions() }) do
                    local a = r:GetObjectType() == "Texture" and r:GetAtlas()
                    if a and a:find("collapseExpand") and r:GetAlpha() > 0 then r:SetAlpha(0) end
                end
                child.Name:SetTextColor(C.text[1], C.text[2], C.text[3])
                if not done[child] then
                    done[child] = true
                    backdrop(child, "Shadow", false, 1)
                    local h = child:CreateTexture(nil, "HIGHLIGHT")
                    h:SetPoint("TOPLEFT", 2, -2)
                    h:SetPoint("BOTTOMRIGHT", -2, 2)
                    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.12)
                end
            elseif isButton and child.icon and child.name and child.selectedTexture and w > 64 then
                styleListRow(child)
            elseif isButton and w <= 64 and (child.Icon or child.icon) and not hasText(child) and not child.Name
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
            elseif child.Slider and child.Back and child.Forward then
                -- A slider with arrows either side (the settings' sliders):
                -- the arrows become our marks.
                -- Bare marks, no tile: they sit either side of a thin track.
                ns:Glyph(child.Back, "left", { tile = false, size = 12 })
                ns:Glyph(child.Forward, "right", { tile = false, size = 12 })
                done[child.Back], done[child.Forward] = true, true
                if child.Slider:GetObjectType() == "Slider" then styleSlider(child.Slider) end
            elseif kind == "Slider" then
                styleSlider(child)
            elseif kind == "StatusBar" then
                styleBar(child)
            elseif kind == "Frame" and child.Fill and child.Mask and child.Text
                and child.Fill.GetObjectType and child.Fill:GetObjectType() == "Texture" then
                paintFill(child)
            elseif kind == "CheckButton" and w <= 36 and h <= 36 and not (child.Icon or child.icon) then
                styleCheck(child)
            elseif isButton and (child.Icon or child.icon) and not child.Left and not child.Name
                and not (child:GetParent() and child:GetParent().Button == child) then
                styleIconButton(child)
            elseif arrowGlyphs[child] or (isButton and w <= 32 and h <= 32 and not hasText(child)) then
                styleArrow(child)
            elseif kind == "Button" and w >= 110 and h <= 36 and hasText(child) and not child.CollapseButton then
                styleRow(child)
            end
            if kind ~= "ScrollFrame" then
                scanButtons(child, depth + 1)
            end
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
        if not CONTENT[kind] and not child.ScrollTarget and not child.ScrollBar and not notOurs(child) then
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
                if text then
                    text:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
                    Chrome:Register(text, C.fel, "text")
                end
            else
                styleQuestHeaders(child, depth + 1)
            end
        end
    end
end

-- The full world map. Its border, title and close button live on a
-- BorderFrame of their own; the quest log beside it has its own art.
-- The maximise and minimise buttons some windows carry: Blizzard's red
-- art gives way to a plain + and -, like our x.
local function styleMaxMin(mm)
    if not mm then return end
    if mm.MaximizeButton then ns:Glyph(mm.MaximizeButton, "plus", { tile = false, size = 12 }) end
    if mm.MinimizeButton then ns:Glyph(mm.MinimizeButton, "minus", { tile = false, size = 12 }) end
end

-- The world map: windowed, not fullscreen, when it opens; no blackout
-- behind it when it is maximised; and a grip in its corner that scales the
-- windowed map (Blizzard's map has only its two fixed sizes), kept between
-- sessions. The scale is only ever changed out of combat.
local function mapMaximized(frame)
    return frame.IsMaximized and frame:IsMaximized() or false
end

local function applyMapScale(frame)
    if InCombatLockdown() then return end
    local want = mapMaximized(frame) and 1 or (db().mapScale or 1)
    if math.abs((frame:GetScale() or 1) - want) > 0.005 then frame:SetScale(want) end
end

-- Where the windowed map sits, saved as its top left corner in screen
-- units so it survives a change of its own scale.
local function saveMapPos(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (left and top) then return end
    local s = frame:GetEffectiveScale()
    db().mapPos = { left * s, top * s }
end

local function applyMapPos(frame)
    local pos = db().mapPos
    if not pos or InCombatLockdown() or mapMaximized(frame) then return end
    local s = frame:GetEffectiveScale()
    if not (s and s > 0) then return end
    local x, y = pos[1] / s, pos[2] / s
    local p, rel, rp, px, py = frame:GetPoint(1)
    if p ~= "TOPLEFT" or rel ~= UIParent or rp ~= "BOTTOMLEFT" or math.abs((px or 0) - x) > 0.5
        or math.abs((py or 0) - y) > 0.5 or frame:GetNumPoints() ~= 1 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

-- A strip over the map's title bar that drags the windowed map.
local function mapMover(frame)
    local e = extras[frame] or {}
    extras[frame] = e
    if e.mover then return e.mover end
    local bf = frame.BorderFrame or frame
    local title = bf.TitleContainer
    local m = CreateFrame("Frame", nil, frame)
    if title then
        m:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
        m:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", -60, 0)
    else
        m:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, 0)
        m:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -60, 0)
        m:SetHeight(20)
    end
    m:SetFrameLevel(frame:GetFrameLevel() + 600)
    m:EnableMouse(true)
    m:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or InCombatLockdown() or mapMaximized(frame) then return end
        frame:SetMovable(true)
        frame:StartMoving()
        m.moving = true
    end)
    m:SetScript("OnMouseUp", function()
        if not m.moving then return end
        m.moving = false
        frame:StopMovingOrSizing()
        saveMapPos(frame)
    end)
    e.mover = m
    return m
end

-- Any other window: dragged by its title bar and kept where it was left,
-- each by name. Blizzard places its windows again every time one opens, so
-- the saved spot is put back straight after it does, and held each frame
-- while the window shows. Never in combat. The map has its own mover; the
-- bags have their own layout.
local NOT_MOVED = { WorldMapFrame = true, ContainerFrameCombinedBags = true }
local function movable(n)
    return not NOT_MOVED[n] and not n:find("^ContainerFrame%d")
end

local function windowPos(n)
    local all = db().windowPos
    return type(all) == "table" and all[n] or nil
end

-- A page that fills a window, such as the group finder's Browse and
-- Listing pages inside LFGParentFrame, is not a window of its own. Its
-- title bar drags the window it sits in, and the spot is kept under that
-- window's name. Dragging a page on its own pulled it out of the window:
-- it lost the anchors that size it to the window, came back at its own
-- spot each time, and left the window standing empty beside it. In the
-- client's own layout the listed frames parented to another listed window
-- are all pages of this kind (Statistics in the character window, Browse
-- and Listing in the group finder), each set to fill its window.
local isWindow
local function windowOf(n, frame)
    if not isWindow then
        isWindow = {}
        for _, w in ipairs(PS.WINDOWS) do isWindow[w] = true end
    end
    local parent = frame.GetParent and frame:GetParent()
    local pn = parent and parent ~= UIParent and parent.GetName and parent:GetName()
    if pn and isWindow[pn] and _G[pn] == parent then return pn, parent end
    return n, frame
end

-- A page dragged loose by an earlier version goes back into its window,
-- and the spot saved for it is dropped.
local function seatPage(n, page, window)
    local all = db().windowPos
    if type(all) == "table" then all[n] = nil end
    if InCombatLockdown() then return end
    local _, rel = page:GetPoint(1)
    if page:GetNumPoints() ~= 2 or rel ~= window then
        page:ClearAllPoints()
        page:SetAllPoints(window)
    end
end

local function applyWindowPos(n, frame)
    local pos = windowPos(n)
    if not pos or InCombatLockdown() then return end
    local s = frame:GetEffectiveScale()
    if not (s and s > 0) then return end
    local x, y = pos[1] / s, pos[2] / s
    local p, rel, rp, px, py = frame:GetPoint(1)
    if p ~= "TOPLEFT" or rel ~= UIParent or rp ~= "BOTTOMLEFT" or math.abs((px or 0) - x) > 0.5
        or math.abs((py or 0) - y) > 0.5 or frame:GetNumPoints() ~= 1 then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

local function windowMover(n, frame)
    local e = extras[frame] or {}
    extras[frame] = e
    if e.mover then return e.mover end
    -- The frame that moves, and the name its spot is kept under: the
    -- window itself, or for a page, the window round it.
    local tn, target = windowOf(n, frame)
    local bf = frame.BorderFrame or frame
    local title = bf.TitleContainer
    -- Our own strip over the title bar, clear of the close and size
    -- buttons in the corner; nothing is written to Blizzard's frame.
    local m = CreateFrame("Frame", nil, frame)
    if title then
        m:SetPoint("TOPLEFT", title, "TOPLEFT", 0, 0)
        m:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", -40, 0)
    else
        m:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, 0)
        m:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -60, 0)
        m:SetHeight(20)
    end
    m:SetFrameLevel(frame:GetFrameLevel() + 600)
    m:EnableMouse(true)
    m:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or InCombatLockdown() or not db().moveWindows then return end
        target:SetMovable(true)
        target:SetClampedToScreen(true)
        target:StartMoving()
        m.moving = true
    end)
    m:SetScript("OnMouseUp", function()
        if not m.moving then return end
        m.moving = false
        target:StopMovingOrSizing()
        -- Ours to remember, not the client's layout cache.
        if target.SetUserPlaced then pcall(target.SetUserPlaced, target, false) end
        local left, top = target:GetLeft(), target:GetTop()
        if not (left and top) then return end
        local s = target:GetEffectiveScale()
        if type(db().windowPos) ~= "table" then db().windowPos = {} end
        db().windowPos[tn] = { left * s, top * s }
    end)
    e.mover = m
    return m
end

-- Called for each skinned window that shows, every frame.
function PS.holdWindow(n, frame)
    if not movable(n) then return end
    local m = windowMover(n, frame)
    local on = db().moveWindows and true or false
    if m:IsShown() ~= on then m:SetShown(on) end
    local tn, target = windowOf(n, frame)
    if tn ~= n then seatPage(n, frame, target) end
    if on and not m.moving then applyWindowPos(tn, target) end
end

-- Straight after Blizzard lays its windows out, before they are drawn.
function PS.restoreWindows()
    if not db().moveWindows or InCombatLockdown() then return end
    local all = db().windowPos
    if type(all) ~= "table" then return end
    for n in pairs(all) do
        local f = rawget(_G, n)
        local e = f and extras[f]
        -- A page's spot is never laid on the page (holdWindow drops it).
        if f and f.IsShown and f:IsShown() and not (e and e.mover and e.mover.moving) and movable(n)
            and windowOf(n, f) == n then
            applyWindowPos(n, f)
        end
    end
end

local function mapGrip(frame)
    local e = extras[frame] or {}
    extras[frame] = e
    if e.grip then return e.grip end
    local g = CreateFrame("Button", nil, frame)
    g:SetSize(16, 16)
    g:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    g:SetFrameLevel(frame:GetFrameLevel() + 600)
    local t = g:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture(ns.Media:Glyph("right"))
    t:SetRotation(-math.pi / 4)
    t:SetVertexColor(C.text[1], C.text[2], C.text[3], 0.7)
    local h = g:CreateTexture(nil, "HIGHLIGHT")
    h:SetAllPoints()
    h:SetTexture(ns.Media:Glyph("right"))
    h:SetRotation(-math.pi / 4)
    h:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
    Chrome:Register(h, "fel", "vertex", 1)
    -- Dragging away from the top left corner grows the map; the size is
    -- taken from how far the pointer is from that corner.
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() or mapMaximized(frame) then return end
        local left, top = frame:GetLeft(), frame:GetTop()
        local w = frame:GetWidth()
        if not (left and top and w and w > 0) then return end
        self.drag = { left = left * frame:GetEffectiveScale(), top = top * frame:GetEffectiveScale(),
                      w = w, parent = frame:GetParent():GetEffectiveScale() }
    end)
    g:SetScript("OnMouseUp", function(self)
        if self.drag then saveMapPos(frame) end
        self.drag = nil
    end)
    g:SetScript("OnUpdate", function(self)
        local d = self.drag
        if not d then return end
        if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then self.drag = nil; return end
        local cx = GetCursorPosition()
        local scale = (cx - d.left) / (d.w * d.parent)
        scale = math.max(0.6, math.min(1.6, scale))
        db().mapScale = scale
        -- Keep the top left corner where it is while the map grows.
        frame:SetScale(scale)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.left / (scale * d.parent), d.top / (scale * d.parent))
    end)
    e.grip = g
    return g
end

PS.SPECIAL.WorldMapFrame = function(frame)
    -- Open windowed: the client keeps the last size in this setting.
    if db().mapWindowed and SetCVar then pcall(SetCVar, "miniWorldMap", "1") end
    local watch = CreateFrame("Frame", nil, frame)
    watch:SetScript("OnUpdate", function()
        local maxed = mapMaximized(frame)
        -- The black around a maximised map.
        if frame.BlackoutFrame then frame.BlackoutFrame:SetAlpha(0) end
        local g = mapGrip(frame)
        g:SetShown(not maxed)
        local m = mapMover(frame)
        m:SetShown(not maxed)
        applyMapScale(frame)
        -- Put back where it was dragged, unless it is being dragged now.
        if not m.moving and not g.drag then applyMapPos(frame) end
    end)
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
        -- The quest log as a black card beside the map. Its gold frame, the
        -- filigree on top and the gradient along the bottom go; the search
        -- box and the quest count become grey pills.
        card(ql, "wuiLog", "TOPLEFT", ql, "BOTTOMRIGHT", ql, 2, -2, -2, 4)
        local qsf = rawget(_G, "QuestScrollFrame")
        if qsf then
            if qsf.BorderFrame then fadeRegions(qsf.BorderFrame) end
            fade(qsf.Edge); fade(qsf.Background)
            if qsf.SearchBox then styleEditBox(qsf.SearchBox) end
            if qsf.SettingsDropdown then ns:Glyph(qsf.SettingsDropdown, "gear", { tile = false, size = 13 }) end
        end
        local count = rawget(_G, "QuestLogCount")
        if count then
            fade(count.Left); fade(count.Right); fade(count.Middle)
            backdrop(count, "Shadow", false, 0)
        end
    end
    -- The full-skin look: the window is the grey panel, the breadcrumb bar
    -- a black card with its crumbs as grey pills, and the gamepad-era
    -- backing that shows past the map's edges gone.
    local flip = CreateFrame("Frame", nil, frame)
    flip:SetScript("OnUpdate", function()
        local win = extras[frame] and extras[frame].backdrop
        if win and win.wuiTemplate ~= "Shadow" then ns:SetTemplate(win, "Shadow", { shadow = true }) end
    end)
    if nav then card(nav, "wuiNav", "TOPLEFT", nav, "BOTTOMRIGHT", nav, -2, 2, 2, -2) end
    if frame.OverscrollBG then fadeRegions(frame.OverscrollBG) end
    local mm = bf and bf.MaximizeMinimizeFrame
    if mm then
        for _, b in ipairs({ mm:GetChildren() }) do
            for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
                local t = b[get] and b[get](b)
                if t and t.SetDesaturated then t:SetDesaturated(true) end
            end
        end
    end
    styleMaxMin(mm)
    -- The quest log toggle at the map's corner: its corner shadow goes, its
    -- art greys on a black tile.
    local spt = frame.SidePanelToggle
    if spt then
        -- Hide pushes the quest log away to the right; show brings it back.
        if spt.CloseButton then ns:Glyph(spt.CloseButton, "right") end
        if spt.OpenButton then ns:Glyph(spt.OpenButton, "left") end
    end
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
-- colour, read while the window is open, with a soft halo of the same
-- colour fading out round the slot (green and up).
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
    local bd = backdrop(b, "Default", false, 0)
    -- The halo is ours, on our backdrop: under the icon, reaching past the
    -- slot's edge into the gaps between slots, clear in the middle.
    local e = extras[b]
    local g = bd:CreateTexture(nil, "BACKGROUND", nil, -7)
    g:SetTexture(ns.Media.glow)
    if g.SetTextureSliceMargins then g:SetTextureSliceMargins(20, 20, 20, 20) end
    g:SetPoint("TOPLEFT", bd, "TOPLEFT", -8, 8)
    g:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", 8, -8)
    g:Hide()
    e.qualityGlow = g
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
                if e.qualityGlow then
                    e.qualityGlow:SetVertexColor(r, g, bl, 0.55)
                    e.qualityGlow:SetShown(db().qualityGlow ~= false)
                end
            else
                ns:SetBorderColor(e.backdrop, "border")
                if e.qualityGlow then e.qualityGlow:Hide() end
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
            Chrome:Register(row.Title, C.fel, "text")
        elseif row.Label and row.Value and row.Background then
            -- Stat rows: Blizzard's brown stripe becomes a faint one of
            -- ours; Blizzard still decides which rows are striped.
            local bg = row.Background
            if bg:GetAtlas() then
                bg:ClearAllPoints()
                bg:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
                bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 0)
                ns:Fill(bg, 1, 1, 1, 0.045)
            end
            row.Label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    -- The gold rule under the scroll box.
    for _, r in ipairs({ sb:GetRegions() }) do
        local a = r:GetObjectType() == "Texture" and r:GetAtlas()
        if a and a:find("ScrollLine") then r:SetAlpha(0) end
    end
end

-- The gear slots' pull-out arrows: Blizzard's yellow side tabs become our
-- chevrons, pointing away from the slot the way the flyout opens.
local function stylePopouts()
    for _, name in ipairs(SLOTS) do
        local slot = _G["Character" .. name .. "Slot"]
        local pop = slot and slot.popoutButton
        if pop then
            local p, rel, rp = pop:GetPoint(1)
            local dir = (p == "RIGHT" and rp == "LEFT" and "left") or (p == "LEFT" and rp == "RIGHT" and "right")
                or (p == "TOP" and "up") or (p == "BOTTOM" and "up") or "right"
            ns:Glyph(pop, dir, { tile = false, size = 12 })
        end
    end
    -- The brass arrow between the ranged slot and the ammo slot.
    local ammo = rawget(_G, "CharacterAmmoSlot")
    if ammo then
        for _, child in ipairs({ ammo:GetChildren() }) do
            for _, r in ipairs({ child:GetRegions() }) do
                local a = r:GetObjectType() == "Texture" and r:GetAtlas()
                if a and a:find("GearSlot%-Arrow") and r:GetAlpha() > 0 then r:SetAlpha(0) end
            end
        end
    end
    -- The flyout of items to choose from: its gold frame goes for a card.
    local fb = rawget(_G, "EquipmentFlyoutFrameButtons")
    if fb and fb:IsVisible() then
        for _, k in ipairs({ "bg1", "bg2", "bg3", "bg4" }) do fade(fb[k]) end
        -- Grey, as it opens over the black card of the model.
        local c = card(fb, "wuiCard", "TOPLEFT", fb, "BOTTOMRIGHT", fb, -2, 2, 2, -2)
        if c.wuiTemplate ~= "Shadow" then ns:SetTemplate(c, "Shadow", { shadow = true }) end
    end
    -- The equipment sets pane: its gold inner frame and rule go; New Set
    -- becomes a grey pill with our plus.
    local pane = rawget(_G, "PaperDollFrame") and PaperDollFrame.EquipmentManagerPane
    local side = pane or (rawget(_G, "PaperDollFrameNewSet") and PaperDollFrameNewSet:GetParent())
    if side and side:IsVisible() then
        fade(side.Border)
        for _, r in ipairs({ side:GetRegions() }) do
            local a = r:GetObjectType() == "Texture" and r:GetAtlas()
            if a and (a:find("ScrollLine") or a:find("insideframe")) then r:SetAlpha(0) end
        end
    end
    local ns_ = rawget(_G, "PaperDollFrameNewSet")
    if ns_ then
        fade(ns_.StateTexture)
        if not done[ns_] then
            done[ns_] = true
            local bd = backdrop(ns_, "Shadow", false, 3)
            for _, r in ipairs({ ns_:GetRegions() }) do
                local a = r:GetObjectType() == "Texture" and r:GetAtlas()
                if a and a:find("Icon%-Add") then
                    r:SetTexture(ns.Media:Glyph("plus"))
                    r:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
                    Chrome:Register(r, "fel", "vertex", 1)
                    r:SetSize(14, 14)
                end
            end
            local h = ns_:CreateTexture(nil, "HIGHLIGHT")
            h:SetAllPoints(bd)
            ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.15)
        end
        if ns_.StateTexture then ns_.StateTexture:SetAlpha(0) end
    end
end

-- The portrait and titles tabs above the stats: their gold frames go, each
-- icon sits on a black tile, the open one wears the accent ring.
local function styleSidebarTabs()
    local host = rawget(_G, "PaperDollSidebarTabs")
    if not host then return end
    for _, tab in ipairs({ host:GetChildren() }) do
        local icon = tab.Icon
        if icon then
            fade(tab.TabBg); fade(tab.Highlight)
            local e = extras[tab] or {}
            extras[tab] = e
            if not e.ring then
                ns:CropIcon(icon)
                local bd = backdrop(tab, "Default", false, 0)
                bd:ClearAllPoints()
                bd:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
                bd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
                ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
                local ring = tab:CreateTexture(nil, "OVERLAY", nil, 2)
                ns:SetRing(ring, bd)
                ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
                Chrome:Register(ring, "fel", "vertex", 1)
                ring:SetAllPoints(bd)
                e.ring = ring
                local h = tab:CreateTexture(nil, "HIGHLIGHT")
                h:SetAllPoints(icon)
                ns:Fill(h, 1, 1, 1, 0.12)
            end
            -- Blizzard darkens the tabs that are not open with Hider.
            e.ring:SetShown(not (tab.Hider and tab.Hider:IsShown()))
        end
    end
end

PS.SPECIAL.CharacterFrame = function(frame)
    -- The race backdrop behind the model goes (Wick chose a card over it,
    -- 2026-09-28): CharacterModelFrameBackground* and BackgroundOverlay.
    for _, s in ipairs(SLOTS) do
        local b = _G["Character" .. s .. "Slot"]
        if b then styleSlot(b) end
    end
    -- Every frame: slots, stats and bars are redrawn by Blizzard as pages
    -- change and items move, and a slower pass shows its art for a moment.
    local poll = CreateFrame("Frame", nil, frame)
    poll:SetScript("OnUpdate", function()
        paintSlots()
        styleStats()
        styleSidebarTabs()
        stylePopouts()
        local detail = rawget(_G, "TokenDetailFrame")
        if detail then fade(detail.Divider) end

        -- The right pane as one black card; the arrow that folds it away
        -- greyed on a tile.
        local scene = rawget(_G, "CharacterModelScene")
        if scene then
            for _, k in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
                fade(scene[k])
            end
        end
        local left = rawget(_G, "CharacterFrameLeftPaneHost")
        if left and left:IsVisible() then
            card(left, "wuiPane", "TOPLEFT", left, "BOTTOMRIGHT", left, 6, -4, -4, 6)
        end
        local host = rawget(_G, "CharacterFrameRightPaneHost")
        if host and host:IsVisible() then
            card(host, "wuiPane", "TOPLEFT", host, "BOTTOMRIGHT", host, 4, -4, -6, 6)
        end
        local tog = rawget(_G, "CharacterFrameRightPaneToggleButton")
        if tog then ns:Glyph(tog, ns:ArrowDirection(tog) or "left") end
    end)
    -- The grey window, as in the other full-skin windows.
    -- The character's name in the title in their class colour, like the
    -- unit frames; other tabs' titles keep the accent.
    local flip = CreateFrame("Frame", nil, frame)
    local _, class = UnitClass("player")
    local me = UnitName("player")
    flip:SetScript("OnUpdate", function()
        -- The side tabs (Character, Reputation, Currency...) down the right
        -- edge, the same kind as the professions' side tabs, every frame:
        -- Blizzard redraws a tab as it is clicked, and a slower look lets
        -- its own art show for a moment.
        for sb in pairs(fillBars) do
            if sb:IsVisible() then paintFill(sb) end
        end
        local modes = rawget(_G, "CharacterFrameModeTabs")
        if modes and PS.styleSideTab then
            for _, tab in ipairs({ modes:GetChildren() }) do
                if tab.Icon and tab:IsShown() then PS.styleSideTab(tab) end
            end
        end
        local win = extras[frame] and extras[frame].backdrop
        if win and win.wuiTemplate ~= "Shadow" then ns:SetTemplate(win, "Shadow", { shadow = true }) end
        local title = frame.TitleContainer and frame.TitleContainer.TitleText
        if title then
            local t = title:GetText()
            if t and not (issecretvalue and issecretvalue(t)) and me and t:find(me, 1, true) then
                title:SetTextColor(ns:ClassColor(class))
            else
                title:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
            end
        end
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
        ns:BarTexture(t)
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
    -- The crafting page puts its link-profession button at the bar's right
    -- end; the bar stops short of it.
    local host = bar:GetParent()
    local link = host and host.LinkButton
    if r and link and link:IsShown() and link:GetLeft() and link:GetLeft() < r then
        r = link:GetLeft() - 4 - PAD * 2
    end
    if l and r and r > l then
        width = r - l + PAD * 2
        -- A slim fill under the text row, as on the unit frames; the row
        -- rises above it.
        e.track:SetSize(width, 6 + PAD * 2 + ROW)
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
    Chrome:Register(e.bar, "fel", "vertex", 1)
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
    local checked = b.GetCheckedTexture and b:GetCheckedTexture()
    local e = extras[b]
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r ~= icon and r ~= checked and r:GetDrawLayer() ~= "HIGHLIGHT"
            and not (e and (e.hover == r or e.ring == r)) and r:GetAlpha() > 0 then
            r:SetAlpha(0)
        end
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
-- Art a window's special gives a card of its own shape; the walk leaves it.
local noCard = setmetatable({}, { __mode = "k" })
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

-- Windows whose art comes in several pieces (a parchment in two halves)
-- get one card of their own over the content instead of one per piece.
local ONE_CARD = { GossipFrame = true, QuestFrame = true, QuestLogPopupDetailFrame = true, ItemTextFrame = true }

-- The old dropdowns (UIDropDownMenuTemplate: Left, Middle and Right
-- textures round a text and an arrow button), still on a few pages (the
-- guild's preferred play settings). Their art goes for a tile of ours round
-- the part that shows and the arrow takes our chevron. Their textures are
-- tall enough to pass for a panel's backing, so they are kept off the
-- walk's cards, which stacked two of them into one dark block.
local function isOldDropdown(f)
    return f.Left and f.Middle and f.Right and f.Button and f.Text and f.GetObjectType and f:GetObjectType() == "Frame"
end
local function styleOldDropdown(dd)
    for _, k in ipairs({ "Left", "Middle", "Right" }) do
        local t = dd[k]
        if t then
            t:SetAlpha(0)
            noCard[t] = true
            if cards[t] then cards[t]:Hide() end
        end
    end
    if done[dd] then return end
    done[dd] = true
    local b = dd.Button
    local e = extras[dd] or {}
    extras[dd] = e
    if not e.backdrop and b then
        local bd = CreateFrame("Frame", nil, dd)
        bd:SetPoint("TOPLEFT", dd, "TOPLEFT", 18, -2)
        bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        bd:SetFrameLevel(math.max(0, dd:GetFrameLevel() - 1))
        ns:SetTemplate(bd, "Shadow")
        e.backdrop = bd
    end
    if b then
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
            local t = b[get] and b[get](b)
            if t then t:SetAlpha(0) end
        end
        ns:Glyph(b, "down", { tile = false, size = 12 })
        done[b] = true
    end
    styleText(dd.Text)
end
PS.styleOldDropdown = styleOldDropdown

local function stripArt(frame, root)
    if frame.wuiBG or rankBars[frame] then return end
    if isOldDropdown(frame) then styleOldDropdown(frame) return end
    local rootName = root.GetName and root:GetName()
    local oneCard = rootName and ONE_CARD[rootName]
    local rw, rh = root:GetSize()
    for _, r in ipairs({ frame:GetRegions() }) do
        local n = r:GetName()
        if r:GetObjectType() == "Texture" and r:GetAlpha() > 0 and not isOwn(frame, r) and not isIcon(frame, r)
            and not (n and n:find("BlackFilter$")) then
            r:SetAlpha(0)
            local w, h = r:GetSize()
            if not oneCard and frame ~= root and w and h and w >= 120 and h >= 60 and not (w >= rw * 0.9 and h >= rh * 0.85) and not cards[r] and not noCard[r] then
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
    if not b then return end
    ns:Glyph(b, (mark == "<" and "left") or (mark == ">" and "right") or mark)
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

-- The stack split (shift-click a stack): its box, border and number well
-- are one old money-frame texture, swapped for a larger one when a vendor
-- sells by the stack. Both go for the look's panel, with the number in a
-- well of ours between the arrow marks and pill buttons under it. The game
-- lays it out again each time it opens, one number or the stacks over a
-- total, and the well follows.
local function placeSplitWell(frame)
    local e = extras[frame]
    local w = e and e.well
    local l, r = frame.LeftButton, frame.RightButton
    if not (w and l and r) then return end
    w:ClearAllPoints()
    -- By the stack, the count of stacks sits a line above the arrows.
    w:SetPoint("TOPLEFT", l, "TOPRIGHT", 3, frame.isMultiStack and 15 or 3)
    w:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT", -3, -3)
end
PS.placeSplitWell = placeSplitWell

PS.SPECIAL.StackSplitFrame = function(frame)
    fadeRegions(frame)
    backdrop(frame, "Default", db().brackets)
    local e = extras[frame]
    local l, r = frame.LeftButton, frame.RightButton
    if l and r and not e.well then
        local well = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        ns:Fill(well, C.void[1], C.void[2], C.void[3], 0.9)
        local ring = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        ring:SetPoint("TOPLEFT", well)
        ring:SetPoint("BOTTOMRIGHT", well)
        ns:SetRing(ring, frame)
        ring:SetVertexColor(C.border[1], C.border[2], C.border[3], 1)
        Chrome:Register(ring, "border", "vertex")
        e.well, e.wellRing = well, ring
        placeSplitWell(frame)
        if type(frame.ChooseFrameType) == "function" then
            hooksecurefunc(frame, "ChooseFrameType", placeSplitWell)
        end
    end
    styleText(frame.StackSplitText, 16, C.text)
    styleText(frame.StackItemCountText, 12, C.muted)
    styleStepper(l, "<")
    styleStepper(r, ">")
    styleButton(frame.OkayButton)
    styleButton(frame.CancelButton)
end

-- Settings headings carry Blizzard's Options_CategoryHeader bars; fading
-- them each pass (they are redrawn as the list scrolls) and saying so.
local function optionsHeader(f)
    local found = false
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local a = r:GetAtlas()
            if a and a:find("^Options_CategoryHeader") then
                if r:GetAlpha() > 0 then r:SetAlpha(0) end
                found = true
            end
        end
    end
    return found
end

-- List buttons drawn with Blizzard's list art (the auction house's
-- categories, the large list rows): the bar and its hover go for a grey
-- pill, and the selected art is repainted as the accent ring so it shows
-- and hides with the selection by itself.
local LIST_ART = { "nav%-button", "button%-list%-large" }
local function listArt(a)
    for _, pat in ipairs(LIST_ART) do if a:find(pat) then return true end end
    return false
end
local function styleListButton(b)
    local any = false
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local a = r:GetAtlas()
            if a and listArt(a) then
                any = true
                local al = a:lower()
                if al:find("select") then
                    ns:SetRing(r, b)
                    r:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
                    Chrome:Register(r, "fel", "vertex", 1)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
                    r:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
                    r:SetAlpha(1)
                elseif r:GetAlpha() > 0 then
                    r:SetAlpha(0)
                end
            end
        end
    end
    if any and not done[b] then
        done[b] = true
        local bd = backdrop(b, "Shadow", false, 1)
        bd:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    end
    return any
end

-- Bag and vendor item buttons: the slot art goes for a black tile, the
-- icon is cropped; the quality ring, the junk coin and the new-item glow
-- are Blizzard's and stay, as they carry meaning.
-- Item buttons (the game's bags, vendors, loot): Blizzard's square slot
-- art goes so our tile shows. An empty slot's art is drawn on the same
-- texture as the item's icon, so the icon is faded only while it shows
-- that art and brought back the moment an item is drawn there; fading it
-- for good left items in the bags with no picture.
local function styleItemButton(b)
    local icon = b.icon or b.Icon
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt and nt:GetAlpha() > 0 then nt:SetAlpha(0) end
    if b.ItemSlotBackground and b.ItemSlotBackground:GetAlpha() > 0 then b.ItemSlotBackground:SetAlpha(0) end
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local a = r:GetAtlas()
            local slotArt = a and a:find("item%-slot")
            if r == icon then
                local want = slotArt and 0 or 1
                if math.abs(r:GetAlpha() - want) > 0.01 then r:SetAlpha(want) end
            elseif slotArt and r:GetAlpha() > 0 then
                r:SetAlpha(0)
            end
        end
    end
    if done[b] then return end
    done[b] = true
    if icon then ns:CropIcon(icon) end
    local bd = backdrop(b, "Default", false, 0)
    ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
end

-- Straight away when Blizzard draws a picture into a slot we skinned.
if SetItemButtonTexture then
    hooksecurefunc("SetItemButtonTexture", function(b)
        if b and done[b] then pcall(styleItemButton, b) end
    end)
end

local function walkProfessions(frame, depth, root)
    if depth > 8 or not frame.GetChildren or notOurs(frame) then return end
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
        if child:IsShown() and not isUnitFrame(child) then
            local kind = child:GetObjectType()
            local fill = child.Fill
            if (kind == "Button" or kind == "CheckButton") and ((child:GetWidth() or 0) < 1 or (child:GetHeight() or 0) < 1) then
                -- Not laid out yet; seen again once it has a size.
            elseif (kind == "ItemButton" or kind == "Button") and child.IconBorder and (child.icon or child.Icon)
                and (child.JunkIcon or child.NewItemTexture or kind == "ItemButton") then
                styleItemButton(child)
            elseif (kind == "Button" or kind == "CheckButton") and styleListButton(child) then
                -- done above
            elseif kind == "Button" and frame.CloseButton == child then
                -- A close button inside the window (a popup's): our x.
                styleClose(child)
            elseif kind == "StatusBar" then
                flatBar(child)
            elseif fill and fill.GetObjectType and fill:GetObjectType() == "Texture"
                and (child.Border or child.Background or child.Mask) then
                flatRankBar(child)
            elseif child.IncrementButton or child.DecrementButton or (kind == "EditBox" and (child.IncrementButton or frame.IncrementButton)) then
                styleSpinner(child)
            elseif (kind == "Button" or kind == "Frame") and child.GetRegions and optionsHeader(child) then
                -- A heading in the Settings category list: its brown bar
                -- goes for a grey pill.
                if not done[child] then
                    done[child] = true
                    local bd = backdrop(child, "Shadow", false, 1)
                    bd:SetFrameLevel(math.max(0, child:GetFrameLevel() - 1))
                end
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
            elseif kind == "Button" and child.Icon and child.Icon.GetAtlas and child.Icon:GetAtlas()
                and child:GetWidth() <= 64 and not child.Left then
                -- A button drawn from Blizzard's icon art (repair, sell junk):
                -- the square slot behind it goes; the icon stays on our tile.
                for _, r in ipairs({ child:GetRegions() }) do
                    if r:GetObjectType() == "Texture" and r ~= child.Icon and r:GetDrawLayer() == "BACKGROUND" and r:GetAlpha() > 0 then
                        r:SetAlpha(0)
                    end
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
        bd:SetSize(46, 46)
        e.tile = bd
        if icon then ns:CropIcon(icon) end
        local ring = tab:CreateTexture(nil, "OVERLAY", nil, 2)
        ns:SetRing(ring, bd)
        ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ring, "fel", "vertex", 1)
        ring:SetAllPoints(bd)
        e.ring = ring
    end
    -- Blizzard's tabs are 55 px tall for its big tab art; around our 46 px
    -- tiles that leaves wide gaps. Each tab is made just taller than its
    -- tile, and as Blizzard stacks them one under the next, the column
    -- closes up.
    if not InCombatLockdown() and math.abs((tab:GetHeight() or 0) - 48) > 0.5 then tab:SetHeight(48) end
    -- In a look whose panels fade out at their sides (Gilded), the column
    -- moves in to the edge that shows. Only the top tab is moved, the rest
    -- hang under it; Blizzard's own place is kept, and the move made
    -- again whenever Blizzard puts the tab back there.
    local st = Chrome.StyleDef and Chrome:StyleDef()
    local inset = st and st.edgeInset
    if inset and not InCombatLockdown() and tab:GetNumPoints() >= 1 then
        local p, rel, rp, x, y = tab:GetPoint(1)
        if rel and not (rel.Icon and extras[rel]) and x then
            if not e.shiftedX or math.abs(x - e.shiftedX) > 0.5 then
                e.shiftedX = x - inset
                tab:SetPoint(p, rel, rp, e.shiftedX, y or 0)
            end
        end
    end
    -- Blizzard sets the icon back to its own size, place and tab-shaped
    -- mask when a tab is chosen, so they are put right on every pass.
    if icon and e.tile then
        if tab.Mask and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, tab.Mask) end
        local w = icon:GetWidth()
        if not w or math.abs(w - 34) > 0.5 then icon:SetSize(34, 34) end
        local p, rel = icon:GetPoint(1)
        if p ~= "CENTER" or rel ~= e.tile or icon:GetNumPoints() ~= 1 then
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", e.tile, "CENTER", 0, 0)
        end
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

PS.styleSideTab = styleSideTab

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
-- The lists inside a window (scroll boxes), found again on each full pass,
-- so a list that gains, loses or swaps rows is seen the frame it happens.
local function scrollTargets(f, depth, out)
    if depth > 7 or not f.GetChildren then return out end
    for _, c in ipairs({ f:GetChildren() }) do
        if c.ScrollTarget then out[#out + 1] = c.ScrollTarget end
        scrollTargets(c, depth + 1, out)
    end
    return out
end

local function fullSkin(frame, each)
    local poll = CreateFrame("Frame", nil, frame)
    local acc, last = 0.5, nil
    local targets = {}
    poll:SetScript("OnUpdate", function(_, e)
        local win = extras[frame] and extras[frame].backdrop
        if win and win.wuiTemplate ~= "Shadow" then ns:SetTemplate(win, "Shadow", { shadow = true }) end
        if each then each(frame) end
        local parts = {}
        for _, child in ipairs({ frame:GetChildren() }) do
            parts[#parts + 1] = child:IsShown() and "1" or "0"
        end
        -- Each list's shown rows and where the first one sits: a row added,
        -- a section opened, or the list scrolled onto new rows all change it.
        for _, t in ipairs(targets) do
            local n, top = 0, 0
            for _, row in ipairs({ t:GetChildren() }) do
                if row:IsShown() then
                    -- Blizzard inks list text for parchment as it fills a
                    -- row; ours goes on the same frame.
                    recolorText(row)
                    n = n + 1
                    if n == 1 then top = math.floor((row:GetTop() or 0) + 0.5) end
                end
            end
            parts[#parts + 1] = n .. ":" .. top
        end
        local sig = table.concat(parts, ",")
        acc = acc + e
        if sig ~= last or acc >= 0.5 then
            if acc >= 0.5 then targets = scrollTargets(frame, 1, {}) end
            last, acc = sig, 0
            walkProfessions(frame, 1)
        end
    end)
end
PS.fullSkin = fullSkin


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
        local sf = _G.SendMailScrollFrame
        if sf then
            noCard[_G.SendStationeryBackgroundLeft or sf] = true
            noCard[_G.SendStationeryBackgroundRight or sf] = true
            card(sf, "wuiLetter", "TOPLEFT", sf, "BOTTOMRIGHT", sf, -4, 6, 6, -6)
        end
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
        local sf = _G.OpenMailScrollFrame
        if sf then
            noCard[_G.OpenStationeryBackgroundLeft or sf] = true
            noCard[_G.OpenStationeryBackgroundRight or sf] = true
            card(sf, "wuiLetter", "TOPLEFT", sf, "BOTTOMRIGHT", sf, -4, 6, 6, -6)
        end
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

-- The guild window's side tabs (Chat, Roster, Benefits, Info), on
-- Blizzard's right-side tab: in the look of the Character window's side
-- tabs. A tile of ours for its black tab art, the icon cropped to the
-- tile, the accent ring in place of the yellow glow on the chosen one; at
-- rest the icon is greyed and dimmed, chosen or under the pointer it is in
-- colour. Looked at on every pass: the chosen tab changes.
local function styleRightTab(tab)
    if not tab or not tab.Icon then return end
    local e = extras[tab] or {}
    extras[tab] = e
    local icon = tab.Icon
    if not e.rightTab then
        e.rightTab = true
        for _, r in ipairs({ tab:GetRegions() }) do
            if r:GetObjectType() == "Texture" and r ~= icon and r ~= tab.IconOverlay then r:SetAlpha(0) end
        end
        for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture" }) do
            local t = tab[get] and tab[get](tab)
            if t then t:SetAlpha(0) end
        end
        local bd = backdrop(tab, "Shadow", false, -3)
        e.tile = bd
        ns:CropIcon(icon)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        local ring = tab:CreateTexture(nil, "OVERLAY", nil, 2)
        ns:SetRing(ring, bd)
        ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ring, "fel", "vertex", 1)
        ring:SetAllPoints(bd)
        e.ring = ring
    end
    local open = tab.GetChecked and tab:GetChecked() or false
    e.ring:SetShown(open)
    local awake = open or tab:IsMouseOver()
    icon:SetDesaturated(not awake)
    icon:SetAlpha(awake and 1 or 0.55)
end
PS.styleRightTab = styleRightTab

-- Guild & Communities: the full skin. The community list's blue backing
-- becomes a card (the walk does that from its Bg) and its gold filigree
-- goes; the chat and the member list get cards of their own, the guild
-- emblem watermark and the tabard portrait go.
PS.SPECIAL.CommunitiesFrame = function(frame)
    fullSkin(frame, function(f)
        styleMaxMin(f.MaximizeMinimizeFrame)
        local list = f.CommunitiesList
        if list and list.FilligreeOverlay then fadeRegions(list.FilligreeOverlay) end
        -- The community entries: their green and blue bars go for grey
        -- pills; the chosen one wears the accent ring. The guild emblem
        -- stays, its banner and border go.
        local target = list and list.ScrollBox and list.ScrollBox.ScrollTarget
        if target then
            for _, row in ipairs({ target:GetChildren() }) do
                if row.Selection and row.Background and row:IsShown() then
                    for _, k in ipairs({ "Background", "Selection", "GuildTabardBackground", "GuildTabardBorder", "IconRing" }) do
                        local t = row[k]
                        if t and t:GetAlpha() > 0 then t:SetAlpha(0) end
                    end
                    for _, r in ipairs({ row:GetRegions() }) do
                        if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "HIGHLIGHT" and not (extras[row] and extras[row].hover == r) then
                            r:SetAlpha(0)
                        end
                    end
                    local e = extras[row] or {}
                    extras[row] = e
                    if not e.ring then
                        local bd = backdrop(row, "Shadow", false, 0)
                        bd:ClearAllPoints()
                        bd:SetPoint("TOPLEFT", 6, -4)
                        bd:SetPoint("BOTTOMRIGHT", -6, 4)
                        local ring = row:CreateTexture(nil, "OVERLAY", nil, 2)
                        ns:SetRing(ring, bd)
                        ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
                        Chrome:Register(ring, "fel", "vertex", 1)
                        ring:SetAllPoints(bd)
                        e.ring = ring
                        local h = row:CreateTexture(nil, "HIGHLIGHT")
                        h:SetAllPoints(bd)
                        ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.12)
                        e.hover = h
                    end
                    e.ring:SetShown(row.Selection:IsShown())
                    if row.Name then row.Name:SetTextColor(C.text[1], C.text[2], C.text[3]) end
                end
            end
        end
        -- Their cards end flush on the right: each has its scroll bar in the
        -- gap beside it, and a card reaching past it ran out over the bar
        -- towards the window's edge.
        local members = f.MemberList
        if members and members:IsVisible() then
            if members.WatermarkFrame then fadeRegions(members.WatermarkFrame) end
            card(members, "wuiCard", "TOPLEFT", members, "BOTTOMRIGHT", members, -3, 3, 0, -3)
            -- The column headers over the roster: the walk's card for their
            -- backing is as wide as the backing, which runs on past the list
            -- and its scroll bar nearly to the window's edge. It ends where
            -- the list does.
            local cd = members.ColumnDisplay
            local cdc = cd and cd.Background and cards[cd.Background]
            if cdc and not cdc.wuiTrimmed then
                cdc:ClearAllPoints()
                cdc:SetPoint("TOPLEFT", cd.Background, "TOPLEFT", 0, 0)
                cdc:SetPoint("BOTTOMRIGHT", members, "TOPRIGHT", 0, 0)
                cdc.wuiTrimmed = true
            end
        end
        local chat = f.Chat
        if chat and chat:IsVisible() then
            card(chat, "wuiCard", "TOPLEFT", chat, "BOTTOMRIGHT", chat, -6, 4, 0, -4)
        end
        for _, k in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }) do
            local tab = f[k]
            if tab and tab:IsShown() then styleRightTab(tab) end
        end
    end)
    return "generic"
end

-- The calendar: the full skin. Each day's parchment becomes a black tile
-- (dimmer for the days of the months either side, which Blizzard marks by
-- darkening the parchment), the dark band behind event text goes, and the
-- holiday art stays, as it says what is on. Month arrows are small tiles.
PS.SPECIAL.CalendarFrame = function(frame)
    styleClose(rawget(_G, "CalendarCloseButton"))
    fullSkin(frame, function()
        styleStepper(rawget(_G, "CalendarPrevMonthButton"), "<")
        styleStepper(rawget(_G, "CalendarNextMonthButton"), ">")
        for i = 1, 42 do
            local b = rawget(_G, "CalendarDayButton" .. i)
            if not b then break end
            local e = extras[b] or {}
            extras[b] = e
            local dim = false
            for _, r in ipairs({ b:GetRegions() }) do
                if r:GetObjectType() == "Texture" and r ~= e.hover then
                    local layer = r:GetDrawLayer()
                    if layer == "BACKGROUND" then
                        local vr = r:GetVertexColor()
                        dim = vr and vr < 0.8 or false
                        if r:GetAlpha() > 0 then r:SetAlpha(0) end
                    elseif layer == "HIGHLIGHT" and r:GetAlpha() > 0 then
                        r:SetAlpha(0)
                    end
                end
            end
            local n = b:GetName()
            local band = rawget(_G, n .. "EventBackgroundTexture")
            if band and band:GetAlpha() > 0 then band:SetAlpha(0) end
            if not e.tile then
                local bd = backdrop(b, "Default", false, 2)
                ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
                e.tile = bd
                local h = b:CreateTexture(nil, "HIGHLIGHT")
                h:SetAllPoints(bd)
                ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.12)
                e.hover = h
            end
            e.tile:SetAlpha(dim and 0.45 or 1)
        end
    end)
    return "generic"
end

-- Collections and the transmog window: the full skin. The stone backing
-- and its corner scrollwork go (the walk turns the backing into a black
-- card); the slot buttons and models are left to Blizzard.
PS.SPECIAL.CollectionsJournal = function(frame)
    fullSkin(frame)
    return "generic"
end
PS.SPECIAL.WardrobeFrame = PS.SPECIAL.CollectionsJournal

-- Settings: the full skin. The category list and the settings beside it
-- are black cards on the grey window.
PS.SPECIAL.SettingsPanel = function(frame)
    styleClose(frame.ClosePanelButton)
    -- The Game and AddOns tabs along the top: Blizzard sets their label
    -- low, for its tall tab art, and small. As our tabs they are held
    -- centred, and their label is given a size the font pass keeps.
    local tabs = tabsOf(frame)
    for _, t in ipairs({ frame.GameTab, frame.AddOnsTab }) do tabs[#tabs + 1] = t end
    for _, tab in ipairs(tabs) do
        styleTab(tab)
        local text = tab.Text or (tab.GetFontString and tab:GetFontString())
        if text then
            fontSet[text] = 14
            text:SetFont(ns.Media:Font(), 14, "")
            text:ClearAllPoints()
            text:SetPoint("CENTER", tab, "CENTER", 0, 0)
        end
    end
    fullSkin(frame, function(f)
        if f.CategoryList then card(f.CategoryList, "wuiCard", "TOPLEFT", f.CategoryList, "BOTTOMRIGHT", f.CategoryList, -6, 6, 6, -6) end
        if f.Container then card(f.Container, "wuiCard", "TOPLEFT", f.Container, "BOTTOMRIGHT", f.Container, -6, 6, 6, -6) end
    end)
    return "generic"
end

-- The vendor, the auction house, Social, the group finder and the bags:
-- the full skin. Their lists, item buttons and tabs are handled by the
-- walk's general rules above.
-- The vendor: each item gets a small card of its own. Blizzard's name
-- plates are tall enough to earn a card from the walk, and five of them in
-- a column ran together into one long block, so they are kept out of it.
PS.SPECIAL.MerchantFrame = function(frame)
    fullSkin(frame, function()
        -- Two columns of items, centred: Blizzard sets them 11 px from the
        -- left and 7 from the right.
        local first, second = rawget(_G, "MerchantItem1"), rawget(_G, "MerchantItem2")
        if first and second and not InCombatLockdown() then
            local gap = 12
            local x = math.floor((frame:GetWidth() - first:GetWidth() * 2 - gap) / 2 + 0.5)
            local p, rel, rp, px, py = first:GetPoint(1)
            if p == "TOPLEFT" and rel == frame and math.abs((px or 0) - x) > 0.5 then
                first:ClearAllPoints()
                first:SetPoint("TOPLEFT", frame, "TOPLEFT", x, py or -69)
            end
        end
        for i = 1, 12 do
            local item = rawget(_G, "MerchantItem" .. i)
            if not item then break end
            local plate = rawget(_G, "MerchantItem" .. i .. "NameFrame")
            if plate then noCard[plate] = true; plate:SetAlpha(0) end
            if item:IsShown() then card(item, "wuiCard", "TOPLEFT", item, "BOTTOMRIGHT", item, -3, 3, 3, -3) end
        end
        local bb = rawget(_G, "MerchantBuyBackItemNameFrame")
        if bb then noCard[bb] = true; bb:SetAlpha(0) end
    end)
    return "generic"
end

-- The party and raid manager on the left edge. Its panel art goes for
-- ours; the marker grid sits on a card, a tile per marker. Blizzard shows
-- a marker's state (applied, selected, disabled) with the button's
-- background art, which is faded here and followed with ns:Follow, so
-- the tile's border carries the state instead. The Unit and Ground tabs,
-- the arrow that folds the panel and the leave buttons are ours; the
-- marker icons and the icon buttons stay as they are.
local MARKER_STATE = {
    ["GM-button-marker-applied"] = "fel", ["GM-button-marker-appliedSelected"] = "fel",
    ["GM-button-marker-selected"] = "text", ["GM-button-marker-pressed"] = "text",
}
local function markerAtlas(b)
    local bg = b.backgroundTexture
    return bg and bg.GetAtlas and bg:GetAtlas() or ""
end

local function markerState(b)
    local e = extras[b]
    if not (e and e.backdrop) then return end
    local atlas = markerAtlas(b)
    ns:SetBorderColor(e.backdrop, MARKER_STATE[atlas] or "border")
    local off = atlas == "GM-button-marker-disabled"
    e.backdrop:SetAlpha(off and 0.45 or 1)
    if b.markerTexture then b.markerTexture:SetAlpha(off and 0.45 or 1) end
end

local function styleMarker(b)
    if done[b] then return end
    done[b] = true
    fade(b.backgroundTexture)
    backdrop(b, "Shadow", false, 2)
    local e = extras[b]
    if not e.hover then
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetPoint("TOPLEFT", 3, -3)
        h:SetPoint("BOTTOMRIGHT", -3, 3)
        ns:Fill(h, 1, 1, 1, 0.12)
        e.hover = h
    end
    if b.backgroundTexture then ns:Follow(b, markerAtlas, markerState) end
    markerState(b)
end

-- The tabs change font object on hover and on being chosen, which would
-- undo a colour set on their text, so they are given font objects of ours.
local tabFonts = {}
local function tabFont(which)
    local f = tabFonts[which]
    if not f then
        f = CreateFont and CreateFont("WicksUI_MarkerTab_" .. which)
        if not f then return nil end
        tabFonts[which] = f
    end
    f:SetFont(ns.Media:Font(), 11, "")
    f:SetShadowOffset(1, -1)
    f:SetShadowColor(0, 0, 0, 1)
    local c = (which == "on" and C.fel) or (which == "hover" and C.text) or C.muted
    f:SetTextColor(c[1], c[2], c[3])
    return f
end

local function tabAtlas(tab)
    local nt = tab.GetNormalTexture and tab:GetNormalTexture()
    return nt and nt.GetAtlas and nt:GetAtlas() or ""
end

local function tabState(tab)
    local on = tabAtlas(tab) == "GM-tab-selected"
    local e = extras[tab]
    if e and e.backdrop then ns:SetBorderColor(e.backdrop, on and "fel" or "border") end
    local normal, hover = tabFont(on and "on" or "off"), tabFont(on and "on" or "hover")
    if normal then tab:SetNormalFontObject(normal) end
    if hover then tab:SetHighlightFontObject(hover) end
end

local function styleMarkerTab(tab)
    if not tab or done[tab] then return end
    done[tab] = true
    local nt = tab:GetNormalTexture()
    if nt then
        nt:SetAlpha(0)
        ns:Follow(tab, tabAtlas, tabState)
    end
    backdrop(tab, "Shadow", false, 0)
    tabState(tab)
end

local function styleFold(b, dir)
    if not b or done[b] then return end
    done[b] = true
    fadeRegions(b)
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(0) end
    end
    ns:Glyph(b, dir)
end

PS.SPECIAL.CompactRaidFrameManager = function(frame)
    fade(frame.Background)
    backdrop(frame, "Default", db().brackets)
    styleFold(frame.toggleButtonBack, "left")
    styleFold(frame.toggleButtonForward, "right")
    local dfr = frame.displayFrame
    if dfr then
        styleText(dfr.label, 14, C.fel)
        styleText(dfr.memberCountLabel, 14, C.text)
        styleText(dfr.RestrictPingsLabel, 12)
        for _, dd in ipairs({ dfr.RestrictPingsDropdown, dfr.ModeControlDropdown }) do
            if dd then pcall(styleDropdown, dd) end
        end
        local rm = dfr.raidMarkers
        if rm then
            fade(rm.BG)
            if rm.BG then card(rm, "wuiGrid", "TOPLEFT", rm.BG, "BOTTOMRIGHT", rm.BG, 0, 0, 0, 0) end
            for _, tab in ipairs(rm.Tabs or {}) do styleMarkerTab(tab) end
            for _, child in ipairs({ rm:GetChildren() }) do
                if child.markerTexture and child.backgroundTexture then styleMarker(child) end
            end
        end
    end
    local bb = frame.BottomButtons
    if bb then
        for _, b in ipairs({ bb:GetChildren() }) do
            if b:GetObjectType() == "Button" then styleButton(b) end
        end
    end
    -- The dividers between the icon buttons come from a pool, drawn again
    -- as the group changes, which is also when the leader's Party/Raid
    -- dropdown is shown or hidden: over the "Party" label, which Blizzard's
    -- solid dropdown art covered and our see-through one does not.
    local function hold()
        for _, pool in ipairs({ frame.dividerVerticalPool, frame.dividerHorizontalPool }) do
            if pool and pool.EnumerateActive then
                for t in pool:EnumerateActive() do t:SetAlpha(0) end
            end
        end
        local dd = dfr and dfr.ModeControlDropdown
        if dfr and dfr.label and dd then dfr.label:SetAlpha(dd:IsShown() and 0 or 1) end
    end
    hold()
    if rawget(_G, "CompactRaidFrameManager_UpdateOptionsFlowContainer") then
        hooksecurefunc("CompactRaidFrameManager_UpdateOptionsFlowContainer", hold)
    end
end

-- The stable (this client's is PetStableFrame, the Classic one): the full
-- skin. The model stands on our card (the walk makes it from the scene's
-- backing) with its own tint and the vignette round it gone; the vignette's
-- long top and bottom pieces would pass for backings, so they get no cards.
-- The pet slots are tiles (the walk), the chosen one in the accent ring;
-- the loyalty level sits on a small tile.
local function stableSlotRing(b)
    local e = extras[b] or {}
    extras[b] = e
    local ct = b.GetCheckedTexture and b:GetCheckedTexture()
    if ct and not e.ringSet then
        e.ringSet = true
        ns:SetRing(ct, b)
        ct:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ct, "fel", "vertex", 1)
        ct:ClearAllPoints()
        ct:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        ct:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    end
end

PS.SPECIAL.PetStableFrame = function(frame)
    fullSkin(frame, function(f)
        local ms = f.modelScene
        if ms then
            fade(ms.Background)
            local sh = ms.PetModelSceneShadow
            if sh then
                for _, r in ipairs({ sh:GetRegions() }) do
                    if r:GetObjectType() == "Texture" then noCard[r] = true; r:SetAlpha(0) end
                end
            end
        end
        for _, name in ipairs({ "PetStableCurrentPet", "PetStableStabledPet1", "PetStableStabledPet2",
            "PetStableStabledPet3", "PetStableStabledPet4" }) do
            local b = rawget(_G, name)
            if b then stableSlotRing(b) end
        end
        local ll = f.loyaltyLevel
        if ll then
            fadeRegions(ll)
            if not done[ll] then
                done[ll] = true
                backdrop(ll, "Shadow", false, -4)
            end
            styleText(ll.levelText, 12, C.fel)
        end
        styleText(rawget(_G, "PetStableLevelText"), 13, C.fel)
    end)
    return "generic"
end

-- Click cast bindings (Blizzard_ClickBindingUI). The full skin: a grey
-- window, the list on a black card, each binding a grey pill with its icon
-- on a black tile, as the pet and mount lists are drawn. Blizzard's own
-- markers are repainted rather than replaced, so they show and hide with
-- its state by themselves: a new binding waiting for its click wears the
-- accent ring, and so does each icon a held spell can go on. The empty
-- slot's green plus is our mark. The talents and macros buttons in the
-- corner are tiles, the accent ring on the one open beside the window.
-- The tutorial that opens with it is a window of its own, its painting
-- replaced by a small unit frame card of ours showing what it explains.
-- Rows are pooled and filled as the list changes: they are looked over on
-- every frame while the window shows, and refilled icons straight after
-- Blizzard fills them. Pieces already ours are skipped.
local EMPTY_SLOT = "clickcast-icon-add"

local function bindingIcon(row)
    local icon = row.Icon
    if not icon then return end
    if icon:GetAtlas() == EMPTY_SLOT then
        -- Drawn smaller than the slot: the mark, not a picture.
        icon:SetTexture(ns.Media:Glyph("plus"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon:SetTexCoord(-0.35, 1.35, -0.35, 1.35)
        icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
    else
        icon:SetVertexColor(1, 1, 1, 1)
        -- A picture from a file is cropped; one from an atlas would be cut.
        if not icon:GetAtlas() then ns:CropIcon(icon) end
    end
end
PS.bindingIcon = bindingIcon

local function styleBindingRow(row)
    local e = extras[row] or {}
    extras[row] = e
    for _, k in ipairs({ "Background", "FrameHighlight" }) do
        local t = row[k]
        if t and t:GetAlpha() > 0 then t:SetAlpha(0) end
    end
    if e.binding then return end
    e.binding = true
    local lvl = row:GetFrameLevel()
    local pill = backdrop(row, "Shadow", false, 0)
    pill:SetFrameLevel(math.max(0, lvl - 2))
    local h = row:CreateTexture(nil, "HIGHLIGHT")
    h:SetAllPoints(pill)
    ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.1)
    local icon = row.Icon
    if icon then
        local tile = CreateFrame("Frame", nil, row)
        tile:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        tile:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        tile:SetFrameLevel(math.max(0, lvl - 1))
        ns:SetTemplate(tile, "Default", { alpha = 0.9, shadow = false })
        e.tile = tile
    end
    local function accent(t, host)
        ns:SetRing(t, host)
        t:SetBlendMode("BLEND")
        t:ClearAllPoints()
        t:SetAllPoints(host)
        t:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(t, "fel", "vertex", 1)
    end
    if row.NewOutline then accent(row.NewOutline, pill) end
    if row.IconHighlight and e.tile then accent(row.IconHighlight, e.tile) end
    local add = row.EmptySlotIconHighlight
    if add and icon then
        add:SetTexture(ns.Media:Glyph("plus"))
        add:SetTexCoord(0, 1, 0, 1)
        add:SetBlendMode("BLEND")
        add:ClearAllPoints()
        add:SetPoint("CENTER", icon, "CENTER", 0, 0)
        add:SetSize(18, 18)
        add:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(add, "fel", "vertex", 1)
    end
    if row.DeleteButton then ns:Glyph(row.DeleteButton, "close") end
    bindingIcon(row)
    if row.Init then hooksecurefunc(row, "Init", bindingIcon) end
end

-- The corner buttons: a tile each, the accent ring on the chosen one.
local function stylePortraitButton(p)
    local e = extras[p] or {}
    extras[p] = e
    if not e.portrait then
        e.portrait = true
        for _, r in ipairs({ p:GetRegions() }) do
            if r:GetObjectType() == "Texture" and r ~= p.Portrait then r:SetAlpha(0) end
        end
        local tile = backdrop(p, "Default", false, 0)
        ns:SetTemplate(tile, "Default", { alpha = 0.9, shadow = false })
        local art = p.Portrait
        if art then
            art:ClearAllPoints()
            art:SetPoint("TOPLEFT", 2, -2)
            art:SetPoint("BOTTOMRIGHT", -2, 2)
            if not art:GetAtlas() then ns:CropIcon(art) end
        end
        local ring = p:CreateTexture(nil, "OVERLAY", nil, 2)
        ns:SetRing(ring, tile)
        ring:SetAllPoints(tile)
        ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ring, "fel", "vertex", 1)
        e.ring = ring
        local hover = p:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(tile)
        ns:Fill(hover, 1, 1, 1, 0.12)
    end
    local un = p.UnselectedFrame
    e.ring:SetShown(not (un and un:IsShown()))
end

-- The help button: Blizzard's ring and its big "i" go for a small tile
-- with a question mark, inside the window's top edge where it already sits.
local function styleHelpButton(b)
    local e = extras[b] or {}
    extras[b] = e
    for _, k in ipairs({ "I", "Ring" }) do
        if b[k] and b[k]:GetAlpha() > 0 then b[k]:SetAlpha(0) end
    end
    -- Its pulse is an animation on alpha, so these are hidden instead.
    for _, k in ipairs({ "BigIPulse", "RingPulse" }) do
        if b[k] and b[k]:IsShown() then b[k]:Hide() end
    end
    if e.help then return end
    e.help = true
    local hl = b.GetHighlightTexture and b:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    local tile = CreateFrame("Frame", nil, b)
    tile:SetPoint("CENTER", b, "CENTER", 0, 0)
    tile:SetSize(20, 20)
    tile:SetFrameLevel(math.max(0, b:GetFrameLevel() - 1))
    ns:SetTemplate(tile, "Default", { alpha = 0.9, shadow = false })
    local q = ns:CreateText(tile, 13, "CENTER", "NONE")
    q:SetPoint("CENTER", 0, 0)
    q:SetText("?")
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(tile)
    ns:Fill(hover, C.fel[1], C.fel[2], C.fel[3], 0.18)
end

-- The tutorial: a window of ours, its words in the Wick type, and in
-- place of the painting a unit frame card with a name, a bar and the
-- accent's plus marks where you click.
local function tutorialExample(tf)
    local ex = CreateFrame("Frame", nil, tf)
    ex:SetSize(172, 42)
    ex:SetPoint("CENTER", tf, "CENTER", -118, -2)
    ex:SetFrameLevel(tf:GetFrameLevel() + 1)
    ns:SetTemplate(ex, "Default", { alpha = 0.9 })
    local r, g, b = ns:ClassColor("SHAMAN")
    local name = ns:CreateText(ex, 12, "LEFT")
    name:SetPoint("TOPLEFT", 8, -6)
    name:SetText(rawget(_G, "THRALL_NAME") or "Thrall")
    ns:TextColor(name, { r, g, b })
    local track = ex:CreateTexture(nil, "ARTWORK")
    track:SetPoint("BOTTOMLEFT", 8, 8)
    track:SetPoint("BOTTOMRIGHT", -8, 8)
    track:SetHeight(8)
    ns:Fill(track, 1, 1, 1, 0.07)
    local fill = ex:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(100)
    ns:BarTexture(fill)
    fill:SetVertexColor(r, g, b, 1)
    for i, s in ipairs({ 16, 11 }) do
        local mark = ex:CreateTexture(nil, "OVERLAY")
        mark:SetTexture(ns.Media:Glyph("plus"))
        mark:SetSize(s, s)
        mark:SetPoint("CENTER", ex, "RIGHT", i == 1 and -4 or 9, i == 1 and 6 or -9)
        mark:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(mark, "fel", "vertex", 1)
    end
    return ex
end

local function styleTutorial(tf)
    local e = extras[tf] or {}
    extras[tf] = e
    if e.tutorial then return end
    e.tutorial = true
    -- Its painting and panel go, and are not carded over as content.
    for _, r in ipairs({ tf:GetRegions() }) do
        if r:GetObjectType() == "Texture" then noCard[r] = true; r:SetAlpha(0) end
    end
    for _, k in ipairs({ "Tutorial", "Bg" }) do
        if tf[k] then noCard[tf[k]] = true; fade(tf[k]) end
    end
    fade(tf.NineSlice); fade(tf.PortraitContainer); fade(tf.TopTileStreaks)
    local bd = backdrop(tf, "Shadow", db().brackets, 0)
    ns:SetTemplate(bd, "Shadow", { shadow = true, brackets = db().brackets })
    bd:SetFrameLevel(math.max(0, tf:GetFrameLevel() - 2))
    local title = tf.TitleContainer and tf.TitleContainer.TitleText
    styleText(title, 14, C.fel)
    styleClose(tf.CloseButton)
    styleText(tf.SummaryText, 16, C.text)
    styleText(tf.InfoText, 13, C.text)
    styleText(tf.AlternateText, 12, C.muted)
    if tf.ThrallName then tf.ThrallName:SetAlpha(0) end
    e.example = tutorialExample(tf)
end
PS.styleTutorial = styleTutorial

local function clickBindingPass(f)
    local sbb = f.ScrollBoxBackground
    if sbb then
        -- Its tooltip border goes; a black card takes the list.
        fade(sbb.NineSlice)
        card(sbb, "list", "TOPLEFT", sbb, "BOTTOMRIGHT", sbb)
    end
    local target = f.ScrollBox and f.ScrollBox.ScrollTarget
    if target then
        for _, row in ipairs({ target:GetChildren() }) do
            if row:IsShown() then
                if row.BindingText then
                    styleBindingRow(row)
                elseif row.Name then
                    -- A section heading, in the accent like the window's own.
                    styleText(row.Name, 12, C.fel)
                end
            end
        end
    end
    for _, p in ipairs(f.FramePortraits or {}) do stylePortraitButton(p) end
    if f.TutorialButton then styleHelpButton(f.TutorialButton) end
    if f.TutorialFrame then styleTutorial(f.TutorialFrame) end
end
PS.clickBindingPass = clickBindingPass

PS.SPECIAL.ClickBindingFrame = function(frame)
    fullSkin(frame, clickBindingPass)
    clickBindingPass(frame)
    return "generic"
end

-- The Legacy window (Blizzard_LegacySystem, this client's own; the older
-- builds' LegacyFrame stays on the list too). The common skin, with its
-- three page tabs drawn as the side tabs elsewhere, which they are built
-- from: styled before the common pass, so it leaves them be, and again on
-- every frame, since Blizzard resets a chosen tab's icon. Its pages keep
-- their own art until they have been seen in game.
PS.SPECIAL.LegacySystemFrame = function(frame)
    local function tabs(f)
        for _, tab in ipairs(f.Tabs or {}) do
            if tab.Icon and tab:IsShown() then styleSideTab(tab) end
        end
    end
    tabs(frame)
    local poll = CreateFrame("Frame", nil, frame)
    poll:SetScript("OnUpdate", function() if db().enable then tabs(frame) end end)
    return "generic"
end

-- The group finder's listing page (Looking For Group). Its category buttons
-- lose their painted banners and gold frames for our tiles; in the looks
-- the painted art sat apart from everything round it. The role picker
-- loses its coloured glow rings: tank, healer and damage take the plain
-- role icons on a tile, the "new player friendly" flag keeps its own
-- picture on one. A chosen role wears the accent ring in colour; one not
-- chosen is greyed and dimmed, and dimmer still where the class cannot
-- take it. Looked at on every pass: the choices change as you click.
local ROLE_ICON = { TANK = "groupfinder-icon-role-large-tank", HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps" }

-- A tile in a fully skinned window: the window itself wears the Shadow
-- template, so a Shadow tile vanishes into it; its buttons are Default, a
-- touch see-through, with no lift. The same here, and one size for all:
-- a tile made earlier (by the generic pass) is put to the same place.
local function lfgTile(b, inset)
    local e = extras[b] or {}
    extras[b] = e
    local bd = backdrop(b, "Default", false, inset)
    if not e.lfgTile then
        e.lfgTile = true
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
        bd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
        ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
    end
    return bd
end

local function styleCategoryButton(b)
    for _, r in ipairs({ b:GetRegions() }) do
        local a = r:GetObjectType() == "Texture" and r.GetAtlas and r:GetAtlas()
        if a and a:find("^groupfinder%-button") and r:GetAlpha() > 0 then r:SetAlpha(0) end
    end
    local e = extras[b] or {}
    extras[b] = e
    if not e.category then
        e.category = true
        local bd = lfgTile(b, 4)
        if not e.hover then
            local h = b:CreateTexture(nil, "HIGHLIGHT")
            h:SetAllPoints(bd)
            ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.12)
            e.hover = h
        end
    end
    if b.Label then b.Label:SetTextColor(C.text[1], C.text[2], C.text[3]) end
end

local function styleRoleButton(b, atlas)
    local e = extras[b] or {}
    extras[b] = e
    if not e.role then
        e.role = true
        if b.Background then b.Background:SetAlpha(0) end
        if b.cover then b.cover:SetAlpha(0) end
        local nt = b.GetNormalTexture and b:GetNormalTexture()
        if nt and atlas then
            nt:SetAtlas(atlas)
            nt:ClearAllPoints()
            nt:SetPoint("CENTER", b, "CENTER", 0, 0)
            nt:SetSize(34, 34)
        end
        e.icon = nt
        local w = b:GetWidth() or 64
        local bd = lfgTile(b, math.max(0, math.floor((w - 48) / 2)))
        local ring = b:CreateTexture(nil, "OVERLAY", nil, 2)
        ns:SetRing(ring, bd)
        ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(ring, "fel", "vertex", 1)
        ring:SetAllPoints(bd)
        e.ring = ring
    end
    local cb = b.CheckButton
    local on = cb and cb:GetChecked() and true or false
    e.ring:SetShown(on)
    if e.icon then
        e.icon:SetDesaturated(not on)
        local able = not (b.IsEnabled and not b:IsEnabled())
        e.icon:SetAlpha(on and 1 or (able and 0.55 or 0.25))
    end
end

PS.styleRoleButton = styleRoleButton

PS.SPECIAL.LFGListingFrame = function(frame)
    fullSkin(frame, function(f)
        if f.RolesSection then fadeRegions(f.RolesSection) end
        local cv = f.CategoryView
        if cv and cv.GetChildren then
            for _, b in ipairs({ cv:GetChildren() }) do
                if b.Icon and b.Cover and b.Label then styleCategoryButton(b) end
            end
        end
        local srb = f.SoloRoleButtons
        if srb and srb.RoleButtons then
            for _, b in ipairs(srb.RoleButtons) do styleRoleButton(b, ROLE_ICON[b.roleID or ""]) end
        end
        if f.NewPlayerFriendlyButton then styleRoleButton(f.NewPlayerFriendlyButton, nil) end
    end)
    return "generic"
end

-- The reward you have chosen. Blizzard marks it by moving one highlight
-- frame onto it, painted with a gold glow that the art pass takes away
-- with the rest of the parchment's art, so nothing showed. The chosen
-- reward wears the accent ring round its icon and an accent wash behind
-- its name instead, read from Blizzard's own choice on every frame.
local function markRewardChoice()
    local rf = rawget(_G, "QuestInfoRewardsFrame")
    if not (rf and rf:IsVisible()) then return end
    local qi = rawget(_G, "QuestInfoFrame")
    local choice = qi and qi.itemChoice
    for _, b in ipairs(rf.RewardButtons or {}) do
        local icon = b.Icon
        if icon and b:IsShown() then
            local e = extras[b] or {}
            extras[b] = e
            if not e.choiceRing then
                local ring = b:CreateTexture(nil, "OVERLAY", nil, 7)
                ns:SetRing(ring, b)
                ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
                ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
                ring:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
                Chrome:Register(ring, "fel", "vertex", 1)
                -- Behind the name, over Blizzard's name plate.
                local wash = b:CreateTexture(nil, "BORDER", nil, -8)
                wash:SetPoint("TOPLEFT", icon, "TOPRIGHT", 2, 0)
                wash:SetPoint("BOTTOM", icon, "BOTTOM", 0, 0)
                wash:SetPoint("RIGHT", b, "RIGHT", -2, 0)
                ns:Fill(wash, C.fel[1], C.fel[2], C.fel[3], 0.18)
                e.choiceRing, e.choiceWash = ring, wash
            end
            local chosen = b.type == "choice" and type(choice) == "number" and choice > 0 and b:GetID() == choice
            e.choiceRing:SetShown(chosen)
            e.choiceWash:SetShown(chosen)
        end
    end
end
PS.markRewardChoice = markRewardChoice

-- The talking windows: one black card over the content (the Inset), the
-- parchment's pieces stripped without cards of their own.
for _, name in ipairs({ "GossipFrame", "QuestFrame", "QuestLogPopupDetailFrame", "ItemTextFrame" }) do
    PS.SPECIAL[name] = function(frame)
        fullSkin(frame, function(f)
            if name == "QuestFrame" then markRewardChoice() end
            local host = f.Inset or f
            if host:IsVisible() then
                local c
                if host == f then
                    c = card(f, "wuiContent", "TOPLEFT", f, "BOTTOMRIGHT", f, 8, -62, -8, 34)
                else
                    c = card(host, "wuiContent", "TOPLEFT", host, "BOTTOMRIGHT", host, 4, -4, -4, 4)
                end
                -- Above the window's own panel (which sits a level under the
                -- window), under the text and buttons.
                local want = f:GetFrameLevel()
                if c:GetFrameLevel() ~= want then c:SetFrameLevel(want) end
            end
        end)
        return "generic"
    end
end

-- Inspect: the full skin, and its side tabs (the Character window's kind)
-- held in our style every frame.
PS.SPECIAL.InspectFrame = function(frame)
    fullSkin(frame, function()
        local tabs = rawget(_G, "InspectUITabs")
        if tabs and PS.styleSideTab then
            for _, tab in ipairs({ tabs:GetChildren() }) do
                if tab.Icon and tab:IsShown() then PS.styleSideTab(tab) end
            end
        end
    end)
    return "generic"
end

-- Tabs on Blizzard's newer tab system (the friends window's Friends and
-- Recent Allies): the chosen tab's font object is set from a field on the
-- tab each time one is chosen, which would undo a font set on its text.
-- After Blizzard's own choice (a post-hook), ours: the accent for the
-- chosen tab, the muted colour for the rest.
local sysTabs = setmetatable({}, { __mode = "k" })
local function systemTabFonts(tab, selected)
    if selected == nil then selected = tab.IsEnabled and not tab:IsEnabled() end
    local normal, hover = tabFont(selected and "on" or "off"), tabFont(selected and "on" or "hover")
    if normal then
        tab:SetNormalFontObject(normal)
        if tab.SetDisabledFontObject then tab:SetDisabledFontObject(normal) end
    end
    if hover then tab:SetHighlightFontObject(hover) end
end
local function styleSystemTab(tab)
    if not tab or sysTabs[tab] or not tab.SetTabSelected then return end
    sysTabs[tab] = true
    hooksecurefunc(tab, "SetTabSelected", function(t, sel) systemTabFonts(t, sel) end)
    systemTabFonts(tab)
end
PS.styleSystemTab = styleSystemTab

-- The friends window: the full skin, its tabs as above, and the friend rows
-- in the look's font. The rows are drawn from shared font families, so
-- setting those restyles every row, the ones made later too; their sizes
-- stay.
PS.SPECIAL.FriendsFrame = function(frame)
    for _, name in ipairs({ "FriendsFont_Normal", "FriendsFont_Small", "FriendsFont_Large", "FriendsFont_UserText", "FriendsFont_11" }) do
        local fo = rawget(_G, name)
        if fo and fo.GetFont and fo.SetFont then
            local _, size, flags = fo:GetFont()
            if size and size > 0 then fo:SetFont(ns.Media:Font(), size, flags or "") end
        end
    end
    fullSkin(frame, function(f)
        local ts = f.FriendsTabHeader and f.FriendsTabHeader.TabSystem
        if ts and ts.GetChildren then
            for _, tab in ipairs({ ts:GetChildren() }) do styleSystemTab(tab) end
        end
    end)
    return "generic"
end

-- (The flight map is not here: its map is Blizzard art, and the full skin
-- would strip it. It keeps the lighter skin every window gets.)
for _, name in ipairs({ "MerchantFrame", "AuctionHouseFrame", "FriendsFrame", "LFGParentFrame", "ClassTrainerFrame",
    "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3",
    "ContainerFrame4", "ContainerFrame5", "ContainerFrame6" }) do
    if not PS.SPECIAL[name] then
        PS.SPECIAL[name] = function(frame)
            fullSkin(frame)
            return "generic"
        end
    end
end

-- The dressing room: the painted backdrop behind the model goes for one of
-- our cards, and the outfit list beside it loses its stone frame and class
-- art for a card of its own. The model itself, and the item icons and
-- names in the list, are content and stay. Held every pass: Blizzard sets
-- the backdrop again for each race and class it shows.
PS.SPECIAL.DressUpFrame = function(frame)
    fullSkin(frame, function(f)
        fade(f.ModelBackground)
        local ms = f.ModelScene
        if ms then
            -- The backdrop is four painted tiles on the model scene itself.
            for _, k in ipairs({ "BGTopLeft", "BGTopRight", "BGBottomLeft", "BGBottomRight" }) do
                local t = ms[k]
                if t and t:GetAlpha() > 0 then t:SetAlpha(0) end
            end
            card(ms, "wuiCard", "TOPLEFT", ms, "BOTTOMRIGHT", ms, 0, 0, 0, 0)
        end
        -- The item list beside the model: its black backing, faded class
        -- art and gold side frame are the panel's own textures; the rows
        -- (icons, names) are children and stay. The card sits where the
        -- black backing was.
        local od = f.CustomSetDetailsPanel or f.OutfitDetailsPanel
        if od then
            for _, r in ipairs({ od:GetRegions() }) do
                if r:GetObjectType() == "Texture" and r:GetAlpha() > 0 then r:SetAlpha(0) end
            end
            fade(od.NineSlice)
            -- Lined up with the window: its top and bottom, 4 px off its
            -- right edge, as wide as the list. Blizzard's backing starts
            -- lower and runs longer, for its own side frame art.
            local c = card(od, "wuiCard", "TOPLEFT", od, "BOTTOMRIGHT", od, 0, 0, 0, 0)
            if not c.wuiPlaced then
                c.wuiPlaced = true
                local bb = od.BlackBackground
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
                c:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 4, 0)
                c:SetWidth((bb and bb:GetWidth() and bb:GetWidth() > 0) and bb:GetWidth() or 301)
            end
        end
    end)
    return "generic"
end

-- The game's bags stack up from the bottom right of the screen, and Blizzard
-- lays them out again whenever one opens or closes. Straight after it
-- does, a bag window that would cover the damage meter is lifted to sit
-- just above the meter's top; the ones stacked on it follow. Only while
-- the meter shows and is under the bags, and only ever up: Blizzard's own
-- place stands otherwise. Checked again while bags are open, as the meter
-- can move.
local BAG_WINDOWS = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3",
    "ContainerFrame4", "ContainerFrame5", "ContainerFrame6" }
-- The game's own meter windows, and Details' where a client has no meter
-- of its own (TBC Anniversary); a Details window wears a title bar above
-- its base frame.
local METERS = { "DamageMeterSessionWindow1", "DamageMeterSessionWindow2", "DamageMeterSessionWindow3",
    "DetailsBaseFrame1", "DetailsBaseFrame2", "DetailsBaseFrame3", "DetailsBaseFrame4" }
local function meterTopUnder(f)
    local fl, fr = f:GetLeft(), f:GetRight()
    if not (fl and fr) then return end
    local fs = f:GetEffectiveScale()
    local best
    for _, name in ipairs(METERS) do
        local win = rawget(_G, name)
        if win and win:IsVisible() then
            local l, r, t = win:GetLeft(), win:GetRight(), win:GetTop()
            if l and r and t then
                local ms = win:GetEffectiveScale()
                if name:find("^Details") then t = t + 20 end
                if not (r * ms < fl * fs or l * ms > fr * fs) then
                    best = math.max(best or 0, t * ms)
                end
            end
        end
    end
    return best
end
function PS:ClearMeter()
    if not (db().enable and db().bagsClearMeter) then return end
    local us = UIParent:GetEffectiveScale()
    for _, name in ipairs(BAG_WINDOWS) do
        local f = rawget(_G, name)
        if f and f:IsShown() and f:GetNumPoints() >= 1 then
            local p, rel, rp, x, y = f:GetPoint(1)
            if rel == UIParent and p and p:find("BOTTOM") and y then
                local top = meterTopUnder(f)
                if top then
                    local want = (top + 6 * us) / f:GetEffectiveScale()
                    if y < want - 0.5 then f:SetPoint(p, rel, rp, x, want) end
                end
            end
        end
    end
end
if UpdateContainerFrameAnchors then
    hooksecurefunc("UpdateContainerFrameAnchors", function() pcall(PS.ClearMeter, PS) end)
end
do
    local acc = 0
    local t = CreateFrame("Frame")
    t:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.5 then return end
        acc = 0
        pcall(PS.ClearMeter, PS)
    end)
end

-- The flight map: the map itself is the window's InsetBg texture, which
-- the fade every window gets would put away with the frame art. It is
-- kept drawn, and held so (Blizzard redraws it as the map opens).
PS.SPECIAL.TaxiFrame = function(frame)
    local keep = CreateFrame("Frame", nil, frame)
    keep:SetScript("OnUpdate", function()
        local map = frame.InsetBg or rawget(_G, "TaxiFrameInsetBg")
        if map and map:GetAlpha() < 1 then map:SetAlpha(1) end
    end)
    return "generic"
end

-- The talents tab. The painting behind the trees (ClassBackground) stays,
-- as Wick wants; the brown frame around it (BackgroundBorder, with the gold
-- bar across the top and the edge along the bottom) goes, the tree headers
-- lose their scrollwork and ring, and the Primary and Secondary tabs go
-- flat. Headers are pooled, so this runs while the tab is open.
-- The painting goes (Wick chose cards over it, 2026-09-28), with the
-- clouds and particles Blizzard animates over it; each tree becomes a
-- black card on the grey window.
local PAINT = { "ClassBackground", "OverlayBackgroundRight", "OverlayBackgroundMid", "BackgroundFlash",
    "Clouds1", "Clouds2", "AirParticlesClose", "AirParticlesFar" }
local function treeCards(tf)
    for _, k in ipairs(PAINT) do
        local t = tf[k]
        if t then t:SetAlpha(0); if k ~= "ClassBackground" then t:Hide() end end
    end
    fade(tf.DividerVerticalLeft)
    fade(tf.DividerVerticalRight)
    local cb = tf.ClassBackground
    local w = cb and cb:GetWidth()
    if not (w and w > 0) then return end
    local e = extras[tf] or {}
    extras[tf] = e
    e.trees = e.trees or {}
    local third = w / 3
    for i = 1, 3 do
        local c = e.trees[i]
        if not c then
            c = CreateFrame("Frame", nil, tf)
            c:SetFrameLevel(math.max(0, tf:GetFrameLevel() - 1))
            ns:SetTemplate(c, "Default", { alpha = 0.9, shadow = false })
            e.trees[i] = c
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", cb, "TOPLEFT", third * (i - 1) + 6, -6)
        c:SetPoint("BOTTOMRIGHT", cb, "BOTTOMLEFT", third * i - 6, 6)
    end
end

-- Talent nodes: Blizzard's square frames (StateBorder, its hover twin,
-- the drop shadow, the sheen that sweeps across, the glows) go. Each node
-- is a tile with a ring for its state, read from the frame Blizzard
-- picked. A look's accent can be any colour (a priest's is white, a
-- hunter's green), so the states differ by weight, not by hue: one that
-- can take a point has a heavy ring in the accent, a maxed one a quiet
-- ring in the accent over a light accent wash, one open but not yet
-- affordable a ring in the border colour, a locked one no ring at all
-- (Blizzard's own dark overlay already dims those). Run every frame while
-- the tab shows, so a point spent repaints at once.
local NODE_FADE = { "StateBorder", "StateBorderHover", "Shadow", "BorderSheen", "Glow", "SelectableGlow" }
local function nodeState(atlas)
    atlas = atlas and atlas:lower() or ""
    if atlas:find("yellow") or atlas:find("gold") then return "maxed" end
    if atlas:find("green") then return "spendable" end
    if atlas:find("gray") or atlas:find("grey") then return "open" end
end
PS.nodeState = nodeState
local function styleNodes(tf)
    local bp = tf.ButtonsParent
    if not bp then return end
    for _, b in ipairs({ bp:GetChildren() }) do
        local sb = b.StateBorder
        if sb and b.Icon and b:IsShown() then
            local state = nodeState(sb:GetAtlas())
            for _, k in ipairs(NODE_FADE) do
                local t = b[k]
                if t and t:GetAlpha() > 0 then t:SetAlpha(0) end
            end
            local e = extras[b] or {}
            extras[b] = e
            if not e.ring then
                local bd = backdrop(b, "Default", false, 0)
                bd:ClearAllPoints()
                bd:SetPoint("TOPLEFT", b.Icon, "TOPLEFT", -2, 2)
                bd:SetPoint("BOTTOMRIGHT", b.Icon, "BOTTOMRIGHT", 2, -2)
                ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
                local ring = b:CreateTexture(nil, "OVERLAY", nil, 1)
                ns:SetRing(ring, bd)
                ring:SetAllPoints(bd)
                -- The heavy ring: a second one a pixel inside the first.
                local inner = b:CreateTexture(nil, "OVERLAY", nil, 1)
                ns:SetRing(inner, bd)
                inner:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
                inner:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
                local wash = b:CreateTexture(nil, "OVERLAY", nil, 0)
                wash:SetAllPoints(bd)
                ns:Fill(wash, C.fel[1], C.fel[2], C.fel[3], 0.18)
                e.ring, e.inner, e.wash = ring, inner, wash
            end
            local f, g = C.fel, C.border
            if state == "spendable" then
                e.ring:SetVertexColor(f[1], f[2], f[3], 1)
                e.inner:SetVertexColor(f[1], f[2], f[3], 1)
            elseif state == "maxed" then
                e.ring:SetVertexColor(f[1], f[2], f[3], 0.55)
            elseif state == "open" then
                e.ring:SetVertexColor(g[1], g[2], g[3], 1)
            end
            e.ring:SetShown(state ~= nil)
            e.inner:SetShown(state == "spendable")
            e.wash:SetShown(state == "maxed")
        end
    end
end
PS.styleNodes = styleNodes

local function styleTalents(tf)
    treeCards(tf)
    -- The search options button: its yellow arrow greyed on a black tile.
    local so = tf.SearchOptionsDropdown
    if so then ns:Glyph(so, "down") end
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

-- The beta's bug-report button (a bug in a gold ring, top left): kept, as
-- it is how feedback reaches Blizzard, but as a small tile in our style.
local function styleBugButton(b)
    if not b or done[b] then return end
    done[b] = true
    fade(b.Ring); fade(b.RingPulse)
    for _, r in ipairs({ b:GetRegions() }) do
        if r:GetObjectType() == "Texture" and r:GetDrawLayer() == "HIGHLIGHT" then r:SetAlpha(0) end
    end
    local icon = b.Bug
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", 0, 0)
        icon:SetSize(22, 22)
        ns:CropIcon(icon)
        local bd = backdrop(b, "Default", false, 0)
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
        bd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
        ns:SetTemplate(bd, "Default", { alpha = 0.9, shadow = false })
        local h = b:CreateTexture(nil, "HIGHLIGHT")
        h:SetAllPoints(bd)
        ns:Fill(h, C.fel[1], C.fel[2], C.fel[3], 0.18)
    end
end

PS.SPECIAL.PlayerSpellsFrame = function(frame)
    styleBugButton(frame.TabSetBugButton)
    local tf = frame.TalentsFrame
    if tf then
        local poll = CreateFrame("Frame", nil, tf)
        local acc = 0.5
        poll:SetScript("OnUpdate", function(_, e)
            -- The window is the grey panel while the talents show, as in
            -- the other full-skin windows; the spellbook keeps its own look.
            local win = extras[frame] and extras[frame].backdrop
            if win and win.wuiTemplate ~= "Shadow" then ns:SetTemplate(win, "Shadow", { shadow = true }) end
            styleNodes(tf)
            acc = acc + e
            if acc < 0.5 then return end
            acc = 0
            styleTalents(tf)
            styleBugButton(frame.TabSetBugButton)
        end)
        poll:SetScript("OnHide", function()
            local win = extras[frame] and extras[frame].backdrop
            if win and win.wuiTemplate ~= "Default" then ns:SetTemplate(win, "Default", { alpha = db().alpha }) end
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

-- The pieces the Classic window pass (PanelsClassic.lua) builds on, shared
-- here rather than copied there, so a look's change to a button or a tab
-- reaches both kinds of window.
PS.H = {
    done = done, extras = extras, noCard = noCard,
    fade = fade, fadeRegions = fadeRegions, backdrop = backdrop, card = card,
    styleText = styleText, styleButton = styleButton, styleClose = styleClose, styleEditBox = styleEditBox,
    styleItemButton = styleItemButton, styleSlot = styleSlot, paintSlots = paintSlots,
    scanButtons = scanButtons, recolorText = recolorText, isIcon = isIcon, isOwn = isOwn,
}

function PS:Skin(frame)
    if not frame or done[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    if screenSized(frame) then return end
    local name = frame:GetName()
    if name and excluded(name) then return end
    -- On a client whose windows are the old Classic kind (TBC Anniversary),
    -- a window without the portrait template's parts has nothing the pass
    -- below undresses, and a backdrop cut to its full rect would stand
    -- proud of its art. The Classic pass (PanelsClassic.lua) knows those
    -- windows' shapes and takes them whole. A dialog (a border or a
    -- background piece that fills its rect) is the same shape on every
    -- client and takes the pass below; anything else of the old kind keeps
    -- Blizzard's art.
    if ns.Core.Client.classicWindows and not (frame.NineSlice or frame.PortraitContainer or frame.TitleContainer) then
        if PS.Classic and PS.Classic:Claim(frame, name) then done[frame] = true return end
        if not (frame.Border or frame.BG or frame.Bg or frame.Center) then return end
    end
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
    -- On a client whose windows are the old kind, the portrait-template
    -- windows still hold old widgets (named tab pieces, scroll bars, text
    -- boxes): the Classic pass looks those over, before the scan below.
    if PS.Classic and ns.Core.Client.classicWindows then PS.Classic:Attach(frame) end
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

-- Blizzard's dropdown menus (every dropdown in the game opens one): the
-- parchment-dark backing becomes our card, check boxes our small fields
-- with the tick in the accent, the hover bar a fel wash, the text our
-- font. The menu's rows are pooled and rebuilt as it opens, so the open
-- menu is looked over every frame; pieces already ours are skipped.
-- Menu text keeps Blizzard's font objects: the menu's compositor forbids
-- SetFont, and swapping the font object broke how it shows enabled and
-- disabled rows (they came out dark).
local function styleMenuRow(b)
    for _, r in ipairs({ b:GetRegions() }) do
        local kind = r:GetObjectType()
        if kind == "Texture" then
            local a = r:GetAtlas()
            if a then
                local al = a:lower()
                if al:find("checkmark") or al:find("radialtick") then
                    r:SetDesaturated(true)
                    r:SetVertexColor(C.fel[1], C.fel[2], C.fel[3], 1)
                    Chrome:Register(r, "fel", "vertex", 1)
                elseif al:find("ticksquare") or al:find("tickradial") then
                    ns:Fill(r, C.shadow[1], C.shadow[2], C.shadow[3], 1)
                elseif al:find("divider") then
                    r:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.8)
                end
            elseif r:GetTexture() == 136810 then
                -- The hover bar Blizzard shows under the row.
                ns:Fill(r, C.fel[1], C.fel[2], C.fel[3], 0.15)
            end
        end
    end
end

local function isMenu(f)
    if not f.GetRegions then return false end
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local a = r:GetAtlas()
            if a and a:find("dropdown%-bg") then return true end
        end
    end
    return false
end

local seenMenus = setmetatable({}, { __mode = "k" })
local function styleMenu(m, depth)
    depth = depth or 0
    if depth > 6 then return end
    seenMenus[m] = true
    for _, r in ipairs({ m:GetRegions() }) do
        if r:GetObjectType() == "Texture" then
            local a = r:GetAtlas()
            if a and a:find("dropdown%-bg") and r:GetAlpha() > 0 then r:SetAlpha(0) end
        end
    end
    if not done[m] then
        done[m] = true
        backdrop(m, "Default", false, 0)
    end
    -- Blizzard reuses menus and raises each one as it opens; our card is
    -- kept just under it, or it ends up above the rows and greys them.
    local bd = extras[m] and extras[m].backdrop
    if bd then
        if bd:GetFrameStrata() ~= m:GetFrameStrata() then bd:SetFrameStrata(m:GetFrameStrata()) end
        local want = math.max(0, m:GetFrameLevel() - 1)
        if bd:GetFrameLevel() ~= want then bd:SetFrameLevel(want) end
    end
    for _, child in ipairs({ m:GetChildren() }) do
        if child:IsShown() then
            -- A menu opened from a row of this one.
            if isMenu(child) then
                styleMenu(child, depth + 1)
            else
                styleMenuRow(child)
                for _, g in ipairs({ child:GetChildren() }) do
                    if g:IsShown() and g.GetRegions then
                        if isMenu(g) then styleMenu(g, depth + 1) else styleMenuRow(g) end
                    end
                end
            end
        end
    end
end

-- The open menu and every menu opened from it. Blizzard keeps submenus as
-- frames of their own on UIParent; they are found there (or under the
-- root) by the dropdown backing they carry.
local menuScan = {}
local function openMenus()
    local mgr = Menu and Menu.GetManager and Menu.GetManager()
    if not mgr or not mgr.GetOpenMenu then return end
    local m = mgr:GetOpenMenu()
    if not (m and m.IsShown and m:IsShown()) then return end
    styleMenu(m)
    -- Submenus can have no parent at all, so walking frames never meets
    -- them; the menu (or the row that opened one) holds them in a field.
    local function fields(t, depth)
        if depth > 3 then return end
        for _, v in pairs(t) do
            if type(v) == "table" and v ~= m and v.GetObjectType and not (v.IsForbidden and v:IsForbidden()) then
                local ok, isFrame = pcall(function() return v:GetObjectType() == "Frame" and v:IsShown() end)
                if ok and isFrame and not seenMenus[v] and isMenu(v) then
                    styleMenu(v)
                    fields(v, depth + 1)
                end
            end
        end
    end
    pcall(fields, m, 0)
    for _, row in ipairs({ m:GetChildren() }) do pcall(fields, row, 1) end
    for sub in pairs(seenMenus) do
        if sub ~= m and sub.IsShown and sub:IsShown() then styleMenu(sub) end
    end
    -- The search beside it can run over every frame on the screen, so a
    -- few times a second is enough; a submenu shows for longer than that.
    local now = GetTime()
    if (menuScan.last or 0) > now - 0.08 then return end
    menuScan.last = now
    -- Submenus sit on UIParent even when the root menu belongs to a window;
    -- only frames on the menu's own layer are looked at.
    local strata = m:GetFrameStrata()
    -- Last resort, a few times a second while a menu is open: every frame
    -- the game has, parentless ones included, on the menu's layer.
    if EnumerateFrames and (menuScan.all or 0) < now - 0.25 then
        menuScan.all = now
        local f = EnumerateFrames()
        local n = 0
        while f and n < 20000 do
            n = n + 1
            if f ~= m and not seenMenus[f] and not (f.IsForbidden and f:IsForbidden())
                and f:IsShown() and isMenu(f) then
                styleMenu(f)
            end
            f = EnumerateFrames(f)
        end
    end
    local seen = {}
    for _, host in ipairs({ m:GetParent(), UIParent }) do
        if host and host.GetChildren and not seen[host] then
            seen[host] = true
            for _, f in ipairs({ host:GetChildren() }) do
                if f ~= m and not (f.IsForbidden and f:IsForbidden()) and f:IsShown()
                    and f:GetFrameStrata() == strata and isMenu(f) then styleMenu(f) end
            end
        end
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
    -- A window whose page changes (a tab chosen) or whose list gains rows
    -- (scrolled, opened a section) is scanned that same frame too: a cheap
    -- signature of what shows is taken every frame and compared.
    local boxes = setmetatable({}, { __mode = "k" })
    local function findBoxes(f, depth, out)
        if depth > 6 or not f.GetChildren then return out end
        for _, c in ipairs({ f:GetChildren() }) do
            if c.ScrollTarget then out[#out + 1] = c.ScrollTarget end
            if c:GetObjectType() ~= "ScrollFrame" then findBoxes(c, depth + 1, out) end
        end
        return out
    end
    local sigs = {}
    local function signature(n, f)
        local parts = {}
        for _, c in ipairs({ f:GetChildren() }) do parts[#parts + 1] = c:IsShown() and "1" or "0" end
        for _, t in ipairs(boxes[f] or {}) do
            parts[#parts + 1] = t:GetNumChildren()
            local shownRows = 0
            for _, row in ipairs({ t:GetChildren() }) do if row:IsShown() then shownRows = shownRows + 1 end end
            parts[#parts + 1] = shownRows
        end
        return table.concat(parts, ",")
    end
    local tick = CreateFrame("Frame")
    local acc, names = 1, allNames()
    local shown, fresh = {}, {}
    -- Blizzard sets a window's title to the right of the round portrait
    -- in its corner; the portrait is gone, so the title is centred on the
    -- window instead, and held there (Blizzard lays it out again).
    local function centreTitle(f)
        local tc = f.TitleContainer or (f.BorderFrame and f.BorderFrame.TitleContainer)
        if not tc or InCombatLockdown() then return end
        local p, rel, rp, x = tc:GetPoint(1)
        if not (p == "TOPLEFT" and rel == f and math.abs((x or 0) - 24) < 0.5 and tc:GetNumPoints() == 2) then
            local _, _, _, _, y = tc:GetPoint(1)
            tc:ClearAllPoints()
            tc:SetPoint("TOPLEFT", f, "TOPLEFT", 24, y or -1)
            tc:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, y or -1)
        end
    end
    tick:SetScript("OnUpdate", function(_, e)
        if not db().enable then return end
        for tab in pairs(skinnedTabs) do
            if tab:IsVisible() then holdTab(tab) end
        end
        pcall(openMenus)
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
            if on and done[f] then
                centreTitle(f)
                local mm = f.MaximizeMinimizeFrame or (f.BorderFrame and f.BorderFrame.MaximizeMinimizeFrame)
                if mm then
                    if mm.MaximizeButton and mm.MaximizeButton:IsShown() then ns:Glyph(mm.MaximizeButton, "plus") end
                    if mm.MinimizeButton and mm.MinimizeButton:IsShown() then ns:Glyph(mm.MinimizeButton, "minus") end
                end
                PS.holdWindow(n, f)
                if full or fresh[n] or not boxes[f] then boxes[f] = findBoxes(f, 1, {}) end
                local sig = signature(n, f)
                local changed = sig ~= sigs[n]
                sigs[n] = sig
                if full or fresh[n] or changed then scanButtons(f, 1) end
            end
            if fresh[n] then fresh[n] = fresh[n] > 1 and fresh[n] - 1 or nil end
        end
    end)
    if UpdateUIPanelPositions then
        hooksecurefunc("UpdateUIPanelPositions", function()
            if db().enable then pcall(PS.restoreWindows) end
        end)
    end
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
    L:Slider("Background opacity", "alpha", 0.3, 1, 0.05)
    L:Toggle("Accent corners", "brackets", { tooltip = "Takes effect after a reload." })
    L:Toggle("Buttons", "buttons")
    L:Toggle("Tabs", "tabs")
    L:Toggle("Quality glow on gear", "qualityGlow", { tooltip = "A soft halo in each item's quality colour round its slot in the character window, from green up." })
    L:Toggle("Drag windows by their title", "moveWindows", { tooltip = "Character, quest log, talents, vendors and the rest stay where you leave them." })
    L:Toggle("Keep the game's bags above the damage meter", "bagsClearMeter", { tooltip = "The game's bag windows stack up from the bottom right corner. With this on, they start just above the damage meter instead of covering it." })
    L:Button("Put windows back", function()
        db().windowPos = {}
        print("|cff4FC778Wick's UI|r: windows go back to their places the next time they open.")
    end)
    L:Note("Found a window still in the game's own look? Point at it and type " .. Chrome:Esc("fel") .. "/wui skin|r. It is skinned on the spot and every time after.")
    L:Input("Skinned with /wui skin", "include", { width = 520, span = 2,
        tooltip = "Windows added with /wui skin. Remove a name to stop skinning it; takes effect after a reload." })
    L:Input("Leave these alone", "exclude", { width = 520, span = 2,
        tooltip = "Frame names separated by commas, for example  WorldMapFrame, AuctionHouseFrame. /fstack in game shows a frame's name. Takes effect after a reload." })
end, { parent = "skins", onChange = function() PS:Update() end, order = 96 })
