-- Tidebound: Eggfall: swimming and fish riding (12 Oct 2026, "Swimming + Fish Riding" update).
-- Shared by TideboundMotion (poses every swimmer and rider), TideboundRide (your ride, the mounts everyone sees,
-- and the water effects) and the server's RideService (checks a ride and shows it to everyone).
--   Swimming: tread water when still (egg-beater legs, sculling arms, bobbing head), front crawl on the move
--     (windmill arms, body roll, flutter kick, a breath every other stroke), butterfly while sprinting, and a
--     streamlined dolphin kick under the surface.
--   Riding: press G (or the RIDE button) in the water and your fish pops up under you. You glide along the
--     surface; Space makes it leap out with a flip; G again, or reaching a beach, hops you off. Each ride rolls
--     a goofy style (Surf, Cowboy, Superman, Noodle). Your first companion is the fish you ride; with no
--     companion out you get a chunky loaner fish. Riding is free movement for fun: no Robux, no stats.
-- Poses use TideboundMotion's keys (radians; rootUp in studs).

local WaterMoves = {}

local TAU = math.pi * 2

WaterMoves.KEY = Enum.KeyCode.G
WaterMoves.PAD = Enum.KeyCode.ButtonL1
WaterMoves.cruise = 30 -- studs/s gliding on your fish (walking is 16)
WaterMoves.turbo = 42 -- holding Shift
WaterMoves.accel = 2.6 -- how fast it gets up to speed (higher is snappier)
WaterMoves.jumpSpeed = 46 -- the leap's take-off speed
WaterMoves.jumpGravity = 120
WaterMoves.jumpCooldown = 0.9
WaterMoves.fishLength = 10 -- 12 Oct: was 6.5; ridden voxel fish read bigger than the rider -- the mount's length in studs
WaterMoves.maxStartHeight = 16 -- the server only starts a ride this close to sea level (the sea's top is y 4)

WaterMoves.STYLES = { "Surf", "Cowboy", "Superman", "Noodle" }
WaterMoves.WORDS = {
	Surf = { "SURF'S UP!", { Color3.fromRGB(120, 230, 255), Color3.fromRGB(40, 140, 255) } },
	Cowboy = { "YEEHAW!", { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 130, 60) } },
	Superman = { "WHEEE!", { Color3.fromRGB(255, 140, 200), Color3.fromRGB(200, 80, 255) } },
	Noodle = { "WOBBLE!", { Color3.fromRGB(170, 255, 140), Color3.fromRGB(40, 200, 120) } },
}

local function smooth(s)
	s = math.clamp(s, 0, 1)
	return s * s * (3 - 2 * s)
end

local function mix(a, b, w)
	if w <= 0 then
		return a
	end
	local keys = {}
	for k in pairs(a) do
		keys[k] = true
	end
	for k in pairs(b) do
		keys[k] = true
	end
	for k in pairs(keys) do
		local x = a[k] or 0
		a[k] = x + ((b[k] or 0) - x) * w
	end
	return a
end

-- Swimming ---------------------------------------------------------------------------------------------------------

-- Treading water: upright, head up, sculling hands and egg-beater legs, bobbing on the swell.
local function tread(t, seed)
	local a = t * 4.2 + seed
	local bob = math.sin(t * 2.2 + seed)
	return {
		rootX = -0.12,
		rootUp = -0.15 + 0.18 * bob,
		rootZ = 0.05 * math.sin(t * 1.3 + seed),
		waistX = 0.08,
		neckX = 0.2 - 0.05 * bob,
		neckY = 0.25 * math.sin(t * 0.7 + seed),
		shRX = 0.55 + 0.15 * math.sin(a),
		shRZ = 1.15 + 0.3 * math.sin(a),
		elRX = 0.7 + 0.25 * math.cos(a),
		shLX = 0.55 + 0.15 * math.sin(a + math.pi),
		shLZ = -(1.15 + 0.3 * math.sin(a + math.pi)),
		elLX = 0.7 + 0.25 * math.cos(a + math.pi),
		hipRX = 0.65 + 0.35 * math.sin(a * 1.1),
		hipRZ = 0.25 + 0.15 * math.cos(a * 1.1),
		kneeRX = -1.2 - 0.4 * math.max(0, math.cos(a * 1.1)),
		ankRX = -0.3,
		hipLX = 0.65 + 0.35 * math.sin(a * 1.1 + math.pi),
		hipLZ = -(0.25 + 0.15 * math.cos(a * 1.1 + math.pi)),
		kneeLX = -1.2 - 0.4 * math.max(0, math.cos(a * 1.1 + math.pi)),
		ankLX = -0.3,
	}
