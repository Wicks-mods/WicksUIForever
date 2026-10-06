-- Wick's UI
-- Core/Widgets.lua: the controls the config window is built from.
--
-- All of them are our own frames. Blizzard's dropdown menus, static popups
-- and settings controls are shared tables, and on this client an addon
-- that writes into a Blizzard table taints whatever reads it next. So a
-- dropdown here is a list of our own buttons, and a confirm is our own
-- dialog.
--
-- Every control takes a get and a set function and has :Refresh(), which
-- reads get() again. The config window refreshes the whole page after any
-- change, so dependent controls (disabled when a parent toggle is off)
-- follow without being told.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local W = {}
ns.Widgets = W

local ROW = 24

-- ============================================================
-- Classic: the game's own art for the controls
-- ============================================================
-- In the Classic look a control is drawn as the game draws its own: the
-- red button, the gold-rimmed check box, the slider's groove and knob, the
-- input box's ends and middle. Each client's own copy of that art, under
-- the same names on both. A template is used where the game has one for
-- the whole control; otherwise its textures are laid on ours.
local function game() return ns:Game() end

-- A box in the input box's art: the game's Common-Input-Border, ends and
-- a stretched middle, as InputBoxTemplate draws it.
local INPUT = "Interface\\Common\\Common-Input-Border"
local function inputArt(f, inset)
    -- WickCore's, shared with the suite; this copy for a WickCore without it.
    if Chrome.GameInputArt then return Chrome:GameInputArt(f, inset) end
    inset = inset or 0
    local l = f:CreateTexture(nil, "BACKGROUND")
    l:SetTexture(INPUT)
    l:SetTexCoord(0, 0.0625, 0, 0.625)
    l:SetPoint("TOPLEFT", -inset, 0)
    l:SetPoint("BOTTOMLEFT", -inset, 0)
    l:SetWidth(8)
    local r = f:CreateTexture(nil, "BACKGROUND")
    r:SetTexture(INPUT)
    r:SetTexCoord(0.9375, 1, 0, 0.625)
    r:SetPoint("TOPRIGHT", 0, 0)
    r:SetPoint("BOTTOMRIGHT", 0, 0)
    r:SetWidth(8)
    local m = f:CreateTexture(nil, "BACKGROUND")
    m:SetTexture(INPUT)
    m:SetTexCoord(0.0625, 0.9375, 0, 0.625)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    return l, m, r
end
W.GameInputArt = inputArt

local function label(parent, text, size)
    local fs = ns:CreateText(parent, size or 12, "LEFT", "NONE")
    fs:SetText(text or "")
    return fs
end

-- A box that greys out mid-edit drops what was typed: the setting it was
-- for no longer applies.
local function unfocus(p)
    if p and p.HasFocus and p:HasFocus() then
        p.wuiCancel = true
        p:ClearFocus()
    end
end

