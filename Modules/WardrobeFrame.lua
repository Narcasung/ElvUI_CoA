local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")
local Skin = CoA.Skin

local FRAME_NAME = "AppearanceWardrobeFrame"

-- Standard UIPanelButtonTemplate art, same as Vanity's action buttons --
-- S:HandleButton's own texture clearing handles these directly.
local function SkinActionButtons()
	Skin:Button(_G[FRAME_NAME.."PlayerModelSaveOutfitButton"])
	Skin:Button(_G[FRAME_NAME.."DisableTransmogButton"])
	Skin:Button(_G[FRAME_NAME.."DisableSpellVisualsButton"])
end

-- Apply and Cancel only exist while a transmog change is pending, which is why
-- they were missed for so long -- but they exist from the start rather than
-- being created on the first change (probed: both are Buttons, hidden, with
-- nothing pending), so the normal skin pass reaches them.
--
-- Same widget as the talent frame's Activate button: the pill is drawn across
-- plain regions, with no Normal/Pushed texture for HandleButton to clear
-- (probed: both come back nil). Apply takes the green variant of the gold
-- atlas, Cancel is drawn from the red file instead -- Skin.RedButtonArt matches
-- both, and Cancel's HIGHLIGHT region goes with the rest of its art.
--
-- The labels don't carry the atlas's green/red split over: the two buttons sit
-- side by side and read apart by their text, and they take the same yellow
-- every other templated button on these frames uses -- the talent frame's live
-- Activate label included -- so a pending change doesn't get its own colour
-- scheme.
local LABEL_COLOR = {1, 0.82, 0}

-- The strip runs on every pass rather than once behind the skinned guard: the
-- art is only there to be cleared once a change is pending, and nothing fires
-- the frame's OnShow at that point -- the window is already open. The buttons'
-- own OnShow is what catches it, since that is exactly when they appear.
local function SkinPendingButton(name)
	local button = _G[name]
	if not button then return end

	Skin:StripArtByFile(button, Skin.RedButtonArt)

	if button.CoASkinned then return end
	button.CoASkinned = true

	-- Stripped before templating: HandleButton adds its backdrop as regions of
	-- this same button, so a strip afterwards takes the backdrop with the pill.
	Skin:Button(button)

	local text = button.GetFontString and button:GetFontString()
	if text then text:SetTextColor(unpack(LABEL_COLOR)) end

	button:HookScript("OnShow", function(self)
		Skin:StripArtByFile(self, Skin.RedButtonArt)
	end)
end

local function SkinPendingButtons()
	SkinPendingButton(FRAME_NAME.."PlayerModelApplyButton")
	SkinPendingButton(FRAME_NAME.."PlayerModelCancelButton")
end

local function SkinSearchBox()
	S:HandleEditBox(_G[FRAME_NAME.."CollectionSearchBox"])
end

-- suffix is "Filter" or "Sorting" -- both are CollectionX buttons with a
-- matching CollectionXMenu popout (confirmed by probe), and both are the same
-- widget as the vanity frame's single dropdown, so both go through the shared
-- handler.
local function SkinCollectionDropdown(suffix)
	Skin:Dropdown(_G[FRAME_NAME.."Collection"..suffix], _G[FRAME_NAME.."Collection"..suffix.."Menu"])
end

local function SkinPagerArrows()
	local prevButton = _G[FRAME_NAME.."CollectionPageLeftButton"]
	local nextButton = _G[FRAME_NAME.."CollectionPageRightButton"]

	if prevButton then S:HandleNextPrevButton(prevButton, "left") end
	if nextButton then S:HandleNextPrevButton(nextButton, "right") end
end

