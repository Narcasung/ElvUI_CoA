local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")
local Skin = CoA.Skin

local FRAME_NAME = "CoATalentFrame"

-- The talent tree is the one part of the frame we must not touch: every node
-- is an icon button whose border/overlay textures encode rank and
-- availability, so ElvUI's generic button handling would flatten the
-- information out of them. The nodes and connectors live in pools under
-- SpecTree, with the scene art in FXFrame, so those subtrees are skipped by
-- name. TreeView itself is walked, because the bottom bar is inside it.
local EXCLUDED = {"PoolFrame", "SpecTree", "ClassTree", "FXFrame", "ShadowOverlay"}

local function IsTreeSubtree(name)
	if not name then return false end

	for _, pattern in ipairs(EXCLUDED) do
		if name:find(pattern) then return true end
	end

	return false
end

local function IsDropDown(frame, name)
	return name ~= nil and _G[name.."Button"] ~= nil and _G[name.."Text"] ~= nil
end

-- The bottom bar's widgets aren't at a fixed depth (some sit directly on the
-- frame, some are nested one or two containers deep), and their names aren't
-- documented anywhere, so skinning is driven by walking the frame instead of
-- by a hardcoded name list. Depth is capped so a container we didn't expect
-- can't drag us down into the tree's pooled widgets.
local MAX_DEPTH = 5

local SkinChildren

function SkinChildren(frame, depth)
	if depth > MAX_DEPTH then return end

	for i = 1, frame:GetNumChildren() do
		local child = select(i, frame:GetChildren())
		local name = child.GetName and child:GetName()

		if child.GetObjectType and not IsTreeSubtree(name) then
			local objType = child:GetObjectType()

			if objType == "EditBox" then
				S:HandleEditBox(child)
			elseif objType == "Button" then
				-- Close buttons are handled explicitly -- the frame's in
				-- SkinFrame, where it needs an anchor and a frame level the walk
				-- can't supply, and each menu's in SkinBottomBar. Matched on
				-- "Close" rather than "CloseButton": the menus name theirs just
				-- "...MenuClose", and it was coming out of the walk as an
				-- ordinary templated square with the X stripped off it.
				if not (name and name:find("Close")) then
					S:HandleButton(child)
				end
			elseif objType == "Frame" then
				if IsDropDown(child, name) then
					S:HandleDropDownBox(child)
				else
					SkinChildren(child, depth + 1)
				end
			end
		end
	end
end

