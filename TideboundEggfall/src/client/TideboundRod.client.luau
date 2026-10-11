-- Tidebound: Eggfall: the rod in motion (Master Patches 5 and 7), for every player on your screen.
-- Until the animator's ids are pasted into Animations.luau, this script works out the arm pose for each step
-- (TideboundMotion applies it to the shoulder, elbow and waist joints through MotionBus), bends the rod, draws the
-- spring line to the bobber and plays each rod's sounds and effects. Once an id is filled in, that step
-- plays the animation instead and this script only bends the rod and draws the line.
-- Your own cast follows FishingFeel (the reel minigame in TideboundClient); other players' casts follow the
-- attributes the server puts on their characters (FishPhase, FishAt, FishBite, FishSpot, FishName, FishTier).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Animations = require(Shared:WaitForChild("Animations"))
local RodModels = require(Shared:WaitForChild("RodModels"))
local FishModels = require(Shared:WaitForChild("FishModels"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local Audio = require(Shared:WaitForChild("Audio"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local Fx = require(Shared:WaitForChild("Fx"))

local player = Players.LocalPlayer
local REVEAL = Config.Reveal

-- effects made here exist only on this screen
local fx = Instance.new("Folder")
fx.Name = "TideboundRodFX"
fx.Parent = workspace

-- Patch 5 timing at 60 fps: windup 18, release 12, landing 24, bite tell 8, hook set 10, struggle loop 45,
-- break 15, flip 30 at half speed, hold 20.
local T = {
	windup = 18 / 60,
	release = 12 / 60,
	landing = 24 / 60,
	tell = 8 / 60,
	hook = 10 / 60,
	struggle = 45 / 60,
	snap = 15 / 60,
	flip = 1.0,
	hold = 20 / 60,
	idle = 3,
	fly = { 0.35, 0.75 }, -- the bobber leaves the tip at 0.35 s and lands at 0.75 s
}
local CAST_END = T.windup + T.release + T.landing

-- Joint angles in radians. Shoulders and elbows swing forward with +, the waist leans back with +, `inR`
-- and `inL` tilt the arms in toward the body. With the grip in Rods.luau, the rod's angle above level is
-- (right shoulder + right elbow) - 40 degrees, so `rest` holds it at the 30 degrees Cast-Landing ends on.
local POSE = {
	rest = { shR = 0.35, elR = 0.87, shL = 0.5, elL = 1.1, waist = 0, inR = -0.12, inL = 0.32 },
	windup = { shR = 2.6, elR = 0.5, shL = 0.3, elL = 0.6, waist = 0.12, inR = -0.05, inL = 0.2 },
	release = { shR = 0.5, elR = 0.4, shL = 0.6, elL = 0.9, waist = -0.1, inR = -0.12, inL = 0.3 },
	hook = { shR = 1.05, elR = 1.0, shL = 0.7, elL = 1.2, waist = 0.1, inR = -0.12, inL = 0.32 },
	struggle = { shR = 0.9, elR = 0.95, shL = 0.65, elL = 1.25, waist = 0.14, inR = -0.12, inL = 0.34 },
	pulled = { shR = 0.3, elR = 0.5, shL = 0.4, elL = 0.9, waist = -0.15, inR = -0.12, inL = 0.3 },
	stumble = { shR = 0.6, elR = 0.6, shL = 0.4, elL = 0.6, waist = 0.25, inR = -0.2, inL = 0.2 },
	flip = { shR = 1.6, elR = 0.9, shL = 1.0, elL = 0.9, waist = 0.1, inR = -0.12, inL = 0.3 },
	hold = { shR = 1.3, elR = 0.5, shL = 1.3, elL = 0.5, waist = 0.05, inR = -0.25, inL = 0.25 },
}

local function lerpPose(a, b, s)
	local out = {}
	for key, value in pairs(a) do
		out[key] = value + (b[key] - value) * s
	end
	return out
end

local function smooth(s)
	s = math.clamp(s, 0, 1)
	return s * s * (3 - 2 * s)
end

local function easeOut(s)
	s = math.clamp(s, 0, 1)
	return 1 - (1 - s) * (1 - s)
end

-- Which Patch 5 step is playing. `biteAt` is nil for your own cast (the minigame says when it bites).
local function stepOf(phase, t, biteAt)
	if phase == "cast" then
		if t < T.windup then
			return "CastWindup", t
		elseif t < T.windup + T.release then
			return "CastRelease", t - T.windup
		elseif t < CAST_END then
			return "CastLanding", t - T.windup - T.release
		elseif not biteAt or t < biteAt then
			return "IdleFishing", t - CAST_END
		end
		local b = t - biteAt
		if b < T.tell then
			return "BiteTell", b
		elseif b < T.tell + T.hook then
			return "HookSet", b - T.tell
		end
		return "ReelStruggle", b - T.tell - T.hook
	elseif phase == "bite" then
		if t < T.tell then
			return "BiteTell", t
		end
		return "HookSet", t - T.tell
	elseif phase == "reel" then
		return "ReelStruggle", t
	elseif phase == "land" then
		if t < T.flip then
			return "LandFlip", t
		end
		return "LandHold", t - T.flip
	elseif phase == "break" then
		return "ReelBreak", t
	end
	return nil, 0
end

-- The arm pose and the rod's BendValue for a step, `u` seconds in.
local function poseOf(step, u, tension)
	if step == "CastWindup" then
		return lerpPose(POSE.rest, POSE.windup, smooth(u / T.windup)), 0.15
	elseif step == "CastRelease" then
		local s = easeOut(u / T.release)
		return lerpPose(POSE.windup, POSE.release, s), 0.3 * (1 - s)
	elseif step == "CastLanding" then
		return lerpPose(POSE.release, POSE.rest, smooth(u / T.landing)), 0
	elseif step == "IdleFishing" then
		-- gentle 3 degree sway, and a hand adjust two seconds into each loop (frame 120)
		local loop = u % T.idle
		local pose = table.clone(POSE.rest)
		pose.shR += math.rad(3) * math.sin(u * 2.1)
		pose.waist += math.rad(1.5) * math.sin(u * 1.3)
		if loop > 2 and loop < 2.3 then
			pose.elR += 0.12 * math.sin((loop - 2) / 0.3 * math.pi)
		end
		return pose, 0.05 + 0.02 * math.sin(u * 2.1)
	elseif step == "BiteTell" then
		-- the tip twitches twice
		return POSE.rest, 0.05 + 0.15 * math.abs(math.sin(u / T.tell * math.pi * 2))
	elseif step == "HookSet" then
		return lerpPose(POSE.rest, POSE.hook, easeOut(u / T.hook)), 0.4
	elseif step == "ReelStruggle" then
		-- one crank of the left arm per loop, a lean back, and a rod that bends harder as the fish pulls
		local a = (u % T.struggle) / T.struggle * math.pi * 2
		local pose = lerpPose(POSE.hook, POSE.struggle, smooth(u / 0.2))
		pose.shL += 0.15 * math.sin(a)
		pose.elL += 0.25 * math.cos(a)
		pose.shR += 0.06 * tension * math.sin(u * 13)
		pose.waist += 0.04 * tension
		return pose, 0.6 + 0.3 * tension
	elseif step == "ReelBreak" then
		-- the fish pulls hard, the line snaps, the rod springs straight and you stumble back
		local s = u / T.snap
		if s < 0.4 then
			return lerpPose(POSE.struggle, POSE.pulled, smooth(s / 0.4)), 1
		end
		return lerpPose(POSE.pulled, POSE.stumble, easeOut((s - 0.4) / 0.6)), math.max(0, 1 - (s - 0.4) * 6)
	elseif step == "LandFlip" then
		return lerpPose(POSE.struggle, POSE.flip, easeOut(u / 0.3)), 0.5 * (1 - u / T.flip)
	elseif step == "LandHold" then
		return lerpPose(POSE.flip, POSE.hold, smooth(u / T.hold)), 0
	end
	return POSE.rest, 0
end

-- Effects ---------------------------------------------------------------------------------------------

local function emitter(props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	for key, value in pairs(props) do
		(e :: any)[key] = value
	end
	return e
end

-- A one-off particle burst at a world position.
local function burst(position, count, props)
	local holder = Instance.new("Part")
	holder.Name = "Burst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = fx
	local e = emitter(props)
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, 3)
	return holder
end

local WATER = ColorSequence.new(Color3.fromRGB(230, 250, 255), Color3.fromRGB(150, 220, 245))

local function waterBurst(position, count, speed)
	burst(position, count, {
		Color = WATER,
		Size = NumberSequence.new(0.3, 0.08),
		Transparency = NumberSequence.new(0.1, 0.8),
		Speed = NumberRange.new(speed * 0.6, speed),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -32, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		LightEmission = 0.3,
	})
end

-- a flat ring that spreads out on the water and fades
local function splashRing(position, size)
	local ring = Instance.new("Part")
	ring.Name = "SplashRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(230, 250, 255)
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.05, 0.4, 0.4)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fx
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, size, size), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.8)
end

-- Patch 7: each rod's cast effect. Dust, coral, static and shadow fire on the release; the rift crack and
-- the aurora burst open where the bobber lands.
local CAST_FX = {}

function CAST_FX.Dust(rec)
	local root = rec.character:FindFirstChild("HumanoidRootPart")
	if root then
		burst(root.Position - Vector3.new(0, 2.6, 0), 14, {
			Color = ColorSequence.new(Color3.fromRGB(214, 196, 160), Color3.fromRGB(170, 150, 120)),
			Size = NumberSequence.new(0.6, 1.6),
			Transparency = NumberSequence.new(0.35, 1),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(80, 80),
			EmissionDirection = Enum.NormalId.Top,
			Lifetime = NumberRange.new(0.6, 1),
			Drag = 3,
		})
	end
end

function CAST_FX.Coral(_rec, tipPos)
	burst(tipPos, 18, {
		Color = ColorSequence.new(Color3.fromRGB(255, 140, 180), Color3.fromRGB(255, 220, 200)),
		Size = NumberSequence.new(0.25, 0),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.4, 0.8),
		LightEmission = 1,
	})
