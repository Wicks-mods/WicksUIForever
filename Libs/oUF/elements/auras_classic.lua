--[[
# Element: Auras (without the AuraContainer intrinsic)

The Auras meta element for a client that has no `AuraContainer` frame type.
TBC Anniversary 2.5.6 runs the 12.x engine with the modern aura API, but
Blizzard_AuraContainer is not part of its interface, so the intrinsic that
auras.lua builds on does not exist there. This file exposes the same meta
function, methods and options, backed by plain frames,
`C_UnitAuras.GetAuraDataByIndex` (or `UnitAura` on an older client) and
`UNIT_AURA`.

Exactly one of auras.lua and this file registers the element:
`Private.hasAuraContainer` decides.

## Options (on the element, or in a group or slot's options table)

.size, .width, .height    - Button size (number?)
.showCount                - Count fontstring with the applications (boolean?)
.showDuration             - Time fontstring with the time left (boolean?)
.showDebuffBorder         - Dispel-type coloured border on debuffs (boolean?)
.showBuffBorder           - Dispel-type coloured border on buffs (boolean?)
.showDebuffIndicator      - Dispel-type icon on the corner of a debuff (boolean?)
.showBuffIndicator        - Dispel-type icon on the corner of a buff (boolean?)
.showStealableBorder      - Glow on a stealable buff (boolean?)
.disableMouse             - No tooltip (boolean?)
.disableCooldown          - No cooldown swipe (boolean?)
.tooltipAnchor, .tooltipOffsetX, .tooltipOffsetY, .tooltipHideInCombat
.maxFrameCount            - Buttons per group (number?)
.elementSpacing           - Gap between buttons (number?)
.lineSpacing              - Gap between rows or columns (number?)
.sortMethod               - 'EXPIRATION' (default: timed auras first, soonest
                            to end first) or 'INDEX' (the client's order) (string?)
.sortDirection            - 'NORMAL' or 'REVERSE' (string?)

Not provided: cancelling an aura by click (`.cancelButton` is accepted and
ignored). A protected action needs a secure aura header; a layout that
wants it on this client builds one.

## Callbacks

PostCreateButton(button, options)
PostUpdateButton(button, unit, data, options)
PostUpdate(event)
--]]
local _, ns = ...
local oUF = ns.oUF

local Private = oUF.Private
local argcheck = Private.argcheck

if(Private.hasAuraContainer) then return end

local STATE = {}
local MAX_SCAN = 40 -- the client's own cap on auras per unit and filter
local TICK = 0.1

local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local LegacyUnitAura = _G.UnitAura

-- One aura as a table, whichever API the client has.
local function auraAt(unit, index, filter)
	if(GetAuraDataByIndex) then
		return GetAuraDataByIndex(unit, index, filter)
	elseif(LegacyUnitAura) then
		local name, icon, count, dispelName, duration, expirationTime, source, isStealable, _, spellId = LegacyUnitAura(unit, index, filter)
		if(not name) then return nil end
		return {
			name = name, icon = icon, applications = count or 0, dispelName = dispelName,
			duration = duration or 0, expirationTime = expirationTime or 0, sourceUnit = source,
			isStealable = isStealable, spellId = spellId,
		}
	end
end

local function option(element, options, key)
	local v = options[key]
	if(v == nil) then v = element[key] end
	return v
end

local function dispelColor(element, name)
	local owner = element.__owner
	local c = owner and owner.colors and owner.colors.dispel and owner.colors.dispel[name]
	if(c) then
		if(c.GetRGB) then return c:GetRGB() end
		if(c.r) then return c.r, c.g, c.b end
		return c[1], c[2], c[3]
	end
	local d = _G.DebuffTypeColor and _G.DebuffTypeColor[name]
	if(d) then return d.r, d.g, d.b end
end

local function formatTime(left)
	if(left >= 3600) then return string.format('%dh', math.floor(left / 3600 + 0.5)) end
	if(left >= 60) then return string.format('%dm', math.floor(left / 60 + 0.5)) end
	return string.format('%d', math.ceil(left))
end

-- ============================================================
-- Tooltips
-- ============================================================
local function updateTooltip(button)
	local unit, data, filter = button.unit, button.auraData, button.filter
	if(not (unit and data)) then return end
	local ok = false
	if(data.auraInstanceID) then
		if(button.isHelpful and GameTooltip.SetUnitBuffByAuraInstanceID) then
			ok = pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, unit, data.auraInstanceID, filter)
		elseif(not button.isHelpful and GameTooltip.SetUnitDebuffByAuraInstanceID) then
			ok = pcall(GameTooltip.SetUnitDebuffByAuraInstanceID, GameTooltip, unit, data.auraInstanceID, filter)
		end
	end
	if(not ok and GameTooltip.SetUnitAura and button.index) then
		pcall(GameTooltip.SetUnitAura, GameTooltip, unit, button.index, filter)
	end
