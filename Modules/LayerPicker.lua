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

function CoA:UpdateInstanceButtonFont()
	UpdateFont()
end

do
	local orig_AddButton = UIDropDownMenu_AddButton
	UIDropDownMenu_AddButton = function(info, level)
		if info and info.text == "Reset Position" and UIDROPDOWNMENU_INIT_MENU == LayerPickerFrameDropDown then
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

local function SetupMover(button)
	if CoA.layerPickerMoverCreated then return true end

	local width, height = button:GetSize()
	if width == 0 or height == 0 then return false end

	local left, bottom = button:GetLeft(), button:GetBottom()
	if not left or not bottom then return false end

	CoA.layerPickerMoverCreated = true

	local holder = CreateFrame("Frame", "CoA_LayerPickerHolder", E.UIParent)
	holder:Size(width, height)
	holder:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", left, bottom)

	E:CreateMover(holder, "CoA_LayerPickerMover", "Instance", nil, nil, nil, nil, nil, "CoA,skin,instance")
	holder:SetAllPoints(_G["CoA_LayerPickerMover"])
	_G["CoA_LayerPickerMover"]:SetFrameStrata("FULLSCREEN")

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

	return true
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
		return SetupMover(button)
	end

	return false
end

function CoA:InitializeLayerPicker()
	if TryHook() then return end

	self.layerPickerTimer = self:ScheduleRepeatingTimer(function()
		if TryHook() then
			self:CancelTimer(self.layerPickerTimer)
			self.layerPickerTimer = nil
		end
	end, 0.5)
end
