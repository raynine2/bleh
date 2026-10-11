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
--   Patches 5-7: casts are shown to everyone (attributes on the character, played by TideboundRod), each
--            catch rolls a mutation and weight and plays a reveal you can't be hurt in, a Celestial catch is
--            announced server-wide, and your rod rides on your back (Rods).
--   Big Update: PUSH DEEPER at a Shoals beacon dives you into Kelp Cathedral (DescentBuilder) with its own
--            fish and guardian, the Kelp Leviathan. Cutscenes play for the first join, every dive, a guardian
--            waking, the descent, extraction (which lifts you home) and a wipe. Attributes on your character
--            (HurtAt, StunUntil, CarryEggs, GrabAt, CheerAt, DownAt) drive everyone's TideboundMotion.
--   Patch 10 (the Open Isles): the map is about 10x bigger: Eggfall Town (TownBuilder) is the safe spawn, and
--            the Sunken Shoals (ShoalsBuilder) are 22 islands in an open sea, laid out by IslesLayout. Mobs camp
--            across the islands and fight you (Mobs); you swipe them with your rod (SwingAt). Stand by a Tide
--            Cache to heal, and you slowly heal anywhere once nothing has hurt you for a while.
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
local Rods = require(script.Parent:WaitForChild("Rods"))
local DescentBuilder = require(script.Parent:WaitForChild("DescentBuilder"))
local TownBuilder = require(script.Parent:WaitForChild("TownBuilder"))
local ShoalsBuilder = require(script.Parent:WaitForChild("ShoalsBuilder"))
local Mobs = require(script.Parent:WaitForChild("Mobs"))
local CollectionService = game:GetService("CollectionService")

local world = WorldBuilder.build()
TownBuilder.build(world)
local shoals = ShoalsBuilder.build(world)
local delta = ExpansionBuilder.build(world)
local descent = DescentBuilder.build(world)
local kelp = descent:WaitForChild("KelpCathedral")

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
local SwipeEvent = remote("RemoteEvent", "Swipe") -- Patch 10: the client asks to swipe its rod

local R = Config.Risk
local G = Config.Guardian
local GREED = Config.Greed
local MODES = Config.Modes
local DURA = Config.Durability
local HC = Config.HeatCarry
local REVEAL = Config.Reveal
local CUT = Config.Cutscene
local rng = Random.new()
local runs = {} -- [Player] = run state: heat and the cargo at risk; lost on wipe, never saved
local incomeCarry = {} -- [Player] = fractional Pearls of aquarium income
local beaconsClosedUntil = 0
local wardenActive = false
local guardianFor -- the guardian of the biome a run is in (set with the guardians below)

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
		revealUntil = 0, -- Master Patch 6: no threat can hurt you while your fish reveal plays
		depth = 1, -- Big Update: 1 = Sunken Shoals, 2 = Kelp Cathedral
		maxDepth = 1,
		travelUntil = 0, -- a descent, ascent or extraction cutscene is moving you; nothing can hurt you
		woke = {}, -- [guardian id] = true once its wake cutscene played this run
		lastHurt = 0, -- Patch 10: out-of-combat healing waits Config.Isles.regenDelay after this
		regen = 0, -- fractional health healed so far
		swipeAt = 0,
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

-- Attributes on your character that every client's TideboundMotion plays (hurt, stun, carry, grab, cheer, down).
local function mark(player, key, value)
	local character = player.Character
	if character then
		character:SetAttribute(key, value)
	end
end

-- Master Patch 5: everyone sees your cast. The phase rides on your character and TideboundRod plays it:
-- "cast" (windup, release, wait, then the bite at FishAt + FishBite), "land" or "break".
local fishTokens = {} -- [Player] = number, so a stale timer never clears a newer cast
local pendingAnnounce = {} -- [Player] = the Celestial announcement waiting for the reveal to end

