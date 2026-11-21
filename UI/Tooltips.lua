-- Forever Writs and Crates: Item tooltip enrichment for Waylaid Crates and Craftsman's Writs.
local _, FWC = ...

local appended = setmetatable({}, { __mode = "k" })

local function FindTierInText(text)
	if type(text) ~= "string" then return nil end
	local l = text:lower()
	for _, t in ipairs(FWC.CRATE_TIERS) do
		if l:find(t, 1, true) then return t end
	end
	return nil
end

local function DetectFilledCrateFavor(id, data)
	local info = FWC.ItemInfo(id)
	local name = info and info.name
	if not name or name == "" then return nil end
	local lowerName = name:lower()

	local isCrate = lowerName:find("waylaid", 1, true)
		or (lowerName:find("crate", 1, true) and (
			lowerName:find("sealed", 1, true)
			or lowerName:find("filled", 1, true)
			or lowerName:find("completed", 1, true)
		))
	if not isCrate and lowerName:find("crate", 1, true) and type(data) == "table" and type(data.lines) == "table" then
		for _, line in ipairs(data.lines) do
			local text = type(line.leftText) == "string" and line.leftText:lower() or ""
			if text:find("completed crate", 1, true) or text:find("trade representative", 1, true) then
				isCrate = true
				break
			end
		end
	end
	if not isCrate then return nil end

	local tier = FindTierInText(lowerName)
	if not tier and type(data) == "table" and type(data.lines) == "table" then
		for _, line in ipairs(data.lines) do
			tier = FindTierInText(line.leftText) or FindTierInText(line.rightText)
			if tier then break end
		end
	end

	if not tier then
		for _, c in ipairs(FWC.Crates()) do
			for _, b in ipairs(c.bundles or {}) do
				for _, itemID in ipairs(b.items or {}) do
					local itemInfo = FWC.ItemInfo(itemID)
					local itemName = itemInfo and itemInfo.name
					if itemName and itemName ~= "" and lowerName:find(itemName:lower(), 1, true) then
						tier = c.tier
						break
					end
				end
				if tier then break end
			end
			if tier then break end
		end
	end

	if not tier then return nil end
	local q = FWC.ItemQuality(id, 1)
	local byQ = FWC.FAVOR_BY_TIER[tier]
	return byQ and byQ[q] or nil
end

local function AppendTooltip(tooltip, data)
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
	local id = type(data) == "table" and data.id or nil
	if type(id) ~= "number" then return end

	local crate = FWC.GetCrate(id)
	local writ = (not crate) and FWC.GetWrit(id) or nil
	local filledFavor = (not crate and not writ) and DetectFilledCrateFavor(id, data) or nil
	if not crate and not writ and not filledFavor then return end

	local instID = type(data) == "table" and data.dataInstanceID or nil
	if instID and appended[tooltip] == instID then return end
	appended[tooltip] = instID

	local book = FWC.Prices()
	tooltip:AddLine(" ")
	tooltip:AddLine("Forever Writs & Crates", 0.2, 0.8, 1)

	if crate then
		local row = FWC.Valuation.EvaluateCrate(book, crate)
		if row.favor then
			tooltip:AddLine(string.format("Gives %d %s", row.favor, FWC.FavorName()), 0.9, 0.9, 0.9)
		end
		if FWC.AuctionPanel then FWC.AuctionPanel.AddCrateTooltipLines(tooltip, row) end
	elseif filledFavor then
		tooltip:AddLine(string.format("Gives %d %s", filledFavor, FWC.FavorName()), 0.9, 0.9, 0.9)
	else
		local row = FWC.Valuation.EvaluateWrit(book, writ)
		row.travelSecs = FWC.RoutePlanner.EstimateWritTravelSecs(writ)
		if row.rep then
			tooltip:AddLine(string.format("Gives %d reputation with %s", row.rep, FWC.Rep.FactionName()), 0.9, 0.9, 0.9)
		end
		if FWC.AuctionPanel then FWC.AuctionPanel.AddWritTooltipLines(tooltip, row) end
	end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
	and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AppendTooltip)
end
