local E, L, V, P, G = unpack(ElvUI)
local EP = E.Libs.EP
local ACH = LibStub("LibAceConfigHelper")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local AddOnName = ...

BINDING_HEADER_COA = "Conquest of Azeroth"

-- TODO: hook up server restart frame (RestartTimerFrame)

local CoA = E:NewModule("CoA", "AceEvent-3.0", "AceTimer-3.0")
E.CoA = CoA

local defaults = {
	profile = {
		skins = {
			extraActionButton = true,
			instanceSwap = true,
		},
		extraActionButtonSize = 52,
		instanceButtonFont = "PT Sans Narrow",
		instanceButtonFontSize = 12,
		instanceButtonFontOutline = "OUTLINE",
		dispelHighlightOnlyMine = false,
		hasBlightAntidote = false,
		hasDevourCurse = false,
		hasBurnImpurities = false,
		hideResourceSegmentBar = false,
		hideResourceOrb = false,
		hideResourceBar = false,
		hideMultiCastActionBar = false,
	},
}

function CoA:RefreshConfig()
	if self.UpdateExtraActionButtonSize then self:UpdateExtraActionButtonSize() end
	if self.UpdateInstanceButtonFont then self:UpdateInstanceButtonFont() end
	if self.UpdateDispelHighlight then self:UpdateDispelHighlight() end
	if self.UpdateClassResourceVisibility then self:UpdateClassResourceVisibility() end
end

CoA:RegisterEvent("ADDON_LOADED", function(_, addon)
	if addon ~= AddOnName then return end
	CoA:UnregisterEvent("ADDON_LOADED")

	CoA.db = AceDB:New("ElvUI_CoADB", defaults)

	-- One-time migration: earlier versions pinned every character to a single
	-- shared "Default" profile. Move each character to its own name-based
	-- profile (copying over the settings it already had) the first time it logs in.
	if not CoA.db.char.migratedSharedProfile then
		local charProfile = CoA.db.keys.char

		if CoA.db:GetCurrentProfile() == "Default" and charProfile ~= "Default" then
			CoA.db:SetProfile(charProfile)
			CoA.db:CopyProfile("Default", true)
		end

		CoA.db.char.migratedSharedProfile = true
	end

	CoA.db.RegisterCallback(CoA, "OnProfileChanged", "RefreshConfig")
	CoA.db.RegisterCallback(CoA, "OnProfileCopied", "RefreshConfig")
	CoA.db.RegisterCallback(CoA, "OnProfileReset", "RefreshConfig")
end)

