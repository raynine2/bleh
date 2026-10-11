-- Tidebound: Eggfall: builds the Nest plaza at the heart of Eggfall Town, the sky, and the shared prop kit.
-- Nest (refs/REF 1): snowy white blocky plaza, a round blue fountain with a gold rim and a square monument,
-- separate wooden plank steps, voxel trees, the egg shrine, incubator and tackle shop.
-- Patch 10 (the Open Isles): the town around the plaza is TownBuilder's and the Sunken Shoals are
-- ShoalsBuilder's, both laid out by IslesLayout; they build with this file's kit (REF 2 boardwalks, bamboo,
-- the lavender tree and lattice huts, REF 3 shops, REF 5 timber houses and torii).
-- Safe to run in Edit mode (the result is saved with the place) or at server start.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local WorldBuilder = {}

local VERSION = 14

-- REF 1 palette
-- Patch 12: the snow is a soft blue-grey, not paper white, so it doesn't glare
local SNOW_GROUND = Color3.fromRGB(168, 182, 206)
local SNOW_CAP = Color3.fromRGB(186, 198, 220)
local DIRT = Color3.fromRGB(146, 104, 82)
local DIRT_DARK = Color3.fromRGB(122, 86, 70)
local COBBLE = Color3.fromRGB(128, 132, 140)
local GRASS = Color3.fromRGB(64, 176, 84)
local STONE = Color3.fromRGB(172, 178, 190)
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
local MINT_ROCK = Color3.fromRGB(150, 196, 178)
local CRYSTAL = Color3.fromRGB(196, 238, 255)
local SAND = Color3.fromRGB(96, 178, 86)
local BEACON = Color3.fromRGB(90, 255, 200)

local TOP = 6 -- walkable surface height for the nest, reefs and boardwalks
local WATER_Y = 4
local SEA_FLOOR = -14 -- IslesLayout.sea.floorY: pilings reach down to it

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

-- Patch 13: voxel trees in the reference style. A thick trunk with a root flare and a branch or two, and a
-- crown heaped from chunky cubes in three tiers: darker cubes underneath, lighter ones on top.
local function voxelTree(parent, base, rng, scale)
	scale = scale or 1
	local s = scale
	local height = rng:NextNumber(6, 8.5) * s
	local w = 2.2 * s
	decor({ Name = "TreeRoot", Size = Vector3.new(w * 1.8, 0.9 * s, w * 1.8), CFrame = CFrame.new(base + Vector3.new(0, 0.45 * s, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = TRUNK, Parent = parent })
	decor({ Name = "TreeTrunk", Size = Vector3.new(w, height, w), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)), Color = TRUNK, Parent = parent })
	decor({ Name = "TreeTrunkLight", Size = Vector3.new(w * 0.4, height * 0.8, w + 0.1), CFrame = CFrame.new(base + Vector3.new(w * 0.25, height * 0.45, 0)), Color = TRUNK:Lerp(Color3.new(1, 1, 1), 0.12), Parent = parent })
	for _ = 1, rng:NextInteger(1, 2) do
		local a = rng:NextNumber(0, math.pi * 2)
		local from = base + Vector3.new(0, height * rng:NextNumber(0.55, 0.8), 0)
		decor({ Name = "TreeBranch", Size = Vector3.new(1.1 * s, 1.1 * s, 3.4 * s), CFrame = CFrame.lookAt(from, from + Vector3.new(math.cos(a), 0.6, math.sin(a))) * CFrame.new(0, 0, -1.4 * s), Color = TRUNK, Parent = parent })
	end
	local top = base + Vector3.new(0, height, 0)
	local dark = LEAF[3]
	local light = LEAF[2]:Lerp(Color3.fromRGB(190, 240, 120), 0.25)
	local function cube(offset, size, color)
		windy(decor({ Name = "TreeLeaves", Size = Vector3.new(size, size * 0.9, size), CFrame = CFrame.new(top + offset) * CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0), Color = color, Parent = parent }))
	end
	-- bottom tier: a wide ring of dark cubes
	local n = rng:NextInteger(6, 8)
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(2.6, 3.6) * s
		cube(Vector3.new(math.cos(a) * r, rng:NextNumber(-0.5, 0.5) * s, math.sin(a) * r), rng:NextNumber(3.4, 4.6) * s, (i % 3 == 0) and LEAF[1] or dark)
	end
	cube(Vector3.new(0, 0, 0), 5 * s, dark)
	-- middle tier
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(1.4, 2.2) * s
		cube(Vector3.new(math.cos(a) * r, rng:NextNumber(2.2, 3) * s, math.sin(a) * r), rng:NextNumber(3, 4) * s, LEAF[1])
	end
	-- top: one or two bright cubes
	cube(Vector3.new(rng:NextNumber(-0.6, 0.6) * s, 4.8 * s, rng:NextNumber(-0.6, 0.6) * s), rng:NextNumber(2.8, 3.6) * s, light)
	if rng:NextNumber() < 0.5 then
		cube(Vector3.new(rng:NextNumber(-1.5, 1.5) * s, 4 * s, rng:NextNumber(-1.5, 1.5) * s), 2.4 * s, light)
	end
