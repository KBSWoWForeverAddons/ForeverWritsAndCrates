-- Forever Writs and Crates: Auction House scanner and browse-list search.
local _, FWC = ...

local Scanner = {}
FWC.Scanner = Scanner

Scanner.BATCH_SIZE = 20
Scanner.TIMEOUT = 12
Scanner.MAX_RETRIES = 3
Scanner.MAX_BATCH_FAILS = 2

local active = nil

local function GetSorts()
	local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
	return { { sortOrder = order, reverseSort = false } }
end

function Scanner.Available()
	return C_AuctionHouse ~= nil
		and C_AuctionHouse.SearchForItemKeys ~= nil
		and C_AuctionHouse.SendSearchQuery ~= nil
		and C_AuctionHouse.MakeItemKey ~= nil
end

function Scanner.IsRunning()
	return active ~= nil and active.kind ~= "show"
end

function Scanner.StatusText()
	if not active or active.kind == "show" then return nil end
	if active.waiting then return "Waiting for Auction House..." end
	if active.kind == "quick" then
		return string.format("Scanning %d / %d items...", active.done, active.total)
	end
	return string.format("Checking %s (%d / %d)...", FWC.ItemName(active.entry.id), active.done, active.total)
end

local function IsThrottleReady()
	if C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady then
		local ok, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
		return not ok or ready ~= false
	end
	return true
end

local function SavePrice(itemID, entry)
	local book = FWC.PriceBook()
	entry.at = time()
	book.items[itemID] = entry
	book.at = time()
	if FWC.AuctionatorBridge then FWC.AuctionatorBridge.Invalidate() end
end

local function NewJob(kind)
	return {
		kind = kind,
		queue = {},
		done = 0,
		answered = 0,
		total = 0,
		startedAt = GetTime(),
		batchFails = 0,
	}
end

local function DropShowJob()
	if active and active.kind == "show" then active = nil end
end

local Step, FailRequest

