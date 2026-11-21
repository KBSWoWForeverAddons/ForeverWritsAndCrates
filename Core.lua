-- Forever Writs and Crates: Core namespace, saved variables, event hub,
-- item/bag/reputation/quest utilities, and slash commands.
local ADDON_NAME, FWC = ...
ForeverWritsAndCrates = FWC

local format = string.format
local floor = math.floor

FWC.name = ADDON_NAME
FWC.title = "Forever Writs and Crates"
FWC.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.0.0"

--------------------------------------------------------------------------------
-- Game Constants (WoW: Forever)
--------------------------------------------------------------------------------
FWC.FAVOR_CURRENCY_ID = 3402
FWC.CRATE_TIERS = { "apprentice", "journeyman", "expert", "artisan" }
FWC.FAVOR_BY_TIER = {
	apprentice = { [1] = 5,  [2] = 10 },
	journeyman = { [1] = 10, [2] = 20 },
	expert     = { [1] = 15, [2] = 30 },
	artisan    = { [1] = 20, [2] = 40 },
}

FWC.RECEIPT_ITEM = 262902
FWC.RECEIPT_FAVOR = 15
FWC.RECEIPT_REP = 50
FWC.RECEIPT_MIN_STANDING = 5 -- Friendly
FWC.RECEIPT_ICON = "Interface\\Icons\\inv_10_inscription2_repcontracts_scroll_02_uprez_color5"

FWC.CRATE_ICON = "Interface\\Icons\\INV_Crate_07"
FWC.WRIT_ICON = "Interface\\Icons\\INV_Misc_Note_01"
FWC.FAVOR_ICON = 135725
FWC.STALE_AFTER = 24 * 3600

FWC.FACTIONS = {
	Alliance = { id = 2586, name = "Azeroth Commerce Authority" },
	Horde    = { id = 2587, name = "Durotar Supply and Logistics" },
}

FWC.STANDING_THRESHOLDS = {
	[1] = -42000, [2] = -6000, [3] = -3000, [4] = 0,
	[5] = 3000,   [6] = 9000,  [7] = 21000, [8] = 42000,
}
FWC.STANDING_NAMES = {
	"Hated", "Hostile", "Unfriendly", "Neutral",
	"Friendly", "Honored", "Revered", "Exalted",
}
FWC.TARGET_STANDINGS = { 5, 6, 7, 8 }

FWC.PROFESSION_SKILL_LINES = {
	alchemy = 171, blacksmithing = 164, enchanting = 333, engineering = 202,
	leatherworking = 165, tailoring = 197, cooking = 185,
}
FWC.TIER_ORDER = { journeyman = 1, expert = 2, artisan = 3 }
FWC.TIER_LABELS = { journeyman = "Journeyman", expert = "Expert", artisan = "Artisan" }
FWC.TIER_REP = { journeyman = 75, expert = 125, artisan = 200 }

local CHAT_PREFIX = "|cff33ccffForever Writs & Crates:|r "

function FWC.Print(msg, ...)
	if select("#", ...) > 0 then
		msg = format(tostring(msg), ...)
	end
	local frame = DEFAULT_CHAT_FRAME or ChatFrame1
	if frame and frame.AddMessage then
		frame:AddMessage(CHAT_PREFIX .. tostring(msg))
	end
end

-- Safe call wrapper that also guards against WoW secret values.
function FWC.SafeCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, val = pcall(fn, ...)
	if not ok then return nil end
	if issecretvalue and issecretvalue(val) then return nil end
	return val
end

function FWC.After(seconds, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seconds, fn)
	else
		fn()
	end
end

--------------------------------------------------------------------------------
-- Event Bus
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = eventHandlers[event]
	if not list then return end
	for i = 1, #list do
		pcall(list[i], ...)
	end
end)

