-- Tidebound: Eggfall: every player's body in motion (Big Update), on your screen, posed in code.
-- Idle (breathing, weight shifts, looking around, fidgets), walk, run and sprint cycles that follow how far
-- you actually move, jumping, falling, landing squash, swimming, getting hurt, being stunned, going down,
-- grabbing an egg, carrying eggs, cheering, and the fishing arms TideboundRod publishes on MotionBus.
-- Patch 10: the fishing body (legs braced, lunging, squatting on the reel), the rod swing and the geyser flip.
-- Effects: footstep puffs (dust, snow, grass or splashes), landing rings, speed trails while sprinting, hit
-- sparks, damage numbers, dizzy stars and the eggs you carry, which everyone can see.
-- It writes each joint's Transform after the default animations every frame (PreSimulation), which works for
-- both joint types (AnimationConstraint and the older Motor6D). Once an animator's id for a state is pasted
-- into Animations.luau, that state is left to the animation instead.
-- The server only sets attributes on the character: HurtAt, HurtAmount, StunUntil, CarryEggs, GrabAt,
-- CheerAt and DownAt (server time), plus the fishing attributes TideboundRod reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Animations = require(Shared:WaitForChild("Animations"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))

local player = Players.LocalPlayer
local rng = Random.new()

local TAU = math.pi * 2
local SPRINT_SPEED = 19 -- above this (walk 16 + sprint 6, minus carried eggs) the run becomes a sprint
local FX_RANGE = 90 -- footstep puffs and trails only for characters this close to the camera
local POSE_RANGE = 260 -- characters further away keep the default animations

-- Joint name, the part it sits in, and the pose keys that drive it
local JOINTS = {
	{ "root", "LowerTorso", "Root" },
	{ "waist", "UpperTorso", "Waist" },
	{ "neck", "Head", "Neck" },
	{ "shR", "RightUpperArm", "RightShoulder" },
	{ "elR", "RightLowerArm", "RightElbow" },
	{ "shL", "LeftUpperArm", "LeftShoulder" },
	{ "elL", "LeftLowerArm", "LeftElbow" },
	{ "hipR", "RightUpperLeg", "RightHip" },
	{ "kneeR", "RightLowerLeg", "RightKnee" },
	{ "ankR", "RightFoot", "RightAnkle" },
	{ "hipL", "LeftUpperLeg", "LeftHip" },
	{ "kneeL", "LeftLowerLeg", "LeftKnee" },
	{ "ankL", "LeftFoot", "LeftAnkle" },
}

local function isJoint(j)
	return j ~= nil and (j:IsA("AnimationConstraint") or j:IsA("Motor6D"))
end

-- The limb a joint moves: a Motor6D's Part1, or the part holding an AnimationConstraint's Attachment1.
local function childPart(j)
	if j:IsA("Motor6D") then
		return j.Part1
	end
	local a1 = j.Attachment1
	return a1 and a1.Parent
end

-- Patch 10: joints are found by name first and, failing that, by the limb they move, so rigs whose joints
-- were renamed or moved (the avatar joint upgrade, some packages) still get every motion.
local function findJoints(character)
	local set = {}
	local all = nil
	for _, spec in ipairs(JOINTS) do
		local p = character:FindFirstChild(spec[2])
		if not p then
			return nil -- R6, a custom rig, or limbs still streaming in
		end
		local j = p:FindFirstChild(spec[3])
		if not isJoint(j) then
			j = nil
			all = all or character:GetDescendants()
			for _, d in ipairs(all) do
				if isJoint(d) and childPart(d) == p then
					j = d
					break
				end
			end
			if not j then
				return nil
			end
		end
		set[spec[1]] = j
	end
	return set
end

local function filled(name)
	local spec = Animations[name]
	return spec ~= nil and spec.id ~= ""
end

-- Poses are flat tables of angles in radians (and rootUp in studs); a missing key is 0.
-- Axes: +X swings a shoulder or hip forward and bends an elbow; knees bend with -X; +X on the waist, neck or
-- root leans back; +Z lifts the right arm (or leg) out to the side and the left one in.
local KEYS = {
	"rootX", "rootY", "rootZ", "rootUp", "waistX", "waistY", "waistZ", "neckX", "neckY", "neckZ",
	"shRX", "shRY", "shRZ", "elRX", "shLX", "shLY", "shLZ", "elLX",
	"hipRX", "hipRZ", "kneeRX", "ankRX", "hipLX", "hipLZ", "kneeLX", "ankLX",
}
local UPPER = { "waistX", "waistY", "waistZ", "shRX", "shRY", "shRZ", "elRX", "shLX", "shLY", "shLZ", "elLX" }
local LOWER = { "rootX", "rootZ", "rootUp", "neckX", "hipRX", "hipRZ", "kneeRX", "ankRX", "hipLX", "hipLZ", "kneeLX", "ankLX" }

local function mix(a, b, w, keys)
	if w <= 0 then
		return a
	end
	for _, k in ipairs(keys or KEYS) do
		local x = a[k] or 0
		a[k] = x + ((b[k] or 0) - x) * w
	end
	return a
end

local function addTo(a, b, w)
	for k, v in pairs(b) do
		a[k] = (a[k] or 0) + v * w
	end
	return a
end

local function smooth(s)
	s = math.clamp(s, 0, 1)
	return s * s * (3 - 2 * s)
end

-- in quickly, hold, out slowly: 0..1 over `length` seconds
local function envelope(t, length, fadeIn, fadeOut)
	if t < 0 or t > length then
		return 0
	end
	return math.min(smooth(t / fadeIn), smooth((length - t) / fadeOut))
end

