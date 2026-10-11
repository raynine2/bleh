-- Tidebound: Eggfall: placeholder voxel creature models (Delta Section 10 hands real rigs to an animator).
-- One builder for every display slot: aquarium fish, pen roamers, trophy statues and the showcase plinth.

local Config = require(script.Parent.Config)

local CreatureModels = {}

local MUTATION_FX = {
	Brine = { color = Color3.fromRGB(80, 230, 255), rate = 6, speed = 1, accel = Vector3.new(0, -6, 0) }, -- cyan drip trail
	Storm = { color = Color3.fromRGB(255, 240, 110), rate = 10, speed = 6, accel = Vector3.new() }, -- arc sparks
	Aurora = { color = Color3.fromRGB(140, 255, 170), rate = 6, speed = 2, accel = Vector3.new(0, 2, 0) }, -- shifting color
	Abyssal = { color = Color3.fromRGB(20, 16, 30), rate = 10, speed = 1.5, accel = Vector3.new(0, 3, 0) }, -- black smoke
	Prismatic = { color = Color3.fromRGB(255, 140, 240), rate = 12, speed = 3, accel = Vector3.new(0, 1, 0) }, -- rainbow
}

local function block(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Returns a Model whose PrimaryPart is "Body", centred on `cframe`, about `scale` studs long.
function CreatureModels.build(tierIndex, mutationId, cframe, scale)
	scale = scale or 3
	local tier = Config.Tiers[tierIndex] or Config.Tiers[1]
	local model = Instance.new("Model")
	model.Name = "Creature"
	local s = scale
	local body = block(model, "Body", Vector3.new(s * 0.7, s * 0.6, s), cframe, tier.color)
	block(model, "Belly", Vector3.new(s * 0.6, s * 0.2, s * 0.8), cframe * CFrame.new(0, -s * 0.3, 0), tier.color:Lerp(Color3.new(1, 1, 1), 0.45))
	block(model, "Tail", Vector3.new(s * 0.1, s * 0.5, s * 0.4), cframe * CFrame.new(0, 0, s * 0.65) * CFrame.Angles(math.rad(20), 0, 0), tier.color:Lerp(Color3.new(0, 0, 0), 0.2))
	block(model, "Fin", Vector3.new(s * 0.1, s * 0.35, s * 0.4), cframe * CFrame.new(0, s * 0.42, 0.05 * s), tier.color:Lerp(Color3.new(0, 0, 0), 0.2))
	for _, side in ipairs({ -1, 1 }) do
		block(model, "Eye", Vector3.new(s * 0.12, s * 0.16, s * 0.12), cframe * CFrame.new(side * s * 0.36, s * 0.1, -s * 0.35), Color3.fromRGB(20, 20, 26))
	end
	if tierIndex >= 5 then
		block(model, "Crown", Vector3.new(s * 0.3, s * 0.2, s * 0.3), cframe * CFrame.new(0, s * 0.45, -s * 0.2), Color3.fromRGB(255, 210, 70), Enum.Material.Neon)
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
		e.Size = NumberSequence.new(s * 0.12, 0)
		e.LightEmission = mutationId == "Abyssal" and 0 or 0.8
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = body
	end
	-- only the body is anchored; everything else is welded to it so moving the body moves the creature
	for _, p in ipairs(model:GetChildren()) do
		if p ~= body and p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.PrimaryPart = body
	model:SetAttribute("Tier", tierIndex)
	model:SetAttribute("Mutation", mutationId or "None")
	return model
end

return CreatureModels