local function getOptions()
	local profiles = AceDBOptions:GetOptionsTable(CoA.db)
	profiles.order = 5

	local options = {
		order = 55,
		type = "group",
		childGroups = "tab",
		name = string.format("|cff1784d1%s|r", "Conquest of Azeroth"),
		args = {
			-- Frame skins live under their own tab, laid out as a vertical tree
			-- rather than more horizontal tabs: one entry per skinned frame, and
			-- there are a lot more of those coming.
			skins = {
				order = 1,
				type = "group",
				childGroups = "tree",
				name = "Skins",
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
							-- Skinning is one-way: the native art is stripped and
							-- replaced in place, so turning a skin off can only take
							-- effect on the next load. Hence the reload prompt.
							enable = {
								order = 2,
								type = "toggle",
								name = "Enable",
								desc = "Skin the Extra Action Button. Requires a UI reload.",
								get = function() return CoA.db.profile.skins.extraActionButton end,
								set = function(_, value)
									CoA.db.profile.skins.extraActionButton = value
									E:StaticPopup_Show("CONFIG_RL")
								end,
							},
							desc = {
								order = 3,
								type = "description",
								name = "You can move this element with Toggle Anchors.\n",
							},
							size = {
								order = 4,
								disabled = function() return not CoA.db.profile.skins.extraActionButton end,
								type = "range",
								name = "Size",
								desc = "Adjust the width/height of the Extra Action Button, in pixels.",
								min = 30,
								max = 100,
								step = 1,
								get = function() return CoA.db.profile.extraActionButtonSize end,
								set = function(_, value)
									CoA.db.profile.extraActionButtonSize = value

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
							enable = {
								order = 2,
								type = "toggle",
								name = "Enable",
								desc = "Skin the Instance Swap button. Requires a UI reload.",
								get = function() return CoA.db.profile.skins.instanceSwap end,
								set = function(_, value)
									CoA.db.profile.skins.instanceSwap = value
									E:StaticPopup_Show("CONFIG_RL")
								end,
							},
							desc = {
								order = 3,
								type = "description",
								name = "You can move this element with Toggle Anchors.\n",
							},
							instanceFont = {
								order = 4,
								disabled = function() return not CoA.db.profile.skins.instanceSwap end,
								type = "group",
								inline = true,
								name = "Instance Font",
								args = {
									font = ACH:SharedMediaFont("Font", nil, 1, nil,
										function() return CoA.db.profile.instanceButtonFont end,
										function(_, value)
											CoA.db.profile.instanceButtonFont = value

											if CoA.UpdateInstanceButtonFont then
												CoA:UpdateInstanceButtonFont()
											end
										end),
									fontSize = {
										order = 2,
										type = "range",
										name = "Font Size",
										min = 8,
										max = 32,
										step = 1,
										get = function() return CoA.db.profile.instanceButtonFontSize end,
										set = function(_, value)
											CoA.db.profile.instanceButtonFontSize = value

											if CoA.UpdateInstanceButtonFont then
												CoA:UpdateInstanceButtonFont()
											end
										end,
									},
									fontOutline = ACH:FontFlags("Font Outline", nil, 3, nil,
										function() return CoA.db.profile.instanceButtonFontOutline end,
										function(_, value)
											CoA.db.profile.instanceButtonFontOutline = value

											if CoA.UpdateInstanceButtonFont then
												CoA:UpdateInstanceButtonFont()
											end
										end),
								},
							},
						},
					},
				},
			},
			classResources = {
				order = 2,
				type = "group",
				name = "Class Resources",
				args = {
					header = {
						order = 1,
						type = "header",
						name = "Class Resources",
					},
					desc = {
						order = 2,
						type = "description",
						name = "You can move these elements with Toggle Anchors.\n",
					},
					hideResourceSegmentBar = {
						order = 3,
						type = "toggle",
						name = "Hide CoAResourceSegmentBar",
						width = "full",
						get = function() return CoA.db.profile.hideResourceSegmentBar end,
						set = function(_, value)
							CoA.db.profile.hideResourceSegmentBar = value

							if CoA.UpdateClassResourceVisibility then
								CoA:UpdateClassResourceVisibility()
							end
						end,
					},
					hideResourceOrb = {
						order = 4,
						type = "toggle",
						name = "Hide CoAResourceOrb",
						width = "full",
						get = function() return CoA.db.profile.hideResourceOrb end,
						set = function(_, value)
							CoA.db.profile.hideResourceOrb = value

							if CoA.UpdateClassResourceVisibility then
								CoA:UpdateClassResourceVisibility()
							end
						end,
					},
					hideResourceBar = {
						order = 5,
						type = "toggle",
						name = "Hide CoAResourceBar",
						width = "full",
						get = function() return CoA.db.profile.hideResourceBar end,
						set = function(_, value)
							CoA.db.profile.hideResourceBar = value

							if CoA.UpdateClassResourceVisibility then
								CoA:UpdateClassResourceVisibility()
							end
						end,
					},
					hideMultiCastActionBar = {
						order = 6,
						type = "toggle",
						name = "Hide CoAMultiCastActionBarFrame",
						width = "full",
						get = function() return CoA.db.profile.hideMultiCastActionBar end,
						set = function(_, value)
							CoA.db.profile.hideMultiCastActionBar = value

							if CoA.UpdateClassResourceVisibility then
								CoA:UpdateClassResourceVisibility()
							end
						end,
					},
					hideAll = {
						order = 7,
						type = "execute",
						name = "Hide All",
						func = function()
							CoA.db.profile.hideResourceSegmentBar = true
							CoA.db.profile.hideResourceOrb = true
							CoA.db.profile.hideResourceBar = true
							CoA.db.profile.hideMultiCastActionBar = true

							if CoA.UpdateClassResourceVisibility then
								CoA:UpdateClassResourceVisibility()
							end
						end,
					},
					showAll = {
						order = 8,
						type = "execute",
						name = "Show All",
						func = function()
							CoA.db.profile.hideResourceSegmentBar = false
							CoA.db.profile.hideResourceOrb = false
							CoA.db.profile.hideResourceBar = false
							CoA.db.profile.hideMultiCastActionBar = false

							if CoA.UpdateClassResourceVisibility then
								CoA:UpdateClassResourceVisibility()
							end
						end,
					},
				},
			},
			dispelHighlight = {
				order = 3,
				type = "group",
				name = "Debuff Highlighting",
				args = {
					header = {
						order = 1,
						type = "header",
						name = "Debuff Highlighting",
					},
					onlyMine = {
						order = 2,
						type = "toggle",
						name = "Only Highlight If Dispellable By Me",
						desc = "Suppress the debuff highlight on unitframes for debuff types your class cannot dispel.",
						get = function() return CoA.db.profile.dispelHighlightOnlyMine end,
						set = function(_, value)
							CoA.db.profile.dispelHighlightOnlyMine = value

							if CoA.UpdateDispelHighlight then
								CoA:UpdateDispelHighlight()
							end
						end,
					},
					talents = {
						order = 3,
						type = "group",
						inline = true,
						name = "Talents",
						args = {
							hasBlightAntidote = {
								order = 1,
								type = "toggle",
								name = string.format("Blight Antidote (%s)", LOCALIZED_CLASS_NAMES_MALE.PROPHET),
								desc = "Grants Curse dispel.",
								get = function() return CoA.db.profile.hasBlightAntidote end,
								set = function(_, value)
									CoA.db.profile.hasBlightAntidote = value

									if CoA.UpdateDispelHighlight then
										CoA:UpdateDispelHighlight()
									end
								end,
							},
							hasDevourCurse = {
								order = 2,
								type = "toggle",
								name = string.format("Devour Curse (%s)", LOCALIZED_CLASS_NAMES_MALE.CULTIST),
								desc = "Grants Curse dispel.",
								get = function() return CoA.db.profile.hasDevourCurse end,
								set = function(_, value)
									CoA.db.profile.hasDevourCurse = value

									if CoA.UpdateDispelHighlight then
										CoA:UpdateDispelHighlight()
									end
								end,
							},
							hasBurnImpurities = {
								order = 3,
								type = "toggle",
								name = string.format("Burn Impurities (%s)", LOCALIZED_CLASS_NAMES_MALE.PYROMANCER),
								desc = "Grants Magic, Disease, and Bleed dispel.",
								get = function() return CoA.db.profile.hasBurnImpurities end,
								set = function(_, value)
									CoA.db.profile.hasBurnImpurities = value

									if CoA.UpdateDispelHighlight then
										CoA:UpdateDispelHighlight()
									end
								end,
							},
						},
					},
				},
			},
			profiles = profiles,
		},
	}

	E.Options.args.CoA = options
