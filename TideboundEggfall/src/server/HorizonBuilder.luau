-- Tidebound: Eggfall: the horizon (Patch 17). Before this the sea simply stopped a few hundred studs past the
-- islands and you could see the edge of the world. Now the sea runs on much further and the play area is ringed
-- with things to look at, all far enough out that you never reach them:
--   * cartoon tropical islands (stepped voxel cliffs with grass caps, sand rings, palms, huts, flowers)
--   * hazy blue mountains on the far skyline, and icebergs on the winter side behind Eggfall Town
--   * pirate ships sailing slow laps round the far islands (TideboundSail), one moored, one wrecked on a sandbar
--   * a giant rubber duck, a whale blowing spray, shark fins circling, two floating sky islands with waterfalls,
--     a rock arch, sea stacks, a striped lighthouse with a turning beam, and the Log Guardian: a giant wooden
--     log with a face and a bat, watching over the north islands
-- Everything is decoration (no collisions, no shadows) and streams to every player (ModelStreamingMode
-- Persistent) so the skyline is never empty. The ships, fins and floating things are moved on each screen by
-- TideboundLife.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local L = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("IslesLayout"))

local HorizonBuilder = {}

local VERSION = 1

local WATER_Y = L.WATER_Y
local FLOOR = L.sea.floorY - 2
local OUTER_MIN = Vector3.new(-1700, 0, -2100) -- the sea now runs out to here
local OUTER_MAX = Vector3.new(3300, 0, 2100)

-- palette (bright and cartoony)
local SAND = Color3.fromRGB(240, 214, 150)
local SAND_WET = Color3.fromRGB(214, 184, 122)
local GRASS = { Color3.fromRGB(96, 200, 84), Color3.fromRGB(120, 214, 92), Color3.fromRGB(78, 180, 76) }
local CLIFF = { Color3.fromRGB(176, 128, 86), Color3.fromRGB(150, 106, 72), Color3.fromRGB(196, 150, 100) }
local ROCK = { Color3.fromRGB(130, 136, 150), Color3.fromRGB(110, 116, 130), Color3.fromRGB(150, 156, 168) }
local MOUNTAIN = { Color3.fromRGB(112, 146, 176), Color3.fromRGB(96, 130, 164), Color3.fromRGB(128, 160, 190) }
local SNOW = Color3.fromRGB(236, 244, 255)
local ICE = { Color3.fromRGB(214, 238, 255), Color3.fromRGB(176, 220, 250), Color3.fromRGB(240, 250, 255) }
local WOOD = Color3.fromRGB(150, 98, 60)
local WOOD_DARK = Color3.fromRGB(104, 66, 42)
local TRUNK = { Color3.fromRGB(160, 116, 72), Color3.fromRGB(134, 96, 62) }
local LEAF = { Color3.fromRGB(70, 186, 80), Color3.fromRGB(100, 206, 90), Color3.fromRGB(54, 160, 70) }
local FLOWERS = { Color3.fromRGB(255, 110, 160), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 130, 255) }
local SAIL_COLORS = {
	{ Color3.fromRGB(248, 244, 232), Color3.fromRGB(220, 60, 60) },
	{ Color3.fromRGB(30, 30, 40), Color3.fromRGB(240, 240, 240) },
	{ Color3.fromRGB(248, 244, 232), Color3.fromRGB(60, 120, 220) },
	{ Color3.fromRGB(230, 70, 70), Color3.fromRGB(255, 220, 90) },
}

local function v(x, z)
	return Vector3.new(x, 0, z)
end

-- Parts ---------------------------------------------------------------------------------------------------------

local function make(className, parent, props)
	local p = Instance.new(className)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, val in pairs(props) do
		p[k] = val
	end
	p.Parent = parent
	return p
end

