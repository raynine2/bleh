-- Tidebound: Eggfall: the rod in motion (Master Patches 5 and 7), for every player on your screen.
-- Until the animator's ids are pasted into Animations.luau, this script works out the arm pose for each step
-- (TideboundMotion applies it to the shoulder, elbow and waist joints through MotionBus), bends the rod, draws the
-- spring line to the bobber and plays each rod's sounds and effects. Once an id is filled in, that step
-- plays the animation instead and this script only bends the rod and draws the line.
-- Your own cast follows FishingFeel (the reel minigame in TideboundClient); other players' casts follow the
-- attributes the server puts on their characters (FishPhase, FishAt, FishBite, FishSpot, FishName, FishTier).
-- Patch 10: the whole body fishes (legs and hips through MotionBus), a fish shadow circles and nibbles before
-- the bite, the reel sprays and the fish leaps, the line glows red under tension, the catch shoots a geyser and
-- a pillar of light in its tier's colour, and you can swipe your rod at mobs (click, F or the SWIPE button).

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
local VfxLibrary = require(Shared:WaitForChild("VfxLibrary")) -- GDD Section 8: bait splash and water impact
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local Fx = require(Shared:WaitForChild("Fx"))
local WaterFx = require(Shared:WaitForChild("WaterFx")) -- 12 Oct 2026 FX remake: real splashes, no rings/cubes/pillars
local RodFx = require(Shared:WaitForChild("RodFx")) -- 13 Oct 2026: each rod's own swing trails, hits and finisher

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
	-- Fisch video (12 Oct 2026): the catch is held high over your head in both hands
	hold = { shR = 2.95, elR = 0.2, shL = 2.95, elL = 0.2, waist = -0.06, inR = -0.3, inL = 0.3 },
	-- Fishing Fight (12 Oct 2026): both hands high on the rod, leaning way back against the fish
	strain = { shR = 1.4, elR = 0.6, shL = 1.25, elL = 0.85, waist = 0.22, inR = -0.18, inL = 0.42 },
}

-- Patch 10: the whole body fishes too, in TideboundMotion's keys (hips and shoulders swing forward with +X,
-- knees bend with -X, +X on the root leans back, rootUp drops the hips in studs). A relaxed stance while you
-- wait, weight back on the windup, a lunge on the release, a braced squat leaning back on the reel, a yank
-- forward when the line snaps, and up on your toes as the fish flies out.
local BODY = {
	rest = { rootX = 0, rootZ = 0, rootUp = -0.08, neckX = 0, hipRX = 0.12, hipRZ = 0.06, kneeRX = -0.22, ankRX = 0.1, hipLX = -0.05, hipLZ = -0.06, kneeLX = -0.12, ankLX = 0.06 },
	windup = { rootX = 0.12, rootZ = 0, rootUp = -0.22, neckX = 0.1, hipRX = -0.35, hipRZ = 0.08, kneeRX = -0.45, ankRX = 0.2, hipLX = 0.4, hipLZ = -0.06, kneeLX = -0.2, ankLX = -0.1 },
	release = { rootX = -0.22, rootZ = 0, rootUp = -0.42, neckX = -0.1, hipRX = -0.5, hipRZ = 0.05, kneeRX = -0.25, ankRX = 0.35, hipLX = 0.75, hipLZ = -0.05, kneeLX = -0.9, ankLX = 0.25 },
	hook = { rootX = 0.18, rootZ = 0, rootUp = -0.5, neckX = 0.15, hipRX = 0.55, hipRZ = 0.12, kneeRX = -0.95, ankRX = 0.4, hipLX = 0.75, hipLZ = -0.12, kneeLX = -1.0, ankLX = 0.3 },
	struggle = { rootX = 0.22, rootZ = 0, rootUp = -0.55, neckX = 0.1, hipRX = 0.6, hipRZ = 0.16, kneeRX = -1.05, ankRX = 0.45, hipLX = 0.85, hipLZ = -0.16, kneeLX = -1.1, ankLX = 0.3 },
	pulled = { rootX = -0.3, rootZ = 0, rootUp = -0.35, neckX = -0.2, hipRX = -0.3, hipRZ = 0.05, kneeRX = -0.3, ankRX = 0.3, hipLX = 0.7, hipLZ = -0.05, kneeLX = -0.8, ankLX = 0.2 },
	stumble = { rootX = 0.35, rootZ = 0.08, rootUp = -0.3, neckX = 0.3, hipRX = 0.5, hipRZ = 0.1, kneeRX = -0.6, ankRX = 0.1, hipLX = -0.2, hipLZ = -0.1, kneeLX = -0.3, ankLX = 0 },
	flip = { rootX = 0.1, rootZ = 0, rootUp = 0.05, neckX = 0.35, hipRX = 0.05, hipRZ = 0.06, kneeRX = -0.1, ankRX = -0.25, hipLX = 0.05, hipLZ = -0.06, kneeLX = -0.1, ankLX = -0.25 },
	hold = { rootX = 0.05, rootZ = 0, rootUp = 0, neckX = 0.1, hipRX = 0, hipRZ = 0.1, kneeRX = -0.05, ankRX = 0, hipLX = 0, hipLZ = -0.1, kneeLX = -0.05, ankLX = 0 },
	strain = { rootX = 0.3, rootZ = 0, rootUp = -0.62, neckX = -0.22, hipRX = 0.72, hipRZ = 0.22, kneeRX = -1.15, ankRX = 0.5, hipLX = 0.95, hipLZ = -0.22, kneeLX = -1.2, ankLX = 0.35 },
}
for name, body in pairs(BODY) do
	for key, value in pairs(body) do
		POSE[name][key] = value
	end
end

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

-- Stances (13 Oct 2026, HJHJH): in the fighting stance you hold the rod like a weapon in a low guard, tip
-- forward, swaying a little as you breathe. Swapping to it (X) twirls the rod up over your head with a twist
-- of the waist and drops you into the guard; swapping back swings it over your shoulder onto your back.
POSE.guard = { shR = 0.95, elR = 0.6, shL = 0.95, elL = 1.05, waist = 0.08, inR = -0.25, inL = 0.55, rootX = 0.1, rootZ = 0, rootUp = -0.3, neckX = 0.05, hipRX = 0.42, hipRZ = 0.14, kneeRX = -0.7, ankRX = 0.28, hipLX = -0.15, hipLZ = -0.14, kneeLX = -0.45, ankLX = 0.18 }
POSE.twirl = { shR = 3.0, elR = 0.15, shL = 0.4, elL = 0.6, waist = -0.12, inR = -0.35, inL = 0.3, rootX = -0.1, rootZ = 0, rootUp = 0, neckX = -0.15, hipRX = 0.05, hipRZ = 0.08, kneeRX = -0.1, ankRX = -0.15, hipLX = 0.05, hipLZ = -0.08, kneeLX = -0.1, ankLX = -0.15 }
POSE.stow = { shR = 2.4, elR = 1.9, shL = 0.4, elL = 0.8, waist = -0.04, inR = -0.4, inL = 0.3, rootX = 0, rootZ = 0, rootUp = -0.05, neckX = 0, hipRX = 0.1, hipRZ = 0.06, kneeRX = -0.15, ankRX = 0.06, hipLX = -0.05, hipLZ = -0.06, kneeLX = -0.1, ankLX = 0.05 }
local SWAP = 0.45

local function stanceOf(p, character)
	if p == player then
		return FishingFeel.stance, FishingFeel.stanceAt
	end
	return character:GetAttribute("Stance") or "fish", character:GetAttribute("StanceAt") or -10
end

-- Every rod's own fighting stance (13 Oct 2026, HJHJH: "make the fighting stance different and unique with
-- every rod"). Each rod has its own guard, its own draw move when you swap to it (a flourish, a glowing arc in
-- the rod's colours and a soft burst at the tip), and its own idle motion while you stand in it:
--   Drift       Quarterstaff: rod across the body in both hands, rocking the weight, re-gripping
--   Coral       Reef Dancer: rod out in one hand, the other arm raised, flowing like kelp; draws with a twirl
--   Stormline   Lightning Rod: rod held up at the sky, bouncing on the toes, twitching with static
--   Abyssal     Undertow: deep crouch, rod trailing behind, rising and sinking like a swell
--   Riftcaster  Fencer: side-on en garde, tip circling; draws with a salute
--   Celestial   Star Staff: rod upright like a staff, floating, palm open; draws a halo
-- HJHJH (13 Oct 2026): five rods follow anime characters' fighting styles:
--   CrimsonCrow Itachi: calm and upright, one hand raised in a hand sign, rod low, barely moving; draws with
--               both hands together in a seal
--   Jackpot     Hakari: his dance, a stomping side shuffle with the arms pumping; draws with arms thrown up
--   ThiefTome   Chrollo: standing tall reading the open book at the chest, turning pages
--   SunRubber   Luffy: wide low stance, right fist cocked back, left arm out, rubbery bounce, now and then a
--               hand up to hold the hat; draws with a windmill arm
--   Boundless   Gojo: floating, leaning back, chin up, left hand in the pocket, right hand raised in front of
--               the face in the domain sign; draws a full void circle
local STANCE_KEYS = { "shR", "elR", "shL", "elL", "waist", "inR", "inL", "waistY", "waistZ", "neckY", "rootX", "rootZ", "rootUp", "neckX", "hipRX", "hipRZ", "kneeRX", "ankRX", "hipLX", "hipLZ", "kneeLX", "ankLX" }
local function blend(a, b, s)
	local out = {}
	for _, key in ipairs(STANCE_KEYS) do
		local x = a[key] or 0
		out[key] = x + ((b[key] or 0) - x) * s
	end
	return out
