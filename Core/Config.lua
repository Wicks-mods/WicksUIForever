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

-- Every control placed after this also greys out while fn() is true: a
-- section whose Show is off, a frame that is switched off. nil ends it.
function Layout:DisabledWhen(fn) self.when = fn end

local function disabledFor(L, opts)
    local own, when = opts.disabled, L.when
    if not when then return own end
    if not own then return when end
    return function() return when() or own() end
end

-- opts.disabled = function() return true when the control should grey out
-- opts.set = function(v) called after the value is stored
function Layout:Toggle(text, key, opts)
    opts = opts or {}
    local get = opts.get or getter(self, key)
    local set = opts.setter or setter(self, key, opts.set)
    return self:Place(W:Check(self.content, text, function() return get() and true or false end, set,
        { width = COL_W, disabled = disabledFor(self, opts), tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Slider(text, key, min, max, step, opts)
    opts = opts or {}
    return self:Place(W:Slider(self.content, text, min, max, step, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), COL_W, { disabled = disabledFor(self, opts), tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Dropdown(text, key, values, opts)
    opts = opts or {}
    return self:Place(W:Dropdown(self.content, text, values, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), COL_W, { disabled = disabledFor(self, opts), tooltip = opts.tooltip }), opts.span, key)
end

function Layout:Color(text, key, opts)
    opts = opts or {}
    return self:Place(W:Color(self.content, text, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), { width = COL_W, alpha = opts.alpha, disabled = disabledFor(self, opts),
        tooltip = opts.tooltip, fallback = opts.fallback, follows = opts.follows }), opts.span, key)
end

function Layout:Input(text, key, opts)
    opts = opts or {}
    return self:Place(W:Input(self.content, text, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), opts.width or COL_W, { disabled = disabledFor(self, opts), tooltip = opts.tooltip }), opts.span, key)
end

function Layout:TextArea(text, key, opts)
    opts = opts or {}
    return self:Place(W:TextArea(self.content, text, opts.get or getter(self, key),
        opts.setter or setter(self, key, opts.set), COL_W * 2 + 24, opts.height or 60,
        { disabled = disabledFor(self, opts), tooltip = opts.tooltip, default = opts.default }), 2, key)
end

function Layout:Button(text, onClick, opts)
    opts = opts or {}
    local holder = CreateFrame("Frame", nil, self.content)
    holder:SetSize(COL_W, 26)
    local page = self.page
    local b = W:Button(holder, text, opts.width or 160, function(...)
        onClick(...)
        Config:Changed(page)
    end, { disabled = disabledFor(self, opts), tooltip = opts.tooltip })
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
    ns:TextColor(arrow, "fel")
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
    ns:TextColor(link.text, "muted")
    link:SetScript("OnEnter", function() ns:TextColor(link.text, "fel") end)
    link:SetScript("OnLeave", function() ns:TextColor(link.text, "muted") end)
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
    self:DropIndex()
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
    self:DropIndex()
    if self.current == key then self:Show(key) end
end

-- ============================================================
-- Search
-- ============================================================
-- Every setting on every page, found by its name. Pages are only built
-- when they are opened, so the search runs each page's builder once
-- against a probe: a layout that writes down what each control is called
-- (its label, its tooltip, the heading over it, the page it is on) where
-- the real one would make it. A frame a builder makes by hand goes on a
-- hidden holder that is never shown. The list is kept until a page is
-- added or rebuilt.
local function plain(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return s
end
Config.Plain = plain

-- What a builder gets back from a probed control: anything asked of it
-- answers with itself, so a builder that sets something on its control
-- runs on.
local absorb
absorb = setmetatable({}, { __index = function() return absorb end, __call = function() return absorb end })

local Probe = setmetatable({}, { __index = Layout })
Probe.__index = Probe

-- Counts each control in the order the real layout places it, so a result
-- finds its control on the built page.
local function found(P, kind, text, tooltip)
    P.n = P.n + 1
    text = plain(text)
    if text == "" then return absorb end
    P.found[#P.found + 1] = { kind = kind, text = text, tooltip = plain(tooltip), heading = P.heading, index = P.n }
    return absorb
end

function Probe:Place(f) self.n = self.n + 1; return f end
function Probe:Heading(text)
    self.heading = plain(text)
    return found(self, "heading", text)
end
function Probe:Note() self.n = self.n + 1; return absorb end
function Probe:Toggle(text, _, opts) return found(self, "setting", text, opts and opts.tooltip) end
function Probe:Slider(text, _, _, _, _, opts) return found(self, "setting", text, opts and opts.tooltip) end
function Probe:Dropdown(text, _, _, opts) return found(self, "setting", text, opts and opts.tooltip) end
function Probe:Color(text, _, opts) return found(self, "setting", text, opts and opts.tooltip) end
function Probe:Input(text, _, opts) return found(self, "setting", text, opts and opts.tooltip) end
function Probe:TextArea(text, _, opts) return found(self, "setting", text, opts and opts.tooltip) end
function Probe:Button(text, _, opts) return found(self, "button", text, opts and opts.tooltip) end
function Probe:Custom(f) self.n = self.n + 1; return f end
function Probe:CopyFrom() end
function Probe:Finish() end

-- The pages in the order the list shows them, children under their parent.
local function allPages()
    local roots, kids = {}, {}
    for _, key in ipairs(Config.order) do
        local p = Config.pages[key]
        if p.parent then
            kids[p.parent] = kids[p.parent] or {}
            table.insert(kids[p.parent], p)
        else
            roots[#roots + 1] = p
        end
    end
    local bySort = function(a, b) return a.sort < b.sort end
    table.sort(roots, bySort)
    local out = {}
    for _, p in ipairs(roots) do
        out[#out + 1] = p
        local k = kids[p.key]
        if k then
            table.sort(k, bySort)
            for _, c in ipairs(k) do out[#out + 1] = c end
        end
    end
    return out
end

-- A page added or rebuilt: the list is made again, from the start if one
-- was being made, for whoever was waiting on it.
function Config:DropIndex()
    self.index = nil
    if self.indexing then
        self.indexing = nil
        C_Timer.After(0, function() Config:IndexAsync() end)
    end
end

-- One page into the index. A builder that stops part way is indexed as
-- far as it got.
function Config:IndexPage(page, out, errors)
    if not self.probeHolder then
        self.probeHolder = CreateFrame("Frame")
        self.probeHolder:Hide()
    end
    local parent = page.parent and self.pages[page.parent]
    local where = parent and (plain(parent.title) .. " > " .. plain(page.title)) or plain(page.title)
    out[#out + 1] = { kind = "page", text = plain(page.title), tooltip = "", page = page,
        path = parent and plain(parent.title) or "Page" }
    local P = setmetatable({ page = page, content = self.probeHolder, x = 0, y = 0, col = 0, rowH = 0,
        controls = {}, n = 0, found = {} }, Probe)
    local ok, err = pcall(page.builder, P)
    if not ok then errors[#errors + 1] = page.key .. ": " .. tostring(err) end
    for _, e in ipairs(P.found) do
        e.page = page
        e.path = (e.heading and e.heading ~= e.text) and (where .. " > " .. e.heading) or where
        out[#out + 1] = e
    end
end

-- Every page at once.
function Config:Index()
    if self.index then return self.index end
    local out, errors = {}, {}
    for _, page in ipairs(allPages()) do self:IndexPage(page, out, errors) end
    self.index, self.probeErrors, self.indexing = out, errors, nil
    return out
end

-- The window's way: one page a frame. Run all at once, the builders went
-- past the client's limit on how long an addon may run in one go, worse
-- on the controller, where the game looks over every frame an addon
-- makes; and as the list was never finished, every key typed into the
-- search began it again. done(index) runs when it is ready.
function Config:IndexAsync(done)
    if self.index then
        if done then done(self.index) end
        return
    end
    self.indexWaiters = self.indexWaiters or {}
    if done then self.indexWaiters[#self.indexWaiters + 1] = done end
    if self.indexing then return end
    local job = { pages = allPages(), i = 0, out = {}, errors = {} }
    self.indexing = job
    local driver = self.indexDriver or CreateFrame("Frame")
    self.indexDriver = driver
    driver:SetScript("OnUpdate", function(f)
        -- A page added or rebuilt meanwhile starts the list again.
        if Config.indexing ~= job then f:SetScript("OnUpdate", nil) return end
        job.i = job.i + 1
        local page = job.pages[job.i]
        if page then
            Config:IndexPage(page, job.out, job.errors)
            return
        end
        f:SetScript("OnUpdate", nil)
        Config.index, Config.probeErrors, Config.indexing = job.out, job.errors, nil
        local waiters = Config.indexWaiters
        Config.indexWaiters = {}
        for _, w in ipairs(waiters) do pcall(w, Config.index) end
    end)
end

-- Every word typed has to be in the setting's name, its page or heading,
-- or its tooltip. A name holding the whole search comes first, then one
-- holding every word, then the rest.
function Config:Search(query)
    local words = {}
    for w in (query or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    local q = table.concat(words, " ")
    if #q < 2 then return nil end
    local hits = {}
    for i, e in ipairs(self:Index()) do
        local name, where, tip = e.text:lower(), e.path:lower(), e.tooltip:lower()
        local all, inName = true, true
        for _, w in ipairs(words) do
            local n = name:find(w, 1, true) ~= nil
            if not n then inName = false end
            if not (n or where:find(w, 1, true) or tip:find(w, 1, true)) then all = false; break end
        end
        if all then
            local score = (name:find(q, 1, true) and 4) or (inName and 3) or (where:find(q, 1, true) and 2) or 1
            if e.kind == "page" then score = score + 0.5 end
            hits[#hits + 1] = { entry = e, score = score, order = i }
        end
    end
    table.sort(hits, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.order < b.order
    end)
    return hits
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
            ns:Fill(b.hl, C.fel[1], C.fel[2], C.fel[3], 0.15)
            -- The chosen page's mark: a bar too thin to round, kept flat,
            -- in the accent of the theme in use.
            b.sel = b:CreateTexture(nil, "BACKGROUND")
            b.sel:SetPoint("TOPLEFT")
            b.sel:SetPoint("BOTTOMLEFT")
            b.sel:SetWidth(2)
            b.sel:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
            Chrome:Register(b.sel, "fel", "texture")
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
        ns:TextColor(b.text, (current and "fel") or (e.depth == 0 and "text") or "muted")
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

    -- Classic: the game's window frame is already drawn round the window
    -- (Skin.lua); its title bar is the header, and its close button the
    -- close.
    local game = ns:Game()
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(game and 22 or 30)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(C.shadow[1], C.shadow[2], C.shadow[3], 1)
    Chrome:Register(hbg, "shadow", "texture")
    if game then hbg:Hide() end
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = ns:CreateText(header, 14, "LEFT", "NONE")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(Chrome:TitleMarkup("Wick's UI") .. "  " .. Chrome:Esc("muted") .. tostring(ns.version) .. "|r")

    local close
    if game then
        local ok, made = pcall(CreateFrame, "Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
        if ok and made then
            close = made
            if close:GetNumPoints() == 0 then close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4) end
            close:SetFrameLevel(header:GetFrameLevel() + 2)
            close:SetScript("OnClick", function() frame:Hide() end)
        end
    end
    if not close then
        close = W:Button(header, "x", 22, function() frame:Hide() end)
        close:SetPoint("RIGHT", -4, 0)
    end

    local movers = W:Button(header, "Move frames", 110, function()
        frame:Hide()
        ns.Movers:Unlock()
    end)
    movers:SetPoint("RIGHT", close, "LEFT", game and -2 or -6, 0)

    local keys = W:Button(header, "Keybind mode", 110, function()
        frame:Hide()
        if ns.Keybind then ns.Keybind:Activate() end
    end)
    keys:SetPoint("RIGHT", movers, "LEFT", -6, 0)

    local reload = W:Button(header, "Reload", 70, nil, { reload = true })
    reload:SetPoint("RIGHT", keys, "LEFT", -6, 0)

    -- The page list. Classic: one of the game's insets, as its own windows
    -- set off a list.
    local navBG = CreateFrame("Frame", nil, frame)
    navBG:SetPoint("TOPLEFT", game and 6 or 1, game and -28 or -31)
    navBG:SetPoint("BOTTOMLEFT", game and 6 or 1, game and 6 or 1)
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
    if game then
        nbg:Hide()
        divider:Hide()
        ns:SetTemplate(navBG, "None")
    end

    -- The search box heads the page list; the list starts under it.
    local search = W:EditBox(navBG, nil, NAV_W - 16, nil)
    search:SetPoint("TOPLEFT", 8, -8)
    local hint = ns:CreateText(search, 12, "LEFT", "NONE")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText("Search settings")
    ns:TextColor(hint, "muted")
    local function showHint() hint:SetShown(search:GetText() == "" and not search:HasFocus()) end
    search:SetScript("OnTextChanged", function(self)
        showHint()
        Config:ShowResults(self:GetText())
    end)
    search:HookScript("OnEditFocusGained", function(self)
        showHint()
        -- Back into a box that still holds a search brings its results back.
        if self:GetText() ~= "" then Config:ShowResults(self:GetText()) end
    end)
    search:HookScript("OnEditFocusLost", showHint)
    -- Escape empties it and puts the page back; Enter opens the top result.
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local top = Config.hits and Config.hits[1]
        if top then Config:Go(top.entry) end
    end)
    Config.searchBox = search

    nav = makeScroll(navBG)
    nav:SetPoint("TOPLEFT", 0, -34)
    nav:SetPoint("BOTTOMRIGHT")
    nav.child:SetWidth(NAV_W)

    scroll = makeScroll(frame)
    scroll:SetPoint("TOPLEFT", navBG, "TOPRIGHT", game and 4 or 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", game and -6 or -1, game and 6 or 1)
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
    if self.results then self.results:Hide() end
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
        if title.wickPlate then ns:HeadingColor(title) end
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
    -- The search's list starts as the window opens, a page a frame, so it
    -- is ready by the time anything is typed.
    if not self.index and not self.indexing then
        C_Timer.After(0.5, function() Config:IndexAsync() end)
    end
end

-- The results, in place of the page: each a row with the setting's name
-- (the words found in the accent) over where it lives. A click opens its
-- page at the setting.
local MAX_HITS = 40

local function marked(text, words)
    local low = text:lower()
    local spans = {}
    for _, w in ipairs(words) do
        local s, e = low:find(w, 1, true)
        if s then spans[#spans + 1] = { s, e } end
    end
    table.sort(spans, function(a, b) return a[1] < b[1] end)
    local out, at = {}, 1
    for _, sp in ipairs(spans) do
        if sp[1] >= at then
            out[#out + 1] = text:sub(at, sp[1] - 1)
            out[#out + 1] = Chrome:Esc("fel") .. text:sub(sp[1], sp[2]) .. "|r"
            at = sp[2] + 1
        end
    end
    out[#out + 1] = text:sub(at)
    return table.concat(out)
end

local function resultRow(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(COL_W * 2 + 24, 36)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    ns:Fill(hl, C.fel[1], C.fel[2], C.fel[3], 0.12)
    b.name = ns:CreateText(b, 13, "LEFT", "NONE")
    b.name:SetPoint("TOPLEFT", 8, -4)
    b.name:SetPoint("TOPRIGHT", -8, -4)
    b.name:SetWordWrap(false)
    b.path = ns:CreateText(b, 11, "LEFT", "NONE")
    b.path:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.path:SetPoint("TOPRIGHT", b.name, "BOTTOMRIGHT", 0, -3)
    b.path:SetWordWrap(false)
    b:SetScript("OnClick", function(self) if self.entry then Config:Go(self.entry) end end)
    return b
end

function Config:ShowResults(query)
    if not frame then return end
    -- Until the list is made the results say so, and fill in by themselves
    -- once it is.
    local typed = {}
    for w in (query or ""):gmatch("%S+") do typed[#typed + 1] = w end
    local pending = not self.index and #table.concat(typed, " ") >= 2
    local hits
    if pending then
        hits = {}
        self:IndexAsync(function()
            if frame:IsShown() and Config.searchBox then Config:ShowResults(Config.searchBox:GetText()) end
        end)
    else
        hits = self:Search(query)
    end
    self.hits = hits
    if not hits then
        -- Nothing to search for: the page again.
        if self.results and self.results:IsShown() then self:Show(self.current) end
        return
    end
    local r = self.results
    if not r then
        r = CreateFrame("Frame", nil, scroll.child)
        r:SetPoint("TOPLEFT")
        r:SetWidth(WIDTH - NAV_W - 4)
        r.title = ns:CreateText(r, 18, "LEFT", "NONE")
        ns:HeadingFont(r.title, 18)
        r.title:SetPoint("TOPLEFT", PAD, -PAD)
        if Chrome.SetHeadingText then Chrome:SetHeadingText(r.title, "Search") else r.title:SetText("Search") end
        if r.title.wickPlate then ns:HeadingColor(r.title) end
        r.count = ns:CreateText(r, 12, "LEFT", "NONE")
        r.count:SetPoint("TOPLEFT", PAD, -PAD - 30)
        ns:TextColor(r.count, "muted")
        r.rows = {}
        self.results = r
    end
    if self.current and self.pages[self.current] and self.pages[self.current].content then
        self.pages[self.current].content:Hide()
    end
    local words = {}
    for w in query:lower():gmatch("%S+") do words[#words + 1] = w end
    local n = #hits
    if pending then
        r.count:SetText("Looking through every page...")
    elseif n == 0 then
        r.count:SetText("Nothing matches. Try fewer letters, or another word for it.")
    elseif n > MAX_HITS then
        r.count:SetText(("%d found. The first %d are here; another word narrows them."):format(n, MAX_HITS))
    else
        r.count:SetText(n == 1 and "1 found." or ("%d found."):format(n))
    end
    local y = -PAD - 52
    for i = 1, math.max(#r.rows, math.min(n, MAX_HITS)) do
        local row = r.rows[i]
        local hit = i <= MAX_HITS and hits[i]
        if hit then
            if not row then
                row = resultRow(r)
                r.rows[i] = row
            end
            local e = hit.entry
            row.entry = e
            row.name:SetText(marked(e.text, words))
            ns:TextColor(row.name, "text")
            local where = e.path
            if e.kind == "page" then
                where = e.path == "Page" and "A page" or ("A page under " .. e.path)
            elseif e.kind == "heading" then
                where = "A section of " .. e.path
            end
            row.path:SetText(where)
            ns:TextColor(row.path, "muted")
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", r, "TOPLEFT", PAD, y)
            row:Show()
            y = y - 40
        elseif row then
            row:Hide()
            row.entry = nil
        end
    end
    r:SetHeight(-y + PAD)
    r:Show()
    scroll.child:SetHeight(r:GetHeight())
    scroll:SetVerticalScroll(0)
    if scroll.layoutBar then C_Timer.After(0, scroll.layoutBar) end
end

-- A result opened: its page, scrolled so the setting sits near the top,
-- and the setting lit for a moment so the eye finds it.
local spot
local function light(f, content)
    if not spot then
        spot = CreateFrame("Frame")
        local t = spot:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        ns:Fill(t, C.fel[1], C.fel[2], C.fel[3], 0.2)
        spot:SetScript("OnUpdate", function(self, e)
            self.left = (self.left or 0) - e
            if self.left <= 0 then self:Hide() return end
            self:SetAlpha(math.min(1, self.left / 0.6))
        end)
    end
    spot:SetParent(content)
    spot:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
    spot:ClearAllPoints()
    spot:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 4)
    spot:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -4)
    spot.left = 1.8
    spot:SetAlpha(1)
    spot:Show()
end

function Config:Go(entry)
    local page = entry and entry.page
    if not page then return end
    self:Show(page.key)
    if entry.kind == "page" or not entry.index then return end
    local L = page.layout
    if not L then return end
    -- The control in the same place on the built page, checked by its
    -- name; a page whose controls have moved since is searched by name.
    local f = L.controls[entry.index]
    if f and f.labelText and plain(f.labelText) ~= entry.text then f = nil end
    if not f then
        for _, c in ipairs(L.controls) do
            if c.labelText and plain(c.labelText) == entry.text then f = c; break end
        end
    end
    if not f then return end
    local _, _, _, _, y = f:GetPoint(1)
    local max = math.max(0, scroll.child:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(max, -(y or 0) - 40)))
    if scroll.layoutBar then scroll.layoutBar() end
    light(f, page.content)
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
