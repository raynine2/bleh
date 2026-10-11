-- Tidebound: Eggfall: every locked value from the Canon Sheet lives here.
-- Server and client both read this module, so the odds the player sees are the odds the server rolls.

local Config = {}

Config.Title = "Tidebound: Eggfall"
Config.Tagline = "Cast. Steal. Hatch. Escape."

Config.Currencies = {
	Pearls = "Pearls", -- soft, 25-120 per fish
	EggShards = "Egg Shards", -- 1 per unique creature, 10 per duplicate
	RunEmbers = "Run Embers", -- 5-25 per successful extraction only
	Tideglass = "Tideglass", -- premium, Robux + free season track only (cosmetics/convenience)
}

-- 7 rarity tiers. `rate` is the Tide Egg base odds (sums to 100.00).
-- `fishRate` is the Sunken Shoals fishing table before rod/bait luck (sums to 100.00).
Config.Tiers = {
	{ id = "Common", rate = 58.00, fishRate = 55.00, color = Color3.fromRGB(176, 190, 197), pearlValue = 50, fishPearls = 25, creatures = { "Tide Sprite", "Barnacle Pup" } },
	{ id = "Uncommon", rate = 24.00, fishRate = 25.00, color = Color3.fromRGB(102, 214, 140), pearlValue = 120, fishPearls = 35, creatures = { "Kelp Crawler", "Shellback Newt" } },
	{ id = "Rare", rate = 12.00, fishRate = 12.00, color = Color3.fromRGB(74, 160, 255), pearlValue = 300, fishPearls = 50, creatures = { "Storm Eel", "Coral Drake" } },
	{ id = "Epic", rate = 4.50, fishRate = 5.00, color = Color3.fromRGB(176, 102, 255), pearlValue = 800, fishPearls = 70, creatures = { "Abyss Angler", "Rift Serpent" } },
	{ id = "Legendary", rate = 1.20, fishRate = 2.20, color = Color3.fromRGB(255, 184, 48), pearlValue = 2500, fishPearls = 90, creatures = { "Tempest Wyrm", "Leviathan Calf" } },
	{ id = "Mythic", rate = 0.25, fishRate = 0.65, color = Color3.fromRGB(255, 72, 120), pearlValue = 8000, fishPearls = 105, creatures = { "Aurora Kraken", "Deep Sovereign" } },
	{ id = "Celestial", rate = 0.05, fishRate = 0.15, color = Color3.fromRGB(140, 255, 250), pearlValue = 30000, fishPearls = 120, creatures = { "Tidebound God", "Prismatic Leviathan" } },
}

-- Independent roll on every hatch (sums to 100.00).
Config.Mutations = {
	{ id = "None", rate = 70.00, mult = 1.00, color = Color3.fromRGB(200, 210, 215), visual = "No mutation" },
	{ id = "Brine", rate = 15.00, mult = 1.25, color = Color3.fromRGB(80, 230, 255), visual = "Cyan drip trail" },
	{ id = "Storm", rate = 9.00, mult = 1.60, color = Color3.fromRGB(255, 240, 110), visual = "Arc lightning" },
	{ id = "Aurora", rate = 4.00, mult = 2.20, color = Color3.fromRGB(140, 255, 170), visual = "Shifting color" },
	{ id = "Abyssal", rate = 1.50, mult = 3.50, color = Color3.fromRGB(120, 90, 160), visual = "Black smoke" },
	{ id = "Prismatic", rate = 0.50, mult = 6.00, color = Color3.fromRGB(255, 140, 240), visual = "Full rainbow refraction" },
}

-- Pity per egg type. `at` is the pull number that is guaranteed. Resets on hit, never hidden.
Config.Pity = {
	{ key = "EpicPlus", label = "Epic+", tier = 4, at = 25 },
	{ key = "LegendaryPlus", label = "Legendary+", tier = 5, at = 90 },
	{ key = "MythicPlus", label = "Mythic+", tier = 6, at = 300 },
	{ key = "CelestialPlus", label = "Celestial (hard pity)", tier = 7, at = 1200 },
}

Config.Eggs = {
	TideEgg = { name = "Tide Egg", pearlCost = 300 },
}

Config.Shards = { unique = 1, duplicate = 10 }

