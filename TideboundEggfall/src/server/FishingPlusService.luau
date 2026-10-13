-- Tidebound: Eggfall: Fishing Overhaul server (12 Oct 2026). Surges, roaming rare fish, stacked conditions,
-- rod roles and the run summary. Numbers are in ReplicatedStorage.Tidebound.FishingPlus.
-- Main calls: FishingPlusService.init(), .onCast(...) when a line goes out, .onCatch(...) when a fish lands,
-- .startRun(run) when a dive starts and .summary(run, ...) at extraction.
-- Everything here leans the rarity roll or decides which fish bites. Pearls are still worked out (and capped)
-- in Main exactly as before.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local FP = require(Shared:WaitForChild("FishingPlus"))

local Service = {}
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

-- Surge state rides on this folder's attributes, so every screen can show it.
local state = Shared:FindFirstChild("FishingPlusState") or Instance.new("Folder")
state.Name = "FishingPlusState"
state.Parent = Shared

local fx = workspace:FindFirstChild("TideboundSurges") or Instance.new("Folder")
fx.Name = "TideboundSurges"
fx.Parent = workspace

local roamFolder = workspace:FindFirstChild("TideboundRoamers") or Instance.new("Folder")
roamFolder.Name = "TideboundRoamers"
roamFolder.Parent = workspace

-- Fishing spots ----------------------------------------------------------------------------------------------

local spotsByBiome = {} -- [biome] = { BasePart }
local lastScan = -math.huge

local function scanSpots()
	if os.clock() - lastScan < 10 then
		return
	end
	lastScan = os.clock()
	local found = {}
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst:GetAttribute("Action") == "Cast" and inst:GetAttribute("Pier") ~= true then
			local part = inst.Parent
			if part and part:IsA("BasePart") then
				local biome = inst:GetAttribute("Biome") or 1
				found[biome] = found[biome] or {}
				table.insert(found[biome], part)
			end
		end
	end
	spotsByBiome = found
end

local function randomSpot(biome)
	local list = spotsByBiome[biome]
	if not list or #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

local function isNight()
	return FP.isNight(Lighting.ClockTime)
end

-- Surges -----------------------------------------------------------------------------------------------------

local surges = {} -- [biome] = { phase, endsAt, disturbance, center, model, nextPassive }

local function publish(biome)
	local s = surges[biome]
	state:SetAttribute("Phase" .. biome, s.phase)
	state:SetAttribute("Ends" .. biome, s.endsAt)
	state:SetAttribute("Disturbance" .. biome, math.floor(s.disturbance))
	state:SetAttribute("Center" .. biome, s.center or Vector3.zero)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- The look, copied from the video: a glowing green pool on the water (Brine Pool), a floating black hole with a
