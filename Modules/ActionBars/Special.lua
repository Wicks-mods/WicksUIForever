-- Wick's UI
-- Modules/ActionBars/Special.lua: the stance bar and the pet bar.
--
-- Both are our own buttons made from Blizzard's templates, so the click
-- itself is Blizzard's secure code, and we draw them ourselves from the
-- stance and pet action APIs. Blizzard's own StanceBar and PetActionBar
-- are taken down with the other bars in ActionBars.lua.
--
-- Cooldowns on both can be secret in combat. They go straight into the
-- Cooldown widget and are never compared.

local ADDON, ns = ...

local AB = ns.ActionBars
local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local S = {}
ns.Special = S

local NUM_STANCE = rawget(_G, "NUM_STANCE_SLOTS") or 10
local NUM_PET = rawget(_G, "NUM_PET_ACTION_SLOTS") or 10

local base = ns.defaults.profile.actionbars
base.stance = AB.barDefaults("stance", {
    enable = true, buttons = NUM_STANCE, perRow = NUM_STANCE, size = 28,
    point = "BOTTOMLEFT,UIParent,BOTTOM,-222,114",
    visibility = "[vehicleui][overridebar][possessbar] hide; show",
})
base.pet = AB.barDefaults("pet", {
    enable = true, buttons = NUM_PET, perRow = NUM_PET, size = 28,
    point = "BOTTOM,UIParent,BOTTOM,0,114",
    visibility = "[pet,novehicleui,nooverridebar,nopossessbar] show; hide",
})

local function styleSimple(b)
    if b.wuiStyled then return end
    b.wuiStyled = true
    local icon = b.icon or b.Icon or _G[b:GetName() .. "Icon"]
    b.wuiIcon = icon
    if b.IconMask and icon and icon.RemoveMaskTexture then icon:RemoveMaskTexture(b.IconMask) end
    for _, key in ipairs({ "SlotArt", "SlotBackground", "FloatingBG" }) do
        local t = b[key]
        if t then t:SetAlpha(0) end
    end
    if b.ClearNormalTexture then b:ClearNormalTexture() end
    local normal = b.GetNormalTexture and b:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    local nt = _G[b:GetName() .. "NormalTexture2"] or _G[b:GetName() .. "NormalTexture"]
    if nt then nt:SetAlpha(0) end
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        ns:CropIcon(icon)
    end
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(C.void[1], C.void[2], C.void[3], 0.6)
    if ns:Modern() then
        ns:SetTemplate(b, "Default")
        bg:Hide()
    else
        ns:SetTemplate(b, "None")
        b.wuiBG:Hide()
    end

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:Fill(hl, 1, 1, 1, 0.12)
    b:SetHighlightTexture(hl)
    local pushed = b:CreateTexture(nil, "ARTWORK", nil, 2)
    pushed:SetPoint("TOPLEFT", 1, -1); pushed:SetPoint("BOTTOMRIGHT", -1, 1)
    ns:Fill(pushed, C.fel[1], C.fel[2], C.fel[3], 0.35)
    b:SetPushedTexture(pushed)
    if b.SetCheckedTexture then
        local checked = b:CreateTexture(nil, "ARTWORK", nil, 1)
        checked:SetPoint("TOPLEFT", 1, -1); checked:SetPoint("BOTTOMRIGHT", -1, 1)
        ns:Fill(checked, C.fel[1], C.fel[2], C.fel[3], 0.3)
        b:SetCheckedTexture(checked)
    end
    local cd = b.cooldown or b.Cooldown or _G[b:GetName() .. "Cooldown"]
    if not cd then
        cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    end
    cd:ClearAllPoints()
    cd:SetPoint("TOPLEFT", 1, -1); cd:SetPoint("BOTTOMRIGHT", -1, 1)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    b.wuiCooldown = cd

    local hk = b.HotKey or _G[b:GetName() .. "HotKey"]
    if not hk then
        hk = b:CreateFontString(nil, "OVERLAY")
        b.HotKey = hk
    end
    hk:ClearAllPoints()
    hk:SetPoint("TOPRIGHT", -1, -3)
    b.wuiHotKey = hk

    b:HookScript("OnEnter", function(self) AB:BarEnter(self:GetParent()) end)
    b:HookScript("OnLeave", function(self) AB:BarLeave(self:GetParent()) end)
