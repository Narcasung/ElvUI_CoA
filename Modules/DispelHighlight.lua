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

-- Extra dispel types unlocked by a talent choice, keyed to the Character
-- Advancement entry that grants them. The IDs are stable and shared across
-- every class tree, so querying one from a class that can't take it simply
-- reports rank 0 rather than erroring.
local TALENT_DISPEL_TYPES = {
	PROPHET = {talentID = 6324, types = {Curse = true}}, -- Blight Antidote
	CULTIST = {talentID = 12982, types = {Curse = true}}, -- Devour Curse
	PYROMANCER = {talentID = 31276, types = {Magic = true, Disease = true, Bleed = true}}, -- Burn Impurities
}

-- Cached result of the talent lookup for the player's current build.
-- PostUpdate_DebuffHighlight runs once per aura per frame, so the query is
-- hoisted out of that path and refreshed only when the build can change.
local hasTalentDispel = false

-- C_CharacterAdvancement is a server addition with no API documentation, so
-- every entry point is guarded and a failed call reads as "talent not taken",
-- which degrades to the same behaviour as before auto-detection existed.
local function HasTalent(talentID)
	local api = C_CharacterAdvancement
	if not (api and type(api.GetTalentRankByID) == "function") then return false end

	local ok, rank = pcall(api.GetTalentRankByID, talentID)

	return ok and type(rank) == "number" and rank > 0
end

local function RefreshTalentState()
	local _, class = UnitClass("player")
	local talent = TALENT_DISPEL_TYPES[class]

	hasTalentDispel = (talent and HasTalent(talent.talentID)) or false
end

function CoA:CanDispel(debuffType)
	local _, class = UnitClass("player")
	local baseTypes = CLASS_DISPEL_TYPES[class]

	if baseTypes == true then return true end
	if baseTypes and baseTypes[debuffType] then return true end

	local talent = TALENT_DISPEL_TYPES[class]
	if talent and hasTalentDispel and CoA.db.profile.dispelHighlightDetectTalents and talent.types[debuffType] then
		return true
	end

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
	RefreshTalentState()
	UF:Update_AllFrames()
end

-- On Ascension, UnitClass("player")'s second return only reliably reports the
-- real custom class (CULTIST, PYROMANCER, ...) a short while after login --
-- immediately at ADDON_LOADED/PLAYER_LOGIN it can still read back the generic
-- "HERO" base class, and the advancement data lags in the same way. If a
-- debuff highlight gets evaluated before that data syncs, CoA:CanDispel
-- wrongly returns false and the highlight stays wrongly suppressed until the
-- next aura change. Force one extra refresh shortly after entering the world
-- so the very first debuff isn't judged too early.
--
-- CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT fires when a build is confirmed,
-- which is the point the talent ranks actually change. The advancement UI also
-- fires CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED while talents are being
-- clicked around, but ranks don't move until the build is saved, so listening
-- to it would only cost refreshes that read back the unchanged state.
function CoA:InitializeDispelHighlight()
	CoA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		CoA:ScheduleTimer("UpdateDispelHighlight", 2)
	end)

	CoA:RegisterEvent("CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT", function()
		CoA:UpdateDispelHighlight()
	end)
end
