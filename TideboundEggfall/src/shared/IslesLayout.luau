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
L.SAFE_RADIUS = 210 -- the whole town is a safe zone (no threats, no heat, hatching allowed)

local function v(x, z)
	return Vector3.new(x, 0, z)
end
L.v = v

-- Eggfall Town -----------------------------------------------------------------------------------------------

L.Town = {
	center = v(0, 0),
	plazaRadius = 50, -- WorldBuilder's REF 1 plaza: the builders leave everything inside this alone
	radius = 205, -- the town island's coast stays inside this
	districts = {
		Docks = { center = v(130, 0), size = v(150, 140), text = "Harbor Street: fish market, warehouses, piers, the Tidegate" },
		Market = { center = v(0, 125), size = v(170, 110), text = "Market Row: neon REF 3 shops, food stalls, an arcade, string lights" },
		ToriiHill = { center = v(-135, 15), radius = 65, topY = 44, top = v(-150, 15), text = "REF 5 torii stairs up to a shrine overlook" },
		Farms = { center = v(-110, -120), radius = 60, text = "Hatchery Farms: crop fields, a windmill, egg barns, chickens" },
		Beach = { center = v(40, -150), size = v(150, 80), text = "South Beach: sand, umbrellas, the ferry pier toward the Harbor Ring" },
		Lighthouse = { center = v(145, 140), radius = 32, text = "Lighthouse Point: cliffs and a striped lighthouse" },
	},
	-- The Tidegate: the big arch at the east end of Harbor Street where the causeway to the Shoals begins.
	tidegate = v(200, 0),
	-- Street graph the villagers walk (TideboundLife). TownBuilder lays a street or path along every edge.
	nodes = {
		P1 = v(30, 0), P2 = v(0, 30), P3 = v(-30, 0), P4 = v(0, -30), -- around the fountain
		D1 = v(62, 0), D2 = v(100, 0), D3 = v(140, 0), D4 = v(180, 0), -- Harbor Street
		PN1 = v(120, 34), PN2 = v(120, 92), -- north pier
		PS1 = v(110, -34), PS2 = v(110, -92), -- south pier
		M1 = v(0, 62), M2 = v(0, 100), M3 = v(-40, 120), M4 = v(40, 120), M5 = v(0, 150), M6 = v(60, 165), M7 = v(-60, 165),
		H1 = v(-62, 0), H2 = v(-84, 12), -- the foot of Torii Hill
		F1 = v(-50, -55), F2 = v(-85, -90), F3 = v(-125, -115), F4 = v(-100, -155),
		B1 = v(0, -70), B2 = v(20, -115), B3 = v(70, -150), B4 = v(-30, -150),
		L1 = v(95, 100), L2 = v(132, 128),
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
		{ at = v(116, 96), face = v(116, 130) }, { at = v(124, 80), face = v(160, 80) },
		{ at = v(106, -96), face = v(106, -130) }, { at = v(114, -70), face = v(150, -70) },
		{ at = v(-118, 52), face = v(-118, 80) }, -- Torii Hill's koi pond
	},
	vendors = {
		{ at = v(-30, 100), face = v(0, 100) }, { at = v(30, 100), face = v(0, 100) },
		{ at = v(-30, 145), face = v(0, 145) }, { at = v(30, 145), face = v(0, 145) },
		{ at = v(150, 22), face = v(150, 0) }, { at = v(90, -22), face = v(90, 0) },
	},
	chickens = { center = v(-110, -120), radius = 20 },
	villagers = 26, -- how many walk the street graph
}

