-- Tidebound: Eggfall: the dash (Patch 19). Q (DASH on touch, B on a gamepad) rolls one of the moves in
-- DashMoves that you can do right now and does it: this script moves you (dash, arc, hook-pull or glide) and
-- plays every dash's effects, yours at once and everyone else's from the DashAt / DashKind / DashTarget
-- attributes the server sets. TideboundMotion poses the body, TideboundCreatures flies the fish, and
-- TideboundClient owns stamina (MotionBus.stamina) and the sprint.
-- Effects: light trails off your hands and feet in the move's colours, dust and smoke bursts, afterimages, speed
-- streaks, and each move's own: the hook line and its hook, rotor blades, a surf wake, slide marks, ground
-- cracks on a superhero landing, a BOOP, a SLAP, dizzy stars. On your screen: speed lines, a punch of the field
-- of view and the move's name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local DashMoves = require(Shared:WaitForChild("DashMoves"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))

local player = Players.LocalPlayer
local ST = Config.Stamina
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FX_RANGE = 160
local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "TideboundDashFX"
folder.Parent = workspace

local remote = nil
task.spawn(function()
	remote = Shared:WaitForChild("Remotes"):WaitForChild("Dash")
end)

-- Little helpers --------------------------------------------------------------------------------------------------

local K = {} -- helpers live in one table