end

function CAST_FX.Static(rec, tipPos)
	local reel = rec.rod and rec.rod:FindFirstChild("Reel")
	local at = reel and reel.Position or tipPos
	burst(at, 24, {
		Color = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(74, 160, 255)),
		Size = NumberSequence.new(0.14, 0),
		Speed = NumberRange.new(10, 16),
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.1, 0.25),
		LightEmission = 1,
	})
	local holder = burst(tipPos, 16, {
		Color = ColorSequence.new(Color3.fromRGB(150, 210, 255)),
		Size = NumberSequence.new(0.1, 0),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.1, 0.2),
		LightEmission = 1,
	})
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(120, 190, 255)
	flash.Brightness = 4
	flash.Range = 12
	flash.Parent = holder
	TweenService:Create(flash, TweenInfo.new(0.25), { Brightness = 0 }):Play()
end

function CAST_FX.Shadow(_rec, tipPos)
	burst(tipPos, 16, {
		Color = ColorSequence.new(Color3.fromRGB(26, 14, 44), Color3.fromRGB(110, 60, 170)),
		Size = NumberSequence.new(0.8, 2.4),
		Transparency = NumberSequence.new(0.2, 1),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.8, 1.2),
		Drag = 2,
	})
end

function CAST_FX.Rift(_rec, _tipPos, spot)
	-- a jagged crack of light on the water that closes again
	local last = spot + Vector3.new(-2.2, 0.08, 0)
	for i = 1, 4 do
		local nextPoint = spot + Vector3.new(-2.2 + i * 1.1, 0.08, (i % 2 == 0 and -0.5 or 0.5))
		local crack = Instance.new("Part")
		crack.Name = "RiftCrack"
		crack.Anchored = true
		crack.CanCollide = false
		crack.CanQuery = false
		crack.CanTouch = false
		crack.Material = Enum.Material.Neon
		crack.Color = Color3.fromRGB(210, 170, 255)
		crack.Size = Vector3.new(0.12, 0.05, (nextPoint - last).Magnitude)
		crack.CFrame = CFrame.lookAt((last + nextPoint) / 2, nextPoint)
		crack.Parent = fx
		TweenService:Create(crack, TweenInfo.new(0.9), { Transparency = 1 }):Play()
		Debris:AddItem(crack, 1)
		last = nextPoint
	end
	burst(spot, 24, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 140, 255)),
		Size = NumberSequence.new(0.2, 0),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(0.5, 1),
		LightEmission = 1,
	})
