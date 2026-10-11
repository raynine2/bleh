-- Tidebound: Eggfall: the dash moves (Patch 19). Q rolls one of these (never the same twice in a row), from the
-- ones you can do right now: rod moves need your rod (everyone has one), fish moves need a companion following
-- you, and in the air only the air moves come up.
--   1 Zoomies       lean way forward, arms flung back, legs a blur
--   2 Penguin Slide a long belly slide on the snow, arms out in front
--   3 Wheel Legs    cartoon wheel legs and windmilling arms
--   4 Barrel Roll   a tucked sideways roll
--   5 Cannonball    a hop into a tucked ball that flips twice through the air, then a "ta-da" landing
--   6 Pole Vault    (rod) plant the rod, backflip up and over it, superhero landing
--   7 Hook Shot     (rod) cast the line at a spot ahead, hook it, get yanked along the line
--   8 Rod Copter    (rod) spin the rod over your head like a rotor and glide, legs kicking
--   9 Fish Surf     (fish) your companion slides under your feet and you surf it
--  10 Fish Rocket   (fish) your companion rams you from behind and you fly off like a superhero
--  11 Tail Slap     (fish) your companion tail-slaps you into a somersault; you end up sitting, dizzy
--  12 Tidal Warp    you dissolve into a rushing wave of light and burst back out further on (Celestial)
-- Patch 20: every move has a rarity (`tier`, Config.Tiers: Common 1 .. Celestial 7) and a save `key`. You own
-- moves by opening Dash Capsules (the same rates and pity as Tide Eggs) and equip up to Config.Capsules.slots of
-- them; Q only rolls equipped moves.
-- Each move: how you move (`profile`: dash, arc, hook or glide, with its numbers), how long the body pose lasts
-- (`length`), its colours, and a pose function in TideboundMotion's keys. Fish moves also say where the
-- companion goes (DashMoves.fish). TideboundDash moves you and plays the effects; TideboundMotion poses you;
-- TideboundCreatures moves the fish; the server only checks the move and shows it to everyone.

local DashMoves = {}

local TAU = math.pi * 2

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

-- a full turn that's back to 0 once it's done, so fading the pose out never unwinds it
local function turn(u, from, to, turns)
	local s = smooth((u - from) / (to - from))
	return s >= 1 and 0 or -TAU * (turns or 1) * s
end

-- Shared endings ------------------------------------------------------------------------------------------------

-- a skid: leaning back, front foot braced toe-up, arms flailing for balance
local function skid(t)
	local flail = math.sin(t * 22)
	return { rootX = 0.32, rootUp = -0.45, waistX = 0.18, neckX = -0.15, shRX = 0.6, shRZ = 1.25 + 0.35 * flail, elRX = 0.4, shLX = 0.6, shLZ = -(1.25 - 0.35 * flail), elLX = 0.4, hipRX = 0.85, kneeRX = -0.35, ankRX = -0.45, hipLX = -0.25, kneeLX = -1.05, ankLX = 0.3 }
end

-- one knee and one fist on the ground
local SUPERHERO = { rootUp = -1.45, rootX = -0.1, waistX = -0.55, neckX = 0.55, shRX = 0.35, shRZ = 0.1, elRX = 0.1, shLX = -0.5, shLZ = -0.95, elLX = 0.3, hipRX = -0.25, kneeRX = -2.0, ankRX = 0.5, hipLX = 1.45, kneeLX = -1.5, ankLX = 0.3 }

-- arms up, a little bounce: ta-da!
local function tada(t)
	local b = math.sin(t * 14) * 0.05
	return { rootUp = -0.5 + b, waistX = 0.2, neckX = -0.2, shRX = 2.6, shRZ = 0.7, elRX = 0.2, shLX = 2.6, shLZ = -0.7, elLX = 0.2, hipRX = 0.5, kneeRX = -0.8, hipLX = 0.5, kneeLX = -0.8, hipRZ = 0.15, hipLZ = -0.15 }
end

local function legsBlur(p, u, speed, swing, bend)
	local ph = u * speed
	p.hipRX = (p.hipRX or 0) + swing * math.sin(ph)
	p.kneeRX = (p.kneeRX or 0) - bend * (0.5 + 0.5 * math.cos(ph))
	p.hipLX = (p.hipLX or 0) - swing * math.sin(ph)
	p.kneeLX = (p.kneeLX or 0) - bend * (0.5 - 0.5 * math.cos(ph))
	return p
