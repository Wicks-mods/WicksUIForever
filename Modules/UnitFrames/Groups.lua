-- Wick's UI
-- Modules/UnitFrames/Groups.lua: party and raid frames.
--
-- Both are secure group headers, so the game decides who is in them and
-- keeps them right through combat. What we control is the layout, which
-- is set out of combat and held through the fight.
--
-- The healer's pieces are the ones that make group frames worth
-- replacing:
--   a centre slot showing a debuff you can dispel, drawn by the client
--   up to three corner icons for your own heals over time
--   missing-health text
--   a fel border on whoever you are targeting
-- The dispel slot and the corners are aura containers the client fills,
-- so they keep working in combat, where addons cannot read auras.

local ADDON, ns = ...

local oUF = ns.oUF
local UF = ns.UnitFrames
local Chrome = ns.Core.Chrome
local C = Chrome.Colors

local G = {}
ns.UnitGroups = G

local unit = UF.unitDefaults
local function text(tag, point, x, y, size, enable)
    return { enable = enable ~= false, tag = tag, point = point, x = x or 0, y = y or 0, size = size or 12 }
end

local function groupDefaults(o)
    local d = unit(o)
    d.growth = d.growth or "DOWN"        -- DOWN, UP, RIGHT, LEFT
    d.spacing = d.spacing or 4
    d.sortBy = d.sortBy or "ROLE"        -- ROLE, GROUP, NAME, INDEX
    d.centerDebuff = d.centerDebuff ~= false
    d.centerSize = d.centerSize or 22
    d.myHots = d.myHots ~= false
    d.hotSize = d.hotSize or 10
    return d
end

local units = ns.defaults.profile.unitframes.units
units.party = groupDefaults({
    point = "LEFT,UIParent,LEFT,30,80",
    width = 170, height = 40, powerHeight = 5,
    showPlayer = true, showSolo = false,
    role = true, readyCheck = true, phase = true, resurrect = true, summon = true, rangeFade = true, leader = true,
    texts = {
        left = text("[wui:namecolor][name]", "LEFT", 4, 0, 12),
        right = text("[wui:deficit]", "RIGHT", -4, 0, 11),
        power = text("", "RIGHT", -4, 0, 10, false),
    },
    debuffs = { enable = true, perRow = 4, size = 22, attach = "RIGHT", anchor = "LEFT", growthX = "RIGHT", x = 4, y = 0, filter = "HARMFUL" },
    buffs = { enable = false },
    visibility = "[@raid6,exists] hide; [group:party] show; hide",
})
units.raid = groupDefaults({
    point = "TOPLEFT,UIParent,TOPLEFT,30,-300",
    width = 84, height = 42, powerHeight = 3, power = true,
    growth = "DOWN", columnGrowth = "RIGHT", perColumn = 5, columnSpacing = 4, spacing = 3,
    sortBy = "GROUP", groups = "1,2,3,4,5,6,7,8",
    role = true, readyCheck = true, phase = true, resurrect = true, summon = true, rangeFade = true, leader = false,
    texts = {
        left = text("[wui:namecolor][name]", "TOP", 0, -4, 11),
        right = text("[wui:deficit]", "BOTTOM", 0, 6, 10),
        power = text("", "RIGHT", -4, 0, 10, false),
    },
    debuffs = { enable = false },
    buffs = { enable = false },
    visibility = "[@raid6,exists] show; hide",
})

-- ============================================================
-- The healer's pieces, added at style time
-- ============================================================
local function addHealerPieces(self, d)
    if not self.CreateAuras or not d then return end
    -- One debuff you can remove, in the middle of the frame. The RAID
    -- filter asks the client for the ones this character can dispel.
    if d.centerDebuff then
        local a = self:CreateAuras({ initialAnchor = "CENTER" })
        a.size = d.centerSize
        a.showCount = true
        a.showDuration = false
        a.showDebuffBorder = true
        a.showDebuffIndicator = true
        a.disableMouse = true
        -- Before the slot or group is added, so the buttons it makes get it.
        a.PostCreateButton = function(_, button)
        ns:AuraCountdown(button, nil, false)
            if button.Icon then ns:CropIcon(button.Icon) end
            ns:CreateBackdrop(button, "Default", ns.mult)
        end
        a:AddSlot("HARMFUL|RAID")
        a:SetSize(d.centerSize, d.centerSize)
        a:SetPoint("CENTER", self, "CENTER", 0, 0)
        self.wuiCenter = a
    end
    -- Your own buffs on them: heals over time, shields. Three, top right.
    if d.myHots then
        local a = self:CreateAuras({ initialAnchor = "TOPRIGHT", growthX = "LEFT", growthY = "DOWN", layoutLimit = d.hotSize * 3 + 4 })
        a.size = d.hotSize
        a.elementSpacing = 1
        a.showCount = false
        a.showDuration = false
        a.disableMouse = true
        -- Before the slot or group is added, so the buttons it makes get it.
        a.PostCreateButton = function(_, button)
        ns:AuraCountdown(button, nil, false)
            if button.Icon then ns:CropIcon(button.Icon, 0.15) end
            ns:CreateBackdrop(button, "None", ns.mult)
        end
        a:AddGroup("HELPFUL|PLAYER|RAID", { maxFrameCount = 3 })
        a:SetSize(d.hotSize * 3 + 2, d.hotSize)
        a:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -2)
        self.wuiHots = a
    end