-- The causeway from the Tidegate to Landing Reef, and where a dive drops you (Gate Warden Sel's DIVE).
L.causeway = { from = v(205, 0), to = v(282, 0), width = 14 }
L.diveSpawn = CFrame.lookAt(Vector3.new(290, L.TOP + 4, 0), Vector3.new(340, L.TOP + 4, 0))

-- The Sunken Shoals ------------------------------------------------------------------------------------------
-- ring: 1 Shallows (REF 2), 2 Coral Maze (the video), 3 Outer Reef (stormy). `feature` says what the island is
-- built around; ShoalsBuilder reads it.

L.islands = {
	-- Ring 1: the Shallows
	{ name = "LandingReef", pos = v(320, 0), r = 40, ring = 1, feature = "landing", title = "Landing Reef" },
	{ name = "LilyPond", pos = v(470, 190), r = 42, ring = 1, feature = "lavender", title = "Lily Pond" },
	{ name = "BambooReef", pos = v(480, -190), r = 38, ring = 1, feature = "bamboo", title = "Bamboo Reef" },
	{ name = "TwinReefNorth", pos = v(650, 60), r = 30, ring = 1, feature = "twin", title = "Twin Reefs" },
	{ name = "TwinReefSouth", pos = v(660, -70), r = 28, ring = 1, feature = "twin", title = "Twin Reefs" },
	{ name = "TurtleBay", pos = v(360, 420), r = 32, ring = 1, feature = "turtles", title = "Turtle Bay" },
	{ name = "MangroveIsle", pos = v(640, -380), r = 40, ring = 1, feature = "mangrove", title = "Mangrove Isle" },
	{ name = "KelpShallows", pos = v(360, -450), r = 30, ring = 1, feature = "kelpbeds", title = "Kelp Shallows" },
	-- Ring 2: the Coral Maze
	{ name = "ShipwreckBay", pos = v(860, 330), r = 48, ring = 2, feature = "shipwreck", title = "Shipwreck Bay" },
	{ name = "CoralArches", pos = v(900, -20), r = 46, ring = 2, feature = "arches", title = "Coral Arches" },
	{ name = "SeaStacks", pos = v(830, -430), r = 40, ring = 2, feature = "stacks", title = "Sea Stacks" },
	{ name = "SmugglersCove", pos = v(1090, 540), r = 38, ring = 2, feature = "cove", title = "Smugglers' Cove" },
	{ name = "PufferLagoon", pos = v(1110, -290), r = 42, ring = 2, feature = "lagoon", title = "Puffer Lagoon" },
	{ name = "GullRock", pos = v(1130, 140), r = 30, ring = 2, feature = "gulls", title = "Gull Rock" },
	{ name = "NorthAtoll", pos = v(690, 660), r = 32, ring = 2, feature = "atoll", title = "North Atoll" },
	{ name = "SouthAtoll", pos = v(780, -700), r = 32, ring = 2, feature = "atoll", title = "South Atoll" },
	-- Ring 3: the Outer Reef
	{ name = "ClamAtoll", pos = v(1330, 20), r = 34, ring = 3, feature = "clam", title = "Giant Clam Atoll" },
	{ name = "LighthouseIsle", pos = v(1380, 470), r = 34, ring = 3, feature = "lighthouse", title = "Lighthouse Isle" },
	{ name = "MaelstromIsle", pos = v(1410, -390), r = 32, ring = 3, feature = "maelstrom", title = "Maelstrom Isle" },
	{ name = "WardensRock", pos = v(1630, 0), r = 40, ring = 3, feature = "warden", title = "Warden's Rock" },
	{ name = "StormSpire", pos = v(1740, 490), r = 28, ring = 3, feature = "spire", title = "Storm Spire" },
	{ name = "BoneReef", pos = v(1700, -540), r = 36, ring = 3, feature = "bones", title = "Bone Reef" },
	{ name = "FarReach", pos = v(1830, 200), r = 26, ring = 3, feature = "far", title = "Far Reach" },
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

-- Geyser jump pads (TideboundTravel launches you): each pair works both ways. Pads sit on the island's land.
L.jumpPads = {
	{ v(343, 21), v(629, 58) }, -- Landing Reef <-> Twin Reefs
	{ v(379, 433), v(670, 649) }, -- Turtle Bay <-> North Atoll
	{ v(379, -459), v(759, -690) }, -- Kelp Shallows <-> South Atoll
	{ v(1149, 131), v(1306, 28) }, -- Gull Rock <-> Giant Clam Atoll
	{ v(1354, 28), v(1600, 7) }, -- Giant Clam Atoll <-> Warden's Rock
	{ v(1404, 478), v(1721, 487) }, -- Lighthouse Isle <-> Storm Spire
	{ v(1430, -401), v(1675, -530) }, -- Maelstrom Isle <-> Bone Reef
	{ v(1656, 17), v(1815, 192) }, -- Warden's Rock <-> Far Reach
}

-- Gameplay objects -------------------------------------------------------------------------------------------
-- Fishing spots sit in the water just off the shore (the server reads the Cast prompt; Biome 1).
L.fishingSpots = {
	v(276, -38), -- Landing Reef
	v(430, 236), v(515, 228), v(500, 140), -- Lily Pond
	v(330, 460), v(400, 456), -- Turtle Bay
	v(322, -470), v(392, -420), -- Kelp Shallows
	v(690, 26), -- Twin Reefs
	v(818, 382), v(910, 380), -- Shipwreck Bay
	v(950, -66), -- Coral Arches
	v(1110, -290), v(1068, -250), v(1156, -330), -- Puffer Lagoon (the lagoon in its middle, and its shore)
	v(654, 700), v(730, 650), -- North Atoll
	v(740, -730), -- South Atoll
	v(1300, 60), v(1370, -12), -- Giant Clam Atoll
	v(1360, 515), v(1420, 440), -- Lighthouse Isle
	v(1376, -430), v(1450, -360), -- Maelstrom Isle
	v(1808, 236), v(1866, 176), -- Far Reach
}

-- Wild egg nests (Steal). `y` is the walk height under the nest when it isn't TOP.
L.eggNests = {
	{ at = v(492, -200) }, -- Bamboo Reef, in the grove
	{ at = v(456, 196) }, -- Lily Pond, under the lavender tree
	{ at = v(655, 72) }, -- Twin Reef North
	{ at = v(666, -80) }, -- Twin Reef South
	{ at = v(650, -392) }, -- Mangrove Isle, among the roots
	{ at = v(862, 336), y = L.TOP + 1 }, -- Shipwreck Bay, in the galleon's smashed hull
	{ at = v(836, -436), y = 32 }, -- Sea Stacks, on top of the tallest stack
	{ at = v(1098, 552) }, -- Smugglers' Cove, in the cave
	{ at = v(1136, 150) }, -- Gull Rock
	{ at = v(790, -710) }, -- South Atoll
	{ at = v(1400, -382) }, -- Maelstrom Isle
	{ at = v(1622, 14) }, -- Warden's Rock
	{ at = v(1644, -18) }, -- Warden's Rock
	{ at = v(1746, 500) }, -- Storm Spire
	{ at = v(1708, -548) }, -- Bone Reef, inside the ribcage
}

-- Extraction beacons (Depth 1). PUSH DEEPER at any of them dives you down the Maelstrom to Kelp Cathedral.
L.beacons = {
	v(672, -58), -- Twin Reef South
	v(884, 304), -- Shipwreck Bay
	v(1132, -270), -- Puffer Lagoon
	v(1362, 452), -- Lighthouse Isle
	v(1398, -370), -- Maelstrom Isle
	v(1754, 477), -- Storm Spire
	v(1721, -523), -- Bone Reef
}

-- Tide Caches: bank your fish (safe Pearls), and stand by one to heal (Config.Isles.cacheHeal).
L.tideCaches = {
	v(302, 22), -- Landing Reef
	v(918, -2), -- Coral Arches
	v(1318, 38), -- Giant Clam Atoll
}

-- Stinging Anemone Beds (Master Patch 3 Table C): 8 x 8 pads on paths and shores.
L.anemoneBeds = {
	v(470, -170), v(452, 170), v(640, 44), v(620, -360), v(884, -58), v(920, 10),
	v(810, -410), v(1090, -270), v(1126, 160), v(1340, 0), v(1612, -20), v(1690, -560),
	v(1100, 520), v(1380, 450),
}

-- Elite dens (Barnacle Brute or Snapjaw Moray, Master Patch 3 Table B). Radius is the Brute's roam.
L.eliteDens = {
	{ at = v(880, -40), radius = 20 }, -- Coral Arches
	{ at = v(1128, 128), radius = 14 }, -- Gull Rock
	{ at = v(1336, 14), radius = 16 }, -- Giant Clam Atoll
	{ at = v(628, -368), radius = 18 }, -- Mangrove Isle
	{ at = v(1690, -530), radius = 16 }, -- Bone Reef
}

-- The Reef Warden's patrol (it hovers over water too), and its lair.
L.wardenLair = v(1630, 0)
L.wardenPath = { v(1630, 0), v(1330, 20), v(1130, 140), v(900, -20), v(1110, -290), v(1410, -390), v(1700, -540), v(1630, 0) }

-- The Maelstrom whirlpool (PUSH DEEPER's cutscene looks at it; the Kelp's current brings you back beside it).
L.maelstrom = v(1485, -400)
L.ascend = CFrame.lookAt(Vector3.new(1430, L.TOP + 4, -396), Vector3.new(1485, L.TOP + 4, -400))

-- Mob camps (Mobs.luau). kinds: crab, puffer, gull, golem. Sharks patrol the water areas in L.sharkWaters.
L.camps = {
	{ at = v(470, -205), radius = 22, mobs = { crab = 3 } }, -- Bamboo Reef
	{ at = v(650, 60), radius = 26, mobs = { puffer = 2 } }, -- Twin Reef North
	{ at = v(640, -380), radius = 28, mobs = { crab = 3, puffer = 2 } }, -- Mangrove Isle
	{ at = v(360, 420), radius = 24, mobs = { puffer = 2 } }, -- Turtle Bay
	{ at = v(360, -450), radius = 22, mobs = { crab = 2 } }, -- Kelp Shallows
	{ at = v(860, 330), radius = 36, mobs = { gull = 3, crab = 2 } }, -- Shipwreck Bay
	{ at = v(900, -20), radius = 34, mobs = { crab = 4 } }, -- Coral Arches
	{ at = v(830, -430), radius = 30, mobs = { gull = 3 } }, -- Sea Stacks
	{ at = v(1090, 540), radius = 28, mobs = { golem = 1, crab = 3 } }, -- Smugglers' Cove
	{ at = v(1110, -290), radius = 32, mobs = { puffer = 5 } }, -- Puffer Lagoon
	{ at = v(1130, 140), radius = 24, mobs = { gull = 4 } }, -- Gull Rock
	{ at = v(690, 660), radius = 24, mobs = { puffer = 2, crab = 2 } }, -- North Atoll
	{ at = v(780, -700), radius = 24, mobs = { crab = 3 } }, -- South Atoll
	{ at = v(1330, 20), radius = 26, mobs = { golem = 1 } }, -- Giant Clam Atoll
	{ at = v(1380, 470), radius = 26, mobs = { gull = 3, crab = 2 } }, -- Lighthouse Isle
	{ at = v(1410, -390), radius = 24, mobs = { crab = 3, puffer = 2 } }, -- Maelstrom Isle
	{ at = v(1630, 0), radius = 30, mobs = { crab = 2 } }, -- Warden's Rock (the Warden lives here too)
	{ at = v(1740, 490), radius = 22, mobs = { gull = 4, golem = 1 } }, -- Storm Spire
	{ at = v(1700, -540), radius = 28, mobs = { golem = 1, crab = 4 } }, -- Bone Reef
	{ at = v(1830, 200), radius = 20, mobs = { puffer = 3 } }, -- Far Reach
}

-- Open water a Reef Shark patrols. It only bites players who are swimming.
L.sharkWaters = {
	{ at = v(760, 170), radius = 110 },
	{ at = v(1000, -120), radius = 140 },
	{ at = v(1240, 260), radius = 150 },
	{ at = v(1540, -250), radius = 150 },
	{ at = v(1560, 260), radius = 140 },
	{ at = v(560, 330), radius = 110 },
}

-- Kelp Cathedral camps (biome 2, under the sea): the same kinds in the cathedral's colours.
L.kelpCamps = {
	{ at = Vector3.new(120, 0, 900), radius = 30, mobs = { crab = 3 } },
	{ at = Vector3.new(120, 0, 1080), radius = 30, mobs = { crab = 3 } },
	{ at = Vector3.new(-120, 0, 960), radius = 34, mobs = { puffer = 3 } },
	{ at = Vector3.new(-120, 0, 1100), radius = 30, mobs = { puffer = 2 } },
	{ at = Vector3.new(0, 0, 1040), radius = 40, mobs = { golem = 1 } },
}

-- The sea: terrain water and a sand floor over this rectangle, and a current that turns you back at its edge.
L.sea = { min = v(-700, -1150), max = v(2250, 1150), floorY = -14 }
L.playMin = v(-260, -880) -- beyond these you get pushed back (TideboundTravel)
L.playMax = v(1960, 860)

-- Zones: anything east of this line (and outside the town) is the Shoals.
L.shoalsX = 208

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
