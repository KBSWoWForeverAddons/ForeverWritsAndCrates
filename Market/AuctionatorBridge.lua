-- Forever Writs and Crates: Auctionator price integration.
-- Overlays newer prices from Auctionator's database onto our realm price book
-- without mutating SavedVariables, and refreshes when Auctionator finishes scans.
local ADDON_NAME, FWC = ...

local Bridge = {}
FWC.AuctionatorBridge = Bridge

local DAY_SECONDS = 86400
local CACHE_TTL = 5

local cachedView = nil
local hookedBus = nil

local function GetAuctionator()
	local at = _G.Auctionator
	return type(at) == "table" and at or nil
end

function Bridge.Available()
	local at = GetAuctionator()
	local v1 = at and type(at.API) == "table" and type(at.API.v1) == "table" and at.API.v1
	return v1 ~= nil
		and type(v1.GetAuctionPriceByItemID) == "function"
		and type(v1.GetAuctionAgeByItemID) == "function"
		and type(at.Database) == "table"
end

local function ScanDay0()
	local at = GetAuctionator()
	local c = at and type(at.Constants) == "table" and at.Constants.SCAN_DAY_0
	return type(c) == "number" and c or nil
end

local function EpochToScanDay(epoch)
	local d0 = ScanDay0()
	if not d0 or type(epoch) ~= "number" then return nil end
	return math.floor((epoch - d0) / DAY_SECONDS)
end

local function ReadQuantity(at, itemID)
	local db = type(at.Database) == "table" and at.Database.db
	local rec = type(db) == "table" and db[tostring(itemID)]
	if type(rec) ~= "table" or type(rec.a) ~= "table" then return nil end
	local bestDay, qty
	for dStr, count in pairs(rec.a) do
		local d = tonumber(dStr)
		if d and type(count) == "number" and (not bestDay or d > bestDay) then
			bestDay, qty = d, count
		end
	end
	return qty
end

function Bridge.GetEntry(itemID)
	if not Bridge.Available() then return nil end
	local at = GetAuctionator()
	local okP, price = pcall(at.API.v1.GetAuctionPriceByItemID, ADDON_NAME, itemID)
	if not okP or type(price) ~= "number" or price <= 0 then return nil end
	local okA, age = pcall(at.API.v1.GetAuctionAgeByItemID, ADDON_NAME, itemID)
	if not okA or type(age) ~= "number" then return nil end
	if age < 0 then age = 0 end
	local today = EpochToScanDay(time())
	local day = today and (today - age) or nil
	local d0 = ScanDay0()
	return {
		min = price,
		qty = ReadQuantity(at, itemID),
		source = "auctionator",
		seenDays = age,
		day = day,
		at = (d0 and day) and (d0 + day * DAY_SECONDS) or (time() - age * DAY_SECONDS),
	}
end

local function IsNewer(theirs, ours)
	if type(ours) ~= "table" or type(ours.at) ~= "number" then return true end
	local ourDay = EpochToScanDay(ours.at)
	if not ourDay or type(theirs.day) ~= "number" then return false end
	return theirs.day > ourDay
end

function Bridge.Invalidate()
	cachedView = nil
end

-- Returns the merged price book (own scan + newer Auctionator prices).
function FWC.Prices()
	local own = FWC.PriceBook()
	if not Bridge.Available() then
		cachedView = nil
		return own
	end
	local key = FWC.RealmKey()
	local now = GetTime()
	if cachedView and cachedView.own == own and cachedView.key == key and (now - cachedView.builtAt) < CACHE_TTL then
		return cachedView.data
	end

	local merged = {}
	for id, entry in pairs(own.items) do merged[id] = entry end

	local used, newest, newestAt = 0, nil, nil
	for _, id in ipairs(FWC.AllItemIDs("all")) do
		local theirs = Bridge.GetEntry(id)
		if theirs and IsNewer(theirs, own.items[id]) then
			merged[id] = theirs
			used = used + 1
			if not newest or theirs.seenDays < newest then
				newest, newestAt = theirs.seenDays, theirs.at
			end
		end
	end

	local data = {
		items = merged,
		at = own.at,
		own = own,
		auctionator = { used = used, newest = newest, at = newestAt },
		stats = {},
	}
	cachedView = { own = own, key = key, builtAt = now, data = data }
	return data
end

function FWC.PricesStats(scope)
	local data = FWC.Prices()
	if not data.auctionator then return nil end
	scope = scope or "all"
	if data.stats[scope] then return data.stats[scope] end
	local ids = FWC.AllItemIDs(scope)
	local s = { total = #ids, used = 0, newest = nil }
	for _, id in ipairs(ids) do
		local e = data.items[id]
		if e and e.source == "auctionator" then
			s.used = s.used + 1
			if not s.newest or e.seenDays < s.newest then s.newest = e.seenDays end
		end
	end
	data.stats[scope] = s
	return s
end

function FWC.PricesAge()
	local data = FWC.Prices()
	local newest = data.at
	if data.auctionator and data.auctionator.at and (not newest or data.auctionator.at > newest) then
		newest = data.auctionator.at
	end
	if not newest then return nil, true end
	local age = time() - newest
	return age, age > FWC.STALE_AFTER
end

-- Subscribe to Auctionator's EventBus so UI updates automatically after Auctionator scans.
local listener = {
	ReceiveEvent = function()
		Bridge.Invalidate()
		FWC.RefreshUI()
	end,
}

local function HookEventBus()
	local at = GetAuctionator()
	local bus = at and at.EventBus
	if type(bus) ~= "table" or type(bus.Register) ~= "function" then return end
	if hookedBus == bus then return end
	local events = {}
	if type(at.IncrementalScan) == "table" and type(at.IncrementalScan.Events) == "table" then
		if at.IncrementalScan.Events.PricesProcessed then events[#events + 1] = at.IncrementalScan.Events.PricesProcessed end
		if at.IncrementalScan.Events.ScanComplete then events[#events + 1] = at.IncrementalScan.Events.ScanComplete end
	end
	if type(at.FullScan) == "table" and type(at.FullScan.Events) == "table" then
		if at.FullScan.Events.ScanComplete then events[#events + 1] = at.FullScan.Events.ScanComplete end
	end
	if #events > 0 and pcall(bus.Register, bus, listener, events) then
		hookedBus = bus
	end
end

FWC.On("ADDON_LOADED", function(name)
	if name == ADDON_NAME or name == "Auctionator" then HookEventBus() end
end)
FWC.On("PLAYER_LOGIN", function()
	HookEventBus()
	Bridge.Invalidate()
end)
