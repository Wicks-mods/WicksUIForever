-- Wick's UI
-- Core/Install.lua: the first-run setup.
--
-- One question to a page: the look, the class colours and the scale, then
-- only the questions this character's addons raise. With Wick's Bags on:
-- which bags B opens. With another addon on that does a job Wick's UI
-- also does (other nameplates, other action bars, another whole UI): which
-- of the two keeps it. Every page can be skipped; a skipped addon question
-- keeps the other addon, and Wick's UI leaves that job to it.
--
-- The setup is drawn in Wick OG with the Fel colours, whatever look the
-- character is in; the look chosen here shows after the reload at the end.
-- Colours come with each look, so there is no colour question: the Done
-- page points to WickCore's options for the palette.
--
-- It runs once per profile; /wui install brings it back. An addon that
-- would clash, switched on later, brings back just its own question at
-- the next login, and Wick's UI stands its part down until it is answered.

local ADDON, ns = ...

local Chrome = ns.Core.Chrome
local C = Chrome.Colors
local W = ns.Widgets

local I = {}
ns.Install = I

-- ============================================================
-- Other addons
-- ============================================================
-- Each job two addons could both do, with the folder names of the addons
-- that do it and a friendly name for each. get/set read and write Wick's
-- UI's own part in a profile.
local CONFLICTS = {
    { key = "ui", whole = true, title = "Another interface", what = "the whole interface",
      addons = { { "ElvUI", "ElvUI" }, { "Tukui", "Tukui" }, { "NDui", "NDui" }, { "GW2_UI", "GW2 UI" },
                 { "KkthnxUI", "KkthnxUI" }, { "RealUI", "RealUI" } } },
    { key = "comforts", comforts = true, title = "Wick's Comforts", what = "tooltips, looting, the vendor, quests and the camera",
      addons = { { "WicksComforts", "Wick's Comforts" } } },
    { key = "unitframes", title = "Unit frames", what = "the unit frames", page = "Unit Frames",
      addons = { { "ShadowedUnitFrames", "Shadowed Unit Frames" }, { "PitBull4", "PitBull" }, { "ZPerl", "Z-Perl" },
                 { "XPerl", "X-Perl" }, { "UnhaltedUnitFrames", "Unhalted Unit Frames" } },
      get = function(p) return p.unitframes.enable ~= false end,
      set = function(p, on) p.unitframes.enable = on end },
    { key = "groups", title = "Party and raid frames", what = "the party and raid frames", page = "Unit Frames",
      addons = { { "Grid2", "Grid2" }, { "VuhDo", "VuhDo" }, { "Cell", "Cell" }, { "HealBot", "HealBot" } },
      get = function(p)
          local u = p.unitframes.units
          return p.unitframes.enable ~= false and (u.party.enable ~= false or u.raid.enable ~= false)
      end,
      set = function(p, on) local u = p.unitframes.units; u.party.enable = on; u.raid.enable = on end },
    { key = "nameplates", title = "Nameplates", what = "the nameplates", page = "Nameplates",
      addons = { { "Platynator", "Platynator" }, { "Plater", "Plater" }, { "Kui_Nameplates", "KuiNameplates" },
                 { "TidyPlates_ThreatPlates", "Threat Plates" }, { "TidyPlates", "TidyPlates" }, { "NeatPlates", "NeatPlates" } },
      get = function(p) return p.nameplates.enable ~= false end,
      set = function(p, on) p.nameplates.enable = on end },
    { key = "actionbars", title = "Action bars", what = "the action bars", page = "Action Bars",
      addons = { { "Bartender4", "Bartender" }, { "Dominos", "Dominos" } },
      get = function(p) return p.actionbars.enable ~= false end,
      set = function(p, on) p.actionbars.enable = on end },
    { key = "chat", title = "Chat", what = "the chat", page = "Chat",
      addons = { { "Prat-3.0", "Prat" }, { "Chattynator", "Chattynator" }, { "Glass", "Glass" }, { "Chatter", "Chatter" } },
      get = function(p) return p.chat.enable ~= false end,
      set = function(p, on) p.chat.enable = on end },
    { key = "minimap", title = "Minimap", what = "the minimap", page = "Minimap",
      addons = { { "SexyMap", "SexyMap" }, { "BasicMinimap", "BasicMinimap" } },
      get = function(p) return p.minimap.enable ~= false end,
      set = function(p, on) p.minimap.enable = on end },
    { key = "tooltip", title = "Tooltips", what = "the tooltips", page = "Tooltips",
      addons = { { "TipTac", "TipTac" }, { "TinyTooltip", "TinyTooltip" } },
      get = function(p) return p.tooltip.enable ~= false end,
      set = function(p, on) p.tooltip.enable = on end },
    { key = "datatexts", title = "Info panels", what = "the info panels along the screen edge", page = "Info panels",
      addons = { { "Titan", "Titan Panel" }, { "ChocolateBar", "ChocolateBar" } },
      get = function(p) return p.datatexts.enable ~= false end,
      set = function(p, on) p.datatexts.enable = on end },
    { key = "threat", title = "Threat meter", what = "the threat meter", page = "Threat",
      addons = { { "ThreatClassic2", "ThreatClassic2" }, { "Omen", "Omen" } },
      get = function(p) return p.threat.enable ~= false and p.threat.meter ~= false end,
      set = function(p, on) p.threat.meter = on; if on then p.threat.enable = true end end },
    { key = "combattext", title = "Combat text", what = "the combat text", page = "Combat text",
      ours = "Wick's UI sets the game's own combat text in the look's font, with its settings under Combat text.",
      addons = { { "MikScrollingBattleText", "MSBT" }, { "xCT+", "xCT+" }, { "Parrot", "Parrot" },
                 { "NameplateSCT", "NameplateSCT" }, { "sct", "SCT" } },
      get = function(p) return p.general.combatTextFont ~= false end,
      set = function(p, on) p.general.combatTextFont = on end },
}
I.CONFLICTS = CONFLICTS

