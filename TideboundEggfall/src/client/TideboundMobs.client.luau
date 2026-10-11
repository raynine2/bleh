-- Tidebound: Eggfall: the wild mobs of the Open Isles (Patch 10), drawn on this screen. The server moves one
-- invisible part per mob (tag TideboundMob, see Mobs.luau); this script builds a chunky voxel model for each and
-- every frame eases it after its part, with crab legs scuttling, gull wings flapping and shark fins cutting the
-- water. What the attributes show:
--   TellAt  a red "!" over its head, and for a puffer's blast or a golem's slam a red ring that fills in
--   State   "attack" plays the strike (the blast, the slam, the snap, the bite)
--   HitAt   a white flash, "-1", a few cubes and a hop back
--   DeadAt  a big burst of cubes and stars; the model shrinks away until State leaves "dead"
-- Past ANIMATE_RANGE a model holds still, and past SHOW_RANGE it is hidden, so a hundred mobs cost little.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))
local Isles = require(Shared:WaitForChild("IslesLayout"))

local player = Players.LocalPlayer

local TAG = "TideboundMob"
local ANIMATE_RANGE = 260
local SHOW_RANGE = 400
local FX_RANGE = 200 -- tells, hits and deaths farther than this play no effects
local SMOOTH = 12
local SNAP_DISTANCE = 30 -- farther than this from its part (a respawn, a lag spike), a model jumps there
local HOP_SECONDS = 0.35
local DEATH_SECONDS = 0.35
local POP_SECONDS = 0.35
local ATTACK_LUNGE = 0.3 -- the server's "attack" window: a crab's or shark's lunge plays over it
local WATER_Y = Isles.WATER_Y
local RED = Color3.fromRGB(255, 52, 52)
local WHITE = Color3.new(1, 1, 1)
local HIT_TEXT = Color3.fromRGB(255, 236, 110)
local PIP_FULL = Color3.fromRGB(255, 84, 84)
local PIP_EMPTY = Color3.fromRGB(70, 60, 74)
local SPRAY = { WHITE, Color3.fromRGB(170, 226, 255) }
local DUST = { Color3.fromRGB(196, 182, 150), Color3.fromRGB(150, 140, 120) }

local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local models = workspace:FindFirstChild("TideboundMobModels")
if not models then
	models = Instance.new("Folder")
	models.Name = "TideboundMobModels"
	models.Parent = workspace
end

-- Palettes ------------------------------------------------------------------------------------------------------
-- Shoals mobs are bright; Kelp Cathedral's are darker greens with neon eyes (`glow`).

local PALETTE = {
	crab = {
		Shoals = { shell = rgb(232, 78, 52), top = rgb(255, 128, 76), leg = rgb(196, 58, 40), claw = rgb(244, 96, 62), pincer = rgb(255, 170, 120), eye = rgb(255, 255, 255), pupil = rgb(24, 22, 30), brow = rgb(92, 22, 20), mouth = rgb(70, 16, 16), fang = rgb(255, 250, 235) },
		Kelp = { shell = rgb(44, 94, 60), top = rgb(66, 132, 78), leg = rgb(32, 70, 44), claw = rgb(52, 110, 66), pincer = rgb(176, 96, 206), eye = rgb(120, 255, 170), pupil = rgb(10, 30, 20), brow = rgb(16, 40, 24), mouth = rgb(14, 34, 22), fang = rgb(210, 240, 200), glow = true },
	},
	puffer = {
		Shoals = { body = rgb(255, 206, 72), belly = rgb(255, 240, 196), spike = rgb(255, 250, 232), fin = rgb(255, 146, 58), eye = rgb(255, 255, 255), pupil = rgb(24, 22, 30), brow = rgb(110, 60, 20), mouth = rgb(120, 36, 30) },
		Kelp = { body = rgb(58, 110, 70), belly = rgb(128, 160, 108), spike = rgb(196, 110, 255), fin = rgb(40, 80, 50), eye = rgb(255, 222, 90), pupil = rgb(30, 24, 10), brow = rgb(20, 44, 26), mouth = rgb(24, 40, 28), glow = true },
	},
	gull = {
		Shoals = { body = rgb(246, 246, 248), wing = rgb(206, 212, 222), wing2 = rgb(172, 180, 194), tip = rgb(40, 44, 54), beak = rgb(255, 176, 40), beakTip = rgb(236, 92, 40), eye = rgb(24, 22, 30), brow = rgb(60, 60, 70), feet = rgb(255, 150, 40) },
		Kelp = { body = rgb(150, 170, 150), wing = rgb(96, 124, 100), wing2 = rgb(70, 96, 76), tip = rgb(26, 40, 30), beak = rgb(200, 170, 70), beakTip = rgb(150, 90, 40), eye = rgb(120, 255, 170), brow = rgb(20, 40, 26), feet = rgb(180, 140, 60), glow = true },
	},
	shark = {
		Shoals = { top = rgb(104, 130, 158), belly = rgb(234, 238, 242), fin = rgb(84, 108, 138), teeth = rgb(255, 255, 250), mouth = rgb(186, 52, 64), eye = rgb(255, 255, 255), pupil = rgb(20, 20, 26), brow = rgb(40, 50, 64) },
		Kelp = { top = rgb(44, 86, 64), belly = rgb(130, 160, 120), fin = rgb(32, 66, 48), teeth = rgb(220, 240, 210), mouth = rgb(120, 40, 90), eye = rgb(120, 255, 170), pupil = rgb(10, 30, 20), brow = rgb(16, 36, 24), glow = true },
	},
	golem = {
		Shoals = { body = rgb(240, 112, 116), dark = rgb(196, 78, 94), light = rgb(255, 172, 160), eye = rgb(255, 176, 60), mouth = rgb(90, 30, 40), coral1 = rgb(255, 140, 56), coral2 = rgb(160, 96, 236), coral3 = rgb(90, 214, 220) },
		Kelp = { body = rgb(54, 92, 70), dark = rgb(38, 68, 52), light = rgb(86, 124, 92), eye = rgb(90, 255, 230), mouth = rgb(16, 34, 24), coral1 = rgb(92, 140, 52), coral2 = rgb(146, 190, 72), coral3 = rgb(90, 255, 230), glow = true },
	},
}

