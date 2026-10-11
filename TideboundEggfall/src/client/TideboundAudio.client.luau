-- Tidebound: Eggfall audio director (GDD Section 9). Everything you hear that isn't a one-off cue:
--   * the mix buses (Master, Music, SFX, Ambience, UI, Voice) at the GDD's dB targets, with its ducking rules
--   * adaptive music: Calm, Menu, Hunt, Heist, Extract, Reveal, Boss and Wipe, with crossfades, beat-quantised
--     stingers, ducks and hard cuts exactly as Table A lists them
--   * the 5 biome ambience beds with their detail layers, per-biome reverb (ms) and occlusion strength
--   * the gacha stages (pre-reveal, reveal, rarity confirm), creature vocals for every guardian, weather sounds
--   * tension: a heartbeat that climbs with heat and the escape clock while the music loses its highs
-- Music state comes from what the server already tells this client (the State push and Cue events) plus what
-- other client scripts ask for through ClientBus. Nothing here can change the game; it only listens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Biomes = require(Shared:WaitForChild("Biomes"))
local Soundtrack = require(Shared:WaitForChild("Soundtrack"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))
local Audio = require(Shared:WaitForChild("Audio"))
local Remotes = Shared:WaitForChild("Remotes")

local state = nil -- the latest State push
local rng = Random.new()

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Buses --------------------------------------------------------------------------------------------------------

local buses = {} -- [name] = SoundGroup
local busBase = {} -- [name] = linear volume at the GDD target
do
	for _, spec in ipairs(Soundtrack.buses) do
		local group = SoundService:FindFirstChild("TB_" .. spec.name) or Instance.new("SoundGroup")
		group.Name = "TB_" .. spec.name
		busBase[spec.name] = Soundtrack.dbToVolume(spec.db)
		group.Volume = busBase[spec.name]
		buses[spec.name] = group
	end
	-- nested SoundGroups multiply, so Music at -12 under Master at -6 plays at -18 overall
	for _, spec in ipairs(Soundtrack.buses) do
		buses[spec.name].Parent = spec.parent and buses[spec.parent] or SoundService
	end
end
Audio.buses = buses -- Audio.play routes its cues to SFX through this

local userVolume = {
	Music = function()
		return ClientBus.settings.musicVolume
	end,
	SFX = function()
		return ClientBus.settings.sfxVolume
	end,
	Ambience = function()
		return ClientBus.settings.ambienceVolume
	end,
	UI = function()
		return ClientBus.settings.uiVolume
	end,
}

local busTweens = {}
local lastDuck = {} -- [bus] = dB currently applied
local function updateBuses(force)
	local now = os.clock()
	local depth = {} -- [bus] = deepest active duck in dB
	for rule, untilTime in pairs(ClientBus.ducks) do
		if untilTime > now then
			for bus, db in pairs(Soundtrack.ducking[rule] or {}) do
				depth[bus] = math.max(depth[bus] or 0, db)
			end
		else
			ClientBus.ducks[rule] = nil
		end
	end
	if not ClientBus.menuOpen then
		for bus, db in pairs(Soundtrack.ducking.gameplay) do
			depth[bus] = math.max(depth[bus] or 0, db)
		end
	end
	for name, group in pairs(buses) do
		local duck = depth[name] or 0
		if force or lastDuck[name] ~= duck then
			local attack = duck > (lastDuck[name] or 0)
			lastDuck[name] = duck
			local user = userVolume[name] and userVolume[name]() or 1
			local target = busBase[name] * Soundtrack.dbToVolume(-duck) * user
			if busTweens[name] then
				busTweens[name]:Cancel()
			end
			busTweens[name] = TweenService:Create(group, TweenInfo.new(attack and Soundtrack.duckAttack or Soundtrack.duckRelease), { Volume = target })
			busTweens[name]:Play()
		end
	end
end