-- TreeView is a sibling drawn above the close button's own frame level, so
-- without the bump the ElvUI close texture ends up behind the tree panel and
-- the corner just looks empty. Anchored explicitly because the native corner
-- position was set relative to the NineSlice art we hide.
local function SkinCloseButton(frame)
	local close = _G[FRAME_NAME.."CloseButton"]
	if not close then return end

	Skin:CloseButton(close)

	-- Re-applied on every pass, not once at skin time. The X is drawn on the
	-- close button's own frame, so it needs to outrank TreeView, and TreeView
	-- rides along whenever the talent frame is raised while the close button,
	-- being a sibling, keeps whatever absolute level it was given -- which is
	-- how the X ends up buried behind the tree panel with the button still
	-- clickable.
	close:SetFrameStrata(frame:GetFrameStrata())
	close:SetFrameLevel(frame:GetFrameLevel() + 20)

	-- HandleCloseButton centres a 12px X inside the button's native 32px box,
	-- so anchoring the box to the frame corner drops the X well below the
	-- title. Centring the button on the title's own vertical midpoint puts the
	-- X on the title line whatever height the bar turns out to be.
	local title = _G[FRAME_NAME.."TitleText"]
	local top = frame:GetTop()
	local titleY = title and select(2, title:GetCenter())

	close:ClearAllPoints()

	if top and titleY then
		close:Point("CENTER", frame, "TOPRIGHT", -16, titleY - top)
	else
		close:Point("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	end
end

local BOTTOM_BAR = FRAME_NAME.."TreeViewBottomBar"
local BOTTOM_BAR_DROPDOWNS = {"SpecDropDown", "BuildDropDown"}

-- The two menus don't name their list alike: the spec menu's inset and scroll
-- frame hang off "List", the build creator's off "BuildList". Assuming they
-- shared the layout is why nothing on the build creator's scrollbar was ever
-- being found.
local BOTTOM_BAR_MENUS = {
	{menu = "SpecializationMenu", list = "List"},
	{menu = "BuildCreatorMenu", list = "BuildList"}
}

-- Rows are pooled, so this walks by index until it runs out rather than
-- tracking how many the list currently holds.
local MENU_ROW_LIMIT = 50

-- Each row's icon sits in a rounded empty-slot ring, which reads as a raised
-- bevel against flat panels. The ring goes and the icon gets the usual ElvUI
-- treatment: cropped edges and a backdrop sized to it.
local function SkinMenuRowIcon(iconFrame)
	if not iconFrame or iconFrame.CoASkinned then return end
	iconFrame.CoASkinned = true

	for i = 1, iconFrame:GetNumRegions() do
		local region = select(i, iconFrame:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and texture:find("EmptySlot") then
			region:SetTexture(nil)
		end
	end

	local name = iconFrame:GetName()
	local icon = name and _G[name..".Icon"]

	if icon then
		S:HandleIcon(icon, iconFrame)
	end
end

local ROW_BORDER_EDGES = {"TOP", "BOTTOM", "LEFT", "RIGHT"}

-- The active row is edged rather than filled, and the edge is four textures on
-- the row for the same reason the fill is a texture: a backdrop frame is a
-- child, so it either covers the row's art or is covered by the neighbouring
-- rows, which overlap far enough that only its bottom line came through.
local function CreateRowBorder(row)
	local border = {}

	for _, edge in ipairs(ROW_BORDER_EDGES) do
		local line = row:CreateTexture(nil, "OVERLAY")
		line:Hide()
		border[edge] = line
	end

	border.TOP:SetPoint("TOPLEFT", row, "TOPLEFT")
	border.TOP:SetPoint("TOPRIGHT", row, "TOPRIGHT")
	border.TOP:SetHeight(E.mult)

	border.BOTTOM:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
	border.BOTTOM:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
	border.BOTTOM:SetHeight(E.mult)

	border.LEFT:SetPoint("TOPLEFT", row, "TOPLEFT")
	border.LEFT:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
	border.LEFT:SetWidth(E.mult)

	border.RIGHT:SetPoint("TOPRIGHT", row, "TOPRIGHT")
	border.RIGHT:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
	border.RIGHT:SetWidth(E.mult)

	row.CoABorder = border
end

-- Selection is read off the native overlay rather than tracked here: the row's
-- own code decides which entry is active and there's no event for it, so the
-- overlay is left in place as the signal and only its art is cleared.
local function UpdateRowSelection(row)
	local border = row.CoABorder
	if not border then return end

	local overlay = row.CoASelected
	-- Alpha as well as visibility, because it isn't known which of the two the
	-- row uses to turn the overlay on.
	local selected = overlay ~= nil and overlay:IsShown() and overlay:GetAlpha() > 0

	if selected == row.CoASelectionShown then return end
	row.CoASelectionShown = selected

	local r, g, b = unpack(E.media.rgbvaluecolor)

	for _, edge in ipairs(ROW_BORDER_EDGES) do
		local line = border[edge]

		line:SetTexture(r, g, b, 1)
		if selected then line:Show() else line:Hide() end
	end
end

-- The row's frame is a rounded plate from the PvP queue art, with a matching
-- background behind it. Both come off in favour of a flat ElvUI panel, and the
-- hover and selection plates have to go with them -- they're cut to the same
-- rounded shape, so they read as bevels once the plate underneath is flat.
-- Hover becomes the flat white wash ElvUI puts on list rows; selection moves
-- onto the 1px edge from CreateRowBorder, which is how the active entry is
-- marked everywhere else in ElvUI.
--
-- Hidden as well as cleared, and re-run from both the row's show and its
-- update: a single pass didn't hold, the rows put their art back as they're
-- refilled from the pool.
local function StripRowArt(row)
	local name = row:GetName()
	local border = name and _G[name..".Border"]

	if border then
		border:SetTexture(nil)
		border:Hide()
	end

	-- ".H" is the row's highlight texture, so retexturing it is enough to
	-- replace the hover state; there's no separate object to chase.
	local hover = name and _G[name..".H"]
	if hover and hover.SetTexture then
		hover:SetTexture(1, 1, 1, 0.15)
		hover:ClearAllPoints()
		hover:SetInside(row)
		row.CoAHover = hover
	end

	local selected = name and _G[name..".Selected"]
	if selected and selected.SetTexture then
		selected:SetTexture(nil)
		row.CoASelected = selected
	end

	for i = 1, row:GetNumRegions() do
		local region = select(i, row:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and texture:find("GuildFrame") then
			region:SetTexture(nil)
			region:Hide()
		end
	end
end

-- Scrolling refills the pooled rows and puts their native hover and selection
-- art back, and a pooled row doesn't fire OnShow when it's refilled, so there's
-- no event to strip on -- which is why the glow only ever appeared after a
-- scroll. The art is checked from the row's update instead. A colour-set
-- texture reads back as "SolidTexture", so the check stays a string compare
-- rather than a blind re-skin every frame.
local function UpdateRowArt(row)
	local hover, selected = row.CoAHover, row.CoASelected

	if (hover and hover:GetTexture() ~= "SolidTexture")
	or (selected and selected:GetTexture() ~= nil) then
		StripRowArt(row)
	end
end

local function UpdateRow(row)
	UpdateRowArt(row)
	UpdateRowSelection(row)
end

local SkinMenuRow

function SkinMenuRow(row)
	if not row then return end

	if not row.CoASkinned then
		row.CoASkinned = true

		-- The fill is painted on the row itself rather than through
		-- CreateBackdrop. The backdrop is a child frame, and here it covered
		-- the row's name, icon and status text at every frame level tried,
		-- including one below the row's own. A texture on the row's BACKGROUND
		-- layer is ordered against those regions inside a single frame instead,
		-- so it can't outrank them. Opaque rather than the transparent template,
		-- since the menu panel behind is already see-through and a second
		-- see-through layer left the rows reading as holes onto the talent scene.
		local background = row:CreateTexture(nil, "BACKGROUND")
		background:SetInside(row)
		background:SetTexture(unpack(E.media.backdropcolor))

		CreateRowBorder(row)

		-- Nooped so a refill can't swap the highlight for a fresh texture
		-- object, which would leave the retextured one orphaned and the check in
		-- UpdateRowArt reading a state nothing draws from any more.
		row.SetHighlightTexture = E.noop

		row:HookScript("OnShow", SkinMenuRow)

		-- No event fires when the active spec changes or when a scroll refills
		-- the row, so both are resynced from the row's update. The comparisons
		-- in UpdateRowArt and UpdateRowSelection make every tick that changes
		-- nothing a no-op.
		row:HookScript("OnUpdate", UpdateRow)
	end

	StripRowArt(row)
	UpdateRowSelection(row)
end

-- The Activate button inside an expanded specialization row draws its pill from
-- a single atlas across three BACKGROUND regions plus a HIGHLIGHT one, and
-- switches between the green and the grey variant by tex coord. There are no
-- Normal/Pushed/Disabled textures for HandleButton to clear (probed: both come
-- back nil, and every region's vertex colour is white in either state), so the
-- art is cleared by file the way the dropdown pills are (Skin:StripArtByFile,
-- which noops SetTexture per region as well -- whatever swaps the tex coord on
-- a state change is free to re-art the region), and the enabled/disabled
-- distinction the atlas was carrying has to be re-created on the label.

-- GetFontString covers the templated case; the scan is for a label that was
-- added as a plain region rather than set as the button's own font string.
local function ActivateLabel(button)
	if button.CoALabel then return button.CoALabel end

	local text = button.GetFontString and button:GetFontString()

	if not text then
		for i = 1, button:GetNumRegions() do
			local region = select(i, button:GetRegions())

			if region:GetObjectType() == "FontString" then
				text = region
				break
			end
		end
	end

	button.CoALabel = text

	return text
end

-- Yellow live, grey dead: the same pair ElvUI's own templated buttons use, so
-- these read as buttons rather than as labels on a panel.
local ACTIVATE_COLOR = {1, 0.82, 0}
local ACTIVATE_DISABLED_COLOR = {0.55, 0.55, 0.55}

-- The active spec's button is disabled, and with the pill gone nothing else
-- says so -- the ElvUI panel is drawn the same either way. The label is greyed
-- instead, which is how ElvUI marks a dead button everywhere else.
--
-- IsEnabled hands back 0 and 1 on this client rather than false and true
-- (probed), and 0 is truthy in Lua, so it's normalised before it's compared
-- against the cached value. Compared rather than written blind because this
-- runs from the button's update: there's no event for a spec becoming active.
local function UpdateActivateState(button)
	local state = button:IsEnabled()
	local enabled = state ~= nil and state ~= false and state ~= 0

	if enabled == button.CoAActivateEnabled then return end
	button.CoAActivateEnabled = enabled

	local text = ActivateLabel(button)
	if not text then return end

	text:SetTextColor(unpack(enabled and ACTIVATE_COLOR or ACTIVATE_DISABLED_COLOR))
end

-- Stripped before templating, as with the dropdown pills: HandleButton adds its
-- backdrop as regions of this same button, so a strip afterwards takes the
-- backdrop with the pill.
local function SkinActivateButton(button)
	if not button then return end

	if not button.CoASkinned then
		button.CoASkinned = true

		Skin:StripArtByFile(button, Skin.RedButtonArt)
		S:HandleButton(button)

		button:HookScript("OnUpdate", UpdateActivateState)
	end

	UpdateActivateState(button)
end

-- Unlike the row's icon these are named without a literal dot
-- ("Button1ExpandedContent", "...ExpandedContentActivateButton"), read off the
-- frame stack.
--
-- The expanded content exists from the moment the menu is built rather than
-- being created when its row is expanded (probed: present, hidden, before any
-- row had been opened), so it's picked up with the rest of the row. The show
-- hook is there for a row whose content is filled in later than this first pass.
local function SkinRowExpansion(rowName)
	local content = _G[rowName.."ExpandedContent"]
	if not content then return end

	local buttonName = rowName.."ExpandedContentActivateButton"

	SkinActivateButton(_G[buttonName])

	if content.CoASkinned then return end
	content.CoASkinned = true

	content:HookScript("OnShow", function()
		SkinActivateButton(_G[buttonName])
	end)
end

-- These children are named with a literal dot ("Button1.SpecIcon"), so they
-- only come out of _G by string key, never as plain identifiers.
local function SkinMenuRows(listName)
	for i = 1, MENU_ROW_LIMIT do
		local rowName = listName.."ScrollFrameButton"..i
		local row = _G[rowName]
		if not row then break end

		SkinMenuRow(row)
		SkinMenuRowIcon(_G[rowName..".SpecIcon"])
		SkinRowExpansion(rowName)
	end
end

-- S:HandleScrollBar can't be used on these: it assumes the thumb is a texture
-- and calls SetTexture on it, but this thumb is a button, so the call errors
-- and takes the rest of the OnShow skinning down with it.
--
-- It's a proportional scrollbar: the thumb is drawn as three slices that the
-- widget re-applies whenever it resizes, so stripping them doesn't hold. The
-- slices are made transparent instead and a value-coloured panel is stretched
-- from the first to the last, which is how ElvUI handles the same widget in
-- HandleProportionalScroll. Slices are looked up as fields and as globals,
-- since only the global names are confirmed here.
local function SkinScrollThumb(thumb, thumbName)
	if not thumb or thumb.backdrop then return end

	local first = thumb.Begin or _G[thumbName.."Begin"]
	local last = thumb.End or _G[thumbName.."End"]
	local middle = thumb.Middle or _G[thumbName.."Middle"]

	if first then first:SetAlpha(0) end
	if last then last:SetAlpha(0) end
	if middle then middle:SetAlpha(0) end

	local r, g, b = unpack(E.media.rgbvaluecolor)

	thumb:CreateBackdrop("Transparent")
	thumb.backdrop:SetFrameLevel(thumb:GetFrameLevel() + 1)
	thumb.backdrop:SetBackdropColor(r, g, b, 0.25)

	if first and last then
		thumb.backdrop:Point("TOPLEFT", first)
		thumb.backdrop:Point("BOTTOMRIGHT", last)
	end

	thumb:HookScript("OnEnter", function(self)
		if self.backdrop then self.backdrop:SetBackdropColor(r, g, b, 0.75) end
	end)

	thumb:HookScript("OnLeave", function(self)
		if self.backdrop then self.backdrop:SetBackdropColor(r, g, b, 0.25) end
	end)
end

-- The scroll arrows come back as Blizzard chevrons after the list refreshes,
-- and it isn't the ElvUI arrow being overwritten -- that texture is still in
-- place underneath. The button's native art is a region StripTextures hid, and
-- the scroll frame shows it again whenever it recalculates.
--
-- Matched by file rather than as "any region that isn't one of ours": on this
-- client ElvUI's own panel and border pieces are regions of the button too, so
-- hiding everything unrecognised would take the ElvUI square with it.
--
-- Compared case-insensitively: the client hands paths back from GetTexture in
-- whatever case it stored them, not the case they were set in.
local ARROW_TEXTURE = E.Media.Textures.ArrowUp:lower()
local NATIVE_SCROLL_ART = "scrollbar"

local function RestoreArrow(button)
	for i = 1, button:GetNumRegions() do
		local region = select(i, button:GetRegions())
		local texture = region.GetTexture and region:GetTexture()

		if texture and texture:lower():find(NATIVE_SCROLL_ART) and region:IsShown() then
			region:Hide()
		end
	end

	-- The arrow itself is re-pointed as well, in case a refresh reaches the
	-- state textures and not only the art it re-shows.
	for _, texture in ipairs(button.CoAArrowTextures) do
		local current = texture:GetTexture()

		if not current or current:lower() ~= ARROW_TEXTURE then
			texture:SetTexture(E.Media.Textures.ArrowUp)
			texture:SetInside(button)
			texture:SetTexCoord(0, 1, 0, 1)
			texture:SetRotation(S.ArrowRotation[button.CoAArrowDirection])
		end
	end
end

local function SkinArrow(button, direction)
	if not button or button.CoASkinned then return end
	button.CoASkinned = true

	S:HandleNextPrevButton(button, direction)

	button.CoAArrowDirection = direction
	button.CoAArrowTextures = {
		button:GetNormalTexture(),
		button:GetPushedTexture(),
		button:GetDisabledTexture()
	}

	-- Still worth closing off: whatever refreshes these would otherwise be free
	-- to swap in a fresh texture object and orphan the three above.
	button.SetNormalTexture = E.noop
	button.SetPushedTexture = E.noop
	button.SetDisabledTexture = E.noop
	button.SetHighlightTexture = E.noop

	button:HookScript("OnUpdate", RestoreArrow)
end

-- The list inside each dropdown popup: a scroll frame with the framed inset
-- and overlay art around it. The arrows are named off the scroll frame rather
-- than off the scrollbar, so they're looked up here instead.
local function SkinMenuScroll(listName)
	local scrollBar = _G[listName.."ScrollFrameScrollBar"]
	if not scrollBar then return end

	local inset = _G[listName.."Inset"]
	if inset then inset:StripTextures() end

	local overlay = _G[listName.."ScrollFrameArtOverlay"]
	if overlay then overlay:StripTextures() end

	if scrollBar.backdrop then return end

	local frameLevel = scrollBar:GetFrameLevel()

	scrollBar:Width(18)
	scrollBar:StripTextures()
	scrollBar:CreateBackdrop()
	scrollBar.backdrop:SetAllPoints()
	scrollBar.backdrop:SetFrameLevel(frameLevel)

	local up = _G[listName.."ScrollFrameScrollUpButton"]
	if up then
		up:Point("BOTTOM", scrollBar, "TOP", 0, 1)
		SkinArrow(up, "up")
	end

	local down = _G[listName.."ScrollFrameScrollDownButton"]
	if down then
		down:Point("TOP", scrollBar, "BOTTOM", 0, -1)
		SkinArrow(down, "down")
	end

	local thumbName = listName.."ScrollFrameScrollBarThumb"
	local thumb = (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()) or _G[thumbName]

	SkinScrollThumb(thumb, thumbName)
end

-- The bar's plate art (BottomBarTexture) is the dark band under the buttons,
-- and it's the bar's only region, so a plain StripTextures clears it without
-- touching the scene art, which lives on TreeView one level up. The buttons,
-- dropdowns and search box sitting on the bar are picked up by the walk.
local function SkinBottomBar()
	local bar = _G[BOTTOM_BAR]
	if not bar then return end

	bar:StripTextures()

	-- Each dropdown's caret is a child button carrying the arrow as its own
	-- art, so the walk was treating it as an ordinary button and giving it a
	-- templated square. Skinned here, ahead of the walk, so it becomes the
	-- ElvUI chevron; HandleNextPrevButton's isSkinned flag then makes the walk
	-- leave it alone. noBackdrop keeps it a bare white arrow that takes the
	-- value colour on hover, and "up" matches the way these menus open.
	for _, suffix in ipairs(BOTTOM_BAR_DROPDOWNS) do
		local dropdown = _G[BOTTOM_BAR..suffix]
		local arrow = _G[BOTTOM_BAR..suffix.."Button"]

		if arrow then
			S:HandleNextPrevButton(arrow, "up", nil, true)
			arrow:Size(20, 20)
		end

		-- These buttons are wider than they look: the label art only ever
		-- covered the part up to the arrow, so templating the whole frame drew
		-- a panel running under the icon buttons to their right. Skinned here
		-- rather than in the walk so the backdrop can be built separately and
		-- stopped at the arrow, and the dead space to its right is taken out
		-- of the hit rect so it can't swallow clicks meant for those icons.
		if dropdown and arrow then
			S:HandleButton(dropdown, nil, nil, true)

			if dropdown.backdrop then
				dropdown.backdrop:ClearAllPoints()
				dropdown.backdrop:Point("TOPLEFT", dropdown, "TOPLEFT", -1, 1)
				dropdown.backdrop:Point("BOTTOMRIGHT", arrow, "BOTTOMRIGHT", 3, -1)
			end

			local dropdownRight, arrowRight = dropdown:GetRight(), arrow:GetRight()

			if dropdownRight and arrowRight then
				dropdown:SetHitRectInsets(0, math.max(0, dropdownRight - arrowRight - 3), 0, 0)
			end
		end
	end

	-- The two dropdown popups are plain frames, which the walk descends into
	-- for their buttons but never templates, so they get their panel here.
	for _, entry in ipairs(BOTTOM_BAR_MENUS) do
		local menuName = BOTTOM_BAR..entry.menu
		local listName = menuName..entry.list
		local menu = _G[menuName]

		if menu and not menu.CoASkinned then
			menu.CoASkinned = true

			Skin:Panel(menu)
			Skin:CloseButton(_G[menuName.."Close"])

			-- Rows don't exist until the menu is first opened, which happens
			-- long after the talent frame's own OnShow, so they're picked up
			-- on the menu's.
			menu:HookScript("OnShow", function()
				SkinMenuRows(listName)
			end)
		end

		SkinMenuScroll(listName)
		SkinMenuRows(listName)
	end
end

-- The scene art belongs to TreeView, which runs on behind the bottom bar, so
-- clearing the bar's own plate left the art showing through under the
-- buttons. The pieces are stretched over the whole of TreeView and show their
-- slice of the file through tex coords, which occupy only part of it -- the
-- rest of the file holds other art. So the coords have to be trimmed in
-- proportion to their existing values rather than replaced outright, or
-- unrelated regions of the file scroll into view.
--
-- Geometry comes from TreeView and the bar rather than from the texture's own
-- rect, so that a re-run reads the same numbers instead of measuring a rect
-- it already cropped. Coords are kept from the first pass for the same reason.
local function CropTexture(tex, bar, keep)
	if not tex.CoAOriginalCoords then
		tex.CoAOriginalCoords = {tex:GetTexCoord()}
	end

	-- GetTexCoord yields the four corners: UL, LL, UR, LR. These are all
	-- axis-aligned, so the edges come off the corners that define them.
	local coords = tex.CoAOriginalCoords
	local left, top, bottom, right = coords[1], coords[2], coords[4], coords[5]

	tex:SetTexCoord(left, right, top, top + (bottom - top) * keep)
	tex:Point("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
end

local function CropBackground()
	local treeView = _G[FRAME_NAME.."TreeView"]
	local bar = _G[BOTTOM_BAR]
	if not (treeView and bar) then return end

	local treeTop, treeBottom, barTop = treeView:GetTop(), treeView:GetBottom(), bar:GetTop()
	if not (treeTop and treeBottom and barTop) then return end

	local height = treeTop - treeBottom
	if height <= 0 then return end

	local keep = (treeTop - barTop) / height
	if keep <= 0 or keep >= 1 then return end

	-- Scoped to TreeView's own regions: earlier this looked the names up as
	-- globals over a fixed range, which pulled in same-named textures owned by
	-- other frames and re-anchored those too.
	for i = 1, treeView:GetNumRegions() do
		local region = select(i, treeView:GetRegions())
		local name = region.GetName and region:GetName()

		if name and name:find("Background") and region:GetObjectType() == "Texture" then
			CropTexture(region, bar, keep)
		end
	end
end

-- The tab row is shared with the vanity and wardrobe windows and is handled in
-- Skinning.lua. The talent frame is passed as its owner while this window is
-- the open one: the tabs aren't its children, so they don't draw above its
-- panel on their own.
local function SkinTabs()
	Skin:CollectionTabs(_G[FRAME_NAME])
end

local SPEC_CHOICE = FRAME_NAME.."SpecViewPoolFrameCoASpecChoiceTemplate%d"
local MAX_SPEC_CHOICES = 10

-- Only each card's action button. The cards themselves keep their art: the
-- portraits and the gold wash on the active spec are the whole point of the
-- view, and there's nothing flat that would say the same thing.
--
-- Skinned by name because the walk can't get here -- the cards hang off a
-- PoolFrame, which EXCLUDED skips so the tree's pooled nodes stay untouched.
-- Stripped as well as templated: the red plate isn't one of the Left/Middle/
-- Right pieces HandleButton clears on its own.
local function SkinSpecChoices()
	for i = 1, MAX_SPEC_CHOICES do
		local cardName = SPEC_CHOICE:format(i)
		if not _G[cardName] then break end

		S:HandleButton(_G[cardName.."SelectButton"], true)
	end
end

local function SkinFrame(frame)
	if not frame.CoASkinned then
		frame.CoASkinned = true

		Skin:HideArt(_G[FRAME_NAME.."NineSlice"])

		-- The round portrait medallion overhangs the top-left corner and has
		-- no flat equivalent, so it goes rather than getting reskinned.
		Skin:HideArt(_G[FRAME_NAME.."PortraitFrame"])

		Skin:Panel(frame)

		-- The choice cards are pulled from the pool as the view opens, so the
		-- talent frame's own show is too early to catch them. Run on the view's
		-- show, and again a tick later in case the pool is filled after it.
		local specView = _G[FRAME_NAME.."SpecView"]
		if specView then
			specView:HookScript("OnShow", function()
				SkinSpecChoices()
				E:Delay(0.1, SkinSpecChoices)
			end)
		end

		-- Children are created lazily as tabs are visited, so the walk has to
		-- run again on every show rather than once at hook time. The isSkinned
		-- / backdrop guards inside ElvUI's handlers make re-runs cheap.
		frame:HookScript("OnShow", function(self)
			Skin:ApplyWindowScale("advancementScale")
	Skin:Title(_G[FRAME_NAME.."TitleText"])
			SkinCloseButton(self)
			SkinBottomBar()
			CropBackground()
			SkinChildren(self, 1)
			SkinTabs()
			SkinSpecChoices()
		end)
	end

	Skin:ApplyWindowScale("advancementScale")
	Skin:Title(_G[FRAME_NAME.."TitleText"])
	SkinCloseButton(frame)
	SkinBottomBar()
	-- Not CropBackground() here: this runs pre-Show now (see InitializeTalentFrame),
	-- before Blizzard's own code sets the background texture's real art-tile
	-- coords -- it's still XML-template default (full 0..1) at this point. Crop
	-- caches "original" coords on first call and never recaptures, so cropping
	-- here would permanently bake in the wrong baseline. OnShow (below) is the
	-- only place this is safe to run.
	SkinChildren(frame, 1)
	SkinTabs()
	SkinSpecChoices()
end

local function TryHook()
	local frame = _G[FRAME_NAME]
	if not frame then return false end

	SkinFrame(frame)

	return true
end

function CoA:InitializeTalentFrame()
	if not E.private.skins.blizzard.enable then return end

	Skin:OnFrameAvailable(TryHook)
end
