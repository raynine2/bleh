-- Tidebound: Eggfall: rod abilities (Patch 21). R (Y on a gamepad, SKILL on touch) casts your rod's ability
-- (RodSkills). The server checks it and lands the hit; this script plays it: for everyone, the ability's effects
-- in the world (from the SkillRod / SkillAlt / SkillRoll / SkillAt attributes); for you, the trial rods' short
-- cinematic first (the camera takes over, letterbox bars, a colour grade, the ability's name across the bottom
-- and its own screen art: the crimson eye, the reels, the void, the black hole), and a pill showing the cooldown.
-- Effects stay clean: a few big readable shapes, smooth tweens, light and particles used sparingly.
-- Patch 22: Boundless Void and Sun God Bounce remade entirely in the world (no flat screen art): orbs, rings,
-- trails, particles and moving parts, each with its own camera path.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local RodSkills = require(Shared:WaitForChild("RodSkills"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))
local Remotes = Shared:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local rng = Random.new()
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2
local FX_RANGE = 220

local folder = Instance.new("Folder")
folder.Name = "TideboundSkillFX"
folder.Parent = workspace

-- Helpers -----------------------------------------------------------------------------------------------------

local K = {}

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

function K.fade(p, time, delay, grow)
	K.tween(p, time, { Transparency = 1, Size = p.Size * (grow or 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
	Debris:AddItem(p, time + (delay or 0) + 0.05)
end

function K.burst(at, count, props)
	local holder = K.part(nil, Vector3.one * 0.2, CFrame.new(at), WHITE, nil, 1)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, (props.Lifetime and props.Lifetime.Max or 1) + 0.2)
end

function K.smoke(at, count, color, size, speed)
	K.burst(at, count, {
		Texture = SMOKE,
		Color = ColorSequence.new(color or Color3.fromRGB(240, 244, 252)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, (size or 2) * 0.5), NumberSequenceKeypoint.new(1, (size or 2) * 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new((speed or 8) * 0.5, speed or 8),
		SpreadAngle = Vector2.new(180, 25),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Drag = 4,
		EmissionDirection = Enum.NormalId.Top,
	})
end

function K.sparks(at, count, color, speed)
	K.burst(at, count, {
		Color = ColorSequence.new(color or WHITE),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new((speed or 16) * 0.5, speed or 16),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
end

-- a flat ring that grows and fades on the ground
function K.ring(at, color, radius, life, thickness)
	return Fx.ring(at, color, radius, life or 0.5, thickness or 0.4)
end

-- a ball of light that swells and fades
function K.swell(at, color, from, to, life, transparency, material)
	local p = K.part(Enum.PartType.Ball, Vector3.one * from, CFrame.new(at), color, material, transparency or 0.2)
	K.tween(p, life, { Size = Vector3.one * to }, Enum.EasingStyle.Quart)
	K.tween(p, life, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, life + 0.05)
	return p
end

-- a zig-zag bolt of lightning from `from` down to `to`
function K.bolt(from, to, color, width)
	local points = { from }
	for i = 1, 5 do
		local s = i / 6
		table.insert(points, from:Lerp(to, s) + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)))
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = K.part(nil, Vector3.new(width or 0.5, width or 0.5, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, nil, 0)
		K.fade(seg, 0.35, 0.05)
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
function K.ground(at)
	local list = { folder, Fx.folder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "TideboundCompanions", "TideboundMobs", "TideboundFoliage", "TideboundLife", "TideboundDashFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	groundParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), groundParams)
	return hit and hit.Position or (at - Vector3.new(0, 3, 0))
end

-- where an ability lands: `forward` studs ahead of the caster, on the ground
function K.target(e, forward)
	local look = e.root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	return K.ground(e.root.Position + flatLook * forward)
end

function K.word(at, text, colors, scale)
	Fx.word(at, text, colors, scale)
end

-- Per-ability effects (everyone sees these) --------------------------------------------------------------------
-- e = { owner, character, root, rod, alt, roll, start, isMe, data = {}, cleanup = {} }; step(e, u) runs every
-- frame until the cast's length.

local FX = {}

FX.Drift = { -- a curling wave rolls forward and crashes
	step = function(e, u, skill)
		local d = e.data
		if not d.wave and u > 0.22 then
			d.wave = true
			Audio.play("SkillWave", e.root)
			local base = e.root.CFrame
			for i = -3, 3 do
				local delay = math.abs(i) * 0.02
				local start = K.ground((base * CFrame.new(i * 1.6, 0, -2)).Position) + Vector3.new(0, 1, 0)
				local stop = K.ground((base * CFrame.new(i * 1.9, 0, -skill.forward - 3)).Position) + Vector3.new(0, 1, 0)
				local crest = K.part(Enum.PartType.Ball, Vector3.new(2.4, 3.6, 2.4), CFrame.new(start), Color3.fromRGB(110, 200, 255), Enum.Material.Glass, 0.25)
				local foam = K.part(Enum.PartType.Ball, Vector3.new(2.2, 1, 2.2), CFrame.new(start + Vector3.new(0, 1.8, 0)), WHITE, Enum.Material.SmoothPlastic, 0.1)
				K.tween(crest, 0.4, { CFrame = CFrame.new(stop + Vector3.new(0, 1.2, 0)), Size = Vector3.new(2.8, 4.8, 2.8) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
				K.tween(foam, 0.4, { CFrame = CFrame.new(stop + Vector3.new(0, 3.6, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
				K.fade(crest, 0.3, 0.42 + delay, 1.4)
				K.fade(foam, 0.3, 0.42 + delay, 1.6)
			end
		end
		if not d.crash and u > skill.impact + 0.08 then
			d.crash = true
			local at = K.target(e, skill.forward)
			K.ring(at + Vector3.new(0, 0.2, 0), skill.colors[1], skill.radius, 0.5, 0.4)
			K.smoke(at + Vector3.new(0, 0.5, 0), 14, Color3.fromRGB(210, 240, 255), 2.2, 12)
			K.sparks(at + Vector3.new(0, 1, 0), 16, skill.colors[1], 20)
		end
	end,
}

FX.Coral = { -- coral spikes burst out of the ground in a ring
	step = function(e, u, skill)
		local d = e.data
		if not d.bloom and u > skill.impact then
			d.bloom = true
			Audio.play("SkillCrash", e.root, 1.3)
			local center = K.ground(e.root.Position)
			K.ring(center + Vector3.new(0, 0.2, 0), skill.colors[1], skill.radius, 0.5, 0.4)
			for i = 1, 16 do
				local a = i / 16 * TAU + rng:NextNumber(-0.15, 0.15)
				local r = rng:NextNumber(3.5, skill.radius - 1)
				local at = K.ground(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				local h = rng:NextNumber(3.5, 6.5)
				local tilt = CFrame.Angles(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3)
				local spike = K.part(nil, Vector3.new(0.9, 0.2, 0.9), CFrame.new(at) * tilt, skill.colors[(i % 2) + 1], Enum.Material.SmoothPlastic, 0)
				K.tween(spike, 0.18, { Size = Vector3.new(0.9, h, 0.9), CFrame = CFrame.new(at) * tilt * CFrame.new(0, h / 2, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, i * 0.012)
				local tip = K.part(Enum.PartType.Ball, Vector3.one * 0.3, CFrame.new(at), WHITE, nil, 0)
				K.tween(tip, 0.18, { CFrame = CFrame.new(at) * tilt * CFrame.new(0, h, 0), Size = Vector3.one * 0.7 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, i * 0.012)
				K.tween(spike, 0.3, { Size = Vector3.new(0.9, 0.1, 0.9), CFrame = CFrame.new(at) * tilt, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.7)
				K.fade(tip, 0.3, 0.7)
				Debris:AddItem(spike, 1.1)
			end
			K.smoke(center + Vector3.new(0, 0.5, 0), 12, Color3.fromRGB(255, 220, 230), 2, 12)
		end
	end,
}

FX.Stormline = { -- three lightning strikes march out ahead
	step = function(e, u, skill)
		local d = e.data
		d.strikes = d.strikes or 0
		local due = u >= skill.impact and math.min(3, 1 + math.floor((u - skill.impact) / 0.1)) or 0
		while d.strikes < due do
			d.strikes += 1
			local at = K.target(e, 3 + d.strikes * 3.5)
			K.bolt(at + Vector3.new(rng:NextNumber(-3, 3), 45, rng:NextNumber(-3, 3)), at, Color3.fromRGB(220, 240, 255), 0.6)
			K.bolt(at + Vector3.new(rng:NextNumber(-4, 4), 40, rng:NextNumber(-4, 4)), at, skill.colors[1], 0.3)
			K.swell(at + Vector3.new(0, 1, 0), WHITE, 1, 7, 0.3, 0.1)
			K.ring(at + Vector3.new(0, 0.2, 0), skill.colors[1], 6, 0.4, 0.35)
			K.sparks(at + Vector3.new(0, 0.5, 0), 14, skill.colors[2], 22)
			Audio.play("SkillZap", e.root, 0.9 + d.strikes * 0.1)
			if e.isMe then
				FishingFeel.shake(0.12, 0.1)
			end
		end
	end,
}

FX.Abyssal = { -- a vortex drags everything in, then shadow jaws snap shut
	start = function(e)
		Audio.play("SkillCast", e.root, 0.7)
	end,
	step = function(e, u, skill)
		local d = e.data
		if not d.vortex and u > 0.12 then
			d.vortex = {}
			d.center = K.target(e, skill.forward) + Vector3.new(0, 0.3, 0)
			for i = 1, 3 do
				local ring = K.part(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), CFrame.new(d.center) * CFrame.Angles(0, 0, math.rad(90)), i == 2 and skill.colors[1] or Color3.fromRGB(40, 16, 70), nil, 0.2 + i * 0.12)
				table.insert(d.vortex, ring)
				table.insert(e.cleanup, ring)
			end
		end
		if d.vortex and not d.snapped then
			local grow = math.clamp((u - 0.12) / 0.5, 0, 1)
			for i, ring in ipairs(d.vortex) do
				local r = skill.radius * 2 * grow * (1 - (i - 1) * 0.22)
				ring.Size = Vector3.new(0.2, r, r)
				ring.CFrame = CFrame.new(d.center + Vector3.new(0, i * 0.05, 0)) * CFrame.Angles(0, os.clock() * (2 + i), math.rad(90))
			end
			-- wisps spiralling in
			if rng:NextNumber() < 0.6 then
				local a = rng:NextNumber(0, TAU)
				local from = d.center + Vector3.new(math.cos(a) * skill.radius, rng:NextNumber(0.5, 3), math.sin(a) * skill.radius)
				local wisp = K.part(nil, Vector3.new(0.25, 0.25, 2), CFrame.lookAt(from, d.center), skill.colors[1], nil, 0.2)
				K.tween(wisp, 0.4, { CFrame = CFrame.lookAt(d.center, d.center + (d.center - from)), Size = Vector3.new(0.1, 0.1, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(wisp, 0.42)
			end
		end
		if d.vortex and not d.snapped and u > skill.impact then
			d.snapped = true
			-- the jaws: two dark slabs slam together over the centre
			for _, side in ipairs({ 1, -1 }) do
				local jaw = K.part(nil, Vector3.new(skill.radius * 1.4, 1.2, 3), CFrame.new(d.center + Vector3.new(0, 1.5 + side * 5, 0)), Color3.fromRGB(30, 10, 50), Enum.Material.SmoothPlastic, 0.05)
				K.tween(jaw, 0.08, { CFrame = CFrame.new(d.center + Vector3.new(0, 1.5 + side * 0.6, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				K.fade(jaw, 0.3, 0.2)
			end
			K.swell(d.center + Vector3.new(0, 1.5, 0), skill.colors[1], 2, skill.radius * 1.2, 0.4, 0.3)
			K.sparks(d.center + Vector3.new(0, 1.5, 0), 24, skill.colors[1], 24)
			Audio.play("SkillCrash", e.root, 0.8)
			for _, ring in ipairs(d.vortex) do
				K.tween(ring, 0.25, { Size = Vector3.new(0.2, 0.5, 0.5), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			if e.isMe then
				FishingFeel.shake(0.2, 0.15)
			end
		end
	end,
}

FX.Riftcaster = { -- three slashes tear space open, then it all shatters
	step = function(e, u, skill)
		local d = e.data
		d.cuts = d.cuts or 0
		local due = math.min(3, math.floor((u - 0.06) / 0.18) + 1)
		while d.cuts < due and u > 0.06 do
			d.cuts += 1
			local center = e.root.Position + e.root.CFrame.LookVector * skill.forward + Vector3.new(0, 1.5, 0)
			local angle = ({ 0.7, -0.7, 0 })[d.cuts]
			local cf = CFrame.lookAt(center, center + e.root.CFrame.LookVector) * CFrame.Angles(0, 0, angle) * CFrame.Angles(0, math.rad(90), 0)
			local slash = K.part(nil, Vector3.new(16, 0.15, 0.15), cf, WHITE, nil, 0)
			K.tween(slash, 0.08, { Size = Vector3.new(18, 0.5, 0.15) })
			local tear = K.part(nil, Vector3.new(16, 1.2, 0.1), cf, Color3.fromRGB(10, 6, 20), Enum.Material.SmoothPlastic, 0.05)
			table.insert(e.cleanup, slash)
			table.insert(e.cleanup, tear)
			d.tears = d.tears or {}
			table.insert(d.tears, { slash, tear })
			Audio.play("SkillZap", e.root, 1.6)
		end
		if not d.shattered and u > skill.impact then
			d.shattered = true
			local center = e.root.Position + e.root.CFrame.LookVector * skill.forward + Vector3.new(0, 1.5, 0)
			for _, pair in ipairs(d.tears or {}) do
				for _, p in ipairs(pair) do
					K.fade(p, 0.2, 0, 1.2)
				end
			end
			for _ = 1, 18 do
				local shard = K.part(nil, Vector3.new(rng:NextNumber(0.4, 1), rng:NextNumber(0.4, 1.4), 0.1), CFrame.new(center) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0), (rng:NextNumber() < 0.5) and skill.colors[1] or skill.colors[2], Enum.Material.Glass, 0.1)
				local out = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(6, 12)
				K.tween(shard, 0.5, { CFrame = shard.CFrame + out, Transparency = 1 }, Enum.EasingStyle.Quart)
				Debris:AddItem(shard, 0.52)
			end
			K.swell(center, WHITE, 1, 9, 0.25, 0.05)
			K.ring(K.ground(center) + Vector3.new(0, 0.2, 0), skill.colors[2], skill.radius, 0.45, 0.35)
			Audio.play("SkillCrash", e.root, 1.4)
		end
	end,
}

FX.Celestial = { -- stars rain down all around
	step = function(e, u, skill)
		local d = e.data
		d.stars = d.stars or 0
		if u > 0.5 and u < 1.25 and d.stars < 14 and os.clock() > (d.nextStar or 0) then
			d.nextStar = os.clock() + 0.05
			d.stars += 1
			local a, r = rng:NextNumber(0, TAU), rng:NextNumber(2, skill.radius)
			local at = K.ground(e.root.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			local from = at + Vector3.new(rng:NextNumber(-6, 6), 40, rng:NextNumber(-6, 6))
			local star = K.part(nil, Vector3.new(1, 1, 0.3), CFrame.new(from) * CFrame.Angles(0, 0, math.rad(45)), skill.colors[(d.stars % 2) + 1], nil, 0)
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.4, 0)
			a0.Parent = star
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.4, 0)
			a1.Parent = star
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.3
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Color = ColorSequence.new(skill.colors[1], skill.colors[2])
			trail.Transparency = NumberSequence.new(0, 1)
			trail.Parent = star
			K.tween(star, 0.35, { CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 2, math.rad(45)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.35, function()
				K.ring(at + Vector3.new(0, 0.2, 0), skill.colors[1], 4, 0.35, 0.3)
				K.sparks(at + Vector3.new(0, 0.5, 0), 8, skill.colors[1], 14)
				star:Destroy()
			end)
		end
		if not d.big and u > skill.impact then
			d.big = true
			K.ring(K.ground(e.root.Position) + Vector3.new(0, 0.2, 0), skill.colors[1], skill.radius, 0.6, 0.4)
			Audio.play("SkillZap", e.root, 0.7)
		end
	end,
}

-- a crow: a dark body and two flapping wings, flying out on a curve, then a puff of black feathers
local function crow(origin, angle, speed, life)
	local body = K.part(nil, Vector3.new(0.6, 0.5, 1.3), CFrame.new(origin), Color3.fromRGB(14, 10, 16), Enum.Material.SmoothPlastic, 0)
	local wingL = K.part(nil, Vector3.new(1.4, 0.1, 0.7), CFrame.new(origin), Color3.fromRGB(20, 14, 22), Enum.Material.SmoothPlastic, 0)
	local wingR = K.part(nil, Vector3.new(1.4, 0.1, 0.7), CFrame.new(origin), Color3.fromRGB(20, 14, 22), Enum.Material.SmoothPlastic, 0)
	local eye = K.part(Enum.PartType.Ball, Vector3.one * 0.18, CFrame.new(origin), Color3.fromRGB(255, 40, 60), nil, 0)
	local start = os.clock()
	local rise = rng:NextNumber(0.5, 3)
	local curve = rng:NextNumber(-1.2, 1.2)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > life then
			conn:Disconnect()
			K.smoke(body.Position, 4, Color3.fromRGB(20, 14, 22), 1.2, 4)
			for _, p in ipairs({ body, wingL, wingR, eye }) do
				p:Destroy()
			end
			return
		end
		local a = angle + curve * t
		local pos = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * speed * t + Vector3.new(0, rise * t * 2 + math.sin(t * 6) * 0.4, 0)
		local dir = Vector3.new(-math.sin(a) * curve + math.cos(a) * speed, rise * 2, math.cos(a) * curve + math.sin(a) * speed)
		local cf = CFrame.lookAt(pos, pos + dir)
		local flap = math.sin(t * 22) * 0.8
		body.CFrame = cf
		wingL.CFrame = cf * CFrame.new(-0.3, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 0, 0)
		wingR.CFrame = cf * CFrame.new(0.3, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 0, 0)
		eye.CFrame = cf * CFrame.new(0, 0.12, -0.6)
	end)
end

FX.CrimsonCrow = { -- a red eye flashes over the caster; at the impact a storm of crows bursts out
	start = function(e)
		local head = e.character:FindFirstChild("Head")
		if head and not e.isMe then
			Fx.alert(head, "◉", Color3.fromRGB(200, 20, 40), 1.2, 2.6)
		end
	end,
	step = function(e, u, skill)
		local d = e.data
		if not d.burst and u > skill.impact - 0.05 then
			d.burst = true
			local origin = e.root.Position + Vector3.new(0, 1.5, 0)
			for i = 1, 26 do
				crow(origin, i / 26 * TAU + rng:NextNumber(-0.2, 0.2), rng:NextNumber(12, 22), rng:NextNumber(0.7, 1.1))
			end
			K.swell(origin, Color3.fromRGB(180, 10, 30), 2, skill.radius * 2, 0.6, 0.55)
			K.ring(K.ground(e.root.Position) + Vector3.new(0, 0.2, 0), skill.colors[1], skill.radius, 0.6, 0.5)
			K.smoke(origin, 18, Color3.fromRGB(30, 10, 14), 3, 14)
			Audio.play("SkillCaw", e.root)
			Audio.play("SkillCrash", e.root, 0.6)
		end
	end,
}

FX.Jackpot = { -- coins burst out; on a jackpot, a gold rain and a golden aura for the fever
	step = function(e, u, skill)
		local d = e.data
		if not d.paid and u > skill.impact then
			d.paid = true
			local origin = e.root.Position + Vector3.new(0, 1, 0)
			local win = e.roll == 1
			for _ = 1, win and 30 or 14 do
				local coin = K.part(Enum.PartType.Cylinder, Vector3.new(0.18, 0.9, 0.9), CFrame.new(origin) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0), Color3.fromRGB(255, 210, 60), Enum.Material.Neon, 0)
				local out = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(5, skill.radius)
				local peak = origin + out * 0.5 + Vector3.new(0, rng:NextNumber(5, 10), 0)
				K.tween(coin, 0.3, { CFrame = CFrame.new(peak) * CFrame.Angles(rng:NextNumber(0, TAU), 0, 2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				K.tween(coin, 0.4, { CFrame = CFrame.new(K.ground(origin + out) + Vector3.new(0, 0.3, 0)), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
				Debris:AddItem(coin, 0.75)
			end
			K.ring(K.ground(e.root.Position) + Vector3.new(0, 0.2, 0), skill.colors[1], skill.radius, 0.5, 0.4)
			Audio.play("SkillCoins", e.root)
			if win then
				Fx.confetti(origin + Vector3.new(0, 3, 0), 40, 8)
				K.word(origin + Vector3.new(0, 5, 0), "JACKPOT!!", { Color3.fromRGB(255, 250, 160), Color3.fromRGB(255, 160, 40) }, 1.5)
				-- the fever aura: gold sparkles round you while you're untouchable
				local torso = e.character:FindFirstChild("UpperTorso") or e.root
				local aura = Instance.new("ParticleEmitter")
				aura.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(120, 255, 160))
				aura.LightEmission = 1
				aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
				aura.Lifetime = NumberRange.new(0.5, 0.9)
				aura.Speed = NumberRange.new(1, 3)
				aura.SpreadAngle = Vector2.new(180, 180)
				aura.Rate = 30
				aura.Parent = torso
				Debris:AddItem(aura, skill.fever)
				local glow = Instance.new("Highlight")
				glow.FillColor = Color3.fromRGB(255, 220, 90)
				glow.FillTransparency = 0.75
				glow.OutlineColor = Color3.fromRGB(255, 240, 160)
				glow.Adornee = e.character
				glow.Parent = folder
				K.tween(glow, 1, { FillTransparency = 1, OutlineTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, skill.fever - 1)
				Debris:AddItem(glow, skill.fever)
			else
				K.word(origin + Vector3.new(0, 4, 0), "SO CLOSE...", { Color3.fromRGB(230, 230, 230), Color3.fromRGB(150, 150, 160) }, 0.9)
			end
		end
	end,
}

-- Patch 22: shared pieces for the remade ultimates ----------------------------------------------------------------

-- a ring of glowing segments; place(cf, radius, spin) puts it flat in cf's XZ plane
function K.ringParts(count, color, thickness, transparency)
	local ring = { parts = {}, thickness = thickness }
	for i = 1, count do
		ring.parts[i] = K.part(nil, Vector3.new(0.5, thickness, thickness), CFrame.new(), color, nil, transparency or 0)
	end
	function ring.place(cf, radius, spin)
		local n = #ring.parts
		local arc = TAU * radius / n
		for i, p in ipairs(ring.parts) do
			local a = i / n * TAU + (spin or 0)
			p.Size = Vector3.new(math.max(arc * 1.08, 0.05), ring.thickness, ring.thickness)
			p.CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		end
	end
	return ring
end

function K.trail(part, colors, lifetime, width)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width or 0.4, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -(width or 0.4), 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = lifetime or 0.3
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = part
	return trail
end

function K.light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 12
	l.Brightness = brightness or 2
	l.Parent = part
	return l
end

function K.emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

-- a point on the curve from a to c bending toward b
function K.bezier(a, b, c, s)
	local ab, bc = a:Lerp(b, s), b:Lerp(c, s)
	return ab:Lerp(bc, s)
end

-- a camera path from keyframes { time, from (root space), look-at (root space), fov }, eased between them
function K.keyCam(root, u, keys)
	local cf = root.CFrame
	local k1, k2 = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if u >= keys[i][1] and u <= keys[i + 1][1] then
			k1, k2 = keys[i], keys[i + 1]
			break
		end
	end
	local span = math.max(k2[1] - k1[1], 0.001)
	local s = math.clamp((u - k1[1]) / span, 0, 1)
	s = s * s * (3 - 2 * s)
	local from = (cf * CFrame.new(k1[2]:Lerp(k2[2], s))).Position
	local at = (cf * CFrame.new(k1[3]:Lerp(k2[3], s))).Position
	return CFrame.lookAt(from, at), k1[4] + (k2[4] - k1[4]) * s
end

local function limb(character, names)
	for _, name in ipairs(names) do
		local p = character:FindFirstChild(name)
		if p then
			return p
		end
	end
	return nil
end

FX.SunRubber = { -- the drums of liberation: clouds, white flames and a sun; then a giant stretching rubber fist
	start = function(e)
		local d = e.data
		local head = e.character:FindFirstChild("Head")
		local torso = e.character:FindFirstChild("UpperTorso") or e.root
		-- a white glow over the whole body that pulses with each beat
		d.glow = Instance.new("Highlight")
		d.glow.FillColor = WHITE
		d.glow.FillTransparency = 0.7
		d.glow.OutlineColor = Color3.fromRGB(255, 244, 200)
		d.glow.OutlineTransparency = 0.1
		d.glow.Adornee = e.character
		d.glow.Parent = folder
		table.insert(e.cleanup, d.glow)
		-- white flames licking up off the head
		if head then
			table.insert(e.cleanup, K.emitter(head, {
				Texture = "rbxasset://textures/particles/fire_main.dds",
				Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 240, 190)),
				LightEmission = 0.7,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(2, 4),
				Acceleration = Vector3.new(0, 8, 0),
				SpreadAngle = Vector2.new(25, 25),
				Rate = 45,
				EmissionDirection = Enum.NormalId.Top,
			}))
		end
		-- soft white steam rising off the body
		table.insert(e.cleanup, K.emitter(torso, {
			Texture = SMOKE,
			Color = ColorSequence.new(WHITE),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(1, 2.5),
			Acceleration = Vector3.new(0, 3, 0),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 18,
		}))
		-- cartoon clouds that circle you
		d.clouds = {}
		for i = 1, 7 do
			local cluster = {}
			for k = 1, 3 do
				local puff = K.part(Enum.PartType.Ball, Vector3.one * (1.3 + k * 0.35), CFrame.new(e.root.Position), WHITE, Enum.Material.SmoothPlastic, 0.05)
				table.insert(cluster, { part = puff, offset = Vector3.new((k - 2) * 0.9, (k == 2) and 0.35 or 0, 0) })
				table.insert(e.cleanup, puff)
			end
			d.clouds[i] = cluster
		end
		-- a golden sun turning behind you
		d.sun = K.part(Enum.PartType.Cylinder, Vector3.new(0.3, 0.2, 0.2), CFrame.new(e.root.Position), Color3.fromRGB(255, 214, 90), nil, 0.1)
		K.light(d.sun, Color3.fromRGB(255, 220, 120), 16, 2)
		table.insert(e.cleanup, d.sun)
		d.rays = {}
		for i = 1, 12 do
			local ray = K.part(nil, Vector3.new(0.35, 0.1, 0.1), CFrame.new(e.root.Position), (i % 2 == 0) and Color3.fromRGB(255, 240, 170) or Color3.fromRGB(255, 200, 70), nil, 0.15)
			d.rays[i] = ray
			table.insert(e.cleanup, ray)
		end
	end,
	step = function(e, u, skill)
		local d = e.data
		local cf = e.root.CFrame
		-- 1. the drums: a beat every 0.3 s, each one a ring and a pulse of light
		d.beats = d.beats or 0
		local due = u < 1.3 and math.min(4, math.floor((u - 0.15) / 0.3) + 1) or d.beats
		while d.beats < due do
			d.beats += 1
			local chest = e.root.Position + Vector3.new(0, 0.5, 0)
			K.ring(chest, WHITE, 8, 0.45, 0.35)
			K.swell(chest, WHITE, 2, 10, 0.35, 0.7)
			K.smoke(K.ground(e.root.Position) + Vector3.new(0, 0.3, 0), 5, WHITE, 1.5, 8)
			d.glow.FillTransparency = 0.25
			K.tween(d.glow, 0.25, { FillTransparency = 0.7 })
			Audio.play("SkillDrum", e.root, 0.95 + d.beats * 0.04)
		end
		-- the clouds circle and rise, then puff away
		local cloudFade = math.clamp((u - 1.3) / 0.25, 0, 1)
		for i, cluster in ipairs(d.clouds) do
			local a = u * 1.7 + i * TAU / #d.clouds
			local center = e.root.Position + Vector3.new(math.cos(a) * 4.6, -0.5 + math.sin(u * 2 + i) * 0.8 + u * 0.8, math.sin(a) * 4.6)
			local face = CFrame.lookAt(center, e.root.Position)
			for _, puff in ipairs(cluster) do
				puff.part.CFrame = face * CFrame.new(puff.offset)
				puff.part.Transparency = 0.05 + 0.95 * cloudFade
			end
		end
		-- the sun behind you, rays turning
		local sunGrow = math.clamp(u / 0.3, 0, 1) * (1 - math.clamp((u - 1.4) / 0.3, 0, 1))
		local sunCf = cf * CFrame.new(0, 3.2, 2.6)
		d.sun.Size = Vector3.new(0.3, 4.2 * sunGrow + 0.01, 4.2 * sunGrow + 0.01)
		d.sun.CFrame = sunCf * CFrame.Angles(0, math.rad(90), 0)
		for i, ray in ipairs(d.rays) do
			local a = u * 0.8 + i * TAU / #d.rays
			ray.Size = Vector3.new(0.35, (1.6 + 0.4 * math.sin(u * 6 + i)) * sunGrow + 0.01, 0.1)
			ray.CFrame = sunCf * CFrame.Angles(0, 0, a) * CFrame.new(0, (2.1 + 0.9) * sunGrow, 0.05)
		end
		-- 2. the arm: a rubbery tube from your shoulder to a fist, flung back, then whipped forward
		local shoulderPart = limb(e.character, { "RightUpperArm", "Right Arm" })
		local shoulder = shoulderPart and shoulderPart.Position or (cf * CFrame.new(1.2, 1.5, 0)).Position
		if not d.arm and u > 1.28 then
			d.arm = {}
			for i = 1, 16 do
				local ball = K.part(Enum.PartType.Ball, Vector3.one * 1.05, CFrame.new(shoulder), Color3.fromRGB(252, 250, 244), Enum.Material.SmoothPlastic, 0)
				d.arm[i] = ball
				table.insert(e.cleanup, ball)
			end
			d.fist = {
				palm = K.part(Enum.PartType.Ball, Vector3.one, CFrame.new(shoulder), Color3.fromRGB(255, 255, 250), Enum.Material.SmoothPlastic, 0),
				knuckles = {},
				thumb = K.part(Enum.PartType.Ball, Vector3.one, CFrame.new(shoulder), Color3.fromRGB(248, 246, 238), Enum.Material.SmoothPlastic, 0),
			}
			for k = 1, 4 do
				d.fist.knuckles[k] = K.part(Enum.PartType.Ball, Vector3.one, CFrame.new(shoulder), Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic, 0)
				table.insert(e.cleanup, d.fist.knuckles[k])
			end
			table.insert(e.cleanup, d.fist.palm)
			table.insert(e.cleanup, d.fist.thumb)
			K.trail(d.fist.palm, { WHITE, skill.colors[2] }, 0.25, 1.2)
		end
		if d.arm then
			local target = K.target(e, skill.forward) + Vector3.new(0, 3, 0)
			local back = (cf * CFrame.new(1.8, 3.2, 10)).Position
			local fistPos, fistSize, mid
			if u < 1.75 then
				local s = math.clamp((u - 1.3) / 0.45, 0, 1)
				fistPos = shoulder:Lerp(back, 1 - (1 - s) ^ 2)
				fistSize = 1.4 + 0.6 * s
				mid = (cf * CFrame.new(2.8, 4.5, 2 + 3 * s)).Position
			elseif u < skill.impact then
				local s = math.clamp((u - 1.75) / (skill.impact - 1.75), 0, 1)
				local e2 = s * s
				local over = (cf * CFrame.new(3, 9, -skill.forward * 0.4)).Position
				fistPos = K.bezier(back, over, target, e2)
				fistSize = 2 + 5 * e2
				mid = (cf * CFrame.new(2.5, 6, -skill.forward * 0.2)).Position
				if rng:NextNumber() < 0.8 then
					local dir = (target - back).Unit
					local streak = K.part(nil, Vector3.new(0.12, 0.12, rng:NextNumber(3, 6)), CFrame.lookAt(fistPos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)), fistPos + dir), WHITE, nil, 0.3)
					K.fade(streak, 0.2, 0, 1.3)
				end
			else
				-- snapping back like rubber, with a wobble
				local s = math.clamp((u - skill.impact) / 0.5, 0, 1)
				local ease = 1 - (1 - s) ^ 3 + math.sin(s * math.pi * 3) * 0.12 * (1 - s)
				fistPos = target:Lerp(shoulder, ease)
				fistSize = 7 - 6 * s
				mid = (cf * CFrame.new(2.6, 5 * (1 - s) + 1.5, -skill.forward * 0.3 * (1 - s))).Position
				if s >= 1 and not d.gone then
					d.gone = true
					K.smoke(shoulder, 6, WHITE, 1.2, 5)
					for _, ball in ipairs(d.arm) do
						ball.Transparency = 1
					end
					for _, p in ipairs({ d.fist.palm, d.fist.thumb, table.unpack(d.fist.knuckles) }) do
						p.Transparency = 1
					end
				end
			end
			-- the tube follows the curve from the shoulder to the fist, thickening toward the fist
			for i, ball in ipairs(d.arm) do
				local s = i / (#d.arm + 1)
				ball.CFrame = CFrame.new(K.bezier(shoulder, mid, fistPos, s))
				ball.Size = Vector3.one * (0.9 + 0.5 * s + fistSize * 0.06)
			end
			-- the fist: a palm, four knuckles across the front, a thumb
			local facing = CFrame.lookAt(fistPos, fistPos + (fistPos - mid).Unit)
			d.fist.palm.Size = Vector3.one * fistSize
			d.fist.palm.CFrame = facing
			for k, knuckle in ipairs(d.fist.knuckles) do
				knuckle.Size = Vector3.one * fistSize * 0.42
				knuckle.CFrame = facing * CFrame.new((k - 2.5) * fistSize * 0.22, fistSize * 0.18, -fistSize * 0.42)
			end
			d.fist.thumb.Size = Vector3.new(fistSize * 0.3, fistSize * 0.3, fistSize * 0.5)
			d.fist.thumb.CFrame = facing * CFrame.new(-fistSize * 0.45, -fistSize * 0.1, -fistSize * 0.2)
		end
		-- 3. the slam: a starburst, a dome of light, and rings that bounce like rubber
		if not d.landed and u > skill.impact then
			d.landed = true
			local at = K.target(e, skill.forward)
			Fx.burst(at + Vector3.new(0, 1, 0), { WHITE, skill.colors[2], Color3.fromRGB(255, 250, 220) }, 12, 16)
			K.swell(at + Vector3.new(0, 1, 0), WHITE, 3, 18, 0.45, 0.35)
			for i = 0, 2 do
				local ring = K.part(Enum.PartType.Cylinder, Vector3.new(0.4, 2, 2), CFrame.new(at + Vector3.new(0, 0.3 + i * 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), i == 1 and skill.colors[2] or WHITE, nil, 0.15)
				local size = skill.radius * (1.2 + i * 0.55)
				K.tween(ring, 0.7, { Size = Vector3.new(0.4, size, size) }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, i * 0.06)
				K.tween(ring, 0.35, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.55 + i * 0.06)
				Debris:AddItem(ring, 1.1)
			end
			K.smoke(at + Vector3.new(0, 0.5, 0), 22, WHITE, 3, 16)
			Fx.cubes(at + Vector3.new(0, 1, 0), { Color3.fromRGB(235, 240, 250), Color3.fromRGB(190, 196, 214), skill.colors[2] }, { spread = 12, size = 0.8, life = 0.7, count = 22, up = 1, material = Enum.Material.SmoothPlastic })
			K.sparks(at + Vector3.new(0, 1, 0), 30, skill.colors[2], 26)
			K.word(at + Vector3.new(0, 7, 0), "BOING!!", { WHITE, skill.colors[2] }, 1.4)
			Audio.play("SkillCrash", e.root, 0.6)
			Audio.play("SkillDrum", e.root, 0.55)
			if e.isMe then
				FishingFeel.shake(0.4, 0.35)
				MotionBus.kick = { at = os.clock(), amount = 8, length = 0.4 }
			end
		end
	end,
}

FX.Boundless = { -- a dome of endless void; red and blue merge into a violet core that's fired and detonates
	start = function(e)
		local d = e.data
		d.floor = K.ground(e.root.Position).Y
		-- a sigil of turning rings on the ground
		d.sigils = { K.ringParts(28, Color3.fromRGB(120, 200, 255), 0.18, 0.1), K.ringParts(36, Color3.fromRGB(200, 230, 255), 0.12, 0.25) }
		for _, ring in ipairs(d.sigils) do
			for _, p in ipairs(ring.parts) do
				table.insert(e.cleanup, p)
			end
		end
		-- wisps of blue light spiralling up around you
		d.wisps = {}
		for i = 1, 6 do
			local w = K.part(Enum.PartType.Ball, Vector3.one * 0.5, CFrame.new(e.root.Position), Color3.fromRGB(150, 210, 255), nil, 0)
			K.trail(w, { Color3.fromRGB(180, 230, 255), Color3.fromRGB(60, 120, 255) }, 0.35, 0.25)
			d.wisps[i] = w
			table.insert(e.cleanup, w)
		end
		Audio.play("SkillCast", e.root, 0.5)
	end,
	step = function(e, u, skill)
		local d = e.data
		local cf = e.root.CFrame
		local center = e.root.Position
		local floorCf = CFrame.new(center.X, d.floor + 0.15, center.Z)
		local R = skill.radius
		-- 1. the sigil and the wisps (fading as the dome rises)
		local sig = math.clamp(u / 0.35, 0, 1) * (1 - math.clamp((u - 1.4) / 0.3, 0, 1))
		d.sigils[1].place(floorCf, 4.2 * sig + 0.01, u * 1.5)
		d.sigils[2].place(floorCf, 6.4 * sig + 0.01, -u * 1.1)
		for k, ring in ipairs(d.sigils) do
			for _, p in ipairs(ring.parts) do
				p.Transparency = sig < 0.03 and 1 or (k == 1 and 0.1 or 0.25)
			end
		end
		for i, w in ipairs(d.wisps) do
			local a = u * 5 + i * TAU / #d.wisps
			local h = ((u * 0.8 + i / #d.wisps) % 1) * 5 - 2.5
			w.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 2.6, h, math.sin(a) * 2.6))
			w.Transparency = math.clamp((u - 0.9) / 0.3, 0, 1)
		end
		-- 2. the void: a shimmering dome closes over everything, full of drifting stars and racing light
		if not d.dome and u > 0.85 then
			d.dome = K.part(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(center), Color3.fromRGB(80, 140, 255), Enum.Material.ForceField, 0)
			d.inner = K.part(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(center), Color3.fromRGB(8, 12, 36), Enum.Material.Glass, 0.45)
			K.tween(d.dome, 0.6, { Size = Vector3.one * R * 2 }, Enum.EasingStyle.Quart)
			K.tween(d.inner, 0.6, { Size = Vector3.one * R * 1.96 }, Enum.EasingStyle.Quart)
			d.stars = K.part(Enum.PartType.Ball, Vector3.one * R * 1.8, CFrame.new(center), WHITE, nil, 1)
			K.emitter(d.stars, {
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 210, 255)),
				LightEmission = 1,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0) }),
				Lifetime = NumberRange.new(1, 1.8),
				Speed = NumberRange.new(0, 0.5),
				Rate = 260,
			})
			d.streaks = K.part(nil, Vector3.new(R * 1.6, R * 0.8, R * 1.6), CFrame.new(center + Vector3.new(0, R * 0.2, 0)), WHITE, nil, 1)
			K.emitter(d.streaks, {
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				EmissionDirection = Enum.NormalId.Right,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 200, 255)),
				LightEmission = 1,
				Size = NumberSequence.new(0.12),
				Squash = NumberSequence.new(4),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(60, 100),
				SpreadAngle = Vector2.new(0, 4),
				Rate = 70,
			})
			d.orbits = { K.ringParts(48, Color3.fromRGB(140, 200, 255), 0.25, 0.2), K.ringParts(48, Color3.fromRGB(200, 160, 255), 0.18, 0.3), K.ringParts(48, WHITE, 0.12, 0.4) }
			for _, inst in ipairs({ d.dome, d.inner, d.stars, d.streaks }) do
				table.insert(e.cleanup, inst)
			end
			for _, ring in ipairs(d.orbits) do
				for _, p in ipairs(ring.parts) do
					table.insert(e.cleanup, p)
				end
			end
			K.ring(floorCf.Position, skill.colors[1], R, 0.6, 0.6)
			K.sparks(center, 30, skill.colors[1], 30)
			Audio.play("SkillZap", e.root, 0.4)
		end
		if d.dome and not d.collapsed then
			local grow = 1 - (1 - math.clamp((u - 0.85) / 0.6, 0, 1)) ^ 3
			local tilts = { CFrame.Angles(0, 0, 0.35), CFrame.Angles(0.5, 0, -0.25), CFrame.Angles(-0.3, 0, 0.6) }
			for i, ring in ipairs(d.orbits) do
				ring.place(CFrame.new(center) * tilts[i], R * (0.94 - i * 0.07) * grow + 0.01, u * (0.6 + i * 0.25) * ((i % 2 == 0) and -1 or 1))
			end
			-- inside the void the world goes dark (on your screen, if you're in it)
			local camera = workspace.CurrentCamera
			local inside = camera and (camera.CFrame.Position - center).Magnitude < R * grow
			if inside and not d.grade then
				d.grade = Instance.new("ColorCorrectionEffect")
				d.grade.Name = "TideboundVoidGrade"
				d.grade.Parent = Lighting
				K.tween(d.grade, 0.35, { Brightness = -0.12, Contrast = 0.2, Saturation = -0.2, TintColor = Color3.fromRGB(190, 210, 255) })
				table.insert(e.cleanup, d.grade)
			end
		end
		-- 3. red in one hand, blue in the other; they spiral together and merge
		local leftHand = limb(e.character, { "LeftHand", "Left Arm" })
		local rightHand = limb(e.character, { "RightHand", "Right Arm" })
		local front = (cf * CFrame.new(0, 1.6, -3.2)).Position
		if not d.orbs and u > 1.25 then
			d.orbs = {}
			for i, color in ipairs({ Color3.fromRGB(255, 60, 70), Color3.fromRGB(70, 140, 255) }) do
				local orb = K.part(Enum.PartType.Ball, Vector3.one * 0.3, CFrame.new(center), color, nil, 0)
				K.tween(orb, 0.3, { Size = Vector3.one * 1.3 }, Enum.EasingStyle.Back)
				K.light(orb, color, 12, 3)
				K.trail(orb, { color, WHITE }, 0.25, 0.5)
				table.insert(e.cleanup, K.emitter(orb, { Color = ColorSequence.new(color, WHITE), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Rate = 40 }))
				d.orbs[i] = orb
				table.insert(e.cleanup, orb)
			end
		end
		if d.orbs and not d.core then
			for i, orb in ipairs(d.orbs) do
				local hand = (i == 1) and leftHand or rightHand
				local handPos = hand and hand.Position or center
				local a = u * 9 + i * math.pi
				if u < 1.75 then
					orb.CFrame = CFrame.new(handPos + Vector3.new(math.cos(a) * 0.4, 0.3 + math.sin(a) * 0.4, 0))
				else
					local s = math.clamp((u - 1.75) / 0.4, 0, 1)
					local r = 1.8 * (1 - s)
					local spiral = front + cf:VectorToWorldSpace(Vector3.new(math.cos(u * 16 + i * math.pi) * r, math.sin(u * 16 + i * math.pi) * r, 0))
					orb.CFrame = CFrame.new(handPos:Lerp(spiral, math.clamp(s * 3, 0, 1)))
				end
			end
		end
		if d.orbs and not d.core and u > 2.15 then
			-- the merge: a black core in a white ring, wrapped in violet, light shooting out of it
			for _, orb in ipairs(d.orbs) do
				orb.Transparency = 1
			end
			K.swell(front, WHITE, 1, 9, 0.25, 0)
			d.core = K.part(Enum.PartType.Ball, Vector3.one * 2.2, CFrame.new(front), Color3.fromRGB(4, 2, 8), Enum.Material.SmoothPlastic, 0)
			d.aura = K.part(Enum.PartType.Ball, Vector3.one * 3.6, CFrame.new(front), Color3.fromRGB(190, 90, 255), nil, 0.4)
			K.light(d.aura, Color3.fromRGB(200, 120, 255), 22, 4)
			K.trail(d.aura, { Color3.fromRGB(220, 150, 255), Color3.fromRGB(80, 40, 160) }, 0.4, 1.4)
			d.halo = K.ringParts(26, WHITE, 0.32, 0)
			for _, inst in ipairs({ d.core, d.aura }) do
				table.insert(e.cleanup, inst)
			end
			for _, p in ipairs(d.halo.parts) do
				table.insert(e.cleanup, p)
			end
			local RAYS = { Color3.fromRGB(255, 80, 130), Color3.fromRGB(90, 150, 255), Color3.fromRGB(220, 100, 255), WHITE }
			local camera = workspace.CurrentCamera
			local toCam = camera and (camera.CFrame.Position - front).Unit or cf.LookVector
			local plane = CFrame.lookAt(front, front + toCam)
			for i = 1, 22 do
				local a = i / 22 * TAU + rng:NextNumber(-0.1, 0.1)
				local dir = plane:VectorToWorldSpace(Vector3.new(math.cos(a), math.sin(a), 0))
				local len = rng:NextNumber(8, 16)
				local ray = K.part(nil, Vector3.new(0.14, 0.14, 1), CFrame.lookAt(front + dir * 2, front + dir * 3), RAYS[(i % #RAYS) + 1], nil, 0.05)
				K.tween(ray, 0.3, { Size = Vector3.new(0.1, 0.1, len), CFrame = CFrame.lookAt(front + dir * (2 + len / 2), front + dir * (3 + len)) }, Enum.EasingStyle.Quart)
				K.fade(ray, 0.25, 0.25)
			end
			Audio.play("SkillZap", e.root, 0.35)
		end
		if d.core and not d.fired then
			local pos = front
			if u > 2.25 then
				-- fired: it rushes forward, scorching a line in the ground
				local s = math.clamp((u - 2.25) / (skill.impact - 2.25), 0, 1)
				local target = K.target(e, skill.forward) + Vector3.new(0, 2, 0)
				pos = front:Lerp(target, s * s)
				if os.clock() > (d.scorchAt or 0) then
					d.scorchAt = os.clock() + 0.02
					local below = K.ground(pos)
					local scorch = K.part(nil, Vector3.new(2.2, 0.08, 2.2), CFrame.new(below + Vector3.new(0, 0.05, 0)), Color3.fromRGB(70, 30, 110), nil, 0.2)
					K.tween(scorch, 1.2, { Transparency = 1, Color = Color3.fromRGB(20, 10, 30) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.4)
					Debris:AddItem(scorch, 1.7)
				end
			end
			local pulse = 1 + 0.08 * math.sin(u * 40)
			d.core.CFrame = CFrame.new(pos)
			d.aura.CFrame = CFrame.new(pos)
			d.aura.Size = Vector3.one * 3.6 * pulse
			local camera = workspace.CurrentCamera
			local toCam = camera and (camera.CFrame.Position - pos).Unit or cf.LookVector
			d.halo.place(CFrame.lookAt(pos, pos + toCam) * CFrame.Angles(math.rad(90), 0, 0), 1.55 * pulse, u * 3)
			if os.clock() > (d.arcAt or 0) then
				d.arcAt = os.clock() + 0.06
				local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
				K.bolt(pos, pos + dir * rng:NextNumber(2.5, 4.5), Color3.fromRGB(230, 170, 255), 0.18)
			end
		end
		-- 4. the blast: a white flash, a violet sphere, a pillar of light, rings, lightning; the void shatters
		if not d.fired and u > skill.impact then
			d.fired = true
			local at = K.target(e, skill.forward) + Vector3.new(0, 2, 0)
			for _, inst in ipairs({ d.core, d.aura }) do
				if inst then
					inst.Transparency = 1
				end
			end
			if d.halo then
				for _, p in ipairs(d.halo.parts) do
					p.Transparency = 1
				end
			end
			K.swell(at, WHITE, 2, 18, 0.3, 0)
			K.swell(at, skill.colors[2], 3, R * 1.4, 0.9, 0.25)
			K.swell(at, Color3.fromRGB(255, 160, 255), 2, R * 0.9, 0.6, 0.1)
			K.swell(at, Color3.fromRGB(120, 60, 200), 2, R * 1.2, 1, 0.5, Enum.Material.ForceField)
			local pillar = K.part(Enum.PartType.Cylinder, Vector3.new(80, 2, 2), CFrame.new(at + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(220, 160, 255), nil, 0.15)
			K.tween(pillar, 0.5, { Size = Vector3.new(80, 16, 16) }, Enum.EasingStyle.Quart)
			K.fade(pillar, 0.6, 0.25)
			local ground = K.ground(at)
			for i = 0, 3 do
				task.delay(i * 0.07, function()
					K.ring(ground + Vector3.new(0, 0.3, 0), (i % 2 == 0) and skill.colors[2] or WHITE, R * (0.45 + i * 0.25), 0.7, 0.7)
				end)
			end
			for _ = 1, 10 do
				local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
				K.bolt(at, at + dir * rng:NextNumber(10, 18), Color3.fromRGB(230, 170, 255), 0.35)
			end
			K.sparks(at, 50, skill.colors[2], 36)
			K.sparks(at, 30, WHITE, 28)
			K.smoke(ground + Vector3.new(0, 0.5, 0), 20, Color3.fromRGB(150, 100, 220), 4, 18)
			Fx.cubes(at, { skill.colors[2], WHITE, Color3.fromRGB(90, 60, 160) }, { spread = 18, size = 0.8, life = 0.9, count = 26, up = 1 })
			Audio.play("SkillCrash", e.root, 0.45)
			Audio.play("SkillZap", e.root, 0.4)
			if e.isMe then
				FishingFeel.shake(0.7, 0.5)
				MotionBus.kick = { at = os.clock(), amount = 12, length = 0.5 }
			end
			-- the void shatters: the rings fly apart, the dome fades, the light comes back
			d.collapsed = true
			if d.orbits then
				for _, ring in ipairs(d.orbits) do
					for _, p in ipairs(ring.parts) do
						local out = (p.Position - center)
						out = out.Magnitude > 0.1 and out.Unit or Vector3.new(0, 1, 0)
						K.tween(p, 0.6, { CFrame = p.CFrame + out * rng:NextNumber(6, 14), Transparency = 1 }, Enum.EasingStyle.Quart)
					end
				end
			end
			for _, inst in ipairs({ d.dome, d.inner }) do
				if inst then
					K.tween(inst, 0.5, { Transparency = 1, Size = inst.Size * 1.08 })
				end
			end
			for _, holder in ipairs({ d.stars, d.streaks }) do
				local emitterInst = holder and holder:FindFirstChildOfClass("ParticleEmitter")
				if emitterInst then
					emitterInst.Enabled = false
				end
			end
			if d.grade then
				K.tween(d.grade, 0.5, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE })
			end
		end
	end,
}

-- Patch 22: camera paths for the remade ultimates (root space: -Z is in front of you)
local CAMERA = {
	Boundless = {
		{ 0, Vector3.new(1.4, 1.9, -4.6), Vector3.new(0, 1.7, 0), 52 }, -- close on the hand sign
		{ 0.85, Vector3.new(1.0, 1.8, -3.9), Vector3.new(0, 1.7, 0), 46 },
		{ 1.35, Vector3.new(0, 16, 26), Vector3.new(0, 1, 0), 70 }, -- pulled up high as the void closes over everything
		{ 1.7, Vector3.new(7, 3, -5), Vector3.new(0, 1.7, -2.5), 58 }, -- the side, for red and blue
		{ 2.2, Vector3.new(5, 2.6, -7.5), Vector3.new(0, 1.7, -3.2), 54 }, -- on the violet core
	},
	SunRubber = {
		{ 0, Vector3.new(2.2, 0.6, -7.5), Vector3.new(0, 2.4, 0), 62 }, -- low, looking up as you laugh to the drums
		{ 1.25, Vector3.new(-2.4, 0.9, -6.5), Vector3.new(0, 2.6, 0), 58 },
		{ 1.6, Vector3.new(4.5, 3.4, 6.5), Vector3.new(0, 2, -9), 66 }, -- over the shoulder as the arm flies back
	},
}

-- the Thief's Tome: the book opens, a page tears out with the stolen ability's name, then that ability plays
FX.ThiefTome = {
	start = function(e)
		local d = e.data
		local hand = e.character:FindFirstChild("LeftHand") or e.character:FindFirstChild("Left Arm") or e.root
		d.hand = hand
		d.cover = K.part(nil, Vector3.new(1.6, 2, 0.3), hand.CFrame, Color3.fromRGB(70, 34, 110), Enum.Material.SmoothPlastic, 0)
		d.pages = K.part(nil, Vector3.new(1.4, 1.8, 0.25), hand.CFrame, Color3.fromRGB(246, 238, 220), Enum.Material.SmoothPlastic, 0)
		d.light = K.part(nil, Vector3.new(1, 1, 0.05), hand.CFrame, e.skill.colors[1], nil, 0.2)
		for _, p in ipairs({ d.cover, d.pages, d.light }) do
			table.insert(e.cleanup, p)
		end
		Audio.play("SkillCast", e.root, 1.2)
	end,
	step = function(e, u, skill)
		local d = e.data
		if u < skill.cut then
			local cf = d.hand.CFrame * CFrame.new(0, -0.4, -1.2) * CFrame.Angles(math.rad(-60), 0, 0)
			d.cover.CFrame = cf
			d.pages.CFrame = cf * CFrame.new(0, 0, -0.2)
			d.light.CFrame = cf * CFrame.new(0, 0, -0.36)
			d.light.Transparency = 0.2 + 0.2 * math.sin(u * 20)
			if os.clock() > (d.flip or 0) then
				d.flip = os.clock() + 0.08
				local page = K.part(nil, Vector3.new(0.7, 1.7, 0.03), cf * CFrame.new(0.35, 0, -0.3), WHITE, Enum.Material.SmoothPlastic, 0)
				K.tween(page, 0.18, { CFrame = cf * CFrame.new(-0.35, 0, -0.3) * CFrame.Angles(0, math.pi, 0), Transparency = 1 })
				Debris:AddItem(page, 0.2)
			end
		elseif not d.torn then
			d.torn = true
			local stolen = RodSkills.list[e.alt]
			if stolen then
				K.word(d.hand.Position + Vector3.new(0, 3, 0), "STOLEN: " .. stolen.name, { Color3.fromRGB(255, 255, 255), skill.colors[1] }, 0.85)
			end
			K.sparks(d.cover.Position, 18, skill.colors[1], 14)
			for _, p in ipairs({ d.cover, d.pages, d.light }) do
				K.fade(p, 0.3, 0, 0.5)
			end
		end
		-- then the stolen ability itself, on its own clock (skipping its cinematic)
		local stolen = e.alt and RodSkills.list[e.alt]
		local fx = stolen and FX[e.alt]
		if fx and u >= skill.cut then
			local su = u - skill.cut + stolen.cut
			e.sub = e.sub or { owner = e.owner, character = e.character, root = e.root, rod = e.alt, isMe = e.isMe, data = {}, cleanup = e.cleanup, skill = stolen }
			if not e.subStarted then
				e.subStarted = true
				if fx.start then
					fx.start(e.sub)
				end
			end
			fx.step(e.sub, su, stolen)
		end
	end,
}

-- Running casts -------------------------------------------------------------------------------------------------

local running = {} -- [character] = e

local function finish(e)
	for _, inst in ipairs(e.cleanup) do
		if inst:IsA("ParticleEmitter") then
			inst.Enabled = false
			Debris:AddItem(inst, 1.2)
		elseif inst.Parent then
			inst:Destroy()
		end
	end
	e.cleanup = {}
end

local function startCast(owner, character, rod, alt, roll, start)
	local old = running[character]
	if old then
		finish(old)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local skill = RodSkills.list[rod]
	if not root or not skill then
		return
	end
	local length = RodSkills.timing(rod, alt)
	local e = { owner = owner, character = character, root = root, rod = rod, alt = alt, roll = roll, start = start, length = length, isMe = owner == player, data = {}, cleanup = {}, skill = skill, fx = FX[rod] }
	running[character] = e
	if skill.cut == 0 then
		-- a quick ability: a burst at your feet and its name over your head
		K.ring(K.ground(root.Position) + Vector3.new(0, 0.2, 0), skill.colors[1], 5, 0.35, 0.3)
		K.word(root.Position + Vector3.new(0, 5, 0), skill.name, { WHITE, skill.colors[1] }, 0.75)
		Audio.play("SkillCast", root, rng:NextNumber(0.95, 1.1))
	end
	if e.fx and e.fx.start then
		e.fx.start(e)
	end
end

-- Your screen: the cinematic --------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TideboundSkills"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 25
gui.Parent = player:WaitForChild("PlayerGui")

local UI = {}
local function frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = props.Parent or gui
	return f
end
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = parent
	return c
end
UI.top = frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0.13, 0), Position = UDim2.new(0, 0, -0.13, 0), ZIndex = 20 })
UI.bottom = frame({ BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0.13, 0), Position = UDim2.new(0, 0, 1, 0), ZIndex = 20 })
UI.flash = frame({ BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 })
UI.art = frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Visible = false })
UI.title = Instance.new("TextLabel")
UI.title.BackgroundTransparency = 1
UI.title.AnchorPoint = Vector2.new(0.5, 1)
UI.title.Position = UDim2.new(0.5, 0, 0.955, 0)
UI.title.Size = UDim2.new(0.7, 0, 0.075, 0)
UI.title.Font = Enum.Font.GothamBlack
UI.title.TextScaled = true
UI.title.TextColor3 = WHITE
UI.title.TextTransparency = 1
UI.title.ZIndex = 25
UI.title.Parent = gui
UI.titleStroke = Instance.new("UIStroke")
UI.titleStroke.Thickness = 3
UI.titleStroke.Transparency = 1
UI.titleStroke.Parent = UI.title
UI.sub = Instance.new("TextLabel")
UI.sub.BackgroundTransparency = 1
UI.sub.AnchorPoint = Vector2.new(0.5, 1)
UI.sub.Position = UDim2.new(0.5, 0, 0.985, 0)
UI.sub.Size = UDim2.new(0.4, 0, 0.026, 0)
UI.sub.Font = Enum.Font.GothamBold
UI.sub.TextScaled = true
UI.sub.TextColor3 = Color3.fromRGB(220, 220, 230)
UI.sub.TextTransparency = 1
UI.sub.ZIndex = 25
UI.sub.Parent = gui

local function clearArt()
	UI.art:ClearAllChildren()
	UI.art.Visible = false
end

-- screen art for each ultimate, built when the cinematic starts; returns update(u) or nil
local ART = {}

ART.CrimsonCrow = function(skill)
	-- a crimson spiral eye that opens across the screen, three commas turning in it
	local eye = frame({ Parent = UI.art, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = Color3.fromRGB(190, 10, 30), BackgroundTransparency = 0.05, ZIndex = 11 })
	corner(eye)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = Color3.fromRGB(20, 4, 8)
	stroke.Parent = eye
	local ringInner = frame({ Parent = eye, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundTransparency = 1, ZIndex = 12 })
	corner(ringInner)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Thickness = 4
	ringStroke.Color = Color3.fromRGB(60, 6, 14)
	ringStroke.Parent = ringInner
	local pupil = frame({ Parent = eye, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = Color3.fromRGB(14, 2, 6), ZIndex = 13 })
	corner(pupil)
	local spin = frame({ Parent = eye, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 13 })
	for i = 0, 2 do
		local a = i * TAU / 3
		local comma = frame({ Parent = spin, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + math.cos(a) * 0.31, 0.5 + math.sin(a) * 0.31), Size = UDim2.fromScale(0.13, 0.13), BackgroundColor3 = Color3.fromRGB(14, 2, 6), ZIndex = 13 })
		corner(comma)
		local tail = frame({ Parent = comma, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.75, 0.5), Size = UDim2.fromScale(0.35, 0.8), Rotation = math.deg(a) + 40, BackgroundColor3 = Color3.fromRGB(14, 2, 6), ZIndex = 13 })
		corner(tail)
	end
	UI.art.Visible = true
	return function(u)
		local open = math.clamp((u - 0.3) / 0.35, 0, 1)
		local close = math.clamp((u - 1.05) / 0.2, 0, 1)
		local size = 0.9 * (1 - (1 - open) ^ 3) * (1 - close)
		eye.Size = UDim2.fromScale(size, size)
		spin.Rotation = u * 220
		eye.BackgroundTransparency = 0.05 + 0.95 * close
	end
end

ART.Jackpot = function(skill, roll)
	-- three reels spin, stop one by one: 7 7 7 on a jackpot
	local SYMBOLS = { "🍒", "💎", "🐟", "⭐", "🔔", "7" }
	local box = frame({ Parent = UI.art, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.5, 0.24), BackgroundColor3 = Color3.fromRGB(40, 20, 10), BackgroundTransparency = 0.1, ZIndex = 11 })
	corner(box, UDim.new(0.12, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(255, 210, 70)
	stroke.Parent = box
	local reels = {}
	local finals = {}
	if roll == 1 then
		finals = { "7", "7", "7" }
	else
		finals = { "7", "7", SYMBOLS[rng:NextInteger(1, 5)] }
	end
	for i = 1, 3 do
		local cell = frame({ Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.2 + (i - 1) * 0.3, 0.5), Size = UDim2.fromScale(0.26, 0.8), BackgroundColor3 = Color3.fromRGB(250, 246, 236), ZIndex = 12 })
		corner(cell, UDim.new(0.15, 0))
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(220, 30, 40)
		label.ZIndex = 13
		label.Parent = cell
		reels[i] = { label = label, stopAt = 0.75 + (i - 1) * 0.25, stopped = false }
	end
	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.62)
	result.Size = UDim2.fromScale(0.6, 0.1)
	result.Font = Enum.Font.LuckiestGuy
	result.TextScaled = true
	result.TextTransparency = 1
	result.ZIndex = 14
	result.Parent = UI.art
	local rStroke = Instance.new("UIStroke")
	rStroke.Thickness = 4
	rStroke.Transparency = 1
	rStroke.Parent = result
	UI.art.Visible = true
	return function(u)
		for i, reel in ipairs(reels) do
			if u < reel.stopAt then
				reel.label.Text = SYMBOLS[(math.floor(u * 22) + i * 2) % #SYMBOLS + 1]
				reel.label.Position = UDim2.fromScale(0, ((u * 22) % 1) * 0.3 - 0.15)
			elseif not reel.stopped then
				reel.stopped = true
				reel.label.Text = finals[i]
				reel.label.Position = UDim2.fromScale(0, 0)
				Audio.play("SkillCoins", nil, 0.8 + i * 0.1)
			end
		end
		if u > 1.3 and result.TextTransparency == 1 then
			result.Text = roll == 1 and "JACKPOT!!" or "SO CLOSE..."
			result.TextColor3 = roll == 1 and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(220, 220, 220)
			result.TextTransparency = 0
			rStroke.Transparency = 0
			if roll == 1 then
				UI.flash.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
				UI.flash.BackgroundTransparency = 0.3
				K.tween(UI.flash, 0.4, { BackgroundTransparency = 1 })
			end
		end
	end
end

ART.ThiefTome = function(skill, roll, alt)
	-- a parchment card with the stolen ability's name
	local stolen = alt and RodSkills.list[alt]
	local card = frame({ Parent = UI.art, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.34, 0.16), BackgroundColor3 = Color3.fromRGB(246, 236, 214), BackgroundTransparency = 1, ZIndex = 11 })
	corner(card, UDim.new(0.08, 0))
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.9, 0.7)
	text.Position = UDim2.fromScale(0.05, 0.15)
	text.Font = Enum.Font.Antique
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(70, 34, 110)
	text.TextTransparency = 1
	text.Text = stolen and ("Page " .. rng:NextInteger(2, 99) .. ": " .. stolen.name) or "..."
	text.ZIndex = 12
	text.Parent = card
	UI.art.Visible = true
	return function(u)
		local show = math.clamp((u - 0.5) / 0.2, 0, 1) * (1 - math.clamp((u - 1.05) / 0.15, 0, 1))
		card.BackgroundTransparency = 1 - show
		text.TextTransparency = 1 - show
		card.Rotation = (1 - show) * 8
	end
end

local cine = { active = false }

-- the camera: in front of you, pushing in on your face, then pulling back wide as the ability goes off
local function cameraFor(root, u, cut)
	local s = u / cut
	local cf = root.CFrame
	local function at(x, y, z)
		return (cf * CFrame.new(x, y, z)).Position
	end
	local face = at(0, 1.6, 0)
	if s < 0.65 then
		local k = math.clamp(s / 0.65, 0, 1)
		local from = at(2.6, 2.0, -7.5):Lerp(at(1.2, 1.8, -4.4), 1 - (1 - k) ^ 2)
		return CFrame.lookAt(from, face), 60 - 10 * k
	end
	local k = math.clamp((s - 0.65) / 0.35, 0, 1)
	local e2 = 1 - (1 - k) ^ 3
	local from = at(1.2, 1.8, -4.4):Lerp(at(9, 7, 13), e2)
	local look = face:Lerp(at(0, 1, -6), e2)
	return CFrame.lookAt(from, look), 50 + 25 * e2
end

local function playCinematic(skill, rod, alt, roll, start)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not root or not humanoid or not camera or cine.active then
		return
	end
	cine.active = true
	local hud = player.PlayerGui:FindFirstChild("TideboundUI")
	local hudOn = hud and hud.Enabled
	if hud then
		hud.Enabled = false
	end
	MotionBus.cutscene = true
	pcall(function()
		ProximityPromptService.Enabled = false
	end)
	local savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	-- the colour grade
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "TideboundSkillGrade"
	grade.Parent = Lighting
	local tint = skill.colors[1]:Lerp(WHITE, 0.55)
	K.tween(grade, 0.3, { Saturation = -0.25, Contrast = 0.25, TintColor = tint })
	-- letterbox and the name
	K.tween(UI.top, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quart)
	K.tween(UI.bottom, 0.3, { Position = UDim2.new(0, 0, 0.87, 0) }, Enum.EasingStyle.Quart)
	UI.title.Text = skill.name
	UI.sub.Text = skill.sub:upper()
	UI.titleStroke.Color = skill.colors[1]:Lerp(Color3.new(0, 0, 0), 0.6)
	K.tween(UI.title, 0.35, { TextTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.25)
	K.tween(UI.titleStroke, 0.35, { Transparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.25)
	K.tween(UI.sub, 0.35, { TextTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.35)
	local art = ART[rod] and ART[rod](skill, roll, alt)
	Audio.play("SkillCast", root, 0.6)

	RunService:BindToRenderStep("TideboundSkillCamera", Enum.RenderPriority.Camera.Value + 10, function()
		local u = os.clock() - start
		if not root.Parent then
			return
		end
		local cf, fov
		if CAMERA[rod] then
			cf, fov = K.keyCam(root, u, CAMERA[rod])
		else
			cf, fov = cameraFor(root, u, skill.cut)
		end
		local shake = u > skill.cut * 0.6 and 0.08 or 0
		camera.CFrame = cf * CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		camera.FieldOfView = fov
		if art then
			art(u)
		end
	end)

	task.delay(skill.cut, function()
		RunService:UnbindFromRenderStep("TideboundSkillCamera")
		K.tween(UI.top, 0.25, { Position = UDim2.new(0, 0, -0.13, 0) })
		K.tween(UI.bottom, 0.25, { Position = UDim2.new(0, 0, 1, 0) })
		K.tween(UI.title, 0.3, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
		K.tween(UI.titleStroke, 0.3, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
		K.tween(UI.sub, 0.3, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.3)
		K.tween(grade, 0.4, { Saturation = 0, Contrast = 0, TintColor = WHITE })
		Debris:AddItem(grade, 0.45)
		clearArt()
		camera.FieldOfView = savedFov
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
		pcall(function()
			ProximityPromptService.Enabled = true
		end)
		if hud and hudOn then
			hud.Enabled = true
		end
		MotionBus.cutscene = false
		MotionBus.kick = { at = os.clock(), amount = 10, length = 0.5 }
		cine.active = false
	end)
end

-- Your ability: the pill, the key, the request ------------------------------------------------------------------

-- HUD restyle (12 Oct 2026): the side buttons' blue tile look (gradient, light outline, rounded corners); the white
-- cooldown fill still sweeps across it.
UI.pill = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.new(0, 230, 0, 30), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 5 })
corner(UI.pill, UDim.new(0, 10))
local pillGradient = Instance.new("UIGradient")
pillGradient.Rotation = 90
pillGradient.Color = ColorSequence.new(Color3.fromRGB(40, 140, 255), Color3.fromRGB(18, 76, 214))
pillGradient.Parent = UI.pill
UI.pillFill = frame({ Parent = UI.pill, Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.82, ZIndex = 5 })
corner(UI.pillFill, UDim.new(0, 10))
UI.pillText = Instance.new("TextLabel")
UI.pillText.BackgroundTransparency = 1
UI.pillText.Size = UDim2.fromScale(1, 1)
UI.pillText.Font = Enum.Font.FredokaOne
UI.pillText.TextSize = 16
UI.pillText.TextColor3 = WHITE
UI.pillText.ZIndex = 6
UI.pillText.Parent = UI.pill
local pillTextStroke = Instance.new("UIStroke")
pillTextStroke.Color = Color3.fromRGB(26, 4, 10)
pillTextStroke.Thickness = 2
pillTextStroke.Parent = UI.pillText
local pillStroke = Instance.new("UIStroke")
pillStroke.Thickness = 2.5
pillStroke.Transparency = 0
pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pillStroke.Parent = UI.pill

local me = { readyAt = 0, cooldown = 1, busy = false }

local function myRod()
	local character = player.Character
	local rod = character and character:FindFirstChild("TideboundRod")
	return rod and rod:GetAttribute("RodId") or nil
end

local function cast()
	if me.busy or cine.active or MotionBus.cutscene or FishingFeel.phase ~= "" or os.clock() < me.readyAt then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	me.busy = true
	local ok, result = pcall(Request.InvokeServer, Request, "UseSkill")
	me.busy = false
	if not ok or type(result) ~= "table" then
		return
	end
	if result.error then
		Fx.alert(character:FindFirstChild("Head") or humanoid, "!", Color3.fromRGB(120, 120, 130), 0.6, 2.6)
		return
	end
	local skill = RodSkills.list[result.rod]
	if not skill then
		return
	end
	local start = os.clock()
	me.readyAt = start + (result.cooldown or skill.cooldown)
	me.cooldown = result.cooldown or skill.cooldown
	MotionBus.skill[character] = { start = start, rod = result.rod, alt = result.alt }
	startCast(player, character, result.rod, result.alt, result.roll, start)
	if skill.cut > 0 then
		playCinematic(skill, result.rod, result.alt, result.roll, start)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
		task.spawn(cast)
	end
end)
if UserInputService.TouchEnabled then
	ContextActionService:BindAction("TideboundSkill", function(_, state)
		if state == Enum.UserInputState.Begin then
			task.spawn(cast)
		end
		return Enum.ContextActionResult.Sink
	end, true)
	ContextActionService:SetTitle("TideboundSkill", "SKILL")
	ContextActionService:SetPosition("TideboundSkill", UDim2.new(1, -320, 1, -160))
end

-- A Rod Trial finished: a card slides in with the new rod, confetti, and a flash
task.spawn(function()
	local cueEvent = Remotes:WaitForChild("Cue")
	cueEvent.OnClientEvent:Connect(function(name, payload)
		if name ~= "RodUnlocked" or type(payload) ~= "table" then
			return
		end
		local rod = Config.RodsById[payload.rod]
		local skill = RodSkills.list[payload.rod]
		if not rod or not skill then
			return
		end
		local card = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, -0.2), Size = UDim2.fromScale(0.42, 0.16), BackgroundColor3 = Color3.fromRGB(14, 16, 28), BackgroundTransparency = 0.1, ZIndex = 40 })
		corner(card, UDim.new(0.12, 0))
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = skill.colors[1]
		stroke.Parent = card
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.Size = UDim2.fromScale(1, 0.35)
		head.Position = UDim2.fromScale(0, 0.08)
		head.Font = Enum.Font.GothamBold
		head.TextScaled = true
		head.TextColor3 = Color3.fromRGB(220, 220, 230)
		head.Text = "ROD TRIAL COMPLETE"
		head.ZIndex = 41
		head.Parent = card
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.fromScale(0.9, 0.45)
		nameLabel.Position = UDim2.fromScale(0.05, 0.45)
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = skill.colors[1]:Lerp(WHITE, 0.4)
		nameLabel.Text = rod.name:upper() .. "  ·  " .. skill.name
		nameLabel.ZIndex = 41
		nameLabel.Parent = card
		K.tween(card, 0.45, { Position = UDim2.fromScale(0.5, 0.25) }, Enum.EasingStyle.Back)
		UI.flash.BackgroundColor3 = skill.colors[1]
		UI.flash.BackgroundTransparency = 0.5
		K.tween(UI.flash, 0.5, { BackgroundTransparency = 1 })
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			Fx.confetti(root.Position + Vector3.new(0, 4, 0), 40, 8)
		end
		task.delay(3.5, function()
			K.tween(card, 0.35, { Position = UDim2.fromScale(0.5, -0.2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(card, 0.4)
		end)
	end)
end)

-- Every frame: start everyone else's casts from their attributes, run all the effects, update the pill ----------

local seen = {}
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if p ~= player and character then
			local at = character:GetAttribute("SkillAt")
			local root = character:FindFirstChild("HumanoidRootPart")
			if at and seen[character] ~= at and root then
				seen[character] = at
				local rod = character:GetAttribute("SkillRod")
				local alt = character:GetAttribute("SkillAlt")
				local age = serverNow - at
				if rod and age >= 0 and age < RodSkills.timing(rod, alt) and (root.Position - eye).Magnitude < FX_RANGE then
					startCast(p, character, rod, alt, character:GetAttribute("SkillRoll"), now - age)
				end
			end
		end
	end
	for character, e in pairs(running) do
		local u = now - e.start
		if not character.Parent or not e.root.Parent or u > e.length + 0.3 then
			finish(e)
			running[character] = nil
		elseif e.fx and e.fx.step then
			local ok, err = pcall(e.fx.step, e, u, e.skill)
			if not ok then
				warn("[TideboundSkills]", err)
				finish(e)
				running[character] = nil
			end
		end
	end
	-- the pill: your rod's ability and its cooldown
	local rod = myRod()
	local skill = rod and RodSkills.list[rod]
	UI.pill.Visible = skill ~= nil
	if skill then
		local left = me.readyAt - now
		if left > 0 then
			UI.pillText.Text = ("R · %s · %.1fs"):format(skill.name, left)
			UI.pillFill.Size = UDim2.new(1 - left / math.max(me.cooldown, 0.1), 0, 1, 0)
			pillStroke.Color = Color3.fromRGB(140, 140, 150)
		else
			UI.pillText.Text = ("R · %s"):format(skill.name)
			UI.pillFill.Size = UDim2.new(1, 0, 1, 0)
			pillStroke.Color = skill.colors[1]
		end
	end
end)