local function newSound(spec, bus, parent, looped)
	local sound = Instance.new("Sound")
	sound.SoundId = spec.id
	sound.Volume = spec.volume or 0.6
	sound.PlaybackSpeed = spec.pitch or 1
	sound.Looped = looped == true
	sound.SoundGroup = buses[bus]
	sound.Parent = parent or buses[bus]
	return sound
end

-- One-shot on a bus. `at` is a Vector3 or a part/attachment (3D), nil plays it flat. Returns the Sound.
local function oneShot(spec, bus, at, life)
	local parent = nil
	if typeof(at) == "Vector3" then
		parent = Instance.new("Attachment")
		parent.WorldPosition = at
		parent.Parent = workspace.Terrain
		Debris:AddItem(parent, life or 8)
	elseif typeof(at) == "Instance" then
		parent = at
	end
	local sound = newSound(spec, bus, parent, false)
	sound.RollOffMaxDistance = 300
	sound:Play()
	if spec.length then
		task.delay(spec.length, function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
			end
		end)
	end
	Debris:AddItem(sound, life or 8)
	return sound
end

-- Occlusion ------------------------------------------------------------------------------------------------------
-- A world sound with something solid between it and the camera loses its highs (and a little level), as much as
-- the biome's occlusion rating says. Underwater, the whole SFX bus is muffled.

local currentBiome = Biomes.default
local occludeParams = RaycastParams.new()
occludeParams.FilterType = Enum.RaycastFilterType.Exclude
occludeParams.IgnoreWater = true

local function occlusionAmount(position)
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	local from = camera.CFrame.Position
	local offset = position - from
	if offset.Magnitude < 2 or offset.Magnitude > 400 then
		return 0
	end
	occludeParams.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(from, offset * 0.97, occludeParams)
	if not hit then
		return 0
	end
	return Biomes.occlusion[Biomes.get(currentBiome).ambience.occlusion] or 0.4
end

local function applyOcclusion(sound, amount)
	local eq = sound:FindFirstChild("Occlusion")
	if amount <= 0 then
		if eq then
			eq.Enabled = false
		end
		return
	end
	if not eq then
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "Occlusion"
		eq.Parent = sound
	end
	eq.Enabled = true
	eq.HighGain = -30 * amount
	eq.MidGain = -10 * amount
	eq.LowGain = -2 * amount
end

-- Audio.play (the cue list every client script uses) asks this for occlusion on 3D cues.
Audio.occluder = function(sound, parent)
	local position = nil
	if parent:IsA("BasePart") then
		position = parent.Position
	elseif parent:IsA("Attachment") then
		position = parent.WorldPosition
	end
	if position then
		applyOcclusion(sound, occlusionAmount(position))
	end
end

local underwaterEq = Instance.new("EqualizerSoundEffect")
underwaterEq.Name = "Underwater"
underwaterEq.HighGain = -20
underwaterEq.MidGain = -6
underwaterEq.LowGain = 2
underwaterEq.Enabled = false
underwaterEq.Parent = buses.SFX

local function cameraUnderwater()
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local p = camera.CFrame.Position
	if p.Y > 40 or p.Y < Config.Kelp.belowY then
		return false
	end
	local region = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, materials = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	return ok and materials[1] and materials[1][1] and materials[1][1][1] == Enum.Material.Water
end

-- Biome reverb on the SFX bus (ambience sits under SFX, so it reverbs too). DecayTime is the GDD's ms.
local reverb = Instance.new("ReverbSoundEffect")
reverb.Name = "BiomeReverb"
reverb.Density = 1
reverb.Diffusion = 1
reverb.DryLevel = 0
reverb.Parent = buses.SFX

local function setReverb(biomeId)
	local ms = Biomes.get(biomeId).ambience.reverbMs
	local seconds = ms / 1000
	-- longer spaces sound wetter: -18 dB wet at 0.8 s up to -8 dB at 4 s
	local wet = -18 + 10 * math.clamp((seconds - 0.8) / 3.2, 0, 1)
	TweenService:Create(reverb, TweenInfo.new(Soundtrack.ambienceFade), { DecayTime = seconds, WetLevel = wet }):Play()
