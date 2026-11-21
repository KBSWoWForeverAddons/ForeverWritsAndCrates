-- Forever Writs and Crates: Unified Reputation/Route Planner & Favor/Zone Calculator.
-- Features auto-populated reputation goals (next standing automatically),
-- Fastest Route vs Cheapest Plan cards, My Bag Writs route button,
-- and one-click AH Browse-list purchasing right from any planned row.
local _, FWC = ...

local PlannerUI = {}
FWC.PlannerWindow = PlannerUI

local WIN_W, WIN_H = 510, 560
local ROW_H = 42
local TAB_PADDING = 18
local MIN_TAB_W = 80
local TAB_GAP = 10

local frame
local activeTab = "rep" -- "rep", "favor", "zones", "quests"
local manualStanding = nil -- nil = Auto next standing!
local selectedPlanKind = "fastest" -- "fastest" or "cheapest"
local lastRepResult = nil

local function ResizeTabs(f)
	if not PanelTemplates_TabResize or type(f.Tabs) ~= "table" then return end
	for _, t in ipairs(f.Tabs) do
		pcall(PanelTemplates_TabResize, t, TAB_PADDING, nil, MIN_TAB_W)
	end
end

--------------------------------------------------------------------------------
-- Zone Grouping (Tab 3)
--------------------------------------------------------------------------------
local function BuildZoneRows()
	local book = FWC.Prices()
	local groups, byMap, unknown = {}, {}, nil

	for _, w in ipairs(FWC.WritsList()) do
		local eval = FWC.Valuation.EvaluateWrit(book, w)
		local loc = FWC.Writs.Location(w)
		local map = loc and loc.map
		local grp
		if map then
			grp = byMap[map]
			if not grp then
				grp = { map = map, name = FWC.MapName(map), writs = {}, count = 0, rep = 0, cost = 0, priced = 0 }
				byMap[map] = grp
				groups[#groups + 1] = grp
			end
		else
			unknown = unknown or { name = "Unknown Hand-in Zone", writs = {}, count = 0, rep = 0, cost = 0, priced = 0, unknown = true }
			grp = unknown
		end
		grp.writs[#grp.writs + 1] = eval
		grp.count = grp.count + 1
		if eval.rep then grp.rep = grp.rep + eval.rep end
		if eval.total then
			grp.cost = grp.cost + eval.total
			grp.priced = grp.priced + 1
		end
	end

	table.sort(groups, function(a, b) return a.name < b.name end)
	if unknown then groups[#groups + 1] = unknown end

	local rows = {}
	for _, grp in ipairs(groups) do
		table.sort(grp.writs, function(a, b)
			local ta = FWC.TIER_ORDER[a.writ.tier] or 9
			local tb = FWC.TIER_ORDER[b.writ.tier] or 9
			if ta ~= tb then return ta < tb end
			return FWC.ItemName(a.id) < FWC.ItemName(b.id)
		end)
		rows[#rows + 1] = { mode = "zoneHeader", group = grp }
		for _, eval in ipairs(grp.writs) do
			rows[#rows + 1] = { mode = "zoneWrit", eval = eval }
		end
	end
	return rows
end

--------------------------------------------------------------------------------
-- Row Rendering & Click-to-Search in AH
--------------------------------------------------------------------------------
local function OnRowClick(row)
	if not row then return end
	if row.mode == "questPick" and row.qStop then
		local qid = row.qStop.questID
		local nowSelected = not FWC.RoutePlanner.IsQuestSelected(row.qStop)
		FWC.RoutePlanner.SetQuestSelected(qid, nowSelected)
		PlannerUI.Refresh()
		return
	end
	local entry
	if row.mode == "repStop" and row.stop then
		if row.stop.kind == "quest" then return end
		entry = row.stop.writ
	elseif row.mode == "favorPick" and row.pick and row.pick.offer then
		entry = row.pick.offer.entry
	elseif row.mode == "zoneWrit" and row.eval then
		entry = row.eval.writ
	end
	if entry then
		FWC.Scanner.ShowInAuctionHouse(entry)
	end
end

local function OnRowEnter(btn)
	local row = btn.row
	if not row or not GameTooltip then return end
	local tip = GameTooltip
	tip:SetOwner(btn, "ANCHOR_RIGHT")
	if row.mode == "repStop" and row.stop then
		if row.stop.kind == "quest" then
			tip:AddLine(row.stop.title or "Completed Quest", 1, 0.82, 0)
			tip:AddLine("Completed quest in your quest log", 0.4, 1, 0.4)
			if row.stop.loc then
				tip:AddLine(string.format("Turn in: %s (%.1f, %.1f)",
					row.stop.loc.zoneName or FWC.MapName(row.stop.loc.map), row.stop.loc.x or 0, row.stop.loc.y or 0), 0.9, 0.9, 0.9)
			end
		else
			local eval = FWC.Valuation.EvaluateWrit(FWC.Prices(), row.stop.writ)
			tip:AddLine(FWC.ItemName(row.stop.writ.id), FWC.QualityColor(eval.quality))
			tip:AddLine(" ")
			if FWC.AuctionPanel then FWC.AuctionPanel.AddWritTooltipLines(tip, eval) end
			tip:AddLine(" ")
			tip:AddLine("Click (at AH): open writ & item in AH Browse list with auto quantity.", 0.6, 0.8, 1, true)
		end
	elseif row.mode == "favorPick" and row.pick then
		local crate = row.pick.offer.entry
		local eval = FWC.Valuation.EvaluateCrate(FWC.Prices(), crate)
		tip:AddLine(FWC.ItemName(crate.id), FWC.QualityColor(eval.quality))
		tip:AddLine(" ")
		if FWC.AuctionPanel then FWC.AuctionPanel.AddCrateTooltipLines(tip, eval) end
		tip:AddLine(" ")
		tip:AddLine("Click (at AH): open crate & materials in AH Browse list.", 0.6, 0.8, 1, true)
	elseif row.mode == "zoneWrit" and row.eval then
		tip:AddLine(FWC.ItemName(row.eval.id), FWC.QualityColor(row.eval.quality))
		local prof = FWC.Writs.ProfessionsText(row.eval.writ)
		local tier = FWC.TIER_LABELS[row.eval.writ.tier] or ""
		if prof then tip:AddLine(prof .. " · " .. tier, 0.8, 0.8, 0.8) end
		tip:AddLine(" ")
		if FWC.AuctionPanel then FWC.AuctionPanel.AddWritTooltipLines(tip, row.eval) end
		tip:AddLine(" ")
		tip:AddLine("Click (at AH): open writ & item in AH Browse list.", 0.6, 0.8, 1, true)
	elseif row.mode == "zoneHeader" and row.group then
		tip:AddLine(row.group.name, 1, 0.82, 0)
		tip:AddLine(string.format("%d writs, %s total rep", row.group.count, FWC.FormatNumber(row.group.rep)), 0.9, 0.9, 0.9)
	elseif row.mode == "questPick" and row.qStop then
		local q = row.qStop
		tip:AddLine(q.title or "Completed Quest", 1, 0.82, 0)
		if q.isDungeon then
			tip:AddLine("Dungeon quest (excluded by default)", 1, 0.45, 0.25)
		elseif q.isRaid then
			tip:AddLine("Raid quest (excluded by default)", 1, 0.45, 0.25)
		else
			tip:AddLine("Open-world completed quest", 0.4, 1, 0.4)
		end
		if q.loc then
			tip:AddLine(string.format("Turn in: %s (%.1f, %.1f)", q.loc.zoneName, q.loc.x, q.loc.y), 0.9, 0.9, 0.9)
		else
			tip:AddLine("No turn-in map pin available (cannot route)", 0.7, 0.7, 0.7)
		end
		tip:AddLine("Click to include or exclude from your route.", 0.6, 0.8, 1)
	end
	tip:Show()
end

local function InitRow(btn, row)
	if not btn.Icon then
		btn:SetHeight(ROW_H)
		btn.Back = btn:CreateTexture(nil, "BACKGROUND")
		btn.Back:SetAllPoints(btn)
		btn.Back:SetColorTexture(1, 0.82, 0, 0.10)
		btn.Back:Hide()

		btn.Icon = btn:CreateTexture(nil, "ARTWORK")
		btn.Icon:SetSize(28, 28)
		btn.Icon:SetPoint("LEFT", btn, "LEFT", 4, 0)

		btn.RightTop = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		btn.RightTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -4)
		btn.RightTop:SetJustifyH("RIGHT")

		btn.RightSub = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		btn.RightSub:SetPoint("TOPRIGHT", btn.RightTop, "BOTTOMRIGHT", 0, -2)
		btn.RightSub:SetJustifyH("RIGHT")
		btn.RightSub:SetTextColor(0.7, 0.7, 0.7)

		btn.Name = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		btn.Name:SetPoint("TOPLEFT", btn.Icon, "TOPRIGHT", 6, 2)
		btn.Name:SetPoint("RIGHT", btn.RightTop, "LEFT", -6, 0)
		btn.Name:SetJustifyH("LEFT")
		btn.Name:SetWordWrap(false)

		btn.Sub = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		btn.Sub:SetPoint("TOPLEFT", btn.Name, "BOTTOMLEFT", 0, -2)
		btn.Sub:SetPoint("RIGHT", btn.RightSub, "LEFT", -6, 0)
		btn.Sub:SetJustifyH("LEFT")
		btn.Sub:SetWordWrap(false)
		btn.Sub:SetTextColor(0.75, 0.75, 0.75)

		btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		btn:SetScript("OnClick", function(self) OnRowClick(self.row) end)
		btn:SetScript("OnEnter", OnRowEnter)
		btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	end

	btn.row = row
	btn.Back:Hide()

	if row.mode == "repStop" then
		local s = row.stop
		if s.kind == "quest" then
			btn.Icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
			btn.Name:SetText(string.format("%d. |cffffd100[Quest]|r %s", row.index, s.title or "Completed Quest"))
			btn.Name:SetTextColor(1, 0.92, 0.4)
			local zone = (s.loc and s.loc.zoneName) or "?"
			btn.Sub:SetText(string.format("Completed Quest Turn-in  |  %s (%.1f, %.1f)", zone, s.pos.x, s.pos.y))
			btn.RightTop:SetText("|cff40ff40Ready|r")
			btn.RightSub:SetText("Quest")
		else
			local info = FWC.ItemInfo(s.writ.id)
			btn.Icon:SetTexture(info.icon or FWC.WRIT_ICON)
			local tag = s.owned and "|cff40ff40[Owned]|r " or "|cffffd100[Buy]|r "
			btn.Name:SetText(string.format("%d. %s%s", row.index, tag, FWC.ItemName(s.writ.id)))
			btn.Name:SetTextColor(1, 1, 1)

			local needText = ""
			if s.writ.needs and s.writ.needs[1] then
				local n = s.writ.needs[1]
				local have = FWC.BagCount(n.item)
				local itemColor = (have >= n.count) and "|cff40ff40" or "|cffffaa44"
				needText = string.format("%s%dx %s|r", itemColor, n.count, FWC.ItemName(n.item))
			end
			local zone = (s.loc and s.loc.zoneName) or "?"
			local npc = (s.loc and s.loc.npcName) or ""
			btn.Sub:SetText(needText .. "  |  " .. zone .. (npc ~= "" and (" (" .. npc .. ")") or ""))

			btn.RightTop:SetText(s.cost > 0 and FWC.FormatMoney(s.cost) or "|cff40ff40Ready|r")
			btn.RightSub:SetText("+" .. s.rep .. " rep")
		end

	elseif row.mode == "favorPick" then
		local p = row.pick
		local offer = p.offer
		local info = FWC.ItemInfo(offer.entry.id)
		btn.Icon:SetTexture(info.icon or FWC.CRATE_ICON)
		btn.Name:SetText(string.format("%d x %s", p.n, FWC.ItemName(offer.entry.id)))
		btn.Name:SetTextColor(FWC.QualityColor(FWC.ItemQuality(offer.entry.id, offer.entry.quality)))
		btn.Sub:SetText(string.format("with %d x %s", offer.bundle.count * p.n, FWC.ItemName(offer.item)))
		btn.RightTop:SetText(FWC.FormatMoney(p.cost))
		btn.RightSub:SetText(FWC.FormatNumber(p.value) .. " favor")

	elseif row.mode == "zoneHeader" then
		local g = row.group
		btn.Back:Show()
		btn.Icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
		btn.Name:SetText(g.name)
		btn.Name:SetTextColor(1, 0.82, 0)
		btn.Sub:SetText(string.format("%d writs · %s rep", g.count, FWC.FormatNumber(g.rep)))
		btn.RightTop:SetText(g.priced > 0 and FWC.FormatMoney(g.cost) or "")
		btn.RightSub:SetText(g.priced > 0 and string.format("%d/%d priced", g.priced, g.count) or "")

	elseif row.mode == "zoneWrit" then
		local e = row.eval
		local info = FWC.ItemInfo(e.id)
		btn.Icon:SetTexture(info.icon or FWC.WRIT_ICON)
		btn.Name:SetText(FWC.ItemName(e.id))
		local r, g, b = FWC.QualityColor(e.quality)
		if FWC.Writs.IsAccepted(e.writ) then r, g, b = 1, 0.82, 0
		elseif FWC.Writs.IsTurnedInToday(e.writ) then r, g, b = 0.5, 0.5, 0.5 end
		btn.Name:SetTextColor(r, g, b)

		local parts = {}
		local prof = FWC.Writs.ProfessionsText(e.writ)
		if prof then parts[#parts + 1] = prof end
		parts[#parts + 1] = FWC.TIER_LABELS[e.writ.tier] or ""
		local loc = FWC.Writs.Location(e.writ)
		if loc and loc.npcName then parts[#parts + 1] = loc.npcName end
		btn.Sub:SetText(table.concat(parts, " · "))
		btn.RightTop:SetText(e.total and FWC.FormatMoney(e.total) or "-")
		btn.RightSub:SetText(e.rep and ("+" .. e.rep .. " rep") or "")

	elseif row.mode == "questPick" then
		local q = row.qStop
		local checked = FWC.RoutePlanner.IsQuestSelected(q)
		btn.Icon:SetTexture(checked and "Interface\\Buttons\\UI-CheckBox-Check" or "Interface\\Buttons\\UI-CheckBox-Up")
		local tag = q.isDungeon and "|cffff6633[Dungeon]|r " or (q.isRaid and "|cffff4444[Raid]|r " or "")
		btn.Name:SetText(tag .. (q.title or "Completed Quest"))
		if not q.pos then
			btn.Name:SetTextColor(0.5, 0.5, 0.5)
		elseif checked then
			btn.Name:SetTextColor(1, 0.92, 0.4)
		else
			btn.Name:SetTextColor(0.7, 0.7, 0.7)
		end
		if q.loc then
			btn.Sub:SetText(string.format("Turn in: %s (%.1f, %.1f)", q.loc.zoneName, q.loc.x, q.loc.y))
		else
			btn.Sub:SetText("No map pin found for turn-in")
		end
		btn.RightTop:SetText(checked and "|cff40ff40Included|r" or "|cff888888Skipped|r")
		btn.RightSub:SetText(q.isDungeon and "Dungeon" or (q.isRaid and "Raid" or "Open World"))
	end
end

--------------------------------------------------------------------------------
-- Frame Construction
--------------------------------------------------------------------------------
local function CreateCard(parent, width, titleText, onClick)
	local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
	card:SetSize(width, 62)
	card:SetBackdrop({
		bgFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeSize = 1,
	})
	card:SetBackdropColor(0.10, 0.10, 0.12, 0.9)
	card:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)

	card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	card.Title:SetPoint("TOPLEFT", 8, -6)
	card.Title:SetText(titleText)

	card.Stats = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	card.Stats:SetPoint("TOPLEFT", card.Title, "BOTTOMLEFT", 0, -4)
	card.Stats:SetPoint("RIGHT", card, "RIGHT", -8, 0)
	card.Stats:SetJustifyH("LEFT")
	card.Stats:SetWordWrap(true)

	card:SetScript("OnClick", onClick)
	return card
end

local function CreateRadio(parent, label, onClick)
	local r = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
	if not r.text then
		r.text = r:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
		r.text:SetPoint("LEFT", r, "RIGHT", 3, 0)
	end
	r.text:SetText(label)
	r:SetScript("OnClick", onClick)
	return r
end

local function EnsureFrame()
	if frame then return frame end
	local f = CreateFrame("Frame", "FWC_PlannerWindow", UIParent, "ButtonFrameTemplate")
	f:SetSize(WIN_W, WIN_H)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	f:SetScript("OnShow", function() PlannerUI.Refresh() end)
	f:Hide()
	if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(f) end
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "FWC_PlannerWindow") end

	local title = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
	if title then title:SetText("Forever Writs & Crates — Planner") end
	if f.SetPortraitToAsset then
		f:SetPortraitToAsset(FWC.WRIT_ICON)
	elseif f.PortraitContainer and f.PortraitContainer.portrait then
		f.PortraitContainer.portrait:SetTexture(FWC.WRIT_ICON)
	end

	-- Attic: faction & standing summary
	local headerInfo = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	headerInfo:SetPoint("TOPLEFT", f, "TOPLEFT", 64, -27)
	headerInfo:SetPoint("RIGHT", f, "RIGHT", -12, 0)
	headerInfo:SetHeight(32)
	headerInfo:SetJustifyH("LEFT")
	headerInfo:SetJustifyV("TOP")
	headerInfo:SetWordWrap(true)
	f.HeaderInfo = headerInfo

	local inset = f.Inset or f

	-- === TAB 1 (Rep & Route) Controls ===
	local repGroup = CreateFrame("Frame", nil, inset)
	repGroup:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
	repGroup:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -8, -8)
	repGroup:SetHeight(172)
	f.RepGroup = repGroup

	local goalLabel = repGroup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	goalLabel:SetPoint("TOPLEFT", 2, -2)
	goalLabel:SetText("Goal:")

	f.GoalRadios = {}
	local autoRadio = CreateRadio(repGroup, "Auto (Next)", function()
		manualStanding = nil
		PlannerUI.Refresh()
	end)
	autoRadio:SetPoint("LEFT", goalLabel, "RIGHT", 6, 0)
	autoRadio.standing = nil
	f.GoalRadios[#f.GoalRadios + 1] = autoRadio

	local prevR = autoRadio
	for _, st in ipairs(FWC.TARGET_STANDINGS) do
		local r = CreateRadio(repGroup, FWC.Rep.StandingLabel(st), function()
			manualStanding = st
			PlannerUI.Refresh()
		end)
		r:SetPoint("LEFT", prevR.text, "RIGHT", 10, 0)
		r.standing = st
		f.GoalRadios[#f.GoalRadios + 1] = r
		prevR = r
	end

	local gapLine = repGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	gapLine:SetPoint("TOPLEFT", goalLabel, "BOTTOMLEFT", 0, -10)
	gapLine:SetPoint("RIGHT", repGroup, "RIGHT", 0, 0)
	gapLine:SetJustifyH("LEFT")
	f.RepGap = gapLine

	-- Two plan cards: Fastest Route vs Cheapest Plan
	local cardW = (WIN_W - 44) / 2
	f.FastCard = CreateCard(repGroup, cardW, "Fastest Route", function()
		selectedPlanKind = "fastest"
		if FWC.db then FWC.db.planner.planKind = "fastest" end
		PlannerUI.Refresh()
	end)
	f.FastCard:SetPoint("TOPLEFT", gapLine, "BOTTOMLEFT", 0, -8)

	f.CheapCard = CreateCard(repGroup, cardW, "Cheapest Plan", function()
		selectedPlanKind = "cheapest"
		if FWC.db then FWC.db.planner.planKind = "cheapest" end
		PlannerUI.Refresh()
	end)
	f.CheapCard:SetPoint("LEFT", f.FastCard, "RIGHT", 8, 0)

	-- Action buttons under cards
	local startBtn = CreateFrame("Button", nil, repGroup, "UIPanelButtonTemplate")
	startBtn:SetSize(140, 24)
	startBtn:SetPoint("TOPLEFT", f.FastCard, "BOTTOMLEFT", 0, -8)
	startBtn:SetText("Start Route Guide")
	startBtn:SetScript("OnClick", function()
		if not lastRepResult then return end
		local plan = (selectedPlanKind == "cheapest") and lastRepResult.cheapest or lastRepResult.fastest
		if not plan or #plan.route == 0 then
			FWC.Print("No writs in this plan yet. Scan at the Auction House first.")
			return
		end
		local label = (selectedPlanKind == "cheapest") and "Cheapest Writ Route" or "Fastest Writ Route"
		FWC.RouteGuide.StartPlan(plan, label)
		FWC.Print("Route started: %d writ(s), +%d rep, ~%s travel.", #plan.route, plan.rep, FWC.FormatTime(plan.secs))
	end)
	f.StartRouteBtn = startBtn

	local bagRouteBtn = CreateFrame("Button", nil, repGroup, "UIPanelButtonTemplate")
	bagRouteBtn:SetSize(150, 24)
	bagRouteBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
	bagRouteBtn:SetText("Route My Bag Writs")
	bagRouteBtn:SetScript("OnClick", function()
		local plan = FWC.RoutePlanner.PlanOwnedWrits()
		if #plan.route == 0 then
			FWC.Print("No turn-in ready writs or completed quests found.")
		else
			FWC.RouteGuide.StartPlan(plan, "My Turn-in Route")
			FWC.Print("Started route: %d writ(s)%s (~%s travel).",
				plan.writCount or #plan.route,
				(plan.questCount and plan.questCount > 0) and string.format(" + %d quest(s)", plan.questCount) or "",
				FWC.FormatTime(plan.secs))
		end
	end)
	f.BagRouteBtn = bagRouteBtn

	local ahHint = repGroup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	ahHint:SetPoint("LEFT", bagRouteBtn, "RIGHT", 8, 0)
	ahHint:SetPoint("RIGHT", repGroup, "RIGHT", 0, 0)
	ahHint:SetJustifyH("LEFT")
	ahHint:SetText("Click row at AH to buy")

	local questCheck = CreateFrame("CheckButton", "FWC_IncludeQuestsCheck", repGroup, "UICheckButtonTemplate")
	questCheck:SetSize(22, 22)
	questCheck:SetPoint("TOPLEFT", startBtn, "BOTTOMLEFT", -2, -3)
	if not questCheck.text then
		questCheck.text = questCheck:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		questCheck.text:SetPoint("LEFT", questCheck, "RIGHT", 4, 0)
	end
	questCheck.text:SetText("Include completed quests")
	questCheck:SetScript("OnClick", function(self)
		if FWC.db then FWC.db.includeCompletedQuests = self:GetChecked() and true or false end
		PlannerUI.Refresh()
	end)
	f.IncludeQuestsCheck = questCheck

	local pickQuestsBtn = CreateFrame("Button", nil, repGroup, "UIPanelButtonTemplate")
	pickQuestsBtn:SetSize(108, 20)
	pickQuestsBtn:SetPoint("LEFT", questCheck.text, "RIGHT", 12, 0)
	pickQuestsBtn:SetText("Pick Quests...")
	pickQuestsBtn:SetScript("OnClick", function()
		activeTab = "quests"
		PlannerUI.Refresh()
	end)
	f.PickQuestsBtn = pickQuestsBtn

	-- === TAB 2 (Favor) Controls ===
	local favorGroup = CreateFrame("Frame", nil, inset)
	favorGroup:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
	favorGroup:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -10)
	favorGroup:SetHeight(72)
	favorGroup:Hide()
	f.FavorGroup = favorGroup

	local favLbl = favorGroup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	favLbl:SetPoint("TOPLEFT", 0, -4)
	favLbl:SetText("Merchant's Favor wanted:")

	local favBox = CreateFrame("EditBox", "FWC_FavorInput", favorGroup, "InputBoxTemplate")
	favBox:SetSize(72, 22)
	favBox:SetPoint("LEFT", favLbl, "RIGHT", 12, 0)
	favBox:SetAutoFocus(false)
	favBox:SetNumeric(true)
	favBox:SetMaxLetters(6)
	favBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput and FWC.db then
			FWC.db.planner.favorWanted = tonumber(self:GetText()) or 0
			PlannerUI.Refresh()
		end
	end)
	favBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	favBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	f.FavorBox = favBox

	local favSummary = favorGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	favSummary:SetPoint("TOPLEFT", favLbl, "BOTTOMLEFT", 0, -12)
	favSummary:SetPoint("RIGHT", favorGroup, "RIGHT", 0, 0)
	favSummary:SetJustifyH("LEFT")
	favSummary:SetWordWrap(true)
	f.FavorSummary = favSummary

	-- === TAB 4 (Completed Quests Picker) Controls ===
	local questGroup = CreateFrame("Frame", nil, inset)
	questGroup:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -8)
	questGroup:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -8)
	questGroup:SetHeight(42)
	questGroup:Hide()
	f.QuestGroup = questGroup

	local selOpenBtn = CreateFrame("Button", nil, questGroup, "UIPanelButtonTemplate")
	selOpenBtn:SetSize(134, 22)
	selOpenBtn:SetPoint("TOPLEFT", 0, -4)
	selOpenBtn:SetText("Select Open-World")
	selOpenBtn:SetScript("OnClick", function()
		for _, q in ipairs(FWC.RoutePlanner.AllCompletedQuestStops()) do
			FWC.RoutePlanner.SetQuestSelected(q.questID, not (q.isDungeon or q.isRaid))
		end
		PlannerUI.Refresh()
	end)

	local deselAllBtn = CreateFrame("Button", nil, questGroup, "UIPanelButtonTemplate")
	deselAllBtn:SetSize(104, 22)
	deselAllBtn:SetPoint("LEFT", selOpenBtn, "RIGHT", 8, 0)
	deselAllBtn:SetText("Deselect All")
	deselAllBtn:SetScript("OnClick", function()
		for _, q in ipairs(FWC.RoutePlanner.AllCompletedQuestStops()) do
			FWC.RoutePlanner.SetQuestSelected(q.questID, false)
		end
		PlannerUI.Refresh()
	end)

	local routeQuestsBtn = CreateFrame("Button", nil, questGroup, "UIPanelButtonTemplate")
	routeQuestsBtn:SetSize(130, 22)
	routeQuestsBtn:SetPoint("LEFT", deselAllBtn, "RIGHT", 8, 0)
	routeQuestsBtn:SetText("Build Route Now")
	routeQuestsBtn:SetScript("OnClick", function()
		local plan = FWC.RoutePlanner.PlanOwnedWrits()
		if #plan.route == 0 then
			FWC.Print("No turn-in ready writs or selected quests found.")
		else
			FWC.RouteGuide.StartPlan(plan, "My Turn-in Route")
			FWC.Print("Started route: %d writ(s)%s (~%s travel).",
				plan.writCount or 0,
				(plan.questCount and plan.questCount > 0) and string.format(" + %d quest(s)", plan.questCount) or "",
				FWC.FormatTime(plan.secs))
		end
	end)

	-- === Shared ScrollBox ===
	if CreateScrollBoxListLinearView and ScrollUtil and ScrollUtil.InitScrollBoxListWithScrollBar then
		local scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
		scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -162)
		scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 4)
		local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
		scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
		scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)
		local view = CreateScrollBoxListLinearView()
		view:SetElementExtent(ROW_H)
		view:SetElementInitializer("Button", InitRow)
		ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
		f.ScrollBox = scrollBox
	end

	-- Tabs
	local function MakeTab(idx, label, mode)
		local t = CreateFrame("Button", "FWC_PlannerTab" .. idx, f, "PanelTabButtonTemplate")
		t:SetID(idx)
		t:SetText(label)
		t:SetScript("OnClick", function()
			activeTab = mode
			PlannerUI.Refresh()
		end)
		return t
	end
	local t1 = MakeTab(1, "Rep & Route", "rep")
	t1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, -28)
	local t2 = MakeTab(2, "Favor", "favor")
	t2:SetPoint("LEFT", t1, "RIGHT", TAB_GAP, 0)
	local t3 = MakeTab(3, "By Zone", "zones")
	t3:SetPoint("LEFT", t2, "RIGHT", TAB_GAP, 0)
	local t4 = MakeTab(4, "Quests", "quests")
	t4:SetPoint("LEFT", t3, "RIGHT", TAB_GAP, 0)
	f.Tabs = { t1, t2, t3, t4 }
	f.numTabs = 4
	f.tabPadding, f.minTabWidth = TAB_PADDING, MIN_TAB_W

	frame = f
	return f