end

function CAST_FX.Aurora(_rec, _tipPos, spot)
	burst(spot, 32, {
		Color = RodModels.RAINBOW,
		Size = NumberSequence.new(1.4, 3.2),
		Transparency = NumberSequence.new(0.45, 1),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(1.2, 1.8),
		LightEmission = 1,
		Drag = 1,
	})
end

local AT_LANDING = { Rift = true, Aurora = true }

-- Per-character state -----------------------------------------------------------------------------------

local rigs = {} -- [Player] = record

local function clearVisuals(rec)
	if rec.bobber then
		rec.bobber:Destroy()
		rec.bobber = nil
	end
	rec.beam = nil
	if rec.fish then
		rec.fish:Destroy()
		rec.fish = nil
	end
	if rec.trail then
		rec.trail.Enabled = false
	end
end

local function lineColor(look)
	if typeof(look.line) == "ColorSequence" then
		return look.line
	end
	return ColorSequence.new(look.line)
end

local function ensureLine(rec, look, rodId)
	if rec.bobber or not rec.rod then
		return
	end
	local tipAttachment = rec.rod:FindFirstChild("LineAttachment", true)
	if not tipAttachment then
		return
	end
	local bobber = RodModels.bobber(rodId)
	bobber.Parent = fx
	local beam = Instance.new("Beam")
	beam.Name = "Line"
	beam.Attachment0 = tipAttachment
	beam.Attachment1 = bobber.PrimaryPart:FindFirstChild("LineAttachment")
	beam.Color = lineColor(look)
	beam.LightEmission = look.aurora and 1 or 0.25
	beam.Width0 = 0.05
	beam.Width1 = 0.05
	beam.Segments = 16
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.05)
	beam.Parent = bobber
	rec.bobber, rec.beam, rec.tipAttachment = bobber, beam, tipAttachment
	rec.slack, rec.slackVel = 0, 0