end

local function makeButton(bar, i, template, fallbackType)
    local name = bar:GetName() .. "Button" .. i
    local ok, b = pcall(CreateFrame, "CheckButton", name, bar, template)
    if not ok or not b then
        b = CreateFrame("CheckButton", name, bar, "SecureActionButtonTemplate")
        b:SetAttribute("type", fallbackType)
        b:SetAttribute("action", i)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b.icon = b:CreateTexture(nil, "BACKGROUND")
    end
    b:SetID(i)
    styleSimple(b)
    return b
end

local function makeBar(key, label, template, fallbackType, count)
    local bar = CreateFrame("Frame", "WicksUI_" .. key:gsub("^%l", string.upper) .. "Bar", UIParent, "SecureHandlerStateTemplate")
    bar.id = key
    bar:SetSize(1, 1)
    bar:SetFrameStrata("LOW")
    bar.buttons = {}
    bar.backdrop = ns:CreateBackdrop(bar, "Transparent")
    bar.backdrop:Hide()
    for i = 1, count do bar.buttons[i] = makeButton(bar, i, template, fallbackType) end
    bar:SetScript("OnEnter", function(self) AB:BarEnter(self) end)
    bar:SetScript("OnLeave", function(self) AB:BarLeave(self) end)
    ns:CreateMover(bar, key .. "bar", label, AB:db()[key].point, { groups = "actionbars", config = "actionbars." .. key })
    AB.bars[key] = bar
    return bar
end