end

-- Front crawl: flat out, arms windmilling in turn, the body rolling with each pull, a quick flutter kick, and
-- the head turning out to breathe every other stroke.
local function crawl(t, seed, m)
	local stroke = t * (3.2 + 2.2 * m) + seed
	local r = stroke % TAU - math.pi -- right arm all the way round
	local l = (stroke + math.pi) % TAU - math.pi -- left arm half a turn behind
	local kick = math.sin(t * 13 + seed)
	return {
		rootX = -1.38,
		rootY = 0.38 * math.sin(stroke),
		rootUp = -0.6 + 0.08 * math.sin(stroke * 2),
		waistY = -0.15 * math.sin(stroke),
		neckX = 0.95,
		neckY = 0.75 * math.max(0, math.sin(stroke * 0.5)) ^ 4,
		shRX = r + math.pi,
		shRZ = 0.25 + 0.2 * math.max(0, math.sin(stroke)),
		elRX = 0.25 + 0.6 * math.max(0, -math.cos(stroke)),
		shLX = l + math.pi,
		shLZ = -(0.25 + 0.2 * math.max(0, -math.sin(stroke))),
		elLX = 0.25 + 0.6 * math.max(0, math.cos(stroke)),
		hipRX = 0.32 * kick,
		kneeRX = -0.25 - 0.25 * math.max(0, kick),
		ankRX = -0.75,
		hipLX = -0.32 * kick,
		kneeLX = -0.25 - 0.25 * math.max(0, -kick),
		ankLX = -0.75,
	}
end

-- Butterfly (sprinting): both arms sweep round together and the whole body ripples like a dolphin.
local function fly(t, seed)
	local stroke = t * 5.2 + seed
	local a = stroke % TAU - math.pi
	local wave = math.sin(stroke)
	return {
		rootX = -1.3 + 0.3 * wave,
		rootUp = -0.5 + 0.4 * wave,
		waistX = -0.3 * math.cos(stroke),
		neckX = 0.8 + 0.35 * wave,
		shRX = a + math.pi,
		shRZ = 0.5 + 0.3 * math.max(0, wave),
		elRX = 0.2 + 0.3 * math.max(0, -wave),
		shLX = a + math.pi,
		shLZ = -(0.5 + 0.3 * math.max(0, wave)),
		elLX = 0.2 + 0.3 * math.max(0, -wave),
		hipRX = 0.45 * math.sin(stroke * 2),
		kneeRX = -0.2 - 0.6 * math.max(0, math.sin(stroke * 2)),
		ankRX = -0.8,
		hipLX = 0.45 * math.sin(stroke * 2),
		kneeLX = -0.2 - 0.6 * math.max(0, math.sin(stroke * 2)),
		ankLX = -0.8,
	}
end

