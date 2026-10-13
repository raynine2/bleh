-- Tidebound: Eggfall: the Fishing Overhaul (12 Oct 2026), copied from the Fisch "Best Money Spots" video.
-- Shared numbers for the server (ServerScriptService.Tidebound.FishingPlusService) and the screen
-- (StarterPlayerScripts.TideboundFishingPlus). Nothing here changes a Canon value: rod stats, bait luck, tier odds,
-- mutation odds and the Pearl caps (120 per fish, 400 per run) are untouched. These only lean the rarity roll
-- the same way rods and bait already do, and decide what the screen shows.
--
--   Surges: each biome's timed event, like Fisch's Brine Storm. It lasts 5 minutes, then rests 7 minutes
--           (the video's exact patch numbers). After the rest, Disturbance builds from every catch in that biome
--           (and slowly by itself, so solo players get it too); at 100 the Surge spawns. Fishing inside it leans
--           the rarity roll.
--   Roamers: rare fish you can see swimming near the fishing spots, like the video's roaming Glacial Squid.
--           Cast at the spot they circle to hook that exact fish. More come out at night.
--   Conditions: rod x bait x biome x night x Surge all multiply, and the cast shows the full sum.
--   Rod roles: each Canon rod keeps its locked stats and gets one job, like the video's summoning rod and
--           farming rod.
--   MAX cast: a power bar above your head while the line flies; stop it at the top for "MAX!" and a head start
--           on the reel.
--   Run summary: after extraction, big green Pearls and Pearls per minute, like the video's money-per-hour text.

local FishingPlus = {}

FishingPlus.Surge = {
	duration = 300, -- 5 minutes on (the video's Brine Storm after the patch)
	cooldown = 420, -- then a 7-minute rest before Disturbance can build again
	firstCooldown = 90, -- after a server starts
	disturbanceMax = 100,
	perCatch = 10, -- Disturbance per fish caught in that biome, by anyone
	passiveEvery = 6, -- +1 Disturbance every 6 s while it's building, so a solo player always gets one
	radius = 45, -- studs from the Surge's centre that count as "inside"
	luck = 1.6, -- multiplies the rarity roll inside a Surge
}

-- One Surge per Canon biome. Only built biomes (Sunken Shoals, Kelp Cathedral) spawn one; the rest are ready
-- for when their maps exist.
FishingPlus.Surges = {
	{ biome = 1, name = "Brine Pool", look = "pool", color = Color3.fromRGB(70, 255, 150), glow = Color3.fromRGB(150, 255, 200), text = "A glowing Brine Pool bubbles up in the Sunken Shoals!" },
	{ biome = 2, name = "Abyssal Darkness", look = "void", color = Color3.fromRGB(255, 40, 200), glow = Color3.fromRGB(140, 40, 255), text = "Abyssal Darkness tears open in the Kelp Cathedral!" },
	{ biome = 3, name = "Lightning Swarm", look = "storm", color = Color3.fromRGB(255, 240, 110), glow = Color3.fromRGB(120, 200, 255), text = "A Lightning Swarm hits the Storm Shelf!" },
	{ biome = 4, name = "Black Hole", look = "void", color = Color3.fromRGB(180, 60, 255), glow = Color3.fromRGB(90, 30, 180), text = "A Black Hole opens over the Abyss Trench!" },
	{ biome = 5, name = "Starfall", look = "stars", color = Color3.fromRGB(255, 228, 130), glow = Color3.fromRGB(255, 140, 240), text = "Starfall rains over the Aurora Rift!" },
}

FishingPlus.Roamers = {
	perBiome = 4, -- swimming at once, per built biome
	nightExtra = 3, -- more come out at night
	respawn = 25, -- seconds after one is hooked
	hookRadius = 18, -- studs from the spot you cast at (they circle 7-16 out)
	minOrbit = 7, -- they circle a fishing spot this far out
	maxOrbit = 16,
	swimEvery = { 2.5, 4.5 }, -- seconds per swim leg
	-- which tier a roamer is (index = tier). Rare and up only; sums to 100.
	tierWeights = { 0, 0, 55, 28, 12, 4, 1 },
	nightTierWeights = { 0, 0, 40, 32, 18, 8, 2 },
}

FishingPlus.Night = { luck = 1.15, from = 18, to = 6 } -- Lighting.ClockTime 18:00 to 06:00

-- Every Canon rod keeps its locked stats; each gets one job (the video's "summoning rod" and "farming rod").
FishingPlus.RodRoles = {
	Drift = { role = "Steady", text = "No tricks. A fair first rod." },
	Coral = { role = "Tidecaller", text = "Your catches add double Disturbance, so Surges come sooner.", disturbanceMult = 2 },
	Stormline = { role = "Static Hook", text = "Bites come 30% faster inside a Surge.", surgeBite = 0.7 },
	Abyssal = { role = "Deep Lure", text = "Hooks roaming fish from much further away.", hookRadius = 30 },
	Riftcaster = { role = "Rift Echo", text = "Surge luck is x1.8 instead of x1.6.", surgeLuck = 1.8 },
	Celestial = { role = "Starfall", text = "A MAX cast gives a much bigger head start on the reel.", maxBonus = 0.3 },
}

FishingPlus.Cast = {
	sweepSeconds = 0.9, -- the power bar fills top to bottom in this long, then falls back
	maxZone = 0.9, -- stop it above this for MAX!
	maxBonus = 0.15, -- MAX! starts the reel this much further along
	goodBonus = 0.05, -- above 60%
	window = 1.8, -- the bar locks by itself after this long
}

-- Fishing Fight (12 Oct 2026): a catch streak. Every fish you land in a row (no fish that got away) leans your
-- next roll a little more, +5% per catch up to +25%, and each catch can turn up a free Brineworm (8%, +2% per
-- streak step, up to 18%). Like Night and Surges it only leans the rarity roll; Pearl caps are untouched.
FishingPlus.Streak = {
	from = 2, -- the bonus starts on your 2nd catch in a row
	perCatch = 0.05,
	maxSteps = 5, -- so x1.25 at most
	bait = "Brineworm",
	baitChance = 0.08,
	baitPerStep = 0.02,
	baitMax = 0.18,
}

function FishingPlus.streakLuck(count)
	local s = FishingPlus.Streak
	if count < s.from then
		return 1
	end
	return 1 + math.min(s.maxSteps, count - 1) * s.perCatch
end

function FishingPlus.isNight(clockTime)
	local n = FishingPlus.Night
	return clockTime >= n.from or clockTime < n.to
end

function FishingPlus.role(rodId)
	return FishingPlus.RodRoles[rodId] or FishingPlus.RodRoles.Drift
end

function FishingPlus.surgeFor(biome)
	for _, s in ipairs(FishingPlus.Surges) do
		if s.biome == biome then
			return s
		end
	end
	return nil
end

-- "3:42"
function FishingPlus.clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

return FishingPlus