function K.part(shape, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

function K.tween(inst, time, props, style, direction, delay)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

-- a one-shot burst of particles at a point
function K.burst(at, count, props)
	local holder = K.part(Enum.PartType.Block, Vector3.one * 0.2, CFrame.new(at), Color3.new(1, 1, 1), nil, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, (props.Lifetime and props.Lifetime.Max or 1) + 0.2)
	return e
end

function K.smoke(at, count, color, size, speed)
	return K.burst(at, count, {
		Texture = SMOKE,
		Color = ColorSequence.new(color or Color3.fromRGB(240, 244, 252)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (size or 2) * 0.5), NumberSequenceKeypoint.new(1, (size or 2) * 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new((speed or 8) * 0.5, speed or 8),
		SpreadAngle = Vector2.new(180, 25),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Drag = 4,
		EmissionDirection = Enum.NormalId.Top,
	})
end

function K.sparks(at, count, color, speed)
	return K.burst(at, count, {
		Color = ColorSequence.new(color or Color3.new(1, 1, 1)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new((speed or 16) * 0.5, speed or 16),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

-- a flat ring of smoke rolling out along the ground (take-offs and landings)
function K.dustRing(at, radius, color)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local puff = K.part(Enum.PartType.Ball, Vector3.one * 1.2, CFrame.new(at + dir * 0.8), color or Color3.fromRGB(240, 244, 252), Enum.Material.SmoothPlastic, 0.15)
		K.tween(puff, 0.45, { CFrame = CFrame.new(at + dir * radius + Vector3.new(0, 0.6, 0)), Size = Vector3.one * rng:NextNumber(2.2, 3.2), Transparency = 1 }, Enum.EasingStyle.Quart)
		Debris:AddItem(puff, 0.5)
	end
end

-- a cartoon cloud of a few white balls that puffs up and pops (left behind where you took off)
function K.cloud(at, scale)
	scale = scale or 1
	for i = 1, 6 do
		local offset = Vector3.new(rng:NextNumber(-1.3, 1.3), rng:NextNumber(0, 1.5), rng:NextNumber(-1.3, 1.3)) * scale
		local puff = K.part(Enum.PartType.Ball, Vector3.one * 0.5, CFrame.new(at + offset), i % 2 == 0 and Color3.fromRGB(232, 238, 248) or Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 0.05)
		local size = rng:NextNumber(2.2, 3.6) * scale
		K.tween(puff, 0.16, { Size = Vector3.one * size }, Enum.EasingStyle.Back)
		K.tween(puff, 0.35, { Size = Vector3.one * 0.3, Transparency = 1, CFrame = CFrame.new(at + offset * 1.5 + Vector3.new(0, 1.2, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.22)
		Debris:AddItem(puff, 0.65)
	end
end

-- see-through copies of the body that fade where you were
function K.afterimage(character, color)
	for _, limb in ipairs(character:GetChildren()) do
		if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and limb.Transparency < 0.9 then
			local g = K.part(Enum.PartType.Block, limb.Size, limb.CFrame, color, nil, 0.5)
			K.tween(g, 0.32, { Transparency = 1, Size = limb.Size * 0.8 })
			Debris:AddItem(g, 0.36)
		end
	end
end

-- thin streaks of light flying back past you
function K.streaks(root, dir, color, count)
	for _ = 1, count or 2 do
		local side = root.CFrame.RightVector * rng:NextNumber(-2.6, 2.6) + Vector3.new(0, rng:NextNumber(-2, 2.5), 0)
		local start = root.Position + side + dir * rng:NextNumber(1, 4)
		local len = rng:NextNumber(3, 6)
		local s = K.part(Enum.PartType.Block, Vector3.new(0.08, 0.08, len), CFrame.lookAt(start, start + dir), color, nil, 0.25)
		K.tween(s, 0.22, { CFrame = CFrame.lookAt(start - dir * 7, start), Transparency = 1, Size = Vector3.new(0.03, 0.03, len * 1.6) })
		Debris:AddItem(s, 0.25)
	end
end

-- ground cracks: dark lines radiating from a superhero landing, fading slowly
function K.cracks(at, count, length)
	for i = 1, count do
		local a = i / count * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = length * rng:NextNumber(0.6, 1)
		local c = K.part(Enum.PartType.Block, Vector3.new(0.3, 0.12, 0.1), CFrame.lookAt(at, at + dir), Color3.fromRGB(70, 74, 92), Enum.Material.SmoothPlastic, 0.1)
		K.tween(c, 0.12, { Size = Vector3.new(0.3, 0.12, len), CFrame = CFrame.lookAt(at, at + dir) * CFrame.new(0, 0, -len / 2) })
		K.tween(c, 0.6, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.9)
		Debris:AddItem(c, 1.6)
	end
end

-- light trails off both hands and both feet (R15; R6 arms and legs)
local LIMBS = { "RightHand", "LeftHand", "RightFoot", "LeftFoot", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
function K.trails(character, colors)
	local made = {}
	for _, name in ipairs(LIMBS) do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			local a0 = Instance.new("Attachment")
			a0.Name = "DashTrailA"
			a0.Position = Vector3.new(0, limb.Size.Y * 0.35, 0)
			a0.Parent = limb
			local a1 = Instance.new("Attachment")
			a1.Name = "DashTrailB"
			a1.Position = Vector3.new(0, -limb.Size.Y * 0.35, 0)
			a1.Parent = limb
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.28
			trail.MinLength = 0.05
			trail.FaceCamera = true
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(colors[1], colors[2])
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
			trail.Parent = limb
			table.insert(made, a0)
			table.insert(made, a1)
			table.insert(made, trail)
		end
	end
	return made
end

function K.feet(e)
	return e.root.Position - Vector3.new(0, 3, 0)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false
function K.filter()
	local list = { folder, Fx.folder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "TideboundCompanions", "TideboundMobs", "TideboundFoliage", "TideboundLife", "TideboundRodFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	groundParams.FilterDescendantsInstances = list
end

function K.ground(at, fallback)
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), groundParams)
	return hit and hit.Position or fallback
end

function K.companion(owner, slot)
	for _, model in ipairs(CollectionService:GetTagged("TideboundCompanion")) do
		if model:GetAttribute("Owner") == owner.UserId and (slot == nil or model:GetAttribute("Slot") == slot) then
			return model
		end
	end
	return nil
end

function K.rodTip(character)
	local rod = character:FindFirstChild("TideboundRod")
	local tip = rod and rod:FindFirstChild("Tip", true)
	return tip and tip:IsA("BasePart") and tip or nil
end

-- Per-move effects ------------------------------------------------------------------------------------------------
-- e = { character, root, owner, move, start, isMe, target, data = {}, cleanup = {} }; step(e, u) runs every frame.

local FX = {}

FX[1] = { -- Zoomies: afterimages and streaks
	step = function(e, u)
		local d = e.data
		d.ghosts = d.ghosts or 0
		if u < 0.3 and math.floor(u / 0.06) > d.ghosts then
			d.ghosts += 1
			K.afterimage(e.character, e.move.colors[1])
		end
		if u < 0.3 then
			K.streaks(e.root, e.root.CFrame.LookVector, Color3.new(1, 1, 1), 1)
		end
	end,
}

FX[2] = { -- Penguin Slide: snow spraying off your belly, sparkles, slide marks in the snow
	start = function(e)
		local chest = e.character:FindFirstChild("UpperTorso") or e.root
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = SMOKE
		spray.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
		spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		spray.Lifetime = NumberRange.new(0.3, 0.55)
		spray.Speed = NumberRange.new(6, 10)
		spray.SpreadAngle = Vector2.new(40, 40)
		spray.Rate = 70
		spray.Drag = 3
		spray.EmissionDirection = Enum.NormalId.Back
		spray.Parent = chest
		table.insert(e.cleanup, spray)
		local glitter = Instance.new("ParticleEmitter")
		glitter.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
		glitter.LightEmission = 1
		glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		glitter.Lifetime = NumberRange.new(0.4, 0.7)
		glitter.Speed = NumberRange.new(2, 5)
		glitter.SpreadAngle = Vector2.new(180, 180)
		glitter.Rate = 40
		glitter.Parent = chest
		table.insert(e.cleanup, glitter)
	end,
	step = function(e, u)
		local d = e.data
		if u < 0.55 and os.clock() > (d.markAt or 0) then
			d.markAt = os.clock() + 0.035
			local at = K.ground(e.root.Position, K.feet(e)) + Vector3.new(0, 0.06, 0)
			local look = e.root.CFrame.LookVector
			local mark = K.part(Enum.PartType.Block, Vector3.new(1.4, 0.05, 1.6), CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)), Color3.fromRGB(235, 245, 255), Enum.Material.SmoothPlastic, 0.2)
			K.tween(mark, 1.2, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
			Debris:AddItem(mark, 1.6)
		end
		if u > 0.52 and not d.stopped then
			d.stopped = true
			for _, inst in ipairs(e.cleanup) do
				if inst:IsA("ParticleEmitter") then
					inst.Enabled = false
				end
			end
			K.smoke(K.feet(e) + e.root.CFrame.LookVector * 1.5, 10, nil, 1.6, 9)
		end
	end,
}

FX[3] = { -- Wheel Legs: dust clouds kicked up behind, streaks
	step = function(e, u)
		local d = e.data
		if u < 0.36 and os.clock() > (d.puffAt or 0) then
			d.puffAt = os.clock() + 0.05
			K.cloud(K.feet(e) + Vector3.new(0, 0.6, 0) - e.root.CFrame.LookVector * 1.5, 0.55)
			K.streaks(e.root, e.root.CFrame.LookVector, Color3.fromRGB(255, 230, 160), 1)
		end
	end,
}

FX[4] = { -- Barrel Roll: a spiral of light round your path, afterimages
	step = function(e, u)
		local d = e.data
		if u < 0.32 then
			local cf = e.root.CFrame
			local a = u * 40
			for k = 0, 1 do
				local ang = a + k * math.pi
				local at = (cf * CFrame.new(math.cos(ang) * 2.2, math.sin(ang) * 2.2, 0.5)).Position
				local seg = K.part(Enum.PartType.Ball, Vector3.one * 0.45, CFrame.new(at), e.move.colors[k + 1], nil, 0.1)
				K.tween(seg, 0.3, { Size = Vector3.one * 0.05, Transparency = 1 })
				Debris:AddItem(seg, 0.32)
			end
			d.ghosts = d.ghosts or 0
			if math.floor(u / 0.08) > d.ghosts then
				d.ghosts += 1
				K.afterimage(e.character, e.move.colors[1])
			end
		end
	end,
}

-- a heavy landing: rings, a dust ring, debris, sparks and a word
local function landing(e, word, scale, cracks)
	local at = K.ground(e.root.Position, K.feet(e))
	Fx.ring(at + Vector3.new(0, 0.2, 0), Color3.new(1, 1, 1), 9 * scale, 0.4, 0.35)
	Fx.ring(at + Vector3.new(0, 0.3, 0), e.move.colors[1], 6 * scale, 0.35, 0.45)
	K.dustRing(at, 7 * scale)
	Fx.cubes(at + Vector3.new(0, 0.5, 0), { Color3.fromRGB(235, 240, 250), Color3.fromRGB(190, 196, 214), e.move.colors[2] }, { spread = 7 * scale, size = 0.6, life = 0.55, count = 16, up = 1, material = Enum.Material.SmoothPlastic })
	K.sparks(at + Vector3.new(0, 1, 0), 18, e.move.colors[2], 22)
	if cracks then
		K.cracks(at + Vector3.new(0, 0.05, 0), 9, 6 * scale)
	end
	Fx.word(at + Vector3.new(0, 5, 0), word, { Color3.fromRGB(255, 255, 255), e.move.colors[1] }, 1.1 * scale)
	Audio.play("DashLand", e.root, rng:NextNumber(0.9, 1.05))
	if e.isMe then
		FishingFeel.shake(0.25 * scale, 0.22)
		MotionBus.kick = { at = os.clock(), amount = 5, length = 0.3 }
	end
end

FX[5] = { -- Cannonball: launch puff, a spinning sparkle, a BOOM landing
	start = function(e)
		local torso = e.character:FindFirstChild("UpperTorso") or e.root
		local glow = Instance.new("ParticleEmitter")
		glow.Color = ColorSequence.new(e.move.colors[1], e.move.colors[2])
		glow.LightEmission = 1
		glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		glow.Lifetime = NumberRange.new(0.25, 0.45)
		glow.Speed = NumberRange.new(1, 3)
		glow.SpreadAngle = Vector2.new(180, 180)
		glow.Rate = 60
		glow.Parent = torso
		table.insert(e.cleanup, glow)
		Audio.play("DashJump", e.root)
	end,
	step = function(e, u)
		local d = e.data
		if not d.landed and u > 0.47 then
			d.landed = true
			for _, inst in ipairs(e.cleanup) do
				if inst:IsA("ParticleEmitter") then
					inst.Enabled = false
				end
			end
			landing(e, ({ "BOOM!", "KA-BLAM!", "SPLOOSH!" })[rng:NextInteger(1, 3)], 1, false)
		end
	end,
}

FX[6] = { -- Pole Vault: the rod planted with a puff, a sparkle arc, a superhero landing
	start = function(e)
		Audio.play("DashJump", e.root, 0.9)
	end,
	step = function(e, u)
		local d = e.data
		if not d.planted and u > 0.08 then
			d.planted = true
			local at = K.ground(e.root.Position + e.root.CFrame.LookVector * 3.5, K.feet(e) + e.root.CFrame.LookVector * 3.5)
			K.smoke(at, 10, nil, 1.4, 7)
			K.sparks(at + Vector3.new(0, 0.5, 0), 10, e.move.colors[1], 14)
			Fx.ring(at + Vector3.new(0, 0.15, 0), e.move.colors[1], 3.5, 0.3, 0.25)
		end
		if u > 0.12 and u < 0.6 then
			local torso = e.character:FindFirstChild("UpperTorso") or e.root
			if os.clock() > (d.twinkle or 0) then
				d.twinkle = os.clock() + 0.04
				local s = K.part(Enum.PartType.Block, Vector3.new(0.5, 0.5, 0.1), torso.CFrame * CFrame.Angles(0, 0, math.rad(45)), e.move.colors[(math.floor(u * 40) % 2) + 1])
				K.tween(s, 0.5, { Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1, CFrame = s.CFrame * CFrame.new(0, -1, 1) * CFrame.Angles(0, 0, 2) })
				Debris:AddItem(s, 0.55)
			end
		end
		if not d.landed and u > 0.63 then
			d.landed = true
			landing(e, "HERO LANDING!", 1.15, true)
		end
	end,
}

FX[7] = { -- Hook Shot: the line flies out, hooks with a spark, and reels you in
	start = function(e)
		Audio.play("DashZip", e.root, 0.8)
	end,
	step = function(e, u)
		local d = e.data
		local target = e.target or (e.root.Position + e.root.CFrame.LookVector * 30)
		local tip = K.rodTip(e.character)
		local from = tip and (tip.CFrame * CFrame.new(0, tip.Size.Y / 2, 0)).Position or e.root.Position + Vector3.new(0, 2, 0)
		if not d.hook and u > 0.06 then
			-- the hook: a gold barb on a glowing line
			d.hook = K.part(Enum.PartType.Ball, Vector3.one * 0.7, CFrame.new(from), Color3.fromRGB(255, 220, 80))
			table.insert(e.cleanup, d.hook)
			local a1 = Instance.new("Attachment")
			a1.Parent = d.hook
			local a0 = Instance.new("Attachment")
			a0.Parent = tip or e.root
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Width0 = 0.18
			beam.Width1 = 0.12
			beam.LightEmission = 1
			beam.FaceCamera = true
			beam.Segments = 12
			beam.Color = ColorSequence.new(e.move.colors[1], e.move.colors[2])
			beam.Transparency = NumberSequence.new(0.05)
			beam.Parent = d.hook
			d.beam = beam
			table.insert(e.cleanup, a0)
		end
		if d.hook then
			local s = math.clamp((u - 0.06) / 0.1, 0, 1)
			local pos = from:Lerp(target, s) + Vector3.new(0, math.sin(s * math.pi) * 3, 0)
			d.hook.CFrame = CFrame.new(pos)
			d.beam.CurveSize0 = (1 - s) * 2
			d.beam.CurveSize1 = -(1 - s) * 2
			if s >= 1 and not d.hooked then
				d.hooked = true
				K.sparks(target, 16, Color3.fromRGB(255, 230, 120), 18)
				Fx.ring(target, e.move.colors[1], 3, 0.3, 0.25)
				Fx.word(target + Vector3.new(0, 3, 0), "HOOKED!", { Color3.fromRGB(255, 255, 255), e.move.colors[1] }, 0.75)
				Audio.play("DashZip", e.root, 1.3)
			end
			if d.hooked and u < 0.6 then
				d.beam.Width0 = 0.18 + 0.08 * math.sin(u * 60) -- taut and humming
				K.streaks(e.root, (target - e.root.Position).Unit, e.move.colors[1], 1)
			end
			if u > 0.6 and not d.gone then
				d.gone = true
				K.cloud(d.hook.Position, 0.5)
				d.hook.Transparency = 1
				d.beam.Enabled = false
			end
		end
	end,
}

FX[8] = { -- Rod Copter: spinning blades over your hand, air rings pushing down
	start = function(e)
		local d = e.data
		d.blades = {}
		for i = 1, 2 do
			local b = K.part(Enum.PartType.Block, Vector3.new(0.25, 0.12, 6), CFrame.new(e.root.Position), e.move.colors[i], nil, 0.15)
			table.insert(d.blades, b)
			table.insert(e.cleanup, b)
		end
		d.disc = K.part(Enum.PartType.Cylinder, Vector3.new(0.1, 6.2, 6.2), CFrame.new(e.root.Position), Color3.new(1, 1, 1), nil, 0.75)
		table.insert(e.cleanup, d.disc)
		Audio.play("DashCopter", e.root)
	end,
	step = function(e, u)
		local d = e.data
		local hand = e.character:FindFirstChild("RightHand") or e.character:FindFirstChild("Right Arm")
		local hub = (hand and hand.Position or e.root.Position + Vector3.new(0, 3, 0)) + Vector3.new(0, 1.6, 0)
		local fade = u > 0.85 and math.clamp((u - 0.85) / 0.1, 0, 1) or 0
		local spin = os.clock() * 28
		for i, b in ipairs(d.blades) do
			b.CFrame = CFrame.new(hub) * CFrame.Angles(0, spin + i * math.pi / 2, 0)
			b.Transparency = 0.15 + 0.85 * fade
		end
		d.disc.CFrame = CFrame.new(hub) * CFrame.Angles(0, 0, math.rad(90))
		d.disc.Transparency = 0.75 + 0.25 * fade
		if u < 0.85 and os.clock() > (d.ringAt or 0) then
			d.ringAt = os.clock() + 0.12
			Fx.ring(hub - Vector3.new(0, 2, 0), Color3.fromRGB(230, 245, 255), 4, 0.35, 0.15)
			local below = K.ground(e.root.Position, nil)
			if below and (e.root.Position - below).Magnitude < 14 then
				K.smoke(below + Vector3.new(0, 0.3, 0), 3, nil, 1.2, 10)
			end
			if math.floor(u * 10) % 3 == 0 then
				Audio.play("DashCopter", e.root, 1.1)
			end
		end
	end,
}

FX[9] = { -- Fish Surf: a wake of spray and foam behind the board
	start = function(e)
		Fx.word(e.root.Position + Vector3.new(0, 4, 0), "SURF'S UP!", { Color3.fromRGB(255, 255, 255), e.move.colors[1] }, 0.9)
		Audio.play("DashSplash", e.root)
		local fish = K.companion(e.owner, 1)
		local base = fish and fish.PrimaryPart or e.root
		local wake = Instance.new("ParticleEmitter")
		wake.Texture = SMOKE
		wake.Color = ColorSequence.new(Color3.fromRGB(200, 236, 255), Color3.fromRGB(255, 255, 255))
		wake.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.2) })
		wake.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		wake.Lifetime = NumberRange.new(0.35, 0.6)
		wake.Speed = NumberRange.new(5, 9)
		wake.SpreadAngle = Vector2.new(35, 35)
		wake.Rate = 80
		wake.Drag = 2
		wake.EmissionDirection = Enum.NormalId.Back
		wake.Parent = base
		table.insert(e.cleanup, wake)
		local drops = Instance.new("ParticleEmitter")
		drops.Color = ColorSequence.new(Color3.fromRGB(120, 210, 255))
		drops.LightEmission = 0.6
		drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.1) })
		drops.Lifetime = NumberRange.new(0.4, 0.7)
		drops.Speed = NumberRange.new(8, 14)
		drops.SpreadAngle = Vector2.new(60, 25)
		drops.Acceleration = Vector3.new(0, -40, 0)
		drops.Rate = 60
		drops.EmissionDirection = Enum.NormalId.Top
		drops.Parent = base
		table.insert(e.cleanup, drops)
	end,
	step = function(e, u)
		local d = e.data
		if u > 0.78 and not d.stopped then
			d.stopped = true
			for _, inst in ipairs(e.cleanup) do
				if inst:IsA("ParticleEmitter") then
					inst.Enabled = false
				end
			end
			K.sparks(K.feet(e) + Vector3.new(0, 0.5, 0), 14, Color3.fromRGB(150, 220, 255), 14)
			Audio.play("DashSplash", e.root, 1.3)
		end
	end,
}

FX[10] = { -- Fish Rocket: BOOP! then a stream of bubbles behind you
	step = function(e, u)
		local d = e.data
		if not d.booped and u > 0.11 then
			d.booped = true
			local back = e.root.Position - e.root.CFrame.LookVector * 1.4
			Fx.burst(back, { e.move.colors[1], e.move.colors[2], Color3.new(1, 1, 1) }, 4, 10, e.root.CFrame.LookVector)
			Fx.word(back + Vector3.new(0, 3.5, 0), "BOOP!", { Color3.fromRGB(255, 255, 255), e.move.colors[1] }, 0.9)
			K.cloud(back, 0.7)
			Audio.play("DashBoop", e.root)
			Audio.play("DashZip", e.root, 1.1)
		end
		if u > 0.11 and u < 0.48 then
			if os.clock() > (d.bubbleAt or 0) then
				d.bubbleAt = os.clock() + 0.025
				local behind = e.root.Position - e.root.CFrame.LookVector * 2 + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.6, 0.8), rng:NextNumber(-0.8, 0.8))
				local b = K.part(Enum.PartType.Ball, Vector3.one * rng:NextNumber(0.4, 0.9), CFrame.new(behind), Color3.fromRGB(200, 240, 255), Enum.Material.Glass, 0.3)
				K.tween(b, 0.5, { CFrame = CFrame.new(behind - e.root.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0)), Size = b.Size * 1.6, Transparency = 1 })
				Debris:AddItem(b, 0.55)
			end
			K.streaks(e.root, e.root.CFrame.LookVector, e.move.colors[2], 1)
		end
	end,
}