-- A crouch that keeps the feet under the hips: the hips drop by `drop` studs.
local function crouch(pose, drop, w)
	local a = math.acos(math.clamp(1 - drop / 2, -1, 1))
	pose.rootUp = (pose.rootUp or 0) - drop * w
	pose.hipRX = (pose.hipRX or 0) + a * w
	pose.hipLX = (pose.hipLX or 0) + a * w
	pose.kneeRX = (pose.kneeRX or 0) - 2 * a * w
	pose.kneeLX = (pose.kneeLX or 0) - 2 * a * w
	pose.ankRX = (pose.ankRX or 0) + a * w
	pose.ankLX = (pose.ankLX or 0) + a * w
	pose.waistX = (pose.waistX or 0) - a * 0.35 * w
end

-- States --------------------------------------------------------------------------------------------------

local function idlePose(rec, t)
	local breathe = math.sin(t * TAU * 0.28 + rec.seed)
	local shift = math.sin(t * TAU * 0.09 + rec.seed * 2)
	local look = math.sin(t * 0.37 + rec.seed) * math.sin(t * 0.13 + 1 + rec.seed)
	local p = {
		rootUp = -0.04 + 0.02 * breathe,
		rootZ = 0.035 * shift,
		waistX = 0.035 * breathe,
		waistY = 0.05 * look,
		neckX = -0.02 * breathe + 0.05 * math.sin(t * 0.21 + rec.seed),
		neckY = 0.4 * look,
		shRX = 0.06,
		shRZ = 0.09 + 0.02 * breathe,
		elRX = 0.16 + 0.03 * breathe,
		shLX = 0.06,
		shLZ = -(0.09 + 0.02 * breathe),
		elLX = 0.16 + 0.03 * breathe,
		hipRZ = -0.035 * shift + 0.05,
		hipLZ = -0.035 * shift - 0.05,
		kneeRX = -0.08 - 0.06 * math.max(0, shift),
		kneeLX = -0.08 - 0.06 * math.max(0, -shift),
		ankRX = 0.04,
		ankLX = 0.04,
	}
	-- fidgets after standing still a while
	local f = rec.fidget
	if f then
		local u = t - f.at
		local w = envelope(u, f.length, 0.3, 0.4)
		if w <= 0 and u > f.length then
			rec.fidget = nil
		elseif f.kind == "stretch" then
			mix(p, { shRX = 2.9, shRZ = 0.35, elRX = 0.25, shLX = 2.9, shLZ = -0.35, elLX = 0.25, waistX = 0.18, neckX = 0.25, rootUp = 0.05, hipRZ = 0.05, hipLZ = -0.05 }, w)
		elseif f.kind == "look" then
			p.neckY = (p.neckY or 0) + math.sin(u / f.length * TAU) * 0.9 * w
			p.waistY = (p.waistY or 0) + math.sin(u / f.length * TAU) * 0.25 * w
		elseif f.kind == "shake" then
			local wob = math.sin(u * 26)
			mix(p, { shRZ = 0.45 + 0.25 * wob, shLZ = -(0.45 - 0.25 * wob), elRX = 0.4, elLX = 0.4, neckZ = 0.12 * wob, waistZ = 0.05 * wob }, w)
		elseif f.kind == "hand" then
			mix(p, { shRX = 1.1, shRZ = -0.2, elRX = 1.7, neckX = -0.35, neckY = -0.35, waistY = -0.12 }, w)
		elseif f.kind == "rod" then
			-- pats the rod on your back
			mix(p, { shRX = 2.6, shRZ = 0.5, elRX = 1.9, neckY = 0.5, neckX = -0.1, waistY = 0.15 }, w)
		end
	end
	return p
end

local FIDGETS = { "stretch", "look", "shake", "hand", "rod" }

local function runPose(rec, speed, dirF, dirS, sprint)
	local s = math.clamp(speed / 16, 0, 1.4)
	local phi = rec.phi
	local sinp, cosp = math.sin(phi), math.cos(phi)
	local A = 0.3 + 0.5 * math.min(s, 1) + 0.18 * sprint -- leg swing
	local K = 0.35 + 1.0 * math.min(s, 1) + 0.35 * sprint -- knee lift on the forward swing
	local C = 0.25 + 0.55 * math.min(s, 1) + 0.35 * sprint -- arm swing
	local lean = -(0.06 + 0.14 * math.min(s, 1) + 0.16 * sprint)
	local twist = 0.1 * s
	local fwd = dirF
	local side = dirS
	local p = {
		rootX = lean,
		rootY = twist * sinp * fwd,
		rootZ = rec.turnLean,
		rootUp = (0.1 + 0.18 * s + 0.08 * sprint) * (math.abs(sinp) - 0.55),
		waistY = -2 * twist * sinp * fwd,
		waistX = -0.04 * sprint,
		neckX = -lean * 0.7,
		neckY = twist * sinp * fwd * 0.8,
		shRX = -C * sinp * fwd + 0.1,
		shRZ = 0.12 + 0.1 * sprint,
		elRX = 0.35 + 0.9 * math.min(s, 1) + 0.25 * math.max(0, -sinp) * fwd + 0.2 * sprint,
		shLX = C * sinp * fwd + 0.1,
		shLZ = -(0.12 + 0.1 * sprint),
		elLX = 0.35 + 0.9 * math.min(s, 1) + 0.25 * math.max(0, sinp) * fwd + 0.2 * sprint,
		hipRX = A * sinp * fwd - lean,
		hipLX = -A * sinp * fwd - lean,
		hipRZ = 0.5 * A * sinp * side + 0.03,
		hipLZ = -0.5 * A * sinp * side - 0.03,
		kneeRX = -(0.12 + K * math.max(0, cosp)),
		kneeLX = -(0.12 + K * math.max(0, -cosp)),
		ankRX = 0.25 * sinp * fwd + 0.15 * math.max(0, cosp),
		ankLX = -0.25 * sinp * fwd + 0.15 * math.max(0, -cosp),
	}
	return p
