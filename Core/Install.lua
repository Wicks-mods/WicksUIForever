-- Wick's UI
-- Core/Install.lua: the first-run setup.
--
-- A few questions, one to a page: the style, the colours, the class
-- colours and the scale, then done. Each answer is applied the moment it
-- is picked (the style waits for the reload at the end, since panels are
-- built once), the current answer is lit, and every page can be skipped.
-- The frames start in Wick's own layout (Core/Layout.lua). It runs once
-- per profile; /wui install brings it back.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local I = {}
ns.Install = I

-- The style chosen here; applied by the reload on the last page.
local pendingStyle

local function currentStyle() return pendingStyle or (Chrome:Modern() and "modern" or "og") end

local PAGES = {
    {
        title = "Welcome",
        text = "Wick's UI replaces the game's action bars, unit frames, group frames, nameplates, buffs, chat, minimap and tooltips, and dresses the game's own windows to match. Every part can be switched off in the settings, and anything switched off is left exactly as the game made it.\n\nA few questions, and you are set. Each one can be skipped and changed later.",
    },
    {
        title = "Style",
        text = "The shape everything is drawn in, across every Wick addon.\n\nWick Modern: rounded glass panels on a soft shadow, the Wick font, no border lines.\nWick OG: the original look, flat panels with a single-pixel border and fel corners.\n\nThe change shows after the reload at the end.",
        choices = {
            { label = "Wick Modern", on = function() return currentStyle() == "modern" end,
              pick = function() pendingStyle = "modern" end },
            { label = "Wick OG", on = function() return currentStyle() == "og" end,
              pick = function() pendingStyle = "og" end },
        },
    },
    {
        title = "Colours",
        text = "The palette, also shared by every Wick addon.\n\nYour class: the accent in your class colour, a new one on each character.\nFel: Wick's own green on violet-black.\nCustom: your own main and accent colours, picked under General, Appearance.",
        choices = {
            { label = "My class", on = function() return Chrome:ThemeSetting() == "auto" end,
              pick = function() Chrome:SetTheme("auto") end },
            { label = "Fel", on = function() return Chrome:ThemeSetting() == "fel" end,
              pick = function() Chrome:SetTheme("fel") end },
            { label = "Custom", on = function() return Chrome:ThemeSetting() == "custom" end,
              pick = function() Chrome:SetTheme("custom") end },
        },
    },
    {
        title = "Class colours",
        text = "How players' classes are coloured on unit frames, nameplates, chat and the class palettes.\n\nThe game's own set, or the Classic era set the original game used (a warmer shaman blue, a deeper paladin pink).",
        choices = {
            { label = "The game's own", on = function() return Chrome.classColorSet ~= "classic" end,
              pick = function() Chrome:SetClassColorSet("client") end },
            { label = "Classic era", on = function() return Chrome.classColorSet == "classic" end,
              pick = function() Chrome:SetClassColorSet("classic") end },
        },
    },
    {
        title = "Scale",
        text = "Pixel perfect sets the game's interface scale so one interface pixel is one screen pixel, which keeps thin borders and rounded corners sharp. On a large monitor it makes everything smaller. The scale can be changed any time under General.",
        choices = {
            { label = "Pixel perfect",
              on = function() local s = ns:G().uiScale; return s and s > 0 and math.abs(s - ns:PixelPerfectScale()) < 0.001 end,
              pick = function()
                  ns:G().uiScale = ns:Round(ns:PixelPerfectScale(), 4)
                  ns:ApplyScale()
              end },
            { label = "Leave the game's", on = function() return (ns:G().uiScale or 0) == 0 end,
              pick = function() ns:G().uiScale = 0; ns:ApplyScale() end },
        },
    },
    {
        title = "Done",
        text = "Your frames start in Wick's own layout. Type |cff4FC778/wui move|r to place them, |cff4FC778/wui|r for the settings and |cff4FC778/wui kb|r to bind keys by pointing at a button.\n\nA reload finishes the setup.",
        button = "Reload now", action = function()
            if pendingStyle and Chrome.SetStyle then Chrome:SetStyle(pendingStyle) end
            I:Finish()
            ReloadUI()
        end,
    },
}

local CHOICE_W = 150

local function paintChoice(btn, on)
    if on then
        btn.text:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
        ns:SetBorderColor(btn, "fel")
    else
        btn.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        ns:SetBorderColor(btn, "border")
    end
end

function I:Show(page)
    local f = self.frame
    if not f then
        f = CreateFrame("Frame", "WicksUI_Install", UIParent)
        f:SetSize(520, 300)
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
        f.step:SetPoint("TOPRIGHT", -34, -20)
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
        f.action:SetPoint("BOTTOMLEFT", 18, 50)
        -- Up to three answers in a row above the Back and Next buttons.
        f.choices = {}
        for i = 1, 3 do
            local b = W:Button(f, "", CHOICE_W, function() end)
            b:SetPoint("BOTTOMLEFT", 18 + (i - 1) * (CHOICE_W + 8), 50)
            f.choices[i] = b
        end
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
    local list = p.choices or {}
    local function paintAll()
        for i, c in ipairs(list) do paintChoice(f.choices[i], c.on and c.on()) end
    end
    for i, btn in ipairs(f.choices) do
        local c = list[i]
        btn:SetShown(c ~= nil)
        if c then
            btn.text:SetText(c.label)
            -- Picked, lit, and on to the next question.
            btn:SetScript("OnClick", function()
                pcall(c.pick)
                paintAll()
                C_Timer.After(0.15, function() if I.page == page then I:Show(page + 1) end end)
            end)
        end
    end
    paintAll()
    f.back:SetShown(page > 1)
    f.next.text:SetText(page == #PAGES and "Finish" or (p.choices and "Skip" or "Next"))
    f.next:SetScript("OnClick", function()
        if page == #PAGES then
            if pendingStyle and pendingStyle ~= (Chrome:Modern() and "modern" or "og") and Chrome.SetStyle then
                Chrome:SetStyle(pendingStyle)
                I:Finish()
                ReloadUI()
                return
            end
            I:Finish()
        else
            I:Show(page + 1)
        end
    end)
    f:Show()
end

function I:Finish()
    ns:G().installed = true
    if self.frame then self.frame:Hide() end
end
