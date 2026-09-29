-- Wick's UI
-- Core/Inspect.lua: /wui inspect, a look at whatever is under the pointer.
--
-- For fitting skins to Blizzard's windows without their source to hand:
-- it lists the frame under the pointer, its regions and its children, each
-- with the key it is known by on its parent, its size, its first anchor,
-- whether it shows, its alpha, and its texture or atlas. Read only: it
-- never writes to what it looks at. The list opens in a window it can be
-- copied from.

local ADDON, ns = ...

local W = ns.Widgets
local I = {}
ns.Inspect = I

-- The key a region or child is stored under on its parent, found by
-- looking, so the names match what the Lua code calls them.
local function keyOn(parent, obj)
    if not parent then return nil end
    for k, v in pairs(parent) do
        if v == obj and type(k) == "string" then return k end
    end
end

local function fmt(n) return n and ("%.0f"):format(n) or "?" end

local function describe(obj, parent, indent)
    local kind = obj.GetObjectType and obj:GetObjectType() or "?"
    local name = obj.GetName and obj:GetName()
    local key = keyOn(parent, obj)
    local w, h = 0, 0
    if obj.GetSize then w, h = obj:GetSize() end
    local p, rel, rp, x, y
    if obj.GetPoint then p, rel, rp, x, y = obj:GetPoint(1) end
    local relName = rel and (rel.GetName and rel:GetName() or keyOn(parent, rel) or "(parent)") or ""
    local parts = {
        indent .. kind,
        key and ("." .. key) or "",
        name and (" " .. name) or "",
        (" %sx%s"):format(fmt(w), fmt(h)),
        obj.IsShown and (obj:IsShown() and " shown" or " hidden") or "",
        obj.GetAlpha and (" a=%.2f"):format(obj:GetAlpha()) or "",
    }
    if kind == "Texture" or kind == "MaskTexture" then
        local layer, sub = obj:GetDrawLayer()
        parts[#parts + 1] = (" %s/%s"):format(tostring(layer), tostring(sub))
        local atlas = obj.GetAtlas and obj:GetAtlas()
        if atlas then
            parts[#parts + 1] = " atlas=" .. atlas
        else
            parts[#parts + 1] = " tex=" .. tostring(obj:GetTexture())
        end
    elseif kind == "FontString" then
        parts[#parts + 1] = " text=" .. tostring(obj:GetText())
    else
        if obj.GetFrameLevel then parts[#parts + 1] = " lvl=" .. obj:GetFrameLevel() end
    end
    if p then parts[#parts + 1] = (" @%s %s %s %s,%s"):format(p, relName, rp or "", fmt(x), fmt(y)) end
    return table.concat(parts)
end

local function walk(frame, depth, lines, limit)
    if #lines > 400 then return end
    local indent = ("  "):rep(depth)
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            lines[#lines + 1] = describe(r, frame, indent .. "  ")
        end
    end
    if frame.GetChildren and depth < limit then
        for _, c in ipairs({ frame:GetChildren() }) do
            local key = keyOn(frame, c) or ""
            -- Gamepad hints and glows never matter to a skin: skipped. A
            -- hidden child gets its one line; what is inside it waits until
            -- it shows.
            if not (key:find("JumpHint$") or key == "FrameGlow" or key == "TabIndicators") then
                lines[#lines + 1] = describe(c, frame, indent .. "  ")
                if c:IsShown() then walk(c, depth + 1, lines, limit) end
            end
        end
    end
end

function I:Run()
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    local f = foci and foci[1]
    -- Things that let the mouse through (aura icons, most text) never
    -- become the focus. Then take the smallest of our skinned frames and
    -- aura containers that the pointer is over.
    if not f or f == WorldFrame or f == UIParent then
        local best, area
        local function consider(fr)
            if fr and fr.IsVisible and fr:IsVisible() and fr:IsMouseOver() then
                local w, h = fr:GetSize()
                local a = (w or 0) * (h or 0)
                if a > 0 and (not area or a < area) then best, area = fr, a end
            end
        end
        for fr in pairs(ns.skinned or {}) do
            consider(fr)
            if fr.GetParent then consider(fr:GetParent()) end
        end
        f = best or f
    end
    if not f or f == WorldFrame then
        ns.A:Print("point at something first, then type /wui inspect.")
        return
    end
    local lines = {}
    -- The chain up to the screen, then the frame itself in full, and its
    -- parent one level down, which is usually where the art is.
    local chain, p = {}, f
    while p and p ~= UIParent do
        chain[#chain + 1] = (p.GetName and p:GetName()) or keyOn(p.GetParent and p:GetParent(), p) or "?"
        p = p.GetParent and p:GetParent()
    end
    lines[#lines + 1] = "path: " .. table.concat(chain, " < ")
    lines[#lines + 1] = describe(f, f.GetParent and f:GetParent(), "")
    walk(f, 0, lines, 2)
    local parent = f.GetParent and f:GetParent()
    if parent and parent ~= UIParent then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "parent: " .. describe(parent, parent.GetParent and parent:GetParent(), "")
        walk(parent, 0, lines, 1)
    end
    self:Show(table.concat(lines, "\n"))
end

function I:Show(text)
    local win = self.win
    if not win then
        win = CreateFrame("Frame", "WicksUI_Inspect", UIParent)
        win:SetSize(760, 420)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        win:EnableMouse(true)
        win:SetMovable(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
        ns:SetTemplate(win, "Default", { alpha = 0.97 })
        local title = ns:CreateText(win, 12, "LEFT", "NONE")
        title:SetPoint("TOPLEFT", 10, -9)
        title:SetText("Wick's UI inspect  |cff8f8770select all with Ctrl-A, copy with Ctrl-C, paste it to Wick|r")
        local close = W:Button(win, "x", 20, function() win:Hide() end)
        close:SetPoint("TOPRIGHT", -4, -4)
        local sf = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -30)
        sf:SetPoint("BOTTOMRIGHT", -30, 10)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetWidth(710)
        ns.Media:SetFont(eb, 11, "NONE")
        eb:SetScript("OnEscapePressed", function() win:Hide() end)
        sf:SetScrollChild(eb)
        win.eb = eb
        ns.Core.Chrome:CloseOnEscape(win)
        self.win = win
    end
    win.eb:SetText(text)
    win:Show()
    win.eb:SetFocus()
    win.eb:HighlightText()
end
