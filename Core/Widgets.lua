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

local function label(parent, text, size)
    local fs = ns:CreateText(parent, size or 12, "LEFT", "NONE")
    fs:SetText(text or "")
    return fs
end

local function setEnabled(f, on)
    f.disabled = not on
    f:SetAlpha(on and 1 or 0.4)
    if f.EnableMouse then f:EnableMouse(on) end
    if f.control and f.control.EnableMouse then f.control:EnableMouse(on) end
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

local function tooltipOn(f, host)
    host = host or f
    host:HookScript("OnEnter", function()
        if not f.tooltip then return end
        GameTooltip:SetOwner(host, "ANCHOR_RIGHT")
        GameTooltip:AddLine(f.labelText or "", C.fel[1], C.fel[2], C.fel[3])
        GameTooltip:AddLine(f.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    host:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ============================================================
-- Button
-- ============================================================
function W:Button(parent, text, width, onClick, opts)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, 22)
    ns:SetTemplate(b, "Shadow")
    b.text = label(b, text)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b:SetScript("OnEnter", function(self) if not self.disabled then ns:SetBorderColor(self, "fel") end end)
    b:SetScript("OnLeave", function(self) ns:SetBorderColor(self, "border") end)
    b:SetScript("OnClick", function(self, ...) if not self.disabled and onClick then onClick(self, ...) end end)
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
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)
    ns:SetTemplate(box, "Shadow")
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", -3, 3)
    mark:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
    Chrome:Register(mark, "fel", "texture")
    f.text = label(f, text)
    f.text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    f.labelText = text
    f:SetScript("OnClick", function(self)
        if self.disabled then return end
        set(not get())
        if self.onChange then self.onChange() end
        self:Refresh()
    end)
    f:SetScript("OnEnter", function() ns:SetBorderColor(box, "fel") end)
    f:SetScript("OnLeave", function() ns:SetBorderColor(box, "border") end)
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

    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 0, -18)
    s:SetSize(width - 52, 12)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    ns:SetTemplate(s, "Shadow")
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    thumb:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 1)
    Chrome:Register(thumb, "fel", "texture")
    s:SetThumbTexture(thumb)
    f.control = s

    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(44, 18)
    box:SetPoint("LEFT", s, "RIGHT", 6, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")
    ns.Media:SetFont(box, 11, "NONE")
    box:SetTextColor(C.text[1], C.text[2], C.text[3])
    ns:SetTemplate(box, "Shadow")

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
    s:SetScript("OnMouseWheel", function(self, delta)
        if f.disabled then return end
        local v = self:GetValue() + delta * (step or 1)
        self:SetValue(math.max(min, math.min(max, v)))
    end)
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            -- Typed values may go past the slider's range on purpose,
            -- the way a player types 0.97 scale or a 2000 wide bar.
            set(v)
            if f.onChange then f.onChange() end
        end
        self:ClearFocus()
        f:Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)

    f.OnRefresh = function()
        local v = tonumber(get()) or min
        busy = true
        s:SetValue(math.max(min, math.min(max, v)))
        busy = false
        box:SetText(fmt(v))
    end
    base(f, opts)
    tooltipOn(f, s)
    f:Refresh()
    return f
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
    end
    local list = type(values) == "function" and values() or values
    local maxRows = 16
    local width = math.max(owner:GetWidth(), 120)
    for _, b in ipairs(menu.buttons) do b:Hide() end

    local function draw()
        for _, b in ipairs(menu.buttons) do b:Hide() end
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
                b.hl:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.25)
                b.text = label(b, "")
                b.text:SetPoint("LEFT", 6, 0)
                b.text:SetPoint("RIGHT", -6, 0)
                menu.buttons[row] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 1, -1 - (row - 1) * 18)
            b:SetPoint("TOPRIGHT", -1, -1 - (row - 1) * 18)
            local text = item[2]
            if item[3] then ns.Media:SetFont(b.text, 12, "NONE", item[3]) else ns.Media:SetFont(b.text, 12, "NONE") end
            if item[1] == current then
                b.text:SetText("|cff4FC778" .. text .. "|r")
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
    b:SetPoint("TOPLEFT", 0, -16)
    b:SetSize(width, 22)
    ns:SetTemplate(b, "Shadow")
    b.value = label(b, "")
    b.value:SetPoint("LEFT", 6, 0)
    b.value:SetPoint("RIGHT", -18, 0)
    local arrow = label(b, "v")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
    f.control = b

    b:SetScript("OnEnter", function() if not f.disabled then ns:SetBorderColor(b, "fel") end end)
    b:SetScript("OnLeave", function() ns:SetBorderColor(b, "border") end)
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
-- EditBox (single line, commits on Enter)
-- ============================================================
function W:EditBox(parent, text, width, onCommit, opts)
    local f = CreateFrame("EditBox", nil, parent)
    f:SetSize(width or 120, 20)
    f:SetAutoFocus(false)
    ns.Media:SetFont(f, 12, "NONE")
    f:SetTextColor(C.text[1], C.text[2], C.text[3])
    f:SetTextInsets(4, 4, 0, 0)
    ns:SetTemplate(f, "Shadow")
    if text and text ~= "" then
        f.text = label(f, text)
        f.text:SetPoint("RIGHT", f, "LEFT", -4, 0)
    end
    f:SetScript("OnEnterPressed", function(self)
        if onCommit then onCommit(self:GetText()) end
        self:ClearFocus()
    end)
    f:SetScript("OnEscapePressed", function(self) self:ClearFocus(); if self.Refresh then self:Refresh() end end)
    f:SetScript("OnEditFocusGained", function(self) ns:SetBorderColor(self, "fel") end)
    f:SetScript("OnEditFocusLost", function(self) ns:SetBorderColor(self, "border") end)
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
    e:SetTextColor(C.text[1], C.text[2], C.text[3])
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Refresh() end)
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() e:SetFocus() end)
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

    f:SetScript("OnClick", function()
        if f.disabled then return end
        local r, g, b, a = rgba(get())
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
                set({ r, g, b, a })
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
    f.OnRefresh = function() fill:SetColorTexture(rgba(get())) end
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
    fs:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
    if Chrome.SetHeadingText then Chrome:SetHeadingText(fs, text) else fs:SetText(text) end
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
    fs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    fs:SetPoint("TOPLEFT")
    f:SetSize(width, math.max(14, fs:GetStringHeight() + 4))
    f.Refresh = function() end
    return f
end

-- ============================================================
-- Confirm dialog
-- ============================================================
local confirm
function W:Confirm(text, onYes, yesText)
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
        confirm.no = W:Button(confirm, "Cancel", 100, function() confirm:Hide() end)
        confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 4, 12)
        Chrome:CloseOnEscape(confirm)
    end
    confirm.text:SetText(text)
    confirm.yes.text:SetText(yesText or "Yes")
    confirm.fn = onYes
    confirm:SetHeight(math.max(110, confirm.text:GetStringHeight() + 60))
    confirm:Show()
end
