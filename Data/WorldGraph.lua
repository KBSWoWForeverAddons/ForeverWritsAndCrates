-- Forever Writs and Crates: World travel graph data (WoW: Forever).
-- All faction flight paths, boats, zeppelins, and zone road crossings.
-- By design, all faction-accessible flight points and ships are assumed available immediately
-- without requiring visits to flight masters first.
local _, FWC = ...
FWC.Data = FWC.Data or {}

-- Flight points: [nodeID] = { map = uiMapID, x = percent, y = percent, side = "A"|"H"|"AH", name = label }
FWC.Data.FlightNodes = {
	-- Eastern Kingdoms
	[2]    = { map = 1453, x = 71.3, y = 72.2, side = "A",  name = "Stormwind, Elwynn" },
	[4]    = { map = 1436, x = 56.5, y = 52.6, side = "A",  name = "Sentinel Hill, Westfall" },
	[5]    = { map = 1433, x = 30.6, y = 59.4, side = "A",  name = "Lakeshire, Redridge" },
	[6]    = { map = 1455, x = 55.5, y = 47.8, side = "A",  name = "Ironforge, Dun Morogh" },
	[7]    = { map = 1437, x = 9.5,  y = 59.7, side = "A",  name = "Menethil Harbor, Wetlands" },
	[8]    = { map = 1432, x = 33.9, y = 51.0, side = "A",  name = "Thelsamar, Loch Modan" },
	[10]   = { map = 1421, x = 45.6, y = 42.6, side = "H",  name = "The Sepulcher, Silverpine" },
	[11]   = { map = 1458, x = 63.2, y = 48.6, side = "H",  name = "Undercity, Tirisfal" },
	[12]   = { map = 1431, x = 77.5, y = 44.3, side = "A",  name = "Darkshire, Duskwood" },
	[13]   = { map = 1424, x = 60.1, y = 18.6, side = "H",  name = "Tarren Mill, Hillsbrad" },
	[14]   = { map = 1424, x = 49.3, y = 52.3, side = "A",  name = "Southshore, Hillsbrad" },
	[16]   = { map = 1417, x = 45.7, y = 46.1, side = "A",  name = "Refuge Pointe, Arathi" },
	[17]   = { map = 1417, x = 73.0, y = 32.7, side = "H",  name = "Hammerfall, Arathi" },
	[18]   = { map = 1434, x = 26.9, y = 77.1, side = "H",  name = "Booty Bay, Stranglethorn" },
	[19]   = { map = 1434, x = 27.5, y = 77.8, side = "A",  name = "Booty Bay, Stranglethorn" },
	[20]   = { map = 1434, x = 32.5, y = 29.4, side = "H",  name = "Grom'gol, Stranglethorn" },
	[21]   = { map = 1418, x = 4.0,  y = 44.8, side = "H",  name = "Kargath, Badlands" },
	[43]   = { map = 1425, x = 11.1, y = 46.1, side = "A",  name = "Aerie Peak, The Hinterlands" },
	[45]   = { map = 1419, x = 65.5, y = 24.3, side = "A",  name = "Nethergarde Keep, Blasted Lands" },
	[56]   = { map = 1435, x = 46.1, y = 54.8, side = "H",  name = "Stonard, Swamp of Sorrows" },
	[66]   = { map = 1422, x = 42.9, y = 85.1, side = "A",  name = "Chillwind Camp, Western Plaguelands" },
	[67]   = { map = 1423, x = 71.8, y = 49.6, side = "A",  name = "Light's Hope Chapel, Eastern Plaguelands" },
	[68]   = { map = 1423, x = 70.5, y = 47.5, side = "H",  name = "Light's Hope Chapel, Eastern Plaguelands" },
	[70]   = { map = 1428, x = 65.7, y = 24.2, side = "H",  name = "Flame Crest, Burning Steppes" },
	[71]   = { map = 1428, x = 84.3, y = 68.3, side = "A",  name = "Morgan's Vigil, Burning Steppes" },
	[74]   = { map = 1427, x = 37.9, y = 30.9, side = "A",  name = "Thorium Point, Searing Gorge" },
	[75]   = { map = 1427, x = 34.8, y = 30.9, side = "H",  name = "Thorium Point, Searing Gorge" },
	[76]   = { map = 1425, x = 81.7, y = 81.8, side = "H",  name = "Revantusk Village, The Hinterlands" },
	[3203] = { map = 2548, x = 59.6, y = 45.1, side = "H",  name = "Rog'mar, Riverglades" },
	[3276] = { map = 2548, x = 60.6, y = 81.6, side = "A",  name = "Farholde Keep, Riverglades" },

	-- Kalimdor
	[22]   = { map = 1456, x = 47.0, y = 49.8, side = "H",  name = "Thunder Bluff, Mulgore" },
	[23]   = { map = 1454, x = 45.1, y = 63.9, side = "H",  name = "Orgrimmar, Durotar" },
	[25]   = { map = 1413, x = 51.5, y = 30.3, side = "H",  name = "Crossroads, The Barrens" },
	[26]   = { map = 1439, x = 36.3, y = 45.6, side = "A",  name = "Auberdine, Darkshore" },
	[27]   = { map = 1438, x = 58.4, y = 94.0, side = "A",  name = "Rut'theran Village, Teldrassil" },
	[28]   = { map = 1440, x = 34.4, y = 48.0, side = "A",  name = "Astranaar, Ashenvale" },
	[29]   = { map = 1442, x = 45.1, y = 59.8, side = "H",  name = "Sun Rock Retreat, Stonetalon" },
	[30]   = { map = 1441, x = 45.1, y = 49.1, side = "H",  name = "Freewind Post, Thousand Needles" },
	[31]   = { map = 1444, x = 89.5, y = 45.8, side = "A",  name = "Thalanaar, Feralas" },
	[32]   = { map = 1445, x = 67.5, y = 51.3, side = "A",  name = "Theramore, Dustwallow Marsh" },
	[33]   = { map = 1442, x = 36.4, y = 7.2,  side = "A",  name = "Stonetalon Peak, Stonetalon" },
	[37]   = { map = 1443, x = 64.7, y = 10.5, side = "A",  name = "Nijel's Point, Desolace" },
	[38]   = { map = 1443, x = 21.6, y = 74.1, side = "H",  name = "Shadowprey Village, Desolace" },
	[39]   = { map = 1446, x = 51.0, y = 29.3, side = "A",  name = "Gadgetzan, Tanaris" },
	[40]   = { map = 1446, x = 51.6, y = 25.4, side = "H",  name = "Gadgetzan, Tanaris" },
	[41]   = { map = 1444, x = 30.2, y = 43.2, side = "A",  name = "Feathermoon, Feralas" },
	[42]   = { map = 1444, x = 75.5, y = 44.4, side = "H",  name = "Camp Mojache, Feralas" },
	[44]   = { map = 1447, x = 22.0, y = 49.6, side = "H",  name = "Valormok, Azshara" },
	[48]   = { map = 1448, x = 34.4, y = 54.0, side = "H",  name = "Bloodvenom Post, Felwood" },
	[49]   = { map = 1450, x = 48.1, y = 67.3, side = "A",  name = "Nighthaven, Moonglade" },
	[52]   = { map = 1452, x = 62.3, y = 36.6, side = "A",  name = "Everlook, Winterspring" },
	[53]   = { map = 1452, x = 60.5, y = 36.3, side = "H",  name = "Everlook, Winterspring" },
	[55]   = { map = 1445, x = 35.6, y = 31.9, side = "H",  name = "Brackenwall Village, Dustwallow" },
	[58]   = { map = 1440, x = 12.2, y = 33.8, side = "H",  name = "Zoram'gar Outpost, Ashenvale" },
	[61]   = { map = 1440, x = 73.2, y = 61.6, side = "H",  name = "Splintertree Post, Ashenvale" },
	[64]   = { map = 1447, x = 11.9, y = 77.6, side = "A",  name = "Talrendis Point, Azshara" },
	[65]   = { map = 1448, x = 62.5, y = 24.2, side = "A",  name = "Talonbranch Glade, Felwood" },
	[69]   = { map = 1450, x = 32.1, y = 66.3, side = "H",  name = "Nighthaven, Moonglade" },
	[72]   = { map = 1451, x = 48.7, y = 36.7, side = "H",  name = "Cenarion Hold, Silithus" },
	[73]   = { map = 1451, x = 50.6, y = 34.5, side = "A",  name = "Cenarion Hold, Silithus" },
	[77]   = { map = 1413, x = 44.5, y = 59.1, side = "H",  name = "Camp Taurajo, The Barrens" },
	[79]   = { map = 1449, x = 45.2, y = 5.8,  side = "AH", name = "Marshal's Refuge, Un'Goro Crater" },
	[80]   = { map = 1413, x = 63.1, y = 37.2, side = "AH", name = "Ratchet, The Barrens" },
}

