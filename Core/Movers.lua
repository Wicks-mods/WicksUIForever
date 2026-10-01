-- Wick's UI
-- Core/Movers.lua: unlock, drag, snap, nudge, reset.
--
-- Every frame the addon places gets a mover: a plain frame the same size
-- that it is anchored to. Moving the mover moves the frame. The mover
-- stays hidden until the player unlocks, and only the mover's position is
-- saved, as a point string in the profile.
--
-- Secure frames anchored to a mover inherit its combat rules, so movers
-- can only be unlocked out of combat and lock themselves when a fight
-- starts. That is the client's rule, not a choice.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local Movers = { list = {}, order = {}, groups = {} }
ns.Movers = Movers

local SNAP = 8          -- pixels within which an edge snaps
local unlocked = false
local selected

local function profileMovers()
    local p = ns.A.db and ns.A.db.profile
    if not p then return {} end
    p.movers = p.movers or {}
    return p.movers
end

-- ============================================================
-- Placement
-- ============================================================

-- Which anchor a frame at this position should keep. Frames near the
-- right edge grow leftwards, near the top grow downwards, and so on, so a
-- bar that gains buttons does not walk off the screen.
local function anchorFor(mover)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local cx, cy = mover:GetCenter()
    if not cx then return "CENTER", 0, 0 end
    local s = mover:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = cx * s, cy * s
    local v = (cy > H * 2 / 3) and "TOP" or (cy < H / 3) and "BOTTOM" or ""
    local h = (cx > W * 2 / 3) and "RIGHT" or (cx < W / 3) and "LEFT" or ""
    local point = v .. h
    if point == "" then point = "CENTER" end

    local left, right = mover:GetLeft() * s, mover:GetRight() * s
    local top, bottom = mover:GetTop() * s, mover:GetBottom() * s
    local x, y
    if h == "LEFT" then x = left elseif h == "RIGHT" then x = right - W else x = cx - W / 2 end
    if v == "TOP" then y = top - H elseif v == "BOTTOM" then y = bottom else y = cy - H / 2 end
    return point, math.floor(x + 0.5), math.floor(y + 0.5)
end

local function apply(mover, pointString)
    local point, rel, relPoint, x, y = ns:StringToPoint(pointString)
    mover:ClearAllPoints()
    if point then
        mover:SetPoint(point, rel, relPoint, x, y)
    else
        mover:SetPoint("CENTER")
    end
    mover.anchor = point or "CENTER"
    -- The frame hangs off the same point of the mover, so it grows away
    -- from the anchor the player chose.
    local f = mover.target
    if f and not (f:IsProtected() and InCombatLockdown()) then
        f:ClearAllPoints()
        f:SetPoint(mover.anchor, mover, mover.anchor, 0, 0)
    end
end

function Movers:Place(name)
    local m = self.list[name]
    if not m then return end
    ns:AfterCombat("mover:" .. name, function()
        apply(m, profileMovers()[name] or m.default)
    end)
end

function Movers:PlaceAll()
    for name in pairs(self.list) do self:Place(name) end
end

function Movers:Save(name)
    local m = self.list[name]
    local point, x, y = anchorFor(m)
    local s = ("%s,UIParent,%s,%d,%d"):format(point, point, x, y)
    profileMovers()[name] = s
    apply(m, s)
    if self.nudge and selected == m then self.nudge:Refresh() end
end

function Movers:Reset(name)
    local m = self.list[name]
    if not m then return end
    profileMovers()[name] = nil
    self:Place(name)
    if self.nudge and selected == m then self.nudge:Refresh() end
end

function Movers:ResetAll(group)
    for name, m in pairs(self.list) do
        if not group or m.groups[group] then
            profileMovers()[name] = nil
        end
    end
    self:PlaceAll()
end