end

-- Ambience -----------------------------------------------------------------------------------------------------

local beds = {} -- [biomeId] = looping Sound
local activeDetails = {} -- { sound, position }
local nextDetail = {} -- [biomeId..detail name] = os.clock()

local function bedFor(biomeId)
	if not beds[biomeId] then
		local spec = Soundtrack.ambience[biomeId].bed
		local sound = newSound(spec, "Ambience", nil, true)
		sound.Name = "Bed_" .. biomeId
		sound.Volume = 0
		beds[biomeId] = sound
	end
	return beds[biomeId]
end

local function setAmbience(biomeId)
	for id, sound in pairs(beds) do
		if id ~= biomeId then
			TweenService:Create(sound, TweenInfo.new(Soundtrack.ambienceFade), { Volume = 0 }):Play()
			task.delay(Soundtrack.ambienceFade + 0.1, function()
				if currentBiome ~= id and sound.Volume <= 0.001 then
					sound:Stop()
				end
			end)
		end
	end
	local bed = bedFor(biomeId)
	if not bed.IsPlaying then
		bed:Play()
	end
	TweenService:Create(bed, TweenInfo.new(Soundtrack.ambienceFade), { Volume = Soundtrack.ambience[biomeId].bed.volume }):Play()
	setReverb(biomeId)
end

local function tickDetails(now)
	local root = rootPart()
	if not root then
		return
	end
	local set = Soundtrack.ambience[currentBiome]
	for _, detail in ipairs(set.details) do
		local key = currentBiome .. detail.name
		if not nextDetail[key] then
			nextDetail[key] = now + rng:NextNumber(2, detail.every[2])
		elseif now >= nextDetail[key] then
			nextDetail[key] = now + rng:NextNumber(detail.every[1], detail.every[2])
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(detail.distance[1], detail.distance[2])
			local position = root.Position + Vector3.new(math.cos(angle) * distance, rng:NextNumber(detail.height[1], detail.height[2]), math.sin(angle) * distance)
			local sound = oneShot(detail, "Ambience", position, 45)
			sound.RollOffMinDistance = 20
			sound.RollOffMaxDistance = 260
			applyOcclusion(sound, occlusionAmount(position))
			table.insert(activeDetails, { sound = sound, position = position })
		end
	end
	for i = #activeDetails, 1, -1 do
		local entry = activeDetails[i]
		if not entry.sound.Parent or not entry.sound.IsPlaying then
			table.remove(activeDetails, i)
		else
			applyOcclusion(entry.sound, occlusionAmount(entry.position))
		end
	end
end

-- Music ----------------------------------------------------------------------------------------------------------

local music = { state = nil, sounds = {}, since = 0 }
local MIN_HOLD = 5 -- a lower-priority state waits this long before replacing the current one

local function stopSounds(sounds, seconds)
	for _, sound in ipairs(sounds) do
		if seconds <= 0 then
			sound:Destroy()
		else
			TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 }):Play()
			Debris:AddItem(sound, seconds + 0.1)
		end
	end
end

-- seconds until the next beat of the outgoing track, so a stinger lands on the groove (at most half a second)
local function untilBeat(old)
	local sound = old[1]
	if not sound or not sound.IsPlaying then
		return 0
	end
	local spec = Soundtrack.music[sound:GetAttribute("State")]
	if not spec then
		return 0
	end
	local beat = 60 / spec.bpm
	return math.min(0.5, beat - (sound.TimePosition % beat))
end

local function playStinger(name)
	local spec = Soundtrack.stingers[name]
	if not spec then
		return
	end
	oneShot(spec, "Music", nil, spec.length + 1)
	ClientBus.duck("swell", spec.length) -- SFX ducks 3 dB under a music swell
end

