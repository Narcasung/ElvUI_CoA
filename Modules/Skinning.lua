local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")

-- Shared skinning helpers for the CoA frames (talent, vanity, wardrobe).
--
-- Those three are built from the same handful of widget templates, so every
-- element that appears in more than one of them lives here rather than being
-- copied per module. The copies had already drifted -- different backdrop
-- insets, different close button sizes, tabs grown in one frame and not the
-- other -- and the drift is exactly what reads as "the same control looks
-- different depending on which tab I'm on".
local Skin = {}
CoA.Skin = Skin

-- Every native close button on these frames is a different size (the vanity
-- store's is visibly larger than the talent frame's), and HandleCloseButton
-- keeps whatever size it's given -- it only centres a fixed 12px X inside the
-- box. Normalised here so the X lands on the same grid in all three, and the
-- click target is the same everywhere too.
local CLOSE_BUTTON_SIZE = 32

function Skin:CloseButton(close)
	if not close then return end

	-- Strictly once: HandleCloseButton strips the button on every call, which
	-- blanks the X texture it added on the first pass, and its own guard won't
	-- rebuild it because the field still points at that blanked texture.
	if not close.CoASkinned then
		close.CoASkinned = true

		S:HandleCloseButton(close)
	end

	close:Size(CLOSE_BUTTON_SIZE)
end

-- Scale is a per-frame setting rather than one shared number: the three frames
-- don't ship at the same scale (the vanity store's is about 9% larger than the
-- other two, measured), and that's the server's choice, so the slider is a
-- multiplier on whatever each frame was given rather than an absolute. A
-- setting of 1 therefore leaves every frame exactly as it came.
--
-- Scale is applied to Collections, the container all three windows and the tab
-- row are children of (confirmed by probe), rather than to a window itself.
-- Collections is also the only one of them with mouse enabled -- it's what the
-- player drags -- so scaling a window directly shrank the art while leaving the
-- drag target at full size, which is why a shrunk window had to be grabbed by
-- clicking outside itself. Scaling the container moves its hit area with it,
-- and the tabs come along as its children.
--
-- The setting is still per-window: only one of them is ever open, and each
-- re-applies its own on show. The native scale is captured before anything here
-- has written one, so re-applying can't compound.
local CONTAINER_NAME = "Collections"

local scaleKey

local function GetScaleSetting(key)
	local db = CoA.db and CoA.db.profile.skins.collections

	return (db and db[key]) or 1
end

function Skin:ApplyWindowScale(key)
	local container = _G[CONTAINER_NAME]
	if not container then return end

	if not container.CoANativeScale then
		container.CoANativeScale = container:GetScale()
	end

	-- Remembered so the slider can re-apply for whichever window is open.
	scaleKey = key

	local scale = container.CoANativeScale * GetScaleSetting(key)

	if container:GetScale() ~= scale then
		container:SetScale(scale)
	end
end

-- Live update from the slider: a window only re-runs its own skin pass on show,
-- and a scale change should land while one is open.
function CoA:UpdateFrameScales()
	if scaleKey then
		Skin:ApplyWindowScale(scaleKey)
	end
end

-- The talent and wardrobe frames title in Arial Narrow, the vanity store in
-- Friz Quadrata (measured live). Arial Narrow is the one that matches the rest
-- of the layout, so it's pinned here rather than left to the frames -- and
-- pinned by name through LSM rather than as a raw path, so it stays the same
-- asset ElvUI itself would resolve.
--
-- Size is written straight through, with no correction for the frames running
-- at different scales: the vanity store's is about 9% larger than the other
-- two (measured), so its title renders slightly bigger than theirs. Left as the
-- server has it for now.
--
-- FontTemplate stashes the font and size it was handed on the fontstring, so an
-- ElvUI font change later re-applies these rather than resetting them.
local TITLE_FONT = "Arial Narrow"
local TITLE_SIZE = 13

function Skin:Title(title)
	if not title then return end

	title:FontTemplate(E.Libs.LSM:Fetch("font", TITLE_FONT), TITLE_SIZE, "OUTLINE")
end