function FWC.On(event, fn)
	if eventHandlers[event] then
		eventHandlers[event][#eventHandlers[event] + 1] = fn
		return true
	end
	local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
	if ok then
		eventHandlers[event] = { fn }
	end
	return ok
end

local refreshQueued = false
function FWC.RefreshUI()
	if refreshQueued then return end
	refreshQueued = true
	FWC.After(0.1, function()
		refreshQueued = false
		if FWC.AuctionPanel and FWC.AuctionPanel.Refresh then FWC.AuctionPanel.Refresh() end
		if FWC.PlannerWindow and FWC.PlannerWindow.Refresh then FWC.PlannerWindow.Refresh() end
		if FWC.RouteGuide and FWC.RouteGuide.Refresh then FWC.RouteGuide.Refresh() end
	end)
end

--------------------------------------------------------------------------------
-- SavedVariables
--------------------------------------------------------------------------------
function FWC.InitDB()
	if type(ForeverWritsAndCratesDB) ~= "table" then ForeverWritsAndCratesDB = {} end
	local db = ForeverWritsAndCratesDB
	db.version = 1
	if db.panelShown == nil then db.panelShown = true end
	if db.panelTab ~= "writs" and db.panelTab ~= "crates" then db.panelTab = "writs" end
	if db.writSort ~= "fastest" and db.writSort ~= "cheapest" then db.writSort = "fastest" end
	if db.autoQuest == nil then db.autoQuest = true end
	if db.includeCompletedQuests == nil then db.includeCompletedQuests = true end
	db.realms = type(db.realms) == "table" and db.realms or {}
	db.learnedLocations = type(db.learnedLocations) == "table" and db.learnedLocations or {}
	db.turnedIn = type(db.turnedIn) == "table" and db.turnedIn or {}
	db.planner = type(db.planner) == "table" and db.planner or {}
	if db.planner.favorWanted == nil then db.planner.favorWanted = 100 end
	if db.planner.planKind ~= "fastest" and db.planner.planKind ~= "cheapest" then db.planner.planKind = "fastest" end
	db.minimap = type(db.minimap) == "table" and db.minimap or {}
	if db.minimap.shown == nil then db.minimap.shown = true end
	if db.minimap.angle == nil then db.minimap.angle = 210 end
	FWC.db = db

	if type(ForeverWritsAndCratesCharDB) ~= "table" then ForeverWritsAndCratesCharDB = {} end
	local cdb = ForeverWritsAndCratesCharDB
	cdb.route = type(cdb.route) == "table" and cdb.route or {}
	cdb.manualSteps = type(cdb.manualSteps) == "table" and cdb.manualSteps or {}
	cdb.questSelection = type(cdb.questSelection) == "table" and cdb.questSelection or {}
	if cdb.pendingMail == nil then cdb.pendingMail = false end
	if cdb.guideShown == nil then cdb.guideShown = false end
	FWC.charDB = cdb
	FWC.loaded = true
end

function FWC.RealmKey()
	local realm = (GetRealmName and GetRealmName()) or "Unknown"
	local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
	return tostring(realm) .. "-" .. tostring(faction)
end

local emptyBook = { items = {} }
function FWC.PriceBook()
	if not FWC.db then return emptyBook end
	local key = FWC.RealmKey()
	local book = FWC.db.realms[key]
	if type(book) ~= "table" then
		book = { items = {} }
		FWC.db.realms[key] = book
	end
	if type(book.items) ~= "table" then book.items = {} end
	return book
end

function FWC.ResetPriceBook()
	if not FWC.db then return end
	local key = FWC.RealmKey()
	FWC.db.realms[key] = nil
	if FWC.AuctionatorBridge then FWC.AuctionatorBridge.Invalidate() end
	FWC.Print("Cleared scanned prices for %s.", key)
	FWC.RefreshUI()
end

function FWC.BookAge()
	local book = FWC.PriceBook()
	if not book.at then return nil, true end
	local age = time() - book.at
	return age, age > FWC.STALE_AFTER
end

function FWC.AuctionHouseOpen()
	return AuctionHouseFrame ~= nil and AuctionHouseFrame:IsShown()
end

--------------------------------------------------------------------------------
-- Catalogue Lookup Helpers
--------------------------------------------------------------------------------
local crateByID, writByID, writByQuest

local function EnsureIndexes()
	if not crateByID and FWC.Data and FWC.Data.Crates then
		crateByID = {}
		for _, c in ipairs(FWC.Data.Crates) do crateByID[c.id] = c end
	end
	if not writByID and FWC.Data and FWC.Data.Writs then
		writByID, writByQuest = {}, {}
		for _, w in ipairs(FWC.Data.Writs) do
			writByID[w.id] = w
			if w.quest then writByQuest[w.quest] = w end
		end
	end
end

function FWC.Crates() return (FWC.Data and FWC.Data.Crates) or {} end
function FWC.WritsList() return (FWC.Data and FWC.Data.Writs) or {} end

function FWC.GetCrate(id)
	EnsureIndexes()
	return crateByID and crateByID[id] or nil
end

function FWC.GetWrit(id)
	EnsureIndexes()
	return writByID and writByID[id] or nil
end

function FWC.GetWritByQuest(questID)
	EnsureIndexes()
	return writByQuest and writByQuest[questID] or nil
end

function FWC.EntryKind(entry)
	if type(entry) ~= "table" then return nil end
	return entry.needs and "writ" or "crate"
end

function FWC.EntryItemIDs(entry)
	local ids, seen = {}, {}
	local function add(id)
		if type(id) == "number" and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end
	if type(entry) == "table" then
		add(entry.id)
		if entry.needs then
			for _, n in ipairs(entry.needs) do add(n.item) end
		else
			for _, b in ipairs(entry.bundles or {}) do
				for _, id in ipairs(b.items or {}) do add(id) end
			end
		end
	end
	return ids
end

function FWC.AllItemIDs(scope)
	scope = scope or "all"
	local ids, seen = {}, {}
	local function addEntry(entry)
		for _, id in ipairs(FWC.EntryItemIDs(entry)) do
			if not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
	end
	if scope == "crates" or scope == "all" then
		for _, c in ipairs(FWC.Crates()) do addEntry(c) end
	end
	if scope == "writs" or scope == "all" then
		for _, w in ipairs(FWC.WritsList()) do addEntry(w) end
	end
	table.sort(ids)
	return ids
end

--------------------------------------------------------------------------------
-- Item & Bag Cache
--------------------------------------------------------------------------------
local itemCache = {}

function FWC.ItemInfo(id)
	local e = itemCache[id]
	if e and e.loaded then return e end
	if not e then
		e = { id = id }
		itemCache[id] = e
	end
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if type(name) == "string" and name ~= "" then
		e.name = name
		e.icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or nil
		e.quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id) or nil
		if C_Item.GetItemInfo then
			local level = select(5, C_Item.GetItemInfo(id))
			if type(level) == "number" then e.level = level end
		end
		e.loaded = true
	elseif not e.requested and not e.failed then
		e.requested = true
		if C_Item and C_Item.RequestLoadItemDataByID then
			pcall(C_Item.RequestLoadItemDataByID, id)
		end
	end
	return e
