-- Forever Writs and Crates: Route planner & optimizer.
-- Supports:
--   1. Auto-populated reputation goal (next standing from current rep)
--   2. Fastest Route (optimizes travel time using all faction flights/boats/roads)
--   3. Cheapest Plan (exact DP knapsack in 25-rep steps for minimum gold)
--   4. My Bag Writs (shortest turn-in order for writs currently in bags/quest log)
--   5. Per-writ travel time estimation for sorting the AH Writs tab by Fastest Travel
local _, FWC = ...

local Planner = {}
FWC.RoutePlanner = Planner

local HANDIN_SECS = 20
local EXACT_TSP_LIMIT = 9

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function WritOwned(writ)
	return FWC.BagCount(writ.id) > 0 or FWC.Writs.IsAccepted(writ)
end

local function MissingItemCount(writ)
	local missing = 0
	for _, need in ipairs(writ.needs or {}) do
		missing = missing + math.max(0, need.count - FWC.BagCount(need.item))
	end
	return missing
end

-- Cost to complete this writ now (0 for writ if owned; 0 for items already in bags).
local function NetWritCost(book, writ)
	local haveWrit = WritOwned(writ)
	local cost = 0
	if not haveWrit then
		local q = FWC.Valuation.Quote(book.items[writ.id], 1)
		if not q.cost then return nil, "writ not listed" end
		cost = cost + q.cost
	end
	for _, need in ipairs(writ.needs or {}) do
		local needQty = math.max(0, need.count - FWC.BagCount(need.item))
		if needQty > 0 then
			local q = FWC.Valuation.Quote(book.items[need.item], needQty)
			if not q.cost then return nil, "item not listed" end
			cost = cost + q.cost
		end
	end
	return cost, haveWrit
end

--------------------------------------------------------------------------------
-- Completed Quests in Quest Log (non-writ turn-ins)
--------------------------------------------------------------------------------
local cachedZoneMaps
local function GetAzerothZoneMaps()
	if cachedZoneMaps then return cachedZoneMaps end
	cachedZoneMaps = {}
	local zoneType = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
	if C_Map and C_Map.GetMapChildrenInfo then
		local ok, kids = pcall(C_Map.GetMapChildrenInfo, 947, zoneType, true)
		if ok and type(kids) == "table" then
			for _, k in ipairs(kids) do
				if type(k) == "table" and type(k.mapID) == "number" then
					cachedZoneMaps[#cachedZoneMaps + 1] = k.mapID
				end
			end
		end
	end
	return cachedZoneMaps
end

local function LocateQuestTurnIn(questID)
	-- 1. Primary: Blizzard's waypoint API (returns exact turn-in zone & coords for completed quests)
	if C_QuestLog and C_QuestLog.GetNextWaypoint then
		local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, questID)
		if ok and type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
			local z = FWC.Travel.ZoneOf(mapID)
			return z or mapID, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
		end
	end
	-- 2. Fallback: scan Azeroth zone maps for the quest's turn-in pin
	if C_QuestLog and C_QuestLog.GetQuestsOnMap then
		local bestMap, bestX, bestY, bestEdge
		for _, mapID in ipairs(GetAzerothZoneMaps()) do
			local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
			if ok and type(list) == "table" then
				for _, q in ipairs(list) do
					if type(q) == "table" and q.questID == questID and not q.isQuestStart
						and type(q.x) == "number" and type(q.y) == "number" then
						local edge = math.min(q.x, 1 - q.x, q.y, 1 - q.y)
						if not bestEdge or edge > bestEdge then
							bestEdge = edge
							bestMap = (type(q.mapID) == "number" and q.mapID or mapID)
							bestX = math.floor(q.x * 1000 + 0.5) / 10
							bestY = math.floor(q.y * 1000 + 0.5) / 10
						end
					end
				end
			end
		end
		if bestMap and bestX and bestY then
			return FWC.Travel.ZoneOf(bestMap) or bestMap, bestX, bestY
		end
	end
	return nil