-- Strip first, THEN template: SetTemplate adds its own backdrop as texture
-- regions on this same frame, so stripping afterwards wipes it straight back
-- off -- which is how the wardrobe's outer panel once came out fully invisible.
--
-- keepTextures is for frames whose own regions aren't all decorative: the
-- vanity store draws its currency counters as regions of the frame itself, and
-- a blind strip blanks the counters along with the panel art.
function Skin:Panel(frame, keepTextures)
	if not frame or frame.CoAPanelSkinned then return end
	frame.CoAPanelSkinned = true

	if not keepTextures then
		frame:StripTextures()
	end

	frame:SetTemplate("Transparent")
end

-- Ornate art with no flat equivalent (portrait medallions, nine-slice borders,
-- shadow overlays): it goes rather than getting reskinned. Hidden as well as
-- stripped, since some of these put their own art back.
function Skin:HideArt(frame)
	if not frame then return end

	frame:StripTextures()
	frame:Hide()
end

-- Buttons ---------------------------------------------------------------------
--
-- IsEnabled hands back 0 and 1 on this client rather than false and true
-- (probed), and 0 is truthy in Lua, so every enabled check has to normalise
-- what it gets back before comparing it.
function Skin:IsEnabled(button)
	local state = button.IsEnabled and button:IsEnabled()

	return state ~= nil and state ~= false and state ~= 0
end

-- The target is resolved the way ElvUI's own SetModifiedBackdrop and
-- SetOriginalBackdrop resolve it -- the backdrop when the button has one, the
-- button itself otherwise -- or the colour lands on something that isn't the
-- object drawing the border.
local function SetButtonBorder(button, lit)
	local backdrop = button.backdrop or button
	if not backdrop.SetBackdropBorderColor then return end

	backdrop:SetBackdropBorderColor(unpack(lit and E.media.rgbvaluecolor or E.media.bordercolor))
end

-- S:HandleButton ends with an unconditional pair of OnEnter/OnLeave hooks that
-- swap the border to the value colour and back, and neither of them looks at
-- IsEnabled. A disabled button still fires both scripts on this client, so a
-- dead button lights up under the cursor and reads as clickable -- the greyed
-- Activate button, Save changes with nothing pending, Purchase with nothing
-- selected. HookScript can't be undone, but handlers fire in registration
-- order, so a hook registered after HandleButton runs last and has the final
-- say on the colour.
--
-- This one deliberately doesn't consult IsMouseOver: OnEnter can fire a pixel
-- before IsMouseOver turns true (ElvUI's own aura code pads around the same
-- quirk), and reading it here would drop the highlight off a live button.
local function OnButtonEnter(button)
	if Skin:IsEnabled(button) then return end

	SetButtonBorder(button, false)
end

-- For a button that can be disabled while the cursor is already on it: OnEnter
-- has been and gone by then, so nothing corrects the border until the pointer
-- leaves. Only worth wiring up where something already watches the button's
-- state -- it does not justify an OnUpdate of its own.
function Skin:RefreshButtonBorder(button)
	SetButtonBorder(button, self:IsEnabled(button) and button:IsMouseOver())
end

-- Every S:HandleButton call site in the plugin goes through here, so the
-- disabled-hover correction is inherited rather than repeated per module. The
-- extra arguments are HandleButton's own (strip, isDeclineButton,
-- useCreateBackdrop, noSetTemplate) and are passed straight through.
function Skin:Button(button, ...)
	if not button then return end

	S:HandleButton(button, ...)

	-- Unguarded: a pass over a handful of regions is cheap, and re-running it
	-- catches a region added to the button after the first skin pass.
	self:StripHighlightArt(button)

	-- Guarded separately from HandleButton's own isSkinned flag: these frames
	-- re-run their skin pass on every show, and HookScript stacks handlers
	-- rather than replacing them, so an unguarded re-hook adds another copy
	-- per show for the life of the session.
	if not button.CoAButtonSkinned then
		button.CoAButtonSkinned = true

		button:HookScript("OnEnter", OnButtonEnter)
	end
end