end
local function over(base, changes)
	local out = table.clone(base)
	for key, value in pairs(changes) do
		out[key] = value
	end
	return out
end
local function pulse(clock, every, length)
	local loop = clock % every
	return loop < length and math.sin(loop / length * math.pi) or 0
end
-- arcs for the draw: `side` is the upright plane through your facing (0 forward, 90 up, 180 behind), `flat`
-- lies around you (0 right, -90 in front), `front` stands across your chest (0 right, 90 up)
local STANCES = {
	Drift = {
		guard = over(POSE.guard, { shR = 0.75, elR = 1.1, inR = -0.45, shL = 1.25, elL = 0.75, inL = 0.6, waist = 0.05, waistY = 0.3, rootX = 0.05, rootUp = -0.35, hipRX = 0.4, hipRZ = 0.25, kneeRX = -0.7, ankRX = 0.3, hipLX = -0.25, hipLZ = -0.25, kneeLX = -0.55, ankLX = 0.25 }),
		flourish = POSE.twirl, up = 0.16, spin = 0.7,
		arcs = { { "side", -30, 240, 4, 0.8 } },
		idle = function(p, c)
			local rock = math.sin(c * 1.5)
			p.rootZ += 0.05 * rock
			p.waistY += 0.08 * rock
			p.hipRZ += 0.04 * rock
			p.hipLZ += 0.04 * rock
			local grip = pulse(c, 2.8, 0.3)
			p.elL += 0.3 * grip
			p.shL -= 0.15 * grip
			p.rootUp += 0.025 * math.sin(c * 2.2)
		end,
	},
	Coral = {
		guard = over(POSE.guard, { shR = 1.25, elR = 0.15, inR = -0.35, shL = 2.1, elL = 0.35, inL = -0.9, waist = -0.05, waistY = -0.25, waistZ = 0.08, neckY = 0.2, rootX = -0.02, rootUp = -0.12, hipRX = -0.1, hipRZ = 0.1, kneeRX = -0.35, ankRX = 0.15, hipLX = 0.35, hipLZ = -0.05, kneeLX = -0.05, ankLX = -0.45 }),
		flourish = over(POSE.twirl, { shR = 2.4, elR = 0.3, inR = 0.3, shL = 2.4, elL = 0.3, inL = -0.3, waist = -0.05, rootUp = 0.05, ankRX = -0.3, ankLX = -0.3 }),
		up = 0.22, spin = 1.1,
		arcs = { { "flat", -90, 320, 3.4, 0.7, 0.4 } },
		idle = function(p, c)
			p.waistY += 0.18 * math.sin(c * 1.4)
			p.waistZ += 0.06 * math.sin(c * 2.8)
			p.shL += 0.15 * math.sin(c * 1.4 + 1)
			p.elL += 0.2 * math.sin(c * 1.4 + 2)
			p.shR += 0.06 * math.sin(c * 1.4)
			p.inR += 0.06 * math.cos(c * 1.4)
			p.ankLX += 0.08 * math.sin(c * 1.4 + 0.5)
		end,
	},
	Stormline = {
		guard = over(POSE.guard, { shR = 2.25, elR = 0.15, inR = 0.15, shL = 1.0, elL = 1.5, inL = 0.35, waist = 0.05, rootX = 0.05, rootUp = -0.22, hipRX = 0.3, hipRZ = 0.2, kneeRX = -0.55, ankRX = 0.1, hipLX = -0.25, hipLZ = -0.2, kneeLX = -0.45, ankLX = -0.15 }),
		flourish = over(POSE.twirl, { shR = 3.0, elR = 0, inR = 0.05, shL = 0.3, elL = 0.4, rootUp = 0.1, ankRX = -0.35, ankLX = -0.35 }),
		up = 0.12, spin = 0.3,
		arcs = { { "side", -20, 110, 5, 0.6 } },
		idle = function(p, c)
			p.rootUp += 0.07 * math.abs(math.sin(c * 6))
			p.ankRX -= 0.1 * math.abs(math.sin(c * 6))
			p.ankLX -= 0.1 * math.abs(math.sin(c * 6))
			local zap = pulse(c, 1.3, 0.14)
			local jit = zap * math.sin(c * 70)
			p.neckY += 0.25 * jit
			p.shR += 0.08 * jit
			p.waistZ += 0.05 * jit
		end,
	},
	Abyssal = {
		guard = over(POSE.guard, { shR = -0.9, elR = 0.25, inR = 0.2, shL = 1.1, elL = 0.45, inL = 0.15, waist = -0.25, waistY = -0.2, neckX = 0.15, rootX = -0.2, rootUp = -0.75, hipRX = 0.9, hipRZ = 0.25, kneeRX = -1.4, ankRX = 0.5, hipLX = 0.5, hipLZ = -0.25, kneeLX = -1.2, ankLX = 0.6 }),
		flourish = over(POSE.guard, { shR = -0.3, elR = 0.2, shL = 0.4, elL = 0.3, waist = -0.4, rootUp = -1.0, hipRX = 1.0, kneeRX = -1.6, hipLX = 0.6, kneeLX = -1.4 }),
		up = 0.2, spin = -0.5,
		arcs = { { "flat", 0, -200, 4, 0.9, -2.2 } },
		idle = function(p, c)
			local swell = math.sin(c * 1.1)
			p.rootUp += 0.08 * swell
			p.waistZ += 0.07 * math.sin(c * 0.55)
			p.shL += 0.1 * math.sin(c * 1.1 + 1.2)
			p.shR -= 0.08 * swell
			p.neckY += 0.12 * math.sin(c * 0.5)
		end,
	},
	Riftcaster = {
		guard = over(POSE.guard, { shR = 0.85, elR = 0.35, inR = 0.05, shL = 1.5, elL = 1.7, inL = -1.0, waist = 0, waistY = -0.7, neckY = 0.6, rootUp = -0.32, hipRX = 0.55, hipRZ = 0.18, kneeRX = -0.8, ankRX = 0.3, hipLX = -0.35, hipLZ = -0.25, kneeLX = -0.55, ankLX = 0.25 }),
		flourish = over(POSE.guard, { shR = 1.9, elR = 1.3, inR = -0.4, shL = 0.3, elL = 0.3, inL = 0.2, waist = 0, rootUp = -0.05, hipRX = 0.1, kneeRX = -0.15, hipLX = 0, kneeLX = -0.15 }),
		up = 0.2, spin = 0,
		arcs = { { "side", 95, -95, 4.5, 0.6 } },
		idle = function(p, c)
			local step = math.sin(c * 2.6)
			p.rootUp += 0.03 * math.abs(step)
			p.hipRX += 0.08 * step
			p.kneeRX -= 0.08 * step
			p.inR += 0.05 * math.cos(c * 5)
			p.elR += 0.06 * math.sin(c * 5)
		end,
	},
	Celestial = {
		guard = over(POSE.guard, { shR = 0.7, elR = 1.55, inR = -0.2, shL = 1.1, elL = 0.35, inL = -0.75, waist = -0.04, neckX = 0.15, rootX = 0.02, rootUp = 0.05, hipRX = 0.05, hipRZ = 0.06, kneeRX = -0.15, ankRX = -0.3, hipLX = 0.02, hipLZ = -0.06, kneeLX = -0.2, ankLX = -0.35 }),
		flourish = over(POSE.twirl, { shR = 2.6, elR = 0.5, inR = 0.2, shL = 2.6, elL = 0.5, inL = -0.4, neckX = 0.35, rootUp = 0.2, waist = -0.1 }),
		up = 0.22, spin = 0,
		arcs = { { "front", -90, 340, 3.2, 1.0, 0.6 } },
		idle = function(p, c)
			p.rootUp += 0.12 * (0.5 + 0.5 * math.sin(c * 0.9))
			p.shL += 0.08 * math.sin(c * 0.9 + 0.8)
			p.neckX += 0.05 * math.sin(c * 0.45)
			p.waistZ += 0.03 * math.sin(c * 0.45)
		end,
	},
	CrimsonCrow = {
		guard = over(POSE.guard, { shR = 0.25, elR = 0.35, inR = -0.05, shL = 1.35, elL = 1.55, inL = 0.55, waist = 0.02, waistY = -0.15, neckX = -0.12, rootX = 0, rootUp = -0.05, hipRX = 0.08, hipRZ = 0.08, kneeRX = -0.12, ankRX = 0.04, hipLX = -0.05, hipLZ = -0.08, kneeLX = -0.1, ankLX = 0.05 }),
		flourish = over(POSE.guard, { shR = 1.3, elR = 1.5, inR = -0.55, shL = 1.3, elL = 1.5, inL = 0.55, waist = 0, neckX = -0.15, rootX = 0, rootUp = -0.1, hipRX = 0.05, kneeRX = -0.15, hipLX = 0, kneeLX = -0.15 }),
		up = 0.2, spin = 0,
		arcs = { { "front", -30, 110, 4, 0.8 }, { "front", 210, -110, 4, 0.8 } },
		idle = function(p, c)
			local breath = math.sin(c * 1.0)
			p.rootUp += 0.015 * breath
			p.shL += 0.02 * breath
			p.neckY += 0.2 * math.sin(c * 0.35)
			local sign = pulse(c, 4, 0.5)
			p.elL += 0.15 * sign
			p.inL += 0.1 * sign
		end,
	},
	Jackpot = {
		guard = over(POSE.guard, { shR = 0.9, elR = 1.3, inR = 0.3, shL = 0.9, elL = 1.3, inL = -0.3, waist = 0.04, waistY = 0, rootX = 0, rootUp = -0.2, hipRX = 0.15, hipRZ = 0.18, kneeRX = -0.4, ankRX = 0.15, hipLX = 0.15, hipLZ = -0.18, kneeLX = -0.4, ankLX = 0.15 }),
		flourish = over(POSE.twirl, { shR = 2.6, elR = 0.1, inR = 0.7, shL = 2.6, elL = 0.1, inL = -0.7, rootUp = 0.1, neckX = 0.25 }),
		up = 0.18, spin = 0.8,
		arcs = { { "flat", -90, 360, 2.6, 0.6, 0.6 } },
		idle = function(p, c)
			local ph = c * 6
			local side = math.sin(ph)
			local beat = math.abs(math.sin(ph * 2))
			p.rootZ += 0.1 * side
			p.waistZ -= 0.1 * side
			p.waistY += 0.2 * side
			p.hipRZ += 0.12 * side
			p.hipLZ += 0.12 * side
			-- the stomp: each knee comes up in turn
			p.hipRX += 0.35 * math.max(0, side)
			p.kneeRX -= 0.6 * math.max(0, side)
			p.hipLX += 0.35 * math.max(0, -side)
			p.kneeLX -= 0.6 * math.max(0, -side)
			-- the arms pump in turn
			p.shR += 0.5 * side
			p.shL -= 0.5 * side
			p.rootUp += 0.06 * beat
			p.neckX += 0.08 * beat
		end,
	},
	ThiefTome = {
		guard = over(POSE.guard, { shR = 0.95, elR = 1.2, inR = -0.35, shL = 1.15, elL = 1.35, inL = 0.4, waist = 0.04, waistY = 0.1, neckX = -0.25, neckY = -0.1, rootX = 0.02, rootUp = -0.05, hipRX = 0.05, hipRZ = 0.08, kneeRX = -0.1, ankRX = 0.04, hipLX = -0.05, hipLZ = -0.08, kneeLX = -0.1, ankLX = 0.04 }),
		flourish = over(POSE.guard, { shR = 0.5, elR = 0.3, inR = 0.4, shL = 1.9, elL = 0.6, inL = 0.2, waist = 0, neckX = 0.1, rootX = 0, rootUp = -0.05, hipRX = 0.05, kneeRX = -0.1, hipLX = 0, kneeLX = -0.1 }),
		up = 0.18, spin = 0.25,
		arcs = { { "front", 200, -140, 2.2, 0.5, 0.8 } },
		idle = function(p, c)
			local page = pulse(c, 2.4, 0.45)
			p.inR += 0.45 * page
			p.elR -= 0.2 * page
			p.rootUp += 0.015 * math.sin(c * 1.1)
			p.neckY += 0.08 * math.sin(c * 0.6)
		end,
	},
	SunRubber = {
		guard = over(POSE.guard, { shR = -0.5, elR = 2.3, inR = 0.35, shL = 1.5, elL = 0.2, inL = 0.1, waist = -0.12, waistY = 0.45, neckX = -0.05, rootX = -0.08, rootUp = -0.45, hipRX = -0.25, hipRZ = 0.35, kneeRX = -0.6, ankRX = 0.3, hipLX = 0.55, hipLZ = -0.35, kneeLX = -0.75, ankLX = 0.25 }),
		flourish = over(POSE.twirl, { shR = 3.0, elR = 0, inR = 0.4, shL = 0.6, elL = 0.3, rootUp = -0.1, waistY = -0.3 }),
		up = 0.16, spin = -0.9,
		arcs = { { "side", -60, 300, 3.5, 0.9 } },
		idle = function(p, c)
			local bounce = math.abs(math.sin(c * 4.2))
			p.rootUp += 0.1 * bounce - 0.04
			p.kneeRX -= 0.12 * (1 - bounce)
			p.kneeLX -= 0.12 * (1 - bounce)
			p.shL += 0.08 * math.sin(c * 8.4)
			p.elL += 0.1 * math.sin(c * 8.4 + 1)
			-- now and then a hand up on the hat
			local hat = pulse(c, 5, 1.2)
			p.shL += (2.6 - p.shL) * hat
			p.elL += (1.7 - p.elL) * hat
			p.inL += (0.5 - p.inL) * hat
		end,
	},
	Boundless = {
		guard = over(POSE.guard, { shR = 1.55, elR = 1.5, inR = -0.55, shL = -0.15, elL = 0.5, inL = -0.12, waist = 0.12, waistY = -0.1, waistZ = 0.05, neckX = 0.12, rootX = 0.06, rootUp = 0.12, hipRX = 0.05, hipRZ = 0.07, kneeRX = -0.1, ankRX = -0.25, hipLX = -0.05, hipLZ = -0.07, kneeLX = -0.15, ankLX = -0.25 }),
		flourish = over(POSE.twirl, { shR = 3.05, elR = 0.05, inR = 0.1, shL = 3.05, elL = 0.05, inL = -0.1, rootUp = 0.25, waist = 0.3, neckX = 0.4 }),
		up = 0.22, spin = 0,
		arcs = { { "front", -90, 350, 4.5, 1.2, 0.8 } },
		idle = function(p, c)
			p.rootUp += 0.1 * (0.5 + 0.5 * math.sin(c * 0.9))
			p.waistZ += 0.04 * math.sin(c * 0.6)
			p.neckY += 0.15 * math.sin(c * 0.4)
			p.shR += 0.03 * math.sin(c * 0.9 + 1)
		end,
	},
}
STANCES.Default = STANCES.Drift