end

function FWC.ItemName(id)
	local e = FWC.ItemInfo(id)
	return e.name or ("Item #" .. tostring(id))
end

function FWC.ItemIcon(id)
	return FWC.ItemInfo(id).icon
end

function FWC.ItemQuality(id, fallback)
	local q = FWC.ItemInfo(id).quality
	if type(q) == "number" then return q end
	return fallback or 1
end

function FWC.QualityColor(quality)
	if C_Item and C_Item.GetItemQualityColor and type(quality) == "number" then
		local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
		if ok and type(r) == "number" then return r, g, b end
	end
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

-- Bag counts (excludes equipped items so equipped quivers/gear aren't counted as turn-in items).
local bagCounts
local function RebuildBagCounts()
	local C = C_Container
	local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
	local getItemID = (C and C.GetContainerItemID) or GetContainerItemID
	local getInfo = (C and C.GetContainerItemInfo) or GetContainerItemInfo
	if not (numSlots and getItemID and getInfo) then return nil end
	local counts = {}
	local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, maxBag do
		for slot = 1, (numSlots(bag) or 0) do
			local id = getItemID(bag, slot)
			if id then
				local info = getInfo(bag, slot)
				local stack = type(info) == "table" and info.stackCount or select(2, getInfo(bag, slot)) or 1
				counts[id] = (counts[id] or 0) + (stack or 1)
			end
		end
	end
	return counts
end

function FWC.BagCount(id)
	if not id then return 0 end
	if not bagCounts then bagCounts = RebuildBagCounts() end
	if bagCounts then return bagCounts[id] or 0 end
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(id) or 0
	end
	return 0
end

local function OnItemLoaded(itemID, success)
	local e = itemCache[itemID]
	if not e then return end
	e.requested = nil
	if success == false then e.failed = true end
	FWC.RefreshUI()
end
FWC.On("ITEM_DATA_LOAD_RESULT", OnItemLoaded)
FWC.On("GET_ITEM_INFO_RECEIVED", OnItemLoaded)
FWC.On("BAG_UPDATE_DELAYED", function() bagCounts = nil; FWC.RefreshUI() end)
FWC.On("BAG_UPDATE", function() bagCounts = nil end)

--------------------------------------------------------------------------------
-- Currency (Merchant's Favor)
--------------------------------------------------------------------------------
function FWC.CrateFavor(crate)
	if not crate then return nil end
	local q = FWC.ItemQuality(crate.id, crate.quality)
	local byQ = FWC.FAVOR_BY_TIER[crate.tier or "apprentice"]
	return byQ and byQ[q] or nil
end

local function GetFavorCurrencyInfo()
	if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, FWC.FAVOR_CURRENCY_ID)
		if ok and type(info) == "table" then return info end
	end
	return nil
end

function FWC.FavorName()
	local info = GetFavorCurrencyInfo()
	return (info and info.name and info.name ~= "") and info.name or "Merchant's Favor"
end

function FWC.FavorOwned()
	local info = GetFavorCurrencyInfo()
	return (info and type(info.quantity) == "number") and info.quantity or nil
end

--------------------------------------------------------------------------------
-- Reputation & Auto-Populated Goal
--------------------------------------------------------------------------------
FWC.Rep = {}

function FWC.Rep.PlayerSide()
	local side = FWC.SafeCall(UnitFactionGroup, "player")
	return (side == "Alliance" or side == "Horde") and side or "Alliance"
end

function FWC.Rep.FactionID(side)
	side = side or FWC.Rep.PlayerSide()
	local f = FWC.FACTIONS[side]
	return f and f.id or 2586
end

function FWC.Rep.FactionName(side)
	local id = FWC.Rep.FactionID(side)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, data = pcall(C_Reputation.GetFactionDataByID, id)
		if ok and type(data) == "table" and type(data.name) == "string" and data.name ~= "" then
			return data.name
		end
	end
	local f = FWC.FACTIONS[side or FWC.Rep.PlayerSide()]
	return f and f.name or "Supply Faction"
end

function FWC.Rep.StandingLabel(reaction)
	local globalLabel = _G["FACTION_STANDING_LABEL" .. tostring(reaction)]
	if type(globalLabel) == "string" and globalLabel ~= "" then return globalLabel end
	return FWC.STANDING_NAMES[reaction] or tostring(reaction)
end

function FWC.Rep.GetStatus(side)
	local id = FWC.Rep.FactionID(side)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, data = pcall(C_Reputation.GetFactionDataByID, id)
		if ok and type(data) == "table" and type(data.currentStanding) == "number" then
			local r = tonumber(data.reaction) or 4
			return {
				factionID = id,
				name = data.name or FWC.Rep.FactionName(side),
				reaction = r,
				standing = data.currentStanding,
				bottom = tonumber(data.currentReactionThreshold) or FWC.STANDING_THRESHOLDS[r] or 0,
				top = tonumber(data.nextReactionThreshold) or FWC.STANDING_THRESHOLDS[r + 1] or 42999,
				known = true,
			}
		end
	end
	return {
		factionID = id,
		name = FWC.Rep.FactionName(side),
		reaction = 4,
		standing = 0,
		bottom = 0,
		top = 3000,
		known = false,
	}
end

-- Auto-populates the goal to the next standing above current standing:
-- Neutral -> Friendly (5), Friendly -> Honored (6), Honored -> Revered (7), Revered -> Exalted (8).
function FWC.Rep.AutoTargetStanding(status)
	status = status or FWC.Rep.GetStatus()
	local r = status.reaction or 4
	if r < 5 then return 5 end
	if r < 8 then return r + 1 end
	return 8
end

function FWC.Rep.NeededForStanding(status, targetReaction)
	status = status or FWC.Rep.GetStatus()
	local threshold = FWC.STANDING_THRESHOLDS[targetReaction]
	if not threshold then return 0 end
	return math.max(0, threshold - (status.standing or 0))
end

function FWC.Rep.RepToReceipts(status)
	return FWC.Rep.NeededForStanding(status, FWC.RECEIPT_MIN_STANDING)
end

--------------------------------------------------------------------------------
-- Writ Runtime Helpers (Locations, Professions, Daily Turn-ins, Quest Log)
--------------------------------------------------------------------------------
FWC.Writs = {}

local mapNameCache = {}
function FWC.MapName(mapID, fallback)
	if type(mapID) ~= "number" then return fallback or "?" end
	if mapNameCache[mapID] then return mapNameCache[mapID] end
	if C_Map and C_Map.GetMapInfo then
		local ok, info = pcall(C_Map.GetMapInfo, mapID)
		if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			mapNameCache[mapID] = info.name
			return info.name
		end
	end
	return fallback or ("Zone #" .. tostring(mapID))
end

function FWC.Writs.ProfessionName(key)
	local skill = FWC.PROFESSION_SKILL_LINES[key]
	if skill and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
		local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, skill)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	return key and (key:sub(1, 1):upper() .. key:sub(2)) or ""
