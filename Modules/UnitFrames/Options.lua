-- Wick's UI
-- Modules/UnitFrames/Options.lua: the unit frame settings pages.

local ADDON, ns = ...

local UF = ns.UnitFrames
local W = ns.Widgets

local function update() UF:Update() end

local POINTS = {
    { "LEFT", "Left" }, { "CENTER", "Centre" }, { "RIGHT", "Right" },
    { "TOPLEFT", "Top left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top right" },
    { "BOTTOMLEFT", "Bottom left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom right" },
}
local SIDES = { { "TOP", "Above" }, { "BOTTOM", "Below" }, { "LEFT", "Left" }, { "RIGHT", "Right" } }

ns.Config:AddPage("unitframes", "Unit Frames", function(L)
    L:DB(function() return UF:db() end)
    L:Heading("Colours")
    L:Dropdown("Health bars", "healthColor", {
        { "class", "Class and reaction" }, { "dark", "Dark" }, { "gradient", "Red to green by health" },
    }, { tooltip = "The gradient is worked out by the client from your health, which this client keeps from addons, so it still follows health in combat." })
    L:Color("Dark colour", "darkColor", { disabled = function() return UF:db().healthColor ~= "dark" end })
    L:Toggle("Class colour behind the bar", "classBackdrop", { tooltip = "The empty part of the health bar in a dim class colour, so a dark bar still says who it is." })
    L:Slider("Behind the bar, strength", "bgAlpha", 0, 1, 0.05, { disabled = function() return not UF:db().classBackdrop end })
    L:Slider("Colour strength", "colorStrength", 0.4, 1, 0.05, {
        tooltip = "How bright the class and reaction colours are on the bars. 1 is the game's colour as it is; lower keeps the hue and takes the glare off pale ones like hunter and priest.",
    })
    L:Color("Cast bar", "castColor")
    L:Color("Cast bar, cannot interrupt", "castLocked")

    L:Heading("Behaviour")
    L:Toggle("Smooth bars", "smooth", { tooltip = "Bars slide to a new value instead of jumping. Takes effect after a reload." })
    L:Dropdown("Font", "font", function()
        local out = {}
        for _, name in ipairs(ns.Media:List("font")) do out[#out + 1] = { name, name, name } end
        return out
    end, { tooltip = "For the text on every unit frame. The rest of the interface keeps the font under General." })
    L:Dropdown("Outline", "fontOutline", ns.Widgets.Values(ns.Media.outlines))
    L:Toggle("Fel border on your target", "targetBorder", { tooltip = "Whichever party or raid frame belongs to what you are targeting gets a fel border." })
    L:Slider("Out of range alpha", "rangeAlpha", 0.1, 1, 0.05)
    L:Button("Preview group frames", function()
        if ns.UnitGroups then ns.UnitGroups:SetTestMode(not ns.UnitGroups.testing) end
    end, { tooltip = "Shows the party and raid frames with you in them, so they can be moved and sized without a group. Click again to stop." })
end, { onChange = update, order = 20 })

local function textSection(L, key, slot, title)
    local function td() return UF:UnitDB(key).texts[slot] end
    L:Heading(title)
    L:DB(td)
    L:Toggle("Show", "enable")
    L:Dropdown("Shows", "tag", ns.TagList, { tooltip = "Pick one, or type your own tag string in the box beside." })
    L:Input("Tag string", "tag", { tooltip = "Any oUF tags, for example  [wui:level] [name]  or  [wui:perhp]. The wui: tags are safe with this client's secret health." })
    L:Dropdown("Position", "point", POINTS)
    L:Slider("Across", "x", -100, 100, 1)
    L:Slider("Up and down", "y", -50, 50, 1)
    L:Slider("Size", "size", 6, 24, 1)
end

local function auraSection(L, key, which, title)
    L:Heading(title)
    L:DB(function() return UF:UnitDB(key)[which] end)
    L:Toggle("Show", "enable")
    L:Toggle("Only mine", "onlyMine")
    L:Dropdown("Side", "attach", SIDES)
    L:Dropdown("Start from", "anchor", { { "TOPLEFT", "Left" }, { "TOPRIGHT", "Right" } })
    L:Slider("Across", "x", -100, 100, 1)
    L:Slider("Up and down", "y", -100, 100, 1)
    L:Slider("Icon size", "size", 10, 48, 1)
    L:Slider("Per row", "perRow", 1, 16, 1)
    L:Slider("Rows", "rows", 1, 4, 1)
    L:Dropdown("Grow", "growthY", { { "UP", "Up" }, { "DOWN", "Down" } })
    L:Note("Icon size, count and the only-mine filter are handed to the client's aura container when the frame is made, so those three take effect after a reload.")
end

local function unitPage(key, order)
    ns.Config:AddPage("unitframes." .. key, UF.LABELS[key], function(L)
        local function d() return UF:UnitDB(key) end
        L:DB(d)
        L:Heading("Frame")
        L:Toggle("Enable", "enable")
        L:Toggle("Fade out of range", "rangeFade")
        L:Slider("Width", "width", 40, 500, 1)
        L:Slider("Height", "height", 10, 120, 1)
        L:Toggle("Power bar", "power")
        L:Slider("Power bar height", "powerHeight", 1, 30, 1, { disabled = function() return not d().power end })
        L:Dropdown("Portrait", "portrait", { { "none", "None" }, { "left", "Left" }, { "right", "Right" } })
        L:Slider("Portrait width", "portraitWidth", 10, 120, 1, { disabled = function() return d().portrait == "none" end })
        if key == "boss" then L:Slider("Space between", "spacing", 0, 80, 1) end

        if key == "party" or key == "raid" then
            L:Heading("Group")
            L:Dropdown("Grow", "growth", { { "DOWN", "Down" }, { "UP", "Up" }, { "RIGHT", "Right" }, { "LEFT", "Left" } })
            L:Slider("Spacing", "spacing", 0, 30, 1)
            L:Dropdown("Sort by", "sortBy", { { "ROLE", "Role, tanks first" }, { "GROUP", "Group" }, { "NAME", "Name" }, { "INDEX", "Join order" } })
            if key == "party" then
                L:Toggle("Include yourself", "showPlayer")
            else
                L:Slider("Per column", "perColumn", 1, 40, 1)
                L:Slider("Column spacing", "columnSpacing", 0, 30, 1)
                L:Dropdown("Columns go", "columnGrowth", { { "RIGHT", "Right" }, { "LEFT", "Left" }, { "DOWN", "Down" }, { "UP", "Up" } })
                L:Input("Groups shown", "groups", { tooltip = "Which raid groups to show, for example  1,2,3,4,5  for a 25." })
            end
            L:Heading("For healers")
            L:Toggle("A debuff you can dispel, in the middle", "centerDebuff", { tooltip = "Drawn by the client, so it works in combat. Takes effect after a reload." })
            L:Slider("Its size", "centerSize", 10, 40, 1)
            L:Toggle("Your own heals over time, top right", "myHots", { tooltip = "Up to three of your buffs on them. Takes effect after a reload." })
            L:Slider("Their size", "hotSize", 6, 20, 1)
            L:TextArea("Visibility", "visibility", {
                tooltip = "When the frames show, as a macro condition.",
                default = function() return ns.defaults.profile.unitframes.units[key].visibility end,
            })
        end

        textSection(L, key, "left", "Left text")
        textSection(L, key, "right", "Right text")
        textSection(L, key, "power", "Power text")

        if d().castbar then
            L:Heading("Cast bar")
            L:DB(function() return d().castbar end)
            L:Toggle("Show", "enable")
            L:Toggle("Icon", "icon")
            L:Slider("Width", "width", 40, 600, 1)
            L:Slider("Height", "height", 6, 60, 1)
            L:Toggle("Spell name", "showName")
            L:Toggle("Time", "showTime")
            L:Toggle("Its own mover", "detach", { tooltip = "Place the cast bar anywhere rather than under the frame." })
            if key == "player" then L:Toggle("Latency", "latency", { tooltip = "The red end of the bar is your latency: past it, the next cast can already be queued." }) end
        end

        if d().buffs then auraSection(L, key, "buffs", "Buffs") end
        if d().debuffs then auraSection(L, key, "debuffs", "Debuffs") end

        L:Heading("Icons")
        L:DB(d)
        L:Toggle("Raid marker", "raidIcon")
        L:Toggle("Leader and assistant", "leader")
        if key == "player" then
            L:Toggle("In combat", "combat")
            L:Toggle("Resting", "resting")
            if ns.myClass == "ROGUE" or ns.myClass == "DRUID" then L:Toggle("Combo points", "classPower") end
        end
        L:Toggle("Role", "role")
        L:Toggle("Ready check", "readyCheck")
        L:Toggle("Different phase", "phase")
        L:Toggle("Being resurrected", "resurrect")
        L:Toggle("Being summoned", "summon")

        L:Button("Reset this frame", function()
            W:Confirm(("Put every setting for the %s frame back to its default?"):format(UF.LABELS[key]), function()
                local fresh = ns:Copy(ns.defaults.profile.unitframes.units[key])
                local t = UF:UnitDB(key)
                for k in pairs(t) do t[k] = nil end
                for k, v in pairs(fresh) do t[k] = v end
                ns.Movers:Reset("uf_" .. key)
                UF:Update()
                ns.Config:Rebuild("unitframes." .. key)
            end, "Reset")
        end)
    end, { parent = "unitframes", onChange = update, order = order })
end

for i, key in ipairs({ "player", "target", "targettarget", "focus", "focustarget", "pet", "boss", "party", "raid" }) do
    unitPage(key, i)
end
