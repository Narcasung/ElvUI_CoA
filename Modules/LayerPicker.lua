local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local CoA = E:GetModule("CoA")

local BUTTON_NAME = "LayerPickerFrame"
local MIN_WIDTH, MIN_HEIGHT = 66, 14
local PAD_X, PAD_Y = 10, 10

local function UpdateFont(button)
	button = button or _G[BUTTON_NAME]
	local text = button and _G[button:GetName().."Text"]
	if not text then return end

	text:FontTemplate(LSM:Fetch("font", CoA.db.profile.instanceButtonFont), CoA.db.profile.instanceButtonFontSize, CoA.db.profile.instanceButtonFontOutline)

	button:SetSize(
		math.max(MIN_WIDTH, text:GetStringWidth() + PAD_X),
		math.max(MIN_HEIGHT, text:GetStringHeight() + PAD_Y)
	)
end

local function SyncHolderSize(button)
	local holder = _G["CoA_LayerPickerHolder"]
	button = button or _G[BUTTON_NAME]
	if holder and button then
		holder:Size(button:GetSize())
	end
end

function CoA:UpdateInstanceButtonFont()
	UpdateFont()
	SyncHolderSize()
end

-- Hooked at file scope, so unlike the rest of the skin it stays live even when
-- the skin is off -- check the toggle here instead. Reset Position only makes
-- sense while the frame is where the server put it; once we've handed it to a
-- mover the entry does nothing useful.
do
	local orig_AddButton = UIDropDownMenu_AddButton
	UIDropDownMenu_AddButton = function(info, level)
		if CoA.db and CoA.db.profile.skins.instanceSwap
		and info and info.text == "Reset Position" and UIDROPDOWNMENU_INIT_MENU == LayerPickerFrameDropDown then
			return
		end

		return orig_AddButton(info, level)
	end
end

-- A single nil-out isn't enough: native dragging ends with the engine
-- calling SetPoint directly on the frame, severing the live anchor to our
-- mover holder. So we don't just clear drag once, we permanently intercept
-- any future attempt to turn it back on. The CoAClearing* guards stop our
-- own corrective calls from re-triggering these same hooks.
local function DisableDrag(button)
	if button.CoADragDisabled then return end
	button.CoADragDisabled = true

	button:SetScript("OnDragStart", nil)
	button:SetScript("OnDragStop", nil)
	button:RegisterForDrag()

	hooksecurefunc(button, "SetScript", function(self, script, handler)
		if handler and (script == "OnDragStart" or script == "OnDragStop") and not self.CoAClearingDragScript then
			self.CoAClearingDragScript = true
			self:SetScript(script, nil)
			self.CoAClearingDragScript = false
		end
	end)

	hooksecurefunc(button, "RegisterForDrag", function(self, ...)
		if select("#", ...) > 0 and not self.CoAClearingDrag then
			self.CoAClearingDrag = true
			self:RegisterForDrag()
			self.CoAClearingDrag = false
		end
	end)
end

-- Created eagerly (independent of the native LayerPickerFrame ever showing
-- up) so the mover always appears in Toggle Anchors. The default point below
-- is only used until the player drags it once; after that E:CreateMover
-- restores the saved position from E.db.movers.
local function CreateMoverHolder()
	if CoA.layerPickerMoverCreated then return end
	CoA.layerPickerMoverCreated = true

	local holder = CreateFrame("Frame", "CoA_LayerPickerHolder", E.UIParent)
	holder:Size(MIN_WIDTH, MIN_HEIGHT)
	holder:Point("TOPLEFT", E.UIParent, "TOPLEFT", 250, -250)

	E:CreateMover(holder, "CoA_LayerPickerMover", "Instance", nil, nil, nil, "ALL,COA", nil, "CoA,skins,instanceSwap")
	holder:SetAllPoints(_G["CoA_LayerPickerMover"])
	_G["CoA_LayerPickerMover"]:SetFrameStrata("FULLSCREEN")
end

local function AnchorButton(button)
	local holder = _G["CoA_LayerPickerHolder"]
	if not holder then return end

	local function Anchor()
		button:ClearAllPoints()
		button:SetPoint("CENTER", holder, "CENTER")
	end

	if InCombatLockdown() then
		CoA:RegisterEvent("PLAYER_REGEN_ENABLED", function()
			Anchor()
			CoA:UnregisterEvent("PLAYER_REGEN_ENABLED")
		end)
	else
		Anchor()
	end
end

local function SkinButton(button)
	if button.CoASkinned then return end
	button.CoASkinned = true

	button:StripTextures(true)
	button:CreateBackdrop("Default")
	button:StyleButton()

	UpdateFont(button)
end

local function TryHook()
	local button = _G[BUTTON_NAME]

	if button then
		DisableDrag(button)
		SkinButton(button)
		SyncHolderSize(button)
		AnchorButton(button)
		return true
	end

	return false
end

function CoA:InitializeLayerPicker()
	CreateMoverHolder()

	if TryHook() then return end

	self.layerPickerTimer = self:ScheduleRepeatingTimer(function()
		if TryHook() then
			self:CancelTimer(self.layerPickerTimer)
			self.layerPickerTimer = nil
		end
	end, 0.5)
end