-- f.parts: what a control has beyond its main part (a slider's number box,
-- a text area's Save and Default). They sit inside it, so its alpha greys
-- them already; they stop taking the mouse and the keyboard with it.
local function setEnabled(f, on)
    f.disabled = not on
    f:SetAlpha(on and 1 or 0.4)
    if f.EnableMouse then f:EnableMouse(on) end
    if f.control then
        f.control.disabled = not on
        if f.control.EnableMouse then f.control:EnableMouse(on) end
    end
    for _, p in ipairs(f.parts or {}) do
        p.disabled = not on
        if p.EnableMouse then p:EnableMouse(on) end
    end
    if not on then
        unfocus(f.control)
        for _, p in ipairs(f.parts or {}) do unfocus(p) end
    end
end

local function refresh(f)
    if f.isDisabled then setEnabled(f, not f.isDisabled()) end
    if f.OnRefresh then f:OnRefresh() end
end

local function base(f, opts)
    f.Refresh = refresh
    f.SetEnabled = setEnabled
    if opts then
        f.isDisabled = opts.disabled
        f.tooltip = opts.tooltip
    end
    return f
end

-- f.hint: a line on how to work the control (a slider's Shift and wheel),
-- under its own tooltip, in the muted colour.
local function tooltipOn(f, host)
    host = host or f
    host:HookScript("OnEnter", function()
        if not f.tooltip and not f.hint then return end
        GameTooltip:SetOwner(host, "ANCHOR_RIGHT")
        GameTooltip:AddLine(f.labelText or "", C.fel[1], C.fel[2], C.fel[3])
        if f.tooltip then GameTooltip:AddLine(f.tooltip, 1, 1, 1, true) end
        if f.hint then GameTooltip:AddLine(f.hint, C.muted[1], C.muted[2], C.muted[3], true) end
        GameTooltip:Show()
    end)
    host:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ============================================================
-- Typing
-- ============================================================
-- A typed value is kept however the box is left: Enter, Tab, a click
-- elsewhere, or its window closing. Escape puts back what was there.
-- Tab and Shift-Tab move between the boxes of one window, in the order
-- they were made, which is the order they read on a page.
local boxes = {}

local function windowOf(f)
    local p = f
    while p.GetParent and p:GetParent() and p:GetParent() ~= UIParent do p = p:GetParent() end
    return p
end

local function tabFrom(self)
    local here
    for i, b in ipairs(boxes) do
        if b == self then here = i; break end
    end
    if not here then return end
    local step = IsShiftKeyDown() and -1 or 1
    local win, n = windowOf(self), #boxes
    for k = 1, n - 1 do
        local b = boxes[(here - 1 + step * k) % n + 1]
        if b:IsVisible() and not b.disabled and windowOf(b) == win then
            self:ClearFocus()
            b:SetFocus()
            if b.HighlightText then b:HighlightText() end
            return
        end
    end
end
W.TabFrom = tabFrom

-- commit(text) runs when the box is left with its text changed; revert()
-- puts the setting's own value back after Escape.
local function typing(box, commit, revert)
    boxes[#boxes + 1] = box
    box:SetScript("OnEditFocusGained", function(self)
        self.wuiStart = self:GetText()
        ns:SetBorderColor(self, "fel")
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ns:SetBorderColor(self, "border")
        local cancel = self.wuiCancel
        self.wuiCancel = nil
        if cancel then
            if revert then revert() end
        elseif commit and self:GetText() ~= self.wuiStart then
            commit(self:GetText())
        end
        self.wuiStart = nil
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        self.wuiCancel = true
        self:ClearFocus()
    end)
    box:SetScript("OnTabPressed", tabFrom)
end

-- ============================================================
-- Button
-- ============================================================
-- opts.reload: the button reloads the interface after onClick (at once,
-- or when a fight ends; see Chrome:Reload).
function W:Button(parent, text, width, onClick, opts)
    local gb
    if game() then
        -- Classic: the game's red button, its gold label and its highlight.
        local ok, made = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
        if ok and made and made.GetFontString then gb = made end
    end
    local b = gb or CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, 22)
    if gb then
        b:SetText(text or "")
        b.text = b:GetFontString()
        b.text:ClearAllPoints()
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        function b:SetSelected(on)
            self.selected = on and true or nil
            if on then self:LockHighlight() else self:UnlockHighlight() end
        end
    else
        ns:SetTemplate(b, "Shadow")
        b.text = label(b, text)
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        b:SetScript("OnEnter", function(self) if not self.disabled then ns:SetBorderColor(self, "fel") end end)
        -- A chosen button (a setup answer) keeps its ring when the pointer leaves.
        b:SetScript("OnLeave", function(self) ns:SetBorderColor(self, self.selected and "fel" or "border") end)
        function b:SetSelected(on)
            self.selected = on and true or nil
            ns:SetBorderColor(self, on and "fel" or "border")
            ns:TextColor(self.text, on and "fel" or "text")
        end
    end
    local reload = opts and opts.reload
    b:SetScript("OnClick", function(self, ...)
        if self.disabled then return end
        if onClick then onClick(self, ...) end
        if reload then
            if Chrome.Reload then Chrome:Reload() else ReloadUI() end
        end
    end)
    b.labelText = text
    base(b, opts)
    tooltipOn(b)
    return b
end

-- ============================================================
-- Check
-- ============================================================
function W:Check(parent, text, get, set, opts)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize((opts and opts.width) or 200, ROW)
    local box = CreateFrame("Frame", nil, f)
    local mark, glow
    if game() then
        -- Classic: the game's check box, its tick and its hover glow.
        box:SetSize(22, 22)
        box:SetPoint("LEFT", -3, 0)
        local up = box:CreateTexture(nil, "BACKGROUND")
        up:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        up:SetAllPoints()
        mark = box:CreateTexture(nil, "ARTWORK")
        mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        mark:SetAllPoints()
        glow = box:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints()
        glow:Hide()
    else
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 0, 0)
        ns:SetTemplate(box, "Shadow")
        mark = box:CreateTexture(nil, "ARTWORK")
        mark:SetPoint("TOPLEFT", 3, -3)
        mark:SetPoint("BOTTOMRIGHT", -3, 3)
        mark:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(mark, "fel", "texture")
    end
    f.text = label(f, text)
    f.text:SetPoint("LEFT", box, "RIGHT", glow and 3 or 6, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.labelText = text
    f:SetScript("OnClick", function(self)
        if self.disabled then return end
        set(not get())
        if self.onChange then self.onChange() end
        self:Refresh()
    end)
    if glow then
        f:SetScript("OnEnter", function() glow:Show() end)
        f:SetScript("OnLeave", function() glow:Hide() end)
    else
        f:SetScript("OnEnter", function() ns:SetBorderColor(box, "fel") end)
        f:SetScript("OnLeave", function() ns:SetBorderColor(box, "border") end)
    end
    f.OnRefresh = function() mark:SetShown(get() and true or false) end
    base(f, opts)
    tooltipOn(f)
    f:Refresh()
    return f
end

-- ============================================================
-- Slider, with a box to type the number
-- ============================================================
function W:Slider(parent, text, min, max, step, get, set, width, opts)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 200
    f:SetSize(width, 38)
    f.text = label(f, text)
    f.text:SetPoint("TOPLEFT", 0, 0)
    f.labelText = text

    local gs
    if game() then
        -- Classic: the game's slider, its groove and its knob.
        local ok, made = pcall(CreateFrame, "Slider", nil, f, "UISliderTemplate")
        if ok and made then gs = made end
    end
    local s = gs or CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 0, gs and -16 or -18)
    s:SetSize(width - 52, gs and 17 or 12)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    if not gs then
        ns:SetTemplate(s, "Shadow")
        local thumb = s:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 14)
        thumb:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
        Chrome:Register(thumb, "fel", "texture")
        s:SetThumbTexture(thumb)
    end
    f.control = s

    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(44, gs and 20 or 18)
    box:SetPoint("LEFT", s, "RIGHT", gs and 10 or 6, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    ns.Media:SetFont(box, 11, "NONE")
    ns:TextColor(box, "text")
    if gs then inputArt(box, 5) else ns:SetTemplate(box, "Shadow") end
    f.parts = { box }

    local function fmt(v)
        if (step or 1) < 1 then return ("%.2f"):format(v) end
        return tostring(math.floor(v + 0.5))
    end

    local busy
    s:SetScript("OnValueChanged", function(_, v, user)
        if busy then return end
        if step and step > 0 then v = math.floor(v / step + 0.5) * step end
        box:SetText(fmt(v))
        if user ~= false then
            set(v)
            if f.onChange then f.onChange() end
        end
    end)
    -- The wheel scrolls the page the slider sits on, so a page can be read
    -- without changing what it passes over; Shift and the wheel turn the
    -- slider. Where nothing scrolls (the mover panel), the wheel turns it.
    s:SetScript("OnMouseWheel", function(self, delta)
        local page = not IsShiftKeyDown() and W.ScrollerOf(f)
        if page then return page:GetScript("OnMouseWheel")(page, delta) end
        if f.disabled then return end
        local v = self:GetValue() + delta * (step or 1)
        self:SetValue(math.max(min, math.min(max, v)))
    end)
    f.hint = "Drag it, type a number in the box, or hold Shift and turn the mouse wheel."
    typing(box, function(text)
        local v = tonumber(text)
        if v then
            -- Typed values may go past the slider's range on purpose,
            -- the way a player types 0.97 scale or a 2000 wide bar.
            set(v)
            if f.onChange then f.onChange() end
        end
        f:Refresh()
    end, function() f:Refresh() end)

    f.OnRefresh = function()
        local v = tonumber(get()) or min
        busy = true
        s:SetValue(math.max(min, math.min(max, v)))
        busy = false
        -- A refresh of the page while a number is being typed leaves it be.
        if not box:HasFocus() then box:SetText(fmt(v)) end
    end
    base(f, opts)
    tooltipOn(f, s)
    f:Refresh()
    return f
end

-- The scrolling page a control sits on, if it sits on one.
function W.ScrollerOf(f)
    local p = f and f.GetParent and f:GetParent()
    while p do
        if p.GetObjectType and p:GetObjectType() == "ScrollFrame" and p:GetScript("OnMouseWheel") then return p end
        p = p.GetParent and p:GetParent()
    end
end

-- ============================================================
-- Dropdown
-- ============================================================
-- values: a list of { value, label } pairs, or a function returning one.
local menu
local function closeMenu() if menu then menu:Hide() end end

local function openMenu(owner, values, current, onPick)
    if not menu then
        menu = CreateFrame("Frame", "WicksUIMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        -- Escape closes an open list too, rather than leaving it over the
        -- game menu.
        Chrome:CloseOnEscape(menu)
        ns:SetTemplate(menu, "Default")
        menu.buttons = {}
        -- Close on any click that lands outside the list.
        menu:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
                if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then self:Hide() end
            end
        end)
        menu.scroll = 0
        menu:EnableMouseWheel(true)
        -- A list longer than the menu shows a slim bar down its right edge,
        -- drawn like the settings' own scroll bar, so it is plain there is
        -- more to wheel through.
        menu.track = menu:CreateTexture(nil, "ARTWORK")
        menu.track:SetPoint("TOPRIGHT", -3, -3)
        menu.track:SetPoint("BOTTOMRIGHT", -3, 3)
        menu.track:SetWidth(3)
        ns:Fill(menu.track, C.border[1], C.border[2], C.border[3], 0.6)
        menu.thumb = menu:CreateTexture(nil, "OVERLAY")
        menu.thumb:SetWidth(3)
        ns:Fill(menu.thumb, C.fel[1], C.fel[2], C.fel[3], 0.8)
    end
    local list = type(values) == "function" and values() or values
    local maxRows = 16
    local width = math.max(owner:GetWidth(), 120)
    for _, b in ipairs(menu.buttons) do b:Hide() end
    local more = #list > maxRows

    local function draw()
        for _, b in ipairs(menu.buttons) do b:Hide() end
        menu.track:SetShown(more)
        menu.thumb:SetShown(more)
        if more then
            local th = maxRows * 18 - 4
            local h = math.max(12, th * maxRows / #list)
            menu.thumb:SetHeight(h)
            menu.thumb:ClearAllPoints()
            menu.thumb:SetPoint("TOPRIGHT", menu.track, "TOPRIGHT", 0, -(th - h) * menu.scroll / (#list - maxRows))
        end
        for row = 1, math.min(#list, maxRows) do
            local i = row + menu.scroll
            local item = list[i]
            if not item then break end
            local b = menu.buttons[row]
            if not b then
                b = CreateFrame("Button", nil, menu)
                b:SetHeight(18)
                b.hl = b:CreateTexture(nil, "HIGHLIGHT")
                b.hl:SetAllPoints()
                ns:Fill(b.hl, C.fel[1], C.fel[2], C.fel[3], 0.25)
                b.text = label(b, "")
                b.text:SetPoint("LEFT", 6, 0)
                b.text:SetPoint("RIGHT", -6, 0)
                menu.buttons[row] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 1, -1 - (row - 1) * 18)
            b:SetPoint("TOPRIGHT", more and -8 or -1, -1 - (row - 1) * 18)
            local text = item[2]
            if item[3] then ns.Media:SetFont(b.text, 12, "NONE", item[3]) else ns.Media:SetFont(b.text, 12, "NONE") end
            if item[1] == current then
                b.text:SetText(Chrome:Esc("fel") .. text .. "|r")
            else
                b.text:SetText(text)
            end
            b:SetScript("OnClick", function() menu:Hide(); onPick(item[1]) end)
            b:Show()
        end
    end
    menu.scroll = 0
    menu:SetScript("OnMouseWheel", function(_, delta)
        menu.scroll = math.max(0, math.min(#list - maxRows, menu.scroll - delta))
        draw()
    end)
    draw()
    menu:SetSize(width, math.min(#list, maxRows) * 18 + 2)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    menu.owner = owner
    menu:Show()
end
W.CloseMenu = closeMenu
W.OpenMenu = openMenu

function W:Dropdown(parent, text, values, get, set, width, opts)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 200
    f:SetSize(width, 42)
    f.text = label(f, text)
    f.text:SetPoint("TOPLEFT", 0, 0)
    f.labelText = text

    local b = CreateFrame("Button", nil, f)
    b:SetPoint("TOPLEFT", game() and 5 or 0, -16)
    b:SetSize(game() and width - 5 or width, 22)
    b.value = label(b, "")
    b.value:SetPoint("LEFT", 6, 0)
    b.value:SetPoint("RIGHT", game() and -26 or -18, 0)
    if game() then
        -- Classic: a field in the input box's art, and the game's down
        -- arrow at its end, as its own drop-down lists have.
        inputArt(b, 5)
        local arrow = CreateFrame("Frame", nil, b)
        arrow:SetSize(24, 24)
        arrow:SetPoint("RIGHT", 2, 0)
        local up = arrow:CreateTexture(nil, "ARTWORK")
        up:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        up:SetAllPoints()
        local hl = arrow:CreateTexture(nil, "OVERLAY")
        hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints()
        hl:Hide()
        b:SetScript("OnEnter", function() if not f.disabled then hl:Show() end end)
        b:SetScript("OnLeave", function() hl:Hide() end)
    else
        ns:SetTemplate(b, "Shadow")
        local arrow = label(b, "v")
        arrow:SetPoint("RIGHT", -6, 0)
        ns:TextColor(arrow, "fel")
        b:SetScript("OnEnter", function() if not f.disabled then ns:SetBorderColor(b, "fel") end end)
        b:SetScript("OnLeave", function() ns:SetBorderColor(b, "border") end)
    end
    f.control = b
    b:SetScript("OnClick", function()
        if f.disabled then return end
        if menu and menu:IsShown() and menu.owner == b then menu:Hide(); return end
        openMenu(b, values, get(), function(v)
            set(v)
            if f.onChange then f.onChange() end
            f:Refresh()
        end)
    end)

    f.OnRefresh = function()
        local cur = get()
        local list = type(values) == "function" and values() or values
        local shown = tostring(cur)
        for _, item in ipairs(list) do
            if item[1] == cur then shown = item[2] break end
        end
        b.value:SetText(shown)
    end
    base(f, opts)
    tooltipOn(f, b)
    f:Refresh()
    return f
end

-- Helper: turn a plain list of strings into dropdown values.
function W.Values(list, labels)
    local out = {}
    for _, v in ipairs(list) do out[#out + 1] = { v, (labels and labels[v]) or v } end
    return out
end

-- ============================================================
-- EditBox (single line, kept when it is left, see Typing)
-- ============================================================
-- f.wuiRevert: what Escape puts back, set by whoever binds the box.
function W:EditBox(parent, text, width, onCommit, opts)
    local f = CreateFrame("EditBox", nil, parent)
    f:SetSize(width or 120, 20)
    f:SetAutoFocus(false)
    ns.Media:SetFont(f, 12, "NONE")
    ns:TextColor(f, "text")
    f:SetTextInsets(4, 4, 0, 0)
    -- Classic: the game's input box ends and middle.
    if game() then inputArt(f, 5) else ns:SetTemplate(f, "Shadow") end
    if text and text ~= "" then
        f.text = label(f, text)
        f.text:SetPoint("RIGHT", f, "LEFT", -4, 0)
    end
    typing(f, function(v) if onCommit then onCommit(v) end end,
        function() if f.wuiRevert then f.wuiRevert() end end)
    base(f, opts)
    return f
end

-- A labelled input bound to a setting.
function W:Input(parent, text, get, set, width, opts)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 200
    f:SetSize(width, 42)
    f.text = label(f, text)
    f.text:SetPoint("TOPLEFT", 0, 0)
    f.labelText = text
    local e = W:EditBox(f, nil, width, function(v) set(v); if f.onChange then f.onChange() end end)
    e:SetPoint("TOPLEFT", 0, -17)
    e.wuiRevert = function() e:SetText(tostring(get() or "")) end
    f.control = e
    f.OnRefresh = function() if not e:HasFocus() then e:SetText(tostring(get() or "")) end end
    base(f, opts)
    tooltipOn(f, e)
    f:Refresh()
    return f
end

-- A multi-line box, for macro-like conditions (paging, visibility).
function W:TextArea(parent, text, get, set, width, height, opts)
    local f = CreateFrame("Frame", nil, parent)
    width, height = width or 420, height or 60
    f:SetSize(width, height + 42)
    f.text = label(f, text)
    f.text:SetPoint("TOPLEFT", 0, 0)
    f.labelText = text
    local bg = CreateFrame("Frame", nil, f)
    bg:SetPoint("TOPLEFT", 0, -17)
    bg:SetSize(width, height)
    ns:SetTemplate(bg, "Shadow")
    local e = CreateFrame("EditBox", nil, bg)
    e:SetMultiLine(true)
    e:SetAutoFocus(false)
    e:SetPoint("TOPLEFT", 4, -4)
    e:SetPoint("BOTTOMRIGHT", -4, 4)
    ns.Media:SetFont(e, 12, "NONE")
    ns:TextColor(e, "text")
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() if not f.disabled then e:SetFocus() end end)
    local save = W:Button(f, "Save", 70, function()
        set(e:GetText())
        e:ClearFocus()
        if f.onChange then f.onChange() end
    end)
    save:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", 0, -3)
    local revert = W:Button(f, "Default", 70, function()
        if opts and opts.default then set(opts.default()) end
        e:ClearFocus()
        if f.onChange then f.onChange() end
        f:Refresh()
    end)
    revert:SetPoint("RIGHT", save, "LEFT", -4, 0)
    revert:SetShown(opts and opts.default ~= nil)
    f.control = e
    f.parts = { bg, save, revert }
    f.OnRefresh = function() if not e:HasFocus() then e:SetText(tostring(get() or "")) end end
    base(f, opts)
    tooltipOn(f, bg)
    f:Refresh()
    return f
end

-- ============================================================
-- Colour swatch
-- ============================================================
-- get returns { r, g, b, a } (array or keyed); set receives { r, g, b, a }.
-- opts.fallback: for a colour that follows the look until one is picked.
-- get() is nil then, and the swatch shows fallback() with the label saying
-- so; a right-click lets a picked colour go again. opts.follows names what
-- it follows on the label ("the game's"), the look's when not given.
local function rgba(c)
    if not c then return 1, 1, 1, 1 end
    return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
end

function W:Color(parent, text, get, set, opts)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize((opts and opts.width) or 200, ROW)
    local sw = CreateFrame("Frame", nil, f)
    sw:SetSize(18, 14)
    sw:SetPoint("LEFT")
    ns:SetTemplate(sw, "None")
    local fill = sw:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    f.text = label(f, text)
    f.text:SetPoint("LEFT", sw, "RIGHT", 6, 0)
    f.labelText = text
    local hasAlpha = opts and opts.alpha
    local fallback = opts and opts.fallback
    local follows = (opts and opts.follows) or "the look's"
    local function current() return get() or (fallback and fallback()) end
    if fallback then
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if not opts.tooltip then
            opts.tooltip = "Follows the look's colours until you pick one. Right-click to follow the look again."
        end
    end

    f:SetScript("OnClick", function(_, button)
        if f.disabled then return end
        if button == "RightButton" then
            if fallback and get() ~= nil then
                set(nil)
                f:Refresh()
                if f.onChange then f.onChange() end
            end
            return
        end
        local r, g, b, a = rgba(current())
        -- Cancelled while following the look, it goes on following it.
        local following = get() == nil
        local function apply()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = hasAlpha and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or 1) or 1
            set({ nr, ng, nb, na })
            f:Refresh()
            if f.onChange then f.onChange() end
        end
        local info = {
            r = r, g = g, b = b,
            opacity = a,
            hasOpacity = hasAlpha,
            swatchFunc = apply,
            opacityFunc = apply,
            cancelFunc = function()
                if following then set(nil) else set({ r, g, b, a }) end
                f:Refresh()
                if f.onChange then f.onChange() end
            end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end
    end)
    f:SetScript("OnEnter", function() ns:SetBorderColor(sw, "fel") end)
    f:SetScript("OnLeave", function() ns:SetBorderColor(sw, "border") end)
    f.OnRefresh = function()
        fill:SetColorTexture(rgba(current()))
        if fallback then
            local following = get() == nil
            f.text:SetText(following and (text .. "  " .. Chrome:Esc("muted") .. follows .. "|r") or text)
        end
    end
    base(f, opts)
    tooltipOn(f)
    f:Refresh()
    return f
end

-- ============================================================
-- Text
-- ============================================================
function W:Heading(parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 440, 26)
    local fs = ns:CreateText(f, 14, "LEFT", "NONE")
    ns:HeadingFont(fs, 14)
    fs:SetPoint("BOTTOMLEFT", 0, 6)
    if Chrome.SetHeadingText then Chrome:SetHeadingText(fs, text) else fs:SetText(text) end
    ns:HeadingColor(fs)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    Chrome:Register(line, "border", "texture")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    f.Refresh = function() end
    return f
end

function W:Note(parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 440
    local fs = ns:CreateText(f, 11, "LEFT", "NONE")
    fs:SetWordWrap(true)
    fs:SetWidth(width)
    fs:SetText(text)
    ns:TextColor(fs, "muted")
    fs:SetPoint("TOPLEFT")
    f:SetSize(width, math.max(14, fs:GetStringHeight() + 4))
    f.Refresh = function() end
    return f
end

-- ============================================================
-- Confirm dialog
-- ============================================================
local confirm
-- opts.reload: the yes button reloads the interface after onYes.
function W:Confirm(text, onYes, yesText, noText, opts)
    if not confirm then
        confirm = CreateFrame("Frame", "WicksUIConfirm", UIParent)
        confirm:SetSize(340, 110)
        confirm:SetPoint("CENTER", 0, 120)
        confirm:SetFrameStrata("FULLSCREEN_DIALOG")
        confirm:EnableMouse(true)
        ns:SetTemplate(confirm, "Default", { brackets = true })
        confirm.text = ns:CreateText(confirm, 12, "CENTER", "NONE")
        confirm.text:SetWordWrap(true)
        confirm.text:SetPoint("TOPLEFT", 14, -14)
        confirm.text:SetPoint("TOPRIGHT", -14, -14)
        confirm.yes = W:Button(confirm, "Yes", 100, function() confirm:Hide(); if confirm.fn then confirm.fn() end end)
        confirm.yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -4, 12)
        -- The same yes, as a button that reloads afterwards.
        confirm.yesReload = W:Button(confirm, "Yes", 100, function() confirm:Hide(); if confirm.fn then confirm.fn() end end, { reload = true })
        confirm.yesReload:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -4, 12)
        confirm.no = W:Button(confirm, "Cancel", 100, function() confirm:Hide() end)
        confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 4, 12)
        Chrome:CloseOnEscape(confirm)
        -- Enter says yes. The dialog listens to the keyboard while it shows
        -- but passes every other key on, so moving and casting still work.
        -- Holding a key back is refused to addons in a fight, so there
        -- Enter goes on to the game as well.
        local function keyboard(on)
            if InCombatLockdown() then return end
            confirm:EnableKeyboard(on)
            confirm:SetPropagateKeyboardInput(true)
        end
        confirm:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            local enter = key == "ENTER" or key == "NUMPADENTER"
            self:SetPropagateKeyboardInput(not enter)
            if enter then
                local yes = self.yes:IsShown() and self.yes or self.yesReload
                yes:Click()
            end
        end)
        -- A new frame starts shown, so its first showing fires no OnShow:
        -- the keyboard is switched on by W:Confirm itself, each time.
        confirm.keyboard = keyboard
        confirm:SetScript("OnHide", function() keyboard(false) end)
    end
    confirm.text:SetText(text)
    local reload = opts and opts.reload
    confirm.yes:SetShown(not reload)
    confirm.yesReload:SetShown(reload and true or false)
    confirm.yes.text:SetText(yesText or "Yes")
    confirm.yesReload.text:SetText(yesText or "Yes")
    confirm.no.text:SetText(noText or "Cancel")
    confirm.fn = onYes
    confirm:SetHeight(math.max(110, confirm.text:GetStringHeight() + 60))
    confirm.keyboard(true)
    confirm:Show()
end