FX[11] = { -- Tail Slap: SLAP!, a rolling tumble of dust, dizzy stars after
	step = function(e, u)
		local d = e.data
		if not d.slapped and u > 0.09 then
			d.slapped = true
			local back = e.root.Position - e.root.CFrame.LookVector * 1.2 + Vector3.new(0, 0.5, 0)
			Fx.burst(back, { Color3.fromRGB(255, 240, 150), Color3.new(1, 1, 1) }, 4.5, 12, e.root.CFrame.LookVector)
			Fx.word(back + Vector3.new(0, 3.5, 0), ({ "SLAP!", "THWACK!", "SMACK!" })[rng:NextInteger(1, 3)], { Color3.fromRGB(255, 250, 150), Color3.fromRGB(255, 110, 80) }, 1)
			Audio.play("DashSlap", e.root)
		end
		if u > 0.12 and u < 0.46 and os.clock() > (d.puffAt or 0) then
			d.puffAt = os.clock() + 0.06
			K.cloud(K.feet(e) + Vector3.new(0, 0.8, 0), 0.5)
		end
		if u > 0.47 then
			local head = e.character:FindFirstChild("Head")
			if head then
				if not d.stars then
					d.stars = {}
					for i = 1, 3 do
						local s = K.part(Enum.PartType.Block, Vector3.new(0.45, 0.45, 0.15), head.CFrame, i == 2 and Color3.new(1, 1, 1) or Color3.fromRGB(255, 220, 60))
						table.insert(d.stars, s)
						table.insert(e.cleanup, s)
					end
				end
				local t = os.clock()
				for i, s in ipairs(d.stars) do
					local a = t * 5 + i * math.pi * 2 / 3
					s.CFrame = head.CFrame * CFrame.new(math.cos(a) * 1.3, 1.1, math.sin(a) * 1.3) * CFrame.Angles(0, -a, math.rad(45) + t * 3)
				end
			end
		end
	end,
}