-- Keep the mover the size of the frame. Modules call this after a layout.
function Movers:Resize(name)
    local m = self.list[name]
    if not m or not m.target then return end
    local w, h = m.target:GetSize()
    if w and w > 0 and h and h > 0 then
        m:SetSize(w * (m.target:GetScale() or 1), h * (m.target:GetScale() or 1))
    end
end

function Movers:SetEnabled(name, on)
    local m = self.list[name]
    if not m then return end
    m.disabled = not on
    if unlocked then m:SetShown(on and self:InFilter(m)) end
end

-- ============================================================
-- Snapping
-- ============================================================
local function snap(m)
    local l, r, t, b = m:GetLeft(), m:GetRight(), m:GetTop(), m:GetBottom()
    if not l then return end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local dx, dy
    local best = SNAP + 1

    local function tryX(mine, theirs)
        local d = theirs - mine
        if math.abs(d) < best then best = math.abs(d); dx = d end
    end
    local bestY = SNAP + 1
    local function tryY(mine, theirs)
        local d = theirs - mine
        if math.abs(d) < bestY then bestY = math.abs(d); dy = d end
    end

    -- Screen edges and centre lines.
    tryX(l, 0); tryX(r, W); tryX((l + r) / 2, W / 2)
    tryY(b, 0); tryY(t, H); tryY((t + b) / 2, H / 2)

    -- Every other visible mover: edge to edge, and aligned edges.
    for _, o in pairs(Movers.list) do
        if o ~= m and o:IsShown() then
            local ol, or_, ot, ob = o:GetLeft(), o:GetRight(), o:GetTop(), o:GetBottom()
            if ol then
                local overlapY = b < ot + SNAP and t > ob - SNAP
                local overlapX = l < or_ + SNAP and r > ol - SNAP
                if overlapY then tryX(l, or_); tryX(r, ol); tryX(l, ol); tryX(r, or_) end
                if overlapX then tryY(b, ot); tryY(t, ob); tryY(t, ot); tryY(b, ob) end
            end
        end
    end

    if dx or dy then
        m:ClearAllPoints()
        m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l + (dx or 0), b + (dy or 0))
    end
end

-- ============================================================
-- The mover frame
-- ============================================================
local function selectMover(m)
    if selected and selected ~= m then ns:SetBorderColor(selected, "border") end
    selected = m
    if m then
        ns:SetBorderColor(m, "fel")
        Movers:ShowNudge(m)
    end
end

local function onDragStart(m)
    if InCombatLockdown() then return end
    selectMover(m)
    m:StartMoving()
    m.moving = true
end

local function onDragStop(m)
    if not m.moving then return end
    m.moving = nil
    m:StopMovingOrSizing()
    if Movers.snapping ~= false and not IsShiftKeyDown() then snap(m) end
    Movers:Save(m.name)
end

local function onClick(m, button)
    if button == "RightButton" then
        if IsShiftKeyDown() and m.config then
            ns.Config:Open(m.config)
        else
            Movers:Reset(m.name)
        end
    else
        selectMover(m)
    end
end

-- A mover's fill, in the accent: rounded in Modern like everything else,
-- and repainted when the theme changes.
local function moverFill(m, alpha) ns:Fill(m.wuiBG, C.fel[1], C.fel[2], C.fel[3], alpha) end

