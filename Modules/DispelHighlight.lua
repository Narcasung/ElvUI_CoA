local E, L, V, P, G = unpack(ElvUI)
local UF = E:GetModule("UnitFrames")
local CoA = E:GetModule("CoA")

-- Base dispel types each custom class can remove, independent of talents.
-- CHRONOMANCER is a special case: its dispel removes the last debuff applied
-- to the target regardless of type, so it's never filtered out here -- we
-- can only approximate this as "treat every typed debuff as dispellable",
-- since the underlying oUF scan only ever surfaces typed debuffs anyway.
local CLASS_DISPEL_TYPES = {
	CHRONOMANCER = true,
	SUNCLERIC = {Magic = true, Poison = true, Disease = true},
	STARCALLER = {Poison = true, Disease = true},
	PROPHET = {Poison = true},
	WITCHDOCTOR = {Curse = true},
	CULTIST = {Magic = true},
	PYROMANCER = {},
}

-- Extra dispel types unlocked by a talent choice. There's no reliable way to
-- auto-detect the talent on this server, so these are gated by a manual
-- checkbox in the options panel instead.
local TALENT_DISPEL_TYPES = {
	PROPHET = {flag = "hasBlightAntidote", types = {Curse = true}},
	CULTIST = {flag = "hasDevourCurse", types = {Curse = true}},
	PYROMANCER = {flag = "hasBurnImpurities", types = {Magic = true, Disease = true, Bleed = true}},
}

function CoA:CanDispel(debuffType)
	local _, class = UnitClass("player")
	local baseTypes = CLASS_DISPEL_TYPES[class]

	if baseTypes == true then return true end
	if baseTypes and baseTypes[debuffType] then return true end

	local talent = TALENT_DISPEL_TYPES[class]
	if talent and CoA.db.profile[talent.flag] and talent.types[debuffType] then return true end

	return false
end

local function SuppressHighlight(object)
	if object.DebuffHighlightBackdrop and object.DBHGlow then
		object.DBHGlow:Hide()
	elseif object.DebuffHighlightUseTexture then
		object.DebuffHighlight:SetTexture(nil)
	else
		object.DebuffHighlight:SetVertexColor(0, 0, 0, 0)
	end
end

local origPostUpdate = UF.PostUpdate_DebuffHighlight

local function DispelAwarePostUpdate(dbh, object, debuffType, texture, wasFiltered, style, color)
	origPostUpdate(dbh, object, debuffType, texture, wasFiltered, style, color)

	if CoA.db.profile.dispelHighlightOnlyMine and debuffType and not wasFiltered and not CoA:CanDispel(debuffType) then
		SuppressHighlight(object)
	end
end

UF.PostUpdate_DebuffHighlight = DispelAwarePostUpdate

hooksecurefunc(UF, "Configure_DebuffHighlight", function(_, frame)
	local dbh = frame.DebuffHighlight
	if dbh then
		dbh.PostUpdate = UF.PostUpdate_DebuffHighlight
	end
end)

function CoA:UpdateDispelHighlight()
	UF:Update_AllFrames()
end

-- On Ascension, UnitClass("player")'s second return only reliably reports the
-- real custom class (CULTIST, PYROMANCER, ...) a short while after login --
-- immediately at ADDON_LOADED/PLAYER_LOGIN it can still read back the generic
-- "HERO" base class. If a debuff highlight gets evaluated before that data
-- syncs, CoA:CanDispel wrongly returns false and the highlight stays wrongly
-- suppressed until the next aura change. Force one extra refresh shortly
-- after entering the world so the very first debuff isn't judged too early.
function CoA:InitializeDispelHighlight()
	CoA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		CoA:ScheduleTimer("UpdateDispelHighlight", 2)
	end)
end
