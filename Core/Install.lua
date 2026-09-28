-- Wick's UI
-- Core/Install.lua: the first-run setup.
--
-- Four pages: welcome, scale, layout, done. Nothing is applied until the
-- player presses a button on a page, and every page can be skipped. It
-- runs once per profile; /wui install brings it back.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local I = {}
ns.Install = I

-- Layout presets move the frames, nothing else.
I.LAYOUTS = {
    damage = {
        label = "Damage or tank",
        movers = {
            uf_player = "BOTTOM,UIParent,BOTTOM,-300,210",
            uf_target = "BOTTOM,UIParent,BOTTOM,300,210",
            uf_party = "LEFT,UIParent,LEFT,30,80",
            uf_raid = "TOPLEFT,UIParent,TOPLEFT,30,-300",
        },
    },
    healer = {
        label = "Healer",
        movers = {
            uf_player = "BOTTOM,UIParent,BOTTOM,-420,260",
            uf_target = "BOTTOM,UIParent,BOTTOM,420,260",
            uf_party = "BOTTOM,UIParent,BOTTOM,0,190",
            uf_raid = "BOTTOM,UIParent,BOTTOM,0,190",
        },
        settings = function(p)
            local party = p.unitframes.units.party
            party.growth = "RIGHT"
            party.width, party.height = 110, 50
            party.texts.left.point, party.texts.left.x, party.texts.left.y = "TOP", 0, -4
            party.texts.right.point, party.texts.right.x, party.texts.right.y = "BOTTOM", 0, 6
            party.debuffs.enable = false
            local raid = p.unitframes.units.raid
            raid.growth, raid.columnGrowth = "RIGHT", "UP"
            raid.width, raid.height = 90, 44
        end,
    },
}

function I:ApplyLayout(key)
    local L = self.LAYOUTS[key]
    local p = ns.A.db.profile
    for name, point in pairs(L.movers) do p.movers[name] = point end
    if L.settings then L.settings(p) end
    ns.Movers:PlaceAll()
    ns:UpdateAll()
end

local PAGES = {
    {
        title = "Welcome",
        text = "Wick's UI replaces the game's action bars, unit frames, group frames, nameplates, buffs, chat, minimap and tooltips, in the flat Wick look. Every part can be switched off in the settings, and anything switched off is left exactly as the game made it.\n\nThis takes a minute. Each step can be skipped.",
    },
    {
        title = "Scale",
        text = "Pixel perfect sets the game's interface scale so one interface pixel is one screen pixel, which is what keeps thin borders sharp. On a large monitor it makes everything smaller; the scale can be changed any time under General.",
        button = "Pixel perfect", action = function()
            ns:G().uiScale = ns:Round(ns:PixelPerfectScale(), 4)
            ns:ApplyScale()
        end,
    },
    {
        title = "Layout",
        text = "Where the frames start. Damage and tank keeps your frames either side of the middle with the group on the left. Healer puts the group frames in the middle, where your eyes are, and moves yours out of the way. Everything can be moved afterwards with /wui move.",
        choices = { { "damage", "Damage or tank" }, { "healer", "Healer" } },
    },
    {
        title = "Done",
        text = "Type |cff4FC778/wui|r for the settings, |cff4FC778/wui move|r to place frames and |cff4FC778/wui kb|r to bind keys by pointing at a button.\n\nA reload finishes the setup.",
        button = "Reload now", action = function() ReloadUI() end,
    },
}

function I:Show(page)
    local f = self.frame
    if not f then
        f = CreateFrame("Frame", "WicksUI_Install", UIParent)
        f:SetSize(520, 260)
        f:SetPoint("CENTER", 0, 80)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        ns:SetTemplate(f, "Default", { brackets = true })
        f.brand = ns:CreateText(f, 18, "LEFT", "NONE")
        f.brand:SetPoint("TOPLEFT", 18, -16)
        f.brand:SetText(Chrome:TitleMarkup("Wick's UI"))
        f.step = ns:CreateText(f, 11, "RIGHT", "NONE")
        f.step:SetPoint("TOPRIGHT", -18, -20)
        f.step:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        f.title = ns:CreateText(f, 15, "LEFT", "NONE")
        f.title:SetPoint("TOPLEFT", 18, -46)
        f.title:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
        f.text = ns:CreateText(f, 12, "LEFT", "NONE")
        f.text:SetWordWrap(true)
        f.text:SetJustifyV("TOP")
        f.text:SetPoint("TOPLEFT", 18, -70)
        f.text:SetPoint("TOPRIGHT", -18, -70)
        f.action = W:Button(f, "", 160, function() end)
        f.action:SetPoint("BOTTOMLEFT", 18, 16)
        f.choice1 = W:Button(f, "", 150, function() end)
        f.choice1:SetPoint("BOTTOMLEFT", 18, 16)
        f.choice2 = W:Button(f, "", 150, function() end)
        f.choice2:SetPoint("LEFT", f.choice1, "RIGHT", 8, 0)
        f.next = W:Button(f, "Next", 90, function() I:Show(I.page + 1) end)
        f.next:SetPoint("BOTTOMRIGHT", -18, 16)
        f.back = W:Button(f, "Back", 90, function() I:Show(I.page - 1) end)
        f.back:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
        f.close = W:Button(f, "x", 22, function() I:Finish() end)
        f.close:SetPoint("TOPRIGHT", -4, -4)
        self.frame = f
    end
    page = math.max(1, math.min(#PAGES, page or 1))
    self.page = page
    local p = PAGES[page]
    f.step:SetText(("%d of %d"):format(page, #PAGES))
    f.title:SetText(p.title)
    f.text:SetText(p.text)
    f.action:SetShown(p.button ~= nil)
    if p.button then
        f.action.text:SetText(p.button)
        f.action:SetScript("OnClick", function() p.action(); if page < #PAGES then I:Show(page + 1) end end)
    end
    f.choice1:SetShown(p.choices ~= nil)
    f.choice2:SetShown(p.choices ~= nil)
    if p.choices then
        for i, btn in ipairs({ f.choice1, f.choice2 }) do
            local key, label = p.choices[i][1], p.choices[i][2]
            btn.text:SetText(label)
            btn:SetScript("OnClick", function() I:ApplyLayout(key); I:Show(page + 1) end)
        end
    end
    f.back:SetShown(page > 1)
    f.next.text:SetText(page == #PAGES and "Finish" or "Skip")
    f.next:SetScript("OnClick", function() if page == #PAGES then I:Finish() else I:Show(page + 1) end end)
    f:Show()
end

function I:Finish()
    ns:G().installed = true
    if self.frame then self.frame:Hide() end
end