-- Several of these controls draw their art as anonymous regions of one atlas
-- file rather than through the named Left/Middle/Right fields or the Normal/
-- Pushed/Disabled set S:HandleButton knows how to clear, so its own clearing
-- can't reach them -- and a blind StripTextures would take the caret or the
-- label with it. Those are cleared by file instead.
--
-- SetTexture is noop'd per region rather than just cleared: whatever re-arts
-- the control on a state change (a mouse-down swapping in the pressed variant,
-- a tex coord swap between two variants of the same file) is free to re-set the
-- file as well, and a cleared texture would come straight back.
function Skin:StripArtByFile(frame, pattern)
	if not frame then return end

	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and tostring(texture):find(pattern) then
			region:SetTexture(nil)
			region.SetTexture = E.noop
		end
	end
end

-- S:HandleButton clears the button's own Normal/Highlight/Pushed/Disabled
-- textures and the named Left/Middle/Right pieces, and nothing else -- so a
-- native highlight drawn as a plain region of the button survives it and lights
-- up under the cursor against the flat ElvUI backdrop. That was the wardrobe
-- Cancel button's red glow, and clearing it by file there fixed exactly that
-- one button: probing the layer across everything the plugin skins turned up
-- the Save outfit button wearing the same red file, and Disable transmog and
-- Disable spell visuals wearing the dialog-box glow, none of which any
-- clear-by-file call site was ever going to reach.
--
-- The whole layer goes rather than named files, because on these frames it only
-- ever carries native hover art. Every button probed has exactly one HIGHLIGHT
-- region, and on the ones that already looked right it is blank -- so there is
-- nothing else living there to lose. ElvUI's own hover treatment isn't caught:
-- it's the backdrop border swap HandleButton hooks, and a backdrop is drawn
-- through SetBackdrop plus two child border frames, not as a region of the
-- button at all.
--
-- Noop'd rather than only cleared, as in StripArtByFile: a state change that
-- re-arts the button would otherwise bring the glow straight back.
function Skin:StripHighlightArt(frame)
	if not frame then return end

	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())

		if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "HIGHLIGHT" then
			region:SetTexture(nil)
			region.SetTexture = E.noop
		end
	end
end

-- The pill behind the talent frame's Activate button and the wardrobe's Apply
-- and Cancel buttons. Two files rather than one: "128GoldRedButton" carries the
-- green and grey variants as tex coords, and Cancel alone is drawn from
-- "128RedButton" (probed). The shared suffix matches both, and nothing else on
-- these frames uses either. Only the pill itself is this pattern's job now --
-- the hover art on both files goes with the rest of the HIGHLIGHT layer.
Skin.RedButtonArt = "RedButton"

-- The dropdown pills on the vanity and wardrobe frames are the same widget:
-- nine anonymous "Silver-Button" slices.
local DROPDOWN_ART = "Silver%-Button"
local CARET_ART = "ChatFrameExpandArrow"
local CARET_SIZE = 14

