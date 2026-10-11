-- Tidebound: Eggfall: builds the Nest hub and the Sunken Shoals biome to match the art references.
-- Nest (refs/REF 1): snowy white blocky plaza in a valley of towering dirt-and-cobble terraces, a round
-- blue fountain with a gold rim and a square monument, separate wooden plank steps, voxel trees.
-- Shoals (refs/REF 2): painterly daylight pond, dark boardwalk with brown posts and sagging rope, lime
-- bamboo in the water, a giant lavender tree, a white hut with dark lattice and round windows, crystal lanterns.
-- Safe to run in Edit mode (the result is saved with the place) or at server start.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local WorldBuilder = {}

local VERSION = 8

-- REF 1 palette
local SNOW_GROUND = Color3.fromRGB(240, 238, 242)
local SNOW_CAP = Color3.fromRGB(248, 248, 252)
local DIRT = Color3.fromRGB(146, 104, 82)
local DIRT_DARK = Color3.fromRGB(122, 86, 70)
local COBBLE = Color3.fromRGB(128, 132, 140)
local GRASS = Color3.fromRGB(64, 176, 84)
local STONE = Color3.fromRGB(206, 208, 214)
local GOLD = Color3.fromRGB(232, 186, 70)
local TAN = Color3.fromRGB(222, 192, 124)
local FOUNTAIN_BLUE = Color3.fromRGB(40, 142, 232)
local TRUNK = Color3.fromRGB(74, 70, 74)
local LEAF = { Color3.fromRGB(58, 178, 82), Color3.fromRGB(88, 198, 92), Color3.fromRGB(40, 150, 72) }
local PINE = { Color3.fromRGB(172, 222, 96), Color3.fromRGB(150, 206, 82), Color3.fromRGB(196, 232, 120) }
local LAMP_WOOD = Color3.fromRGB(64, 50, 46)
local LANTERN_ORANGE = Color3.fromRGB(255, 150, 60)
local PLANK = Color3.fromRGB(128, 86, 62)
local PLANK_EDGE = Color3.fromRGB(88, 58, 44)
local HOUSE_WALL = Color3.fromRGB(96, 112, 134)

-- REF 2 palette
local DECK = Color3.fromRGB(58, 60, 68)
local POST = Color3.fromRGB(116, 76, 52)
local ROPE = Color3.fromRGB(206, 182, 136)
local BAMBOO = Color3.fromRGB(206, 240, 128)
local BARK = Color3.fromRGB(168, 154, 184)
local BARK_DARK = Color3.fromRGB(140, 126, 160)
local CANOPY = { Color3.fromRGB(92, 210, 92), Color3.fromRGB(132, 226, 96), Color3.fromRGB(70, 190, 86) }
local POND_GRASS = Color3.fromRGB(118, 214, 96)
local MINT_ROCK = Color3.fromRGB(196, 234, 214)
local CRYSTAL = Color3.fromRGB(196, 238, 255)
local SAND = Color3.fromRGB(96, 178, 86)
local SPOT = Color3.fromRGB(150, 236, 255)
local BEACON = Color3.fromRGB(90, 255, 200)

local TOP = 6 -- walkable surface height for the nest, reefs and boardwalks
local WATER_Y = 4

local ISLANDS = {
	{ name = "ReefA", pos = Vector3.new(110, 0, 0), r = 22 },
	{ name = "ReefB", pos = Vector3.new(160, 0, 58), r = 18 },
	{ name = "ReefC", pos = Vector3.new(165, 0, -60), r = 18 },
	{ name = "ReefD", pos = Vector3.new(232, 0, 8), r = 24 },
	{ name = "ReefE", pos = Vector3.new(262, 0, -72), r = 16 },
	{ name = "WardensRock", pos = Vector3.new(305, 0, 0), r = 11 },
}
local LINKS = { { "ReefA", "ReefB" }, { "ReefA", "ReefC" }, { "ReefA", "ReefD" }, { "ReefB", "ReefD" }, { "ReefD", "ReefE" }, { "ReefC", "ReefE" } }
local FISHING_SPOTS = {
	Vector3.new(110, 0, 31), Vector3.new(104, 0, -31), Vector3.new(180, 0, 78), Vector3.new(140, 0, 78),
	Vector3.new(186, 0, -80), Vector3.new(146, 0, -82), Vector3.new(255, 0, 30), Vector3.new(282, 0, -88),
}
local EGG_NESTS = {
	Vector3.new(160, 0, 58), Vector3.new(165, 0, -60), Vector3.new(240, 0, -4), Vector3.new(224, 0, 20), Vector3.new(262, 0, -72),
}
local BEACONS = { Vector3.new(148, 0, 48), Vector3.new(268, 0, -62) }
local WARDEN_PATH = { "ReefA", "ReefB", "ReefD", "ReefE", "ReefC" }

-- Primitives ---------------------------------------------------------------------

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function decor(props)
	props.CanCollide = false
	props.CanQuery = false
	return part(props)
end

-- Foliage tagged WindShake sways on the client (see TideboundWind).
local function windy(p)
	CollectionService:AddTag(p, "WindShake")
	return p
end