FX[12] = { -- Tidal Warp: you melt into a rushing wave of light and burst back out in a prism splash
	start = function(e)
		e.data.hidden = {}
		Audio.play("DashSplash", e.root, 0.7)
	end,
	step = function(e, u)
		local d = e.data
		local hide = u > 0.05 and u < 0.3
		if hide and not d.isHidden then
			d.isHidden = true
			for _, inst in ipairs(e.character:GetDescendants()) do
				if inst:IsA("BasePart") or inst:IsA("Decal") then
					table.insert(d.hidden, inst)
					inst.LocalTransparencyModifier = 1
				end
			end
			K.sparks(e.root.Position, 24, e.move.colors[1], 24)
			Fx.ring(e.root.Position, e.move.colors[1], 7, 0.35, 0.4)
			if e.isMe then
				MotionBus.kick = { at = os.clock(), amount = 14, length = 0.5 }
			end
		end
		if d.isHidden and hide then
			-- the wave: a crest of glassy light and foam rushing along with you
			local cf = e.root.CFrame
			for k = -2, 2 do
				local at = (cf * CFrame.new(k * 0.9, -1.5 + math.abs(k) * -0.3, 0)).Position
				local crest = K.part(Enum.PartType.Ball, Vector3.new(1.6, 2.4 - math.abs(k) * 0.4, 1.6), CFrame.new(at), Color3.fromHSV((os.clock() * 0.8 + k * 0.08) % 1, 0.45, 1), nil, 0.25)
				K.tween(crest, 0.4, { Size = crest.Size * 0.2, Transparency = 1, CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0)) })
				Debris:AddItem(crest, 0.42)
			end
			K.smoke(K.feet(e) + Vector3.new(0, 0.5, 0), 3, Color3.fromRGB(200, 250, 255), 1.4, 6)
			K.streaks(e.root, cf.LookVector, e.move.colors[2], 2)
		end
		if not hide and d.isHidden then
			d.isHidden = false
			for _, inst in ipairs(d.hidden) do
				inst.LocalTransparencyModifier = 0
			end
			d.hidden = {}
			-- burst back out: a prism splash, rings in every colour, a word
			local at = e.root.Position
			for i = 0, 3 do
				task.delay(i * 0.06, function()
					Fx.ring(K.ground(at, at - Vector3.new(0, 3, 0)) + Vector3.new(0, 0.3, 0), Color3.fromHSV(i / 4, 0.5, 1), 6 + i * 3, 0.45, 0.4)
				end)
			end
			K.sparks(at, 40, e.move.colors[2], 30)
			Fx.cubes(at, { e.move.colors[1], e.move.colors[2], Color3.new(1, 1, 1) }, { spread = 10, size = 0.5, life = 0.7, count = 24 })
			Fx.word(at + Vector3.new(0, 4.5, 0), "WARP!", { Color3.fromRGB(255, 255, 255), e.move.colors[1] }, 1.1)
			Audio.play("DashSplash", e.root, 1.2)
			Audio.play("DashPop", e.root, 0.8)
			if e.isMe then
				FishingFeel.shake(0.2, 0.2)
			end
		end
	end,
	finish = function(e)
		for _, inst in ipairs(e.data.hidden or {}) do
			inst.LocalTransparencyModifier = 0
		end
	end,
}

