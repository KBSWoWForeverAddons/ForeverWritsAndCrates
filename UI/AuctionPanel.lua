-- Forever Writs and Crates: Auction House side panel & SearchBar toggle button.
-- Provides Crates tab (cost/favor) and Writs tab (sortable by Fastest Travel or Cheapest),
-- with one-click AH Browse-list display, material highlighting, and quantity pre-fill.
local _, FWC = ...

local Panel = {}
FWC.AuctionPanel = Panel

local PANEL_WIDTH = 400
local ROW_HEIGHT = 58
local TAB_PADDING = 20
local MIN_TAB_WIDTH = 74
local TAB_GAP = 12

local COLOR_ACCEPTED = { 1, 0.82, 0 }
local COLOR_TURNED_IN = { 0.5, 0.5, 0.5 }

local panelFrame, toggleBtn

--------------------------------------------------------------------------------
-- Shared Formatting Helpers (also used by Tooltips.lua)
--------------------------------------------------------------------------------
local function QuoteShort(q)
	if q and q.cost then return FWC.FormatMoney(q.cost) end
	if not q or q.unknown then return "unknown" end
	if q.listed and q.short then return string.format("%d/%d listed", q.count - q.short, q.count) end
	return "not listed"
end

local function QuoteDetail(q)
	if q.cost then
		local src = (q.source == "auctionator") and ("Auctionator, " .. FWC.SeenText(q.seenDays))
			or (q.exact and "exact" or "estimate")
		local s = FWC.FormatMoney(q.cost) .. " (" .. src .. ")"
		if q.surplus and q.surplus > 0 then s = s .. ", " .. q.surplus .. " extra" end
		return s
	elseif q.unknown then
		return "unknown (not scanned)"
	elseif q.listed then
		return string.format("only %d listed (%d missing)", q.count - q.short, q.short)
	end
	return "not listed"
end

local function ItemWithOwned(itemID, count)
	local text = string.format("%d x %s", count, FWC.ItemName(itemID))
	local inBag = FWC.BagCount(itemID)
	local inMail = FWC.InMailCount and FWC.InMailCount(itemID) or 0
	if inBag > 0 and inMail > 0 then
		text = text .. string.format(" (have %d + %d mail)", inBag, inMail)
	elseif inBag > 0 then
		text = text .. string.format(" (have %d)", inBag)
	elseif inMail > 0 then
		text = text .. string.format(" (%d in mail)", inMail)
	end
	return text
end

function Panel.AddCrateTooltipLines(tip, row)
	local bp = row.bagProgress
	if bp and bp.bagCount > 0 then
		if bp.remaining > 0 then
			tip:AddLine(string.format("In your bags: %d crate(s) — %d covered (bags/mail), %d still need mats",
				bp.bagCount, bp.covered, bp.remaining), 1, 0.85, 0.25, true)
		else
			tip:AddLine(string.format("In your bags: %d crate(s) — all covered by bags/AH mail!", bp.bagCount), 0.25, 1, 0.4, true)
		end
	end
	if row.bagCount and row.bagCount > 0 then
		tip:AddLine(string.format("In bags: %d unfilled crate%s", row.bagCount, row.bagCount == 1 and "" or "s"), 0.25, 1, 0.5)
	end
	if row.ownedMode then
		if row.perFavor then
			tip:AddLine(string.format("Fill per favor: %s%s / favor",
				row.estimate and "~" or "", FWC.FormatMoney(row.perFavor)), 1, 0.82, 0)
		end
	else
		if row.totalPerFavor then
			tip:AddLine(string.format("Total per favor: %s%s / favor",
				row.estimate and "~" or "", FWC.FormatMoney(row.totalPerFavor)), 1, 0.82, 0)
		end
		if row.total then
			tip:AddLine(string.format("Total %s = crate %s + fill %s",
				FWC.FormatMoney(row.total), QuoteShort(row.crateQuote), QuoteShort(row.fill)), 0.9, 0.9, 0.9, true)
		end
	end
	tip:AddLine("Fill options:", 1, 0.82, 0)
	for _, q in ipairs(row.bundles or {}) do
		local best = (q == row.fill and q.cost ~= nil)
		if best then
			tip:AddDoubleLine(ItemWithOwned(q.item, q.count), QuoteDetail(q), 0.1, 1, 0.1, 0.1, 1, 0.1)
		else
			tip:AddDoubleLine(ItemWithOwned(q.item, q.count), QuoteDetail(q), 0.9, 0.9, 0.9, 0.7, 0.7, 0.7)
		end
	end