end

-- The moves -------------------------------------------------------------------------------------------------------

DashMoves.list = {
	{
		id = 1,
		key = "Zoomies",
		tier = 1,
		name = "ZOOMIES",
		cost = 20,
		air = true,
		profile = { kind = "dash", speed = 72, time = 0.28 },
		length = 0.62,
		colors = { Color3.fromRGB(150, 230, 255), Color3.fromRGB(255, 255, 255) },
		pose = function(u, t)
			local p = legsBlur({ rootX = -0.8, rootUp = -0.2, waistX = -0.15, neckX = 0.6, shRX = -1.35, shRZ = 0.25, elRX = 0.05, shLX = -1.35, shLZ = -0.25, elLX = 0.05, kneeRX = -0.8, kneeLX = -0.8 }, u, 48, 1.1, 1.4)
			return mix(p, skid(t), smooth((u - 0.27) / 0.1))
		end,
	},
	{
		id = 2,
		key = "PenguinSlide",
		tier = 2,
		name = "PENGUIN SLIDE",
		cost = 22,
		profile = { kind = "dash", speed = 64, time = 0.5, floor = 0.55 },
		length = 0.85,
		colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(120, 200, 255) },
		pose = function(u, t)
			local flutter = math.sin(u * 40) * 0.15
			local p = { rootX = -1.42, rootUp = -2.0, rootZ = 0.08 * math.sin(u * 22), waistX = 0.15, neckX = 0.85, shRX = 3.0, shRZ = 0.25, elRX = 0.05, shLX = 3.0, shLZ = -0.25, elLX = 0.05, hipRX = -0.15 + flutter, kneeRX = -0.1, ankRX = -0.7, hipLX = -0.15 - flutter, kneeLX = -0.1, ankLX = -0.7 }
			return mix(p, skid(t), smooth((u - 0.5) / 0.14))
		end,
	},
	{
		id = 3,
		key = "WheelLegs",
		tier = 1,
		name = "WHEEL LEGS",
		cost = 20,
		profile = { kind = "dash", speed = 68, time = 0.36 },
		length = 0.68,
		colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 150, 80) },
		pose = function(u, t)
			local ph = u * 48
			local p = legsBlur({ rootX = -0.4, rootUp = 0.15 * math.sin(ph * 2), waistY = 0.15 * math.sin(ph), waistX = -0.1, neckX = 0.35, shRX = 1.4 + 1.6 * math.sin(ph * 0.6), shRZ = 0.5, elRX = 0.3, shLX = 1.4 - 1.6 * math.sin(ph * 0.6), shLZ = -0.5, elLX = 0.3, kneeRX = -0.9, kneeLX = -0.9 }, u, 48, 1.3, 1.8)
			return mix(p, skid(t), smooth((u - 0.34) / 0.1))
		end,
	},
	{
		id = 4,
		key = "BarrelRoll",
		tier = 2,
		name = "BARREL ROLL",
		cost = 20,
		air = true,
		profile = { kind = "dash", speed = 66, time = 0.32 },
		length = 0.64,
		colors = { Color3.fromRGB(190, 150, 255), Color3.fromRGB(255, 255, 255) },
		pose = function(u, t)
			local p = { rootUp = -0.35, waistX = -0.45, neckX = -0.3, shRX = 1.3, elRX = 1.9, shLX = 1.3, elLX = 1.9, hipRX = 1.5, kneeRX = -2.1, hipLX = 1.5, kneeLX = -2.1, rootZ = turn(u, 0.03, 0.3, 1) }
			return mix(p, skid(t), smooth((u - 0.3) / 0.1))
		end,
	},
	{
		id = 5,
		key = "Cannonball",
		tier = 3,
		name = "CANNONBALL",
		cost = 24,
		profile = { kind = "arc", speed = 52, lift = 44, time = 0.5 },
		length = 0.95,
		colors = { Color3.fromRGB(255, 140, 90), Color3.fromRGB(255, 230, 120) },
		pose = function(u, t)
			local p = { rootUp = -0.6, waistX = 0.1, shRX = 1.2, elRX = 1.4, shLX = 1.2, elLX = 1.4, hipRX = 0.9, kneeRX = -1.6, hipLX = 0.9, kneeLX = -1.6 } -- crouch to hop
			mix(p, { rootUp = 0.2, waistX = -0.65, neckX = -0.45, shRX = 1.7, elRX = 2.1, shLX = 1.7, elLX = 2.1, hipRX = 2.0, kneeRX = -2.45, hipLX = 2.0, kneeLX = -2.45 }, smooth((u - 0.03) / 0.06))
			p.rootX = turn(u, 0.06, 0.46, 2)
			return mix(p, tada(t), smooth((u - 0.48) / 0.08))
		end,
	},
	{
		id = 6,
		key = "PoleVault",
		tier = 5,
		name = "POLE VAULT",
		cost = 26,
		rod = true,
		profile = { kind = "arc", speed = 48, lift = 56, time = 0.58, delay = 0.1 },
		length = 1.05,
		colors = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(120, 230, 255) },
		pose = function(u, t)
			-- plant: both hands on the rod, pointed down at the ground ahead
			local p = legsBlur({ rootX = -0.35, waistX = -0.25, neckX = 0.3, shRX = 1.05, shRZ = -0.1, elRX = 0.2, shLX = 1.1, shLZ = 0.25, elLX = 0.5, kneeRX = -0.6, kneeLX = -0.6 }, u, 40, 0.8, 1)
			-- up and over: a backflip, rod held overhead, legs together
			local fly = smooth((u - 0.1) / 0.06)
			if fly > 0 then
				local s = math.clamp((u - 0.12) / 0.5, 0, 1)
				mix(p, { shRX = 3.05, shRZ = 0.15, elRX = 0.1, shLX = 3.05, shLZ = -0.15, elLX = 0.1, hipRX = 0.3, kneeRX = -0.2, hipLX = 0.3, kneeLX = -0.2, neckX = 0.4, waistX = 0.3, rootUp = 0.6 }, fly)
				p.rootX = s >= 1 and 0 or TAU * smooth(s) -- backwards: feet up and over
			end
			return mix(p, SUPERHERO, smooth((u - 0.64) / 0.08))
		end,
	},
	{
		id = 7,
		key = "HookShot",
		tier = 4,
		name = "HOOK SHOT",
		cost = 26,
		rod = true,
		air = true,
		profile = { kind = "hook", speed = 92, time = 0.42, delay = 0.16, reach = 42 },
		length = 0.82,
		colors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(255, 255, 255) },
		pose = function(u, t)
			-- the cast: rod back over the shoulder, then whipped forward
			local p = { rootX = 0.15, waistY = -0.4, waistX = 0.15, shRX = 3.0, shRZ = 0.3, elRX = 0.6, shLX = 0.6, shLZ = -0.3, elLX = 0.8, hipLX = 0.4, kneeLX = -0.4, hipRX = -0.2, kneeRX = -0.2 }
			mix(p, { rootX = -0.1, waistY = 0.4, waistX = -0.2, shRX = 1.6, shRZ = -0.1, elRX = 0.05 }, smooth((u - 0.06) / 0.08))
			-- yanked along the line: rod arm out in front, the rest of you trailing behind
			local pull = smooth((u - 0.16) / 0.05)
			if pull > 0 then
				mix(p, { rootX = -0.65, rootUp = 0.25, waistY = 0.1, waistX = -0.2, neckX = 0.5, shRX = 1.65, shRZ = 0, elRX = 0, shLX = -0.7, shLZ = -0.5, elLX = 0.3, hipRX = -0.45, kneeRX = -0.7, hipLX = -0.15, kneeLX = -0.9, ankRX = -0.4, ankLX = -0.4 }, pull)
				p.hipRX += 0.15 * math.sin(t * 30)
				p.hipLX -= 0.15 * math.sin(t * 30)
			end
			return mix(p, skid(t), smooth((u - 0.58) / 0.1))
		end,
	},
	{
		id = 8,
		key = "RodCopter",
		tier = 6,
		name = "ROD COPTER",
		cost = 28,
		rod = true,
		air = true,
		profile = { kind = "glide", speed = 44, lift = 16, time = 0.85 },
		length = 1.1,
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 255, 170) },
		pose = function(u, t)
			local kick = math.sin(t * 20)
			local p = { rootUp = 0.5, rootY = 0.25 * math.sin(t * 9), rootZ = 0.08 * math.sin(t * 7), neckX = 0.45, waistX = 0.05, shRX = 3.1, shRZ = 0.05, elRX = 0, shLX = 0.3, shLZ = -0.9 + 0.2 * kick, elLX = 0.4, hipRX = 0.25 + 0.45 * kick, kneeRX = -0.7 - 0.3 * kick, hipLX = 0.25 - 0.45 * kick, kneeLX = -0.7 + 0.3 * kick, ankRX = -0.3, ankLX = -0.3 }
			return mix(p, skid(t), smooth((u - 0.86) / 0.1))
		end,
	},
	{
		id = 9,
		key = "FishSurf",
		tier = 4,
		name = "FISH SURF",
		cost = 24,
		fish = true,
		profile = { kind = "dash", speed = 60, time = 0.75, floor = 0.6 },
		length = 1.05,
		colors = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(230, 250, 255) },
		pose = function(u, t)
			local w = math.sin(t * 8)
			local p = { rootY = 1.25, rootUp = 1.0 + 0.1 * math.sin(t * 11), rootZ = 0.12 * w, waistX = -0.15, waistY = -0.5, neckY = -0.9, neckX = 0.1, shRX = 0.4, shRZ = 1.35 + 0.2 * w, elRX = 0.3, shLX = 0.4, shLZ = -1.35 + 0.2 * w, elLX = 0.3, hipRX = 0.6, hipRZ = 0.35, kneeRX = -1.0, hipLX = 0.6, hipLZ = -0.35, kneeLX = -1.0 }
			return mix(p, skid(t), smooth((u - 0.76) / 0.12))
		end,
	},
	{
		id = 10,
		key = "FishRocket",
		tier = 5,
		name = "FISH ROCKET",
		cost = 26,
		fish = true,
		air = true,
		profile = { kind = "dash", speed = 88, time = 0.34, delay = 0.12 },
		length = 0.82,
		colors = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(255, 230, 120) },
		pose = function(u, t)
			-- here it comes: a surprised lean back, arms up
			local p = { waistX = 0.3, neckX = -0.25, shRX = 2.5, shRZ = 0.5, elRX = 0.6, shLX = 2.5, shLZ = -0.5, elLX = 0.6, hipRX = 0.2, kneeRX = -0.3, hipLX = 0.2, kneeLX = -0.3 }
			-- BOOP: flying low like a superhero
			mix(p, { rootX = -1.2, rootUp = 0.5, waistX = 0, neckX = 0.75, shRX = 3.05, shRZ = 0.1, elRX = 0, shLX = 3.05, shLZ = -0.1, elLX = 0, hipRX = -0.1, kneeRX = -0.05, hipLX = 0.1, kneeLX = -0.9, ankRX = -0.6, ankLX = -0.6 }, smooth((u - 0.11) / 0.05))
			return mix(p, skid(t), smooth((u - 0.48) / 0.1))
		end,
	},
	{
		id = 11,
		key = "TailSlap",
		tier = 3,
		name = "TAIL SLAP",
		cost = 22,
		fish = true,
		profile = { kind = "dash", speed = 62, time = 0.36, delay = 0.1 },
		length = 0.95,
		colors = { Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 120, 120) },
		pose = function(u, t)
			-- SLAP! arched back, arms flung up
			local p = { waistX = 0.55, neckX = -0.45, shRX = 2.8, shRZ = 0.7, elRX = 0.3, shLX = 2.8, shLZ = -0.7, elLX = 0.3, hipRX = -0.3, hipLX = -0.3 }
			-- a flailing somersault along the ground
			local roll = smooth((u - 0.1) / 0.04)
			if roll > 0 then
				local f = math.sin(t * 26)
				mix(p, { rootUp = -1.0, waistX = -0.5, neckX = -0.4, shRX = 1.5 + 1.2 * f, shRZ = 0.8, elRX = 1.0, shLX = 1.5 - 1.2 * f, shLZ = -0.8, elLX = 1.0, hipRX = 1.4 + 0.5 * f, kneeRX = -1.6, hipLX = 1.4 - 0.5 * f, kneeLX = -1.6 }, roll)
				p.rootX = turn(u, 0.12, 0.46, 1)
			end
			-- sat on the ground, dizzy, head wobbling
			local wob = math.sin(t * 7)
			return mix(p, { rootUp = -1.75, rootX = 0.15, waistX = 0.1, neckZ = 0.35 * wob, neckX = 0.1 * math.cos(t * 7), shRX = -0.6, shRZ = 0.45, elRX = 0.2, shLX = -0.6, shLZ = -0.45, elLX = 0.2, hipRX = 1.5, hipRZ = 0.25, kneeRX = -0.35, hipLX = 1.5, hipLZ = -0.25, kneeLX = -0.35 }, smooth((u - 0.46) / 0.08))
		end,
	},
	{
		id = 12,
		key = "TidalWarp",
		tier = 7,
		name = "TIDAL WARP",
		cost = 30,
		air = true,
		profile = { kind = "dash", speed = 150, time = 0.2, delay = 0.06 },
		length = 0.8,
		colors = { Color3.fromRGB(140, 255, 250), Color3.fromRGB(255, 160, 250) },
		pose = function(u, t)
			-- gather: arms crossed, crouched, then gone in a wave; burst back out arms wide, glowing
			local p = { rootUp = -0.7, waistX = -0.3, neckX = -0.3, shRX = 1.6, shRZ = -0.6, elRX = 2.0, shLX = 1.6, shLZ = 0.6, elLX = 2.0, hipRX = 0.9, kneeRX = -1.5, hipLX = 0.9, kneeLX = -1.5 }
			local out = smooth((u - 0.28) / 0.08)
			if out > 0 then
				local b = math.sin(t * 12) * 0.05
				mix(p, { rootUp = 0.3 + b, waistX = 0.35, neckX = -0.35, shRX = 2.2, shRZ = 1.2, elRX = 0.1, shLX = 2.2, shLZ = -1.2, elLX = 0.1, hipRX = 0.2, kneeRX = -0.3, hipLX = -0.1, kneeLX = -0.5, hipRZ = 0.2, hipLZ = -0.2 }, out)
			end
			return p
		end,
	},
}

