-- Tidebound: Eggfall server: fishing sessions, egg stealing, heat, Reef Warden, extraction, gacha.
-- Delta Section 9 risk rules live here too: 3 health, carry slowdown, the 3 s beacon channel and the
-- Greed Window, beacon grace, lock-on that breaks after 6 s out of sight, frayed rods, Lucky Scales and
-- opt-in Open Tide egg snatching. Home Nests, hub boards and the base economy are in BaseService.
-- Everything that grants currency or rolls odds happens here; the client only displays and asks.

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
local rng = Random.new()
local runs = {} -- [Player] = run state: heat and the haul at risk; lost on wipe, never saved
local incomeCarry = {} -- [Player] = fractional Pearls of aquarium income
local beaconsClosedUntil = 0
local wardenActive = false
local wardenPauseUntil = 0

local function now()
	return workspace:GetServerTimeNow()
end

local function newRun()
	return {
		heat = 0,
		carriedPearls = 0,
		carriedEggs = 0,
		carriedFish = 0,
		lastGain = 0,
		decayTicks = 0,
		riptideTicks = 0,
		session = nil,
		health = R.maxHealth,
		invulnerableUntil = 0,
		frayed = false,
		lockDropped = false,
		unseenFor = 0,
		greed = nil,
		graceUntil = 0,
		immuneUntil = 0,
		burstUntil = 0,
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

local function walkSpeed(data, run)
	local base = BaseService.walkSpeed(data)
	local speed = math.max(R.minWalkSpeed, base - run.carriedEggs * R.carrySlowPerEgg)
	if now() < run.burstUntil then
		speed += Config.OpenTide.burstSpeed
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
	local greed = run.greed and { started = run.greed.started, steps = run.greed.steps } or nil
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
		openTide = data.settings.openTide,
		heat = run.heat,
		carriedPearls = run.carriedPearls,
		carriedEggs = run.carriedEggs,
		carriedFish = run.carriedFish,
		health = run.health,
		maxHealth = R.maxHealth,
		frayed = run.frayed,
		locked = run.heat >= Config.Heat.lockAt and not run.lockDropped and not inNest(player),
		greed = greed,
		graceUntil = run.graceUntil,
		immuneUntil = run.immuneUntil,
		walkSpeed = walkSpeed(data, run),
		beaconsClosedUntil = beaconsClosedUntil,
		wardenActive = wardenActive,
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

-- Heat ----------------------------------------------------------------------

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

local function wipe(player, reason)
	local run = runs[player]
	if not run then
		return
	end
	local keptPearls = math.floor(run.carriedPearls * Config.Extraction.wipeKeepPearls)
	local lostPearls, lostEggs = run.carriedPearls - keptPearls, run.carriedEggs
	runs[player] = newRun()
	local data = PlayerData.get(player)
	if data then
		data.stats.wipes += 1
		data.stats.cleanStreak = 0
		data.pearls += keptPearls
	end
	notify(player, ("%s You kept %d Pearls of fish and lost %d Pearls and %d egg(s). Pity and bestiary are safe."):format(reason, keptPearls, lostPearls, lostEggs), "bad")
	cue(player, "Down")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		character:PivotTo(Config.World.spawnCFrame)
	end
	push(player)
end

-- A Warden hit costs 1 of 3 health; the third hit is a wipe.
local function hit(player, fromPosition)
	local run = runs[player]
	local root = rootOf(player)
	if not run or not root or now() < run.invulnerableUntil then
		return
	end
	run.health -= 1
	run.invulnerableUntil = now() + R.hitInvulnerable
	wardenPauseUntil = now() + R.wardenRecover
	if run.health <= 0 then
		wipe(player, "The Reef Warden caught you!")
		return
	end
	local away = Vector3.new(root.Position.X - fromPosition.X, 0, root.Position.Z - fromPosition.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(1, 0, 0)
	end
	HazardEvent:FireClient(player, "Hit", away.Unit)
	cue(player, "Hit", run.health)
	notify(player, ("The Reef Warden hit you! %d of %d health left."):format(run.health, R.maxHealth), "bad")
	push(player)
end

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
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
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
	run.session = {
		id = HttpService:GenerateGUID(false),
		tier = tierIndex,
		fish = fish,
		pier = pier,
		started = os.clock(),
		minTime = biteWait + Config.Fishing.minReelSeconds,
	}
	local frayed = run.frayed and not pier
	FishingEvent:FireClient(player, {
		id = run.session.id,
		biteWait = biteWait,
		difficulty = tierIndex,
		control = rod.control * (frayed and R.frayControl or 1),
		resilience = rod.resilience,
		bait = bait and bait.name or nil,
		frayed = frayed,
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
	egg:SetAttribute("Taken", true)
	prompt.Enabled = false
	egg.Transparency = 1
	for _, d in ipairs(egg:GetDescendants()) do
		if d:IsA("Light") or d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	local gained = 1
	if data.settings.openTide and rng:NextNumber() < Config.OpenTide.bonusEggChance then
		gained = 2
	end
	run.carriedEggs += gained
	run.lockDropped = false
	addHeat(player, Config.Heat.perSteal)
	questProgress(player, data, "steal", 1)
	cue(player, "Steal")
	if gained > 1 then
		notify(player, "Open Tide bonus: the nest held 2 Tide Eggs! +8 heat. Extract to keep them.", "good")
	else
		notify(player, "You stole a Tide Egg! +8 heat. Extract at a beacon to keep it.", "good")
	end
	push(player)
	task.delay(Config.World.eggRespawnSeconds, function()
		egg:SetAttribute("Taken", false)
		egg.Transparency = 0
		prompt.Enabled = true
		for _, d in ipairs(egg:GetDescendants()) do
			if d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = true
			end
		end
	end)
end

-- Banks the haul. `greedSteps` is how many 5 s Greed Window steps the player held (0-3).
local function bank(player, greedSteps)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	local x = Config.Extraction
	local payout = math.min(x.payoutCap, math.floor((x.payoutBase + run.carriedEggs * x.payoutPerEgg) * (1 + greedSteps * R.greedPayoutPct)))
	local streak = data.stats.cleanStreak + 1
	local streakEmbers = math.min(R.streakEmberMax, math.floor(streak / R.streakEmberEvery))
	local greedEmbers = greedSteps >= R.greedSeconds / R.greedStep and R.greedEmbers or 0
	local embers = math.clamp(x.baseEmbers + run.carriedEggs * x.embersPerEgg + math.floor(run.carriedPearls / x.pearlsPerEmber) + streakEmbers + greedEmbers, x.minEmbers, x.maxEmbers)
	data.pearls += run.carriedPearls + payout
	data.eggs += run.carriedEggs
	data.embers += embers
	data.stats.extractions += 1
	data.stats.cleanStreak = streak
	data.stats.bestStreak = math.max(data.stats.bestStreak, streak)
	data.stats.bestHeatExtract = math.max(data.stats.bestHeatExtract or 0, run.heat)
	questProgress(player, data, "extract", 1)
	local greedText = greedSteps > 0 and (" Greed Window +%d%%."):format(greedSteps * 15) or ""
	notify(player, ("Extracted! Banked %d fish Pearls + %d run payout, %d Tide Egg(s) and %d Run Embers. Streak %d.%s"):format(run.carriedPearls, payout, run.carriedEggs, embers, streak, greedText), "good")
	cue(player, "Extract")
	local session = run.session
	runs[player] = newRun()
	runs[player].session = session
	BaseService.refresh(player)
	push(player)
end

local function onExtract(player, prompt)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	if run.greed then
		return
	end
	if now() < beaconsClosedUntil and now() >= run.graceUntil then
		notify(player, "The beacons are closed. Survive until they reopen.", "bad")
		return
	end
	if run.carriedPearls == 0 and run.carriedEggs == 0 then
		local session = run.session
		runs[player] = newRun()
		runs[player].session = session
		notify(player, "Nothing to bank yet. Catch fish or steal eggs in the Shoals first.", "info")
		push(player)
		return
	end
	if inNest(player) then
		-- the Nest beacon is already safe, so it banks at once with no Greed Window
		bank(player, 0)
		return
	end
	run.greed = { position = prompt.Parent.Position, started = now(), steps = 0 }
	cue(player, "Greed")
	notify(player, "Channel complete! Walk away or press BANK NOW to leave. Hold here for the Greed Window: +15% payout and +5 Heat every 5 s.", "warn")
	push(player)
end

-- Open Tide egg snatching -------------------------------------------------------------------

local function snatchAllowed(victim, victimRun)
	local data = PlayerData.get(victim)
	local root = rootOf(victim)
	return data ~= nil
		and root ~= nil
		and data.settings.openTide
		and victimRun.carriedEggs > 0
		and now() >= victimRun.immuneUntil
		and not inNest(victim)
		and not nearBeacon(root.Position, Config.OpenTide.beaconSafeRadius)
end

local function onSnatch(player, prompt)
	local victim = Players:GetPlayerFromCharacter(prompt.Parent and prompt.Parent.Parent)
	local run, victimRun = runs[player], victim and runs[victim]
	local data = PlayerData.get(player)
	if not victim or victim == player or not run or not victimRun or not data then
		return
	end
	if not data.settings.openTide then
		notify(player, "Snatching is only for Open Tide runs. Switch at Gate Warden Sel.", "info")
		return
	end
	if not snatchAllowed(victim, victimRun) or inNest(player) then
		return
	end
	local root, victimRoot = rootOf(player), rootOf(victim)
	local offset = root.Position - victimRoot.Position
	if offset.Magnitude > Config.OpenTide.snatchRange + 1.5 then
		return
	end
	if offset.Unit:Dot(victimRoot.CFrame.LookVector) > 0 then
		notify(player, "They turned to face you. Snatches only work from behind!", "info")
		return
	end
	victimRun.carriedEggs -= 1 -- every Tide Egg is the same tier, so this is always the cheapest one
	victimRun.immuneUntil = now() + Config.OpenTide.immunity
	victimRun.burstUntil = now() + Config.OpenTide.burstSeconds
	run.carriedEggs += 1
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
	elseif action == "Snatch" then
		onSnatch(player, prompt)
	elseif action == "Travel" then
		onTravel(player, prompt)
	elseif action == "Feed" then
		BaseService.onFeed(player, prompt)
	elseif action == "Admire" then
		BaseService.onAdmire(player, prompt)
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
		local lines = { ("The %s got away."):format(session.fish) }
		if type(peak) == "number" and peak >= R.luckyScaleThreshold then
			local scale = math.floor(R.luckyScalePearls * pierPct)
			if session.pier then
				data.pearls += scale
			else
				run.carriedPearls += scale
			end
			table.insert(lines, ("It shed a Lucky Scale: +%d Pearls."):format(scale))
		end
		if not session.pier and not run.frayed then
			run.frayed = true
			table.insert(lines, "Your rod is frayed (-20% Control) until you extract.")
		end
		notify(player, table.concat(lines, " "), "info")
		return { ok = true, caught = false }
	end
	local tier = Config.Tiers[session.tier]
	local pearls = tier.fishPearls
	if perfect == true then
		pearls = math.floor(pearls * Config.Fishing.perfectBonus)
	end
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
		run.carriedPearls += pearls
		run.carriedFish += 1
		addHeat(player, Config.Heat.perFish)
		notify(player, ("%s %s (%s): +%d Pearls at risk."):format(perfect == true and "Perfect catch!" or "Caught", session.fish, tier.id, pearls), session.tier >= 4 and "rare" or "good")
	end
	return { ok = true, caught = true, fish = session.fish, tier = session.tier, pearls = pearls }
end

function handlers.BankNow(player, data, run)
	if not run.greed then
		return { error = "You're not at a beacon." }
	end
	local steps = run.greed.steps
	run.greed = nil
	bank(player, steps)
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

local function hatchOne(player, data)
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
	if value > (data.stats.bestHatchValue or 0) then
		data.stats.bestHatchValue = value
		data.stats.bestHatch = ("%s%s %s"):format(prefix, tier.id, creature)
	end
	if tierIndex >= 5 then
		notifyAll(("%s hatched a %s%s %s!"):format(player.DisplayName, prefix, tier.id, creature), "rare")
	end
	return { tier = tierIndex, creature = creature, mutation = mutation.id, value = value, shards = shards, isNew = isNew, pity = pityKey }
end

-- Hatches up to one egg per incubator slot at once.
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
		data.eggs -= 1
		local result = hatchOne(player, data)
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

function handlers.SetOpenTide(player, data, run, enabled)
	if type(enabled) ~= "boolean" then
		return { error = "Bad value." }
	end
	if atRisk(run) or not inNest(player) then
		return { error = "Pick Calm or Open Tide in the Nest or Harbor, before your run." }
	end
	data.settings.openTide = enabled
	notify(player, enabled and "Open Tide: rivals can snatch your eggs from behind, and egg nests can hold a bonus egg." or "Calm Tide: no PvP on your runs.", enabled and "warn" or "good")
	return { ok = true }
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

-- Home Nest handlers from BaseService (they don't need the run)
for name, handler in pairs(BaseService.handlers) do
	handlers[name] = function(player, data, _run, ...)
		return handler(player, data, ...)
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

-- Once per second: heat decay, riptide, the Greed Window, snatch prompts and aquarium income --------

local function greedTick(player, run)
	local greed = run.greed
	local root = rootOf(player)
	if now() < beaconsClosedUntil and now() >= run.graceUntil then
		run.greed = nil
		run.graceUntil = 0
		notify(player, "The Greed Window collapsed at Heat 100! Bonus lost. Reach another beacon when they reopen.", "bad")
		return
	end
	if not root or (root.Position - greed.position).Magnitude > 12 then
		run.greed = nil
		bank(player, greed.steps)
		return
	end
	if now() - greed.started >= (greed.steps + 1) * R.greedStep then
		greed.steps += 1
		addHeat(player, R.greedHeat)
		if runs[player] ~= run or not run.greed then
			return
		end
		if now() < beaconsClosedUntil then
			run.greed = nil
			run.graceUntil = 0
			notify(player, "Your greed hit Heat 100 and the beacon closed! Bonus lost. Reach another beacon when they reopen.", "bad")
			return
		end
		notify(player, ("Greed Window: +%d%% payout, Heat +5."):format(greed.steps * 15), "warn")
		if greed.steps * R.greedStep >= R.greedSeconds then
			run.greed = nil
			bank(player, greed.steps)
		end
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
			if run.heat >= Config.Heat.hazardAt and not inNest(player) then
				run.riptideTicks += 1
				local root = rootOf(player)
				if run.riptideTicks >= Config.Heat.riptideEvery and root then
					run.riptideTicks = 0
					local outward = Vector3.new(root.Position.X, 0, root.Position.Z)
					if outward.Magnitude < 1 then
						outward = Vector3.new(1, 0, 0)
					end
					local direction = CFrame.Angles(0, rng:NextNumber(-0.7, 0.7), 0):VectorToWorldSpace(outward.Unit)
					HazardEvent:FireClient(player, "Riptide", direction)
				end
			else
				run.riptideTicks = 0
			end
			if run.greed then
				greedTick(player, run)
			end
			local snatch = snatchPromptFor(player)
			if snatch then
				snatch.Enabled = snatchAllowed(player, runs[player] or run)
			end
			local data = PlayerData.get(player)
			if data then
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

-- Reef Warden: sleeps on its rock, patrols at heat 25, locks on at heat 75 ----
-- Lock-on drops after 6 s out of sight (blocked, or more than 60 studs away) until Heat falls or you steal again.

local warden = shoals:WaitForChild("ReefWarden")
local lairCFrame = warden:GetPivot()
local waypoints = shoals:WaitForChild("WardenPath"):GetChildren()
table.sort(waypoints, function(a, b)
	return a.Name < b.Name
end)
local waypointIndex = 1
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(fromPos, player, root)
	local offset = root.Position - fromPos
	if offset.Magnitude > R.lockLoseRange then
		return false
	end
	sightParams.FilterDescendantsInstances = { warden, player.Character }
	return workspace:Raycast(fromPos, offset, sightParams) == nil
end

RunService.Heartbeat:Connect(function(dt)
	local active, chaseRoot, chaseHeat = false, nil, -1
	local wardenPos = warden:GetPivot().Position
	for player, run in pairs(runs) do
		if run.heat >= Config.Heat.patrolAt and not inNest(player) then
			active = true
			local root = rootOf(player)
			if run.heat >= Config.Heat.lockAt and not run.lockDropped and root then
				if canSee(wardenPos, player, root) then
					run.unseenFor = 0
				else
					run.unseenFor += dt
					if run.unseenFor >= R.lockLoseSight then
						run.lockDropped = true
						run.unseenFor = 0
						notify(player, "You broke line of sight. The Reef Warden lost your trail!", "good")
						cue(player, "LockLost")
					end
				end
				if not run.lockDropped and run.heat > chaseHeat then
					chaseRoot, chaseHeat = root, run.heat
				end
			end
		end
	end
	if active ~= wardenActive then
		wardenActive = active
		warden:SetAttribute("Active", active)
	end

	if now() >= wardenPauseUntil then
		local goal, speed
		if chaseRoot then
			goal, speed = chaseRoot.Position, Config.Warden.chaseSpeed
		elseif active then
			goal, speed = waypoints[waypointIndex].Position, Config.Warden.patrolSpeed
			if (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(wardenPos.X, 0, wardenPos.Z)).Magnitude < 3 then
				waypointIndex = waypointIndex % #waypoints + 1
			end
		else
			goal, speed = lairCFrame.Position, Config.Warden.patrolSpeed
		end

		local delta = Vector3.new(goal.X, Config.Warden.hoverY, goal.Z) - wardenPos
		if delta.Magnitude > 0.05 then
			local newPos = wardenPos + delta.Unit * math.min(delta.Magnitude, speed * dt)
			local flat = Vector3.new(newPos.X, 0, newPos.Z)
			if flat.Magnitude < Config.World.wardenNoGoRadius then
				flat = flat.Unit * Config.World.wardenNoGoRadius
				newPos = Vector3.new(flat.X, newPos.Y, flat.Z)
			end
			local facing = Vector3.new(delta.X, 0, delta.Z)
			if facing.Magnitude > 0.01 then
				warden:PivotTo(CFrame.lookAt(newPos, newPos + facing))
			else
				warden:PivotTo(CFrame.new(newPos) * warden:GetPivot().Rotation)
			end
		end
	end

	if not active then
		return
	end
	wardenPos = warden:GetPivot().Position
	for player, run in pairs(runs) do
		if atRisk(run) and not inNest(player) then
			local root = rootOf(player)
			if root and (root.Position - wardenPos).Magnitude < Config.Warden.catchRadius then
				hit(player, wardenPos)
			end
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
		snatch.HoldDuration = Config.OpenTide.snatchHold
		snatch.MaxActivationDistance = Config.OpenTide.snatchRange
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
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	push(player)
	notify(player, "Welcome to Tidebound: Eggfall! Cast in the Sunken Shoals, steal eggs, then extract at a beacon.", "info")
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	BaseService.release(player)
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
