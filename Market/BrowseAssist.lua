-- Forever Writs and Crates: Auction House Browse-list highlighter and commodity quantity pre-fill.
-- When a crate or writ is clicked in our panel or planner, Blizzard's browse list shows
-- the crate/writ and its fill items together. This module highlights the cheapest fill
-- material (or required writ items) and auto-populates the needed quantity on click.
local _, FWC = ...

local Assist = {}
FWC.BrowseAssist = Assist

local highlighted = {}
local shownIDs = {}
local activeEntry = nil
local pending = nil
local installed = { highlight = false, prefill = false }

local POLL_INTERVAL = 0.2
local POLL_MAX_TRIES = 25
local VERIFY_DELAY = 0.5
local REAPPLY_MAX = 2

local function GetItemList()
	local ah = AuctionHouseFrame
	return ah and ah.BrowseResultsFrame and ah.BrowseResultsFrame.ItemList or nil
end

local function GetBuyDisplay()
	local ah = AuctionHouseFrame
	return ah and ah.CommoditiesBuyFrame and ah.CommoditiesBuyFrame.BuyDisplay or nil
end

local function HighlightCallback(rowData)
	local id = type(rowData) == "table" and type(rowData.itemKey) == "table" and rowData.itemKey.itemID or nil
	if id and highlighted[id] then
		return true, 1.0
	end
	return false
end

local function RedrawBrowseList()
	local list = GetItemList()
	if list and list.DirtyScrollFrame then pcall(list.DirtyScrollFrame, list) end
end

function Assist.Clear()
	local had = next(highlighted) ~= nil
	wipe(highlighted)
	wipe(shownIDs)
	activeEntry = nil
	if had then RedrawBrowseList() end
end

function Assist.SetContext(entry)
	Assist.Clear()
	activeEntry = entry
	if type(entry) ~= "table" then return end
	for _, id in ipairs(FWC.EntryItemIDs(entry)) do
		shownIDs[id] = true
	end
end

function Assist.HighlightEntry(entry)
	Assist.SetContext(entry)
	if FWC.EntryKind(entry) == "writ" then
		local row = FWC.Valuation.EvaluateWrit(FWC.Prices(), entry)
		for _, q in ipairs(row.needs) do
			if q.item and (q.cost or q.listed) then
				highlighted[q.item] = true
			end
		end
	else
		local row = FWC.Valuation.EvaluateCrate(FWC.Prices(), entry)
		if row.fill and row.fill.cost and row.fill.item then
			highlighted[row.fill.item] = true
		end
	end
	RedrawBrowseList()
end

function Assist.CheckForeignResults(results)
	if next(highlighted) == nil and activeEntry == nil then return end
	for _, r in ipairs(results or {}) do
		local id = type(r) == "table" and type(r.itemKey) == "table" and r.itemKey.itemID or nil
		if id and not shownIDs[id] then
			Assist.Clear()
			return
		end
	end
end

--------------------------------------------------------------------------------
-- Quantity Pre-fill
--------------------------------------------------------------------------------
local function NeededCountIn(entry, itemID)
	if type(entry) ~= "table" then return nil end
	if entry.needs then
		for _, n in ipairs(entry.needs) do
			if n.item == itemID then return n.count end
		end
		return nil
	end
	for _, b in ipairs(entry.bundles or {}) do
		for _, id in ipairs(b.items or {}) do
			if id == itemID then return b.count end
		end
	end
	return nil
end

local function WantedQuantity(itemID)
	local count = activeEntry and NeededCountIn(activeEntry, itemID)
	if count then return count end
	for _, c in ipairs(FWC.Crates()) do
		count = NeededCountIn(c, itemID)
		if count then return count end
	end
	for _, w in ipairs(FWC.WritsList()) do
		count = NeededCountIn(w, itemID)
		if count then return count end
	end
	return nil
end

local function IsDisplayReady(p)
	local display = GetBuyDisplay()
	if not display then return false end
	if display.IsVisible and not display:IsVisible() then return false end
	local ok, current = pcall(display.GetItemID, display)
	if not ok or current ~= p.itemID then return false end
	local n = 0
	if C_AuctionHouse and C_AuctionHouse.GetNumCommoditySearchResults then
		local okN, c = pcall(C_AuctionHouse.GetNumCommoditySearchResults, p.itemID)
		if okN and type(c) == "number" then n = c end
	end
	return n > 0 or display.resultsLoaded == true
