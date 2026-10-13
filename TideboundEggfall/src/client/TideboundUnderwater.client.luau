-- Tidebound: Eggfall: the underwater look. Every frame it finds where the camera sits against the sea's surface
-- (a short column of terrain voxels above and below the camera), and keeps ClientBus.underwater /
-- .underwaterDepth / .submersion up to date for the other client scripts (BiomeLook, OceanLife, Audio...).
-- Detection has a 0.25-stud dead band and a short hold, and every effect follows one smoothed 0..1 blend
-- (~0.3 s in or out), so bobbing at the surface never flickers.
-- Under the sea: a deep-blue grade (less of the blinding cyan, more saturation, a little darker the deeper you go),
-- a slight blur, dense blue distance fog, deep-blue ambient light and water colour, and a soft vignette drawn
-- behind the HUD so the UI stays readable. Its own effect instances, so it never fights BiomeLook's tweens;
-- the shared fog and ambient are handed back to the biome's values when you surface.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Biomes = require(Shared:WaitForChild("Biomes"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))

local terrain = workspace.Terrain
local WATER = Enum.Material.Water
local VOXEL = 4

local ENTER_DEPTH = 0.25 -- the camera counts as under once it's this far below the surface...
local EXIT_DEPTH = 0 -- ...and as out once it's back above it
local HOLD = 0.15 -- seconds a new state must hold before it flips
local BLEND_TIME = 0.3 -- seconds for the look to blend fully in or out
local SEA_DEPTH = 18 -- surface to sand in the open sea: the look deepens over this

local DEEP = {
	tint = Color3.fromRGB(196, 226, 255),
	tintDeep = Color3.fromRGB(160, 198, 250),
	fog = Color3.fromRGB(46, 120, 166),
	decay = Color3.fromRGB(18, 58, 100),
	ambient = Color3.fromRGB(52, 84, 120),
	outdoor = Color3.fromRGB(70, 118, 156),
	water = Color3.fromRGB(28, 112, 158),
	vignette = Color3.fromRGB(4, 20, 44),
}

-- Detection ------------------------------------------------------------------------------------------------

-- Studs from `p` up to the water's surface: positive under it, negative above it, -inf away from any water.
local function depthAt(p: Vector3): number
	local cx, cz = math.floor(p.X / VOXEL) * VOXEL, math.floor(p.Z / VOXEL) * VOXEL
	local cy = math.floor(p.Y / VOXEL) * VOXEL
	local low, high = cy - VOXEL, cy + VOXEL * 12
	local ok, mats, occ = pcall(terrain.ReadVoxels, terrain, Region3.new(Vector3.new(cx, low, cz), Vector3.new(cx + VOXEL, high, cz + VOXEL)), VOXEL)
	if not ok then
		return -math.huge
	end
	local column, fill = mats[1], occ[1]
	local here = 2 -- index of the voxel holding the camera (index 1 is the one under it)
	local function isWater(i)
		return column[i] and column[i][1] == WATER and fill[i][1] > 0.05
	end
	local function surfaceOf(i) -- top of water voxel i, by how full it is
		return low + (i - 1) * VOXEL + fill[i][1] * VOXEL
	end
	if isWater(here) then
		local top = here
		while isWater(top + 1) do
			top += 1
		end
		if top == #column then
			return high - p.Y -- deeper than we read: plenty
		end
		return surfaceOf(top) - p.Y
	elseif isWater(here - 1) then
		return surfaceOf(here - 1) - p.Y
	end
	return -math.huge
end

-- Effects ---------------------------------------------------------------------------------------------------

local function effect(className, name)
	local e = Lighting:FindFirstChild(name)
	if not e or not e:IsA(className) then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local grade = effect("ColorCorrectionEffect", "TideboundUnderwaterGrade")
local blur = effect("BlurEffect", "TideboundUnderwaterBlur")
grade.Enabled, blur.Enabled = false, false

