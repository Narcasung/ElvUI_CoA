local E, L, V, P, G = unpack(ElvUI)
local CoA = E:GetModule("CoA")

local FRAMES = {
	{name = "CoAResourceSegmentBar", moverText = "Resource Segment Bar", hideKey = "hideResourceSegmentBar"},
	{name = "CoAResourceOrb", moverText = "Resource Orb", hideKey = "hideResourceOrb"},
	{name = "CoAResourceBar", moverText = "Resource Bar", hideKey = "hideResourceBar"},
	{name = "CoAMultiCastActionBarFrame", moverText = "Multi Cast Action Bar", hideKey = "hideMultiCastActionBar"},
}

local FRAME_NAMES = {}
for _, def in ipairs(FRAMES) do
	FRAME_NAMES[def.name] = true
end

-- These frames' native right-click dropdown offers a "Lock/Unlock Frame"
-- entry that's meaningless now that dragging is permanently disabled (see
-- DisableDrag below), so strip it. Matched loosely (case-insensitive,
-- requiring both words) since the exact wording isn't confirmed, and scoped
-- to only our tracked frames' dropdowns so it can't affect unrelated menus.
do
	local function IsTrackedDropdown(menu)
		if not menu then return false end

		local name = menu.GetName and menu:GetName()
		local ownerName = name and name:match("^(.-)DropDown$")
		if ownerName and FRAME_NAMES[ownerName] then return true end

		local parent = menu.GetParent and menu:GetParent()
		local parentName = parent and parent.GetName and parent:GetName()
		return parentName and FRAME_NAMES[parentName] or false
	end

	local orig_AddButton = UIDropDownMenu_AddButton
	UIDropDownMenu_AddButton = function(info, level)
		if info and info.text and IsTrackedDropdown(UIDROPDOWNMENU_INIT_MENU) then
			local text = info.text:lower()
			if text:find("lock") and text:find("frame") then
				return
			end
		end

		return orig_AddButton(info, level)
	end
end

-- Replace the native "Drag to move" tooltip hint with one that reflects how
-- these frames are actually repositioned now (native drag is disabled).
-- Scoped by IsMouseOver rather than GameTooltip:GetOwner(), since the owner
-- passed to SetOwner may be a child region rather than the tracked frame
-- itself. Matched loosely (case-insensitive "drag" + "move") since the exact
-- wording isn't confirmed. Hooked on both OnShow and OnUpdate since some
-- tooltips keep refreshing their lines while visible.
local tooltipFrames = {}
local tooltipHooked = false

local function ReplaceTooltipLines()
	local hovering = false
	for frame in pairs(tooltipFrames) do
		if frame:IsMouseOver() then
			hovering = true
			break
		end
	end
	if not hovering then return end

	for i = 1, GameTooltip:NumLines() do
		local line = _G["GameTooltipTextLeft"..i]
		local text = line and line:GetText()
		if text then
			-- Some lines combine the drag hint with other text (e.g. a
			-- trailing "Right-click for options"), so replace just the
			-- matched span instead of the whole line.
			local replaced, count = text:gsub("[Dd]rag.-[Mm]ove", "Toggle ElvUI's anchors to move")
			if count > 0 then
				line:SetText(replaced)
			end
		end
	end
end

local function FixTooltip(frame)
	if tooltipFrames[frame] then return end
	tooltipFrames[frame] = true

	if not tooltipHooked then
		tooltipHooked = true
		GameTooltip:HookScript("OnShow", ReplaceTooltipLines)
		GameTooltip:HookScript("OnUpdate", ReplaceTooltipLines)
	end
end

-- A single nil-out isn't enough: the frame's own update logic re-attaches
-- OnDragStart/OnDragStop (and re-registers drag buttons) on refresh, and
-- native dragging ends with the engine calling SetPoint directly on the
-- frame, severing the live anchor to our mover holder. So we don't just
-- clear drag once, we permanently intercept any future attempt to turn it
-- back on. The CoAClearing* guards stop our own corrective calls from
-- re-triggering these same hooks.
local function DisableDrag(frame)
	if frame.CoADragDisabled then return end
	frame.CoADragDisabled = true

	frame:SetScript("OnDragStart", nil)
	frame:SetScript("OnDragStop", nil)
	frame:RegisterForDrag()

	hooksecurefunc(frame, "SetScript", function(self, script, handler)
		if handler and (script == "OnDragStart" or script == "OnDragStop") and not self.CoAClearingDragScript then
			self.CoAClearingDragScript = true
			self:SetScript(script, nil)
			self.CoAClearingDragScript = false
		end
	end)

	hooksecurefunc(frame, "RegisterForDrag", function(self, ...)
		if select("#", ...) > 0 and not self.CoAClearingDrag then
			self.CoAClearingDrag = true
			self:RegisterForDrag()
			self.CoAClearingDrag = false
		end
	end)
