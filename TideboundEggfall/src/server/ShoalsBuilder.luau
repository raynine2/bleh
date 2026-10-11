-- Tidebound: Eggfall: the Sunken Shoals of the Open Isles (Patch 10). Builds TideboundWorld.SunkenShoals from
-- IslesLayout: the sea (terrain water on a sand floor), the 22 islands in three rings, the bridges and geyser jump
-- pads between them, and every gameplay object on them. IsleFeatures decorates each island's top by its feature.
--   Ring 1, the Shallows (REF 2): pond-green tops ringed by mint rocks, dark boardwalks on brown posts with
--     sagging rope, lime bamboo standing in the water, lily pads, clovers and daisies.
--   Ring 2, the Coral Maze (the reference video): checkered grass, studded orange paths, sandy beaches, chunky
--     coral in the shallows, plank bridges on stilts with buoys.
--   Ring 3, the Outer Reef: dark rock and moss, jagged shores, rickety rope bridges, rain under storm clouds.
-- The server finds the gameplay objects by their prompts' Action attribute (Cast, Steal, Extract, BankCatch) and
-- by tag: TideboundJumpPad (Target), TideboundCache, TideboundAnemone, TideboundEliteDen (Radius, Hole children).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local L = require(Shared:WaitForChild("IslesLayout"))
local Config = require(Shared:WaitForChild("Config"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local DescentBuilder = require(script.Parent:WaitForChild("DescentBuilder"))
local IsleFeatures = require(script.Parent:WaitForChild("IsleFeatures"))

local ShoalsBuilder = {}

local VERSION = 1

local K = WorldBuilder.kit
local D = DescentBuilder.kit
local P = K.color
local V = D.color
local part, decor, disk, rod, light, particles = K.part, K.decor, K.disk, K.rod, K.light, K.particles
local TOP, WATER_Y, SEA_FLOOR = K.TOP, K.WATER_Y, K.SEA_FLOOR

local LAGOON_HOLE = 16 -- the open water in the middle of Puffer Lagoon
local GAP = 5 -- what we place on land keeps this far from every gameplay object
local WIDTH = { boardwalk = 7, plank = 7, rope = 5 }
local PLANK_PITCH, PLANK_DEPTH = 2.45, 2 -- plank bridge: 0.45 gaps between planks
local ROPE_PITCH, ROPE_DEPTH, ROPE_SAG = 1.32, 1.2, 0.5 -- rope bridge: a missing plank leaves a 1.44 gap

-- palette
local SHALLOW_SHORE = Color3.fromRGB(214, 220, 164)
local SHALLOW_TUFT = Color3.fromRGB(92, 190, 84)
local SHALLOW_TIP = Color3.fromRGB(166, 232, 116)
local LILY = { Color3.fromRGB(92, 186, 84), Color3.fromRGB(74, 166, 76), Color3.fromRGB(122, 206, 98) }
local LILY_FLOWER = Color3.fromRGB(255, 170, 214)
local BEACH = Color3.fromRGB(240, 214, 152)
local MAZE_TUFT = Color3.fromRGB(58, 156, 66)
local MAZE_TIP = Color3.fromRGB(122, 214, 98)
local CORAL = { Color3.fromRGB(255, 118, 168), Color3.fromRGB(255, 150, 66), Color3.fromRGB(168, 98, 232) }
local PLANKS = { Color3.fromRGB(176, 122, 76), Color3.fromRGB(156, 106, 68), Color3.fromRGB(136, 92, 60) }
local REEF_TOP = V.ROCK:Lerp(V.STONE_DARK, 0.45)
local REEF_TUFT = Color3.fromRGB(72, 112, 78)
local WET_WOOD = Color3.fromRGB(78, 64, 54)
local RAIN = Color3.fromRGB(176, 204, 236)
local CLOUD = { Color3.fromRGB(64, 70, 84), Color3.fromRGB(84, 90, 104), Color3.fromRGB(50, 56, 68) }
local GEYSER = Color3.fromRGB(64, 226, 230)
local GEYSER_GLOW = Color3.fromRGB(150, 255, 250)
local HEAL = Color3.fromRGB(120, 255, 150)
local FOAM = Color3.fromRGB(236, 250, 255)
local SEAGRASS = Color3.fromRGB(70, 150, 90)
local ANEMONE_BASE = Color3.fromRGB(196, 64, 126)
local ANEMONE_TIP = Color3.fromRGB(255, 120, 200)
local CORAL_DARK = Color3.fromRGB(70, 58, 84)
local SIGN_DARK = Color3.fromRGB(20, 16, 34)
local BUOY = { Color3.fromRGB(230, 60, 56), Color3.fromRGB(60, 200, 96) }
local SCHOOL_COLORS = {
	{ Color3.fromRGB(90, 255, 230), Color3.fromRGB(255, 214, 96) },
	{ Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 96, 206) },
	{ Color3.fromRGB(150, 200, 255), Color3.fromRGB(176, 120, 255) },
}

-- Per ring: the shore band (the foundation's top, half a stud under the walk), the ground cap, how far the cap
-- sits in from the coast, and the sand shelf under the water around the island.
local RING = {
	{ shore = SHALLOW_SHORE, top = P.POND_GRASS, inset = 2.5, material = Enum.Material.SmoothPlastic, shelf = -5 },
	{ shore = BEACH, inset = 3, material = Enum.Material.SmoothPlastic, shelf = -6 },
	{ shore = V.ROCK, top = REEF_TOP, inset = 2, material = Enum.Material.Slate, shelf = -9 },
}

-- Build state (reset by plan): island outlines, the gameplay objects decor keeps clear of, bridge decks.
local shapes = {} -- [island name] = { island, center, lobes = { { c, r } }, hole, inset, reach }
local shapeList = {}
local blockers = {} -- { at, r }
local corridors = {} -- { points, r, box }
local bridges = {}
local padSigns = {}
local denHoles = {}
local maelstromSign = Vector3.zero

-- Geometry ----------------------------------------------------------------------------------------------------

local function flat(p)
	return Vector3.new(p.X, 0, p.Z)
end

local function along(angle)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function segmentDistance(p, a, b)
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	if lengthSq < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / lengthSq, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function polylineDistance(p, points)
	local best = math.huge
	for i = 1, #points - 1 do
		best = math.min(best, segmentDistance(p, points[i], points[i + 1]))
	end
	return best
end

-- A path through flat `points`, measured by length: at(s) gives the point s studs along it and the direction.
local function polyCurve(points)
	local lengths = { 0 }
	for i = 2, #points do
		lengths[i] = lengths[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	local total = lengths[#points]
	local function at(s)
		s = math.clamp(s, 0, total)
		for i = 1, #points - 2 do
			if s <= lengths[i + 1] then
				local span = lengths[i + 1] - lengths[i]
				return points[i]:Lerp(points[i + 1], span > 0 and (s - lengths[i]) / span or 0), (points[i + 1] - points[i]).Unit
			end
		end
		local n = #points
		local span = lengths[n] - lengths[n - 1]
		return points[n - 1]:Lerp(points[n], span > 0 and (s - lengths[n - 1]) / span or 1), (points[n] - points[n - 1]).Unit
	end
	return { points = points, length = total, at = at }
end

-- A bridge centreline: a smooth curve from a to b, bowed sideways by `bend` studs at the middle.
local function bowCurve(a, b, bend)
	local fa, fb = flat(a), flat(b)
	local dir = (fb - fa).Unit
	local control = (fa + fb) / 2 + Vector3.new(-dir.Z, 0, dir.X) * (bend * 2)
	local points = {}
	for i = 0, 40 do
		local t = i / 40
		points[i + 1] = fa * ((1 - t) ^ 2) + control * (2 * (1 - t) * t) + fb * (t ^ 2)
	end
	return polyCurve(points)
end

-- The island a point belongs to: the one whose rim it is furthest inside (or least outside).
local function islandAt(p)
	local best, bestGap = L.islands[1], math.huge
	for _, island in ipairs(L.islands) do
		local gap = (flat(p) - flat(island.pos)).Magnitude - island.r
		if gap < bestGap then
			best, bestGap = island, gap
		end
	end
	return best
end

-- Where a geyser drops you: 10 studs in from its pad, toward the middle of the pad's island.
local function landingFrom(padAt)
	local p = flat(padAt)
	local inward = flat(islandAt(p).pos) - p
	return Vector3.new(p.X, TOP, p.Z) + (inward.Magnitude > 0.1 and inward.Unit * 10 or Vector3.zero)
end

-- Island outlines ---------------------------------------------------------------------------------------------
-- An island is a main disk plus lobes (all within its r): arms reaching out to every bridge, a couple more for an
-- organic coast, and an outcrop under a gameplay object that sits right on the rim (a geyser, a beacon).

local function inShape(shape, p, inset)
	p = flat(p)
	if shape.hole and (p - shape.hole).Magnitude < LAGOON_HOLE + inset then
		return false
	end
	for _, lobe in ipairs(shape.lobes) do
		if (p - lobe.c).Magnitude <= lobe.r - inset then
			return true
		end
	end
	return false
end

-- Is the whole circle (p, radius) on the island's top (`inset` in from the coast)?
local function covers(shape, p, radius, inset)
	if not inShape(shape, p, inset) then
		return false
	end
	for i = 1, 8 do
		if not inShape(shape, flat(p) + along(i / 8 * math.pi * 2) * radius, inset) then
			return false
		end
	end
	return true
end

-- On any island? A negative inset asks for that much water all round instead.
local function onLand(p, inset)
	p = flat(p)
	for _, shape in ipairs(shapeList) do
		if (p - shape.center).Magnitude <= shape.reach - inset + 1 and inShape(shape, p, inset) then
			return true
		end
	end
	return false
end

-- Everything that stands on an island's top, with the radius of ground it needs.
local function landObjects()
	local list = {}
	local function add(at, radius)
		table.insert(list, { at = flat(at), r = radius, island = islandAt(at) })
	end
	for _, pair in ipairs(L.jumpPads) do
		add(pair[1], 6.5)
		add(pair[2], 6.5)
	end
	for _, at in ipairs(L.beacons) do
		add(at, 6)
	end
	for _, at in ipairs(L.tideCaches) do
		add(at, 3.5)
	end
	for _, at in ipairs(L.anemoneBeds) do
		add(at, 5)
	end
	for _, nest in ipairs(L.eggNests) do
		add(nest.at, 3)
	end
	add(L.ascend.Position, 3)
	add(L.diveSpawn.Position, 4)
	return list
end

local function makeShape(index, island, objects)
	local rng = Random.new(1000 + index * 37)
	local center = flat(island.pos)
	local r = island.r
	local inset = RING[island.ring].inset
	local shape = { island = island, center = center, lobes = {}, dirs = {}, inset = inset, reach = r, hole = nil }
	local armR = math.clamp(r * 0.32, 9, 14)
	local function addLobe(c, radius, kind)
		if shape.hole then
			radius = math.min(radius, (c - shape.hole).Magnitude - LAGOON_HOLE)
		end
		if radius >= 3 then
			table.insert(shape.lobes, { c = c, r = radius, kind = kind })
			shape.reach = math.max(shape.reach, (c - center).Magnitude + radius)
		end
	end
	local function addArm(dir)
		for _, d in ipairs(shape.dirs) do
			if d:Dot(dir) > 0.996 then
				return
			end
		end
		table.insert(shape.dirs, dir)
		addLobe(center + dir * (r - armR), armR, "arm")
	end
	if island.feature == "lagoon" then
		-- a ring of lobes round the open water in the middle
		shape.hole = center
		local width = (r - LAGOON_HOLE) / 2
		local phase = rng:NextNumber(0, math.pi * 2)
		for i = 1, 10 do
			addLobe(center + along(phase + i / 10 * math.pi * 2) * (LAGOON_HOLE + width), width, "ring")
		end
	else
		local mainR = r * rng:NextNumber(0.76, 0.82)
		local shift = rng:NextNumber(0, math.min(r * 0.06, r - 1 - mainR))
		addLobe(center + along(rng:NextNumber(0, math.pi * 2)) * shift, mainR, "main")
	end
	for _, link in ipairs(L.links) do
		local other = (link[1] == island.name and link[2]) or (link[2] == island.name and link[1]) or nil
		if other then
			addArm((flat(L.byName[other].pos) - center).Unit)
		end
	end
	-- the causeway from town lands on Landing Reef
	if islandAt(L.causeway.to) == island then
		local dir = (flat(L.causeway.to) - flat(L.causeway.from)).Unit
		addLobe(flat(L.causeway.to) + dir * 12, 12, "causeway")
	end
	for _, object in ipairs(objects) do
		if object.island == island and not covers(shape, object.at, object.r, inset) then
			local offset = object.at - center
			if offset.Magnitude > 1 then
				addArm(offset.Unit)
			end
			if not covers(shape, object.at, object.r, inset) then
				addLobe(object.at, object.r + inset + 1.5, "outcrop")
			end
		end
	end
	if not shape.hole then
		local extra = (#shape.lobes <= 2) and 2 or rng:NextInteger(1, 2)
		for _ = 1, extra do
			for _ = 1, 16 do
				local dir = along(rng:NextNumber(0, math.pi * 2))
				local free = true
				for _, d in ipairs(shape.dirs) do
					if d:Dot(dir) > 0.77 then
						free = false
						break
					end
				end
				if free then
					local radius = r * rng:NextNumber(0.3, 0.42)
					table.insert(shape.dirs, dir)
					addLobe(center + dir * (r * rng:NextNumber(0.88, 1) - radius), radius, "lobe")
					break
				end
			end
		end
	end
	return shape
end

-- Points along the coastline every `step` studs, each with the outward direction there.
local function coast(shape, step)
	local points = {}
	for _, lobe in ipairs(shape.lobes) do
		local count = math.max(6, math.floor(2 * math.pi * lobe.r / step))
		local phase = (lobe.c.X * 0.37 + lobe.c.Z * 0.11) % 1
		for i = 1, count do
			local out = along((i + phase) / count * math.pi * 2)
			local p = lobe.c + out * lobe.r
			local inside = false
			for _, other in ipairs(shape.lobes) do
				if other ~= lobe and (p - other.c).Magnitude < other.r - 0.5 then
					inside = true
					break
				end
			end
			if not inside then
				table.insert(points, { at = p, out = out })
			end
		end
	end
	return points
end

-- The Coral Maze's checkered grass: one grid over the whole island, so overlapping lobes never double up.
local function tileSize(island)
	return island.r >= 36 and 6 or 5
end

local function tileOn(shape, x, z, tile)
	return inShape(shape, Vector3.new(x, 0, z), 2 + tile * 0.5)
end

local function onTiles(shape, p)
	local tile = tileSize(shape.island)
	local ix = math.floor((p.X - shape.center.X) / tile + 0.5)
	local iz = math.floor((p.Z - shape.center.Z) / tile + 0.5)
	return tileOn(shape, shape.center.X + ix * tile, shape.center.Z + iz * tile, tile)
end

-- On the walkable top (grass, tiles or rock), `margin` in from its edge?
local function onTop(shape, p, margin)
	if shape.island.ring == 2 and not onTiles(shape, p) then
		return false
	end
	return inShape(shape, p, shape.inset + margin)
end

-- Clearance -----------------------------------------------------------------------------------------------

local function block(at, radius)
	table.insert(blockers, { at = flat(at), r = radius })
end

local function addCorridor(points, radius)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(points) do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local pad = radius + 24
	table.insert(corridors, { points = points, r = radius, minX = minX - pad, maxX = maxX + pad, minZ = minZ - pad, maxZ = maxZ + pad })
end

local function nearCorridor(p, extra)
	for _, c in ipairs(corridors) do
		if p.X > c.minX and p.X < c.maxX and p.Z > c.minZ and p.Z < c.maxZ and polylineDistance(p, c.points) < c.r + extra then
			return true
		end
	end
	return false
end

-- Is a thing of this radius at p `gap` studs clear of every gameplay object, and off the bridges?
local function clear(p, radius, gap)
	p = flat(p)
	for _, b in ipairs(blockers) do
		if (p - b.at).Magnitude < b.r + radius + gap then
			return false
		end
	end
	return not nearCorridor(p, radius + 1)
end

-- A random point on an island's top, clear of the gameplay objects.
local function landPoint(shape, rng, margin, radius)
	for _ = 1, 24 do
		local p = shape.center + along(rng:NextNumber(0, math.pi * 2)) * (shape.reach * math.sqrt(rng:NextNumber()))
		if onTop(shape, p, margin) and clear(p, radius, GAP) then
			return p
		end
	end
	return nil
end

-- A random point in open water off an island.
local function waterPoint(shape, rng, near, far, radius)
	for _ = 1, 12 do
		local p = shape.center + along(rng:NextNumber(0, math.pi * 2)) * (shape.island.r + rng:NextNumber(near, far))
		if not onLand(p, -(radius + 2)) and clear(p, radius, 3) then
			return p
		end
	end
	return nil
end

-- Planning: outlines, bridges, gameplay objects, then the pieces we place beside them ---------------------------

local function planBridges()
	for index, link in ipairs(L.links) do
		local a, b, kind, bend = L.byName[link[1]], L.byName[link[2]], link[3], link[4]
		local fa, fb = flat(a.pos), flat(b.pos)
		local dir = (fb - fa).Unit
		local from, to = fa + dir * (a.r - 3), fb - dir * (b.r - 3)
		local curve
		if kind == "boardwalk" then
			-- the kit's curved boardwalk: two straight runs meeting `bend` studs to the side
			curve = polyCurve({ from, (from + to) / 2 + Vector3.new(-dir.Z, 0, dir.X) * bend, to })
		else
			curve = bowCurve(from, to, bend)
		end
		local width = WIDTH[kind] or 7
		local _, startDir = curve.at(0)
		local _, endDir = curve.at(curve.length)
		local reach = { from - startDir * 6 }
		for _, p in ipairs(curve.points) do
			table.insert(reach, p)
		end
		table.insert(reach, to + endDir * 6)
		addCorridor(reach, width / 2)
		table.insert(bridges, { index = index, a = a, b = b, kind = kind, bend = bend, from = from, to = to, curve = curve, width = width })
	end
	local from, to = flat(L.causeway.from), flat(L.causeway.to)
	addCorridor({ from, to + (to - from).Unit * 8 }, L.causeway.width / 2)
end

local function blockGameplay()
	for _, at in ipairs(L.fishingSpots) do
		block(at, 4)
	end
	for _, nest in ipairs(L.eggNests) do
		block(nest.at, 3)
	end
	for _, at in ipairs(L.beacons) do
		block(at, 7)
	end
	for _, at in ipairs(L.tideCaches) do
		block(at, 3.5)
	end
	for _, at in ipairs(L.anemoneBeds) do
		block(at, 5.7)
	end
	for _, pair in ipairs(L.jumpPads) do
		for _, at in ipairs(pair) do
			block(at, 4.7)
			block(landingFrom(at), 3)
		end
	end
	block(L.ascend.Position, 4)
	block(L.diveSpawn.Position, 4)
end

-- Each geyser's sign stands beside its pad, on the side away from where the other geyser drops you.
local function planPadSigns()
	for i, pair in ipairs(L.jumpPads) do
		for k = 1, 2 do
			local here, there = flat(pair[k]), flat(pair[3 - k])
			local dir = (there - here).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X) * 5.8
			local landing = flat(landingFrom(here))
			local first, second = here + side, here - side
			if (second - landing).Magnitude > (first - landing).Magnitude then
				first, second = second, first
			end
			local shape = shapes[islandAt(here).name]
			local at = inShape(shape, first, shape.inset) and first or second
			padSigns[i .. ":" .. k] = at
			block(at, 1.2)
		end
	end
end

local function findHole(den, shape, angle)
	local center = shape.center
	for _, scale in ipairs({ 0.7, 0.6, 0.8, 0.5, 0.4, 0.3 }) do
		for _, turn in ipairs({ 0, 0.25, -0.25, 0.5, -0.5, 0.8, -0.8 }) do
			local p = flat(den.at) + along(angle + turn) * (den.radius * scale)
			if (p - center).Magnitude <= shape.island.r - 5 and covers(shape, p, 3, shape.inset) and clear(p, 3, GAP) then
				return p
			end
		end
	end
	warn(("ShoalsBuilder: no clear spot for a Moray hole near %s"):format(tostring(den.at)))
	return flat(den.at) + along(angle) * 4
end

-- Three Moray holes round each elite den, about 0.7 of its radius out, on land and clear of everything else.
local function planDenHoles()
	local rng = Random.new(2611)
	for i, den in ipairs(L.eliteDens) do
		local shape = shapes[islandAt(den.at).name]
		local phase = rng:NextNumber(0, math.pi * 2)
		local holes = {}
		for k = 1, 3 do
			holes[k] = findHole(den, shape, phase + k / 3 * math.pi * 2)
			block(holes[k], 3)
		end
		denHoles[i] = { island = shape.island, holes = holes }
	end
end

-- The Maelstrom's sign on Maelstrom Isle, between the island and the whirlpool, clear of the Ascend point.
local function planMaelstromSign()
	local shape = shapes[islandAt(L.maelstrom).name]
	local toward = (flat(L.maelstrom) - shape.center).Unit
	local base = math.atan2(toward.Z, toward.X)
	for _, distance in ipairs({ 20, 17, 23, 14 }) do
		for _, turn in ipairs({ 0.55, -0.55, 0.8, -0.8, 0.3, -0.3, 1.1, -1.1 }) do
			local p = shape.center + along(base + turn) * distance
			if covers(shape, p, 6.5, shape.inset) and clear(p, 6.5, GAP) then
				block(p, 6.5)
				return p
			end
		end
	end
	warn("ShoalsBuilder: no clear spot for the Maelstrom sign")
	return shape.center + toward * 12
end

local function plan()
	shapes, shapeList, blockers, corridors, bridges, padSigns, denHoles = {}, {}, {}, {}, {}, {}, {}
	local objects = landObjects()
	for index, island in ipairs(L.islands) do
		local shape = makeShape(index, island, objects)
		shapes[island.name] = shape
		table.insert(shapeList, shape)
	end
	planBridges()
	blockGameplay()
	planPadSigns()
	planDenHoles()
	maelstromSign = planMaelstromSign()
end

-- Pieces ------------------------------------------------------------------------------------------------------

local function newFolder(name, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A flat disk you can't bump (lily pads, moss, glows).
local function decorDisk(parent, name, center, radius, height, color, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Parent = parent,
	}
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return decor(props)
end

-- A soft ellipsoid: a sphere mesh on a block, so it can be squashed (clouds, foam).
local function blob(parent, name, cframe, size, color, extra)
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, CastShadow = false, Parent = parent }
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	local p = decor(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- TideboundFX turns it round `pivot`.
local function spin(p, pivot, speed)
	p:SetAttribute("Pivot", pivot)
	p:SetAttribute("SpinSpeed", speed)
	D.tag(p, "TideboundSpin")
	return p
end

-- A chunky coral clump standing in the shallows (the video's blocky coral).
local function coralClump(parent, at, rng)
	local color = CORAL[rng:NextInteger(1, #CORAL)]
	local s = rng:NextNumber(2.2, 3.6)
	local top = WATER_Y + rng:NextNumber(0.2, 1.3)
	local base = CFrame.new(at.X, top - s * 0.55, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	decor({ Name = "Coral", Size = Vector3.new(s, s * 1.1, s), CFrame = base, Color = color, Parent = parent })
	decor({ Name = "Coral", Size = Vector3.new(s * 0.6, s * 0.7, s * 0.6), CFrame = base * CFrame.new(s * 0.6, -s * 0.15, s * 0.3), Color = color:Lerp(Color3.new(1, 1, 1), 0.2), Parent = parent })
	if rng:NextNumber() < 0.6 then
		local h = rng:NextNumber(1.6, 3)
		local cf = base * CFrame.new(rng:NextNumber(-0.3, 0.3) * s, s * 0.55 + h / 2 - 0.2, rng:NextNumber(-0.3, 0.3) * s) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		decor({ Name = "CoralBranch", Size = Vector3.new(0.7, h, 0.7), CFrame = cf, Color = color:Lerp(Color3.new(1, 1, 1), 0.35), CastShadow = false, Parent = parent })
	end
end

-- A tall shard of dark rock on the Outer Reef's shore, leaning out over the water.
local function jaggedRock(parent, point, rng)
	local h = rng:NextNumber(4, 9)
	local w = rng:NextNumber(2.2, 4)
	local base = point.at + point.out * rng:NextNumber(0, 1.5)
	local mid = Vector3.new(base.X, WATER_Y - 0.5 + h / 2, base.Z)
	local cf = CFrame.lookAt(mid, mid + point.out) * CFrame.Angles(rng:NextNumber(-0.4, -0.1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.25, 0.25))
	decor({ Name = "JaggedRock", Size = Vector3.new(w, h, w * rng:NextNumber(0.6, 0.9)), CFrame = cf, Color = (rng:NextNumber() < 0.5) and V.ROCK or V.STONE_DARK, Material = Enum.Material.Slate, Parent = parent })
	if rng:NextNumber() < 0.45 then
		local h2 = h * rng:NextNumber(0.4, 0.7)
		decor({ Name = "JaggedRock", Size = Vector3.new(w * 0.6, h2, w * 0.6), CFrame = cf * CFrame.new(w * 0.6, (h2 - h) / 2, rng:NextNumber(-1, 1)) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)), Color = V.ROCK, Material = Enum.Material.Slate, Parent = parent })
	end
end

local function mossPatch(parent, at, radius, rng)
	decorDisk(parent, "Moss", Vector3.new(at.X, TOP + 0.05, at.Z), radius, 0.1, V.MOSS, { CastShadow = false })
	local off = along(rng:NextNumber(0, math.pi * 2)) * radius * 0.7
	decorDisk(parent, "Moss", Vector3.new(at.X + off.X, TOP + 0.08, at.Z + off.Z), radius * 0.6, 0.1, V.MOSS:Lerp(REEF_TUFT, 0.35), { CastShadow = false })
end

-- Rain falling from a dark sky over an Outer Reef island.
local function storm(parent, shape, rng)
	local c = shape.center
	local span = shape.island.r * 2
	local sky = decor({ Name = "RainCloud", Size = Vector3.new(span, 1, span), CFrame = CFrame.new(c.X, 62, c.Z), Transparency = 1, Parent = parent })
	particles(sky, {
		Color = ColorSequence.new(RAIN),
		LightEmission = 0.2,
		Rate = math.floor(shape.island.r * 3),
		Lifetime = NumberRange.new(0.7, 0.8),
		Speed = NumberRange.new(70, 80),
		Size = NumberSequence.new(0.14),
		Squash = NumberSequence.new(2.5),
		Transparency = NumberSequence.new(0.35),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(4, 4),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	for _ = 1, 5 do
		local s = rng:NextNumber(26, 44)
		local at = CFrame.new(c.X + rng:NextNumber(-0.4, 0.4) * span, rng:NextNumber(70, 80), c.Z + rng:NextNumber(-0.4, 0.4) * span)
		blob(parent, "StormCloud", at * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Vector3.new(s * 1.3, s * 0.32, s), CLOUD[rng:NextInteger(1, #CLOUD)], { Transparency = rng:NextNumber(0.05, 0.25) })
	end
end

-- Islands -----------------------------------------------------------------------------------------------------

local function checkerTiles(folder, shape)
	local tile = tileSize(shape.island)
	local c = shape.center
	local n = math.ceil(shape.reach / tile)
	for ix = -n, n do
		for iz = -n, n do
			local x, z = c.X + ix * tile, c.Z + iz * tile
			if tileOn(shape, x, z, tile) then
				part({ Name = "GrassTile", Size = Vector3.new(tile, 0.5, tile), CFrame = CFrame.new(x, TOP - 0.25, z), Color = ((ix + iz) % 2 == 0) and V.GRASS_A or V.GRASS_B, Parent = folder })
			end
		end
	end
end

-- Foundations from the sea floor (their tops are the shore band), and the ground on top at exactly TOP.
local function buildGround(folder, shape)
	local style = RING[shape.island.ring]
	local shoreTop = TOP - 0.5
	for _, lobe in ipairs(shape.lobes) do
		disk(folder, "Foundation", Vector3.new(lobe.c.X, (SEA_FLOOR + shoreTop) / 2, lobe.c.Z), lobe.r, shoreTop - SEA_FLOOR, style.shore, style.material)
		if style.top and lobe.r - style.inset >= 1.5 then
			disk(folder, "Ground", Vector3.new(lobe.c.X, TOP - 0.5, lobe.c.Z), lobe.r - style.inset, 1, style.top, style.material)
		end
	end
	if shape.island.ring == 2 then
		checkerTiles(folder, shape)
	end
end

-- Ring 1 (REF 2): mint rocks ringing the shore, daisies and tufts on the grass, clovers floating off the shore.
local function decorateShallows(folder, shape, rng)
	for i, point in ipairs(coast(shape, 7.5)) do
		local scale = (i % 6 == 0) and 1.8 or rng:NextNumber(1, 1.4)
		if rng:NextNumber() < 0.88 and clear(point.at, 2.5 * scale, GAP) then
			K.mintRock(folder, Vector3.new(point.at.X, TOP - 0.6, point.at.Z) + point.out * rng:NextNumber(-0.5, 1), rng, scale)
		end
	end
	for _ = 1, 3 do
		local p = landPoint(shape, rng, 2, 1.5)
		if p then
			K.daisies(folder, Vector3.new(p.X, TOP, p.Z), rng)
		end
	end
	for _ = 1, 6 do
		local p = landPoint(shape, rng, 1, 1)
		if p then
			D.tuft(folder, Vector3.new(p.X, TOP, p.Z), rng, SHALLOW_TUFT, SHALLOW_TIP)
		end
	end
	local points = coast(shape, 23)
	for _ = 1, 2 do
		local point = points[rng:NextInteger(1, math.max(1, #points))]
		if point then
			local p = point.at + point.out * rng:NextNumber(5, 8)
			if not onLand(p, -3.5) and clear(p, 3.5, 2) then
				K.clovers(folder, p, rng)
			end
		end
	end
end

-- Studded orange paths (the video): spokes in from each bridge, geyser, beacon and cache to a loop round the
-- island's middle (round the open water on Puffer Lagoon).
local function mazePaths(folder, shape)
	local island = shape.island
	local center = shape.center
	local hubR = shape.hole and (LAGOON_HOLE + island.r) / 2 or island.r * 0.32
	local y = TOP + 0.05
	local spokes = {}
	local function spoke(at, stop)
		local offset = flat(at) - center
		if offset.Magnitude - stop > hubR + 2 then
			local dir = offset.Unit
			table.insert(spokes, math.atan2(dir.Z, dir.X))
			D.studPath(folder, center + dir * (offset.Magnitude - stop), center + dir * hubR, 5, y)
		end
	end
	for _, bridge in ipairs(bridges) do
		if bridge.a == island then
			spoke(bridge.from, 1.5)
		elseif bridge.b == island then
			spoke(bridge.to, 1.5)
		end
	end
	for _, pair in ipairs(L.jumpPads) do
		for _, at in ipairs(pair) do
			if islandAt(at) == island then
				spoke(at, 6)
			end
		end
	end
	for _, at in ipairs(L.beacons) do
		if islandAt(at) == island then
			spoke(at, 7.5)
		end
	end
	for _, at in ipairs(L.tideCaches) do
		if islandAt(at) == island then
			spoke(at, 5)
		end
	end
	if #spokes < 2 then
		return
	end
	-- the loop goes the long way round, leaving out the widest gap between spokes
	table.sort(spokes)
	local widest, from = -1, 1
	for i = 1, #spokes do
		local gap = (i < #spokes) and (spokes[i + 1] - spokes[i]) or (spokes[1] + math.pi * 2 - spokes[i])
		if gap > widest then
			widest, from = gap, i % #spokes + 1
		end
	end
	local sweep = math.pi * 2 - widest
	if sweep < 0.1 then
		return
	end
	local steps = math.ceil(sweep / math.rad(40))
	for k = 0, steps - 1 do
		local p1 = center + along(spokes[from] + sweep * k / steps) * hubR
		local p2 = center + along(spokes[from] + sweep * (k + 1) / steps) * hubR
		local dir = (p2 - p1).Unit
		D.studPath(folder, p1 - dir * 1.2, p2 + dir * 1.2, 5, y)
	end
end

-- Ring 2 (the video): paths, chunky grass tufts, coral clumps in the shallows round the beach.
local function decorateMaze(folder, shape, rng)
	mazePaths(folder, shape)
	for _ = 1, 9 do
		local p = landPoint(shape, rng, 1, 1)
		if p then
			D.tuft(folder, Vector3.new(p.X, TOP, p.Z), rng, MAZE_TUFT, MAZE_TIP)
		end
	end
	for _, point in ipairs(coast(shape, 15)) do
		local p = point.at + point.out * rng:NextNumber(2.5, 5.5)
		if not onLand(p, -1.5) and clear(p, 2.5, 3) then
			coralClump(folder, p, rng)
		end
	end
end

-- Ring 3 (stormy): jagged rocks on the shore, moss on the rock, rain and storm clouds overhead.
local function decorateReef(folder, shape, rng)
	for _, point in ipairs(coast(shape, 9)) do
		if rng:NextNumber() < 0.85 and clear(point.at, 2.5, GAP) then
			jaggedRock(folder, point, rng)
		end
	end
	for _ = 1, 6 do
		local radius = rng:NextNumber(2.5, 4.5)
		local p = landPoint(shape, rng, radius * 1.3 + 0.5, radius * 1.3)
		if p then
			mossPatch(folder, p, radius, rng)
		end
	end
	for _ = 1, 4 do
		local p = landPoint(shape, rng, 1, 1)
		if p then
			D.tuft(folder, Vector3.new(p.X, TOP, p.Z), rng, REEF_TUFT, V.MOSS)
		end
	end
	storm(folder, shape, rng)
end

local function buildIslands(root)
	for index, island in ipairs(L.islands) do
		local shape = shapes[island.name]
		local folder = newFolder(island.name, root)
		folder:SetAttribute("Title", island.title)
		folder:SetAttribute("Ring", island.ring)
		buildGround(folder, shape)
		-- onLand and isClear are optional helpers for IsleFeatures
		local ctx = {
			rng = Random.new(3000 + index * 71),
			top = TOP,
			onLand = function(position, margin)
				return inShape(shape, position, shape.inset + (margin or 0))
			end,
			isClear = function(position, radius)
				return clear(position, radius or 1, GAP)
			end,
		}
		local ok, err = pcall(IsleFeatures.build, folder, island, ctx)
		if not ok then
			warn(("ShoalsBuilder: IsleFeatures failed on %s: %s"):format(island.name, tostring(err)))
		end
		local rng = Random.new(2000 + index * 53)
		if island.ring == 1 then
			decorateShallows(folder, shape, rng)
		elseif island.ring == 2 then
			decorateMaze(folder, shape, rng)
		else
			decorateReef(folder, shape, rng)
		end
	end
end

-- The sea -----------------------------------------------------------------------------------------------------

-- Terrain water from the sea floor up to WATER_Y over the whole rectangle, on 4 studs of sand, in 512 tiles.
local function fillSea()
	local terrain = workspace.Terrain
	local sea = L.sea
	local x = sea.min.X
	while x < sea.max.X do
		local w = math.min(512, sea.max.X - x)
		local z = sea.min.Z
		while z < sea.max.Z do
			local d = math.min(512, sea.max.Z - z)
			terrain:FillBlock(CFrame.new(x + w / 2, (sea.floorY + WATER_Y) / 2, z + d / 2), Vector3.new(w, WATER_Y - sea.floorY, d), Enum.Material.Water)
			terrain:FillBlock(CFrame.new(x + w / 2, sea.floorY - 2, z + d / 2), Vector3.new(w, 4, d), Enum.Material.Sand)
			z += d
		end
		x += w
	end
end

local function seagrass(parent, at, rng)
	for _ = 1, 3 do
		local h = rng:NextNumber(2, 3.5)
		local base = at + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		D.windy(decor({ Name = "Seagrass", Size = Vector3.new(0.35, h, 0.35), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = SEAGRASS, CastShadow = false, Parent = parent }))
	end
end

-- A sand bar rising to just under the surface off an island, with seagrass (and coral on the Coral Maze).
local function sandBar(parent, shape, rng)
	local terrain = workspace.Terrain
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local c = shape.center + along(a) * (shape.island.r + rng:NextNumber(6, 16))
		if not onLand(c, -4) and (c - flat(L.maelstrom)).Magnitude > 45 then
			local tangent = along(a + math.pi / 2)
			local top = rng:NextNumber(-2.4, -1.2)
			for k = -1, 1 do
				local radius = rng:NextNumber(5, 7.5) * (k == 0 and 1.2 or 1)
				local p = c + tangent * (k * 7)
				terrain:FillBall(Vector3.new(p.X, top - radius, p.Z), radius, Enum.Material.Sand)
			end
			seagrass(parent, Vector3.new(c.X, top - 0.4, c.Z), rng)
			if shape.island.ring == 2 then
				for _ = 1, 2 do
					local s = rng:NextNumber(1, 1.8)
					local p = c + tangent * rng:NextNumber(-5, 5)
					decor({ Name = "Coral", Size = Vector3.new(s, s * 1.2, s), CFrame = CFrame.new(p.X, top + s * 0.4, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = CORAL[rng:NextInteger(1, #CORAL)], Parent = parent })
				end
			end
			return
		end
	end
end

-- Depth near the islands: a sand shelf round each island's foot, sand bars, and rocks on the floor.
local function buildSeabed(root)
	local folder = newFolder("Seabed", root)
	local terrain = workspace.Terrain
	local rng = Random.new(6203)
	for _, shape in ipairs(shapeList) do
		local ring = shape.island.ring
		local shelf = RING[ring].shelf
		local c = shape.center
		terrain:FillCylinder(CFrame.new(c.X, (SEA_FLOOR - 4 + shelf) / 2, c.Z), shelf - SEA_FLOOR + 4, shape.reach + 12, Enum.Material.Sand)
		if ring < 3 then
			sandBar(folder, shape, rng)
			sandBar(folder, shape, rng)
		end
		for _ = 1, 3 do
			local p = c + along(rng:NextNumber(0, math.pi * 2)) * (shape.island.r + rng:NextNumber(3, 14))
			if (p - flat(L.maelstrom)).Magnitude > 45 then
				terrain:FillBall(Vector3.new(p.X, shelf - 1, p.Z), rng:NextNumber(3, 5.5), ring == 3 and Enum.Material.Basalt or Enum.Material.Rock)
			end
		end
	end
end

-- Bridges -----------------------------------------------------------------------------------------------------

local function seedOf(a, b)
	return math.floor(math.abs(a.X * 7 + a.Z * 13 + b.X * 3 + b.Z)) % 1000003
end

-- The video's plank bridge: separate planks with small gaps on cross beams, posts on stilts down to the sea
-- floor and a rail along each side. a and b are the ends (flat); the walk is at TOP.
local function plankBridge(parent, a, b, width, bend)
	local curve = bowCurve(a, b, bend)
	local rng = Random.new(seedOf(a, b))
	local length = curve.length
	local count = math.floor(length / PLANK_PITCH)
	local start = (length - (count - 1) * PLANK_PITCH) / 2
	for i = 0, count - 1 do
		local pos, dir = curve.at(start + i * PLANK_PITCH)
		local cf = CFrame.lookAt(Vector3.new(pos.X, TOP - 0.25, pos.Z), Vector3.new(pos.X + dir.X, TOP - 0.25, pos.Z + dir.Z)) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0)
		part({ Name = "Plank", Size = Vector3.new(width - rng:NextNumber(0, 0.5), 0.5, PLANK_DEPTH), CFrame = cf, Color = PLANKS[rng:NextInteger(1, #PLANKS)], Parent = parent })
	end
	local spans = math.max(1, math.floor(length / 16 + 0.5))
	local height = TOP + 3 - SEA_FLOOR
	local previous = nil
	for k = 0, spans do
		local pos, dir = curve.at(length * k / spans)
		local frame = CFrame.lookAt(Vector3.new(pos.X, TOP, pos.Z), Vector3.new(pos.X + dir.X, TOP, pos.Z + dir.Z))
		local tops = {}
		for _, side in ipairs({ -1, 1 }) do
			local base = frame * CFrame.new(side * (width / 2 + 0.35), 0, 0)
			part({ Name = "Stilt", Size = Vector3.new(0.9, height, 0.9), CFrame = base * CFrame.new(0, 3 - height / 2, 0), Color = P.PLANK_EDGE, Parent = parent })
			tops[side] = (base * CFrame.new(0, 2.7, 0)).Position
		end
		part({ Name = "CrossBeam", Size = Vector3.new(width + 1.6, 0.5, 0.7), CFrame = frame * CFrame.new(0, -0.8, 0), Color = P.PLANK_EDGE, Parent = parent })
		if previous then
			for _, side in ipairs({ -1, 1 }) do
				local p0, p1 = previous[side], tops[side]
				part({ Name = "Rail", Size = Vector3.new(0.45, 0.45, (p1 - p0).Magnitude + 0.45), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = P.PLANK, Parent = parent })
			end
		end
		previous = tops
	end
	return curve
end

-- The Outer Reef's rope bridge: a narrow plank walk that sags between posts, rope rails, a few planks missing
-- (never two together, so no gap is wider than 1.44 studs).
local function ropeBridge(parent, a, b, width, bend)
	local curve = bowCurve(a, b, bend)
	local rng = Random.new(seedOf(a, b))
	local length = curve.length
	local spans = math.max(1, math.floor(length / 22 + 0.5))
	local spanLength = length / spans
	local function walkY(s)
		return TOP - ROPE_SAG * math.sin(math.pi * ((s % spanLength) / spanLength))
	end
	local count = math.floor(length / ROPE_PITCH)
	local start = (length - (count - 1) * ROPE_PITCH) / 2
	local missing = {}
	for i = 1, count - 2 do
		local s = start + i * ROPE_PITCH
		if not missing[i - 1] and s > 8 and s < length - 8 and rng:NextNumber() < 0.045 then
			missing[i] = true
		end
	end
	for i = 0, count - 1 do
		if not missing[i] then
			local s = start + i * ROPE_PITCH
			local pos, dir = curve.at(s)
			local y = walkY(s) - 0.2
			local slope = walkY(s + 0.5) - walkY(s - 0.5)
			local steady = missing[i - 1] or missing[i + 1]
			local cf = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X + dir.X, y + slope, pos.Z + dir.Z))
			if not steady then
				cf *= CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.04, 0.04))
			end
			part({ Name = "Plank", Size = Vector3.new(width - (steady and 0 or rng:NextNumber(0, 0.6)), 0.4, ROPE_DEPTH), CFrame = cf, Color = PLANKS[rng:NextInteger(2, #PLANKS)]:Lerp(WET_WOOD, 0.35), Parent = parent })
		end
	end
	local height = TOP + 3.4 - SEA_FLOOR
	local previous = nil
	for k = 0, spans do
		local pos, dir = curve.at(spanLength * k)
		local frame = CFrame.lookAt(Vector3.new(pos.X, TOP, pos.Z), Vector3.new(pos.X + dir.X, TOP, pos.Z + dir.Z))
		local thick = (k == 0 or k == spans) and 1.2 or 0.75
		local tops = {}
		for _, side in ipairs({ -1, 1 }) do
			local base = frame * CFrame.new(side * (width / 2 + 0.4), 0, 0)
			part({ Name = "RopePost", Size = Vector3.new(thick, height, thick), CFrame = base * CFrame.new(0, 3.4 - height / 2, 0), Color = WET_WOOD, Parent = parent })
			tops[side] = (base * CFrame.new(0, 3.1, 0)).Position
		end
		if previous then
			for _, side in ipairs({ -1, 1 }) do
				local sag = (previous[side] + tops[side]) / 2 - Vector3.new(0, 1.3, 0)
				rod(parent, previous[side], sag, 0.35, P.ROPE)
				rod(parent, sag, tops[side], 0.35, P.ROPE)
			end
		end
		previous = tops
	end
	return curve
end

-- A landing slab at each end, a hair above the walk, so deck and ground never fight where they overlap.
local function bridgeHeads(parent, bridge)
	local curve = bridge.curve
	local _, startDir = curve.at(0)
	local _, endDir = curve.at(curve.length)
	for _, side in ipairs({ { bridge.from, startDir }, { bridge.to, -endDir } }) do
		local center = side[1] + side[2] * 0.25
		local y = TOP - 0.13
		local cf = CFrame.lookAt(Vector3.new(center.X, y, center.Z), Vector3.new(center.X + side[2].X, y, center.Z + side[2].Z))
		if bridge.kind == "boardwalk" then
			part({ Name = "Landing", Size = Vector3.new(bridge.width + 0.8, 0.5, 4.5), CFrame = cf, Color = P.DECK, Parent = parent })
		elseif bridge.kind == "plank" then
			part({ Name = "Landing", Size = Vector3.new(bridge.width + 1.2, 0.5, 4.5), CFrame = cf, Color = P.PLANK_EDGE, Parent = parent })
		else
			part({ Name = "Landing", Size = Vector3.new(bridge.width + 2, 0.5, 4.5), CFrame = cf, Color = V.STONE_DARK, Material = Enum.Material.Slate, Parent = parent })
		end
	end
end

-- Old stumps of a fallen bridge poking out of the water (Outer Reef).
local function brokenPost(parent, at, rng)
	local top = WATER_Y + rng:NextNumber(1.5, 4.5)
	local height = top - SEA_FLOOR
	local cf = CFrame.new(at.X, SEA_FLOOR + height / 2, at.Z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 3), rng:NextNumber(-0.12, 0.12))
	decor({ Name = "BrokenPost", Size = Vector3.new(0.9, height, 0.9), CFrame = cf, Color = WET_WOOD, Parent = parent })
	if rng:NextNumber() < 0.6 then
		local tip = (cf * CFrame.new(0, height / 2 - 0.4, 0)).Position
		rod(parent, tip, tip + Vector3.new(rng:NextNumber(-1, 1), -2.2, rng:NextNumber(-1, 1)), 0.25, P.ROPE)
	end
end

local function bridgeDecor(parent, bridge, rng)
	local curve = bridge.curve
	local function beside(t, offset)
		local pos, dir = curve.at(curve.length * t)
		return pos + Vector3.new(-dir.Z, 0, dir.X) * offset
	end
	local half = bridge.width / 2
	if bridge.kind == "boardwalk" then
		-- lime bamboo standing in the water beside the boardwalk, clovers floating by it (REF 2)
		K.bambooCluster(parent, beside(0.3, half + 6) + Vector3.new(0, -4, 0), rng)
		K.bambooCluster(parent, beside(0.68, -(half + 6.5)) + Vector3.new(0, -4, 0), rng)
		K.clovers(parent, beside(0.5, half + 7), rng)
	elseif bridge.kind == "plank" then
		coralClump(parent, beside(0.27, half + 4.5), rng)
		coralClump(parent, beside(0.6, -(half + 5)), rng)
	else
		for i, t in ipairs({ 0.22, 0.5, 0.78 }) do
			brokenPost(parent, beside(t, (i % 2 == 0 and -1 or 1) * (half + rng:NextNumber(5, 9))), rng)
		end
	end
end

local function buildBridges(root)
	local folder = newFolder("Bridges", root)
	for _, bridge in ipairs(bridges) do
		local f = newFolder(bridge.a.name .. "To" .. bridge.b.name, folder)
		f:SetAttribute("Kind", bridge.kind)
		if bridge.kind == "boardwalk" then
			K.curvedBoardwalk(f, bridge.from, bridge.to, bridge.width, bridge.bend)
		elseif bridge.kind == "plank" then
			plankBridge(f, bridge.from, bridge.to, bridge.width, bridge.bend)
		else
			ropeBridge(f, bridge.from, bridge.to, bridge.width, bridge.bend)
		end
		bridgeHeads(f, bridge)
		bridgeDecor(f, bridge, Random.new(4000 + bridge.index * 29))
	end
	-- a stone landing where the causeway from town meets Landing Reef
	local from, to = flat(L.causeway.from), flat(L.causeway.to)
	local dir = (to - from).Unit
	local at = to + dir * 1.5
	part({ Name = "CausewayLanding", Size = Vector3.new(L.causeway.width + 2, 0.5, 7), CFrame = CFrame.lookAt(Vector3.new(at.X, TOP - 0.13, at.Z), Vector3.new(at.X + dir.X, TOP - 0.13, at.Z + dir.Z)), Color = P.MINT_ROCK, Parent = folder })
end

-- Geyser jump pads -----------------------------------------------------------------------------------------

local function jumpPad(parent, name, here, there, signAt)
	local pivot = Vector3.new(here.X, TOP, here.Z)
	local pad = part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 8, 8),
		CFrame = CFrame.new(pivot + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GEYSER,
		Material = Enum.Material.Plastic,
		Parent = parent,
	})
	pad.TopSurface = Enum.SurfaceType.Studs
	pad.RightSurface = Enum.SurfaceType.Studs -- a cylinder's top face, once it stands upright
	pad:SetAttribute("Target", landingFrom(there))
	D.tag(pad, "TideboundJumpPad")
	decorDisk(parent, "PadRing", pivot + Vector3.new(0, 0.02, 0), 4.7, 0.5, GEYSER_GLOW, { Material = Enum.Material.Neon, CastShadow = false })
	decorDisk(parent, "PadCore", pivot + Vector3.new(0, 0.38, 0), 1.8, 0.06, Color3.new(1, 1, 1), { Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false })
	light(pad, GEYSER, 14, 1)
	particles(pad, {
		Color = ColorSequence.new(GEYSER_GLOW, Color3.new(1, 1, 1)),
		LightEmission = 0.5,
		Rate = 14,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(7, 13),
		SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(0, -16, 0),
		Size = NumberSequence.new(0.55, 0.15),
		Transparency = NumberSequence.new(0.15, 1),
		EmissionDirection = Enum.NormalId.Right,
	})
	-- a little GEYSER sign beside it, its arrow pointing at the far end
	local dir = (flat(there) - flat(here)).Unit
	decor({ Name = "SignPost", Size = Vector3.new(0.6, 4.2, 0.6), CFrame = CFrame.new(signAt.X, TOP + 2.1, signAt.Z), Color = P.POST, Parent = parent })
	local boardCf = CFrame.fromMatrix(Vector3.new(signAt.X, TOP + 3.7, signAt.Z), dir, Vector3.new(0, 1, 0)) * CFrame.new(0.4, 0, 0)
	local board = decor({ Name = "GeyserSign", Size = Vector3.new(4.6, 1.3, 0.25), CFrame = boardCf, Color = P.LAMP_WOOD, Parent = parent })
	decor({ Name = "GeyserArrow", Size = Vector3.new(1.3, 1.3, 0.25), CFrame = boardCf * CFrame.new(2.4, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = P.LAMP_WOOD, Parent = parent })
	K.surfaceText(board, "GEYSER", GEYSER_GLOW, Enum.NormalId.Front)
	K.surfaceText(board, "GEYSER", GEYSER_GLOW, Enum.NormalId.Back)
	return pad
end

local function buildJumpPads(root)
	local folder = newFolder("JumpPads", root)
	for i, pair in ipairs(L.jumpPads) do
		for k = 1, 2 do
			local pad = jumpPad(folder, ("Geyser%d%s"):format(i, k == 1 and "A" or "B"), pair[k], pair[3 - k], padSigns[i .. ":" .. k])
			pad:SetAttribute("Pair", i)
		end
	end
end

-- Gameplay objects ------------------------------------------------------------------------------------------

-- Foam blobs circling a fishing spot and a pale bubbling ring round it, so spots read from far away.
local function foamRing(parent, at)
	local c = Vector3.new(at.X, WATER_Y + 0.12, at.Z)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local foam = blob(parent, "Foam", CFrame.new(c + along(a) * 5.4) * CFrame.Angles(0, -a, 0), Vector3.new(1.1, 0.35, 1.7), FOAM, { Material = Enum.Material.Neon, Transparency = 0.25 })
		spin(foam, c, 0.35)
	end
	local ring = decorDisk(parent, "FoamRing", c - Vector3.new(0, 0.06, 0), 6.2, 0.1, FOAM, { Transparency = 0.7, CastShadow = false })
	particles(ring, {
		Color = ColorSequence.new(FOAM),
		LightEmission = 0.3,
		Rate = 5,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(1, 2.5),
		Size = NumberSequence.new(0.45, 0.1),
		Transparency = NumberSequence.new(0.2, 1),
		EmissionDirection = Enum.NormalId.Right,
	})
end

local function buildFishingSpots(root)
	local folder = newFolder("FishingSpots", root)
	local foam = newFolder("Foam", folder)
	for i, at in ipairs(L.fishingSpots) do
		D.fishingSpot(folder, i, at, WATER_Y, 1)
		foamRing(foam, at)
	end
end

local function buildEggNests(root)
	local folder = newFolder("EggNests", root)
	for i, nest in ipairs(L.eggNests) do
		D.wildEgg(folder, i, nest.at, nest.y or TOP)
	end
end

local function buildBeacons(root)
	local folder = newFolder("Beacons", root)
	for i, at in ipairs(L.beacons) do
		D.beacon(folder, i, at, TOP, 1)
	end
end

-- A soft green ring of light at the healing radius (Config.Isles.cacheRadius), turning slowly.
local function healingRing(parent, at)
	local radius = Config.Isles.cacheRadius
	local pivot = Vector3.new(at.X, TOP + 0.12, at.Z)
	local shape = shapes[islandAt(at).name]
	local count = 20
	for i = 1, count do
		local a = i / count * math.pi * 2
		local p = pivot + along(a) * radius
		if inShape(shape, p, 0) then
			local segment = decor({ Name = "HealRing", Size = Vector3.new(0.5, 0.1, 2 * math.pi * radius / count * 0.7), CFrame = CFrame.new(p) * CFrame.Angles(0, -a, 0), Color = HEAL, Material = Enum.Material.Neon, Transparency = 0.35, CastShadow = false, Parent = parent })
			spin(segment, pivot, 0.2)
		end
	end
	local glow = decor({ Name = "HealGlow", Size = Vector3.new(radius * 1.6, 0.2, radius * 1.6), CFrame = CFrame.new(pivot + Vector3.new(0, 0.2, 0)), Transparency = 1, Parent = parent })
	light(glow, HEAL, radius + 6, 0.7)
	particles(glow, {
		Color = ColorSequence.new(HEAL),
		LightEmission = 0.8,
		Rate = 6,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.6, 1.4),
		Size = NumberSequence.new(0.25, 0),
		Transparency = NumberSequence.new(0.2, 1),
		EmissionDirection = Enum.NormalId.Top,
	})
end

-- The Tide Cache (ported from the old Shoals): a life-ring buoy post with a lantern and the chest. Bank your
-- catch here; standing near one heals (Main reads the TideboundCache tag).
local function tideCache(parent, at)
	local cacheAt = Vector3.new(at.X, TOP, at.Z)
	disk(parent, "CacheBase", cacheAt + Vector3.new(0, 0.4, 0), 3.4, 0.8, P.MINT_ROCK)
	part({ Name = "CachePost", Size = Vector3.new(0.8, 8, 0.8), CFrame = CFrame.new(cacheAt + Vector3.new(0, 4.6, 0)), Color = P.POST, Parent = parent })
	part({ Name = "CacheArm", Size = Vector3.new(3.4, 0.5, 0.5), CFrame = CFrame.new(cacheAt + Vector3.new(1.4, 8.4, 0)), Color = P.POST, Parent = parent })
	K.crystalLantern(parent, cacheAt + Vector3.new(2.8, 8.2, 0), 1.2)
	local ring = decor({ Name = "CacheRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5.6, 5.6), CFrame = CFrame.new(cacheAt + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 120, 80), Parent = parent })
	decor({ Name = "CacheRingHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 3.8, 3.8), CFrame = ring.CFrame, Color = P.MINT_ROCK, Parent = parent })
	local chest = part({ Name = "TideCache", Size = Vector3.new(3, 2.2, 2.2), CFrame = CFrame.new(cacheAt + Vector3.new(0, 2.7, 0)), Color = P.PLANK, Material = Enum.Material.WoodPlanks, Parent = parent })
	decor({ Name = "CacheLid", Size = Vector3.new(3.2, 0.5, 2.4), CFrame = chest.CFrame * CFrame.new(0, 1.3, 0), Color = P.GOLD, Parent = parent })
	light(chest, P.BEACON, 14, 1)
	K.sparkles(chest, Color3.fromRGB(200, 255, 240), 4)
	K.prompt(chest, "Bank Catch", "Tide Cache", { Action = "BankCatch" }, 1, 12)
	K.billboard(chest, "TIDE CACHE", "Bank fish and heal here", 5)
	D.tag(chest, "TideboundCache")
	healingRing(parent, at)
end

local function buildTideCaches(root)
	local folder = newFolder("TideCaches", root)
	for i, at in ipairs(L.tideCaches) do
		tideCache(newFolder("TideCache" .. i, folder), at)
	end
end

-- Stinging Anemone Beds (ported): an 8 x 8 pad Threats stings you on, stalks with glowing tips.
local function buildAnemoneBeds(root)
	local folder = newFolder("AnemoneBeds", root)
	local rng = Random.new(2613)
	for _, at in ipairs(L.anemoneBeds) do
		local pad = decor({ Name = "AnemoneBed", Size = Vector3.new(8, 0.3, 8), CFrame = CFrame.new(at.X, TOP + 0.35, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = ANEMONE_BASE, Parent = folder })
		D.tag(pad, "TideboundAnemone")
		for _ = 1, 9 do
			local h = rng:NextNumber(0.8, 1.8)
			local stalk = pad.CFrame * CFrame.new(rng:NextNumber(-3.3, 3.3), h / 2, rng:NextNumber(-3.3, 3.3))
			decor({ Name = "Stalk", Size = Vector3.new(0.4, h, 0.4), CFrame = stalk, Color = ANEMONE_BASE, Parent = folder })
			decor({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = stalk * CFrame.new(0, h / 2, 0), Color = ANEMONE_TIP, Material = Enum.Material.Neon, CastShadow = false, Parent = folder })
		end
	end
end

-- Elite dens (Barnacle Brute or Snapjaw Moray): an invisible marker with its roam Radius, holding three Moray
-- holes (Hole = true) for Threats.
local function buildEliteDens(root)
	local folder = newFolder("EliteDens", root)
	local rng = Random.new(2612)
	for i, den in ipairs(L.eliteDens) do
		local plan = denHoles[i]
		local slot = decor({ Name = "EliteDen" .. i, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(den.at.X, TOP + 1, den.at.Z), Transparency = 1, Parent = folder })
		slot:SetAttribute("Radius", den.radius)
		slot:SetAttribute("Island", plan.island.name)
		D.tag(slot, "TideboundEliteDen")
		for j, at in ipairs(plan.holes) do
			local base = Vector3.new(at.X, TOP, at.Z)
			disk(slot, "HoleRim", base + Vector3.new(0, 0.6, 0), 2.4, 1.2, CORAL_DARK).CanCollide = false
			local glow = disk(slot, "MorayHole" .. j, base + Vector3.new(0, 1.25, 0), 1.6, 0.15, Color3.fromRGB(255, 190, 70))
			glow.CanCollide = false
			glow.CanQuery = false
			glow.CastShadow = false
			glow.Material = Enum.Material.Neon
			glow.Transparency = 0.7
			glow:SetAttribute("Hole", true)
			for _ = 1, 3 do
				local b = rng:NextNumber(0, math.pi * 2)
				decor({ Name = "Coral", Size = Vector3.new(0.5, rng:NextNumber(1, 2.2), 0.5), CFrame = CFrame.new(base + Vector3.new(math.cos(b) * 2.6, 1.2, math.sin(b) * 2.6)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(255, 140, 120), Parent = slot })
			end
		end
	end
end

-- The Reef Warden in its lair, and its patrol (WP01, WP02 ... at hover height).
local function buildWarden(root)
	local warden = K.reefWarden(root, L.wardenLair)
	warden.Name = "ReefWarden"
	local path = newFolder("WardenPath", root)
	local count = #L.wardenPath
	if count > 1 and L.wardenPath[count] == L.wardenPath[1] then
		count -= 1
	end
	for i = 1, count do
		local p = L.wardenPath[i]
		part({ Name = ("WP%02d"):format(i), Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(p.X, 8, p.Z), Transparency = 1, CanCollide = false, CanQuery = false, Parent = path })
	end
end

-- The Maelstrom in the water east of Maelstrom Isle (its standing stones give way to the bridges), and the sign.
local function buildMaelstrom(root)
	local folder = newFolder("Maelstrom", root)
	D.maelstrom(folder, L.maelstrom, Random.new(4401))
	local removed = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "StandingStone" and nearCorridor(flat(child.Position), 3) then
			table.insert(removed, flat(child.Position))
			child:Destroy()
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "Rune" then
			for _, gone in ipairs(removed) do
				if (flat(child.Position) - gone).Magnitude < 3 then
					child:Destroy()
					break
				end
			end
		end
	end
	local signPos = Vector3.new(maelstromSign.X, TOP + 5, maelstromSign.Z)
	local look = Vector3.new(L.maelstrom.X, TOP + 5, L.maelstrom.Z)
	-- the text faces back over the island, so you read it looking out at the whirlpool
	local board = part({ Name = "MaelstromSign", Size = Vector3.new(12, 5, 0.6), CFrame = CFrame.lookAt(signPos, look) * CFrame.Angles(0, math.pi, 0), Color = SIGN_DARK, Parent = folder })
	K.surfaceText(board, "THE MAELSTROM\nPush deeper at a beacon to dive to Kelp Cathedral", V.RUNE)
	decor({ Name = "SignNeon", Size = Vector3.new(12.6, 0.3, 0.3), CFrame = board.CFrame * CFrame.new(0, 2.7, 0), Color = V.RUNE, Material = Enum.Material.Neon, CastShadow = false, Parent = folder })
	for _, x in ipairs({ -5, 5 }) do
		part({ Name = "SignPost", Size = Vector3.new(0.8, 5, 0.8), CFrame = board.CFrame * CFrame.new(x, -4, 0), Color = V.HULL_DARK, Parent = folder })
	end
end

-- Life in the water -----------------------------------------------------------------------------------------

local function school(parent, shape, rng)
	local colors = SCHOOL_COLORS[shape.island.ring]
	for _ = 1, 10 do
		local p = shape.center + along(rng:NextNumber(0, math.pi * 2)) * (shape.island.r + rng:NextNumber(12, 22))
		if not onLand(p, -10) then
			local anchor = decor({ Name = "School", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(p.X, WATER_Y - 2.5, p.Z), Transparency = 1, Parent = parent })
			anchor:SetAttribute("Radius", rng:NextNumber(6, 10))
			anchor:SetAttribute("Count", rng:NextInteger(6, 10))
			anchor:SetAttribute("Color", colors[rng:NextInteger(1, #colors)])
			D.tag(anchor, "TideboundSchool")
			return
		end
	end
end

local function lilyPads(parent, at, rng)
	for k = 0, rng:NextInteger(1, 3) do
		local p = at + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		local y = WATER_Y + 0.08 + k * 0.04
		decorDisk(parent, "LilyPad", Vector3.new(p.X, y, p.Z), rng:NextNumber(1, 1.7), 0.15, LILY[rng:NextInteger(1, #LILY)], { CastShadow = false })
		if rng:NextNumber() < 0.25 then
			decor({ Name = "LilyFlower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(p.X, y + 0.4, p.Z), Color = LILY_FLOWER, CastShadow = false, Parent = parent })
		end
	end
end

local function bambooLog(parent, at, rng)
	local length = rng:NextNumber(8, 13)
	local cf = CFrame.new(at.X, WATER_Y + 0.25, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	decor({ Name = "BambooLog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, 1, 1), CFrame = cf, Color = P.BAMBOO, Parent = parent })
	for _, x in ipairs({ -length * 0.25, length * 0.2 }) do
		decor({ Name = "BambooNode", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.15, 1.15), CFrame = cf * CFrame.new(x, 0, 0), Color = P.BAMBOO:Lerp(Color3.fromRGB(120, 170, 70), 0.35), Parent = parent })
	end
end

local function barrel(parent, at, rng)
	local cf = CFrame.new(at.X, WATER_Y + 0.35, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15))
	decor({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2, 2), CFrame = cf, Color = V.HULL, Parent = parent })
	for _, x in ipairs({ -0.8, 0.8 }) do
		decor({ Name = "BarrelBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.08, 2.08), CFrame = cf * CFrame.new(x, 0, 0), Color = Color3.fromRGB(60, 60, 66), Parent = parent })
	end
end

local function debris(parent, at, rng)
	for _ = 1, rng:NextInteger(2, 3) do
		local p = at + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		decor({ Name = "Driftwood", Size = Vector3.new(1.2, 0.35, rng:NextNumber(4, 6.5)), CFrame = CFrame.new(p.X, WATER_Y + 0.1, p.Z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15)), Color = PLANKS[3]:Lerp(WET_WOOD, 0.5), Parent = parent })
	end
end

local function buoy(parent, at, color)
	local base = Vector3.new(at.X, WATER_Y, at.Z)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	decor({ Name = "Buoy", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8), CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * upright, Color = color, Parent = parent })
	decor({ Name = "BuoyBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.95, 1.95), CFrame = CFrame.new(base + Vector3.new(0, 1.1, 0)) * upright, Color = Color3.fromRGB(245, 245, 240), Parent = parent })
	local lamp = decor({ Name = "BuoyLight", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(base + Vector3.new(0, 2.2, 0)), Color = color:Lerp(Color3.new(1, 1, 1), 0.3), Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	light(lamp, color, 12, 1)
end

local function buildAmbient(root)
	local folder = newFolder("Ambient", root)
	local rng = Random.new(7311)
	for i, shape in ipairs(shapeList) do
		local ring = shape.island.ring
		if i % 3 ~= 0 then
			school(folder, shape, rng)
		end
		if ring == 1 then
			for _ = 1, 5 do
				local p = waterPoint(shape, rng, 3, 26, 3)
				if p then
					lilyPads(folder, p, rng)
				end
			end
			local p = waterPoint(shape, rng, 6, 22, 7)
			if p then
				bambooLog(folder, p, rng)
			end
		elseif ring == 3 then
			for k = 1, 3 do
				local p = waterPoint(shape, rng, 6, 25, 3.5)
				if p then
					if k == 3 then
						debris(folder, p, rng)
					else
						barrel(folder, p, rng)
					end
				end
			end
		end
	end
	-- buoys mark the Coral Maze's plank bridges, red on one side and green on the other
	for _, bridge in ipairs(bridges) do
		if bridge.kind == "plank" then
			for k, t in ipairs({ 0.33, 0.66 }) do
				local pos, dir = bridge.curve.at(bridge.curve.length * t)
				local side = k == 1 and 1 or -1
				buoy(folder, pos + Vector3.new(-dir.Z, 0, dir.X) * (side * (bridge.width / 2 + 6)), BUOY[k])
			end
		end
	end
end

-- Build -------------------------------------------------------------------------------------------------------

function ShoalsBuilder.build(world)
	local existing = world:FindFirstChild("SunkenShoals")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SunkenShoals"
	root:SetAttribute("Version", VERSION)
	fillSea()
	plan()
	buildIslands(root)
	buildSeabed(root)
	buildBridges(root)
	buildJumpPads(root)
	buildFishingSpots(root)
	buildEggNests(root)
	buildBeacons(root)
	buildTideCaches(root)
	buildAnemoneBeds(root)
	buildEliteDens(root)
	buildWarden(root)
	buildMaelstrom(root)
	buildAmbient(root)
	local count = 0
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") then
			count += 1
		end
	end
	root:SetAttribute("PartCount", count)
	root.Parent = world
	return root
end

return ShoalsBuilder