end

function FWC.Writs.ProfessionsText(writ)
	if not writ or type(writ.professions) ~= "table" or #writ.professions == 0 then return nil end
	local out = {}
	for i, k in ipairs(writ.professions) do out[i] = FWC.Writs.ProfessionName(k) end
	return table.concat(out, " / ")
end

function FWC.Writs.Rep(writ)
	if not writ then return nil end
	return writ.rep or FWC.TIER_REP[writ.tier]
end

-- Customer key for the 1-writ-per-customer-per-day rule.
function FWC.Writs.CustomerKey(writ)
	if not writ then return nil end
	if writ.customerKey then return writ.customerKey end
	if writ.npc then return "npc:" .. tostring(writ.npc) end
	if writ.npcName then return "name:" .. writ.npcName end
	return "writ:" .. tostring(writ.id)
end

-- Returns { map, x, y, npcName, zoneName, exact, learned } or nil.
function FWC.Writs.Location(writ)
	if not writ then return nil end
	local learned = FWC.db and FWC.db.learnedLocations and writ.quest and FWC.db.learnedLocations[writ.quest]
	local npcs = FWC.Data and FWC.Data.NPCs or {}
	local zones = FWC.Data and FWC.Data.Zones or {}
	local npc = writ.npc and npcs[writ.npc] or nil

	if type(learned) == "table" and type(learned.map) == "number" and type(learned.x) == "number" then
		return {
			map = learned.map,
			x = learned.x,
			y = learned.y,
			npcName = learned.npcName or writ.npcName or (npc and npc.name),
			zoneName = FWC.MapName(learned.map, zones[learned.map]),
			exact = true,
			learned = true,
		}
	end
	if writ.who and type(writ.who.map) == "number" then
		return {
			map = writ.who.map,
			x = writ.who.x,
			y = writ.who.y,
			npcName = writ.who.npc or writ.npcName,
			zoneName = FWC.MapName(writ.who.map, zones[writ.who.map]),
			exact = true,
		}
	end
	if type(npc) == "table" and type(npc.map) == "number" then
		return {
			map = npc.map,
			x = npc.x,
			y = npc.y,
			npcName = npc.name,
			zoneName = FWC.MapName(npc.map, npc.zone or zones[npc.map]),
			exact = (type(npc.x) == "number" and type(npc.y) == "number"),
		}
	end
	if type(writ.zone) == "number" then
		return {
			map = writ.zone,
			x = 50,
			y = 50,
			npcName = writ.npcName,
			zoneName = FWC.MapName(writ.zone, zones[writ.zone]),
			exact = false,
		}
	end
	return nil