end

function Panel.AddWritTooltipLines(tip, row)
	if FWC.Writs.IsAccepted(row.writ) then
		tip:AddLine("Quest accepted (in your quest log)", 1, 0.82, 0)
	end
	if FWC.Writs.IsTurnedInToday(row.writ) then
		local sec = FWC.Writs.SecondsUntilReset()
		tip:AddLine(sec and ("Already turned in today (resets in " .. FWC.FormatSpan(sec) .. ")") or "Already turned in today", 1, 0.25, 0.25)
	end
	if row.bagHopSecs then
		local nearName = row.bagHopAnchor and row.bagHopAnchor.loc and row.bagHopAnchor.loc.zoneName or "bag writ"
		tip:AddLine(string.format("Hop from bag writ (%s): +%s", nearName, FWC.FormatTime(row.bagHopSecs)), 0.25, 1, 0.5)
	end
	if row.travelSecs then
		tip:AddLine(string.format("Est. travel time: ~%s (all flights & boats assumed)", FWC.FormatTime(row.travelSecs)), 0.4, 0.9, 1)
	end
	if row.perHundred then
		tip:AddLine(string.format("Cost per 100 rep: %s%s", row.estimate and "~" or "", FWC.FormatMoney(row.perHundred)), 1, 0.82, 0)
	end
	if row.total then
		tip:AddLine(string.format("Total %s = writ %s + items %s",
			FWC.FormatMoney(row.total), QuoteShort(row.writQuote), QuoteShort(row.fill)), 0.9, 0.9, 0.9, true)
	end
	tip:AddLine("Required items:", 1, 0.82, 0)
	for _, q in ipairs(row.needs or {}) do
		local r, g, b = q.cost and 0.1 or 0.9, q.cost and 1 or 0.9, q.cost and 0.1 or 0.9
		tip:AddDoubleLine(ItemWithOwned(q.item, q.count), QuoteDetail(q), r, g, b, r, g, b)
	end
	local where = FWC.Writs.TurnInText(row.writ)
	tip:AddLine("Hand in: " .. where, 0.85, 0.85, 0.85, true)
end

--------------------------------------------------------------------------------
-- Row Building & Sorting
--------------------------------------------------------------------------------
local function ActiveTab()
	return (FWC.db and FWC.db.panelTab == "crates") and "crates" or "writs"
end

local SORT_CYCLE = { fastest = "nearbags", nearbags = "cheapest", cheapest = "fastest" }
local SORT_LABELS = { fastest = "Sort: Fast", nearbags = "Sort: Bags", cheapest = "Sort: Cost" }

local function WritSortMode()
	local m = FWC.db and FWC.db.writSort
	if m == "cheapest" or m == "nearbags" then return m end
	return "fastest"
end

local function CrateMode()
	return (FWC.db and FWC.db.crateMode == "bags") and "bags" or "all"
end

local lastBagAnchorCount = 0