end
UF.PostStyle.party = addHealerPieces
UF.PostStyle.raid = addHealerPieces

-- ============================================================
-- Headers
-- ============================================================
local SORT = {
    ROLE  = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE" },
    GROUP = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8" },
    NAME  = { sortMethod = "NAME" },
    INDEX = { sortMethod = "INDEX" },
}

local GROW = {
    DOWN  = { point = "TOP",    x = 0,  y = -1 },
    UP    = { point = "BOTTOM", x = 0,  y = 1 },
    RIGHT = { point = "LEFT",   x = 1,  y = 0 },
    LEFT  = { point = "RIGHT",  x = -1, y = 0 },
}
local COLUMN = { RIGHT = "LEFT", LEFT = "RIGHT", DOWN = "TOP", UP = "BOTTOM" }

local function headerAttributes(key, d)
    local grow = GROW[d.growth] or GROW.DOWN
    local sort = SORT[d.sortBy] or SORT.ROLE
    local attrs = {
        showPlayer = key == "party" and d.showPlayer or (key == "raid"),
        showSolo = d.showSolo or false,
        showParty = key == "party",
        showRaid = key == "raid",
        point = grow.point,
        xOffset = grow.x * d.spacing,
        yOffset = grow.y * d.spacing,
        groupBy = sort.groupBy,
        groupingOrder = sort.groupingOrder,
        sortMethod = sort.sortMethod or "INDEX",
        ["oUF-initialConfigFunction"] = ("self:SetWidth(%d); self:SetHeight(%d)"):format(d.width, d.height),
    }
    if key == "raid" then
        attrs.groupFilter = d.groups or "1,2,3,4,5,6,7,8"
        attrs.maxColumns = 8
        attrs.unitsPerColumn = d.perColumn or 5
        attrs.columnSpacing = d.columnSpacing or 4
        attrs.columnAnchorPoint = COLUMN[d.columnGrowth or "RIGHT"] or "LEFT"
    end
    return attrs
end

local function applyAttributes(header, key, d)
    for att, val in pairs(headerAttributes(key, d)) do
        if att ~= "oUF-initialConfigFunction" then header:SetAttribute(att, val) end
    end
end

-- The mover follows the space a full group would take, so it is where
-- the frames will be when the group fills.
local function headerSize(key, d)
    local n = key == "raid" and (d.perColumn or 5) or 5
    local cols = key == "raid" and math.ceil(40 / (d.perColumn or 5)) or 1
    local vertical = d.growth == "DOWN" or d.growth == "UP"
    local w = vertical and d.width or (d.width * n + d.spacing * (n - 1))
    local h = vertical and (d.height * n + d.spacing * (n - 1)) or d.height
    if key == "raid" then
        local cs = d.columnSpacing or 4
        if vertical then w = d.width * cols + cs * (cols - 1) else h = d.height * cols + cs * (cols - 1) end
    end
    return w, h
end

function G:Spawn(key)
    local d = UF:UnitDB(key)
    local header = oUF:SpawnHeader("WicksUI_" .. key:gsub("^%l", string.upper), nil, headerAttributes(key, d))
    header.wuiKey = key
    self.headers[key] = header

    -- A holder the header hangs from, so the mover has a fixed size.
    local holder = CreateFrame("Frame", "WicksUI_" .. key .. "Holder", UIParent)
    holder:SetSize(headerSize(key, d))
    header:SetParent(holder)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", holder, "TOPLEFT")
    self.holders[key] = holder
    ns:CreateMover(holder, "uf_" .. key, UF.LABELS[key] .. " frames", d.point, { groups = "unitframes,group", config = "unitframes." .. key })
    return header
