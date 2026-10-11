-- Tidebound: Eggfall server: dives, fishing sessions, egg stealing, heat, the Reef Warden, extraction, gacha.
-- Master Patch rules live here:
--   Patch 1: solo is the default. Dive Solo (1.15x Pearls) or Dive With Crew (+5% per extra member), and
--            opt-in Contested Waters (PvP egg theft), set before each run and back to OFF after it.
--   Patch 2: 100 health. Fish bank at the Tide Cache and are safe; a wipe loses 100% of carried cargo.
--            Rod durability, carried heat after a wipe at 75+, vials, companions that can be knocked out,
--            and the Greed Window at every beacon (extract now, or push deeper for +40% cargo, +25 heat and
--            an angrier guardian).
--   Patch 3: the Reef Warden's 3 phases (3rd egg, heat 75, heat 100), a 0.6 s tell before every strike,
--            25 damage, and each hit knocks your newest egg back to its shrine. Elites, anemone beds and
--            Glass Calm weather are in Threats.
-- Home Nests, hub boards and the base economy are in BaseService. Everything that grants currency or rolls
-- odds happens here; the client only displays and asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local ExpansionBuilder = require(script.Parent:WaitForChild("ExpansionBuilder"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local Crew = require(script.Parent:WaitForChild("Crew"))
local Companions = require(script.Parent:WaitForChild("Companions"))
local Threats = require(script.Parent:WaitForChild("Threats"))

local world = WorldBuilder.build()
local shoals = world:WaitForChild("SunkenShoals")
local delta = ExpansionBuilder.build(world)

local remotes = Shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = Shared
local function remote(className, name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local Request = remote("RemoteFunction", "Request")
local StateEvent = remote("RemoteEvent", "State")
local NotifyEvent = remote("RemoteEvent", "Notify")
local FishingEvent = remote("RemoteEvent", "Fishing")
local HazardEvent = remote("RemoteEvent", "Hazard")
local CueEvent = remote("RemoteEvent", "Cue") -- feel cues (Delta Section 10): animations, camera, screen effects

local R = Config.Risk
local G = Config.Guardian
local GREED = Config.Greed
local MODES = Config.Modes
local DURA = Config.Durability
local HC = Config.HeatCarry
local rng = Random.new()
local runs = {} -- [Player] = run state: heat and the cargo at risk; lost on wipe, never saved
local incomeCarry = {} -- [Player] = fractional Pearls of aquarium income
local beaconsClosedUntil = 0
local wardenActive = false
local wardenPauseUntil = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function newRun()
	return {
		started = false, -- set when you leave the Nest or Harbor; a dive lasts until you extract or wipe
		mode = "Solo",
		modeMult = MODES.soloPearlMult,
		crewSize = 1,
		wantCrew = false, -- pressed Dive With Crew
		contested = false,
		maxPushes = 0,
		heat = 0,
		carriedPearls = 0, -- unbanked fish: cargo, lost on a wipe
		carriedEggs = 0,
		carriedFish = 0,
		eggStack = {}, -- newest last: { egg = Part?, token = number }
		bankedPearls = 0, -- fish banked at the Tide Cache this run (already in the wallet)
		lastGain = 0,
		decayTicks = 0,
		riptideTicks = 0,
		session = nil,
		health = R.maxHealth,
		invulnerableUntil = 0,
		lockDropped = false,
		unseenFor = 0,
		steals = 0,
		aggro = 0,
		phase = 0,
		maxPhase = 0,
		pushes = 0,
		spentBeacons = {},
		choice = nil, -- the Greed Window card: { beacon, position, started }
		graceUntil = 0,
		immuneUntil = 0,
		burstUntil = 0,
		stunUntil = 0,
		vialsUsed = 0,
	}
end

local function notify(player, message, kind)
	NotifyEvent:FireClient(player, message, kind or "info")
end

local function notifyAll(message, kind)
	NotifyEvent:FireAllClients(message, kind or "info")
end

local function cue(player, name, payload)
	CueEvent:FireClient(player, name, payload)
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function inNest(player)
	local root = rootOf(player)
	if not root then
		return true
	end
	return Config.safeZone(root.Position) ~= nil
end

local function atRisk(run)
	return run.heat > 0 or run.carriedPearls > 0 or run.carriedEggs > 0
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function beaconParts()
	local list = {}
	for _, inst in ipairs(world:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst:GetAttribute("Action") == "Extract" then
			table.insert(list, inst.Parent)
		end
	end
	return list
end
local beacons = beaconParts()
for _, beacon in ipairs(beacons) do
	beacon:FindFirstChildOfClass("ProximityPrompt").HoldDuration = R.beaconChannel
end

local function nearBeacon(position, radius)
	for _, beacon in ipairs(beacons) do
		if (beacon.Position - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

-- Daily quests (Quill's board): progress resets at 00:00 UTC.
local function questsFor(data)
	local today = math.floor(os.time() / 86400)
	if data.quests.day ~= today then
		data.quests = { day = today, progress = {}, claimed = {} }
	end
	return data.quests
end

local function questProgress(player, data, id, amount)
	local quests = questsFor(data)
	for _, quest in ipairs(Config.Quests) do
		if quest.id == id and not quests.claimed[id] then
			local before = quests.progress[id] or 0
			quests.progress[id] = math.min(quest.goal, before + (amount or 1))
			if before < quest.goal and quests.progress[id] >= quest.goal then
				notify(player, ("Quest complete: %s. Claim it at Quill's board or the QUESTS tab."):format(quest.text), "good")
			end
		end
	end
end

-- Rod durability (missing entry = full) -------------------------------------------------------

local function duraOf(data, rodId)
	return data.rodDura[rodId] or DURA.max
end

-- A broken rod fishes as a tier-1 Drift Rod until repaired.
local function effectiveRod(data)
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	if duraOf(data, rod.id) <= 0 then
		return Config.Rods[1], true
	end
	return rod, false
end

local function wear(player, data, amount)
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	local before = duraOf(data, rod.id)
	if before <= 0 then
		return
	end
	data.rodDura[rod.id] = math.max(0, before - amount)
	if data.rodDura[rod.id] <= 0 then
		notify(player, ("Your %s broke! It fishes like a Drift Rod until you repair it (RODS tab, in the Nest or Harbor)."):format(rod.name), "bad")
	end
end

-- Mode multipliers --------------------------------------------------------------------------------

local function modeFor(player, run)
	local size = Crew.size(player)
	if run.wantCrew and size >= 2 then
		return "Crew", 1 + MODES.crewPerMember * (size - 1), size
	end
	return "Solo", MODES.soloPearlMult, 1
end

-- Guardian phase: 1 at the 3rd egg, 2 at heat 75, 3 at heat 100; each Greed push adds one.
local function rawPhase(run)
	local phase = 0
	if run.steals >= G.triggerEggs then
		phase = 1
	end
	if run.heat >= Config.Heat.lockAt then
		phase = 2
	end
	if run.heat >= Config.Heat.max then
		phase = 3
	end
	if phase > 0 or run.aggro > 0 then
		phase = math.min(3, phase + run.aggro)
	end
	return phase
end

-- What the Warden actually does to you: breaking line of sight drops a chase back to guarding the exit.
local function behaviour(run)
	local phase = rawPhase(run)
	if phase >= 2 and run.lockDropped then
		return 1
	end
	return phase
end

local function walkSpeed(data, run)
	local base = BaseService.walkSpeed(data)
	local slowedEggs = math.max(0, run.carriedEggs - Companions.carry(data))
	local speed = math.max(R.minWalkSpeed, base - slowedEggs * R.carrySlowPerEgg)
	if now() < run.burstUntil then
		speed += Config.Contested.burstSpeed
	end
	return speed
end

local function buildState(player)
	local data, run = PlayerData.get(player), runs[player]
	if not data or not run then
		return nil
	end
	local unique = 0
	for _ in pairs(data.collection) do
		unique += 1
	end
	local base = BaseService.state(player, data)
	local mode, modeMult = run.mode, run.modeMult
	if not run.started then
		mode, modeMult = modeFor(player, run)
	end
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	local maxPushes = run.started and run.maxPushes or (rod.biomes - 1)
	local choice = run.choice and { started = run.choice.started, canPush = run.pushes < maxPushes } or nil
	local _, broken = effectiveRod(data)
	return {
		pearls = data.pearls,
		shards = data.shards,
		embers = data.embers,
		tideglass = data.tideglass,
		eggs = data.eggs,
		rod = data.rod,
		ownedRods = data.ownedRods,
		bait = data.bait,
		baitInv = data.baitInv,
		pity = data.pity.TideEgg,
		history = data.history,
		collection = data.collection,
		bestiary = data.bestiary,
		uniqueCreatures = unique,
		totalCreatures = #data.aquarium,
		hatched = data.stats.hatched,
		incomePerMin = base.incomePerMin,
		base = base,
		stats = data.stats,
		quests = questsFor(data),
		boards = BaseService.boards,
		trophies = data.trophies,
		-- dive setup (Master Patch 1)
		started = run.started,
		mode = mode,
		modeMult = modeMult,
		wantCrew = run.wantCrew,
		contested = data.settings.contested,
		runContested = run.contested,
		crew = Crew.state(player),
		-- run and risk
		heat = run.heat,
		carriedPearls = run.carriedPearls,
		carriedEggs = run.carriedEggs,
		carriedFish = run.carriedFish,
		bankedPearls = run.bankedPearls,
		health = run.health,
		maxHealth = R.maxHealth,
		phase = rawPhase(run),
		locked = behaviour(run) >= 2 and not inNest(player),
		pushes = run.pushes,
		maxPushes = maxPushes,
		cargoMult = 1 + run.pushes * GREED.cargoPct,
		choice = choice,
		graceUntil = run.graceUntil,
		immuneUntil = run.immuneUntil,
		stunUntil = run.stunUntil,
		walkSpeed = walkSpeed(data, run),
		beaconsClosedUntil = beaconsClosedUntil,
		wardenActive = wardenActive,
		-- loadout (Master Patch 2)
		rodDura = data.rodDura,
		rodBroken = broken,
		vials = data.vials,
		vialsUsed = run.vialsUsed,
		heatDebt = data.heatDebt,
		heatDebtRest = data.heatDebtRest,
		companions = Companions.state(data),
		carryHelp = Companions.carry(data),
		weather = Threats.weather(),
	}
end

local function push(player)
	local state = buildState(player)
	if not state then
		return
	end
	StateEvent:FireClient(player, state)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Pearls.Value = state.pearls
		stats.Hatched.Value = state.hatched
	end
end

BaseService.init({ delta = delta, notify = notify, push = push })
Crew.init({
	notify = notify,
	push = push,
	canChange = function(player)
		local run = runs[player]
		if run and (run.started or atRisk(run)) then
			return ("%s is on a dive. Crews change in the Nest or Harbor between runs."):format(player.DisplayName)
		end
		return nil
	end,
})

-- Heat ----------------------------------------------------------------------------------------

local function setBeaconsOpen(open)
	-- prompts stay enabled so a player inside the 10 s grace can still extract; the server checks
	for _, beacon in ipairs(beacons) do
		beacon.Color = open and Config.World.beaconOpenColor or Config.World.beaconClosedColor
		local glow = beacon:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Color = beacon.Color
		end
	end
end

local function closeBeacons()
	beaconsClosedUntil = now() + Config.Heat.beaconCloseSeconds
	setBeaconsOpen(false)
	notifyAll("Heat 100: every extraction beacon is closed for 30 seconds!", "bad")
	-- Beacon grace: anyone within 10 studs of a beacon gets 10 s to extract anyway
	for player, run in pairs(runs) do
		local root = rootOf(player)
		if root and nearBeacon(root.Position, R.graceRadius) then
			run.graceUntil = now() + R.graceSeconds
			notify(player, "Beacon grace: you have 10 seconds to extract!", "warn")
		end
	end
	task.delay(Config.Heat.beaconCloseSeconds, function()
		if now() >= beaconsClosedUntil - 0.1 then
			setBeaconsOpen(true)
			notifyAll("Extraction beacons are open again.", "good")
		end
	end)
end

local function addHeat(player, amount)
	local run = runs[player]
	if not run then
		return
	end
	local before = run.heat
	run.heat = math.clamp(before + amount, 0, Config.Heat.max)
	run.lastGain = os.clock()
	run.decayTicks = 0
	for _, threshold in ipairs(Config.Heat.thresholds) do
		if before < threshold.at and run.heat >= threshold.at then
			notify(player, ("Heat %d: %s"):format(threshold.at, threshold.label), threshold.at >= 75 and "bad" or "warn")
			cue(player, "Threshold", threshold.at)
			if threshold.at == Config.Heat.beaconCloseAt then
				closeBeacons()
			end
		end
	end
end

-- Wild eggs ------------------------------------------------------------------------------------

local function setEggVisible(egg, visible)
	egg.Transparency = visible and 0 or 1
	local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = visible
	end
	for _, d in ipairs(egg:GetDescendants()) do
		if d:IsA("Light") or d:IsA("ParticleEmitter") then
			d.Enabled = visible
		end
	end
end

-- Puts a stolen egg back on its shrine, unless it was already restocked and stolen again since.
local function restoreEgg(entry)
	local egg = entry and entry.egg
	if egg and egg:GetAttribute("Token") == entry.token and egg:GetAttribute("Taken") then
		egg:SetAttribute("Taken", false)
		setEggVisible(egg, true)
	end
end

local function takeEgg(egg)
	local token = (egg:GetAttribute("Token") or 0) + 1
	egg:SetAttribute("Token", token)
	egg:SetAttribute("Taken", true)
	setEggVisible(egg, false)
	local entry = { egg = egg, token = token }
	task.delay(Config.World.eggRespawnSeconds, function()
		restoreEgg(entry)
	end)
	return entry
end

-- Runs: start, wipe, damage ------------------------------------------------------------------------

local function startRun(player, run, data)
	run.started = true
	run.mode, run.modeMult, run.crewSize = modeFor(player, run)
	run.contested = data.settings.contested == true
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	run.maxPushes = rod.biomes - 1
	local lines = { ("Dive started: %s (x%.2f Pearls). Contested Waters %s."):format(run.mode == "Crew" and ("Crew of " .. run.crewSize) or "Solo", run.modeMult, run.contested and "ON" or "OFF") }
	if data.heatDebt > 0 then
		run.heat = math.max(run.heat, data.heatDebt)
		run.lastGain = os.clock()
		table.insert(lines, ("You carried heat from your last wipe: starting at heat %d."):format(data.heatDebt))
		data.heatDebt = 0
		data.heatDebtRest = 0
	end
	notify(player, table.concat(lines, " "), run.contested and "warn" or "info")
end

local function wipe(player, reason)
	local run = runs[player]
	if not run then
		return
	end
	local data = PlayerData.get(player)
	local lostPearls, lostEggs = run.carriedPearls, run.carriedEggs
	for _, entry in ipairs(run.eggStack) do
		restoreEgg(entry)
	end
	local carryHeat = run.heat >= HC.wipeAt
	local wasStarted, mode = run.started, run.mode
	runs[player] = newRun()
	local lines = { reason }
	if data then
		if wasStarted then
			data.stats.wipes += 1
			data.stats.cleanStreak = 0
			data.stats.modes[mode].cleanStreak = 0
		end
		if carryHeat then
			data.heatDebt = HC.startHeat
			data.heatDebtRest = 0
		end
		data.settings.contested = false
	end
	table.insert(lines, ("You lost %d Pearls of unbanked fish and %d egg(s). Banked Pearls, pity, Bestiary, rods and your base are safe."):format(lostPearls, lostEggs))
	if carryHeat then
		table.insert(lines, ("You wiped at heat %d+, so your next dive starts at heat %d. Rest 3 min at your Home Nest to clear it."):format(HC.wipeAt, HC.startHeat))
	end
	notify(player, table.concat(lines, " "), "bad")
	cue(player, "Down")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		character:PivotTo(Config.World.spawnCFrame)
	end
	push(player)
end

local function knockback(player, fromPosition)
	local root = rootOf(player)
	if not root then
		return
	end
	local away = flat(root.Position - fromPosition)
	if away.Magnitude < 0.1 then
		away = Vector3.new(1, 0, 0)
	end
	HazardEvent:FireClient(player, "Hit", away.Unit)
end

-- Damage from any Shoals threat. A guardian hit also knocks your newest egg back to its shrine and
-- knocks out a companion.
local function damage(player, amount, fromPosition, label, guardian)
	local run = runs[player]
	if not run or not rootOf(player) or inNest(player) or now() < run.invulnerableUntil then
		return
	end
	run.health = math.max(0, run.health - amount)
	run.invulnerableUntil = now() + R.hitInvulnerable
	if run.health <= 0 then
		wipe(player, ("The %s took you down!"):format(label))
		return
	end
	knockback(player, fromPosition)
	local lines = { ("The %s hit you for %d! %d/%d health."):format(label, amount, run.health, R.maxHealth) }
	if guardian then
		local entry = table.remove(run.eggStack)
		if entry then
			run.carriedEggs = math.max(0, run.carriedEggs - 1)
			restoreEgg(entry)
			table.insert(lines, "Your newest egg washed back to its shrine.")
		end
		local data = PlayerData.get(player)
		local ko = data and Companions.knockOut(data)
		if ko then
			Companions.refresh(player, data)
			table.insert(lines, ("%s was knocked out and swam home (10 min, or a Revive Vial)."):format(ko))
		end
	end
	cue(player, "Hit", run.health)
	notify(player, table.concat(lines, " "), "bad")
	push(player)
end

local function stun(player, seconds, fromPosition)
	local run = runs[player]
	if not run or inNest(player) or now() < run.stunUntil then
		return
	end
	run.stunUntil = now() + seconds
	knockback(player, fromPosition)
	cue(player, "Stun", seconds)
	notify(player, ("A Barnacle Brute bowled you over! Stunned for %.1f s."):format(seconds), "bad")
	push(player)
end

local function giveBait(player, baitId, count)
	local data = PlayerData.get(player)
	if data then
		data.baitInv[baitId] = (data.baitInv[baitId] or 0) + count
		if data.bait == "" then
			data.bait = baitId
		end
		push(player)
	end
end

Threats.init({
	delta = delta,
	notify = notify,
	notifyAll = notifyAll,
	cue = cue,
	exposed = function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and humanoid and humanoid.Health > 0 and runs[player] and not Config.safeZone(root.Position) then
			return root
		end
		return nil
	end,
	damage = function(player, amount, fromPosition, label)
		damage(player, amount, fromPosition, label, false)
	end,
	stun = stun,
	giveBait = giveBait,
})

-- World actions (ProximityPrompts) -------------------------------------------

local function onCast(player, prompt)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	if run.session and os.clock() - run.session.started < 60 then
		notify(player, "You're already reeling.", "info")
		return
	end
	local pier = prompt:GetAttribute("Pier") == true
	if not pier and not run.started then
		startRun(player, run, data)
	end
	local rod, broken = effectiveRod(data)
	wear(player, data, DURA.perCast)
	local bait = nil
	if data.bait ~= "" and (data.baitInv[data.bait] or 0) > 0 then
		bait = Config.BaitById[data.bait]
		data.baitInv[data.bait] -= 1
	end
	local luck = rod.luck * (bait and bait.luck or 1)
	local tierIndex = Gacha.rollFishTier(luck, rng)
	if pier then
		tierIndex = math.min(tierIndex, Config.Harbor.pier.maxTier)
	end
	local names = Config.Biomes[1].fish[tierIndex]
	local fish = names[rng:NextInteger(1, #names)]
	local biteWait = rng:NextNumber(Config.Fishing.biteMin, Config.Fishing.biteMax) / rod.lureSpeed
	if not pier then
		biteWait *= Threats.biteMult()
	end
	run.session = {
		id = HttpService:GenerateGUID(false),
		tier = tierIndex,
		fish = fish,
		pier = pier,
		started = os.clock(),
		minTime = biteWait + Config.Fishing.minReelSeconds,
	}
	FishingEvent:FireClient(player, {
		id = run.session.id,
		biteWait = biteWait,
		difficulty = tierIndex,
		control = rod.control,
		resilience = rod.resilience,
		bait = bait and bait.name or nil,
		broken = broken,
		pier = pier,
	})
	push(player)
end

local function onSteal(player, prompt)
	local run, data = runs[player], PlayerData.get(player)
	local egg = prompt.Parent
	if not run or not data or egg:GetAttribute("Taken") then
		return
	end
	if not run.started then
		startRun(player, run, data)
	end
	table.insert(run.eggStack, takeEgg(egg))
	local gained = 1
	if run.contested and rng:NextNumber() < Config.Contested.bonusEggChance then
		gained = 2
		table.insert(run.eggStack, { egg = nil, token = 0 })
	end
	run.carriedEggs += gained
	run.steals += 1
	run.lockDropped = false
	addHeat(player, Config.Heat.perSteal)
	questProgress(player, data, "steal", 1)
	cue(player, "Steal")
	if gained > 1 then
		notify(player, "Contested Waters bonus: the nest held 2 Tide Eggs! +8 heat. Extract to keep them.", "good")
	else
		notify(player, "You stole a Tide Egg! +8 heat. Extract at a beacon to keep it.", "good")
	end
	push(player)
end

-- Tide Cache: unbanked fish become safe Pearls in your wallet.
local function onBankCatch(player)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	if run.carriedPearls <= 0 then
		notify(player, "Nothing to bank. Fish you catch in the Shoals are cargo until you bank them here.", "info")
		return
	end
	local pearls, fish = run.carriedPearls, run.carriedFish
	data.pearls += pearls
	run.bankedPearls += pearls
	run.carriedPearls, run.carriedFish = 0, 0
	cue(player, "Bank")
	notify(player, ("Banked %d fish as %d Pearls. No wipe can touch them now."):format(fish, pearls), "good")
	push(player)
end

-- Extract now: banks the cargo with any Greed pushes, ends the run.
local function extract(player)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	run.choice = nil
	local x = Config.Extraction
	local mult = 1 + run.pushes * GREED.cargoPct
	local payout = math.min(x.payoutCap, math.floor((x.payoutBase + run.carriedEggs * x.payoutPerEgg) * mult * run.modeMult))
	local fishCap = math.max(run.carriedPearls, run.carriedFish * Config.Tiers[#Config.Tiers].fishPearls)
	local fishPearls = math.min(math.floor(run.carriedPearls * mult), fishCap)
	local mode = run.mode
	local modeStats = data.stats.modes[mode]
	local streak = data.stats.cleanStreak + 1
	local streakEmbers = math.min(R.streakEmberMax, math.floor(streak / R.streakEmberEvery))
	local embers = math.clamp(
		x.baseEmbers + run.carriedEggs * x.embersPerEgg + math.floor((run.carriedPearls + run.bankedPearls) / x.pearlsPerEmber) + streakEmbers + run.pushes * GREED.embersPerPush,
		x.minEmbers,
		x.maxEmbers
	)
	data.pearls += fishPearls + payout
	data.eggs += run.carriedEggs
	if mode == "Crew" then
		data.crewEggs += run.carriedEggs
	end
	data.embers += embers
	data.stats.extractions += 1
	data.stats.cleanStreak = streak
	data.stats.bestStreak = math.max(data.stats.bestStreak, streak)
	data.stats.bestHeatExtract = math.max(data.stats.bestHeatExtract or 0, run.heat)
	modeStats.extractions += 1
	modeStats.cleanStreak += 1
	modeStats.bestStreak = math.max(modeStats.bestStreak, modeStats.cleanStreak)
	modeStats.bestHeatExtract = math.max(modeStats.bestHeatExtract, run.heat)
	modeStats.deepestPush = math.max(modeStats.deepestPush, run.pushes)
	questProgress(player, data, "extract", 1)
	local lines = { ("Extracted! +%d fish Pearls and +%d run payout, %d Tide Egg(s) and %d Run Embers. Streak %d."):format(fishPearls, payout, run.carriedEggs, embers, streak) }
	if run.pushes > 0 then
		table.insert(lines, ("Greed paid x%.1f cargo."):format(mult))
	end
	if run.maxPhase >= 3 then
		data.trophies[G.drop] = (data.trophies[G.drop] or 0) + 1
		table.insert(lines, ("You escaped the %s's Phase 3: +1 %s for your Trophy Room (%d/%d for its Bestiary page)."):format(G.name, G.dropName, data.trophies[G.drop], G.dropsForPage))
	end
	if data.settings.contested then
		data.settings.contested = false
		table.insert(lines, "Contested Waters is back to OFF.")
	end
	notify(player, table.concat(lines, " "), "good")
	cue(player, "Extract")
	local session = run.session
	runs[player] = newRun()
	runs[player].session = session
	BaseService.refresh(player)
	push(player)
end

-- Push deeper: +40% cargo value, +25 heat, guardian one phase angrier, and this beacon is spent.
local function pushDeeper(player, run)
	local beacon = run.choice and run.choice.beacon
	run.choice = nil
	run.pushes += 1
	run.aggro += GREED.aggro
	if beacon then
		run.spentBeacons[beacon] = true
	end
	notify(player, ("You pushed deeper: cargo x%.1f, heat +%d, and the %s gets angrier. Extract at a different beacon."):format(1 + run.pushes * GREED.cargoPct, GREED.heat, G.name), "warn")
	cue(player, "Push")
	addHeat(player, GREED.heat)
	push(player)
end

local function onExtract(player, prompt)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data or run.choice then
		return
	end
	if now() < beaconsClosedUntil and now() >= run.graceUntil then
		notify(player, "The beacons are closed. Survive until they reopen.", "bad")
		return
	end
	if run.carriedPearls == 0 and run.carriedEggs == 0 and run.bankedPearls == 0 then
		notify(player, "Nothing to extract yet. Catch fish or steal eggs in the Shoals first.", "info")
		return
	end
	local beacon = prompt.Parent
	if run.spentBeacons[beacon] then
		notify(player, "You pushed past this beacon. Extract at a different one.", "warn")
		return
	end
	if not run.started then
		startRun(player, run, data)
	end
	run.choice = { beacon = beacon, position = beacon.Position, started = now() }
	cue(player, "Greed")
	push(player)
end

-- Contested Waters egg snatching -------------------------------------------------------------------

local function snatchAllowed(victim, victimRun)
	local root = rootOf(victim)
	return root ~= nil
		and victimRun.contested
		and victimRun.carriedEggs > 0
		and now() >= victimRun.immuneUntil
		and not inNest(victim)
		and not nearBeacon(root.Position, Config.Contested.beaconSafeRadius)
end

local function onSnatch(player, prompt)
	local victim = Players:GetPlayerFromCharacter(prompt.Parent and prompt.Parent.Parent)
	local run, victimRun = runs[player], victim and runs[victim]
	if not victim or victim == player or not run or not victimRun then
		return
	end
	if not run.contested then
		notify(player, "Snatching is only for Contested Waters runs. Switch it on at Gate Warden Sel before you dive.", "info")
		return
	end
	if Crew.sameCrew(player, victim) then
		notify(player, "Crewmates never snatch from each other.", "info")
		return
	end
	if not snatchAllowed(victim, victimRun) or inNest(player) then
		return
	end
	local root, victimRoot = rootOf(player), rootOf(victim)
	local offset = root.Position - victimRoot.Position
	if offset.Magnitude > Config.Contested.snatchRange + 1.5 then
		return
	end
	if offset.Unit:Dot(victimRoot.CFrame.LookVector) > 0 then
		notify(player, "They turned to face you. Snatches only work from behind!", "info")
		return
	end
	-- every Tide Egg is the same tier, so the newest is also the cheapest one; it isn't on a shrine any more
	table.remove(victimRun.eggStack)
	victimRun.carriedEggs -= 1
	victimRun.immuneUntil = now() + Config.Contested.immunity
	victimRun.burstUntil = now() + Config.Contested.burstSeconds
	run.carriedEggs += 1
	table.insert(run.eggStack, { egg = nil, token = 0 })
	addHeat(player, Config.Heat.perSteal)
	cue(player, "Steal")
	cue(victim, "Snatched")
	notify(player, ("You snatched a Tide Egg from %s! +8 heat."):format(victim.DisplayName), "good")
	notify(victim, ("%s snatched a Tide Egg! You're immune for 5 s and get a speed burst."):format(player.DisplayName), "bad")
	push(player)
	push(victim)
end

local function onTravel(player, prompt)
	local result = BaseService.travel(player, prompt:GetAttribute("Dest"))
	if result.error then
		notify(player, result.error, "info")
	end
end

local function onPrompt(prompt, player)
	if not prompt:IsDescendantOf(world) and prompt:GetAttribute("Action") ~= "Snatch" then
		return
	end
	local action = prompt:GetAttribute("Action")
	if action == "Cast" then
		onCast(player, prompt)
	elseif action == "Steal" then
		onSteal(player, prompt)
	elseif action == "Extract" then
		onExtract(player, prompt)
	elseif action == "BankCatch" then
		onBankCatch(player)
	elseif action == "Snatch" then
		onSnatch(player, prompt)
	elseif action == "Travel" then
		onTravel(player, prompt)
	elseif action == "Feed" then
		BaseService.onFeed(player, prompt)
	elseif action == "Admire" then
		BaseService.onAdmire(player, prompt)
	elseif action == "EliteLoot" then
		Threats.onLoot(player, prompt)
	end
end
ProximityPromptService.PromptTriggered:Connect(onPrompt)

-- Studio-only hook so automated playtests can trigger prompts without a keyboard.
if RunService:IsStudio() then
	local debugPrompt = Instance.new("BindableEvent")
	debugPrompt.Name = "TideboundDebugPrompt"
	debugPrompt.Event:Connect(onPrompt)
	debugPrompt.Parent = game:GetService("ServerStorage")
end

-- Client requests --------------------------------------------------------------

local handlers = {}

function handlers.GetState(player)
	return buildState(player)
end

function handlers.FinishCast(player, data, run, id, success, perfect, peak)
	local session = run.session
	if not session or session.id ~= id then
		return { error = "That cast already ended." }
	end
	run.session = nil
	local elapsed = os.clock() - session.started
	if elapsed < session.minTime or elapsed > 90 then
		return { error = "The line snapped." }
	end
	local pierPct = session.pier and Config.Harbor.pier.payoutPct or 1
	if success ~= true then
		local lines = { ("The %s got away and snapped your line (-%d durability)."):format(session.fish, DURA.perSnap) }
		wear(player, data, DURA.perSnap)
		if type(peak) == "number" and peak >= R.luckyScaleThreshold then
			local scale = math.floor(R.luckyScalePearls * pierPct)
			if session.pier then
				data.pearls += scale
			else
				run.carriedPearls += scale
			end
			table.insert(lines, ("It shed a Lucky Scale: +%d Pearls."):format(scale))
		end
		notify(player, table.concat(lines, " "), "info")
		return { ok = true, caught = false }
	end
	local tier = Config.Tiers[session.tier]
	local pearls = tier.fishPearls * (perfect == true and Config.Fishing.perfectBonus or 1)
	data.stats.fishCaught += 1
	data.bestiary[session.fish] = true
	questProgress(player, data, "fish", 1)
	if session.pier then
		pearls = math.floor(pearls * pierPct)
		data.pearls += pearls
		local baitText = ""
		if rng:NextNumber() < Config.Harbor.pier.baitChance then
			data.baitInv.Brineworm = (data.baitInv.Brineworm or 0) + 1
			baitText = " Found a Brineworm!"
		end
		notify(player, ("%s %s: +%d Pearls banked (pier, no Heat).%s"):format(perfect == true and "Perfect catch!" or "Caught", session.fish, pearls, baitText), "good")
	else
		-- Canon: 25-120 Pearls per fish, with the solo or Crew bonus inside that cap
		pearls = math.min(Config.Tiers[#Config.Tiers].fishPearls, math.floor(pearls * run.modeMult))
		run.carriedPearls += pearls
		run.carriedFish += 1
		addHeat(player, Config.Heat.perFish)
		local lines = { ("%s %s (%s): +%d Pearls of cargo. Bank it at the Tide Cache to keep it safe."):format(perfect == true and "Perfect catch!" or "Caught", session.fish, tier.id, pearls) }
		local bonus = Threats.onCatch(player)
		if bonus then
			table.insert(lines, bonus)
		end
		notify(player, table.concat(lines, " "), session.tier >= 4 and "rare" or "good")
	end
	return { ok = true, caught = true, fish = session.fish, tier = session.tier, pearls = pearls }
end

function handlers.GreedChoice(player, data, run, choice)
	if not run.choice then
		return { error = "You're not at a beacon." }
	end
	if choice == "push" then
		if run.pushes >= run.maxPushes then
			return { error = "Your rod's run has no deeper biome left: extract only." }
		end
		pushDeeper(player, run)
	else
		extract(player)
	end
	return { ok = true }
end

-- Master Patch 1: Dive Solo or Dive With Crew from the dive screen.
function handlers.Dive(player, data, run, mode)
	if mode ~= "Solo" and mode ~= "Crew" then
		return { error = "Pick Dive Solo or Dive With Crew." }
	end
	if run.started or atRisk(run) then
		return { error = "You're already on a dive. Extract first." }
	end
	if not inNest(player) then
		return { error = "Dive from the Nest or the Harbor Ring." }
	end
	if mode == "Crew" and Crew.size(player) < 2 then
		return { error = "Invite someone to your Crew first, or Dive Solo." }
	end
	run.wantCrew = mode == "Crew"
	player.Character:PivotTo(MODES.diveSpawn)
	return { ok = true }
end

function handlers.SetContested(player, data, run, enabled)
	if type(enabled) ~= "boolean" then
		return { error = "Bad value." }
	end
	if run.started or atRisk(run) or not inNest(player) then
		return { error = "Set Contested Waters in the Nest or Harbor, before your dive." }
	end
	data.settings.contested = enabled
	notify(player, enabled and "Contested Waters ON for your next dive: rivals can snatch your cheapest egg from behind, and egg nests can hold a bonus egg." or "Contested Waters OFF: nobody can take anything from you.", enabled and "warn" or "good")
	return { ok = true }
end

function handlers.RepairRod(player, data)
	if not inNest(player) then
		return { error = "Repair your rod in the Nest or Harbor." }
	end
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	local missing = DURA.max - duraOf(data, rod.id)
	if missing <= 0 then
		return { error = "Your rod is in perfect shape." }
	end
	local cost = math.ceil(DURA.repairCost[rod.id] * missing / DURA.max)
	if data.pearls < cost then
		return { error = ("Repairing the %s costs %d Pearls."):format(rod.name, cost) }
	end
	data.pearls -= cost
	data.rodDura[rod.id] = nil
	notify(player, ("Repaired the %s for %d Pearls."):format(rod.name, cost), "good")
	return { ok = true }
end

local vialsById = {}
for _, vial in ipairs(Config.Vials) do
	vialsById[vial.id] = vial
end

function handlers.BuyVial(player, data, run, vialId)
	local vial = vialsById[vialId]
	if type(vialId) ~= "string" or not vial then
		return { error = "Unknown vial." }
	end
	if not inNest(player) then
		return { error = "Nim sells vials in the Nest and Harbor, not mid-dive." }
	end
	if data.pearls < vial.cost then
		return { error = ("A %s costs %d Pearls."):format(vial.name, vial.cost) }
	end
	data.pearls -= vial.cost
	data.vials[vialId] = (data.vials[vialId] or 0) + 1
	return { ok = true }
end

function handlers.UseVial(player, data, run, vialId)
	local vial = vialsById[vialId]
	if type(vialId) ~= "string" or not vial then
		return { error = "Unknown vial." }
	end
	if (data.vials[vialId] or 0) < 1 then
		return { error = ("You have no %s. Nim sells them."):format(vial.name) }
	end
	local onDive = run.started and not inNest(player)
	if onDive and run.vialsUsed >= Config.VialsPerRun then
		return { error = ("You can use %d vials per dive."):format(Config.VialsPerRun) }
	end
	if vialId == "Mending" then
		if not onDive then
			return { error = "Mending Vials are for dives. You heal fully between runs." }
		end
		if run.health >= R.maxHealth then
			return { error = "You're at full health." }
		end
		run.health = math.min(R.maxHealth, run.health + Config.VialHeal)
		notify(player, ("Mending Vial: +%d health (%d/%d)."):format(Config.VialHeal, run.health, R.maxHealth), "good")
	else
		local name = Companions.revive(data)
		if not name then
			return { error = "None of your companions is knocked out." }
		end
		Companions.refresh(player, data, true)
		notify(player, ("Revive Vial: %s is back by your side."):format(name), "good")
	end
	data.vials[vialId] -= 1
	if onDive then
		run.vialsUsed += 1
	end
	return { ok = true }
end

function handlers.BuyEgg(player, data)
	local cost = Config.Eggs.TideEgg.pearlCost
	if data.pearls < cost then
		return { error = ("A Tide Egg costs %d Pearls. Stealing one in the Shoals is free."):format(cost) }
	end
	data.pearls -= cost
	data.eggs += 1
	BaseService.refresh(player)
	return { ok = true }
end

local function hatchOne(player, data, mode)
	local tierIndex, pityKey = Gacha.rollTier(data.pity.TideEgg, rng)
	local tier = Config.Tiers[tierIndex]
	local creature = tier.creatures[rng:NextInteger(1, #tier.creatures)]
	local mutation = Gacha.rollMutation(rng)
	local value = math.floor(tier.pearlValue * mutation.mult)
	local isNew = data.collection[creature] == nil
	data.collection[creature] = (data.collection[creature] or 0) + 1
	local shards = isNew and Config.Shards.unique or Config.Shards.duplicate
	data.shards += shards
	table.insert(data.aquarium, { c = creature, t = tierIndex, m = mutation.id, v = value })
	table.insert(data.history, 1, { tier = tierIndex, creature = creature, mutation = mutation.id, value = value, pity = pityKey ~= nil })
	while #data.history > 10 do
		table.remove(data.history)
	end
	data.stats.hatched += 1
	local prefix = mutation.id ~= "None" and (mutation.id .. " ") or ""
	local label = ("%s%s %s"):format(prefix, tier.id, creature)
	if value > (data.stats.bestHatchValue or 0) then
		data.stats.bestHatchValue = value
		data.stats.bestHatch = label
	end
	local modeStats = data.stats.modes[mode]
	if value > modeStats.bestHatchValue then
		modeStats.bestHatchValue = value
		modeStats.bestHatch = label
	end
	if tierIndex >= 5 then
		notifyAll(("%s hatched a %s!"):format(player.DisplayName, label), "rare")
	end
	return { tier = tierIndex, creature = creature, mutation = mutation.id, value = value, shards = shards, isNew = isNew, pity = pityKey }
end

-- Hatches up to one egg per incubator slot at once. Eggs from Crew runs count on the Crew board.
function handlers.Hatch(player, data, run, count)
	if data.eggs < 1 then
		return { error = "No Tide Eggs. Steal one in the Sunken Shoals or buy one at the shrine." }
	end
	if not inNest(player) then
		return { error = "Hatch at an incubator in the Nest or your Home Nest." }
	end
	local slots = BaseService.incubatorSlots(data)
	count = math.clamp(math.floor(tonumber(count) or 1), 1, math.min(slots, data.eggs))
	local results, best = {}, nil
	for _ = 1, count do
		data.crewEggs = math.clamp(data.crewEggs, 0, data.eggs)
		local mode = data.eggs > data.crewEggs and "Solo" or "Crew"
		if mode == "Crew" then
			data.crewEggs -= 1
		end
		data.eggs -= 1
		local result = hatchOne(player, data, mode)
		table.insert(results, result)
		if not best or result.value > best.value then
			best = result
		end
	end
	local sold, soldCount = BaseService.enforceStorage(data)
	if soldCount > 0 then
		notify(player, ("Storage full: sold %d lowest-value creature(s) for %d Pearls. A Nest Vault holds more."):format(soldCount, sold), "warn")
	end
	BaseService.changed(player)
	return { ok = true, result = best, results = results }
end

function handlers.ClaimQuest(player, data, run, questId)
	local quests = questsFor(data)
	for _, quest in ipairs(Config.Quests) do
		if quest.id == questId then
			if quests.claimed[questId] then
				return { error = "Already claimed today." }
			end
			if (quests.progress[questId] or 0) < quest.goal then
				return { error = "Not finished yet." }
			end
			quests.claimed[questId] = true
			data.pearls += quest.reward
			notify(player, ("Quest reward: +%d Pearls."):format(quest.reward), "good")
			return { ok = true }
		end
	end
	return { error = "Unknown quest." }
end

function handlers.Travel(player, data, run, destination)
	return BaseService.travel(player, destination)
end

function handlers.BuyRod(player, data, run, rodId)
	local rod = Config.RodsById[rodId]
	if type(rodId) ~= "string" or not rod then
		return { error = "Unknown rod." }
	end
	if rod.prestigeOnly then
		return { error = "The Celestial Rod is a prestige reward." }
	end
	if data.ownedRods[rodId] then
		return { error = "You already own that rod." }
	end
	for i, r in ipairs(Config.Rods) do
		if r.id == rodId and i > 1 and not data.ownedRods[Config.Rods[i - 1].id] then
			return { error = ("Buy the %s first."):format(Config.Rods[i - 1].name) }
		end
	end
	if data.pearls < rod.cost then
		return { error = ("The %s costs %d Pearls."):format(rod.name, rod.cost) }
	end
	data.pearls -= rod.cost
	data.ownedRods[rodId] = true
	data.rod = rodId
	notify(player, ("You bought the %s."):format(rod.name), "good")
	BaseService.refresh(player)
	return { ok = true }
end

function handlers.EquipRod(player, data, run, rodId)
	if type(rodId) ~= "string" or not data.ownedRods[rodId] then
		return { error = "You don't own that rod." }
	end
	if run.started and not inNest(player) then
		return { error = "Swap rods between dives." }
	end
	data.rod = rodId
	return { ok = true }
end

function handlers.BuyBait(player, data, run, baitId)
	local bait = Config.BaitById[baitId]
	if type(baitId) ~= "string" or not bait then
		return { error = "Unknown bait." }
	end
	if not bait.shop then
		return { error = ("%s is found in %s."):format(bait.name, bait.source) }
	end
	local cost = bait.cost * Config.BaitPackSize
	if data.pearls < cost then
		return { error = ("%d %s costs %d Pearls."):format(Config.BaitPackSize, bait.name, cost) }
	end
	data.pearls -= cost
	data.baitInv[baitId] = (data.baitInv[baitId] or 0) + Config.BaitPackSize
	if data.bait == "" then
		data.bait = baitId
	end
	return { ok = true }
end

function handlers.EquipBait(player, data, run, baitId)
	if baitId == "" then
		data.bait = ""
		return { ok = true }
	end
	if type(baitId) ~= "string" or (data.baitInv[baitId] or 0) < 1 then
		return { error = "You have none of that bait." }
	end
	data.bait = baitId
	return { ok = true }
end

-- Handlers from the other services (they don't need the run)
for _, source in ipairs({ BaseService.handlers, Crew.handlers, Companions.handlers }) do
	for name, handler in pairs(source) do
		handlers[name] = function(player, data, _run, ...)
			return handler(player, data, ...)
		end
	end
end

Request.OnServerInvoke = function(player, action, ...)
	local handler = type(action) == "string" and handlers[action]
	if not handler then
		return { error = "Unknown action." }
	end
	local data, run = PlayerData.get(player), runs[player]
	if not data or not run then
		return { error = "Still loading your save." }
	end
	local result = handler(player, data, run, ...)
	push(player)
	return result
end

-- Once per second: dives, heat decay, riptide, the Greed Window, guardian phases, carried heat, snatch
-- prompts, companions and aquarium income ------------------------------------------------------------

local PHASE_TEXT = {
	"Reef Warden Phase 1: it rises to guard the exit. Hide behind coral and dash between cover.",
	"Reef Warden Phase 2: it has locked onto you. Break line of sight for 6 s to shake it.",
	"Reef Warden Phase 3: full fury. It's faster than ever. Get to a beacon!",
}

local function choiceTick(player, run)
	local choice = run.choice
	local root = rootOf(player)
	if now() < beaconsClosedUntil and now() >= run.graceUntil then
		run.choice = nil
		notify(player, "The beacon closed before you chose! Survive until the beacons reopen.", "bad")
		return
	end
	if now() - choice.started >= GREED.choiceSeconds or not root or (root.Position - choice.position).Magnitude > GREED.leaveRadius then
		extract(player)
	end
end

local function snatchPromptFor(player)
	local root = rootOf(player)
	return root and root:FindFirstChild("SnatchPrompt")
end

task.spawn(function()
	while true do
		task.wait(1)
		for player, run in pairs(runs) do
			local data = PlayerData.get(player)
			local safe = inNest(player)
			if data and not run.started and not safe and rootOf(player) then
				startRun(player, run, data)
			elseif data and run.started and safe and not atRisk(run) and not run.choice and run.bankedPearls == 0 then
				-- back home with nothing at stake: the dive quietly ends and you heal up
				runs[player] = newRun()
				run = runs[player]
			end
			if run.heat > 0 and os.clock() - run.lastGain >= Config.Heat.decayInterval then
				run.decayTicks += 1
				if run.decayTicks >= Config.Heat.decayInterval then
					run.decayTicks = 0
					run.heat -= 1
					if run.heat < Config.Heat.lockAt then
						run.lockDropped = false
					end
				end
			end
			if run.heat >= Config.Heat.hazardAt and not safe then
				run.riptideTicks += 1
				local root = rootOf(player)
				if Threats.riptidePaused() then
					run.riptideTicks = 0
				elseif run.riptideTicks >= Config.Heat.riptideEvery and root then
					run.riptideTicks = 0
					local outward = flat(root.Position)
					if outward.Magnitude < 1 then
						outward = Vector3.new(1, 0, 0)
					end
					local direction = CFrame.Angles(0, rng:NextNumber(-0.7, 0.7), 0):VectorToWorldSpace(outward.Unit)
					HazardEvent:FireClient(player, "Riptide", direction, Config.Heat.riptideSeconds, Config.Heat.riptideSpeed)
				end
			else
				run.riptideTicks = 0
			end
			local phase = rawPhase(run)
			if phase > run.phase then
				notify(player, PHASE_TEXT[phase], phase >= 2 and "bad" or "warn")
				cue(player, "Phase", phase)
			end
			run.phase = phase
			run.maxPhase = math.max(run.maxPhase, phase)
			if run.choice then
				choiceTick(player, run)
			end
			local snatch = snatchPromptFor(player)
			if snatch then
				snatch.Enabled = snatchAllowed(player, runs[player] or run)
			end
			if data then
				if data.heatDebt > 0 and BaseService.atHome(player) then
					data.heatDebtRest += 1
					if data.heatDebtRest >= HC.drainSeconds then
						data.heatDebt = 0
						data.heatDebtRest = 0
						notify(player, "Your carried heat has cooled off. Your next dive starts at heat 0.", "good")
					end
				end
				Companions.refresh(player, data)
				incomeCarry[player] = (incomeCarry[player] or 0) + BaseService.income(data) / 60
				local whole = math.floor(incomeCarry[player])
				if whole > 0 then
					data.pearls += whole
					incomeCarry[player] -= whole
				end
			end
			push(player)
		end
	end
end)

-- Reef Warden (Master Patch 3 Table A) -------------------------------------------------------------
-- Sleeps on its rock, patrols at heat 25 (Canon). Phase 1 guards the exit between you and your nearest
-- beacon, Phase 2 chases (lock-on breaks after 6 s out of sight), Phase 3 chases faster. Every strike
-- has a 0.6 s wind-up you can see, then it lunges up to 6 studs: step out of the way.

local warden = shoals:WaitForChild("ReefWarden")
local lairCFrame = warden:GetPivot()
local waypoints = shoals:WaitForChild("WardenPath"):GetChildren()
table.sort(waypoints, function(a, b)
	return a.Name < b.Name
end)
local waypointIndex = 1
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local windup = nil -- { at = Vector3, untilTime = number }

local function canSee(fromPos, player, root)
	local offset = root.Position - fromPos
	if offset.Magnitude > R.lockLoseRange then
		return false
	end
	sightParams.FilterDescendantsInstances = { warden, player.Character }
	return workspace:Raycast(fromPos, offset, sightParams) == nil
end

local function guardPoint(run, root)
	local best, bestDistance = nil, math.huge
	for _, beacon in ipairs(beacons) do
		if not run.spentBeacons[beacon] and not Config.safeZone(beacon.Position) then
			local distance = (flat(beacon.Position) - flat(root.Position)).Magnitude
			if distance < bestDistance then
				best, bestDistance = beacon, distance
			end
		end
	end
	if not best then
		return root.Position
	end
	return root.Position + (best.Position - root.Position) * 0.65
end

local function moveWarden(goal, speed, dt)
	local wardenPos = warden:GetPivot().Position
	local delta = Vector3.new(goal.X, Config.Warden.hoverY, goal.Z) - wardenPos
	if delta.Magnitude <= 0.05 then
		return
	end
	local newPos = wardenPos + delta.Unit * math.min(delta.Magnitude, speed * dt)
	local flatPos = flat(newPos)
	if flatPos.Magnitude < Config.World.wardenNoGoRadius then
		flatPos = flatPos.Unit * Config.World.wardenNoGoRadius
		newPos = Vector3.new(flatPos.X, newPos.Y, flatPos.Z)
	end
	local facing = flat(delta)
	if facing.Magnitude > 0.01 then
		warden:PivotTo(CFrame.lookAt(newPos, newPos + facing))
	else
		warden:PivotTo(CFrame.new(newPos) * warden:GetPivot().Rotation)
	end
end

local function canStrike(player, run, root, center, radius)
	return run.started and atRisk(run) and not inNest(player) and (flat(root.Position) - flat(center)).Magnitude <= radius and math.abs(root.Position.Y - center.Y) < 14
end

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	local wardenPos = warden:GetPivot().Position
	local active, target, targetScore = false, nil, -1
	for player, run in pairs(runs) do
		local root = rootOf(player)
		if root and run.started and not inNest(player) then
			local phase = rawPhase(run)
			if run.heat >= Config.Heat.patrolAt or phase > 0 then
				active = true
			end
			if phase >= 2 and not run.lockDropped then
				if canSee(wardenPos, player, root) then
					run.unseenFor = 0
				else
					run.unseenFor += dt
					if run.unseenFor >= R.lockLoseSight then
						run.lockDropped = true
						run.unseenFor = 0
						notify(player, "You broke line of sight. The Reef Warden lost your trail and goes back to guarding the exit!", "good")
						cue(player, "LockLost")
					end
				end
			end
			local b = behaviour(run)
			if b > 0 and b * 1000 + run.heat > targetScore then
				target, targetScore = { root = root, run = run, behaviour = b }, b * 1000 + run.heat
			end
		end
	end
	if active ~= wardenActive then
		wardenActive = active
		warden:SetAttribute("Active", active)
	end

	-- a strike that is winding up lands when the tell ends
	if windup then
		if t < windup.untilTime then
			return
		end
		local toward = flat(windup.at - wardenPos)
		local strikePos = wardenPos
		if toward.Magnitude > 0.1 then
			strikePos = wardenPos + toward.Unit * math.min(6, toward.Magnitude)
		end
		local flatStrike = flat(strikePos)
		if flatStrike.Magnitude < Config.World.wardenNoGoRadius then
			flatStrike = flatStrike.Unit * Config.World.wardenNoGoRadius
			strikePos = Vector3.new(flatStrike.X, strikePos.Y, flatStrike.Z)
		end
		warden:PivotTo(CFrame.new(strikePos) * warden:GetPivot().Rotation)
		for player, run in pairs(runs) do
			local root = rootOf(player)
			if root and canStrike(player, run, root, strikePos, G.strikeRadius) then
				damage(player, G.damage, strikePos, G.name, true)
			end
		end
		warden:SetAttribute("Tell", false)
		windup = nil
		wardenPauseUntil = t + G.recover
		return
	end

	if t < wardenPauseUntil then
		return
	end
	if target and target.behaviour >= 2 then
		moveWarden(target.root.Position, target.behaviour >= 3 and G.speeds.fury or G.speeds.chase, dt)
	elseif target then
		moveWarden(guardPoint(target.run, target.root), G.speeds.guard, dt)
	elseif active then
		local goal = waypoints[waypointIndex].Position
		if (flat(goal) - flat(wardenPos)).Magnitude < 3 then
			waypointIndex = waypointIndex % #waypoints + 1
		end
		moveWarden(goal, G.speeds.patrol, dt)
	else
		moveWarden(lairCFrame.Position, G.speeds.patrol, dt)
	end

	if not active then
		return
	end
	wardenPos = warden:GetPivot().Position
	for player, run in pairs(runs) do
		local root = rootOf(player)
		if root and canStrike(player, run, root, wardenPos, G.lungeRange) then
			windup = { at = root.Position, untilTime = t + G.tell }
			warden:SetAttribute("Tell", true)
			cue(player, "WardenTell")
			break
		end
	end
end)

-- Player lifecycle ---------------------------------------------------------------

local function onPlayerAdded(player)
	local data = PlayerData.load(player)
	runs[player] = newRun()
	-- after the client has loaded, so the toast is seen
	task.delay(4, function()
		if player.Parent then
			BaseService.offlineIncome(player, data)
		end
	end)
	if not BaseService.assign(player) then
		notify(player, "Every Home Nest on this server is taken, so your base is hidden this session. Your progress is safe.", "warn")
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local pearls = Instance.new("IntValue")
	pearls.Name = "Pearls"
	pearls.Parent = stats
	local hatched = Instance.new("IntValue")
	hatched.Name = "Hatched"
	hatched.Parent = stats
	stats.Parent = player

	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")
		local snatch = Instance.new("ProximityPrompt")
		snatch.Name = "SnatchPrompt"
		snatch.ActionText = "Snatch Egg"
		snatch.ObjectText = player.DisplayName
		snatch.HoldDuration = Config.Contested.snatchHold
		snatch.MaxActivationDistance = Config.Contested.snatchRange
		snatch.RequiresLineOfSight = false
		snatch.Enabled = false
		snatch:SetAttribute("Action", "Snatch")
		snatch.Parent = root
		humanoid.Died:Connect(function()
			local run = runs[player]
			if run and (run.carriedPearls > 0 or run.carriedEggs > 0) then
				wipe(player, "You were swept away.")
			end
		end)
		task.defer(function()
			local current = PlayerData.get(player)
			if current then
				Companions.refresh(player, current, true)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	push(player)
	notify(player, "Welcome to Tidebound: Eggfall! Talk to Gate Warden Sel to dive, bank fish at the Tide Cache, steal eggs, then extract at a beacon.", "info")
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	BaseService.release(player)
	Companions.release(player)
	PlayerData.release(player)
	runs[player] = nil
	incomeCarry[player] = nil
end)

game:BindToClose(function()
	PlayerData.saveAll()
end)

task.spawn(function()
	while true do
		task.wait(60)
		for player in pairs(runs) do
			task.spawn(PlayerData.save, player)
		end
	end
end)