local function stanceFor(rodId)
	return STANCES[rodId] or STANCES.Default
end

-- the draw: the rod's arc(s) traced around you and a soft burst at the tip, on every screen
local function drawFx(character, rodId)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, arc in ipairs(stanceFor(rodId).arcs) do
		local plane, from, sweep, radius, width, lift = arc[1], arc[2], arc[3], arc[4], arc[5], arc[6] or 0.4
		local base
		if plane == "flat" then
			base = root.CFrame * CFrame.new(0, lift, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		elseif plane == "front" then
			base = root.CFrame * CFrame.new(0, lift, -0.6)
		else
			base = root.CFrame * CFrame.new(0.8, lift, 0) * CFrame.Angles(0, math.pi / 2, 0)
		end
		RodFx.swoosh(base, radius, math.rad(from), math.rad(sweep), rodId, width, 0.4)
	end
	task.delay(0.22, function()
		local tip = character.Parent and RodFx.tipOf(character)
		if tip then
			RodFx.burst(tip, rodId, 0.6)
		end
	end)
end

-- the pose `u` seconds after the last swap, and how much of it shows (the arms let go after a swap to fishing)
local function stancePose(stance, u, clock, rodId)
	local st = stanceFor(rodId)
	if stance == "fight" then
		local pose
		if u < st.up then
			pose = blend(POSE.rest, st.flourish, smooth(u / st.up))
		elseif u < SWAP then
			pose = blend(st.flourish, st.guard, easeOut((u - st.up) / (SWAP - st.up)))
		else
			pose = blend(st.guard, st.guard, 0)
		end
		if u < SWAP then
			pose.waistY += math.sin(math.clamp(u / SWAP, 0, 1) * math.pi) * st.spin
		end
		-- the idle motion eases in once you've settled into the guard
		local settle = smooth((u - SWAP * 0.6) / 0.3)
		if settle > 0 then
			local moved = table.clone(pose)
			st.idle(moved, clock)
			for key, value in pairs(moved) do
				pose[key] += (value - pose[key]) * settle
			end
		end
		if math.abs(pose.neckY) < 1e-3 then
			pose.neckY = nil
		end
		return pose, 1
	end
	local k = math.clamp(u / SWAP, 0, 1)
	local pose = blend(st.guard, POSE.stow, smooth(math.min(1, k * 1.6)))
	if math.abs(pose.neckY) < 1e-3 then
		pose.neckY = nil
	end
	return pose, 1 - smooth(math.max(0, (k - 0.55) / 0.45))
end

-- Which Patch 5 step is playing. `biteAt` is nil for your own cast (the minigame says when it bites).
local function stepOf(phase, t, biteAt)
	if phase == "charge" then
		-- Fisch video: holding the click to charge the cast (FischUI's power bar)
		return "CastCharge", t
	elseif phase == "cast" then
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
local function poseOf(step, u, tension, fight)
	if step == "CastCharge" then
		-- the rod swings back over your shoulder and trembles as the power builds
		local power = FishingFeel.power or 0
		local pose = lerpPose(POSE.rest, POSE.windup, smooth(u / 0.3))
		pose.shR += 0.12 * power + 0.015 * math.sin(u * 40) * power
		pose.waist += 0.06 * power
		pose.rootUp -= 0.08 * power
		return pose, 0.12 + 0.3 * power
	elseif step == "CastWindup" then
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
		-- Fishing Fight (12 Oct 2026): you strain against the fish with everything you've got. Both hands high on
		-- the rod, leaning way back; each heave hauls the rod up and back, then you dip it and crank the slack in.
		-- Arms and legs shake with the effort, the fish drags you toward its side (you twist and lean against it,
		-- eyes on it), its warning makes you brace low, and its lunge yanks your arms out and jerks you forward.
		local side = fight and fight.side or 0
		local thrash = fight and fight.thrash or 0
		local age = fight and fight.age or 9
		local pose = lerpPose(POSE.hook, POSE.strain, smooth(u / 0.3))
		local heave = 0.5 + 0.5 * math.sin(u * (4.6 + 2.4 * tension))
		heave = heave * heave * (3 - 2 * heave)
		if thrash == 1 then
			-- brace: sink low and dig in
			local s = smooth(age / 0.3)
			pose = lerpPose(pose, POSE.struggle, 0.35 * s)
			pose.rootUp -= 0.22 * s
			pose.kneeRX -= 0.3 * s
			pose.kneeLX -= 0.3 * s
			pose.rootX += 0.08 * s
			heave = heave * (1 - s) + s
		elseif thrash == 2 then
			-- yanked: arms pulled out toward the water, body jerked forward, then fighting back
			local jolt = math.max(0, 1 - age / 0.55)
			local s = jolt * jolt
			pose = lerpPose(pose, POSE.pulled, 0.75 * s)
			pose.rootX -= 0.18 * s
			heave *= 1 - s
		end
		local crank = u * 12
		-- the haul: the rod sweeps up and back, then dips while the left hand cranks
		pose.shR += 0.32 * heave - 0.12
		pose.elR -= 0.12 * heave
		pose.shL += 0.22 * heave + 0.07 * math.sin(crank)
		pose.elL += 0.22 * math.cos(crank) * (1 - 0.6 * heave)
		pose.waist += 0.16 * heave + 0.1 * tension
		pose.rootX += 0.12 * heave + 0.1 * tension
		pose.rootUp -= 0.1 * heave
		pose.kneeRX -= 0.2 * heave + 0.12 * tension
		pose.kneeLX -= 0.2 * (1 - heave) + 0.12 * tension
		pose.hipRX += 0.1 * heave
		pose.hipLX += 0.1 * (1 - heave)
		-- effort: everything trembles, harder the more it pulls
		local tremble = 0.018 + 0.05 * tension + (thrash > 0 and 0.03 or 0)
		pose.shR += tremble * math.sin(u * 47)
		pose.shL += tremble * math.sin(u * 53 + 1.3)
		pose.elR += tremble * 0.6 * math.sin(u * 59 + 0.4)
		pose.waist += tremble * 0.7 * math.sin(u * 43 + 2.1)
		pose.kneeRX += tremble * 0.8 * math.sin(u * 37)
		pose.kneeLX += tremble * 0.8 * math.sin(u * 41 + 0.7)
		-- the fish drags you toward its side: lean away from it, twist toward it, watch it
		pose.rootZ += 0.11 * side + 0.05 * math.sin(u * 2.3)
		pose.hipRZ += 0.06 * side
		pose.hipLZ += 0.06 * side
		pose.waistY = -0.4 * side
		pose.waistZ = -0.08 * side
		pose.neckY = -0.5 * side
		return pose, math.min(1, 0.62 + 0.3 * tension + (thrash == 2 and 0.25 or 0) + 0.08 * heave)
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
		-- a happy bounce while you show it off
		local pose = lerpPose(POSE.flip, POSE.hold, smooth(u / T.hold))
		pose.rootUp += 0.18 * math.abs(math.sin(u * 7)) * math.max(0, 1 - u / 1.6)
		return pose, 0
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

-- 12 Oct 2026 FX remake: droplets and spray (WaterFx) instead of plain white specks. Small counts are a
-- spray, big ones a full splash.
local function waterBurst(position, count, speed)
	if count >= 14 then
		WaterFx.splash(position, math.clamp(count / 26, 0.5, 3))
	else
		WaterFx.spray(position, count + 2, speed + 2)
	end
end

-- 12 Oct 2026 FX remake: HJHJH didn't like the neon circles, so this is now soft foam settling on the water
local function splashRing(position, size)
	WaterFx.foam(position, math.clamp(size * 0.45, 0.8, 7), size >= 5 and 3 or 1)
end

-- Patch 10: a dark fish shape under the water that circles the bobber, closing in as the bite comes.
local function shadowOf(rec)
	if not rec.shadow then
		local shadow = Instance.new("Part")
		shadow.Name = "FishShadow"
		shadow.Shape = Enum.PartType.Ball
		shadow.Anchored = true
		shadow.CanCollide = false
		shadow.CanQuery = false
		shadow.CanTouch = false
		shadow.CastShadow = false
		shadow.Color = Color3.fromRGB(16, 36, 58)
		shadow.Transparency = 0.45
		shadow.Size = Vector3.new(1.3, 0.35, 2.8)
		shadow.Parent = fx
		rec.shadow = shadow
	end
	return rec.shadow
end

-- a geyser of real spray (or, for a catch, motes of light lifting off the water) instead of a plastic pillar
local function column(position, color, height, width, _life, neon)
	if neon then
		WaterFx.rise(position, color, height)
	else
		WaterFx.spout(position, height * 0.6, width)
	end
end

local WATER_CUBES = { Color3.fromRGB(120, 220, 255), Color3.fromRGB(220, 250, 255) }
local LINE_RED = Color3.fromRGB(255, 70, 60)

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
	if rec.shadow then
		rec.shadow:Destroy()
		rec.shadow = nil
	end
	if rec.fightFish then
		rec.fightFish:Destroy()
		rec.fightFish = nil
	end
	rec.fightLunge, rec.landFrom = nil, nil
	rec.milestone = 0
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
	local sequence = lineColor(look)
	rec.lineBase, rec.lineSequence = sequence.Keypoints[1].Value, sequence
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
		-- Fisch video: the fish shows its colour as soon as it lands in your hands (no slow reveal climb)
		return result.fish, result.tier, FishingFeel.startedAt + T.flip, os.clock()
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

-- Fishing Fight (12 Oct 2026) ------------------------------------------------------------------------------
-- The hooked fish comes up and fights where you can see it, like the Sea Leviathan in HJHJH's inspiration
-- video: it runs left and right with the reel bar's fish, shakes its head at the surface, rolls and churns
-- under a red "!!" before it lunges, then breaches. Small fish leap clear in an arc; Legendary and up rear
-- right out of the sea, turn on you shaking the line, and crash back down. It stays a dark silhouette (the
-- reveal still shows what it is), and the hook rides in its mouth so the line follows every move.

-- Where the hooked fish is pulling. side: -1 (your left) to 1 (your right); thrash: 0 swimming, 1 warning,
-- 2 lunging; age: seconds into the thrash. Your own fish follows the reel bar (FishingFeel); other players'
-- fish wander and lunge on a loop, so everyone nearby sees a fight.
local function fightOf(rec)
	if rec.player == player then
		local cast = FishingFeel.cast
		return {
			side = math.clamp(((FishingFeel.fishPos or 0.5) - 0.5) * 2, -1, 1),
			thrash = FishingFeel.thrash or 0,
			age = os.clock() - (FishingFeel.thrashAt or 0),
			tier = cast and cast.difficulty or 1,
			heldAt = FishingFeel.heldAt or 0,
		}
	end
	local t = (rec.t or 0) + (rec.player.UserId % 7)
	local cycle = t % 4.2
	local thrash, age = 0, 9
	if cycle > 3.0 then
		thrash, age = 2, cycle - 3.0
	elseif cycle > 2.45 then
		thrash, age = 1, cycle - 2.45
	end
	local tier = rec.character:GetAttribute("FishTier") or 0
	return { side = math.sin(t * 0.8) * 0.8, thrash = thrash, age = age, tier = tier > 0 and tier or 2, heldAt = 0 }
end

local FIGHT_DARK = Color3.fromRGB(18, 30, 48)
local fightRng = Random.new()

local function lungeLength(tier)
	return tier >= 5 and 1.45 or (0.7 + 0.05 * tier)
end

-- Moves the fighting fish for this frame and returns where its mouth (the hook) is.
local function fightFish(rec, spot, step, u, clock)
	if rec.shadow then
		rec.shadow:Destroy()
		rec.shadow = nil
	end
	local fight = fightOf(rec)
	local tier = math.clamp(math.floor(fight.tier), 1, #Config.Tiers)
	local isMe = rec.player == player
	local waterY = spot.Y - 0.15
	if not rec.fightFish then
		local biome = Config.Biomes[1]
		local pool = biome and biome.fish and biome.fish[tier]
		local name = pool and #pool > 0 and pool[fightRng:NextInteger(1, #pool)] or "Fish"
		local model, length = FishModels.build(name, tier)
		-- big fish fight big: Epic and up grow, and Mythic and Celestial are sea monsters
		local scale = tier >= 6 and (2.4 + (tier - 6)) or (tier >= 4 and (1.3 + (tier - 4) * 0.35) or 1)
		if scale ~= 1 then
			pcall(function()
				model:ScaleTo(scale)
			end)
		end
		FishModels.paint(model, FIGHT_DARK)
		model.Parent = fx
		rec.fightFish, rec.fightLen = model, (length or 2.5) * scale
		rec.fightAt, rec.fightLast, rec.fightLunge = spot, clock, nil
		rec.fightState, rec.fightHeld = 0, fight.heldAt
		rec.fightNextSplash, rec.fightNextFlop, rec.fightFlopAt = 0, clock + 0.7, nil
		-- it breaks the surface where the bobber went under
		Audio.play("Splash", model.PrimaryPart)
		waterBurst(spot, 16 + tier * 3, 9 + tier)
		splashRing(spot, 4 + rec.fightLen * 0.5)
	end
	local model, len = rec.fightFish, rec.fightLen
	local dt = math.clamp(clock - rec.fightLast, 0, 0.1)
	rec.fightLast = clock
	local tension = rec.tension or 0
	-- "away from you" and "to your right", from where you stand
	local root = rec.character:FindFirstChild("HumanoidRootPart")
	local away = root and Vector3.new(spot.X - root.Position.X, 0, spot.Z - root.Position.Z) or Vector3.new(0, 0, -1)
	away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-away.Z, 0, away.X)
	-- it runs side to side with the reel bar's fish, always pulling away from you
	local range = 6 + len * 1.0
	local target = spot + right * (fight.side * range) + away * (1 + len * 0.25 + 1.2 * math.sin(clock * 0.9))
	local before = rec.fightAt
	rec.fightAt = before:Lerp(Vector3.new(target.X, spot.Y, target.Z), math.min(1, dt * (fight.thrash == 2 and 4.5 or 2)))
	local lateral = (rec.fightAt - before):Dot(right) / math.max(dt, 1e-3)
	local heading = (away + right * math.clamp(lateral * 0.25, -1.2, 1.2)).Unit
	local at = Vector3.new(rec.fightAt.X, waterY, rec.fightAt.Z)
	local body = at - Vector3.new(0, len * 0.06, 0)
	local pitch = 0.06
	local yaw = math.sin(clock * (8 + 6 * tension)) * (0.18 + 0.25 * tension)
	local roll = math.sin(clock * 5.3) * 0.2
	-- the warning, the lunge, and a lunge you held through
	if fight.thrash ~= rec.fightState then
		rec.fightState = fight.thrash
		if fight.thrash == 1 then
			Fx.alert(model.PrimaryPart, "!!", Color3.fromRGB(255, 60, 60), 0.75, 2 + len * 0.3)
			Audio.play("TickTick", model.PrimaryPart)
			if isMe then
				FishingFeel.shake(0.12, 0.3)
			end
		elseif fight.thrash == 2 then
			rec.fightLunge = { start = clock, big = tier >= 5, landed = false, length = lungeLength(tier) }
			Audio.play("Splash", model.PrimaryPart)
			waterBurst(at, 24 + tier * 4, 12 + tier * 2)
			splashRing(at, 5 + len * 0.6)
			column(at, Color3.fromRGB(200, 240, 255), 6 + len * 1.2, 1.5 + len * 0.25, 0.7, false)
			if isMe then
				FishingFeel.shake(0.22 + 0.04 * tier, 0.35)
				MotionBus.kick = { at = os.clock(), amount = 3 + tier, length = 0.45 }
			end
		end
	end
	if fight.heldAt ~= rec.fightHeld then
		rec.fightHeld = fight.heldAt
		if fight.heldAt > 0 then
			Fx.alert(model.PrimaryPart, "HELD!", Color3.fromRGB(255, 220, 90), 0.9, 2.5 + len * 0.3)
			WaterFx.glimmer(at + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 220, 90), 0.6)
			Audio.play("TickTick", model.PrimaryPart)
		end
	end
	local lunge = rec.fightLunge
	local la = lunge and (clock - lunge.start) or math.huge
	if lunge and la < lunge.length then
		if lunge.big then
			-- the rise: it rears out of the sea, turns on you and shakes the line, then crashes down
			heading = heading:Lerp(-away, smooth(la / 0.35)).Unit
			local rise
			if la < 0.35 then
				rise = easeOut(la / 0.35)
			elseif la < 1.15 then
				rise = 1 + 0.06 * math.sin((la - 0.35) * 9)
				yaw += math.sin(clock * 15) * 0.32
				roll += math.sin(clock * 11) * 0.12
			else
				rise = 1 - smooth((la - 1.15) / 0.3)
			end
			pitch = 0.06 + 1.15 * rise
			body = at + Vector3.new(0, len * 0.42 * rise - len * 0.06, 0)
			if la < 1.15 and clock >= rec.fightNextSplash then
				-- water pours off it
				rec.fightNextSplash = clock + 0.05
				waterBurst(at + Vector3.new(0, len * 0.3 * rise, 0), 3, 3)
			end
		else
			-- the leap: clear of the water in an arc, twisting
			local s = la / lunge.length
			local height = 2.5 + len * 0.9
			body = at + Vector3.new(0, height * 4 * s * (1 - s), 0)
			pitch = (0.5 - s) * 2.2
			roll = s * math.pi * 2 * (tier >= 3 and 1 or 0.5)
			yaw = math.sin(clock * 20) * 0.25
			if clock >= rec.fightNextSplash then
				rec.fightNextSplash = clock + 0.05
				waterBurst(body, 2, 3)
			end
		end
	elseif lunge and not lunge.landed then
		-- it crashes back into the sea
		lunge.landed = true
		Audio.play("Splash", model.PrimaryPart)
		waterBurst(at, 26 + tier * 4, 13 + tier * 2)
		splashRing(at, 6 + len * 0.7)
		for i = 1, 2 do
			task.delay(i * 0.15, splashRing, at, 6 + len * 0.7 + i * 4)
		end
		if lunge.big then
			Audio.play("SlamBoom", model.PrimaryPart)
			column(at, Color3.fromRGB(200, 240, 255), 10 + len * 1.4, 2 + len * 0.3, 0.9, false)
		end
		if isMe then
			FishingFeel.shake(0.18 + (lunge.big and 0.25 or 0), 0.3)
		end
	else
		-- a head-shake flop every second or so: head up out of the water, thrashing the line
		if clock >= rec.fightNextFlop then
			rec.fightNextFlop = clock + fightRng:NextNumber(0.9, 1.6) - 0.3 * tension
			rec.fightFlopAt = clock
			waterBurst(at + heading * len * 0.4, 6 + tier, 6 + tier)
			splashRing(at + heading * len * 0.4, 1.5 + len * 0.3)
		end
		local flop = rec.fightFlopAt and (clock - rec.fightFlopAt) / 0.45 or 2
		if flop < 1 then
			local f = math.sin(flop * math.pi)
			pitch += 0.55 * f
			body += Vector3.new(0, len * 0.18 * f, 0)
			roll += math.sin(flop * math.pi * 4) * 0.5 * f
		end
		if fight.thrash == 1 then
			-- the warning: it rolls and churns the water white
			roll += math.sin(clock * 22) * 0.9
			yaw *= 1.8
			if clock >= rec.fightNextSplash then
				rec.fightNextSplash = clock + 0.06
				waterBurst(at, 4 + tier, 7 + tier)
			end
		elseif math.abs(lateral) > 2.5 and clock >= rec.fightNextSplash then
			-- a wake behind it as it runs
			rec.fightNextSplash = clock + 0.08
			waterBurst(at - heading * len * 0.45, 3, 5)
		end
	end
	local cf = CFrame.lookAt(body, body + heading) * CFrame.Angles(pitch, yaw, roll)
	model:PivotTo(cf)
	return (cf * CFrame.new(0, 0, -len * 0.5)).Position
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
				rec.pose, rec.bend = poseOf(step, u, rec.tension, fightOf(rec))
				rec.weight = math.min(1, rec.weight + dt / 0.12)
				playStep(rec, step)
			else
				rec.step = nil
				rec.bend = 0
				local stance, stanceAt = stanceOf(p, character)
				local since = workspace:GetServerTimeNow() - stanceAt
				local rodId = RodFx.rodOf(character)
				if stance == "fight" and since < 0.25 and rec.drawnAt ~= stanceAt then
					rec.drawnAt = stanceAt
					drawFx(character, rodId)
				end
				if stance == "fight" or since < SWAP then
					local pose, show = stancePose(stance, since, os.clock(), rodId)
					rec.pose = pose
					rec.weight = math.min(show, rec.weight + dt / 0.12)
				else
					rec.weight = math.max(0, rec.weight - dt / 0.25)
				end
				playStep(rec, nil)
			end
			-- TideboundMotion poses the arms from this (it owns every joint, both joint types)
			local animated = rec.step and Animations[rec.step] and Animations[rec.step].id ~= ""
			if rec.weight > 0 and not animated then
				MotionBus.arms[character] = { weight = rec.weight, pose = rec.pose, body = rec.pose }
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
			WaterFx.splash(spot, 0.4)
			local effect = CAST_FX[look.castFx]
			if effect and AT_LANDING[look.castFx] then
				effect(rec, tipPos, spot)
			end
		end
		local clock = os.clock()
		position = spot + Vector3.new(0, 0.1 + 0.15 * math.sin(clock * 2.4), 0)
		slackTarget = 2.5
		if step == "IdleFishing" then
			-- Patch 10: rings spread from the bobber, a fish shadow circles in, and it nibbles before the bite
			local cast = FishingFeel.cast
			local biteAt = rec.biteAt or (rec.player == player and cast and math.max(cast.biteWait, CAST_END)) or (t + 3)
			local biteIn = biteAt - t
			if clock >= (rec.nextRipple or 0) then
				rec.nextRipple = clock + 1.6
				WaterFx.foam(spot, 1.1, 1)
			end
			local shadow = shadowOf(rec)
			local radius = 0.8 + 5 * math.clamp(biteIn / 4, 0, 1)
			local angle = clock * (1.2 + 1.6 * (1 - math.clamp(biteIn / 4, 0, 1)))
			local at = spot + Vector3.new(math.cos(angle) * radius, -0.55, math.sin(angle) * radius)
			shadow.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
			if biteIn < 1.6 and biteIn > 0.15 and math.sin(clock * 8.5) > 0.9 then
				position -= Vector3.new(0, 0.25, 0)
				if once(rec, "nibble" .. math.floor(clock * 8.5 / (math.pi * 2))) then
					Audio.play("Plop", rec.bobber.PrimaryPart, 1.2)
					WaterFx.droplets(spot, 5, 5, 40, 0.1)
					WaterFx.foam(spot, 0.9, 1)
				end
			end
		elseif step == "BiteTell" then
			if once(rec, "tell") then
				Audio.play("TickTick", rec.bobber.PrimaryPart)
				-- the video's bite alert: a red "!" pops over the bobber
				Fx.alert(rec.bobber.PrimaryPart, "!", Color3.fromRGB(255, 64, 64), 0.7, 2)
				-- Patch 10: the fish slams the bobber: a burst of water, cubes and a ring, and a "!" over your head too
				WaterFx.splash(spot, 0.9)
				local head = rec.character:FindFirstChild("Head")
				if head then
					Fx.alert(head, "!", Color3.fromRGB(255, 64, 64), 0.8, 3)
				end
				if rec.player == player then
					FishingFeel.shake(0.22, 0.2)
				end
				if rec.shadow then
					rec.shadow:Destroy()
					rec.shadow = nil
				end
			end
			position -= Vector3.new(0, 0.3 * math.abs(math.sin(u / T.tell * math.pi * 2)), 0)
			slackTarget = 0.4
		elseif step == "HookSet" or step == "ReelStruggle" then
			if step == "HookSet" and once(rec, "hook") then
				Audio.play("Snap", rec.bobber.PrimaryPart)
				WaterFx.droplets(spot, 10, 9, 30, 0.12)
				if rec.player == player then
					FishingFeel.shake(0.15, 0.15)
				end
			end
			-- Fishing Fight (12 Oct 2026): the hooked fish comes up and fights at the surface; the hook rides in
			-- its mouth, so the line follows every run, flop, leap and rise (fightFish)
			position = fightFish(rec, spot, step, u, clock)
			slackTarget = 0
			if step == "ReelStruggle" then
				local loop = math.floor(u / T.struggle)
				if once(rec, "loop" .. loop) then
					Audio.play("ReelClick", rec.rod.PrimaryPart)
				end
				-- spray where the line cuts the water, the line glowing red as it pulls, a burst at every milestone
				if clock >= (rec.nextSpray or 0) then
					rec.nextSpray = clock + 0.14 - 0.06 * rec.tension
					waterBurst(Vector3.new(position.X, spot.Y, position.Z), 2 + math.floor(3 * rec.tension), 4 + 6 * rec.tension)
				end
				if rec.beam and rec.lineBase then
					rec.beam.Color = ColorSequence.new(rec.lineBase:Lerp(LINE_RED, math.clamp(rec.tension, 0, 1) * 0.85))
				end
				if rec.player == player and FishingFeel.milestone > (rec.milestone or 0) then
					rec.milestone = FishingFeel.milestone
					WaterFx.glimmer(position + Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 220, 90), 0.4 + rec.milestone * 0.2)
					Audio.play("TickTick", rec.bobber.PrimaryPart)
				end
				-- Patch 10: holding the fish in the sweet spot throws gold sparkles off the line
				if rec.player == player and FishingFeel.sweet and clock >= (rec.nextSweet or 0) then
					rec.nextSweet = clock + 0.12
					WaterFx.droplets(position + Vector3.new(0, 0.3, 0), 3, 6, 45, 0.1)
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
	-- Fishing Fight: the fish you fought is the one that flies into your hands
	if rec.fightFish then
		rec.landFrom = rec.fightAt
		rec.fightFish:Destroy()
		rec.fightFish = nil
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
		-- 12 Oct 2026 FX remake: the fish tears out of the sea in a real splash and a spout of spray
		local from = rec.landFrom or spot
		WaterFx.splash(from, 1.6)
		WaterFx.spout(from, 6, 1.8)
	end
	local hands = handsOf(character)
	if not hands then
		return
	end
	local held = CFrame.lookAt(hands + Vector3.new(0, 0.5, 0), hands + Vector3.new(0, 0.5, 0) + root.CFrame.RightVector)
	if rec.step == "LandFlip" and spot then
		-- the fish arcs out of the water, flips twice and drops into your hands (Patch 5, half speed)
		local s = math.clamp(rec.u / T.flip, 0, 1)
		local start = (rec.landFrom or spot) - Vector3.new(0, 0.4, 0)
		local height = 4 + (hands - start).Magnitude * 0.2
		local position = start:Lerp(held.Position, s) + Vector3.new(0, height * 4 * s * (1 - s), 0)
		local spin = CFrame.lookAt(position, position + (held.Position - start).Unit) * CFrame.Angles(s * math.pi * 4, 0, 0)
		rec.fish:PivotTo(s > 0.8 and spin:Lerp(held, (s - 0.8) / 0.2) or spin)
		-- a trail of droplets behind it
		if s < 0.85 and os.clock() >= (rec.nextDrip or 0) then
			rec.nextDrip = os.clock() + 0.04
			WaterFx.drip(position, 2)
		end
	else
		if once(rec, "hold") then
			Audio.play("Fanfare", root)
			WaterFx.drip(hands + Vector3.new(0, 0.3, 0), 8)
		end
		rec.fish:PivotTo(held)
	end
	-- dark silhouette until the reveal's climb reaches the fish's tier, then its colour
	if clock >= showAt then
		local color = Config.Tiers[tier] and Config.Tiers[tier].color or Color3.new(1, 1, 1)
		if once(rec, "colour") then
			-- the catch pops in its tier's colour: cubes, a ring, and gold bolts from Epic up
			-- 12 Oct 2026 FX remake: a soft glimmer in the tier's colour, brighter for rarer fish
			WaterFx.glimmer(hands, color, 0.6 + tier * 0.35)
			-- Patch 10: a pillar of light in the tier's colour rises where it came from, taller for rarer fish
			if spot and tier >= 3 then
				column(rec.landFrom or spot, color, 14 + tier * 8, 1.6 + tier * 0.3, 1.2 + tier * 0.15, true)
			end
			if tier >= 5 then
				WaterFx.glimmer(hands + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 220, 90), 2.5)
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
			WaterFx.droplets(rec.bobber.PrimaryPart.Position, 8, 7, 40, 0.1)
		end
		-- Fishing Fight: the fish breaks free and dives
		if rec.fightFish and rec.fightAt then
			waterBurst(rec.fightAt, 20, 11)
			splashRing(rec.fightAt, 5 + (rec.fightLen or 3) * 0.5)
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