-- Boats and Zeppelins (zone coords, assumed available for the player's faction)
-- { kind = "boat"|"zeppelin", side = "A"|"H"|"AH", fromMap, fx, fy, toMap, tx, ty, time, label }
FWC.Data.Ships = {
	-- Neutral Boats
	{ kind = "boat", side = "AH", fromMap = 1413, fx = 63.7, fy = 38.6, toMap = 1434, tx = 25.9, ty = 73.1, time = 240, label = "Boat: Ratchet -> Booty Bay" },
	{ kind = "boat", side = "AH", fromMap = 1434, fx = 25.9, fy = 73.1, toMap = 1413, tx = 63.7, ty = 38.6, time = 240, label = "Boat: Booty Bay -> Ratchet" },
	{ kind = "boat", side = "AH", fromMap = 2548, fx = 80.5, fy = 55.0, toMap = 1446, tx = 68.5, ty = 23.3, time = 240, label = "Boat: Powderfuse Port -> Steamwheedle Port" },
	{ kind = "boat", side = "AH", fromMap = 1446, fx = 68.5, fy = 23.3, toMap = 2548, tx = 80.5, ty = 55.0, time = 240, label = "Boat: Steamwheedle Port -> Powderfuse Port" },

	-- Alliance Boats
	{ kind = "boat", side = "A", fromMap = 1437, fx = 4.7,  fy = 57.1, toMap = 1439, tx = 32.4, ty = 43.8, time = 240, label = "Boat: Menethil Harbor -> Auberdine" },
	{ kind = "boat", side = "A", fromMap = 1439, fx = 32.4, fy = 43.8, toMap = 1437, tx = 4.7,  ty = 57.1, time = 240, label = "Boat: Auberdine -> Menethil Harbor" },
	{ kind = "boat", side = "A", fromMap = 1437, fx = 5.0,  fy = 63.5, toMap = 1445, tx = 71.6, ty = 56.5, time = 240, label = "Boat: Menethil Harbor -> Theramore" },
	{ kind = "boat", side = "A", fromMap = 1445, fx = 71.6, fy = 56.5, toMap = 1437, tx = 5.0,  ty = 63.5, time = 240, label = "Boat: Theramore -> Menethil Harbor" },
	{ kind = "boat", side = "A", fromMap = 1439, fx = 33.2, fy = 40.0, toMap = 1438, tx = 54.9, ty = 96.0, time = 150, label = "Boat: Auberdine -> Rut'theran Village" },
	{ kind = "boat", side = "A", fromMap = 1438, fx = 54.9, fy = 96.0, toMap = 1439, tx = 33.2, ty = 40.0, time = 150, label = "Boat: Rut'theran Village -> Auberdine" },
	{ kind = "boat", side = "A", fromMap = 1453, fx = 22.5, fy = 55.8, toMap = 1439, tx = 32.4, ty = 43.8, time = 240, label = "Boat: Stormwind Harbor -> Auberdine" },
	{ kind = "boat", side = "A", fromMap = 1439, fx = 32.4, fy = 43.8, toMap = 1453, tx = 22.5, ty = 55.8, time = 240, label = "Boat: Auberdine -> Stormwind Harbor" },

	-- Horde Zeppelins
	{ kind = "zeppelin", side = "H", fromMap = 1411, fx = 50.8, fy = 13.8, toMap = 1420, tx = 60.6, ty = 58.8, time = 220, label = "Zeppelin: Orgrimmar -> Undercity" },
	{ kind = "zeppelin", side = "H", fromMap = 1420, fx = 60.6, fy = 58.8, toMap = 1411, tx = 50.8, ty = 13.8, time = 220, label = "Zeppelin: Undercity -> Orgrimmar" },
	{ kind = "zeppelin", side = "H", fromMap = 1411, fx = 50.6, fy = 12.6, toMap = 1434, tx = 31.4, ty = 30.1, time = 220, label = "Zeppelin: Orgrimmar -> Grom'gol" },
	{ kind = "zeppelin", side = "H", fromMap = 1434, fx = 31.4, fy = 30.1, toMap = 1411, tx = 50.6, ty = 12.6, time = 220, label = "Zeppelin: Grom'gol -> Orgrimmar" },
	{ kind = "zeppelin", side = "H", fromMap = 1420, fx = 61.9, fy = 59.1, toMap = 1434, tx = 31.6, ty = 29.1, time = 220, label = "Zeppelin: Undercity -> Grom'gol" },
	{ kind = "zeppelin", side = "H", fromMap = 1434, fx = 31.6, fy = 29.1, toMap = 1420, tx = 61.9, ty = 59.1, time = 220, label = "Zeppelin: Grom'gol -> Undercity" },
	{ kind = "zeppelin", side = "H", fromMap = 1456, fx = 41.3, fy = 55.9, toMap = 1458, tx = 84.6, ty = 16.3, time = 220, label = "Zeppelin: Thunder Bluff -> Undercity" },
	{ kind = "zeppelin", side = "H", fromMap = 1458, fx = 84.6, fy = 16.3, toMap = 1456, tx = 41.3, ty = 55.9, time = 220, label = "Zeppelin: Undercity -> Thunder Bluff" },
}

-- Major bidirectional zone road crossings: { mapA, ax, ay, mapB, bx, by }
FWC.Data.RoadCrossings = {
	-- Kalimdor
	{ 1454, 45.0, 91.0, 1411, 45.5, 11.0 }, -- Orgrimmar <-> Durotar
	{ 1411, 35.0, 42.0, 1413, 62.0, 21.0 }, -- Durotar <-> Barrens
	{ 1413, 41.5, 58.0, 1412, 68.5, 61.0 }, -- Barrens <-> Mulgore
	{ 1412, 39.8, 29.2, 1456, 40.6, 12.1 }, -- Mulgore <-> Thunder Bluff
	{ 1413, 48.0, 5.0,  1440, 68.0, 86.0 }, -- Barrens <-> Ashenvale
	{ 1413, 35.0, 27.0, 1442, 80.0, 85.0 }, -- Barrens <-> Stonetalon
	{ 1413, 49.0, 88.0, 1441, 32.0, 24.0 }, -- Barrens <-> Thousand Needles
	{ 1413, 49.0, 74.0, 1445, 29.0, 47.0 }, -- Barrens <-> Dustwallow Marsh
	{ 1440, 28.0, 35.0, 1439, 43.0, 94.0 }, -- Ashenvale <-> Darkshore
	{ 1440, 55.0, 35.0, 1448, 54.0, 94.0 }, -- Ashenvale <-> Felwood
	{ 1440, 95.0, 50.0, 1447, 11.0, 77.0 }, -- Ashenvale <-> Azshara
	{ 1442, 30.0, 80.0, 1443, 53.0, 5.0  }, -- Stonetalon <-> Desolace
	{ 1443, 42.0, 95.0, 1444, 45.0, 12.0 }, -- Desolace <-> Feralas
	{ 1444, 89.0, 46.0, 1441, 8.0,  11.0 }, -- Feralas <-> Thousand Needles
	{ 1441, 75.0, 96.0, 1446, 51.0, 15.0 }, -- Thousand Needles <-> Tanaris
	{ 1446, 27.0, 57.0, 1449, 71.0, 77.0 }, -- Tanaris <-> Un'Goro Crater
	{ 1449, 29.0, 78.0, 1451, 81.0, 18.0 }, -- Un'Goro Crater <-> Silithus
	{ 1448, 65.0, 7.0,  1450, 36.0, 68.0 }, -- Felwood <-> Moonglade (Timbermaw)
	{ 1448, 65.0, 7.0,  1452, 27.0, 35.0 }, -- Felwood <-> Winterspring (Timbermaw)

	-- Eastern Kingdoms
	{ 1453, 66.0, 75.0, 1429, 32.0, 49.0 }, -- Stormwind <-> Elwynn Forest
	{ 1429, 24.0, 75.0, 1436, 61.0, 18.0 }, -- Elwynn <-> Westfall
	{ 1429, 43.0, 91.0, 1431, 44.0, 12.0 }, -- Elwynn <-> Duskwood
	{ 1429, 93.0, 73.0, 1433, 15.0, 72.0 }, -- Elwynn <-> Redridge
	{ 1436, 63.0, 62.0, 1431, 8.0,  59.0 }, -- Westfall <-> Duskwood
	{ 1431, 44.8, 84.6, 1434, 43.0, 4.0  }, -- Duskwood <-> Stranglethorn Vale
	{ 1431, 92.0, 43.0, 1430, 14.0, 48.0 }, -- Duskwood <-> Deadwind Pass
	{ 1430, 58.0, 41.0, 1435, 6.0,  61.0 }, -- Deadwind Pass <-> Swamp of Sorrows
	{ 1435, 34.0, 88.0, 1419, 52.0, 10.0 }, -- Swamp of Sorrows <-> Blasted Lands
	{ 1433, 30.0, 12.0, 1428, 78.0, 76.0 }, -- Redridge <-> Burning Steppes
	{ 1428, 30.0, 38.0, 1427, 35.0, 82.0 }, -- Burning Steppes <-> Searing Gorge
	{ 1427, 68.0, 62.0, 1418, 5.0,  61.0 }, -- Searing Gorge <-> Badlands
	{ 1418, 49.0, 9.0,  1432, 46.0, 86.0 }, -- Badlands <-> Loch Modan
	{ 1432, 21.0, 17.0, 1437, 54.0, 71.0 }, -- Loch Modan <-> Wetlands
	{ 1432, 19.0, 62.0, 1426, 84.0, 51.0 }, -- Loch Modan <-> Dun Morogh
	{ 1426, 53.0, 35.0, 1455, 14.0, 86.0 }, -- Dun Morogh <-> Ironforge
	{ 1437, 51.0, 9.0,  1417, 45.0, 88.0 }, -- Wetlands <-> Arathi Highlands
	{ 1417, 21.0, 29.0, 1424, 85.0, 32.0 }, -- Arathi <-> Hillsbrad Foothills
	{ 1424, 83.0, 22.0, 1425, 8.0,  46.0 }, -- Hillsbrad <-> The Hinterlands
	{ 1424, 52.0, 15.0, 1416, 48.0, 80.0 }, -- Hillsbrad <-> Alterac Mountains
	{ 1424, 15.0, 46.0, 1421, 66.0, 79.0 }, -- Hillsbrad <-> Silverpine Forest
	{ 1421, 65.0, 7.0,  1420, 54.0, 72.0 }, -- Silverpine <-> Tirisfal Glades
	{ 1420, 62.0, 68.0, 1458, 66.3, 0.8  }, -- Tirisfal <-> Undercity
	{ 1420, 86.0, 69.0, 1422, 28.0, 58.0 }, -- Tirisfal <-> Western Plaguelands
	{ 1416, 80.0, 60.0, 1422, 54.0, 85.0 }, -- Alterac <-> Western Plaguelands
	{ 1422, 69.0, 50.0, 1423, 8.0,  66.0 }, -- Western Plaguelands <-> Eastern Plaguelands
	{ 1437, 65.0, 75.0, 2548, 25.0, 30.0 }, -- Wetlands <-> Riverglades
}

-- City / Capital zones (avoid routing straight through hostile capitals)
FWC.Data.HostileCapitals = {
	Alliance = { [1454] = true, [1456] = true, [1458] = true },
	Horde    = { [1453] = true, [1455] = true, [1457] = true },
}

-- Approach waypoints for tricky mountain paths, cave/dungeon entrances, tunnels, and teleporters.
-- Matched by zone mapID + target coordinate box (xMin..xMax, yMin..yMax) OR title/NPC substring.
-- Each waypoint is { x, y, text } in order before the final turn-in step.
FWC.Data.Approaches = {
	-- Wetlands: Excavation Site: Wetlands dungeon (Songblade Search)
	-- Approach via main Wetlands road south (54.0, 56.0) -> Thelgen Rock trailhead (53.5, 65.5) -> uphill portal (48.1, 56.5).
	{
		map = 1437,
		xMin = 44, xMax = 55, yMin = 52, yMax = 66,
		titleMatch = "Songblade",
		waypoints = {
			{ x = 54.0, y = 56.0, text = "Follow the main Wetlands road south toward Thelgen Rock" },
			{ x = 53.5, y = 65.5, text = "Go to Thelgen Rock Meeting Stone (do NOT enter cave; take uphill trail just south of it)" },
			{ x = 48.1, y = 56.5, text = "Follow the uphill mountain trail to the Excavation Site: Wetlands dungeon portal" },
		},
	},
	-- Wetlands: Dun Algaz mountain tunnels (south-east Wetlands)
	{
		map = 1437,
		xMin = 47, xMax = 58, yMin = 68, yMax = 82,
		waypoints = {
			{ x = 53.8, y = 70.5, text = "Enter the Dun Algaz mountain tunnel" },
		},
	},
	-- Azshara: Archmage Xylem's Tower (cliff teleporter pad)
	{
		map = 1447,
		xMin = 26, xMax = 33, yMin = 36, yMax = 44,
		waypoints = {
			{ x = 28.1, y = 50.1, text = "Step on the glowing Teleporter Pad at the cliff base to reach Xylem's Tower" },
		},
	},
	-- Azshara: Duke Hydraxis (island offshore)
	{
		map = 1447,
		xMin = 75, xMax = 84, yMin = 70, yMax = 78,
		waypoints = {
			{ x = 77.0, y = 62.5, text = "Swim southeast from the shore out to Hydraxis's island" },
		},
	},
	-- Alterac Mountains: Bath'rah the Windwatcher (mountain trail north)
	{
		map = 1416,
		xMin = 76, xMax = 85, yMin = 62, yMax = 72,
		waypoints = {
			{ x = 76.2, y = 77.5, text = "Take the mountain trail north up to Bath'rah's camp" },
		},
	},
	-- Felwood -> Moonglade / Winterspring: Timbermaw Hold tunnel entrance
	{
		map = 1448,
		xMin = 60, xMax = 70, yMin = 2, yMax = 12,
		waypoints = {
			{ x = 65.0, y = 7.0, text = "Enter the Timbermaw Hold tunnel" },
		},
	},
	-- The Hinterlands: Atal'ai Exile (Shadra'Alor ruins path)
	{
		map = 1425,
		xMin = 30, xMax = 38, yMin = 70, yMax = 80,
		waypoints = {
			{ x = 34.5, y = 66.5, text = "Follow the path south into Shadra'Alor ruins" },
		},
	},
	-- Stonetalon Mountains: Ziz Fizziks (Windshear Crag ramp)
	{
		map = 1442,
		xMin = 56, xMax = 63, yMin = 59, yMax = 66,
		waypoints = {
			{ x = 66.5, y = 65.5, text = "Take the Windshear Crag road west to Ziz Fizziks" },
		},
	},
	-- Deadwind Pass: Hastings (south road toward Karazhan)
	{
		map = 1430,
		xMin = 43, xMax = 52, yMin = 70, yMax = 80,
		waypoints = {
			{ x = 46.0, y = 63.0, text = "Follow the road south toward Karazhan" },
		},
	},
}