-- Under the surface: a streamline, arms locked overhead, legs together in a dolphin kick, nose following the dive.
local function dolphin(t, seed, vy)
	local k = math.sin(t * 8 + seed)
	local pitch = math.clamp(-vy / 16, -0.7, 0.7)
	return {
		rootX = -1.5 - pitch,
		rootUp = -0.3,
		waistX = 0.15 * k,
		neckX = 0.45,
		shRX = 3.05,
		shRZ = 0.12,
		elRX = 0.08,
		shLX = 3.05,
		shLZ = -0.12,
		elLX = 0.08,
		hipRX = 0.35 * k,
		kneeRX = -0.15 - 0.45 * math.max(0, k),
		ankRX = -0.85,
		hipLX = 0.35 * k,
		kneeLX = -0.15 - 0.45 * math.max(0, k),
		ankLX = -0.85,
	}
end

-- The whole swim: `speed` is flat speed, `under` how far below the surface you are (studs), `vy` up/down speed.
function WaterMoves.swimPose(t, seed, speed, sprinting, under, vy)
	local m = math.clamp(speed / 14, 0, 1)
	local p = tread(t, seed)
	if m > 0.05 then
		mix(p, sprinting and fly(t, seed) or crawl(t, seed, m), smooth(m * 1.6))
	end
	local deep = smooth((under - 2.5) / 2)
	if deep > 0 and (m > 0.2 or math.abs(vy) > 3) then
		mix(p, dolphin(t, seed, vy), deep)
	end
	return p
end

-- Riding ------------------------------------------------------------------------------------------------------------
-- `speed` is how fast the fish is going (0..1 of cruise), `lean` the bank into a turn, `jump` 0..1 through a
-- leap (nil when not leaping).

local RIDE = {}

-- Surfing it sideways like a board: knees bent, arms out, wobbling for balance, hips wiggling.
function RIDE.Surf(t, speed, lean)
	local w = math.sin(t * 7.5)
	local wig = math.sin(t * 3.1)
	return {
		rootY = 1.35,
		rootZ = -0.25 * lean + 0.06 * w,
		rootUp = -0.55 + 0.08 * math.sin(t * 11),
		waistY = -0.6 + 0.12 * wig,
		waistZ = 0.1 * wig,
		waistX = -0.1 - 0.12 * speed,
		neckY = -0.95,
		neckX = 0.1,
		shRX = 0.35,
		shRZ = 1.3 + 0.35 * w,
		elRX = 0.35 + 0.2 * math.sin(t * 9),
		shLX = 0.35,
		shLZ = -1.3 + 0.35 * w,
		elLX = 0.35 + 0.2 * math.cos(t * 9),
		hipRX = 0.6,
		hipRZ = 0.45,
		kneeRX = -1.05,
		ankRX = 0.35,
		hipLX = 0.6,
		hipLZ = -0.45,
		kneeLX = -1.05,
		ankLX = 0.35,
	}
end

-- Sitting astride like a rodeo rider: bouncing, one hand holding on, the other spinning a lasso over the hat.
function RIDE.Cowboy(t, speed, lean)
	local bounce = math.abs(math.sin(t * 6.5))
	local lasso = t * 11
	return {
		rootUp = -1.55 + 0.45 * bounce,
		rootX = 0.1 - 0.15 * bounce,
		rootZ = -0.2 * lean,
		waistX = 0.2 * bounce - 0.1,
		neckX = -0.15 + 0.15 * bounce,
		neckY = 0.3 * math.sin(t * 2),
		shRX = 2.7 + 0.25 * math.sin(lasso),
		shRZ = 0.55 + 0.35 * math.cos(lasso),
		elRX = 0.55 + 0.3 * math.sin(lasso + 1),
		shLX = 0.7,
		shLZ = 0.2,
		elLX = 1.1,
		hipRX = 1.25,
		hipRZ = 0.7,
		kneeRX = -1.5 + 0.3 * bounce,
		ankRX = 0.2,
		hipLX = 1.25,
		hipLZ = -0.7,
		kneeLX = -1.5 + 0.3 * bounce,
		ankLX = 0.2,
	}
end