-- Locked rod stats table. Costs are Pearls; Celestial Rod is prestige only.
Config.Rods = {
	{ id = "Drift", name = "Drift Rod", lureSpeed = 1.00, luck = 1.00, control = 1.00, resilience = 1.00, biomes = 3, cost = 0 },
	{ id = "Coral", name = "Coral Rod", lureSpeed = 1.15, luck = 1.20, control = 1.10, resilience = 1.15, biomes = 3, cost = 2500 },
	{ id = "Stormline", name = "Stormline Rod", lureSpeed = 1.35, luck = 1.45, control = 1.25, resilience = 1.30, biomes = 4, cost = 12000 },
	{ id = "Abyssal", name = "Abyssal Rod", lureSpeed = 1.60, luck = 1.75, control = 1.45, resilience = 1.55, biomes = 4, cost = 40000 },
	{ id = "Riftcaster", name = "Riftcaster", lureSpeed = 1.90, luck = 2.10, control = 1.70, resilience = 1.85, biomes = 5, cost = 120000 },
	{ id = "Celestial", name = "Celestial Rod", lureSpeed = 2.50, luck = 3.00, control = 2.20, resilience = 2.40, biomes = 5, cost = 0, prestigeOnly = true },
}

-- Each bait multiplies rod luck on the fish rarity roll. `shop` = sold at the Sunken Shoals nest.
Config.Baits = {
	{ id = "Brineworm", name = "Brineworm", luck = 1.10, cost = 15, shop = true, source = "Nest tackle shop" },
	{ id = "Glowmite", name = "Glowmite", luck = 1.25, cost = 40, shop = true, source = "Nest tackle shop" },
	{ id = "Stormfin", name = "Stormfin", luck = 1.45, cost = 0, shop = false, source = "Storm Shelf" },
	{ id = "AbyssalSquid", name = "Abyssal Squid", luck = 1.70, cost = 0, shop = false, source = "Abyss Trench" },
	{ id = "AuroraKrill", name = "Aurora Krill", luck = 2.00, cost = 0, shop = false, source = "Aurora Rift" },
	{ id = "PrismaticRoe", name = "Prismatic Roe", luck = 2.50, cost = 0, shop = false, source = "Guardian drops" },
}
Config.BaitPackSize = 5

Config.Heat = {
	max = 100,
	perSteal = 8,
	perFish = 2,
	decayInterval = 3, -- -1 heat per 3s without a fish or a steal
	patrolAt = 25,
	hazardAt = 50,
	lockAt = 75,
	beaconCloseAt = 100,
	beaconCloseSeconds = 30,
	-- Master Patch 3 Table C: Riptide Pull pulls toward open water at 8 studs/s, 6 s pulses every 20 s
	riptideEvery = 20,
	riptideSeconds = 6,
	riptideSpeed = 8,
	thresholds = {
		{ at = 25, label = "Reef Warden patrol is out" },
		{ at = 50, label = "Riptide hazard active" },
		{ at = 75, label = "The Reef Warden has locked onto you" },
		{ at = 100, label = "Full Warden alert, beacons closing" },
	},
}

Config.Extraction = {
	baseEmbers = 5,
	embersPerEgg = 5,
	pearlsPerEmber = 50,
	minEmbers = 5,
	maxEmbers = 25,
	-- Master Patch 2: a wipe loses 100% of cargo (carried eggs and unbanked fish). Fish banked at the
	-- Tide Cache are already Pearls in the wallet, so they are always safe.
	-- Run extraction payout (canon 50-400 per run), separate from fish Pearls
	payoutBase = 50,
	payoutPerEgg = 30,
	payoutCap = 400,
}

-- Delta Section 9 + Master Patch 2: risk, loss and tension
Config.Risk = {
	maxHealth = 100, -- Master Patch 2: guardians deal 25-60 per hit
	hitInvulnerable = 1.5,
	knockback = 60,
	carrySlowPerEgg = 2, -- each carried egg costs WalkSpeed (an awake companion carries one for you)
	minWalkSpeed = 10,
	sprintBonus = 6,
	beaconChannel = 3, -- hold to extract
	graceSeconds = 10, -- within 10 studs of a beacon when Heat 100 closes it
	graceRadius = 10,
	lockLoseSight = 6, -- lock-on drops after 6 s without line of sight
	luckyScalePearls = 25, -- an escaped fish whose meter passed 90%
	luckyScaleThreshold = 0.9,
	lockLoseRange = 60, -- beyond this the Warden counts as out of sight
	streakEmberEvery = 3, -- Clean Extraction streak: +1 Ember per 3 in a row, up to +3
	streakEmberMax = 3,
}

