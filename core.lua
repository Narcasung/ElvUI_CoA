local E, L, V, P, G = unpack(ElvUI)
local EP = E.Libs.EP

local AddOnName = ...

local CoA = E:NewModule("CoA", "AceEvent-3.0", "AceTimer-3.0")
E.CoA = CoA

V.CoA = {
	extraActionBar = true,
	instance = true,
}

local function getOptions()
	local options = {
		order = 55,
		type = "group",
		childGroups = "tab",
		name = string.format("|cff1784d1%s|r", "Conquest of Azeroth"),
		args = {
			skin = {
				order = 1,
				type = "group",
				name = "Skins",
				get = function(info) return E.private.CoA[info[#info]] end,
				set = function(info, value)
					E.private.CoA[info[#info]] = value
					E:StaticPopup_Show("PRIVATE_RL")
				end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = "Skins",
					},
					extraActionBar = {
						order = 2,
						type = "toggle",
						name = "Extra Action Bar",
						desc = "Skin the ExtraActionBar frame.",
					},
					instance = {
						order = 3,
						type = "toggle",
						name = "Instance",
						desc = "Skin the LayerPickerFrame button.",
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
