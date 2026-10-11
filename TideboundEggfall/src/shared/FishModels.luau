-- Tidebound: Eggfall: placeholder fish models for the landing flip and the reveal (Master Patches 5 and 6).
-- Blocky like the creature models, with ellipsoid bodies. The shape and size come from the fish, so a Riptide
-- Marlin's silhouette is longer than a Reef Sprat's before any colour shows. The head points along -Z.
-- Every part is anchored; move the model with PivotTo. FishModels.paint fills it with one colour (the dark
-- silhouette, then each rarity tier as the reveal climbs).

local FishModels = {}

FishModels.SILHOUETTE = Color3.fromRGB(46, 48, 56)

local SHAPES = {
	["Sunfin Ray"] = "ray",
	["Pearl Moray"] = "eel",
	["Gilded Barracuda"] = "long",
	["Riptide Marlin"] = "marlin",
	["Lantern Puffer"] = "round",
	["Eggfall Koi"] = "koi",
	-- Kelp Cathedral (Big Update)
	["Kelp Darter"] = "long",
	["Vine Pipefish"] = "eel",
	["Choir Grouper"] = "round",
	["Stained-Glass Ray"] = "ray",
	["Bishop Eel"] = "eel",
	["Cathedral Sturgeon"] = "long",
	["Gilded Seahorse"] = "seahorse",
	["Hymnal Oarfish"] = "eel",
	["Halo Koi"] = "koi",
}
local STRETCH = { eel = 1.6, long = 1.45, marlin = 1.8, round = 0.85, ray = 1.1, koi = 1.2, seahorse = 0.9 }

-- Body length in studs: grows with the tier and the fish's shape.
function FishModels.length(name, tierIndex)
	return (1.6 + 0.3 * (tierIndex or 1)) * (STRETCH[SHAPES[name] or ""] or 1)
end

local function piece(model, name, size, cframe, shade, shape, mesh)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = FishModels.SILHOUETTE
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	if shade then
		p:SetAttribute("Shade", shade) -- 0 = main colour, >0 darker, <0 lighter; eyes have none
	end
	p.Parent = model
	return p
end

local function eyes(model, x, y, z, size)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Eye", Vector3.new(size, size, size), CFrame.new(side * x, y, z), nil, Enum.PartType.Ball).Color = Color3.fromRGB(16, 16, 20)
		piece(model, "Shine", Vector3.new(size * 0.4, size * 0.4, size * 0.4), CFrame.new(side * (x + size * 0.3), y + size * 0.2, z - size * 0.2), nil, Enum.PartType.Ball).Color = Color3.new(1, 1, 1)
	end
end

local function forkedTail(model, L, z, size)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Tail", Vector3.new(0.05 * L, size * L, 0.22 * L), CFrame.new(0, side * size * 0.32 * L, z) * CFrame.Angles(side * math.rad(-35), 0, 0), 0.25)
	end
end

local BUILD = {}

function BUILD.fish(model, L)
	piece(model, "Body", Vector3.new(0.3 * L, 0.45 * L, L), CFrame.new(), 0, nil, true)
	piece(model, "Belly", Vector3.new(0.24 * L, 0.26 * L, 0.78 * L), CFrame.new(0, -0.1 * L, -0.02 * L), -0.35, nil, true)
	piece(model, "Fin", Vector3.new(0.04 * L, 0.2 * L, 0.32 * L), CFrame.new(0, 0.24 * L, 0.05 * L) * CFrame.Angles(math.rad(-20), 0, 0), 0.25)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Fin", Vector3.new(0.14 * L, 0.03 * L, 0.12 * L), CFrame.new(side * 0.16 * L, -0.08 * L, -0.12 * L) * CFrame.Angles(0, 0, side * 0.5), 0.25)
	end
	forkedTail(model, L, 0.55 * L, 0.38)
	eyes(model, 0.12 * L, 0.06 * L, -0.33 * L, 0.09 * L)
end

