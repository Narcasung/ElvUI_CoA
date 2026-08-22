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
-- rather than sharing one set, so they're skinned per tab; Trials, Rewards,
-- Challenges and Gamemodes are done, and the two left follow the same shape.
--
-- Nothing about one tab's naming carries to the next: the Trials search box is
-- "...TrialsTabSearch" and its filter a "...FilterDropDown", where the Rewards
-- pair are "...StoreTabSearchBox" and "...Filter" (probed). Every suffix on a
-- new tab is worth confirming rather than copying.
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

local STORE_TAB = FRAME_NAME.."StoreTab"
local STORE_LAYOUT = STORE_TAB.."StoreButtonLayout"

-- Walked to the first missing index rather than against the twenty-one that
-- exist today, the same shape as the tab row: this count is a page size, and a
-- page size is exactly the sort of thing a content patch moves.
local MAX_SLOTS = 40

-- The bevelled empty-slot plate every bag and auction square on this client
-- draws, here behind each reward card (probed). The dashes are escaped because
-- StripArtByFile matches with find, where an unescaped dash is a pattern range.
local SLOT_ART = "UI%-AuctionFrame%-ItemSlot"

-- The card's rect is drawn tight around its contents: 140x32 with a 32px icon,
-- so the icon meets the top and bottom edges exactly and the name runs to the
-- right one. The native plate hid that by bleeding a bevel outwards; a flat
-- backdrop on the same rect just looks cramped. The grid leaves far more room
-- than this between cards -- tens of pixels each way -- so the box is grown
-- rather than the contents moved in, which would fight the store's own layout.
local CARD_PADDING = 4

-- The headings above the grid are drawn out of the quest log's atlas by tex
-- coord (probed: three slices plus the button's own NormalTexture, all one
-- file). Cleared by file rather than stripped so the label survives.
local HEADING_ART = "questmaplogatlas"

-- A row rather than an item square: 140x32 with a 32px icon flush left, then
-- the name, then a SimpleHTML cost (probed). The icon is a region of the button
-- itself rather than sitting in a frame of its own, unlike the talent menu's
-- rows, so it takes the crop but not a backdrop of its own.
--
-- The card takes HandleButton's useCreateBackdrop path rather than its default
-- SetTemplate one, which is what makes the padding possible at all: a template
-- is drawn as regions of the button and can only ever match its rect, while a
-- backdrop is a child frame that can be set outside it. Same reasoning as the
-- window panel's, one level down. Skin:Button's hover colouring follows either
-- way -- it resolves button.backdrop before the button itself.
--
-- The native hover square needs nothing by name: it's a plain region on the
-- HIGHLIGHT layer (probed), which is the whole layer Skin:Button's
-- StripHighlightArt takes.
--
-- The crop is re-applied from a hook rather than set once. The grid is a fixed
-- pool the store refills in place on every search, filter and page change, and
-- SetTexture resets a texture's coords -- so a one-shot crop would survive
-- exactly until the first page turn, and the native icon borders would come
-- back on every card at once. The plate underneath needs no such watch:
-- StripArtByFile noops its SetTexture, so a refill that re-arts it writes
-- nothing.
local function SkinStoreCard(slot)
	if not slot then return end

	Skin:StripArtByFile(slot, SLOT_ART)
	Skin:Button(slot, nil, nil, true)

	-- Re-set on every pass rather than once: SetOutside writes fixed points, so
	-- a UI scale change that moves what a pixel is leaves them stale.
	if slot.backdrop then
		slot.backdrop:SetOutside(slot, CARD_PADDING, CARD_PADDING)
	end

	local name = slot:GetName()
	local icon = name and _G[name.."Icon"]
	if not icon then return end

	icon:SetTexCoord(unpack(E.TexCoords))

	-- Guarded separately from Skin:Button's own flag, and for the same reason it
	-- guards its own: this runs again on every show, and hooksecurefunc stacks
	-- handlers rather than replacing them.
	if not slot.CoAIconHooked then
		slot.CoAIconHooked = true

		hooksecurefunc(icon, "SetTexture", function(texture)
			texture:SetTexCoord(unpack(E.TexCoords))
		end)
	end
end

-- "Trial Master's Rewards" and its sibling for the build vendor are Buttons by
-- type, but they aren't buttons: they're the grid's section headings, drawn as
-- a stylised plaque and doing nothing when clicked. So they get their art taken
-- off and nothing put back -- no backdrop, which would draw a box around a
-- caption and read as clickable, and no hover border for the same reason. The
-- HIGHLIGHT layer goes too, or the caption lights up under the cursor with
-- nothing behind it.
--
-- Walked off the layout rather than named, since the set is one per reward
-- vendor and grows with content. Same reasoning as the tab row.
local function SkinStoreHeadings()
	local layout = _G[STORE_LAYOUT]
	if not layout then return end

	for i = 1, layout:GetNumChildren() do
		local heading = select(i, layout:GetChildren())

		Skin:StripArtByFile(heading, HEADING_ART)
		Skin:StripHighlightArt(heading)
	end
end

