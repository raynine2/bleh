-- Tidebound: Eggfall wind, weather and biome particles on the client (GDD Section 8 Table B and Table C, and the
-- Wind Implementation paragraph). WindService on the server owns the weather and publishes each biome's wind; this
-- script:
--   * sets Workspace.GlobalWind locally to your biome's vector x the server's gust, so every WindAffectsDrag
--     emitter you see leans with the biome you're in (Table C vectors)
--   * keeps a box of emitters around the camera with your biome's Table C particles (rain, sea spray, leaves,
--     bubbles, sand, spores, fog, debris, plankton, ash, embers, smoke), all WindAffectsDrag with the biome's Drag,
--     inside the biome's particle budget, plus Grid2x2 flipbook wind streams (ParticleEmitter.Acceleration adds
--     local gusts on top of GlobalWind)
--   * draws weather: rain, storm lightning, aurora ribbons and bioluminescence at night, the volcanic heat pulse,
--     and flipbook kelp sway on the Kelp Forest's kelp
--   * applies the wind's gameplay effect to your own character: Volcanic Isle pushes you, the Abyssal Trench's
--     downdraft pulls swimmers down (your character's physics are yours, so the push is applied here)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Biomes = require(Shared:WaitForChild("Biomes"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))
local Vfx = require(Shared:WaitForChild("VfxLibrary"))
local Isles = require(Shared:WaitForChild("IslesLayout"))

local T = Vfx.textures
local seq = Vfx.seq
local WHITE = Color3.new(1, 1, 1)

local biomeId = Biomes.default

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Weather each biome shows for the server's global weather (a biome without rain shows clear skies, and the
-- sunken biomes never see the sky).
local function localWeather()
	local global = workspace:GetAttribute("Weather") or "Clear"
	local biome = Biomes.get(biomeId)
	if biome.underground then
		return "Clear"
	end
	if table.find(biome.weather, global) then
		return global
	end
	if global == "Storm" and table.find(biome.weather, "Rain") then
		return "Rain"
	end
	return "Clear"
end

-- Wind ------------------------------------------------------------------------------------------------------------

local windTarget = Biomes.get(biomeId).wind.vector
local windNow = windTarget
local settingWind = false

local function computeWind()
	local vector = workspace:GetAttribute("Wind_" .. biomeId)
	if typeof(vector) ~= "Vector3" then
		vector = Biomes.get(biomeId).wind.vector
	end
	return vector * (workspace:GetAttribute("WindGust") or 1)
end

-- the server sets GlobalWind on a weather change; put this client's biome wind straight back
workspace:GetPropertyChangedSignal("GlobalWind"):Connect(function()
	if not settingWind then
		settingWind = true
		workspace.GlobalWind = windNow
		settingWind = false
	end
end)

-- Camera box emitters -------------------------------------------------------------------------------------------
-- One anchored box follows the camera; each biome's emitters live on it and only the current biome's are on.
-- Rates are set so rate x lifetime (particles alive) stays inside the biome's Table C budget at full quality.

local box = Vfx.anchor(CFrame.new(0, 50, 0), nil, Vector3.new(140, 50, 140))
box.Name = "WeatherBox"
local sky = Vfx.anchor(CFrame.new(0, 300, 0), nil, Vector3.new(500, 10, 500))
sky.Name = "SkyBox"
local surface = Vfx.anchor(CFrame.new(0, Isles.WATER_Y + 0.5, 0), nil, Vector3.new(120, 1, 120))
surface.Name = "SurfaceBox"

local function windEmitter(parent, drag, props, flipbook)
	props.WindAffectsDrag = true
	props.Drag = drag
	return Vfx.emitter(parent, props, flipbook)
end

local sets = {} -- [biomeId] = { { emitter = e, rate = full rate, weather = "Rain"? } }
local function add(id, e, rate, weather)
	sets[id] = sets[id] or {}
	table.insert(sets[id], { emitter = e, rate = rate, weather = weather })
end