-- Patch 17: the rod combo everyone sees (the server sets SwingStep, then SwingAt). Hit 1, Bonk: a white chop arc
-- and a cartoon bonk. Hit 2, Whirl: a rainbow ring all the way round you. Hit 3, the Big Fish Slap: a giant
-- googly-eyed fish pops into your hands and gets slammed into the ground: spikes, shock rings, stars, confetti.
local SLASH = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 240, 255) }
local GOLD = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 180, 60) }
local WORDS = {
	{ "BONK!", "BONKA!", "WHAP!", "BOINK!", "TUNG!", "BOP!" },
	{ "WHEEE!", "SPINNY!", "WHIRL-O!", "BRRRR!", "SKRRT!", "ZOOM!" },
	{ "FISH SLAP!", "TUNG TUNG SLAP!", "SLAPPUCCINO!", "MEGA BONK!", "SPLAT-O-RAMA!", "TRALALA SLAP!" },
}
local WORD_COLORS = {
	{ Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 220, 255) },
	{ Color3.fromRGB(255, 160, 250), Color3.fromRGB(120, 140, 255) },
	{ Color3.fromRGB(255, 250, 120), Color3.fromRGB(255, 90, 60) },
}
local comboRng = Random.new()

local function neonSeg(size, color, cf, transparency)
	local seg = Instance.new("Part")
	seg.Name = "Slash"
	seg.Anchored = true
	seg.CanCollide = false
	seg.CanQuery = false
	seg.CanTouch = false
	seg.CastShadow = false
	seg.Material = Enum.Material.Neon
	seg.Color = color
	seg.Transparency = transparency or 0.15
	seg.Size = size
	seg.CFrame = cf
	seg.Parent = fx
	return seg