-- Running effects -------------------------------------------------------------------------------------------------

local running = {} -- [character] = e

local function finish(e)
	for _, inst in ipairs(e.cleanup) do
		if inst:IsA("ParticleEmitter") then
			inst.Enabled = false
			Debris:AddItem(inst, 1)
		elseif inst:IsA("Trail") then
			inst.Enabled = false
			Debris:AddItem(inst, 0.4)
		elseif inst:IsA("Attachment") then
			Debris:AddItem(inst, 0.45)
		else
			inst:Destroy()
		end
	end
	e.cleanup = {}
	if e.fx and e.fx.finish then
		e.fx.finish(e)
	end
end

local function startFx(owner, character, id, start, target)
	local old = running[character]
	if old then
		finish(old)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local move = DashMoves.byId[id]
	if not root or not move then
		return
	end
	local e = { owner = owner, character = character, root = root, move = move, start = start, isMe = owner == player, target = target, data = {}, cleanup = {}, fx = FX[id] }
	running[character] = e
	-- shared take-off: trails, a cartoon cloud left behind, a ring and a puff of smoke at your feet
	for _, inst in ipairs(K.trails(character, move.colors)) do
		table.insert(e.cleanup, inst)
	end
	local feet = K.ground(root.Position, root.Position - Vector3.new(0, 3, 0))
	if os.clock() - start < 0.2 then
		K.cloud(feet + Vector3.new(0, 1, 0), 0.9)
		Fx.ring(feet + Vector3.new(0, 0.2, 0), move.colors[1], 5, 0.3, 0.25)
		K.smoke(feet + Vector3.new(0, 0.3, 0), 8, nil, 1.6, 10)
		Audio.play("DashWhoosh", root, rng:NextNumber(0.9, 1.1))
		Audio.play("DashPop", root, rng:NextNumber(0.9, 1.15))
	end
	if e.fx and e.fx.start then
		e.fx.start(e)
	end
