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
		-- GDD Sections 6 / 10 / 12 (LiveOps): weekly goals, the live event, the season pass, collection goals,
		-- cosmetics, and audio / VFX / accessibility settings (the Settings_<UserId> row lives here too)
		weekly = { week = 0, progress = {}, claimed = {} },
		eventProgress = { id = "", progress = {}, claimed = {} },
		season = { id = "", xp = 0, claimedFree = {}, claimedPremium = {} },
		collectionClaimed = {},
		cosmetics = { owned = {}, trail = "", title = "" },
		settings = {
			contested = false,
			privacy = "Public",
			musicVolume = 1,
			sfxVolume = 1,
			ambienceVolume = 1,
			uiVolume = 1,
			reduceFlashing = false,
			cameraShake = true,
			vfxQuality = "Auto",
		},
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

-- Section 10 Table C: saves go through UpdateAsync with a version check. Every save bumps `saveVersion`; a save
-- whose version doesn't match what this server loaded means another server wrote since, so it is refused rather
-- than overwriting newer progress. `session` marks which server holds the profile, so a fast rejoin waits for the
-- old server's last save before loading.
local SESSION_STALE = 90 -- seconds after which a session mark from a crashed server is ignored

function PlayerData.load(player)
	local data = nil
	local canSave = store ~= nil
	if store then
		local loaded = false
		for attempt = 1, 5 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				local session = type(data) == "table" and data.session
				local busy = type(session) == "table" and session.job ~= game.JobId and os.time() - (session.t or 0) < SESSION_STALE
				if not busy or attempt >= 4 then
					break
				end
				task.wait(2) -- another server is still saving this player; give it a moment
			else
				warn(("[Tidebound] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
				task.wait(1)
			end
		end
		-- Never overwrite a save we failed to read.
		canSave = loaded
	end
	if type(data) ~= "table" then
		data = template()
	end
	reconcile(data, template())
	profiles[player] = { data = data, canSave = canSave, version = data.saveVersion or 0 }
	return data
end

function PlayerData.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerData.save(player, releasing)
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return
	end
	-- one save at a time per player, so the 60 s save and the leave save never race each other's version
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true
	profile.data.lastSeen = os.time()
	local conflict = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(old)
			conflict = false
			if type(old) == "table" and (old.saveVersion or 0) ~= profile.version then
				conflict = true
				return nil -- cancels the write: newer data from another server is kept
			end
			profile.data.saveVersion = profile.version + 1
			profile.data.session = not releasing and { job = game.JobId, t = os.time() } or nil
			return profile.data
		end)
	end)
	if not ok then
		warn("[Tidebound] Save failed for", player.Name, err)
	elseif conflict then
		warn("[Tidebound] Save skipped for", player.Name, "(a newer save from another server exists)")
	else
		profile.version += 1
	end
	profile.saving = false
end

function PlayerData.release(player)
	PlayerData.save(player, true)
	profiles[player] = nil
end

function PlayerData.saveAll()
	for player in pairs(profiles) do
		task.spawn(PlayerData.save, player)
	end
	task.wait(2)
end

return PlayerData