-- magenta swirl and light beams (Abyssal Darkness / Black Hole), yellow lightning (Lightning Swarm), falling stars.
local function buildSurgeModel(def, center)
	local model = Instance.new("Model")
	model.Name = def.name
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		for k, v in pairs(props) do
			p[k] = v
		end
		p.Parent = model
		return p
	end
	local glowColor = ColorSequence.new(def.color, def.glow)
	if def.look == "pool" then
		local pool = part({ Name = "Pool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 60, 60), CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = def.color, Transparency = 0.55 })
		part({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 66, 66), CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = def.glow, Transparency = 0.7 })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = def.color, 40, 1.5
		light.Parent = pool
		emitter(pool, { Color = glowColor, LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(1.5, 3), Rate = 35, Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Right, Shape = Enum.ParticleEmitterShape.Box, Texture = "rbxasset://textures/particles/sparkles_main.dds" })
		emitter(pool, { Color = ColorSequence.new(Color3.fromRGB(220, 255, 235)), LightEmission = 0.6, Transparency = NumberSequence.new(0.3, 1), Size = NumberSequence.new(1.2, 2.5), Lifetime = NumberRange.new(1, 2), Rate = 25, Speed = NumberRange.new(2, 5), EmissionDirection = Enum.NormalId.Right, Shape = Enum.ParticleEmitterShape.Box })
	elseif def.look == "void" then
		local orb = part({ Name = "Void", Shape = Enum.PartType.Ball, Size = Vector3.new(16, 16, 16), CFrame = CFrame.new(center + Vector3.new(0, 14, 0)), Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0) })
		local halo = part({ Name = "Halo", Shape = Enum.PartType.Ball, Size = Vector3.new(22, 22, 22), CFrame = orb.CFrame, Material = Enum.Material.Neon, Color = def.color, Transparency = 0.75 })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = def.color, 60, 4
		light.Parent = halo
		local hl = Instance.new("Highlight")
		hl.FillTransparency, hl.OutlineColor, hl.OutlineTransparency = 1, def.color, 0
		hl.Adornee = orb
		hl.Parent = orb
		emitter(halo, { Color = glowColor, LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(1, 2), Rate = 80, Speed = NumberRange.new(-14, -8), RotSpeed = NumberRange.new(-200, 200), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Texture = "rbxasset://textures/particles/sparkles_main.dds" })
		-- light beams shooting out, like the video's pink rays
		emitter(halo, { Color = glowColor, LightEmission = 1, Size = NumberSequence.new(0.6), Lifetime = NumberRange.new(0.4, 0.8), Rate = 30, Speed = NumberRange.new(40, 70), Shape = Enum.ParticleEmitterShape.Sphere, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = NumberSequence.new(-3) })
		task.spawn(function()
			while halo.Parent do
				TweenService:Create(halo, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = Vector3.new(26, 26, 26), Transparency = 0.82 }):Play()
				task.wait(1.2)
				if not halo.Parent then
					break
				end
				TweenService:Create(halo, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = Vector3.new(21, 21, 21), Transparency = 0.7 }):Play()
				task.wait(1.2)
			end
		end)
	else
		-- storm or stars: a bright beacon column with sparks raining in
		local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(center + Vector3.new(0, 18, 0)), Material = Enum.Material.Neon, Color = def.color, Transparency = 0.2 })
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = def.color, 60, 4
		light.Parent = core
		emitter(core, { Color = glowColor, LightEmission = 1, Size = NumberSequence.new(0.8, 0), Lifetime = NumberRange.new(1, 2), Rate = 50, Speed = NumberRange.new(20, 40), Shape = Enum.ParticleEmitterShape.Sphere, Acceleration = Vector3.new(0, -30, 0), Texture = "rbxasset://textures/particles/sparkles_main.dds" })
	end
	-- a tall marker so you can find it from far away
	local beam = part({ Name = "Marker", Size = Vector3.new(1.5, 120, 1.5), CFrame = CFrame.new(center + Vector3.new(0, 60, 0)), Material = Enum.Material.Neon, Color = def.color, Transparency = 0.6 })
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance = UDim2.new(0, 260, 0, 50), Vector3.new(0, 66, 0), true, 2000
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Size, label.Font, label.TextScaled = 1, UDim2.fromScale(1, 1), Enum.Font.LuckiestGuy, true
	label.Text, label.TextColor3, label.TextStrokeTransparency = def.name, def.color, 0
	label.Parent = gui
	gui.Parent = beam
	model.Parent = fx
	return model
end

local function startSurge(biome)
	local def = FP.surgeFor(biome)
	local spot = randomSpot(biome)
	local s = surges[biome]
	if not def or not spot then
		return false
	end
	s.phase, s.endsAt, s.disturbance = "active", now() + FP.Surge.duration, FP.Surge.disturbanceMax
	s.center = spot.Position
	if s.model then
		s.model:Destroy()
	end
	s.model = buildSurgeModel(def, spot.Position)
	publish(biome)
	for _, player in ipairs(Players:GetPlayers()) do
		Service.notify(player, def.text .. " Fish inside it for luck x" .. FP.Surge.luck .. " for 5 minutes.", "rare")
		Service.cue(player, "SurgeStart", { biome = biome, name = def.name })
	end
	return true
end

local function endSurge(biome)
	local s = surges[biome]
	s.phase, s.endsAt, s.disturbance = "cooldown", now() + FP.Surge.cooldown, 0
	if s.model then
		s.model:Destroy()
		s.model = nil
	end
	publish(biome)
	local def = FP.surgeFor(biome)
	for _, player in ipairs(Players:GetPlayers()) do
		Service.notify(player, ("The %s faded. It can return in 7 minutes."):format(def.name), "info")
	end
end

function Service.addDisturbance(biome, amount)
	local s = surges[biome]
	if not s or s.phase ~= "building" then
		return
	end
	s.disturbance = math.min(FP.Surge.disturbanceMax, s.disturbance + amount)
	if s.disturbance >= FP.Surge.disturbanceMax then
		if not startSurge(biome) then
			s.disturbance = FP.Surge.disturbanceMax - 1
		end
	end
	publish(biome)
end

local function surgeTick()
	scanSpots()
	local t = now()
	for biome, s in pairs(surges) do
		if s.phase == "active" and t >= s.endsAt then
			endSurge(biome)
		elseif s.phase == "cooldown" and t >= s.endsAt then
			s.phase, s.disturbance = "building", 0
			publish(biome)
		elseif s.phase == "building" and os.clock() >= s.nextPassive and spotsByBiome[biome] then
			s.nextPassive = os.clock() + FP.Surge.passiveEvery
			Service.addDisturbance(biome, 1)
		end
	end
end

local function inSurge(biome, position)
	local s = surges[biome]
	return s and s.phase == "active" and s.center and (position - s.center).Magnitude <= FP.Surge.radius