-- Master Patch 2: the Greed Window. Every beacon asks: extract now, or push deeper.
Config.Greed = {
	cargoPct = 0.40, -- each push adds +40% cargo value (1.4x, 1.8x, 2.2x), within the Canon caps
	heat = 25,
	aggro = 1, -- the guardian moves one phase up
	embersPerPush = 2, -- within the 25 Ember cap
	choiceSeconds = 10, -- no answer picks Extract now
	leaveRadius = 12, -- walking away from the beacon also picks Extract now
}

-- Master Patch 1: Solo is the default and co-op is opt-in.
Config.Modes = {
	soloPearlMult = 1.15, -- offsets lost co-op scaling; Canon caps still apply (120 per fish, 400 per run)
	crewPerMember = 0.05, -- a Crew earns +5% Pearls per extra member (1.15x at 4)
	crewMax = 4,
	inviteSeconds = 60,
	diveSpawn = CFrame.new(86, 10, 0) * CFrame.Angles(0, -math.pi / 2, 0), -- end of the dock into the Shoals
}

-- Master Patch 1: opt-in PvP egg theft ("Contested Waters"), set before each run, OFF by default and
-- back to OFF after every run. Replaces the Delta's Open Tide toggle with the same theft rule.
Config.Contested = {
	snatchRange = 6, -- a rival behind you holds interact for 1 s
	snatchHold = 1,
	beaconSafeRadius = 40, -- no snatching near an extraction beacon
	immunity = 5, -- seconds of snatch immunity after you are snatched from
	burstSpeed = 3,
	burstSeconds = 3,
	bonusEggChance = 0.2, -- egg nests pay x1.20 in Contested Waters: a 20% chance of a second egg per steal
}

-- Master Patch 3 Table A: the Sunken Shoals guardian. Phase 1 at its trigger, Phase 2 at heat 75,
-- Phase 3 at heat 100. Every strike telegraphs for at least 0.6 s.
Config.Guardian = {
	name = "Reef Warden",
	damage = 25,
	triggerEggs = 3, -- Phase 1 starts on the 3rd egg stolen in a run
	drop = "ReefCore",
	dropName = "Reef Core",
	dropsForPage = 5, -- 5 Reef Cores complete its Bestiary page
	tell = 0.6,
	lungeRange = 10,
	strikeRadius = 7.5,
	recover = 2, -- pause after a strike
	speeds = { patrol = 10, guard = 13, chase = 15, fury = 16.5 },
}

-- Master Patch 2: rod durability. A broken rod fishes as a tier-1 Drift Rod until repaired (Pearls only).
Config.Durability = {
	max = 100,
	perCast = 1,
	perSnap = 10, -- a fish that gets away snaps the line
	repairCost = { Drift = 50, Coral = 150, Stormline = 400, Abyssal = 900, Riftcaster = 2000, Celestial = 3000 }, -- full repair
}

-- Master Patch 2: wiping at heat 75+ carries heat into the next run until you rest at your Home Nest.
Config.HeatCarry = { wipeAt = 75, startHeat = 15, drainSeconds = 180 }

-- Master Patch 2 + 4: vials from Nim's Bait Shop. Pearls only; at most 3 used per run.
Config.Vials = {
	{ id = "Mending", name = "Mending Vial", cost = 150, text = "Heals 25 health" },
	{ id = "Revive", name = "Revive Vial", cost = 200, text = "Wakes a knocked-out companion" },
}
Config.VialHeal = 25
Config.VialsPerRun = 3

-- Master Patch 1 step 4: 2 companion creatures from your collection follow you on dives. Each awake
-- companion carries one egg, so it doesn't slow you down. A Warden hit knocks one out for 10 min.
Config.Companions = { slots = 2, koSeconds = 600 }