end

-- Snowy voxel pine: tiers made of a cross of boxes, each tier capped with a little snow (REF 1).
local function pineTree(parent, base, scale)
	scale = scale or 1
	local s = scale
	decor({ Name = "PineTrunk", Size = Vector3.new(1.6 * s, 3 * s, 1.6 * s), CFrame = CFrame.new(base + Vector3.new(0, 1.5 * s, 0)), Color = TRUNK, Parent = parent })
	local y = base.Y + 2.6 * s
	for i, size in ipairs({ 7, 5.8, 4.6, 3.4, 2.2 }) do
		local w = size * s
		local h = 2.4 * s
		local color = PINE[(i % #PINE) + 1]:Lerp(Color3.fromRGB(40, 110, 70), 0.45)
		local c = Vector3.new(base.X, y + h / 2, base.Z)
		windy(decor({ Name = "PineTier", Size = Vector3.new(w, h, w * 0.62), CFrame = CFrame.new(c), Color = color, Parent = parent }))
		windy(decor({ Name = "PineTier", Size = Vector3.new(w * 0.62, h, w), CFrame = CFrame.new(c), Color = color, Parent = parent }))
		decor({ Name = "PineSnow", Size = Vector3.new(w * 0.7, 0.35 * s, w * 0.42), CFrame = CFrame.new(c + Vector3.new(0, h / 2 + 0.1, 0)), Color = SNOW_CAP, Parent = parent })
		decor({ Name = "PineSnow", Size = Vector3.new(w * 0.42, 0.35 * s, w * 0.7), CFrame = CFrame.new(c + Vector3.new(0, h / 2 + 0.1, 0)), Color = SNOW_CAP, Parent = parent })
		y += h * 0.82
	end
end

local function lampPost(parent, base, facing)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	decor({ Name = "LampFoot", Size = Vector3.new(1.6, 0.8, 1.6), CFrame = cf * CFrame.new(0, 0.4, 0), Color = Color3.fromRGB(70, 72, 82), Parent = parent })
	decor({ Name = "LampPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = cf * CFrame.new(0, 4.5, 0), Color = LAMP_WOOD, Parent = parent })
	decor({ Name = "LampRing", Size = Vector3.new(1.1, 0.4, 1.1), CFrame = cf * CFrame.new(0, 3, 0), Color = Color3.fromRGB(70, 72, 82), Parent = parent })
	decor({ Name = "LampArm", Size = Vector3.new(0.4, 0.4, 2.2), CFrame = cf * CFrame.new(0, 8.4, -1), Color = LAMP_WOOD, Parent = parent })
	decor({ Name = "LampFrame", Size = Vector3.new(1.3, 1.6, 1.3), CFrame = cf * CFrame.new(0, 7.3, -1.9), Color = Color3.fromRGB(46, 40, 40), Transparency = 0.5, Parent = parent })
	local glow = decor({ Name = "LampLantern", Size = Vector3.new(0.9, 1.2, 0.9), CFrame = cf * CFrame.new(0, 7.3, -1.9), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, Parent = parent })
	decor({ Name = "LampCap", Size = Vector3.new(1.6, 0.4, 1.6), CFrame = cf * CFrame.new(0, 8.25, -1.9), Color = LAMP_WOOD, Parent = parent })
	light(glow, Color3.fromRGB(255, 196, 120), 16, 1)
end

-- Patch 13: blocky ground. A disc (or ring, with `inner`) built from strips snapped to a grid, so coasts and
-- floors have the reference's stepped voxel edge, with classic studs on top.
local function voxelDisk(parent, name, center, radius, bottom, top, color, step, inner, material)
	step = step or 4
	local made = {}
	local rows = math.ceil(radius / step)
	for i = -rows, rows - 1 do
		local zc = (i + 0.5) * step
		if math.abs(zc) < radius then
			local half = math.floor(math.sqrt(radius * radius - zc * zc) / step + 0.5) * step
			if half >= step * 0.5 then
				local spans = { { -half, half } }
				if inner and math.abs(zc) < inner then
					local ih = math.floor(math.sqrt(inner * inner - zc * zc) / step + 0.5) * step
					spans = { { -half, -ih }, { ih, half } }
				end
				for _, span in ipairs(spans) do
					local w = span[2] - span[1]
					if w > 0.5 then
						local p = part({ Name = name, Size = Vector3.new(w, top - bottom, step), CFrame = CFrame.new(center.X + (span[1] + span[2]) / 2, (top + bottom) / 2, center.Z + zc), Color = color, Material = material or Enum.Material.Plastic, Parent = parent })
						p.TopSurface = Enum.SurfaceType.Studs
						table.insert(made, p)
					end
				end
			end
		end
	end
	return made
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
			local depth = base.Y - SEA_FLOOR
			decor({ Name = "Piling", Size = Vector3.new(1, depth, 1), CFrame = base * CFrame.new(0, -depth / 2, 0), Color = POST, Parent = parent })
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
	-- Patch 14: the reference winter town's look. A high, cool sun; strong blue-tinted ambient so shadows stay
	-- soft and coloured, never black; a pale blue haze that swallows the distance; saturated colour; and bloom
	-- low enough to make windows, lanterns, neon and ice glow. (Set Lighting.Technology to Future in Studio for
	-- the lanterns and windows to light their surroundings like the references.)
	-- Patch 15: much dimmer. The snow glared because bright ambient, high exposure and a low bloom threshold all
	-- stacked on near-white ground; now the light is softer and only real light sources (neon, lanterns) bloom.
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 1.5
	Lighting.ExposureCompensation = -0.65
	Lighting.Ambient = Color3.fromRGB(92, 102, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(108, 120, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(200, 214, 240)
	Lighting.ColorShift_Bottom = Color3.fromRGB(90, 110, 150)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(150, 176, 214)
	atmosphere.Decay = Color3.fromRGB(92, 120, 176)
	atmosphere.Glare = 0
	atmosphere.Haze = 1
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
	effect("ColorCorrectionEffect", "TideboundGrade", { Saturation = 0.2, Contrast = 0.14, Brightness = -0.1, TintColor = Color3.fromRGB(232, 240, 255) })
	effect("BloomEffect", "TideboundBloom", { Intensity = 0.25, Size = 22, Threshold = 2.2 })
	effect("SunRaysEffect", "TideboundSunRays", { Intensity = 0.015, Spread = 0.5 })

	workspace.GlobalWind = Vector3.new(6, 0, 3)

	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(56, 190, 190)
	terrain.WaterTransparency = 0.65
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.06
	terrain.WaterWaveSpeed = 5
	-- the sea itself (terrain water over a sand floor) is ShoalsBuilder's

	-- the baseplate sinks under the sea floor so the sea is deep enough to swim and for sharks
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.CFrame = CFrame.new(baseplate.Position.X, SEA_FLOOR - 3 - baseplate.Size.Y / 2, baseplate.Position.Z)
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

-- Patch 13: a detailed half-timbered cottage. A stone foundation, plaster walls with a timber frame and braces,
-- framed glass windows with sills and flower boxes, a panelled door under a little porch roof with a lantern, a
-- stepped roof of studded rows with eaves, and a chimney with wisps of smoke that drift in the wind.
local function timberHouse(parent, center, facing, w, d, h, roofColor)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
	local model = Instance.new("Model")
	model.Name = "TimberHouse"
	model.Parent = parent
	local stone = Color3.fromRGB(150, 150, 160)
	part({ Name = "Foundation", Size = Vector3.new(w + 1, 1.4, d + 1), CFrame = cf * CFrame.new(0, 0.7, 0), Color = stone, Material = Enum.Material.Plastic, Parent = model }).TopSurface = Enum.SurfaceType.Studs
	for x = -w / 2, w / 2 - 1, 2.2 do
		decor({ Name = "FoundationStone", Size = Vector3.new(2, 1, 0.3), CFrame = cf * CFrame.new(x + 1.1, 0.75, -d / 2 - 0.55), Color = (math.floor(x) % 2 == 0) and stone:Lerp(Color3.new(0, 0, 0), 0.12) or stone, Parent = model })
	end
	local base = 1.4
	part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, base + h / 2, 0), Color = PLASTER, Parent = model })
	local front = -d / 2 - 0.15
	for _, x in ipairs({ -w / 2, -w / 6, w / 6, w / 2 }) do
		decor({ Name = "Timber", Size = Vector3.new(0.7, h, 0.4), CFrame = cf * CFrame.new(x, base + h / 2, front), Color = TIMBER, Parent = model })
	end
	for _, y in ipairs({ 0.3, h * 0.5, h - 0.3 }) do
		decor({ Name = "Timber", Size = Vector3.new(w + 0.2, 0.6, 0.4), CFrame = cf * CFrame.new(0, base + y, front), Color = TIMBER, Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Brace", Size = Vector3.new(0.5, h * 0.55, 0.4), CFrame = cf * CFrame.new(side * w / 3, base + h * 0.75, front) * CFrame.Angles(0, 0, side * math.rad(35)), Color = TIMBER, Parent = model })
		for _, z in ipairs({ -d / 2, 0, d / 2 }) do
			decor({ Name = "SideTimber", Size = Vector3.new(0.4, h, 0.7), CFrame = cf * CFrame.new(side * (w / 2 + 0.15), base + h / 2, z), Color = TIMBER, Parent = model })
		end
		decor({ Name = "SideBand", Size = Vector3.new(0.4, 0.6, d), CFrame = cf * CFrame.new(side * (w / 2 + 0.15), base + h * 0.5, 0), Color = TIMBER, Parent = model })
		-- a side window too
		decor({ Name = "SideWindow", Size = Vector3.new(0.3, 2, 1.8), CFrame = cf * CFrame.new(side * (w / 2 + 0.3), base + h * 0.72, 0), Color = Color3.fromRGB(255, 226, 160), Material = Enum.Material.Neon, Transparency = 0.35, Parent = model })
	end
	-- framed windows with glass, sills and flower boxes
	local flowers = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 210, 80), Color3.fromRGB(200, 120, 255) }
	for row, y in ipairs({ h * 0.28, h * 0.74 }) do
		for _, x in ipairs({ -w / 3, w / 3 }) do
			local at = cf * CFrame.new(x, base + y, front - 0.15)
			decor({ Name = "WindowFrame", Size = Vector3.new(2.4, 2.6, 0.3), CFrame = at, Color = TIMBER, Parent = model })
			decor({ Name = "WindowGlass", Size = Vector3.new(1.8, 2, 0.3), CFrame = at * CFrame.new(0, 0, -0.08), Color = Color3.fromRGB(150, 200, 230), Material = Enum.Material.Glass, Transparency = 0.25, Parent = model })
			decor({ Name = "Mullion", Size = Vector3.new(0.2, 2, 0.35), CFrame = at * CFrame.new(0, 0, -0.12), Color = TIMBER, Parent = model })
			decor({ Name = "Mullion", Size = Vector3.new(1.8, 0.2, 0.35), CFrame = at * CFrame.new(0, 0, -0.12), Color = TIMBER, Parent = model })
			decor({ Name = "Sill", Size = Vector3.new(2.8, 0.3, 0.7), CFrame = at * CFrame.new(0, -1.45, -0.3), Color = Color3.fromRGB(230, 226, 214), Parent = model })
			if row == 1 then
				decor({ Name = "FlowerBox", Size = Vector3.new(2.4, 0.6, 0.6), CFrame = at * CFrame.new(0, -1.85, -0.45), Color = TIMBER, Parent = model })
				for k = -1, 1 do
					windy(decor({ Name = "Flower", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = at * CFrame.new(k * 0.7, -1.35, -0.45), Color = flowers[(k + 2)], Parent = model }))
				end
			end
		end
	end
	-- the door, a step and a little porch roof with a lantern
	local door = cf * CFrame.new(0, base + 2.2, front - 0.15)
	decor({ Name = "DoorFrame", Size = Vector3.new(3.2, 4.8, 0.3), CFrame = door, Color = TIMBER:Lerp(Color3.new(0, 0, 0), 0.2), Parent = model })
	decor({ Name = "Door", Size = Vector3.new(2.6, 4.3, 0.3), CFrame = door * CFrame.new(0, -0.15, -0.08), Color = Color3.fromRGB(150, 90, 56), Parent = model })
	for _, y in ipairs({ -1, 1 }) do
		decor({ Name = "DoorPanel", Size = Vector3.new(1.8, 1.4, 0.2), CFrame = door * CFrame.new(0, y * 1, -0.2), Color = Color3.fromRGB(126, 74, 46), Parent = model })
	end
	decor({ Name = "Knob", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = door * CFrame.new(0.9, -0.2, -0.3), Color = GOLD, Parent = model })
	part({ Name = "Step", Size = Vector3.new(3.6, 0.6, 1.4), CFrame = cf * CFrame.new(0, 0.3, -d / 2 - 1.1), Color = stone, Material = Enum.Material.Plastic, Parent = model }).TopSurface = Enum.SurfaceType.Studs
	decor({ Name = "PorchRoof", Size = Vector3.new(4.4, 0.4, 1.8), CFrame = cf * CFrame.new(0, base + 5.1, front - 0.8) * CFrame.Angles(math.rad(-15), 0, 0), Color = roofColor, Parent = model })
	local lantern = decor({ Name = "DoorLantern", Size = Vector3.new(0.7, 0.9, 0.7), CFrame = cf * CFrame.new(2.1, base + 3.8, front - 0.5), Color = Color3.fromRGB(255, 210, 140), Material = Enum.Material.Neon, Parent = model })
	light(lantern, Color3.fromRGB(255, 200, 130), 12, 0.8)
	-- the roof: rows of studded slabs stepping up to the ridge, with eaves and a ridge beam
	local rows = 5
	local half = d / 2 + 1.2
	local rise = math.min(h * 0.7, half)
	for _, dir in ipairs({ -1, 1 }) do
		for i = 0, rows - 1 do
			local s = i / rows
			local slab = part({ Name = "RoofRow", Size = Vector3.new(w + 2, 0.9, half / rows + 0.5), CFrame = cf * CFrame.new(0, base + h + rise * s + 0.45, dir * (half - (i + 0.5) * half / rows)), Color = (i % 2 == 0) and roofColor or roofColor:Lerp(Color3.new(0, 0, 0), 0.12), Material = Enum.Material.Plastic, CanCollide = false, Parent = model })
			slab.TopSurface = Enum.SurfaceType.Studs
		end
	end
	decor({ Name = "Ridge", Size = Vector3.new(w + 2.4, 0.8, 1.2), CFrame = cf * CFrame.new(0, base + h + rise + 0.6, 0), Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.3), Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		-- gable ends stepped to follow the roof
		for i = 0, rows - 1 do
			local s = i / rows
			decor({ Name = "Gable", Size = Vector3.new(0.6, rise / rows + 0.1, 2 * (half - i * half / rows) - 1.4), CFrame = cf * CFrame.new(side * (w / 2 - 0.3), base + h + rise * s + rise / rows / 2, 0), Color = PLASTER, Parent = model })
		end
	end
	-- the chimney, smoking
	local chimney = decor({ Name = "Chimney", Size = Vector3.new(1.6, rise + 3, 1.6), CFrame = cf * CFrame.new(w / 3, base + h + (rise + 3) / 2, d / 4), Color = Color3.fromRGB(170, 96, 80), Parent = model })
	decor({ Name = "ChimneyCap", Size = Vector3.new(2, 0.5, 2), CFrame = chimney.CFrame * CFrame.new(0, (rise + 3) / 2, 0), Color = Color3.fromRGB(80, 70, 70), Parent = model })
	particles(chimney, {
		Color = ColorSequence.new(Color3.fromRGB(230, 230, 236)),
		Rate = 3,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 3),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 0.5,
		WindAffectsDrag = true,
	})
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

-- Patch 15: the hub plaza (the egg shop, incubator, tackle stall, Nest beacon and everything round them) is
-- TownBuilder's now, built from the reference-style PropKit. This only keeps the Nest folder and the spawn.
local function buildNest(world)
	local nest = Instance.new("Folder")
	nest.Name = "Nest"
	nest.Parent = world
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.new(0, TOP + 0.4, -24)
		spawn.Color = Color3.fromRGB(150, 162, 186)
		spawn.Material = Enum.Material.Plastic
		spawn.TopSurface = Enum.SurfaceType.Studs
		for _, child in ipairs(spawn:GetChildren()) do
			if child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
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

-- Reef Warden: the Sunken Shoals guardian, moved by the server. ShoalsBuilder puts it at Warden's Rock.
local function reefWarden(parent, lair)
	local warden = Instance.new("Model")
	warden.Name = "ReefWarden"
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
	warden.Parent = parent
	return warden
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
	-- the planet hangs over the open sea, so it fills the view east from the town toward the Shoals
	local planetAt = Vector3.new(1050, 600, 120)
	decor({ Name = "Planet", Shape = Enum.PartType.Ball, Size = Vector3.new(600, 600, 600), CFrame = CFrame.new(planetAt), Color = Color3.fromRGB(196, 214, 246), CastShadow = false, Parent = sky })
	decor({ Name = "PlanetBurn", Shape = Enum.PartType.Ball, Size = Vector3.new(544, 544, 544), CFrame = CFrame.new(planetAt + Vector3.new(-44, 100, 0)), Color = Color3.fromRGB(226, 52, 58), Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, Parent = sky })
	-- the slanted beam rises from the shrine on top of Torii Hill (IslesLayout.Town.districts.ToriiHill)
	local a, b = Vector3.new(-150, 44, 15), Vector3.new(-210, 380, 150)
	for _, layer in ipairs({ { 7, Color3.fromRGB(110, 160, 255), 0.4 }, { 3, Color3.fromRGB(210, 232, 255), 0.1 } }) do
		local beam = rod(sky, a, b, layer[1], layer[2])
		beam.Name = "LightBeam"
		beam.Material = Enum.Material.Neon
		beam.Transparency = layer[3]
		beam.CastShadow = false
	end
	floatingIsland(sky, Vector3.new(420, 120, -150), 16, rng)
	floatingIsland(sky, Vector3.new(560, 160, 110), 20, rng)
	floatingIsland(sky, Vector3.new(330, 180, 270), 12, rng)
	floatingIsland(sky, Vector3.new(980, 210, -560), 18, rng)
	floatingIsland(sky, Vector3.new(1250, 190, 330), 14, rng)
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
	voxelDisk = voxelDisk,
	toriiGate = toriiGate,
	latticeHut = latticeHut,
	TOP = TOP,
	WATER_Y = WATER_Y,
	-- REF 2 Shoals props
	canopyTree = canopyTree,
	giantLavenderTree = giantLavenderTree,
	mintRock = mintRock,
	clovers = clovers,
	daisies = daisies,
	curvedBoardwalk = curvedBoardwalk,
	reefWarden = reefWarden,
	SEA_FLOOR = SEA_FLOOR,
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
		MINT_ROCK = MINT_ROCK,
		BAMBOO = BAMBOO,
		POND_GRASS = POND_GRASS,
		SAND = SAND,
		BARK = BARK,
		LEAF = LEAF,
		CANOPY = CANOPY,
	},
}

return WorldBuilder
