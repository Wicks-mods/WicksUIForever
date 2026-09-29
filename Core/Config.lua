-- Wick's UI
-- Core/Config.lua: the settings window.
--
-- A page list on the left, the page on the right. Modules describe their
-- pages with a small layout helper and never position a control by hand:
--
--   ns.Config:AddPage("actionbars.bar1", "Bar 1", function(L)
--       L:DB(function() return AB:db().bar1 end)
--       L:Toggle("Enable", "enable")
--       L:Slider("Button size", "buttonSize", 16, 64, 1)
--   end, { parent = "actionbars", onChange = function() AB:Update() end })
--
-- Controls flow two to a row; headings, notes and text areas take the
-- full width. After any change the page's onChange runs and every control
-- on the page re-reads its value, so a control that depends on another
-- follows it.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local Config = { pages = {}, order = {} }
ns.Config = Config

local WIDTH, HEIGHT = 860, 620
local NAV_W = 190
local COL_W = 250
local PAD = 16

-- ============================================================
-- Layout helper
-- ============================================================
local Layout = {}
Layout.__index = Layout

local function newLayout(page, content)
    return setmetatable({ page = page, content = content, x = 0, y = -PAD, col = 0, rowH = 0, controls = {} }, Layout)
end

function Layout:DB(fn) self.db = fn end

local function getter(L, key)
    local db = L.db
    return function()
        local t = db and db()
        if type(key) == "function" then return key() end
        return t and t[key]
    end
end

local function setter(L, key, after)
    local db = L.db
    return function(v)
        local t = db and db()
        if t then t[key] = v end
        if after then after(v) end
    end
end

local function newRow(L)
    if L.col > 0 then
        L.y = L.y - L.rowH - 8
        L.col, L.rowH = 0, 0
    end
end