-- Everything on this tab exists before it has ever been opened (probed: the
-- same twenty-nine children on a cold reload as after a click), so it goes
-- through SkinContents with the rest rather than needing a hook on the tab's
-- own OnShow.
--
-- Two things here are deliberately left alone. The Currency button carries the
-- trophy icon and the "Trial Master's Trophy: 0" counter as its only two
-- regions and no frame art at all, so there's nothing to strip and a backdrop
-- would only make a label look clickable. PageText is a FontString region of
-- the tab itself -- the same trap as the vanity store's counters, and the
-- reason Skin:Panel grew keepTextures -- so nothing here blind-strips the tab.
--
-- No scroll bar is wired: the grid pages rather than scrolls, and there's no
-- scroll frame anywhere under the tab to hang one off (probed).
local function SkinStoreTab()
	Skin:SearchBox(_G[STORE_TAB.."SearchBox"])

	-- Not a dropdown by structure -- no Middle texture, no Button child, no Text
	-- fontstring, just a plain Button (probed) -- but it is one by art: the same
	-- nine "UI-Silver-Button" slices and ChatFrameExpandArrow caret the Trials
	-- filter wears. Skin:Dropdown matches on the art rather than on the naming,
	-- so it takes this one too; the Middle-plus-Button structural test is only
	-- ever a shortcut to that question, and here it answers it wrongly.
	Skin:Dropdown(_G[STORE_TAB.."Filter"])

	-- Stock "UI-SquareButton" arrows (probed), unlike the hand-built bar on the
	-- Trials list, so these go through the ElvUI handler unaided.
	Skin:NextPrevButton(_G[STORE_TAB.."PreviousPageButton"], "left")
	Skin:NextPrevButton(_G[STORE_TAB.."NextPageButton"], "right")

	SkinStoreHeadings()

	for i = 1, MAX_SLOTS do
		local slot = _G[STORE_TAB.."Slot"..i]
		if not slot then break end

		SkinStoreCard(slot)
	end
end

local CHALLENGES_TAB = FRAME_NAME.."ChallengesTab"
local CHALLENGES_LIST = CHALLENGES_TAB.."Challenges"
local CHALLENGES_SCROLL = CHALLENGES_LIST.."ScrollFrame"

-- The one tab whose naming does carry over from another: the same three
-- children as Trials, under the same suffixes, with the same store divider as
-- its list container's only region, the same nine "UI-Silver-Button" slices and
-- caret on its filter, and its arrows named off the scroll frame rather than
-- off the bar (probed). So it takes the Trials treatment call for call -- see
-- SkinTrialsTab above for why each of the four is the call it is.
--
-- The divider constant is shared rather than copied: it is the same 2px rule out
-- of the same file, not a second one that happens to match today.
local function SkinChallengesTab()
	Skin:SearchBox(_G[CHALLENGES_TAB.."Search"])
	Skin:StripArtByFile(_G[CHALLENGES_LIST], LIST_DIVIDER_ART)
	Skin:Dropdown(_G[CHALLENGES_TAB.."FilterDropDown"])
	Skin:ScrollBar(
		_G[CHALLENGES_SCROLL.."ScrollBar"],
		_G[CHALLENGES_SCROLL.."ScrollBarThumb"],
		_G[CHALLENGES_SCROLL.."ScrollUpButton"],
		_G[CHALLENGES_SCROLL.."ScrollDownButton"]
	)
end

local GAMEMODES_TAB = FRAME_NAME.."GamemodesTab"
local GAMEMODES_LIST = GAMEMODES_TAB.."Challenges"
local GAMEMODES_SCROLL = GAMEMODES_LIST.."ScrollFrame"

-- The Trials/Challenges shape a third time, and again suffix for suffix: the
-- same search box and list names, the same store divider as its list
-- container's only region, the same arrows named off the scroll frame rather
-- than off the bar (probed). See SkinTrialsTab above for why each call is the
-- call it is.
--
-- What differs is the filter: there isn't one, and that's the tab's own shape
-- rather than something missed here. It has exactly two children, the search
-- box and the list, and neither of them is a menu (probed), so there is nothing
-- for a Skin:Dropdown line to be handed.
--
-- It owns no regions of its own either (probed), so nothing here needs the
-- keepTextures care the Rewards tab's PageText took. And everything under it
-- exists before the tab has ever been opened -- two children and no regions on
-- a cold reload, unchanged after a click -- so it rides SkinContents like the
-- other three rather than needing a hook on the tab's own OnShow.
local function SkinGamemodesTab()
	Skin:SearchBox(_G[GAMEMODES_TAB.."Search"])
	Skin:StripArtByFile(_G[GAMEMODES_LIST], LIST_DIVIDER_ART)
	Skin:ScrollBar(
		_G[GAMEMODES_SCROLL.."ScrollBar"],
		_G[GAMEMODES_SCROLL.."ScrollBarThumb"],
		_G[GAMEMODES_SCROLL.."ScrollUpButton"],
		_G[GAMEMODES_SCROLL.."ScrollDownButton"]
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
	SkinStoreTab()
	SkinGamemodesTab()
	SkinChallengesTab()
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