end

local function onEnter(button)
	if(button.tooltipHideInCombat and InCombatLockdown()) then return end
	GameTooltip:SetOwner(button, button.tooltipAnchor or 'ANCHOR_BOTTOMLEFT', button.tooltipOffsetX or 0, button.tooltipOffsetY or 0)
	updateTooltip(button)
end

local function onLeave()
	GameTooltip:Hide()
end

-- ============================================================
-- Buttons
-- ============================================================
local function CreateButton(element, options, button)
	local size = options.size or element.size or 16
	button:SetSize(options.width or element.width or size, options.height or element.height or size)

	local mouse = not option(element, options, 'disableMouse')
	button:EnableMouse(mouse)
	button.tooltipAnchor = options.tooltipAnchor or element.tooltipAnchor or 'ANCHOR_BOTTOMLEFT'
	button.tooltipOffsetX = options.tooltipOffsetX or element.tooltipOffsetX or 0
	button.tooltipOffsetY = options.tooltipOffsetY or element.tooltipOffsetY or 0
	button.tooltipHideInCombat = option(element, options, 'tooltipHideInCombat')

	if(not option(element, options, 'disableCooldown')) then
		local cooldown = CreateFrame('Cooldown', '$parentCooldown', button, 'CooldownFrameTemplate')
		cooldown:SetAllPoints()
		if(cooldown.SetReverse) then cooldown:SetReverse(true) end
		if(cooldown.SetHideCountdownNumbers) then cooldown:SetHideCountdownNumbers(true) end
		button.Cooldown = cooldown
	end

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetAllPoints()
	button.Icon = icon

	-- Text above the cooldown swipe.
	local textParent = button
	if(button.Cooldown) then
		textParent = CreateFrame('Frame', nil, button)
		textParent:SetAllPoints()
		textParent:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)
	end
	button.textParent = textParent

	if(option(element, options, 'showCount')) then
		local count = textParent:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
		count:SetPoint('BOTTOMRIGHT', -1, 0)
		button.Count = count
	end

	button.showDebuffBorder = option(element, options, 'showDebuffBorder')
	button.showBuffBorder = option(element, options, 'showBuffBorder')
	if(button.showDebuffBorder or button.showBuffBorder) then
		local border = button:CreateTexture(nil, 'OVERLAY')
		border:SetAllPoints()
		border:SetTexture([[Interface\Buttons\UI-Debuff-Overlays]])
		border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		border:Hide()
		button.Border = border
	end

	button.showDebuffIndicator = option(element, options, 'showDebuffIndicator')
	button.showBuffIndicator = option(element, options, 'showBuffIndicator')
	if(button.showDebuffIndicator or button.showBuffIndicator) then
		local indicator = button:CreateTexture(nil, 'OVERLAY', nil, 1)
		indicator:SetPoint('CENTER', button, 'TOPRIGHT')
		indicator:SetSize(18, 18)
		indicator:Hide()
		button.DispelIndicator = indicator
	end

	if(option(element, options, 'showStealableBorder')) then
		local stealable = button:CreateTexture(nil, 'OVERLAY')
		stealable:SetPoint('TOPLEFT', -3, 3)
		stealable:SetPoint('BOTTOMRIGHT', 3, -3)
		stealable:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Stealable]])
		stealable:SetBlendMode('ADD')
		stealable:Hide()
		button.Stealable = stealable
	end

	if(option(element, options, 'showDuration')) then
		local time = textParent:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
		time:SetPoint('TOPLEFT', 1, 0)
		button.Time = time
	end

	if(mouse) then
		button:SetScript('OnEnter', onEnter)
		button:SetScript('OnLeave', onLeave)
	end

	--[[ Callback: Auras:PostCreateButton(button, options)
	Called after a new aura button has been created.

	* self    - the element used to represent the aura buttons
	* button  - the aura button (Button)
	* options - the aura group/slot options passed through to CreateButton (table)
	--]]
	if(element.PostCreateButton) then element:PostCreateButton(button, options) end