-- Place a control. span = 2 takes the whole row.
function Layout:Place(f, span, key)
    local page = self.page
    f.onChange = function() Config:Changed(page) end
    if self.copy and type(key) == "string" and not self.copy.skip[key] then
        self.copy.hover[f] = { key = key, db = self.db }
    end
    if span == 2 then
        newRow(self)
        f:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD, self.y)
        self.y = self.y - f:GetHeight() - 8
    else
        if self.col >= 2 then newRow(self) end
        f:SetPoint("TOPLEFT", self.content, "TOPLEFT", PAD + self.col * (COL_W + 24), self.y)
        self.col = self.col + 1
        self.rowH = math.max(self.rowH, f:GetHeight())
        if self.col >= 2 then newRow(self) end
    end
    self.controls[#self.controls + 1] = f
    return f
end

function Layout:Break() newRow(self) end
function Layout:Space(h) newRow(self); self.y = self.y - (h or 8) end

function Layout:Heading(text)
    newRow(self)
    self.y = self.y - 6
    return self:Place(W:Heading(self.content, text, COL_W * 2 + 24), 2)
end

function Layout:Note(text)
    return self:Place(W:Note(self.content, text, COL_W * 2 + 24), 2)
end

-- opts.disabled = function() return true when the control should grey out
-- opts.set = function(v) called after the value is stored
function Layout:Toggle(text, key, opts)
    opts = opts or {}
    local get = opts.get or getter(self, key)
    local set = opts.setter or setter(self, key, opts.set)
    return self:Place(W:Check(self.content, text, function() return get() and true or false end, set,
        { width = COL_W, disabled = opts.disabled, tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Slider(text, key, min, max, step, opts)
    opts = opts or {}
    return self:Place(W:Slider(self.content, text, min, max, step, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), COL_W, { disabled = opts.disabled, tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Dropdown(text, key, values, opts)
    opts = opts or {}
    return self:Place(W:Dropdown(self.content, text, values, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), COL_W, { disabled = opts.disabled, tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Color(text, key, opts)
    opts = opts or {}
    return self:Place(W:Color(self.content, text, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), { width = COL_W, alpha = opts.alpha, disabled = opts.disabled, tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Input(text, key, opts)
    opts = opts or {}
    return self:Place(W:Input(self.content, text, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), opts.width or COL_W, { disabled = opts.disabled, tooltip = opts.tooltip }), opts.span, key)
end

function Layout:TextArea(text, key, opts)
    opts = opts or {}
    return self:Place(W:TextArea(self.content, text, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), COL_W * 2 + 24, opts.height or 60,
        { disabled = opts.disabled, tooltip = opts.tooltip, default = opts.default }), 2, key)
end

function Layout:Button(text, onClick, opts)
    opts = opts or {}
    local holder = CreateFrame("Frame", nil, self.content)
    holder:SetSize(COL_W, 26)
    local page = self.page
    local b = W:Button(holder, text, opts.width or 160, function(...)
        onClick(...)
        Config:Changed(page)
    end, { disabled = opts.disabled, tooltip = opts.tooltip })
    -- Wide enough for its label, whatever the label is.
    b:SetWidth(math.min(COL_W, math.max(opts.width or 160, (b.text:GetStringWidth() or 0) + 24)))
    b:SetPoint("LEFT")
    holder.Refresh = function() b:Refresh() end
    return self:Place(holder, opts.span)
end

-- Copying settings from a sibling (another bar, another unit):
--
--   L:CopyFrom({
--       sources = function() return { { id, "Bar 2" }, ... } end,
--       table   = function(id) return the settings table for id end,
--       skip    = { paging = true },   -- keys never copied
--   })
--
-- Sections that switch L:DB to a table inside the page's (a unit's texts,
-- its cast bar) copy from the same place in the source.
--
-- Called before the controls. A "Copy all from" picker sits at the top
-- right of the page, level with its title. Each setting shows a small
-- "copy from" at the end of its label while the pointer is over it, and
-- nowhere else, so the page reads as it did.
local function deep(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deep(x) end
    return out
end

function Layout:CopyFrom(opts)
    local L, page = self, self.page
    self.copy = { skip = opts.skip or {}, hover = {} }
    local root = L.db

    -- A section of the page (a unit's left text, its cast bar) has its own
    -- table inside the root: found by identity, and the same path is then
    -- read in the source.
    local function pathTo(t, want, depth, out)
        if t == want then return out end
        if depth > 4 or type(t) ~= "table" then return end
        for k, v in pairs(t) do
            if type(v) == "table" then
                out[#out + 1] = k
                if pathTo(v, want, depth + 1, out) then return out end
                out[#out] = nil
            end
        end
    end
    local function walk(t, path)
        for _, k in ipairs(path) do
            if type(t) ~= "table" then return end
            t = t[k]
        end
        return t
    end

    -- Everything, where the target has that setting too, so a frame
    -- never takes settings it has no use for.
    local function copyAll(id)
        local from, to = opts.table(id), root and root()
        if not (from and to) then return end
        for k, v in pairs(from) do
            if not L.copy.skip[k] and to[k] ~= nil then to[k] = deep(v) end
        end
        Config:Changed(page)
    end

    local function sectionFor(entry, id)
        local to = entry.db and entry.db()
        local path = to and pathTo(root and root(), to, 0, {})
        if not path then return end
        return walk(opts.table(id), path), to
    end

    local function copyOne(entry, id)
        local from, to = sectionFor(entry, id)
        if type(from) ~= "table" or not to or from[entry.key] == nil then return end
        to[entry.key] = deep(from[entry.key])
        Config:Changed(page)
    end

    -- Only the sources that have this setting.
    local function sourcesFor(entry)
        local out = {}
        for _, s in ipairs(opts.sources()) do
            local from = sectionFor(entry, s[1])
            if type(from) == "table" and from[entry.key] ~= nil then out[#out + 1] = s end
        end
        return out
    end

    -- The page-wide picker, level with the title.
    local b = CreateFrame("Button", nil, self.content)
    b:SetSize(140, 22)
    b:SetPoint("TOPRIGHT", self.content, "TOPLEFT", PAD + COL_W * 2 + 24, -PAD + 2)
    ns:SetTemplate(b, "Shadow")
    b.value = ns:CreateText(b, 12, "LEFT", "NONE")
    b.value:SetPoint("LEFT", 6, 0)
    b.value:SetText("Copy all from")
    local arrow = ns:CreateText(b, 12, "RIGHT", "NONE")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
    b:SetScript("OnEnter", function() ns:SetBorderColor(b, "fel") end)
    b:SetScript("OnLeave", function() ns:SetBorderColor(b, "border") end)
    b:SetScript("OnClick", function()
        W.OpenMenu(b, opts.sources, nil, function(id)
            local name = tostring(id)
            for _, s in ipairs(opts.sources()) do if s[1] == id then name = s[2] end end
            W:Confirm(("Copy every setting from %s onto %s? Where it sits, and what only it should have, stay as they are."):format(name, page.title),
                function() copyAll(id) end, "Copy")
        end)
    end)

    -- One "copy from" link, moved to whichever setting is under the pointer.
    local link = CreateFrame("Button", nil, self.content)
    link:SetSize(64, 14)
    link:SetFrameLevel(self.content:GetFrameLevel() + 20)
    link.text = ns:CreateText(link, 11, "RIGHT", "NONE")
    link.text:SetPoint("RIGHT")
    link.text:SetText("copy from")
    link.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    link:SetScript("OnEnter", function() link.text:SetTextColor(C.fel[1], C.fel[2], C.fel[3]) end)
    link:SetScript("OnLeave", function() link.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    link:SetScript("OnClick", function()
        local entry = link.entry
        if not entry then return end
        local list = sourcesFor(entry)
        if #list == 0 then return end
        W.OpenMenu(link, list, nil, function(id) copyOne(entry, id) end)
    end)
    link:Hide()
    local watch = CreateFrame("Frame", nil, self.content)
    watch:SetScript("OnUpdate", function()
        local menu = rawget(_G, "WicksUIMenu")
        if menu and menu:IsShown() and menu.owner == link then return end
        if link:IsShown() and link:IsMouseOver() then return end
        local over
        for f in pairs(L.copy.hover) do
            if f:IsVisible() and not f.disabled and f:IsMouseOver(2, 0, 0, 0) then over = f; break end
        end
        if over ~= link.owner then
            link.owner = over
            if over then
                link.entry = L.copy.hover[over]
                link:ClearAllPoints()
                link:SetPoint("TOPRIGHT", over, "TOPRIGHT", 0, 1)
                link:Show()
            else
                link:Hide()
            end
        end
    end)
end

-- Any frame the page builds by hand; it gets the full row.
function Layout:Custom(f, span) return self:Place(f, span or 2) end

function Layout:Finish()
    newRow(self)
    self.content:SetHeight(-self.y + PAD)
end

-- ============================================================
-- Pages
-- ============================================================
-- key:     "actionbars" or "actionbars.bar1" (the part before the dot is the parent)
-- builder: function(L) ... end
-- opts:    parent, onChange, order
function Config:AddPage(key, title, builder, opts)
    opts = opts or {}
    local page = self.pages[key]
    if not page then
        page = { key = key }
        self.pages[key] = page
        self.order[#self.order + 1] = key
    end
    page.title = title
    page.builder = builder
    page.parent = opts.parent
    page.onChange = opts.onChange
    page.sort = opts.order or (#self.order * 10)
    page.built = nil
    return page
end

function Config:Changed(page)
    if page.onChange then
        local ok, err = pcall(page.onChange)
        if not ok then ns.A:Print("settings: " .. tostring(err)) end
    end
    self:RefreshPage(page)
end

function Config:RefreshPage(page)
    if not page or not page.layout then return end
    for _, c in ipairs(page.layout.controls) do
        if c.Refresh then c:Refresh() end
    end
end

-- Pages whose contents depend on settings (a list of bars, say) ask to be
-- built again the next time they are shown.
function Config:Rebuild(key)
    local page = self.pages[key]
    if not page then return end
    if page.content then page.content:Hide() end
    page.content = nil
    page.layout = nil
    page.built = nil
    if self.current == key then self:Show(key) end
end

-- ============================================================
-- The window
-- ============================================================
local frame, nav, scroll

local function navEntries()
    local roots, children = {}, {}
    for _, key in ipairs(Config.order) do
        local p = Config.pages[key]
        if p.parent then
            children[p.parent] = children[p.parent] or {}
            table.insert(children[p.parent], p)
        else
            roots[#roots + 1] = p
        end
    end
    local bySort = function(a, b) return a.sort < b.sort end
    table.sort(roots, bySort)
    local out = {}
    for _, p in ipairs(roots) do
        out[#out + 1] = { page = p, depth = 0 }
        local kids = children[p.key]
        if kids and Config.expanded[p.key] then
            table.sort(kids, bySort)
            for _, k in ipairs(kids) do out[#out + 1] = { page = k, depth = 1 } end
        end
    end
    return out, children
end

Config.expanded = {}

local function drawNav()
    local entries, children = navEntries()
    nav.buttons = nav.buttons or {}
    for _, b in ipairs(nav.buttons) do b:Hide() end
    local y = -8
    for i, e in ipairs(entries) do
        local b = nav.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, nav.child)
            b:SetHeight(20)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetAllPoints()
            b.hl:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.15)
            b.sel = b:CreateTexture(nil, "BACKGROUND")
            b.sel:SetPoint("TOPLEFT")
            b.sel:SetPoint("BOTTOMLEFT")
            b.sel:SetWidth(2)
            b.sel:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
            b.text = ns:CreateText(b, 12, "LEFT", "NONE")
            nav.buttons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 4, y)
        b:SetPoint("TOPRIGHT", -4, y)
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", 8 + e.depth * 12, 0)
        local p = e.page
        local hasKids = e.depth == 0 and children[p.key]
        local mark = hasKids and (Config.expanded[p.key] and "- " or "+ ") or ""
        b.text:SetText(mark .. p.title)
        local current = Config.current == p.key
        b.sel:SetShown(current)
        if current then
            b.text:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
        elseif e.depth == 0 then
            b.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        else
            b.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        end
        b:SetScript("OnClick", function()
            if hasKids then Config.expanded[p.key] = not Config.expanded[p.key] or Config.current ~= p.key end
            Config:Show(p.key)
        end)
        b:Show()
        y = y - 20
    end
    nav.child:SetHeight(-y + 8)
end

local function makeScroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    local function maxScroll() return math.max(0, child:GetHeight() - sf:GetHeight()) end

    -- A slim bar inside the right edge: a track and a thumb sized to how
    -- much of the page shows, dragged or wheeled. It hides when the page
    -- fits.
    local track = CreateFrame("Frame", nil, sf)
    track:SetPoint("TOPRIGHT", -3, -6)
    track:SetPoint("BOTTOMRIGHT", -3, 6)
    track:SetWidth(4)
    local line = track:CreateTexture(nil, "BACKGROUND")
    line:SetAllPoints()
    ns:Fill(line, C.border[1], C.border[2], C.border[3], 0.6)
    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(4)
    local tt = thumb:CreateTexture(nil, "ARTWORK")
    tt:SetAllPoints()
    ns:Fill(tt, C.fel[1], C.fel[2], C.fel[3], 0.8)
    thumb:EnableMouse(true)
    thumb:RegisterForDrag("LeftButton")

    local function layout()
        local th = track:GetHeight()
        -- Before the window is first drawn its sizes read as nothing; the
        -- OnShow below lays it out again once they are real.
        if not th or th <= 0 or sf:GetHeight() <= 0 then return end
        local max = maxScroll()
        if max <= 0 then track:Hide(); return end
        track:Show()
        local h = math.max(24, th * sf:GetHeight() / child:GetHeight())
        thumb:SetHeight(h)
        local y = (th - h) * (sf:GetVerticalScroll() / max)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -y)
    end
    sf.layoutBar = layout

    local dragFrom, dragScroll
    thumb:SetScript("OnDragStart", function()
        local _, cy = GetCursorPosition()
        dragFrom, dragScroll = cy / thumb:GetEffectiveScale(), sf:GetVerticalScroll()
    end)
    thumb:SetScript("OnDragStop", function() dragFrom = nil end)
    thumb:SetScript("OnUpdate", function()
        if not dragFrom then return end
        local _, cy = GetCursorPosition()
        cy = cy / thumb:GetEffectiveScale()
        local room = track:GetHeight() - thumb:GetHeight()
        if room <= 0 then return end
        local v = dragScroll + (dragFrom - cy) / room * maxScroll()
        sf:SetVerticalScroll(math.max(0, math.min(maxScroll(), v)))
        layout()
    end)

    sf:SetScript("OnMouseWheel", function(self, delta)
        local v = math.max(0, math.min(maxScroll(), self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(v)
        layout()
    end)
    sf:SetScript("OnSizeChanged", layout)
    sf:SetScript("OnShow", function() C_Timer.After(0, layout) end)
    child:SetScript("OnSizeChanged", layout)
    sf.child = child
    return sf
end

local function build()
    frame = CreateFrame("Frame", "WicksUIConfig", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    -- Near the top of the screen rather than its middle, so the action bars
    -- and unit frames along the bottom stay in view while settings change.
    frame:SetPoint("TOP", UIParent, "TOP", 0, -60)
    -- DIALOG, the layer Blizzard's own dialogs use, so no frame of the
    -- interface (unit frames, bars, their text overlays) draws over it.
    -- Its dropdown menus and confirms sit higher still, in FULLSCREEN_DIALOG.
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    ns:SetTemplate(frame, "Default", { brackets = true, alpha = ns:Modern() and 0.96 or nil })
    Chrome:CloseOnEscape(frame)
    frame:SetScript("OnHide", function() W.CloseMenu() end)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(30)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(C.shadow[1], C.shadow[2], C.shadow[3], 1)
    Chrome:Register(hbg, "shadow", "texture")
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = ns:CreateText(header, 14, "LEFT", "NONE")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(Chrome:TitleMarkup("Wick's UI") .. "  |cff8f8770" .. tostring(ns.version) .. "|r")

    local close = W:Button(header, "x", 22, function() frame:Hide() end)
    close:SetPoint("RIGHT", -4, 0)

    local movers = W:Button(header, "Move frames", 110, function()
        frame:Hide()
        ns.Movers:Unlock()
    end)
    movers:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local keys = W:Button(header, "Keybinds", 90, function()
        frame:Hide()
        if ns.Keybind then ns.Keybind:Activate() end
    end)
    keys:SetPoint("RIGHT", movers, "LEFT", -6, 0)

    local reload = W:Button(header, "Reload", 70, function() ReloadUI() end)
    reload:SetPoint("RIGHT", keys, "LEFT", -6, 0)

    -- The page list.
    local navBG = CreateFrame("Frame", nil, frame)
    navBG:SetPoint("TOPLEFT", 1, -31)
    navBG:SetPoint("BOTTOMLEFT", 1, 1)
    navBG:SetWidth(NAV_W)
    local nbg = navBG:CreateTexture(nil, "BACKGROUND")
    nbg:SetAllPoints()
    nbg:SetColorTexture(C.shadow[1], C.shadow[2], C.shadow[3], 0.6)
    Chrome:Register(nbg, "shadow", "texture", 0.6)
    local divider = navBG:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPRIGHT")
    divider:SetPoint("BOTTOMRIGHT")
    divider:SetWidth(ns.mult or 1)
    divider:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    Chrome:Register(divider, "border", "texture")

    nav = makeScroll(navBG)
    nav:SetAllPoints()
    nav.child:SetWidth(NAV_W)

    scroll = makeScroll(frame)
    scroll:SetPoint("TOPLEFT", navBG, "TOPRIGHT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -1, 1)
    scroll.child:SetWidth(WIDTH - NAV_W - 4)
end

function Config:Show(key)
    if not frame then build() end
    key = key or self.current or (self.order[1])
    local page = self.pages[key]
    if not page then return end
    -- Opening a child shows its parent open in the list.
    if page.parent then self.expanded[page.parent] = true end

    if self.current and self.pages[self.current] and self.pages[self.current].content then
        self.pages[self.current].content:Hide()
    end
    self.current = key

    if not page.content then
        local content = CreateFrame("Frame", nil, scroll.child)
        content:SetPoint("TOPLEFT")
        content:SetWidth(WIDTH - NAV_W - 4)
        page.content = content
        local L = newLayout(page, content)
        page.layout = L
        local title = ns:CreateText(content, 18, "LEFT", "NONE")
        ns:HeadingFont(title, 18)
        title:SetPoint("TOPLEFT", PAD, -PAD)
        if Chrome.SetHeadingText then Chrome:SetHeadingText(title, page.title) else title:SetText(page.title) end
        L.y = -PAD - 30
        local ok, err = pcall(page.builder, L)
        page.buildError = not ok and tostring(err) or nil
        if not ok then
            L:Note("|cffff6060This page failed to build:|r " .. tostring(err))
        end
        L:Finish()
    end
    page.content:Show()
    scroll.child:SetHeight(page.content:GetHeight())
    scroll:SetVerticalScroll(0)
    if scroll.layoutBar then C_Timer.After(0, scroll.layoutBar) end
    self:RefreshPage(page)
    drawNav()
    frame:Show()
end

function Config:Open(key)
    if InCombatLockdown() then
        ns.A:Print("the settings will open when the fight is over.")
        ns:AfterCombat("config", function() Config:Show(key) end)
        return
    end
    self:Show(key)
end

function Config:Hide()
    if frame then frame:Hide() end
end

function Config:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Open() end
end

-- A fight starting hides the window: several pages rebuild secure frames,
-- which cannot happen until it is over anyway.
ns:On("PLAYER_REGEN_DISABLED", function()
    if frame and frame:IsShown() then
        frame:Hide()
        Config.hiddenForCombat = true
    end
end)
ns:On("PLAYER_REGEN_ENABLED", function()
    if Config.hiddenForCombat then
        Config.hiddenForCombat = nil
        Config:Show()
    end
end)