end

-- Your screen: speed lines round the edge and the move's name -----------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "TideboundDash"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 2
screen.Parent = player:WaitForChild("PlayerGui")
local lines = {}
for i = 1, 30 do
	local a = i / 30 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 1
	line.Rotation = math.deg(a)
	line.Parent = screen
	lines[i] = { frame = line, angle = a, radius = rng:NextNumber(0.42, 0.56), len = rng:NextNumber(0.12, 0.24) }
end
local nameLabel = Instance.new("TextLabel")
nameLabel.BackgroundTransparency = 1
nameLabel.AnchorPoint = Vector2.new(0.5, 1)
nameLabel.Position = UDim2.new(0.5, 0, 1, -80) -- above the stamina bar and the ability pill
nameLabel.Size = UDim2.fromOffset(360, 40)
nameLabel.Font = Enum.Font.LuckiestGuy
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.TextTransparency = 1
nameLabel.Parent = screen
local nameStroke = Instance.new("UIStroke")
nameStroke.Thickness = 3
nameStroke.Color = Color3.fromRGB(24, 16, 40)
nameStroke.Transparency = 1
nameStroke.Parent = nameLabel
local nameGradient = Instance.new("UIGradient")
nameGradient.Rotation = 90
nameGradient.Parent = nameLabel
local screenFx = { start = -10, length = 1, color = Color3.new(1, 1, 1) }