end

function PlannerUI.Refresh()
	if not frame or not frame:IsShown() then return end
	if FWC.db and FWC.db.planner.planKind then selectedPlanKind = FWC.db.planner.planKind end

	local tabIdx = (activeTab == "rep" and 1) or (activeTab == "favor" and 2) or (activeTab == "zones" and 3) or 4
	if PanelTemplates_SetTab then PanelTemplates_SetTab(frame, tabIdx) end
	ResizeTabs(frame)

	frame.RepGroup:SetShown(activeTab == "rep")
	frame.FavorGroup:SetShown(activeTab == "favor")
	frame.QuestGroup:SetShown(activeTab == "quests")

	local topOffset = (activeTab == "rep" and -186) or (activeTab == "favor" and -88) or (activeTab == "quests" and -46) or -8
	if frame.ScrollBox then
		frame.ScrollBox:ClearAllPoints()
		frame.ScrollBox:SetPoint("TOPLEFT", frame.Inset or frame, "TOPLEFT", 4, topOffset)
		frame.ScrollBox:SetPoint("BOTTOMRIGHT", frame.Inset or frame, "BOTTOMRIGHT", -22, 4)
	end

	local rows = {}

	if activeTab == "rep" then
		-- If manual standing was already reached, revert to Auto!
		local status = FWC.Rep.GetStatus()
		if manualStanding and status.reaction >= manualStanding then
			manualStanding = nil
		end

		local res = FWC.RoutePlanner.PlanForStanding(manualStanding)
		lastRepResult = res

		local curLabel = FWC.Rep.StandingLabel(status.reaction)
		local goalLabel = FWC.Rep.StandingLabel(res.targetStanding)
		frame.HeaderInfo:SetText(string.format("%s — Current: |cff40ff40%s|r (%s / %s)\nAll faction flights & boats assumed available.",
			status.name, curLabel, FWC.FormatNumber(status.standing - status.bottom), FWC.FormatNumber(status.top - status.bottom)))

		for _, r in ipairs(frame.GoalRadios) do
			r:SetChecked(r.standing == manualStanding)
		end
		if frame.IncludeQuestsCheck then
			frame.IncludeQuestsCheck:SetChecked(FWC.RoutePlanner.IncludeQuestsEnabled())
		end

		if res.needRep <= 0 then
			frame.RepGap:SetText("|cff40ff40You have already reached " .. goalLabel .. "!|r")
		else
			local autoTag = res.isAutoTarget and " (Auto)" or ""
			frame.RepGap:SetText(string.format("Goal: |cffffd100%s%s|r — %s reputation needed",
				goalLabel, autoTag, FWC.FormatNumber(res.needRep)))
		end

		local function StyleCard(card, plan, selected)
			if selected then
				card:SetBackdropColor(0.12, 0.24, 0.20, 0.95)
				card:SetBackdropBorderColor(0.25, 0.9, 0.6, 1)
			else
				card:SetBackdropColor(0.10, 0.10, 0.12, 0.9)
				card:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
			end
			if #plan.route == 0 then
				card.Stats:SetText("|cffaaaaaaNo writs available.\nScan at Auction House.|r")
			else
				local qStr = (plan.questCount and plan.questCount > 0) and string.format(" + %dq", plan.questCount) or ""
				card.Stats:SetText(string.format("%d writs%s · +%s rep\n~%s travel · %s",
					plan.writCount or #plan.route, qStr, FWC.FormatNumber(plan.rep), FWC.FormatTime(plan.secs), FWC.FormatMoney(plan.cost)))
			end
		end

		StyleCard(frame.FastCard, res.fastest, selectedPlanKind == "fastest")
		StyleCard(frame.CheapCard, res.cheapest, selectedPlanKind == "cheapest")

		local chosen = (selectedPlanKind == "cheapest") and res.cheapest or res.fastest
		for idx, stop in ipairs(chosen.route) do
			rows[#rows + 1] = { mode = "repStop", index = idx, stop = stop }
		end

	elseif activeTab == "favor" then
		local owned = FWC.FavorOwned()
		frame.HeaderInfo:SetText(owned and string.format("You currently have %s %s.", FWC.FormatNumber(owned), FWC.FavorName()) or FWC.FavorName())
		local wanted = (FWC.db and FWC.db.planner.favorWanted) or 100
		if not frame.FavorBox:HasFocus() then
			frame.FavorBox:SetText(tostring(wanted))
		end
		local plan = FWC.Valuation.PlanFavor(FWC.Prices(), wanted)
		if wanted <= 0 then
			frame.FavorSummary:SetText("Enter how much Merchant's Favor you want above.")
		elseif plan.achieved <= 0 then
			frame.FavorSummary:SetText("|cffff8844No crate prices yet. Scan Crates at the Auction House.|r")
		else
			local prefix = plan.complete and "|cff40ff40" or "|cffffaa44Partial: "
			frame.FavorSummary:SetText(string.format("%s%s / %s favor|r — Total: %s%s (click any crate at AH to buy)",
				prefix, FWC.FormatNumber(plan.achieved), FWC.FormatNumber(wanted),
				plan.estimate and "~" or "", FWC.FormatMoney(plan.cost)))
		end
		for _, pick in ipairs(plan.picks) do
			rows[#rows + 1] = { mode = "favorPick", pick = pick }
		end

	elseif activeTab == "zones" then
		local status = FWC.Rep.GetStatus()
		frame.HeaderInfo:SetText(string.format("%s — All 150 Craftsman's Writs grouped by hand-in zone.\nClick any writ while at the Auction House to search & buy it.", status.name))
		rows = BuildZoneRows()

	else -- quests
		local allQ = FWC.RoutePlanner.AllCompletedQuestStops()
		local selCount = 0
		for _, q in ipairs(allQ) do
			if q.pos and FWC.RoutePlanner.IsQuestSelected(q) then selCount = selCount + 1 end
			rows[#rows + 1] = { mode = "questPick", qStop = q }
		end
		frame.HeaderInfo:SetText(string.format("Completed Quests: %d of %d selected for routing.\nDungeon & Raid quests are excluded by default. Click any row to toggle.", selCount, #allQ))
	end

	if frame.ScrollBox and CreateDataProvider then
		frame.ScrollBox:SetDataProvider(CreateDataProvider(rows), true)
	end
end

function PlannerUI.Show()
	local f = EnsureFrame()
	f:Show()
	PlannerUI.Refresh()
end

function PlannerUI.Hide()
	if frame then frame:Hide() end
end

function PlannerUI.Toggle()
	if frame and frame:IsShown() then PlannerUI.Hide() else PlannerUI.Show() end
end

FWC.On("UPDATE_FACTION", function() if frame and frame:IsShown() then FWC.RefreshUI() end end)
FWC.On("CURRENCY_DISPLAY_UPDATE", function() if frame and frame:IsShown() then FWC.RefreshUI() end end)