end

local function airPose(rec, t, vy)
	local rising = smooth((vy + 4) / 20)
	local flail = math.sin(t * 15 + rec.seed)
	local up = {
		rootX = -0.05,
		waistX = -0.12,
		neckX = 0.12,
		shRX = 0.7,
		shRZ = 0.75,
		elRX = 0.7,
		shLX = -0.25,
		shLZ = -0.6,
		elLX = 0.5,
		hipRX = 0.85,
		kneeRX = -1.45,
		ankRX = 0.3,
		hipLX = 0.15,
		kneeLX = -0.55,
		ankLX = 0.2,
	}
	local down = {
		rootX = 0.06,
		waistX = 0.12,
		neckX = -0.15,
		shRX = 2.1 + 0.3 * flail,
		shRZ = 0.6,
		elRX = 0.35,
		shLX = 2.0 - 0.3 * flail,
		shLZ = -0.6,
		elLX = 0.35,
		hipRX = 0.35 + 0.1 * flail,
		kneeRX = -0.45,
		ankRX = -0.2,
		hipLX = -0.1 - 0.1 * flail,
		kneeLX = -0.35,
		ankLX = -0.2,
	}
	return mix(down, up, rising)
end

local function swimPose(rec, t, speed)
	local m = math.clamp(speed / 12, 0, 1)
	local stroke = t * (4 + 3 * m) + rec.seed
	return {
		rootX = -1.25 * m - 0.15,
		neckX = 1.0 * m + 0.1,
		shRX = 2.0 + 0.9 * math.sin(stroke),
		shRZ = 0.45 + 0.55 * math.cos(stroke),
		elRX = 0.4 + 0.3 * math.max(0, math.sin(stroke)),
		shLX = 2.0 + 0.9 * math.sin(stroke),
		shLZ = -(0.45 + 0.55 * math.cos(stroke)),
		elLX = 0.4 + 0.3 * math.max(0, math.sin(stroke)),
		hipRX = 0.35 * math.sin(stroke * 2.2),
		hipLX = -0.35 * math.sin(stroke * 2.2),
		kneeRX = -0.3 - 0.2 * math.max(0, math.sin(stroke * 2.2)),
		kneeLX = -0.3 - 0.2 * math.max(0, -math.sin(stroke * 2.2)),
		ankRX = -0.5,
		ankLX = -0.5,
	}
end

local HOLD_EGG = { shRX = 0.95, shRZ = -0.32, elRX = 1.25, shLX = 0.95, shLZ = 0.32, elLX = 1.25, waistX = 0.1 }

local function grabPose(u)
	-- reach down and forward, then scoop it up to the chest
	local scoop = smooth((u - 0.25) / 0.25)
	local p = { waistX = -0.65, rootX = -0.2, shRX = 1.9, shRZ = -0.15, elRX = 0.25, shLX = 1.9, shLZ = 0.15, elLX = 0.25, neckX = -0.35 }
	crouch(p, 0.7, 1)
	return mix(p, { waistX = 0.05, shRX = 1.0, shRZ = -0.3, elRX = 1.3, shLX = 1.0, shLZ = 0.3, elLX = 1.3, neckX = 0.1 }, scoop, UPPER)
end

local function cheerPose(t, u)
	local pump = math.sin(t * 13)
	local hop = math.abs(math.sin(u * 7.5))
	return {
		rootUp = 0.45 * hop - 0.1,
		waistX = 0.15,
		neckX = 0.3,
		shRX = 2.95 + 0.18 * pump,
		shRZ = 0.35,
		elRX = 0.2 + 0.25 * math.max(0, pump),
		shLX = 2.95 - 0.18 * pump,
		shLZ = -0.35,
		elLX = 0.2 + 0.25 * math.max(0, -pump),
		hipRX = 0.3 * hop,
		kneeRX = -0.6 * hop,
		hipLX = 0.3 * hop,
		kneeLX = -0.6 * hop,
	}
end

local function hurtPose(u, side)
	-- snapped back by the blow, arms up to guard
	return {
		rootX = 0.18,
		rootZ = 0.15 * side,
		rootUp = -0.12,
		waistX = 0.5,
		waistZ = 0.1 * side,
		neckX = 0.4,
		neckZ = -0.15 * side,
		shRX = 1.0,
		shRZ = 0.55,
		elRX = 1.5,
		shLX = 1.0,
		shLZ = -0.55,
		elLX = 1.5,
		hipRX = 0.35,
		kneeRX = -0.55,
		hipLX = -0.1,
		kneeLX = -0.2,
	}
end

-- Patch 10: the rod swing. Up and back over the shoulder, then a chop forward into a lunge.
local function swingPose(u)
	local p = {
		waistY = -0.45,
		waistX = 0.12,
		neckX = -0.1,
		shRX = 3.0,
		shRZ = 0.35,
		elRX = 0.75,
		shLX = 0.7,
		shLZ = -0.25,
		elLX = 0.9,
		hipLX = 0.3,
		kneeLX = -0.35,
		hipRX = -0.2,
		kneeRX = -0.2,
		rootUp = -0.2,
	}
	local chop = smooth((u - 0.1) / 0.13)
	return mix(p, {
		waistY = 0.6,
		waistX = -0.25,
		neckX = -0.15,
		shRX = 0.45,
		shRZ = -0.55,
		elRX = 0.15,
		shLX = -0.35,
		shLZ = -0.2,
		elLX = 0.6,
		hipLX = 0.65,
		kneeLX = -0.85,
		ankLX = 0.2,
		hipRX = -0.45,
		kneeRX = -0.3,
		rootUp = -0.45,
		rootX = -0.18,
	}, chop)
end