function Scanner.StartQuick(scope)
	DropShowJob()
	if active then return false end
	if not Scanner.Available() then
		FWC.Print("Auction House search API is unavailable.")
		return false
	end
	scope = scope or (FWC.db and FWC.db.panelTab) or "writs"
	local ids = FWC.AllItemIDs(scope)
	if #ids == 0 then
		if scope == "bagcrates" then
			FWC.Print("No unfilled crates found in your bags.")
		end
		return false
	end

	if FWC.BrowseAssist then FWC.BrowseAssist.Clear() end
	active = NewJob("quick")
	active.scope = scope
	active.total = #ids
	local i = 1
	while i <= #ids do
		local batch = {}
		for j = i, math.min(i + Scanner.BATCH_SIZE - 1, #ids) do
			batch[#batch + 1] = ids[j]
		end
		active.queue[#active.queue + 1] = { mode = "keys", ids = batch, tries = 0 }
		i = i + Scanner.BATCH_SIZE
	end
	FWC.RefreshUI()
	Step()
	return true
end

function Scanner.StartExact(entry)
	DropShowJob()
	if active or type(entry) ~= "table" then return false end
	if not Scanner.Available() then return false end

	active = NewJob("exact")
	active.entry = entry
	for _, id in ipairs(FWC.EntryItemIDs(entry)) do
		active.queue[#active.queue + 1] = { mode = "single", id = id, tries = 0 }
	end
	active.total = #active.queue
	FWC.RefreshUI()
	Step()
	return true
end

-- Shows a crate or writ AND all of its required fill items together in Blizzard's AH Browse list,
-- refreshes their prices, and highlights the target materials with quantity pre-fill.
function Scanner.ShowInAuctionHouse(entry)
	if type(entry) ~= "table" or not Scanner.Available() or not FWC.AuctionHouseOpen() then
		if not FWC.AuctionHouseOpen() then
			FWC.Print("Open the Auction House to search for %s.", FWC.ItemName(entry and entry.id or 0))
		end
		return false
	end
	if active and active.kind ~= "show" then
		Scanner.Cancel("Scan paused for your search.")
	end
	active = nil
	if not IsThrottleReady() then
		FWC.Print("Auction House is busy; try again in a moment.")
		return false
	end

	local ah = AuctionHouseFrame
	if ah.SetDisplayMode and AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Buy then
		pcall(ah.SetDisplayMode, ah, AuctionHouseFrameDisplayMode.Buy)
	end
	if ah.TriggerEvent and AuctionHouseFrameMixin and AuctionHouseFrameMixin.Event
		and AuctionHouseFrameMixin.Event.BrowseSearchStarted then
		pcall(ah.TriggerEvent, ah, AuctionHouseFrameMixin.Event.BrowseSearchStarted)
	end

	if FWC.BrowseAssist then FWC.BrowseAssist.SetContext(entry) end

	local ids = FWC.EntryItemIDs(entry)
	active = NewJob("show")
	active.entry = entry
	active.total = #ids
	active.queue[1] = { mode = "keys", ids = ids, tries = 0 }
	Step()
	return true
end

function Scanner.Cancel(msg)
	if not active then return end
	local wasShow = (active.kind == "show")
	active = nil
	if msg and not wasShow then FWC.Print(msg) end
	FWC.RefreshUI()
end

local function CompleteJob()
	local job = active
	active = nil
	if job.kind == "quick" then
		FWC.Print("Scan complete: %d of %d items checked in %s.",
			job.answered, job.total, FWC.FormatTime(GetTime() - job.startedAt))
	elseif job.kind == "exact" then
		FWC.Print("Exact price check finished for %s.", FWC.ItemName(job.entry.id))
	elseif job.kind == "show" and FWC.BrowseAssist then
		FWC.BrowseAssist.HighlightEntry(job.entry)
	end
	FWC.RefreshUI()
end

local function Advance(job, req)
	job.current = nil
	local count = (req.mode == "keys") and #req.ids or 1
	job.done = job.done + count
	job.answered = job.answered + count
	job.batchFails = 0
	FWC.RefreshUI()
	Step()
end

Step = function()
	local job = active
	if not job or job.current then return end
	local req = table.remove(job.queue, 1)
	if not req then
		CompleteJob()
		return
	end
	if not IsThrottleReady() then
		table.insert(job.queue, 1, req)
		if not job.waiting then
			job.waiting = true
			FWC.After(0.5, function()
				if active == job and job.waiting then
					job.waiting = false
					Step()
				end
			end)
			FWC.RefreshUI()
		end
		return
	end

	job.waiting = false
	job.current = req
	req.tries = req.tries + 1

	local ok, err
	if req.mode == "keys" then
		local keys, pending = {}, {}
		for _, id in ipairs(req.ids) do
			keys[#keys + 1] = C_AuctionHouse.MakeItemKey(id)
			pending[id] = true
		end
		req.pending = pending
		ok, err = pcall(C_AuctionHouse.SearchForItemKeys, keys, GetSorts())
	else
		req.key = C_AuctionHouse.MakeItemKey(req.id)
		ok, err = pcall(C_AuctionHouse.SendSearchQuery, req.key, GetSorts(), false)
	end

	if not ok then
		FailRequest(job, req, tostring(err))
		return
	end

	FWC.After(Scanner.TIMEOUT, function()
		if active == job and job.current == req then
			FailRequest(job, req, "timeout")
		end
	end)
	FWC.RefreshUI()
end

FailRequest = function(job, req, reason)
	if job.current ~= req then return end
	job.current = nil
	if job.kind == "show" then
		active = nil
		FWC.RefreshUI()
		return
	end
	if req.mode == "keys" then
		job.batchFails = job.batchFails + 1
		if job.batchFails < Scanner.MAX_BATCH_FAILS and req.tries < 2 then
			table.insert(job.queue, 1, req)
		else
			-- Fall back to single-item queries
			local singles = {}
			for _, id in ipairs(req.ids) do singles[#singles + 1] = { mode = "single", id = id, tries = 0 } end
			for _, other in ipairs(job.queue) do
				if other.mode == "keys" then
					for _, id in ipairs(other.ids) do singles[#singles + 1] = { mode = "single", id = id, tries = 0 } end
				else
					singles[#singles + 1] = other
				end
			end
			job.queue = singles
		end
	elseif req.tries < Scanner.MAX_RETRIES then
		table.insert(job.queue, 1, req)
	else
		job.done = job.done + 1
	end
	Step()
end

--------------------------------------------------------------------------------
-- Auction House Event Handlers
--------------------------------------------------------------------------------
local function OnBrowseResults()
	local job = active
	local req = job and job.current
	if not req or req.mode ~= "keys" then
		if not job and FWC.BrowseAssist and C_AuctionHouse and C_AuctionHouse.GetBrowseResults then
			local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
			if ok and type(results) == "table" then
				FWC.BrowseAssist.CheckForeignResults(results)
			end
		end
		return
	end
	if C_AuctionHouse.HasFullBrowseResults and not C_AuctionHouse.HasFullBrowseResults() then
		if C_AuctionHouse.RequestMoreBrowseResults then pcall(C_AuctionHouse.RequestMoreBrowseResults) end
		return
	end
	local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
	if not ok or type(results) ~= "table" then return end

	local foreign, seen = 0, {}
	for _, r in ipairs(results) do
		local id = type(r) == "table" and type(r.itemKey) == "table" and r.itemKey.itemID or nil
		if id and req.pending[id] then
			local prev = seen[id]
			local price = tonumber(r.minPrice)
			local qty = tonumber(r.totalQuantity) or 0
			if not prev then
				seen[id] = { min = price, qty = qty, own = r.containsOwnerItem or nil }
			else
				prev.qty = prev.qty + qty
				if price and (not prev.min or price < prev.min) then prev.min = price end
			end
		else
			foreign = foreign + 1
		end
	end
	if foreign > 0 then return end

	for id in pairs(req.pending) do
		local r = seen[id]
		if r then
			SavePrice(id, { min = r.min, qty = r.qty, own = r.own })
		else
			SavePrice(id, { qty = 0 })
		end
	end
	Advance(job, req)
end

local function ReadCommodityExact(itemID)
	if C_AuctionHouse.HasFullCommoditySearchResults and not C_AuctionHouse.HasFullCommoditySearchResults(itemID) then
		if C_AuctionHouse.RequestMoreCommoditySearchResults then
			pcall(C_AuctionHouse.RequestMoreCommoditySearchResults, itemID)
		end
		return nil
	end
	local n = (C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID)) or 0
	local levels, qty, minPrice = {}, 0, nil
	for i = 1, n do
		local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
		if type(r) == "table" and type(r.unitPrice) == "number" and type(r.quantity) == "number" then
			local avail = r.quantity - (tonumber(r.numOwnerItems) or 0)
			if r.containsAccountItem and avail == r.quantity then avail = 0 end
			if avail > 0 then
				levels[#levels + 1] = { unit = r.unitPrice, qty = avail }
				qty = qty + avail
				if not minPrice or r.unitPrice < minPrice then minPrice = r.unitPrice end
			end
		end
	end
	return { min = minPrice, qty = qty, exact = levels }
end

local function ReadItemExact(key)
	if C_AuctionHouse.HasFullItemSearchResults and not C_AuctionHouse.HasFullItemSearchResults(key) then
		if C_AuctionHouse.RequestMoreItemSearchResults then
			pcall(C_AuctionHouse.RequestMoreItemSearchResults, key)
		end
		return nil
	end
	local n = (C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(key)) or 0
	local levels, qty, minPrice = {}, 0, nil
	for i = 1, n do
		local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
		if type(r) == "table" and type(r.quantity) == "number" and r.quantity > 0
			and type(r.buyoutAmount) == "number" and r.buyoutAmount > 0
			and not r.containsOwnerItem and not r.containsAccountItem then
			local unit = r.buyoutAmount / r.quantity
			levels[#levels + 1] = { unit = unit, qty = r.quantity, whole = true }
			qty = qty + r.quantity
			if not minPrice or unit < minPrice then minPrice = unit end
		end
	end
	return { min = minPrice, qty = qty, exact = levels }
end

local function HandleSingleResult(itemID, isCommodity)
	local job = active
	local req = job and job.current
	if not req or req.mode ~= "single" or req.id ~= itemID then return end
	local data = isCommodity and ReadCommodityExact(itemID) or ReadItemExact(req.key)
	if not data then return end
	SavePrice(itemID, data)
	Advance(job, req)
end

FWC.On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", OnBrowseResults)
FWC.On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", OnBrowseResults)
FWC.On("COMMODITY_SEARCH_RESULTS_UPDATED", function(id) HandleSingleResult(id, true) end)
FWC.On("COMMODITY_SEARCH_RESULTS_ADDED", function(id) HandleSingleResult(id, true) end)
FWC.On("ITEM_SEARCH_RESULTS_UPDATED", function(key)
	local id = type(key) == "table" and key.itemID or nil
	if id then HandleSingleResult(id, false) end
end)
FWC.On("ITEM_SEARCH_RESULTS_ADDED", function(key)
	local id = type(key) == "table" and key.itemID or nil
	if id then HandleSingleResult(id, false) end
end)
FWC.On("AUCTION_HOUSE_NEW_RESULTS_RECEIVED", function(key)
	local job = active
	local req = job and job.current
	local id = type(key) == "table" and key.itemID or nil
	if not req or req.mode ~= "single" or id ~= req.id then return end
	if C_AuctionHouse.GetNumCommoditySearchResults and (C_AuctionHouse.GetNumCommoditySearchResults(id) or 0) > 0 then
		HandleSingleResult(id, true)
	elseif C_AuctionHouse.GetNumItemSearchResults and (C_AuctionHouse.GetNumItemSearchResults(req.key) or 0) > 0 then
		HandleSingleResult(id, false)
	end
end)
FWC.On("AUCTION_HOUSE_BROWSE_FAILURE", function()
	if active and active.current and active.current.mode == "keys" then
		FailRequest(active, active.current, "browse failure")
	end
end)
FWC.On("AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", function()
	if active and active.current then FailRequest(active, active.current, "dropped") end
end)
FWC.On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function()
	if active and active.waiting then
		active.waiting = false
		Step()
	end
end)
FWC.On("AUCTION_HOUSE_CLOSED", function()
	Scanner.Cancel(active and "Scan stopped: Auction House closed." or nil)
end)