-- Master Patch 3 Table B: Sunken Shoals elites. Weights are the spawn chance within the biome's pool.
-- Elites are dodged, not killed: a missed charge or lunge leaves them dazed, and you can loot their bait.
Config.Elites = {
	{ id = "BarnacleBrute", name = "Barnacle Brute", weight = 70, drop = { bait = "Brineworm", count = 5 }, tell = 1, chargeSpeed = 38, chargeDistance = 32, aggroRange = 28, hitRadius = 4.5, stun = 1.5, daze = 4, cooldown = 5 },
	{ id = "SnapjawMoray", name = "Snapjaw Moray", weight = 30, drop = { bait = "Glowmite", count = 2 }, tell = 0.6, range = 6, damage = 10, exposed = 3, cooldown = 4 },
}
Config.EliteLootCooldown = 180 -- per player, per elite

-- Master Patch 3 Table C: Sunken Shoals terrain hazard (always on).
Config.Anemone = { damage = 10, slow = 0.3, tick = 1.5 }

-- Master Patch 3 Table D: Sunken Shoals weather.
Config.Weather = {
	GlassCalm = { name = "Glass Calm", every = 900, firstAfter = 300, duration = 180, warning = 20, biteMult = 0.7, reward = { bait = "Brineworm", count = 3 } },
}

-- Delta Section 10 Table C: camera field of view per situation.
Config.Camera = { exploration = 70, fishing = 65, chase = 80, hatch = 55 }

-- Delta Section 8: the Harbor Ring hub, a ring town around a lagoon with the 8 Home Nest plots on its edge.
-- North (+Z) points back toward the Nest plaza, which stays the Spawn Plaza and the Tidegate to the Shoals.
Config.Harbor = {
	center = Vector3.new(0, 0, -560),
	lagoonRadius = 38,
	groundRadius = 160,
	plotInner = 150, -- plots start here; 8 plots of 120 x 120 need at least 145 so corners don't touch
	plotSize = 120,
	pier = { payoutPct = 0.5, maxTier = 2, baitChance = 0.25 }, -- Lagoon pier fishing: no Heat, banked at once
}

Config.Npcs = {
	Pinch = { name = "Pinch", role = "Guide crab", lines = { "New here? Cast in the Shoals, bank fish at the Tide Cache, steal eggs, then hold at a beacon to extract.", "The Tide Slide behind me goes to the Harbor Ring, where your Home Nest is." } },
	OldHarl = { name = "Old Harl", role = "Tackle Shop", panel = "RODS", lines = { "Every rod's stats are on the rack. No secrets, no Robux.", "Worn rod? I'll repair it for Pearls before you dive." } },
	Nim = { name = "Nim", role = "Bait Shop", panel = "BAIT", lines = { "Brineworm for the shallows, Glowmite when you want rarer bites!", "Mending Vials heal you, Revive Vials wake a companion. Pearls only!" } },
	SisterCoralie = { name = "Sister Coralie", role = "Tide Egg Shrine", panel = "ODDS", lines = { "These are the odds, child, every one of them. Your pity never resets on a wipe." } },
	CaptainBrask = { name = "Captain Brask", role = "Season Pass Board", panel = "QUESTS", lines = { "The season track isn't posted yet. Quill's quests pay Pearls today." } },
	Quill = { name = "Quill", role = "Daily Quest Board", panel = "QUESTS", lines = { "Three quests a day, reset at midnight UTC. Squawk!" } },
	ArchivistOphel = { name = "Archivist Ophel", role = "Leaderboard Hall", panel = "BOARDS", lines = { "The Hall remembers this server's rarest hatches and boldest escapes." } },
	GateWardenSel = { name = "Gate Warden Sel", role = "Tidegate", panel = "DIVE", lines = { "Dive Solo or Dive With Crew. Contested Waters stays off unless you switch it on.", "Push past a beacon and the Shoals pay more, but the Warden gets angrier." } },
	TradesmanKobb = { name = "Tradesman Kobb", role = "Trading Post", lines = { "Trades open when cosmetics arrive. Creatures, eggs and bait never trade, so nobody buys power." } },
}

