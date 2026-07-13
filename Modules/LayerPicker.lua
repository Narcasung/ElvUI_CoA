local E, L, V, P, G = unpack(ElvUI)
local CoA = E:GetModule("CoA")

local BUTTON_NAME = "LayerPickerFrame"

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

	if button and E.private.CoA.instance then
		SkinButton(button)
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