end

local function fadeSeg(seg, life)
	TweenService:Create(seg, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = seg.Size * Vector3.new(1, 0.2, 1.4) }):Play()
	Debris:AddItem(seg, life + 0.05)
end

-- Where the ground is under `at` (ignoring people and effects), or a guess.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(at, fallback)
	local list = { fx, Fx.folder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "TideboundMobs", "TideboundFoliage", "TideboundLife" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	groundParams.FilterDescendantsInstances = list
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), groundParams)
	return hit and hit.Position or fallback
end

-- The giant fish for the slam: a few parts posed every frame off your hand, held by the tail.
local FISH_PARTS = {
	-- name, size, offset from the grip (fish hangs along -Y), colour, ellipsoid?
	{ "Body", Vector3.new(1.9, 3.4, 1.5), CFrame.new(0, -2.3, 0), Color3.fromRGB(255, 150, 60), true },
	{ "Belly", Vector3.new(1.5, 2.6, 0.9), CFrame.new(0, -2.4, -0.35), Color3.fromRGB(255, 225, 170), true },
	{ "TailL", Vector3.new(1.4, 0.8, 0.25), CFrame.new(-0.45, -0.35, 0) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(255, 110, 50), false },
	{ "TailR", Vector3.new(1.4, 0.8, 0.25), CFrame.new(0.45, -0.35, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(255, 110, 50), false },
	{ "Fin", Vector3.new(0.25, 1.2, 0.9), CFrame.new(0, -2.0, 0.85), Color3.fromRGB(255, 110, 50), false },
	{ "Lips", Vector3.new(0.9, 0.55, 0.7), CFrame.new(0, -4.0, -0.25), Color3.fromRGB(255, 120, 170), true },
	{ "EyeL", Vector3.new(0.95, 0.95, 0.95), CFrame.new(-0.72, -3.2, -0.25), Color3.fromRGB(255, 255, 255), true },
	{ "EyeR", Vector3.new(0.95, 0.95, 0.95), CFrame.new(0.72, -3.2, -0.25), Color3.fromRGB(255, 255, 255), true },
	{ "PupilL", Vector3.new(0.45, 0.45, 0.45), CFrame.new(-1.08, -3.25, -0.3), Color3.fromRGB(20, 20, 30), true },
	{ "PupilR", Vector3.new(0.45, 0.45, 0.45), CFrame.new(1.08, -3.25, -0.3), Color3.fromRGB(20, 20, 30), true },
}

local function giantFish(rec, start, root)
	local character = rec.character
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local parts = {}
	for _, def in ipairs(FISH_PARTS) do
		local p = neonSeg(def[2] * 0.05, def[4], hand.CFrame, 0)
		p.Name = "GiantFish" .. def[1]
		p.Material = Enum.Material.SmoothPlastic
		if def[5] then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		table.insert(parts, { part = p, def = def })
	end
	Fx.cubes(hand.Position, { Color3.new(1, 1, 1), Color3.fromRGB(255, 200, 120) }, { spread = 3, size = 0.5, life = 0.35, count = 10 })
	Audio.play("FishPop", root, comboRng:NextNumber(0.9, 1.1))
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local u = os.clock() - start
		if u > 0.95 or not hand.Parent then
			connection:Disconnect()
			for _, item in ipairs(parts) do
				item.part:Destroy()
			end
			return
		end
		-- pop in (overshoot), squash on the slam, then shrink away
		local grow = u < 0.12 and math.sin(math.clamp(u / 0.12, 0, 1) * math.pi * 0.62) / math.sin(math.pi * 0.62) * 1.15 or 1
		if u > 0.8 then
			grow = math.max(0.02, 1 - (u - 0.8) / 0.12)
		end
		local squashY, squashX, flop = 1, 1, 0
		if u > 0.36 then
			local e = math.exp(-(u - 0.36) * 8)
			squashY = 1 - 0.35 * e * math.cos((u - 0.36) * 30)
			squashX = 1 + 0.3 * e * math.cos((u - 0.36) * 30)
			flop = 0.4 * e * math.sin((u - 0.36) * 26)
		elseif u > 0.12 then
			flop = 0.15 * math.sin(u * 30) -- wiggling, it does not want to be here
		end
		local grip = hand.CFrame * CFrame.new(0, -0.6, 0) * CFrame.Angles(flop, 0, 0)
		local look = u * 18
		for _, item in ipairs(parts) do
			local def = item.def
			local off = def[3]
			local pos = off.Position * Vector3.new(squashX, squashY, squashX) * grow
			if def[1] == "PupilL" or def[1] == "PupilR" then
				-- googly eyes rolling around
				pos += Vector3.new(0, math.sin(look) * 0.18, math.cos(look) * 0.18) * grow
			end
			item.part.Size = def[2] * Vector3.new(squashX, squashY, squashX) * grow
			item.part.CFrame = grip * CFrame.new(pos) * (off - off.Position)
		end
	end)