-- Delta Section 7: Home Nest plots. Zone costs and upgrade curves are from Tables A and B.
Config.Base = {
	plotCount = 8,
	zones = {
		{ id = "hatch", name = "Hatch Chamber", cost = 0, kind = "room" },
		{ id = "aquarium", name = "Aquarium Hall", cost = 0, kind = "room" },
		{ id = "pen", name = "Creature Pen", cost = 3000, kind = "outdoor" },
		{ id = "workshop", name = "Rod Workshop", cost = 5000, kind = "room" },
		{ id = "trophy", name = "Trophy Room", cost = 20000, kind = "room" },
		{ id = "vault", name = "Nest Vault", cost = 8000, kind = "outdoor" },
		{ id = "deck", name = "Visitor Deck", cost = 2000, kind = "outdoor" },
		{ id = "altar", name = "Prestige Altar", cost = 75000, kind = "room", requires = "a Rift Sovereign defeat (Aurora Rift isn't built yet)" },
	},
	upgrades = {
		{ id = "incubators", name = "Incubator slots", zone = "hatch", unit = "eggs hatched at once", values = { 1, 2, 3, 4, 5, 6, 7, 8 }, costs = { 1000, 4000, 10000, 25000, 50000, 100000, 200000 } },
		{ id = "aquarium", name = "Aquarium capacity", zone = "aquarium", unit = "earning creatures", values = { 10, 25, 40, 60, 85, 110, 140, 170, 200 }, costs = { 2000, 6000, 12000, 25000, 45000, 75000, 120000, 180000 } },
		{ id = "filter", name = "Tank Filter", zone = "aquarium", unit = "% aquarium income", values = { 0, 2, 4, 6, 8, 10 }, costs = { 5000, 12000, 25000, 50000, 100000 }, needs = { id = "aquarium", level = 4 } },
		{ id = "treadmill", name = "Treadmill", zone = "pen", unit = "WalkSpeed", values = { 16, 17, 18, 19, 20, 21, 22, 23, 24, 25 }, costs = { 500, 1500, 3000, 5500, 9000, 14000, 21700, 40000, 60000 }, free = true },
		{ id = "pen", name = "Pen size", zone = "pen", unit = "roaming creatures", values = { 3, 6, 9, 12 }, costs = { 8000, 18000, 35000 } },
		{ id = "trophy", name = "Trophy pedestals", zone = "trophy", unit = "pedestals", values = { 6, 12, 18, 24 }, costs = { 30000, 45000, 70000 } },
		{ id = "vault", name = "Vault capacity", zone = "vault", unit = "stored creatures", values = { 100, 250, 500, 750, 1000 }, costs = { 20000, 40000, 70000, 110000 } },
	},
	incomePct = 0.01, -- 1% of a creature's value per minute
	feedBonus = 0.05, -- fed pen creatures: +5% aquarium value for 30 min
	feedMinutes = 30,
	trophyBonusPerLegendary = 0.01, -- each Legendary+ on a pedestal: +1% aquarium income
	trophyBonusCap = 0.10,
	offlineRate = 0.5, -- offline aquarium income is 50% of online, up to 8 h
	offlineCapHours = 8,
	admireShards = 1, -- a visitor admiring your Showcase Plinth: +1 Egg Shard, 10 per day
	admireDailyCap = 10,
	duplicateSellPct = 0.5, -- duplicate sales pay half the creature's value
	baseStorage = 200, -- creatures kept without a Nest Vault; overflow is sold at duplicateSellPct
	privacy = { "Public", "Friends", "Private" },
	guestbookSize = 6,
}

-- Delta Section 8 / 11: daily quests on Quill's board (300-800 Pearls each, reset 00:00 UTC)
Config.Quests = {
	{ id = "fish", text = "Catch 5 fish", goal = 5, reward = 300 },
	{ id = "steal", text = "Steal 3 wild eggs", goal = 3, reward = 500 },
	{ id = "extract", text = "Extract 2 times", goal = 2, reward = 800 },
}

Config.Fishing = {
	biteMin = 2,
	biteMax = 5,
	minReelSeconds = 1.0, -- server rejects catches faster than bite + this
	perfectBonus = 1.2,
	baseBarWidth = 0.22, -- times rod Control
	reelAccel = 2.6,
	gainPerSecond = 0.32,
	lossPerSecond = 0.22, -- divided by rod Resilience
	startProgress = 0.3,
}

