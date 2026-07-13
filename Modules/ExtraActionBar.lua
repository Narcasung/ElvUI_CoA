local E, L, V, P, G = unpack(ElvUI)
local LSM = E.Libs.LSM
local CoA = E:GetModule("CoA")

local CONTAINER_NAME = "ExtraActionBar"
local BUTTON_NAME = "ExtraActionBarPoolFrameExtraActionButtonTemplate1"
local BINDING_ACTION = "CLICK "..BUTTON_NAME..":LeftButton"

_G["BINDING_NAME_"..BINDING_ACTION] = "Extra Action Button"

local function SkinGlow(button, name)
	local glow = _G[name.."SpellActivationAlert"]
	if not glow or not glow.GetNumRegions then return end

	for i = 1, glow:GetNumRegions() do
		local region = select(i, glow:GetRegions())
		if region and region.IsObjectType and region:IsObjectType("Texture") then
			region:SetVertexColor(unpack(E.media.rgbvaluecolor))
		end
	end
end

local function UpdateSize(button)
	button = button or _G[BUTTON_NAME]
	if button then
		local size = E.global.CoA.extraActionButtonSize or 52
		button:SetSize(size, size)
	end
end

function CoA:UpdateExtraActionButtonSize()
	UpdateSize()
end

local function UpdateHotkeyText(button)
	button = button or _G[BUTTON_NAME]
	local hotkey = button and _G[button:GetName().."HotKey"]
	if not hotkey then return end

	local key = GetBindingKey(BINDING_ACTION)
	if key then
		hotkey:SetText(GetBindingText(key, "KEY_"))
		hotkey:Show()
	else
		hotkey:SetText("")
		hotkey:Hide()
	end
end

local function RecenterAnchor(button, container)
	local x, y = button:GetCenter()
	local cx, cy = container:GetCenter()
	if not (x and y and cx and cy) then return end

	button:ClearAllPoints()
	button:SetPoint("CENTER", container, "CENTER", x - cx, y - cy)
end

local function SkinButton(button, container)
	if button.CoASkinned then return end
	button.CoASkinned = true

	RecenterAnchor(button, container)
	UpdateSize(button)

	local name = button:GetName()
	local icon = _G[name.."Icon"]
	local hotkey = _G[name.."HotKey"]
	local macroText = _G[name.."Name"]
	local count = _G[name.."Count"]
	local flash = _G[name.."Flash"]
	local border = _G[name.."Border"]
	local normal = _G[name.."NormalTexture"]
	local normal2 = button:GetNormalTexture()
	local cooldown = _G[name.."Cooldown"]

	if flash then flash:SetTexture(nil) end
	if border then border:Kill() end
	if normal then normal:SetTexture(nil) normal:Hide() end
	if normal2 then normal2:SetTexture(nil) normal2:Hide() end

	for i = 1, button:GetNumRegions() do
		local region = select(i, button:GetRegions())
		if region and region.IsObjectType and region:IsObjectType("Texture") and region:GetTexture() == [[Interface\ExtraButton\Default]] then
			region:SetTexture(nil)
			region:Hide()
		end
	end

	button:CreateBackdrop("Default")
	button.backdrop:SetBackdropColor(0, 0, 0, 0)
	button.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
	button:StyleButton()

	if icon then
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetParent(button.backdrop)
		button.backdrop:SetOutside(icon, 1, 1)

		local rim = CreateFrame("Frame", nil, button.backdrop)
		rim:SetAllPoints(icon)
		rim:SetFrameLevel(button.backdrop:GetFrameLevel() + 10)
		rim:SetBackdrop({edgeFile = E.media.blankTex, edgeSize = 6})
		rim:SetBackdropBorderColor(unpack(E.media.bordercolor))

		button:SetFrameLevel(rim:GetFrameLevel() + 1)
	end

	if hotkey then
		hotkey:ClearAllPoints()
		hotkey:Point("TOPRIGHT", -8, -8)
		hotkey:FontTemplate(LSM:Fetch("font", E.db.actionbar.font), E.db.actionbar.fontSize, E.db.actionbar.fontOutline)
		hotkey:SetTextColor(1, 1, 1)

		UpdateHotkeyText(button)
		CoA:RegisterEvent("UPDATE_BINDINGS", function() UpdateHotkeyText(button) end)
	end

	if macroText then
		macroText:ClearAllPoints()
		macroText:Point("BOTTOM", 0, 1)
		macroText:FontTemplate()
	end

	if count then
		count:ClearAllPoints()
		count:Point("BOTTOMRIGHT", 0, 2)
		count:FontTemplate()
	end

	if cooldown then
		cooldown.CooldownOverride = "actionbar"
		E:RegisterCooldown(cooldown)
	end

	SkinGlow(button, name)
end

local function SetupMover(container, button)
	if CoA.extraActionBarMoverCreated then return end

	local width, height = button:GetSize()
	if width == 0 or height == 0 then return end

	local left, bottom = button:GetLeft(), button:GetBottom()
	if not left or not bottom then return end

	CoA.extraActionBarMoverCreated = true

	container:StripTextures(true)
	container:EnableMouse(false)

	local holder = CreateFrame("Frame", "CoA_ExtraActionBarHolder", E.UIParent)
	holder:Size(width, height)
	holder:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", left, bottom)

	E:CreateMover(holder, "CoA_ExtraActionBarMover", "Extra Action Bar", nil, nil, nil, "ALL,ACTIONBARS", nil, "CoA,skin,extraActionBar")
	holder:SetAllPoints(_G["CoA_ExtraActionBarMover"])

	local function Anchor()
		container:ClearAllPoints()
		container:SetPoint("CENTER", holder, "CENTER")
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

local function TryHook()
	local container = _G[CONTAINER_NAME]
	local button = _G[BUTTON_NAME]

	if container and button then
		SetupMover(container, button)
		SkinButton(button, container)
	end

	return container ~= nil and button ~= nil
end

function CoA:InitializeExtraActionBar()
	if TryHook() then return end

	self.extraActionBarTimer = self:ScheduleRepeatingTimer(function()
		if TryHook() then
			self:CancelTimer(self.extraActionBarTimer)
			self.extraActionBarTimer = nil
		end
	end, 0.5)
end