end

local function makeButton(element, source, i)
	local parentName = element:GetName()
	local button = CreateFrame('Button', parentName and (parentName .. source.key .. i) or nil, element)
	source.options.initializeFrame(button)
	source.buttons[i] = button
	return button
end

local function setButton(element, button, unit, data, source)
	button.unit, button.filter, button.index, button.auraData = unit, source.filter, data.index, data
	button.isHelpful = data.isHelpful
	if(button.isHelpful == nil) then button.isHelpful = not source.filter:find('HARMFUL') end

	button.Icon:SetTexture(data.icon)

	if(button.Count) then
		local n = data.applications or 0
		button.Count:SetText(n > 1 and n or '')
	end

	local timed = (data.duration or 0) > 0 and (data.expirationTime or 0) > 0
	if(button.Cooldown) then
		if(timed) then
			button.Cooldown:SetCooldown(data.expirationTime - data.duration, data.duration)
			button.Cooldown:Show()
		elseif(button.Cooldown.Clear) then
			button.Cooldown:Clear()
		else
			button.Cooldown:SetCooldown(0, 0)
		end
	end

	local wantDispel = (button.isHelpful and (button.showBuffBorder or button.showBuffIndicator))
		or (not button.isHelpful and (button.showDebuffBorder or button.showDebuffIndicator))
	local r, g, b
	if(wantDispel and data.dispelName) then r, g, b = dispelColor(element, data.dispelName) end

	if(button.Border) then
		local wantBorder = (button.isHelpful and button.showBuffBorder) or (not button.isHelpful and button.showDebuffBorder)
		if(wantBorder and r) then
			button.Border:SetVertexColor(r, g, b)
			button.Border:Show()
		else
			button.Border:Hide()
		end
	end

	if(button.DispelIndicator) then
		local wantIndicator = (button.isHelpful and button.showBuffIndicator) or (not button.isHelpful and button.showDebuffIndicator)
		if(wantIndicator and data.dispelName and data.dispelName ~= '') then
			button.DispelIndicator:SetTexture([[Interface\RaidFrame\Raid-Icon-Debuff]] .. data.dispelName)
			button.DispelIndicator:Show()
		else
			button.DispelIndicator:Hide()
		end
	end

	if(button.Stealable) then
		button.Stealable:SetShown(data.isStealable and true or false)
	end

	if(button.Time) then
		button.Time:SetText(timed and formatTime(math.max(0, data.expirationTime - GetTime())) or '')
	end

	button:Show()

	--[[ Callback: Auras:PostUpdateButton(button, unit, data, options)
	Called after a button has been given an aura.

	* self    - the element used to represent the aura buttons
	* button  - the aura button (Button)
	* unit    - the unit the aura is on (string)
	* data    - the aura (AuraData)
	* options - the aura group/slot options (table)
	--]]
	if(element.PostUpdateButton) then element:PostUpdateButton(button, unit, data, source.options) end
end