do
	for id, biome in pairs(Biomes.list) do
		local drag = biome.wind.drag
		local c = biome.colors
		-- Grid2x2 flipbook wind streams in every biome: one sprite plays a 4-frame swirl (Wind Implementation)
		add(id, windEmitter(box, drag, {
			Texture = T.wind, Color = ColorSequence.new(biome.underground and c.accent or WHITE), Size = seq(3, 6, 4),
			Transparency = seq(1, 0.55, 1), Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(2, 4),
			Acceleration = biome.wind.vector * 0.15, LightEmission = 0.3, Orientation = Enum.ParticleOrientation.VelocityParallel,
			FlipbookFramerate = NumberRange.new(5, 7),
		}, "Loop"), 10)
		if id == "OpenSea" then
			add(id, windEmitter(box, drag, { -- rain: thin streaks falling through the wind
				Texture = T.glow, Color = ColorSequence.new(Color3.fromRGB(200, 220, 255)), Size = NumberSequence.new(0.18),
				Squash = NumberSequence.new(-2.6), Transparency = NumberSequence.new(0.35), Lifetime = NumberRange.new(0.9, 1.1),
				Speed = NumberRange.new(70, 90), EmissionDirection = Enum.NormalId.Bottom, LightEmission = 0.2,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
			}), 900, "Rain")
			add(id, windEmitter(surface, drag, { -- sea spray off the wave tops
				Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(230, 245, 255)), Size = seq(0.6, 2.4),
				Transparency = seq(0.5, 1), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(3, 6),
				EmissionDirection = Enum.NormalId.Top, LightEmission = 0.2,
			}), 60)
			add(id, windEmitter(box, drag, { -- leaves blown off the islands
				Texture = T.sparkle, Color = ColorSequence.new(Color3.fromRGB(120, 200, 90), Color3.fromRGB(200, 220, 90)),
				Size = NumberSequence.new(0.35), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 3),
				RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(0, -1.5, 0),
				LightEmission = 0,
			}), 12)
		elseif id == "CoralReef" then
			add(id, windEmitter(box, drag, {
				Texture = T.glow, Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)), Size = seq(0.2, 0.5),
				Squash = NumberSequence.new(-2.6), Transparency = NumberSequence.new(0.4), Lifetime = NumberRange.new(0.9, 1.1),
				Speed = NumberRange.new(70, 90), EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
			}), 700, "Rain")
			add(id, windEmitter(surface, drag, { -- bubbles rising out of the reef water
				Texture = T.glow, Color = ColorSequence.new(Color3.fromRGB(180, 250, 255)), Size = seq(0.3, 0.6),
				Transparency = seq(0.3, 0.8), Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 2.5),
				EmissionDirection = Enum.NormalId.Top, LightEmission = 0.6,
			}), 40)
			add(id, windEmitter(box, drag, { -- sand drifting low
				Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(255, 230, 190)), Size = seq(0.8, 2),
				Transparency = seq(0.75, 1), Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(1, 2), LightEmission = 0,
			}), 20)
		elseif id == "KelpForest" then
			add(id, windEmitter(box, drag, { -- glowing spores
				Texture = T.glow, Color = ColorSequence.new(c.accent), Size = seq(0.2, 0.45, 0.2), Transparency = seq(0.6, 0.2, 1),
				Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.5, 1.5), LightEmission = 1,
			}), 60)
			add(id, windEmitter(box, drag, { -- low fog banks
				Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(110, 170, 130)), Size = seq(12, 22),
				Transparency = seq(1, 0.85, 1), Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.5, 1.5),
				LightEmission = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, 6),
			}), 6)
		elseif id == "AbyssalTrench" then
			add(id, windEmitter(box, drag, { -- plankton motes
				Texture = T.glow, Color = ColorSequence.new(c.accent, Color3.fromRGB(100, 150, 255)), Size = seq(0.15, 0.3, 0.1),
				Transparency = seq(0.4, 0.1, 1), Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.3, 1), LightEmission = 1,
			}), 70)
			add(id, windEmitter(box, drag, { -- sinking debris in the downdraft
				Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(40, 40, 60)), Size = seq(0.3, 0.6),
				Transparency = NumberSequence.new(0.3), Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(1, 2),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), LightEmission = 0,
			}), 40)
		elseif id == "VolcanicIsle" then
			add(id, windEmitter(box, drag, { -- ash fall
				Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(90, 85, 85)), Size = seq(0.3, 0.6),
				Transparency = seq(0.2, 0.6), Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(2, 4),
				EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), LightEmission = 0,
			}), 220)
			add(id, windEmitter(box, drag, { -- embers
				Texture = T.spark, Color = ColorSequence.new(c.accent, c.secondary), Size = seq(0.25, 0), Transparency = seq(0, 1),
				Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(3, 7), EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, 4, 0), LightEmission = 1,
			}), 160)
			add(id, windEmitter(box, drag, { -- smoke drifting through
				Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(60, 50, 50)), Size = seq(8, 18),
				Transparency = seq(1, 0.8, 1), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 2),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10), LightEmission = 0,
			}), 8)
		end
	end
end

-- Section 8 Table B night effects and the heat pulse -------------------------------------------------------------

local aurora = Vfx.emitter(sky, { -- Aurora Ribbons: Grid2x2 flipbook ribbons across the night sky
	Texture = T.aurora, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 255, 170)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 90, 255)),
	}),
	Size = seq(60, 110, 80), Transparency = seq(1, 0.35, 1), Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(1, 3),
	LightEmission = 1, Rotation = NumberRange.new(-12, 12), FlipbookFramerate = NumberRange.new(1, 2),
}, "Loop")
local biolum = Vfx.emitter(surface, { -- Bioluminescent water: cyan motes on the surface at night
	Texture = T.glow, Color = ColorSequence.new(Color3.fromRGB(0, 255, 240), Color3.fromRGB(80, 160, 255)),
	Size = seq(0, 0.5, 0), Transparency = seq(0.2, 0.6), Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(0, 0.4),
	LightEmission = 1,
})
local heat = Vfx.emitter(box, { -- Heat Pulse: rising shimmer off the volcanic ground
	Texture = T.glow, Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 191, 0)),
	Size = seq(2, 5), Transparency = seq(0.85, 1), Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(3, 6),
	EmissionDirection = Enum.NormalId.Top, LightEmission = 1,
})

