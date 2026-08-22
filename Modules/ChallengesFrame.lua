local E, L, V, P, G = unpack(ElvUI)
local CoA = E:GetModule("CoA")
local Skin = CoA.Skin

local FRAME_NAME = "ChallengesFrame"

-- Unlike the talent/vanity/wardrobe trio, this window is not one of the
-- Collections container's children: it's a HIGH-strata frame parented straight
-- to UIParent, and it's mouse-enabled itself rather than being dragged by a
-- container (probed). So it deliberately doesn't go through
-- Skin:ApplyWindowScale or Skin:CollectionTabs -- the first scales Collections,
-- which would resize the other three windows and not this one, and the second
-- skins the tab row those three share, which this window has no part in. A
-- scale slider for it later would set the scale on the frame itself, and the
-- drag target moves with it because the frame is its own drag target.

-- Stock Blizzard panel tabs, unlike every other tab row the plugin skins: plain
-- Buttons rather than CheckButtons, and their art is named Left/Middle/Right
-- (plus the Disabled set Blizzard swaps in for the selected tab) rather than
-- the server's Left/Center/Right -- both flavours are covered by the shared
-- strip in Skinning.lua. They're real children of the frame, so no level parent
-- is needed: normal parent/child z-order already puts them above its panel.
--
-- Six exist today, two of them gated behind content an account may not have, so
-- the row is walked until the first missing index rather than against a
-- hardcoded count -- same shape as Skin:CollectionTabs.
--
-- This is the one row in the plugin that interlocks: every tab past the first is
-- anchored 16px back into the one before it (probed) so the native end caps
-- overlap, which reads as a single merged bar once the art is gone. Hence the
-- unoverlap flag; the server-authored rows sit apart already and don't take it.
local MAX_TABS = 10

local function SkinTabs()
	for i = 1, MAX_TABS do
		local tab = _G[FRAME_NAME.."Tab"..i]
		if not tab then break end

		Skin:Tab(tab, nil, true)
	end
end

-- The row hangs 6px clear of the frame's bottom edge (probed), which the native
-- art spanned with the tabs' own ornate tops -- gone with the art, so the row
-- reads as detached from the window it belongs to. Only the first tab carries a
-- vertical offset at all, the rest being anchored off its edge, so moving it
-- moves the row.
--
-- Set to the backdrop inset rather than to zero: the tab's flat backdrop starts
-- that far inside the tab, so a tab flush with the frame still leaves its
-- visible edge floating. Written as an absolute rather than as an adjustment to
-- what's there, which keeps it idempotent across the repeated skin passes.
local function AnchorTabRow()
	local tab = _G[FRAME_NAME.."Tab1"]
	if not tab then return end

	local point, relativeTo, relativePoint, x = tab:GetPoint(1)
	if not point then return end

	tab:SetPoint(point, relativeTo, relativePoint, x, Skin.TabBackdropInset)
end

-- The nine-slice draws the ornate purple border and the teal inner panel over
-- the top of the frame, doubling up with the Transparent template's own border
-- -- but unlike the talent and wardrobe frames' nine-slices it isn't purely
-- decorative: the window's title is one of its regions (probed: nine BORDER
-- textures, one ARTWORK texture, and the title FontString). So it's stripped
-- rather than run through Skin:HideArt, whose Hide() would take the title down
-- with the border. StripTextures only touches Textures, so the art goes and the
-- FontString stays.
local function StripBorderArt()
	local nineSlice = _G[FRAME_NAME.."NineSlice"]
	if not nineSlice then return end

	nineSlice:StripTextures()
end

-- That title has no name of its own -- there is no ChallengesFrameTitleText,
-- and none of the other usual suffixes resolve either (probed) -- so it's
-- picked out by type, the same way the vanity frame's pager arrows are picked
-- out by position. The nine-slice owns exactly one FontString.
local function GetTitle()
	local nineSlice = _G[FRAME_NAME.."NineSlice"]
	if not nineSlice then return end

	for i = 1, nineSlice:GetNumRegions() do
		local region = select(i, nineSlice:GetRegions())

		if region:GetObjectType() == "FontString" then return region end
	end
end

-- Vertical slack left above the title inside the widened panel.
local TITLE_PADDING = 6

-- The title is drawn above the frame's own top edge -- the native art carries a
-- banner up there that the frame's rect doesn't include -- so a panel sized to
-- the frame leaves the title floating over the open world. The panel is built
-- as a backdrop rather than through SetTemplate for exactly this reason: a
-- template's backdrop is drawn as regions of the frame itself and can only ever
-- match its rect, while a backdrop is a child frame with points of its own, so
-- its top edge can be pushed up to take the title in.
--
-- The distance is measured live rather than hardcoded: it's whatever gap the
-- server's own layout left between the title and the frame, so this stays right
-- if that layout changes. Re-measured on every show for the same reason the tab
-- heights are (see Skinning.lua) -- on a cold /reload the layout isn't settled
-- at skin time, and a one-shot measurement catches a stale value.
--
-- The hit rect is grown to match. The frame is its own drag target (probed), and
-- without this the widened panel would have a band along its top that looks part
-- of the window but can't be grabbed.
local function UpdatePanelTop(frame)
	local backdrop = frame.backdrop
	local title = GetTitle()
	if not (backdrop and title) then return end

	local frameTop, titleTop = frame:GetTop(), title:GetTop()
	if not (frameTop and titleTop) then return end

	local offset = titleTop - frameTop + TITLE_PADDING
	if offset < 0 then offset = 0 end

	backdrop:Point("TOPLEFT", frame, "TOPLEFT", 0, offset)
	backdrop:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

	-- Negative insets grow the hit rect outwards rather than shrinking it.
	frame:SetHitRectInsets(0, 0, -offset, 0)