-- ============================================================
-- Scanning and layout
-- ============================================================
local function scan(element, unit, source)
	local options = source.options
	local candidates = options.candidateFilters
	local include = candidates and candidates.includeSpellIDs
	local exclude = candidates and candidates.excludeSpellIDs
	local out = {}
	for index = 1, MAX_SCAN do
		local data = auraAt(unit, index, source.filter)
		if(not data) then break end
		if((not include or include[data.spellId]) and not (exclude and exclude[data.spellId])) then
			data.index = index
			out[#out + 1] = data
		end
	end

	local method = options.sortMethod or element.sortMethod or 'EXPIRATION'
	if(method == 'EXPIRATION') then
		table.sort(out, function(a, b)
			local ea, eb = a.expirationTime or 0, b.expirationTime or 0
			if((ea == 0) ~= (eb == 0)) then return ea ~= 0 end -- timed before permanent
			if(ea ~= eb) then return ea < eb end
			return a.index < b.index
		end)
	end
	if((options.sortDirection or element.sortDirection) == 'REVERSE') then
		local n = #out
		for i = 1, math.floor(n / 2) do out[i], out[n - i + 1] = out[n - i + 1], out[i] end
	end
	return out
end

-- Buttons flow from the initial anchor along the growth axis and wrap at
-- the layout limit, one line stacking on the next. Button sizes are taken
-- as uniform within an element, which is how the layouts use it.
local function layoutButtons(element, buttons)
	local anchor = element.initialAnchor or 'TOPLEFT'
	local gx = element.growthX == 'LEFT' and -1 or 1
	local gy = element.growthY == 'DOWN' and -1 or 1
	local vertical = element.layoutVertical
	local limit = element.layoutLimit or 0
	if(limit <= 0) then limit = vertical and element:GetHeight() or element:GetWidth() end
	local spacing = element.elementSpacing or 0
	local lineSpacing = element.lineSpacing or 0

	local along, across = 0, 0
	for i, button in ipairs(buttons) do
		local w, h = button:GetWidth(), button:GetHeight()
		local step = vertical and h or w
		if(i > 1 and limit and limit > 0 and along + step > limit + 0.5) then
			along = 0
			across = across + (vertical and w or h) + lineSpacing
		end
		button:ClearAllPoints()
		local dx = vertical and across or along
		local dy = vertical and along or across
		button:SetPoint(anchor, element, anchor, dx * gx, dy * gy)
		along = along + step + spacing
	end
end

local function tick(element, elapsed)
	element.sinceTick = (element.sinceTick or 0) + elapsed
	if(element.sinceTick < TICK) then return end
	element.sinceTick = 0
	local now = GetTime()
	for _, button in ipairs(element.activeButtons) do
		local data = button.auraData
		if(button.Time and data) then
			if((data.duration or 0) > 0 and (data.expirationTime or 0) > 0) then
				local left = data.expirationTime - now
				button.Time:SetText(left > 0 and formatTime(left) or '')
			else
				button.Time:SetText('')
			end
		end
	end
end

local function hideAll(element)
	for _, source in ipairs(element.sources) do
		for _, button in ipairs(source.buttons) do
			button.auraData = nil
			button:Hide()
		end
	end
	element.activeButtons = {}
	element:SetScript('OnUpdate', nil)
end

local function updateElement(self, element, event)
	local unit = self.__unit
	element.__unit = unit
	if(not unit or not element.enabled) then
		hideAll(element)
		return
	end

	local shown, timing = {}, false
	for _, source in ipairs(element.sources) do
		local list = scan(element, unit, source)
		local max = math.min(#list, source.options.maxFrameCount or MAX_SCAN)
		for i = 1, max do
			local button = source.buttons[i] or makeButton(element, source, i)
			setButton(element, button, unit, list[i], source)
			shown[#shown + 1] = button
			if(button.Time) then timing = true end
		end
		for i = max + 1, #source.buttons do
			source.buttons[i].auraData = nil
			source.buttons[i]:Hide()
		end
	end
	element.activeButtons = shown
	layoutButtons(element, shown)
	element:SetScript('OnUpdate', (timing and #shown > 0) and tick or nil)

	--[[ Callback: Auras:PostUpdate(event)
	Called after the element has been updated.

	* self  - the Auras element
	* event - the event that triggered the update
	--]]
	if(element.PostUpdate) then element:PostUpdate(event) end
end

-- ============================================================
-- The element
-- ============================================================
local elementMixin = {}

local function addSource(self, kind, filter, options)
	argcheck(filter, 2, 'string')
	argcheck(options, 3, 'table', 'nil')
	options = options or {}
	if(kind == 'Slot') then options.maxFrameCount = 1 end
	if(not options.initializeFrame) then
		local create = options.CreateButton or self.CreateButton or CreateButton
		options.initializeFrame = function(button) create(self, options, button) end
	end
	local frame = self.__owner
	local state = STATE[frame]
	local index
	if(kind == 'Slot') then
		state.slotIndex = state.slotIndex + 1
		index = state.slotIndex
	else
		state.groupIndex = state.groupIndex + 1
		index = state.groupIndex
	end
	local key = kind .. index
	self.sources[#self.sources + 1] = { key = key, filter = filter, options = options, buttons = {} }
	return key
end

--[[ Auras: auras:AddGroup(filter[, options])
Defines a group of auras to display on the element. Can be called more than once.

* filter  - aura filter for this group (string)
* options - options for this group; button options here override the element's (table?)

## Returns

* groupKey - identifier for this group (string)
--]]
function elementMixin:AddGroup(filter, options)
	return addSource(self, 'Group', filter, options)
end

--[[ Auras: auras:AddSlot(filter[, options])
Defines a slot for a single aura. `options.candidateFilters.includeSpellIDs`
narrows it to given spells. Can be called more than once.

* filter  - aura filter for this slot (string)
* options - options for this slot (table?)

## Returns

* slotKey - identifier for this slot (string)
--]]
function elementMixin:AddSlot(filter, options)
	return addSource(self, 'Slot', filter, options)
end

--[[ Auras: auras:ForceUpdate()
Rescan and redraw every group and slot on the element.
--]]
function elementMixin:ForceUpdate()
	updateElement(self.__owner, self, 'ForceUpdate')
end

function elementMixin:GetUnit() return self.__unit end
function elementMixin:SetUnit(unit) self.__unit = unit; self:ForceUpdate() end
function elementMixin:SetEnabled(flag)
	self.enabled = flag and true or false
	self:ForceUpdate()
end

--[[ Auras: frame:CreateAuras([options])
Create and return an aura element.

* self     - the unit frame on which to create the element
* options  - extra options (table?)

## Options

.layout        - AnchorUtil.FlowLayoutAxis.Vertical for columns; rows otherwise (number?)
.layoutLimit   - Max width (or height) of a line before it wraps. Defaults to the frame's (number?)
.initialAnchor - Anchor point the first button sits in. Defaults to 'TOPLEFT' (string?)
.growthX       - 'LEFT' or 'RIGHT'. Defaults to 'RIGHT' (string?)
.growthY       - 'UP' or 'DOWN'. Defaults to 'UP' (string?)

## Returns

* auras - the element (Frame)
--]]
local function Create(self, options)
	if(not STATE[self]) then
		STATE[self] = { index = 0, elements = {}, groupIndex = 0, slotIndex = 0 }
	end
	STATE[self].index = STATE[self].index + 1
	local element = CreateFrame('Frame', '$parentAuras' .. STATE[self].index, self)
	STATE[self].elements[STATE[self].index] = element

	element.__owner = self
	element.sources = {}
	element.activeButtons = {}
	element.enabled = true
	if(options) then
		element.initialAnchor = options.initialAnchor or 'TOPLEFT'
		element.growthX = options.growthX or 'RIGHT'
		element.growthY = options.growthY or 'UP'
		element.layoutLimit = options.layoutLimit
		local vertical = _G.AnchorUtil and _G.AnchorUtil.FlowLayoutAxis and _G.AnchorUtil.FlowLayoutAxis.Vertical
		element.layoutVertical = vertical ~= nil and options.layout == vertical
	end
	return Mixin(element, elementMixin)
end

local function Path(self, event, unit)
	if(STATE[self] and STATE[self].elements) then
		for _, element in next, STATE[self].elements do
			updateElement(self, element, event)
		end
	end
end

local function Update(self, event)
	Path(self, event, self.__unit)
end

local function Enable(self)
	if(STATE[self] and STATE[self].elements) then
		self:RegisterEvent('UNIT_AURA', Path)
		return true
	end
end

local function Disable(self)
	if(STATE[self] and STATE[self].elements) then
		self:UnregisterEvent('UNIT_AURA', Path)
		for _, element in next, STATE[self].elements do
			hideAll(element)
		end
	end
end

oUF:AddMetaElement('Auras', Create, Update, Enable, Disable)