local function onEnter(m)
    moverFill(m, 0.35)
    GameTooltip:SetOwner(m, "ANCHOR_TOP")
    GameTooltip:AddLine(m.label, C.fel[1], C.fel[2], C.fel[3])
    GameTooltip:AddLine("Drag to move. Shift while dropping skips snapping.", 1, 1, 1)
    GameTooltip:AddLine("Right-click to put it back where it started.", 1, 1, 1)
    if m.config then GameTooltip:AddLine("Shift right-click for its settings.", 1, 1, 1) end
    GameTooltip:AddLine("Click, then arrow keys to nudge a pixel at a time.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function onLeave(m)
    moverFill(m, 0.15)
    GameTooltip:Hide()
end

-- frame:   what moves
-- name:    unique key, used for the saved position
-- label:   what the player reads
-- default: "POINT,UIParent,relPoint,x,y"
-- opts.groups: "actionbars,unitframes", used by the filter
-- opts.config: config page to open on shift right-click
function ns:CreateMover(frame, name, label, default, opts)
    opts = opts or {}
    local m = Movers.list[name]
    if not m then
        m = CreateFrame("Button", "WicksUIMover_" .. name, UIParent)
        m:SetFrameStrata("DIALOG")
        m:SetFrameLevel(100)
        m:SetMovable(true)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        m:RegisterForDrag("LeftButton")
        m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        ns:SetTemplate(m, "None")
        m.wuiBG:Show()
        moverFill(m, 0.15)
        m.text = ns:CreateText(m, 11, "CENTER")
        m.text:SetPoint("CENTER")
        m:SetScript("OnDragStart", onDragStart)
        m:SetScript("OnDragStop", onDragStop)
        m:SetScript("OnClick", onClick)
        m:SetScript("OnEnter", onEnter)
        m:SetScript("OnLeave", onLeave)
        m:Hide()
        Movers.list[name] = m
        Movers.order[#Movers.order + 1] = name
    end
    m.name = name
    m.label = label or name
    m.text:SetText(m.label)
    m.target = frame
    -- The shipped layout's place (Core/Layout.lua) first, then the module's.
    local shipped = ns.defaults.profile.movers
    m.default = (shipped and shipped[name]) or default or "CENTER,UIParent,CENTER,0,0"
    m.config = opts.config
    m.groups = {}
    for _, g in ipairs(ns:List(opts.groups or "")) do
        m.groups[g] = true
        Movers.groups[g] = true
    end
    frame.mover = m
    Movers:Resize(name)
    if m:GetWidth() < 1 then m:SetSize(opts.width or 100, opts.height or 20) end
    Movers:Place(name)
    return m
end

-- ============================================================
-- Unlock and lock
-- ============================================================
Movers.filter = "all"

function Movers:InFilter(m)
    return self.filter == "all" or m.groups[self.filter]
end

function Movers:IsUnlocked() return unlocked end

function Movers:Unlock()
    if InCombatLockdown() then
        ns.A:Print("frames cannot be moved in combat. Try again once the fight is over.")
        return
    end
    unlocked = true
    for _, m in pairs(self.list) do
        self:Resize(m.name)
        m:SetShown(not m.disabled and self:InFilter(m))
    end
    self:ShowGrid(ns:G().gridSize or 32)
    self:ShowPanel()
end

function Movers:Lock()
    unlocked = false
    for _, m in pairs(self.list) do
        if m.moving then onDragStop(m) end
        m:Hide()
    end
    selectMover(nil)
    if self.grid then self.grid:Hide() end
    if self.panel then self.panel:Hide() end
    if self.nudge then self.nudge:Hide() end
    -- The panel's Show dropdown, if it was left open.
    if ns.Widgets and ns.Widgets.CloseMenu then ns.Widgets.CloseMenu() end
end

function Movers:Toggle()
    if unlocked then self:Lock() else self:Unlock() end
end

ns:On("PLAYER_REGEN_DISABLED", function()
    if unlocked then
        Movers:Lock()
        ns.A:Print("frames locked for combat.")
    end
end)

-- ============================================================
-- The grid
-- ============================================================
function Movers:ShowGrid(size)
    size = math.max(8, size or 32)
    local g = self.grid
    if not g then
        g = CreateFrame("Frame", "WicksUIGrid", UIParent)
        g:SetAllPoints(UIParent)
        g:SetFrameStrata("BACKGROUND")
        g.lines = {}
        self.grid = g
    end
    for _, l in ipairs(g.lines) do l:Hide() end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local px = ns.mult or 1
    local n = 0
    local function line(vertical, pos, centre)
        n = n + 1
        local l = g.lines[n]
        if not l then
            l = g:CreateTexture(nil, "BACKGROUND")
            g.lines[n] = l
        end
        l:ClearAllPoints()
        if centre then
            l:SetColorTexture(C.fel[1], C.fel[2], C.fel[3], 0.6)
        else
            l:SetColorTexture(0, 0, 0, 0.5)
        end
        if vertical then
            l:SetPoint("TOPLEFT", g, "TOPLEFT", pos, 0)
            l:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", pos, 0)
            l:SetWidth(centre and px * 2 or px)
        else
            l:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, pos)
            l:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, pos)
            l:SetHeight(centre and px * 2 or px)
        end
        l:Show()
    end
    -- Out from the centre, so the centre lines are always on the grid.
    local cx, cy = W / 2, H / 2
    line(true, cx, true); line(false, cy, true)
    for x = cx + size, W, size do line(true, x) end
    for x = cx - size, 0, -size do line(true, x) end
    for y = cy + size, H, size do line(false, y) end
    for y = cy - size, 0, -size do line(false, y) end
    g:Show()
