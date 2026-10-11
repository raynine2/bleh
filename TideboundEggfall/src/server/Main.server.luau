-- Tidebound: Eggfall server: fishing sessions, egg stealing, heat, Reef Warden, extraction, gacha.
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

local world = WorldBuilder.build()
local shoals = world:WaitForChild("SunkenShoals")

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

local rng = Random.new()
local runs = {} -- [Player] = run state: heat and the haul at risk; lost on wipe, never saved
local beaconsClosedUntil = 0
local wardenActive = false

local function newRun()
	return { heat = 0, carriedPearls = 0, carriedEggs = 0, carriedFish = 0, lastGain = 0, decayTicks = 0, riptideTicks = 0, incomeCarry = 0, session = nil }
end

local function notify(player, message, kind)
	NotifyEvent:FireClient(player, message, kind or "info")
end

local function notifyAll(message, kind)
	NotifyEvent:FireAllClients(message, kind or "info")
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
	return Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude <= Config.World.nestRadius
end

local function atRisk(run)
	return run.heat > 0 or run.carriedPearls > 0 or run.carriedEggs > 0
end

local function incomePerMinute(data)
	local values = {}
	for _, creature in ipairs(data.aquarium) do
		table.insert(values, creature.v)
	end
	table.sort(values, function(a, b)
		return a > b
	end)
	local total = 0
	for i = 1, math.min(#values, Config.Aquarium.capacity) do
		total += values[i]
	end
	return total / Config.Aquarium.incomeDivisor
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
		incomePerMin = incomePerMinute(data),
		heat = run.heat,
		carriedPearls = run.carriedPearls,
		carriedEggs = run.carriedEggs,
		carriedFish = run.carriedFish,
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

-- Heat ----------------------------------------------------------------------

local function setBeaconsOpen(open)
	for _, inst in ipairs(world:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst:GetAttribute("Action") == "Extract" then
			inst.Enabled = open
			local beacon = inst.Parent
			beacon.Color = open and Config.World.beaconOpenColor or Config.World.beaconClosedColor
			local glow = beacon:FindFirstChildOfClass("PointLight")
			if glow then
				glow.Color = beacon.Color
			end
		end
	end
end

local function closeBeacons()
	beaconsClosedUntil = workspace:GetServerTimeNow() + Config.Heat.beaconCloseSeconds
	setBeaconsOpen(false)
	notifyAll("Heat 100: every extraction beacon is closed for 30 seconds!", "bad")
	task.delay(Config.Heat.beaconCloseSeconds, function()
		if workspace:GetServerTimeNow() >= beaconsClosedUntil - 0.1 then
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
		data.pearls += keptPearls
	end
	notify(player, ("%s You kept %d Pearls of fish and lost %d Pearls and %d egg(s)."):format(reason, keptPearls, lostPearls, lostEggs), "bad")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		character:PivotTo(Config.World.spawnCFrame)
	end
	push(player)
end

-- World actions (ProximityPrompts) -------------------------------------------

local function onCast(player)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	if run.session and os.clock() - run.session.started < 60 then
		notify(player, "You're already reeling.", "info")
		return
	end
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	local bait = nil
	if data.bait ~= "" and (data.baitInv[data.bait] or 0) > 0 then
		bait = Config.BaitById[data.bait]
		data.baitInv[data.bait] -= 1
	end
	local luck = rod.luck * (bait and bait.luck or 1)
	local tierIndex = Gacha.rollFishTier(luck, rng)
	local names = Config.Biomes[1].fish[tierIndex]
	local fish = names[rng:NextInteger(1, #names)]
	local biteWait = rng:NextNumber(Config.Fishing.biteMin, Config.Fishing.biteMax) / rod.lureSpeed
	run.session = {
		id = HttpService:GenerateGUID(false),
		tier = tierIndex,
		fish = fish,
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
	})
	push(player)
end

local function onSteal(player, prompt)
	local run = runs[player]
	local egg = prompt.Parent
	if not run or egg:GetAttribute("Taken") then
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
	run.carriedEggs += 1
	addHeat(player, Config.Heat.perSteal)
	notify(player, "You stole a Tide Egg! +8 heat. Extract at a beacon to keep it.", "good")
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

local function onExtract(player)
	local run, data = runs[player], PlayerData.get(player)
	if not run or not data then
		return
	end
	if workspace:GetServerTimeNow() < beaconsClosedUntil then
		notify(player, "The beacons are closed. Survive until they reopen.", "bad")
		return
	end
	local session = run.session
	if run.carriedPearls == 0 and run.carriedEggs == 0 then
		runs[player] = newRun()
		runs[player].session = session
		notify(player, "Nothing to bank yet. Catch fish or steal eggs in the Shoals first.", "info")
		push(player)
		return
	end
	local x = Config.Extraction
	local embers = math.clamp(x.baseEmbers + run.carriedEggs * x.embersPerEgg + math.floor(run.carriedPearls / x.pearlsPerEmber), x.minEmbers, x.maxEmbers)
	data.pearls += run.carriedPearls
	data.eggs += run.carriedEggs
	data.embers += embers
	data.stats.extractions += 1
	notify(player, ("Extracted! Banked %d Pearls, %d Tide Egg(s) and %d Run Embers."):format(run.carriedPearls, run.carriedEggs, embers), "good")
	runs[player] = newRun()
	runs[player].session = session
	push(player)
end

local function onPrompt(prompt, player)
	if not prompt:IsDescendantOf(world) then
		return
	end
	local action = prompt:GetAttribute("Action")
	if action == "Cast" then
		onCast(player)
	elseif action == "Steal" then
		onSteal(player, prompt)
	elseif action == "Extract" then
		onExtract(player)
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

function handlers.FinishCast(player, data, run, id, success, perfect)
	local session = run.session
	if not session or session.id ~= id then
		return { error = "That cast already ended." }
	end
	run.session = nil
	local elapsed = os.clock() - session.started
	if elapsed < session.minTime or elapsed > 90 then
		return { error = "The line snapped." }
	end
	if success ~= true then
		notify(player, ("The %s got away."):format(session.fish), "info")
		return { ok = true, caught = false }
	end
	local tier = Config.Tiers[session.tier]
	local pearls = tier.fishPearls
	if perfect == true then
		pearls = math.floor(pearls * Config.Fishing.perfectBonus)
	end
	run.carriedPearls += pearls
	run.carriedFish += 1
	data.stats.fishCaught += 1
	data.bestiary[session.fish] = true
	addHeat(player, Config.Heat.perFish)
	notify(player, ("%s %s (%s): +%d Pearls at risk."):format(perfect == true and "Perfect catch!" or "Caught", session.fish, tier.id, pearls), session.tier >= 4 and "rare" or "good")
	return { ok = true, caught = true, fish = session.fish, tier = session.tier, pearls = pearls }
end

function handlers.BuyEgg(player, data)
	local cost = Config.Eggs.TideEgg.pearlCost
	if data.pearls < cost then
		return { error = ("A Tide Egg costs %d Pearls. Stealing one in the Shoals is free."):format(cost) }
	end
	data.pearls -= cost
	data.eggs += 1
	return { ok = true }
end

function handlers.Hatch(player, data)
	if data.eggs < 1 then
		return { error = "No Tide Eggs. Steal one in the Sunken Shoals or buy one at the shrine." }
	end
	if not inNest(player) then
		return { error = "Hatch at the Incubator in your nest." }
	end
	data.eggs -= 1
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
	if #data.aquarium > Config.Aquarium.maxStored then
		table.sort(data.aquarium, function(a, b)
			return a.v > b.v
		end)
		table.remove(data.aquarium)
	end
	table.insert(data.history, 1, { tier = tierIndex, creature = creature, mutation = mutation.id, value = value, pity = pityKey ~= nil })
	while #data.history > 10 do
		table.remove(data.history)
	end
	data.stats.hatched += 1
	if tierIndex >= 5 then
		local prefix = mutation.id ~= "None" and (mutation.id .. " ") or ""
		notifyAll(("%s hatched a %s%s %s!"):format(player.DisplayName, prefix, tier.id, creature), "rare")
	end
	return {
		ok = true,
		result = { tier = tierIndex, creature = creature, mutation = mutation.id, value = value, shards = shards, isNew = isNew, pity = pityKey },
	}
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

-- Heat decay, riptide hazard and aquarium income: once per second -----------

task.spawn(function()
	while true do
		task.wait(1)
		for player, run in pairs(runs) do
			if run.heat > 0 and os.clock() - run.lastGain >= Config.Heat.decayInterval then
				run.decayTicks += 1
				if run.decayTicks >= Config.Heat.decayInterval then
					run.decayTicks = 0
					run.heat -= 1
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
			local data = PlayerData.get(player)
			if data then
				run.incomeCarry += incomePerMinute(data) / 60
				local whole = math.floor(run.incomeCarry)
				if whole > 0 then
					data.pearls += whole
					run.incomeCarry -= whole
				end
			end
			push(player)
		end
	end
end)

-- Reef Warden: sleeps on its rock, patrols at heat 25, locks on at heat 75 ----

local warden = shoals:WaitForChild("ReefWarden")
local lairCFrame = warden:GetPivot()
local waypoints = shoals:WaitForChild("WardenPath"):GetChildren()
table.sort(waypoints, function(a, b)
	return a.Name < b.Name
end)
local waypointIndex = 1

RunService.Heartbeat:Connect(function(dt)
	local active, chaseRoot, chaseHeat = false, nil, -1
	for player, run in pairs(runs) do
		if run.heat >= Config.Heat.patrolAt and not inNest(player) then
			active = true
			if run.heat >= Config.Heat.lockAt and run.heat > chaseHeat then
				local root = rootOf(player)
				if root then
					chaseRoot, chaseHeat = root, run.heat
				end
			end
		end
	end
	if active ~= wardenActive then
		wardenActive = active
		warden:SetAttribute("Active", active)
	end

	local pos = warden:GetPivot().Position
	local goal, speed
	if chaseRoot then
		goal, speed = chaseRoot.Position, Config.Warden.chaseSpeed
	elseif active then
		goal, speed = waypoints[waypointIndex].Position, Config.Warden.patrolSpeed
		if (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < 3 then
			waypointIndex = waypointIndex % #waypoints + 1
		end
	else
		goal, speed = lairCFrame.Position, Config.Warden.patrolSpeed
	end

	local delta = Vector3.new(goal.X, Config.Warden.hoverY, goal.Z) - pos
	if delta.Magnitude > 0.05 then
		local newPos = pos + delta.Unit * math.min(delta.Magnitude, speed * dt)
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

	if not active then
		return
	end
	local wardenPos = warden:GetPivot().Position
	for player, run in pairs(runs) do
		if atRisk(run) and not inNest(player) then
			local root = rootOf(player)
			if root and (root.Position - wardenPos).Magnitude < Config.Warden.catchRadius then
				wipe(player, "The Reef Warden caught you!")
			end
		end
	end
end)

-- Player lifecycle ---------------------------------------------------------------

local function onPlayerAdded(player)
	PlayerData.load(player)
	runs[player] = newRun()

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
	PlayerData.release(player)
	runs[player] = nil
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
