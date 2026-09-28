-- WickGlow: a stand-in for LibButtonGlow-1.0.
--
-- LibActionButton lights a button that has a proc through
-- LibButtonGlow-1.0 when that library is present, and draws nothing when
-- it is not. This registers the same name at the lowest possible version,
-- so the real library replaces it whenever another addon ships it, and
-- until then a proc draws a pulsing fel frame around the button instead
-- of Blizzard's spinning ants.
--
-- MIT, part of Wick's UI.

local lib = LibStub:NewLibrary("LibButtonGlow-1.0", 1)
if not lib then return end

local BLANK = "Interface\\Buttons\\WHITE8X8"
local FEL = { 0.310, 0.780, 0.471 }

lib.color = lib.color or FEL
lib.pool = lib.pool or {}

local function makeGlow(parent)
    local g = CreateFrame("Frame", nil, parent)
    g:SetFrameLevel(parent:GetFrameLevel() + 5)
    g.edges = {}
    for i = 1, 4 do
        local t = g:CreateTexture(nil, "OVERLAY")
        t:SetTexture(BLANK)
        g.edges[i] = t
    end
    local e = g.edges
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(2)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(2)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(2)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(2)
    local fill = g:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetTexture(BLANK)
    g.fill = fill

    local ag = g:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.35)
    a:SetDuration(0.45)
    a:SetSmoothing("IN_OUT")
    g.anim = ag
    return g
end

function lib.ShowOverlayGlow(frame)
    local g = frame.__WickGlow
    if not g then
        g = makeGlow(frame)
        frame.__WickGlow = g
    end
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    g:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    local c = lib.color
    for _, t in ipairs(g.edges) do t:SetVertexColor(c[1], c[2], c[3], 1) end
    g.fill:SetVertexColor(c[1], c[2], c[3], 0.18)
    g:Show()
    g.anim:Play()
end

function lib.HideOverlayGlow(frame)
    local g = frame.__WickGlow
    if g then
        g.anim:Stop()
        g:Hide()
    end
end
