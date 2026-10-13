-- Tidebound: Eggfall: the five canon biomes (GDD Sections 7, 8 and 9) and which one a position is in.
-- Every biome-driven system reads this one table: lighting and post-processing (TideboundBiomeLook), wind and
-- weather (WindService, TideboundWeather), ambience (TideboundAudio) and the VFX budget (VfxLibrary).
--
-- The built map came before the canon biome list, so the canon biomes are laid over it here:
--   Open Sea        Eggfall Town, ring 1 (the Shallows) and the open water between rings
--   Coral Reef      ring 2 (the Coral Maze) and Giant Clam Atoll
--   Kelp Forest     Kelp Cathedral (everything below Config.Kelp.belowY) and Kelp Shallows
--   Abyssal Trench  Maelstrom Isle and Bone Reef (the whirlpool and the bones)
--   Volcanic Isle   Warden's Rock, Storm Spire and Far Reach (the far, dangerous edge)
-- Retag an island by editing `islandBiome`. A part tagged "BiomeVolume" with a "Biome" attribute overrides
-- everything inside its box, so a new biome area can be dropped in without code.

local CollectionService = game:GetService("CollectionService")

local Isles = require(script.Parent:WaitForChild("IslesLayout"))

local Biomes = {}

Biomes.order = { "OpenSea", "CoralReef", "KelpForest", "AbyssalTrench", "VolcanicIsle" }
Biomes.default = "OpenSea"

-- Section 7 Table A: global lighting. Technology can't be set from a script (Roblox locks it), so set
-- Lighting.Technology = Future once in Studio's Properties window; everything else is applied in code.
-- Brightness pass (2026-10-11): the game read too bright, so the sun and sky fill are ~30% lower and every biome's
-- bloom intensity, glare and sun rays below are ~40% softer. Exposure and bloom thresholds stay at the GDD values
-- because Biomes.calibration (below) already darkens exposure and raises thresholds from them.
Biomes.lighting = {
	Technology = "Future",
	Brightness = 1.8,
	ExposureCompensation = 0.2,
	GeographicLatitude = 25,
	Ambient = Color3.fromRGB(0, 0, 0),
	OutdoorAmbient = Color3.fromRGB(25, 25, 25),
	ShadowSoftness = 0.2,
	EnvironmentDiffuseScale = 1.0,
	dayClock = 14, -- 14:00, max visibility
	nightClock = 20, -- 20:00, the bioluminescent biomes light up
}

