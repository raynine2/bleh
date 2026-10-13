-- Tidebound: Eggfall: creature models for companions, the Home Nest and the hatch fallback.
-- 12 Oct: uses the real voxel fish (ReplicatedStorage.VoxelFish.<Name>) when the caller passes the fish name.
-- Returns a Model whose PrimaryPart is "Body" (an invisible anchored root), centred on `cframe`, about `scale`
-- studs long, head pointing -Z like the old block creatures. Everything else is welded to Body, so moving Body
-- (or PivotTo) moves the whole fish.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)

local CreatureModels = {}

local MUTATION_FX = {
	Brine = { color = Color3.fromRGB(80, 230, 255), rate = 6, speed = 1, accel = Vector3.new(0, -6, 0) },
	Storm = { color = Color3.fromRGB(255, 240, 110), rate = 10, speed = 6, accel = Vector3.new() },
	Aurora = { color = Color3.fromRGB(140, 255, 170), rate = 6, speed = 2, accel = Vector3.new(0, 2, 0) },
	Abyssal = { color = Color3.fromRGB(20, 16, 30), rate = 10, speed = 1.5, accel = Vector3.new(0, 3, 0) },
	Prismatic = { color = Color3.fromRGB(255, 140, 240), rate = 12, speed = 3, accel = Vector3.new(0, 1, 0) },
}

-- voxel fish are a bit bigger than the old blocks so their faces read at a distance
local FISH_SIZE = 1.4

local function root(model, size, cframe, color, visible)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.CFrame = cframe
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = visible and 0 or 1
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = visible
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body
	return body
end

function CreatureModels.build(tierIndex, mutationId, cframe, scale, creatureName)
	scale = scale or 3
	local tier = Config.Tiers[tierIndex] or Config.Tiers[1]
	local model = Instance.new("Model")
	model.Name = "Creature"
	local source = creatureName and ReplicatedStorage:FindFirstChild("VoxelFish") and ReplicatedStorage.VoxelFish:FindFirstChild(creatureName)
	local body
	if source then
		local fish = source:Clone()
		local _, size = fish:GetBoundingBox()
		fish:ScaleTo(scale * FISH_SIZE / math.max(size.X, size.Y, size.Z))
		-- voxel fish face +X; turn them to face -Z, centred on cframe
		fish:PivotTo(cframe * CFrame.Angles(0, math.rad(90), 0))
		body = root(model, Vector3.one * 0.5, cframe, tier.color, false)
		for _, p in ipairs(fish:GetChildren()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.Massless = true
				p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
				p.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = body, p
				weld.Parent = p
			end
		end
		fish:Destroy()
	else
		-- no voxel model for this name (or no name given): a simple tier-coloured block
		body = root(model, Vector3.new(scale * 0.7, scale * 0.6, scale), cframe, tier.color, true)
	end

	local fx = MUTATION_FX[mutationId or "None"]
	if fx then
		local e = Instance.new("ParticleEmitter")
		e.Color = mutationId == "Prismatic" and ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 140, 255)),
		}) or ColorSequence.new(fx.color)
		e.Rate = fx.rate
		e.Lifetime = NumberRange.new(0.6, 1.2)
		e.Speed = NumberRange.new(fx.speed)
		e.Acceleration = fx.accel
		e.Size = NumberSequence.new(scale * 0.12, 0)
		e.LightEmission = mutationId == "Abyssal" and 0 or 0.8
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = body
	end

	model:SetAttribute("Tier", tierIndex)
	model:SetAttribute("Mutation", mutationId or "None")
	return model
end

return CreatureModels
