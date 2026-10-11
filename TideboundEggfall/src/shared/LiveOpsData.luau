-- Tidebound: Eggfall: retention tables (GDD Sections 6, 7, 12): daily quests, weekly goals, seasonal events, the
-- season pass, collection goals, the shop and the global leaderboards. Server (LiveOps) and client (TideboundMenus)
-- both read this, but only the server grants anything: the client shows these tables, the server checks them.
--
-- Placeholder numbers: the GDD's Section 6/11/12/13 tables weren't in the handoff, so these values follow the
-- existing economy (Config: 25-120 Pearls per fish, 300-800 per daily quest, 100 Tideglass per 10 season tiers).
-- Change any number here; nothing else needs touching.
--
-- Canon policy, enforced by these tables: no pay-to-win (Robux and Tideglass only buy cosmetics), every odds table
-- is shown, and every reward is coloured by the canon rarity spectrum (White, Green, Blue, Purple, Gold).

local LiveOpsData = {}

-- Events the server counts (LiveOps.track). Each quest/goal names one of these.
LiveOpsData.events = {
	fish = "Catch fish",
	rareFish = "Catch Rare+ fish",
	steal = "Steal wild eggs",
	extract = "Extract",
	hatch = "Hatch eggs",
	bank = "Bank cargo at a Tide Cache",
	mob = "Beat wild mobs",
	push = "Push deeper at a beacon",
	pearls = "Earn Pearls from fish",
}

-- Reward kinds: pearls, shards, embers, tideglass, bait (+ id), xp (season), cosmetic (+ id). `tier` colours the
-- reward chip with the canon rarity spectrum (1 White ... 5 Gold).

-- Daily quests: 3 a day from this pool, the same 3 for everyone, reset 00:00 UTC (Delta Section 8 / 11).
LiveOpsData.daily = {
	count = 3,
	pool = {
		{ id = "d_fish", event = "fish", goal = 5, text = "Catch 5 fish", reward = { pearls = 300, xp = 150 }, tier = 1 },
		{ id = "d_fish_big", event = "fish", goal = 12, text = "Catch 12 fish", reward = { pearls = 550, xp = 200 }, tier = 2 },
		{ id = "d_rare", event = "rareFish", goal = 2, text = "Catch 2 Rare or better fish", reward = { pearls = 600, xp = 200 }, tier = 3 },
		{ id = "d_steal", event = "steal", goal = 3, text = "Steal 3 wild eggs", reward = { pearls = 500, xp = 200 }, tier = 2 },
		{ id = "d_extract", event = "extract", goal = 2, text = "Extract 2 times", reward = { pearls = 800, xp = 250 }, tier = 3 },
		{ id = "d_hatch", event = "hatch", goal = 3, text = "Hatch 3 eggs", reward = { pearls = 400, shards = 5, xp = 150 }, tier = 2 },
		{ id = "d_bank", event = "bank", goal = 2, text = "Bank cargo at a Tide Cache twice", reward = { pearls = 350, xp = 150 }, tier = 1 },
		{ id = "d_mob", event = "mob", goal = 8, text = "Beat 8 wild mobs with your rod", reward = { pearls = 450, bait = { id = "Glowmite", count = 2 }, xp = 150 }, tier = 2 },
		{ id = "d_push", event = "push", goal = 1, text = "Push deeper at a beacon once", reward = { pearls = 700, embers = 5, xp = 250 }, tier = 3 },
	},
}

-- Weekly goals: 5 a week from this pool, reset Monday 00:00 UTC.
LiveOpsData.weekly = {
	count = 5,
	pool = {
		{ id = "w_fish", event = "fish", goal = 60, text = "Catch 60 fish", reward = { pearls = 2500, xp = 600 }, tier = 2 },
		{ id = "w_rare", event = "rareFish", goal = 15, text = "Catch 15 Rare or better fish", reward = { pearls = 3000, shards = 15, xp = 700 }, tier = 3 },
		{ id = "w_steal", event = "steal", goal = 25, text = "Steal 25 wild eggs", reward = { pearls = 3500, xp = 700 }, tier = 3 },
		{ id = "w_extract", event = "extract", goal = 12, text = "Extract 12 times", reward = { pearls = 4000, embers = 20, xp = 800 }, tier = 4 },
		{ id = "w_hatch", event = "hatch", goal = 20, text = "Hatch 20 eggs", reward = { shards = 40, xp = 600 }, tier = 3 },
		{ id = "w_mob", event = "mob", goal = 60, text = "Beat 60 wild mobs", reward = { pearls = 2000, bait = { id = "Glowmite", count = 10 }, xp = 600 }, tier = 2 },
		{ id = "w_pearls", event = "pearls", goal = 6000, text = "Earn 6,000 Pearls from fish", reward = { pearls = 2000, xp = 600 }, tier = 2 },
		{ id = "w_push", event = "push", goal = 6, text = "Push deeper 6 times", reward = { tideglass = 10, embers = 15, xp = 800 }, tier = 4 },
	},
}