-- Upright cylinder (Roblox cylinders run along X, so rotate 90 degrees).
local function disk(parent, name, center, radius, height, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- Rod from a to b (ropes, vines, branches).
local function rod(parent, a, b, thickness, color)
	return decor({
		Name = "Rope",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new((b - a).Magnitude, thickness, thickness),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Parent = parent,
	})
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 12
	l.Brightness = brightness or 1
	l.Parent = parent
	return l
end

local function particles(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function sparkles(parent, color, rate)
	-- Wind-driven particles: WindAffectsDrag + Drag > 0 makes them follow Workspace.GlobalWind.
	return particles(parent, {
		Color = ColorSequence.new(color),
		LightEmission = 0.6,
		Rate = rate or 3,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(1, 2),
		Size = NumberSequence.new(0.3, 0),
		SpreadAngle = Vector2.new(25, 25),
		Drag = 1,
		WindAffectsDrag = true,
	})
end

local function billboard(adornee, title, subtitle, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 220, 0, subtitle and 48 or 28)
	gui.StudsOffset = Vector3.new(0, offset or 6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 28)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(40, 30, 30)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Parent = gui
	if subtitle then
		local sub = titleLabel:Clone()
		sub.Font = Enum.Font.BuilderSansBold
		sub.Position = UDim2.new(0, 0, 0, 28)
		sub.Size = UDim2.new(1, 0, 0, 18)
		sub.Text = subtitle
		sub.Parent = gui
	end
	gui.Parent = adornee
	return gui
end

local function prompt(parent, actionText, objectText, attributes, holdDuration, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = holdDuration or 0
	p.MaxActivationDistance = distance or 14
	p.RequiresLineOfSight = false
	for key, value in pairs(attributes) do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	return p
end

local function eggShape(parent, name, cframe, size, color)
	local egg = part({ Name = name, Size = size, CFrame = cframe, Color = color, CanCollide = false, Parent = parent })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	return egg
end

-- REF 1 props -----------------------------------------------------------------------------

-- Voxel tree: thick dark trunk that forks, chunky rectangular leaf slabs in two or three greens.
local function voxelTree(parent, base, rng, scale)
	scale = scale or 1
	local height = rng:NextNumber(7, 10) * scale
	local w = 2.2 * scale
	decor({ Name = "TreeTrunk", Size = Vector3.new(w, height, w), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)), Color = TRUNK, Parent = parent })
	local crowns = { Vector3.new(0, height + 1.5 * scale, 0) }
	if rng:NextNumber() < 0.6 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local branchEnd = base + Vector3.new(side * 3.5 * scale, height * 0.75, 0)
		decor({ Name = "TreeBranch", Size = Vector3.new(4 * scale, 1.2 * scale, 1.2 * scale), CFrame = CFrame.new(base + Vector3.new(side * 1.8 * scale, height * 0.62, 0)) * CFrame.Angles(0, 0, side * 0.45), Color = TRUNK, Parent = parent })
		table.insert(crowns, branchEnd - base + Vector3.new(0, 1.2 * scale, 0))
	end
	for _, crown in ipairs(crowns) do
		for i = 1, 3 do
			local sw, sd = rng:NextNumber(6, 9) * scale, rng:NextNumber(4, 6.5) * scale
			windy(decor({
				Name = "TreeLeaves",
				Size = Vector3.new(sw, 2.2 * scale, sd),
				CFrame = CFrame.new(base + crown + Vector3.new(rng:NextNumber(-1.5, 1.5) * scale, (i - 2) * 1.9 * scale, rng:NextNumber(-1.5, 1.5) * scale)) * CFrame.Angles(0, rng:NextInteger(0, 1) * math.pi / 2, 0),
				Color = LEAF[rng:NextInteger(1, #LEAF)],
				Parent = parent,
			}))
		end
	end
end

-- Tiered pine made of stacked light-green boxes.
local function pineTree(parent, base, scale)
	scale = scale or 1
	decor({ Name = "PineTrunk", Size = Vector3.new(1.4 * scale, 2.5 * scale, 1.4 * scale), CFrame = CFrame.new(base + Vector3.new(0, 1.25 * scale, 0)), Color = TRUNK, Parent = parent })
	local y = base.Y + 2.5 * scale
	for i, s in ipairs({ 6, 5, 4, 3, 2 }) do
		local size = s * scale
		windy(decor({ Name = "PineTier", Size = Vector3.new(size, 2.4 * scale, size), CFrame = CFrame.new(base.X, y + 1.2 * scale, base.Z), Color = PINE[(i % #PINE) + 1], Parent = parent }))
		y += 2.4 * scale
	end
end

local function lampPost(parent, base, facing)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	decor({ Name = "LampPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = cf * CFrame.new(0, 4.5, 0), Color = LAMP_WOOD, Parent = parent })
	decor({ Name = "LampArm", Size = Vector3.new(0.4, 0.4, 2.2), CFrame = cf * CFrame.new(0, 8.4, -1), Color = LAMP_WOOD, Parent = parent })
	decor({ Name = "LampLantern", Size = Vector3.new(0.9, 1.2, 0.9), CFrame = cf * CFrame.new(0, 7.3, -1.9), Color = LANTERN_ORANGE, Parent = parent })
	decor({ Name = "LampCap", Size = Vector3.new(1.2, 0.3, 1.2), CFrame = cf * CFrame.new(0, 8, -1.9), Color = LAMP_WOOD, Parent = parent })
end

local function crate(parent, cframe)
	decor({ Name = "Crate", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cframe, Color = Color3.fromRGB(96, 68, 52), Parent = parent })
	for _, x in ipairs({ -1, 1 }) do
		decor({ Name = "CrateFrame", Size = Vector3.new(0.3, 2.7, 2.7), CFrame = cframe * CFrame.new(x * 1.2, 0, 0), Color = Color3.fromRGB(70, 50, 40), Parent = parent })
	end
end

local function flowerTuft(parent, base, rng)
	for _ = 1, 3 do
		local at = base + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
		decor({ Name = "Flower", Size = Vector3.new(0.35, rng:NextNumber(0.8, 1.4), 0.35), CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(226, 46, 60), Parent = parent })
	end
end

-- Separate wooden planks laid across the path, as in REF 1.
local function plankSteps(parent, a, b, width)
	local frame = CFrame.lookAt(Vector3.new(a.X, TOP, a.Z), Vector3.new(b.X, TOP, b.Z))
	local length = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	local step = 3.2
	for i = 0, math.floor(length / step) do
		local cf = frame * CFrame.new(0, 0.12, -(i * step + 1))
		decor({ Name = "PlankEdge", Size = Vector3.new(width, 0.24, 2), CFrame = cf, Color = PLANK_EDGE, Parent = parent })
		decor({ Name = "Plank", Size = Vector3.new(width - 0.5, 0.3, 1.5), CFrame = cf * CFrame.new(0, 0.05, 0), Color = PLANK, Parent = parent })
	end
end

-- REF 2 props ------------------------------------------------------------------------------

local function bambooCluster(parent, base, rng)
	for _ = 1, rng:NextInteger(3, 6) do
		local at = base + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local height = rng:NextNumber(18, 30)
		local lean = CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
		local stalk = decor({ Name = "Bamboo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.1, 1.1), CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * lean * CFrame.Angles(0, 0, math.rad(90)), Color = BAMBOO, Parent = parent })
		for y = 4, height - 2, 4.5 do
			decor({ Name = "BambooNode", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.25, 1.25), CFrame = stalk.CFrame * CFrame.new(y - height / 2, 0, 0), Color = BAMBOO:Lerp(Color3.fromRGB(120, 170, 70), 0.35), Parent = parent })
		end
	end
end

-- Pale-blue crystal lantern hanging on a dark vine.
local function crystalLantern(parent, hangFrom, length)
	local bottom = hangFrom - Vector3.new(0, length, 0)
	rod(parent, hangFrom, bottom, 0.25, Color3.fromRGB(36, 44, 36))
	decor({ Name = "LanternCap", Size = Vector3.new(1.2, 0.4, 1.2), CFrame = CFrame.new(bottom) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(60, 70, 90), Parent = parent })
	local crystal = decor({ Name = "CrystalLantern", Size = Vector3.new(1.1, 1.8, 1.1), CFrame = CFrame.new(bottom - Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = CRYSTAL, Material = Enum.Material.Neon, Transparency = 0.2, CastShadow = false, Parent = parent })
	decor({ Name = "LanternTip", Size = Vector3.new(0.5, 0.6, 0.5), CFrame = CFrame.new(bottom - Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(60, 70, 90), Parent = parent })
	light(crystal, CRYSTAL, 10, 0.8)
end

local function canopyTree(parent, base, rng)
	local height = rng:NextNumber(9, 13)
	local lean = rng:NextNumber(-0.25, 0.25)
	local trunk = decor({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 2, 2), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, 0, math.rad(90)), Color = Color3.fromRGB(122, 84, 72), Parent = parent })
	local top = trunk.Position + Vector3.new(0, height / 2, 0)
	for _ = 1, 6 do
		local s = rng:NextNumber(7, 12)
		windy(decor({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.3, s * 0.6, s), CFrame = CFrame.new(top + Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-0.5, 3), rng:NextNumber(-6, 6))), Color = CANOPY[rng:NextInteger(1, #CANOPY)], Parent = parent }))
	end
	for _ = 1, 2 do
		crystalLantern(parent, top + Vector3.new(rng:NextNumber(-5, 5), -1.5, rng:NextNumber(-5, 5)), rng:NextNumber(3, 6))
	end
end

-- The giant twisted lavender-grey tree from REF 2.
local function giantLavenderTree(parent, base, rng)
	local at = base
	local radius = 5.5
	for i = 1, 9 do
		local height = 5.5
		local twist = CFrame.Angles(math.rad(math.sin(i * 0.9) * 10), math.rad(i * 25), math.rad(math.cos(i * 0.7) * 10))
		local seg = decor({ Name = "Bark", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height + 1.2, radius * 2, radius * 2), CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * twist * CFrame.Angles(0, 0, math.rad(90)), Color = i % 2 == 0 and BARK or BARK_DARK, Parent = parent })
		at = seg.Position + Vector3.new(math.sin(i * 0.8) * 1, height / 2, math.cos(i * 0.6) * 1)
		radius = math.max(2.6, radius - 0.3)
	end
	for i = 1, 4 do
		local root = base + Vector3.new(math.cos(i * 1.6) * 5, 1, math.sin(i * 1.6) * 5)
		rod(parent, root, root + Vector3.new(math.cos(i * 1.6) * 4, -2.5, math.sin(i * 1.6) * 4), 2, BARK_DARK)
	end
	for i = 1, 5 do
		local angle = i * math.pi * 2 / 5 + 0.3
		local tip = at + Vector3.new(math.cos(angle) * 13, rng:NextNumber(1, 6), math.sin(angle) * 13)
		rod(parent, at, tip, 1.8, BARK)
		for _ = 1, 3 do
			local s = rng:NextNumber(11, 16)
			windy(decor({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.3, s * 0.55, s), CFrame = CFrame.new(tip + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(0, 3), rng:NextNumber(-4, 4))), Color = CANOPY[rng:NextInteger(1, #CANOPY)], Parent = parent }))
		end
		crystalLantern(parent, tip - Vector3.new(0, 1, 0), rng:NextNumber(5, 10))
	end
end

local function mintRock(parent, at, rng, scale)
	local s = rng:NextNumber(2, 4) * (scale or 1)
	decor({ Name = "MintRock", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.5, s * 0.9, s * 1.1), CFrame = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = MINT_ROCK, Parent = parent })
end

local function clovers(parent, at, rng)
	for _ = 1, rng:NextInteger(3, 6) do
		local c = at + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		for i = 1, 3 do
			local angle = i * math.pi * 2 / 3
			decor({ Name = "Clover", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.8, 0.8), CFrame = CFrame.new(c.X + math.cos(angle) * 0.35, WATER_Y + 0.08, c.Z + math.sin(angle) * 0.35) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 196, 96), CastShadow = false, Parent = parent })
		end
	end
end

local function daisies(parent, base, rng)
	for _ = 1, 4 do
		local at = base + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		decor({ Name = "Petals", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1, 1), CFrame = CFrame.new(at + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 244, 200), Parent = parent })
		decor({ Name = "Center", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.3, 0.4), CFrame = CFrame.new(at + Vector3.new(0, 0.9, 0)), Color = Color3.fromRGB(255, 206, 50), Parent = parent })
	end
end

-- Dark boardwalk with brown posts and sagging rope between them (REF 2).
local function boardwalkSegment(parent, a, b, width)
	local flatA, flatB = Vector3.new(a.X, TOP - 0.5, a.Z), Vector3.new(b.X, TOP - 0.5, b.Z)
	local length = (flatB - flatA).Magnitude
	local frame = CFrame.lookAt((flatA + flatB) / 2, flatB)
	part({ Name = "Boardwalk", Size = Vector3.new(width, 1, length + 1), CFrame = frame, Color = DECK, Parent = parent })
	local half = width / 2
	local count = math.max(1, math.floor(length / 6))
	local previous = { [-1] = nil, [1] = nil }
	for i = 0, count do
		local z = -length / 2 + i * (length / count)
		for _, side in ipairs({ -1, 1 }) do
			local base = frame * CFrame.new(side * (half - 0.5), 0, z)
			decor({ Name = "Post", Size = Vector3.new(1.1, 4.2, 1.1), CFrame = base * CFrame.new(0, 1.6, 0), Color = POST, Parent = parent })
			decor({ Name = "Piling", Size = Vector3.new(1, 5, 1), CFrame = base * CFrame.new(0, -3, 0), Color = POST, Parent = parent })
			local topPoint = (base * CFrame.new(0, 3.2, 0)).Position
			if previous[side] then
				local sag = (previous[side] + topPoint) / 2 - Vector3.new(0, 1.1, 0)
				rod(parent, previous[side], sag, 0.5, ROPE)
				rod(parent, sag, topPoint, 0.5, ROPE)
			end
			previous[side] = topPoint
		end
	end
end

local function curvedBoardwalk(parent, a, b, width, bend)
	local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local dir = (flatB - flatA).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local mid = (flatA + flatB) / 2 + side * bend
	boardwalkSegment(parent, flatA, mid, width)
	boardwalkSegment(parent, mid, flatB, width)
	return mid, side
end

-- Environment -------------------------------------------------------------------------
-- The client swaps between the Nest and Shoals atmospheres by zone (see TideboundClient).

local function setupEnvironment()
	Lighting.ClockTime = 14
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(150, 146, 156)
	Lighting.OutdoorAmbient = Color3.fromRGB(176, 172, 184)
	Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.5

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(226, 214, 222)
	atmosphere.Decay = Color3.fromRGB(196, 184, 196)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	for _, name in ipairs({ "TideboundRays" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local function effect(className, name, props)
		local e = Lighting:FindFirstChild(name) or Instance.new(className)
		e.Name = name
		for k, v in pairs(props) do
			e[k] = v
		end
		e.Parent = Lighting
	end
	effect("ColorCorrectionEffect", "TideboundGrade", { Saturation = 0.12, Contrast = 0.03, Brightness = 0.02, TintColor = Color3.fromRGB(255, 248, 250) })
	effect("BloomEffect", "TideboundBloom", { Intensity = 0.3, Size = 24, Threshold = 1.7 })

	workspace.GlobalWind = Vector3.new(6, 0, 3)

	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(56, 190, 190)
	terrain.WaterTransparency = 0.65
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.06
	terrain.WaterWaveSpeed = 5
	terrain:FillBlock(CFrame.new(100, 0, 0), Vector3.new(560, 8, 440), Enum.Material.Water)

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(104, 156, 138)
		baseplate.Material = Enum.Material.Sand
		for _, child in ipairs(baseplate:GetChildren()) do
			if child:IsA("Texture") then
				child:Destroy()
			end
		end
	end
end

-- Nest hub (REF 1) -------------------------------------------------------------------------

-- One terrace block: dirt or cobble body, thin grass cap, snow dusting, sometimes a tree.
local function terraceBlock(parent, cframe, size, rng)
	local cobble = rng:NextNumber() < 0.3
	part({ Name = "TerraceBlock", Size = size, CFrame = cframe, Color = cobble and COBBLE or (rng:NextNumber() < 0.5 and DIRT or DIRT_DARK), Material = cobble and Enum.Material.Cobblestone or Enum.Material.SmoothPlastic, Parent = parent })
	local top = cframe * CFrame.new(0, size.Y / 2, 0)
	decor({ Name = "GrassCap", Size = Vector3.new(size.X + 0.3, 0.8, size.Z + 0.3), CFrame = top * CFrame.new(0, -0.3, 0), Color = GRASS, Parent = parent })
	decor({ Name = "SnowCap", Size = Vector3.new(size.X - 1, 0.3, size.Z - 1), CFrame = top * CFrame.new(0, 0.2, 0), Color = SNOW_CAP, Parent = parent })
	if not cobble and rng:NextNumber() < 0.5 then
		-- grey cobble patch on the face
		decor({ Name = "CobblePatch", Size = Vector3.new(rng:NextNumber(2, size.X * 0.5), rng:NextNumber(2, size.Y * 0.5), 0.6), CFrame = cframe * CFrame.new(rng:NextNumber(-size.X / 4, size.X / 4), rng:NextNumber(-size.Y / 4, size.Y / 4), -size.Z / 2 - 0.2), Color = COBBLE, Material = Enum.Material.Cobblestone, Parent = parent })
	end
	local r = rng:NextNumber()
	local treeBase = (top * CFrame.new(rng:NextNumber(-size.X / 4, size.X / 4), 0.35, rng:NextNumber(-size.Z / 4, size.Z / 4))).Position
	if r < 0.25 then
		voxelTree(parent, treeBase, rng, rng:NextNumber(0.9, 1.3))
	elseif r < 0.42 then
		pineTree(parent, treeBase, rng:NextNumber(0.8, 1.2))
	elseif r < 0.55 then
		flowerTuft(parent, treeBase, rng)
	end
end

-- Stepped terraces enclosing the plaza on the west, north and south, leaving the east open to the dock.
local function buildTerraces(parent, rng)
	local center = Vector3.new(0, 0, 0)
	for ring = 1, 7 do
		local radius = 52 + (ring - 1) * 12
		local top = TOP + ring * 6 + (ring >= 6 and (ring - 5) * 10 or 0)
		local count = math.floor(radius * 0.42)
		for i = 0, count - 1 do
			local angle = math.rad(-125) + (i / count) * math.rad(250)
			local at = center + Vector3.new(-math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local w = rng:NextNumber(9, 14)
			local h = top + rng:NextNumber(-2, 2)
			local cf = CFrame.lookAt(Vector3.new(at.X, h / 2 - 2, at.Z), Vector3.new(center.X, h / 2 - 2, center.Z))
			terraceBlock(parent, cf, Vector3.new(w, h + 4, rng:NextNumber(11, 14)), rng)
		end
	end
	-- stone steps leading up the first terraces
	for i = 1, 4 do
		part({ Name = "StoneStep", Size = Vector3.new(8, i * 1.5, 3), CFrame = CFrame.new(-44 - i * 2.5, TOP + i * 0.75 - 0.75, -26), Color = STONE, Parent = parent })
	end
end

-- REF 3 shop props ---------------------------------------------------------------------------

local function surfaceText(board, text, color, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(30, 8, 20)
	outline.Thickness = 5
	outline.Parent = label
	label.Parent = gui
	gui.Parent = board
	return gui
end

-- Neon storefront with a big 3D sign and a glowing archway door (REF 3 "RAIDS" building), used for the egg shrine.
local function neonStorefront(parent, center, facing, title, signColor, doorColor)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
	local model = Instance.new("Model")
	model.Name = "EggStorefront"
	model.Parent = parent
	local w, d, h = 18, 10, 16
	local front = -d / 2 - 0.1
	part({ Name = "Body", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = Color3.fromRGB(34, 26, 70), Parent = model })
	part({ Name = "LowerFacade", Size = Vector3.new(w, 9, 0.6), CFrame = cf * CFrame.new(0, 4.5, -d / 2 - 0.3), Color = Color3.fromRGB(236, 50, 72), Parent = model })
	-- glowing window grid on the upper facade
	for row = 0, 2 do
		for col = 0, 5 do
			decor({ Name = "Window", Size = Vector3.new(2, 1.3, 0.2), CFrame = cf * CFrame.new(-6.25 + col * 2.5, 10.6 + row * 1.8, front - 0.1), Color = (row + col) % 2 == 0 and Color3.fromRGB(150, 110, 255) or Color3.fromRGB(80, 170, 255), Material = Enum.Material.Neon, Parent = model })
		end
	end
	-- glowing archway door: dark frame, neon outline, glowing inner door
	local doorW, doorH = 7, 7.5
	decor({ Name = "DoorGlow", Size = Vector3.new(doorW - 1.4, doorH - 0.8, 0.2), CFrame = cf * CFrame.new(0, doorH / 2, -d / 2 - 0.7), Color = doorColor, Material = Enum.Material.Neon, Transparency = 0.1, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "ArchPost", Size = Vector3.new(1.2, doorH, 1), CFrame = cf * CFrame.new(side * (doorW / 2 - 0.2), doorH / 2, -d / 2 - 0.8), Color = Color3.fromRGB(30, 20, 34), Parent = model })
		decor({ Name = "ArchNeon", Size = Vector3.new(0.3, doorH + 1, 0.3), CFrame = cf * CFrame.new(side * (doorW / 2 + 0.6), doorH / 2 + 0.5, -d / 2 - 1), Color = Color3.fromRGB(70, 220, 255), Material = Enum.Material.Neon, Parent = model })
		decor({ Name = "ArchCorner", Size = Vector3.new(1.4, 1.4, 1), CFrame = cf * CFrame.new(side * (doorW / 2 - 0.9), doorH - 0.1, -d / 2 - 0.8) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(30, 20, 34), Parent = model })
	end
	decor({ Name = "ArchTop", Size = Vector3.new(doorW - 1.4, 1, 1), CFrame = cf * CFrame.new(0, doorH + 0.4, -d / 2 - 0.8), Color = Color3.fromRGB(30, 20, 34), Parent = model })
	decor({ Name = "ArchNeonTop", Size = Vector3.new(doorW + 1.5, 0.3, 0.3), CFrame = cf * CFrame.new(0, doorH + 1, -d / 2 - 1), Color = Color3.fromRGB(70, 220, 255), Material = Enum.Material.Neon, Parent = model })
	light(model:FindFirstChild("DoorGlow"), doorColor, 16, 1.5)
	-- big slanted title sign across the lower facade
	local board = decor({ Name = "TitleSign", Size = Vector3.new(12, 3, 0.6), CFrame = cf * CFrame.new(0, 10.2, -d / 2 - 1.2) * CFrame.Angles(0, 0, math.rad(-6)), Color = Color3.fromRGB(30, 10, 24), Parent = model })
	surfaceText(board, title, signColor)
	-- neon tube along the roof line
	decor({ Name = "RoofNeon", Size = Vector3.new(w + 0.4, 0.4, 0.4), CFrame = cf * CFrame.new(0, h + 0.2, -d / 2 - 0.2), Color = Color3.fromRGB(70, 220, 255), Material = Enum.Material.Neon, Parent = model })
	-- giant 3D egg on the roof (in place of REF 3's skull)
	local eggCf = cf * CFrame.new(0, h + 5.5, -1)
	eggShape(model, "GiantEgg", eggCf, Vector3.new(7, 9.5, 7), Color3.fromRGB(255, 60, 86))
	for i = 1, 6 do
		local angle = i * math.pi * 2 / 6
		eggShape(model, "GiantEggSpot", eggCf * CFrame.new(math.cos(angle) * 3.2, (i % 2) * 2.2 - 0.8, math.sin(angle) * 3.2), Vector3.new(1.4, 1.8, 1.4), Color3.fromRGB(255, 220, 230))
	end
	return cf
end

-- Striped awning stall with a big cyan sign (REF 3 "MISCELLANEOUS SHOP!" stall), used for the tackle shop.
local function awningStall(parent, center, facing, title, subtitle)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
	local model = Instance.new("Model")
	model.Name = "TackleShop"
	model.Parent = parent
	local w, d = 14, 8
	part({ Name = "Floor", Size = Vector3.new(w + 1, 0.6, d + 1), CFrame = cf * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(84, 62, 52), Parent = model })
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			part({ Name = "StallPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = cf * CFrame.new(x, 4.5, z), Color = Color3.fromRGB(96, 66, 50), Parent = model })
		end
	end
	part({ Name = "BackBoard", Size = Vector3.new(w, 8, 0.6), CFrame = cf * CFrame.new(0, 4.6, d / 2), Color = Color3.fromRGB(124, 86, 62), Material = Enum.Material.WoodPlanks, Parent = model })
	-- red and cream striped awning, angled down toward the front
	local stripes = 8
	for i = 1, stripes do
		decor({
			Name = "Awning",
			Size = Vector3.new(w / stripes, 0.4, d + 3),
			CFrame = cf * CFrame.new(-w / 2 + (i - 0.5) * (w / stripes), 9.2, -1.2) * CFrame.Angles(math.rad(-16), 0, 0),
			Color = i % 2 == 0 and Color3.fromRGB(250, 226, 160) or Color3.fromRGB(214, 52, 52),
			Parent = model,
		})
	end
	for i = 1, stripes do
		decor({ Name = "AwningFlap", Size = Vector3.new(w / stripes, 1.2, 0.3), CFrame = cf * CFrame.new(-w / 2 + (i - 0.5) * (w / stripes), 7.8, -d / 2 - 2.8), Color = i % 2 == 0 and Color3.fromRGB(250, 226, 160) or Color3.fromRGB(214, 52, 52), Parent = model })
	end
	local counter = part({ Name = "Counter", Size = Vector3.new(w - 2, 3.4, 1.8), CFrame = cf * CFrame.new(0, 2.3, -d / 2 + 1.4), Color = Color3.fromRGB(150, 104, 68), Material = Enum.Material.WoodPlanks, Parent = model })
	for i = 1, 4 do
		decor({ Name = "DisplayRod", Size = Vector3.new(0.3, 6, 0.3), CFrame = cf * CFrame.new(-3 + i * 1.4, 4.2, d / 2 - 0.8) * CFrame.Angles(0, 0, math.rad(8)), Color = ({ TRUNK, Color3.fromRGB(230, 90, 100), Color3.fromRGB(80, 120, 230), GOLD })[i], Parent = model })
	end
	crate(model, cf * CFrame.new(w / 2 + 2, 1.3, -1))
	-- big cyan sign with a green subtitle above the awning
	local sign = decor({ Name = "ShopSign", Size = Vector3.new(w, 3.2, 0.5), CFrame = cf * CFrame.new(0, 12.6, -d / 2 + 0.6), Color = Color3.fromRGB(20, 16, 34), Parent = model })
	surfaceText(sign, title, Color3.fromRGB(110, 236, 255))
	local sub = decor({ Name = "ShopSubSign", Size = Vector3.new(w * 0.6, 1.2, 0.5), CFrame = cf * CFrame.new(0, 10.5, -d / 2 + 0.6), Color = Color3.fromRGB(20, 16, 34), Parent = model })
	surfaceText(sub, subtitle, Color3.fromRGB(120, 255, 140))
	decor({ Name = "SignNeon", Size = Vector3.new(w + 0.6, 0.3, 0.3), CFrame = cf * CFrame.new(0, 14.4, -d / 2 + 0.3), Color = Color3.fromRGB(110, 236, 255), Material = Enum.Material.Neon, Parent = model })
	return cf, counter
end

-- Small blue-grey house with a white roof (REF 1): the Hatchery behind the incubator.
local function greyHouse(parent, center, facing)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
	local model = Instance.new("Model")
	model.Name = "Hatchery"
	model.Parent = parent
	local w, d, h = 14, 11, 8
	part({ Name = "Floor", Size = Vector3.new(w + 1, 0.6, d + 1), CFrame = cf * CFrame.new(0, 0.3, 0), Color = STONE, Parent = model })
	part({ Name = "BackWall", Size = Vector3.new(w, h, 1), CFrame = cf * CFrame.new(0, h / 2, d / 2), Color = HOUSE_WALL, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SideWall", Size = Vector3.new(1, h, d), CFrame = cf * CFrame.new(side * w / 2, h / 2, 0), Color = HOUSE_WALL, Parent = model })
		part({ Name = "FrontWall", Size = Vector3.new(w / 2 - 2.5, h, 1), CFrame = cf * CFrame.new(side * (w / 4 + 1.25), h / 2, -d / 2), Color = HOUSE_WALL, Parent = model })
		decor({ Name = "Window", Size = Vector3.new(2.6, 2.6, 0.3), CFrame = cf * CFrame.new(side * (w / 4 + 1.25), h * 0.55, -d / 2 - 0.55), Color = Color3.fromRGB(46, 56, 72), Parent = model })
		decor({ Name = "WindowSill", Size = Vector3.new(3.2, 0.4, 0.6), CFrame = cf * CFrame.new(side * (w / 4 + 1.25), h * 0.55 - 1.5, -d / 2 - 0.6), Color = SNOW_CAP, Parent = model })
	end
	part({ Name = "DoorHeader", Size = Vector3.new(5, 2, 1), CFrame = cf * CFrame.new(0, h - 1, -d / 2), Color = HOUSE_WALL, Parent = model })
	local angle = math.rad(32)
	local half = d / 2 + 1.5
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "Roof", Size = Vector3.new(w + 2, 1.2, half), CFrame = cf * CFrame.new(0, h + math.sin(angle) * half / 2, dir * math.cos(angle) * half / 2) * CFrame.Angles(dir * angle, 0, 0), Color = SNOW_CAP, Parent = model })
	end
	decor({ Name = "Gable", Size = Vector3.new(0.8, math.sin(angle) * half * 1.6, d - 1), CFrame = cf * CFrame.new(w / 2, h + math.sin(angle) * half * 0.4, 0), Color = HOUSE_WALL, Parent = model })
	decor({ Name = "Gable", Size = Vector3.new(0.8, math.sin(angle) * half * 1.6, d - 1), CFrame = cf * CFrame.new(-w / 2, h + math.sin(angle) * half * 0.4, 0), Color = HOUSE_WALL, Parent = model })
	return cf
end

-- REF 5 props ---------------------------------------------------------------------------------

local PLASTER = Color3.fromRGB(238, 228, 208)
local TIMBER = Color3.fromRGB(96, 64, 46)
local ROOF_ORANGE = Color3.fromRGB(198, 112, 64)
local ROOF_SLATE = Color3.fromRGB(86, 98, 120)
local TORII_RED = Color3.fromRGB(176, 34, 30)
local TORII_BLACK = Color3.fromRGB(44, 34, 34)

-- Half-timbered house: cream plaster, dark timber frame and braces, steep tiled roof.
local function timberHouse(parent, center, facing, w, d, h, roofColor)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
	local model = Instance.new("Model")
	model.Name = "TimberHouse"
	model.Parent = parent
	part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = PLASTER, Parent = model })
	local front = -d / 2 - 0.15
	for _, x in ipairs({ -w / 2, -w / 6, w / 6, w / 2 }) do
		decor({ Name = "Timber", Size = Vector3.new(0.7, h, 0.4), CFrame = cf * CFrame.new(x, h / 2, front), Color = TIMBER, Parent = model })
	end
	for _, y in ipairs({ 0.4, h * 0.5, h - 0.3 }) do
		decor({ Name = "Timber", Size = Vector3.new(w + 0.2, 0.6, 0.4), CFrame = cf * CFrame.new(0, y, front), Color = TIMBER, Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Brace", Size = Vector3.new(0.5, h * 0.55, 0.4), CFrame = cf * CFrame.new(side * w / 3, h * 0.75, front) * CFrame.Angles(0, 0, side * math.rad(35)), Color = TIMBER, Parent = model })
		for _, z in ipairs({ -d / 4, d / 4 }) do
			decor({ Name = "SideTimber", Size = Vector3.new(0.4, h, 0.7), CFrame = cf * CFrame.new(side * (w / 2 + 0.15), h / 2, z), Color = TIMBER, Parent = model })
		end
		decor({ Name = "SideBand", Size = Vector3.new(0.4, 0.6, d), CFrame = cf * CFrame.new(side * (w / 2 + 0.15), h * 0.5, 0), Color = TIMBER, Parent = model })
	end
	for _, y in ipairs({ h * 0.28, h * 0.74 }) do
		for _, x in ipairs({ -w / 3, w / 3 }) do
			decor({ Name = "WindowFrame", Size = Vector3.new(2, 2.2, 0.3), CFrame = cf * CFrame.new(x, y, front - 0.15), Color = TIMBER, Parent = model })
			decor({ Name = "WindowPane", Size = Vector3.new(1.4, 1.6, 0.3), CFrame = cf * CFrame.new(x, y, front - 0.25), Color = Color3.fromRGB(40, 46, 60), Parent = model })
		end
	end
	decor({ Name = "Door", Size = Vector3.new(2.6, 4.2, 0.3), CFrame = cf * CFrame.new(0, 2.1, front - 0.15), Color = TIMBER, Parent = model })
	local angle = math.rad(45)
	local half = d / 2 + 1.2
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "Roof", Size = Vector3.new(w + 2, 0.9, half / math.cos(angle)), CFrame = cf * CFrame.new(0, h + math.tan(angle) * half / 2, dir * half / 2) * CFrame.Angles(dir * angle, 0, 0), Color = roofColor, Parent = model })
	end
	local gable = d / math.sqrt(2)
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Gable", Size = Vector3.new(0.6, gable, gable), CFrame = cf * CFrame.new(side * (w / 2 - 0.3), h, 0) * CFrame.Angles(math.rad(45), 0, 0), Color = PLASTER, Parent = model })
	end
	return cf
end

-- Red torii gate spanning along Z, with paper lanterns hanging from the lower beam.
local function toriiGate(parent, at, span, height)
	for _, z in ipairs({ -span / 2, span / 2 }) do
		part({ Name = "ToriiPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.8, 1.8), CFrame = CFrame.new(at.X, at.Y + height / 2, at.Z + z) * CFrame.Angles(0, 0, math.rad(90)), Color = TORII_RED, Parent = parent })
		part({ Name = "ToriiFoot", Size = Vector3.new(2.6, 1.2, 2.6), CFrame = CFrame.new(at.X, at.Y + 0.6, at.Z + z), Color = TORII_BLACK, Parent = parent })
	end
	decor({ Name = "Kasagi", Size = Vector3.new(2.2, 1.2, span + 7), CFrame = CFrame.new(at.X, at.Y + height + 0.9, at.Z), Color = TORII_BLACK, Parent = parent })
	decor({ Name = "Shimaki", Size = Vector3.new(2, 1, span + 5), CFrame = CFrame.new(at.X, at.Y + height, at.Z), Color = TORII_RED, Parent = parent })
	for _, z in ipairs({ -(span / 2 + 3.2), span / 2 + 3.2 }) do
		decor({ Name = "KasagiTip", Size = Vector3.new(2.2, 1, 1.6), CFrame = CFrame.new(at.X, at.Y + height + 1.5, at.Z + z) * CFrame.Angles(z > 0 and math.rad(-20) or math.rad(20), 0, 0), Color = TORII_BLACK, Parent = parent })
	end
	decor({ Name = "Nuki", Size = Vector3.new(1.4, 1, span + 3), CFrame = CFrame.new(at.X, at.Y + height - 3, at.Z), Color = TORII_RED, Parent = parent })
	decor({ Name = "Gakuzuka", Size = Vector3.new(1.2, 2.6, 1), CFrame = CFrame.new(at.X, at.Y + height - 1.5, at.Z), Color = TORII_RED, Parent = parent })
	for _, z in ipairs({ -span / 2 + 2.2, span / 2 - 2.2 }) do
		rod(parent, Vector3.new(at.X, at.Y + height - 3.5, at.Z + z), Vector3.new(at.X, at.Y + height - 4.6, at.Z + z), 0.15, TORII_BLACK)
		local lantern = decor({ Name = "PaperLantern", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(at.X, at.Y + height - 5.8, at.Z + z), Color = Color3.fromRGB(255, 236, 170), Material = Enum.Material.Neon, Transparency = 0.1, Parent = parent })
		light(lantern, Color3.fromRGB(255, 220, 150), 14, 1.2)
	end
end

local function buildNest(world)
	local nest = Instance.new("Folder")
	nest.Name = "Nest"
	nest.Parent = world
	local rng = Random.new(42)
	local plaza = Vector3.new(0, TOP, 0)

	part({ Name = "NestGround", Size = Vector3.new(200, 8, 220), CFrame = CFrame.new(-50, TOP - 4, 0), Color = SNOW_GROUND, Parent = nest })

	-- fountain: grey stone basin wall, gold rim, blue water, square tan monument in the middle
	disk(nest, "FountainWall", plaza + Vector3.new(0, 1.3, 0), 9, 2.6, STONE)
	disk(nest, "FountainRim", plaza + Vector3.new(0, 2.8, 0), 9.2, 0.5, GOLD)
	local water = disk(nest, "FountainWater", plaza + Vector3.new(0, 1.9, 0), 8, 2.4, FOUNTAIN_BLUE)
	water.CanCollide = false
	water.Transparency = 0.05
	part({ Name = "MonumentBase", Size = Vector3.new(6, 1.6, 6), CFrame = CFrame.new(plaza + Vector3.new(0, 3.2, 0)), Color = TAN, Parent = nest })
	part({ Name = "MonumentPlinth", Size = Vector3.new(4, 1.2, 4), CFrame = CFrame.new(plaza + Vector3.new(0, 4.6, 0)), Color = GOLD, Parent = nest })
	part({ Name = "MonumentColumn", Size = Vector3.new(2.6, 6, 2.6), CFrame = CFrame.new(plaza + Vector3.new(0, 8.2, 0)), Color = STONE, Parent = nest })
	part({ Name = "MonumentCollar", Size = Vector3.new(3.2, 0.8, 3.2), CFrame = CFrame.new(plaza + Vector3.new(0, 11.6, 0)), Color = TAN, Parent = nest })
	part({ Name = "MonumentCap", Size = Vector3.new(2.2, 2, 2.2), CFrame = CFrame.new(plaza + Vector3.new(0, 13, 0)), Color = STONE, Parent = nest })
	part({ Name = "MonumentTop", Size = Vector3.new(1, 1.2, 1), CFrame = CFrame.new(plaza + Vector3.new(0, 14.6, 0)), Color = GOLD, Parent = nest })
	particles(water, {
		Color = ColorSequence.new(Color3.fromRGB(210, 240, 255)),
		Rate = 12,
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -12, 0),
		Size = NumberSequence.new(0.3, 0.1),
		Transparency = NumberSequence.new(0.3, 1),
		EmissionDirection = Enum.NormalId.Right,
	})
	for i = 1, 4 do
		local angle = math.rad(45 + i * 90)
		local at = plaza + Vector3.new(math.cos(angle) * 9.4, 0, math.sin(angle) * 9.4)
		part({ Name = "FinialPillar", Size = Vector3.new(2.2, 4.4, 2.2), CFrame = CFrame.new(at + Vector3.new(0, 2.2, 0)), Color = STONE, Parent = nest })
		part({ Name = "FinialBall", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(at + Vector3.new(0, 5.5, 0)), Color = STONE, Parent = nest })
	end

	-- separate wooden plank steps leading out of the plaza
	plankSteps(nest, Vector3.new(12, 0, 0), Vector3.new(46, 0, 0), 6)
	plankSteps(nest, Vector3.new(-11, 0, 5), Vector3.new(-20, 0, 9), 5)
	plankSteps(nest, Vector3.new(-11, 0, -5), Vector3.new(-20, 0, -9), 5)
	plankSteps(nest, Vector3.new(5, 0, -11), Vector3.new(13, 0, -22), 5)
	plankSteps(nest, Vector3.new(8, 0, 9), Vector3.new(21, 0, 19), 5)
	plankSteps(nest, Vector3.new(0, 0, -12), Vector3.new(0, 0, -20), 5)

	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.new(0, TOP + 0.2, -24)
		spawn.Color = SNOW_GROUND
		spawn.Material = Enum.Material.SmoothPlastic
		for _, child in ipairs(spawn:GetChildren()) do
			if child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end

	-- Tide Egg shrine: REF 3 storefront behind a stone pedestal with the big spotted egg
	neonStorefront(nest, Vector3.new(-40, TOP, 14), plaza, "TIDE EGGS", Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 50, 80))
	local shrineAt = Vector3.new(-24, TOP, 12)
	part({ Name = "ShrineStep", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(shrineAt + Vector3.new(0, 0.5, 0)), Color = STONE, Parent = nest })
	local pedestal = part({ Name = "ShrinePedestal", Size = Vector3.new(7, 2, 7), CFrame = CFrame.new(shrineAt + Vector3.new(0, 2, 0)), Color = TAN, Parent = nest })
	local shrineEgg = eggShape(nest, "ShrineEgg", CFrame.new(shrineAt + Vector3.new(0, 6.6, 0)), Vector3.new(5, 7, 5), Color3.fromRGB(250, 246, 236))
	for i = 1, 5 do
		local angle = i * math.pi * 2 / 5
		eggShape(nest, "EggSpot", CFrame.new(shrineAt + Vector3.new(math.cos(angle) * 2.35, 6.2 + (i % 2) * 1.6, math.sin(angle) * 2.35)), Vector3.new(0.9, 1.1, 0.9), FOUNTAIN_BLUE)
	end
	prompt(pedestal, "Odds & Buy", "Tide Egg Shrine", { Panel = "Odds" })
	billboard(shrineEgg, "TIDE EGGS", "Odds and pity", 6)

	-- Incubator: wooden frame with straw and an egg, in front of the REF 1 grey house
	greyHouse(nest, Vector3.new(-40, TOP, -16), plaza)
	local incAt = Vector3.new(-24, TOP, -12)
	local incubatorBase = part({ Name = "IncubatorBase", Size = Vector3.new(8, 2, 8), CFrame = CFrame.new(incAt + Vector3.new(0, 1, 0)), Color = PLANK, Parent = nest })
	decor({ Name = "Straw", Size = Vector3.new(6.6, 0.6, 6.6), CFrame = CFrame.new(incAt + Vector3.new(0, 2.2, 0)), Color = Color3.fromRGB(232, 200, 110), Parent = nest })
	for _, x in ipairs({ -3.6, 3.6 }) do
		for _, z in ipairs({ -3.6, 3.6 }) do
			decor({ Name = "IncubatorPost", Size = Vector3.new(0.8, 6, 0.8), CFrame = CFrame.new(incAt + Vector3.new(x, 4, z)), Color = LAMP_WOOD, Parent = nest })
		end
	end
	decor({ Name = "IncubatorRoof", Size = Vector3.new(9, 0.8, 9), CFrame = CFrame.new(incAt + Vector3.new(0, 7.4, 0)), Color = SNOW_CAP, Parent = nest })
	eggShape(nest, "IncubatingEgg", CFrame.new(incAt + Vector3.new(0, 4, 0)), Vector3.new(2.6, 3.4, 2.6), Color3.fromRGB(248, 236, 210))
	prompt(incubatorBase, "Hatch Eggs", "Incubator", { Panel = "Odds" })
	billboard(incubatorBase, "INCUBATOR", "Hatch your eggs", 9)

	-- Tackle shop: REF 3 striped awning stall
	local _, counter = awningStall(nest, Vector3.new(18, TOP, -32), plaza, "TACKLE SHOP!", "RODS & BAIT")
	prompt(counter, "Rods & Bait", "Tackle Shop", { Panel = "Tackle" })
	crate(nest, CFrame.new(29, TOP + 1.3, -22) * CFrame.Angles(0, 0.3, 0))
	crate(nest, CFrame.new(29.4, TOP + 3.9, -22.2) * CFrame.Angles(0, 0.7, 0))

	-- Nest beacon: stone base with a crystal (the server recolours it when beacons close)
	part({ Name = "NestBeaconBase", Size = Vector3.new(6, 1.5, 6), CFrame = CFrame.new(26, TOP + 0.75, 22), Color = STONE, Parent = nest })
	local nestBeacon = part({ Name = "NestBeacon", Size = Vector3.new(2.6, 8, 2.6), CFrame = CFrame.new(26, TOP + 5.5, 22) * CFrame.Angles(0, math.rad(45), 0), Color = BEACON, Transparency = 0.1, Parent = nest })
	prompt(nestBeacon, "Extract", "Nest Beacon", { Action = "Extract" }, 1, 12)
	billboard(nestBeacon, "EXTRACT", "Bank your haul", 6)

	-- REF 5: timber houses lining the walk to the dock, and the torii gate with paper lanterns
	timberHouse(nest, Vector3.new(36, TOP, 18), Vector3.new(36, TOP, 0), 11, 9, 9, ROOF_ORANGE)
	timberHouse(nest, Vector3.new(36, TOP, -18), Vector3.new(36, TOP, 0), 11, 9, 9, ROOF_SLATE)
	timberHouse(nest, Vector3.new(38, TOP, 32), Vector3.new(38, TOP, 0), 10, 8, 12, ROOF_ORANGE)
	timberHouse(nest, Vector3.new(38, TOP, -32), Vector3.new(38, TOP, 0), 10, 8, 12, ROOF_ORANGE)
	toriiGate(nest, Vector3.new(47, TOP, 0), 11, 16)

	for _, at in ipairs({ Vector3.new(13, TOP, 7), Vector3.new(13, TOP, -7), Vector3.new(-13, TOP, 16), Vector3.new(-13, TOP, -16), Vector3.new(30, TOP, 5), Vector3.new(44, TOP, -5), Vector3.new(6, TOP, -28), Vector3.new(-6, TOP, 26) }) do
		lampPost(nest, at, plaza)
	end
	crate(nest, CFrame.new(44, TOP + 1.3, 8))
	crate(nest, CFrame.new(41.5, TOP + 1.3, 9.6) * CFrame.Angles(0, 0.5, 0))
	crate(nest, CFrame.new(-8, TOP + 1.3, -32))

	for _, at in ipairs({ Vector3.new(-40, TOP, -34), Vector3.new(26, TOP, 42), Vector3.new(-36, TOP, 34), Vector3.new(46, TOP, -44), Vector3.new(4, TOP, 38) }) do
		voxelTree(nest, at, rng, 1.2)
	end
	for _, at in ipairs({ Vector3.new(-40, TOP, 2), Vector3.new(-26, TOP, 40), Vector3.new(20, TOP, 42), Vector3.new(-14, TOP, -40) }) do
		pineTree(nest, at, 1.1)
	end
	for _, at in ipairs({ Vector3.new(-30, TOP, 36), Vector3.new(12, TOP, 30) }) do
		for i = 1, 3 do
			part({ Name = "StoneBlock", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(at + Vector3.new(i * 2.2 - 4, 1.2 + (i == 2 and 2.4 or 0), (i % 2) * 1.5)), Color = COBBLE, Material = Enum.Material.Cobblestone, Parent = nest })
		end
	end
	for _ = 1, 16 do
		local at = Vector3.new(rng:NextNumber(-44, 44), TOP, rng:NextNumber(-44, 44))
		if at.Magnitude > 14 and math.abs(at.Z) > 5 then
			flowerTuft(nest, at, rng)
		end
	end

	-- light snow drifting over the hub
	local snow = decor({ Name = "SnowEmitter", Size = Vector3.new(130, 1, 130), CFrame = CFrame.new(-10, 70, 0), Transparency = 1, Parent = nest })
	particles(snow, {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rate = 40,
		Lifetime = NumberRange.new(14, 18),
		Speed = NumberRange.new(3, 5),
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new(0.1),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(10, 10),
		Drag = 0.3,
		WindAffectsDrag = true,
	})

	-- dock out to the Shoals
	boardwalkSegment(nest, Vector3.new(47, 0, 0), Vector3.new(90, 0, 0), 8)
	billboard(decor({ Name = "BiomeSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(60, TOP + 7, 0), Transparency = 1, Parent = nest }), "SUNKEN SHOALS", "Hazard at heat 50: riptide pull", 0)

	buildTerraces(nest, rng)
end

-- Sunken Shoals (REF 2) ----------------------------------------------------------------------

local function latticeHut(parent, center, facing)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
	local model = Instance.new("Model")
	model.Name = "LatticeHut"
	model.Parent = parent
	local w, d, h = 12, 9, 8
	local frameColor = Color3.fromRGB(34, 36, 46)
	local wallColor = Color3.fromRGB(246, 246, 240)
	part({ Name = "Deck", Size = Vector3.new(w + 3, 1, d + 3), CFrame = cf * CFrame.new(0, 0.5, 0), Color = DECK, Parent = model })
	part({ Name = "Step", Size = Vector3.new(5, 0.6, 2), CFrame = cf * CFrame.new(0, 0.3, -d / 2 - 2.5), Color = DECK, Parent = model })
	part({ Name = "BackWall", Size = Vector3.new(w, h, 0.6), CFrame = cf * CFrame.new(0, 1 + h / 2, d / 2), Color = wallColor, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SideWall", Size = Vector3.new(0.6, h, d), CFrame = cf * CFrame.new(side * w / 2, 1 + h / 2, 0), Color = wallColor, Parent = model })
		part({ Name = "FrontWall", Size = Vector3.new(w / 2 - 2, h, 0.6), CFrame = cf * CFrame.new(side * (w / 4 + 1), 1 + h / 2, -d / 2), Color = wallColor, Parent = model })
		for _, z in ipairs({ -d / 2, d / 2 }) do
			part({ Name = "Post", Size = Vector3.new(0.8, h + 1, 0.8), CFrame = cf * CFrame.new(side * w / 2, 1 + h / 2, z), Color = frameColor, Parent = model })
		end
		-- tall dark lattice panel beside the door
		local panelX = side * (w / 4 + 1)
		for i = -1, 1 do
			decor({ Name = "Lattice", Size = Vector3.new(0.25, h - 1, 0.25), CFrame = cf * CFrame.new(panelX + i * 1.1, 1 + h / 2, -d / 2 - 0.4), Color = frameColor, Parent = model })
		end
		for j = 0, 3 do
			decor({ Name = "Lattice", Size = Vector3.new(2.6, 0.25, 0.25), CFrame = cf * CFrame.new(panelX, 2 + j * 2, -d / 2 - 0.4), Color = frameColor, Parent = model })
		end
		-- round window frame over the lattice
		local ringCf = cf * CFrame.new(panelX, 1 + h * 0.4, -d / 2 - 0.55) * CFrame.Angles(0, math.rad(90), 0)
		decor({ Name = "RoundWindow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.8, 2.8), CFrame = ringCf, Color = frameColor, Parent = model })
		decor({ Name = "RoundPane", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.2, 2.2), CFrame = ringCf, Color = Color3.fromRGB(196, 230, 250), Parent = model })
	end
	part({ Name = "DoorFrame", Size = Vector3.new(4.2, 0.6, 0.6), CFrame = cf * CFrame.new(0, 1 + h - 1, -d / 2), Color = frameColor, Parent = model })
	local angle = math.rad(22)
	local half = d / 2 + 3
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "Roof", Size = Vector3.new(w + 6, 0.9, half), CFrame = cf * CFrame.new(0, 1 + h + math.sin(angle) * half / 2, dir * math.cos(angle) * half / 2) * CFrame.Angles(dir * angle, 0, 0), Color = Color3.fromRGB(40, 44, 56), Parent = model })
	end
	-- upturned eave tips
	for _, x in ipairs({ -(w / 2 + 3), w / 2 + 3 }) do
		for _, dir in ipairs({ -1, 1 }) do
			decor({ Name = "EaveTip", Size = Vector3.new(1, 1.6, 1), CFrame = cf * CFrame.new(x, 1 + h + 0.4, dir * (half - 0.6)) * CFrame.Angles(dir * math.rad(-30), 0, 0), Color = Color3.fromRGB(40, 44, 56), Parent = model })
		end
	end
	decor({ Name = "Ridge", Size = Vector3.new(w + 7, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1 + h + math.sin(angle) * half, 0), Color = frameColor, Parent = model })
	-- vines over the roof edge
	for i = 1, 6 do
		decor({ Name = "Vine", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.2, 1.6), CFrame = cf * CFrame.new(-w / 2 - 1 + i * 2.2, 1 + h + 0.2, -half + 1.2), Color = CANOPY[(i % #CANOPY) + 1], Parent = model })
	end
	crystalLantern(model, (cf * CFrame.new(-w / 2 - 2, 1 + h, -d / 2 - 1.5)).Position, 3)
	crystalLantern(model, (cf * CFrame.new(w / 2 + 2, 1 + h, -d / 2 - 1.5)).Position, 3)
end

local function buildShoals(world)
	local shoals = Instance.new("Folder")
	shoals.Name = "SunkenShoals"
	shoals.Parent = world
	local rng = Random.new(1337)

	local byName = {}
	for _, island in ipairs(ISLANDS) do
		byName[island.name] = island
		local rock = island.name == "WardensRock"
		disk(shoals, island.name, Vector3.new(island.pos.X, TOP - 4, island.pos.Z), island.r, 8, rock and MINT_ROCK or SAND)
		if rock then
			for _ = 1, 8 do
				local angle = rng:NextNumber(0, math.pi * 2)
				mintRock(shoals, island.pos + Vector3.new(math.cos(angle) * rng:NextNumber(3, 9), TOP + 1, math.sin(angle) * rng:NextNumber(3, 9)), rng, 1.3)
			end
		else
			disk(shoals, island.name .. "Grass", Vector3.new(island.pos.X, TOP + 0.1, island.pos.Z), island.r - 1.5, 0.4, POND_GRASS)
			for _ = 1, 7 do
				local angle = rng:NextNumber(0, math.pi * 2)
				mintRock(shoals, island.pos + Vector3.new(math.cos(angle) * (island.r - 0.5), TOP - 0.3, math.sin(angle) * (island.r - 0.5)), rng, 1.2)
			end
			for _ = 1, 3 do
				local angle = rng:NextNumber(0, math.pi * 2)
				local dist = rng:NextNumber(4, island.r - 5)
				daisies(shoals, island.pos + Vector3.new(math.cos(angle) * dist, TOP + 0.3, math.sin(angle) * dist), rng)
			end
		end
	end

	for _, spec in ipairs({ { "ReefA", Vector3.new(-10, 0, 10) }, { "ReefB", Vector3.new(8, 0, -6) }, { "ReefC", Vector3.new(-7, 0, 6) }, { "ReefD", Vector3.new(-12, 0, -8) }, { "ReefE", Vector3.new(6, 0, 6) } }) do
		local island = byName[spec[1]]
		canopyTree(shoals, Vector3.new(island.pos.X, TOP, island.pos.Z) + spec[2], rng)
	end

	-- the giant lavender tree, on its own rock to the left of the dock
	disk(shoals, "LavenderRock", Vector3.new(92, TOP - 4.5, -40), 10, 8, POND_GRASS)
	giantLavenderTree(shoals, Vector3.new(92, TOP - 1, -40), rng)
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		mintRock(shoals, Vector3.new(92 + math.cos(angle) * 10, TOP - 0.5, -40 + math.sin(angle) * 10), rng, 1.4)
	end

	-- curving boardwalks between the reefs, with bamboo standing in the water beside them
	for i, link in ipairs(LINKS) do
		local a, b = byName[link[1]], byName[link[2]]
		local dir = (Vector3.new(b.pos.X, 0, b.pos.Z) - Vector3.new(a.pos.X, 0, a.pos.Z)).Unit
		local mid, side = curvedBoardwalk(shoals, a.pos + dir * (a.r - 3), b.pos - dir * (b.r - 3), 7, (i % 2 == 0) and 7 or -7)
		bambooCluster(shoals, mid + side * 9 - Vector3.new(0, 4, 0), rng)
		bambooCluster(shoals, mid - side * 10 + dir * 8 - Vector3.new(0, 4, 0), rng)
		clovers(shoals, mid + side * 6, rng)
	end

	latticeHut(shoals, Vector3.new(244, TOP, 24), byName.ReefD.pos)

	local spots = Instance.new("Folder")
	spots.Name = "FishingSpots"
	spots.Parent = shoals
	for i, pos in ipairs(FISHING_SPOTS) do
		local spot = part({
			Name = "FishingSpot" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 8, 8),
			CFrame = CFrame.new(pos.X, WATER_Y + 0.15, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SPOT,
			Transparency = 0.55,
			CanCollide = false,
			CastShadow = false,
			Parent = spots,
		})
		sparkles(spot, Color3.new(1, 1, 1), 4)
		prompt(spot, "Cast", "Fishing Spot", { Action = "Cast" }, 0, 16)
	end

	local nests = Instance.new("Folder")
	nests.Name = "EggNests"
	nests.Parent = shoals
	for i, pos in ipairs(EGG_NESTS) do
		disk(nests, "NestBase" .. i, Vector3.new(pos.X, TOP + 0.6, pos.Z), 2.8, 1, Color3.fromRGB(200, 164, 96))
		local egg = eggShape(nests, "WildEgg" .. i, CFrame.new(pos.X, TOP + 2.6, pos.Z), Vector3.new(2.4, 3.2, 2.4), Color3.fromRGB(232, 248, 255))
		sparkles(egg, Color3.fromRGB(200, 240, 255), 3)
		prompt(egg, "Steal Egg", "Wild Tide Egg", { Action = "Steal" }, 1, 10)
	end

	for i, pos in ipairs(BEACONS) do
		part({ Name = "BeaconBase" .. i, Size = Vector3.new(6, 1.5, 6), CFrame = CFrame.new(pos.X, TOP + 0.75, pos.Z), Color = MINT_ROCK, Parent = shoals })
		local crystal = part({ Name = "ExtractionBeacon" .. i, Size = Vector3.new(2.6, 8, 2.6), CFrame = CFrame.new(pos.X, TOP + 5.5, pos.Z) * CFrame.Angles(0, math.rad(45), 0), Color = BEACON, Transparency = 0.1, Parent = shoals })
		prompt(crystal, "Extract", "Extraction Beacon", { Action = "Extract" }, 1, 12)
		billboard(crystal, "EXTRACT", nil, 6)
	end

	for _ = 1, 50 do
		local at = Vector3.new(rng:NextNumber(60, 320), 0, rng:NextNumber(-130, 130))
		local clear = true
		for _, island in ipairs(ISLANDS) do
			if (Vector3.new(at.X, 0, at.Z) - Vector3.new(island.pos.X, 0, island.pos.Z)).Magnitude < island.r + 4 then
				clear = false
			end
		end
		if clear then
			if rng:NextNumber() < 0.5 then
				clovers(shoals, at, rng)
			else
				decor({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.6, 2.6), CFrame = CFrame.new(at.X, WATER_Y + 0.08, at.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(92, 186, 84), CastShadow = false, Parent = shoals })
			end
		end
	end
	for _ = 1, 10 do
		bambooCluster(shoals, Vector3.new(rng:NextNumber(70, 300), WATER_Y - 4, rng:NextNumber(-120, 120)), rng)
	end

	-- drifting petals over the pond
	local petals = decor({ Name = "PetalEmitter", Size = Vector3.new(240, 1, 240), CFrame = CFrame.new(190, 40, 0), Transparency = 1, Parent = shoals })
	particles(petals, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 255, 230)),
		Rate = 25,
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(2, 4),
		Size = NumberSequence.new(0.35),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		EmissionDirection = Enum.NormalId.Bottom,
		Drag = 0.4,
		WindAffectsDrag = true,
	})

	local path = Instance.new("Folder")
	path.Name = "WardenPath"
	path.Parent = shoals
	for i, name in ipairs(WARDEN_PATH) do
		local pos = byName[name].pos
		part({ Name = ("WP%02d"):format(i), Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pos.X, 8, pos.Z), Transparency = 1, CanCollide = false, CanQuery = false, Parent = path })
	end

	-- Reef Warden: the Sunken Shoals guardian, moved by the server
	local warden = Instance.new("Model")
	warden.Name = "ReefWarden"
	local lair = byName.WardensRock.pos
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(lair.X, 8, lair.Z), Color = Color3.fromRGB(40, 110, 120), CanCollide = false, Parent = warden })
	for _, side in ipairs({ -1, 1 }) do
		local eye = part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = body.CFrame * CFrame.new(side * 1.5, 1, -3), Color = Color3.fromRGB(255, 70, 60), Material = Enum.Material.Neon, CanCollide = false, Anchored = false, Massless = true, Parent = warden })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end
	for i = 1, 6 do
		local angle = i * math.pi * 2 / 6
		local spike = part({ Name = "Spike", Size = Vector3.new(0.8, 3, 0.8), CFrame = body.CFrame * CFrame.Angles(0, angle, math.rad(60)) * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(255, 140, 120), CanCollide = false, Anchored = false, Massless = true, Parent = warden })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = spike
		weld.Parent = spike
	end
	billboard(body, "REEF WARDEN", "Guardian of the Sunken Shoals", 6)
	warden.PrimaryPart = body
	warden.Parent = shoals
end

-- REF 5 sky: giant red-and-blue planet, slanted blue light beam, floating islands with waterfalls.
local function floatingIsland(parent, at, r, rng)
	for i = 0, 3 do
		disk(parent, "FloatingRock", at - Vector3.new(0, i * 3 + 1.5, 0), r * (1 - i * 0.22), 3, i == 0 and Color3.fromRGB(150, 120, 100) or Color3.fromRGB(120, 104, 100))
	end
	disk(parent, "FloatingGrass", at + Vector3.new(0, 0.3, 0), r, 0.8, GRASS)
	canopyTree(parent, at + Vector3.new(0, 0.6, 0), rng)
	local fall = decor({ Name = "Waterfall", Size = Vector3.new(0.6, 60, 4), CFrame = CFrame.new(at + Vector3.new(-r + 1, -30, 0)), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, Transparency = 0.45, CastShadow = false, Parent = parent })
	particles(fall, {
		Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)),
		Rate = 15,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(4, 8),
		Size = NumberSequence.new(1.5, 4),
		Transparency = NumberSequence.new(0.5, 1),
		EmissionDirection = Enum.NormalId.Bottom,
	})
end

local function buildSkyline(world)
	local sky = Instance.new("Folder")
	sky.Name = "Skyline"
	sky.Parent = world
	local rng = Random.new(77)
	local planetAt = Vector3.new(760, 420, 80)
	decor({ Name = "Planet", Shape = Enum.PartType.Ball, Size = Vector3.new(420, 420, 420), CFrame = CFrame.new(planetAt), Color = Color3.fromRGB(196, 214, 246), CastShadow = false, Parent = sky })
	decor({ Name = "PlanetBurn", Shape = Enum.PartType.Ball, Size = Vector3.new(380, 380, 380), CFrame = CFrame.new(planetAt + Vector3.new(-30, 70, 0)), Color = Color3.fromRGB(226, 52, 58), Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, Parent = sky })
	local a, b = Vector3.new(64, 0, 40), Vector3.new(10, 300, 150)
	for _, layer in ipairs({ { 7, Color3.fromRGB(110, 160, 255), 0.4 }, { 3, Color3.fromRGB(210, 232, 255), 0.1 } }) do
		local beam = rod(sky, a, b, layer[1], layer[2])
		beam.Name = "LightBeam"
		beam.Material = Enum.Material.Neon
		beam.Transparency = layer[3]
		beam.CastShadow = false
	end
	floatingIsland(sky, Vector3.new(380, 90, -110), 14, rng)
	floatingIsland(sky, Vector3.new(430, 130, 70), 18, rng)
	floatingIsland(sky, Vector3.new(350, 160, 190), 12, rng)
end

function WorldBuilder.build()
	local existing = workspace:FindFirstChild("TideboundWorld")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	setupEnvironment()
	local world = Instance.new("Folder")
	world.Name = "TideboundWorld"
	world:SetAttribute("Version", VERSION)
	buildNest(world)
	buildShoals(world)
	buildSkyline(world)
	world.Parent = workspace
	return world
end

-- Shared props and palette so the Delta areas (see ExpansionBuilder) are built in the same style.
WorldBuilder.kit = {
	part = part,
	decor = decor,
	windy = windy,
	disk = disk,
	rod = rod,
	light = light,
	particles = particles,
	sparkles = sparkles,
	billboard = billboard,
	prompt = prompt,
	eggShape = eggShape,
	surfaceText = surfaceText,
	voxelTree = voxelTree,
	pineTree = pineTree,
	lampPost = lampPost,
	crate = crate,
	flowerTuft = flowerTuft,
	plankSteps = plankSteps,
	terraceBlock = terraceBlock,
	boardwalkSegment = boardwalkSegment,
	crystalLantern = crystalLantern,
	bambooCluster = bambooCluster,
	neonStorefront = neonStorefront,
	awningStall = awningStall,
	greyHouse = greyHouse,
	timberHouse = timberHouse,
	toriiGate = toriiGate,
	latticeHut = latticeHut,
	TOP = TOP,
	WATER_Y = WATER_Y,
	color = {
		SNOW_GROUND = SNOW_GROUND,
		SNOW_CAP = SNOW_CAP,
		DIRT = DIRT,
		COBBLE = COBBLE,
		GRASS = GRASS,
		STONE = STONE,
		GOLD = GOLD,
		TAN = TAN,
		FOUNTAIN_BLUE = FOUNTAIN_BLUE,
		TRUNK = TRUNK,
		LAMP_WOOD = LAMP_WOOD,
		LANTERN_ORANGE = LANTERN_ORANGE,
		PLANK = PLANK,
		PLANK_EDGE = PLANK_EDGE,
		HOUSE_WALL = HOUSE_WALL,
		DECK = DECK,
		POST = POST,
		ROPE = ROPE,
		CRYSTAL = CRYSTAL,
		BEACON = BEACON,
		PLASTER = PLASTER,
		TIMBER = TIMBER,
		ROOF_ORANGE = ROOF_ORANGE,
		ROOF_SLATE = ROOF_SLATE,
		TORII_RED = TORII_RED,
	},
}

return WorldBuilder