local transitionToken = 0
local function setMusic(name)
	if music.state == name then
		return
	end
	local spec = Soundtrack.music[name]
	local t = spec.transition
	transitionToken += 1
	local token = transitionToken
	local old = music.sounds
	music.state, music.sounds, music.since = name, {}, os.clock()
	local fresh = {}
	for _, track in ipairs(spec.tracks) do
		local sound = newSound(track, "Music", nil, true)
		sound.Name = "Music_" .. name
		sound:SetAttribute("State", name)
		sound.Volume = 0
		table.insert(fresh, sound)
	end
	music.sounds = fresh
	task.spawn(function()
		if t.hardCut then
			stopSounds(old, 0)
		elseif t.duck then
			for _, sound in ipairs(old) do
				TweenService:Create(sound, TweenInfo.new(0.25), { Volume = sound.Volume * 0.3 }):Play()
			end
		end
		if t.stinger then
			if not t.hardCut then
				task.wait(untilBeat(old))
			end
			if token ~= transitionToken then
				return
			end
			playStinger(t.stinger)
			if t.hardCut then
				task.wait(0.6) -- let the hit land on silence before the boss theme comes in
			end
		end
		if token ~= transitionToken then
			for _, sound in ipairs(fresh) do
				sound:Destroy()
			end
			return
		end
		local fade = t.crossfade or 0
		if not t.hardCut then
			stopSounds(old, math.max(fade, 0.05))
		end
		for i, sound in ipairs(fresh) do
			sound:Play()
			local target = spec.tracks[i].volume or 0.8
			if fade > 0 then
				TweenService:Create(sound, TweenInfo.new(fade), { Volume = target }):Play()
			else
				sound.Volume = target
			end
		end
	end)
end

local HUNT_STATES = { chase = true, tell = true, strike = true, dive = true }
local HUNT_RANGE = 70
local mobFolder = nil

local function mobsHunting(root)
	mobFolder = mobFolder or Shared:FindFirstChild("MobState")
	if not mobFolder then
		return false
	end
	for _, mob in ipairs(mobFolder:GetChildren()) do
		local pos = mob:GetAttribute("Pos")
		if HUNT_STATES[mob:GetAttribute("State")] and typeof(pos) == "Vector3" then
			local flat = Vector3.new(pos.X - root.Position.X, 0, pos.Z - root.Position.Z)
			if flat.Magnitude < HUNT_RANGE then
				return true
			end
		end
	end
	return false
end

local function wantedState()
	local root = rootPart()
	local candidates = { "Calm" }
	local function want(name)
		table.insert(candidates, name)
	end
	for name in pairs(Soundtrack.music) do
		if ClientBus.holding(name) then
			want(name)
		end
	end
	if state and root then
		local diving = state.started and not Config.safeZone(root.Position)
		if diving and (state.phase or 0) >= 1 then
			want("Boss")
		end
		if state.choice then
			want("Extract")
		end
		if diving and (state.carriedEggs or 0) > 0 then
			want("Heist")
		end
		if not Config.safeZone(root.Position) and mobsHunting(root) then
			want("Hunt")
		end
		if ClientBus.menuOpen and Config.safeZone(root.Position) then
			want("Menu")
		end
	end
	local best, bestPriority = "Calm", -1
	for _, name in ipairs(candidates) do
		local priority = Soundtrack.music[name].priority
		if priority > bestPriority then
			best, bestPriority = name, priority
		end
	end
	return best
end

local function tickMusic()
	local wanted = wantedState()
	if wanted == music.state then
		return
	end
	local current = music.state and Soundtrack.music[music.state]
	local rising = not current or Soundtrack.music[wanted].priority > current.priority
	if rising or os.clock() - music.since >= MIN_HOLD then
		setMusic(wanted)
	end
end

-- Tension --------------------------------------------------------------------------------------------------------

local heartbeat = newSound(Soundtrack.tension.heartbeat, "SFX", nil, true)
heartbeat.Name = "TensionHeartbeat"
heartbeat.Volume = 0
local highCut = Instance.new("EqualizerSoundEffect")
highCut.Name = "TensionHighCut"
highCut.Parent = buses.Music