-- Seasonal events: personal goals while the event runs (UTC dates). The first event whose window holds now is live.
LiveOpsData.seasonal = {
	{
		id = "eggfall_festival_2026",
		name = "Eggfall Festival",
		blurb = "The tide brings eggs ashore. Steal, hatch and extract for festival rewards.",
		starts = { year = 2026, month = 10, day = 1 },
		ends = { year = 2026, month = 11, day = 30 },
		color = Color3.fromRGB(255, 196, 40),
		goals = {
			{ id = "e_steal", event = "steal", goal = 40, text = "Steal 40 wild eggs", reward = { pearls = 3000, xp = 500 }, tier = 3 },
			{ id = "e_hatch", event = "hatch", goal = 30, text = "Hatch 30 eggs", reward = { cosmetic = "trail_festival", xp = 500 }, tier = 4 },
			{ id = "e_extract", event = "extract", goal = 20, text = "Extract 20 times", reward = { cosmetic = "title_festival", tideglass = 25 }, tier = 5 },
		},
	},
	{
		id = "abyssal_blackout_2026",
		name = "Abyssal Blackout",
		blurb = "The deep goes dark. Push deeper and bring back the rarest catches.",
		starts = { year = 2026, month = 12, day = 1 },
		ends = { year = 2027, month = 1, day = 15 },
		color = Color3.fromRGB(143, 0, 255),
		goals = {
			{ id = "e_push", event = "push", goal = 15, text = "Push deeper 15 times", reward = { pearls = 4000, xp = 500 }, tier = 4 },
			{ id = "e_rare", event = "rareFish", goal = 25, text = "Catch 25 Rare or better fish", reward = { cosmetic = "trail_abyss", xp = 500 }, tier = 4 },
			{ id = "e_mob", event = "mob", goal = 100, text = "Beat 100 wild mobs", reward = { cosmetic = "title_abyss", tideglass = 25 }, tier = 5 },
		},
	},
}

