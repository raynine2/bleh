-- Tidebound: Eggfall: persistent player saves (DataStore). Run state lives in Main and is never saved.

local DataStoreService = game:GetService("DataStoreService")

local PlayerData = {}

local STORE_NAME = "TideboundEggfall_v1"
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Tidebound] DataStore unavailable, progress will not save:", result)
	end
end

local profiles = {} -- [Player] = { data = table, canSave = boolean }

local function template()
	return {
		version = 1,
		pearls = 150,
		shards = 0,
		embers = 0,
		tideglass = 0,
		eggs = 1, -- one starter Tide Egg so the first hatch happens in minute one
		rod = "Drift",
		ownedRods = { Drift = true },
		bait = "",
		baitInv = {},
		pity = {
			TideEgg = { EpicPlus = 0, LegendaryPlus = 0, MythicPlus = 0, CelestialPlus = 0 },
			DashCapsule = { EpicPlus = 0, LegendaryPlus = 0, MythicPlus = 0, CelestialPlus = 0 }, -- Patch 20
			TideChest = { EpicPlus = 0, LegendaryPlus = 0, MythicPlus = 0, CelestialPlus = 0 }, -- Patch 23
		},
		-- Patch 20: dash moves owned (DashMoves key = copies), the ones equipped, and capsules to open
		dashes = { Zoomies = 1 },
		equippedDashes = { "Zoomies" },
		capsules = 1,
		-- Patch 21: mobs defeated, per kind and in total ("any"), for the Rod Trials
		mobKills = { any = 0, crab = 0, puffer = 0, gull = 0, shark = 0, golem = 0 },
		collection = {},
		aquarium = {},
		history = {},
		bestiary = {},
		stats = {
			fishCaught = 0,
			hatched = 0,
			extractions = 0,
			wipes = 0,
			cleanStreak = 0,
			bestStreak = 0,
			bestHeatExtract = 0,
			bestHatchValue = 0,
			bestHatch = "",
			-- Master Patch 1: every leaderboard has separate Solo and Crew boards
			modes = {
				Solo = { extractions = 0, cleanStreak = 0, bestStreak = 0, bestHeatExtract = 0, deepestPush = 0, bestHatchValue = 0, bestHatch = "" },
				Crew = { extractions = 0, cleanStreak = 0, bestStreak = 0, bestHeatExtract = 0, deepestPush = 0, bestHatchValue = 0, bestHatch = "" },
			},
		},
		crewEggs = 0, -- eggs extracted on Crew runs and not hatched yet (they count toward the Crew rarest-hatch board)
		-- Master Patch 2: rod durability (missing = full), vials, carried heat, guardian trophies
		rodDura = {},
		vials = { Mending = 0, Revive = 0 },
		heatDebt = 0,
		heatDebtRest = 0, -- seconds rested at your Home Nest toward clearing it
		trophies = { ReefCore = 0, KelpScale = 0 },
		seenIntro = false, -- Big Update: the opening cutscene plays once
		-- Master Patch 1 step 4: two companion slots (creature names) and knock-out timers (os.time)
		companions = { slots = { "", "" }, ko = {} },
		-- Delta Section 7: Home Nest zones (true = unlocked) and upgrade levels (1 = first value)
		zones = { hatch = true, aquarium = true },
		levels = { incubators = 1, aquarium = 1, filter = 1, treadmill = 1, pen = 1, trophy = 1, vault = 1 },
		fedUntil = 0,
		admires = { day = 0, count = 0, visitors = {} },
		quests = { day = 0, progress = {}, claimed = {} },
		settings = { contested = false, privacy = "Public" },
		guestbook = {},
		lastSeen = 0,
	}
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fills keys missing from an older save without touching existing values.
local function reconcile(target, source)
	for key, value in pairs(source) do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player)
	return "p_" .. player.UserId
end

function PlayerData.load(player)
	local data = nil
	local canSave = store ~= nil
	if store then
		local loaded = false
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(("[Tidebound] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			task.wait(1)
		end
		-- Never overwrite a save we failed to read.
		canSave = loaded
	end
	if type(data) ~= "table" then
		data = template()
	end
	reconcile(data, template())
	profiles[player] = { data = data, canSave = canSave }
	return data
end

function PlayerData.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerData.save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	profile.data.lastSeen = os.time()
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), profile.data)
	end)
	if not ok then
		warn("[Tidebound] Save failed for", player.Name, err)
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.saveAll()
	for player in pairs(profiles) do
		task.spawn(PlayerData.save, player)
	end
	task.wait(2)
end

return PlayerData