end

-- Roaming rare fish ------------------------------------------------------------------------------------------

local roamers = {} -- [Part] = { biome, tier, fish, spot }
local nextSpawn = {} -- [biome] = os.clock() when the next roamer may appear

local function rollRoamerTier(night)
	local weights = night and FP.Roamers.nightTierWeights or FP.Roamers.tierWeights
	local roll = rng:NextNumber() * 100
	for tier, w in ipairs(weights) do
		roll -= w
		if roll < 0 then
			return tier
		end
	end
	return 3
end

local function orbitPoint(spot)
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(FP.Roamers.minOrbit, FP.Roamers.maxOrbit)
	return spot.Position + Vector3.new(math.cos(angle) * r, -0.8, math.sin(angle) * r)
end

local function spawnRoamer(biome)
	local spot = randomSpot(biome)
	local b = Config.Biomes[biome]
	if not spot or not b or not b.fish then
		return
	end
	local tier = rollRoamerTier(isNight())
	local names = b.fish[tier] or b.fish[#b.fish]
	local fish = names[rng:NextInteger(1, #names)]
	-- an invisible anchor the server swims around; every screen draws the fish on it (TideboundFishingPlus)
	local p = Instance.new("Part")
	p.Name = "Roamer"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(orbitPoint(spot))
	p:SetAttribute("Tier", tier)
	p:SetAttribute("Fish", fish)
	p:SetAttribute("Biome", biome)
	p.Parent = roamFolder
	roamers[p] = { biome = biome, tier = tier, fish = fish, spot = spot }
	task.spawn(function()
		while p.Parent do
			local goal = orbitPoint(spot)
			local legTime = rng:NextNumber(FP.Roamers.swimEvery[1], FP.Roamers.swimEvery[2])
			local look = CFrame.lookAt(p.Position, Vector3.new(goal.X, p.Position.Y, goal.Z))
			p.CFrame = look
			TweenService:Create(p, TweenInfo.new(legTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = CFrame.lookAt(goal, goal + look.LookVector) }):Play()
			task.wait(legTime)
		end
	end)
end

local function roamerTick()
	local want = FP.Roamers.perBiome + (isNight() and FP.Roamers.nightExtra or 0)
	for biome, list in pairs(spotsByBiome) do
		if #list > 0 and Config.Biomes[biome] and Config.Biomes[biome].fish and os.clock() >= (nextSpawn[biome] or 0) then
			local count = 0
			for _, r in pairs(roamers) do
				if r.biome == biome then
					count += 1
				end
			end
			if count < want then
				nextSpawn[biome] = os.clock() + 3
				spawnRoamer(biome)
			end
		end
	end
end

local function hookRoamer(biome, position, radius)
	local best, bestDist
	for part, r in pairs(roamers) do
		if r.biome == biome and part.Parent then
			local d = (Vector3.new(part.Position.X, 0, part.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			if d <= radius and (not best or d < bestDist) then
				best, bestDist = part, d
			end
		end
	end
	if not best then
		return nil
	end
	local r = roamers[best]
	roamers[best] = nil
	best:Destroy()
	return r
end

-- Fishing Fight (12 Oct 2026): catch streaks. A cast that never reached onCatch (the fish got away, the line
-- snapped) ends the streak. The count rides on the player as FishStreak so the screen can cheer it.
local streaks = {} -- [Player] = { count, pending }
Players.PlayerRemoving:Connect(function(player)
	streaks[player] = nil
end)

-- Main hooks -------------------------------------------------------------------------------------------------

-- Called by Main when a line goes out (not on the Harbor pier). Returns how this cast leans:
--   luck: multiplies the rarity roll (on top of rod, bait and biome); tier/fish: a hooked roamer;
--   bite: multiplies the bite wait; info: what the screen shows ("Luck x2.3 = ...").
function Service.onCast(player, data, biomeIndex, position, rod, baitLuck, biomeLuck)
	local role = FP.role(rod.id)
	local info = { parts = {}, role = role.role }
	local luck, bite = 1, 1
	table.insert(info.parts, { "Rod", rod.luck })
	if baitLuck and baitLuck ~= 1 then
		table.insert(info.parts, { "Bait", baitLuck })
	end
	if biomeLuck and biomeLuck ~= 1 then
		table.insert(info.parts, { "Depth", biomeLuck })
	end
	if isNight() then
		luck *= FP.Night.luck
		table.insert(info.parts, { "Night", FP.Night.luck })
		info.night = true
	end
	if inSurge(biomeIndex, position) then
		local surgeLuck = role.surgeLuck or FP.Surge.luck
		luck *= surgeLuck
		table.insert(info.parts, { FP.surgeFor(biomeIndex).name, surgeLuck })
		info.surge = FP.surgeFor(biomeIndex).name
		if role.surgeBite then
			bite *= role.surgeBite
		end
	end
	local streak = streaks[player] or { count = 0, pending = false }
	streaks[player] = streak
	if streak.pending and streak.count > 0 then
		streak.count = 0
		player:SetAttribute("FishStreak", 0)
	end
	streak.pending = true
	local streakLuck = FP.streakLuck(streak.count + 1)
	if streakLuck > 1 then
		luck *= streakLuck
		table.insert(info.parts, { ("Streak %d"):format(streak.count), streakLuck })
		info.streak = streak.count
	end
	local hooked = hookRoamer(biomeIndex, position, role.hookRadius or FP.Roamers.hookRadius)
	if hooked then
		info.roamer = hooked.fish
		info.roamerTier = hooked.tier
		nextSpawn[biomeIndex] = os.clock() + FP.Roamers.respawn
	end
	local total = rod.luck * (baitLuck or 1) * (biomeLuck or 1) * luck
	info.total = math.floor(total * 100 + 0.5) / 100
	return {
		luck = luck,
		bite = bite,
		tier = hooked and hooked.tier or nil,
		fish = hooked and hooked.fish or nil,
		info = info,
	}
end

function Service.startRun(run)
	run.plus = { startedAt = now(), fish = 0, perfect = 0, best = nil, bestTier = 0, surges = {}, roamers = 0 }
end

-- Called by Main when a fish lands (not on the pier). `pearls` is what Main already worked out and capped.
function Service.onCatch(player, data, run, session, pearls, perfect)
	player:SetAttribute("FishCaught", data.stats.fishCaught)
	local rod = Config.RodsById[data.rod] or Config.Rods[1]
	local role = FP.role(rod.id)
	if not session.pier then
		Service.addDisturbance(session.biome, FP.Surge.perCatch * (role.disturbanceMult or 1))
		-- Fishing Fight: the streak grows, and it can turn up a free Brineworm
		local streak = streaks[player] or { count = 0, pending = false }
		streaks[player] = streak
		streak.pending = false
		streak.count += 1
		player:SetAttribute("FishStreak", streak.count)
		local S = FP.Streak
		local chance = math.min(S.baitMax, S.baitChance + S.baitPerStep * math.max(0, streak.count - 1))
		if data.baitInv and rng:NextNumber() < chance then
			data.baitInv[S.bait] = (data.baitInv[S.bait] or 0) + 1
			if Service.notify then
				Service.notify(player, ("Lucky! A %s was stuck to your catch. +1 bait."):format(S.bait), "good")
			end
		end
	end
	local p = run.plus
	if not p then
		return
	end
	p.fish += 1
	if perfect then
		p.perfect += 1
	end
	if session.tier >= p.bestTier then
		p.bestTier, p.best = session.tier, session.fish
	end
	if session.surge then
		p.surges[session.surge] = true
	end
	if session.roamer then
		p.roamers += 1
	end
end

-- Run summary for the screen (the video's big green money-per-hour text). `pearls` is everything this run paid.
function Service.summary(run, pearls, eggs, embers, biome)
	local p = run.plus or { startedAt = now(), fish = 0, perfect = 0, bestTier = 0, surges = {}, roamers = 0 }
	local seconds = math.max(30, now() - p.startedAt)
	local surgeNames = {}
	for name in pairs(p.surges) do
		table.insert(surgeNames, name)
	end
	return {
		pearls = pearls,
		perMinute = math.floor(pearls / (seconds / 60) + 0.5),
		seconds = math.floor(seconds),
		fish = p.fish,
		perfect = p.perfect,
		best = p.best,
		bestTier = p.bestTier,
		roamers = p.roamers,
		surges = surgeNames,
		eggs = eggs,
		embers = embers,
		biome = biome,
	}
end

function Service.init(deps)
	Service.notify = deps.notify
	Service.cue = deps.cue
	for _, def in ipairs(FP.Surges) do
		surges[def.biome] = { phase = "cooldown", endsAt = now() + FP.Surge.firstCooldown, disturbance = 0, nextPassive = 0 }
		publish(def.biome)
	end
	Players.PlayerAdded:Connect(function(player)
		task.delay(5, function()
			if player.Parent then
				for _, def in ipairs(FP.Surges) do
					local s = surges[def.biome]
					if s.phase == "active" then
						Service.notify(player, ("A %s is active right now! Look for the tall %s light."):format(def.name, def.look == "pool" and "green" or "glowing"), "rare")
					end
				end
			end
		end)
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(surgeTick)
			if not ok then
				warn("[Tidebound] FishingPlus surge tick:", err)
			end
			ok, err = pcall(roamerTick)
			if not ok then
				warn("[Tidebound] FishingPlus roamer tick:", err)
			end
			task.wait(1)
		end
	end)
end

return Service
