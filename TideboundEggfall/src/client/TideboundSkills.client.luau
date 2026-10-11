-- Tidebound: Eggfall: rod abilities (Patch 21). R (Y on a gamepad, SKILL on touch) casts your rod's ability
-- (RodSkills). The server checks it and lands the hit; this script plays it: for everyone, the ability's effects
-- in the world (from the SkillRod / SkillAlt / SkillRoll / SkillAt attributes); for you, the trial rods' short
-- cinematic first (the camera takes over, letterbox bars, a colour grade, the ability's name across the bottom
-- and its own screen art: the crimson eye, the reels, the void, the black hole), and a pill showing the cooldown.
-- Effects stay clean: a few big readable shapes, smooth tweens, light and particles used sparingly.

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

FX.SunRubber = { -- white steam and drum beats, then a giant bouncing fist
	start = function(e)
		local d = e.data
		local torso = e.character:FindFirstChild("UpperTorso") or e.root
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = SMOKE
		steam.Color = ColorSequence.new(WHITE)
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.5) })
		steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		steam.Lifetime = NumberRange.new(0.7, 1.2)
		steam.Speed = NumberRange.new(2, 4)
		steam.SpreadAngle = Vector2.new(180, 180)
		steam.Rate = 30
		steam.Parent = torso
		table.insert(e.cleanup, steam)
		d.glow = Instance.new("Highlight")
		d.glow.FillColor = WHITE
		d.glow.FillTransparency = 0.6
		d.glow.OutlineColor = Color3.fromRGB(255, 240, 180)
		d.glow.Adornee = e.character
		d.glow.Parent = folder
		table.insert(e.cleanup, d.glow)
	end,
	step = function(e, u, skill)
		local d = e.data
		d.beats = d.beats or 0
		local due = math.min(3, math.floor(u / 0.35))
		while d.beats < due do
			d.beats += 1
			K.ring(K.ground(e.root.Position) + Vector3.new(0, 0.3, 0), WHITE, 6 + d.beats * 2, 0.4, 0.5)
			Audio.play("SkillDrum", e.root, 0.9 + d.beats * 0.05)
		end
		if not d.fist and u > skill.impact - 0.18 then
			d.fist = {}
			local hand = e.character:FindFirstChild("RightHand") or e.character:FindFirstChild("Right Arm") or e.root
			d.hand = hand
			d.fist.ball = K.part(Enum.PartType.Ball, Vector3.one * 1, CFrame.new(hand.Position), WHITE, Enum.Material.SmoothPlastic, 0)
			d.fist.arm = K.part(Enum.PartType.Cylinder, Vector3.new(1, 0.8, 0.8), CFrame.new(hand.Position), Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic, 0)
			table.insert(e.cleanup, d.fist.ball)
			table.insert(e.cleanup, d.fist.arm)
			d.fistAt = u
		end
		if d.fist and not d.landed then
			local s = math.clamp((u - d.fistAt) / 0.18, 0, 1)
			local from = d.hand.Position
			local to = K.target(e, skill.forward) + Vector3.new(0, 3, 0)
			local pos = from:Lerp(to, s)
			local size = 1 + 6 * s
			d.fist.ball.Size = Vector3.one * size
			d.fist.ball.CFrame = CFrame.new(pos)
			local len = (pos - from).Magnitude
			d.fist.arm.Size = Vector3.new(math.max(len, 0.5), 0.8 + 1.5 * s, 0.8 + 1.5 * s)
			d.fist.arm.CFrame = CFrame.lookAt((from + pos) / 2, pos) * CFrame.Angles(0, math.rad(90), 0)
			if s >= 1 then
				d.landed = true
				local at = K.target(e, skill.forward)
				for i = 0, 2 do
					task.delay(i * 0.1, function()
						K.ring(at + Vector3.new(0, 0.3, 0), i == 1 and skill.colors[2] or WHITE, skill.radius * (0.6 + i * 0.3), 0.45, 0.6)
					end)
				end
				K.smoke(at + Vector3.new(0, 0.5, 0), 18, WHITE, 3, 14)
				K.word(at + Vector3.new(0, 6, 0), "BOING!!", { Color3.fromRGB(255, 255, 255), skill.colors[2] }, 1.4)
				Audio.play("SkillCrash", e.root, 0.7)
				Audio.play("SkillDrum", e.root, 0.6)
				if e.isMe then
					FishingFeel.shake(0.35, 0.3)
				end
				-- the fist bounces back like rubber
				K.tween(d.fist.ball, 0.25, { Size = Vector3.one * 0.5, CFrame = CFrame.new(from), Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0.12)
				K.tween(d.fist.arm, 0.25, { Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(from), Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0.12)
			end
		end
	end,
}

FX.Boundless = { -- a dome of endless void closes over everyone nearby, then collapses into a violet blast
	step = function(e, u, skill)
		local d = e.data
		local center = e.root.Position
		if not d.dome and u > 0.45 then
			d.dome = K.part(Enum.PartType.Ball, Vector3.one * 4, CFrame.new(center), Color3.fromRGB(30, 60, 160), Enum.Material.ForceField, 0)
			K.tween(d.dome, 0.5, { Size = Vector3.one * skill.radius * 2 }, Enum.EasingStyle.Quart)
			table.insert(e.cleanup, d.dome)
			d.inner = K.part(Enum.PartType.Ball, Vector3.one * 3, CFrame.new(center), Color3.fromRGB(10, 14, 40), Enum.Material.Glass, 0.55)
			K.tween(d.inner, 0.5, { Size = Vector3.one * skill.radius * 1.9 }, Enum.EasingStyle.Quart)
			table.insert(e.cleanup, d.inner)
			K.ring(K.ground(center) + Vector3.new(0, 0.2, 0), skill.colors[1], skill.radius, 0.6, 0.6)
			Audio.play("SkillCast", e.root, 0.5)
		end
		if d.dome and u < skill.impact and rng:NextNumber() < 0.5 then
			-- specks of starlight drifting inside the void
			local a, b = rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 1)
			local p = center + Vector3.new(math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b)) * rng:NextNumber(4, skill.radius * 0.9)
			local speck = K.part(Enum.PartType.Ball, Vector3.one * rng:NextNumber(0.2, 0.5), CFrame.new(p), (rng:NextNumber() < 0.7) and WHITE or skill.colors[1], nil, 0)
			K.fade(speck, 0.8, 0)
		end
		if d.dome and not d.collapsed and u > skill.impact - 0.25 then
			d.collapsed = true
			K.tween(d.dome, 0.25, { Size = Vector3.one * 2, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			K.tween(d.inner, 0.25, { Size = Vector3.one * 2, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		if not d.blast and u > skill.impact then
			d.blast = true
			local at = center + Vector3.new(0, 2, 0)
			K.swell(at, Color3.fromRGB(255, 255, 255), 2, 14, 0.35, 0)
			K.swell(at, skill.colors[2], 3, skill.radius * 1.6, 0.8, 0.25)
			K.swell(at, Color3.fromRGB(255, 150, 255), 2, skill.radius, 0.6, 0.15)
			for i = 0, 3 do
				task.delay(i * 0.08, function()
					K.ring(K.ground(center) + Vector3.new(0, 0.3, 0), (i % 2 == 0) and skill.colors[2] or WHITE, skill.radius * (0.5 + i * 0.25), 0.6, 0.6)
				end)
			end
			for _ = 1, 8 do
				local a = rng:NextNumber(0, TAU)
				K.bolt(at, at + Vector3.new(math.cos(a) * 14, rng:NextNumber(-3, 8), math.sin(a) * 14), Color3.fromRGB(230, 170, 255), 0.35)
			end
			K.sparks(at, 40, skill.colors[2], 34)
			Audio.play("SkillCrash", e.root, 0.5)
			Audio.play("SkillZap", e.root, 0.5)
			if e.isMe then
				FishingFeel.shake(0.6, 0.45)
			end
		end
	end,
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

ART.Boundless = function(skill)
	-- the void: deep blue, streaks of light racing past, splashes of white, a huge eye-like ring; then the
	-- black hole: a black disc in a white ring with lines of light radiating out
	local void = frame({ Parent = UI.art, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 22, 60), BackgroundTransparency = 1, ZIndex = 10 })
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 70, 140), Color3.fromRGB(6, 10, 30))
	grad.Rotation = 20
	grad.Parent = void
	local streaks = {}
	for i = 1, 22 do
		local s = frame({ Parent = void, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(rng:NextNumber(-0.2, 1), rng:NextNumber(0.1, 0.9)), Size = UDim2.new(rng:NextNumber(0.06, 0.2), 0, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, ZIndex = 11 })
		streaks[i] = { frame = s, speed = rng:NextNumber(0.6, 1.6) }
	end
	for _ = 1, 14 do
		local blot = frame({ Parent = void, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.05, 0.45), rng:NextNumber(0.1, 0.8)), Size = UDim2.fromScale(rng:NextNumber(0.02, 0.07), rng:NextNumber(0.03, 0.1)), Rotation = rng:NextNumber(0, 360), BackgroundColor3 = Color3.fromRGB(235, 240, 250), BackgroundTransparency = 0.15, ZIndex = 11 })
		corner(blot, UDim.new(0.4, 0))
	end
	local eyeRing = frame({ Parent = void, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.45), Size = UDim2.fromScale(0.9, 0.9), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1, ZIndex = 11 })
	corner(eyeRing)
	local eyeStroke = Instance.new("UIStroke")
	eyeStroke.Thickness = 40
	eyeStroke.Color = Color3.fromRGB(20, 40, 110)
	eyeStroke.Transparency = 0.2
	eyeStroke.Parent = eyeRing
	-- the black hole
	local hole = frame({ Parent = UI.art, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 14 })
	corner(hole)
	local holeStroke = Instance.new("UIStroke")
	holeStroke.Thickness = 14
	holeStroke.Color = WHITE
	holeStroke.Parent = hole
	local rays = {}
	local RAY_COLORS = { Color3.fromRGB(255, 70, 120), Color3.fromRGB(90, 140, 255), Color3.fromRGB(220, 90, 255), WHITE }
	for i = 1, 28 do
		local r = frame({ Parent = UI.art, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(0, 0, 0, rng:NextInteger(2, 5)), Rotation = i / 28 * 360 + rng:NextNumber(-4, 4), BackgroundColor3 = RAY_COLORS[(i % #RAY_COLORS) + 1], BackgroundTransparency = 1, ZIndex = 13 })
		rays[i] = { frame = r, len = rng:NextNumber(0.5, 0.9) }
	end
	UI.art.Visible = true
	return function(u)
		-- 0.4 .. 1.2: the void
		local inVoid = u > 0.4 and u < 1.25
		void.BackgroundTransparency = inVoid and 0 or 1
		void.Visible = inVoid
		for _, s in ipairs(streaks) do
			local x = (s.frame.Position.X.Scale + s.speed * 0.016) % 1.2 - 0.2
			s.frame.Position = UDim2.fromScale(x, s.frame.Position.Y.Scale)
		end
		-- 1.2 .. 1.8: the black hole grows, rays shoot out
		local h = math.clamp((u - 1.2) / 0.4, 0, 1)
		local size = 0.45 * (1 - (1 - h) ^ 3)
		hole.Size = UDim2.fromScale(size, size)
		hole.Visible = h > 0
		for _, r in ipairs(rays) do
			r.frame.Size = UDim2.new(r.len * h, 0, 0, r.frame.Size.Y.Offset)
			r.frame.BackgroundTransparency = h > 0 and 0.15 or 1
		end
		if u > 1.25 and u < 1.3 then
			UI.flash.BackgroundColor3 = WHITE
			UI.flash.BackgroundTransparency = 0.2
			K.tween(UI.flash, 0.25, { BackgroundTransparency = 1 })
		end
	end
end

ART.SunRubber = function()
	-- white flashes on each drum beat, the screen bouncing
	UI.art.Visible = true
	local beats = 0
	return function(u)
		local due = math.min(3, math.floor(u / 0.35))
		while beats < due do
			beats += 1
			UI.flash.BackgroundColor3 = WHITE
			UI.flash.BackgroundTransparency = 0.45
			K.tween(UI.flash, 0.25, { BackgroundTransparency = 1 })
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
		local cf, fov = cameraFor(root, u, skill.cut)
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

UI.pill = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.new(0, 230, 0, 26), BackgroundColor3 = Color3.fromRGB(16, 20, 32), BackgroundTransparency = 0.25, ZIndex = 5 })
corner(UI.pill)
UI.pillFill = frame({ Parent = UI.pill, Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.82, ZIndex = 5 })
corner(UI.pillFill)
UI.pillText = Instance.new("TextLabel")
UI.pillText.BackgroundTransparency = 1
UI.pillText.Size = UDim2.fromScale(1, 1)
UI.pillText.Font = Enum.Font.GothamBold
UI.pillText.TextSize = 14
UI.pillText.TextColor3 = WHITE
UI.pillText.ZIndex = 6
UI.pillText.Parent = UI.pill
local pillStroke = Instance.new("UIStroke")
pillStroke.Thickness = 1.5
pillStroke.Transparency = 0.5
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
