-- Tidebound: Eggfall: rod abilities (Patch 21). Every rod has its own ability on R (Y on a gamepad, SKILL on
-- touch). The six shop rods have quick abilities with a caption; the five trial rods (Config.RodTrials) have
-- ultimates that open with a short cinematic (`cut` seconds: the camera takes over, letterbox bars, the name
-- across the bottom of the screen) before they land.
--   Drift        TIDE LASH         whip a curling wave forward
--   Coral        CORAL BLOOM       stab the rod down; coral spikes erupt in a ring
--   Stormline    THUNDER HOOK      three lightning strikes march out ahead
--   Abyssal      ABYSS MAW         a vortex drags mobs in, then shadow jaws snap shut
--   Riftcaster   RIFT SLASH        three slashes tear space open, then it shatters
--   Celestial    STARFALL          stars rain down all around
--   CrimsonCrow  CRIMSON ILLUSION  a crimson spiral eye opens; a storm of crows; everything nearby is frozen
--   Jackpot      JACKPOT RUSH      the reels spin; on a jackpot you're healed and untouchable for a while
--   ThiefTome    STOLEN PAGE       the book flips to a stolen page and casts another rod's ability
--   SunRubber    SUN GOD BOUNCE    drums, laughter, white steam, then a giant bouncing fist
--   Boundless    BOUNDLESS VOID    the world falls into an endless void; it collapses into a violet blast
-- Each: when it lands (`impact`, seconds after the start), where (`forward` studs ahead, `radius`), what it does
-- (`damage`, `stun` seconds, `knock`, `pull`), the cooldown, colours, and a pose in TideboundMotion's keys. The
-- server applies the hit (Mobs.area); TideboundSkills plays the cinematic and the effects; Motion poses you.

local RodSkills = {}

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

-- a steady, braced stance to build the others on
local function stance()
	return { hipRX = 0.35, kneeRX = -0.55, hipLX = -0.1, kneeLX = -0.3, hipRZ = 0.1, hipLZ = -0.1, rootUp = -0.2 }
end