-- Master Patch 6: the fish reveal. Seconds per phase; the tier climb holds `step` on every tier it passes.
-- The server rolls the tier at the cast and the mutation and weight at the landing; the reveal only shows it.
Config.Reveal = {
	silhouette = 0.4, -- Phase 1
	step = 0.3, -- Phase 2, per tier
	card = 0.8, -- Phase 3
	celebrate = 0.8, -- Phase 4
	back = 0.5, -- Phase 5
	nearMissChance = 0.4, -- fish only, below Celestial: the climb goes one tier past, holds, then drains back
	nearMissHold = 0.3,
	nearMissDrain = 0.3,
	npcLookRadius = 60, -- Mythic and up: NPCs this close turn to look
	landSeconds = 1.35, -- Patch 5: Land-Flip (1.0 s at half speed) and Land-Hold (0.35 s) come first
	-- weight in kg per tier, for show only (never changes Pearls)
	weights = { { 0.2, 1.5 }, { 0.8, 4 }, { 2, 9 }, { 5, 20 }, { 12, 45 }, { 30, 110 }, { 80, 300 } },
}

-- 2.8 s for a Common up to 4.6 s for a Celestial; the near-miss adds 0.6 s.
function Config.revealSeconds(tierIndex, nearMiss)
	local r = Config.Reveal
	local seconds = r.silhouette + tierIndex * r.step + r.card + r.celebrate + r.back
	return seconds + (nearMiss and r.nearMissHold + r.nearMissDrain or 0)
end

Config.Aquarium = {
	capacity = 10, -- creatures that earn passive income
	maxStored = 200,
	incomeDivisor = 100, -- Pearls per minute = creature value / 100
}

Config.Warden = {
	patrolSpeed = 10,
	chaseSpeed = 15, -- just under default walk speed so a clean escape is possible
	hoverY = 8,
	catchRadius = 7,
}

Config.World = {
	nestRadius = 46,
	wardenNoGoRadius = 54,
	spawnCFrame = CFrame.new(0, 10, -24),
	eggRespawnSeconds = 45,
	beaconOpenColor = Color3.fromRGB(90, 255, 200),
	beaconClosedColor = Color3.fromRGB(255, 70, 70),
}

-- Biome order is canon. Only Sunken Shoals is built so far.
Config.Biomes = {
	{
		id = "SunkenShoals",
		name = "Sunken Shoals",
		hazard = "Riptide pull",
		guardian = "Reef Warden",
		built = true,
		weather = "Glass Calm",
		fish = {
			{ "Sand Minnow", "Reef Sprat" },
			{ "Glass Shrimp", "Striped Grunt" },
			{ "Lantern Puffer", "Coral Trout" },
			{ "Sunfin Ray", "Pearl Moray" },
			{ "Shoal Monarch", "Gilded Barracuda" },
			{ "Riptide Marlin" },
			{ "Eggfall Koi" },
		},
	},
	{ id = "KelpCathedral", name = "Kelp Cathedral", hazard = "Grasping vines slow player", guardian = "Kelp Leviathan" },
	{ id = "StormShelf", name = "Storm Shelf", hazard = "Lightning strikes random spots", guardian = "Storm Herald" },
	{ id = "AbyssTrench", name = "Abyss Trench", hazard = "Sonar pulses reveal player to Warden", guardian = "Trench Maw" },
	{ id = "AuroraRift", name = "Aurora Rift", hazard = "Gravity shifts + aurora ribbons blind vision", guardian = "Rift Sovereign" },
}

-- Safe zones: the Nest plaza and the Harbor Ring. No Warden, no Heat hazards, and hatching is allowed.
function Config.safeZone(position)
	local flat = Vector3.new(position.X, 0, position.Z)
	if flat.Magnitude <= Config.World.nestRadius then
		return "Nest"
	end
	local h = Config.Harbor.center
	if (flat - Vector3.new(h.X, 0, h.Z)).Magnitude <= Config.Harbor.plotInner + Config.Harbor.plotSize * 1.5 then
		return "Harbor"
	end
	return nil
end

Config.LegalText = "Odds are per pull and shown before every purchase or hatch. Pity counters only reset when you hit that tier and are never hidden. "
	.. "Tide Eggs are earned free by stealing them in the Sunken Shoals. Robux never buys eggs, odds, pity, speed or power."

Config.RodsById, Config.BaitById, Config.TierIndexById = {}, {}, {}
for _, rod in ipairs(Config.Rods) do
	Config.RodsById[rod.id] = rod
end
for _, bait in ipairs(Config.Baits) do
	Config.BaitById[bait.id] = bait
end
for index, tier in ipairs(Config.Tiers) do
	Config.TierIndexById[tier.id] = index
end

return Config
