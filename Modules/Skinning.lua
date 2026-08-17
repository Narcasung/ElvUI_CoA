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

-- The dropdown pills on the vanity and wardrobe frames are the same widget:
-- nine anonymous "Silver-Button" slices rather than the named Left/Middle/Right
-- fields or the Normal/Pushed/Disabled set S:HandleButton knows how to clear,
-- so its own clearing can't reach them -- and a blind StripTextures would take
-- the caret and the label with them.
--
-- The native mouse-down handler re-arts one of these regions with a pressed
-- variant of the same file on every click, which is why the pill came back
-- skinless while held. SetTexture is noop'd per region after clearing.
local DROPDOWN_ART = "Silver%-Button"
local CARET_ART = "ChatFrameExpandArrow"
local CARET_SIZE = 14

local function StripDropdownArt(dropdown)
	for i = 1, dropdown:GetNumRegions() do
		local region = select(i, dropdown:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and tostring(texture):find(DROPDOWN_ART) then
			region:SetTexture(nil)
			region.SetTexture = E.noop
		end
	end
end

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

	StripDropdownArt(dropdown)
	S:HandleButton(dropdown)
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

-- levelParent is the frame the tab must draw above, and is only needed for tabs
-- that aren't its children (see BumpTabLevel). Pass nil for tabs parented to
-- the frame they belong to -- normal parent/child z-order already covers those.
function Skin:Tab(tab, levelParent)
	if not tab then return end

	if not tab.CoASkinned then
		tab.CoASkinned = true
		tab.CoALevelParent = levelParent

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

			-- The label's native anchor sits right off the icon, sized for the
			-- smaller native font, so grown text collides with the icon. Nudged
			-- off whatever point the native layout gave it rather than a
			-- hardcoded anchor that would fight that layout.
			local point, relTo, relPoint, x, y = fontString:GetPoint(1)
			if point then
				fontString:SetPoint(point, relTo, relPoint, x + TAB_LABEL_OFFSET, y)
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