local function tension()
	if not state or not state.started then
		return 0
	end
	local T = Soundtrack.tension
	local heat = math.clamp(((state.heat or 0) - T.startHeat) / (Config.Heat.max - T.startHeat), 0, 1)
	local clock = 0
	if state.choice then
		-- the Greed Window's 10 s countdown
		clock = math.clamp((workspace:GetServerTimeNow() - state.choice.started) / Config.Greed.choiceSeconds, 0, 1)
	end
	local closing = (state.beaconsClosedUntil or 0) - workspace:GetServerTimeNow()
	if closing > 0 then
		clock = math.max(clock, 0.6)
	end
	return math.max(heat, clock)
end

local function tickTension(dt)
	local T = Soundtrack.tension
	local t = tension()
	if t > 0.01 and not heartbeat.IsPlaying then
		heartbeat:Play()
	elseif t <= 0.01 and heartbeat.IsPlaying and heartbeat.Volume < 0.02 then
		heartbeat:Stop()
	end
	local step = math.min(1, dt * 2)
	heartbeat.Volume += ((T.heartbeat.volume * t) - heartbeat.Volume) * step
	heartbeat.PlaybackSpeed = T.minSpeed + (T.maxSpeed - T.minSpeed) * t
	highCut.HighGain += ((T.maxHighCut * t) - highCut.HighGain) * step
	highCut.MidGain = highCut.HighGain * 0.25
end

-- Gacha stages ---------------------------------------------------------------------------------------------------

local function playStage(stage, part)
	local spec = Soundtrack.gacha[stage]
	if not spec then
		return
	end
	for _, sound in ipairs(spec.sounds) do
		local s = oneShot({ id = sound.id, volume = sound.volume, length = spec.duration + 0.4 }, "SFX", part, spec.duration + 2)
		s.RollOffMaxDistance = 200
	end
	if stage == "Reveal" or stage == "RarityConfirm" then
		ClientBus.duck("important", spec.duration + 0.5) -- important SFX: the music dips 6 dB
	end
end

-- Creature vocals ------------------------------------------------------------------------------------------------

local function guardianPart(model)
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function vocal(model, kind)
	local vocalId = model:GetAttribute("Vocal") or Soundtrack.guardianVocal[model.Name]
	local set = vocalId and Soundtrack.vocals[vocalId]
	local part = guardianPart(model)
	if not set or not part then
		return
	end
	local longest = 0
	for _, layer in ipairs(set[kind] or {}) do
		local sound = oneShot(layer, "Voice", part, 10)
		sound.RollOffMinDistance = 25
		sound.RollOffMaxDistance = 500
		applyOcclusion(sound, occlusionAmount(part.Position))
		longest = math.max(longest, kind == "roar" and 3 or 1.2)
	end
	ClientBus.duck("voice", longest) -- Voice ducks Music and SFX 4 dB while it speaks
	if kind == "roar" then
		ClientBus.duck("important", longest) -- and a roar is important: Music goes 6 dB down
	end
end

local guardians = {} -- [Model] = { nextIdle = os.clock() }
local function watchGuardian(model)
	if guardians[model] then
		return
	end
	guardians[model] = { nextIdle = os.clock() + rng:NextNumber(10, 20) }
	model:GetAttributeChangedSignal("WokeAt"):Connect(function()
		vocal(model, "roar")
	end)
	model:GetAttributeChangedSignal("TellAt"):Connect(function()
		vocal(model, "call")
	end)
