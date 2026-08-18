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
	PROPHET = {talentID = 6324, talentName = "Blight Antidote", types = {Curse = true}},
	CULTIST = {talentID = 12982, talentName = "Devour Curse", types = {Curse = true}},
	PYROMANCER = {talentID = 31276, talentName = "Burn Impurities", types = {Magic = true, Disease = true, Bleed = true}},
}

-- Cached result of the talent lookup for the player's current build.
-- PostUpdate_DebuffHighlight runs once per aura per frame, so the query is
-- hoisted out of that path and refreshed only when the build can change.
local hasTalentDispel = false

-- C_CharacterAdvancement is a server addition with no API documentation, so
-- every entry point is guarded and a failed call reads as "talent not taken",
-- which degrades to the same behaviour as before auto-detection existed.
local function HasTalent(talent)
	local api = C_CharacterAdvancement
	if not api then return false end

	if type(api.GetTalentRankByID) == "function" then
		local ok, rank = pcall(api.GetTalentRankByID, talent.talentID)
		if ok and type(rank) == "number" and rank > 0 then return true end
	end

	-- Fall back to matching the talent by name, so an entry ID gone stale after
	-- a server rebalance doesn't silently switch the feature off. Names are the
	-- more fragile key of the two, but GetKnownTalentEntries only ever lists
	-- entries the player has actually learned, which makes this a genuinely
	-- independent check rather than a second opinion on the same ID. The list
	-- has been seen with holes in it, so it's walked with pairs.
	if type(api.GetKnownTalentEntries) == "function" then
		local ok, entries = pcall(api.GetKnownTalentEntries)
		if ok and type(entries) == "table" then
			for _, entry in pairs(entries) do
				if type(entry) == "table" and entry.Name == talent.talentName then return true end
			end
		end
	end

	return false
end

-- Returns whether the talent state actually moved, so callers reacting to the
-- chattier advancement events can skip the unitframe rebuild when it didn't.
local function RefreshTalentState()
	local _, class = UnitClass("player")
	local talent = TALENT_DISPEL_TYPES[class]
	local hasTalent = (talent and HasTalent(talent)) or false

	if hasTalent == hasTalentDispel then return false end

	hasTalentDispel = hasTalent

	return true
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

function CoA:RefreshDispelTalents()
	if RefreshTalentState() then
		UF:Update_AllFrames()
	end
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
-- CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT fires when a build is confirmed
-- in the talent UI, but switching to another saved specialization doesn't
-- confirm anything -- that path only fires PENDING_BUILD_UPDATED and
-- SUGGESTIONS_UPDATED, so both are needed or the ranks read stale for the rest
-- of the session. PENDING_BUILD_UPDATED also fires on every click inside the
-- talent UI and SUGGESTIONS_UPDATED is only incidentally related, which is why
-- they go through RefreshDispelTalents: it costs one rank lookup and rebuilds
-- the unitframes only when the answer changed.
function CoA:InitializeDispelHighlight()
	CoA:RegisterEvent("PLAYER_ENTERING_WORLD", function()
		CoA:ScheduleTimer("UpdateDispelHighlight", 2)
	end)

	for _, event in ipairs({
		"CHARACTER_ADVANCEMENT_UPDATE_ENTRIES_RESULT",
		"CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED",
		"CHARACTER_ADVANCEMENT_SUGGESTIONS_UPDATED",
	}) do
		CoA:RegisterEvent(event, function()
			CoA:RefreshDispelTalents()
		end)
	end
end
