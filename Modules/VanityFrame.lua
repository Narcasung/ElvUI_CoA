local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")

local FRAME_NAME = "StoreCollectionFrame"

-- Confirmed live by probing size/position: these two OVERLAY "Portrait2"
-- regions sit at the currency counters (aligned with SPCounterHintButton and
-- DPCounterHintButton), not at the top-left corner. An earlier version of
-- this matched them as the portrait and stripped them, which blanked the
-- counter badges instead. Whatever the real top-left portrait is hasn't been
-- identified yet -- it isn't among StoreCollectionFrame's own regions or
-- children -- so nothing removes it for now.

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

-- Standard UIPanelButtonTemplate art (FontString + Normal/Pushed/Disabled/
-- Highlight textures), confirmed by probe -- S:HandleButton's own texture
-- clearing handles these directly, no manual stripping needed.
local function SkinActionButtons()
	S:HandleButton(_G[FRAME_NAME.."ActivateStoreButton"])
	S:HandleButton(_G[FRAME_NAME.."BuyStoreButton"])
end

local function SkinSearchBox()
	S:HandleEditBox(_G[FRAME_NAME.."SearchBox"])
end

-- Unlike the action buttons, the dropdown's art is nine anonymous
-- "Silver-Button-Up"/"-Highlight" slices rather than named Left/Middle/Right
-- fields or a Normal/Pushed/Disabled texture set, so S:HandleButton's own
-- clearing can't reach them and a blind StripTextures would take the arrow
-- and label with them (the same mistake made on the portrait). Matched by
-- texture path instead, same fix as the portrait.
--
-- The native mouse-down handler re-sets one of these regions to a pressed
-- variant of the same file on every click, which is why the pill came back
-- skinless while held. SetTexture is noop'd per region after clearing it,
-- the same trick TalentFrame uses on rows the pool keeps re-arting.
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

local function SkinDropdown()
	local dropdown = _G[FRAME_NAME.."Dropdown"]
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

	local menu = _G[FRAME_NAME.."DropdownMenu"]
	if menu and not menu.CoASkinned then
		menu.CoASkinned = true

		-- Panel only, matching how the talent frame's own popup menus are
		-- treated -- the option rows inside are a later pass.
		menu:StripTextures()
		menu:SetTemplate("Transparent")
	end
end

-- Neither pager button is named (both are anonymous children of
-- CollectionList), so direction is worked out from their own anchor offset
-- rather than a name match, and re-checked on every pass instead of cached --
-- cheap, and self-corrects if the two ever come back in a different order.
local function SkinPagerArrows()
	local list = _G[FRAME_NAME.."CollectionList"]
	if not list then return end

	local a, b = select(3, list:GetChildren()), select(4, list:GetChildren())
	if not (a and b and a:GetObjectType() == "Button" and b:GetObjectType() == "Button") then return end

	local _, _, _, ax = a:GetPoint()
	local _, _, _, bx = b:GetPoint()

	local prevButton, nextButton = a, b
	if bx and ax and bx < ax then
		prevButton, nextButton = b, a
	end

	S:HandleNextPrevButton(prevButton, "left")
	S:HandleNextPrevButton(nextButton, "right")
end

local function SkinFrame(frame)
	if not frame.CoASkinned then
		frame.CoASkinned = true

		frame:SetTemplate("Transparent")

		frame:HookScript("OnShow", function(self)
			SkinCloseButton(self)
			SkinActionButtons()
			SkinSearchBox()
			SkinDropdown()
			SkinPagerArrows()
		end)
	end

	SkinCloseButton(frame)
	SkinActionButtons()
	SkinSearchBox()
	SkinDropdown()
	SkinPagerArrows()
end

local function TryHook()
	local frame = _G[FRAME_NAME]
	if not frame then return false end

	SkinFrame(frame)

	return true
end

function CoA:InitializeVanityFrame()
	if not E.private.skins.blizzard.enable then return end
	if TryHook() then return end

	self.vanityFrameTimer = self:ScheduleRepeatingTimer(function()
		if TryHook() then
			self:CancelTimer(self.vanityFrameTimer)
			self.vanityFrameTimer = nil
		end
	end, 0.5)
end
