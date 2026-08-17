local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")

local FRAME_NAME = "AppearanceWardrobeFrame"

local function SkinCloseButton(frame)
	local close = _G[FRAME_NAME.."CloseButton"]
	if not close then return end

	-- Strictly once: HandleCloseButton strips the button every call, which
	-- blanks the X texture it added on the first pass.
	if not close.CoASkinned then
		close.CoASkinned = true

		S:HandleCloseButton(close)
	end
end

-- Standard UIPanelButtonTemplate art, same as Vanity's action buttons --
-- S:HandleButton's own texture clearing handles these directly.
local function SkinActionButtons()
	S:HandleButton(_G[FRAME_NAME.."PlayerModelSaveOutfitButton"])
	S:HandleButton(_G[FRAME_NAME.."DisableTransmogButton"])
	S:HandleButton(_G[FRAME_NAME.."DisableSpellVisualsButton"])
end

local function SkinSearchBox()
	S:HandleEditBox(_G[FRAME_NAME.."CollectionSearchBox"])
end

-- Filter and Order By share Vanity's exact dropdown art -- same nine
-- anonymous "Silver-Button" slices, confirmed by probe, that S:HandleButton
-- can't reach on its own, plus the same native mouse-down re-art problem on
-- click (SetTexture noop'd per region after clearing, same trick).
local DROPDOWN_ART_PATTERNS = {"Silver%-Button"}

local function StripDropdownArt(dropdown)
	for i = 1, dropdown:GetNumRegions() do
		local region = select(i, dropdown:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture then
			for _, pattern in ipairs(DROPDOWN_ART_PATTERNS) do
				if tostring(texture):find(pattern) then
					region:SetTexture(nil)
					region.SetTexture = E.noop
					break
				end
			end
		end
	end
end

-- suffix is "Filter" or "Sorting" -- both are CollectionX buttons with a
-- matching CollectionXMenu popout (confirmed by probe), same shape as
-- Vanity's single dropdown.
local function SkinCollectionDropdown(suffix)
	local dropdown = _G[FRAME_NAME.."Collection"..suffix]
	if not dropdown or dropdown.CoASkinned then return end
	dropdown.CoASkinned = true

	StripDropdownArt(dropdown)

	S:HandleButton(dropdown)

	-- The caret is a plain OVERLAY texture on the dropdown itself, not a
	-- separate button, so it can't go through HandleNextPrevButton -- it's
	-- retextured directly instead.
	for i = 1, dropdown:GetNumRegions() do
		local region = select(i, dropdown:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and tostring(texture):find("ChatFrameExpandArrow") then
			-- No ArrowDown asset exists -- every other direction in ElvUI is
			-- ArrowUp rotated, so this matches that convention.
			region:SetTexture(E.Media.Textures.ArrowUp)
			region:SetVertexColor(1, 1, 1)
			region:SetTexCoord(0, 1, 0, 1)
			region:SetRotation(S.ArrowRotation.down)
			region:SetSize(14, 14)
		end
	end

	local menu = _G[FRAME_NAME.."Collection"..suffix.."Menu"]
	if menu and not menu.CoASkinned then
		menu.CoASkinned = true

		-- Panel only, matching how Vanity's own popup menu is treated -- the
		-- option rows inside are a later pass.
		menu:StripTextures()
		menu:SetTemplate("Transparent")
	end
end

local function SkinPagerArrows()
	local prevButton = _G[FRAME_NAME.."CollectionPageLeftButton"]
	local nextButton = _G[FRAME_NAME.."CollectionPageRightButton"]

	if prevButton then S:HandleNextPrevButton(prevButton, "left") end
	if nextButton then S:HandleNextPrevButton(nextButton, "right") end
end

-- Same Left/Center/Right art naming as the talent frame's tabs (confirmed by
-- probe), but these are proper descendants of Collection rather than
-- separately-placed siblings, so the frame-level bump Talent needs to clear
-- its own frame's regions doesn't apply here -- normal parent/child z-order
-- already puts them on top.
local TAB_TEXTURES = {"Left", "Center", "Right"}

local function StripTab(tab)
	local name = tab:GetName()
	if name then
		for _, suffix in ipairs(TAB_TEXTURES) do
			local tex = _G[name..suffix]
			if tex then tex:SetTexture(nil) end
		end
	end

	local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if highlight then highlight:SetTexture(nil) end

	local checked = tab.GetCheckedTexture and tab:GetCheckedTexture()
	if checked then checked:SetTexture(nil) end
end

-- Only the tab being switched to gets any kind of hook fired -- the ones
-- switched away from never fire OnClick/OnShow/SetChecked again, but their
-- native art still comes back, so there's no event to catch it from. Same
-- fix as the talent frame's tabs: a cheap OnUpdate texture check, only pays
-- for the full strip when the native art has actually reappeared.
local function UpdateTabArt(tab)
	local name = tab:GetName()
	local tex = name and _G[name.."Left"]

	if tex and tex:GetTexture() then
		StripTab(tab)
	end
end

local function SkinTab(tab)
	if not tab.CoASkinned then
		tab.CoASkinned = true

		tab:CreateBackdrop("Default")
		tab.backdrop:Point("TOPLEFT", 2, -2)
		tab.backdrop:Point("BOTTOMRIGHT", -2, 2)

		tab:HookScript("OnUpdate", UpdateTabArt)
	end

	StripTab(tab)
end

-- Named PoolFrameAppearanceTypeTabTemplate1 through 8 (confirmed by probe),
-- not pooled/created dynamically like the talent frame's spec choices, so a
-- plain indexed loop is enough -- no OnShow hook needed to catch late pool
-- fills.
local TAB_COUNT = 8

local function SkinCategoryTabs()
	for i = 1, TAB_COUNT do
		local tab = _G[FRAME_NAME.."CollectionPoolFrameAppearanceTypeTabTemplate"..i]
		if tab then SkinTab(tab) end
	end
end

local function SkinFrame(frame)
	if not frame.CoASkinned then
		frame.CoASkinned = true

		-- The native NineSlice panel draws its own ornate border/background on
		-- top of the Transparent template's border, doubling up. Same fix as
		-- the talent frame: strip and hide it.
		local nineSlice = _G[FRAME_NAME.."NineSlice"]
		if nineSlice then
			nineSlice:StripTextures()
			nineSlice:Hide()
		end

		-- The round medallion overhangs the top-left corner (confirmed by
		-- probe: 61x61, TOPLEFT -6,8 -- matches the frame's own corner, not a
		-- counter badge elsewhere, unlike Vanity's same-named "Portrait2"
		-- texture). No flat equivalent, so it goes rather than getting
		-- reskinned, same treatment as the talent frame's portrait.
		local portrait = _G[FRAME_NAME.."PortraitFrame"]
		if portrait then
			portrait:StripTextures()
			portrait:Hide()
		end

		-- The frame's own regions (confirmed by probe: 4 total, all BACKGROUND/
		-- BORDER/OVERLAY textures, none of them functional -- unlike Vanity's
		-- frame, nothing here doubles as a counter badge) are the wood-panel
		-- background art. Strip it first, THEN apply the template -- SetTemplate
		-- adds its own backdrop as real texture regions on this same frame, so
		-- stripping afterward wiped the backdrop right back off (outer panel
		-- came out fully invisible).
		frame:StripTextures()
		frame:SetTemplate("Transparent")

		-- InsetOverlay's NineSlice and the ShadowOverlay are separate decorative
		-- art layered over the item grid area (8-piece atlas borders/shadow
		-- edges, confirmed via probe), stripped outright -- no functional
		-- content lives on either.
		local insetOverlayNineSlice = _G[FRAME_NAME.."CollectionInsetOverlayNineSlice"]
		if insetOverlayNineSlice then
			insetOverlayNineSlice:StripTextures()
			insetOverlayNineSlice:Hide()
		end

		-- The actual panel behind the grid: Collection itself (confirmed via
		-- /fstack -- InsetOverlay was the wrong target, its own rect doesn't
		-- match the visible panel). Collection is the grid's real parent, so
		-- no frame-level/strata juggling needed -- children always draw above
		-- their own parent.
		--
		-- 16 of its own regions turned out to hold real art -- a background
		-- tile plus ~14 atlas border/corner pieces (the ornate corners
		-- /fstack couldn't ever pick out, since loose regions aren't frames
		-- and don't show up there) -- none of it functional (the "Collected
		-- 50/2744" counter is a separate FontString region, untouched by
		-- StripTextures). Painting an opaque/red template over it earlier
		-- just masked it; it was still there underneath, which is why
		-- Transparent let it bleed back through. Strip first, then template,
		-- same order as the outer frame -- SetTemplate's own WHITE8X8 backdrop
		-- pieces land as regions on this same frame too, so stripping after
		-- would wipe them right back off.
		local collection = _G[FRAME_NAME.."Collection"]
		if collection then
			collection:StripTextures()
			collection:SetTemplate("Transparent")
		end

		-- The 3D model preview's vanilla border is an anonymous child (first
		-- of PlayerModel's own, confirmed by probe: 8-piece "UIFrame" atlas
		-- border, sized to match the model panel). No name to key off of, same
		-- as Vanity's pager arrows -- picked out positionally instead. The
		-- race-specific scenic backdrop texture is PlayerModel's own region,
		-- not this child's, so it's untouched.
		local playerModel = _G[FRAME_NAME.."PlayerModel"]
		local modelBorder = playerModel and select(1, playerModel:GetChildren())
		if modelBorder and modelBorder:GetObjectType() == "Frame" then
			modelBorder:StripTextures()
			modelBorder:Hide()
		end

		local shadowOverlay = _G[FRAME_NAME.."CollectionShadowOverlay"]
		if shadowOverlay then
			shadowOverlay:StripTextures()
			shadowOverlay:Hide()
		end

		frame:HookScript("OnShow", function(self)
			SkinCloseButton(self)
			SkinActionButtons()
			SkinSearchBox()
			SkinCollectionDropdown("Filter")
			SkinCollectionDropdown("Sorting")
			SkinPagerArrows()
			SkinCategoryTabs()
		end)
	end

	SkinCloseButton(frame)
	SkinActionButtons()
	SkinSearchBox()
	SkinCollectionDropdown("Filter")
	SkinCollectionDropdown("Sorting")
	SkinPagerArrows()
	SkinCategoryTabs()
end

local function TryHook()
	local frame = _G[FRAME_NAME]
	if not frame then return false end

	SkinFrame(frame)

	return true
end

function CoA:InitializeWardrobeFrame()
	if not E.private.skins.blizzard.enable then return end
	if TryHook() then return end

	-- Frame is created on-demand by its owning addon, the instant the player
	-- first opens it -- a poll can't catch that before native art gets a
	-- paint. ADDON_LOADED fires (synchronously, before control returns to
	-- whatever code calls :Show()) the moment that addon finishes loading, so
	-- skinning here lands before the first-ever :Show(). Confirmed in-game on
	-- the talent frame's identical pattern; see TalentFrame.lua.
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self)
		if TryHook() then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end
