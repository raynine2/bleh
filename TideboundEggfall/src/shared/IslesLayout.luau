-- Tidebound: Eggfall: the Open Isles map plan (Patch 10). One table that the builders (TownBuilder,
-- ShoalsBuilder), the server systems (Mobs, Main) and the client scripts (TideboundLife, TideboundTravel,
-- TideboundCutscenes) all read, so the town streets the villagers walk, the islands the mobs roam and the pads
-- you launch from always line up. Positions are flat (x, z); the walk height on land is TOP and the sea's
-- surface is WATER_Y, unless an entry gives its own y.
--
-- The surface world is about ten times the old Nest and Shoals:
--   Eggfall Town (spawn, safe): the REF 1 fountain plaza at its heart, then Harbor Street and the docks east,
--     Market Row north, Torii Hill west, Hatchery Farms south-west, South Beach south, Lighthouse Point
--     north-east. Everything inside SAFE_RADIUS of the plaza is safe.
--   The Sunken Shoals: 22 islands in three rings east of town. The Shallows (REF 2 boardwalks and bamboo),
--     the Coral Maze (the reference video's studded paths, checkered grass and voxel trees), and the Outer
--     Reef (stormy rope bridges, the Warden's Rock, the Maelstrom down to Kelp Cathedral).

local L = {}

L.TOP = 6 -- walk height on land
L.WATER_Y = 4 -- the sea's surface (terrain water)
L.SAFE_RADIUS = 420 -- the whole town is a safe zone (doubled for larger scale)

local function v(x, z)
	return Vector3.new(x, 0, z)
end
L.v = v

-- Eggfall Town -----------------------------------------------------------------------------------------------

L.Town = {
	center = v(0, 0),
	plazaRadius = 100, -- WorldBuilder's REF 1 plaza: doubled for scale
	radius = 410, -- the town island's coast stays inside this (doubled)
	districts = {
		Docks = { center = v(260, 0), size = v(300, 280), text = "Harbor Street: fish market, warehouses, piers, the Tidegate" },
		Market = { center = v(0, 250), size = v(340, 220), text = "Market Row: neon REF 3 shops, food stalls, an arcade, string lights" },
		ToriiHill = { center = v(-270, 30), radius = 130, topY = 88, top = v(-300, 30), text = "REF 5 torii stairs up to a shrine overlook" },
		Farms = { center = v(-220, -240), radius = 120, text = "Hatchery Farms: crop fields, a windmill, egg barns, chickens" },
		Beach = { center = v(80, -300), size = v(300, 160), text = "South Beach: sand, umbrellas, the ferry pier toward the Harbor Ring" },
		Lighthouse = { center = v(290, 280), radius = 64, text = "Lighthouse Point: cliffs and a striped lighthouse" },
	},
	-- The Tidegate: the big arch at the east end of Harbor Street where the causeway to the Shoals begins.
	tidegate = v(400, 0),
	-- Street graph the villagers walk (TideboundLife). TownBuilder lays a street or path along every edge.
	nodes = {
		P1 = v(60, 0), P2 = v(0, 60), P3 = v(-60, 0), P4 = v(0, -60), -- around the fountain (doubled)
		D1 = v(124, 0), D2 = v(200, 0), D3 = v(280, 0), D4 = v(360, 0), -- Harbor Street (doubled)
		PN1 = v(240, 68), PN2 = v(240, 184), -- north pier (doubled)
		PS1 = v(220, -68), PS2 = v(220, -184), -- south pier (doubled)
		M1 = v(0, 124), M2 = v(0, 200), M3 = v(-80, 240), M4 = v(80, 240), M5 = v(0, 300), M6 = v(120, 330), M7 = v(-120, 330),
		H1 = v(-124, 0), H2 = v(-168, 24), -- the foot of Torii Hill (doubled)
		F1 = v(-100, -110), F2 = v(-170, -180), F3 = v(-250, -230), F4 = v(-200, -310),
		B1 = v(0, -140), B2 = v(40, -230), B3 = v(140, -300), B4 = v(-60, -300),
		L1 = v(190, 200), L2 = v(264, 256),
	},
	edges = {
		{ "P1", "P2" }, { "P2", "P3" }, { "P3", "P4" }, { "P4", "P1" },
		{ "P1", "D1" }, { "D1", "D2" }, { "D2", "D3" }, { "D3", "D4" },
		{ "D2", "PN1" }, { "PN1", "PN2" }, { "D2", "PS1" }, { "PS1", "PS2" },
		{ "P2", "M1" }, { "M1", "M2" }, { "M2", "M3" }, { "M2", "M4" }, { "M3", "M5" }, { "M4", "M5" }, { "M3", "M7" }, { "M4", "M6" },
		{ "M4", "L1" }, { "L1", "L2" }, { "D3", "L1" },
		{ "P3", "H1" }, { "H1", "H2" },
		{ "P4", "B1" }, { "B1", "B2" }, { "B2", "B3" }, { "B2", "B4" },
		{ "B1", "F1" }, { "F1", "F2" }, { "F2", "F3" }, { "F3", "F4" }, { "F4", "B4" },
	},
	-- Where villager NPCs stand and fish, sit or work (TideboundLife). `face` is the point they look at.
	fishers = {
		{ at = v(232, 192), face = v(232, 260) }, { at = v(248, 160), face = v(320, 160) },
		{ at = v(212, -192), face = v(212, -260) }, { at = v(228, -140), face = v(300, -140) },
		{ at = v(-236, 104), face = v(-236, 160) }, -- Torii Hill's koi pond
	},
	vendors = {
		{ at = v(-60, 200), face = v(0, 200) }, { at = v(60, 200), face = v(0, 200) },
		{ at = v(-60, 290), face = v(0, 290) }, { at = v(60, 290), face = v(0, 290) },
		{ at = v(300, 44), face = v(300, 0) }, { at = v(180, -44), face = v(180, 0) },
	},
	chickens = { center = v(-220, -240), radius = 40 },
	-- the town island's coast: a union of grass shapes topped at TOP, plus the beach (TownBuilder, the sea chart)
	land = {
		{ kind = "disk", c = v(-50, 0), r = 280 }, -- the core around the plaza (doubled)
		{ kind = "box", c = v(248, 0), size = v(336, 120) }, -- Harbor Street out to the Tidegate (doubled)
		{ kind = "disk", c = v(0, 260), r = 150 }, -- Market Row (doubled)
		{ kind = "disk", c = v(240, 240), r = 80 }, -- Lighthouse Point (doubled)
		{ kind = "disk", c = v(-270, 30), r = 132 }, -- Torii Hill (doubled)
		{ kind = "disk", c = v(-200, -220), r = 110 }, -- Hatchery Farms (doubled)
		{ kind = "disk", c = v(156, 212), r = 32 }, -- the neck between Market Row and Lighthouse Point (doubled)
		{ kind = "disk", c = v(-124, -300), r = 44 }, -- the meadow between the farms and the beach (doubled)
	},
	beach = { c = v(60, -280), r = 130 },
	villagers = 26, -- how many walk the street graph
}

-- The causeway from the Tidegate to Landing Reef, and where a dive drops you (Gate Warden Sel's DIVE).
L.causeway = { from = v(410, 0), to = v(564, 0), width = 28 }
L.diveSpawn = CFrame.lookAt(Vector3.new(580, L.TOP + 4, 0), Vector3.new(680, L.TOP + 4, 0))

-- The Sunken Shoals ------------------------------------------------------------------------------------------
-- ring: 1 Shallows (REF 2), 2 Coral Maze (the video), 3 Outer Reef (stormy). `feature` says what the island is
-- built around; ShoalsBuilder reads it.

L.islands = {
	-- Ring 1: the Shallows (all scaled 2x with radius increased 1.8x for better exploration)
	{ name = "LandingReef", pos = v(640, 0), r = 72, ring = 1, feature = "landing", title = "Landing Reef" },
	{ name = "LilyPond", pos = v(940, 380), r = 76, ring = 1, feature = "lavender", title = "Lily Pond" },
	{ name = "BambooReef", pos = v(960, -380), r = 68, ring = 1, feature = "bamboo", title = "Bamboo Reef" },
	{ name = "TwinReefNorth", pos = v(1300, 120), r = 54, ring = 1, feature = "twin", title = "Twin Reefs" },
	{ name = "TwinReefSouth", pos = v(1320, -140), r = 50, ring = 1, feature = "twin", title = "Twin Reefs" },
	{ name = "TurtleBay", pos = v(720, 840), r = 58, ring = 1, feature = "turtles", title = "Turtle Bay" },
	{ name = "MangroveIsle", pos = v(1280, -760), r = 72, ring = 1, feature = "mangrove", title = "Mangrove Isle" },
	{ name = "KelpShallows", pos = v(720, -900), r = 54, ring = 1, feature = "kelpbeds", title = "Kelp Shallows" },
	-- Ring 2: the Coral Maze (all scaled 2x with radius increased 1.8x)
	{ name = "ShipwreckBay", pos = v(1720, 660), r = 86, ring = 2, feature = "shipwreck", title = "Shipwreck Bay" },
	{ name = "CoralArches", pos = v(1800, -40), r = 83, ring = 2, feature = "arches", title = "Coral Arches" },
	{ name = "SeaStacks", pos = v(1660, -860), r = 72, ring = 2, feature = "stacks", title = "Sea Stacks" },
	{ name = "SmugglersCove", pos = v(2180, 1080), r = 68, ring = 2, feature = "cove", title = "Smugglers' Cove" },
	{ name = "PufferLagoon", pos = v(2220, -580), r = 76, ring = 2, feature = "lagoon", title = "Puffer Lagoon" },
	{ name = "GullRock", pos = v(2260, 280), r = 54, ring = 2, feature = "gulls", title = "Gull Rock" },
	{ name = "NorthAtoll", pos = v(1380, 1320), r = 58, ring = 2, feature = "atoll", title = "North Atoll" },
	{ name = "SouthAtoll", pos = v(1560, -1400), r = 58, ring = 2, feature = "atoll", title = "South Atoll" },
	-- Ring 3: the Outer Reef (all scaled 2x with radius increased 1.8x)
	{ name = "ClamAtoll", pos = v(2660, 40), r = 61, ring = 3, feature = "clam", title = "Giant Clam Atoll" },
	{ name = "LighthouseIsle", pos = v(2760, 940), r = 61, ring = 3, feature = "lighthouse", title = "Lighthouse Isle" },
	{ name = "MaelstromIsle", pos = v(2820, -780), r = 58, ring = 3, feature = "maelstrom", title = "Maelstrom Isle" },
	{ name = "WardensRock", pos = v(3260, 0), r = 72, ring = 3, feature = "warden", title = "Warden's Rock" },
	{ name = "StormSpire", pos = v(3480, 980), r = 50, ring = 3, feature = "spire", title = "Storm Spire" },
	{ name = "BoneReef", pos = v(3400, -1080), r = 65, ring = 3, feature = "bones", title = "Bone Reef" },
	{ name = "FarReach", pos = v(3660, 400), r = 47, ring = 3, feature = "far", title = "Far Reach" },
}

L.byName = {}
for _, island in ipairs(L.islands) do
	L.byName[island.name] = island
end

-- Bridges between islands. kind: "boardwalk" (REF 2 dark deck, posts and sagging rope), "plank" (the
-- video's plank bridge on stilts), "rope" (a rickety rope bridge, Outer Reef). `bend` curves it (studs).
L.links = {
	{ "LandingReef", "LilyPond", "boardwalk", 14 },
	{ "LandingReef", "BambooReef", "boardwalk", -14 },
	{ "LilyPond", "TwinReefNorth", "boardwalk", -10 },
	{ "BambooReef", "TwinReefSouth", "boardwalk", 10 },
	{ "TwinReefNorth", "TwinReefSouth", "boardwalk", 0 },
	{ "LilyPond", "TurtleBay", "boardwalk", 12 },
	{ "BambooReef", "KelpShallows", "boardwalk", -12 },
	{ "BambooReef", "MangroveIsle", "boardwalk", 10 },
	{ "TwinReefNorth", "ShipwreckBay", "plank", 16 },
	{ "TwinReefSouth", "CoralArches", "plank", -12 },
	{ "MangroveIsle", "SeaStacks", "plank", 10 },
	{ "NorthAtoll", "ShipwreckBay", "plank", -14 },
	{ "SouthAtoll", "SeaStacks", "plank", 12 },
	{ "ShipwreckBay", "CoralArches", "plank", 18 },
	{ "CoralArches", "GullRock", "plank", -12 },
	{ "CoralArches", "PufferLagoon", "plank", 14 },
	{ "SeaStacks", "PufferLagoon", "plank", -16 },
	{ "ShipwreckBay", "SmugglersCove", "plank", 12 },
	{ "GullRock", "ClamAtoll", "rope", 10 },
	{ "PufferLagoon", "MaelstromIsle", "rope", -14 },
	{ "SmugglersCove", "LighthouseIsle", "rope", 12 },
	{ "ClamAtoll", "WardensRock", "rope", -10 },
	{ "MaelstromIsle", "BoneReef", "rope", 14 },
	{ "WardensRock", "FarReach", "rope", -8 },
}

-- Geyser jump pads (TideboundTravel launches you): each pair works both ways. Pads sit on the island's land. (all scaled 2x)
L.jumpPads = {
	{ v(686, 42), v(1258, 116) }, -- Landing Reef <-> Twin Reefs
	{ v(758, 866), v(1340, 1298) }, -- Turtle Bay <-> North Atoll
	{ v(758, -918), v(1518, -1380) }, -- Kelp Shallows <-> South Atoll
	{ v(2298, 262), v(2612, 56) }, -- Gull Rock <-> Giant Clam Atoll
	{ v(2708, 56), v(3200, 14) }, -- Giant Clam Atoll <-> Warden's Rock
	{ v(2808, 956), v(3442, 974) }, -- Lighthouse Isle <-> Storm Spire
	{ v(2860, -802), v(3350, -1060) }, -- Maelstrom Isle <-> Bone Reef
	{ v(3312, 34), v(3630, 384) }, -- Warden's Rock <-> Far Reach
}

-- Gameplay objects -------------------------------------------------------------------------------------------
-- Fishing spots sit in the water just off the shore (the server reads the Cast prompt; Biome 1). (all scaled 2x)
L.fishingSpots = {
	v(552, -76), -- Landing Reef
	v(860, 472), v(1030, 456), v(1000, 280), -- Lily Pond
	v(660, 920), v(800, 912), -- Turtle Bay
	v(644, -940), v(784, -840), -- Kelp Shallows
	v(1380, 52), -- Twin Reefs
	v(1636, 764), v(1820, 760), -- Shipwreck Bay
	v(1900, -132), -- Coral Arches
	v(2220, -580), v(2136, -500), v(2312, -660), -- Puffer Lagoon (the lagoon in its middle, and its shore)
	v(1308, 1400), v(1460, 1300), -- North Atoll
	v(1480, -1460), -- South Atoll
	v(2600, 120), v(2740, -24), -- Giant Clam Atoll
	v(2720, 1030), v(2840, 880), -- Lighthouse Isle
	v(2752, -860), v(2900, -720), -- Maelstrom Isle
	v(3616, 472), v(3732, 352), -- Far Reach
	-- Fishing Fight (12 Oct 2026): 67 more spots, two or three on every island's shore, each with its own jetty
	v(724, -24), v(631, 85), v(856, 350), v(1029, 380), v(931, 469), v(888, -418),
	v(996, -307), v(963, -461), v(1266, 179), v(1358, 156), v(1236, 97), v(1313, -204),
	v(1374, -106), v(1265, -111), v(723, 768), v(733, 911), v(791, 850), v(1364, -736),
	v(1197, -778), v(1328, -690), v(695, -837), v(695, -963), v(1710, 561), v(1816, 632),
	v(1620, 639), v(1731, 27), v(1866, 33), v(1731, -107), v(1730, -904), v(1663, -775),
	v(1617, -935), v(2194, 1160), v(2150, 1005), v(2108, 1118), v(2260, -498), v(2198, -668),
	v(2133, -599), v(2205, 320), v(2306, 229), v(2306, 331), v(1362, 1248), v(1420, 1380),
	v(1308, 1305), v(1623, -1361), v(1516, -1343), v(1600, -1460), v(2599, -4), v(2722, 79),
	v(2673, -36), v(2688, 925), v(2809, 995), v(2752, 865), v(2868, -834), v(2812, -708),
	v(2748, -785), v(3275, -84), v(3263, 85), v(3345, 0), v(3456, 1039), v(3538, 954),
	v(3521, 1026), v(3453, -1139), v(3392, -1001), v(3330, -1117), v(3605, 380), v(3687, 454),
	v(3720, 392),
}

-- Wild egg nests (Steal). `y` is the walk height under the nest when it isn't TOP. (all scaled 2x)
L.eggNests = {
	{ at = v(984, -400) }, -- Bamboo Reef, in the grove
	{ at = v(912, 392) }, -- Lily Pond, under the lavender tree
	{ at = v(1310, 144) }, -- Twin Reef North
	{ at = v(1332, -160) }, -- Twin Reef South
	{ at = v(1300, -784) }, -- Mangrove Isle, among the roots
	{ at = v(1724, 672), y = L.TOP + 1 }, -- Shipwreck Bay, in the galleon's smashed hull
	{ at = v(1672, -872), y = 64 }, -- Sea Stacks, on top of the tallest stack (taller now)
	{ at = v(2196, 1104) }, -- Smugglers' Cove, in the cave
	{ at = v(2272, 300) }, -- Gull Rock
	{ at = v(1580, -1420) }, -- South Atoll
	{ at = v(2800, -764) }, -- Maelstrom Isle
	{ at = v(3244, 28) }, -- Warden's Rock
	{ at = v(3288, -36) }, -- Warden's Rock
	{ at = v(3492, 1000) }, -- Storm Spire
	{ at = v(3416, -1096) }, -- Bone Reef, inside the ribcage
}

-- Extraction beacons (Depth 1). PUSH DEEPER at any of them dives you down the Maelstrom to Kelp Cathedral. (all scaled 2x)
L.beacons = {
	v(1344, -116), -- Twin Reef South
	v(1768, 608), -- Shipwreck Bay
	v(2264, -540), -- Puffer Lagoon
	v(2724, 904), -- Lighthouse Isle
	v(2796, -740), -- Maelstrom Isle
	v(3508, 954), -- Storm Spire
	v(3442, -1046), -- Bone Reef
}

-- Tide Caches: bank your fish (safe Pearls), and stand by one to heal (Config.Isles.cacheHeal). (all scaled 2x)
L.tideCaches = {
	v(604, 44), -- Landing Reef
	v(1836, -4), -- Coral Arches
	v(2636, 76), -- Giant Clam Atoll
}

-- Stinging Anemone Beds (Master Patch 3 Table C): 8 x 8 pads on paths and shores. (all scaled 2x)
L.anemoneBeds = {
	v(940, -340), v(904, 340), v(1280, 88), v(1240, -720), v(1768, -116), v(1840, 20),
	v(1620, -820), v(2180, -540), v(2252, 320), v(2680, 0), v(3224, -40), v(3380, -1120),
	v(2200, 1040), v(2760, 900),
}

-- Elite dens (Barnacle Brute or Snapjaw Moray, Master Patch 3 Table B). Radius is the Brute's roam. (all scaled 2x)
L.eliteDens = {
	{ at = v(1760, -80), radius = 40 }, -- Coral Arches
	{ at = v(2256, 256), radius = 28 }, -- Gull Rock
	{ at = v(2672, 28), radius = 32 }, -- Giant Clam Atoll
	{ at = v(1256, -736), radius = 36 }, -- Mangrove Isle
	{ at = v(3380, -1060), radius = 32 }, -- Bone Reef
}

-- The Reef Warden's patrol (it hovers over water too), and its lair. (all scaled 2x)
L.wardenLair = v(3260, 0)
L.wardenPath = { v(3260, 0), v(2660, 40), v(2260, 280), v(1800, -40), v(2220, -580), v(2820, -780), v(3400, -1080), v(3260, 0) }

-- The Maelstrom whirlpool (PUSH DEEPER's cutscene looks at it; the Kelp's current brings you back beside it). (scaled 2x)
L.maelstrom = v(2970, -800)
L.ascend = CFrame.lookAt(Vector3.new(2860, L.TOP + 4, -792), Vector3.new(2970, L.TOP + 4, -800))

-- Mob camps (Mobs.luau). kinds: crab, puffer, gull, golem. Sharks patrol the water areas in L.sharkWaters. (all scaled 2x)
L.camps = {
	{ at = v(940, -410), radius = 44, mobs = { crab = 3 } }, -- Bamboo Reef
	{ at = v(1300, 120), radius = 52, mobs = { puffer = 2 } }, -- Twin Reef North
	{ at = v(1280, -760), radius = 56, mobs = { crab = 3, puffer = 2 } }, -- Mangrove Isle
	{ at = v(720, 840), radius = 48, mobs = { puffer = 2 } }, -- Turtle Bay
	{ at = v(720, -900), radius = 44, mobs = { crab = 2 } }, -- Kelp Shallows
	{ at = v(1720, 660), radius = 72, mobs = { gull = 3, crab = 2 } }, -- Shipwreck Bay
	{ at = v(1800, -40), radius = 68, mobs = { crab = 4 } }, -- Coral Arches
	{ at = v(1660, -860), radius = 60, mobs = { gull = 3 } }, -- Sea Stacks
	{ at = v(2180, 1080), radius = 56, mobs = { golem = 1, crab = 3 } }, -- Smugglers' Cove
	{ at = v(2220, -580), radius = 64, mobs = { puffer = 5 } }, -- Puffer Lagoon
	{ at = v(2260, 280), radius = 48, mobs = { gull = 4 } }, -- Gull Rock
	{ at = v(1380, 1320), radius = 48, mobs = { puffer = 2, crab = 2 } }, -- North Atoll
	{ at = v(1560, -1400), radius = 48, mobs = { crab = 3 } }, -- South Atoll
	{ at = v(2660, 40), radius = 52, mobs = { golem = 1 } }, -- Giant Clam Atoll
	{ at = v(2760, 940), radius = 52, mobs = { gull = 3, crab = 2 } }, -- Lighthouse Isle
	{ at = v(2820, -780), radius = 48, mobs = { crab = 3, puffer = 2 } }, -- Maelstrom Isle
	{ at = v(3260, 0), radius = 60, mobs = { crab = 2 } }, -- Warden's Rock (the Warden lives here too)
	{ at = v(3480, 980), radius = 44, mobs = { gull = 4, golem = 1 } }, -- Storm Spire
	{ at = v(3400, -1080), radius = 56, mobs = { golem = 1, crab = 4 } }, -- Bone Reef
	{ at = v(3660, 400), radius = 40, mobs = { puffer = 3 } }, -- Far Reach
}

-- Open water a Reef Shark patrols. It only bites players who are swimming. (all scaled 2x)
L.sharkWaters = {
	{ at = v(1520, 340), radius = 220 },
	{ at = v(2000, -240), radius = 280 },
	{ at = v(2480, 520), radius = 300 },
	{ at = v(3080, -500), radius = 300 },
	{ at = v(3120, 520), radius = 280 },
	{ at = v(1120, 660), radius = 220 },
}

-- Kelp Cathedral camps (biome 2, under the sea): the same kinds in the cathedral's colours.
L.kelpCamps = {
	{ at = Vector3.new(120, 0, 900), radius = 30, mobs = { crab = 3 } },
	{ at = Vector3.new(120, 0, 1080), radius = 30, mobs = { crab = 3 } },
	{ at = Vector3.new(-120, 0, 960), radius = 34, mobs = { puffer = 3 } },
	{ at = Vector3.new(-120, 0, 1100), radius = 30, mobs = { puffer = 2 } },
	{ at = Vector3.new(0, 0, 1040), radius = 40, mobs = { golem = 1 } },
}

-- The sea: terrain water and a sand floor over this rectangle, and a current that turns you back at its edge. (scaled 2x)
L.sea = { min = v(-1400, -2300), max = v(4500, 2300), floorY = -14 }
L.playMin = v(-520, -1760) -- beyond these you get pushed back (TideboundTravel)
L.playMax = v(3920, 1720)

-- Zones: anything east of this line (and outside the town) is the Shoals. (scaled 2x)
L.shoalsX = 416

-- EXPLORATION FEATURES: Secrets, hidden areas, viewpoints and exploration rewards -------------------------------

-- Hidden caves with treasure chests (rare bait, bonus pearls, or cosmetics)
L.hiddenCaves = {
	{ at = v(672, -892), radius = 18, reward = "treasure", pearls = 500, title = "Kelp Grotto" },
	{ at = v(1292, -148), radius = 22, reward = "bait", baitType = "Stormfin", count = 3, title = "Twin Reef Secret Cave" },
	{ at = v(1648, -876), radius = 20, reward = "treasure", pearls = 800, title = "Sea Stack Hollow" },
	{ at = v(2196, 1104), radius = 24, reward = "bait", baitType = "AbyssalSquid", count = 2, title = "Smuggler's Hidden Cache" },
	{ at = v(3372, -1084), radius = 26, reward = "treasure", pearls = 1200, title = "Bone Reef Ossuary" },
	{ at = v(3644, 388), radius = 16, reward = "bait", baitType = "AuroraKrill", count = 1, title = "Far Reach Secret" },
}

-- Scenic viewpoints ("Vista Points") that reward exploration with Pearls and Egg Shards on first visit
L.viewpoints = {
	{ at = v(-300, 30), y = 88, radius = 12, reward = { pearls = 200, shards = 2 }, title = "Torii Shrine Overlook", view = v(0, 0) },
	{ at = v(290, 280), y = 50, radius = 10, reward = { pearls = 150, shards = 1 }, title = "Lighthouse Summit", view = v(640, 0) },
	{ at = v(1672, -872), y = 64, radius = 10, reward = { pearls = 250, shards = 2 }, title = "Sea Stack Peak", view = v(1800, -40) },
	{ at = v(1724, 688), y = 24, radius = 14, reward = { pearls = 300, shards = 3 }, title = "Shipwreck Crow's Nest", view = v(2220, -580) },
	{ at = v(2672, 56), y = 32, radius = 12, reward = { pearls = 400, shards = 4 }, title = "Giant Clam Vista", view = v(3260, 0) },
	{ at = v(3260, 0), y = 48, radius = 14, reward = { pearls = 500, shards = 5 }, title = "Warden's Rock Summit", view = v(2970, -800) },
	{ at = v(3492, 1000), y = 72, radius = 12, reward = { pearls = 600, shards = 6 }, title = "Storm Spire Top", view = v(1800, 0) },
}

-- Secret fishing spots (better luck multiplier, hidden from map)
L.secretFishingSpots = {
	{ at = v(-236, 104), luck = 1.5, title = "Torii Koi Pond" }, -- Town secret spot
	{ at = v(912, 408), luck = 1.4, title = "Lavender Tree Pool" }, -- Lily Pond
	{ at = v(1320, -160), luck = 1.3, title = "Twin Reef Hidden Pool" },
	{ at = v(2220, -580), luck = 1.6, title = "Puffer Lagoon Center" }, -- in the middle of lagoon
	{ at = v(2970, -800), luck = 2.0, title = "Maelstrom Eye" }, -- at the whirlpool center - dangerous but rewarding!
}

-- Shortcut tunnels and passages (faster travel between distant points)
L.shortcuts = {
	{ from = v(960, -360), to = v(1280, -740), title = "Bamboo-Mangrove Tunnel", locked = false },
	{ from = v(1660, -840), to = v(1800, -60), title = "Sea Stack Passage", locked = true, unlockQuest = "defeat_golem_5" },
	{ from = v(2180, 1060), to = v(2760, 920), title = "Smuggler's Route", locked = true, unlockQuest = "find_all_ring2_secrets" },
	{ from = v(3240, -20), to = v(3660, 380), title = "Warden's Bypass", locked = true, unlockQuest = "defeat_warden_10" },
}

-- Rare mob spawn locations (mini-bosses with guaranteed rare drops)
L.rareMobs = {
	{ at = v(758, 866), kind = "GoldenTurtle", hp = 15, damage = 20, drop = { bait = "AuroraKrill", count = 2, pearls = 800 }, respawn = 1800, title = "Golden Turtle" },
	{ at = v(1724, 672), kind = "GhostCaptain", hp = 20, damage = 25, drop = { pearls = 1200, shards = 10 }, respawn = 2400, title = "Ghost Captain" },
	{ at = v(2970, -800), kind = "MaelstromGuardian", hp = 30, damage = 35, drop = { bait = "PrismaticRoe", count = 1, pearls = 2000 }, respawn = 3600, title = "Maelstrom Guardian" },
	{ at = v(3416, -1096), kind = "AncientLeviathan", hp = 40, damage = 40, drop = { pearls = 3000, shards = 20 }, respawn = 4800, title = "Ancient Leviathan Bones" },
}

-- Interactive environmental objects (pull levers, light braziers, solve puzzles for rewards)
L.puzzles = {
	{ at = v(-150, 15), type = "torii_gates", steps = 5, reward = { pearls = 300, shards = 3 }, title = "Torii Pilgrimage" },
	{ at = v(1724, 672), type = "shipwreck_journal", steps = 3, reward = { pearls = 500, shards = 5 }, title = "Captain's Lost Log" },
	{ at = v(2660, 40), type = "clam_pearls", steps = 4, reward = { pearls = 800, shards = 8 }, title = "Giant Clam Offering" },
	{ at = v(3260, 0), type = "warden_shrine", steps = 6, reward = { pearls = 1500, shards = 15 }, title = "Reef Warden's Trial" },
}

-- Collectible lore tablets (discover island history, unlock codex entries)
L.loreTables = {
	{ at = v(640, 12), text = "Landing Reef was the first foothold of the tide-watchers...", title = "Landing Reef Chronicle" },
	{ at = v(940, 368), text = "The lavender tree blooms only under moonlight, drawing rare fish...", title = "Lily Pond Legend" },
	{ at = v(1320, 120), text = "Twin Reefs were once one, split by an ancient quake...", title = "Twin Reefs Origin" },
	{ at = v(1724, 672), text = "The galleon sank with a fortune, but the captain refused to leave...", title = "Shipwreck Tale" },
	{ at = v(2220, -580), text = "Puffers gather here in numbers uncounted, drawn by the warm currents...", title = "Puffer Migration" },
	{ at = v(2660, 40), text = "The giant clam is older than Eggfall Town itself...", title = "Ancient Clam" },
	{ at = v(2970, -800), text = "The Maelstrom leads to the cathedral below, where the Leviathan sleeps...", title = "Maelstrom Mystery" },
	{ at = v(3260, 0), text = "The Warden was once mortal, transformed to guard the Shoals forever...", title = "Warden's Curse" },
	{ at = v(3492, 1000), text = "Storms gather at the spire, a beacon for the lost...", title = "Storm Spire Purpose" },
	{ at = v(3416, -1096), text = "These bones belong to the first Leviathan, defeated in the age of heroes...", title = "Bone Reef History" },
}

-- Vertical exploration: climbing spots and elevated platforms
L.climbingSpots = {
	{ at = v(-270, 30), climbTo = v(-300, 30), height = 82, title = "Torii Hill Ascent" },
	{ at = v(290, 280), climbTo = v(290, 280), height = 44, title = "Lighthouse Climb" },
	{ at = v(1660, -860), climbTo = v(1672, -872), height = 58, title = "Sea Stack Climb" },
	{ at = v(3480, 980), climbTo = v(3492, 1000), height = 66, title = "Storm Spire Ascent" },
}

-- CHEST SYSTEM: World-found chests (MASTER PATCH) ---------------------------------------------------------------

-- Surface chests (beached on islands, every ~500 studs)
L.surfaceChests = {
	{ at = v(640, 28), type = "SunkenChest", title = "Landing Reef Chest" },
	{ at = v(940, 340), type = "SunkenChest", title = "Lily Pond Chest" },
	{ at = v(960, -340), type = "SunkenChest", title = "Bamboo Reef Chest" },
	{ at = v(1310, 100), type = "CoralChest", title = "Twin Reefs Chest" },
	{ at = v(720, 820), type = "SunkenChest", title = "Turtle Bay Chest" },
	{ at = v(1280, -720), type = "CoralChest", title = "Mangrove Isle Chest" },
	{ at = v(1720, 640), type = "CoralChest", title = "Shipwreck Bay Chest" },
	{ at = v(1800, -60), type = "CoralChest", title = "Coral Arches Chest" },
	{ at = v(1660, -840), type = "CoralChest", title = "Sea Stacks Chest" },
	{ at = v(2180, 1060), type = "CoralChest", title = "Smugglers' Cove Chest" },
	{ at = v(2220, -560), type = "CoralChest", title = "Puffer Lagoon Chest" },
	{ at = v(2260, 260), type = "CoralChest", title = "Gull Rock Chest" },
	{ at = v(2660, 60), type = "AbyssalChest", title = "Giant Clam Chest" },
	{ at = v(2760, 920), type = "AbyssalChest", title = "Lighthouse Isle Chest" },
	{ at = v(2820, -760), type = "AbyssalChest", title = "Maelstrom Isle Chest" },
	{ at = v(3260, 20), type = "AbyssalChest", title = "Warden's Rock Chest" },
	{ at = v(3480, 960), type = "RiftChest", title = "Storm Spire Chest" },
	{ at = v(3400, -1060), type = "AbyssalChest", title = "Bone Reef Chest" },
	{ at = v(3660, 380), type = "RiftChest", title = "Far Reach Chest" },
}

-- Buried chests (requires shovel upgrade, 2-3 per biome, luck 1.2x)
L.buriedChests = {
	{ at = v(680, -40), type = "SunkenChest", luck = 1.2, title = "Landing Reef Buried" },
	{ at = v(1000, 360), type = "SunkenChest", luck = 1.2, title = "Lily Pond Buried" },
	{ at = v(1320, -720), type = "CoralChest", luck = 1.2, title = "Mangrove Buried" },
	{ at = v(1760, 680), type = "CoralChest", luck = 1.2, title = "Shipwreck Buried" },
	{ at = v(2700, 40), type = "AbyssalChest", luck = 1.2, title = "Clam Atoll Buried" },
	{ at = v(3220, -40), type = "AbyssalChest", luck = 1.2, title = "Warden's Rock Buried" },
}

-- Sunken chests (seafloor, deeper biomes only, luck 1.5x)
L.sunkenChests = {
	{ at = v(800, 200), y = -10, type = "SunkenChest", luck = 1.5, title = "Shallows Seafloor Chest" },
	{ at = v(1500, -400), y = -10, type = "CoralChest", luck = 1.5, title = "Maze Seafloor Chest" },
	{ at = v(2400, 600), y = -10, type = "CoralChest", luck = 1.5, title = "Reef Seafloor Chest" },
	{ at = v(2900, -200), y = -10, type = "AbyssalChest", luck = 1.5, title = "Outer Seafloor Chest" },
}

-- Guarded chests (behind guardian, luck 2.0x, 1 per biome)
L.guardedChests = {
	{ at = v(3260, 0), type = "BossChest", luck = 2.0, guardedBy = "ReefWarden", title = "Warden's Hoard" },
	{ at = v(2970, -800), type = "BossChest", luck = 2.0, guardedBy = "MaelstromGuardian", title = "Maelstrom Hoard" },
}

-- Lucky chest spawn zones (1 in 20 runs, golden glow, luck 5.0x)
L.luckyChestZones = {
	{ center = v(1500, 0), radius = 800, type = "LuckyChest", luck = 5.0 },
	{ center = v(2500, 400), radius = 600, type = "LuckyChest", luck = 5.0 },
	{ center = v(3200, -400), radius = 500, type = "LuckyChest", luck = 5.0 },
}

function L.island(position)
	local flat = v(position.X, position.Z)
	for _, island in ipairs(L.islands) do
		if (flat - island.pos).Magnitude <= island.r then
			return island
		end
	end
	return nil
end

return L