end

local function RegisterMoverCategory()
	for _, layout in ipairs(E.ConfigModeLayouts) do
		if layout == "COA" then return end
	end

	tinsert(E.ConfigModeLayouts, "COA")
	E.ConfigModeLocalizedStrings.COA = "CoA"
end

function CoA:Initialize()
	RegisterMoverCategory()

	EP:RegisterPlugin(AddOnName, getOptions)

	-- ADDON_LOADED normally beats module init, but fall back to the defaults
	-- rather than error out if a skin gets initialized before the DB exists.
	local skins = self.db and self.db.profile.skins or defaults.profile.skins

	if self.InitializeExtraActionBar and skins.extraActionButton then
		self:InitializeExtraActionBar()
	end

	if self.InitializeLayerPicker and skins.instanceSwap then
		self:InitializeLayerPicker()
	end

	if self.InitializeDispelHighlight then
		self:InitializeDispelHighlight()
	end

	if self.InitializeClassResources then
		self:InitializeClassResources()
	end

	if self.InitializeTalentFrame then
		self:InitializeTalentFrame()
	end

	if self.InitializeVanityFrame then
		self:InitializeVanityFrame()
	end

	if self.InitializeWardrobeFrame then
		self:InitializeWardrobeFrame()
	end
end

local function InitializeCallback()
	CoA:Initialize()
end

E:RegisterModule(CoA:GetName(), InitializeCallback)