end

-- 13 Oct 2026 (HJHJH: the last hit's FX were "very chunky and not high quality"): every swing is now a smooth
-- glowing arc in your rod's colours (RodFx.swoosh, curved beams) and every hit soft particles and light in that
-- rod's style (RodFx.hit, RodFx.finisher). The neon blocks, rings, cubes, floating words and the cartoon fish
-- (giantFish above, kept but unused) are gone from the combo.
local function bonk(rec, root, isMe)
	local rodId = RodFx.rodOf(rec.character)
	Audio.play("SwingWhoosh", root, comboRng:NextNumber(0.9, 1.1))
	task.delay(0.05, function()
		if not root.Parent then
			return
		end
		-- a chop arc from over the shoulder down to the ground in front, a little to the right
		local base = root.CFrame * CFrame.new(0.8, 0.4, 0) * CFrame.Angles(0, math.pi / 2, 0)
		RodFx.swoosh(base, 4.5, math.rad(110), math.rad(-160), rodId, 0.9, 0.3)
	end)
	task.delay(0.12, function()
		if not root.Parent then
			return
		end
		local at = (root.CFrame * CFrame.new(0.6, -1.2, -4.5)).Position
		RodFx.hit(at, rodId, 1)
		Audio.play("SwingBonk", root, comboRng:NextNumber(0.9, 1.15))
		if isMe then
			FishingFeel.shake(0.07, 0.1)
		end
	end)
end

local function whirl(rec, root, isMe)
	local rodId = RodFx.rodOf(rec.character)
	Audio.play("SwingSpin", root, comboRng:NextNumber(0.9, 1.1))
	-- an arc traced all the way round you as you spin
	local base = root.CFrame * CFrame.new(0, 0.3, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	RodFx.swoosh(base, 5, -math.pi / 2, -math.pi * 1.9, rodId, 0.75, 0.45)
	task.delay(0.17, function()
		if not root.Parent then
			return
		end
		RodFx.hit(root.Position - Vector3.new(0, 1.8, 0), rodId, 2)
		Audio.play("SwingDing", root, comboRng:NextNumber(0.9, 1.2))
		if isMe then
			FishingFeel.shake(0.1, 0.12)
		end
	end)
end

local function fishSlap(rec, root, isMe, start)
	local rodId = RodFx.rodOf(rec.character)
	-- the finisher: a big overhead arc, then the rod's own impact (RodFx.finisher)
	local base = root.CFrame * CFrame.new(0.5, 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0)
	RodFx.swoosh(base, 5.5, math.rad(120), math.rad(-175), rodId, 1.4, 0.42)
	task.delay(math.max(0, 0.36 - (os.clock() - start)), function()
		if not root.Parent then
			return
		end
		local guess = (root.CFrame * CFrame.new(0, -3, -5.5)).Position
		local at = groundBelow(guess, guess) + Vector3.new(0, 0.3, 0)
		RodFx.finisher(at, rodId)
		Audio.play("SlamBoom", root)
		Audio.play("SlamDing", root, comboRng:NextNumber(0.95, 1.1))
		if isMe then
			-- a punch of the camera's zoom and a shake (TideboundClient owns the field of view, via MotionBus)
			RodFx.kick(7, 0.32, 0.4)
		end
	end)
end

local function slash(rec, age)
	local root = rec.character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local step = rec.character:GetAttribute("SwingStep") or 1
	local isMe = rec.player == player
	local start = os.clock() - math.max(age, 0)
	if step == 2 then
		whirl(rec, root, isMe)
	elseif step == 3 then
		fishSlap(rec, root, isMe, start)
	else
		bonk(rec, root, isMe)
	end
end

RunService.RenderStepped:Connect(function()
	local serverNow = workspace:GetServerTimeNow()
	for _, rec in pairs(rigs) do
		local swingAt = rec.character:GetAttribute("SwingAt")
		if swingAt ~= rec.swingAt then
			rec.swingAt = swingAt
			if swingAt and serverNow - swingAt < 0.4 then
				slash(rec, serverNow - swingAt)
			end
		end
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
		elseif rec.bobber or rec.fish or rec.fightFish then
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

-- Patch 10: swipe your rod at mobs with a click, F, or the SWIPE touch button, any time you aren't fishing.
-- The server checks every hit (Mobs.swipe) and sets SwingAt, which plays the swing above for everyone.
-- Patch 17: keep clicking for the 3-hit combo (Config.Swipe.combo). A click a little early is remembered and
-- swings the moment it can, so mashing flows; three pips under your character show where you are (13 Oct 2026:
-- each rod names its own moves and colours them, see RodFx.MOVES).
do
	local ContextActionService = game:GetService("ContextActionService")
	local UserInputService = game:GetService("UserInputService")
	local S = Config.Swipe
	local swipeEvent = nil
	task.spawn(function()
		swipeEvent = Shared:WaitForChild("Remotes"):WaitForChild("Swipe")
	end)

	-- the combo readout (13 Oct 2026 rework, HJHJH: "very clean like Fisch" and "different on every single rod"):
	-- the move's name in small italic letters over three thin pips. Every rod has its own move names, colour and
	-- pip shape (RodFx.MOVES): bars, dots, slants, lines or diamonds; the rainbow rods' pips shimmer.
	local WHITE = Color3.new(1, 1, 1)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TideboundCombo"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.66, 0)
	holder.Size = UDim2.fromOffset(220, 34)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local moveLabel = Instance.new("TextLabel")
	moveLabel.BackgroundTransparency = 1
	moveLabel.Size = UDim2.new(1, 0, 0, 18)
	moveLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
	moveLabel.TextSize = 16
	moveLabel.TextColor3 = WHITE
	moveLabel.Parent = holder
	local moveStroke = Instance.new("UIStroke")
	moveStroke.Thickness = 1.2
	moveStroke.Color = Color3.fromRGB(12, 12, 16)
	moveStroke.Transparency = 0.3
	moveStroke.Parent = moveLabel
	local labelShine = Instance.new("UIGradient")
	labelShine.Color = RodModels.RAINBOW
	labelShine.Enabled = false
	labelShine.Parent = moveLabel
	local pips = {}
	for i = 1, #S.combo do
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		pip.BorderSizePixel = 0
		pip.Parent = holder
		local corner = Instance.new("UICorner")
		corner.Parent = pip
		local shine = Instance.new("UIGradient")
		shine.Color = RodModels.RAINBOW
		shine.Enabled = false
		shine.Parent = pip
		local scale = Instance.new("UIScale")
		scale.Parent = pip
		pips[i] = { frame = pip, corner = corner, shine = shine, scale = scale }
	end
	local SHAPES = {
		bar = { size = Vector2.new(20, 4), gap = 25, rot = 0, round = 2 },
		line = { size = Vector2.new(24, 2), gap = 28, rot = 0, round = 1 },
		slant = { size = Vector2.new(18, 4), gap = 22, rot = -22, round = 2 },
		dot = { size = Vector2.new(7, 7), gap = 14, rot = 0, round = 4 },
		diamond = { size = Vector2.new(7, 7), gap = 15, rot = 45, round = 1 },
	}
	local function stylePips(mv)
		local shape = SHAPES[mv.pip] or SHAPES.bar
		for i, pip in ipairs(pips) do
			pip.frame.Size = UDim2.fromOffset(shape.size.X, shape.size.Y)
			pip.frame.Position = UDim2.new(0.5, (i - (#pips + 1) / 2) * shape.gap, 0, 27)
			pip.frame.Rotation = shape.rot
			pip.corner.CornerRadius = UDim.new(0, shape.round)
		end
	end
	local showToken = 0
	local function showCombo(step)
		showToken += 1
		local token = showToken
		local mv = RodFx.move(RodFx.rodOf(player.Character))
		local finisher = step == #S.combo
		stylePips(mv)
		holder.Visible = true
		moveLabel.Text = mv.names[step] or S.combo[step].name
		moveLabel.TextColor3 = (finisher and not mv.rainbow) and mv.accent or WHITE
		labelShine.Enabled = finisher and mv.rainbow == true
		moveLabel.TextTransparency = 0
		moveStroke.Transparency = 0.3
		moveLabel.Position = UDim2.fromOffset(0, 5)
		TweenService:Create(moveLabel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
		for i, pip in ipairs(pips) do
			local lit = i <= step
			pip.shine.Enabled = lit and mv.rainbow == true
			pip.frame.BackgroundColor3 = (lit and not mv.rainbow) and mv.accent or WHITE
			pip.frame.BackgroundTransparency = lit and 0 or 0.72
			if i == step then
				pip.scale.Scale = 1.7
				TweenService:Create(pip.scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			else
				pip.scale.Scale = 1
			end
		end
		task.delay(S.combo[step].wait + S.window, function()
			if showToken ~= token then
				return
			end
			local fade = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(moveLabel, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(moveStroke, fade, { Transparency = 1 }):Play()
			for _, pip in ipairs(pips) do
				TweenService:Create(pip.frame, fade, { BackgroundTransparency = 1 }):Play()
			end
			task.delay(0.22, function()
				if showToken == token then
					holder.Visible = false
				end
			end)
		end)
	end

	local step, lastSwipe, buffered = 0, -10, -10
	local function ready(now)
		local last = S.combo[step]
		return now - lastSwipe >= math.max(S.cooldown, last and last.wait or 0)
	end
	local function swipe(fromButton)
		-- 13 Oct 2026: a click only swings in the fighting stance (X swaps); the SWIPE button and gamepad X
		-- switch you into it
		if FishingFeel.stance ~= "fight" then
			if fromButton and FishingFeel.phase == "" then
				FishingFeel.setStance("fight")
			end
			return
		end
		local now = os.clock()
		if not ready(now) then
			buffered = now -- swing as soon as it can
			return
		end
		-- at a fishing spot a click charges the cast instead (FischUI)
		if not swipeEvent or FishingFeel.phase ~= "" or FishingFeel.castReady or MotionBus.cutscene then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		-- the same rule as the server: carry on within the window, else start again
		local last = S.combo[step]
		step = (last and step < #S.combo and now - lastSwipe <= last.wait + S.window) and step + 1 or 1
		lastSwipe = now
		buffered = -10
		showCombo(step)
		swipeEvent:FireServer()
	end
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - buffered < 0.3 and ready(now) then
			buffered = -10
			swipe()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Studio and some devices flag plain clicks on the world as processed, so look for a button under
			-- the pointer instead (13 Oct 2026)
			if FishingFeel.overUi(input.Position) then
				return
			end
			swipe()
		elseif not processed and input.KeyCode == Enum.KeyCode.F then
			swipe()
		end
	end)
	ContextActionService:BindAction("TideboundSwipe", function(_, state)
		if state == Enum.UserInputState.Begin then
			swipe(true)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("TideboundSwipe", "SWIPE")
	ContextActionService:SetPosition("TideboundSwipe", UDim2.new(1, -180, 1, -160))
end