end

function FWC.Writs.LocationText(loc)
	if not loc then return "Location unknown" end
	if loc.exact and loc.x and loc.y then
		return format("%s (%.1f, %.1f)", loc.zoneName or FWC.MapName(loc.map), loc.x, loc.y)
	end
	return loc.zoneName or FWC.MapName(loc.map)
end

function FWC.Writs.TurnInText(writ)
	local loc = FWC.Writs.Location(writ)
	if loc then
		local where = FWC.Writs.LocationText(loc)
		if loc.npcName then return format("%s, %s", loc.npcName, where), loc.exact end
		return where, loc.exact
	end
	if writ and writ.npcName then return writ.npcName .. " (location unknown)", false end
	return "Turn-in location unknown", false
end

function FWC.Writs.SecondsUntilReset()
	if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
		local ok, sec = pcall(C_DateAndTime.GetSecondsUntilDailyReset)
		if ok and type(sec) == "number" and sec >= 0 then return sec end
	end
	return nil
end

local function CharTurnIns(create)
	if not FWC.db then return nil end
	local guid = FWC.SafeCall(UnitGUID, "player")
	if not guid then return nil end
	local rec = FWC.db.turnedIn[guid]
	if type(rec) ~= "table" then
		if not create then return nil end
		rec = {}
		FWC.db.turnedIn[guid] = rec
	end
	return rec