-- Patch 10: flying off a geyser: arms flung up, a tucked front flip at the top of the arc, then legs down to land.
local function launchPose(s)
	local p = { shRX = 2.8, shRZ = 0.55, elRX = 0.3, shLX = 2.8, shLZ = -0.55, elLX = 0.3, waistX = 0.2, neckX = 0.25, hipRX = -0.15, hipLX = 0.25, kneeRX = -0.35, kneeLX = -0.6 }
	local tuck = math.min(smooth((s - 0.2) / 0.12), smooth((0.78 - s) / 0.12))
	if tuck > 0 then
		mix(p, { shRX = 1.3, shRZ = -0.1, elRX = 1.4, shLX = 1.3, shLZ = 0.1, elLX = 1.4, waistX = -0.5, neckX = -0.3, hipRX = 1.7, hipLX = 1.7, kneeRX = -2.2, kneeLX = -2.2, ankRX = 0.5, ankLX = 0.5 }, tuck)
	end
	local flip = smooth((s - 0.25) / 0.5)
	p.rootX = flip < 1 and -flip * math.pi * 2 or 0
	return p
end

local function dizzyPose(t)
	local c, s = math.cos(t * 5.5), math.sin(t * 5.5)
	local p = {
		rootZ = 0.09 * math.sin(t * 2.7),
		rootX = 0.05 * math.cos(t * 2.7),
		waistZ = 0.12 * s,
		waistX = 0.08 * c,
		neckX = 0.22 * c,
		neckZ = 0.3 * s,
		shRX = -0.05,
		shRZ = 0.2 + 0.08 * s,
		elRX = 0.3,
		shLX = -0.05,
		shLZ = -(0.2 - 0.08 * s),
		elLX = 0.3,
	}
	crouch(p, 0.35, 1)
	return p
end

local function downPose(u)
	-- buckle to one knee, then topple forward onto the hands
	local fall = smooth((u - 0.35) / 0.45)
	local p = { waistX = -0.35, neckX = -0.4, shRX = 0.4, shLX = 0.4, elRX = 0.5, elLX = 0.5, hipRX = 1.25, kneeRX = -2.3, ankRX = 1.0, hipLX = 0.35, kneeLX = -1.9, ankLX = 0.6, rootUp = -1.05 }
	return mix(p, { rootX = -1.25, rootUp = -1.85, waistX = -0.2, neckX = 0.7, shRX = 2.4, shLX = 2.4, shRZ = 0.3, shLZ = -0.3, elRX = 0.3, elLX = 0.3, hipRX = 1.6, kneeRX = -1.6, hipLX = 1.4, kneeLX = -1.5 }, fall)
end

-- Effects -------------------------------------------------------------------------------------------------

local MATERIAL_DUST = {
	[Enum.Material.Snow] = Color3.fromRGB(246, 246, 252),
	[Enum.Material.Sand] = Color3.fromRGB(226, 206, 160),
	[Enum.Material.Grass] = Color3.fromRGB(120, 200, 96),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(120, 200, 96),
	[Enum.Material.Ground] = Color3.fromRGB(150, 120, 96),
	[Enum.Material.Mud] = Color3.fromRGB(120, 96, 76),
}

local function dustColor(rec)
	if rec.inWater then
		return Color3.fromRGB(200, 240, 255)
	end
	local color = MATERIAL_DUST[rec.floorMaterial]
	if color then
		return color
	end
	return (rec.floorColor or Color3.fromRGB(200, 200, 200)):Lerp(Color3.new(1, 1, 1), 0.45)
end

local function footstep(rec, footPart, strength)
	if not footPart or not rec.near then
		return
	end
	local at = footPart.Position - Vector3.new(0, footPart.Size.Y / 2, 0)
	if rec.inWater then
		Fx.cubes(at, { Color3.fromRGB(200, 240, 255), Color3.fromRGB(150, 220, 255) }, { count = 3 + strength, spread = 1.6 + strength * 0.4, size = 0.3, life = 0.35, up = 1, material = Enum.Material.Glass })
	else
		Fx.cubes(at, dustColor(rec), { count = 2 + strength, spread = 1.2 + strength * 0.5, size = 0.3, life = 0.4, up = 0.5, material = Enum.Material.SmoothPlastic })
	end
end

local function landed(rec, impact)
	if not rec.near then
		return
	end
	local root = rec.root
	local at = root.Position - Vector3.new(0, rec.hipOffset, 0)
	local strength = math.clamp((impact - 25) / 40, 0, 1)
	Fx.ring(at + Vector3.new(0, 0.1, 0), dustColor(rec), 3 + 5 * strength, 0.4, 0.2)
	Fx.cubes(at, dustColor(rec), { count = 6 + math.floor(10 * strength), spread = 3 + 4 * strength, size = 0.45, life = 0.5, up = 0.35, material = Enum.Material.SmoothPlastic })
	if rec.player == player and impact > 45 then
		Audio.play("LandHeavy", root)
	end
end

local function trailsFor(rec)
	if rec.trails then
		return rec.trails
	end
	local list = {}
	for _, handName in ipairs({ "LeftHand", "RightHand" }) do
		local hand = rec.character:FindFirstChild(handName)
		if hand then
			local a0 = Instance.new("Attachment")
			a0.Name = "TideboundTrailTop"
			a0.Position = Vector3.new(0, 0.25, 0)
			a0.Parent = hand
			local a1 = Instance.new("Attachment")
			a1.Name = "TideboundTrailBottom"
			a1.Position = Vector3.new(0, -0.25, 0)
			a1.Parent = hand
			local trail = Instance.new("Trail")
			trail.Name = "TideboundSpeedTrail"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.18
			trail.LightEmission = 0.6
			trail.FaceCamera = true
			trail.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
			trail.Transparency = NumberSequence.new(0.35, 1)
			trail.WidthScale = NumberSequence.new(1, 0)
			trail.Enabled = false
			trail.Parent = hand
			table.insert(list, trail)
		end
	end
	rec.trails = list
	return list