DashMoves.byId = {}
DashMoves.byKey = {}
DashMoves.byTier = {} -- [tier] = { moves } (Patch 20: what a capsule can roll at each rarity)
for _, move in ipairs(DashMoves.list) do
	DashMoves.byId[move.id] = move
	DashMoves.byKey[move.key] = move
	DashMoves.byTier[move.tier] = DashMoves.byTier[move.tier] or {}
	table.insert(DashMoves.byTier[move.tier], move)
end

function DashMoves.pose(id, u, t)
	local move = DashMoves.byId[id] or DashMoves.byId[1]
	return move.pose(u, t)
end

function DashMoves.length(id)
	local move = DashMoves.byId[id] or DashMoves.byId[1]
	return move.length
end

-- Where a companion goes during a fish move (`rootCf` is its owner's root, `slot` 1 or 2), or nil to follow as
-- usual. Fish face -Z, like their owner.
function DashMoves.fish(id, slot, u, rootCf, t)
	if id == 9 then -- surf: slot 1 is the board, slot 2 zooms circles round you
		if u > 0.85 then
			return nil
		end
		if slot == 1 then
			return rootCf * CFrame.new(0, -3.15 + 0.1 * math.sin(t * 11), -0.2) * CFrame.Angles(0, 0, 0.12 * math.sin(t * 8))
		end
		local a = t * 9
		local p = rootCf * CFrame.new(math.cos(a) * 4.5, 0.6 + 0.4 * math.sin(t * 5), math.sin(a) * 4.5)
		local ahead = rootCf * CFrame.new(math.cos(a + 0.3) * 4.5, 0.6, math.sin(a + 0.3) * 4.5)
		return CFrame.lookAt(p.Position, ahead.Position)
	elseif id == 10 then -- rocket: rushes in from behind, pushes, then spins away
		if u < 0.12 then
			local s = u / 0.12
			return rootCf * CFrame.new(slot == 1 and 0 or 1.6, 0.4, 12 - 10.2 * s * s)
		elseif u < 0.5 then
			return rootCf * CFrame.new(slot == 1 and 0 or 1.6, 0.4 + 0.15 * math.sin(t * 30), 1.8) * CFrame.Angles(0, 0, math.sin(t * 40) * 0.25)
		elseif u < 0.7 then
			return rootCf * CFrame.new(slot == 1 and -2 or 2, 1.5, 2.5) * CFrame.Angles(0, (u - 0.5) * 30, 0)
		end
		return nil
	elseif id == 11 then -- tail slap: swings round behind you so the tail smacks your back
		if slot ~= 1 or u > 0.3 then
			return nil
		end
		local s = math.clamp(u / 0.1, 0, 1)
		return rootCf * CFrame.new(-1.2, 0.4, 2.4) * CFrame.Angles(0, -math.pi * 1.2 * smooth(s), 0)
	end
	return nil
end

return DashMoves