end

function FWC.Writs.PruneTurnIns()
	if not FWC.db or type(FWC.db.turnedIn) ~= "table" then return end
	local now = time()
	for guid, rec in pairs(FWC.db.turnedIn) do
		if type(rec) == "table" then
			for qid, resetAt in pairs(rec) do
				if type(resetAt) ~= "number" or resetAt <= now then rec[qid] = nil end
			end
			if next(rec) == nil then FWC.db.turnedIn[guid] = nil end
		else
			FWC.db.turnedIn[guid] = nil
		end
	end
end

function FWC.Writs.RecordTurnIn(questID)
	local rec = CharTurnIns(true)
	local sec = FWC.Writs.SecondsUntilReset()
	if not rec or not sec or type(questID) ~= "number" then return end
	rec[questID] = time() + sec
end

function FWC.Writs.IsTurnedInToday(writ)
	local qid = type(writ) == "table" and writ.quest or writ
	if type(qid) ~= "number" then return false end
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, qid)
		if ok and done == true then return true end
	end
	local rec = CharTurnIns(false)
	local resetAt = rec and rec[qid]
	return type(resetAt) == "number" and resetAt > time()
end

function FWC.Writs.IsAccepted(writ)
	local qid = type(writ) == "table" and writ.quest or writ
	if type(qid) ~= "number" then return false end
	if C_QuestLog and C_QuestLog.IsOnQuest then
		local ok, on = pcall(C_QuestLog.IsOnQuest, qid)
		if ok and on == true then return true end
	end
	return false
end

function FWC.Writs.UsedCustomersToday()
	local used = {}
	for _, w in ipairs(FWC.WritsList()) do
		if FWC.Writs.IsTurnedInToday(w) then
			local key = FWC.Writs.CustomerKey(w)
			if key then used[key] = FWC.ItemName(w.id) end
		end
	end
	return used
end

-- Learn writ turn-in locations automatically from the quest log or turn-in.
local function LearnFromQuestLog()
	if not (FWC.db and C_QuestLog and C_QuestLog.IsOnQuest) then return end
	local changed = false
	for _, w in ipairs(FWC.WritsList()) do
		if w.quest and not FWC.db.learnedLocations[w.quest] then
			local ok, on = pcall(C_QuestLog.IsOnQuest, w.quest)
			if ok and on then
				local map, x, y
				if FWC.RoutePlanner and FWC.RoutePlanner.LocateQuestTurnIn then
					map, x, y = FWC.RoutePlanner.LocateQuestTurnIn(w.quest)
				elseif C_QuestLog.GetNextWaypoint then
					local wok, wm, wx, wy = pcall(C_QuestLog.GetNextWaypoint, w.quest)
					if wok and type(wm) == "number" and type(wx) == "number" and type(wy) == "number" then
						map, x, y = wm, wx * 100, wy * 100
					end
				end
				if map and x and y then
					FWC.db.learnedLocations[w.quest] = {
						map = map,
						x = floor(x * 10 + 0.5) / 10,
						y = floor(y * 10 + 0.5) / 10,
						at = time(),
					}
					changed = true
				end
			end
		end
	end
	if changed then FWC.RefreshUI() end
end

local lastNpcSpot
FWC.On("QUEST_COMPLETE", function()
	local name = FWC.SafeCall(UnitName, "npc") or FWC.SafeCall(UnitName, "target")
	local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	if name and map and pos then
		local x, y = pos:GetXY()
		lastNpcSpot = { npcName = name, map = map, x = floor(x * 1000 + 0.5) / 10, y = floor(y * 1000 + 0.5) / 10, at = GetTime() }
	end
end)

FWC.On("QUEST_TURNED_IN", function(questID)
	local w = FWC.GetWritByQuest(questID)
	if not w then return end
	FWC.Writs.RecordTurnIn(questID)
	if FWC.db and lastNpcSpot and (GetTime() - lastNpcSpot.at < 120) then
		FWC.db.learnedLocations[questID] = {
			map = lastNpcSpot.map,
			x = lastNpcSpot.x,
			y = lastNpcSpot.y,
			npcName = lastNpcSpot.npcName,
			at = time(),
		}
	end
	FWC.RefreshUI()
end)