local function showName(move)
	local icon = move.rod and "🎣 " or move.fish and "🐟 " or ""
	nameLabel.Text = icon .. move.name .. "!"
	nameGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), move.colors[1])
	nameLabel.TextTransparency = 0
	nameStroke.Transparency = 0
	nameLabel.Rotation = rng:NextNumber(-5, 5)
	nameLabel.Size = UDim2.fromOffset(460, 52)
	K.tween(nameLabel, 0.25, { Size = UDim2.fromOffset(360, 40) }, Enum.EasingStyle.Back)
	K.tween(nameLabel, 0.35, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.7)
	K.tween(nameStroke, 0.35, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.7)
	screenFx.start, screenFx.length, screenFx.color = os.clock(), math.min(move.length, 0.7), move.colors[1]
end

local function updateScreen()
	local u = (os.clock() - screenFx.start) / screenFx.length
	local strength = u < 0 and 0 or u < 0.1 and u / 0.1 or math.max(0, 1 - (u - 0.1) / 0.9)
	for i, l in ipairs(lines) do
		local f = l.frame
		if strength <= 0.01 then
			f.BackgroundTransparency = 1
		else
			local jitter = 0.03 * math.sin(os.clock() * 40 + i)
			local r = l.radius + jitter
			f.Position = UDim2.fromScale(0.5 + math.cos(l.angle) * r, 0.5 + math.sin(l.angle) * r)
			f.Size = UDim2.new(l.len * strength, 0, 0, 2 + 2 * strength)
			f.BackgroundColor3 = (i % 3 == 0) and screenFx.color or Color3.new(1, 1, 1)
			f.BackgroundTransparency = 1 - 0.65 * strength
		end
	end
end

-- Your dash: choosing a move and moving you -----------------------------------------------------------------------

local me = { lastId = 0, readyAt = 0, active = nil }

local function grounded(humanoid)
	return humanoid.FloorMaterial ~= Enum.Material.Air
end

local function canDash(humanoid)
	local stamina = MotionBus.stamina
	return humanoid.Health > 0 and not humanoid.Sit and not FishingFeel.frozen and not MotionBus.cutscene and FishingFeel.phase == "" and not (stamina and stamina.winded) and humanoid:GetState() ~= Enum.HumanoidStateType.Swimming and not (MotionBus.ride and MotionBus.ride[humanoid.Parent]) -- no dashing off your fish
end