end

-- Anchoring a frame while in combat lockdown can taint it, so anchors
-- queued during combat are batched and applied together on the next
-- PLAYER_REGEN_ENABLED instead of each frame registering its own handler
-- (which would stomp on each other, since AceEvent keeps only the most
-- recently registered callback per event for a given object).
local pendingAnchors = {}
local combatHandlerRegistered = false

local function QueueAnchor(fn)
	if not InCombatLockdown() then
		fn()
		return
	end

	table.insert(pendingAnchors, fn)

	if not combatHandlerRegistered then
		combatHandlerRegistered = true

		CoA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
			for i = 1, #pendingAnchors do
				pendingAnchors[i]()
			end

			wipe(pendingAnchors)
			CoA:UnregisterEvent("PLAYER_REGEN_ENABLED")
			combatHandlerRegistered = false
		end)
	end
end

local function AnchorToHolder(frame, holder)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", holder, "CENTER")
end

-- Class resource frames re-anchor themselves (e.g. relative to the player/
-- target frame) whenever they refresh, which stomps our mover anchor. Since
-- there's no event that fires only for that self-repositioning, we hook
-- SetPoint itself and snap back to the holder any time something else moves
-- the frame. CoARepositioning guards against the corrective SetPoint call
-- re-triggering this same hook.
local function LockPosition(frame, holder)
	if frame.CoAPositionLocked then return end
	frame.CoAPositionLocked = true

	hooksecurefunc(frame, "SetPoint", function(self)
		if self.CoARepositioning then return end
		self.CoARepositioning = true

		QueueAnchor(function()
			AnchorToHolder(self, holder)
			self.CoARepositioning = false
		end)
	end)
end

local function SetupMover(frame, name, moverText)
	if frame.CoAMoverCreated then return true end

	local width, height = frame:GetSize()
	if width == 0 or height == 0 then return false end

	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if not left or not bottom then return false end

	frame.CoAMoverCreated = true

	local holder = CreateFrame("Frame", "CoA_"..name.."Holder", E.UIParent)
	holder:Size(width, height)
	holder:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", left, bottom)

	E:CreateMover(holder, "CoA_"..name.."Mover", moverText, nil, nil, nil, "ALL,COA", nil, "CoA,skin,classResources")
	holder:SetAllPoints(_G["CoA_"..name.."Mover"])

	QueueAnchor(function()
		AnchorToHolder(frame, holder)
		LockPosition(frame, holder)
	end)

	return true
end

-- The server never Show()s a frame the current class doesn't use, so its
-- data (powerType, maxValue, ...) is never populated. Forcing Show() on it
-- exposes that uninitialized state and renders as a garbage white bar
-- texture (same issue and same fix as HideCoAUI). Only force-show a frame
-- we've already seen the game display naturally at least once.
local seenNaturalShow = {}

-- CoAForceHidden distinguishes frames we hid ourselves (via the options
-- checkbox) from frames the game itself decided to hide, so unchecking the
-- box only restores frames we were suppressing.
local function ApplyVisibility(frame, hideKey)
	if CoA.db.profile[hideKey] then
		frame.CoAForceHidden = true
		frame:Hide()
	elseif frame.CoAForceHidden and seenNaturalShow[frame] then
		frame.CoAForceHidden = false
		frame:Show()
	end
end

local function SetupVisibility(frame, hideKey)
	if frame.CoAVisibilityHooked then return end
	frame.CoAVisibilityHooked = true

	frame:HookScript("OnShow", function(self)
		seenNaturalShow[self] = true
		ApplyVisibility(self, hideKey)
	end)

	ApplyVisibility(frame, hideKey)
end

function CoA:UpdateClassResourceVisibility()
	for _, def in ipairs(FRAMES) do
		local frame = _G[def.name]
		if frame then
			ApplyVisibility(frame, def.hideKey)
		end
	end
end

local hooked = {}

local function TryHookAll()
	local allHooked = true

	for _, def in ipairs(FRAMES) do
		if not hooked[def.name] then
			local frame = _G[def.name]

			if frame then
				DisableDrag(frame)
				SetupVisibility(frame, def.hideKey)
				FixTooltip(frame)

				if SetupMover(frame, def.name, def.moverText) then
					hooked[def.name] = true
				else
					allHooked = false
				end
			else
				allHooked = false
			end
		end
	end

	return allHooked
end

function CoA:InitializeClassResources()
	if TryHookAll() then return end

	self.classResourcesTimer = self:ScheduleRepeatingTimer(function()
		if TryHookAll() then
			self:CancelTimer(self.classResourcesTimer)
			self.classResourcesTimer = nil
		end
	end, 0.5)
end