-- Rigs: blocks hung on joints -------------------------------------------------------------------------------------
-- Every block has a rest CFrame around the mob's centre (-Z is forward). A joint turns its blocks about its pivot,
-- and can hang off a parent joint (a pincer on a claw, a wing tip on a wing).

local function newRig()
	local model = Instance.new("Model")
	return { model = model, pieces = {}, joints = {}, order = {}, legs = {} }
end

local function joint(rig, name, pivot, parent)
	rig.joints[name] = { pivot = pivot, inv = pivot:Inverse(), parent = parent, world = CFrame.identity }
	table.insert(rig.order, name)
end

local function block(rig, size, rest, color, jointName, material)
	local p = Instance.new("Part")
	p.Name = "Block"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.CFrame = rest
	p.Parent = rig.model
	local piece = { part = p, rest = rest, size = size, joint = jointName }
	table.insert(rig.pieces, piece)
	return piece
end

local function glowOf(c)
	return c.glow and Enum.Material.Neon or nil
end

-- Snapper Crab: 24 blocks. The part is 4 x 2.4 x 3.6 and its centre rides 1.2 above the ground.
local function buildCrab(c)
	local rig = newRig()
	local body = block(rig, V(3.4, 1.3, 2.6), CF(0, 0.15, 0), c.shell)
	body.part.CastShadow = true
	block(rig, V(2.6, 0.5, 2.0), CF(0, 0.95, 0.15), c.top)
	block(rig, V(1.0, 0.18, 0.1), CF(0, -0.05, -1.32), c.mouth)
	block(rig, V(0.2, 0.28, 0.12), CF(0.3, -0.22, -1.33), c.fang) -- one snaggletooth
	for _, s in ipairs({ -1, 1 }) do
		block(rig, V(0.3, 0.7, 0.3), CF(s * 0.6, 1.25, -0.9), c.top)
		block(rig, V(0.62, 0.62, 0.62), CF(s * 0.6, 1.78, -0.95), c.eye, nil, glowOf(c))
		block(rig, V(0.3, 0.34, 0.1), CF(s * 0.55, 1.74, -1.28), c.pupil)
		block(rig, V(0.66, 0.16, 0.2), CF(s * 0.6, 2.16, -1.0) * A(0, 0, s * 0.45), c.brow)
		local claw = s < 0 and "clawL" or "clawR"
		local pinch = s < 0 and "pinchL" or "pinchR"
		joint(rig, claw, CF(s * 1.55, 0.1, -0.9))
		joint(rig, pinch, CF(s * 2.05, 0.7, -1.9), claw)
		block(rig, V(0.5, 0.5, 1.0), CF(s * 1.85, 0.1, -1.35), c.claw, claw)
		block(rig, V(1.1, 0.8, 1.2), CF(s * 2.05, 0.25, -2.25), c.claw, claw)
		block(rig, V(1.0, 0.36, 1.0), CF(s * 2.05, 0.84, -2.4), c.pincer, pinch)
		for i, z in ipairs({ -0.55, 0.3, 1.1 }) do
			local name = (s < 0 and "legL" or "legR") .. i
			joint(rig, name, CF(s * 1.5, -0.25, z))
			block(rig, V(1.5, 0.35, 0.35), CF(s * 2.14, -0.64, z) * A(0, 0, -s * 0.55), c.leg, name)
			table.insert(rig.legs, { name = name, side = s, phase = i * 2.1 + (s > 0 and math.pi or 0) })
		end
	end
	rig.head = body.part
	rig.alertOffset = 2.6
	rig.barOffset = 3.3
	rig.lift = 1.2
	rig.colors = { c.shell, c.top, c.pincer }
	return rig
end

-- the puffer's spikes point out along these directions (none across its face)
local SPIKES = { V(1, 0.4, -0.3), V(-1, 0.4, -0.3), V(1, -0.5, 0.4), V(-1, -0.5, 0.4), V(0.5, 1, 0.3), V(-0.5, 1, 0.3), V(0, 0.6, 1), V(0.7, 0.2, 0.9), V(-0.7, 0.2, 0.9) }

-- Spike Puffer: 22 blocks, hovering 2.5 above the ground.
local function buildPuffer(c)
	local rig = newRig()
	local body = block(rig, V(2.8, 2.6, 2.8), CF(0, 0, 0), c.body)
	body.part.CastShadow = true
	block(rig, V(2.9, 1.0, 2.9), CF(0, -0.85, 0), c.belly)
	block(rig, V(0.8, 0.45, 0.12), CF(0, -0.42, -1.5), c.mouth)
	block(rig, V(0.2, 0.55, 0.9), CF(0, 1.55, 0.35), c.fin)
	for _, s in ipairs({ -1, 1 }) do
		block(rig, V(0.75, 0.75, 0.2), CF(s * 0.68, 0.38, -1.45), c.eye, nil, glowOf(c))
		block(rig, V(0.34, 0.4, 0.1), CF(s * 0.6, 0.34, -1.58), c.pupil)
		block(rig, V(0.85, 0.2, 0.2), CF(s * 0.68, 0.95, -1.5) * A(0, 0, s * 0.5), c.brow)
		local fin = s < 0 and "finL" or "finR"
		joint(rig, fin, CF(s * 1.4, -0.1, 0.1))
		block(rig, V(0.2, 0.75, 1.0), CF(s * 1.52, -0.1, 0.4), c.fin, fin)
	end
	joint(rig, "tail", CF(0, 0.1, 1.4))
	block(rig, V(0.25, 1.2, 0.9), CF(0, 0.1, 1.85), c.fin, "tail")
	for _, n in ipairs(SPIKES) do
		local u = n.Unit
		-- where this direction leaves the body's box, so every spike pokes out the same amount
		local reach = math.min(1.4 / math.max(math.abs(u.X), 1e-3), 1.3 / math.max(math.abs(u.Y), 1e-3), 1.4 / math.max(math.abs(u.Z), 1e-3))
		local at = u * (reach + 0.12)
		local spike = block(rig, V(0.36, 0.36, 0.8), CFrame.lookAt(at, at + u), c.spike, nil, glowOf(c))
		spike.out = u
	end
	rig.head = body.part
	rig.alertOffset = 2.6
	rig.barOffset = 3
	rig.lift = 2.5
	rig.colors = { c.body, c.spike, c.fin }
	return rig
