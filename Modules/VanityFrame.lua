local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local CoA = E:GetModule("CoA")
local Skin = CoA.Skin

local FRAME_NAME = "StoreCollectionFrame"

-- Confirmed live by probing size/position: these two OVERLAY "Portrait2"
-- regions sit at the currency counters (aligned with SPCounterHintButton and
-- DPCounterHintButton), not at the top-left corner. An earlier version of
-- this matched them as the portrait and stripped them, which blanked the
-- counter badges instead. Whatever the real top-left portrait is hasn't been
-- identified yet -- it isn't among StoreCollectionFrame's own regions or
-- children -- so nothing removes it for now.

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

-- The filter pill and its popout are the shared dropdown widget; see
-- Skinning.lua for why S:HandleButton alone can't clear it.
local function SkinDropdown()
	Skin:Dropdown(_G[FRAME_NAME.."Dropdown"], _G[FRAME_NAME.."DropdownMenu"])
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

local function SkinContents()
	Skin:Title(_G[FRAME_NAME.."TitleText"])
	Skin:CloseButton(_G[FRAME_NAME.."CloseButton"])
	SkinActionButtons()
	SkinSearchBox()
	SkinDropdown()
	SkinPagerArrows()
end

local function SkinFrame(frame)
	if not frame.CoASkinned then
		frame.CoASkinned = true

		-- Templated without stripping, unlike the talent and wardrobe frames:
		-- the currency counters are drawn as regions of the frame itself (see
		-- the note at the top of this file), so a strip blanks them.
		Skin:Panel(frame, true)

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

function CoA:InitializeVanityFrame()
	if not E.private.skins.blizzard.enable then return end

	Skin:OnFrameAvailable(TryHook)
end