end

function G:Layout(key)
    local header, holder = self.headers[key], self.holders[key]
    if not header then return end
    local d = UF:UnitDB(key)
    applyAttributes(header, key, d)
    holder:SetSize(headerSize(key, d))
    ns.Movers:Resize("uf_" .. key)

    -- Where the header starts inside the holder follows the growth.
    header:ClearAllPoints()
    local grow = GROW[d.growth] or GROW.DOWN
    local corner = (d.growth == "UP" and "BOTTOM" or "TOP") .. ((d.growth == "LEFT" or d.columnGrowth == "LEFT") and "RIGHT" or "LEFT")
    header:SetPoint(corner, holder, corner)

    -- Children that exist already take the new size now.
    for i = 1, 40 do
        local child = header:GetAttribute("child" .. i)
        if not child then break end
        child.wuiHeaderChild = true
        child:SetSize(d.width, d.height)
        UF:Configure(child)
    end

    if d.enable and not self.testing then
        local cond = (d.visibility or "show"):gsub("%s+", " ")
        header:SetVisibility("custom " .. cond)
        ns.Movers:SetEnabled("uf_" .. key, true)
    elseif self.testing then
        header:SetVisibility("custom show")
        ns.Movers:SetEnabled("uf_" .. key, true)
    else
        header:SetVisibility("custom hide")
        ns.Movers:SetEnabled("uf_" .. key, false)
    end
end

-- Show the frames with fake members while placing them, so there is
-- something to see without a group.
-- A full group of you, to place and size the frames without a group.
-- The header is told to lay out from a negative starting index, which
-- makes it build every slot, and each slot is pointed at you and kept
-- shown. Leaving puts the real attributes and unit watch back.
local PREVIEW = { party = 5, raid = 25 }

local function children(header)
    local out = {}
    for i = 1, 40 do
        local c = header:GetAttribute("child" .. i)
        if not c then break end
        out[#out + 1] = c
    end
    return out
end

function G:SetTestMode(on)
    if InCombatLockdown() then
        ns.A:Print("group frames can be previewed once the fight is over.")
        return
    end
    self.testing = on
    for key, header in pairs(self.headers) do
        local d = UF:UnitDB(key)
        if on then
            header:SetAttribute("showSolo", true)
            header:SetAttribute("showPlayer", true)
            header:SetAttribute("showParty", true)
            header:SetAttribute("showRaid", true)
            header:SetAttribute("groupFilter", nil)
            header:SetAttribute("startingIndex", -(PREVIEW[key] - 1))
            header:SetVisibility("custom show")
            -- The header builds its slots a moment after it shows, so
            -- point them at you now and again once they exist.
            local function fill()
                if not G.testing or InCombatLockdown() then return end
                for _, c in ipairs(children(header)) do
                    UnregisterUnitWatch(c)
                    c:SetAttribute("unit", "player")
                    c:Show()
                    if c.UpdateAllElements then c:UpdateAllElements("WicksUI_Preview") end
                end
            end
            fill()
            C_Timer.After(0.2, fill)
            C_Timer.After(1, fill)
        else
            header:SetAttribute("startingIndex", 1)
            applyAttributes(header, key, d)
            for _, c in ipairs(children(header)) do
                c:SetAttribute("unit", nil)
                RegisterUnitWatch(c)
            end
            header:SetVisibility("custom " .. (d.enable and d.visibility or "hide"))
        end
    end
    ns.A:Print(on and "showing a full party and raid of you. Move them with /wui move; the same button ends the preview."
        or "preview over, group frames are back to normal.")
end


function G:Initialize()
    self.headers, self.holders = {}, {}
    -- The game's own party and raid frames step aside for ours. The raid
    -- manager stays: world markers and the ready check live on it. With
    -- both of ours off (another addon draws the group) the game's stay,
    -- for that addon to hide or keep.
    local party, raid = UF:UnitDB("party"), UF:UnitDB("raid")
    if (party and party.enable) or (raid and raid.enable) then
        pcall(oUF.DisableBlizzard, oUF, "party")
        local crc = _G.CompactRaidFrameContainer
        if crc then ns:Kill(crc) end
    end
    self:Spawn("party")
    self:Spawn("raid")
end

function G:Update()
    if not self.headers then return end
    self:Layout("party")
    self:Layout("raid")
end