end
Planner.LocateQuestTurnIn = LocateQuestTurnIn

function Planner.IncludeQuestsEnabled()
	return FWC.db == nil or FWC.db.includeCompletedQuests ~= false
end

function Planner.IsQuestSelected(qStop)
	if not qStop or not qStop.questID then return false end
	local sel = FWC.charDB and FWC.charDB.questSelection
	if type(sel) == "table" and sel[qStop.questID] ~= nil then
		return sel[qStop.questID] == true
	end
	-- By default, exclude Dungeon and Raid quests so you aren't routed into instances!
	return not (qStop.isDungeon or qStop.isRaid)
end

function Planner.SetQuestSelected(questID, enabled)
	if not (FWC.charDB and type(questID) == "number") then return end
	FWC.charDB.questSelection = FWC.charDB.questSelection or {}
	FWC.charDB.questSelection[questID] = enabled and true or false
end

function Planner.AllCompletedQuestStops()
	local stops = {}
	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return stops end
	local isComplete = C_QuestLog.IsComplete or IsQuestComplete
	if not isComplete then return stops end

	local num = C_QuestLog.GetNumQuestLogEntries() or 0
	local seen = {}
	for i = 1, num do
		local info = C_QuestLog.GetInfo(i)
		if type(info) == "table" and not info.isHeader and type(info.questID) == "number" and not seen[info.questID] then
			seen[info.questID] = true
			local qid = info.questID
			-- Skip Craftsman's Writs (handled by writ planner)
			if not FWC.GetWritByQuest(qid) then
				local ok, complete = pcall(isComplete, qid)
				if ok and complete == true then
					local mapID, x, y = LocateQuestTurnIn(qid)
					local pos = (mapID and x and y) and FWC.Travel.Point(mapID, x, y) or nil
					local isDungeon, isRaid = false, false
					if C_QuestLog and C_QuestLog.GetQuestTagInfo then
						local tok, tag = pcall(C_QuestLog.GetQuestTagInfo, qid)
						if tok and type(tag) == "table" then
							local dungeonID = Enum and Enum.QuestTag and Enum.QuestTag.Dungeon or 81
							local raidID = Enum and Enum.QuestTag and Enum.QuestTag.Raid or 62
							local raid10 = Enum and Enum.QuestTag and Enum.QuestTag.Raid10 or 88
							local raid25 = Enum and Enum.QuestTag and Enum.QuestTag.Raid25 or 89
							if tag.tagID == dungeonID or tag.tagName == "Dungeon" then
								isDungeon = true
							elseif tag.tagID == raidID or tag.tagID == raid10 or tag.tagID == raid25 or tag.tagName == "Raid" then
								isRaid = true
							end
						end
					end
					-- Also detect instance-style quest headers (e.g. "Excavation Site: Wetlands")
					if not isDungeon and not isRaid and info.suggestedGroup and info.suggestedGroup >= 3 then
						isDungeon = true
					end
					local qStop = {
						kind = "quest",
						questID = qid,
						isDungeon = isDungeon,
						isRaid = isRaid,
						title = info.title or ("Quest #" .. tostring(qid)),
						loc = (mapID and x and y) and {
							map = mapID,
							x = x,
							y = y,
							zoneName = FWC.MapName(mapID),
							exact = true,
						} or nil,
						pos = pos,
						rep = 0,
						cost = 0,
						owned = true,
					}
					qStop.selected = Planner.IsQuestSelected(qStop)
					stops[#stops + 1] = qStop
				end
			end
		end
	end
	return stops
end

function Planner.CompletedQuestStops()
	local out = {}
	for _, qStop in ipairs(Planner.AllCompletedQuestStops()) do
		if qStop.pos and Planner.IsQuestSelected(qStop) then
			out[#out + 1] = qStop
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- TSP Order Optimization (Cheapest Insertion + 2-Opt + Exact DFS for <= 9 stops)
--------------------------------------------------------------------------------
local function OptimizeOrder(startPt, stops)
	local n = #stops
	if n <= 1 then return stops end

	local pts = { startPt }
	for i, s in ipairs(stops) do pts[i + 1] = s.pos end

	local freeTeleports = {}
	for _, tp in ipairs(FWC.Travel.GetTeleports() or {}) do
		if (tp.cd or 0) == 0 and (tp.ready or 0) <= 0 and tp.dest then
			freeTeleports[#freeTeleports + 1] = tp
		end
	end

	local T = {}
	for i = 1, n + 1 do
		T[i] = {}
		for j = 1, n + 1 do
			if i == j then
				T[i][j] = 0
			else
				local t = FWC.Travel.Time(pts[i], pts[j])
				for _, tp in ipairs(freeTeleports) do
					if not pts[i] or pts[i].map ~= tp.dest.map then
						local via = (tp.cast or 15) + FWC.Travel.Time(tp.dest, pts[j])
						if via < t then t = via end
					end
				end
				T[i][j] = t
			end
		end
	end

	-- 1. Cheapest insertion
	local order = {}
	for i = 1, n do
		local bestDelta, bestPos = math.huge, 1
		for k = 1, #order + 1 do
			local a = (k == 1) and 1 or order[k - 1]
			local b = order[k]
			local delta = T[a][i + 1] + (b and (T[i + 1][b] - T[a][b]) or 0)
			if delta < bestDelta then bestDelta, bestPos = delta, k end
		end
		table.insert(order, bestPos, i + 1)
	end

	local function PathLen(o)
		local total, prev = 0, 1
		for _, idx in ipairs(o) do
			total = total + T[prev][idx]
			prev = idx
		end
		return total
	end

	-- 2. 2-opt local search
	local improved, passes = true, 0
	while improved and passes < 40 do
		improved, passes = false, passes + 1
		local curLen = PathLen(order)
		for i = 1, n - 1 do
			for j = i + 1, n do
				local a, b = i, j
				while a < b do order[a], order[b] = order[b], order[a]; a = a + 1; b = b - 1 end
				local newLen = PathLen(order)
				if newLen < curLen - 0.5 then
					curLen = newLen
					improved = true
				else
					a, b = i, j
					while a < b do order[a], order[b] = order[b], order[a]; a = a + 1; b = b - 1 end
				end
			end
		end
	end

	-- 3. Exact branch-and-bound DFS for small routes
	if n <= EXACT_TSP_LIMIT then
		local bestLen = PathLen(order)
		local bestOrder = { unpack(order) }
		local used, cur = {}, {}
		local function DFS(depth, last, acc)
			if acc >= bestLen then return end
			if depth > n then
				bestLen = acc
				bestOrder = { unpack(cur) }
				return
			end
			for j = 2, n + 1 do
				if not used[j] then
					used[j] = true
					cur[depth] = j
					DFS(depth + 1, j, acc + T[last][j])
					used[j] = nil
				end
			end
		end
		DFS(1, 1, 0)
		order = bestOrder
	end

	local out = {}
	for i, idx in ipairs(order) do out[i] = stops[idx - 1] end
	return out
end
Planner.OptimizeStops = OptimizeOrder

local function BestLegTeleport(prev, targetPos, teleports, usedCooldownTp)
	local legSecs = FWC.Travel.Time(prev, targetPos)
	local bestTp, bestSave = nil, 60 -- must save at least 60 seconds
	for _, tp in ipairs(teleports or {}) do
		local available = (tp.ready or 0) <= 0 and tp.dest and (tp.cd == 0 or not usedCooldownTp[tp.key])
		-- Don't teleport to the zone we're already standing in
		if available and (not prev or prev.map ~= tp.dest.map) then
			local viaSecs = (tp.cast or 15) + FWC.Travel.Time(tp.dest, targetPos)
			local save = legSecs - viaSecs
			if save > bestSave then
				bestTp, bestSave = tp, save
			end
		end
	end
	return bestTp, bestSave
end

local function TotalTravelSecs(startPt, route)
	local teleports = FWC.Travel.GetTeleports()
	local usedCd = {}
	local total, prev = 0, startPt
	for _, stop in ipairs(route) do
		local leg = FWC.Travel.Time(prev, stop.pos)
		local tp, save = BestLegTeleport(prev, stop.pos, teleports, usedCd)
		if tp then
			leg = leg - save
			if (tp.cd or 0) > 0 then usedCd[tp.key] = true end
		end
		total = total + leg + HANDIN_SECS
		prev = stop.pos
	end
	return total
end

--------------------------------------------------------------------------------
-- Build Concrete Guide Steps from an Ordered Route
--------------------------------------------------------------------------------
-- Nearest AH-adjacent mailbox coordinates in major cities/hubs
local CITY_MAILBOXES = {
	[1453] = { x = 61.5, y = 71.5, name = "Stormwind Trade District Mailbox" },
	[1455] = { x = 25.5, y = 74.5, name = "Ironforge AH Mailbox" },
	[1457] = { x = 56.8, y = 55.2, name = "Darnassus AH Mailbox" },
	[1454] = { x = 51.0, y = 69.5, name = "Orgrimmar AH Mailbox" },
	[1456] = { x = 40.5, y = 55.0, name = "Thunder Bluff Mailbox" },
	[1458] = { x = 68.0, y = 38.0, name = "Undercity Mailbox" },
	[1434] = { x = 27.1, y = 76.9, name = "Booty Bay Mailbox" },
	[1446] = { x = 52.0, y = 27.9, name = "Gadgetzan Mailbox" },
}

function Planner.BuildGuideSteps(startPt, route)
	local steps = {}
	local prev = startPt or FWC.Travel.PlayerPoint()
	local teleports = FWC.Travel.GetTeleports()
	local usedCooldownTp = {}

	-- Prepend a mailbox reminder step if the player has uncollected AH purchases!
	if #route > 0 and FWC.HasPendingAuctionMail and FWC.HasPendingAuctionMail(route) then
		if FWC.charDB then FWC.charDB.pendingMail = true end
		local mb = prev and prev.map and CITY_MAILBOXES[prev.map]
		steps[#steps + 1] = {
			kind = "mail",
			text = mb and ("Check your mailbox before leaving town (" .. mb.name .. ")")
				or "Check your mailbox before leaving town (AH purchases waiting!)",
			map = mb and prev.map or nil,
			x = mb and mb.x or nil,
			y = mb and mb.y or nil,
			label = mb and mb.name or "Mailbox",
		}
	end

	for idx, stop in ipairs(route) do
		-- Check if Hearthstone, Astral Recall, Druid Teleport: Moonglade, or a Mage Teleport saves >= 60s
		local usedTp = BestLegTeleport(prev, stop.pos, teleports, usedCooldownTp)
		if usedTp then
			if (usedTp.cd or 0) > 0 then usedCooldownTp[usedTp.key] = true end
			steps[#steps + 1] = {
				kind = usedTp.kind or "hearth",
				text = "Cast " .. usedTp.name,
				map = usedTp.dest.map,
				x = usedTp.dest.x,
				y = usedTp.dest.y,
				destMap = usedTp.dest.map,
				label = usedTp.name,
			}
			prev = usedTp.dest
		end

		local travelSteps = FWC.Travel.Steps(prev, stop.pos)
		for _, ts in ipairs(travelSteps) do
			if ts.kind == "fly" then
				steps[#steps + 1] = {
					kind = "fly",
					text = string.format("Fly: %s -> %s (~%s)", ts.fromName, ts.destName, FWC.FormatTime(ts.secs)),
					map = ts.map,
					x = ts.x,
					y = ts.y,
					destMap = ts.destMap,
					label = ts.fromName,
				}
			elseif ts.kind == "boat" or ts.kind == "zeppelin" then
				steps[#steps + 1] = {
					kind = ts.kind,
					text = ts.label,
					map = ts.map,
					x = ts.x,
					y = ts.y,
					destMap = ts.destMap,
					label = ts.label,
				}
			elseif ts.kind == "road" then
				steps[#steps + 1] = {
					kind = "road",
					text = ts.label,
					map = ts.map,
					x = ts.x,
					y = ts.y,
					destMap = ts.destMap,
					label = ts.label,
				}
			end
		end

		local loc = stop.loc
		local zoneLabel = (loc and loc.zoneName) or FWC.MapName(stop.pos.map)

		-- Insert approach waypoints (mountain paths, cave/dungeon entrances, tunnels, teleporters)
		local approaches = FWC.Data and FWC.Data.Approaches or {}
		local titleText = (stop.title or (stop.writ and FWC.ItemName(stop.writ.id)) or ""):lower()
		local atTarget = (prev and prev.map == stop.pos.map and FWC.Travel.Distance(prev, stop.pos) < 40)
		if not atTarget then
			for _, app in ipairs(approaches) do
				if app.map == stop.pos.map then
					local inBox = (stop.pos.x >= (app.xMin or -1) and stop.pos.x <= (app.xMax or 101)
						and stop.pos.y >= (app.yMin or -1) and stop.pos.y <= (app.yMax or 101))
					local titleHit = app.titleMatch and titleText:find(app.titleMatch:lower(), 1, true) ~= nil
					if inBox or titleHit then
						for _, wp in ipairs(app.waypoints or {}) do
							steps[#steps + 1] = {
								kind = "approach",
								text = string.format("%s (%s %.1f, %.1f)", wp.text, zoneLabel, wp.x, wp.y),
								map = app.map,
								x = wp.x,
								y = wp.y,
								label = wp.text,
							}
						end
						break
					end
				end
			end
		end

		if stop.kind == "quest" then
			local tag = stop.isDungeon and "[Dungeon] " or ""
			steps[#steps + 1] = {
				kind = "questTurnin",
				text = string.format("Turn in %squest: %s (%s %.1f, %.1f)",
					tag, stop.title or "Quest", zoneLabel, stop.pos.x, stop.pos.y),
				map = stop.pos.map,
				x = stop.pos.x,
				y = stop.pos.y,
				questID = stop.questID,
				label = stop.title or "Quest Turn-in",
			}
		else
			local npcLabel = (loc and loc.npcName) or "Customer"
			steps[#steps + 1] = {
				kind = "turnin",
				text = string.format("Hand in %s to %s (%s %.1f, %.1f)",
					FWC.ItemName(stop.writ.id), npcLabel, zoneLabel, stop.pos.x, stop.pos.y),
				map = stop.pos.map,
				x = stop.pos.x,
				y = stop.pos.y,
				questID = stop.writ.quest,
				writID = stop.writ.id,
				rep = stop.rep,
				label = npcLabel,
			}
		end
		prev = stop.pos
	end
	return steps
end

--------------------------------------------------------------------------------
-- 1. Plan My Bag Writs (writs currently in bags / quest log)
--------------------------------------------------------------------------------
function Planner.PlanOwnedWrits()
	local book = FWC.Prices()
	local startPt = FWC.Travel.PlayerPoint()
	local owned, skipped = {}, {}

	for _, w in ipairs(FWC.WritsList()) do
		if WritOwned(w) then
			if FWC.Writs.IsTurnedInToday(w) then
				skipped[#skipped + 1] = { writ = w, reason = "already turned in today (wait for daily reset)" }
			else
				owned[#owned + 1] = w
			end
		end
	end
	table.sort(owned, function(a, b)
		local ra, rb = FWC.Writs.Rep(a) or 0, FWC.Writs.Rep(b) or 0
		if ra ~= rb then return ra > rb end
		return a.id < b.id
	end)

	local stops = {}
	for _, w in ipairs(owned) do
		local loc = FWC.Writs.Location(w)
		-- If location isn't in DB yet, try locating live from quest log!
		if not loc and w.quest and FWC.Writs.IsAccepted(w) then
			local lm, lx, ly = LocateQuestTurnIn(w.quest)
			if lm and lx and ly then
				if FWC.db and FWC.db.learnedLocations then
					FWC.db.learnedLocations[w.quest] = { map = lm, x = lx, y = ly, at = time() }
				end
				loc = FWC.Writs.Location(w)
			end
		end
		if not loc then
			skipped[#skipped + 1] = { writ = w, reason = "Location unknown (accept writ first)" }
		else
			local pos = FWC.Travel.Point(loc.map, loc.x or 50, loc.y or 50)
			if pos then
				local netCost = NetWritCost(book, w) or 0
				stops[#stops + 1] = {
					writ = w,
					loc = loc,
					pos = pos,
					rep = FWC.Writs.Rep(w) or 0,
					cost = netCost,
					owned = true,
					missingItems = MissingItemCount(w),
				}
			end
		end
	end

	local writCount = #stops
	local questCount = 0
	if Planner.IncludeQuestsEnabled() then
		for _, qStop in ipairs(Planner.CompletedQuestStops()) do
			stops[#stops + 1] = qStop
			questCount = questCount + 1
		end
	end

	local route = OptimizeOrder(startPt, stops)
	local totalRep, totalCost = 0, 0
	for _, s in ipairs(route) do
		totalRep = totalRep + (s.rep or 0)
		totalCost = totalCost + (s.cost or 0)
	end
	local secs = TotalTravelSecs(startPt, route)
	return {
		kind = "owned",
		route = route,
		steps = Planner.BuildGuideSteps(startPt, route),
		rep = totalRep,
		cost = totalCost,
		secs = secs,
		writCount = writCount,
		questCount = questCount,
		skipped = skipped,
		start = startPt,
	}
end

function Planner.ReportSkipped(plan)
	if not (plan and type(plan.skipped) == "table") then return end
	for _, sk in ipairs(plan.skipped) do
		FWC.Print("|cffffaa44Skipped|r %s: %s.", FWC.ItemName(sk.writ.id), sk.reason or "unavailable")
	end
end

--------------------------------------------------------------------------------
-- 2. Plan Fastest & Cheapest for Reputation Target (auto-populated by default!)
--    Allows multiple different writs at the same NPC (1 of each unique writ/day).
--------------------------------------------------------------------------------
local function BuildCheapestSet(cands, needRep)
	if needRep <= 0 then return {} end
	local U = math.ceil(needRep / 25)
	local INF = math.huge
	local dp = { [0] = 0 }
	for u = 1, U do dp[u] = INF end
	local picks = {}

	for ci, c in ipairs(cands) do
		local ndp, pk = {}, {}
		for u = 0, U do ndp[u] = dp[u] end
		local r = math.floor(c.rep / 25)
		for u = 0, U do
			if dp[u] < INF then
				local v = math.min(U, u + r)
				if dp[u] + c.cost < ndp[v] then
					ndp[v] = dp[u] + c.cost
					pk[v] = { c = c, from = u }
				end
			end
		end
		picks[ci] = pk
		dp = ndp
	end

	local u = U
	while u > 0 and dp[u] == INF do u = u - 1 end
	local out = {}
	for ci = #cands, 1, -1 do
		local p = picks[ci][u]
		if p then
			out[#out + 1] = p.c
			u = p.from
		end
	end
	return out
end

local function BuildFastestSet(startPt, ownedStops, cands, needRep)
	if needRep <= 0 then return {} end
	local route = {}
	for _, s in ipairs(ownedStops) do route[#route + 1] = s end

	local usedIDs, chosen, rep = {}, {}, 0
	for _, s in ipairs(ownedStops) do
		if s.writ then usedIDs[s.writ.id] = true end
	end

	while rep < needRep do
		local best, bestScore, bestAt = nil, math.huge, 1
		for _, c in ipairs(cands) do
			if not usedIDs[c.writ.id] then
				local bestDt, at = math.huge, 1
				for k = 1, #route + 1 do
					local prevPt = (k == 1) and startPt or route[k - 1].pos
					local nextPt = route[k] and route[k].pos
					local dt = FWC.Travel.Time(prevPt, c.pos)
						+ (nextPt and (FWC.Travel.Time(c.pos, nextPt) - FWC.Travel.Time(prevPt, nextPt)) or 0)
					if dt < bestDt then bestDt, at = dt, k end
				end
				-- Score: seconds added per useful rep point (+ tiny gold tiebreaker)
				local gain = math.min(c.rep, needRep - rep)
				local score = (bestDt + HANDIN_SECS) / gain + (c.cost * 1e-7)
				if score < bestScore then
					best, bestScore, bestAt = c, score, at
				end
			end
		end
		if not best then break end
		usedIDs[best.writ.id] = true
		table.insert(route, bestAt, best)
		chosen[#chosen + 1] = best
		rep = rep + best.rep
	end
	return chosen
end

function Planner.PlanForStanding(targetStanding)
	local status = FWC.Rep.GetStatus()
	local autoStanding = FWC.Rep.AutoTargetStanding(status)
	local target = targetStanding or autoStanding
	local needRep = FWC.Rep.NeededForStanding(status, target)

	local book = FWC.Prices()
	local startPt = FWC.Travel.PlayerPoint()

	-- Gather owned writs first (all unique writs not turned in today)
	local ownedStops, ownedRep, ownedCost = {}, 0, 0
	local ownedRaw = {}
	for _, w in ipairs(FWC.WritsList()) do
		if WritOwned(w) and not FWC.Writs.IsTurnedInToday(w) then
			ownedRaw[#ownedRaw + 1] = w
		end
	end
	table.sort(ownedRaw, function(a, b) return (FWC.Writs.Rep(a) or 0) > (FWC.Writs.Rep(b) or 0) end)

	for _, w in ipairs(ownedRaw) do
		local loc = FWC.Writs.Location(w)
		if loc then
			local pos = FWC.Travel.Point(loc.map, loc.x or 50, loc.y or 50)
			local netCost = NetWritCost(book, w)
			if pos and netCost then
				local stop = {
					writ = w, loc = loc, pos = pos,
					rep = FWC.Writs.Rep(w) or 0, cost = netCost,
					owned = true, missingItems = MissingItemCount(w),
				}
				ownedStops[#ownedStops + 1] = stop
				ownedRep = ownedRep + stop.rep
				ownedCost = ownedCost + stop.cost
			end
		end
	end

	-- Gather buyable candidates (not owned, not turned in today, known location, listed on AH)
	local cands = {}
	for _, w in ipairs(FWC.WritsList()) do
		if not WritOwned(w) and not FWC.Writs.IsTurnedInToday(w) then
			local loc = FWC.Writs.Location(w)
			if loc then
				local pos = FWC.Travel.Point(loc.map, loc.x or 50, loc.y or 50)
				local netCost = NetWritCost(book, w)
				if pos and netCost then
					cands[#cands + 1] = {
						writ = w, loc = loc, pos = pos,
						rep = FWC.Writs.Rep(w) or 0, cost = netCost,
						owned = false, missingItems = MissingItemCount(w),
					}
				end
			end
		end
	end

	local remainingRep = math.max(0, needRep - ownedRep)
	local questStops = Planner.IncludeQuestsEnabled() and Planner.CompletedQuestStops() or {}

	local function Finalize(kind, extraSet)
		local combined = {}
		for _, s in ipairs(ownedStops) do combined[#combined + 1] = s end
		for _, s in ipairs(extraSet) do combined[#combined + 1] = s end
		local writCount = #combined
		for _, qs in ipairs(questStops) do combined[#combined + 1] = qs end
		local ordered = OptimizeOrder(startPt, combined)
		local rep, cost = 0, 0
		for _, s in ipairs(ordered) do
			rep = rep + (s.rep or 0)
			cost = cost + (s.cost or 0)
		end
		local secs = TotalTravelSecs(startPt, ordered)
		return {
			kind = kind,
			route = ordered,
			steps = Planner.BuildGuideSteps(startPt, ordered),
			rep = rep,
			cost = cost,
			secs = secs,
			writCount = writCount,
			questCount = #questStops,
			complete = rep >= needRep,
			start = startPt,
		}
	end

	-- Pass ownedStops + questStops into BuildFastestSet so new writs cluster around your existing quest turn-ins too!
	local fastSeed = {}
	for _, s in ipairs(ownedStops) do fastSeed[#fastSeed + 1] = s end
	for _, qs in ipairs(questStops) do fastSeed[#fastSeed + 1] = qs end
	local fastest = Finalize("fastest", BuildFastestSet(startPt, fastSeed, cands, remainingRep))
	local cheapest = Finalize("cheapest", BuildCheapestSet(cands, remainingRep))

	-- Guarantee fastest is never slower than cheapest, and cheapest is never pricier than fastest
	if cheapest.secs < fastest.secs and cheapest.rep >= fastest.rep then
		fastest = Finalize("fastest", BuildCheapestSet(cands, remainingRep))
	end

	return {
		status = status,
		targetStanding = target,
		isAutoTarget = (targetStanding == nil),
		needRep = needRep,
		fastest = fastest,
		cheapest = cheapest,
		candidateCount = #cands,
	}
end

--------------------------------------------------------------------------------
-- 3. Per-Writ Travel Time Estimates (Fastest Travel & Near Bag Writs)
--------------------------------------------------------------------------------
function Planner.EstimateWritTravelSecs(writ, startPt)
	startPt = startPt or FWC.Travel.PlayerPoint()
	local loc = FWC.Writs.Location(writ)
	if not (startPt and loc) then return nil end
	local pos = FWC.Travel.Point(loc.map, loc.x or 50, loc.y or 50)
	if not pos then return nil end
	return FWC.Travel.Time(startPt, pos)
end

-- Returns turn-in anchor positions and customer keys for all writs currently in bags or quest log.
function Planner.GetOwnedWritAnchors()
	local anchors, ownedIDs, ownedCustomers = {}, {}, {}
	for _, w in ipairs(FWC.WritsList()) do
		if WritOwned(w) and not FWC.Writs.IsTurnedInToday(w) then
			ownedIDs[w.id] = true
			local cKey = FWC.Writs.CustomerKey(w)
			if cKey then ownedCustomers[cKey] = FWC.ItemName(w.id) end
			local loc = FWC.Writs.Location(w)
			if not loc and w.quest and FWC.Writs.IsAccepted(w) then
				local lm, lx, ly = LocateQuestTurnIn(w.quest)
				if lm and lx and ly then
					loc = { map = lm, x = lx, y = ly, zoneName = FWC.MapName(lm), exact = true }
				end
			end
			if loc then
				local pos = FWC.Travel.Point(loc.map, loc.x or 50, loc.y or 50)
				if pos then
					anchors[#anchors + 1] = { writ = w, loc = loc, pos = pos, cKey = cKey }
				end
			end
		end
	end
	return { anchors = anchors, ownedIDs = ownedIDs, ownedCustomers = ownedCustomers }
end

-- Minimum travel time from ANY owned bag/quest-log writ to `writ`.
function Planner.MinTravelFromAnchors(writ, anchorInfo)
	if not (anchorInfo and anchorInfo.anchors and #anchorInfo.anchors > 0) then return nil end
	local loc = FWC.Writs.Location(writ)
	if not loc then return nil end
	local pos = FWC.Travel.Point(loc.map, loc.x or 50, loc.y or 50)
	if not pos then return nil end

	local bestSecs, bestAnchor
	for _, a in ipairs(anchorInfo.anchors) do
		local t = FWC.Travel.Time(a.pos, pos)
		if not bestSecs or t < bestSecs then
			bestSecs, bestAnchor = t, a
		end
	end
	return bestSecs, bestAnchor
end