-- The caret is retextured after HandleButton, not before: HandleButton strips
-- the pill, and a caret replaced ahead of that gets cleared straight back off.
local function SkinDropdownCaret(dropdown)
	for i = 1, dropdown:GetNumRegions() do
		local region = select(i, dropdown:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and tostring(texture):find(CARET_ART) then
			-- The caret is a plain OVERLAY texture on the dropdown itself rather
			-- than a separate button, so it can't go through
			-- HandleNextPrevButton and is retextured directly. No ArrowDown
			-- asset exists -- every other direction in ElvUI is ArrowUp rotated.
			region:SetTexture(E.Media.Textures.ArrowUp)
			region:SetVertexColor(1, 1, 1)
			region:SetTexCoord(0, 1, 0, 1)
			region:SetRotation(S.ArrowRotation.down)
			region:SetSize(CARET_SIZE, CARET_SIZE)
		end
	end
end

-- menu is the popout list this dropdown owns; it gets the panel only, matching
-- how the talent frame's own popup menus are treated. The option rows inside
-- are a later pass.
function Skin:Dropdown(dropdown, menu)
	if not dropdown or dropdown.CoASkinned then return end
	dropdown.CoASkinned = true

	self:StripArtByFile(dropdown, DROPDOWN_ART)
	self:Button(dropdown)
	SkinDropdownCaret(dropdown)

	self:Panel(menu)
end

-- Tabs -----------------------------------------------------------------------
--
-- S:HandleTab can't be used on any of these: it clears the tab body by name,
-- looking for a "Middle" piece, and every CoA tab names theirs "Center", so the
-- body survives and the ElvUI backdrop just lands behind the old art.
--
-- One list covers both tab flavours: the talent frame's tabs carry the
-- Disabled variants as well, the wardrobe's category tabs don't, and the
-- lookups for the ones that don't exist simply come back nil.
local TAB_TEXTURES = {"Left", "Center", "Right", "LeftDisabled", "CenterDisabled", "RightDisabled"}

-- Blizzard's own tab code re-sets these textures both when a frame reopens and,
-- separately, on every tab switch -- and a switch never fires the owning
-- frame's OnShow, only SetChecked. So this has to be idempotent and re-run from
-- everywhere rather than skinned once behind a guard.
function Skin:StripTabArt(tab)
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

local TAB_BACKDROP_INSET = 3

-- Native tab sizing is a retail leftover -- every other ElvUI tab row in this
-- client reads bigger -- so labelled tabs are grown, off the font's own current
-- size rather than a hardcoded number, and stay in step with the user's font
-- settings. Icon-only tabs (the wardrobe's category strip) have no label to
-- grow around and keep their native size; growing them would only push the
-- icons off their own layout.
local TAB_GROWTH = 8
local TAB_FONT_GROWTH = 3
local TAB_LABEL_OFFSET = 12

-- Grown height self-heals: on a plain /reload a tab's native height isn't
-- settled yet at skin time (Blizzard lays it out asynchronously), so a one-shot
-- SetHeight caught a stale value and left a shorter tab until something let the
-- native layout finish.
--
-- Compared by equality rather than "did it shrink": the late layout can land on
-- a height larger than the stale one this grew from, and a shrink-only check
-- would then see current > target and never regrow. GetHeight doesn't read back
-- byte-exact after SetHeight either -- UI scale rounds it to a slightly
-- different float -- so a strict ~= compare never held and this grew every tick
-- without bound. Half a pixel of slack absorbs the rounding while still
-- catching a genuine Blizzard-driven change, which is always a full tab's worth
-- of height.
local TAB_HEIGHT_EPSILON = 0.5

local function UpdateTabSize(tab)
	if not tab.CoAGrowTab then return end

	local height = tab:GetHeight()

	if not tab.CoAGrownHeight or math.abs(height - tab.CoAGrownHeight) > TAB_HEIGHT_EPSILON then
		tab.CoAGrownHeight = height + TAB_GROWTH
		tab:SetHeight(tab.CoAGrownHeight)
	end
end

-- Tabs that aren't children of the frame they belong to (the talent frame's
-- are separately-placed siblings) sit behind its panel art once grown, so they
-- get bumped above it. Re-applied every tick rather than on show or on select:
-- bumping from those two alone still left them behind the panel, so whatever
-- resets their level isn't either of those events.
local function BumpTabLevel(tab)
	local parent = tab.CoALevelParent
	if not parent then return end

	tab:SetFrameStrata(parent:GetFrameStrata())
	tab:SetFrameLevel(parent:GetFrameLevel() + 20)
end

-- Only the tab being switched to fires anything at all -- the ones switched
-- away from never fire OnClick/OnShow/SetChecked again, yet their native art
-- still comes back, so there's no event to catch it from. Checked from OnUpdate
-- instead: a cheap GetTexture() compare that only pays for the full strip when
-- the art has actually reappeared.
local function UpdateTabArt(tab)
	BumpTabLevel(tab)
	UpdateTabSize(tab)

	local name = tab:GetName()
	local tex = name and _G[name.."Left"]

	if tex and tex:GetTexture() then
		Skin:StripTabArt(tab)
	end
end

-- No fill or border swap marks the open tab: the native tab code already turns
-- the label white on the checked one and leaves the rest their normal colour,
-- same as the Friends/Character tab rows. Only the art strip has to re-run.
local function OnTabChecked(tab)
	Skin:StripTabArt(tab)
end

-- The tab row along the bottom of the talent window is one set of buttons
-- shared by all three windows it switches between, not one row per window,
-- which is why it lives here rather than in any single frame's module. It
-- doesn't need scaling of its own -- it's a child of Collections, so it follows
-- whatever ApplyWindowScale sets.
local COLLECTION_TAB = "CollectionsPoolFrameCollectionTabTemplate%d"
local MAX_COLLECTION_TABS = 10

function Skin:CollectionTabs(owner)
	for i = 1, MAX_COLLECTION_TABS do
		local tab = _G[COLLECTION_TAB:format(i)]
		if not tab then break end

		self:Tab(tab, owner)
	end
end

-- levelParent is the frame the tab must draw above, and is only needed for tabs
-- that aren't its children (see BumpTabLevel). Pass nil for tabs parented to
-- the frame they belong to -- normal parent/child z-order already covers those.
function Skin:Tab(tab, levelParent)
	if not tab then return end

	-- Set on every call rather than only the first: the collection tabs are
	-- shared, so the frame they have to draw above is whichever window is open.
	if levelParent then
		tab.CoALevelParent = levelParent
	end

	if not tab.CoASkinned then
		tab.CoASkinned = true

		self:StripTabArt(tab)

		-- Default rather than Transparent: tabs sit below their frame over the
		-- open world, so a see-through panel reads as washed out instead of as
		-- the solid tabs the retail layout has.
		--
		-- The backdrop's own level is left alone. CreateBackdrop keeps it level
		-- with the tab, and regions render fine on top of a same-level child;
		-- forcing it a level above the tab reproduces the
		-- child-frame-covers-its-parent's-own-regions quirk (see StripRowArt in
		-- TalentFrame), which blanks the label.
		tab:CreateBackdrop("Default")
		tab.backdrop:Point("TOPLEFT", TAB_BACKDROP_INSET, -TAB_BACKDROP_INSET)
		tab.backdrop:Point("BOTTOMRIGHT", -TAB_BACKDROP_INSET, TAB_BACKDROP_INSET)
		tab:SetHitRectInsets(TAB_BACKDROP_INSET, TAB_BACKDROP_INSET, TAB_BACKDROP_INSET, TAB_BACKDROP_INSET)

		local fontString = tab.GetFontString and tab:GetFontString()
		if fontString then
			tab.CoAGrowTab = true

			local font, size, flags = fontString:GetFont()
			if font then
				fontString:SetFont(font, size + TAB_FONT_GROWTH, flags)
			end

			-- Only for tabs that actually carry an icon. On those (the talent
			-- window's) the label's native anchor sits right off the icon, sized
			-- for the smaller native font, so grown text collides with it, and
			-- the label is nudged off whatever point the native layout gave it
			-- rather than a hardcoded anchor that would fight that layout. The
			-- wardrobe's category tabs have no icon and centre their label, so
			-- the same nudge just pushed every one of them off-centre to the
			-- right.
			local name = tab:GetName()
			local icon = name and _G[name.."Icon"]

			if icon and icon.GetTexture and icon:GetTexture() and icon:IsShown() then
				local point, relTo, relPoint, x, y = fontString:GetPoint(1)

				if point then
					fontString:SetPoint(point, relTo, relPoint, x + TAB_LABEL_OFFSET, y)
				end
			end
		end

		-- Guarded: the talent frame's tabs are CheckButtons, the wardrobe's
		-- category tabs aren't guaranteed to be, and hooksecurefunc errors
		-- outright on a method that doesn't exist.
		if tab.SetChecked then
			hooksecurefunc(tab, "SetChecked", OnTabChecked)
		end

		tab:HookScript("OnUpdate", UpdateTabArt)
	end

	self:StripTabArt(tab)
	BumpTabLevel(tab)
end

-- These frames are created on-demand by their owning addon, the instant the
-- player first opens one -- a poll can't catch that before the native art gets
-- a paint. ADDON_LOADED fires (synchronously, before control returns to
-- whatever code calls :Show()) the moment that addon finishes loading, so
-- skinning from it lands before the first-ever :Show(), killing the one-frame
-- flicker a poll-based catch can't avoid. Confirmed in-game.
function Skin:OnFrameAvailable(tryHook)
	if tryHook() then return end

	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self)
		if tryHook() then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end