end

-- Plays an animator's track for your own character once its id is filled in (Animations.luau).
local trackCache = {}
local function playStep(rec, step)
	if rec.player ~= player or rec.trackStep == step then
		return
	end
	if rec.track then
		rec.track:Stop(0.1)
		rec.track = nil
	end
	rec.trackStep = step
	local spec = step and Animations[step]
	if not spec or spec.id == "" then
		return
	end
	local humanoid = rec.character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	trackCache[animator] = trackCache[animator] or {}
	local track = trackCache[animator][step]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = spec.id
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if not ok or not loaded then
			return
		end
		track = loaded
		track.Looped = spec.loop == true
		track.Priority = Enum.AnimationPriority.Action
		trackCache[animator][step] = track
	end
	track:Play(0.1, 1, spec.speed or 1)
	rec.track = track
end

-- What a character is doing right now: phase, seconds into it, when it bites, and a key per cast (so each
-- one-shot sound and effect fires once per cast).
local function stateOf(p, character)
	if p == player then
		if FishingFeel.phase == "" then
			return "", 0, nil, ""
		end
		local cast = FishingFeel.cast
		return FishingFeel.phase, FishingFeel.elapsed(), nil, cast and tostring(cast.id) or "local"
	end
	local phase = character:GetAttribute("FishPhase") or ""
	if phase == "" then
		return "", 0, nil, ""
	end
	local at = character:GetAttribute("FishAt") or 0
	local bite = math.max(character:GetAttribute("FishBite") or 3, CAST_END)
	return phase, workspace:GetServerTimeNow() - at, bite, phase .. at
