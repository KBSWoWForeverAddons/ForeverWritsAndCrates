-- Forever Writs and Crates: Guided Route window, Navigation Arrow, Waypoints,
-- and optional auto-accept / auto-turn-in for Craftsman's Writs.
local _, FWC = ...

local Guide = {}
FWC.RouteGuide = Guide

local GUIDE_W = 310
local MAX_ROWS = 10
local MAX_LIST_H = 340
local NEAR_YARDS = 180
local APPROACH_YARDS = 65

local guideFrame, arrowFrame
local rows = {}
local scrollOffset = 0
local lastStepIdx = nil
local activeTomTomUID = nil

local STEP_ICONS = {
	mail        = "|TInterface\\Icons\\INV_Letter_15:0|t ",
	fly         = "|TInterface\\GossipFrame\\TaxiGossipIcon:0|t ",
	boat        = "|TInterface\\Icons\\INV_Misc_Anchor:0|t ",
	zeppelin    = "|TInterface\\Icons\\INV_Misc_Bomb_04:0|t ",
	road        = "|TInterface\\MINIMAP\\POIICONS:0:0:0:0:128:128:96:112:0:16|t ",
	approach    = "|TInterface\\MINIMAP\\TRACKING\\PoiArrow:0|t ",
	hearth      = "|TInterface\\MINIMAP\\TRACKING\\Innkeeper:0|t ",
	teleport    = "|TInterface\\Icons\\Spell_Arcane_TeleportMoonglade:0|t ",
	turnin      = "|TInterface\\GossipFrame\\DailyActiveQuestIcon:0|t ",
	questTurnin = "|TInterface\\GossipFrame\\ActiveQuestIcon:0|t ",
}

local function Steps()
	return (FWC.charDB and FWC.charDB.route) or {}
end

local function Manual()
	if not FWC.charDB then return {} end
	FWC.charDB.manualSteps = FWC.charDB.manualSteps or {}
	return FWC.charDB.manualSteps
end

local function UseTomTom()
	return TomTom ~= nil and type(TomTom.AddWaypoint) == "function"
end

local function SetWaypoint(step)
	-- Native WoW User Waypoint
	pcall(function()
		if not (step and step.map and step.x and step.y) then
			if C_Map and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
			return
		end
		if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(step.map) then
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(step.map, step.x / 100, step.y / 100))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			end
		end
	end)

	-- Optional TomTom integration if installed
	if TomTom then
		pcall(function()
			if activeTomTomUID and TomTom.RemoveWaypoint then
				TomTom:RemoveWaypoint(activeTomTomUID)
				activeTomTomUID = nil
			end
			if step and step.map and step.x and step.y and TomTom.AddWaypoint then
				activeTomTomUID = TomTom:AddWaypoint(step.map, step.x / 100, step.y / 100, {
					title = step.label or step.text or "Writ Route",
					persistent = false,
					minimap = true,
					world = true,
					crazy = true,
					from = "ForeverWritsAndCrates",
				})
				if activeTomTomUID and TomTom.SetCrazyArrow then
					TomTom:SetCrazyArrow(activeTomTomUID, 15, step.label or step.text or "Writ Route")
				end
			end
		end)
	end
end

local function IsStepDone(i)
	local s = Steps()[i]
	if not s then return false end
	if Manual()[i] then return true end

	local done = false
	if s.kind == "mail" then
		if not (FWC.charDB and FWC.charDB.pendingMail) then done = true end
	elseif (s.kind == "turnin" or s.kind == "questTurnin") and s.questID then
		if FWC.Writs.IsTurnedInToday(s.questID) then
			done = true
		elseif s.kind == "questTurnin" and C_QuestLog and C_QuestLog.IsOnQuest then
			local ok, on = pcall(C_QuestLog.IsOnQuest, s.questID)
			if ok and on == false then done = true end
		end
	elseif s.kind == "fly" then
		if FWC.SafeCall(UnitOnTaxi, "player") then done = true end
		local p = FWC.Travel.PlayerPoint()
		if p and s.destMap and p.map == s.destMap and p.map ~= s.map then done = true end
	elseif s.kind == "hearth" or s.kind == "teleport" then
		local p = FWC.Travel.PlayerPoint()
		if p and s.destMap and p.map == s.destMap then done = true end
	elseif s.kind == "boat" or s.kind == "zeppelin" then
		local p = FWC.Travel.PlayerPoint()
		if p and s.destMap and p.map == s.destMap and p.map ~= s.map then done = true end
	elseif s.kind == "approach" then
		if s.map and s.x and s.y then
			local dist = FWC.Travel.VectorFromPlayer(s.map, s.x, s.y)
			if dist and dist <= APPROACH_YARDS then done = true end
		end
	elseif s.kind == "road" then
		local p = FWC.Travel.PlayerPoint()
		if p and s.destMap and p.map == s.destMap then
			done = true
		elseif s.map and s.x and s.y then
			local dist = FWC.Travel.VectorFromPlayer(s.map, s.x, s.y)
			if dist and dist <= NEAR_YARDS then done = true end
		end
	end

	if done then Manual()[i] = true end
	return done