end

local ApplyQuantity

local function VerifyQuantity(p)
	if pending ~= p then return end
	local display = GetBuyDisplay()
	if not display or not display.QuantityInput or not display.QuantityInput.GetQuantity then return end
	local ok, current = pcall(display.GetItemID, display)
	if not ok or current ~= p.itemID then return end
	local okQ, qty = pcall(display.QuantityInput.GetQuantity, display.QuantityInput)
	if not okQ then return end
	if (qty == 1 or qty == 0) and p.quantity ~= qty and p.reapplied < REAPPLY_MAX then
		p.reapplied = p.reapplied + 1
		ApplyQuantity(p)
	end
end

ApplyQuantity = function(p)
	local display = GetBuyDisplay()
	local input = display and display.QuantityInput
	if not input or not input.SetQuantity then return false end
	pcall(input.SetQuantity, input, p.quantity)
	local ah = AuctionHouseFrame
	if ah and ah.TriggerEvent and AuctionHouseFrameMixin and AuctionHouseFrameMixin.Event
		and AuctionHouseFrameMixin.Event.CommoditiesQuantitySelectionChanged then
		pcall(ah.TriggerEvent, ah, AuctionHouseFrameMixin.Event.CommoditiesQuantitySelectionChanged, p.quantity)
	end
	FWC.After(VERIFY_DELAY, function() VerifyQuantity(p) end)
	return true
end

local function TryApply()
	local p = pending
	if not p or p.applied then return false end
	if not IsDisplayReady(p) then return false end
	p.applied = true
	return ApplyQuantity(p)
end

local function PollPending(p)
	if pending ~= p or p.applied then return end
	p.tries = p.tries + 1
	if TryApply() then return end
	if p.tries < POLL_MAX_TRIES then
		FWC.After(POLL_INTERVAL, function() PollPending(p) end)
	end
end

local function OnSelectCommodity(itemID)
	if type(itemID) ~= "number" then return end
	if pending and pending.itemID == itemID and not pending.applied then return end
	local wanted = WantedQuantity(itemID)
	if not wanted then
		pending = nil
		return
	end
	local p = { itemID = itemID, quantity = wanted, applied = false, tries = 0, reapplied = 0 }
	pending = p
	FWC.After(POLL_INTERVAL, function() PollPending(p) end)
end

function Assist.Install()
	local ah = AuctionHouseFrame
	if not ah then return end
	if not installed.highlight then
		local list = GetItemList()
		if list and list.SetHighlightCallback then
			list:SetHighlightCallback(HighlightCallback)
			installed.highlight = true
		end
	end
	if not installed.prefill and hooksecurefunc then
		if ah.SelectBrowseResult then
			hooksecurefunc(ah, "SelectBrowseResult", function(_, browseResult)
				local id = type(browseResult) == "table" and type(browseResult.itemKey) == "table" and browseResult.itemKey.itemID or nil
				if id then OnSelectCommodity(id) end
			end)
		end
		local buy = ah.CommoditiesBuyFrame
		if buy and buy.SetItemIDAndPrice then
			hooksecurefunc(buy, "SetItemIDAndPrice", function(_, itemID) OnSelectCommodity(itemID) end)
		end
		local display = buy and buy.BuyDisplay
		if display and display.SetItemIDAndPrice then
			hooksecurefunc(display, "SetItemIDAndPrice", function(_, itemID) OnSelectCommodity(itemID) end)
		end
		if display and display.SetQuantitySelected then
			hooksecurefunc(display, "SetQuantitySelected", function() TryApply() end)
		end
		installed.prefill = true
	end
end

local function OnCommodityResults()
	if pending and not pending.applied then
		FWC.After(0, TryApply)
	end
end

FWC.On("COMMODITY_SEARCH_RESULTS_RECEIVED", OnCommodityResults)
FWC.On("COMMODITY_SEARCH_RESULTS_UPDATED", OnCommodityResults)
FWC.On("COMMODITY_SEARCH_RESULTS_ADDED", OnCommodityResults)
FWC.On("AUCTION_HOUSE_CLOSED", function()
	pending = nil
	Assist.Clear()
end)
