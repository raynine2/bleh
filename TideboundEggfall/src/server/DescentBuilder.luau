-- Tidebound: Eggfall: the Big Update map. Builds Kelp Cathedral into Workspace.TideboundWorld.Descent, and
-- shares its video-style pieces (DescentBuilder.kit) with ShoalsBuilder, which builds the Open Isles (Patch 10):
-- studded paths, checkered grass, voxel trees, the shipwreck, the lighthouse and the Maelstrom.
--   KelpCathedral: biome 2 (Canon order), a sunken cathedral in a cavern under the sea. A studded nave between
--     stone pillars and giant kelp, arches, a rose window over the apse where the Kelp Leviathan coils, holy-
--     water pools to fish in (west aisle), ruined chapels with wild eggs (east aisle), a whale skeleton,
--     grasping vines (the Canon hazard), glowing anemones, floating jellies, light shafts through the roof,
--     a Tide Cache, two beacons and the Descent dais with the current back up.
-- The new areas take their look from the reference video the user picked: chunky voxel trees and grass,
-- checkered grass, studded paths and pads, plank bridges, a dark misty forest full of glowing life.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local Config = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("Config"))

local DescentBuilder = {}

local VERSION = 2

local K = WorldBuilder.kit
local P = K.color
local part, decor, disk, prompt, billboard, light = K.part, K.decor, K.disk, K.prompt, K.billboard, K.light
local TOP, WATER_Y = K.TOP, K.WATER_Y

-- palette: the video's voxel forest, and the cathedral
local GRASS_A = Color3.fromRGB(86, 196, 84)
local GRASS_B = Color3.fromRGB(64, 170, 70)
local LEAVES = { Color3.fromRGB(58, 168, 70), Color3.fromRGB(84, 192, 80), Color3.fromRGB(42, 136, 62), Color3.fromRGB(110, 206, 90) }
local TRUNK = Color3.fromRGB(112, 74, 50)
local PATH = Color3.fromRGB(214, 134, 62)
local PATH_EDGE = Color3.fromRGB(150, 92, 52)
local HULL = Color3.fromRGB(110, 72, 48)
local HULL_DARK = Color3.fromRGB(78, 50, 36)
local SAIL = Color3.fromRGB(236, 226, 196)
local STRIPE_RED = Color3.fromRGB(210, 52, 48)
local WHITE = Color3.fromRGB(244, 244, 240)
local WHIRL = { Color3.fromRGB(40, 150, 190), Color3.fromRGB(70, 200, 220), Color3.fromRGB(160, 240, 250) }
local RUNE = Color3.fromRGB(110, 255, 230)

local FLOOR_A = Color3.fromRGB(42, 98, 66)
local FLOOR_B = Color3.fromRGB(34, 82, 56)
local ROCK = Color3.fromRGB(56, 70, 78)
local ROCK_DARK = Color3.fromRGB(40, 50, 60)
local MOSS = Color3.fromRGB(62, 146, 82)
local STONE = Color3.fromRGB(154, 166, 156)
local STONE_DARK = Color3.fromRGB(116, 126, 120)
local KELP = Color3.fromRGB(92, 140, 52)
local KELP_DARK = Color3.fromRGB(64, 108, 40)
local KELP_LIGHT = Color3.fromRGB(146, 190, 72)
local BULB = Color3.fromRGB(196, 196, 74)
local BONE = Color3.fromRGB(236, 230, 210)
local VINE = Color3.fromRGB(36, 72, 36)
local VINE_TIP = Color3.fromRGB(160, 70, 170)
local GLOWS = { Color3.fromRGB(90, 255, 230), Color3.fromRGB(255, 96, 206), Color3.fromRGB(176, 120, 255), Color3.fromRGB(255, 214, 96) }
local GLASS = { Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 90, 180), Color3.fromRGB(255, 200, 70), Color3.fromRGB(150, 100, 255), Color3.fromRGB(90, 255, 150) }

local KC = Config.Kelp.center
local F = KC.Y -- the cavern floor's top
local CZ = KC.Z
local HALF = 240 -- the cavern's inside runs 240 studs each way from its centre

-- Shared pieces ---------------------------------------------------------------------------------------------

local function studded(props)
	local p = part(props)
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	return p
end

local function windy(p)
	CollectionService:AddTag(p, "WindShake")
	return p
end

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

-- A studded path from a to b (both at the walk height `y`), with darker edges, like the video's dirt paths.
local function studPath(parent, a, b, width, y, color)
	local fa, fb = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	local length = (fb - fa).Magnitude
	local frame = CFrame.lookAt((fa + fb) / 2, fb)
	studded({ Name = "StudPath", Size = Vector3.new(width, 0.6, length), CFrame = frame * CFrame.new(0, -0.3, 0), Color = color or PATH, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "PathEdge", Size = Vector3.new(0.9, 0.7, length), CFrame = frame * CFrame.new(side * (width / 2 + 0.3), -0.3, 0), Color = PATH_EDGE, Parent = parent })
	end
end

-- Checkered grass tiles inside a circle (island tops) or a rectangle.
local function checkerDisk(parent, center, radius, tile, y)
	local n = math.floor(radius / tile)
	for ix = -n, n do
		for iz = -n, n do
			local x, z = ix * tile, iz * tile
			if x * x + z * z <= (radius - tile * 0.5) ^ 2 then
				part({ Name = "GrassTile", Size = Vector3.new(tile, 0.5, tile), CFrame = CFrame.new(center.X + x, y + 0.25, center.Z + z), Color = ((ix + iz) % 2 == 0) and GRASS_A or GRASS_B, Parent = parent })
			end
		end
	end
end

-- Video-style voxel tree: thick trunk, a lumpy crown of chunky cubes in several greens.
local function blockTree(parent, base, rng, scale)
	scale = scale or 1
	local h = rng:NextNumber(8, 11) * scale
	decor({ Name = "Trunk", Size = Vector3.new(2.4, h, 2.4) * Vector3.new(scale, 1, scale), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)), Color = TRUNK, Parent = parent })
	decor({ Name = "Root", Size = Vector3.new(4, 1.2, 4) * scale, CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = TRUNK, Parent = parent })
	local top = base + Vector3.new(0, h, 0)
	for i = 1, rng:NextInteger(5, 7) do
		local s = rng:NextNumber(4.5, 7.5) * scale
		local offset = i == 1 and Vector3.new(0, 1.5 * scale, 0) or Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(-1, 3), rng:NextNumber(-3.5, 3.5)) * scale
		windy(decor({ Name = "Leaves", Size = Vector3.new(s, s * 0.85, s), CFrame = CFrame.new(top + offset) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0), Color = LEAVES[rng:NextInteger(1, #LEAVES)], Parent = parent }))
	end
end

-- Chunky grass tuft: three tall thin blocks.
local function tuft(parent, at, rng, color, tipColor)
	for _ = 1, 3 do
		local h = rng:NextNumber(1.2, 2.6)
		local blade = decor({ Name = "Grass", Size = Vector3.new(0.45, h, 0.45), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-0.7, 0.7), h / 2, rng:NextNumber(-0.7, 0.7))) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25)), Color = color, CastShadow = false, Parent = parent })
		if tipColor then
			blade.Color = rng:NextNumber() < 0.5 and color or tipColor
		end
		windy(blade)
	end
