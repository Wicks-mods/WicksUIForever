local _, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

function Private.argcheck(value, num, ...)
	assert(type(num) == 'number', "Bad argument #2 to 'argcheck' (number expected, got " .. type(num) .. ')')

	for i = 1, select('#', ...) do
		if(type(value) == select(i, ...)) then return end
	end

	local types = string.join(', ', ...)
	local name = debugstack(2,2,0):match(": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to '%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end

function Private.print(...)
	print('|cff33ff99oUF:|r', ...)
end

function Private.nierror(...)
	return geterrorhandler()(...)
end

function Private.xpcall(func, ...)
	return xpcall(func, Private.nierror, ...)
end

function Private.unitExists(unit)
	return unit and (UnitExists(unit) or UnitIsVisible(unit))
end

function Private.unitIsUnit(unit1, unit2)
	-- A client without the comparison API (no secret unit tokens) can
	-- always compare.
	if(C_Secrets and C_Secrets.CanCompareUnitTokens and not C_Secrets.CanCompareUnitTokens(unit1, unit2)) then
		return false
	end
	return UnitIsUnit(unit1, unit2)
end

-- What the client ships, read off the templates it knows. TBC Anniversary
-- 2.5.6 has the 12.x engine but neither Blizzard_AuraContainer nor
-- Blizzard_PingUI, so the aura intrinsic and the pingable template are
-- missing there while everything else oUF leans on is present.
local function hasTemplate(name)
	if(not (C_XMLUtil and C_XMLUtil.GetTemplateInfo)) then return false end
	local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
	return ok and info ~= nil
end
Private.hasAuraContainer = hasTemplate('CustomAuraContainerTemplate')
Private.hasPing = hasTemplate('PingableUnitFrameTemplate')
Private.pingTemplate = Private.hasPing and ', PingableUnitFrameTemplate' or ''

local validator = CreateFrame('Frame')

function Private.validateEventUnit(unit)
	local isOK, _ = pcall(validator.RegisterUnitEvent, validator, 'UNIT_HEALTH', unit)
	if(isOK) then
		_, unit = validator:IsEventRegistered('UNIT_HEALTH')
		validator:UnregisterEvent('UNIT_HEALTH')

		return not not unit
	end
end

function Private.validateEvent(event)
	local isOK = xpcall(validator.RegisterEvent, Private.nierror, validator, event)
	if(isOK) then
		validator:UnregisterEvent(event)
	end

	return isOK
end

function Private.isUnitEvent(event, unit)
	local isOK = pcall(validator.RegisterUnitEvent, validator, event, unit)
	if(isOK) then
		validator:UnregisterEvent(event)
	end

	return isOK
end

local validSelectionTypes = {}
for _, selectionType in next, oUF.Enum.SelectionType do
	validSelectionTypes[selectionType] = selectionType
end

function Private.unitSelectionType(unit, considerHostile)
	if(considerHostile and UnitThreatSituation('player', unit)) then
		return 0
	else
		return validSelectionTypes[UnitSelectionType(unit, true)]
	end
end

local interface = select(4, GetBuildInfo())
Private.GameVersion = {
	             PTR = interface >= 120105,
	         Forever = interface >= 16000 and interface < 20000,
	         Vanilla = interface < 16000,
	  BurningCrusade = interface >= 20000 and interface < 30000,
	           Wrath = interface >= 30000 and interface < 40000,
	   TitanReforged = interface >= 38000 and interface < 40000,
	       Cataclysm = interface >= 40000 and interface < 50000,
	           Mists = interface >= 50000 and interface < 60000,
	        Warlords = interface >= 60000 and interface < 70000,
	          Legion = interface >= 70000 and interface < 80000,
	BattleForAzeroth = interface >= 80000 and interface < 90000,
	     Shadowlands = interface >= 90000 and interface < 100000,
	    Dragonflight = interface >= 100000 and interface < 110000,
	       WarWithin = interface >= 110000 and interface < 120000,
	        Midnight = interface >= 120000 and interface < 130000,
	       LastTitan = interface >= 130000 and interface < 140000,
}

-- map fluctuating game versions
Private.GameVersion.Retail = Private.GameVersion.Midnight
Private.GameVersion.Classic = Private.GameVersion.Mists
Private.GameVersion.Anniversary = Private.GameVersion.BurningCrusade

Private.GameCompatibility = {
	         Vanilla = interface >= 10000,
	  BurningCrusade = interface >= 20000,
	           Wrath = interface >= 30000,
	       Cataclysm = interface >= 40000,
	           Mists = interface >= 50000,
	        Warlords = interface >= 60000,
	          Legion = interface >= 70000,
	BattleForAzeroth = interface >= 80000,
	     Shadowlands = interface >= 90000,
	    Dragonflight = interface >= 100000,
	       WarWithin = interface >= 110000,
	        Midnight = interface >= 120000,
	       LastTitan = interface >= 130000,
}