local function BuildRows()
	local book = FWC.Prices()
	if ActiveTab() == "crates" then
		if CrateMode() == "bags" then
			return FWC.Valuation.EvaluateOwnedCrates(book)
		end
		return FWC.Valuation.EvaluateAllCrates(book)
	end

	local rows = FWC.Valuation.EvaluateAllWrits(book)
	local startPt = FWC.Travel.PlayerPoint()
	local mode = WritSortMode()
	local bagInfo = FWC.RoutePlanner.GetOwnedWritAnchors()
	lastBagAnchorCount = (bagInfo and #bagInfo.anchors) or 0

	for _, r in ipairs(rows) do
		r.travelSecs = FWC.RoutePlanner.EstimateWritTravelSecs(r.writ, startPt)
		r.isOwnedWrit = bagInfo.ownedIDs[r.writ.id] or false
		if mode == "nearbags" and lastBagAnchorCount > 0 then
			r.bagHopSecs, r.bagHopAnchor = FWC.RoutePlanner.MinTravelFromAnchors(r.writ, bagInfo)
		end
	end

	local receipt = FWC.Valuation.EvaluateReceipt(book, FWC.Crates())
	rows[#rows + 1] = receipt

	local function CanBuyToday(r)
		return (r.kind == "writ") and (r.score ~= nil)
			and not r.isOwnedWrit and not FWC.Writs.IsTurnedInToday(r.writ)
	end

	if mode == "nearbags" and lastBagAnchorCount > 0 then
		table.sort(rows, function(a, b)
			local aBuy = CanBuyToday(a) and (a.bagHopSecs ~= nil)
			local bBuy = CanBuyToday(b) and (b.bagHopSecs ~= nil)
			if aBuy ~= bBuy then return aBuy end
			if aBuy and bBuy then
				if math.abs(a.bagHopSecs - b.bagHopSecs) > 10 then
					return a.bagHopSecs < b.bagHopSecs
				end
				return (a.score or math.huge) < (b.score or math.huge)
			end
			if (a.isOwnedWrit or false) ~= (b.isOwnedWrit or false) then return a.isOwnedWrit end
			local ha, hb = a.bagHopSecs or math.huge, b.bagHopSecs or math.huge
			if ha ~= hb then return ha < hb end
			return (a.score or math.huge) < (b.score or math.huge)
		end)
	elseif mode == "fastest" or (mode == "nearbags" and lastBagAnchorCount == 0) then
		table.sort(rows, function(a, b)
			local aAvail = CanBuyToday(a) and (a.travelSecs ~= nil)
			local bAvail = CanBuyToday(b) and (b.travelSecs ~= nil)
			if aAvail ~= bAvail then return aAvail end
			if aAvail and bAvail then
				local ea = a.travelSecs / math.max(1, (a.rep or 75) / 100)
				local eb = b.travelSecs / math.max(1, (b.rep or 75) / 100)
				if math.abs(ea - eb) > 5 then return ea < eb end
				return (a.score or math.huge) < (b.score or math.huge)
			end
			local ra = a.travelSecs or math.huge
			local rb = b.travelSecs or math.huge
			if ra ~= rb then return ra < rb end
			return (a.score or math.huge) < (b.score or math.huge)
		end)
	else
		table.sort(rows, function(a, b)
			local aAvail = (a.kind == "receipt" and a.score ~= nil) or CanBuyToday(a)
			local bAvail = (b.kind == "receipt" and b.score ~= nil) or CanBuyToday(b)
			if aAvail ~= bAvail then return aAvail end
			local sa = a.score or a.fillScore or math.huge
			local sb = b.score or b.fillScore or math.huge
			if sa ~= sb then return sa < sb end
			return a.id < b.id
		end)
	end
	return rows
end

--------------------------------------------------------------------------------
-- Row Rendering & Interaction
--------------------------------------------------------------------------------
local function ShowRowTooltip(btn)
	local row = btn.row
	if not row or not GameTooltip then return end
	local tip = GameTooltip
	tip:SetOwner(btn, "ANCHOR_RIGHT")
	local r, g, b = FWC.QualityColor(row.quality)
	tip:AddLine(FWC.ItemName(row.id), r, g, b)
	if row.kind == "crate" then
		if row.favor then tip:AddLine(string.format("Gives %d %s", row.favor, FWC.FavorName()), 1, 0.82, 0) end
		tip:AddLine(" ")
		Panel.AddCrateTooltipLines(tip, row)
		tip:AddLine(" ")
		tip:AddLine("Left-click: show crate & materials in AH list (auto pre-fills qty).", 0.6, 0.8, 1, true)
		tip:AddLine("Right-click: exact price check for this crate.", 0.6, 0.6, 0.6, true)
	elseif row.kind == "writ" then
		if row.rep then tip:AddLine(string.format("Gives %d reputation with %s", row.rep, FWC.Rep.FactionName()), 1, 0.82, 0) end
		tip:AddLine(" ")
		Panel.AddWritTooltipLines(tip, row)
		tip:AddLine(" ")
		tip:AddLine("Left-click: show writ & required item in AH list (auto pre-fills qty).", 0.6, 0.8, 1, true)
		tip:AddLine("Right-click: exact price check for this writ.", 0.6, 0.6, 0.6, true)
	elseif row.kind == "receipt" then
		tip:AddLine(string.format("Gives %d reputation (15 %s + empty crate, Friendly+)", row.rep, FWC.FavorName()), 1, 0.82, 0, true)
		if row.total then
			tip:AddLine(string.format("Est. total: %s (%s / 100 rep)", FWC.FormatMoney(row.total), FWC.FormatMoney(row.perHundred)), 0.9, 0.9, 0.9)
		end
	end
	tip:Show()
end

local function OnRowClick(row, mouse)
	if not row or row.kind == "receipt" then return end
	local entry = (row.kind == "writ") and row.writ or row.crate
	if mouse == "RightButton" then
		FWC.Scanner.StartExact(entry)
	else
		FWC.Scanner.ShowInAuctionHouse(entry)
	end
	Panel.Refresh()
end

local function InitRow(btn, row)
	if not btn.Icon then
		btn:SetHeight(ROW_HEIGHT)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		btn.Icon = btn:CreateTexture(nil, "ARTWORK")
		btn.Icon:SetSize(36, 36)
		btn.Icon:SetPoint("LEFT", btn, "LEFT", 4, 0)

		btn.RightTop = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		btn.RightTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -4)
		btn.RightTop:SetJustifyH("RIGHT")
		btn.RightTop:SetWordWrap(false)

		btn.Name = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		btn.Name:SetPoint("TOPLEFT", btn.Icon, "TOPRIGHT", 6, 2)
		btn.Name:SetPoint("RIGHT", btn.RightTop, "LEFT", -6, 0)
		btn.Name:SetJustifyH("LEFT")
		btn.Name:SetWordWrap(false)

		btn.Line2 = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		btn.Line2:SetPoint("TOPLEFT", btn.Name, "BOTTOMLEFT", 0, -3)
		btn.Line2:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
		btn.Line2:SetJustifyH("LEFT")
		btn.Line2:SetWordWrap(false)

		btn.Line3 = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		btn.Line3:SetPoint("TOPLEFT", btn.Line2, "BOTTOMLEFT", 0, -2)
		btn.Line3:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
		btn.Line3:SetJustifyH("LEFT")
		btn.Line3:SetWordWrap(false)
		btn.Line3:SetTextColor(0.7, 0.7, 0.7)

		btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		btn:SetScript("OnClick", function(self, mouse) OnRowClick(self.row, mouse) end)
		btn:SetScript("OnEnter", ShowRowTooltip)
		btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	end

	btn.row = row
	local info = FWC.ItemInfo(row.id)
	local r, g, b = FWC.QualityColor(row.quality)

	if row.kind == "writ" then
		local turnedIn = FWC.Writs.IsTurnedInToday(row.writ)
		if FWC.Writs.IsAccepted(row.writ) or row.isOwnedWrit then
			r, g, b = unpack(COLOR_ACCEPTED)
		elseif turnedIn then
			r, g, b = unpack(COLOR_TURNED_IN)
		end
		btn.Icon:SetTexture(info.icon or FWC.WRIT_ICON)
		local namePrefix = ""
		if row.isOwnedWrit then
			namePrefix = "|cff40ff40[In Bag]|r "
		elseif turnedIn then
			namePrefix = "|cff888888[Done]|r "
		end
		btn.Name:SetText(namePrefix .. (info.name or ("#" .. row.id)))
		btn.Name:SetTextColor(r, g, b)

		local priceStr = row.perHundred and ((row.estimate and "~" or "") .. FWC.FormatMoney(row.perHundred) .. "/100") or "-"
		local timeStr
		if row.bagHopSecs and WritSortMode() == "nearbags" and not row.isOwnedWrit then
			timeStr = "|cff40ff80+" .. FWC.FormatTime(row.bagHopSecs) .. "|r  "
		else
			timeStr = row.travelSecs and ("|cff66ddff" .. FWC.FormatTime(row.travelSecs) .. "|r  ") or ""
		end
		btn.RightTop:SetText(timeStr .. priceStr)

		if row.total then
			btn.Line2:SetText(string.format("Total %s = writ %s + item %s",
				FWC.FormatMoney(row.total), QuoteShort(row.writQuote), QuoteShort(row.fill)))
		else
			btn.Line2:SetText(string.format("Writ %s, item %s", QuoteShort(row.writQuote), QuoteShort(row.fill)))
		end

		local needParts = {}
		for _, q in ipairs(row.needs) do needParts[#needParts + 1] = string.format("%dx %s", q.count, FWC.ItemName(q.item)) end
		local loc = FWC.Writs.Location(row.writ)
		btn.Line3:SetText(table.concat(needParts, ", ") .. "  |  " .. (loc and FWC.Writs.LocationText(loc) or "Unknown zone"))

	elseif row.kind == "crate" then
		btn.Icon:SetTexture(info.icon or FWC.CRATE_ICON)
		local bp = row.bagProgress
		local namePrefix = ""
		if bp and bp.bagCount > 0 then
			if bp.remaining > 0 then
				namePrefix = string.format("|cffffd100[%d to fill]|r ", bp.remaining)
			else
				namePrefix = string.format("|cff40ff40[%d Ready]|r ", bp.bagCount)
				r, g, b = 0.55, 0.85, 0.55
			end
		elseif row.bagCount and row.bagCount > 0 then
			namePrefix = (row.bagCount > 1)
				and string.format("|cff40ff40[In Bag x%d]|r ", row.bagCount)
				or "|cff40ff40[In Bag]|r "
		end
		btn.Name:SetText(namePrefix .. (info.name or ("#" .. row.id)))
		btn.Name:SetTextColor(r, g, b)
		if row.ownedMode then
			btn.RightTop:SetText(row.perFavor and ((row.estimate and "~" or "") .. FWC.FormatMoney(row.perFavor) .. "/fav") or "-")
			btn.Line2:SetText("Best fill: " .. (row.fill and QuoteDetail(row.fill) or "unknown"))
		else
			btn.RightTop:SetText(row.totalPerFavor and ((row.estimate and "~" or "") .. FWC.FormatMoney(row.totalPerFavor) .. "/fav") or "-")
			if row.total then
				btn.Line2:SetText(string.format("Total %s = crate %s + fill %s",
					FWC.FormatMoney(row.total), QuoteShort(row.crateQuote), QuoteShort(row.fill)))
			else
				btn.Line2:SetText(string.format("Crate %s, fill %s", QuoteShort(row.crateQuote), QuoteShort(row.fill)))
			end
		end
		if row.fill and row.fill.item then
			btn.Line3:SetText("Fill: " .. ItemWithOwned(row.fill.item, row.fill.count))
		else
			btn.Line3:SetText("")
		end

	else -- receipt
		if FWC.Rep.RepToReceipts() > 0 then r, g, b = unpack(COLOR_TURNED_IN) end
		btn.Icon:SetTexture(info.icon or FWC.RECEIPT_ICON)
		btn.Name:SetText(info.name or "Forged Delivery Receipt")
		btn.Name:SetTextColor(r, g, b)
		btn.RightTop:SetText(row.perHundred and ((row.estimate and "~" or "") .. FWC.FormatMoney(row.perHundred) .. "/100") or "-")
		btn.Line2:SetText(row.total and string.format("Total %s (15 favor + empty crate)", FWC.FormatMoney(row.total)) or "Scan crates to price receipts")
		btn.Line3:SetText("Uncertified Scribe (Friendly+) -> +50 rep")
	end
end

--------------------------------------------------------------------------------
-- Frame Construction
--------------------------------------------------------------------------------
local function ResizeTabs(f)
	if not PanelTemplates_TabResize or type(f.Tabs) ~= "table" then return end
	for _, t in ipairs(f.Tabs) do
		pcall(PanelTemplates_TabResize, t, TAB_PADDING, nil, MIN_TAB_WIDTH)
	end
end

local function EnsureButton()
	if toggleBtn or not AuctionHouseFrame then return toggleBtn end
	local ah = AuctionHouseFrame
	local parent = ah.SearchBar or ah
	local b = CreateFrame("Button", "FWC_AuctionToggleBtn", parent, "UIPanelButtonTemplate")
	b:SetSize(106, 22)
	if ah.SearchBar then
		b:SetPoint("RIGHT", ah.SearchBar, "LEFT", -6, 0)
	else
		b:SetPoint("TOPRIGHT", ah, "TOPRIGHT", -40, -30)
	end
	b:SetText("Writs & Crates")
	b:SetScript("OnClick", function() Panel.Toggle() end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Forever Writs and Crates", 1, 0.82, 0)
		GameTooltip:AddLine("Toggle the Writs & Crates Auction House side panel.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	toggleBtn = b
	return b
end

local function EnsurePanel()
	if panelFrame or not AuctionHouseFrame then return panelFrame end
	local ah = AuctionHouseFrame

	local f = CreateFrame("Frame", "FWC_AuctionPanel", ah, "ButtonFrameTemplate")
	f:SetWidth(PANEL_WIDTH)
	f:SetPoint("TOPLEFT", ah, "TOPRIGHT", 2, 0)
	f:SetPoint("BOTTOMLEFT", ah, "BOTTOMRIGHT", 2, 0)
	f:SetFrameLevel((ah.GetFrameLevel and ah:GetFrameLevel() or 1) + 10)
	f:EnableMouse(true)
	f:Hide()

	local title = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
	if title then title:SetText("Forever Writs & Crates") end
	if f.SetPortraitToAsset then
		f:SetPortraitToAsset(FWC.CRATE_ICON)
	elseif f.PortraitContainer and f.PortraitContainer.portrait then
		f.PortraitContainer.portrait:SetTexture(FWC.CRATE_ICON)
	end
	if f.CloseButton then
		f.CloseButton:SetScript("OnClick", function() Panel.Hide() end)
	end

	-- Attic: status text + Sort button + Scan button
	local status = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", f, "TOPLEFT", 64, -28)
	status:SetPoint("RIGHT", f, "RIGHT", -174, 0)
	status:SetHeight(30)
	status:SetJustifyH("LEFT")
	status:SetJustifyV("TOP")
	status:SetWordWrap(true)
	f.Status = status

	local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	scanBtn:SetSize(74, 22)
	scanBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -31)
	scanBtn:SetText("Scan")
	scanBtn:SetScript("OnClick", function()
		if FWC.Scanner.IsRunning() then
			FWC.Scanner.Cancel("Scan stopped.")
		elseif ActiveTab() == "crates" and CrateMode() == "bags" then
			FWC.Scanner.StartQuick("bagcrates")
		else
			FWC.Scanner.StartQuick(ActiveTab())
		end
		Panel.Refresh()
	end)
	scanBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Scan Auction House", 1, 0.82, 0)
		if ActiveTab() == "crates" and CrateMode() == "bags" then
			GameTooltip:AddLine("Scans prices for unfilled crates currently in your bags and their fill materials.", 1, 1, 1, true)
		elseif ActiveTab() == "crates" then
			GameTooltip:AddLine("Scans prices for all Waylaid Crates and their fill materials.", 1, 1, 1, true)
		else
			GameTooltip:AddLine("Scans prices for all Writs and their required items.", 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	scanBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.ScanBtn = scanBtn

	local sortBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	sortBtn:SetSize(84, 22)
	sortBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)
	sortBtn:SetText("Fastest")
	sortBtn:SetScript("OnClick", function()
		if FWC.db then
			FWC.db.writSort = SORT_CYCLE[WritSortMode()] or "fastest"
		end
		Panel.Refresh()
	end)
	sortBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Writ Sort Order", 1, 0.82, 0)
		GameTooltip:AddLine("Click to cycle between:", 1, 1, 1)
		GameTooltip:AddLine("• Sort: Fast — fastest travel from your current location", 0.4, 0.9, 1, true)
		GameTooltip:AddLine("• Sort: Bags — closest in travel time to writs already in your bags/quest log", 0.25, 1, 0.5, true)
		GameTooltip:AddLine("• Sort: Cost — cheapest gold per 100 reputation", 1, 0.85, 0.3, true)
		GameTooltip:Show()
	end)
	sortBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.SortBtn = sortBtn

	local crateModeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	crateModeBtn:SetSize(84, 22)
	crateModeBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)
	crateModeBtn:SetText("Show: All")
	crateModeBtn:SetScript("OnClick", function()
		if FWC.db then
			FWC.db.crateMode = (CrateMode() == "bags") and "all" or "bags"
		end
		Panel.Refresh()
	end)
	crateModeBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Crate List & Scan Mode", 1, 0.82, 0)
		GameTooltip:AddLine("Click to toggle between:", 1, 1, 1)
		GameTooltip:AddLine("• Show: All — all crates, sorted by total gold / favor (crate + fill)", 0.4, 0.9, 1, true)
		GameTooltip:AddLine("• Show: Bags — only unfilled crates in your bags, sorted by best fill gold / favor (Scan also targets only bag crates)", 0.25, 1, 0.5, true)
		GameTooltip:Show()
	end)
	crateModeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.CrateModeBtn = crateModeBtn

	-- Bottom bar: Planner button, Bag Route button, Auctionator source info
	local planBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	planBtn:SetSize(88, 22)
	planBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
	planBtn:SetText("Planner")
	planBtn:SetScript("OnClick", function()
		if FWC.PlannerWindow then FWC.PlannerWindow.Toggle() end
	end)
	f.PlanBtn = planBtn

	local bagBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	bagBtn:SetSize(86, 22)
	bagBtn:SetPoint("RIGHT", planBtn, "LEFT", -4, 0)
	bagBtn:SetText("Bag Route")
	bagBtn:SetScript("OnClick", function()
		local plan = FWC.RoutePlanner.PlanOwnedWrits()
		if #plan.route == 0 then
			FWC.Print("No turn-in ready writs or completed quests found.")
		else
			FWC.RouteGuide.StartPlan(plan, "My Turn-in Route")
			FWC.Print("Started route: %d writ(s)%s (~%s).",
				plan.writCount or #plan.route,
				(plan.questCount and plan.questCount > 0) and string.format(" + %d quest(s)", plan.questCount) or "",
				FWC.FormatTime(plan.secs))
		end
		FWC.RoutePlanner.ReportSkipped(plan)
	end)
	bagBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Create Route for Bag Writs", 1, 0.82, 0)
		GameTooltip:AddLine("Calculates the fastest turn-in order for writs currently in your bags/quest log (assumes all flights & boats).", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	bagBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.BagBtn = bagBtn

	local source = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	source:SetPoint("LEFT", f, "BOTTOMLEFT", 10, 15)
	source:SetPoint("RIGHT", bagBtn, "LEFT", -6, 0)
	source:SetJustifyH("LEFT")
	source:SetWordWrap(false)
	source:SetTextColor(0.75, 0.75, 0.75)
	f.Source = source

	-- Tabs below the frame
	local function MakeTab(idx, label, tabKey)
		local t = CreateFrame("Button", "FWC_AuctionPanelTab" .. idx, f, "PanelTabButtonTemplate")
		t:SetID(idx)
		t:SetText(label)
		t:SetScript("OnClick", function()
			if FWC.db then FWC.db.panelTab = tabKey end
			Panel.Refresh()
		end)
		return t
	end
	local tab1 = MakeTab(1, "Writs", "writs")
	tab1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, -28)
	local tab2 = MakeTab(2, "Crates", "crates")
	tab2:SetPoint("LEFT", tab1, "RIGHT", TAB_GAP, 0)
	f.Tabs = { tab1, tab2 }
	f.numTabs = 2
	f.tabPadding, f.minTabWidth = TAB_PADDING, MIN_TAB_WIDTH

	-- Scroll list
	local inset = f.Inset or f
	if CreateScrollBoxListLinearView and ScrollUtil and ScrollUtil.InitScrollBoxListWithScrollBar then
		local scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
		scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 3, -3)
		scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 3)
		local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
		scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
		scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)
		local view = CreateScrollBoxListLinearView()
		view:SetElementExtent(ROW_HEIGHT)
		view:SetElementInitializer("Button", InitRow)
		ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
		f.ScrollBox = scrollBox
	end

	panelFrame = f
	return f