-- Same art naming as the talent frame's tabs (confirmed by probe), so they go
-- through the same shared handler. No level parent is passed: these are proper
-- descendants of Collection rather than separately-placed siblings, so normal
-- parent/child z-order already puts them above the panel and the frame-level
-- bump the talent tabs need doesn't apply.
--
-- Named PoolFrameAppearanceTypeTabTemplate1 through 8 (confirmed by probe),
-- not pooled/created dynamically like the talent frame's spec choices, so a
-- plain indexed loop is enough -- no OnShow hook needed to catch late pool
-- fills.
local TAB_COUNT = 8

local function SkinCategoryTabs()
	for i = 1, TAB_COUNT do
		Skin:Tab(_G[FRAME_NAME.."CollectionPoolFrameAppearanceTypeTabTemplate"..i])
	end
end

local function SkinContents()
	-- Scale is set on the shared container while this window is the open one,
	-- which carries the tab row along with it (see Skinning.lua).
	Skin:ApplyWindowScale("wardrobeScale")
	Skin:CollectionTabs(_G[FRAME_NAME])
	Skin:Title(_G[FRAME_NAME.."TitleText"])
	Skin:CloseButton(_G[FRAME_NAME.."CloseButton"])
	SkinActionButtons()
	SkinPendingButtons()
	SkinSearchBox()
	SkinCollectionDropdown("Filter")
	SkinCollectionDropdown("Sorting")
	SkinPagerArrows()
	SkinCategoryTabs()
end

local function SkinFrame(frame)
	if not frame.CoASkinned then
		frame.CoASkinned = true

		-- The native NineSlice panel draws its own ornate border/background on
		-- top of the Transparent template's border, doubling up. Same fix as
		-- the talent frame: strip and hide it.
		Skin:HideArt(_G[FRAME_NAME.."NineSlice"])

		-- The round medallion overhangs the top-left corner (confirmed by
		-- probe: 61x61, TOPLEFT -6,8 -- matches the frame's own corner, not a
		-- counter badge elsewhere, unlike Vanity's same-named "Portrait2"
		-- texture). No flat equivalent, so it goes rather than getting
		-- reskinned, same treatment as the talent frame's portrait.
		Skin:HideArt(_G[FRAME_NAME.."PortraitFrame"])

		-- The frame's own regions (confirmed by probe: 4 total, all BACKGROUND/
		-- BORDER/OVERLAY textures, none of them functional -- unlike Vanity's
		-- frame, nothing here doubles as a counter badge) are the wood-panel
		-- background art, so this one is safe to strip before templating.
		Skin:Panel(frame)

		-- InsetOverlay's NineSlice and the ShadowOverlay are separate decorative
		-- art layered over the item grid area (8-piece atlas borders/shadow
		-- edges, confirmed via probe), stripped outright -- no functional
		-- content lives on either.
		Skin:HideArt(_G[FRAME_NAME.."CollectionInsetOverlayNineSlice"])

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
		Skin:Panel(_G[FRAME_NAME.."Collection"])

		-- The 3D model preview's vanilla border is an anonymous child (first
		-- of PlayerModel's own, confirmed by probe: 8-piece "UIFrame" atlas
		-- border, sized to match the model panel). No name to key off of, same
		-- as Vanity's pager arrows -- picked out positionally instead. The
		-- race-specific scenic backdrop texture is PlayerModel's own region,
		-- not this child's, so it's untouched.
		local playerModel = _G[FRAME_NAME.."PlayerModel"]
		local modelBorder = playerModel and select(1, playerModel:GetChildren())
		if modelBorder and modelBorder:GetObjectType() == "Frame" then
			Skin:HideArt(modelBorder)
		end

		Skin:HideArt(_G[FRAME_NAME.."CollectionShadowOverlay"])

		frame:HookScript("OnShow", SkinContents)
	end

	SkinContents()
end

local function TryHook()
	local frame = _G[FRAME_NAME]
	if not frame then return false end

	SkinFrame(frame)

	return true
end

function CoA:InitializeWardrobeFrame()
	if not E.private.skins.blizzard.enable then return end

	Skin:OnFrameAvailable(TryHook)
end