local function pickMove(character, humanoid)
	local hasRod = character:FindFirstChild("TideboundRod") ~= nil
	local hasFish = K.companion(player, nil) ~= nil
	local inAir = not grounded(humanoid)
	local stamina = MotionBus.stamina and MotionBus.stamina.value or ST.max
	-- Patch 20: only the dashes you've equipped (the server puts their ids on you as "Dashes")
	local equipped = nil
	local list = player:GetAttribute("Dashes")
	if type(list) == "string" and list ~= "" then
		equipped = {}
		for id in list:gmatch("%d+") do
			equipped[tonumber(id)] = true
		end
	end
	local options = {}
	for _, move in ipairs(DashMoves.list) do
		local ok = (not equipped or equipped[move.id]) and (not move.rod or hasRod) and (not move.fish or hasFish) and (not inAir or move.air) and stamina >= move.cost * 0.5
		if ok then
			table.insert(options, move)
		end
	end
	-- never the same one twice in a row, unless it's the only one you can do
	if #options > 1 then
		for i, move in ipairs(options) do
			if move.id == me.lastId then
				table.remove(options, i)
				break
			end
		end
	end
	if #options == 0 then
		return nil
	end
	return options[rng:NextInteger(1, #options)]
end

local function hookTarget(root, dir, reach)
	K.filter()
	local origin = root.Position + Vector3.new(0, 1, 0)
	local wall = workspace:Raycast(origin, dir * reach, groundParams)
	if wall then
		return wall.Position - dir * 1.5
	end
	local ahead = root.Position + dir * reach * 0.85
	local floor = workspace:Raycast(ahead + Vector3.new(0, 25, 0), Vector3.new(0, -60, 0), groundParams)
	if floor then
		return floor.Position + Vector3.new(0, 2.5, 0)
	end
	return ahead
end

local function stopMover()
	local a = me.active
	if a and a.mover then
		a.mover:Destroy()
		a.mover = nil
	end
end

local function dash()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local stamina = MotionBus.stamina
	if not humanoid or not root or not canDash(humanoid) or os.clock() < me.readyAt then
		if stamina then
			stamina.shownAt = os.clock()
		end
		return
	end
	local move = pickMove(character, humanoid)
	if not move then
		if stamina then
			stamina.shownAt = os.clock()
		end
		return
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return
	end
	dir = dir.Unit
	local now = os.clock()
	me.lastId = move.id
	me.readyAt = now + ST.dashCooldown
	if stamina then
		stamina.value = math.max(0, stamina.value - move.cost)
		stamina.lastDrain = now
		stamina.shownAt = now
	end
	local target = move.profile.kind == "hook" and hookTarget(root, dir, move.profile.reach) or nil
	stopMover()
	me.active = { move = move, start = now, dir = dir, target = target, launched = false }
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	MotionBus.dash[character] = { start = now, kind = move.id }
	MotionBus.kick = { at = now, amount = ST.dashFov, length = 0.45 }
	startFx(player, character, move.id, now, target)
	showName(move)
	if remote then
		remote:FireServer("dash", move.id, target)
	end
end

local function newMover(root, perAxis)
	local attachment = root:FindFirstChild("DashAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "DashAttachment"
		attachment.Parent = root
	end
	local mover = Instance.new("LinearVelocity")
	mover.Name = "DashVelocity"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	if perAxis then
		mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		mover.MaxAxesForce = Vector3.new(1, 0, 1) * 60000
	else
		mover.MaxForce = 90000
	end
	mover.Parent = root
	return mover
end

-- moves you, every physics step
local function drive()
	local a = me.active
	if not a then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local prof = a.move.profile
	local t = os.clock() - a.start - (prof.delay or 0)
	if not humanoid or not root or humanoid.Health <= 0 or MotionBus.cutscene or FishingFeel.frozen or t > prof.time then
		stopMover()
		if a.move.profile.kind == "hook" and root and t > prof.time then
			root.AssemblyLinearVelocity = a.dir * 24 + Vector3.new(0, 12, 0) -- let go with a little fling
		end
		me.active = nil
		return
	end
	if t < 0 then
		return -- winding up (the fish is on its way, the rod is going down, the line is flying out)
	end
	local s = t / prof.time
	local walk = humanoid.WalkSpeed
	if prof.kind == "dash" then
		a.mover = a.mover or newMover(root, true)
		local ease = prof.floor and (1 - s ^ 3) or (1 - s) ^ 2
		a.mover.VectorVelocity = a.dir * (walk + (prof.speed - walk) * ease)
	elseif prof.kind == "arc" then
		if not a.launched then
			a.launched = true
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			root.AssemblyLinearVelocity = a.dir * prof.speed + Vector3.new(0, prof.lift, 0)
		end
		a.mover = a.mover or newMover(root, true)
		a.mover.VectorVelocity = a.dir * prof.speed * (1 - 0.35 * s)
		if s > 0.35 and grounded(humanoid) then
			a.start -= prof.time -- landed early: done
		end
	elseif prof.kind == "hook" then
		a.mover = a.mover or newMover(root, false)
		local to = (a.target or root.Position) - root.Position
		if to.Magnitude < 4 then
			a.start -= prof.time
		else
			a.mover.VectorVelocity = to.Unit * prof.speed
		end
	elseif prof.kind == "glide" then
		a.mover = a.mover or newMover(root, false)
		a.mover.MaxForce = 40000
		a.mover.VectorVelocity = a.dir * prof.speed * (1 - 0.45 * s) + Vector3.new(0, prof.lift * (1 - 1.8 * s), 0)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonB then
		dash()
	end
end)
if UserInputService.TouchEnabled then
	ContextActionService:BindAction("TideboundDash", function(_, state)
		if state == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Sink
	end, true)
	ContextActionService:SetTitle("TideboundDash", "DASH")
	ContextActionService:SetPosition("TideboundDash", UDim2.new(1, -250, 1, -160))
end
player.CharacterAdded:Connect(function()
	me.active = nil
end)

RunService.PreSimulation:Connect(drive)

-- Every frame: start everyone else's dashes from their attributes, and run all the effects ------------------------

local seen = {} -- [character] = the DashAt last started
local filterAt = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if now > filterAt then
		filterAt = now + 1
		K.filter()
	end
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if p ~= player and character then
			local dashAt = character:GetAttribute("DashAt")
			local root = character:FindFirstChild("HumanoidRootPart")
			if dashAt and seen[character] ~= dashAt and root then
				seen[character] = dashAt
				local age = serverNow - dashAt
				local id = character:GetAttribute("DashKind") or 1
				if age >= 0 and age < DashMoves.length(id) and (root.Position - eye).Magnitude < FX_RANGE then
					local target = character:GetAttribute("DashTarget")
					startFx(p, character, id, now - age, typeof(target) == "Vector3" and target or nil)
				end
			end
		end
	end
	for character, e in pairs(running) do
		local u = now - e.start
		if not character.Parent or not e.root.Parent or u > e.move.length then
			finish(e)
			running[character] = nil
		elseif e.fx and e.fx.step then
			local ok, err = pcall(e.fx.step, e, u, dt)
			if not ok then
				warn("[TideboundDash]", err)
				finish(e)
				running[character] = nil
			end
		end
	end
	updateScreen()
end)