end

function Panel.Refresh()
	if not panelFrame then return end
	local tab = ActiveTab()
	panelFrame.ScanBtn:SetText(FWC.Scanner.IsRunning() and "Stop" or "Scan")

	local isWrits = (tab == "writs")
	local mode = WritSortMode()
	local cMode = CrateMode()
	panelFrame.SortBtn:SetShown(isWrits)
	if isWrits then
		panelFrame.SortBtn:SetText(SORT_LABELS[mode] or "Sort: Fast")
	end
	panelFrame.CrateModeBtn:SetShown(not isWrits)
	if not isWrits then
		panelFrame.CrateModeBtn:SetText(cMode == "bags" and "Show: Bags" or "Show: All")
	end

	local rows = panelFrame:IsShown() and BuildRows() or nil

	local scanStatus = FWC.Scanner.StatusText()
	if scanStatus then
		panelFrame.Status:SetText(scanStatus)
	else
		local book = FWC.PriceBook()
		local line1 = book.at and ("Scanned " .. FWC.FormatAge(time() - book.at)) or "Not scanned yet."
		local line2
		if not isWrits then
			if cMode == "bags" then
				local n = rows and #rows or #FWC.OwnedCrates()
				line2 = (n > 0)
					and string.format("Bag crates (%d): lowest fill cost", n)
					or "No unfilled crates in bags"
			else
				line2 = "Sorted by gold / favor"
			end
		elseif mode == "nearbags" then
			line2 = (lastBagAnchorCount > 0)
				and string.format("Closest to your %d bag writ(s)", lastBagAnchorCount)
				or "No writs in bags (showing fastest)"
		elseif mode == "fastest" then
			line2 = "Sorted by fastest travel"
		else
			line2 = "Sorted by gold / 100 rep"
		end
		panelFrame.Status:SetText(line1 .. "\n" .. line2)
	end

	local statsScope = isWrits and "writs" or (cMode == "bags" and "bagcrates" or "crates")
	local stats = FWC.PricesStats(statsScope)
	if stats and stats.used > 0 then
		panelFrame.Source:SetText(string.format("Auctionator: %d/%d (%s)", stats.used, stats.total, FWC.SeenText(stats.newest)))
		panelFrame.Source:Show()
	else
		panelFrame.Source:Hide()
	end

	if PanelTemplates_SetTab then
		PanelTemplates_SetTab(panelFrame, isWrits and 1 or 2)
	end
	if not panelFrame:IsShown() then return end
	ResizeTabs(panelFrame)

	if panelFrame.ScrollBox and CreateDataProvider and rows then
		panelFrame.ScrollBox:SetDataProvider(CreateDataProvider(rows), true)
	end
end

function Panel.Show()
	local f = EnsurePanel()
	if not f then return end
	if FWC.db then FWC.db.panelShown = true end
	f:Show()
	Panel.Refresh()
end

function Panel.Hide()
	if panelFrame then panelFrame:Hide() end
	if FWC.db then FWC.db.panelShown = false end
end

function Panel.Toggle()
	if panelFrame and panelFrame:IsShown() then Panel.Hide() else Panel.Show() end
end

local function OnAHReady()
	if not AuctionHouseFrame then return end
	EnsureButton()
	EnsurePanel()
	if FWC.BrowseAssist then FWC.BrowseAssist.Install() end
	if FWC.db and FWC.db.panelShown then Panel.Show() end
end

FWC.On("ADDON_LOADED", function(name)
	if name == "Blizzard_AuctionHouseUI" then OnAHReady() end
end)
FWC.On("AUCTION_HOUSE_SHOW", function()
	OnAHReady()
	FWC.RefreshUI()
end)

if C_AddOns and C_AddOns.IsAddOnLoaded then
	local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI")
	if (loaded == nil and loadedOrLoading or loaded) and AuctionHouseFrame then
		OnAHReady()
	end
end