end

local function setTrails(rec, on)
	if rec.trailsOn == on then
		return
	end
	rec.trailsOn = on
	for _, trail in ipairs(trailsFor(rec)) do
		trail.Enabled = on
	end
end

-- The eggs you carry, held in front of your chest (everyone sees how much you have at risk).
local EGG_COLOR = Color3.fromRGB(232, 248, 255)
local function eggPart(scale)
	local egg = Instance.new("Part")
	egg.Name = "CarriedEgg"
	egg.Anchored = true
	egg.CanCollide = false
	egg.CanQuery = false
	egg.CanTouch = false
	egg.CastShadow = false
	egg.Size = Vector3.new(1.3, 1.7, 1.3) * scale
	egg.Color = EGG_COLOR
	egg.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 230, 255)
	glow.Range = 6
	glow.Brightness = 0.8
	glow.Parent = egg
	egg.Parent = Fx.folder()
	return egg
end

local function updateEggs(rec, count, t, burst)
	rec.eggs = rec.eggs or {}
	local shown = math.min(count, 3)
	while #rec.eggs > shown do
		local egg = table.remove(rec.eggs)
		if burst then
			Fx.cubes(egg.Position, EGG_COLOR, { count = 6, spread = 3, size = 0.35, life = 0.4 })
		end
		egg:Destroy()
	end
	while #rec.eggs < shown do
		local egg = eggPart(#rec.eggs == 0 and 1 or 0.75)
		table.insert(rec.eggs, egg)
		if burst then
			Fx.cubes(rec.root.Position, Color3.fromRGB(150, 230, 255), { count = 8, spread = 2.5, size = 0.35, life = 0.4 })
		end
	end
	local torso = rec.character:FindFirstChild("UpperTorso")
	if not torso then
		return
	end
	local slots = { CFrame.new(0, -0.35, -1.15), CFrame.new(-0.55, 0.45, -1.05), CFrame.new(0.55, 0.45, -1.05) }
	for i, egg in ipairs(rec.eggs) do
		local bob = math.sin(t * 3 + i) * 0.04
		egg.CFrame = torso.CFrame * slots[i] * CFrame.new(0, bob, 0) * CFrame.Angles(0.15, t * 0.6 + i, 0)
	end
end

-- Spinning stars over a stunned head.
local function updateStars(rec, on, t)
	if not on then
		if rec.stars then
			for _, star in ipairs(rec.stars) do
				star:Destroy()
			end
			rec.stars = nil
		end
		return
	end
	local head = rec.character:FindFirstChild("Head")
	if not head then
		return
	end
	if not rec.stars then
		rec.stars = {}
		for i = 1, 3 do
			local star = Instance.new("Part")
			star.Name = "DizzyStar"
			star.Anchored = true
			star.CanCollide = false
			star.CanQuery = false
			star.CanTouch = false
			star.CastShadow = false
			star.Material = Enum.Material.Neon
			star.Color = i == 2 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 220, 60)
			star.Size = Vector3.new(0.45, 0.45, 0.15)
			star.Parent = Fx.folder()
			rec.stars[i] = star
		end
	end
	for i, star in ipairs(rec.stars) do
		local angle = t * 4 + i * TAU / 3
		star.CFrame = head.CFrame * CFrame.new(math.cos(angle) * 1.3, 1.1 + 0.15 * math.sin(t * 6 + i), math.sin(angle) * 1.3) * CFrame.Angles(0, -angle, math.rad(45) + t * 3)
	end
end

-- Per character ---------------------------------------------------------------------------------------------

local rigs = {} -- [Player] = record
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
local filterAt = 0