-- Bag addons besides Wick's Bags, for the bags question.
local OTHER_BAGS = { { "Baganator", "Baganator" }, { "Bagnon", "Bagnon" }, { "AdiBags", "AdiBags" },
    { "ArkInventory", "ArkInventory" }, { "BetterBags", "BetterBags" } }

-- Every addon switched on for this session, by lowercase folder name.
-- Asked at the time, never cached: an addon may be loaded late.
local function loadedAddons()
    local set = {}
    local num = (C_AddOns and C_AddOns.GetNumAddOns) or rawget(_G, "GetNumAddOns")
    local info = (C_AddOns and C_AddOns.GetAddOnInfo) or rawget(_G, "GetAddOnInfo")
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
    if not isLoaded then return set end
    local ok, n = pcall(function() return num and num() end)
    if ok and type(n) == "number" and n > 0 and info then
        for i = 1, n do
            local okI, name = pcall(info, i)
            if okI and type(name) == "string" then
                local okL, on = pcall(isLoaded, i)
                if okL and on then set[name:lower()] = name end
            end
        end
    end
    return set, isLoaded
end

-- The listed addons that are on, as { folder, friendly } pairs.
local function present(list, set, isLoaded)
    local out = {}
    for _, a in ipairs(list) do
        local on = set[a[1]:lower()]
        if not on and isLoaded then
            local ok, v = pcall(isLoaded, a[1])
            on = ok and v
        end
        if on then out[#out + 1] = a end
    end
    return out
end
I.present = present

local function names(list)
    local t = {}
    for i, a in ipairs(list) do t[i] = a[2] end
    if #t <= 1 then return t[1] or "" end
    return table.concat(t, ", ", 1, #t - 1) .. " and " .. t[#t]
end

local function profile() return ns.A and ns.A.db and ns.A.db.profile end
local function answers()
    local g = ns:G()
    g.conflicts = type(g.conflicts) == "table" and g.conflicts or {}
    return g.conflicts
end

-- Is this question still open? A job is only in question while Wick's
-- UI's own part is on; one left to the other addon stays left, unless that
-- addon is new. Keeping Wick's UI and then switching the other back on
-- asks again: switching it on was a choice.
local function unanswered(c, found)
    local a = answers()
    if c.whole then return true end
    if c.comforts then return a.comforts ~= "theirs" end
    local p = profile()
    if not (p and c.get(p)) then return false end
    for _, addon in ipairs(found) do
        if a[c.key .. ":" .. addon[1]] ~= "theirs" then return true end
    end
    return false
end

-- ============================================================
-- State for one run of the setup
-- ============================================================
local pendingStyle      -- the look chosen here, saved at the end
local run = {}          -- this run: the questions and what was picked

local function resetRun(questions)
    run = { questions = questions or {}, picked = {}, disable = {}, leaving = false, copyComforts = false }
end
resetRun()

-- Called at login, before any module starts: find what clashes, and while
-- a question is open leave the job to the other addon, so the two never
-- run at once. Answers come at the end of the setup.
function I:Detect()
    local set, isLoaded = loadedAddons()
    local open = {}
    local p = profile()
    for _, c in ipairs(CONFLICTS) do
        local found = present(c.addons, set, isLoaded)
        if #found > 0 and unanswered(c, found) then
            open[#open + 1] = { def = c, found = found }
            if c.set and p then c.set(p, false) end
        end
    end
    self.open = open
    self.bagsOpen = self:BagsQuestion(set, isLoaded)
    return open
end

-- Every clash this character has, open or answered: for /wui install.
function I:AllConflicts()
    local set, isLoaded = loadedAddons()
    local out = {}
    for _, c in ipairs(CONFLICTS) do
        local found = present(c.addons, set, isLoaded)
        if #found > 0 then out[#out + 1] = { def = c, found = found } end
    end
    return out
end

-- Anything to ask at this login on a profile already set up.
function I:HasQuestions()
    return (self.open and #self.open > 0) or (self.bagsOpen and self.bagsOpen.open) or false
end

-- The setup is showing.
function I:Busy() return self.frame and self.frame:IsShown() or false end

-- ============================================================
-- Bags
-- ============================================================
local BAG_KEY, GAME_BAG_KEY = "B", "SHIFT-B"
local function charDB() return ns.A and ns.A.db and ns.A.db.char or {} end

local function bindingAction(key)
    if not GetBindingAction then return "" end
    local ok, a = pcall(GetBindingAction, key)
    return ok and a or ""
end

-- The bags question: Wick's Bags must be on, and this character must not
-- have answered. One already on B has answered it without being asked.
function I:BagsQuestion(set, isLoaded)
    if not set then set, isLoaded = loadedAddons() end
    local wb = present({ { "WicksBags", "Wick's Bags" } }, set, isLoaded)
    if #wb == 0 then return nil end
    local others = present(OTHER_BAGS, set, isLoaded)
    local ch = charDB()
    if ch.bagKeys == nil and bindingAction(BAG_KEY) == "WICKSBAGS_TOGGLE" and #others == 0 then
        ch.bagKeys, ch.bagKeysSet = "wicks", true
    end
    return { others = others, open = ch.bagKeys == nil or (#others > 0 and not ch.bagsKeepBoth) }
end

-- B opens Wick's Bags and Shift+B the game's; or the keys as they were.
-- Out of combat only (the game refuses key changes in a fight), so a pick
-- made in one waits, and one lost to a reload is made at the next login.
function I:ApplyBagKeys()
    local ch = charDB()
    if not (SetBinding and GetBindingAction) then return end
    if InCombatLockdown() then
        ns:AfterCombat("bagkeys", function() I:ApplyBagKeys() end)
        return
    end
    if ch.bagKeys == "wicks" then
        if not ch.bagKeysWas then
            ch.bagKeysWas = { b = bindingAction(BAG_KEY), shiftB = bindingAction(GAME_BAG_KEY) }
        end
        pcall(SetBinding, BAG_KEY, "WICKSBAGS_TOGGLE")
        pcall(SetBinding, GAME_BAG_KEY, "OPENALLBAGS")
    elseif ch.bagKeysWas then
        -- Back as they were, unless they were changed since.
        local was = ch.bagKeysWas
        if bindingAction(BAG_KEY) == "WICKSBAGS_TOGGLE" then
            pcall(SetBinding, BAG_KEY, was.b ~= "" and was.b or nil)
        end
        if bindingAction(GAME_BAG_KEY) == "OPENALLBAGS" then
            pcall(SetBinding, GAME_BAG_KEY, was.shiftB ~= "" and was.shiftB or nil)
        end
        ch.bagKeysWas = nil
    end
    if SaveBindings then pcall(SaveBindings, (GetCurrentBindingSet and GetCurrentBindingSet()) or 1) end
    ch.bagKeysSet = true
end

local function setBagKeys(v)
    local ch = charDB()
    ch.bagKeys, ch.bagKeysSet, ch.bagsKeepBoth = v, false, nil
    I:ApplyBagKeys()
end

-- What Shift+B does now, if it is something else: the bags question says
-- it moves.
local function shiftBNote()
    local a = bindingAction(GAME_BAG_KEY)
    if a == "" or a == "OPENALLBAGS" or a == "TOGGLEBACKPACK" or a == "WICKSBAGS_TOGGLE" then return "" end
    local label = rawget(_G, "BINDING_NAME_" .. a) or a
    return ("\n\nShift+B is %s now; it moves to the game's bags."):format(label)
end

local function bagsPage(q)
    local others = q.others
    if #others > 0 then
        local other = others[1]
        return {
            title = "Bags",
            text = ("Wick's Bags and %s are both on, and both want your bags. Keep one.\n\nWick's Bags: B opens Wick's Bags and Shift+B the game's bags. %s is switched off at the reload.\n%s: Wick's Bags is switched off at the reload."):format(
                names(others), names(others), other[2]) .. shiftBNote(),
            choices = function()
                local out = {
                    { label = "Wick's Bags", on = function() return run.picked.bags == "wicks" end,
                      pick = function()
                          run.picked.bags = "wicks"
                          for _, a in ipairs(others) do run.disable[a[1]] = true end
                          run.disable.WicksBags = nil
                          setBagKeys("wicks")
                      end },
                }
                out[2] = { label = other[2], on = function() return run.picked.bags == "other" end,
                    pick = function()
                        run.picked.bags = "other"
                        for _, a in ipairs(others) do run.disable[a[1]] = nil end
                        run.disable.WicksBags = true
                        setBagKeys("game")
                    end }
                return out
            end,
        }
    end
    return {
        title = "Bags",
        text = "Wick's Bags is on. Which bags should B open?\n\nWick's Bags: B opens Wick's Bags, and Shift+B opens the game's bags.\nThe game's bags: B stays as it is. Wick's Bags keeps its own key under Key Bindings, AddOns." .. shiftBNote(),
        choices = {
            { label = "Wick's Bags", on = function() return charDB().bagKeys == "wicks" end,
              pick = function() run.picked.bags = "wicks"; setBagKeys("wicks") end },
            { label = "The game's bags", on = function() return charDB().bagKeys == "game" end,
              pick = function() run.picked.bags = "game"; setBagKeys("game") end },
        },
    }
end

-- ============================================================
-- Conflict pages
-- ============================================================
local function wholePage(q)
    local found, other = q.found, q.found[1]
    return {
        title = q.def.title,
        text = ("%s is on, and it replaces the whole interface, as Wick's UI does. Two at once fight over every frame, so keep one.\n\nWick's UI: %s is switched off at the reload.\n%s: Wick's UI switches itself off at the reload, and the rest of the setup is skipped."):format(
            names(found), names(found), other[2]),
        choices = function()
            return {
                { label = "Wick's UI", on = function() return run.picked.ui == "ours" end,
                  pick = function()
                      run.picked.ui, run.leaving = "ours", false
                      for _, a in ipairs(found) do run.disable[a[1]] = true end
                  end },
                { label = other[2], on = function() return run.picked.ui == "theirs" end,
                  pick = function()
                      run.picked.ui, run.leaving = "theirs", true
                      for _, a in ipairs(found) do run.disable[a[1]] = nil end
                  end },
            }
        end,
        -- Skipped, nothing changes and it is asked again next time.
    }
end

local function comfortsPage(q)
    return {
        title = "Wick's Comforts",
        text = "Wick's Comforts is on. Wick's UI has everything it does built in: the tooltips, looting, the vendor, quests, the camera and the client fixes. While both are on, Wick's UI leaves all of that to Comforts.\n\nWick's UI: your Comforts settings come across, and Wick's Comforts is switched off at the reload.\nKeep Comforts: both stay on, and Comforts keeps doing it.",
        choices = {
            { label = "Wick's UI", on = function() return run.picked.comforts == "ours" end,
              pick = function() run.picked.comforts = "ours"; run.copyComforts = true; run.disable.WicksComforts = true end },
            { label = "Keep Comforts", on = function() return run.picked.comforts == "theirs" or (not run.picked.comforts and answers().comforts == "theirs") end,
              pick = function() run.picked.comforts = "theirs"; run.copyComforts = false; run.disable.WicksComforts = nil end },
        },
    }
end

local function featurePage(q)
    local c, found = q.def, q.found
    local list = names(found)
    local text = ("%s %s on, and %s %s too. Two at once get in each other's way, so keep one.\n\nWick's UI: %s %s switched off at the reload.\n%s: Wick's UI leaves %s to %s. Its own can be switched on again under %s in the settings."):format(
        list, #found > 1 and "are" or "is", #found > 1 and "they do" or "it does", c.what,
        list, #found > 1 and "are" or "is",
        found[1][2], c.what, #found > 1 and "them" or "it", c.page or c.title)
    if c.ours then text = text .. "\n\n" .. c.ours end
    return {
        title = c.title,
        text = text,
        choices = function()
            local p = profile()
            local function now() return run.picked[c.key] or ((p and c.get(p)) and "ours" or found[1][1]) end
            local out = {
                { label = "Wick's UI", on = function() return now() == "ours" end,
                  pick = function()
                      run.picked[c.key] = "ours"
                      if p then c.set(p, true) end
                      for _, a in ipairs(found) do run.disable[a[1]] = true end
                  end },
            }
            -- One button for each of theirs, up to the row's room.
            for i = 1, math.min(#found, 8) do
                local a = found[i]
                out[#out + 1] = { label = a[2],
                    on = function() return now() == a[1] end,
                    pick = function()
                        run.picked[c.key] = a[1]
                        if p then c.set(p, false) end
                        for _, b in ipairs(found) do run.disable[b[1]] = nil end
                    end }
            end
            return out
        end,
    }
end

local function conflictPage(q)
    if q.def.whole then return wholePage(q) end
    if q.def.comforts then return comfortsPage(q) end
    return featurePage(q)
end

-- ============================================================
-- The pages
-- ============================================================
-- The look as saved, not as the setup draws itself.
local function savedStyle()
    local was = Chrome.forceStyle
    Chrome.forceStyle = nil
    local id = Chrome:StyleID()
    Chrome.forceStyle = was
    return id
end

local function currentStyle() return pendingStyle or savedStyle() end

local WELCOME = {
    title = "Welcome",
    text = "Wick's UI replaces the game's action bars, unit frames, group frames, nameplates, buffs, chat, minimap and tooltips, and dresses the game's own windows to match. Every part can be switched off in the settings, and anything switched off is left exactly as the game made it.\n\nA few questions, and you are set. Each one can be skipped and changed later.",
}

local STYLE = {
    title = "Look",
    text = "The look everything is drawn in, across every Wick addon. Each look comes with its own colours. Point at one to read about it; it shows after the reload at the end.",
    choices = function()
        local out = {}
        for _, st in ipairs(Chrome.Styles) do
            out[#out + 1] = { label = st.name, tip = st.blurb,
                on = function() return currentStyle() == st.id end,
                pick = function() pendingStyle = st.id end }
        end
        return out
    end,
}

local CLASS_COLOURS = {
    title = "Class colours",
    text = "How players' classes are coloured on unit frames, nameplates, chat and the class palettes.\n\nThe game's own set, or the Classic era set the original game used (a warmer shaman blue, a deeper paladin pink).",
    choices = {
        { label = "The game's own", on = function() return Chrome.classColorSet ~= "classic" end,
          pick = function() Chrome:SetClassColorSet("client") end },
        { label = "Classic era", on = function() return Chrome.classColorSet == "classic" end,
          pick = function() Chrome:SetClassColorSet("classic") end },
    },
}

local SCALE = {
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
}

local function donePage(full)
    local text
    if run.leaving then
        text = "Wick's UI switches itself off at the reload. It can be switched on again from the AddOns list on the character screen."
    elseif full then
        text = "Your frames start in Wick's own layout. Type |cff4FC778/wui move|r to place them, |cff4FC778/wui|r for the settings and |cff4FC778/wui kb|r to bind keys by pointing at a button.\n\nColours come with the look. To change them, or see the palette, open WickCore's options: |cff4FC778/wickcore options|r.\n\nA reload finishes the setup."
    else
        text = "Answered. A reload puts it into effect.\n\n|cff4FC778/wui install|r asks every question again."
    end
    return { title = "Done", text = text, done = true }
end

-- The pages for this run. A full run on a new profile, or just the open
-- questions at a later login.
local function buildPages(full)
    local pages = {}
    local function add(p) pages[#pages + 1] = p end
    if full then add(WELCOME) end
    -- A whole other UI comes first: kept, nothing else here matters.
    for _, q in ipairs(run.questions) do
        if q.def.whole then add(conflictPage(q)) end
    end
    if not run.leaving then
        if full then
            add(STYLE)
            add(CLASS_COLOURS)
            add(SCALE)
        end
        if run.bags then add(bagsPage(run.bags)) end
        for _, q in ipairs(run.questions) do
            if not q.def.whole then add(conflictPage(q)) end
        end
    end
    add(donePage(full))
    return pages
end

-- ============================================================
-- Drawing
-- ============================================================
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

-- Draw in Wick OG, whatever the character's look.
local function inSetupLook(fn, ...)
    local was = Chrome.forceStyle
    Chrome.forceStyle = "og"
    local ok, err = pcall(fn, ...)
    Chrome.forceStyle = was
    if not ok then error(err, 0) end
end

local function build()
    local f = CreateFrame("Frame", "WicksUI_Install", UIParent)
    f:SetSize(520, 360)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    ns:SetTemplate(f, "Default", { brackets = true })
    f.brand = ns:CreateText(f, 18, "LEFT", "NONE")
    f.brand:SetPoint("TOPLEFT", 18, -16)
    f.step = ns:CreateText(f, 11, "RIGHT", "NONE")
    f.step:SetPoint("TOPRIGHT", -34, -20)
    f.title = ns:CreateText(f, 15, "LEFT", "NONE")
    f.title:SetPoint("TOPLEFT", 18, -46)
    f.text = ns:CreateText(f, 12, "LEFT", "NONE")
    f.text:SetWordWrap(true)
    f.text:SetJustifyV("TOP")
    f.text:SetPoint("TOPLEFT", 18, -70)
    f.text:SetPoint("TOPRIGHT", -18, -70)
    f.reloadAction = W:Button(f, "Reload now", 160, function() I:Finish(true) end)
    f.reloadAction:SetPoint("BOTTOMLEFT", 18, 16)
    -- Up to nine answers, three to a row, above the Back and Next buttons.
    f.choices = {}
    for i = 1, 9 do
        local b = W:Button(f, "", CHOICE_W, function() end)
        b:HookScript("OnEnter", function()
            if not b.tip then return end
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(b.text:GetText() or "", 1, 1, 1)
            GameTooltip:AddLine(b.tip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        f.choices[i] = b
    end
    f.next = W:Button(f, "Next", 90, function() end)
    f.next:SetPoint("BOTTOMRIGHT", -18, 16)
    f.back = W:Button(f, "Back", 90, function() I:Show(I.page - 1) end)
    f.back:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    f.close = W:Button(f, "x", 22, function() I:Finish(false) end)
    f.close:SetPoint("TOPRIGHT", -4, -4)
    return f
end

local function fill(f, page)
    local pages = I.pages
    local p = pages[page]
    f.brand:SetText(Chrome:TitleMarkup("Wick's UI"))
    f.step:SetText(("%d of %d"):format(page, #pages))
    f.step:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    f.title:SetText(p.title)
    f.title:SetTextColor(C.fel[1], C.fel[2], C.fel[3])
    f.text:SetText(type(p.text) == "string" and (p.text:gsub("|cff4FC778", Chrome:Esc("fel"))) or p.text)
    f.reloadAction:SetShown(p.done and true or false)
    local list = (type(p.choices) == "function" and p.choices()) or p.choices or {}
    -- One row sits on the lower line; more fill upwards.
    local rows = math.ceil(#list / 3)
    for i, btn in ipairs(f.choices) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", 18 + col * (CHOICE_W + 8), 50 + (rows - 1 - row) * 34)
    end
    local function paintAll()
        inSetupLook(function()
            for i, c in ipairs(list) do paintChoice(f.choices[i], c.on and c.on()) end
        end)
    end
    for i, btn in ipairs(f.choices) do
        local c = list[i]
        btn:SetShown(c ~= nil)
        if c then
            btn.text:SetText(c.label)
            btn.tip = c.tip
            -- Picked, lit, and on to the next question.
            btn:SetScript("OnClick", function()
                local ok, err = pcall(c.pick)
                if not ok then ns.A:Print("|cffff6060setup|r: " .. tostring(err)) end
                -- A pick can change the pages (another whole UI kept).
                I.pages = buildPages(I.full)
                paintAll()
                C_Timer.After(0.15, function()
                    if I.page == page and I:Busy() then I:Show(math.min(page + 1, #I.pages)) end
                end)
            end)
        end
    end
    paintAll()
    f.back:SetShown(page > 1)
    if p.done then
        f.next.text:SetText("Later")
        f.next:SetScript("OnClick", function() I:Finish(false) end)
    else
        f.next.text:SetText(p.choices and "Skip" or "Next")
        f.next:SetScript("OnClick", function() I:Show(page + 1) end)
    end
end

-- Open the setup. full: every question (a new profile, or /wui install);
-- otherwise just the ones this login raised.
function I:Start(full)
    if full == nil then full = not ns:G().installed end
    if full then
        pendingStyle = nil
        resetRun(self:AllConflicts())
        run.bags = self:BagsQuestion()
    else
        resetRun(self.open or {})
        local b = self.bagsOpen
        run.bags = (b and b.open) and b or nil
    end
    self.full = full
    self.pages = buildPages(full)
    self:Show(1)
end

function I:Show(page)
    if not self.pages then return self:Start(true) end
    page = math.max(1, math.min(#self.pages, page or 1))
    self.page = page
    -- The setup's own colours while it shows; the look's come back at the end.
    if Chrome.activeTheme ~= "fel" then
        self.themeWas = self.themeWas or Chrome.activeTheme
        Chrome:ApplyTheme("fel")
    end
    inSetupLook(function()
        self.frame = self.frame or build()
        fill(self.frame, page)
    end)
    self.frame:Show()
end

local function disableAddOn(name)
    local fn = (C_AddOns and C_AddOns.DisableAddOn) or rawget(_G, "DisableAddOn")
    if not fn then return false end
    return pcall(fn, name)
end

-- End the setup. reload: the Reload now button; otherwise Later or the
-- close button, and what needs a reload waits for one.
function I:Finish(reload)
    local g = ns:G()
    local a = answers()
    local p = profile()
    -- Every addon question: the pick, and a skipped one keeps theirs.
    for _, q in ipairs(run.questions) do
        local c = q.def
        local pick = run.picked[c.key]
        if c.comforts then
            if pick then a.comforts = pick elseif a.comforts ~= "ours" then a.comforts = "theirs" end
        elseif not c.whole then
            local ours = p and c.get(p)
            for _, addon in ipairs(q.found) do a[c.key .. ":" .. addon[1]] = ours and "ours" or "theirs" end
        end
    end
    -- The bags question skipped: the keys stay as they are, both bag
    -- addons too, and it is not asked again.
    if run.bags and not run.picked.bags then
        local ch = charDB()
        ch.bagKeys = ch.bagKeys or "game"
        if #run.bags.others > 0 then ch.bagsKeepBoth = true end
    end
    if run.copyComforts and ns.ComfortsModule and ns.ComfortsModule.CopyFromComforts then
        pcall(ns.ComfortsModule.CopyFromComforts, ns.ComfortsModule)
    end
    local switched = false
    for name in pairs(run.disable) do
        if disableAddOn(name) then switched = true end
    end
    if run.leaving and disableAddOn(ADDON) then switched = true end
    -- A new look is saved with its colours; the same one again changes
    -- nothing, so colours picked since in WickCore stay.
    local newStyle = pendingStyle and pendingStyle ~= savedStyle()
    if newStyle and Chrome.SetStyle then Chrome:SetStyle(pendingStyle) end
    pendingStyle = nil
    g.installed = true
    self.open, self.bagsOpen = nil, nil
    if self.frame then self.frame:Hide() end
    -- The palette in use again: the character's, or the new look's.
    if self.themeWas then
        Chrome:ApplyTheme(Chrome:ResolveTheme(Chrome:ThemeSetting()))
    end
    self.themeWas = nil
    if reload then
        -- The game refuses an addon's reload once an addon is switched
        -- off; the prompt's reload counts as the player's own.
        if switched and Chrome.ReloadPrompt then
            Chrome:ReloadPrompt("Setup done. Reload to finish.")
        elseif Chrome.Reload then
            Chrome:Reload()
        else
            ReloadUI()
        end
    elseif newStyle or switched or #run.questions > 0 then
        ns.A:Print("setup saved. The rest shows after a reload: type /reload.")
    end
end

-- For the harness.
I._run = function() return run end