function BUILD.koi(model, L)
	BUILD.fish(model, L)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Whisker", Vector3.new(0.02 * L, 0.02 * L, 0.2 * L), CFrame.new(side * 0.08 * L, -0.06 * L, -0.55 * L) * CFrame.Angles(0, side * 0.5, 0), 0.25)
		piece(model, "Veil", Vector3.new(0.02 * L, 0.3 * L, 0.35 * L), CFrame.new(side * 0.03 * L, 0, 0.75 * L) * CFrame.Angles(0, side * 0.25, 0), -0.2)
	end
end

function BUILD.ray(model, L)
	piece(model, "Body", Vector3.new(1.05 * L, 0.14 * L, 0.8 * L), CFrame.new(), 0, nil, true)
	piece(model, "Back", Vector3.new(0.4 * L, 0.18 * L, 0.5 * L), CFrame.new(0, 0.03 * L, 0), 0.2, nil, true)
	piece(model, "Tail", Vector3.new(0.04 * L, 0.04 * L, 0.8 * L), CFrame.new(0, 0, 0.75 * L), 0.25)
	piece(model, "Barb", Vector3.new(0.03 * L, 0.12 * L, 0.06 * L), CFrame.new(0, 0.06 * L, 0.55 * L), 0.25)
	eyes(model, 0.1 * L, 0.09 * L, -0.24 * L, 0.07 * L)
end

function BUILD.eel(model, L)
	piece(model, "Body", Vector3.new(0.16 * L, 0.2 * L, L), CFrame.new(), 0, nil, true)
	piece(model, "Head", Vector3.new(0.18 * L, 0.22 * L, 0.3 * L), CFrame.new(0, 0.01 * L, -0.38 * L), 0, nil, true)
	piece(model, "Fin", Vector3.new(0.03 * L, 0.07 * L, 0.85 * L), CFrame.new(0, 0.11 * L, 0.05 * L), 0.25)
	piece(model, "Tail", Vector3.new(0.03 * L, 0.12 * L, 0.2 * L), CFrame.new(0, 0, 0.55 * L), 0.25)
	eyes(model, 0.07 * L, 0.06 * L, -0.45 * L, 0.05 * L)
end

function BUILD.long(model, L)
	piece(model, "Body", Vector3.new(0.17 * L, 0.24 * L, L), CFrame.new(), 0, nil, true)
	piece(model, "Belly", Vector3.new(0.13 * L, 0.12 * L, 0.8 * L), CFrame.new(0, -0.06 * L, 0), -0.35, nil, true)
	piece(model, "Jaw", Vector3.new(0.08 * L, 0.06 * L, 0.18 * L), CFrame.new(0, -0.03 * L, -0.52 * L), 0.15)
	piece(model, "Fin", Vector3.new(0.03 * L, 0.12 * L, 0.14 * L), CFrame.new(0, 0.14 * L, -0.05 * L), 0.25)
	piece(model, "Fin", Vector3.new(0.03 * L, 0.1 * L, 0.12 * L), CFrame.new(0, 0.12 * L, 0.25 * L), 0.25)
	forkedTail(model, L, 0.55 * L, 0.3)
	eyes(model, 0.07 * L, 0.04 * L, -0.38 * L, 0.06 * L)
end

function BUILD.marlin(model, L)
	piece(model, "Body", Vector3.new(0.2 * L, 0.3 * L, L), CFrame.new(), 0, nil, true)
	piece(model, "Belly", Vector3.new(0.15 * L, 0.16 * L, 0.8 * L), CFrame.new(0, -0.08 * L, 0), -0.35, nil, true)
	piece(model, "Bill", Vector3.new(0.04 * L, 0.04 * L, 0.42 * L), CFrame.new(0, 0.02 * L, -0.66 * L), 0.15)
	piece(model, "Sail", Vector3.new(0.03 * L, 0.32 * L, 0.5 * L), CFrame.new(0, 0.28 * L, -0.05 * L) * CFrame.Angles(math.rad(-12), 0, 0), 0.3)
	forkedTail(model, L, 0.55 * L, 0.42)
	eyes(model, 0.09 * L, 0.05 * L, -0.38 * L, 0.06 * L)