-- Lying belly-down along its back like a flying superhero: arms out front, legs kicking happily behind.
function RIDE.Superman(t, speed, lean)
	local kick = math.sin(t * 9)
	return {
		rootX = -1.5,
		rootZ = -0.35 * lean,
		rootUp = -2.15 + 0.06 * math.sin(t * 4),
		waistX = 0.25,
		neckX = 1.1,
		neckY = 0.25 * math.sin(t * 1.5),
		shRX = 3.0 - 0.15 * speed,
		shRZ = 0.25 + 0.1 * math.sin(t * 5),
		elRX = 0.05,
		shLX = 3.0 - 0.15 * speed,
		shLZ = -0.25 - 0.1 * math.sin(t * 5),
		elLX = 0.05,
		hipRX = -0.1 + 0.25 * kick,
		kneeRX = -1.2 - 0.6 * math.max(0, kick),
		ankRX = -0.6,
		hipLX = -0.1 - 0.25 * kick,
		kneeLX = -1.2 - 0.6 * math.max(0, -kick),
		ankLX = -0.6,
	}
end

-- Standing on one leg, arms flopping round like wet noodles, head wobbling: about to fall off any second.
function RIDE.Noodle(t, speed, lean)
	local a = t * 8
	local wob = math.sin(t * 5.3)
	return {
		rootZ = 0.28 * wob - 0.3 * lean,
		rootX = -0.12 * math.cos(t * 4.1),
		rootUp = -0.15,
		waistZ = -0.3 * wob,
		waistY = 0.3 * math.sin(t * 3.7),
		neckZ = 0.45 * math.sin(t * 6.1),
		neckX = 0.2 * math.cos(t * 4.9),
		shRX = 1.6 + 1.5 * math.sin(a),
		shRZ = 1.0 + 0.6 * math.cos(a * 1.3),
		elRX = 1.0 + 0.9 * math.sin(a * 1.7),
		shLX = 1.6 + 1.5 * math.sin(a + 2),
		shLZ = -(1.0 + 0.6 * math.cos(a * 1.3 + 1)),
		elLX = 1.0 + 0.9 * math.sin(a * 1.7 + 2),
		hipRX = 0.1,
		kneeRX = -0.2,
		hipLX = 1.4 + 0.3 * math.sin(t * 6),
		hipLZ = -0.5,
		kneeLX = -1.6,
		ankLX = 0.3,
	}
end

-- The leap: crouch, fling the arms up mid-air while the fish flips under you, then a "ta-da" on the splash down.
local function leapPose(base, t, u)
	local up = { rootUp = 0.2, waistX = 0.35, neckX = -0.3, shRX = 2.8, shRZ = 0.9, elRX = 0.2, shLX = 2.8, shLZ = -0.9, elLX = 0.2, hipRX = 0.9, kneeRX = -1.7, hipLX = 0.9, kneeLX = -1.7 }
	local flail = math.sin(t * 24)
	up.shRZ += 0.3 * flail
	up.shLZ -= 0.3 * flail
	local p = table.clone(base)
	mix(p, up, smooth(u / 0.15) * smooth((1 - u) / 0.2))
	return p
end

function WaterMoves.ridePose(style, t, speed, lean, jump)
	local base = (RIDE[style] or RIDE.Surf)(t, speed, lean)
	if jump and jump >= 0 and jump <= 1 then
		return leapPose(base, t, jump)
	end
	return base
end

-- Where the top of the fish sits under each style's feet, seat or belly (studs below the rider's root).
local SEAT = { Surf = -3.3, Cowboy = -2.5, Superman = -2.7, Noodle = -3.15 }

-- How high your root rides above the water for a style: the fish's back sits a little out of the water.
function WaterMoves.heightFor(style)
	return -(SEAT[style] or -3.3) + 0.8
end

