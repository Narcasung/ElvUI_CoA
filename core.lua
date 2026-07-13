local E, L, V, P, G = unpack(ElvUI)
local EP = E.Libs.EP
local ACH = LibStub("LibAceConfigHelper")

local AddOnName = ...

BINDING_HEADER_COA = "Conquest of Azeroth"

local CoA = E:NewModule("CoA", "AceEvent-3.0", "AceTimer-3.0")
E.CoA = CoA

V.CoA = {}

G.CoA = {
	extraActionButtonSize = 52,
	instanceButtonFont = "PT Sans Narrow",
	instanceButtonFontSize = 12,
	instanceButtonFontOutline = "OUTLINE",
}

local function getOptions()
	local options = {
		order = 55,
		type = "group",
		childGroups = "tab",
		name = string.format("|cff1784d1%s|r", "Conquest of Azeroth"),
		args = {
			extraActionButton = {
				order = 1,
				type = "group",
				name = "Extra Action Button",
				args = {
					header = {
						order = 1,
						type = "header",
						name = "Extra Action Button",
					},
					size = {
						order = 2,
						type = "range",
						name = "Size",
						desc = "Adjust the width/height of the Extra Action Button, in pixels.",
						min = 30,
						max = 100,
						step = 1,
						get = function() return E.global.CoA.extraActionButtonSize end,
						set = function(_, value)
							E.global.CoA.extraActionButtonSize = value

							if CoA.UpdateExtraActionButtonSize then
								CoA:UpdateExtraActionButtonSize()
							end
						end,
					},
				},
			},
			instanceSwap = {
				order = 2,
				type = "group",
				name = "Instance Swap",
				args = {
					header = {
						order = 1,
						type = "header",
						name = "Instance Swap",
					},
					font = ACH:SharedMediaFont("Font", nil, 2, nil,
						function() return E.global.CoA.instanceButtonFont end,
						function(_, value)
							E.global.CoA.instanceButtonFont = value

							if CoA.UpdateInstanceButtonFont then
								CoA:UpdateInstanceButtonFont()
							end
						end),
					fontSize = {
						order = 3,
						type = "range",
						name = "Font Size",
						min = 8,
						max = 32,
						step = 1,
						get = function() return E.global.CoA.instanceButtonFontSize end,
						set = function(_, value)
							E.global.CoA.instanceButtonFontSize = value

							if CoA.UpdateInstanceButtonFont then
								CoA:UpdateInstanceButtonFont()
							end
						end,
					},
					fontOutline = ACH:FontFlags("Font Outline", nil, 4, nil,
						function() return E.global.CoA.instanceButtonFontOutline end,
						function(_, value)
							E.global.CoA.instanceButtonFontOutline = value

							if CoA.UpdateInstanceButtonFont then
								CoA:UpdateInstanceButtonFont()
							end
						end),
				},
			},
		},
	}

	E.Options.args.CoA = options
end

function CoA:Initialize()
	EP:RegisterPlugin(AddOnName, getOptions)

	if self.InitializeExtraActionBar then
		self:InitializeExtraActionBar()
	end

	if self.InitializeLayerPicker then
		self:InitializeLayerPicker()
	end
end

local function InitializeCallback()
	CoA:Initialize()
end

E:RegisterModule(CoA:GetName(), InitializeCallback)