local function block(parent, size, cf, color, material)
	return make("Part", parent, { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

local function ball(parent, size, cf, color)
	-- an ellipsoid: a block with a sphere mesh fills its box
	local p = block(parent, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinder(parent, length, diameter, cf, color)
	-- along the CFrame's Y axis
	local p = block(parent, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function wedge(parent, size, cf, color)
	return make("WedgePart", parent, { Size = size, CFrame = cf, Color = color })
end

local function neon(parent, size, cf, color)
	local p = block(parent, size, cf, color, Enum.Material.Neon)
	return p
end

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function newModel(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
	return m
end

-- The wider sea ---------------------------------------------------------------------------------------------------

local function fillBox(min, max)
	local terrain = workspace.Terrain
	local CHUNK = 512
	local x = min.X
	while x < max.X do
		local x2 = math.min(max.X, x + CHUNK)
		local z = min.Z
		while z < max.Z do
			local z2 = math.min(max.Z, z + CHUNK)
			local cx, cz = (x + x2) / 2, (z + z2) / 2
			local size = Vector3.new(x2 - x, 0, z2 - z)
			terrain:FillBlock(CFrame.new(cx, FLOOR - 2, cz), size + Vector3.new(0, 4, 0), Enum.Material.Sand)
			terrain:FillBlock(CFrame.new(cx, (FLOOR + WATER_Y) / 2, cz), size + Vector3.new(0, WATER_Y - FLOOR, 0), Enum.Material.Water)
			z = z2
		end
		x = x2
		task.wait()
	end
end

-- the four bands round the Shoals' own sea (L.sea)
local function widenSea()
	local a, b = L.sea.min, L.sea.max
	fillBox(Vector3.new(OUTER_MIN.X, 0, OUTER_MIN.Z), Vector3.new(a.X, 0, OUTER_MAX.Z))
	fillBox(Vector3.new(b.X, 0, OUTER_MIN.Z), Vector3.new(OUTER_MAX.X, 0, OUTER_MAX.Z))
	fillBox(Vector3.new(a.X, 0, b.Z), Vector3.new(b.X, 0, OUTER_MAX.Z))
	fillBox(Vector3.new(a.X, 0, OUTER_MIN.Z), Vector3.new(b.X, 0, a.Z))
end

-- Pieces ------------------------------------------------------------------------------------------------------------

-- A stepped voxel hill: layers of blocks that shrink as they rise, each layer capped with `cap` (grass, snow) on
-- the ledges. Returns the top height.
local function steppedHill(parent, center, w, d, bottom, height, rng, sides, cap, layer)
	layer = layer or 10
	local y = bottom
	local i = 0
	while y < height and w > 8 and d > 8 do
		local top = math.min(height, y + layer)
		for k = 1, rng:NextInteger(2, 3) do
			local bw = w * rng:NextNumber(0.6, 1)
			local bd = d * rng:NextNumber(0.6, 1)
			local ox = rng:NextNumber(-(w - bw) / 2, (w - bw) / 2)
			local oz = rng:NextNumber(-(d - bd) / 2, (d - bd) / 2)
			block(parent, Vector3.new(bw, top - y, bd), CFrame.new(center.X + ox, (y + top) / 2, center.Z + oz), sides[((i + k) % #sides) + 1])
			if cap and y > WATER_Y + 2 then
				block(parent, Vector3.new(bw + 0.6, 1.4, bd + 0.6), CFrame.new(center.X + ox, top + 0.2, center.Z + oz), type(cap) == "table" and pick(rng, cap) or cap)
			end
		end
		y = top
		w *= rng:NextNumber(0.72, 0.86)
		d *= rng:NextNumber(0.72, 0.86)
		i += 1
	end
	return y
end

local function palm(parent, base, rng, scale)
	local lean = rng:NextNumber(-0.3, 0.3)
	local dir = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, lean)
	local pos = base
	for i = 1, 4 do
		local seg = dir * CFrame.Angles(0, 0, lean * i * 0.15)
		local nextPos = pos + seg.UpVector * 4 * scale
		block(parent, Vector3.new(1.8 - i * 0.15, 4.3, 1.8 - i * 0.15) * scale, CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(math.rad(90), 0, 0), TRUNK[(i % 2) + 1])
		pos = nextPos
	end
	for k = 1, 5 do
		local yaw = k / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local frond = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -4 * scale)
		block(parent, Vector3.new(2.6, 0.5, 8) * scale, frond, pick(rng, LEAF))
	end
	ball(parent, Vector3.new(1.4, 1.4, 1.4) * scale, CFrame.new(pos - Vector3.new(0, 0.8 * scale, 0)), Color3.fromRGB(120, 84, 50))
end

local function bush(parent, base, rng, scale)
	ball(parent, Vector3.new(6, 4.5, 6) * scale, CFrame.new(base + Vector3.new(0, 1.8 * scale, 0)), pick(rng, LEAF))
	if rng:NextNumber() < 0.5 then
		ball(parent, Vector3.new(1.2, 1.2, 1.2) * scale, CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), 4 * scale, rng:NextNumber(-2, 2))), pick(rng, FLOWERS))
	end
end

local function hut(parent, base, rng, scale)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local cf = CFrame.new(base) * yaw
	block(parent, Vector3.new(10, 7, 9) * scale, cf * CFrame.new(0, 3.5 * scale, 0), Color3.fromRGB(226, 196, 140))
	block(parent, Vector3.new(2.4, 4, 0.4) * scale, cf * CFrame.new(0, 2 * scale, -4.6 * scale), WOOD_DARK)
	for _, side in ipairs({ -1, 1 }) do
		wedge(parent, Vector3.new(12, 5, 6) * scale, cf * CFrame.new(0, 9.5 * scale, side * 3 * scale) * CFrame.Angles(0, side == 1 and math.pi or 0, 0), Color3.fromRGB(214, 170, 80))
	end
end

-- A cartoon tropical island. Returns the model and its top height.
local function island(parent, name, center, r, h, rng)
	local model = newModel(parent, name)
	-- sand ring and a wet edge just above the water
	local beach = block(model, Vector3.new(3, r * 2.3, r * 2.3), CFrame.new(center.X, WATER_Y + 0.4, center.Z) * CFrame.Angles(0, 0, math.rad(90)), SAND)
	beach.Shape = Enum.PartType.Cylinder
	local wet = block(model, Vector3.new(2, r * 2.45, r * 2.45), CFrame.new(center.X, WATER_Y - 0.3, center.Z) * CFrame.Angles(0, 0, math.rad(90)), SAND_WET)
	wet.Shape = Enum.PartType.Cylinder
	local top = steppedHill(model, center, r * 1.5, r * 1.3, FLOOR, WATER_Y + h, rng, CLIFF, GRASS, 12)
	-- palms on the beach, bushes and flowers up the slopes, sometimes a hut
	for _ = 1, rng:NextInteger(4, 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * r * rng:NextNumber(0.85, 1.05)
		palm(model, Vector3.new(p.X, WATER_Y + 1.8, p.Z), rng, rng:NextNumber(1.3, 1.8))
	end
	for _ = 1, rng:NextInteger(3, 5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * r * rng:NextNumber(0.1, 0.3)
		bush(model, Vector3.new(p.X, top + 0.8, p.Z), rng, rng:NextNumber(1.2, 2))
	end
	if rng:NextNumber() < 0.6 then
		palm(model, Vector3.new(center.X, top + 0.8, center.Z), rng, 2.2)
	end
	if rng:NextNumber() < 0.5 then
		local a = rng:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * r * 1.0
		hut(model, Vector3.new(p.X, WATER_Y + 1.9, p.Z), rng, 1.6)
	end
	return model, top
end

local function mountain(parent, center, size, h, rng, snowy)
	local model = newModel(parent, "Mountain")
	local top = steppedHill(model, center, size, size * rng:NextNumber(0.7, 0.9), FLOOR, WATER_Y + h, rng, MOUNTAIN, nil, 28)
	if snowy then
		ball(model, Vector3.new(size * 0.22, 14, size * 0.2), CFrame.new(center.X, top, center.Z), SNOW)
	end
	return model
end

local function iceberg(parent, center, r, h, rng)
	local model = newModel(parent, "Iceberg")
	steppedHill(model, center, r * 1.6, r * 1.3, WATER_Y - 10, WATER_Y + h, rng, ICE, SNOW, 9)
	-- a few glassy shards
	for _ = 1, 3 do
		local p = center + Vector3.new(rng:NextNumber(-r, r) * 0.6, 0, rng:NextNumber(-r, r) * 0.6)
		local shard = block(model, Vector3.new(4, rng:NextNumber(12, 24), 4), CFrame.new(p.X, WATER_Y + h * 0.4, p.Z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(150, 220, 255), Enum.Material.Glass)
		shard.Transparency = 0.2
	end
	return model
end

-- A pirate ship (local space: bow toward -Z, waterline at y = 0), returned as a model pivoting at `cf`.
local function ship(parent, name, cf, scale, colors, rng)
	local model = newModel(parent, name)
	local function at(x, y, z)
		return cf * CFrame.new(x * scale, y * scale, z * scale)
	end
	local s = scale
	local hullColor = Color3.fromRGB(122, 74, 44)
	local trim = colors[2]
	block(model, Vector3.new(10, 6, 30) * s, at(0, 1, 2), hullColor).Name = "Hull"
	block(model, Vector3.new(8, 2, 28) * s, at(0, -2.5, 2), Color3.fromRGB(96, 58, 36))
	block(model, Vector3.new(10.4, 1, 30.4) * s, at(0, 2.6, 2), trim) -- the painted stripe
	block(model, Vector3.new(10.6, 0.8, 30.6) * s, at(0, 4.4, 2), WOOD_DARK) -- the rail
	-- the bow: flat on top, the keel sweeping up to the front
	wedge(model, Vector3.new(10, 6, 8) * s, at(0, 1, -17) * CFrame.Angles(0, 0, math.pi), hullColor)
	wedge(model, Vector3.new(10.4, 1, 8) * s, at(0, 2.6, -17) * CFrame.Angles(0, 0, math.pi), trim)
	cylinder(model, 14 * s, 0.9 * s, at(0, 5, -22) * CFrame.Angles(math.rad(-65), 0, 0), WOOD_DARK) -- bowsprit
	-- the stern castle with lanterns
	block(model, Vector3.new(10, 5, 8) * s, at(0, 6.5, 13), hullColor)
	block(model, Vector3.new(10.6, 0.8, 8.6) * s, at(0, 9.2, 13), WOOD_DARK)
	for _, side in ipairs({ -1, 1 }) do
		neon(model, Vector3.new(0.9, 1.3, 0.9) * s, at(side * 4.4, 10.4, 16.8), Color3.fromRGB(255, 190, 90))
		-- cannons poking out of the sides
		for k = 0, 3 do
			cylinder(model, 2.4 * s, 1.1 * s, at(side * 5.4, 1.4, -8 + k * 6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(34, 34, 40))
		end
	end
	-- masts, sails and flags
	for k, mast in ipairs({ { z = -6, h = 30 }, { z = 5, h = 26 } }) do
		cylinder(model, mast.h * s, 1.2 * s, at(0, 4 + mast.h / 2, mast.z), WOOD)
		local sail = block(model, Vector3.new(15, 10, 0.6) * s, at(0, 4 + mast.h * 0.45, mast.z - 0.8), colors[1])
		sail.Name = "Sail"
		block(model, Vector3.new(15.4, 1, 0.8) * s, at(0, 4 + mast.h * 0.45 + 5.2, mast.z - 0.8), trim)
		block(model, Vector3.new(11, 7, 0.6) * s, at(0, 4 + mast.h * 0.8, mast.z - 0.8), colors[1]).Name = "Sail"
		cylinder(model, 16 * s, 0.6 * s, at(0, 4 + mast.h * 0.45 + 5.6, mast.z - 0.4) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK)
		if k == 1 then
			cylinder(model, 1.6 * s, 3.4 * s, at(0, 4 + mast.h - 3, mast.z), WOOD_DARK) -- the crow's nest
		end
		block(model, Vector3.new(0.2, 2.4, 4) * s, at(0, 4 + mast.h + 1, mast.z + 2), trim)
	end
	-- a skull on the big sail: white head, two dark eyes
	ball(model, Vector3.new(4, 3.6, 0.4) * s, at(0, 4 + 30 * 0.45 + 0.5, -7.2), Color3.fromRGB(250, 250, 250))
	for _, side in ipairs({ -0.9, 0.9 }) do
		ball(model, Vector3.new(1, 1, 0.3) * s, at(side, 4 + 30 * 0.45 + 0.8, -7.45), Color3.fromRGB(30, 30, 30))
	end
	-- foam at the bow
	local foam = block(model, Vector3.new(12, 0.4, 6) * s, at(0, -0.3, -18), Color3.fromRGB(240, 250, 255))
	foam.Transparency = 0.3
	model.WorldPivot = cf
	return model
end

-- Something that sails laps round a centre on every screen (TideboundLife moves it).
local function sail(model, center, radius, speed, phase, y)
	model:SetAttribute("Center", Vector3.new(center.X, y or WATER_Y, center.Z))
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Phase", phase)
	CollectionService:AddTag(model, "TideboundSail")
end

-- Something that floats and bobs where it is (TideboundLife's TideboundBob).
local function bob(model, home, seed)
	model.WorldPivot = home
	model:SetAttribute("Home", home)
	model:SetAttribute("Seed", seed)
	model:SetAttribute("BobRange", 3000) -- far away, but big enough to see rock
	CollectionService:AddTag(model, "TideboundBob")
end

local function rubberDuck(parent, pos, scale)
	local model = newModel(parent, "GiantRubberDuck")
	local cf = CFrame.new(pos.X, WATER_Y, pos.Z) * CFrame.Angles(0, math.rad(200), 0)
	local s = scale
	local yellow = Color3.fromRGB(255, 214, 40)
	ball(model, Vector3.new(26, 18, 34) * s, cf * CFrame.new(0, 6 * s, 2 * s), yellow)
	ball(model, Vector3.new(18, 17, 17) * s, cf * CFrame.new(0, 19 * s, -9 * s), yellow)
	ball(model, Vector3.new(10, 4, 9) * s, cf * CFrame.new(0, 17 * s, -18 * s), Color3.fromRGB(255, 130, 30))
	for _, side in ipairs({ -1, 1 }) do
		ball(model, Vector3.new(3.6, 4.4, 2) * s, cf * CFrame.new(side * 4.5, 22 * s, -16.4 * s), Color3.fromRGB(255, 255, 255))
		ball(model, Vector3.new(2, 2.6, 1.2) * s, cf * CFrame.new(side * 4.7, 22 * s, -17.4 * s), Color3.fromRGB(20, 20, 30))
		ball(model, Vector3.new(4, 10, 18) * s, cf * CFrame.new(side * 12.5, 8 * s, 4 * s) * CFrame.Angles(math.rad(-15), 0, side * 0.2), Color3.fromRGB(255, 200, 30))
	end
	ball(model, Vector3.new(10, 9, 8) * s, cf * CFrame.new(0, 13 * s, 17 * s) * CFrame.Angles(math.rad(-35), 0, 0), yellow) -- tail
	bob(model, cf, 3.1)
	return model
end

local function whale(parent, pos, scale)
	local model = newModel(parent, "Whale")
	local cf = CFrame.new(pos.X, WATER_Y, pos.Z) * CFrame.Angles(0, math.rad(65), 0)
	local s = scale
	local blue = Color3.fromRGB(60, 100, 170)
	ball(model, Vector3.new(22, 16, 56) * s, cf * CFrame.new(0, 2 * s, 0), blue)
	ball(model, Vector3.new(18, 8, 40) * s, cf * CFrame.new(0, -2 * s, -4 * s), Color3.fromRGB(220, 230, 240))
	block(model, Vector3.new(22, 2, 8) * s, cf * CFrame.new(0, 4 * s, 30 * s) * CFrame.Angles(math.rad(-25), 0, 0), blue) -- flukes
	for _, side in ipairs({ -1, 1 }) do
		ball(model, Vector3.new(2.6, 2.6, 1) * s, cf * CFrame.new(side * 9.5, 5 * s, -18 * s) * CFrame.Angles(0, side * math.rad(90), 0), Color3.fromRGB(255, 255, 255))
		ball(model, Vector3.new(1.4, 1.4, 0.6) * s, cf * CFrame.new(side * 10.3, 5 * s, -18.4 * s) * CFrame.Angles(0, side * math.rad(90), 0), Color3.fromRGB(20, 20, 30))
		ball(model, Vector3.new(12, 2, 6) * s, cf * CFrame.new(side * 12, -1 * s, -8 * s) * CFrame.Angles(0, 0, side * 0.4), blue)
	end
	-- the spout: a fountain of spray off the blowhole
	local hole = block(model, Vector3.new(1, 1, 1), cf * CFrame.new(0, 10 * s, -10 * s), blue)
	hole.Transparency = 1
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 236, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(1.4, 2)
	spray.Speed = NumberRange.new(30, 40)
	spray.SpreadAngle = Vector2.new(12, 12)
	spray.Acceleration = Vector3.new(0, -26, 0)
	spray.Rate = 40
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = hole
	bob(model, cf, 1.7)
	return model
end

local function sharkFin(parent, name)
	local model = newModel(parent, name)
	local cf = CFrame.new(0, WATER_Y, 0)
	wedge(model, Vector3.new(1.4, 7, 8), cf * CFrame.new(0, 3, 0), Color3.fromRGB(90, 104, 124)).Name = "Fin"
	local foam = block(model, Vector3.new(3, 0.4, 9), cf * CFrame.new(0, 0, 1), Color3.fromRGB(240, 250, 255))
	foam.Transparency = 0.35
	model.WorldPivot = cf
	return model
end

local function skyIsland(parent, pos, y, r, rng)
	local model = newModel(parent, "SkyIsland")
	local center = Vector3.new(pos.X, 0, pos.Z)
	-- an upside-down stepped rock, grass on top
	local w = r * 2
	local bottom = y
	for i = 0, 5 do
		local layerY = bottom - i * 10
		block(model, Vector3.new(w * (1 - i * 0.15), 10, w * (0.9 - i * 0.13)), CFrame.new(center.X + rng:NextNumber(-3, 3), layerY - 5, center.Z + rng:NextNumber(-3, 3)), ROCK[(i % #ROCK) + 1])
	end
	block(model, Vector3.new(w + 1, 2, w * 0.9 + 1), CFrame.new(center.X, y + 1, center.Z), GRASS[1])
	for _ = 1, 3 do
		palm(model, Vector3.new(center.X + rng:NextNumber(-r, r) * 0.6, y + 2, center.Z + rng:NextNumber(-r, r) * 0.5), rng, 1.5)
	end
	bush(model, Vector3.new(center.X + r * 0.4, y + 2, center.Z), rng, 1.6)
	-- a waterfall pouring off one edge and fading into the air
	local fall = block(model, Vector3.new(8, 120, 2), CFrame.new(center.X + r * 0.9, y - 58, center.Z), Color3.fromRGB(150, 216, 255))
	fall.Transparency = 0.35
	local tex = Instance.new("ParticleEmitter")
	tex.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	tex.Size = NumberSequence.new(3)
	tex.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	tex.Lifetime = NumberRange.new(2, 3)
	tex.Speed = NumberRange.new(30, 40)
	tex.EmissionDirection = Enum.NormalId.Bottom
	tex.Rate = 20
	tex.Parent = fall
	bob(model, CFrame.new(center.X, y, center.Z), rng:NextNumber(0, 6))
	return model
end

local function logGuardian(parent, pos, y, scale)
	-- a giant wooden log with a face, holding a bat over its shoulder (the brainrot bat hero, in voxel wood)
	local model = newModel(parent, "LogGuardian")
	local s = scale
	local cf = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.rad(170), 0)
	cylinder(model, 30 * s, 13 * s, cf * CFrame.new(0, 15 * s, 0), Color3.fromRGB(170, 120, 70))
	cylinder(model, 0.6 * s, 13.4 * s, cf * CFrame.new(0, 30.2 * s, 0), Color3.fromRGB(226, 186, 130)) -- the cut top
	for _, ringY in ipairs({ 6, 24 }) do
		cylinder(model, 0.8 * s, 13.4 * s, cf * CFrame.new(0, ringY * s, 0), Color3.fromRGB(140, 96, 56))
	end
	for _, side in ipairs({ -1, 1 }) do
		ball(model, Vector3.new(3.6, 4.4, 1.6) * s, cf * CFrame.new(side * 2.6, 21 * s, -6.2 * s), Color3.fromRGB(255, 255, 255))
		ball(model, Vector3.new(1.6, 2, 1) * s, cf * CFrame.new(side * 2.5, 20.6 * s, -6.9 * s), Color3.fromRGB(20, 20, 30))
		block(model, Vector3.new(3.6, 0.8, 0.8) * s, cf * CFrame.new(side * 2.6, 24 * s, -6.4 * s) * CFrame.Angles(0, 0, side * -0.25), Color3.fromRGB(70, 44, 26)) -- brows
		-- stubby arms
		cylinder(model, 8 * s, 2.2 * s, cf * CFrame.new(side * 8, 14 * s, -2 * s) * CFrame.Angles(0, 0, side * math.rad(60)), Color3.fromRGB(160, 112, 66))
	end
	block(model, Vector3.new(5, 1.4, 0.8) * s, cf * CFrame.new(0, 16.5 * s, -6.4 * s), Color3.fromRGB(70, 30, 30)) -- a wide grin
	-- the bat, resting on its shoulder
	local bat = cf * CFrame.new(10 * s, 20 * s, -1 * s) * CFrame.Angles(0, 0, math.rad(-35))
	cylinder(model, 22 * s, 2.6 * s, bat * CFrame.new(0, 8 * s, 0), Color3.fromRGB(214, 170, 110))
	cylinder(model, 8 * s, 1.4 * s, bat * CFrame.new(0, -6 * s, 0), Color3.fromRGB(190, 146, 92))
	return model
end

local function rockArch(parent, pos, rng)
	local model = newModel(parent, "RockArch")
	for _, side in ipairs({ -1, 1 }) do
		steppedHill(model, Vector3.new(pos.X + side * 30, 0, pos.Z), 22, 20, FLOOR, WATER_Y + 60, rng, ROCK, GRASS, 12)
	end
	block(model, Vector3.new(82, 14, 20), CFrame.new(pos.X, WATER_Y + 62, pos.Z), ROCK[1])
	block(model, Vector3.new(84, 2, 21), CFrame.new(pos.X, WATER_Y + 70, pos.Z), GRASS[2])
	for k = -3, 3 do
		local vine = block(model, Vector3.new(1.2, rng:NextNumber(6, 16), 1.2), CFrame.new(pos.X + k * 7, WATER_Y + 50, pos.Z - 10.4), LEAF[(k % 3) + 1])
		vine.Name = "Vine"
	end
	palm(model, Vector3.new(pos.X - 30, WATER_Y + 61, pos.Z), rng, 1.6)
	return model
end

local function seaStacks(parent, pos, rng)
	local model = newModel(parent, "SeaStacks")
	for _ = 1, rng:NextInteger(3, 5) do
		local p = pos + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40))
		local top = steppedHill(model, p, rng:NextNumber(12, 20), rng:NextNumber(12, 20), FLOOR, WATER_Y + rng:NextNumber(30, 75), rng, ROCK, GRASS, 10)
		if rng:NextNumber() < 0.5 then
			bush(model, Vector3.new(p.X, top + 0.8, p.Z), rng, 1)
		end
	end
	return model
end

local function lighthouse(parent, pos, rng)
	local model = newModel(parent, "FarLighthouse")
	local top = steppedHill(model, pos, 50, 44, FLOOR, WATER_Y + 18, rng, ROCK, GRASS, 8)
	local y = top + 1
	for i = 0, 7 do
		cylinder(model, 6, 14 - i * 0.7, CFrame.new(pos.X, y + 3 + i * 6, pos.Z), (i % 2 == 0) and Color3.fromRGB(240, 60, 60) or Color3.fromRGB(250, 250, 250))
	end
	local lampY = y + 51
	cylinder(model, 2, 12, CFrame.new(pos.X, lampY - 2, pos.Z), Color3.fromRGB(40, 40, 50))
	local lamp = neon(model, Vector3.new(6, 6, 6), CFrame.new(pos.X, lampY + 2, pos.Z), Color3.fromRGB(255, 236, 140))
	lamp.Shape = Enum.PartType.Ball
	wedge(model, Vector3.new(12, 6, 6), CFrame.new(pos.X, lampY + 8, pos.Z - 3), Color3.fromRGB(220, 50, 50))
	wedge(model, Vector3.new(12, 6, 6), CFrame.new(pos.X, lampY + 8, pos.Z + 3) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(220, 50, 50))
	-- the turning beam (TideboundFX spins anything tagged TideboundSpin round its Pivot)
	local beam = neon(model, Vector3.new(3, 3, 120), CFrame.new(pos.X, lampY + 2, pos.Z - 60), Color3.fromRGB(255, 244, 190))
	beam.Name = "Beam"
	beam.Transparency = 0.6
	beam:SetAttribute("Pivot", Vector3.new(pos.X, lampY + 2, pos.Z))
	beam:SetAttribute("SpinSpeed", 0.8)
	CollectionService:AddTag(beam, "TideboundSpin")
	return model
end

-- Build ---------------------------------------------------------------------------------------------------------------

local function build(root, rng)
	-- far tropical islands, ringing the Shoals (north, south and east)
	local ISLANDS = {
		{ v(200, 1250), 120, 70 },
		{ v(700, 1400), 160, 110 },
		{ v(1200, 1250), 110, 60 },
		{ v(1700, 1380), 170, 130 },
		{ v(2300, 1200), 130, 80 },
		{ v(300, -1250), 140, 90 },
		{ v(850, -1400), 170, 120 },
		{ v(1400, -1220), 110, 60 },
		{ v(1950, -1350), 150, 100 },
		{ v(-200, -1300), 110, 70 },
		{ v(2450, 500), 150, 100 },
		{ v(2550, -150), 180, 140 },
		{ v(2400, -750), 120, 70 },
		{ v(-500, 1250), 120, 60 },
	}
	local tops = {}
	for i, def in ipairs(ISLANDS) do
		local _, top = island(root, "FarIsland" .. i, def[1], def[2], def[3], rng)
		tops[i] = top
		if i % 4 == 0 then
			task.wait()
		end
	end

	-- the skyline: hazy mountains far behind the islands; snowy ones on the town's side
	for _, def in ipairs({
		{ v(500, 1950), 340, 300, false },
		{ v(1500, 2000), 380, 360, false },
		{ v(2600, 1800), 300, 260, false },
		{ v(1100, -1950), 360, 320, false },
		{ v(2300, -1900), 300, 280, false },
		{ v(3050, 300), 360, 340, false },
		{ v(3000, -900), 320, 300, false },
		{ v(-1350, 650), 380, 380, true },
		{ v(-1400, -450), 400, 420, true },
		{ v(-1100, 1700), 340, 300, true },
		{ v(-1000, -1800), 340, 320, true },
	}) do
		mountain(root, def[1], def[2], def[3], rng, def[4])
	end
	task.wait()

	-- icebergs drifting off the winter town's coast
	for _, def in ipairs({
		{ v(-620, 720), 34, 40 },
		{ v(-700, -150), 46, 55 },
		{ v(-620, -700), 30, 34 },
		{ v(-820, 280), 40, 46 },
		{ v(-540, -1000), 36, 40 },
		{ v(-900, -420), 50, 64 },
		{ v(-480, 980), 28, 30 },
	}) do
		iceberg(root, def[1], def[2], def[3], rng)
	end

	-- pirate ships sailing laps round four of the far islands
	local laps = { { 2, 230, 9 }, { 7, 240, 8 }, { 12, 250, 10 }, { 4, 240, 7 } }
	for i, lap in ipairs(laps) do
		local def = ISLANDS[lap[1]]
		local model = ship(root, "PirateShip" .. i, CFrame.new(def[1].X + lap[2], WATER_Y, def[1].Z), 1.8, SAIL_COLORS[i], rng)
		sail(model, def[1], lap[2], lap[3], rng:NextNumber(0, math.pi * 2))
	end
	-- one moored off the east island, one wrecked on a sandbar
	local moored = ship(root, "MooredShip", CFrame.new(2250, WATER_Y, 520) * CFrame.Angles(0, math.rad(80), 0), 1.6, SAIL_COLORS[3], rng)
	bob(moored, moored:GetPivot(), 2.2)
	local wreckAt = v(1650, -1060)
	local bar = block(newModel(root, "Sandbar"), Vector3.new(3, 90, 90), CFrame.new(wreckAt.X, WATER_Y + 0.3, wreckAt.Z) * CFrame.Angles(0, 0, math.rad(90)), SAND)
	bar.Shape = Enum.PartType.Cylinder
	local wreck = ship(root, "Shipwreck", CFrame.new(wreckAt.X, WATER_Y - 4, wreckAt.Z) * CFrame.Angles(0, math.rad(30), 0) * CFrame.Angles(math.rad(-10), 0, math.rad(22)), 1.6, { Color3.fromRGB(170, 150, 120), Color3.fromRGB(90, 70, 50) }, rng)
	for _, p in ipairs(wreck:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "Sail" then
			p.Size *= Vector3.new(0.7, 0.6, 1) -- torn
		end
	end

	-- the fun ones
	rubberDuck(root, v(1300, 1020), 1.3)
	whale(root, v(2200, 960), 1.4)
	for i, def in ipairs({ { v(1000, -1050), 40, 14 }, { v(2160, 260), 46, 12 }, { v(-450, 400), 34, 11 } }) do
		local fin = sharkFin(root, "SharkFin" .. i)
		sail(fin, def[1], def[2], def[3], i * 2)
	end
	skyIsland(root, v(600, 1700), WATER_Y + 260, 46, rng)
	skyIsland(root, v(2250, -1150), WATER_Y + 300, 40, rng)
	skyIsland(root, v(2900, 900), WATER_Y + 240, 36, rng)
	logGuardian(root, ISLANDS[3][1], tops[3] + 0.8, 1.6)
	rockArch(root, v(2250, -430), rng)
	seaStacks(root, v(2150, 1000), rng)
	seaStacks(root, v(100, -1080), rng)
	seaStacks(root, v(-450, -1250), rng)
	lighthouse(root, v(2150, -960), rng)
end

function HorizonBuilder.build(world)
	local existing = world:FindFirstChild("Horizon")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	widenSea()
	local root = Instance.new("Folder")
	root.Name = "Horizon"
	root:SetAttribute("Version", VERSION)
	build(root, Random.new(1717))
	root.Parent = world
	return root
end

return HorizonBuilder