end

--------------------------------------------------------------------------------
-- Frame Construction
--------------------------------------------------------------------------------
local function EnsureFrames()
	if guideFrame then return end

	local bd = {
		bgFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	}

	local g = CreateFrame("Frame", "FWC_RouteGuide", UIParent, "BackdropTemplate")
	g:SetWidth(GUIDE_W)
	g:SetHeight(120)
	g:SetPoint("RIGHT", UIParent, "RIGHT", -50, 100)
	g:SetMovable(true)
	g:EnableMouse(true)
	g:RegisterForDrag("LeftButton")
	g:SetClampedToScreen(true)
	g:SetBackdrop(bd)
	g:SetBackdropColor(0.07, 0.07, 0.09, 0.94)
	g:SetBackdropBorderColor(0.25, 0.55, 0.70, 1)
	g:Hide()

	-- Header bar
	local hdr = CreateFrame("Frame", nil, g, "BackdropTemplate")
	hdr:SetHeight(24)
	hdr:SetPoint("BOTTOMLEFT", g, "TOPLEFT", 0, -1)
	hdr:SetPoint("BOTTOMRIGHT", g, "TOPRIGHT", 0, -1)
	hdr:SetBackdrop(bd)
	hdr:SetBackdropColor(0.04, 0.08, 0.12, 0.98)
	hdr:SetBackdropBorderColor(0.25, 0.55, 0.70, 1)
	hdr:EnableMouse(true)
	hdr:RegisterForDrag("LeftButton")

	local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", 8, 0)
	title:SetText("Forever Writs Route")
	g.Title = title

	local closeBtn = CreateFrame("Button", nil, hdr, "UIPanelCloseButton")
	closeBtn:SetSize(20, 20)
	closeBtn:SetPoint("RIGHT", -2, 0)
	closeBtn:SetScript("OnClick", function() Guide.Hide() end)

	local clearBtn = CreateFrame("Button", nil, hdr)
	clearBtn:SetSize(16, 16)
	clearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
	clearBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	clearBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	clearBtn:SetScript("OnClick", function() Guide.Clear() end)
	clearBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Clear Route")
		GameTooltip:Show()
	end)
	clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local planBtn = CreateFrame("Button", nil, hdr)
	planBtn:SetSize(16, 16)
	planBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
	planBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
	planBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	planBtn:SetScript("OnClick", function() if FWC.PlannerWindow then FWC.PlannerWindow.Toggle() end end)
	planBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Open Planner")
		GameTooltip:Show()
	end)
	planBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local countText = hdr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	countText:SetPoint("RIGHT", planBtn, "LEFT", -6, 0)
	g.Count = countText

	local function SaveGuidePos()
		g:StopMovingOrSizing()
		if FWC.charDB then
			local p, _, rp, x, y = g:GetPoint()
			FWC.charDB.guidePos = { p, rp, x, y }
		end
	end
	g:SetScript("OnDragStart", function() g:StartMoving() end)
	g:SetScript("OnDragStop", SaveGuidePos)
	hdr:SetScript("OnDragStart", function() g:StartMoving() end)
	hdr:SetScript("OnDragStop", SaveGuidePos)

	g:EnableMouseWheel(true)
	g:SetScript("OnMouseWheel", function(_, delta)
		scrollOffset = scrollOffset - delta
		Guide.Refresh()
	end)

	for r = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, g, "BackdropTemplate")
		row:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8" })
		row.Num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.Num:SetPoint("TOPLEFT", 6, -5)
		row.Num:SetWidth(20)
		row.Num:SetJustifyH("LEFT")

		row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.Text:SetPoint("TOPLEFT", 26, -5)
		row.Text:SetWidth(GUIDE_W - 58)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetJustifyV("TOP")
		row.Text:SetSpacing(2)

		row.Check = CreateFrame("Button", nil, row)
		row.Check:SetSize(16, 16)
		row.Check:SetPoint("TOPRIGHT", -6, -4)
		row.Check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		row.Check:SetScript("OnClick", function()
			if not row.stepIndex then return end
			local m = Manual()
			m[row.stepIndex] = not m[row.stepIndex] or nil
			Guide.Refresh()
		end)
		rows[r] = row
	end

	-- Draggable Navigation Arrow
	local a = CreateFrame("Frame", "FWC_RouteArrow", UIParent)
	a:SetSize(44, 44)
	a:SetPoint("TOP", UIParent, "TOP", 0, -120)
	a:SetMovable(true)
	a:EnableMouse(true)
	a:RegisterForDrag("LeftButton")
	a:SetClampedToScreen(true)
	a:SetScript("OnDragStart", a.StartMoving)
	a:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if FWC.charDB then
			local p, _, rp, x, y = self:GetPoint()
			FWC.charDB.arrowPos = { p, rp, x, y }
		end
	end)
	a.Tex = a:CreateTexture(nil, "ARTWORK")
	a.Tex:SetAllPoints()
	a.Tex:SetTexture("Interface\\Minimap\\MinimapArrow")
	a.Text = a:CreateFontString(nil, "OVERLAY")
	a.Text:SetFont(GameFontNormal:GetFont(), 11, "OUTLINE")
	a.Text:SetPoint("TOP", a, "BOTTOM", 0, -4)
	a.Text:SetJustifyH("CENTER")
	a:Hide()

	local poll = 0
	g:SetScript("OnUpdate", function(_, elapsed)
		poll = poll + elapsed
		if poll > 0.6 then
			poll = 0
			Guide.Refresh()
		end
	end)

	local tick = 0
	a:SetScript("OnUpdate", function(self, elapsed)
		tick = tick + elapsed
		if tick < 0.04 then return end
		tick = 0

		local curIdx = FWC.charDB and FWC.charDB.currentStep or 1
		local step = Steps()[curIdx]
		if not (step and step.map and step.x and step.y) then
			self.Tex:SetAlpha(0)
			self.Text:SetText("")
			return
		end
		local dist, angle = FWC.Travel.VectorFromPlayer(step.map, step.x, step.y)
		if not dist then
			self.Tex:SetAlpha(angle == "continent" and 0.35 or 0)
			self.Tex:SetRotation(0)
			self.Text:SetText((step.label or "Target") .. "\n" .. (angle == "continent" and "|cffff6633Other Continent|r" or "..."))
			return
		end
		if dist < 12 then
			self.Tex:SetAlpha(0)
			self.Text:SetText((step.label or "Target") .. "\n|cff40ff40Here!|r")
			return
		end
		local facing = FWC.SafeCall(GetPlayerFacing)
		if facing and angle then
			self.Tex:SetAlpha(1)
			self.Tex:SetRotation(angle - facing)
		else
			self.Tex:SetAlpha(0)
		end
		self.Text:SetText(string.format("%s\n(%d yd)", step.label or "Target", math.floor(dist)))
	end)

	guideFrame = g
	arrowFrame = a
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function Guide.Refresh()
	if not guideFrame or not FWC.charDB then return end
	local list = Steps()
	local cur = 1
	while list[cur] and IsStepDone(cur) do cur = cur + 1 end

	FWC.charDB.currentStep = cur
	guideFrame.Title:SetText(FWC.charDB.routeTitle or "Forever Writs Route")
	scrollOffset = math.max(1 - cur, math.min(scrollOffset, #list - cur))
	guideFrame.Count:SetText(#list > 0 and string.format("%d/%d", math.min(cur, #list), #list) or "0/0")

	if cur ~= lastStepIdx then
		lastStepIdx = cur
		scrollOffset = 0
		SetWaypoint(list[cur])
	end

	local y = -4
	local full = false
	for r = 1, MAX_ROWS do
		local row = rows[r]
		local idx = cur + scrollOffset + r - 1
		local step = (not full) and list[idx] or nil
		row.stepIndex = step and idx or nil
		if step then
			row:Show()
			if idx == cur then
				row:SetBackdropColor(0.10, 0.28, 0.32, 1)
			else
				row:SetBackdropColor(0.11, 0.11, 0.13, 0.9)
			end
			row.Num:SetText(idx)
			row.Text:SetText((STEP_ICONS[step.kind] or "") .. (step.text or ""))
			row.Text:SetAlpha(idx == cur and 1 or (idx < cur and 0.45 or 0.75))
			row.Check:SetNormalTexture(Manual()[idx] and "Interface\\Buttons\\UI-CheckBox-Check" or "Interface\\Buttons\\UI-CheckBox-Up")
			local h = math.max(26, row.Text:GetStringHeight() + 10)
			if r > 1 and (-y + h) > MAX_LIST_H then
				full = true
				row:Hide()
				row.stepIndex = nil
			else
				row:SetHeight(h)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 4, y)
				row:SetPoint("TOPRIGHT", -4, y)
				y = y - h - 2
			end
		else
			row:Hide()
		end
	end

	if not list[cur] then
		local row = rows[1]
		row:Show()
		row.stepIndex = nil
		row:SetBackdropColor(0.10, 0.28, 0.22, 1)
		row.Num:SetText("")
		if #list == 0 then
			row.Text:SetText("No active route. Open the Planner (map icon above) or run /fwc route for your bag writs.")
		else
			row.Text:SetText("|cff40ff40All route steps complete!|r Click Clear or close with X.")
		end
		row.Text:SetAlpha(1)
		row:SetHeight(36)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 4, -4)
		row:SetPoint("TOPRIGHT", -4, -4)
		y = -44
		arrowFrame:Hide()
	elseif guideFrame:IsShown() then
		if UseTomTom() then
			arrowFrame:Hide()
		else
			arrowFrame:Show()
		end
	end

	guideFrame:SetHeight(-y + 6)
end

function Guide.StartPlan(plan, titleText)
	EnsureFrames()
	if not FWC.charDB then return end
	FWC.charDB.route = plan.steps or {}
	FWC.charDB.routeTitle = titleText or "Writ Route"
	FWC.charDB.manualSteps = {}
	lastStepIdx = nil
	if FWC.charDB.pendingMail then
		FWC.Print("|cffffd100Reminder:|r Check your mailbox before leaving town—you have uncollected AH purchases!")
	end
	Guide.Show()
end

function Guide.Clear()
	if not FWC.charDB then return end
	FWC.charDB.route = {}
	FWC.charDB.manualSteps = {}
	lastStepIdx = nil
	SetWaypoint(nil)
	Guide.Refresh()
	FWC.Print("Route cleared.")
end

function Guide.Show()
	EnsureFrames()
	if FWC.charDB then FWC.charDB.guideShown = true end
	guideFrame:Show()
	Guide.Refresh()
end

function Guide.Hide()
	if FWC.charDB then FWC.charDB.guideShown = false end
	if guideFrame then guideFrame:Hide() end
	if arrowFrame then arrowFrame:Hide() end
end

function Guide.Toggle()
	EnsureFrames()
	if guideFrame:IsShown() then Guide.Hide() else Guide.Show() end
end

--------------------------------------------------------------------------------
-- Auto-Accept & Auto-Turn-in for Craftsman's Writs
--------------------------------------------------------------------------------
local function IsWritQuest(questID)
	return questID and FWC.GetWritByQuest(questID) ~= nil
end

FWC.On("QUEST_DETAIL", function()
	if not (FWC.db and FWC.db.autoQuest) then return end
	local qid = GetQuestID and GetQuestID()
	if IsWritQuest(qid) and AcceptQuest then
		AcceptQuest()
	end
end)

FWC.On("QUEST_PROGRESS", function()
	if not (FWC.db and FWC.db.autoQuest) then return end
	local qid = GetQuestID and GetQuestID()
	if IsWritQuest(qid) and IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
		CompleteQuest()
	end
end)

FWC.On("QUEST_COMPLETE", function()
	if not (FWC.db and FWC.db.autoQuest) then return end
	local qid = GetQuestID and GetQuestID()
	if IsWritQuest(qid) and GetQuestReward then
		GetQuestReward(1)
	end
end)

FWC.On("PLAYER_LOGIN", function()
	EnsureFrames()
	if FWC.charDB then
		local gp = FWC.charDB.guidePos
		if gp then
			guideFrame:ClearAllPoints()
			guideFrame:SetPoint(gp[1], UIParent, gp[2], gp[3], gp[4])
		end
		local ap = FWC.charDB.arrowPos
		if ap then
			arrowFrame:ClearAllPoints()
			arrowFrame:SetPoint(ap[1], UIParent, ap[2], ap[3], ap[4])
		end
		if FWC.charDB.guideShown and #Steps() > 0 then
			Guide.Show()
		end
	end
end)

FWC.On("QUEST_TURNED_IN", function() FWC.After(0.4, Guide.Refresh) end)
FWC.On("ZONE_CHANGED_NEW_AREA", function() FWC.After(0.5, Guide.Refresh) end)