end

local function wildEgg(parent, index, at, y)
	disk(parent, "NestBase" .. index, Vector3.new(at.X, y + 0.6, at.Z), 2.8, 1, Color3.fromRGB(200, 164, 96))
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		decor({ Name = "NestTwig", Size = Vector3.new(0.4, 0.6, 2.4), CFrame = CFrame.new(at.X + math.cos(a) * 2.5, y + 1.2, at.Z + math.sin(a) * 2.5) * CFrame.Angles(0, -a, 0.3), Color = Color3.fromRGB(150, 110, 66), Parent = parent })
	end
	local egg = K.eggShape(parent, "WildEgg" .. index, CFrame.new(at.X, y + 2.6, at.Z), Vector3.new(2.4, 3.2, 2.4), Color3.fromRGB(232, 248, 255))
	K.sparkles(egg, Color3.fromRGB(200, 240, 255), 3)
	light(egg, Color3.fromRGB(170, 230, 255), 10, 0.6)
	prompt(egg, "Steal Egg", "Wild Tide Egg", { Action = "Steal" }, 1, 10)
	return egg
end

local function fishingSpot(parent, index, at, y, biome)
	local spot = part({
		Name = "FishingSpot" .. index,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 8, 8),
		CFrame = CFrame.new(at.X, y + 0.15, at.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = biome == 2 and Color3.fromRGB(120, 255, 210) or Color3.fromRGB(150, 236, 255),
		Transparency = 0.55,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	K.sparkles(spot, Color3.new(1, 1, 1), 4)
	prompt(spot, "Cast", biome == 2 and "Kelp Cathedral Pool" or "Fishing Spot", { Action = "Cast", Biome = biome }, 0, 16)
	return spot
end

local function beacon(parent, index, at, y, depth)
	part({ Name = "BeaconBase" .. index, Size = Vector3.new(6, 1.5, 6), CFrame = CFrame.new(at.X, y + 0.75, at.Z), Color = P.MINT_ROCK, Parent = parent })
	studded({ Name = "BeaconPad" .. index, Size = Vector3.new(12, 0.5, 12), CFrame = CFrame.new(at.X, y + 0.25, at.Z), Color = Color3.fromRGB(240, 196, 70), Parent = parent })
	local crystal = part({ Name = "ExtractionBeacon" .. index, Size = Vector3.new(2.6, 8, 2.6), CFrame = CFrame.new(at.X, y + 5.5, at.Z) * CFrame.Angles(0, math.rad(45), 0), Color = P.BEACON, Transparency = 0.1, Parent = parent })
	crystal:SetAttribute("Depth", depth)
	light(crystal, P.BEACON, 16, 1.2)
	prompt(crystal, "Extract", "Extraction Beacon", { Action = "Extract" }, 1, 12)
	billboard(crystal, "EXTRACT", nil, 6)
	-- a pillar of light you can see across the map
	decor({ Name = "BeaconColumn", Size = Vector3.new(3, 120, 3), CFrame = CFrame.new(at.X, y + 68, at.Z), Color = P.BEACON, Material = Enum.Material.Neon, Transparency = 0.82, CastShadow = false, Parent = parent })
	return crystal
end

-- Two curved boardwalk halves between islands, in the Shoals style (REF 2).
local function boardwalk(parent, a, ra, b, rb, bend)
	local fa, fb = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local dir = (fb - fa).Unit
	local from, to = fa + dir * (ra - 3), fb - dir * (rb - 3)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local mid = (from + to) / 2 + side * bend
	K.boardwalkSegment(parent, from, mid, 7)
	K.boardwalkSegment(parent, mid, to, 7)
	return mid, side
end

-- Set pieces the Shoals use (ShoalsBuilder builds them on the Open Isles) ----------------------------------

local function shipwreck(parent, at, rng)
	local model = Instance.new("Model")
	model.Name = "Shipwreck"
	model.Parent = parent
	-- the galleon lies on the sand, rolled 18 degrees, bow toward the water
	local cf = CFrame.new(at + Vector3.new(0, TOP + 2.5, 0)) * CFrame.Angles(0, math.rad(-25), math.rad(18))
	part({ Name = "Keel", Size = Vector3.new(30, 2, 10), CFrame = cf, Color = HULL_DARK, Material = Enum.Material.WoodPlanks, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		for i = -3, 3 do
			if not (side == 1 and (i == 0 or i == 1)) then -- the starboard hull is smashed open: walk in here
				part({ Name = "HullPlank", Size = Vector3.new(4.2, 7, 1), CFrame = cf * CFrame.new(i * 4.2, 4, side * 5), Color = (i % 2 == 0) and HULL or HULL_DARK, Material = Enum.Material.WoodPlanks, Parent = model })
			end
		end
		part({ Name = "Gunwale", Size = Vector3.new(30, 0.8, 1.4), CFrame = cf * CFrame.new(0, 7.8, side * 5.2), Color = Color3.fromRGB(196, 150, 70), Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Bow", Size = Vector3.new(9, 7, 1), CFrame = cf * CFrame.new(17.5, 4, side * 2.7) * CFrame.Angles(0, side * math.rad(-38), 0), Color = HULL, Material = Enum.Material.WoodPlanks, Parent = model })
	end
	part({ Name = "Stern", Size = Vector3.new(1, 9, 10), CFrame = cf * CFrame.new(-15, 5, 0), Color = HULL_DARK, Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "SternCabin", Size = Vector3.new(7, 5, 10), CFrame = cf * CFrame.new(-11.5, 9.5, 0), Color = HULL, Material = Enum.Material.WoodPlanks, Parent = model })
	decor({ Name = "CabinWindow", Size = Vector3.new(0.3, 1.6, 6), CFrame = cf * CFrame.new(-15.1, 9.5, 0), Color = Color3.fromRGB(255, 200, 110), Material = Enum.Material.Neon, Parent = model })
	-- the broken mast and its torn sail
	local mast = cf * CFrame.new(2, 9, 0) * CFrame.Angles(0, 0, math.rad(-30))
	decor({ Name = "Mast", Size = Vector3.new(1.4, 24, 1.4), CFrame = mast * CFrame.new(0, 12, 0), Color = HULL_DARK, Parent = model })
	decor({ Name = "Yard", Size = Vector3.new(1, 1, 14), CFrame = mast * CFrame.new(0, 19, 0), Color = HULL_DARK, Parent = model })
	for i = 0, 3 do
		decor({ Name = "Sail", Size = Vector3.new(0.2, 2.6, 12 - i * 1.5), CFrame = mast * CFrame.new(0.4, 17.4 - i * 2.7, (i % 2) * 0.8), Color = SAIL, Parent = model })
	end
	decor({ Name = "Flag", Size = Vector3.new(0.15, 2, 3.4), CFrame = mast * CFrame.new(0, 24.6, 1.6), Color = STRIPE_RED, Parent = model })
	for _ = 1, 4 do
		K.crate(model, cf * CFrame.new(rng:NextNumber(-8, 8), 2.4, rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0))
	end
	-- a treasure chest spilling gold, for the eye
	local chest = cf * CFrame.new(-4, 2.6, -2)
	decor({ Name = "Chest", Size = Vector3.new(3, 2, 2), CFrame = chest, Color = HULL, Parent = model })
	decor({ Name = "ChestLid", Size = Vector3.new(3.2, 0.6, 2.2), CFrame = chest * CFrame.new(0, 1.2, -0.8) * CFrame.Angles(math.rad(-50), 0, 0), Color = Color3.fromRGB(230, 180, 60), Parent = model })
	for _ = 1, 8 do
		decor({ Name = "Coin", Size = Vector3.new(0.6, 0.2, 0.6), CFrame = chest * CFrame.new(rng:NextNumber(-2, 2), 1 + rng:NextNumber(-0.8, 0.2), rng:NextNumber(-2.5, 1)), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Neon, Parent = model })
	end
	return cf
end

local function lighthouse(parent, at)
	local base = Vector3.new(at.X, TOP, at.Z)
	local y = base.Y
	for i = 1, 8 do
		local r = 5 - i * 0.18
		disk(parent, "LighthouseBand", Vector3.new(base.X, y + 2.5, base.Z), r, 5, (i % 2 == 0) and STRIPE_RED or WHITE)
		y += 5
	end
	disk(parent, "Gallery", Vector3.new(base.X, y + 0.4, base.Z), 5.6, 0.8, Color3.fromRGB(60, 60, 70))
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		decor({ Name = "Rail", Size = Vector3.new(0.3, 2, 0.3), CFrame = CFrame.new(base.X + math.cos(a) * 5.3, y + 1.8, base.Z + math.sin(a) * 5.3), Color = Color3.fromRGB(60, 60, 70), Parent = parent })
	end
	local lamp = disk(parent, "LampRoom", Vector3.new(base.X, y + 3.2, base.Z), 3, 4.6, Color3.fromRGB(255, 240, 180))
	lamp.Material = Enum.Material.Neon
	lamp.Transparency = 0.2
	light(lamp, Color3.fromRGB(255, 230, 160), 40, 2)
	decor({ Name = "LampRoof", Size = Vector3.new(7, 2.4, 7), CFrame = CFrame.new(base.X, y + 6.6, base.Z) * CFrame.Angles(0, math.rad(45), 0), Color = STRIPE_RED, Parent = parent })
	-- the beam the client sweeps round (TideboundFX spins anything tagged TideboundSpin)
	local beam = decor({ Name = "LighthouseBeam", Size = Vector3.new(90, 5, 5), CFrame = CFrame.new(base.X + 45, y + 3.2, base.Z), Color = Color3.fromRGB(255, 244, 200), Material = Enum.Material.Neon, Transparency = 0.75, CastShadow = false, Parent = parent })
	beam:SetAttribute("Pivot", Vector3.new(base.X, y + 3.2, base.Z))
	beam:SetAttribute("SpinSpeed", 0.6)
	tag(beam, "TideboundSpin")
	part({ Name = "LighthouseDoor", Size = Vector3.new(3, 5, 0.6), CFrame = CFrame.new(base.X, TOP + 2.5, base.Z - 4.9), Color = HULL_DARK, Parent = parent })
end

local function maelstrom(parent, at, rng)
	local c = Vector3.new(at.X, WATER_Y + 0.1, at.Z)
	-- spinning rings of water, darker toward the funnel
	for i, r in ipairs({ 22, 17, 12, 8, 4.5 }) do
		local ring = decor({ Name = "Whirl" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 + i * 0.05, r * 2, r * 2), CFrame = CFrame.new(c + Vector3.new(0, i * 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = WHIRL[(i % #WHIRL) + 1], Material = Enum.Material.Neon, Transparency = 0.55 + i * 0.05, CastShadow = false, Parent = parent })
		ring:SetAttribute("Pivot", c)
		ring:SetAttribute("SpinSpeed", 0.4 + i * 0.35)
		tag(ring, "TideboundSpin")
		-- foam streaks riding each ring
		for j = 1, 3 do
			local a = j / 3 * math.pi * 2 + i
			local streak = decor({ Name = "Foam", Size = Vector3.new(0.3, 0.3, r * 0.9), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r * 0.85, 0.35 + i * 0.06, math.sin(a) * r * 0.85)) * CFrame.Angles(0, -a, 0), Color = Color3.fromRGB(240, 255, 255), Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false, Parent = parent })
			streak:SetAttribute("Pivot", c)
			streak:SetAttribute("SpinSpeed", 0.4 + i * 0.35)
			tag(streak, "TideboundSpin")
		end
	end
	local funnel = decor({ Name = "Funnel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 6, 6), CFrame = CFrame.new(c - Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(8, 30, 50), Parent = parent })
	K.particles(funnel, {
		Color = ColorSequence.new(Color3.fromRGB(220, 250, 255)),
		Rate = 18,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(4, 8),
		Size = NumberSequence.new(0.6, 0),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Right,
		LightEmission = 0.5,
	})
	-- standing stones with glowing runes around it
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local at2 = Vector3.new(c.X + math.cos(a) * 27, WATER_Y, c.Z + math.sin(a) * 27)
		local h = rng:NextNumber(10, 15)
		part({ Name = "StandingStone", Size = Vector3.new(3.4, h + 6, 2.4), CFrame = CFrame.lookAt(at2 + Vector3.new(0, (h + 6) / 2 - 4, 0), Vector3.new(c.X, at2.Y + (h + 6) / 2 - 4, c.Z)), Color = STONE_DARK, Parent = parent })
		decor({ Name = "Rune", Size = Vector3.new(1.4, 3, 0.3), CFrame = CFrame.lookAt(at2 + Vector3.new(0, h * 0.55, 0), Vector3.new(c.X, at2.Y + h * 0.55, c.Z)) * CFrame.new(0, 0, -1.3), Color = RUNE, Material = Enum.Material.Neon, Parent = parent })
	end
	light(funnel, Color3.fromRGB(90, 220, 255), 30, 1.5)
end

-- Kelp Cathedral --------------------------------------------------------------------------------------------

local function at(x, z, y)
	return Vector3.new(x, y or F, CZ + z)
end

local function kelpStalk(parent, base, height, rng)
	local pos = base
	local segments = math.floor(height / 8)
	local twist = rng:NextNumber(0, 6)
	for i = 1, segments do
		local nextPos = pos + Vector3.new(rng:NextNumber(-0.7, 0.7), 8, rng:NextNumber(-0.7, 0.7))
		local w = 4.4 - i * 0.12
		decor({ Name = "Kelp", Size = Vector3.new(w, 8.6, w), CFrame = CFrame.new((pos + nextPos) / 2) * CFrame.Angles(0, twist + i * 0.3, 0), Color = (i % 2 == 0) and KELP or KELP_DARK, Parent = parent }).CanCollide = i <= 2
		if i % 2 == 0 and i < segments then
			local a = twist + i * 1.9
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local blade = windy(decor({ Name = "KelpBlade", Size = Vector3.new(0.4, 2.6, 10), CFrame = CFrame.lookAt(nextPos + dir * 5, nextPos + dir * 10) * CFrame.Angles(math.rad(-25), 0, 0), Color = KELP_LIGHT, CastShadow = false, Parent = parent }))
			blade.Transparency = 0.05
			decor({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(nextPos + dir * 2.6 + Vector3.new(0, -0.5, 0)), Color = BULB, Parent = parent })
		end
		pos = nextPos
	end
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		windy(decor({ Name = "KelpFrond", Size = Vector3.new(0.4, 2.2, 12), CFrame = CFrame.lookAt(pos + Vector3.new(math.cos(a) * 5, 2, math.sin(a) * 5), pos + Vector3.new(math.cos(a) * 12, 6, math.sin(a) * 12)), Color = KELP_LIGHT, CastShadow = false, Parent = parent }))
	end
end

-- Pointed stone arch from `a` to `b` (the springing points), peaking `rise` studs above them.
local function arch(parent, a, b, rise, thickness, broken)
	local pieces = 12
	local previous = a
	for i = 1, pieces do
		local s = i / pieces
		-- two circle arcs meeting at the apex: a gothic point
		local pointy = math.sin(s * math.pi) ^ 0.75
		local point = a:Lerp(b, s) + Vector3.new(0, rise * pointy, 0)
		if not (broken and (i == 5 or i == 6)) then
			decor({ Name = "ArchStone", Size = Vector3.new(thickness, thickness * 0.8, (point - previous).Magnitude + 0.6), CFrame = CFrame.lookAt((previous + point) / 2, point), Color = (i % 2 == 0) and STONE or STONE_DARK, Parent = parent }).CanCollide = false
		end
		previous = point
	end
end

local function pillar(parent, base, height, broken, rng)
	part({ Name = "PillarBase", Size = Vector3.new(8, 3, 8), CFrame = CFrame.new(base + Vector3.new(0, 1.5, 0)), Color = STONE_DARK, Parent = parent })
	local h = broken and height * rng:NextNumber(0.3, 0.55) or height
	part({ Name = "Pillar", Size = Vector3.new(5, h, 5), CFrame = CFrame.new(base + Vector3.new(0, 3 + h / 2, 0)), Color = STONE, Parent = parent })
	for _, y in ipairs({ 0.3, 0.65 }) do
		if y * height < h then
			decor({ Name = "PillarBand", Size = Vector3.new(5.6, 1, 5.6), CFrame = CFrame.new(base + Vector3.new(0, 3 + h * y, 0)), Color = STONE_DARK, Parent = parent })
		end
	end
	if broken then
		for _ = 1, 4 do
			local s = rng:NextNumber(2, 3.6)
			part({ Name = "Rubble", Size = Vector3.new(s, s * 0.7, s), CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-7, 7), s * 0.35, rng:NextNumber(-7, 7))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), Color = STONE_DARK, Parent = parent })
		end
	else
		decor({ Name = "Capital", Size = Vector3.new(8, 3, 8), CFrame = CFrame.new(base + Vector3.new(0, 3 + h + 1.5, 0)), Color = STONE_DARK, Parent = parent })
	end
	-- moss creeping up the shaft
	decor({ Name = "Moss", Size = Vector3.new(5.4, rng:NextNumber(4, 10), 5.4), CFrame = CFrame.new(base + Vector3.new(0, 5, 0)), Color = MOSS, Transparency = 0.1, Parent = parent })
	return 3 + h
end

local function roseWindow(parent, center, radius)
	-- the window glows from behind: stained-glass rings, stone spokes and a stone frame
	local frame = CFrame.new(center)
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		decor({ Name = "WindowFrame", Size = Vector3.new(radius * 0.25, 3, 3), CFrame = frame * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Parent = parent })
	end
	for ring, spec in ipairs({ { 0.3, 8 }, { 0.58, 12 }, { 0.84, 16 } }) do
		for i = 1, spec[2] do
			local a = (i + ring * 0.5) / spec[2] * math.pi * 2
			local pane = decor({ Name = "StainedGlass", Size = Vector3.new(radius * 0.22, radius * 0.22, 0.4), CFrame = frame * CFrame.Angles(0, 0, a) * CFrame.new(radius * spec[1], 0, 0.4) * CFrame.Angles(0, 0, math.rad(45)), Color = GLASS[((i + ring) % #GLASS) + 1], Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, Parent = parent })
			pane.CanCollide = false
		end
	end
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		decor({ Name = "WindowSpoke", Size = Vector3.new(radius, 1, 1.4), CFrame = frame * CFrame.Angles(0, 0, a) * CFrame.new(radius / 2, 0, -0.3), Color = STONE_DARK, Parent = parent })
	end
	local heart = decor({ Name = "WindowHeart", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, radius * 0.42, radius * 0.42), CFrame = frame * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	local glow = decor({ Name = "WindowGlow", Size = Vector3.new(radius * 2.2, radius * 2.2, 0.5), CFrame = frame * CFrame.new(0, 0, 1.5), Color = Color3.fromRGB(120, 60, 140), Material = Enum.Material.Neon, Transparency = 0.35, CastShadow = false, Parent = parent })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 80
	spot.Range = 60
	spot.Brightness = 3
	spot.Color = Color3.fromRGB(255, 190, 220)
	spot.Parent = heart
	return glow
end

local function chapel(parent, center, rng, eggIndex)
	-- faces west (-X), toward the nave
	local cf = CFrame.lookAt(center, center + Vector3.new(-1, 0, 0))
	for ix = -1, 1, 2 do
		for iz = -1, 1, 2 do
			studded({ Name = "ChapelFloor", Size = Vector3.new(11, 0.8, 11), CFrame = cf * CFrame.new(ix * 5.5, 0.4, iz * 5.5), Color = ((ix + iz) % 4 == 0) and STONE or STONE_DARK, Parent = parent })
		end
	end
	part({ Name = "ChapelBack", Size = Vector3.new(22, 20, 2), CFrame = cf * CFrame.new(0, 10, 11), Color = STONE_DARK, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		local h = rng:NextNumber(10, 16)
		part({ Name = "ChapelSide", Size = Vector3.new(2, h, 22), CFrame = cf * CFrame.new(side * 11, h / 2, 0), Color = STONE, Parent = parent })
		part({ Name = "ChapelColumn", Size = Vector3.new(2.4, 16, 2.4), CFrame = cf * CFrame.new(side * 9, 8, -11), Color = STONE_DARK, Parent = parent })
		-- arched window in each side wall (a glowing slit)
		decor({ Name = "ChapelWindow", Size = Vector3.new(2.2, 5, 2), CFrame = cf * CFrame.new(side * 11, 7, 2), Color = GLASS[rng:NextInteger(1, #GLASS)], Material = Enum.Material.Neon, Transparency = 0.2, Parent = parent })
	end
	arch(parent, (cf * CFrame.new(-9, 16, -11)).Position, (cf * CFrame.new(9, 16, -11)).Position, 6, 2.2, false)
	-- the roof fell in: one slab still up, one leaning on the floor
	decor({ Name = "Roof", Size = Vector3.new(24, 1.2, 12), CFrame = cf * CFrame.new(0, 19, 6) * CFrame.Angles(math.rad(-8), 0, 0), Color = ROCK_DARK, Parent = parent })
	part({ Name = "FallenRoof", Size = Vector3.new(12, 1.2, 10), CFrame = cf * CFrame.new(-6, 3, -4) * CFrame.Angles(math.rad(20), 0.4, math.rad(25)), Color = ROCK_DARK, Parent = parent })
	-- the altar with the nest
	studded({ Name = "Altar", Size = Vector3.new(8, 2, 6), CFrame = cf * CFrame.new(0, 1.8, 5), Color = Color3.fromRGB(196, 160, 90), Parent = parent })
	local altarTop = (cf * CFrame.new(0, 2.8, 5)).Position
	wildEgg(parent, eggIndex, altarTop, altarTop.Y - 0.2)
	K.crystalLantern(parent, (cf * CFrame.new(0, 19, 0)).Position, 6)
	for _ = 1, 3 do
		local g = (cf * CFrame.new(rng:NextNumber(-9, 9), 0.8, rng:NextNumber(-9, 9))).Position
		decor({ Name = "Glowcap", Size = Vector3.new(1.2, 0.5, 1.2), CFrame = CFrame.new(g + Vector3.new(0, 1.4, 0)), Color = GLOWS[rng:NextInteger(1, #GLOWS)], Material = Enum.Material.Neon, Parent = parent })
		decor({ Name = "GlowcapStem", Size = Vector3.new(0.4, 1.4, 0.4), CFrame = CFrame.new(g + Vector3.new(0, 0.7, 0)), Color = BONE, Parent = parent })
	end
end

local function pool(parent, center, radius, spots, rng)
	-- a raised holy-water basin: stone rim, one layer of water, glowing lily pads
	local segments = 20
	for i = 1, segments do
		local a = i / segments * math.pi * 2
		local w = 2 * math.pi * radius / segments + 1
		studded({ Name = "PoolRim", Size = Vector3.new(3, 4.6, w), CFrame = CFrame.new(center + Vector3.new(math.cos(a) * radius, 2.3, math.sin(a) * radius)) * CFrame.Angles(0, -a, 0), Color = (i % 2 == 0) and STONE or STONE_DARK, Parent = parent })
	end
	part({ Name = "PoolFloor", Size = Vector3.new(radius * 2, 0.2, radius * 2), CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)), Color = Color3.fromRGB(20, 60, 70), Transparency = 1, Parent = parent })
	workspace.Terrain:FillCylinder(CFrame.new(center + Vector3.new(0, 2, 0)), 4, radius - 1, Enum.Material.Water)
	for _ = 1, 5 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, radius - 3)
		decor({ Name = "GlowPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.4, 2.4), CFrame = CFrame.new(center + Vector3.new(math.cos(a) * d, 4.08, math.sin(a) * d)) * CFrame.Angles(0, 0, math.rad(90)), Color = GLOWS[1], Material = Enum.Material.Neon, Transparency = 0.3, CastShadow = false, Parent = parent })
	end
	light(decor({ Name = "PoolLight", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center + Vector3.new(0, 3, 0)), Transparency = 1, Parent = parent }), Color3.fromRGB(80, 255, 220), 26, 1.4)
	for i, offset in ipairs(spots) do
		fishingSpot(parent, 200 + #parent:GetChildren() + i, center + offset, F + 4, 2)
	end
end

local function whale(parent, head, rng)
	-- the bones of something enormous, nose toward +Z
	local spineY = 9
	for i = 0, 15 do
		local s = 3.4 - i * 0.14
		decor({ Name = "Vertebra", Size = Vector3.new(s, s, 3), CFrame = CFrame.new(head + Vector3.new(0, spineY - i * 0.25, -i * 6.5)), Color = BONE, Parent = parent }).CanCollide = true
	end
	for i = 1, 8 do
		local z = -4 - i * 7
		local width = 13 - math.abs(i - 4) * 1.4
		for _, side in ipairs({ -1, 1 }) do
			local top = head + Vector3.new(side * 1.5, spineY, z)
			local mid = head + Vector3.new(side * width, spineY - 3, z + 1)
			local foot = head + Vector3.new(side * (width - 2), 0.4, z + 2)
			K.rod(parent, top, mid, 1.4, BONE)
			K.rod(parent, mid, foot, 1.3, BONE)
		end
	end
	part({ Name = "Skull", Size = Vector3.new(14, 9, 18), CFrame = CFrame.new(head + Vector3.new(0, 5, 10)) * CFrame.Angles(math.rad(-6), 0, 0), Color = BONE, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "EyeSocket", Size = Vector3.new(0.6, 3, 3), CFrame = CFrame.new(head + Vector3.new(side * 7, 6.5, 8)), Color = Color3.fromRGB(20, 26, 30), Parent = parent })
		K.rod(parent, head + Vector3.new(side * 5, 1, 4), head + Vector3.new(side * 3, 0.6, 26), 1.6, BONE)
	end
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Fluke", Size = Vector3.new(9, 0.8, 5), CFrame = CFrame.new(head + Vector3.new(side * 5, 2, -104)) * CFrame.Angles(0, side * 0.4, side * 0.2), Color = BONE, Parent = parent })
	end
	for _ = 1, 4 do
		decor({ Name = "Glowcap", Size = Vector3.new(1.4, 0.6, 1.4), CFrame = CFrame.new(head + Vector3.new(rng:NextNumber(-8, 8), 0.6, rng:NextNumber(-90, 0))), Color = GLOWS[rng:NextInteger(1, #GLOWS)], Material = Enum.Material.Neon, Parent = parent })
	end
end

local function vines(parent, center, rng)
	local pad = decor({ Name = "GraspingVines", Size = Vector3.new(16, 0.3, 16), CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = VINE, Parent = parent })
	tag(pad, "TideboundVines")
	for _ = 1, 10 do
		local x, z = rng:NextNumber(-7, 7), rng:NextNumber(-7, 7)
		local h = rng:NextNumber(2, 5)
		local stalk = pad.CFrame * CFrame.new(x, h / 2, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
		windy(decor({ Name = "Tendril", Size = Vector3.new(0.5, h, 0.5), CFrame = stalk, Color = VINE, Parent = parent }))
		decor({ Name = "TendrilTip", Size = Vector3.new(0.7, 0.7, 0.7), CFrame = stalk * CFrame.new(0, h / 2, 0), Color = VINE_TIP, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	end
	K.billboard(pad, "GRASPING VINES", "They slow you down", 4).MaxDistance = 40
end

local function glowCluster(parent, center, rng, lit)
	local color = GLOWS[rng:NextInteger(1, #GLOWS)]
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(0.8, 3)
		local g = center + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		decor({ Name = "GlowStem", Size = Vector3.new(0.5, h, 0.5), CFrame = CFrame.new(g + Vector3.new(0, h / 2, 0)), Color = BONE:Lerp(color, 0.3), Parent = parent })
		decor({ Name = "GlowCap", Size = Vector3.new(1.6, 0.6, 1.6) * rng:NextNumber(0.7, 1.3), CFrame = CFrame.new(g + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = color, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	end
	if lit then
		light(decor({ Name = "GlowLight", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(center + Vector3.new(0, 2, 0)), Transparency = 1, Parent = parent }), color, 16, 1)
	end
end

local function jelly(parent, center, rng)
	local model = Instance.new("Model")
	model.Name = "Jelly"
	local color = GLOWS[rng:NextInteger(1, 3)]
	local bell = decor({ Name = "Bell", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 2.4, 3.4), CFrame = CFrame.new(center), Color = color, Material = Enum.Material.Neon, Transparency = 0.35, CastShadow = false, Parent = model })
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		decor({ Name = "Tentacle", Size = Vector3.new(0.25, 4, 0.25), CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 0.9, -2.4, math.sin(a) * 0.9)), Color = color, Material = Enum.Material.Neon, Transparency = 0.5, CastShadow = false, Parent = model })
	end
	light(bell, color, 14, 0.8)
	model.PrimaryPart = bell
	model:SetAttribute("Home", center)
	model:SetAttribute("Seed", rng:NextNumber(0, 10))
	tag(model, "TideboundFloat")
	model.Parent = parent
end

local function shaft(parent, top, bottom)
	local length = (bottom - top).Magnitude
	local beam = decor({ Name = "LightShaft", Size = Vector3.new(16, 16, length), CFrame = CFrame.lookAt((top + bottom) / 2, bottom), Color = Color3.fromRGB(200, 255, 236), Material = Enum.Material.Neon, Transparency = 0.9, CastShadow = false, Parent = parent })
	K.particles(beam, {
		Color = ColorSequence.new(Color3.fromRGB(230, 255, 245)),
		Rate = 6,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(0.3, 0.8),
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new(0.3, 1),
		LightEmission = 1,
		SpreadAngle = Vector2.new(180, 180),
	})
end

local function cavern(parent, rng)
	-- checkered moss floor
	local tile = 20
	for ix = -12, 11 do
		for iz = -12, 11 do
			part({ Name = "CavernFloor", Size = Vector3.new(tile, 10, tile), CFrame = CFrame.new(ix * tile + tile / 2, F - 5, CZ + iz * tile + tile / 2), Color = ((ix + iz) % 2 == 0) and FLOOR_A or FLOOR_B, Parent = parent })
		end
	end
	-- cliffs all round: a tall back layer and a lower front ledge with moss on top, leaving room for the
	-- cathedral's back wall in the middle of the north side
	local function cliff(x, z, nx, nz)
		local h = rng:NextNumber(90, 170)
		local w = rng:NextNumber(18, 26)
		local look = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x - nx, 0, z - nz))
		part({ Name = "Cliff", Size = Vector3.new(w, h, 20), CFrame = CFrame.new(x, F + h / 2 - 4, z) * look.Rotation, Color = (rng:NextNumber() < 0.5) and ROCK or ROCK_DARK, Parent = parent })
		local lh = rng:NextNumber(12, 40)
		local ledge = CFrame.new(x - nx * 14, F + lh / 2 - 2, z - nz * 14) * look.Rotation
		part({ Name = "Ledge", Size = Vector3.new(w + 2, lh, 10), CFrame = ledge, Color = ROCK, Parent = parent })
		decor({ Name = "LedgeMoss", Size = Vector3.new(w + 2.6, 1.2, 10.6), CFrame = ledge * CFrame.new(0, lh / 2, 0), Color = MOSS, Parent = parent })
		if rng:NextNumber() < 0.3 then
			decor({ Name = "WallCrystal", Size = Vector3.new(2, rng:NextNumber(4, 8), 2), CFrame = ledge * CFrame.new(rng:NextNumber(-6, 6), lh / 2 + 2, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Color = GLOWS[rng:NextInteger(1, #GLOWS)], Material = Enum.Material.Neon, Parent = parent })
		end
	end
	local edge = HALF + 12
	for x = -edge, edge, 20 do
		cliff(x, CZ - edge, 0, -1)
		if math.abs(x) > 82 then
			cliff(x, CZ + edge, 0, 1)
		end
	end
	for z = -edge + 20, edge - 20, 20 do
		cliff(-edge, CZ + z, -1, 0)
		cliff(edge, CZ + z, 1, 0)
	end
	-- the roof, with holes where light pours in from the sea above
	local holes = { ["-2,-1"] = true, ["1,1"] = true, ["-1,3"] = true, ["2,-3"] = true, ["-3,2"] = true, ["3,2"] = true }
	local roofY = F + 172
	for ix = -4, 4 do
		for iz = -4, 4 do
			local key = ix .. "," .. iz
			local c = Vector3.new(ix * 62, roofY, CZ + iz * 62)
			if holes[key] then
				shaft(parent, c + Vector3.new(0, -4, 0), Vector3.new(c.X + 30, F + 1, c.Z + 14))
			else
				part({ Name = "Roof", Size = Vector3.new(62, 14, 62), CFrame = CFrame.new(c), Color = ROCK_DARK, Parent = parent })
				if rng:NextNumber() < 0.55 then
					local len = rng:NextNumber(10, 34)
					decor({ Name = "Stalactite", Size = Vector3.new(rng:NextNumber(3, 7), len, rng:NextNumber(3, 7)), CFrame = CFrame.new(c + Vector3.new(rng:NextNumber(-20, 20), -7 - len / 2, rng:NextNumber(-20, 20))), Color = ROCK, Parent = parent })
				end
			end
		end
	end
end

local function leviathan(parent, lair)
	local model = Instance.new("Model")
	model.Name = "KelpLeviathan"
	local skin = Color3.fromRGB(46, 104, 70)
	local belly = Color3.fromRGB(196, 214, 140)
	local frill = Color3.fromRGB(150, 70, 170)
	local body = part({ Name = "Body", Size = Vector3.new(7, 5.5, 9), CFrame = CFrame.new(lair), Color = skin, CanCollide = false, Parent = model })
	local function bolt(name, size, offset, color, material)
		local p = part({ Name = name, Size = size, CFrame = body.CFrame * offset, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, Anchored = false, Massless = true, Parent = model })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	bolt("Snout", Vector3.new(5.6, 3.6, 5), CFrame.new(0, -0.4, -6.4), skin)
	bolt("Jaw", Vector3.new(5.2, 1.6, 8.6), CFrame.new(0, -2.9, -4.6), belly)
	for i = -2, 2 do
		bolt("Tooth", Vector3.new(0.5, 0.9, 0.5), CFrame.new(i * 1.05, -1.9, -8.6), BONE)
	end
	for _, side in ipairs({ -1, 1 }) do
		bolt("Eye", Vector3.new(1.3, 1.1, 1.3), CFrame.new(side * 3.1, 1.1, -3.6), Color3.fromRGB(230, 255, 90), Enum.Material.Neon)
		bolt("Horn", Vector3.new(0.9, 0.9, 5), CFrame.new(side * 2.4, 3.2, 2) * CFrame.Angles(math.rad(30), side * 0.3, 0), BONE)
		for j = 0, 2 do
			bolt("Frill", Vector3.new(0.3, 3.6 - j * 0.8, 3), CFrame.new(side * (3.8 + j * 0.5), 0.6, 1 + j * 1.4) * CFrame.Angles(0, 0, side * math.rad(35 + j * 10)), frill, Enum.Material.Neon)
		end
	end
	bolt("Crest", Vector3.new(0.4, 2.6, 7), CFrame.new(0, 3.6, 1), frill, Enum.Material.Neon)
	billboard(body, "KELP LEVIATHAN", "Guardian of Kelp Cathedral", 7)
	model.PrimaryPart = body
	-- TideboundFX draws its body: segments trailing behind the head along its path
	model:SetAttribute("Segments", 14)
	model:SetAttribute("Spacing", 3.8)
	model:SetAttribute("SegmentSize", 5)
	model:SetAttribute("SkinColor", skin)
	model:SetAttribute("FinColor", frill)
	model:SetAttribute("BellyColor", belly)
	tag(model, "TideboundSerpent")
	model.Parent = parent
	return model
end

local function buildKelp(root)
	local folder = Instance.new("Folder")
	folder.Name = "KelpCathedral"
	local rng = Random.new(7702)
	cavern(folder, rng)

	-- the Descent dais: where the Maelstrom drops you, and the current back up
	local dais = at(0, -188)
	disk(folder, "DescentDais", dais + Vector3.new(0, 1, 0), 18, 2, STONE)
	local runeRing = disk(folder, "DaisRunes", dais + Vector3.new(0, 2.05, 0), 15, 0.1, RUNE)
	runeRing.Material = Enum.Material.Neon
	runeRing.Transparency = 0.5
	runeRing.CanCollide = false
	disk(folder, "DaisInner", dais + Vector3.new(0, 2.1, 0), 13.5, 0.12, STONE).CanCollide = false
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local h = rng:NextNumber(4, 10)
		part({ Name = "DaisPillar", Size = Vector3.new(2.6, h, 2.6), CFrame = CFrame.new(dais + Vector3.new(math.cos(a) * 16.5, 2 + h / 2, math.sin(a) * 16.5)), Color = STONE_DARK, Parent = folder })
	end
	local current = decor({ Name = "UpCurrent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 9, 9), CFrame = CFrame.new(at(0, -212, F + 40)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon, Transparency = 0.8, CastShadow = false, Parent = folder })
	K.particles(current, {
		Color = ColorSequence.new(Color3.fromRGB(220, 250, 255)),
		Rate = 30,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(14, 22),
		Size = NumberSequence.new(0.5, 0.1),
		EmissionDirection = Enum.NormalId.Right,
		LightEmission = 0.6,
	})
	local currentBase = part({ Name = "CurrentBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12), CFrame = CFrame.new(at(0, -212, F + 0.5)) * CFrame.Angles(0, 0, math.rad(90)), Color = RUNE, Material = Enum.Material.Neon, Transparency = 0.3, Parent = folder })
	prompt(currentBase, "Swim Up", "The Current (back to the Shoals)", { Action = "Ascend" }, 1, 12)
	billboard(currentBase, "THE CURRENT", "Swim back up to the Sunken Shoals", 7)

	-- the nave: a studded path between stone pillars, giant kelp behind them, arches overhead
	studPath(folder, at(0, -170), at(0, 168), 34, F + 0.6)
	local pillarTops = {}
	for i = 0, 7 do
		local z = -140 + i * 40
		for _, x in ipairs({ -32, 32 }) do
			local broken = (i == 2 and x < 0) or (i == 5 and x > 0)
			pillarTops[x .. "," .. z] = { pillar(folder, at(x, z), 56, broken, rng), broken }
		end
	end
	for i = 0, 3 do
		local z = -120 + i * 80
		local left, right = pillarTops["-32," .. z], pillarTops["32," .. z]
		if left and right and not left[2] and not right[2] then
			arch(folder, at(-32, z, F + left[1]), at(32, z, F + right[1]), 24, 3, i == 2)
		end
	end
	for i = 0, 6 do
		local z1, z2 = -140 + i * 40, -100 + i * 40
		for _, x in ipairs({ -32, 32 }) do
			local a, b = pillarTops[x .. "," .. z1], pillarTops[x .. "," .. z2]
			if a and b and not a[2] and not b[2] then
				arch(folder, at(x, z1, F + a[1]), at(x, z2, F + b[1]), 12, 2.4, false)
			end
		end
	end
	for _, z in ipairs({ -140, -80, -20, 40, 100, 160 }) do
		for _, x in ipairs({ -52, 52 }) do
			kelpStalk(folder, at(x + rng:NextNumber(-3, 3), z), rng:NextNumber(96, 140), rng)
		end
	end
	for _, spot in ipairs({ { -95, -40 }, { -140, 50 }, { -210, -130 }, { -90, 170 }, { 140, 10 }, { 210, -120 }, { 95, 170 }, { -215, 120 }, { 215, 60 }, { 60, -150 } }) do
		kelpStalk(folder, at(spot[1], spot[2]), rng:NextNumber(70, 120), rng)
	end
	-- the entrance arch with the cathedral's name
	local gate = part({ Name = "NaveSign", Size = Vector3.new(30, 5, 1), CFrame = CFrame.new(at(0, -160, F + 30)) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(20, 16, 34), Parent = folder })
	K.surfaceText(gate, "KELP CATHEDRAL", RUNE)
	for _, x in ipairs({ -17, 17 }) do
		part({ Name = "GatePost", Size = Vector3.new(4, 34, 4), CFrame = CFrame.new(at(x, -160, F + 17)), Color = STONE_DARK, Parent = folder })
	end
	arch(folder, at(-17, -160, F + 34), at(17, -160, F + 34), 10, 2.6, false)

	-- the apse: steps, a raised floor, the altar with a cracked stone egg, the rose window above
	studded({ Name = "ApseStep", Size = Vector3.new(140, 2, 4), CFrame = CFrame.new(at(0, 163, F + 1)), Color = STONE_DARK, Parent = folder })
	studded({ Name = "ApseStep", Size = Vector3.new(140, 4, 4), CFrame = CFrame.new(at(0, 167, F + 2)), Color = STONE, Parent = folder })
	studded({ Name = "Apse", Size = Vector3.new(140, 6, 66), CFrame = CFrame.new(at(0, 202, F + 3)), Color = STONE_DARK, Parent = folder })
	part({ Name = "BackWall", Size = Vector3.new(170, 180, 8), CFrame = CFrame.new(at(0, 248, F + 88)), Color = ROCK_DARK, Parent = folder })
	roseWindow(folder, at(0, 243, F + 92), 30)
	part({ Name = "Altar", Size = Vector3.new(18, 5, 8), CFrame = CFrame.new(at(0, 224, F + 8.5)), Color = STONE, Parent = folder })
	decor({ Name = "AltarTrim", Size = Vector3.new(18.6, 0.8, 8.6), CFrame = CFrame.new(at(0, 224, F + 11.2)), Color = Color3.fromRGB(230, 186, 70), Parent = folder })
	local relic = K.eggShape(folder, "StoneEgg", CFrame.new(at(0, 228, F + 22)), Vector3.new(14, 19, 14), STONE_DARK)
	relic.CanCollide = true
	decor({ Name = "EggCrack", Size = Vector3.new(0.6, 12, 0.6), CFrame = CFrame.new(at(0, 221, F + 22)) * CFrame.Angles(0, 0, 0.3), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Parent = folder })
	light(relic, Color3.fromRGB(255, 210, 120), 30, 1.5)
	for _, x in ipairs({ -56, 56 }) do
		pillar(folder, at(x, 190, F + 6), 70, false, rng)
		pillar(folder, at(x, 228, F + 6), 70, false, rng)
	end
	wildEgg(folder, 205, at(44, 186), F + 6)

	-- west aisle: three holy-water pools to fish in, and the whale
	pool(folder, at(-120, -120), 14, { Vector3.new(0, 0, 0) }, rng)
	pool(folder, at(-170, -10), 18, { Vector3.new(-6, 0, -5), Vector3.new(6, 0, 6) }, rng)
	pool(folder, at(-115, 110), 14, { Vector3.new(0, 0, 0) }, rng)
	studPath(folder, at(-17, -120), at(-104, -120), 12, F + 0.6)
	studPath(folder, at(-17, -10), at(-150, -10), 12, F + 0.6)
	studPath(folder, at(-17, 110), at(-99, 110), 12, F + 0.6)
	whale(folder, at(-195, 150), rng)

	-- east aisle: four ruined chapels, each with a wild egg on its altar
	local chapels = { { 105, -120 }, { 175, -50 }, { 110, 50 }, { 170, 130 } }
	for i, c in ipairs(chapels) do
		chapel(folder, at(c[1], c[2]), rng, 200 + i)
		studPath(folder, at(17, c[2]), at(c[1] - 11, c[2]), 12, F + 0.6)
	end

	-- the Tide Cache (bank your fish) by the entrance
	local cache = at(-55, -140)
	studded({ Name = "CachePlinth", Size = Vector3.new(8, 2, 8), CFrame = CFrame.new(cache + Vector3.new(0, 1, 0)), Color = STONE, Parent = folder })
	local chest = part({ Name = "TideCache", Size = Vector3.new(3, 2.2, 2.2), CFrame = CFrame.new(cache + Vector3.new(0, 3.1, 0)), Color = P.PLANK, Material = Enum.Material.WoodPlanks, Parent = folder })
	decor({ Name = "CacheLid", Size = Vector3.new(3.2, 0.5, 2.4), CFrame = chest.CFrame * CFrame.new(0, 1.3, 0), Color = P.GOLD, Parent = folder })
	light(chest, P.BEACON, 16, 1.2)
	K.sparkles(chest, Color3.fromRGB(200, 255, 240), 4)
	prompt(chest, "Bank Catch", "Tide Cache", { Action = "BankCatch" }, 1, 12)
	billboard(chest, "TIDE CACHE", "Bank fish here: safe Pearls", 5)
	studPath(folder, at(-17, -140), at(-51, -140), 8, F + 0.6)

	-- two beacons in the far corners, past the Leviathan's apse
	beacon(folder, 201, at(-198, 200), F, 2)
	beacon(folder, 202, at(200, 212), F, 2)
	studPath(folder, at(-70, 192), at(-192, 200), 12, F + 0.6)
	studPath(folder, at(70, 196), at(194, 211), 12, F + 0.6)

	-- grasping vines (Canon hazard: they slow you), glowing life, jellies, bubbles, grass
	for _, v in ipairs({ { -50, -95 }, { -75, 5 }, { -45, 125 }, { 50, -85 }, { 80, 5 }, { 45, 110 }, { -150, -70 }, { 150, 60 }, { 0, 75 }, { -210, 0 }, { 140, 180 }, { -140, 190 } }) do
		vines(folder, at(v[1], v[2]), rng)
	end
	for i = 1, 40 do
		local x, z = rng:NextNumber(-225, 225), rng:NextNumber(-225, 225)
		if math.abs(x) > 22 then
			glowCluster(folder, at(x, z), rng, i % 3 == 0)
		end
	end
	for _ = 1, 16 do
		jelly(folder, at(rng:NextNumber(-200, 200), rng:NextNumber(-180, 200), F + rng:NextNumber(14, 60)), rng)
	end
	for _ = 1, 10 do
		local vent = decor({ Name = "BubbleVent", Size = Vector3.new(3, 0.6, 3), CFrame = CFrame.new(at(rng:NextNumber(-220, 220), rng:NextNumber(-220, 220), F + 0.3)), Color = ROCK_DARK, Parent = folder })
		K.particles(vent, {
			Color = ColorSequence.new(Color3.fromRGB(200, 250, 255)),
			Rate = 4,
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(5, 9),
			Size = NumberSequence.new(0.6, 0.9),
			Transparency = NumberSequence.new(0.2, 0.8),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(8, 8),
			LightEmission = 0.4,
		})
	end
	for _ = 1, 150 do
		local x, z = rng:NextNumber(-230, 230), rng:NextNumber(-230, 230)
		if math.abs(x) > 20 then
			tuft(folder, at(x, z), rng, Color3.fromRGB(56, 140, 70), Color3.fromRGB(110, 200, 110))
		end
	end
	-- schools of little fish that swim through the air (TideboundFX animates them)
	for _ = 1, 7 do
		local anchor = decor({ Name = "School", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at(rng:NextNumber(-180, 180), rng:NextNumber(-160, 180), F + rng:NextNumber(10, 40))), Transparency = 1, Parent = folder })
		anchor:SetAttribute("Radius", rng:NextNumber(8, 16))
		anchor:SetAttribute("Count", rng:NextInteger(6, 10))
		anchor:SetAttribute("Color", GLOWS[rng:NextInteger(1, #GLOWS)])
		tag(anchor, "TideboundSchool")
	end

	-- the Kelp Leviathan coils in front of the altar; its patrol loops the nave and aisles
	local lair = at(0, 200, Config.Leviathan.hoverY)
	leviathan(folder, lair)
	local path = Instance.new("Folder")
	path.Name = "LeviathanPath"
	path.Parent = folder
	for i, wp in ipairs({ { 0, 150 }, { -80, 80 }, { -110, -40 }, { -50, -120 }, { 50, -120 }, { 110, -40 }, { 80, 80 } }) do
		part({ Name = ("WP%02d"):format(i), Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at(wp[1], wp[2], Config.Leviathan.hoverY)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = path })
	end
	folder.Parent = root
end

function DescentBuilder.build(world)
	local existing = world:FindFirstChild("Descent")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Descent"
	root:SetAttribute("Version", VERSION)
	buildKelp(root)
	root.Parent = world
	return root
end

-- The video-style pieces, for ShoalsBuilder (Patch 10). y arguments are walk heights.
DescentBuilder.kit = {
	studded = studded,
	windy = windy,
	tag = tag,
	studPath = studPath,
	checkerDisk = checkerDisk,
	blockTree = blockTree,
	tuft = tuft,
	wildEgg = wildEgg,
	fishingSpot = fishingSpot,
	beacon = beacon,
	boardwalk = boardwalk,
	shipwreck = shipwreck,
	lighthouse = lighthouse,
	maelstrom = maelstrom,
	color = {
		GRASS_A = GRASS_A,
		GRASS_B = GRASS_B,
		LEAVES = LEAVES,
		TRUNK = TRUNK,
		PATH = PATH,
		PATH_EDGE = PATH_EDGE,
		HULL = HULL,
		HULL_DARK = HULL_DARK,
		SAIL = SAIL,
		STRIPE_RED = STRIPE_RED,
		WHITE = WHITE,
		RUNE = RUNE,
		STONE = STONE,
		STONE_DARK = STONE_DARK,
		ROCK = ROCK,
		MOSS = MOSS,
		BONE = BONE,
		GLOWS = GLOWS,
	},
}

return DescentBuilder
