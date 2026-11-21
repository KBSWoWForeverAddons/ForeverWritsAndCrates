-- Forever Writs and Crates: Item tooltip enrichment for Waylaid Crates and Craftsman's Writs.
local _, FWC = ...

local appended = setmetatable({}, { __mode = "k" })

local function AppendTooltip(tooltip, data)
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
	local id = type(data) == "table" and data.id or nil
	if type(id) ~= "number" then return end

	local crate = FWC.GetCrate(id)
	local writ = (not crate) and FWC.GetWrit(id) or nil
	if not crate and not writ then return end

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
