-- Forever Writs and Crates: Draggable minimap button.
local _, FWC = ...

local Mini = {}
FWC.MinimapButton = Mini

local btn

local function PlaceButton()
	if not (btn and Minimap and Minimap.GetWidth) then return end
	local angle = math.rad((FWC.db and FWC.db.minimap and FWC.db.minimap.angle) or 210)
	local rx = (Minimap:GetWidth() or 140) / 2 + 8
	local ry = (Minimap:GetHeight() or 140) / 2 + 8
	local x = math.cos(angle) * rx
	local y = math.sin(angle) * ry
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateButton()
	if btn or not Minimap then return btn end
	local b = CreateFrame("Button", "FWC_MinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")

	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("CENTER", 0, 0)
	bg:SetTexture(FWC.CRATE_ICON)
	bg:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local sc = Minimap:GetEffectiveScale()
			if FWC.db and FWC.db.minimap then
				FWC.db.minimap.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
			end
			PlaceButton()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			if FWC.RouteGuide then FWC.RouteGuide.Toggle() end
		else
			if FWC.PlannerWindow then FWC.PlannerWindow.Toggle() end
		end
	end)

	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Forever Writs and Crates", 1, 0.82, 0)
		GameTooltip:AddLine("Left-click: Open Planner & Calculator", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Toggle Route Guide", 1, 1, 1)
		GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	btn = b
	PlaceButton()
	return b
end

function Mini.ApplyVisibility()
	CreateButton()
	if not btn then return end
	local show = not FWC.db or not FWC.db.minimap or FWC.db.minimap.shown ~= false
	btn:SetShown(show)
	PlaceButton()
end

function Mini.Toggle()
	if FWC.db and FWC.db.minimap then
		FWC.db.minimap.shown = not FWC.db.minimap.shown
	end
	Mini.ApplyVisibility()
end

FWC.On("PLAYER_LOGIN", function()
	Mini.ApplyVisibility()
end)