end

-- Per-tab contents. Each of the six tabs owns its own copy of these widgets
-- rather than sharing one set, so they're skinned per tab; only the Trials tab
-- is done so far and the rest follow the same shape.
local TRIALS_TAB = FRAME_NAME.."TrialsTab"
local TRIALS_LIST = TRIALS_TAB.."Challenges"
local TRIALS_SCROLL = TRIALS_LIST.."ScrollFrame"

-- The list container's one and only region: a 2px rule drawn across the bottom
-- of the panel from the store art (probed). It's the native panel's own divider,
-- and with the panel around it flat there's nothing left for it to divide.
local LIST_DIVIDER_ART = "perksactivities"

local function SkinTrialsTab()
	Skin:SearchBox(_G[TRIALS_TAB.."Search"])

	-- Cleared by file rather than stripped: the container is the scroll frame's
	-- own parent, so a blind strip is a blunter instrument than one known region
	-- needs, and StripArtByFile's noop holds if the list ever re-arts it.
	Skin:StripArtByFile(_G[TRIALS_LIST], LIST_DIVIDER_ART)

	-- The same nine "UI-Silver-Button" slices and ChatFrameExpandArrow caret as
	-- the vanity and wardrobe dropdowns (probed), so it takes the same handler.
	-- Nothing is passed for its popout: the Trials tab has exactly three children
	-- and none of them is a menu (probed), so wherever the list is built it isn't
	-- there. Skin:Dropdown skips that half when it's handed nil.
	Skin:Dropdown(_G[TRIALS_TAB.."FilterDropDown"])

	-- The arrows are named off the scroll frame rather than off the bar, which is
	-- the other reason S:HandleScrollBar can't find them on its own.
	Skin:ScrollBar(
		_G[TRIALS_SCROLL.."ScrollBar"],
		_G[TRIALS_SCROLL.."ScrollBarThumb"],
		_G[TRIALS_SCROLL.."ScrollUpButton"],
		_G[TRIALS_SCROLL.."ScrollDownButton"]
	)
end

-- The close button is anchored inside the frame's own top-right corner, which
-- stopped being the corner the player sees once the panel grew up over the title
-- band -- it ends up floating a title's height below the top edge. Re-anchored
-- to the panel instead, and re-run on every pass so it follows the panel's top
-- whenever that gets re-measured.
--
-- No offset of its own: Skin:CloseButton normalises the button to a 32px box
-- with a 12px X centred in it, so the margin off the corner is already built in.
local function AnchorCloseButton(frame)
	local close = _G[FRAME_NAME.."CloseButton"]
	if not (close and frame.backdrop) then return end

	close:ClearAllPoints()
	close:SetPoint("TOPRIGHT", frame.backdrop, "TOPRIGHT", 0, 0)
end

-- Nothing here re-runs on a tab switch, and nothing needs to: switching tabs
-- doesn't fire the frame's OnShow, and the one thing a switch does disturb is
-- the tab art, which Skin:Tab watches from its own OnUpdate. The title
-- fontstring is reused across tabs rather than swapped for a per-tab one -- its
-- text changes, the object doesn't -- so it only needs the one pass too.
local function SkinContents()
	StripBorderArt()
	Skin:Title(GetTitle())
	UpdatePanelTop(_G[FRAME_NAME])
	Skin:CloseButton(_G[FRAME_NAME.."CloseButton"])
	AnchorCloseButton(_G[FRAME_NAME])
	SkinTabs()
	AnchorTabRow()
	SkinTrialsTab()
end

local function SkinFrame(frame)
	if not frame.CoASkinned then
		frame.CoASkinned = true

		-- A single BACKGROUND texture is all the frame owns (probed), and it's
		-- decorative -- nothing functional is drawn as a region of this frame,
		-- unlike the vanity store, whose currency counters are. So it's stripped
		-- outright. Stripped before the backdrop is made, not after: a backdrop
		-- built first would be a child frame and survive, but the order is kept
		-- the same as Skin:Panel's for one less rule to remember.
		frame:StripTextures()
		frame:CreateBackdrop("Transparent")

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

function CoA:InitializeChallengesFrame()
	if not E.private.skins.blizzard.enable then return end

	Skin:OnFrameAvailable(TryHook)
end