-- Season pass: XP from quests, goals and play; 30 tiers. The free track pays Pearls, Shards, bait and 100 Tideglass
-- per 10 tiers; the premium track is cosmetic only. `premiumPassId` is the game pass that unlocks premium
-- (0 = not on sale yet, the button says so).
LiveOpsData.season = {
	id = "S1",
	name = "Season 1: Rising Tide",
	starts = { year = 2026, month = 10, day = 1 },
	ends = { year = 2026, month = 12, day = 31 },
	xpPerTier = 1000,
	premiumPassId = 0,
	-- XP for playing, on top of quest rewards
	playXp = { fish = 10, rareFish = 15, steal = 25, extract = 60, hatch = 15, bank = 10, mob = 4, push = 40 },
	tiers = {},
}
do
	local S = LiveOpsData.season
	local premiumCosmetics = {
		[5] = "trail_tide", [10] = "title_tidebound", [15] = "trail_coral", [20] = "title_deepdiver",
		[25] = "trail_aurora", [30] = "title_sovereign",
	}
	for tier = 1, 30 do
		local free
		if tier % 10 == 0 then
			free = { tideglass = 100 }
		elseif tier % 5 == 0 then
			free = { shards = 25 }
		elseif tier % 3 == 0 then
			free = { bait = { id = "Glowmite", count = 5 } }
		else
			free = { pearls = 250 + tier * 50 }
		end
		local premium = premiumCosmetics[tier] and { cosmetic = premiumCosmetics[tier] } or { pearls = 400 + tier * 60 }
		S.tiers[tier] = { free = free, premium = premium, tier = math.min(5, 1 + tier // 7) }
	end
end

-- Collection goals: milestones for unique creatures hatched and unique fish caught (the Bestiary).
LiveOpsData.collection = {
	creatures = {
		{ id = "c_1", goal = 1, text = "Hatch your first creature", reward = { pearls = 200 }, tier = 1 },
		{ id = "c_3", goal = 3, text = "Collect 3 creatures", reward = { pearls = 600, shards = 5 }, tier = 2 },
		{ id = "c_5", goal = 5, text = "Collect 5 creatures", reward = { pearls = 1200, shards = 10 }, tier = 3 },
		{ id = "c_8", goal = 8, text = "Collect 8 creatures", reward = { pearls = 2500, cosmetic = "title_collector" }, tier = 4 },
		{ id = "c_11", goal = 11, text = "Collect 11 creatures", reward = { pearls = 5000, tideglass = 25 }, tier = 4 },
		{ id = "c_14", goal = 14, text = "Collect all 14 creatures", reward = { cosmetic = "trail_prismatic", tideglass = 50 }, tier = 5 },
	},
	fish = {
		{ id = "f_3", goal = 3, text = "Log 3 fish species", reward = { pearls = 200 }, tier = 1 },
		{ id = "f_8", goal = 8, text = "Log 8 fish species", reward = { pearls = 800, bait = { id = "Glowmite", count = 5 } }, tier = 2 },
		{ id = "f_15", goal = 15, text = "Log 15 fish species", reward = { pearls = 2000, shards = 15 }, tier = 3 },
		{ id = "f_24", goal = 24, text = "Log all 24 fish species", reward = { cosmetic = "title_angler", tideglass = 50 }, tier = 5 },
	},
}

-- Cosmetics. Trails ride on your character; titles float over your head. Nothing here changes a stat.
LiveOpsData.cosmetics = {
	trail_tide = { kind = "trail", name = "Tide Trail", colors = { Color3.fromRGB(0, 127, 255), Color3.fromRGB(150, 220, 255) }, tier = 3 },
	trail_coral = { kind = "trail", name = "Coral Trail", colors = { Color3.fromRGB(255, 127, 127), Color3.fromRGB(64, 224, 208) }, tier = 3 },
	trail_aurora = { kind = "trail", name = "Aurora Trail", colors = { Color3.fromRGB(140, 255, 170), Color3.fromRGB(170, 90, 255) }, tier = 4 },
	trail_festival = { kind = "trail", name = "Festival Trail", colors = { Color3.fromRGB(255, 196, 40), Color3.fromRGB(255, 120, 60) }, tier = 4 },
	trail_abyss = { kind = "trail", name = "Abyss Trail", colors = { Color3.fromRGB(25, 25, 112), Color3.fromRGB(143, 0, 255) }, tier = 4 },
	trail_prismatic = { kind = "trail", name = "Prismatic Trail", colors = { Color3.fromRGB(255, 140, 240), Color3.fromRGB(140, 255, 250) }, tier = 5 },
	trail_ember = { kind = "trail", name = "Ember Trail", colors = { Color3.fromRGB(255, 191, 0), Color3.fromRGB(150, 20, 10) }, tier = 3 },
	trail_seafoam = { kind = "trail", name = "Seafoam Trail", colors = { Color3.fromRGB(240, 244, 248), Color3.fromRGB(80, 220, 120) }, tier = 2 },
	title_tidebound = { kind = "title", name = "Tidebound", color = Color3.fromRGB(60, 150, 255), tier = 3 },
	title_deepdiver = { kind = "title", name = "Deep Diver", color = Color3.fromRGB(170, 90, 255), tier = 4 },
	title_sovereign = { kind = "title", name = "Tide Sovereign", color = Color3.fromRGB(255, 196, 40), tier = 5 },
	title_festival = { kind = "title", name = "Festival Star", color = Color3.fromRGB(255, 196, 40), tier = 5 },
	title_abyss = { kind = "title", name = "Blackout Survivor", color = Color3.fromRGB(170, 90, 255), tier = 5 },
	title_collector = { kind = "title", name = "Collector", color = Color3.fromRGB(80, 220, 120), tier = 4 },
	title_angler = { kind = "title", name = "Master Angler", color = Color3.fromRGB(255, 196, 40), tier = 5 },
	title_rookie = { kind = "title", name = "Rookie Raider", color = Color3.fromRGB(240, 244, 248), tier = 1 },
}

-- The shop. Prices are Pearls or Tideglass; Tideglass packs are Robux Developer Products (`productId` 0 = not on
-- sale yet). Supplies call the existing bait and vial handlers, so their prices stay in Config.
LiveOpsData.shop = {
	cosmetics = {
		{ id = "trail_seafoam", price = { pearls = 5000 } },
		{ id = "trail_ember", price = { pearls = 15000 } },
		{ id = "title_rookie", price = { pearls = 1000 } },
		{ id = "trail_tide", price = { tideglass = 150 } },
		{ id = "trail_coral", price = { tideglass = 200 } },
		{ id = "title_tidebound", price = { tideglass = 120 } },
	},
	tideglassPacks = {
		{ id = "tg_small", name = "Pouch of Tideglass", amount = 100, robux = 49, productId = 0 },
		{ id = "tg_medium", name = "Chest of Tideglass", amount = 550, robux = 249, productId = 0 },
		{ id = "tg_large", name = "Vault of Tideglass", amount = 1200, robux = 499, productId = 0 },
	},
	supplies = { "Brineworm", "Glowmite", "Mending", "Revive" }, -- Config.Baits / Config.Vials ids
	note = "Tideglass and Robux only buy cosmetics. Eggs, odds, pity, speed and power are never for sale.",
}

-- Global leaderboards (Section 10 Table C): OrderedDataStores, written every 5 minutes, top 100 read back.
LiveOpsData.leaderboards = {
	{ id = "Coins", store = "Leaderboard_Coins", title = "RICHEST DIVERS", unit = "Pearls", stat = "pearls" },
	{ id = "Eggs", store = "Leaderboard_Eggs", title = "MOST EGGS HATCHED", unit = "hatched", stat = "hatched" },
}
LiveOpsData.leaderboardEvery = 300
LiveOpsData.leaderboardSize = 100

-- UTC day / week numbers, the same on server and client.
function LiveOpsData.dayNumber(t)
	return math.floor((t or os.time()) / 86400)
end

function LiveOpsData.weekNumber(t)
	-- day 0 (1 Jan 1970) was a Thursday; +3 makes weeks start on Monday
	return math.floor((LiveOpsData.dayNumber(t) + 3) / 7)
end

function LiveOpsData.secondsToNextDay(t)
	t = t or os.time()
	return 86400 - t % 86400
end

function LiveOpsData.secondsToNextWeek(t)
	t = t or os.time()
	local nextWeekDay = (LiveOpsData.weekNumber(t) + 1) * 7 - 3
	return nextWeekDay * 86400 - t
end

local function stamp(date)
	return os.time({ year = date.year, month = date.month, day = date.day, hour = 0, min = 0, sec = 0 })
end
LiveOpsData.stamp = stamp

-- Deterministic picks: everyone gets the same quests for a day or week.
local function pick(pool, count, seed)
	local rng = Random.new(seed)
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	for i = #indices, 2, -1 do
		local j = rng:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local out = {}
	for i = 1, math.min(count, #pool) do
		table.insert(out, pool[indices[i]])
	end
	return out
end

function LiveOpsData.dailyQuests(day)
	return pick(LiveOpsData.daily.pool, LiveOpsData.daily.count, 7919 * (day or LiveOpsData.dayNumber()))
end

function LiveOpsData.weeklyGoals(week)
	return pick(LiveOpsData.weekly.pool, LiveOpsData.weekly.count, 104729 * (week or LiveOpsData.weekNumber()))
end

function LiveOpsData.activeEvent(t)
	t = t or os.time()
	for _, event in ipairs(LiveOpsData.seasonal) do
		if t >= stamp(event.starts) and t < stamp(event.ends) + 86400 then
			return event
		end
	end
	return nil
end

function LiveOpsData.eventEnds(event)
	return stamp(event.ends) + 86400
end

function LiveOpsData.seasonActive(t)
	t = t or os.time()
	local S = LiveOpsData.season
	return t >= stamp(S.starts) and t < stamp(S.ends) + 86400
end

function LiveOpsData.seasonTier(xp)
	return math.min(#LiveOpsData.season.tiers, math.floor((xp or 0) / LiveOpsData.season.xpPerTier))
end

return LiveOpsData