-- Where the mount sits under its rider (rootCf: the rider's root, facing the way they ride). The fish faces -Z;
-- `half` is half the mount's height. `jump` 0..1 gives a full forward flip through the leap.
function WaterMoves.mountCFrame(style, rootCf, t, speed, lean, jump, half)
	local y = (SEAT[style] or -3.3) - (half or 1.2)
	local wiggle = math.sin(t * (7 + 6 * speed)) * (0.12 + 0.12 * speed)
	local bob = 0.12 * math.sin(t * 3.3)
	local cf = rootCf * CFrame.new(0, y + bob, 0.3) * CFrame.Angles(0, wiggle, -0.35 * lean)
	if jump and jump >= 0 and jump <= 1 then
		-- nose up on the way out, a full front flip at the top, nose down into the splash
		local flip = -TAU * smooth((jump - 0.2) / 0.55)
		cf *= CFrame.Angles(0.5 * math.sin(jump * math.pi) + (flip <= -TAU + 1e-3 and 0 or flip), 0, 0)
	end
	return cf
end

-- What a character is doing on the water right now, for any player: style and leap progress (0..1), or nil.
-- `own` is your own ride from MotionBus.ride (it plays at once; everyone else's comes from attributes).
function WaterMoves.rideOf(character, own, serverNow)
	if own then
		local u = own.jumpAt and (os.clock() - own.jumpAt) / own.jumpLength or nil
		return own.style, u
	end
	local style = character:GetAttribute("Riding")
	if type(style) ~= "string" or style == "" then
		return nil
	end
	local jumpAt = character:GetAttribute("RideJumpAt")
	local u = jumpAt and (serverNow - jumpAt) / WaterMoves.jumpLength() or nil
	return style, u
end

function WaterMoves.jumpLength()
	return 2 * WaterMoves.jumpSpeed / WaterMoves.jumpGravity
end

-- Sound cues (they join Audio.cues, so they play on the SFX bus like every other cue) --------------------------------

local POOL_SPLASH = "rbxassetid://9117823374"
local SPLASH_THUNK = "rbxassetid://9119481909"
local WET_SLAP = "rbxassetid://9120085618"
local BUBBLE_WHOOSH = "rbxassetid://9113605893"
WaterMoves.WAKE_LOOP = "rbxassetid://9120610116" -- Water Wake Constant 2, looped under a moving fish

function WaterMoves.addCues(Audio)
	local cues = Audio.cues
	cues.RideSummon = { note = "Your fish bursts up under you", layers = {
		{ id = POOL_SPLASH, volume = 0.6, pitch = 1.05, start = 0.14, length = 0.55, fadeOut = 0.25, jitter = 0.05 },
		{ id = "rbxasset://sounds/action_jump.mp3", volume = 0.4, pitch = 1.7 },
	} }
	cues.RideLeap = { note = "The fish leaps out: boing and spray", layers = {
		{ id = "rbxasset://sounds/action_jump.mp3", volume = 0.5, pitch = 1.45, jitter = 0.06 },
		{ id = POOL_SPLASH, volume = 0.35, pitch = 1.35, start = 0.16, length = 0.3, fadeOut = 0.15 },
	} }
	cues.RideSplash = { note = "Belly-flop back into the water", layers = {
		{ id = SPLASH_THUNK, volume = 0.6, pitch = 1.05, start = 0.15, length = 0.6, fadeOut = 0.3, jitter = 0.05 },
		{ id = WET_SLAP, volume = 0.35, pitch = 0.85, start = 0.12, length = 0.25, fadeOut = 0.1 },
	} }
	cues.RideHop = { note = "Hopping off your fish", layers = {
		{ id = BUBBLE_WHOOSH, volume = 0.3, pitch = 1.4, start = 2.2, length = 0.4, fadeIn = 0.05, fadeOut = 0.2 },
		{ id = "rbxasset://sounds/action_jump.mp3", volume = 0.35, pitch = 1.2 },
	} }
	cues.SwimStroke = { note = "One arm stroke breaking the surface", layers = {
		{ id = POOL_SPLASH, volume = 0.13, pitch = 1.6, start = 0.2, length = 0.18, fadeOut = 0.1, jitter = 0.12 },
	} }
end

return WaterMoves
