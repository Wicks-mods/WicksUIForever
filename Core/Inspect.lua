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

local function secret(v) return issecretvalue and issecretvalue(v) end
local function fmt(n)
    if secret(n) then return "secret" end
    return type(n) == "number" and ("%.0f"):format(n) or "?"
end
-- A value the client hands out as a secret (sizes and places of aura
-- buttons in combat, their text) is shown as the word, never used.
local function safeText(v)
    if secret(v) then return "secret" end
    return tostring(v)
end

local function describeUnsafe(obj, parent, indent)
    local kind = obj.GetObjectType and obj:GetObjectType() or "?"
    local name = obj.GetName and obj:GetName()
    local key = keyOn(parent, obj)
    local w, h = 0, 0
    if obj.GetSize then w, h = obj:GetSize() end
    local p, rel, rp, x, y
    if obj.GetPoint then p, rel, rp, x, y = obj:GetPoint(1) end
    if secret(p) then p = "secret" end
    if secret(rp) then rp = "secret" end
    local relName
    if secret(rel) then relName = "secret"
    else relName = rel and (rel.GetName and rel:GetName() or keyOn(parent, rel) or "(parent)") or "" end
    local parts = {
        indent .. kind,
        key and ("." .. key) or "",
        name and (" " .. name) or "",
        (" %sx%s"):format(fmt(w), fmt(h)),
        obj.IsShown and (secret(obj:IsShown()) and " shown?" or (obj:IsShown() and " shown" or " hidden")) or "",
        obj.GetAlpha and (secret(obj:GetAlpha()) and " a=secret" or (" a=%.2f"):format(obj:GetAlpha())) or "",
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
        parts[#parts + 1] = " text=" .. safeText(obj:GetText())
        local font, size = obj:GetFont()
        parts[#parts + 1] = (" font=%s/%s"):format(safeText(font and font:match("[^\/]+$") or font), fmt(size))
    else
        if obj.GetFrameLevel then parts[#parts + 1] = " lvl=" .. obj:GetFrameLevel() end
    end
    if p then
        parts[#parts + 1] = (" @%s %s %s %s,%s"):format(safeText(p), safeText(relName), safeText(rp or ""), fmt(x), fmt(y))
    end
    -- Any piece that came back secret (a place, a name) is shown as the word.
    for i, v in ipairs(parts) do
        if secret(v) then parts[i] = " secret" end
    end
    return table.concat(parts)
end

local function describe(obj, parent, indent)
    local ok, line = pcall(describeUnsafe, obj, parent, indent)
    if ok then return line end
    return indent .. "(could not read: " .. tostring(line) .. ")"
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
                -- A secret "shown" is walked into: better too much than nothing.
                local shown = c:IsShown()
                if secret(shown) or shown then walk(c, depth + 1, lines, limit) end
            end
        end
    end
end

-- A frame by the name the frame stack shows ("MinimapCluster.DielFrame"):
-- a global, then keys down from it.
local function byPath(path)
    local obj
    for part in path:gmatch("[^%.]+") do
        if obj == nil then obj = rawget(_G, part) else obj = type(obj) == "table" and obj[part] or nil end
        if obj == nil then return nil end
    end
    return type(obj) == "table" and obj.GetObjectType and obj or nil
end

-- The first shown aura button on a unit frame ("auras" is the target's),
-- since aura buttons let the mouse through and a pointer never finds them.
local function firstAura(unit)
    local uf = rawget(_G, "WicksUI_" .. unit:gsub("^%l", string.upper))
    if not uf then return nil end
    for _, which in ipairs({ "wuibuffs", "wuidebuffs" }) do
        local a = uf[which]
        if a and a.GetChildren then
            for _, b in ipairs({ a:GetChildren() }) do
                local shown = b:IsShown()
                if b.Cooldown and (secret(shown) or shown) then return b end
            end
        end
    end
end

function I:Run(path)
    local f
    if path == "auras" or (path and path:match("^auras:")) then
        local unit = path:match("^auras:(%a+)") or "target"
        f = firstAura(unit)
        if not f then
            ns.A:Print(("no aura showing on the %s frame."):format(unit))
            return
        end
    elseif path and path ~= "" then
        f = byPath(path)
        if not f then
            ns.A:Print(("no frame called %s. Use the name the frame stack shows."):format(path))
            return
        end
        if f.IsForbidden and f:IsForbidden() then
            ns.A:Print(("%s is one of Blizzard's protected frames; nothing can read it."):format(path))
            return
        end
    end
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    f = f or (foci and foci[1])
    -- What the pointer is on can be one of Blizzard's protected frames (an
    -- aura's tooltip region is), which nothing may read.
    if f and f.IsForbidden and f:IsForbidden() then
        ns.A:Print("that is one of Blizzard's protected frames; nothing can read it. For auras, use /wui inspect auras.")
        return
    end
    -- Things that let the mouse through (aura icons, most text) never
    -- become the focus. Then take the smallest of our skinned frames and
    -- aura containers that the pointer is over.
    if not f or f == WorldFrame or f == UIParent then
        local best, area
        local function consider(fr)
            local okV, vis = pcall(function() return fr and fr.IsVisible and fr:IsVisible() and fr:IsMouseOver() end)
            if okV and vis and not secret(vis) then
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
    win.eb:ClearFocus()
    win:Show()
    -- Focus waits a moment: run from a keybound macro, the key's own
    -- character would otherwise land in the box and replace the dump.
    C_Timer.After(0.15, function()
        if not win:IsShown() then return end
        win.eb:SetText(text)
        win.eb:SetFocus()
        win.eb:HighlightText()
    end)
end
