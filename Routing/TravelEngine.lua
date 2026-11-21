-- Forever Writs and Crates: Travel graph and shortest-path engine.
-- Assumes ALL faction-accessible flight paths, boats, zeppelins, and zone roads
-- are available immediately by default (no flight master visits required).
local _, FWC = ...

local Travel = {}
FWC.Travel = Travel

local RIDE_SPEED = 11          -- yards/s (mounted/average travel speed)
local FLY_SPEED = 29           -- yards/s (flight path average)
local FLIGHT_OVERHEAD = 32     -- seconds to mount/take off/land
local CROSSING_COST = 5        -- seconds for a zone crossing
local HOSTILE_PENALTY = 1200   -- avoid routing through enemy capitals

local graphNodes = nil
local graphByZone = nil
local builtSide = nil
local distCache = {}

local function GetHBD()
	return LibStub and LibStub("HereBeDragons-2.0", true) or nil
end

function Travel.ZoneOf(mapID)
	if not mapID or not C_Map or not C_Map.GetMapInfo then return mapID end
	local zoneType = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
	local info = C_Map.GetMapInfo(mapID)
	while info and info.mapType and info.mapType > zoneType and info.parentMapID and info.parentMapID > 0 do
		mapID = info.parentMapID
		info = C_Map.GetMapInfo(mapID)
	end
	return mapID
end

-- Returns { map, x, y, inst, wx, wy } or nil.
function Travel.Point(mapID, x, y)
	if not (mapID and x and y) then return nil end
	local hbd = GetHBD()
	if hbd then
		local wx, wy, inst = hbd:GetWorldCoordinatesFromZone(x / 100, y / 100, mapID)
		if wx and wy and inst then
			return { map = mapID, x = x, y = y, inst = inst, wx = wx, wy = wy }
		end
	end
	if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
		local ok, inst, vec = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x / 100, y / 100))
		if ok and inst and vec then
			local a, b = vec:GetXY()
			if hbd then a, b = b, a end
			return { map = mapID, x = x, y = y, inst = inst, wx = a, wy = b }
		end
	end
	return nil
end

