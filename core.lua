local E, L, V, P, G = unpack(ElvUI)
local EP = E.Libs.EP

local AddOnName = ...

local CoA = E:NewModule("CoA", "AceEvent-3.0", "AceTimer-3.0")
E.CoA = CoA

V.CoA = {}

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
				args = {},
			},
			instanceSwap = {
				order = 2,
				type = "group",
				name = "Instance Swap",
				args = {},
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