-- ============================================================
-- Layout, shared by both
-- ============================================================
local function layout(bar, d, shown)
    local w = d.size
    local h = d.keepRatio and d.size or (d.height or d.size)
    local n = math.max(1, math.min(#bar.buttons, d.buttons, shown or #bar.buttons))
    local perRow = math.max(1, math.min(n, d.perRow))
    local rows = math.ceil(n / perRow)
    local sp, pad = d.spacing, d.padding
    local growth = d.growth or "BOTTOMLEFT"
    local up, left = growth:find("BOTTOM") ~= nil, growth:find("LEFT") ~= nil
    local g = AB:db()
    for i, b in ipairs(bar.buttons) do
        b:SetSize(w, h)
        b:ClearAllPoints()
        local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
        local x, y = pad + col * (w + sp), pad + row * (h + sp)
        b:SetPoint(growth, bar, growth, left and x or -x, up and y or -y)
        b:SetShown(i <= n)
        if b.wuiHotKey then
            ns.Media:SetFont(b.wuiHotKey, g.hotkeySize, g.fontOutline, g.font)
            -- The action bars' keybind colour; the look's text colour by
            -- default, which then follows a theme change by itself.
            ns:TextColor(b.wuiHotKey, AB:HotkeyColor())
            b.wuiHotKey:SetShown(d.showHotkey)
        end
    end
    bar:SetSize(pad * 2 + perRow * w + (perRow - 1) * sp, pad * 2 + rows * h + (rows - 1) * sp)
    bar.backdrop:SetShown(d.backdrop)
    ns.Movers:Resize(bar.mover and bar.mover.name or "")
    bar:SetParent(d.globalFade and AB.fader or UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetAlpha(d.mouseover and (d.mouseoverAlpha or 0) or (d.alpha or 1))
end

-- ============================================================
-- Stance
-- ============================================================
function S:UpdateStance()
    local bar = self.stance
    if not bar then return end
    local num = GetNumShapeshiftForms() or 0
    local current = GetShapeshiftForm() or 0
    for i, b in ipairs(bar.buttons) do
        if i <= num then
            local texture, isActive, isCastable = GetShapeshiftFormInfo(i)
            if b.wuiIcon then
                b.wuiIcon:SetTexture(texture)
                b.wuiIcon:SetDesaturated(not isCastable)
            end
            b:SetChecked(isActive or i == current)
            if GetShapeshiftFormCooldown then
                local start, duration = GetShapeshiftFormCooldown(i)
                if start and duration and b.wuiCooldown then b.wuiCooldown:SetCooldown(start, duration) end
            end
        end
    end
end

function S:LayoutStance()
    local bar = self.stance
    local d = AB:db().stance
    local num = GetNumShapeshiftForms() or 0
    layout(bar, d, num)
    if d.enable and num > 0 then
        RegisterStateDriver(bar, "visibility", (d.visibility or "show"):gsub("[\r\n]", " "))
        ns.Movers:SetEnabled("stancebar", true)
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
        ns.Movers:SetEnabled("stancebar", d.enable)
    end
    self:UpdateStance()
end

-- ============================================================
-- Pet
-- ============================================================
function S:UpdatePet()
    local bar = self.pet
    if not bar then return end
    for i, b in ipairs(bar.buttons) do
        local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)
        if isToken and texture then texture = _G[texture] or texture end
        if b.wuiIcon then
            b.wuiIcon:SetTexture(texture)
            b.wuiIcon:SetShown(texture ~= nil)
        end
        b:SetChecked(isActive and true or false)
        local overlay = b.AutoCastOverlay
        if overlay and overlay.SetShown then
            overlay:SetShown(autoCastAllowed and true or false)
            if overlay.ShowAutoCastEnabled then overlay:ShowAutoCastEnabled(autoCastEnabled and true or false) end
        else
            local able = b.AutoCastable or _G[b:GetName() .. "AutoCastable"]
            if able then able:SetShown(autoCastAllowed and true or false) end
            local shine = b.AutoCastShine or _G[b:GetName() .. "Shine"]
            if shine and AutoCastShine_AutoCastStart then
                if autoCastEnabled then AutoCastShine_AutoCastStart(shine) else AutoCastShine_AutoCastStop(shine) end
            end
        end
        if b.wuiIcon then
            local usable = GetPetActionSlotUsable and GetPetActionSlotUsable(i)
            b.wuiIcon:SetDesaturated(texture ~= nil and not usable)
        end
    end
    self:UpdatePetCooldowns()
end

function S:UpdatePetCooldowns()
    local bar = self.pet
    if not bar or not GetPetActionCooldown then return end
    for i, b in ipairs(bar.buttons) do
        local start, duration = GetPetActionCooldown(i)
        if start and duration and b.wuiCooldown then b.wuiCooldown:SetCooldown(start, duration) end
    end
end

function S:LayoutPet()
    local bar = self.pet
    local d = AB:db().pet
    layout(bar, d)
    if d.enable then
        RegisterStateDriver(bar, "visibility", (d.visibility or "show"):gsub("[\r\n]", " "))
        ns.Movers:SetEnabled("petbar", true)
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Hide()
        ns.Movers:SetEnabled("petbar", false)
    end
    self:UpdatePet()
end

-- ============================================================
-- Keybinds and text
-- ============================================================
local function bindingText(target)
    local key = GetBindingKey(target)
    if not key then return "" end
    local text = GetBindingText and GetBindingText(key, 1) or key
    if AB:db().abbreviate then text = AB.Abbreviate(text) end
    return text
end

function S:UpdateBindings()
    for key, prefix in pairs({ stance = "SHAPESHIFTBUTTON", pet = "BONUSACTIONBUTTON" }) do
        local bar = self[key]
        if bar then
            ClearOverrideBindings(bar)
            local d = AB:db()[key]
            for i, b in ipairs(bar.buttons) do
                if b.wuiHotKey then b.wuiHotKey:SetText(bindingText(prefix .. i)) end
                if d.enable then
                    for _, k in ipairs({ GetBindingKey(prefix .. i) }) do
                        if k and k ~= "" then SetOverrideBindingClick(bar, false, k, b:GetName()) end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- Lifecycle
-- ============================================================
function S:Build()
    if self.built then return end
    self.built = true
    self.stance = makeBar("stance", "Stance bar", "StanceButtonTemplate", "stance", NUM_STANCE)
    self.pet = makeBar("pet", "Pet bar", "PetActionButtonTemplate", "pet", NUM_PET)

    local function stanceLayout() ns:AfterCombat("ab:stance", function() S:LayoutStance() end) end
    ns:On("UPDATE_SHAPESHIFT_FORMS", stanceLayout)
    ns:On("PLAYER_ENTERING_WORLD", stanceLayout)
    for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE", "UPDATE_SHAPESHIFT_COOLDOWN", "ACTIONBAR_PAGE_CHANGED" }) do
        ns:On(e, function() S:UpdateStance() end)
    end
    for _, e in ipairs({ "PET_BAR_UPDATE", "PET_UI_UPDATE", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST",
        "PLAYER_FARSIGHT_FOCUS_CHANGED", "SPELLS_CHANGED", "PET_SPECIALIZATION_CHANGED" }) do
        ns:On(e, function() S:UpdatePet() end)
    end
    ns:On("UNIT_PET", function(_, unit) if unit == "player" then S:UpdatePet() end end)
    ns:On("UNIT_FLAGS", function(_, unit) if unit == "pet" then S:UpdatePet() end end)
    ns:On("PET_BAR_UPDATE_COOLDOWN", function() S:UpdatePetCooldowns() end)
end

function S:Update()
    self:Build()
    self:LayoutStance()
    self:LayoutPet()
    self:UpdateBindings()
end

-- ============================================================
-- Settings
-- ============================================================
local function page(key, title, extraNote)
    ns.Config:AddPage("actionbars." .. key, title, function(L)
        L:DB(function() return AB:db()[key] end)
        if extraNote then L:Note(extraNote) end
        L:Toggle("Enable", "enable")
        L:Toggle("Backdrop", "backdrop")
        L:Slider("Buttons", "buttons", 1, 10, 1)
        L:Slider("Buttons per row", "perRow", 1, 10, 1)
        L:Slider("Button size", "size", 14, 64, 1)
        L:Toggle("Square buttons", "keepRatio")
        L:Slider("Button height", "height", 10, 64, 1, { disabled = function() return AB:db()[key].keepRatio end })
        L:Slider("Spacing", "spacing", -1, 20, 1)
        L:Slider("Padding", "padding", 0, 20, 1)
        L:Dropdown("Grow", "growth", {
            { "BOTTOMLEFT", "Up and right" }, { "BOTTOMRIGHT", "Up and left" },
            { "TOPLEFT", "Down and right" }, { "TOPRIGHT", "Down and left" },
        })
        L:Toggle("Keybind text", "showHotkey")
        L:Heading("Fading")
        L:Slider("Opacity", "alpha", 0, 1, 0.05)
        L:Toggle("Fade until moused over", "mouseover")
        L:Slider("Opacity until moused over", "mouseoverAlpha", 0, 1, 0.05, { disabled = function() return not AB:db()[key].mouseover end })
        L:Toggle("Follow the global fade", "globalFade")
        L:Heading("Conditions")
        L:TextArea("Visibility", "visibility", { default = function() return ns.defaults.profile.actionbars[key].visibility end })
    end, { parent = "actionbars", onChange = function() AB:Update() end, order = key == "stance" and 50 or 51 })
end
page("stance", "Stance bar", "Stances, forms, auras and stealth. The bar only appears for a character that has any.")
page("pet", "Pet bar", "Right-click a pet ability to switch its autocast.")
