local E, L, V, P, G = unpack(ElvUI)
local EP = E.Libs.EP

local AddOnName = ...

BINDING_HEADER_COA = "Conquest of Azeroth"

local CoA = E:NewModule("CoA", "AceEvent-3.0", "AceTimer-3.0")
E.CoA = CoA

V.CoA = {}

P.CoA = {
	extraActionButtonSize = 52,
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
						get = function() return E.db.CoA.extraActionButtonSize end,
						set = function(_, value)
							E.db.CoA.extraActionButtonSize = value

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