FWC.On("QUEST_ACCEPTED", function(questID)
	if FWC.GetWritByQuest(questID) then
		FWC.After(1, LearnFromQuestLog)
		FWC.RefreshUI()
	end
end)
FWC.On("QUEST_REMOVED", function(questID)
	if FWC.GetWritByQuest(questID) then FWC.RefreshUI() end
end)

--------------------------------------------------------------------------------
-- Auction House Purchase & Mailbox Reminder Tracking
--------------------------------------------------------------------------------
local AUCTION_WON_PAT = (ERR_AUCTION_WON_S and ERR_AUCTION_WON_S:gsub("%%s", ".+")) or "You won an auction"
local mailboxWasOpened = false

local function MarkPendingMail()
	if not FWC.charDB then return end
	FWC.charDB.pendingMail = true
	FWC.RefreshUI()
end

function FWC.HasPendingAuctionMail(route)
	if FWC.charDB and FWC.charDB.pendingMail then return true end
	-- Also catch the case where a writ in the route is missing its item and player has unread mail
	if HasNewMail and HasNewMail() and type(route) == "table" then
		for _, stop in ipairs(route) do
			if stop.writ and (stop.missingItems or 0) > 0 then
				return true
			end
		end
	end
	return false
end

FWC.On("AUCTION_HOUSE_PURCHASE_COMPLETED", MarkPendingMail)
FWC.On("CHAT_MSG_SYSTEM", function(msg)
	if type(msg) == "string" and (msg:find(AUCTION_WON_PAT) or msg:find("You won an auction", 1, true)) then
		MarkPendingMail()
	end
end)
FWC.On("MAIL_SHOW", function()
	mailboxWasOpened = true
	if GetInboxNumItems and (GetInboxNumItems() or 0) == 0 then
		if FWC.charDB then FWC.charDB.pendingMail = false end
		FWC.RefreshUI()
	end
end)
FWC.On("MAIL_INBOX_UPDATE", function()
	if mailboxWasOpened and GetInboxNumItems and (GetInboxNumItems() or 0) == 0 then
		if FWC.charDB then FWC.charDB.pendingMail = false end
		FWC.RefreshUI()
	end
end)
FWC.On("MAIL_CLOSED", function()
	if mailboxWasOpened then
		mailboxWasOpened = false
		if FWC.charDB then FWC.charDB.pendingMail = false end
		FWC.RefreshUI()
	end
end)