end

-- Raider Gull: 18 blocks.
local function buildGull(c)
	local rig = newRig()
	local body = block(rig, V(1.4, 1.2, 2.4), CF(0, 0, 0.1), c.body)
	body.part.CastShadow = true
	local head = block(rig, V(1.2, 1.1, 1.1), CF(0, 0.55, -1.35), c.body)
	block(rig, V(0.5, 0.3, 0.9), CF(0, 0.45, -2.3), c.beak)
	joint(rig, "jaw", CF(0, 0.3, -1.9))
	block(rig, V(0.44, 0.22, 0.8), CF(0, 0.2, -2.25), c.beakTip, "jaw")
	block(rig, V(1.0, 0.2, 1.0), CF(0, 0.25, 1.7), c.wing2)
	block(rig, V(1.0, 0.18, 0.35), CF(0, 0.25, 2.35), c.tip)
	for _, s in ipairs({ -1, 1 }) do
		block(rig, V(0.12, 0.34, 0.34), CF(s * 0.61, 0.72, -1.55), c.eye, nil, glowOf(c))
		block(rig, V(0.12, 0.14, 0.55), CF(s * 0.62, 0.98, -1.55) * A(-0.45, 0, 0), c.brow)
		block(rig, V(0.25, 0.45, 0.3), CF(s * 0.35, -0.75, 0.35), c.feet)
		local wing = s < 0 and "wingL" or "wingR"
		local tip = s < 0 and "tipL" or "tipR"
		joint(rig, wing, CF(s * 0.65, 0.3, 0))
		joint(rig, tip, CF(s * 2.35, 0.3, 0.05), wing)
		block(rig, V(1.7, 0.22, 1.3), CF(s * 1.5, 0.3, 0.05), c.wing, wing)
		block(rig, V(1.5, 0.18, 1.05), CF(s * 3.1, 0.3, 0.15), c.wing2, tip)
		block(rig, V(0.7, 0.16, 0.85), CF(s * 4.15, 0.3, 0.25), c.tip, tip)
	end
	rig.head = head.part
	rig.alertOffset = 1.8
	rig.barOffset = 2.4
	rig.lift = 1
	rig.colors = { c.body, c.wing, c.beak }
	return rig
end

-- Reef Shark: 21 blocks. Its centre swims at WATER_Y - 1.5, so only the dorsal fin breaks the surface.
local function buildShark(c)
	local rig = newRig()
	local front = block(rig, V(2.6, 2.3, 3.6), CF(0, 0, -1.4), c.top)
	front.part.CastShadow = true
	block(rig, V(2.3, 0.5, 4.6), CF(0, -1.05, -1.3), c.belly)
	local snout = block(rig, V(2.1, 1.5, 1.6), CF(0, 0.15, -3.95), c.top)
	block(rig, V(1.8, 0.25, 0.15), CF(0, -0.72, -4.6), c.teeth)
	block(rig, V(1.8, 0.3, 1.4), CF(0, -0.75, -3.9), c.mouth)
	joint(rig, "jaw", CF(0, -0.8, -2.9))
	block(rig, V(1.9, 0.45, 1.8), CF(0, -1.0, -3.8), c.belly, "jaw")
	block(rig, V(1.7, 0.25, 0.15), CF(0, -0.7, -4.45), c.teeth, "jaw")
	block(rig, V(0.35, 2.2, 1.8), CF(0, 2.0, -0.9) * A(0.35, 0, 0), c.fin)
	for _, s in ipairs({ -1, 1 }) do
		block(rig, V(0.14, 0.5, 0.5), CF(s * 1.06, 0.4, -3.75), c.eye, nil, glowOf(c))
		block(rig, V(0.1, 0.26, 0.26), CF(s * 1.12, 0.36, -3.85), c.pupil)
		block(rig, V(0.14, 0.16, 0.6), CF(s * 1.08, 0.74, -3.7) * A(-0.4, 0, 0), c.brow)
		block(rig, V(1.7, 0.22, 1.1), CF(s * 1.9, -0.75, -1.4) * A(0, 0, -s * 0.35), c.fin)
	end
	joint(rig, "tail1", CF(0, 0, 0.4))
	joint(rig, "tail2", CF(0, 0.15, 3.2), "tail1")
	block(rig, V(2.0, 1.8, 3.0), CF(0, 0.1, 1.8), c.top, "tail1")
	block(rig, V(1.2, 1.2, 2.2), CF(0, 0.2, 4.2), c.top, "tail2")
	block(rig, V(0.3, 2.0, 1.1), CF(0, 1.2, 5.3) * A(0.5, 0, 0), c.fin, "tail2")
	block(rig, V(0.3, 1.2, 0.9), CF(0, -0.5, 5.2) * A(-0.5, 0, 0), c.fin, "tail2")
	-- foam where the fin cuts the surface (placed on the water, not on the body)
	local foam = block(rig, V(1.4, 0.12, 3.2), CF(0, 1.5, -0.6), WHITE)
	foam.part.Transparency = 0.3
	foam.water = true
	rig.head = snout.part
	rig.alertOffset = 3.4
	rig.barOffset = 4.2
	rig.lift = 1.5
	rig.colors = { c.top, c.belly, c.fin }
	return rig