local function setFishPhase(player, phase, clearAfter, attributes)
	fishTokens[player] = (fishTokens[player] or 0) + 1
	local token = fishTokens[player]
	local character = player.Character
	if character then
		character:SetAttribute("FishPhase", phase)
		character:SetAttribute("FishAt", now())
		for key, value in pairs(attributes or {}) do
			character:SetAttribute(key, value)
		end
	end
	Rods.hold(player, phase ~= "")
	if clearAfter then
		task.delay(clearAfter, function()
			if fishTokens[player] == token and player.Parent then
				setFishPhase(player, "")
			end
		end)
	end
end

local function announce(player)
	local text = pendingAnnounce[player]
	pendingAnnounce[player] = nil
	if text then
		notifyAll(text, "rare")
	end
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
		-- Big Update
		depth = run.depth,
		biomeName = (Config.Biomes[run.depth] or Config.Biomes[1]).name,
		guardianName = guardianFor(run).cfg.name,
		seenIntro = data.seenIntro == true,
	}
end

local function push(player)
	local state = buildState(player)
	if not state then
		return
	end
	StateEvent:FireClient(player, state)
	mark(player, "CarryEggs", state.carriedEggs)
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

-- Big Update: a cutscene moves you (the descent, the ascent, extraction, a wipe). Nothing can hurt you
-- meanwhile; the teleport lands while the screen is dark, after the area around the destination has streamed in.
local function travel(player, run, cframe, delay, depth)
	run.travelUntil = now() + delay + 1.5
	run.invulnerableUntil = math.max(run.invulnerableUntil, run.travelUntil)
	task.delay(delay, function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		pcall(player.RequestStreamAroundAsync, player, cframe.Position, 4)
		if player.Character ~= character then
			return
		end
		character:PivotTo(cframe)
		if depth and runs[player] == run then
			run.depth = depth
			run.maxDepth = math.max(run.maxDepth, depth)
			push(player)
		end
	end)
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
	setFishPhase(player, "")
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
	-- Big Update: you collapse where you fell, the screen fades, and you wake up in the Nest
	mark(player, "DownAt", now())
	cue(player, "Cutscene", { kind = "Wiped", reason = reason, lostPearls = lostPearls, lostEggs = lostEggs })
	travel(player, runs[player], Config.World.spawnCFrame, CUT.wipeTeleport)
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
	if not run or not rootOf(player) or inNest(player) or now() < math.max(run.invulnerableUntil, run.revealUntil, run.travelUntil) then
		return
	end
	run.health = math.max(0, run.health - amount)
	run.invulnerableUntil = now() + R.hitInvulnerable
	run.lastHurt = now()
	mark(player, "HurtAt", now())
	mark(player, "HurtAmount", amount)
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
	if not run or inNest(player) or now() < run.stunUntil or now() < math.max(run.revealUntil, run.travelUntil) then
		return
	end
	run.stunUntil = now() + seconds
	mark(player, "StunUntil", run.stunUntil)
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

-- Anyone out of the safe zones on a dive, alive: what threats and mobs may target.
local function exposedRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and humanoid and humanoid.Health > 0 and runs[player] and not Config.safeZone(root.Position) then
		return root
	end
	return nil
end

Threats.init({
	delta = delta,
	notify = notify,
	notifyAll = notifyAll,
	cue = cue,
	exposed = exposedRoot,
	damage = function(player, amount, fromPosition, label)
		damage(player, amount, fromPosition, label, false)
	end,
	stun = stun,
	giveBait = giveBait,
})

-- Patch 10: wild mobs across the Open Isles and Kelp Cathedral, and the rod swipe that fights them.
Mobs.init({
	world = world,
	notify = notify,
	exposed = exposedRoot,
	damage = function(player, amount, fromPosition, label)
		damage(player, amount, fromPosition, label, false)
	end,
	heatOf = function(player)
		local run = runs[player]
		return run and run.heat or 0
	end,
	giveBait = giveBait,
})

