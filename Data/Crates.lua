-- Forever Writs and Crates: Waylaid Crate catalogue (WoW: Forever).
local _, FWC = ...
FWC.Data = FWC.Data or {}

FWC.Data.Crates = {
	-- Apprentice (White: 5 Favor)
	{ id = 248682, quality = 1, level = 10, tier = "apprentice", bundles = {
		{ count = 20, items = { 2447 } }, -- Peacebloom
		{ count = 20, items = { 765 } },  -- Silverleaf
		{ count = 10, items = { 2449 } }, -- Earthroot
		{ count = 10, items = { 785 } },  -- Mageroyal
		{ count = 10, items = { 2450 } }, -- Briarthorn
	} },
	{ id = 248683, quality = 1, level = 10, tier = "apprentice", bundles = {
		{ count = 20, items = { 2770 } }, -- Copper Ore
		{ count = 20, items = { 2771 } }, -- Tin Ore
	} },
	{ id = 248684, quality = 1, level = 10, tier = "apprentice", bundles = {
		{ count = 40, items = { 2589 } }, -- Linen Cloth
		{ count = 20, items = { 2318 } }, -- Light Leather
	} },
	{ id = 248685, quality = 1, level = 10, tier = "apprentice", bundles = {
		{ count = 20, items = { 10940 } }, -- Strange Dust
		{ count = 4,  items = { 10939 } }, -- Greater Magic Essence
		{ count = 6,  items = { 10978 } }, -- Small Glimmering Shard
		{ count = 2,  items = { 11084 } }, -- Large Glimmering Shard
	} },

	-- Journeyman (White: 10 Favor)
	{ id = 248686, quality = 1, level = 10, tier = "journeyman", bundles = {
		{ count = 10, items = { 3820 } }, -- Stranglekelp
		{ count = 10, items = { 2453 } }, -- Bruiseweed
		{ count = 10, items = { 3355 } }, -- Wild Steelbloom
		{ count = 10, items = { 3369 } }, -- Grave Moss
		{ count = 10, items = { 3356 } }, -- Kingsblood
	} },
	{ id = 248687, quality = 1, level = 10, tier = "journeyman", bundles = {
		{ count = 10, items = { 2775 } }, -- Silver Ore
		{ count = 20, items = { 2772 } }, -- Iron Ore
	} },
	{ id = 248688, quality = 1, level = 10, tier = "journeyman", bundles = {
		{ count = 20, items = { 2592 } }, -- Wool Cloth
		{ count = 40, items = { 4306 } }, -- Silk Cloth
		{ count = 20, items = { 2319 } }, -- Medium Leather
	} },
	{ id = 248689, quality = 1, level = 10, tier = "journeyman", bundles = {
		{ count = 20, items = { 11083 } }, -- Soul Dust
		{ count = 4,  items = { 11082 } }, -- Greater Astral Essence
		{ count = 6,  items = { 11138 } }, -- Small Glowing Shard
		{ count = 2,  items = { 11139 } }, -- Large Glowing Shard
	} },

	-- Expert (White: 15 Favor)
	{ id = 248690, quality = 1, level = 20, tier = "expert", bundles = {
		{ count = 20, items = { 3357 } }, -- Liferoot
		{ count = 10, items = { 3818 } }, -- Fadeleaf
		{ count = 10, items = { 3821 } }, -- Goldthorn
		{ count = 10, items = { 3358 } }, -- Khadgar's Whisker
	} },
	{ id = 248691, quality = 1, level = 20, tier = "expert", bundles = {
		{ count = 10, items = { 3819 } }, -- Wintersbite
		{ count = 10, items = { 4625 } }, -- Firebloom
		{ count = 20, items = { 8831 } }, -- Purple Lotus
		{ count = 10, items = { 8836 } }, -- Arthas' Tears
	} },
	{ id = 248692, quality = 1, level = 20, tier = "expert", bundles = {
		{ count = 10, items = { 2776 } }, -- Gold Ore
		{ count = 20, items = { 3858 } }, -- Mithril Ore
	} },
	{ id = 248693, quality = 1, level = 20, tier = "expert", bundles = {
		{ count = 40, items = { 4338 } }, -- Mageweave Cloth
		{ count = 20, items = { 4234 } }, -- Heavy Leather
	} },
	{ id = 248694, quality = 1, level = 20, tier = "expert", bundles = {
		{ count = 20, items = { 11137 } }, -- Vision Dust
		{ count = 4,  items = { 11135 } }, -- Greater Mystic Essence
		{ count = 6,  items = { 11177 } }, -- Small Radiant Shard
		{ count = 2,  items = { 11178 } }, -- Large Radiant Shard
	} },

	-- Artisan (White: 20 Favor)
	{ id = 248695, quality = 1, level = 35, tier = "artisan", bundles = {
		{ count = 10, items = { 13464 } }, -- Golden Sansam
		{ count = 20, items = { 8838 } },  -- Sungrass
		{ count = 10, items = { 8839 } },  -- Blindweed
		{ count = 10, items = { 8845 } },  -- Ghost Mushroom
		{ count = 10, items = { 8846 } },  -- Gromsblood
	} },
	{ id = 248696, quality = 1, level = 35, tier = "artisan", bundles = {
		{ count = 20, items = { 13463 } }, -- Dreamfoil
		{ count = 20, items = { 13465 } }, -- Mountain Silversage
		{ count = 20, items = { 13466 } }, -- Plaguebloom
		{ count = 20, items = { 13467 } }, -- Icecap
	} },
	{ id = 248697, quality = 1, level = 35, tier = "artisan", bundles = {
		{ count = 10, items = { 7911 } },         -- Truesilver Ore
		{ count = 20, items = { 10620 } },        -- Thorium Ore
		{ count = 20, items = { 11370, 11099 } }, -- Dark Iron Ore
	} },
	{ id = 248698, quality = 1, level = 35, tier = "artisan", bundles = {
		{ count = 40, items = { 14047 } }, -- Runecloth
		{ count = 20, items = { 4304 } },  -- Thick Leather
		{ count = 20, items = { 8170 } },  -- Rugged Leather
	} },
	{ id = 248699, quality = 1, level = 35, tier = "artisan", bundles = {
		{ count = 20, items = { 11176 } }, -- Dream Dust
		{ count = 4,  items = { 11175 } }, -- Greater Nether Essence
		{ count = 6,  items = { 14343 } }, -- Small Brilliant Shard
		{ count = 2,  items = { 14344 } }, -- Large Brilliant Shard
	} },

	-- Apprentice (Green: 10 Favor)
	{ id = 248702, quality = 2, level = 10, tier = "apprentice", bundles = {
		{ count = 2,  items = { 4231 } }, -- Cured Light Hide
		{ count = 20, items = { 2996 } }, -- Bolt of Linen Cloth
	} },
	{ id = 248703, quality = 2, level = 10, tier = "apprentice", bundles = {
		{ count = 20, items = { 2840 } }, -- Copper Bar
		{ count = 20, items = { 3576 } }, -- Tin Bar
		{ count = 10, items = { 2841 } }, -- Bronze Bar
	} },
	{ id = 248704, quality = 2, level = 10, tier = "apprentice", bundles = {
		{ count = 16, items = { 4359 } }, -- Handful of Copper Bolts
		{ count = 16, items = { 4361 } }, -- Copper Tube
		{ count = 4,  items = { 4363 } }, -- Copper Modulator
	} },

	-- Journeyman (Green: 20 Favor)
	{ id = 248705, quality = 2, level = 10, tier = "journeyman", bundles = {
		{ count = 6,  items = { 2997 } }, -- Bolt of Woolen Cloth
		{ count = 10, items = { 4305 } }, -- Bolt of Silk Cloth
		{ count = 2,  items = { 4233 } }, -- Cured Medium Hide
	} },
	{ id = 248706, quality = 2, level = 10, tier = "journeyman", bundles = {
		{ count = 10, items = { 2842 } }, -- Silver Bar
		{ count = 20, items = { 3575 } }, -- Iron Bar
	} },
	{ id = 248707, quality = 2, level = 10, tier = "journeyman", bundles = {
		{ count = 8,  items = { 4371 } },  -- Bronze Tube
		{ count = 7,  items = { 4375 } },  -- Whirring Bronze Gizmo
		{ count = 4,  items = { 4382 } },  -- Bronze Framework
		{ count = 45, items = { 10558 } }, -- Gold Power Core
	} },

	-- Expert (Green: 30 Favor)
	{ id = 248708, quality = 2, level = 20, tier = "expert", bundles = {
		{ count = 8, items = { 4339 } }, -- Bolt of Mageweave
		{ count = 2, items = { 4236 } }, -- Cured Heavy Hide
	} },
	{ id = 248709, quality = 2, level = 20, tier = "expert", bundles = {
		{ count = 20, items = { 3860 } }, -- Mithril Bar
		{ count = 15, items = { 3859 } }, -- Steel Bar
		{ count = 10, items = { 3577 } }, -- Gold Bar
	} },
	{ id = 248710, quality = 2, level = 20, tier = "expert", bundles = {
		{ count = 8,  items = { 4387 } },  -- Iron Strut
		{ count = 5,  items = { 10559 } }, -- Mithril Tube
		{ count = 12, items = { 10560 } }, -- Unstable Trigger
		{ count = 5,  items = { 10561 } }, -- Mithril Casing
	} },

	-- Artisan (Green: 40 Favor)
	{ id = 248711, quality = 2, level = 35, tier = "artisan", bundles = {
		{ count = 8, items = { 14048 } }, -- Bolt of Runecloth
		{ count = 2, items = { 8172 } },  -- Cured Thick Hide
	} },
	{ id = 248712, quality = 2, level = 35, tier = "artisan", bundles = {
		{ count = 2,  items = { 11371 } }, -- Dark Iron Bar
		{ count = 10, items = { 6037 } },  -- Truesilver Bar
		{ count = 20, items = { 12359 } }, -- Thorium Bar
	} },
	{ id = 248713, quality = 2, level = 35, tier = "artisan", bundles = {
		{ count = 5, items = { 15994 } }, -- Thorium Widget
		{ count = 5, items = { 18631 } }, -- Truesilver Transformer
		{ count = 2, items = { 16000 } }, -- Thorium Tube
	} },
}