RodSkills.list = {
	Drift = {
		name = "TIDE LASH",
		sub = "Drift Rod",
		cooldown = 6,
		cut = 0,
		impact = 0.32,
		length = 0.9,
		forward = 10,
		radius = 9,
		damage = 2,
		knock = 18,
		colors = { Color3.fromRGB(140, 220, 255), Color3.fromRGB(255, 255, 255) },
		pose = function(u)
			local p = mix(stance(), { waistY = -0.6, waistX = 0.2, shRX = 3.0, shRZ = 0.4, elRX = 0.6, shLX = 0.8, shLZ = -0.4, elLX = 0.8 }, 1)
			return mix(p, { waistY = 0.7, waistX = -0.35, shRX = 0.5, shRZ = -0.6, elRX = 0.1, shLX = -0.4, hipLX = 0.8, kneeLX = -0.9, rootUp = -0.5, rootX = -0.2 }, smooth((u - 0.2) / 0.12))
		end,
	},
	Coral = {
		name = "CORAL BLOOM",
		sub = "Coral Rod",
		cooldown = 7,
		cut = 0,
		impact = 0.4,
		length = 1.0,
		forward = 0,
		radius = 11,
		damage = 2,
		stun = 0.8,
		colors = { Color3.fromRGB(255, 130, 160), Color3.fromRGB(255, 200, 130) },
		pose = function(u)
			local p = mix(stance(), { shRX = 2.6, elRX = 0.8, shLX = 2.6, elLX = 0.8, waistX = 0.2, rootUp = 0.1 }, 1)
			return mix(p, { shRX = 0.6, shRZ = -0.3, elRX = 0.2, shLX = 0.6, shLZ = 0.3, elLX = 0.2, waistX = -0.6, neckX = 0.4, rootUp = -1.1, hipRX = 1.2, kneeRX = -1.9, hipLX = 1.2, kneeLX = -1.9 }, smooth((u - 0.28) / 0.1))
		end,
	},
	Stormline = {
		name = "THUNDER HOOK",
		sub = "Stormline Rod",
		cooldown = 8,
		cut = 0,
		impact = 0.45,
		length = 1.1,
		forward = 11,
		radius = 10,
		damage = 3,
		stun = 0.5,
		colors = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 255, 200) },
		pose = function(u)
			local p = mix(stance(), { shRX = 3.1, shRZ = 0.1, elRX = 0, waistX = 0.3, neckX = 0.5, shLX = 0.3, shLZ = -0.6, elLX = 0.4 }, 1)
			return mix(p, { shRX = 1.6, waistX = -0.1, neckX = 0.1 }, smooth((u - 0.4) / 0.12))
		end,
	},
	Abyssal = {
		name = "ABYSS MAW",
		sub = "Abyssal Rod",
		cooldown = 9,
		cut = 0,
		impact = 0.75,
		length = 1.25,
		forward = 11,
		radius = 12,
		damage = 3,
		pull = true,
		colors = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(30, 10, 50) },
		pose = function(u, t)
			local strain = 0.05 * math.sin(t * 30)
			local p = mix(stance(), { shRX = 1.6, elRX = 0.05, shLX = 1.1, shLZ = -0.2, elLX = 0.9, waistX = 0.25 + strain, rootX = 0.15, hipRX = 0.7, kneeRX = -0.8 }, 1)
			return mix(p, { shRX = 0.4, elRX = 1.6, shLX = 0.3, elLX = 1.4, waistX = -0.25, rootX = -0.1 }, smooth((u - 0.7) / 0.08))
		end,
	},
	Riftcaster = {
		name = "RIFT SLASH",
		sub = "Riftcaster",
		cooldown = 9,
		cut = 0,
		impact = 0.6,
		length = 1.1,
		forward = 8,
		radius = 10,
		damage = 4,
		colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(150, 110, 255) },
		pose = function(u)
			local p = stance()
			local a = smooth(u / 0.12)
			local b = smooth((u - 0.18) / 0.12)
			local c = smooth((u - 0.36) / 0.14)
			mix(p, { waistY = -0.7, shRX = 1.8, shRZ = 1.0, elRX = 0.2 }, 1 - a)
			mix(p, { waistY = 0.7, shRX = 1.5, shRZ = -0.9, elRX = 0.1 }, a)
			mix(p, { waistY = -0.6, shRX = 1.6, shRZ = 0.9, elRX = 0.1 }, b)
			return mix(p, { waistY = 0, waistX = -0.4, shRX = 0.4, shRZ = 0, elRX = 0, rootUp = -0.6, hipLX = 0.8, kneeLX = -1.0 }, c)
		end,
	},
	Celestial = {
		name = "STARFALL",
		sub = "Celestial Rod",
		cooldown = 10,
		cut = 0,
		impact = 0.7,
		length = 1.4,
		forward = 0,
		radius = 14,
		damage = 4,
		colors = { Color3.fromRGB(255, 244, 190), Color3.fromRGB(190, 160, 255) },
		pose = function(u)
			local p = mix(stance(), { shRX = 3.1, shRZ = 0.25, elRX = 0, shLX = 3.0, shLZ = -0.25, elLX = 0.1, neckX = 0.6, waistX = 0.3 }, 1)
			return mix(p, { shRX = 2.2, shRZ = 1.3, shLX = 2.2, shLZ = -1.3, neckX = 0.3 }, smooth((u - 0.65) / 0.15))
		end,
	},
	CrimsonCrow = {
		name = "CRIMSON ILLUSION",
		sub = "Crimson Crow Rod",
		cooldown = 14,
		cut = 1.3,
		impact = 1.5,
		length = 2.3,
		forward = 0,
		radius = 16,
		damage = 3,
		stun = 3,
		colors = { Color3.fromRGB(255, 40, 60), Color3.fromRGB(20, 10, 14) },
		pose = function(u)
			-- two fingers up by the eye, calm; then the arm sweeps out and the crows go
			local p = mix(stance(), { shRX = 2.0, shRZ = -0.35, elRX = 2.3, shLX = 0.1, shLZ = -0.15, elLX = 0.3, neckX = -0.1, waistY = -0.2 }, 1)
			return mix(p, { shRX = 1.4, shRZ = 1.2, elRX = 0.1, waistY = 0.4, neckX = 0.1 }, smooth((u - 1.35) / 0.15))
		end,
	},
	Jackpot = {
		name = "JACKPOT RUSH",
		sub = "Jackpot Rod",
		cooldown = 15,
		cut = 1.6,
		impact = 1.7,
		length = 2.6,
		forward = 0,
		radius = 12,
		damage = 3,
		knock = 12,
		fever = 8, -- seconds of being untouchable (and healed to full) on a jackpot
		jackpotChance = 1 / 3,
		colors = { Color3.fromRGB(255, 214, 70), Color3.fromRGB(60, 220, 120) },
		pose = function(u, t)
			-- hands together, bouncing on your toes while the reels spin; then a fist to the sky
			local bounce = 0.08 * math.abs(math.sin(t * 9))
			local p = mix(stance(), { rootUp = -0.2 + bounce, shRX = 1.5, shRZ = -0.5, elRX = 1.6, shLX = 1.5, shLZ = 0.5, elLX = 1.6, waistX = -0.1, neckX = 0.2 }, 1)
			return mix(p, { rootUp = 0.15, shRX = 3.0, shRZ = 0.2, elRX = 0.2, shLX = 0.4, shLZ = -0.5, elLX = 1.2, waistX = 0.3, neckX = 0.4 }, smooth((u - 1.6) / 0.12))
		end,
	},
	ThiefTome = {
		name = "STOLEN PAGE",
		sub = "Thief's Tome Rod",
		cooldown = 12,
		cut = 1.2,
		impact = 1.2, -- plus the stolen ability's own impact
		length = 1.2, -- plus the stolen ability's own length
		forward = 0,
		radius = 0,
		damage = 0,
		steals = { "Drift", "Coral", "Stormline", "Abyssal", "Riftcaster", "Celestial", "CrimsonCrow", "SunRubber" },
		colors = { Color3.fromRGB(180, 130, 255), Color3.fromRGB(255, 240, 220) },
		pose = function(u)
			-- the open book held up in the left hand, the right hand turning pages
			return mix(stance(), { shLX = 1.5, shLZ = -0.2, elLX = 1.3, shRX = 1.3, shRZ = -0.5, elRX = 1.2 + 0.3 * math.sin(u * 18), neckX = -0.25, waistX = -0.05 }, 1)
		end,
	},
	SunRubber = {
		name = "SUN GOD BOUNCE",
		sub = "Sun Rubber Rod",
		cooldown = 14,
		cut = 1.4,
		impact = 1.65,
		length = 2.4,
		forward = 11,
		radius = 13,
		damage = 4,
		knock = 30,
		colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 110) },
		pose = function(u, t)
			-- laughing and bouncing to the drums, arms wide; then the giant punch
			local beat = math.abs(math.sin(t * 7))
			local p = mix(stance(), { rootUp = -0.4 + 0.5 * beat, waistX = 0.45, neckX = -0.45, shRX = 1.8, shRZ = 1.3, elRX = 0.6, shLX = 1.8, shLZ = -1.3, elLX = 0.6, kneeRX = -0.9 * beat, kneeLX = -0.9 * beat }, 1)
			return mix(p, { rootUp = -0.5, rootX = -0.25, waistX = -0.3, neckX = 0.3, waistY = 0.5, shRX = 1.6, shRZ = 0, elRX = 0, shLX = -0.5, shLZ = -0.4, elLX = 0.6, hipLX = 0.9, kneeLX = -1.0, hipRX = -0.3, kneeRX = -0.3 }, smooth((u - 1.5) / 0.1))
		end,
	},
	Boundless = {
		name = "BOUNDLESS VOID",
		sub = "Boundless Rod",
		cooldown = 25,
		cut = 1.8,
		impact = 2.05,
		length = 3.0,
		forward = 0,
		radius = 30,
		damage = 6,
		stun = 4,
		colors = { Color3.fromRGB(110, 190, 255), Color3.fromRGB(190, 110, 255) },
		pose = function(u)
			-- one hand up before the face, two fingers crossed; calm. Then the hand opens to the void.
			local p = mix(stance(), { shRX = 1.9, shRZ = -0.4, elRX = 2.0, shLX = 0.05, shLZ = -0.1, elLX = 0.2, neckX = 0.05, rootUp = -0.1, hipRX = 0.1, kneeRX = -0.2 }, 1)
			return mix(p, { shRX = 1.7, shRZ = 0.8, elRX = 0.3, shLX = 1.0, shLZ = -0.8, elLX = 0.3, waistX = 0.15, neckX = -0.1 }, smooth((u - 1.95) / 0.15))
		end,
	},
}

function RodSkills.get(rodId)
	return RodSkills.list[rodId] or RodSkills.list.Drift
end

-- The full pose for a cast of `rodId` (with `alt` the stolen ability for the Thief's Tome).
function RodSkills.pose(rodId, alt, u, t)
	local skill = RodSkills.get(rodId)
	if rodId == "ThiefTome" and alt and RodSkills.list[alt] then
		if u < skill.cut then
			return skill.pose(u, t)
		end
		local stolen = RodSkills.list[alt]
		-- the stolen ability without its own cinematic: jump straight to its action
		return stolen.pose(u - skill.cut + stolen.cut, t)
	end
	return skill.pose(u, t)
end

-- How long a cast lasts, and when it hits (the Thief's Tome adds the stolen ability's action after the book).
function RodSkills.timing(rodId, alt)
	local skill = RodSkills.get(rodId)
	if rodId == "ThiefTome" and alt and RodSkills.list[alt] then
		local stolen = RodSkills.list[alt]
		return skill.cut + (stolen.length - stolen.cut), skill.cut + (stolen.impact - stolen.cut)
	end
	return skill.length, skill.impact
end

return RodSkills