-- Calibration from the GDD's numbers to this map in Roblox units (Section 7 Rule 6, Environment Readability, wins
-- over raw values). Playtested 11 Oct 2026: the raw Table A/B/C values white out the voxel islands and the snowy
-- town (Roblox's BloomEffect.Threshold defaults to 2, so a GDD threshold of 0.8 blooms almost every lit surface,
-- and Haze 1.5+ hides the next island). The calibration keeps every biome's values in the same order and ratio:
--   exposure  = GDD exposure + exposureOffset      (0.2 -> -0.4)
--   threshold = GDD threshold x bloomThresholdScale (0.8 -> 2.0, Roblox's default; Abyss 0.5 -> 1.25 glows most)
--   haze      = GDD haze x hazeScale                (1.5 -> 0.9)
-- Set enabled = false to see the raw GDD values.
Biomes.calibration = { enabled = true, exposureOffset = -0.6, bloomThresholdScale = 2.5, hazeScale = 0.6 }

function Biomes.exposure()
	local c = Biomes.calibration
	return Biomes.lighting.ExposureCompensation + (c.enabled and c.exposureOffset or 0)
end

function Biomes.bloomThreshold(id)
	local c = Biomes.calibration
	return Biomes.get(id).post.bloomThreshold * (c.enabled and c.bloomThresholdScale or 1)
end

function Biomes.haze(id)
	local c = Biomes.calibration
	return Biomes.get(id).atmosphere.Haze * (c.enabled and c.hazeScale or 1)
end

-- One entry per biome. Units follow the GDD tables:
--   atmosphere (Section 7 Table B): Density, Offset, Color, decay (a 0-1 darkening; Atmosphere.Decay is a colour,
--     so it is Color darkened by decay x 4), Glare, Haze
--   post (Section 7 Table C): ColorCorrection saturation/contrast/tint, Bloom intensity/size/threshold,
--     DOF focus distance/in-focus radius/far intensity, SunRays intensity/spread
--   colors (Section 7 Table D): primary, secondary, accent glow, mood
--   wind (Section 8 Table C): GlobalWind vector, the emitters that ride it, their Drag, the particle budget
--   ambience (Section 9 Table B): bed, detail layers, reverb (ms) and occlusion
Biomes.list = {
	OpenSea = {
		name = "Open Sea",
		clock = "day",
		atmosphere = { Density = 0.35, Offset = 0.1, Color = Color3.fromRGB(150, 200, 255), decay = 0.05, Glare = 0.05, Haze = 1.5 },
		post = {
			saturation = 0.2, contrast = 0.1, tint = Color3.fromRGB(255, 255, 255),
			bloomIntensity = 0.6, bloomSize = 24, bloomThreshold = 0.8,
			focusDistance = 50, inFocusRadius = 20, farIntensity = 0.5,
			sunIntensity = 0.06, sunSpread = 0.5,
		},
		colors = { primary = Color3.fromRGB(0, 71, 171), secondary = Color3.fromRGB(0, 127, 255), accent = Color3.fromRGB(255, 214, 10), mood = "Freedom, Adventure" },
		wind = { vector = Vector3.new(15, 0, -10), emitters = { "Rain", "Sea Spray", "Leaves" }, drag = 2.5, budget = 1500, effect = "Pushes projectiles, affects boat speed" },
		ambience = { bed = "Ocean Waves", details = { "Seagulls", "Wind", "Hull Creak" }, reverbMs = 1500, occlusion = "Low" },
		weather = { "Clear", "Clear", "Rain", "Storm" }, -- the pool the weather cycle draws from here
	},
	CoralReef = {
		name = "Coral Reef",
		clock = "day",
		atmosphere = { Density = 0.30, Offset = 0.0, Color = Color3.fromRGB(255, 180, 200), decay = 0.03, Glare = 0.0, Haze = 1.0 },
		post = {
			saturation = 0.4, contrast = 0.2, tint = Color3.fromRGB(255, 220, 220),
			bloomIntensity = 0.9, bloomSize = 32, bloomThreshold = 0.7,
			focusDistance = 40, inFocusRadius = 15, farIntensity = 0.6,
			sunIntensity = 0.12, sunSpread = 0.6,
		},
		colors = { primary = Color3.fromRGB(255, 127, 127), secondary = Color3.fromRGB(64, 224, 208), accent = Color3.fromRGB(255, 95, 31), mood = "Playful, Vibrant" },
		wind = { vector = Vector3.new(5, 0, 5), emitters = { "Bubbles", "Sand" }, drag = 1.5, budget = 1200, effect = "Gentle breeze, minimal impact" },
		ambience = { bed = "Gentle Lapping", details = { "Fish Bubbles", "Coral Crackle" }, reverbMs = 800, occlusion = "Medium" },
		weather = { "Clear", "Clear", "Rain" },
	},
	KelpForest = {
		name = "Kelp Forest",
		clock = "night",
		atmosphere = { Density = 0.45, Offset = -0.2, Color = Color3.fromRGB(100, 180, 120), decay = 0.07, Glare = 0.0, Haze = 2.0 },
		post = {
			saturation = 0.1, contrast = 0.3, tint = Color3.fromRGB(200, 255, 200),
			bloomIntensity = 0.5, bloomSize = 16, bloomThreshold = 0.9,
			focusDistance = 30, inFocusRadius = 10, farIntensity = 0.8,
			sunIntensity = 0.0, sunSpread = 0.0,
		},
		colors = { primary = Color3.fromRGB(0, 155, 119), secondary = Color3.fromRGB(128, 128, 0), accent = Color3.fromRGB(0, 255, 240), mood = "Mysterious, Serene" },
		wind = { vector = Vector3.new(10, 2, -5), emitters = { "Kelp", "Spores", "Fog" }, drag = 3.0, budget = 1000, effect = "Sways kelp, obscures vision slightly" },
		ambience = { bed = "Underwater Hum", details = { "Kelp Sway", "Distant Whales" }, reverbMs = 2500, occlusion = "High" },
		weather = { "Clear" },
		dofAlways = true, -- a sunken cathedral: the underwater blur is always on
		underground = true,
	},
	AbyssalTrench = {
		name = "Abyssal Trench",
		clock = "night",
		atmosphere = { Density = 0.60, Offset = -1.5, Color = Color3.fromRGB(20, 20, 40), decay = 0.15, Glare = 0.0, Haze = 3.5 },
		post = {
			saturation = -0.2, contrast = 0.5, tint = Color3.fromRGB(100, 150, 255),
			bloomIntensity = 1.5, bloomSize = 48, bloomThreshold = 0.5,
			focusDistance = 20, inFocusRadius = 5, farIntensity = 1.0,
			sunIntensity = 0.0, sunSpread = 0.0,
		},
		colors = { primary = Color3.fromRGB(25, 25, 112), secondary = Color3.fromRGB(75, 0, 130), accent = Color3.fromRGB(143, 0, 255), mood = "Dread, Isolation" },
		wind = { vector = Vector3.new(0, -5, 0), emitters = { "Debris", "Plankton" }, drag = 4.0, budget = 800, effect = "Downward draft, affects swimming" },
		ambience = { bed = "Deep Rumble", details = { "Sonar Pings", "Pressure Creaks" }, reverbMs = 4000, occlusion = "Very High" },
		weather = { "Clear", "Storm" },
		dofAlways = true,
	},
	VolcanicIsle = {
		name = "Volcanic Isle",
		clock = "day",
		atmosphere = { Density = 0.40, Offset = 0.5, Color = Color3.fromRGB(255, 100, 50), decay = 0.10, Glare = 0.1, Haze = 1.8 },
		post = {
			saturation = 0.3, contrast = 0.4, tint = Color3.fromRGB(255, 150, 100),
			bloomIntensity = 1.2, bloomSize = 40, bloomThreshold = 0.6,
			focusDistance = 60, inFocusRadius = 25, farIntensity = 0.4,
			sunIntensity = 0.18, sunSpread = 0.8,
		},
		colors = { primary = Color3.fromRGB(54, 69, 79), secondary = Color3.fromRGB(150, 20, 10), accent = Color3.fromRGB(255, 191, 0), mood = "Danger, Intensity" },
		wind = { vector = Vector3.new(25, 5, 15), emitters = { "Ash", "Embers", "Smoke" }, drag = 5.0, budget = 2000, effect = "Pushes players, spreads fire VFX" },
		ambience = { bed = "Lava Bubbling", details = { "Ash Fall", "Distant Eruptions" }, reverbMs = 1200, occlusion = "Low" },
		weather = { "Clear", "Ash" },
	},
	-- 2026-10-12 lobby remake: the Nest (the canon hub) is a moonlit blue plaza like HJHJH's two lobby screenshots.
	-- Only the BiomeVolume Workspace.TideboundLobby.NestLook uses it; it is the hub's look, not a sixth fishing biome.
	Nest = {
		name = "The Nest",
		clock = "night",
		clockTime = 19.6, -- just after dusk: deep blue sky with stars, lit by the lanterns
		outdoorAmbient = Color3.fromRGB(116, 122, 156), -- moonlight fill so the plaza stays readable at night
		atmosphere = { Density = 0.3, Offset = 0.15, Color = Color3.fromRGB(90, 120, 210), decay = 0.08, Glare = 0.0, Haze = 1.2 },
		post = {
			saturation = 0.15, contrast = 0.18, tint = Color3.fromRGB(222, 228, 255),
			bloomIntensity = 0.9, bloomSize = 28, bloomThreshold = 0.55,
			focusDistance = 50, inFocusRadius = 20, farIntensity = 0.4,
			sunIntensity = 0.0, sunSpread = 0.0,
		},
		colors = { primary = Color3.fromRGB(60, 110, 230), secondary = Color3.fromRGB(150, 95, 255), accent = Color3.fromRGB(110, 200, 255), mood = "Home, Moonlight" },
		wind = { vector = Vector3.new(6, 0, -4), emitters = { "Leaves" }, drag = 2.5, budget = 800, effect = "Gentle breeze" },
		ambience = { bed = "Ocean Waves", details = { "Wind" }, reverbMs = 1200, occlusion = "Low" },
		weather = { "Clear" },
	},
}

-- Occlusion strength by the GDD's words: how much a blocked line of sight muffles a sound (0 = never, 1 = fully).
Biomes.occlusion = { Low = 0.25, Medium = 0.45, High = 0.7, ["Very High"] = 0.9 }

-- Section 7 Clarity Rule 1: the canon rarity spectrum. The game has 7 tiers, so they share the 5 canon colours:
-- Legendary, Mythic and Celestial are all Gold (Mythic and Celestial add a shimmer, never a new colour).
Biomes.rarityBands = {
	{ name = "White", color = Color3.fromRGB(240, 244, 248) },
	{ name = "Green", color = Color3.fromRGB(80, 220, 120) },
	{ name = "Blue", color = Color3.fromRGB(60, 150, 255) },
	{ name = "Purple", color = Color3.fromRGB(170, 90, 255) },
	{ name = "Gold", color = Color3.fromRGB(255, 196, 40) },
}
Biomes.tierBand = { 1, 2, 3, 4, 5, 5, 5 } -- Config.Tiers index -> rarityBands index

function Biomes.rarityColor(tierIndex)
	local band = Biomes.rarityBands[Biomes.tierBand[tierIndex or 1] or 1]
	return band.color, band.name
end

-- Which canon biome each island of the Open Isles belongs to (IslesLayout names).
Biomes.islandBiome = {
	-- ring 1, the Shallows
	LandingReef = "OpenSea", LilyPond = "OpenSea", BambooReef = "OpenSea", TwinReefNorth = "OpenSea",
	TwinReefSouth = "OpenSea", TurtleBay = "OpenSea", MangroveIsle = "OpenSea", KelpShallows = "KelpForest",
	-- ring 2, the Coral Maze
	ShipwreckBay = "CoralReef", CoralArches = "CoralReef", SeaStacks = "CoralReef", SmugglersCove = "CoralReef",
	PufferLagoon = "CoralReef", GullRock = "CoralReef", NorthAtoll = "CoralReef", SouthAtoll = "CoralReef",
	-- ring 3, the Outer Reef
	ClamAtoll = "CoralReef", LighthouseIsle = "OpenSea", MaelstromIsle = "AbyssalTrench", BoneReef = "AbyssalTrench",
	WardensRock = "VolcanicIsle", StormSpire = "VolcanicIsle", FarReach = "VolcanicIsle",
}

local KELP_BELOW_Y = -150 -- Config.Kelp.belowY (not required here, so Config can require Biomes later)
local ISLAND_REACH = 95 -- an island's biome reaches this far past its shore over the water
local ABYSS_WATER = { at = Isles.maelstrom, radius = 140 } -- the whirlpool's water is the trench too

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function volumeBiome(position)
	for _, part in ipairs(CollectionService:GetTagged("BiomeVolume")) do
		if part:IsA("BasePart") then
			local localPos = part.CFrame:PointToObjectSpace(position)
			local half = part.Size / 2
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				local id = part:GetAttribute("Biome")
				if Biomes.list[id] then
					return id
				end
			end
		end
	end
	return nil
end

-- The canon biome id at a world position.
function Biomes.at(position: Vector3): string
	local override = volumeBiome(position)
	if override then
		return override
	end
	if position.Y < KELP_BELOW_Y then
		return "KelpForest"
	end
	if flatDistance(position, ABYSS_WATER.at) <= ABYSS_WATER.radius then
		return "AbyssalTrench"
	end
	local best, bestGap = nil, math.huge
	for _, island in ipairs(Isles.islands) do
		local gap = flatDistance(position, island.pos) - island.r
		if gap < bestGap then
			best, bestGap = island, gap
		end
	end
	if best and bestGap <= ISLAND_REACH then
		return Biomes.islandBiome[best.name] or Biomes.default
	end
	return Biomes.default
end

function Biomes.get(id)
	return Biomes.list[id] or Biomes.list[Biomes.default]
end

-- Atmosphere.Decay is a Color3; the GDD gives a 0-1 darkening, applied to the biome's haze colour.
function Biomes.decayColor(id)
	local a = Biomes.get(id).atmosphere
	return a.Color:Lerp(Color3.new(0, 0, 0), math.clamp(a.decay * 4, 0, 1))
end

function Biomes.clockTime(id)
	if Biomes.get(id).clockTime then
		return Biomes.get(id).clockTime
	end
	return Biomes.get(id).clock == "night" and Biomes.lighting.nightClock or Biomes.lighting.dayClock
end

return Biomes