end

-- Coral Golem: 21 blocks. The part is 6 x 7 x 4.5 and its centre is 3.5 above the ground.
local function buildGolem(c)
	local rig = newRig()
	local torso = block(rig, V(4.2, 3.0, 3.0), CF(0, 0.3, 0), c.body)
	torso.part.CastShadow = true
	block(rig, V(3.0, 1.6, 0.35), CF(0, 0.6, -1.6), c.light)
	joint(rig, "head", CF(0, 1.8, 0))
	local head = block(rig, V(2.4, 1.8, 2.2), CF(0, 2.7, -0.2), c.body, "head")
	block(rig, V(1.3, 0.28, 0.2), CF(0, 2.25, -1.32), c.mouth, "head")
	block(rig, V(0.6, 1.4, 0.6), CF(1.3, 2.3, 0.95) * A(0, 0, -0.3), c.coral1)
	block(rig, V(0.5, 1.1, 0.5), CF(-1.4, 2.15, 0.8) * A(0, 0, 0.35), c.coral2)
	block(rig, V(0.7, 0.7, 0.7), CF(0.2, 2.0, 1.3), c.coral3, nil, glowOf(c))
	block(rig, V(0.5, 0.5, 0.5), CF(-1.2, -0.5, -1.55), c.light)
	block(rig, V(0.4, 0.4, 0.4), CF(1.5, 1.2, -1.55), c.light)
	for _, s in ipairs({ -1, 1 }) do
		block(rig, V(0.56, 0.38, 0.2), CF(s * 0.55, 2.85, -1.32), c.eye, "head", Enum.Material.Neon)
		block(rig, V(0.95, 0.3, 0.3), CF(s * 0.55, 3.3, -1.3) * A(0, 0, s * 0.4), c.dark, "head")
		local leg = s < 0 and "legL" or "legR"
		local arm = s < 0 and "armL" or "armR"
		joint(rig, leg, CF(s * 1.15, -1.3, 0))
		joint(rig, arm, CF(s * 2.55, 1.3, 0))
		block(rig, V(1.7, 2.3, 1.9), CF(s * 1.15, -2.35, 0), c.dark, leg)
		block(rig, V(1.7, 0.7, 1.7), CF(s * 2.8, 1.6, 0), c.light, arm)
		block(rig, V(1.3, 2.4, 1.4), CF(s * 2.8, 0.3, 0), c.dark, arm)
		block(rig, V(1.8, 1.6, 1.8), CF(s * 2.9, -1.5, -0.1), c.body, arm)
	end
	rig.head = head.part
	rig.alertOffset = 2.4
	rig.barOffset = 3
	rig.lift = 3.5
	rig.colors = { c.body, c.coral1, c.light }
	return rig
end

local BUILD = { crab = buildCrab, puffer = buildPuffer, gull = buildGull, shark = buildShark, golem = buildGolem }

-- Effects helpers ---------------------------------------------------------------------------------------------

local function camPos()
	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