-- the vignette: four soft edges in a ScreenGui under every HUD layer
local gui = Instance.new("ScreenGui")
gui.Name = "TideboundUnderwaterVignette"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -10
gui.Enabled = false
local edges = {}
for _, e in ipairs({
	{ UDim2.new(1, 0, 0.34, 0), UDim2.new(0, 0, 0, 0), 90 },
	{ UDim2.new(1, 0, 0.34, 0), UDim2.new(0, 0, 0.66, 0), -90 },
	{ UDim2.new(0.26, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
	{ UDim2.new(0.26, 0, 1, 0), UDim2.new(0.74, 0, 0, 0), 180 },
}) do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = DEEP.vignette
	f.Size, f.Position = e[1], e[2]
	local g = Instance.new("UIGradient")
	g.Rotation = e[3]
	g.Parent = f
	f.Parent = gui
	table.insert(edges, g)
end
gui.Parent = player:WaitForChild("PlayerGui")

local function setVignette(strength)
	local seq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - 0.62 * strength),
		NumberSequenceKeypoint.new(0.55, 1 - 0.12 * strength),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, g in ipairs(edges) do
		g.Transparency = seq
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- the surface values everything blends from, read fresh while you're above water (so other scripts' changes stick)
local surfaceWater = terrain.WaterColor
local function biomeBase()
	local id = ClientBus.biome or Biomes.default
	local biome = Biomes.get(id)
	local a = biome.atmosphere
	return {
		Density = a.Density, Offset = a.Offset, Color = a.Color, Decay = Biomes.decayColor(id), Glare = a.Glare, Haze = Biomes.haze(id),
		Ambient = Biomes.lighting.Ambient, OutdoorAmbient = biome.outdoorAmbient or Biomes.lighting.OutdoorAmbient,
	}
end

local applied, appliedDeep = 0, 0 -- the blend last written to the shared Lighting / terrain properties
local function apply(s, deep)
	local on = s > 0.001
	grade.Enabled, blur.Enabled, gui.Enabled = on, on, on
	if not on and applied == 0 then
		surfaceWater = terrain.WaterColor
		return
	end
	if on and math.abs(s - applied) < 0.002 and math.abs(deep - appliedDeep) < 0.01 then
		return -- nothing visible changed since the last write
	end
	appliedDeep = deep
	grade.TintColor = Color3.new(1, 1, 1):Lerp(DEEP.tint:Lerp(DEEP.tintDeep, deep), s)
	grade.Saturation = 0.12 * s
	grade.Contrast = 0.1 * s
	grade.Brightness = -(0.03 + 0.08 * deep) * s
	blur.Size = 2.5 * s
	setVignette(s * (0.75 + 0.25 * deep))
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local base = biomeBase()
	if atmosphere then
		atmosphere.Density = lerp(base.Density, 0.5 + 0.15 * deep, s)
		atmosphere.Offset = lerp(base.Offset, 0.2, s)
		atmosphere.Color = base.Color:Lerp(DEEP.fog, s)
		atmosphere.Decay = base.Decay:Lerp(DEEP.decay, s)
		atmosphere.Glare = lerp(base.Glare, 0, s)
		atmosphere.Haze = lerp(base.Haze, 1.6, s)
	end
	Lighting.Ambient = base.Ambient:Lerp(DEEP.ambient, s)
	Lighting.OutdoorAmbient = base.OutdoorAmbient:Lerp(DEEP.outdoor, s)
	terrain.WaterColor = surfaceWater:Lerp(DEEP.water, s)
	applied = on and s or 0
end

-- Loop --------------------------------------------------------------------------------------------------------

local state, pendingSince = false, nil
local s = 0

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local depth = depthAt(camera.CFrame.Position)
	ClientBus.underwaterDepth = depth
	local want = state
	if state and depth < EXIT_DEPTH then
		want = false
	elseif not state and depth > ENTER_DEPTH then
		want = true
	end
	if want ~= state then
		pendingSince = pendingSince or os.clock()
		if os.clock() - pendingSince >= HOLD then
			state, pendingSince = want, nil
			ClientBus.underwater = state
			ClientBus.signal:Fire("underwater", state)
		end
	else
		pendingSince = nil
	end
	local target = state and 1 or 0
	if s ~= target then
		local step = dt / BLEND_TIME
		s = target > s and math.min(target, s + step) or math.max(target, s - step)
	end
	ClientBus.submersion = s
	local eased = s * s * (3 - 2 * s) -- smoothstep, so it eases at both ends
	apply(eased, math.clamp(depth / SEA_DEPTH, 0, 1))
end)