--------------------------------------------------------------------------------
-- Formatting Helpers
--------------------------------------------------------------------------------
function FWC.FormatMoney(copper)
	copper = tonumber(copper)
	if not copper then return "?" end
	local neg = copper < 0
	copper = floor(math.abs(copper) + 0.5)
	local text
	if GetMoneyString then
		local ok, s = pcall(GetMoneyString, copper, true)
		if ok and type(s) == "string" then text = s end
	end
	if not text then
		local g = floor(copper / 10000)
		local s = floor(copper / 100) % 100
		local c = copper % 100
		local parts = {}
		if g > 0 then parts[#parts + 1] = g .. "g" end
		if s > 0 or g > 0 then parts[#parts + 1] = s .. "s" end
		parts[#parts + 1] = c .. "c"
		text = table.concat(parts, " ")
	end
	return (neg and "-" or "") .. text
end

function FWC.FormatNumber(n)
	n = floor((tonumber(n) or 0) + 0.5)
	local s = tostring(math.abs(n))
	while true do
		local replaced
		s, replaced = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then break end
	end
	return (n < 0 and "-" or "") .. s
end

function FWC.FormatAge(seconds)
	seconds = floor((tonumber(seconds) or 0) + 0.5)
	if seconds < 0 then seconds = 0 end
	if seconds < 60 then return format("%ds ago", seconds) end
	if seconds < 3600 then return format("%dm ago", floor(seconds / 60)) end
	if seconds < 86400 then return format("%dh ago", floor(seconds / 3600)) end
	return format("%dd ago", floor(seconds / 86400))
end

function FWC.FormatTime(seconds)
	seconds = floor((tonumber(seconds) or 0) + 0.5)
	if seconds < 0 then seconds = 0 end
	if seconds >= 3600 then
		return format("%dh %dm", floor(seconds / 3600), floor((seconds % 3600) / 60))
	elseif seconds >= 60 then
		return format("%dm %02ds", floor(seconds / 60), seconds % 60)
	end
	return format("%ds", seconds)
end

function FWC.FormatSpan(seconds)
	seconds = floor((tonumber(seconds) or 0) + 0.5)
	if seconds < 0 then seconds = 0 end
	if seconds >= 86400 then return format("%dd %dh", floor(seconds / 86400), floor((seconds % 86400) / 3600)) end
	if seconds >= 3600 then return format("%dh %dm", floor(seconds / 3600), floor((seconds % 3600) / 60)) end
	if seconds >= 60 then return format("%dm", floor(seconds / 60)) end
	return format("%ds", seconds)
end

function FWC.SeenText(days)
	days = floor((tonumber(days) or 0) + 0.5)
	if days <= 0 then return "today" end
	if days == 1 then return "yesterday" end
	return format("%d days ago", days)
end

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
local function PrintHelp()
	FWC.Print("Commands:")
	FWC.Print("  |cffffd100/fwc|r - open or close the Planner & Calculator")
	FWC.Print("  |cffffd100/fwc route|r - build a turn-in route for writs currently in your bags")
	FWC.Print("  |cffffd100/fwc guide|r - show or hide the Route Guide window")
	FWC.Print("  |cffffd100/fwc panel|r - toggle the Auction House side panel")
	FWC.Print("  |cffffd100/fwc scan [crates|writs|all]|r - scan Auction House prices")
	FWC.Print("  |cffffd100/fwc quests|r - toggle including completed quest turn-ins in routes")
	FWC.Print("  |cffffd100/fwc auto|r - toggle auto-accept & auto-turn-in for writs")
	FWC.Print("  |cffffd100/fwc minimap|r - show or hide the minimap button")
	FWC.Print("  |cffffd100/fwc reset|r - clear scanned prices for this realm")
end

SLASH_FOREVERWRITS1 = "/fwc"
SLASH_FOREVERWRITS2 = "/foreverwrits"
SlashCmdList["FOREVERWRITS"] = function(msg)
	msg = tostring(msg or "")
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	rest = (rest or ""):lower()
	if not FWC.loaded then return end

	if cmd == "" or cmd == "plan" or cmd == "calc" then
		if FWC.PlannerWindow then FWC.PlannerWindow.Toggle() end
	elseif cmd == "route" or cmd == "bags" then
		if FWC.RoutePlanner and FWC.RouteGuide then
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
		end
	elseif cmd == "quests" then
		FWC.db.includeCompletedQuests = not FWC.db.includeCompletedQuests
		FWC.Print("Include completed quest turn-ins in routes: %s.", FWC.db.includeCompletedQuests and "|cff40ff40ON|r" or "|cffff4040OFF|r")
		FWC.RefreshUI()
	elseif cmd == "guide" then
		if FWC.RouteGuide then FWC.RouteGuide.Toggle() end
	elseif cmd == "panel" then
		if FWC.AuctionHouseOpen() and FWC.AuctionPanel then
			FWC.AuctionPanel.Toggle()
		else
			FWC.Print("Open the Auction House first.")
		end
	elseif cmd == "scan" then
		if FWC.AuctionHouseOpen() and FWC.Scanner then
			local scope = (rest == "crates" or rest == "writs" or rest == "all") and rest or (FWC.db.panelTab or "writs")
			FWC.Scanner.StartQuick(scope)
		else
			FWC.Print("Open the Auction House first.")
		end
	elseif cmd == "stop" then
		if FWC.Scanner then FWC.Scanner.Cancel("Scan stopped.") end
	elseif cmd == "auto" then
		FWC.db.autoQuest = not FWC.db.autoQuest
		FWC.Print("Auto-accept and auto-turn-in for writs: %s.", FWC.db.autoQuest and "|cff40ff40ON|r" or "|cffff4040OFF|r")
	elseif cmd == "minimap" then
		if FWC.MinimapButton then FWC.MinimapButton.Toggle() end
	elseif cmd == "reset" then
		FWC.ResetPriceBook()
	else
		PrintHelp()
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
FWC.On("ADDON_LOADED", function(name)
	if name == ADDON_NAME then
		FWC.InitDB()
	end
end)

FWC.On("PLAYER_ENTERING_WORLD", function()
	FWC.Writs.PruneTurnIns()
	local sec = FWC.Writs.SecondsUntilReset()
	if sec and sec > 0 then
		FWC.After(sec + 5, function()
			FWC.Writs.PruneTurnIns()
			FWC.RefreshUI()
		end)
	end
	FWC.After(2, LearnFromQuestLog)
end)