local function refreshFilter()
	local list = { Fx.folder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local rodFx = workspace:FindFirstChild("TideboundRodFX")
	if rodFx then
		table.insert(list, rodFx)
	end
	rayParams.FilterDescendantsInstances = list
end

local function newRecord(p, character)
	return {
		player = p,
		character = character,
		seed = rng:NextNumber(0, 10),
		phi = 0,
		weight = 0, -- how much of the pose is ours (0 while an animator's animation plays)
		air = 0,
		swim = 0,
		move = 0,
		sprint = 0,
		carry = 0,
		arms = 0,
		turnLean = 0,
		lastYaw = nil,
		grounded = true,
		airTime = 0,
		minVy = 0,
		land = nil, -- { at, drop }
		stillSince = os.clock(),
		nextFidget = os.clock() + rng:NextNumber(5, 9),
		seen = {},
		externalAt = 0,
		external = false,
	}
end

local function clearRecord(rec)
	updateStars(rec, false, 0)
	MotionBus.arms[rec.character] = nil
	MotionBus.pose[rec.character] = nil
	if rec.eggs then
		for _, egg in ipairs(rec.eggs) do
			egg:Destroy()
		end
		rec.eggs = nil
	end
end

-- An animation an animator made (an Action-priority track we didn't start) takes the body over.
-- Core (Value 1000, the default Animate script's tracks) sorts above Action by Value, so the check names the
-- four Action priorities instead of comparing values; comparing them switched every body off.
local ACTION = {
	[Enum.AnimationPriority.Action] = true,
	[Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true,
	[Enum.AnimationPriority.Action4] = true,
}
local function externalTrack(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if ACTION[track.Priority] and track.WeightCurrent > 0.3 then
			return true
		end
	end
	return false
end

-- One-shot reactions from the server's attributes: hit sparks, damage numbers, the grab burst.
local function reactions(rec, character, serverNow)
	local hurtAt = character:GetAttribute("HurtAt")
	if hurtAt and rec.seen.hurt ~= hurtAt then
		rec.seen.hurt = hurtAt
		if serverNow - hurtAt < 1 then
			rec.hurtSide = rng:NextNumber() < 0.5 and -1 or 1
			local torso = character:FindFirstChild("UpperTorso")
			if torso and rec.near then
				Fx.cubes(torso.Position, { Color3.fromRGB(255, 80, 70), Color3.fromRGB(255, 220, 120), Color3.new(1, 1, 1) }, { count = 14, spread = 5, size = 0.45, life = 0.45 })
				Fx.ring(torso.Position, Color3.fromRGB(255, 120, 100), 4, 0.3, 0.3)
				Fx.flashModel(character, Color3.fromRGB(255, 50, 50), 0.45)
				local amount = character:GetAttribute("HurtAmount")
				if amount then
					Fx.number(torso, "-" .. tostring(amount), Color3.fromRGB(255, 70, 70))
				end
			end
			if rec.player == player then
				Audio.play("HitThud", rec.root)
			end
		end
	end
	local grabAt = character:GetAttribute("GrabAt")
	if grabAt and rec.seen.grab ~= grabAt then
		rec.seen.grab = grabAt
		if serverNow - grabAt < 1 and rec.near then
			task.delay(0.3, function()
				if rec.root.Parent then
					local at = rec.root.Position + rec.root.CFrame.LookVector * 1.5
					Fx.cubes(at, { Color3.fromRGB(150, 230, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 255, 200) }, { count = 18, spread = 6, size = 0.5, life = 0.55, up = 0.9 })
					Fx.stars(at, 5)
				end
			end)
		end
	end
	local cheerAt = character:GetAttribute("CheerAt")
	if cheerAt and rec.seen.cheer ~= cheerAt then
		rec.seen.cheer = cheerAt
		if serverNow - cheerAt < 1 and rec.near then
			Fx.bolts(rec.root.Position + Vector3.new(0, 1, 0), 5)
			Fx.stars(rec.root.Position + Vector3.new(0, 2, 0), 8)
		end
	end
	local downAt = character:GetAttribute("DownAt")
	if downAt and rec.seen.down ~= downAt then
		rec.seen.down = downAt
		if serverNow - downAt < 1 then
			if rec.near then
				Fx.cubes(rec.root.Position, { Color3.fromRGB(90, 90, 110), Color3.fromRGB(255, 80, 80) }, { count = 16, spread = 6, size = 0.5, life = 0.7, up = 0.4 })
			end
			if rec.player == player then
				Audio.play("Down", rec.root)
			end
		end
	end
end

local function applyPose(j, pose, w)
	local function set(joint, cf)
		joint.Transform = w >= 0.999 and cf or joint.Transform:Lerp(cf, w)
	end
	set(j.root, CFrame.new(0, pose.rootUp or 0, 0) * CFrame.Angles(pose.rootX or 0, pose.rootY or 0, pose.rootZ or 0))
	set(j.waist, CFrame.Angles(pose.waistX or 0, pose.waistY or 0, pose.waistZ or 0))
	set(j.neck, CFrame.Angles(pose.neckX or 0, pose.neckY or 0, pose.neckZ or 0))
	set(j.shR, CFrame.Angles(pose.shRX or 0, pose.shRY or 0, pose.shRZ or 0))
	set(j.elR, CFrame.Angles(pose.elRX or 0, 0, 0))
	set(j.shL, CFrame.Angles(pose.shLX or 0, pose.shLY or 0, pose.shLZ or 0))
	set(j.elL, CFrame.Angles(pose.elLX or 0, 0, 0))
	set(j.hipR, CFrame.Angles(pose.hipRX or 0, 0, pose.hipRZ or 0))
	set(j.kneeR, CFrame.Angles(pose.kneeRX or 0, 0, 0))
	set(j.ankR, CFrame.Angles(pose.ankRX or 0, 0, 0))
	set(j.hipL, CFrame.Angles(pose.hipLX or 0, 0, pose.hipLZ or 0))
	set(j.kneeL, CFrame.Angles(pose.kneeLX or 0, 0, 0))
	set(j.ankL, CFrame.Angles(pose.ankLX or 0, 0, 0))
end

-- Reads where the character is: moving, on the ground, in water.
local function sense(rec, humanoid, root, dt)
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local dirF, dirS = 1, 0
	if speed > 0.5 then
		dirF = flat:Dot(look) / speed
		dirS = flat:Dot(right) / speed
	end
	local yaw = math.atan2(-look.X, -look.Z)
	if rec.lastYaw then
		local d = (yaw - rec.lastYaw + math.pi) % TAU - math.pi
		local rate = d / math.max(dt, 1 / 240)
		rec.turnLean += (math.clamp(-rate * 0.05 * math.min(speed / 16, 1.2), -0.32, 0.32) - rec.turnLean) * math.min(1, dt * 8)
	end
	rec.lastYaw = yaw
	rec.hipOffset = humanoid.HipHeight + root.Size.Y / 2
	local result = workspace:Raycast(root.Position, Vector3.new(0, -(rec.hipOffset + 1.6), 0), rayParams)
	local grounded, inWater = false, false
	if result then
		if result.Material == Enum.Material.Water then
			inWater = root.Position.Y < result.Position.Y + 0.4
			rec.floorMaterial, rec.floorColor = Enum.Material.Water, nil
		else
			grounded = true
			rec.floorMaterial = result.Material
			rec.floorColor = result.Instance and result.Instance:IsA("BasePart") and result.Instance.Color or nil
		end
	end
	if rec.player == player then
		local state = humanoid:GetState()
		inWater = state == Enum.HumanoidStateType.Swimming
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air and not inWater
	end
	if not grounded and not inWater and math.abs(v.Y) < 1.5 and rec.grounded then
		grounded = true -- stepping over a gap between parts
	end
	rec.inWater = inWater
	return speed, v.Y, dirF, dirS, grounded
end

local function step(p, rec, dt, t, serverNow, cameraPos)
	local character = rec.character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	rec.root = root
	local distance = (root.Position - cameraPos).Magnitude
	rec.near = distance < FX_RANGE
	if distance > POSE_RANGE then
		return
	end
	if not rec.joints then
		if os.clock() < (rec.jointTry or 0) then
			return
		end
		rec.jointTry = os.clock() + 0.5
		rec.joints = findJoints(character)
		if not rec.joints then
			if p == player and humanoid.RigType == Enum.HumanoidRigType.R6 and not rec.warnedRig then
				rec.warnedRig = true
				warn("[TideboundMotion] Your avatar is R6, so the custom idle, run and fishing animations are off. Set Game Settings > Avatar > Avatar Type to R15.")
			end
			return
		end
	end
	reactions(rec, character, serverNow)

	local speed, vy, dirF, dirS, grounded = sense(rec, humanoid, root, dt)

	-- an animator's own animation (or sitting) takes the body over
	if os.clock() - rec.externalAt > 0.2 then
		rec.externalAt = os.clock()
		rec.external = humanoid.Sit or humanoid.PlatformStand or externalTrack(humanoid)
	end
	rec.weight += ((rec.external and 0 or 1) - rec.weight) * math.min(1, dt * 10)

	-- landing: how hard, and the squash that follows
	if grounded and not rec.grounded and rec.airTime > 0.25 then
		local impact = -rec.minVy
		if impact > 18 then
			rec.land = { at = t, drop = math.clamp((impact - 18) / 70, 0.15, 0.65) }
			landed(rec, impact)
		end
	end
	if grounded or rec.inWater then
		rec.airTime = 0
		rec.minVy = 0
	else
		rec.airTime += dt
		rec.minVy = math.min(rec.minVy, vy)
	end
	rec.grounded = grounded

	-- blend weights
	local airborne = not grounded and not rec.inWater and rec.airTime > 0.08
	rec.air += ((airborne and 1 or 0) - rec.air) * math.min(1, dt * 12)
	rec.swim += ((rec.inWater and 1 or 0) - rec.swim) * math.min(1, dt * 6)
	local moving = speed > 1.2 and not airborne
	rec.move += ((moving and 1 or 0) - rec.move) * math.min(1, dt * 10)
	local sprinting = speed > SPRINT_SPEED and moving
	rec.sprint += ((sprinting and 1 or 0) - rec.sprint) * math.min(1, dt * 6)

	-- the run cycle follows the distance actually covered
	local stride = 8 + 1.6 * rec.sprint
	local before = rec.phi
	if moving then
		rec.phi = (rec.phi + speed * dt / stride * TAU * (dirF < -0.3 and -1 or 1)) % TAU
		-- footsteps: right foot plants at pi/2, left at 3pi/2
		local function crossed(mark)
			local a, b = before, rec.phi
			if b < a then
				return (a < mark) or (b >= mark)
			end
			return a < mark and b >= mark
		end
		local strength = rec.sprint > 0.5 and 2 or 1
		if crossed(math.pi / 2) then
			footstep(rec, character:FindFirstChild("RightFoot"), strength)
		end
		if crossed(math.pi * 1.5) then
			footstep(rec, character:FindFirstChild("LeftFoot"), strength)
		end
		rec.stillSince = os.clock()
		rec.fidget = nil
	end
	setTrails(rec, distance < 60 and rec.sprint > 0.6 and moving)

	-- base: idle, run, air, swim
	local pose
	if filled("IdleHub") then
		pose = {}
	else
		if not moving and os.clock() - rec.stillSince > 4 and not rec.fidget and os.clock() > rec.nextFidget then
			rec.fidget = { kind = FIDGETS[rng:NextInteger(1, #FIDGETS)], at = t, length = rng:NextNumber(1.6, 2.4) }
			rec.nextFidget = os.clock() + rng:NextNumber(7, 13)
		end
		pose = idlePose(rec, t)
	end
	if rec.move > 0.01 and not filled("Run") then
		local run = runPose(rec, math.max(speed, 6), dirF, dirS, rec.sprint)
		mix(pose, run, rec.move)
	end
	if rec.air > 0.01 and not filled("Jump") then
		mix(pose, airPose(rec, t, vy), rec.air)
	end
	if rec.swim > 0.01 then
		mix(pose, swimPose(rec, t, speed), rec.swim)
	end

	-- landing squash
	local land = rec.land
	if land then
		local u = t - land.at
		if u > 0.45 then
			rec.land = nil
		else
			crouch(pose, land.drop, envelope(u, 0.45, 0.05, 0.38))
		end
	end

	-- the head follows your camera a little (your own character)
	if p == player and rec.move < 0.5 then
		local camera = workspace.CurrentCamera
		if camera then
			local rel = root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
			local yaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1.1, 1.1)
			if math.abs(yaw) < 1.6 then
				pose.neckY = (pose.neckY or 0) * 0.4 + yaw * 0.45
				pose.neckX = (pose.neckX or 0) + math.clamp(rel.Y, -0.6, 0.6) * 0.35
			end
		end
	end

	-- carrying eggs: both arms hug them to the chest
	local eggs = character:GetAttribute("CarryEggs") or 0
	rec.carry += (((eggs > 0) and 1 or 0) - rec.carry) * math.min(1, dt * 8)
	if rec.carry > 0.01 and not filled("EggTuck") then
		local hold = table.clone(HOLD_EGG)
		hold.shRX += 0.12 * math.sin(rec.phi) * rec.move
		hold.shLX -= 0.12 * math.sin(rec.phi) * rec.move
		mix(pose, hold, rec.carry * (1 - rec.swim), UPPER)
	end
	-- only drawn up close; walking into range doesn't burst, a new or lost egg does
	local shown = rec.near and eggs or 0
	updateEggs(rec, shown, t, rec.near and eggs ~= rec.lastEggs)
	rec.lastEggs = eggs

	-- the fishing arms (TideboundRod)
	local arms = MotionBus.arms[character]
	local armsW = arms and arms.weight or 0
	rec.arms += (armsW - rec.arms) * math.min(1, dt * 20)
	if arms and armsW > 0 then
		local a = arms.pose
		mix(pose, { shRX = a.shR, shRZ = a.inR, elRX = a.elR, shLX = a.shL, shLZ = a.inL, elLX = a.elL, waistX = a.waist, waistY = 0, waistZ = 0, shRY = 0, shLY = 0 }, armsW, UPPER)
	end
	-- Patch 10: the legs and hips join in (braced stance, lunge on the cast, squat and lean on the reel)
	if arms and armsW > 0 and arms.body then
		mix(pose, arms.body, armsW * (1 - 0.8 * math.clamp(rec.move, 0, 1)), LOWER)
	end

	-- Patch 10: the rod swing every client sees (SwingAt from the server)
	local swingAt = character:GetAttribute("SwingAt")
	if swingAt then
		local u = serverNow - swingAt
		local w = envelope(u, 0.5, 0.04, 0.22)
		if w > 0 then
			-- the arms always swing; the lunge only while standing, so you can swing on the run
			local swing = swingPose(u)
			mix(pose, swing, w, UPPER)
			mix(pose, swing, w * (1 - 0.85 * math.clamp(rec.move, 0, 1)), LOWER)
		end
	end

	-- Patch 10: a geyser launch (TideboundTravel)
	local launch = MotionBus.launch and MotionBus.launch[character]
	if launch then
		local s = (os.clock() - launch.start) / math.max(launch.duration, 0.1)
		if s >= 0 and s <= 1 then
			mix(pose, launchPose(s), math.min(1, s * 10, (1 - s) * 6))
		end
	end

	-- one-shot full-body moments from the server
	local grabAt = character:GetAttribute("GrabAt")
	if grabAt and not filled("EggGrab") then
		local u = serverNow - grabAt
		local w = envelope(u, 0.55, 0.08, 0.2)
		if w > 0 then
			mix(pose, grabPose(u), w)
		end
	end
	local cheerAt = character:GetAttribute("CheerAt")
	if cheerAt and not filled("ExtractionEmote") then
		local u = serverNow - cheerAt
		local w = envelope(u, 2.6, 0.15, 0.4)
		if w > 0 then
			mix(pose, cheerPose(t, u), w)
		end
	end
	local stunUntil = character:GetAttribute("StunUntil") or 0
	local stunned = serverNow < stunUntil
	if stunned then
		mix(pose, dizzyPose(t), math.min(1, (stunUntil - serverNow) / 0.25))
	end
	updateStars(rec, stunned and rec.near, t)
	local hurtAt = character:GetAttribute("HurtAt")
	if hurtAt and not filled("HitReact") then
		local u = serverNow - hurtAt
		local w = envelope(u, 0.5, 0.05, 0.35)
		if w > 0 then
			addTo(pose, hurtPose(u, rec.hurtSide or 1), w)
		end
	end
	local downAt = character:GetAttribute("DownAt")
	if downAt and not filled("Down") then
		local u = serverNow - downAt
		local w = envelope(u, 2.4, 0.08, 0.3)
		if w > 0 then
			mix(pose, downPose(u), w)
		end
	end
	-- a cutscene can ask for a pose for a moment
	local asked = MotionBus.pose[character]
	if asked then
		if os.clock() > asked.untilTime then
			MotionBus.pose[character] = nil
		elseif asked.name == "cheer" then
			mix(pose, cheerPose(t, t), 1)
		elseif asked.name == "brace" then
			mix(pose, hurtPose(0.2, 1), 0.6)
		end
	end

	if rec.weight > 0.01 then
		applyPose(rec.joints, pose, rec.weight)
	end
end

-- Hands filled-in Idle, Run and Jump ids to the default Animate script, so they play on your own avatar.
local ANIMATE_SLOTS = { IdleHub = { "idle", { "Animation1", "Animation2" } }, Run = { "run", { "RunAnim" } }, Jump = { "jump", { "JumpAnim" } } }
local function useFilledIds(character)
	local animate = character:WaitForChild("Animate", 10)
	if not animate then
		return
	end
	for name, slot in pairs(ANIMATE_SLOTS) do
		if filled(name) then
			local folder = animate:FindFirstChild(slot[1])
			for _, child in ipairs(slot[2]) do
				local value = folder and folder:FindFirstChild(child)
				if value and value:IsA("Animation") then
					value.AnimationId = Animations[name].id
				end
			end
		end
	end
end
player.CharacterAdded:Connect(useFilledIds)
if player.Character then
	task.spawn(useFilledIds, player.Character)
end

RunService.PreSimulation:Connect(function(dt)
	local t = os.clock()
	if t > filterAt then
		filterAt = t + 1
		refreshFilter()
	end
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local cameraPos = camera and camera.CFrame.Position or Vector3.zero
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local rec = rigs[p]
		if character and (not rec or rec.character ~= character) then
			if rec then
				clearRecord(rec)
			end
			rec = newRecord(p, character)
			rigs[p] = rec
		end
		if rec and character and character.Parent then
			local ok, err = pcall(step, p, rec, dt, t, serverNow, cameraPos)
			if not ok and not rec.warned then
				rec.warned = true
				warn("[TideboundMotion]", err)
			end
		end
	end
	for p, rec in pairs(rigs) do
		if not p.Parent or not rec.character.Parent then
			clearRecord(rec)
			rigs[p] = nil
		end
	end
end)