end

-- ============================================================
-- The unlock panel and the nudge panel
-- ============================================================
function Movers:ShowPanel()
    local p = self.panel
    if not p then
        p = CreateFrame("Frame", "WicksUIMoverPanel", UIParent)
        p:SetSize(300, 116)
        p:SetPoint("TOP", 0, -60)
        p:SetFrameStrata("DIALOG")
        p:SetFrameLevel(200)
        p:EnableMouse(true)
        p:SetMovable(true)
        p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart", p.StartMoving)
        p:SetScript("OnDragStop", p.StopMovingOrSizing)
        ns:SetTemplate(p, "Default", { brackets = true })
        -- Escape locks the frames, so none is left unlocked with no panel
        -- to lock it from. Only the panel's own hiding counts; hiding the
        -- whole interface (Alt-Z) leaves everything as it was.
        Chrome:CloseOnEscape(p)
        p:SetScript("OnHide", function(self)
            if not self:IsShown() and unlocked then Movers:Lock() end
        end)

        local title = ns:CreateText(p, 13, "CENTER")
        title:SetPoint("TOP", 0, -8)
        title:SetText(Chrome:TitleMarkup("Wick's UI") .. "  " .. Chrome:Esc("muted") .. "frames unlocked|r")

        local W = ns.Widgets
        local lock = W:Button(p, "Lock", 80, function() Movers:Lock() end)
        lock:SetPoint("BOTTOMRIGHT", -10, 10)

        local reset = W:Button(p, "Reset shown", 100, function()
            W:Confirm("Put every frame shown here back where it started?", function()
                Movers:ResetAll(Movers.filter ~= "all" and Movers.filter or nil)
            end, "Reset")
        end)
        reset:SetPoint("RIGHT", lock, "LEFT", -6, 0)

        local snapBox = W:Check(p, "Snap", function() return Movers.snapping ~= false end,
            function(v) Movers.snapping = v end)
        snapBox:SetPoint("BOTTOMLEFT", 10, 10)

        local grid = W:Slider(p, "Grid", 8, 128, 4, function() return ns:G().gridSize or 32 end,
            function(v) ns:G().gridSize = v; Movers:ShowGrid(v) end, 130)
        grid:SetPoint("TOPLEFT", 12, -44)

        local function groupValues()
            local out = { { "all", "Everything" } }
            local names = {}
            for g in pairs(Movers.groups) do names[#names + 1] = g end
            table.sort(names)
            for _, g in ipairs(names) do out[#out + 1] = { g, ns.groupLabels[g] or g } end
            return out
        end
        local filter = W:Dropdown(p, "Show", groupValues, function() return Movers.filter end,
            function(v)
                Movers.filter = v
                for _, m in pairs(Movers.list) do m:SetShown(not m.disabled and Movers:InFilter(m)) end
            end, 120)
        filter:SetPoint("TOPRIGHT", -12, -38)

        self.panel = p
    end
    p:Show()
end

ns.groupLabels = {
    actionbars = "Action bars",
    unitframes = "Unit frames",
    group      = "Party and raid",
    auras      = "Buffs",
    misc       = "Everything else",
    datatexts  = "Info panels",
}

function Movers:ShowNudge(m)
    local n = self.nudge
    if not n then
        n = CreateFrame("Frame", "WicksUINudge", UIParent)
        n:SetSize(220, 92)
        n:SetFrameStrata("DIALOG")
        n:SetFrameLevel(200)
        n:EnableMouse(true)
        n:EnableKeyboard(true)
        n:SetPropagateKeyboardInput(true)
        ns:SetTemplate(n, "Default")
        -- Escape closes it with the panel above it.
        Chrome:CloseOnEscape(n)
        n:SetScript("OnHide", function(self)
            if not self:IsShown() and selected then selectMover(nil) end
        end)
        n.title = ns:CreateText(n, 12, "CENTER")
        n.title:SetPoint("TOP", 0, -6)

        local W = ns.Widgets
        n.x = W:EditBox(n, "X", 60, function(v)
            local m2 = selected; if not m2 then return end
            local point, _, _, _, y = ns:StringToPoint(profileMovers()[m2.name] or m2.default)
            local s = ("%s,UIParent,%s,%d,%d"):format(point, point, tonumber(v) or 0, y)
            profileMovers()[m2.name] = s
            apply(m2, s)
        end)
        n.x:SetPoint("TOPLEFT", 24, -30)
        n.y = W:EditBox(n, "Y", 60, function(v)
            local m2 = selected; if not m2 then return end
            local point, _, _, x = ns:StringToPoint(profileMovers()[m2.name] or m2.default)
            local s = ("%s,UIParent,%s,%d,%d"):format(point, point, x, tonumber(v) or 0)
            profileMovers()[m2.name] = s
            apply(m2, s)
        end)
        n.y:SetPoint("LEFT", n.x, "RIGHT", 30, 0)
        -- Escape in either box puts back where the frame is.
        n.x.wuiRevert = function() n:Refresh() end
        n.y.wuiRevert = function() n:Refresh() end

        local reset = W:Button(n, "Reset", 70, function() if selected then Movers:Reset(selected.name) end end)
        reset:SetPoint("BOTTOMLEFT", 10, 8)
        local done = W:Button(n, "Done", 70, function() selectMover(nil); n:Hide() end)
        done:SetPoint("BOTTOMRIGHT", -10, 8)

        n:SetScript("OnKeyDown", function(self, key)
            local m2 = selected
            local step = IsShiftKeyDown() and 10 or 1
            local dx = (key == "LEFT" and -step) or (key == "RIGHT" and step) or 0
            local dy = (key == "DOWN" and -step) or (key == "UP" and step) or 0
            if not m2 or (dx == 0 and dy == 0) or InCombatLockdown() then
                self:SetPropagateKeyboardInput(true)
                return
            end
            self:SetPropagateKeyboardInput(false)
            local point, _, _, x, y = ns:StringToPoint(profileMovers()[m2.name] or m2.default)
            local s = ("%s,UIParent,%s,%d,%d"):format(point, point, x + dx, y + dy)
            profileMovers()[m2.name] = s
            apply(m2, s)
            self:Refresh()
        end)

        function n:Refresh()
            local m2 = selected
            if not m2 then return end
            local point, _, _, x, y = ns:StringToPoint(profileMovers()[m2.name] or m2.default)
            self.title:SetText(m2.label .. "  " .. Chrome:Esc("muted") .. (point or "") .. "|r")
            self.x:SetText(tostring(x or 0))
            self.y:SetText(tostring(y or 0))
        end
        self.nudge = n
    end
    n:ClearAllPoints()
    if self.panel and self.panel:IsShown() then
        n:SetPoint("TOP", self.panel, "BOTTOM", 0, -4)
    else
        n:SetPoint("TOP", 0, -180)
    end
    n:Refresh()
    n:Show()
end