end

function BUILD.round(model, L)
	piece(model, "Body", Vector3.new(0.8 * L, 0.8 * L, 0.85 * L), CFrame.new(), 0, Enum.PartType.Ball)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		piece(model, "Spike", Vector3.new(0.06 * L, 0.2 * L, 0.06 * L), CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.42 * L, 0), 0.25)
	end
	piece(model, "Lure", Vector3.new(0.12 * L, 0.12 * L, 0.12 * L), CFrame.new(0, 0.55 * L, -0.35 * L), -0.6, Enum.PartType.Ball)
	piece(model, "Tail", Vector3.new(0.05 * L, 0.3 * L, 0.2 * L), CFrame.new(0, 0, 0.48 * L), 0.25)
	eyes(model, 0.22 * L, 0.12 * L, -0.3 * L, 0.14 * L)
end

function BUILD.seahorse(model, L)
	piece(model, "Body", Vector3.new(0.28 * L, 0.6 * L, 0.3 * L), CFrame.new(), 0, nil, true)
	piece(model, "Belly", Vector3.new(0.2 * L, 0.45 * L, 0.2 * L), CFrame.new(0, -0.02 * L, -0.06 * L), -0.35, nil, true)
	piece(model, "Head", Vector3.new(0.22 * L, 0.22 * L, 0.26 * L), CFrame.new(0, 0.36 * L, -0.05 * L), 0, nil, true)
	piece(model, "Snout", Vector3.new(0.07 * L, 0.07 * L, 0.3 * L), CFrame.new(0, 0.33 * L, -0.28 * L), 0.15)
	piece(model, "Crown", Vector3.new(0.05 * L, 0.12 * L, 0.1 * L), CFrame.new(0, 0.5 * L, 0), 0.25)
	piece(model, "Fin", Vector3.new(0.03 * L, 0.2 * L, 0.12 * L), CFrame.new(0, 0.05 * L, 0.15 * L), 0.25)
	-- the curled tail
	piece(model, "Tail", Vector3.new(0.12 * L, 0.25 * L, 0.12 * L), CFrame.new(0, -0.38 * L, 0.05 * L) * CFrame.Angles(math.rad(-15), 0, 0), 0.1)
	piece(model, "Tail", Vector3.new(0.1 * L, 0.1 * L, 0.18 * L), CFrame.new(0, -0.5 * L, 0.12 * L), 0.15)
	piece(model, "Tail", Vector3.new(0.08 * L, 0.12 * L, 0.08 * L), CFrame.new(0, -0.44 * L, 0.2 * L), 0.2)
	eyes(model, 0.1 * L, 0.4 * L, -0.12 * L, 0.06 * L)
end

-- Returns the model (PrimaryPart "Body", built around the origin) and its length in studs.
function FishModels.build(name, tierIndex)
	local L = FishModels.length(name, tierIndex)
	local model = Instance.new("Model")
	model.Name = "Fish"
	local builder = BUILD[SHAPES[name] or "fish"] or BUILD.fish
	builder(model, L)
	model.PrimaryPart = model:FindFirstChild("Body")
	model:SetAttribute("Fish", name)
	return model, L
end

-- Fills the fish with one colour: shaded parts go darker or lighter, eyes stay as they are.
function FishModels.paint(model, color, material)
	for _, p in ipairs(model:GetChildren()) do
		local shade = p:IsA("BasePart") and p:GetAttribute("Shade")
		if shade then
			p.Color = shade >= 0 and color:Lerp(Color3.new(0, 0, 0), shade) or color:Lerp(Color3.new(1, 1, 1), -shade)
			p.Material = material or Enum.Material.SmoothPlastic
		end
	end
end

return FishModels