end
CollectionService:GetInstanceAddedSignal("TideboundGuardian"):Connect(watchGuardian)
CollectionService:GetInstanceRemovedSignal("TideboundGuardian"):Connect(function(model)
	guardians[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("TideboundGuardian")) do
	watchGuardian(model)
end

local function tickGuardianIdle(now)
	local root = rootPart()
	if not root then
		return
	end
	for model, info in pairs(guardians) do
		local part = guardianPart(model)
		if part and now >= info.nextIdle then
			info.nextIdle = now + rng:NextNumber(12, 25)
			if model:GetAttribute("Active") and (part.Position - root.Position).Magnitude < Soundtrack.idleCallRange then
				vocal(model, "idle")
			end
		end
	end
end

-- Weather --------------------------------------------------------------------------------------------------------

local rain = newSound(Soundtrack.weather.Rain, "Ambience", nil, true)
rain.Name = "WeatherRain"
rain.Volume = 0

local function tickWeather()
	local weather = workspace:GetAttribute("Weather") or "Clear"
	local biome = Biomes.get(currentBiome)
	local wet = (weather == "Rain" or weather == "Storm") and not biome.underground
	local target = wet and Soundtrack.weather.Rain.volume * (weather == "Storm" and 1.4 or 1) or 0
	if target > 0 and not rain.IsPlaying then
		rain:Play()
	end
	rain.Volume += (target - rain.Volume) * 0.15
	if target == 0 and rain.Volume < 0.01 and rain.IsPlaying then
		rain:Stop()
	end
end

workspace:GetAttributeChangedSignal("LightningAt"):Connect(function()
	local at = workspace:GetAttribute("LightningPos")
	local camera = workspace.CurrentCamera
	if typeof(at) ~= "Vector3" or not camera or Biomes.get(currentBiome).underground then
		return
	end
	local distance = (at - camera.CFrame.Position).Magnitude
	task.delay(math.clamp(distance / 1200, 0, 3), function() -- sound is slower than light
		local spec = distance < 250 and Soundtrack.weather.ThunderClose or Soundtrack.weather.Thunder
		oneShot(spec, "SFX", nil, 10)
	end)
end)

-- Inputs ---------------------------------------------------------------------------------------------------------

Remotes:WaitForChild("State").OnClientEvent:Connect(function(newState)
	state = newState
end)

Remotes:WaitForChild("Cue").OnClientEvent:Connect(function(name, payload)
	if name == "Down" then
		ClientBus.hold("Wipe", 6)
	elseif name == "Greed" or name == "Extract" then
		ClientBus.hold("Extract", name == "Extract" and 9 or 12)
	elseif name == "Steal" then
		ClientBus.hold("Heist", 20)
	elseif name == "Hit" then
		ClientBus.hold("Hunt", 8)
	elseif name == "Cutscene" and type(payload) == "table" and payload.kind == "Wake" then
		ClientBus.hold("Boss", 20)
	end
end)

ClientBus.signal.Event:Connect(function(kind, a, b)
	if kind == "gacha" then
		playStage(a, b)
	elseif kind == "settings" then
		updateBuses(true)
	elseif kind == "menu" or kind == "duck" then
		updateBuses(false)
	elseif kind == "ui" then
		local spec = Soundtrack.ui[a]
		if spec then
			oneShot(spec, "UI", nil, 3)
		end
	end
end)

-- Main loop ------------------------------------------------------------------------------------------------------

local pendingBiome, pendingSince = nil, 0
setAmbience(currentBiome)
setMusic("Calm")
updateBuses(true)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	tickTension(dt)
	accumulator += dt
	if accumulator < 0.25 then
		return
	end
	accumulator = 0
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local root = rootPart()
	local focus = root and root.Position or (camera and camera.Focus.Position)
	if focus then
		-- a new biome has to hold for a second, so a shoreline doesn't flicker between two beds
		local biome = Biomes.at(focus)
		if biome ~= currentBiome then
			if pendingBiome ~= biome then
				pendingBiome, pendingSince = biome, now
			elseif now - pendingSince >= 1 then
				currentBiome = biome
				pendingBiome = nil
				setAmbience(biome)
			end
		else
			pendingBiome = nil
		end
	end
	underwaterEq.Enabled = cameraUnderwater()
	tickMusic()
	tickDetails(now)
	tickGuardianIdle(now)
	tickWeather()
	updateBuses(false)
end)