local function localRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- A short camera kick, like a guardian's strike.
local function kick(strength)
	task.spawn(function()
		for i = 1, 6 do
			local camera = workspace.CurrentCamera
			if camera then
				camera.CFrame *= CFrame.Angles(math.rad((7 - i) * strength * (i % 2 == 0 and 1 or -1)), 0, 0)
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(m)
	local pos = m.cf.Position
	local list = { models, Fx.folder() }
	if player.Character then
		table.insert(list, player.Character)
	end
	rayParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(pos + V(0, 1, 0), V(0, -(m.rig.lift + 12), 0), rayParams)
	return hit and hit.Position.Y or pos.Y - m.rig.lift
end

local function ringPart(size, transparency)
	local p = Instance.new("Part")
	p.Name = "MobTellRing"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Transparency = transparency
	p.Size = size
	p.Parent = Fx.folder()
	return p
end

local function placeRing(m)
	local ring = m.ring
	local pos = m.cf.Position
	local flatRing = CF(pos.X, ring.y, pos.Z) * A(0, 0, math.rad(90))
	ring.outer.CFrame = flatRing
	ring.inner.CFrame = flatRing * CF(0.03, 0, 0)
end

local function clearRing(m)
	local ring = m.ring
	m.ring = nil
	if ring then
		ring.outer:Destroy()
		ring.inner:Destroy()
	end
end

-- The red ground ring of a blast or slam: the outline at full size, and a fill that grows until it lands.
local function startRing(m, radius, length)
	clearRing(m)
	local outer = ringPart(V(0.2, radius * 2, radius * 2), 0.72)
	local inner = ringPart(V(0.25, 0.4, 0.4), 0.35)
	TweenService:Create(inner, TweenInfo.new(length, Enum.EasingStyle.Linear), { Size = V(0.25, radius * 2, radius * 2) }):Play()
	Debris:AddItem(outer, length + 1.5)
	Debris:AddItem(inner, length + 1.5)
	m.ring = { outer = outer, inner = inner, y = groundBelow(m) + 0.12 }
	placeRing(m)
end

-- Whether this mob is close enough, and on screen, for its effects to play.
local function inView(m)
	return m.shown and (m.cf.Position - camPos()).Magnitude <= FX_RANGE
end

-- HP pips ----------------------------------------------------------------------------------------------------------

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeBar(m, maxHp)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MobHp"
	gui.Size = UDim2.fromOffset(maxHp * 11 + 8, 14)
	gui.StudsOffset = V(0, m.rig.barOffset, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Enabled = false
	gui.Adornee = m.rig.head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(24, 20, 28)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	corner(back, 4)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = back
	local pips = {}
	for i = 1, maxHp do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(9, 8)
		pip.BorderSizePixel = 0
		pip.LayoutOrder = i
		corner(pip, 2)
		pip.Parent = back
		pips[i] = pip
	end
	back.Parent = gui
	gui.Parent = m.model
	m.bar = { gui = gui, pips = pips, max = maxHp }
end

-- Shows the pips while the mob is hurt or after you.
local function refreshBar(m)
	local part = m.part
	local maxHp = math.clamp(math.floor(tonumber(part:GetAttribute("MaxHp")) or 1), 1, 20)
	local hp = tonumber(part:GetAttribute("Hp")) or maxHp
	local s = m.state
	local show = s ~= "dead" and (hp < maxHp or s == "chase" or s == "tell" or s == "attack" or s == "recover")
	if not show and not m.bar then
		return
	end
	if not m.bar or m.bar.max ~= maxHp then
		if m.bar then
			m.bar.gui:Destroy()
		end
		makeBar(m, maxHp)
	end
	m.bar.gui.Enabled = show
	for i, pip in ipairs(m.bar.pips) do
		pip.BackgroundColor3 = i <= hp and PIP_FULL or PIP_EMPTY
	end
end

-- Attribute events ---------------------------------------------------------------------------------------------

-- The strike itself, when State turns to "attack".
local function attackFx(m)
	if not inView(m) then
		return
	end
	local part = m.part
	local tellKind = part:GetAttribute("TellKind")
	local radius = tonumber(part:GetAttribute("TellRadius")) or 0
	local pos = m.cf.Position
	local colors = m.rig.colors
	if (tellKind == "blast" or tellKind == "slam") and radius > 0 then
		local y = m.ring and m.ring.y or groundBelow(m)
		local ground = V(pos.X, y + 0.2, pos.Z)
		Fx.ring(ground, RED, radius, 0.4, 0.4)
		Fx.ring(ground + V(0, 0.1, 0), WHITE, radius * 0.7, 0.3, 0.25)
		if tellKind == "blast" then
			Fx.cubes(pos, { colors[1], colors[2], WHITE }, { spread = radius, size = 0.5, life = 0.5, up = 0.5, count = 16 })
		else
			Fx.cubes(ground + V(0, 1, 0), { colors[1], colors[3], DUST[1] }, { spread = radius, size = 0.9, life = 0.6, up = 0.6, count = 18, material = Enum.Material.SmoothPlastic })
		end
		local root = localRoot()
		if root and (root.Position - ground).Magnitude < radius + 8 then
			kick(tellKind == "slam" and 0.35 or 0.2)
		end
	elseif tellKind == "snap" then
		Fx.cubes((m.cf * CF(0, 0.3, -2.6)).Position, { WHITE, colors[1] }, { spread = 2.5, size = 0.35, life = 0.3, up = 0.5, count = 6 })
	elseif tellKind == "bite" then
		local mouth = (m.cf * CF(0, 0, -4.5)).Position
		Fx.cubes(V(mouth.X, WATER_Y + 0.3, mouth.Z), SPRAY, { spread = 5, size = 0.5, life = 0.5, up = 1, count = 14, material = Enum.Material.SmoothPlastic })
		Audio.play("Splash", m.rig.head)
	elseif tellKind == "dive" then
		Fx.cubes(m.rig.head.Position, { WHITE, colors[2] }, { spread = 3, size = 0.4, life = 0.4, up = 0.4, count = 6, material = Enum.Material.SmoothPlastic })
	end
end

local function onState(m)
	local s = m.part:GetAttribute("State") or "idle"
	local prev = m.state
	if s == prev then
		return
	end
	m.state = s
	m.stateClock = os.clock()
	if s == "tell" then
		m.tellAt = tonumber(m.part:GetAttribute("TellAt")) or 0
	end
	if s == "attack" then
		attackFx(m)
	end
	if prev == "tell" then
		clearRing(m)
	end
	if s == "dead" then
		m.deathClock = os.clock()
		m.hitClock = nil
		clearRing(m)
	elseif prev == "dead" then
		-- back from the dead somewhere else in the camp: pop in there
		m.spawnClock = os.clock()
		m.snap = true
	end
	refreshBar(m)
end

local function onTell(m)
	local part = m.part
	m.tellAt = tonumber(part:GetAttribute("TellAt")) or 0
	if part:GetAttribute("State") ~= "tell" or not inView(m) then
		return
	end
	Fx.alert(m.rig.head, "!", RED, 0.8, m.rig.alertOffset)
	local tellKind = part:GetAttribute("TellKind")
	local radius = tonumber(part:GetAttribute("TellRadius")) or 0
	if (tellKind == "blast" or tellKind == "slam") and radius > 0 then
		local left = m.tellAt + m.tellLength - workspace:GetServerTimeNow()
		startRing(m, radius, math.clamp(left, 0.05, m.tellLength))
	end
end

local function onHit(m)
	refreshBar(m)
	if not inView(m) then
		return
	end
	m.hitClock = os.clock()
	Fx.flashModel(m.model, WHITE, 0.3)
	Fx.number(m.rig.head, "-" .. Config.Swipe.damage, HIT_TEXT)
	Fx.cubes(m.rig.head.Position, m.rig.colors, { spread = 3, size = 0.4, life = 0.35, up = 0.7, count = 8 })
end

local function onDead(m)
	if not inView(m) then
		return
	end
	local pos = m.cf.Position
	Fx.cubes(pos, m.rig.colors, { spread = 10, size = 0.8, life = 0.8, up = 0.9, count = 26 })
	Fx.stars(pos + V(0, 1, 0), 6)
	Fx.ring(pos, WHITE, 5, 0.35, 0.25)
end

-- Tracking tagged parts ---------------------------------------------------------------------------------------

local mobs = {} -- [BasePart] = mob view

local function addMob(part)
	if mobs[part] or not part:IsA("BasePart") then
		return
	end
	local kind = part:GetAttribute("Kind")
	local build = BUILD[kind]
	local cfg = Config.Mobs.kinds[kind]
	if not build or not cfg then
		if kind == nil then
			-- attributes not here yet: try again when they are
			part:GetAttributeChangedSignal("Kind"):Once(function()
				if CollectionService:HasTag(part, TAG) then
					addMob(part)
				end
			end)
		end
		return
	end
	local variant = part:GetAttribute("Variant") == "Kelp" and "Kelp" or "Shoals"
	local rig = build(PALETTE[kind][variant] or PALETTE[kind].Shoals)
	rig.model.Name = part.Name
	rig.model.PrimaryPart = rig.head
	local state = part:GetAttribute("State") or "idle"
	local m = {
		part = part,
		kind = kind,
		rig = rig,
		model = rig.model,
		poses = {},
		state = state,
		stateClock = os.clock(),
		tellAt = tonumber(part:GetAttribute("TellAt")) or 0,
		tellLength = cfg.tell,
		tell = 0,
		since = 0,
		cf = part.CFrame,
		speed = 0,
		yaw = 0,
		yawRate = 0,
		phase = 0,
		seed = math.random() * 10,
		scale = 1,
		spike = 0,
		shown = false,
		snap = true,
		deathClock = -math.huge, -- already dead when we first see it: stay hidden
		nextSplash = 0,
		stepSign = true,
	}
	mobs[part] = m
	m.conn = part.AttributeChanged:Connect(function(name)
		if name == "State" then
			onState(m)
		elseif name == "TellAt" then
			onTell(m)
		elseif name == "HitAt" then
			onHit(m)
		elseif name == "DeadAt" then
			onDead(m)
		elseif name == "Hp" or name == "MaxHp" then
			refreshBar(m)
		end
	end)
	refreshBar(m)
end

local function removeMob(part)
	local m = mobs[part]
	if not m then
		return
	end
	mobs[part] = nil
	m.conn:Disconnect()
	clearRing(m)
	m.model:Destroy()
end

for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
	addMob(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(addMob)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeMob)

-- Animation ------------------------------------------------------------------------------------------------------
-- Each returns the body's offset from the eased part CFrame and the model's scale, and fills m.poses.

local function animateCrab(m, t, dt)
	local poses, seed = m.poses, m.seed
	local walk = math.clamp(m.speed / 7, 0, 1)
	m.phase += dt * (6 + 14 * walk)
	local ph = m.phase
	local body = CF(0, math.abs(math.sin(ph)) * 0.14 * walk + math.sin(t * 2 + seed) * 0.03, 0) * A(0, 0, math.sin(ph) * 0.05 * walk)
	for _, leg in ipairs(m.rig.legs) do
		local p = ph + leg.phase
		poses[leg.name] = A(0, math.sin(p) * 0.35 * walk, leg.side * (math.max(0, math.cos(p)) * 0.5 * walk + math.sin(t * 3 + leg.phase) * 0.04))
	end
	local raise, open = math.sin(t * 2.4 + seed) * 0.08, 0.12
	if math.sin(t * 3.1 + seed * 2) > 0.92 then
		open = 0.6 -- an idle snap now and then
	end
	local state = m.state
	if state == "chase" then
		raise = 0.25 + math.sin(t * 9 + seed) * 0.15
		open = math.sin(t * 14 + seed) > 0 and 0.55 or 0.05
	elseif state == "tell" then
		-- claws up and wide open, quivering
		local p = m.tell
		raise = 0.95 * math.min(1, p * 2.5) + math.sin(t * 55) * 0.05
		open = 0.75
		body = body * CF(0, -0.15 * p, 0) * A(0.15 * p, 0, 0)
	elseif state == "attack" then
		-- both claws slam down and snap shut
		local k = math.min(1, m.since / 0.1)
		raise = 0.95 - 1.25 * k
		open = 0
		body = body * CF(0, 0, -0.5 * math.sin(math.min(1, m.since / ATTACK_LUNGE) * math.pi)) * A(-0.12 * k, 0, 0)
	elseif state == "recover" then
		raise, open = -0.1, 0.3
	end
	local sway = math.sin(t * 1.7 + seed) * 0.1
	poses.clawL = A(raise, sway, 0)
	poses.clawR = A(raise, -sway, 0)
	poses.pinchL = A(open, 0, 0)
	poses.pinchR = A(open, 0, 0)
	return body, 1
end

local function animatePuffer(m, t)
	local poses, seed = m.poses, m.seed
	local body = CF(0, math.sin(t * 2.2 + seed) * 0.35, 0) * A(math.sin(t * 1.3 + seed) * 0.08, 0, math.sin(t * 1.7 + seed) * 0.08)
	local flap = math.sin(t * 10 + seed) * 0.5
	local scale, spike = 1, 0
	local state = m.state
	if state == "tell" then
		-- it gulps water and swells to 1.6x, trembling
		local p = m.tell
		scale = 1 + 0.6 * (1 - (1 - p) * (1 - p)) + math.sin(t * 40) * 0.025 * p
		spike = 0.2 * p
		flap = math.sin(t * 24 + seed) * 0.7
		body = CF(math.sin(t * 47) * 0.06 * p, math.sin(t * 2.2 + seed) * 0.35 * (1 - p), 0)
	elseif state == "attack" then
		-- the blast: spikes shoot out and it snaps back to size
		local k = math.clamp(m.since / 0.25, 0, 1)
		scale = 1.6 - 0.6 * k + math.sin(k * math.pi) * 0.15
		spike = 0.9 * (1 - k * 0.6)
	elseif state == "recover" then
		local k = math.clamp(m.since / 0.4, 0, 1)
		scale = 1 + math.sin(k * math.pi * 3) * 0.06 * (1 - k)
		spike = 0.36 * (1 - k)
	elseif state == "chase" then
		flap = math.sin(t * 16 + seed) * 0.6
	end
	poses.finL = A(0, flap, 0)
	poses.finR = A(0, -flap, 0)
	poses.tail = A(0, math.sin(t * 7 + seed) * 0.45, 0)
	m.spike = spike
	return body, scale
end

local function animateGull(m, t)
	local poses, seed = m.poses, m.seed
	local state = m.state
	-- bank into turns
	local body = A(0, 0, math.clamp(m.yawRate * 0.35, -0.7, 0.7))
	local rate, amp, jaw = 9, 0.75, 0
	if state == "tell" then
		-- hovering hard and shrieking
		rate, amp = 22, 0.9
		jaw = math.sin(t * 26) > 0 and -0.55 or -0.15
		body = CF(0, math.sin(t * 6 + seed) * 0.3, 0) * A(0.35, math.sin(t * 30) * 0.08, 0)
	elseif state == "recover" then
		rate, amp = 12, 0.85
	elseif m.speed < 2 then
		rate = 11
	end
	if state == "attack" then
		-- wings tucked back for the dive
		jaw = -0.4
		poses.wingL = A(0, 1.15, 0) * A(0, 0, 0.25)
		poses.wingR = A(0, -1.15, 0) * A(0, 0, -0.25)
		poses.tipL = A(0, 0.5, 0)
		poses.tipR = A(0, -0.5, 0)
	else
		local f = math.sin(t * rate + seed)
		local tip = math.sin(t * rate + seed - 0.7) * amp * 0.6
		poses.wingL = A(0, 0, -f * amp)
		poses.wingR = A(0, 0, f * amp)
		poses.tipL = A(0, 0, -tip)
		poses.tipR = A(0, 0, tip)
		-- the body lifts a little on each downstroke
		body = CF(0, -f * 0.12 * amp, 0) * body
	end
	poses.jaw = A(jaw, 0, 0)
	return body, 1
end

local function animateShark(m, t, dt)
	local poses = m.poses
	m.phase += dt * (3 + math.min(m.speed, 26) * 0.35)
	local ph = m.phase
	poses.tail1 = A(0, math.sin(ph) * 0.22, 0)
	poses.tail2 = A(0, math.sin(ph - 0.9) * 0.42, 0)
	local body = A(0, -math.sin(ph) * 0.06, math.sin(ph * 0.5 + m.seed) * 0.04)
	local jaw = 0.05
	local state = m.state
	if state == "tell" then
		-- jaws open, nose up out of the water
		local p = m.tell
		jaw = 0.65 * math.min(1, p * 2)
		body = CF(0, 0.7 * p, 0) * A(0.18 * p, 0, 0) * body
	elseif state == "attack" then
		-- the lunge and the snap
		local k = math.clamp(m.since / ATTACK_LUNGE, 0, 1)
		jaw = k < 0.4 and 0.65 or 0
		body = CF(0, 0.8 * (1 - k), -3 * math.sin(k * math.pi)) * A(0.18 * (1 - k), 0, 0) * body
	end
	poses.jaw = A(-jaw, 0, 0)
	return body, 1
end

local function animateGolem(m, t, dt)
	local poses, seed = m.poses, m.seed
	local walk = math.clamp(m.speed / 4, 0, 1)
	m.phase += dt * 5.5 * walk
	local ph = m.phase
	local swing = math.sin(ph) * 0.5 * walk
	poses.legL = A(swing, 0, 0)
	poses.legR = A(-swing, 0, 0)
	local armL, armR, spread = -swing * 0.7, swing * 0.7, 0.06
	local body = CF(0, -math.abs(math.sin(ph)) * 0.22 * walk + math.sin(t * 1.4 + seed) * 0.05, 0) * A(0, math.sin(ph) * 0.06 * walk, math.sin(ph) * 0.04 * walk)
	local nod = 0
	local state = m.state
	if state == "tell" then
		-- both arms up over its head, leaning back
		local e = 1 - (1 - math.min(1, m.tell * 1.4)) ^ 2
		armL, armR = 2.7 * e, 2.7 * e
		spread = 0.06 + 0.25 * e
		body = CF(math.sin(t * 40) * 0.05 * m.tell, 0.25 * e, 0) * A(0.16 * e, 0, 0)
		nod = 0.2 * e
	elseif state == "attack" then
		-- and down they come
		local k = math.clamp(m.since / 0.12, 0, 1)
		armL = 2.7 - 3.1 * k
		armR = armL
		spread = 0.31 - 0.2 * k
		body = CF(0, 0.25 - 0.55 * k, 0) * A(0.16 - 0.4 * k, 0, 0)
		nod = -0.2 * k
	elseif state == "recover" then
		local k = math.clamp(m.since / 0.8, 0, 1)
		armL = -0.4 * (1 - k)
		armR = armL
		body = CF(0, -0.3 * (1 - k), 0) * A(-0.24 * (1 - k), 0, 0)
	end
	poses.armL = A(armL, 0, -spread)
	poses.armR = A(armR, 0, spread)
	poses.head = A(nod, math.sin(t * 0.7 + seed) * 0.15, 0)
	-- a puff of dust at each heavy footfall
	local down = math.sin(ph) >= 0
	if down ~= m.stepSign then
		m.stepSign = down
		if walk > 0.5 and (m.cf.Position - camPos()).Magnitude < 120 then
			local foot = (m.cf * CF(down and 1.15 or -1.15, -3.3, 0)).Position
			Fx.cubes(foot, DUST, { spread = 2.2, size = 0.4, life = 0.35, up = 0.5, count = 3, material = Enum.Material.SmoothPlastic })
		end
	end
	return body, 1
end

local ANIMATE = { crab = animateCrab, puffer = animatePuffer, gull = animateGull, shark = animateShark, golem = animateGolem }

-- Placing ---------------------------------------------------------------------------------------------------------

local partList, cframeList = {}, {}
local count = 0

local function push(part, cf)
	count += 1
	partList[count] = part
	cframeList[count] = cf
end

-- the shark's foam lies flat on the sea, under wherever the fin is
local function onWater(world, origin)
	return CF(world.X, WATER_Y + 0.08, world.Z) * origin.Rotation
end

local function applyScale(m, scale)
	if math.abs(scale - m.scale) < 0.005 then
		return
	end
	m.scale = scale
	for _, piece in ipairs(m.rig.pieces) do
		piece.part.Size = piece.size * scale
	end
end

local function placeStill(m)
	local origin = m.cf
	for _, piece in ipairs(m.rig.pieces) do
		local world = origin * piece.rest
		push(piece.part, piece.water and onWater(world, origin) or world)
	end
	m.placedAt = origin
end

local function placeAnimated(m, body, scale)
	local rig, poses = m.rig, m.poses
	for _, name in ipairs(rig.order) do
		local j = rig.joints[name]
		local w = j.pivot * (poses[name] or CFrame.identity) * j.inv
		if j.parent then
			w = rig.joints[j.parent].world * w
		end
		j.world = w
	end
	local origin = m.cf
	local root = origin * body
	local spike = m.spike
	for _, piece in ipairs(rig.pieces) do
		local cf = piece.rest
		if piece.joint then
			cf = rig.joints[piece.joint].world * cf
		end
		if piece.out then
			cf += piece.out * spike
		end
		if scale ~= 1 then
			cf = CF(cf.Position * scale) * cf.Rotation
		end
		local world = root * cf
		push(piece.part, piece.water and onWater(world, origin) or world)
	end
	m.placedAt = nil
end

local function setShown(m, shown)
	if m.shown == shown then
		return
	end
	m.shown = shown
	m.model.Parent = shown and models or nil
	if shown then
		m.snap = true
		m.placedAt = nil
	else
		clearRing(m)
	end
end

-- The frame loop ------------------------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
	local cam = camPos()
	local clock = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local alpha = 1 - math.exp(-dt * SMOOTH)
	local step = math.max(dt, 1e-3)
	table.clear(partList)
	table.clear(cframeList)
	count = 0
	for part, m in pairs(mobs) do
		if not part.Parent then
			removeMob(part)
			continue
		end
		local target = part.CFrame
		local distance = (target.Position - cam).Magnitude
		local dead = m.state == "dead"
		if distance > SHOW_RANGE or (dead and (clock - m.deathClock >= DEATH_SECONDS or distance > ANIMATE_RANGE)) then
			setShown(m, false)
			continue
		end
		setShown(m, true)
		-- ease after the server's part (a jump, like a respawn, doesn't count as moving)
		local prev = m.cf
		local look
		if m.snap or (target.Position - prev.Position).Magnitude > SNAP_DISTANCE then
			m.cf = target
			m.snap = false
			look = target.LookVector
			m.speed = 0
			m.yawRate = 0
			m.yaw = math.atan2(-look.X, -look.Z)
		else
			m.cf = prev:Lerp(target, alpha)
			-- how fast it moves and turns, for the animations
			local moved = m.cf.Position - prev.Position
			m.speed += (V(moved.X, 0, moved.Z).Magnitude / step - m.speed) * math.min(1, dt * 8)
			look = m.cf.LookVector
			local yaw = math.atan2(-look.X, -look.Z)
			local turn = (yaw - m.yaw + math.pi) % (math.pi * 2) - math.pi
			m.yaw = yaw
			m.yawRate += (turn / step - m.yawRate) * math.min(1, dt * 6)
		end
		if distance > ANIMATE_RANGE then
			-- far off: hold the rest pose, and only move it when it moves
			applyScale(m, 1)
			local placed = m.placedAt
			if not placed or (placed.Position - m.cf.Position).Magnitude > 0.05 or placed.LookVector:Dot(look) < 0.9995 then
				placeStill(m)
			end
		else
			m.tell = m.state == "tell" and math.clamp((serverNow - m.tellAt) / m.tellLength, 0, 1) or 0
			m.since = clock - m.stateClock
			local body, scale = ANIMATE[m.kind](m, clock, dt)
			if m.hitClock then
				-- a hop back from the swipe
				local a = clock - m.hitClock
				if a < HOP_SECONDS then
					local s = math.sin(a / HOP_SECONDS * math.pi)
					body = CF(0, s * (m.kind == "shark" and 0.4 or 1.1), 0.6 * s) * A(0.3 * s, 0, 0) * body
				else
					m.hitClock = nil
				end
			end
			if dead then
				-- shrink and spin away
				local a = clock - m.deathClock
				scale *= math.max(0.05, 1 - a / DEATH_SECONDS)
				body = body * A(0, a * 12, 0)
			elseif m.spawnClock then
				local a = clock - m.spawnClock
				if a < POP_SECONDS then
					local k = a / POP_SECONDS
					scale *= 0.2 + 0.8 * k + math.sin(k * math.pi) * 0.25
				else
					m.spawnClock = nil
				end
			end
			applyScale(m, scale)
			placeAnimated(m, body, scale)
			if m.ring then
				if m.ring.outer.Parent then
					placeRing(m)
				else
					m.ring = nil
				end
			end
			-- spray off the shark's fin while it hunts
			if m.kind == "shark" and m.speed > 12 and clock >= m.nextSplash and distance < 160 then
				m.nextSplash = clock + 0.14
				local fin = (m.cf * CF(0, 0, -1.5)).Position
				Fx.cubes(V(fin.X, WATER_Y + 0.2, fin.Z), SPRAY, { spread = 2.2, size = 0.35, life = 0.35, up = 0.9, count = 3, material = Enum.Material.SmoothPlastic })
			end
		end
	end
	if count > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
