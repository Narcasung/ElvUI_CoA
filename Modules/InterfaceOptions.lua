local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")

local _G = _G
local ipairs, pairs, select, type = ipairs, pairs, select, type

-- Generic sweep over the stock options windows.
--
-- ElvUI skins those windows from four hardcoded name lists (checkboxes,
-- sliders, buttons, dropdowns) in Modules/Skins/Blizzard/BlizzardOptions.lua,
-- so anything the client added since upstream last synced stays native --
-- 53 widgets on this server, 39 of them in four panels upstream never
-- enumerated at all (Battlenet, RaidEffects, Stereo, Voice). Rather than
-- carry a parallel name list that goes stale the same way, this walks the
-- panel containers and skins by object type.

local MAX_DEPTH = 3

-- Every panel is parented at load (probed: the Interface container reports the
-- same child count before and after opening the window), so the containers can
-- be walked without waiting for a category to be displayed.
local ROOTS = {
	"InterfaceOptionsFramePanelContainer",
	"VideoOptionsFramePanelContainer",
	"AudioOptionsFramePanelContainer",
}

-- Hooked on all three windows rather than only the Interface one: the Video and
-- Audio windows are separate frames reachable straight from the game menu, and
-- a player who opens one of those first would otherwise see it unskinned. Each
-- show sweeps every root, which costs nothing -- the pass is idempotent.
local TRIGGERS = {
	"InterfaceOptionsFrame",
	"VideoOptionsFrame",
	"AudioOptionsFrame",
}

-- Panels owned by other addons, keyed by frame. Rebuilt on every sweep rather
-- than cached at init: load-on-demand addons register their category late, and
-- a set built once would let their panels through on later shows.
local addonPanels = {}

local function RebuildAddOnPanels()
	for panel in pairs(addonPanels) do
		addonPanels[panel] = nil
	end

	local categories = _G.INTERFACEOPTIONS_ADDONCATEGORIES
	if type(categories) ~= "table" then return end

	-- The entries are the panel frames themselves, not descriptors (probed).
	-- Matching on the frame is why this doesn't need a name prefix whitelist:
	-- an addon can name its panel anything, and the registry is authoritative.
	for _, panel in ipairs(categories) do
		if type(panel) == "table" then
			addonPanels[panel] = true
		end
	end
end

-- Structural test, not a name test. S:HandleDropDownBox uses _G[name.."Button"]
-- unguarded when anchoring its backdrop, so a false positive is a Lua error
-- rather than a cosmetic miss; it also force-sets the frame's width, which
-- mangles a group box even when it doesn't error. A DropDown name suffix was
-- considered and rejected -- ElvUI's own dropdown list carries
-- CompactUnitFrameProfilesProfileSelector (no suffix) and ...SortByDropdown
-- (lowercase d), so suffix matching misses real dropdowns and adds nothing.
local function IsDropDown(frame)
	local name = frame.GetName and frame:GetName()
	if not name then return false end

	local middle = _G[name.."Middle"]
	if not middle or not middle.IsObjectType or not middle:IsObjectType("Texture") then return false end

	return _G[name.."Button"] ~= nil
end

-- depth is the depth of the children being visited, counting the container's
-- own children as 1. Three is enough for the deepest real case: the Controls
-- panel's anonymous "Looting Options" group box and the compact raid frame
-- profile dialogs both hold their widgets a level below the panel.
local function Sweep(frame, depth)
	for i = 1, frame:GetNumChildren() do
		local child = select(i, frame:GetChildren())

		if child and not addonPanels[child] then
			local objectType = child:GetObjectType()

			if objectType == "CheckButton" then
				S:HandleCheckBox(child)
			elseif objectType == "Slider" then
				-- The gate is load-bearing, not an optimisation:
				-- HandleSliderFrame has no idempotence guard of its own and
				-- HookScript stacks, so a second pass over a slider ElvUI
				-- already skinned would run its OnDisable/OnEnable handlers
				-- twice. E:SetTemplate sets frame.template, so that field is
				-- the "already skinned" marker for sliders.
				if not child.template then
					S:HandleSliderFrame(child)
				end
			elseif objectType == "Frame" and IsDropDown(child) then
				S:HandleDropDownBox(child)
			elseif depth < MAX_DEPTH then
				-- Deliberately no Button branch: nothing in the sweep needs one,
				-- and it would flatten other addons' panel tabs -- object type
				-- Button, but tabs -- into ElvUI pill buttons.
				Sweep(child, depth + 1)
			end
		end
	end
end

local function SweepOptions()
	RebuildAddOnPanels()

	for _, name in ipairs(ROOTS) do
		local root = _G[name]

		if root then
			Sweep(root, 1)
		end
	end
end

function CoA:InitializeInterfaceOptions()
	-- The same two switches that gate ElvUI's own pass: if the user turned the
	-- stock options skin off, the gap this fills isn't a gap any more.
	if not E.private.skins.blizzard.enable then return end
	if not E.private.skins.blizzard.BlizzardOptions then return end

	-- Skinning on show rather than at init puts the sweep after ElvUI's
	-- Skin_BlizzardOptions callback with no ordering work, and re-running it on
	-- every show catches panels that only appear once their addon loads.
	for _, name in ipairs(TRIGGERS) do
		local frame = _G[name]

		if frame then
			frame:HookScript("OnShow", SweepOptions)
		end
	end
end