-- Kelp Sway: a Grid2x2 frond flipbook on the Kelp Forest's swaying kelp (the WindShake-tagged kelp under the sea).
-- They register with the LOD tracker, so only kelp within 150 studs emits.
local kelpDone = {}
local function addKelp(part)
	if kelpDone[part] or not part:IsA("BasePart") or part.Position.Y > -150 then
		return
	end
	kelpDone[part] = true
	local e = Vfx.emitter(part, {
		Texture = T.kelp, Color = ColorSequence.new(Biomes.list.KelpForest.colors.primary, Biomes.list.KelpForest.colors.accent),
		Size = seq(3, 4, 3), Transparency = seq(1, 0.4, 1), Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(0.2, 0.6),
		LightEmission = 0.4, WindAffectsDrag = true, Drag = Biomes.list.KelpForest.wind.drag, FlipbookFramerate = NumberRange.new(2, 3),
	}, "Loop")
	Vfx.track(e, 0.5)
end
CollectionService:GetInstanceAddedSignal("WindShake"):Connect(addKelp)
for _, part in ipairs(CollectionService:GetTagged("WindShake")) do
	addKelp(part)
end

-- Applying the current biome and weather ------------------------------------------------------------------------

local function refreshEmitters()
	local q = Vfx.quality()
	local weather = localWeather()
	local biome = Biomes.get(biomeId)
	local night = biome.clock == "night"
	for id, list in pairs(sets) do
		for _, entry in ipairs(list) do
			local on = id == biomeId and (entry.weather == nil or entry.weather == weather)
			local rate = entry.rate * q * (entry.weather == "Rain" and weather == "Storm" and 1.4 or 1)
			entry.emitter.Rate = rate
			entry.emitter.Enabled = on
		end
	end
	aurora.Rate = 0.5 * q
	aurora.Enabled = night and not biome.underground
	biolum.Rate = 50 * q
	biolum.Enabled = night
	heat.Rate = 20 * q
	heat.Enabled = biomeId == "VolcanicIsle"
end

-- Wind push (Table C "Effect on gameplay") ---------------------------------------------------------------------
local PUSH = { VolcanicIsle = 0.35 } -- fraction of the wind vector applied as acceleration (horizontal)
local DOWNDRAFT = { AbyssalTrench = 0.8 } -- fraction of the downward wind applied while swimming
local force, forceAttachment = nil, nil
local function updatePush()
	local root = rootPart()
	local humanoid = root and root.Parent:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	if not force or force.Parent ~= root then
		forceAttachment = Instance.new("Attachment")
		forceAttachment.Name = "WindPush"
		forceAttachment.Parent = root
		force = Instance.new("VectorForce")
		force.Name = "WindPush"
		force.Attachment0 = forceAttachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Parent = root
	end
	local mass = root.AssemblyMass
	local accel = Vector3.zero
	if PUSH[biomeId] then
		accel += Vector3.new(windNow.X, 0, windNow.Z) * PUSH[biomeId]
	end
	if DOWNDRAFT[biomeId] and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		accel += Vector3.new(0, math.min(0, windNow.Y), 0) * DOWNDRAFT[biomeId]
	end
	force.Force = accel * mass
end

-- Main loop ------------------------------------------------------------------------------------------------------

ClientBus.signal.Event:Connect(function(kind, id)
	if kind == "biome" then
		biomeId = id
		refreshEmitters()
	elseif kind == "settings" then
		refreshEmitters()
	end
end)
workspace:GetAttributeChangedSignal("Weather"):Connect(refreshEmitters)
workspace:GetAttributeChangedSignal("LightningAt"):Connect(function()
	local at = workspace:GetAttribute("LightningPos")
	if typeof(at) == "Vector3" and localWeather() == "Storm" then
		Vfx.lightning(at)
	end
end)

biomeId = ClientBus.biome or biomeId
refreshEmitters()

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local p = camera.CFrame.Position
	box.CFrame = CFrame.new(p + Vector3.new(0, 20, 0))
	sky.CFrame = CFrame.new(p.X, math.max(p.Y + 220, 260), p.Z)
	surface.CFrame = CFrame.new(p.X, biomeId == "KelpForest" and p.Y - 4 or Isles.WATER_Y + 0.5, p.Z)
	-- ease the wind toward the target so a biome change or gust never snaps
	windTarget = computeWind()
	windNow = windNow:Lerp(windTarget, math.min(1, dt * 1.5))
	if (workspace.GlobalWind - windNow).Magnitude > 0.05 then
		settingWind = true
		workspace.GlobalWind = windNow
		settingWind = false
	end
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.2 then
		return
	end
	accumulator = 0
	if ClientBus.biome and ClientBus.biome ~= biomeId then
		biomeId = ClientBus.biome
		refreshEmitters()
	end
	updatePush()
end)