local swipeTokens = {} -- [Player] = the latest swing, so only it puts the rod back
SwipeEvent.OnServerEvent:Connect(function(player)
	local run, root = runs[player], rootOf(player)
	if not run or not root or now() - run.swipeAt < Config.Swipe.cooldown * 0.8 then
		return
	end
	if run.session or now() < math.max(run.revealUntil, run.travelUntil, run.stunUntil) then
		return
	end
	local token = now()
	run.swipeAt = token
	mark(player, "SwingAt", token) -- every client's TideboundMotion and TideboundRod play the swing
	-- the rod jumps from your back to your hand for the swing, then goes back
	Rods.hold(player, true)
	swipeTokens[player] = token
	task.delay(0.7, function()
		local current = runs[player]
		if swipeTokens[player] == token and not (current and current.session) then
			swipeTokens[player] = nil
			Rods.hold(player, false)
		end
	end)
	if not Config.safeZone(root.Position) then
		Mobs.swipe(player, root)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	swipeTokens[player] = nil
end)

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
	if now() < run.revealUntil then
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
	-- Big Update: each spot belongs to a biome; deeper biomes multiply your luck (Kelp Cathedral x1.3)
	local biomeIndex = prompt:GetAttribute("Biome") or 1
	local biome = Config.Biomes[biomeIndex] or Config.Biomes[1]
	local luck = rod.luck * (bait and bait.luck or 1) * (biome.luck or 1)
	local tierIndex = Gacha.rollFishTier(luck, rng)
	if pier then
		tierIndex = math.min(tierIndex, Config.Harbor.pier.maxTier)
	end
	local names = biome.fish[tierIndex]
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
		biome = biomeIndex,
		started = os.clock(),
		minTime = biteWait + Config.Fishing.minReelSeconds,
	}
	-- the bobber lands somewhere on the fishing spot's ring
	local spotPart = prompt.Parent
	local root = rootOf(player)
	local center = (spotPart and spotPart:IsA("BasePart") and spotPart.Position) or (root and root.Position) or Vector3.zero
	local spot = center + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
	setFishPhase(player, "cast", nil, { FishBite = biteWait, FishSpot = spot, FishTier = 0, FishName = "", FishShowAt = 0 })
	FishingEvent:FireClient(player, {
		id = run.session.id,
		biteWait = biteWait,
		difficulty = tierIndex,
		control = rod.control,
		resilience = rod.resilience,
		bait = bait and bait.name or nil,
		broken = broken,
		pier = pier,
		spot = spot,
		rod = data.rod, -- the look: a broken rod keeps its look
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
	mark(player, "GrabAt", now())
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
		-- the trophy comes from the deepest guardian you faced this run
		local g = run.maxDepth >= 2 and Config.Leviathan or G
		data.trophies[g.drop] = (data.trophies[g.drop] or 0) + 1
		table.insert(lines, ("You escaped the %s's Phase 3: +1 %s for your Trophy Room (%d/%d for its Bestiary page)."):format(g.name, g.dropName, data.trophies[g.drop], g.dropsForPage))
	end
	if data.settings.contested then
		data.settings.contested = false
		table.insert(lines, "Contested Waters is back to OFF.")
	end
	notify(player, table.concat(lines, " "), "good")
	cue(player, "Extract")
	-- Big Update: a column of light lifts you out, the tally plays, and you land back in the Nest
	mark(player, "CheerAt", now())
	cue(player, "Cutscene", {
		kind = "Extracted",
		fishPearls = fishPearls,
		payout = payout,
		eggs = run.carriedEggs,
		embers = embers,
		streak = streak,
		mult = mult,
		biome = (Config.Biomes[run.depth] or Config.Biomes[1]).name,
	})
	local session = run.session
	local fresh = newRun()
	fresh.session = session
	runs[player] = fresh
	travel(player, fresh, Config.World.spawnCFrame, CUT.extractTeleport)
	BaseService.refresh(player)
	push(player)
end

-- Push deeper: +40% cargo value, +25 heat, guardian one phase angrier, and this beacon is spent. From the
-- Shoals it dives you down the Maelstrom into Kelp Cathedral (Big Update); deeper biomes aren't built yet, so
-- a push in the Kelp keeps you there and needs a different beacon.
local function pushDeeper(player, run)
	local beacon = run.choice and run.choice.beacon
	run.choice = nil
	run.pushes += 1
	run.aggro += GREED.aggro
	if beacon then
		run.spentBeacons[beacon] = true
	end
	local cargo = 1 + run.pushes * GREED.cargoPct
	if run.depth == 1 then
		local kelpBiome = Config.Biomes[2]
		notify(player, ("You pushed deeper: the Maelstrom pulls you down into %s! Cargo x%.1f, heat +%d, rarer bites (luck x%.1f), and the %s is waiting."):format(kelpBiome.name, cargo, GREED.heat, kelpBiome.luck, Config.Leviathan.name), "warn")
		cue(player, "Cutscene", { kind = "Descent", name = kelpBiome.name, depth = 2, guardian = Config.Leviathan.name, hazard = kelpBiome.hazard, luck = kelpBiome.luck })
		travel(player, run, Config.Kelp.arrival, CUT.descentTeleport, 2)
	else
		notify(player, ("You pushed deeper: cargo x%.1f, heat +%d, and the %s gets angrier. Extract at a different beacon."):format(cargo, GREED.heat, guardianFor(run).cfg.name), "warn")
	end
	cue(player, "Push")
	addHeat(player, GREED.heat)
	push(player)
end

-- Big Update: the current at the Descent dais carries you back up to the Shoals (your cargo comes along).
local function onAscend(player)
	local run = runs[player]
	if not run or now() < run.travelUntil then
		return
	end
	notify(player, "The current carries you back up to the Sunken Shoals.", "info")
	cue(player, "Cutscene", { kind = "Ascend", name = Config.Biomes[1].name, depth = 1, guardian = G.name, hazard = Config.Biomes[1].hazard })
	travel(player, run, Config.Kelp.ascend, CUT.descentTeleport, 1)
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
		and now() >= victimRun.revealUntil
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
	elseif action == "Ascend" then
		onAscend(player)
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
		setFishPhase(player, "break", 1)
		return { error = "The line snapped." }
	end
	local pierPct = session.pier and Config.Harbor.pier.payoutPct or 1
	if success ~= true then
		setFishPhase(player, "break", 1)
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
	-- Master Patch 6: the tier was rolled at the cast; the mutation and weight are rolled now
	local tier = Config.Tiers[session.tier]
	local mutation = Gacha.rollMutation(rng)
	local named = mutation.id ~= "None" and (mutation.id .. " ") or ""
	local isNew = not data.bestiary[session.fish]
	-- Canon: 25-120 Pearls per fish. Perfect catches, mutations and the solo or Crew bonus all stay inside it.
	local cap = Config.Tiers[#Config.Tiers].fishPearls
	local pearls = math.min(cap, tier.fishPearls * (perfect == true and Config.Fishing.perfectBonus or 1) * mutation.mult)
	data.stats.fishCaught += 1
	data.bestiary[session.fish] = true
	questProgress(player, data, "fish", 1)
	local lines
	if session.pier then
		pearls = math.floor(pearls * pierPct)
		data.pearls += pearls
		local baitText = ""
		if rng:NextNumber() < Config.Harbor.pier.baitChance then
			data.baitInv.Brineworm = (data.baitInv.Brineworm or 0) + 1
			baitText = " Found a Brineworm!"
		end
		lines = { ("%s %s%s: +%d Pearls banked (pier, no Heat).%s"):format(perfect == true and "Perfect catch!" or "Caught", named, session.fish, pearls, baitText) }
	else
		pearls = math.min(cap, math.floor(pearls * run.modeMult))
		run.carriedPearls += pearls
		run.carriedFish += 1
		addHeat(player, Config.Heat.perFish)
		lines = { ("%s %s%s (%s): +%d Pearls of cargo. Bank it at the Tide Cache to keep it safe."):format(perfect == true and "Perfect catch!" or "Caught", named, session.fish, tier.id, pearls) }
		local bonus = Threats.onCatch(player)
		if bonus then
			table.insert(lines, bonus)
		end
	end
	-- weight is for show: a squared roll keeps big fish rare, and "Top X%" is that roll's percentile
	local range = REVEAL.weights[session.tier]
	local u = rng:NextNumber()
	local weight = math.floor((range[1] + (range[2] - range[1]) * u * u) * 10 + 0.5) / 10
	local nearMiss = session.tier < #Config.Tiers and rng:NextNumber() < REVEAL.nearMissChance
	local reveal = Config.revealSeconds(session.tier, nearMiss)
	local total = REVEAL.landSeconds + reveal
	run.revealUntil = now() + total
	-- other players see the fish's colour when your climb reaches it
	local climb = REVEAL.landSeconds + REVEAL.silhouette + session.tier * REVEAL.step + (nearMiss and REVEAL.nearMissHold + REVEAL.nearMissDrain or 0)
	setFishPhase(player, "land", total, { FishTier = session.tier, FishName = session.fish, FishShowAt = now() + climb })
	if session.tier == #Config.Tiers then
		pendingAnnounce[player] = ("%s landed a CELESTIAL %s%s in the %s!"):format(player.DisplayName, named, session.fish, session.pier and "Harbor Lagoon" or Config.Biomes[session.biome].name)
		task.delay(total, announce, player)
	end
	return {
		ok = true,
		caught = true,
		fish = session.fish,
		tier = session.tier,
		pearls = pearls,
		mutation = mutation.id,
		mult = mutation.mult,
		weight = weight,
		top = math.max(1, math.ceil((1 - u) * 100)),
		isNew = isNew,
		nearMiss = nearMiss,
		reveal = reveal,
		biome = session.pier and "Harbor Lagoon" or Config.Biomes[session.biome].name,
		note = table.concat(lines, " "),
		noteKind = session.tier >= 4 and "rare" or "good",
	}
end

-- The reveal ended (or was skipped): you can be hurt again and the fish leaves your hands.
function handlers.RevealDone(player, _data, run)
	if run.revealUntil > now() then
		run.revealUntil = now()
		setFishPhase(player, "")
		announce(player)
	end
	return { ok = true }
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
	local biome = Config.Biomes[1]
	cue(player, "Cutscene", { kind = "Dive", name = biome.name, depth = 1, guardian = G.name, hazard = biome.hazard, mode = mode })
	return { ok = true }
end

-- Big Update: the opening cutscene played (or was skipped), so it won't play again.
function handlers.IntroSeen(player, data)
	data.seenIntro = true
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
	Rods.attach(player, rodId)
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
	if run.session then
		return { error = "Finish your cast first." }
	end
	data.rod = rodId
	Rods.attach(player, rodId)
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

-- Guardians (Master Patch 3 Table A) ------------------------------------------------------------------------
-- Each biome's guardian sleeps in its lair and patrols at heat 25 (Canon). Phase 1 guards the exit between you
-- and your nearest beacon, Phase 2 chases (lock-on breaks after 6 s out of sight), Phase 3 chases faster.
-- Every strike has a wind-up you can see (0.6 s for the Reef Warden, 0.7 s for the Kelp Leviathan), then it
-- lunges up to 6 studs: step out of the way. A guardian only hunts divers in its own biome.

local PHASE_TEXT = {
	"Reef Warden Phase 1: it rises to guard the exit. Hide behind coral and dash between cover.",
	"Reef Warden Phase 2: it has locked onto you. Break line of sight for 6 s to shake it.",
	"Reef Warden Phase 3: full fury. It's faster than ever. Get to a beacon!",
}
local LEVIATHAN_TEXT = {
	"Kelp Leviathan Phase 1: it uncoils to guard the exit. Weave between the kelp columns.",
	"Kelp Leviathan Phase 2: it has your scent. Break line of sight for 6 s to shake it.",
	"Kelp Leviathan Phase 3: the whole cathedral shakes. Run for a beacon!",
}

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function newGuardian(id, model, pathFolder, cfg, depth, hoverY, noGoCenter, noGoRadius, phaseText)
	local waypoints = pathFolder:GetChildren()
	table.sort(waypoints, function(a, b)
		return a.Name < b.Name
	end)
	return {
		id = id,
		model = model,
		cfg = cfg,
		depth = depth,
		hoverY = hoverY,
		noGoCenter = Vector3.new(noGoCenter.X, 0, noGoCenter.Z),
		noGoRadius = noGoRadius,
		phaseText = phaseText,
		lair = model:GetPivot(),
		waypoints = waypoints,
		waypointIndex = 1,
		windup = nil, -- { at = Vector3, untilTime = number }
		pauseUntil = 0,
		active = false,
	}
end

local guardians = {
	newGuardian("ReefWarden", shoals:WaitForChild("ReefWarden"), shoals:WaitForChild("WardenPath"), G, 1, Config.Warden.hoverY, Vector3.zero, Config.World.wardenNoGoRadius, PHASE_TEXT),
	newGuardian("KelpLeviathan", kelp:WaitForChild("KelpLeviathan"), kelp:WaitForChild("LeviathanPath"), Config.Leviathan, 2, Config.Leviathan.hoverY, Config.Kelp.arrival.Position, Config.Leviathan.noGoRadius, LEVIATHAN_TEXT),
}

guardianFor = function(run)
	return guardians[run.depth] or guardians[1]
end

-- Is this diver in the guardian's biome and fair game right now?
local function hunts(g, player, run, root)
	return run.started and now() >= run.travelUntil and not inNest(player) and ((Config.zoneOf(root.Position) == "Kelp") == (g.depth == 2))
end

-- Big Update: the guardian rises and the camera shows it; it holds still and can't hurt you meanwhile.
local function wake(player, run, g)
	run.woke[g.id] = true
	g.pauseUntil = math.max(g.pauseUntil, now() + CUT.wakeSeconds)
	if g.windup then
		g.windup = nil
		g.model:SetAttribute("Tell", false)
	end
	run.invulnerableUntil = math.max(run.invulnerableUntil, now() + CUT.wakeSeconds + 0.5)
	g.model:SetAttribute("WokeAt", now())
	cue(player, "Cutscene", { kind = "Wake", name = g.cfg.name, at = g.model:GetPivot().Position, depth = g.depth })
end

local function canSee(g, fromPos, player, root)
	local offset = root.Position - fromPos
	if offset.Magnitude > R.lockLoseRange then
		return false
	end
	sightParams.FilterDescendantsInstances = { g.model, player.Character }
	return workspace:Raycast(fromPos, offset, sightParams) == nil
end

local function guardPoint(g, run, root)
	local best, bestDistance = nil, math.huge
	for _, beacon in ipairs(beacons) do
		if not run.spentBeacons[beacon] and not Config.safeZone(beacon.Position) and (beacon:GetAttribute("Depth") or 1) == g.depth then
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

-- keeps a guardian out of its no-go circle (the Nest for the Warden, the Descent dais for the Leviathan)
local function outsideNoGo(g, position)
	local fromCenter = flat(position) - g.noGoCenter
	if fromCenter.Magnitude >= g.noGoRadius then
		return position
	end
	local dir = fromCenter.Magnitude > 0.01 and fromCenter.Unit or Vector3.new(1, 0, 0)
	local edge = g.noGoCenter + dir * g.noGoRadius
	return Vector3.new(edge.X, position.Y, edge.Z)
end

local function moveGuardian(g, goal, speed, dt)
	local pos = g.model:GetPivot().Position
	local delta = Vector3.new(goal.X, g.hoverY, goal.Z) - pos
	if delta.Magnitude <= 0.05 then
		return
	end
	local newPos = outsideNoGo(g, pos + delta.Unit * math.min(delta.Magnitude, speed * dt))
	local facing = flat(delta)
	if facing.Magnitude > 0.01 then
		g.model:PivotTo(CFrame.lookAt(newPos, newPos + facing))
	else
		g.model:PivotTo(CFrame.new(newPos) * g.model:GetPivot().Rotation)
	end
end

local function canStrike(g, player, run, root, center, radius)
	return hunts(g, player, run, root) and atRisk(run) and (flat(root.Position) - flat(center)).Magnitude <= radius and math.abs(root.Position.Y - center.Y) < 14
end

local function tickGuardian(g, dt, t)
	local cfg = g.cfg
	local pos = g.model:GetPivot().Position
	local active, target, targetScore = false, nil, -1
	for player, run in pairs(runs) do
		local root = rootOf(player)
		if root and hunts(g, player, run, root) then
			local phase = rawPhase(run)
			if run.heat >= Config.Heat.patrolAt or phase > 0 then
				active = true
			end
			if phase >= 2 and not run.lockDropped then
				if canSee(g, pos, player, root) then
					run.unseenFor = 0
				else
					run.unseenFor += dt
					if run.unseenFor >= R.lockLoseSight then
						run.lockDropped = true
						run.unseenFor = 0
						notify(player, ("You broke line of sight. The %s lost your trail and goes back to guarding the exit!"):format(cfg.name), "good")
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
	if active ~= g.active then
		g.active = active
		g.model:SetAttribute("Active", active)
	end

	-- a strike that is winding up lands when the tell ends
	if g.windup then
		if t < g.windup.untilTime then
			return
		end
		local toward = flat(g.windup.at - pos)
		local strikePos = pos
		if toward.Magnitude > 0.1 then
			strikePos = pos + toward.Unit * math.min(6, toward.Magnitude)
		end
		strikePos = outsideNoGo(g, strikePos)
		g.model:PivotTo(CFrame.new(strikePos) * g.model:GetPivot().Rotation)
		g.model:SetAttribute("StrikeAt", now())
		for player, run in pairs(runs) do
			local root = rootOf(player)
			if root and canStrike(g, player, run, root, strikePos, cfg.strikeRadius) then
				damage(player, cfg.damage, strikePos, cfg.name, true)
			end
		end
		g.model:SetAttribute("Tell", false)
		g.windup = nil
		g.pauseUntil = t + cfg.recover
		return
	end

	if t < g.pauseUntil then
		return
	end
	if target and target.behaviour >= 2 then
		moveGuardian(g, target.root.Position, target.behaviour >= 3 and cfg.speeds.fury or cfg.speeds.chase, dt)
	elseif target then
		moveGuardian(g, guardPoint(g, target.run, target.root), cfg.speeds.guard, dt)
	elseif active then
		local goal = g.waypoints[g.waypointIndex].Position
		if (flat(goal) - flat(pos)).Magnitude < 3 then
			g.waypointIndex = g.waypointIndex % #g.waypoints + 1
		end
		moveGuardian(g, goal, cfg.speeds.patrol, dt)
	else
		moveGuardian(g, g.lair.Position, cfg.speeds.patrol, dt)
	end

	if not active then
		return
	end
	pos = g.model:GetPivot().Position
	for player, run in pairs(runs) do
		local root = rootOf(player)
		if root and canStrike(g, player, run, root, pos, cfg.lungeRange) then
			g.windup = { at = root.Position, untilTime = t + cfg.tell }
			g.model:SetAttribute("Tell", true)
			g.model:SetAttribute("TellAt", now())
			cue(player, "WardenTell", cfg.name)
			break
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for _, g in ipairs(guardians) do
		tickGuardian(g, dt, t)
	end
	wardenActive = guardians[1].active
end)

-- Once per second: dives, heat decay, riptide, the Greed Window, guardian phases, carried heat, snatch
-- prompts, companions and aquarium income ------------------------------------------------------------

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
			if run.session and os.clock() - run.session.started > 90 then
				run.session = nil
				setFishPhase(player, "")
			end
			-- Patch 10: heal in town or by a Tide Cache, and slowly anywhere once nothing has hurt you for a while
			if run.health < R.maxHealth and run.health > 0 then
				local root = rootOf(player)
				local heal = 0
				if safe then
					heal = Config.Isles.cacheHeal
				elseif root then
					for _, cache in ipairs(CollectionService:GetTagged("TideboundCache")) do
						if cache:IsA("BasePart") and (cache.Position - root.Position).Magnitude <= Config.Isles.cacheRadius then
							heal = Config.Isles.cacheHeal
							break
						end
					end
				end
				if heal == 0 and now() - run.lastHurt >= Config.Isles.regenDelay and not Mobs.inCombat(player) then
					run.regen += Config.Isles.regenPerSecond
					heal = math.floor(run.regen)
					run.regen -= heal
				end
				if heal > 0 then
					run.health = math.min(R.maxHealth, run.health + heal)
					push(player)
				end
			end
			if data and not run.started and not safe and rootOf(player) and now() >= run.travelUntil then
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
			if run.heat >= Config.Heat.hazardAt and not safe and run.depth == 1 then
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
			-- guardian phases (held while a cutscene moves you, so they land in the biome you arrive in)
			local phase = rawPhase(run)
			if now() >= run.travelUntil then
				local g = guardianFor(run)
				if phase > run.phase then
					notify(player, g.phaseText[phase], phase >= 2 and "bad" or "warn")
					cue(player, "Phase", { phase = phase, guardian = g.cfg.name })
				end
				local root = rootOf(player)
				if phase >= 1 and not run.woke[g.id] and root and hunts(g, player, run, root) then
					wake(player, run, g)
				end
				run.phase = phase
				run.maxPhase = math.max(run.maxPhase, phase)
			end
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
			-- Master Patch 7: your rod rides on your back
			Rods.hold(player, false)
			character:WaitForChild("UpperTorso", 5)
			character:WaitForChild("RightHand", 5)
			current = PlayerData.get(player)
			if current and character.Parent then
				Rods.attach(player, current.rod)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	push(player)
	notify(player, "Welcome to Tidebound: Eggfall! Talk to Gate Warden Sel to dive, bank fish at the Tide Cache, steal eggs, then extract at a beacon.", "info")

	-- Studio testing only (never in a live server): start with 10 Tide Eggs, and chat /eggs 25 or /pearls 5000
	if RunService:IsStudio() then
		data.eggs = math.max(data.eggs, 10)
		push(player)
		task.delay(5, function()
			if player.Parent then
				notify(player, "Studio test: you have Tide Eggs to hatch. Chat /eggs 25 or /pearls 5000 for more.", "info")
			end
		end)
		player.Chatted:Connect(function(message)
			local command, amount = message:lower():match("^/(%a+)%s*(%d*)")
			local current = PlayerData.get(player)
			if not current or not command then
				return
			end
			local n = math.clamp(tonumber(amount) or 10, 1, 100000)
			if command == "eggs" then
				current.eggs += n
				notify(player, ("Studio test: +%d Tide Eggs."):format(n), "good")
			elseif command == "pearls" then
				current.pearls += n
				notify(player, ("Studio test: +%d Pearls."):format(n), "good")
			else
				return
			end
			push(player)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	BaseService.release(player)
	Companions.release(player)
	Rods.release(player)
	fishTokens[player] = nil
	pendingAnnounce[player] = nil
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
