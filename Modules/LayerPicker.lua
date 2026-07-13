local E, L, V, P, G = unpack(ElvUI)
local CoA = E:GetModule("CoA")

local BUTTON_NAME = "LayerPickerFrame"

do
	local orig_AddButton = UIDropDownMenu_AddButton
	UIDropDownMenu_AddButton = function(info, level)
		if info and info.text == "Reset Position" and UIDROPDOWNMENU_INIT_MENU == LayerPickerFrameDropDown then
			return
		end

		return orig_AddButton(info, level)
	end
end

local function DisableDrag(button)
	if button.CoADragDisabled then return end
	button.CoADragDisabled = true

	button:SetScript("OnDragStart", nil)
	button:SetScript("OnDragStop", nil)
end

local function SetupMover(button)
	if CoA.layerPickerMoverCreated then return end

	local width, height = button:GetSize()
	if width == 0 or height == 0 then return end

	local left, bottom = button:GetLeft(), button:GetBottom()
	if not left or not bottom then return end

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
end

local function SkinButton(button)
	if button.CoASkinned then return end
	button.CoASkinned = true

	local name = button:GetName()
	local text = _G[name.."Text"]

	button:StripTextures(true)
	button:CreateBackdrop("Default")
	button:StyleButton()

	if text then
		text:FontTemplate()
	end
end

local function TryHook()
	local button = _G[BUTTON_NAME]

	if button then
		DisableDrag(button)
		SetupMover(button)

		if E.private.CoA.instance then
			SkinButton(button)
		end
	end

	return button ~= nil
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