end

local function spotOf(rec)
	if rec.player == player then
		local cast = FishingFeel.cast
		return cast and typeof(cast.spot) == "Vector3" and cast.spot or nil
	end
	local spot = rec.character:GetAttribute("FishSpot")
	return typeof(spot) == "Vector3" and spot or nil
end

-- The landed fish: its name, tier, and when it takes its colour (when the reveal's climb reaches it).
local function catchOf(rec)
	if rec.player == player then
		local result = FishingFeel.result
		if not result then
			return nil
		end
		local climb = REVEAL.landSeconds + REVEAL.silhouette + result.tier * REVEAL.step + (result.nearMiss and REVEAL.nearMissHold + REVEAL.nearMissDrain or 0)
		return result.fish, result.tier, FishingFeel.startedAt + climb, os.clock()
	end
	local name = rec.character:GetAttribute("FishName")
	if not name or name == "" then
		return nil
	end
	return name, rec.character:GetAttribute("FishTier") or 1, rec.character:GetAttribute("FishShowAt") or 0, workspace:GetServerTimeNow()
end

local function once(rec, key)
	if rec.fired[key] then
		return false
	end
	rec.fired[key] = true
	return true
end

-- Poses (published to MotionBus every frame, before physics) ---------------------------------------------

RunService.Stepped:Connect(function(_, dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local rec = rigs[p]
		if character and (not rec or rec.character ~= character) then
			if rec then
				clearVisuals(rec)
			end
			if rec then
				MotionBus.arms[rec.character] = nil
			end
			rec = { player = p, character = character, weight = 0, fired = {}, key = "", pose = POSE.rest, bend = 0, tension = 0 }
			rigs[p] = rec
		end
		if rec and character then
			local phase, t, biteAt, key = stateOf(p, character)
			if key ~= rec.key then
				rec.key = key
				rec.fired = {}
			end
			rec.phase, rec.t, rec.biteAt = phase, t, biteAt
			rec.rod = character:FindFirstChild("TideboundRod")
			if phase ~= "" then
				local step, u = stepOf(phase, t, biteAt)
				local target = p == player and FishingFeel.tension or (0.5 + 0.5 * math.sin(t * 1.7) * math.sin(t * 0.9))
				rec.tension += (target - rec.tension) * math.min(1, dt * 6)
				rec.step, rec.u = step, u
				rec.pose, rec.bend = poseOf(step, u, rec.tension)
				rec.weight = math.min(1, rec.weight + dt / 0.12)
				playStep(rec, step)
			else
				rec.step = nil
				rec.weight = math.max(0, rec.weight - dt / 0.25)
				rec.bend = 0
				playStep(rec, nil)
			end
			-- TideboundMotion poses the arms from this (it owns every joint, both joint types)
			local animated = rec.step and Animations[rec.step] and Animations[rec.step].id ~= ""
			if rec.weight > 0 and not animated then
				MotionBus.arms[character] = { weight = rec.weight, pose = rec.pose }
			else
				MotionBus.arms[character] = nil
			end
			if rec.rod and (rec.weight > 0 or rec.bent) then
				RodModels.setBend(rec.rod, rec.bend)
				rec.bent = rec.weight > 0
			end
		end
	end
	for p, rec in pairs(rigs) do
		if not p.Parent then
			clearVisuals(rec)
			MotionBus.arms[rec.character] = nil
			rigs[p] = nil
		end
	end
end)

-- Line, bobber, fish and effects (every frame, after the rod has moved) -----------------------------------

local function updateCast(rec, look, rodId, spot, tipPos)
	local step, t, u = rec.step, rec.t, rec.u
	ensureLine(rec, look, rodId)
	if not rec.bobber then
		return
	end
	-- the trail runs for the whip
	local trail = rec.rod and rec.rod:FindFirstChild("CastTrail", true)
	rec.trail = trail
	if trail then
		trail.Enabled = step == "CastWindup" and u > T.windup * 0.5 or step == "CastRelease"
	end
	if step == "CastWindup" and once(rec, "windup") then
		Audio.play("CastWindup", rec.rod.PrimaryPart)
	elseif step == "CastRelease" and once(rec, "release") then
		if rec.player == player then
			FishingFeel.kickUntil = os.clock() + 6 / 60
		end
		Audio.play(look.castSound, rec.rod.PrimaryPart)
		local effect = CAST_FX[look.castFx]
		if effect and not AT_LANDING[look.castFx] then
			effect(rec, tipPos, spot)
		end
	end
	-- where the bobber is
	local slackTarget = 0
	local position
	local bobT = rec.phase == "cast" and t or math.huge
	if bobT < T.fly[1] then
		position = tipPos - Vector3.new(0, 0.7, 0)
	elseif bobT < T.fly[2] then
		local s = (bobT - T.fly[1]) / (T.fly[2] - T.fly[1])
		local height = 3 + (spot - tipPos).Magnitude * 0.15
		position = tipPos:Lerp(spot, s) + Vector3.new(0, height * 4 * s * (1 - s), 0)
		slackTarget = 1
	else
		if once(rec, "plop") then
			Audio.play("Plop", rec.bobber.PrimaryPart)
			splashRing(spot, 3)
			waterBurst(spot, 8, 6)
			local effect = CAST_FX[look.castFx]
			if effect and AT_LANDING[look.castFx] then
				effect(rec, tipPos, spot)
			end
		end
		local clock = os.clock()
		position = spot + Vector3.new(0, 0.1 + 0.15 * math.sin(clock * 2.4), 0)
		slackTarget = 2.5
		if step == "BiteTell" then
			if once(rec, "tell") then
				Audio.play("TickTick", rec.bobber.PrimaryPart)
				-- the video's bite alert: a red "!" pops over the bobber
				Fx.alert(rec.bobber.PrimaryPart, "!", Color3.fromRGB(255, 64, 64), 0.7, 2)
			end
			position -= Vector3.new(0, 0.3 * math.abs(math.sin(u / T.tell * math.pi * 2)), 0)
			slackTarget = 0.4
		elseif step == "HookSet" or step == "ReelStruggle" then
			if step == "HookSet" and once(rec, "hook") then
				Audio.play("Snap", rec.bobber.PrimaryPart)
				splashRing(spot, 2)
				if rec.player == player then
					FishingFeel.shake(0.15, 0.15)
				end
			end
			-- under the surface, dragged around by the fish
			local root = rec.character:FindFirstChild("HumanoidRootPart")
			local side = root and root.CFrame.RightVector or Vector3.new(1, 0, 0)
			position = spot + side * (math.sin(clock * 3.1) * 0.6 + math.sin(clock * 7.3) * 0.25 * rec.tension) - Vector3.new(0, 0.35, 0)
			slackTarget = 0
			if step == "ReelStruggle" then
				local loop = math.floor(u / T.struggle)
				if once(rec, "loop" .. loop) then
					Audio.play("ReelClick", rec.rod.PrimaryPart)
					waterBurst(position + Vector3.new(0, 0.35, 0), 6, 5 + 4 * rec.tension)
				end
			end
		end
	end
	rec.bobber:PivotTo(CFrame.new(position))
	-- the spring line: whips on release, sags while waiting, snaps taut on the bite
	local dt = math.clamp(os.clock() - (rec.lastLine or os.clock()), 0, 0.1)
	rec.lastLine = os.clock()
	rec.slackVel += ((slackTarget - rec.slack) * 90 - rec.slackVel * 9) * dt
	rec.slack += rec.slackVel * dt
	if rec.tipAttachment then
		rec.tipAttachment.WorldAxis = Vector3.new(0, -1, 0)
	end
	rec.beam.CurveSize0 = math.max(0, rec.slack)
end

local function handsOf(character)
	local right = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local left = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if right and left then
		return (right.Position + left.Position) / 2
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and (root.CFrame * CFrame.new(0, 1, -2)).Position or nil
end

local function updateLand(rec, spot)
	local character = rec.character
	local root = character:FindFirstChild("HumanoidRootPart")
	local name, tier, showAt, clock = catchOf(rec)
	if rec.bobber then
		rec.bobber:Destroy()
		rec.bobber, rec.beam = nil, nil
	end
	if not root or not name then
		return
	end
	if not rec.fish then
		rec.fish = FishModels.build(name, tier)
		rec.fish.Parent = fx
		rec.painted = false
	end
	if once(rec, "flip") and spot then
		Audio.play("Splash", root)
		waterBurst(spot, 30, 14)
		splashRing(spot, 5)
		-- the video's chunky splash: water cubes fly out where the fish breaks the surface
		Fx.cubes(spot, { Color3.fromRGB(120, 220, 255), Color3.fromRGB(220, 250, 255) }, { spread = 6, size = 0.6, life = 0.6, up = 1, count = 14, material = Enum.Material.SmoothPlastic })
	end
	local hands = handsOf(character)
	if not hands then
		return
	end
	local held = CFrame.lookAt(hands + Vector3.new(0, 0.35, 0), hands + Vector3.new(0, 0.35, 0) + root.CFrame.RightVector)
	if rec.step == "LandFlip" and spot then
		-- the fish arcs out of the water, flips twice and drops into your hands (Patch 5, half speed)
		local s = math.clamp(rec.u / T.flip, 0, 1)
		local start = spot - Vector3.new(0, 0.4, 0)
		local height = 4 + (hands - start).Magnitude * 0.2
		local position = start:Lerp(held.Position, s) + Vector3.new(0, height * 4 * s * (1 - s), 0)
		local spin = CFrame.lookAt(position, position + (held.Position - start).Unit) * CFrame.Angles(s * math.pi * 4, 0, 0)
		rec.fish:PivotTo(s > 0.8 and spin:Lerp(held, (s - 0.8) / 0.2) or spin)
	else
		if once(rec, "hold") then
			Audio.play("Fanfare", root)
			burst(hands + Vector3.new(0, 0.6, 0), 14, {
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Size = NumberSequence.new(0.25, 0),
				Speed = NumberRange.new(3, 6),
				SpreadAngle = Vector2.new(180, 180),
				Lifetime = NumberRange.new(0.4, 0.8),
				LightEmission = 1,
			})
			Fx.stars(hands + Vector3.new(0, 0.6, 0), 5)
		end
		rec.fish:PivotTo(held)
	end
	-- dark silhouette until the reveal's climb reaches the fish's tier, then its colour
	if clock >= showAt then
		local color = Config.Tiers[tier] and Config.Tiers[tier].color or Color3.new(1, 1, 1)
		if once(rec, "colour") then
			-- the catch pops in its tier's colour: cubes, a ring, and gold bolts from Epic up
			Fx.cubes(hands, { color, color:Lerp(Color3.new(1, 1, 1), 0.5) }, { spread = 4 + tier, size = 0.5, life = 0.7, up = 0.8, count = 8 + tier * 3 })
			Fx.ring(hands - Vector3.new(0, 1.5, 0), color, 4 + tier, 0.5, 0.25)
			if tier >= 4 then
				Fx.bolts(hands, 3 + tier)
			end
		end
		if tier >= #Config.Tiers then
			FishModels.paint(rec.fish, Color3.fromHSV((os.clock() * 0.4) % 1, 0.4, 1):Lerp(color, 0.35), Enum.Material.Neon)
		elseif not rec.painted then
			FishModels.paint(rec.fish, color, tier >= 5 and Enum.Material.Neon or nil)
			rec.painted = true
		end
	end
end

local function updateBreak(rec, tipPos)
	if once(rec, "snap") then
		Audio.play("Crack", rec.rod and rec.rod.PrimaryPart or nil)
		if rec.player == player then
			FishingFeel.shake(0.3, 0.25)
		end
		-- the line whips away
		burst(tipPos, 10, {
			Color = lineColor(RodModels.looks[rec.rod and rec.rod:GetAttribute("RodId") or "Drift"] or RodModels.looks.Drift),
			Size = NumberSequence.new(0.12, 0),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(40, 40),
			Lifetime = NumberRange.new(0.2, 0.4),
			LightEmission = 0.6,
		})
		if rec.bobber then
			local at = rec.bobber.PrimaryPart.Position
			splashRing(at, 2)
		end
	end
	clearVisuals(rec)
end

-- Ambient rod looks on every rod in view: the Abyssal pulse, the aurora colours, Celestial halos and the
-- Riftcaster's floating crystal.
local rodInfo = setmetatable({}, { __mode = "k" })
local function ambient(model, clock)
	local info = rodInfo[model]
	if not info then
		local look = RodModels.looks[model:GetAttribute("RodId") or ""]
		info = { look = look, glows = RodModels.glows(model), motors = {}, phase = math.random() * 10 }
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") and (d.Name:match("^RodHalo") or d.Name:match("^RodFloat")) then
				table.insert(info.motors, d)
			end
		end
		rodInfo[model] = info
	end
	local look = info.look
	if not look then
		return
	end
	local c = clock + info.phase
	if look.aurora then
		RodModels.tint(info.glows, Color3.fromHSV((c * 0.15) % 1, model:GetAttribute("RodId") == "Celestial" and 0.3 or 0.55, 1))
	elseif look.pulse then
		local breathe = 0.5 + 0.5 * math.sin(c * 2.2)
		RodModels.tint(info.glows, look.glow:Lerp(Color3.fromRGB(20, 8, 34), 0.65 * (1 - breathe)), 0.4 + 1.4 * breathe)
	end
	for i, motor in ipairs(info.motors) do
		if motor.Name == "RodHalo" then
			motor.Transform = CFrame.Angles(0, c * 1.6, 0)
		elseif motor.Name == "RodHalo2" then
			motor.Transform = CFrame.Angles(0, -c * 2.1, 0)
		else
			motor.Transform = CFrame.new(0, 0.12 * math.sin(c * 2 + i), 0) * CFrame.Angles(0, c * (0.8 + i * 0.25), 0)
		end
	end
end

RunService.RenderStepped:Connect(function()
	for _, rec in pairs(rigs) do
		if rec.phase and rec.phase ~= "" and rec.rod and rec.rod.Parent then
			local rodId = rec.rod:GetAttribute("RodId") or "Drift"
			local look = RodModels.looks[rodId] or RodModels.looks.Drift
			local tip = rec.rod:FindFirstChild("Tip")
			local tipPos = tip and (tip.CFrame * CFrame.new(0, RodModels.TIP / 2, 0)).Position or rec.rod.PrimaryPart.Position
			local spot = spotOf(rec)
			if rec.phase == "land" then
				updateLand(rec, spot)
			elseif rec.phase == "break" then
				updateBreak(rec, tipPos)
			elseif spot then
				updateCast(rec, look, rodId, spot, tipPos)
			end
		elseif rec.bobber or rec.fish then
			clearVisuals(rec)
		end
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local clock = os.clock()
	for _, model in ipairs(CollectionService:GetTagged("TideboundRod")) do
		local handle = model:IsA("Model") and model.PrimaryPart
		if handle and (handle.Position - eye).Magnitude < 160 then
			ambient(model, clock)
		end
	end
end)