function Travel.PlayerPoint()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
	local m = C_Map.GetBestMapForUnit("player")
	if not m then return nil end
	local z = Travel.ZoneOf(m)
	local pos = C_Map.GetPlayerMapPosition(z, "player") or C_Map.GetPlayerMapPosition(m, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	return Travel.Point(z, x * 100, y * 100)
end

function Travel.Distance(a, b)
	if not (a and b and a.wx and b.wx) then return math.huge end
	if a.inst ~= b.inst then return math.huge end
	local dx, dy = a.wx - b.wx, a.wy - b.wy
	return math.sqrt(dx * dx + dy * dy)
end

-- Bearing in radians (counter-clockwise from north) and distance in yards from player to target {map, x, y}.
function Travel.VectorFromPlayer(mapID, x, y)
	local hbd = GetHBD()
	if hbd then
		local tx, ty, ti = hbd:GetWorldCoordinatesFromZone(x / 100, y / 100, mapID)
		local px, py, pi = hbd:GetPlayerWorldPosition()
		if not (tx and px) then return nil, "nopos" end
		if ti ~= pi then return nil, "continent" end
		local angle, dist = hbd:GetWorldVector(pi, px, py, tx, ty)
		return dist, angle
	end
	local p = Travel.PlayerPoint()
	local t = Travel.Point(mapID, x, y)
	if not (p and t) then return nil, "nopos" end
	if p.inst ~= t.inst then return nil, "continent" end
	local dx, dy = t.wx - p.wx, t.wy - p.wy
	local o = Travel.Point(p.map, 50, 50)
	local e = Travel.Point(p.map, 60, 50)
	local s = Travel.Point(p.map, 50, 60)
	if not (o and e and s) then return math.sqrt(dx * dx + dy * dy), 0 end
	local exv, eyv = e.wx - o.wx, e.wy - o.wy
	local sxv, syv = s.wx - o.wx, s.wy - o.wy
	local east = (dx * exv + dy * eyv) / math.sqrt(exv * exv + eyv * eyv)
	local south = (dx * sxv + dy * syv) / math.sqrt(sxv * sxv + syv * syv)
	return math.sqrt(dx * dx + dy * dy), math.atan2(-east, -south)
end

--------------------------------------------------------------------------------
-- Graph Construction (All faction flights + ships + roads enabled by default!)
--------------------------------------------------------------------------------
function Travel.Reset()
	graphNodes = nil
	graphByZone = nil
	builtSide = nil
	wipe(distCache)
end

local function SideMatches(entrySide, playerSide)
	local tag = (playerSide == "Horde") and "H" or "A"
	return entrySide == "AH" or entrySide == tag
end

local function BuildGraph()
	local side = FWC.Rep.PlayerSide()
	if graphNodes and builtSide == side then return graphNodes, graphByZone end

	local nodes = {}
	local byZone = {}
	local hostile = (FWC.Data and FWC.Data.HostileCapitals and FWC.Data.HostileCapitals[side]) or {}

	local function AddNode(n)
		local idx = #nodes + 1
		n.idx = idx
		n.edges = {}
		nodes[idx] = n
		if n.map then
			byZone[n.map] = byZone[n.map] or {}
			byZone[n.map][#byZone[n.map] + 1] = n
		end
		return n
	end

	local function AddEdge(a, b, cost, kind, label)
		a.edges[#a.edges + 1] = { to = b.idx, cost = cost, kind = kind, label = label }
	end

	-- 1. All faction flight points (assumed available immediately!)
	local flightNodes = {}
	for fpID, fp in pairs((FWC.Data and FWC.Data.FlightNodes) or {}) do
		if SideMatches(fp.side, side) then
			local pt = Travel.Point(fp.map, fp.x, fp.y)
			if pt then
				local n = AddNode({
					kind = "flight",
					fpID = fpID,
					name = fp.name,
					map = fp.map,
					x = fp.x,
					y = fp.y,
					inst = pt.inst,
					wx = pt.wx,
					wy = pt.wy,
				})
				flightNodes[#flightNodes + 1] = n
			end
		end
	end

	-- Connect all flight nodes on the same continent
	for i = 1, #flightNodes do
		for j = i + 1, #flightNodes do
			local a, b = flightNodes[i], flightNodes[j]
			if a.inst == b.inst then
				local d = Travel.Distance(a, b)
				local secs = math.floor(d / FLY_SPEED + FLIGHT_OVERHEAD + 0.5)
				AddEdge(a, b, secs, "fly", "Fly to " .. b.name)
				AddEdge(b, a, secs, "fly", "Fly to " .. a.name)
			end
		end
	end

	-- 2. All faction boats & zeppelins (assumed available immediately!)
	for _, ship in ipairs((FWC.Data and FWC.Data.Ships) or {}) do
		if SideMatches(ship.side, side) then
			local pFrom = Travel.Point(ship.fromMap, ship.fx, ship.fy)
			local pTo = Travel.Point(ship.toMap, ship.tx, ship.ty)
			if pFrom and pTo then
				local na = AddNode({
					kind = ship.kind,
					name = ship.label,
					map = ship.fromMap,
					x = ship.fx,
					y = ship.fy,
					inst = pFrom.inst,
					wx = pFrom.wx,
					wy = pFrom.wy,
				})
				local nb = AddNode({
					kind = "landing",
					name = FWC.MapName(ship.toMap),
					map = ship.toMap,
					x = ship.tx,
					y = ship.ty,
					inst = pTo.inst,
					wx = pTo.wx,
					wy = pTo.wy,
				})
				AddEdge(na, nb, ship.time or 240, ship.kind, ship.label)
			end
		end
	end

	-- 3. Zone road crossings (bidirectional)
	for _, rc in ipairs((FWC.Data and FWC.Data.RoadCrossings) or {}) do
		local pa = Travel.Point(rc[1], rc[2], rc[3])
		local pb = Travel.Point(rc[4], rc[5], rc[6])
		if pa and pb then
			local na = AddNode({
				kind = "road",
				name = FWC.MapName(rc[4]),
				map = rc[1],
				x = rc[2],
				y = rc[3],
				inst = pa.inst,
				wx = pa.wx,
				wy = pa.wy,
			})
			local nb = AddNode({
				kind = "road",
				name = FWC.MapName(rc[1]),
				map = rc[4],
				x = rc[5],
				y = rc[6],
				inst = pb.inst,
				wx = pb.wx,
				wy = pb.wy,
			})
			local penA = hostile[rc[4]] and HOSTILE_PENALTY or 0
			local penB = hostile[rc[1]] and HOSTILE_PENALTY or 0
			AddEdge(na, nb, CROSSING_COST + penA, "road", "Cross into " .. FWC.MapName(rc[4]))
			AddEdge(nb, na, CROSSING_COST + penB, "road", "Cross into " .. FWC.MapName(rc[1]))
		end
	end

	-- 4. Connect all nodes within the same zone by riding
	for zone, list in pairs(byZone) do
		local pen = hostile[zone] and HOSTILE_PENALTY or 0
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				if a.inst == b.inst then
					local ride = Travel.Distance(a, b) / RIDE_SPEED * 1.15 + pen
					AddEdge(a, b, ride, "ride")
					AddEdge(b, a, ride, "ride")
				end
			end
		end
	end

	graphNodes = nodes
	graphByZone = byZone
	builtSide = side
	return nodes, byZone
end

--------------------------------------------------------------------------------
-- Dijkstra Shortest Path
--------------------------------------------------------------------------------
local function RunDijkstra(startPt, endPt)
	if not (startPt and endPt) then return 600, {} end
	if startPt.map == endPt.map and startPt.inst == endPt.inst then
		local direct = Travel.Distance(startPt, endPt) / RIDE_SPEED * 1.1
		if direct < 120 then return direct, {} end
	end

	local nodes, byZone = BuildGraph()
	local N = #nodes
	local startIdx = N + 1
	local endIdx = N + 2

	local dist = {}
	local prev = {}
	local prevEdge = {}
	local visited = {}
	for i = 1, endIdx do dist[i] = math.huge end
	dist[startIdx] = 0

	-- Virtual edges from startPt to nodes in startPt.map (plus direct if same map)
	local startEdges = {}
	if startPt.map == endPt.map and startPt.inst == endPt.inst then
		local direct = Travel.Distance(startPt, endPt) / RIDE_SPEED * 1.15
		startEdges[#startEdges + 1] = { to = endIdx, cost = direct, kind = "ride" }
	end
	for _, n in ipairs(byZone[startPt.map] or {}) do
		if n.inst == startPt.inst then
			startEdges[#startEdges + 1] = { to = n.idx, cost = Travel.Distance(startPt, n) / RIDE_SPEED * 1.15, kind = "ride" }
		end
	end
	-- Fallback if player is in a subzone/unmapped zone: connect to nearest 3 nodes on same continent
	if #startEdges == 0 then
		local nearest = {}
		for _, n in ipairs(nodes) do
			if n.inst == startPt.inst then
				nearest[#nearest + 1] = { idx = n.idx, d = Travel.Distance(startPt, n) }
			end
		end
		table.sort(nearest, function(a, b) return a.d < b.d end)
		for i = 1, math.min(3, #nearest) do
			startEdges[#startEdges + 1] = { to = nearest[i].idx, cost = nearest[i].d / RIDE_SPEED * 1.25, kind = "ride" }
		end
	end

	-- Virtual edges from nodes in endPt.map to endPt
	local toEndCost = {}
	local endZoneNodes = byZone[endPt.map] or {}
	if #endZoneNodes > 0 then
		for _, n in ipairs(endZoneNodes) do
			if n.inst == endPt.inst then
				toEndCost[n.idx] = Travel.Distance(n, endPt) / RIDE_SPEED * 1.15
			end
		end
	else
		local nearest = {}
		for _, n in ipairs(nodes) do
			if n.inst == endPt.inst then
				nearest[#nearest + 1] = { idx = n.idx, d = Travel.Distance(n, endPt) }
			end
		end
		table.sort(nearest, function(a, b) return a.d < b.d end)
		for i = 1, math.min(3, #nearest) do
			toEndCost[nearest[i].idx] = nearest[i].d / RIDE_SPEED * 1.25
		end
	end

	-- Simple O(V^2) Dijkstra (V ~ 130 nodes -> <0.1ms in Lua!)
	for _ = 1, endIdx do
		local u, bestD = nil, math.huge
		for i = 1, endIdx do
			if not visited[i] and dist[i] < bestD then
				u, bestD = i, dist[i]
			end
		end
		if not u or u == endIdx then break end
		visited[u] = true

		local edges = (u == startIdx) and startEdges or (nodes[u] and nodes[u].edges) or nil
		if edges then
			for _, e in ipairs(edges) do
				local nd = bestD + e.cost
				if nd < dist[e.to] then
					dist[e.to] = nd
					prev[e.to] = u
					prevEdge[e.to] = e
				end
			end
		end
		local ec = toEndCost[u]
		if ec then
			local nd = bestD + ec
			if nd < dist[endIdx] then
				dist[endIdx] = nd
				prev[endIdx] = u
				prevEdge[endIdx] = { to = endIdx, cost = ec, kind = "ride" }
			end
		end
	end

	if dist[endIdx] == math.huge then
		return 900, {}
	end

	-- Reconstruct travel steps
	local chain = {}
	local cur = endIdx
	while cur and cur ~= startIdx do
		local p = prev[cur]
		local e = prevEdge[cur]
		if p and e then
			chain[#chain + 1] = { from = p, to = cur, edge = e }
		end
		cur = p
	end

	local steps = {}
	for i = #chain, 1, -1 do
		local seg = chain[i]
		local e = seg.edge
		local fromNode = nodes[seg.from]
		local toNode = nodes[seg.to]
		if e.kind == "fly" and fromNode and toNode then
			steps[#steps + 1] = {
				kind = "fly",
				map = fromNode.map,
				x = fromNode.x,
				y = fromNode.y,
				destMap = toNode.map,
				destName = toNode.name,
				fromName = fromNode.name,
				secs = math.floor(e.cost + 0.5),
			}
		elseif (e.kind == "boat" or e.kind == "zeppelin") and fromNode and toNode then
			steps[#steps + 1] = {
				kind = e.kind,
				map = fromNode.map,
				x = fromNode.x,
				y = fromNode.y,
				destMap = toNode.map,
				label = e.label,
				secs = math.floor(e.cost + 0.5),
			}
		elseif e.kind == "road" and fromNode and toNode then
			steps[#steps + 1] = {
				kind = "road",
				map = fromNode.map,
				x = fromNode.x,
				y = fromNode.y,
				destMap = toNode.map,
				label = e.label,
				secs = math.floor(e.cost + 0.5),
			}
		end
	end

	return dist[endIdx], steps
end

function Travel.Time(startPt, endPt)
	if not (startPt and endPt) then return 600 end
	local k = string.format("%d:%.0f:%.0f>%d:%.0f:%.0f",
		startPt.map or 0, startPt.x or 0, startPt.y or 0,
		endPt.map or 0, endPt.x or 0, endPt.y or 0)
	if distCache[k] then return distCache[k] end
	local secs = RunDijkstra(startPt, endPt)
	distCache[k] = secs
	return secs
end

function Travel.Steps(startPt, endPt)
	local secs, steps = RunDijkstra(startPt, endPt)
	return steps, secs
end

--------------------------------------------------------------------------------
-- Available Teleports / Hearthstone (optional time-savers)
--------------------------------------------------------------------------------
local BIND_LOOKUP = {
	["Stormwind"] = 2, ["Trade District"] = 2, ["Ironforge"] = 6, ["Menethil"] = 7,
	["Darkshire"] = 12, ["Southshore"] = 14, ["Booty Bay"] = 19, ["Auberdine"] = 26,
	["Astranaar"] = 28, ["Theramore"] = 32, ["Gadgetzan"] = 39, ["Everlook"] = 52,
	["Orgrimmar"] = 23, ["Valley of Strength"] = 23, ["Thunder Bluff"] = 22, ["Undercity"] = 11,
	["Crossroads"] = 25, ["Grom'gol"] = 20, ["Kargath"] = 21, ["Tarren Mill"] = 13,
	["Stonard"] = 56, ["Ratchet"] = 80, ["Hammerfall"] = 17, ["Freewind Post"] = 30,
}

local function IsSpellKnownSafe(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
		if ok and known then return true end
	end
	if IsPlayerSpell then
		local ok, known = pcall(IsPlayerSpell, spellID)
		if ok and known then return true end
	end
	if IsSpellKnown then
		local ok, known = pcall(IsSpellKnown, spellID)
		if ok and known then return true end
	end
	return false
end

local function SpellCooldownRemaining(spellID)
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if ok and type(info) == "table" and info.startTime and info.duration and info.duration > 1.5 then
			return math.max(0, (info.startTime + info.duration) - GetTime())
		end
	elseif GetSpellCooldown then
		local start, dur = GetSpellCooldown(spellID)
		if start and dur and dur > 1.5 then
			return math.max(0, (start + dur) - GetTime())
		end
	end
	return 0
end

local MAGE_TELEPORTS = {
	-- Alliance
	{ spellID = 3561, side = "Alliance", minLevel = 20, name = "Teleport: Stormwind",     map = 1453, x = 49.6, y = 87.2 },
	{ spellID = 3562, side = "Alliance", minLevel = 20, name = "Teleport: Ironforge",     map = 1455, x = 27.2, y = 8.6  },
	{ spellID = 3565, side = "Alliance", minLevel = 30, name = "Teleport: Darnassus",     map = 1457, x = 40.4, y = 81.8 },
	-- Horde
	{ spellID = 3567, side = "Horde",    minLevel = 20, name = "Teleport: Orgrimmar",     map = 1454, x = 38.6, y = 85.4 },
	{ spellID = 3563, side = "Horde",    minLevel = 20, name = "Teleport: Undercity",     map = 1458, x = 85.2, y = 17.0 },
	{ spellID = 3566, side = "Horde",    minLevel = 30, name = "Teleport: Thunder Bluff", map = 1456, x = 22.2, y = 13.8 },
}

function Travel.GetTeleports()
	local list = {}
	local nodes = BuildGraph()
	local byID = {}
	for _, n in ipairs(nodes) do
		if n.fpID then byID[n.fpID] = n end
	end

	local _, classToken = UnitClass and UnitClass("player")
	local playerLevel = (UnitLevel and UnitLevel("player")) or 60
	local side = FWC.Rep.PlayerSide()

	-- 1. Hearthstone (and Shaman Astral Recall to the same bind spot)
	local bindDest, bindName
	if GetBindLocation then
		local bind = GetBindLocation()
		if type(bind) == "string" and bind ~= "" then
			bindName = bind
			local fpID
			for pattern, id in pairs(BIND_LOOKUP) do
				if bind:find(pattern, 1, true) and byID[id] then fpID = id; break end
			end
			if fpID and byID[fpID] then
				local n = byID[fpID]
				bindDest = Travel.Point(n.map, n.x, n.y)
				local ready = 0
				if C_Container and C_Container.GetItemCooldown then
					local start, dur = C_Container.GetItemCooldown(6948)
					if start and dur and dur > 0 then ready = math.max(0, (start + dur) - GetTime()) end
				end
				list[#list + 1] = {
					key = "hearth",
					kind = "hearth",
					name = "Hearthstone (" .. bind .. ")",
					cast = 15,
					cd = 3600,
					ready = ready,
					dest = bindDest,
				}
			end
		end
	end

	-- 2. Shaman: Astral Recall (spell 556)
	if classToken == "SHAMAN" and bindDest and IsSpellKnownSafe(556) then
		list[#list + 1] = {
			key = "astral",
			kind = "hearth",
			name = "Astral Recall (" .. (bindName or "Hearth") .. ")",
			cast = 15,
			cd = 900,
			ready = SpellCooldownRemaining(556),
			dest = bindDest,
		}
	end

	-- 3. Druid: Teleport: Moonglade (spell 18960, no cooldown)
	if classToken == "DRUID" and (IsSpellKnownSafe(18960) or playerLevel >= 10) then
		local dest = Travel.Point(1450, 56.0, 32.0)
		if dest then
			list[#list + 1] = {
				key = "moonglade",
				kind = "teleport",
				name = "Teleport: Moonglade",
				cast = 15,
				cd = 0,
				ready = 0,
				dest = dest,
			}
		end
	end

	-- 4. Mage: Every faction City Teleport available for the mage's current level / spellbook
	if classToken == "MAGE" then
		for _, mt in ipairs(MAGE_TELEPORTS) do
			if mt.side == side and (IsSpellKnownSafe(mt.spellID) or playerLevel >= mt.minLevel) then
				local dest = Travel.Point(mt.map, mt.x, mt.y)
				if dest then
					list[#list + 1] = {
						key = "mage_" .. mt.spellID,
						kind = "teleport",
						name = mt.name,
						cast = 15,
						cd = 0,
						ready = 0,
						dest = dest,
					}
				end
			end
		end
	end

	return list
end
