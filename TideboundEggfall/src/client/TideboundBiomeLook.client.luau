-- Tidebound: Eggfall biome look (GDD Section 7, Section 10 "Client" rows for Atmosphere, ColorCorrection, Bloom, DOF
-- and SunRays). Applies Table A's global lighting once, then blends Table B's atmosphere and Table C's
-- post-processing to the canon biome you're in, sets the biome's clock (14:00 day, 20:00 for the bioluminescent
-- biomes) and shows a small biome title in its Table D colours. Depth of field is the underwater-immersion effect:
-- it's on while the camera is underwater, and always in the sunken biomes (Kelp Forest, Abyssal Trench).
-- Everything is local to this client; the server's Lighting stays as WorldBuilder set it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Biomes = require(Shared:WaitForChild("Biomes"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))
local UiKit = require(Shared:WaitForChild("UiKit"))

local BLEND = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local HOLD = 1 -- seconds a new biome must hold before the look changes (no flicker on a shoreline)

local function effect(className, name)
	local e = Lighting:FindFirstChild(name)
	if not e or not e:IsA(className) then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

-- Table A: global lighting (Technology is locked to Studio's Properties window; see Biomes.lighting)
local A = Biomes.lighting
Lighting.Brightness = A.Brightness
Lighting.ExposureCompensation = Biomes.exposure() -- Table A value through Biomes.calibration
Lighting.GeographicLatitude = A.GeographicLatitude
Lighting.Ambient = A.Ambient
Lighting.OutdoorAmbient = A.OutdoorAmbient
Lighting.ShadowSoftness = A.ShadowSoftness
Lighting.EnvironmentDiffuseScale = A.EnvironmentDiffuseScale
Lighting.GlobalShadows = true

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or effect("Atmosphere", "Atmosphere")
local grade = effect("ColorCorrectionEffect", "TideboundGrade")
local bloom = effect("BloomEffect", "TideboundBloom")
local rays = effect("SunRaysEffect", "TideboundSunRays")
local dof = effect("DepthOfFieldEffect", "TideboundDOF")
dof.NearIntensity = 0
dof.Enabled = false

local tweens = {}
local function blend(instance, goal)
	if tweens[instance] then
		tweens[instance]:Cancel()
	end
	tweens[instance] = TweenService:Create(instance, BLEND, goal)
	tweens[instance]:Play()
end

-- Table D title: the biome name in its primary colour with an accent-glow stroke, top centre, then it fades.
local gui = UiKit.new("ScreenGui", { Name = "TideboundBiomeTitle", ResetOnSpawn = false, DisplayOrder = 3, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })
local title = UiKit.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.new(0.6, 0, 0, 40),
	BackgroundTransparency = 1, Font = UiKit.DISPLAY, TextSize = 30, TextTransparency = 1, TextColor3 = UiKit.WHITE, Parent = gui,
})
local titleStroke = UiKit.new("UIStroke", { Thickness = 3, Transparency = 1, Parent = title })
local mood = UiKit.new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 128), Size = UDim2.new(0.6, 0, 0, 20),
	BackgroundTransparency = 1, Font = UiKit.BODY, TextSize = 15, TextTransparency = 1, TextColor3 = UiKit.WHITE, Parent = gui,
})
local moodStroke = UiKit.new("UIStroke", { Thickness = 1.5, Color = UiKit.C.ink, Transparency = 1, Parent = mood })
local titleToken = 0

local function showTitle(biome)
	titleToken += 1
	local token = titleToken
	title.Text = biome.name:upper()
	title.TextColor3 = biome.colors.primary:Lerp(UiKit.WHITE, 0.35) -- lifted so it reads on the dark world (Rule 3)
	titleStroke.Color = biome.colors.accent
	mood.Text = biome.colors.mood
	for _, inst in ipairs({ title, mood }) do
		TweenService:Create(inst, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	end
	TweenService:Create(titleStroke, TweenInfo.new(0.5), { Transparency = 0.1 }):Play()
	TweenService:Create(moodStroke, TweenInfo.new(0.5), { Transparency = 0 }):Play()
	task.delay(3, function()
		if token ~= titleToken then
			return
		end
		for _, inst in ipairs({ title, mood }) do
			TweenService:Create(inst, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		end
		TweenService:Create(titleStroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		TweenService:Create(moodStroke, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	end)
end

local current = nil
local function apply(id, instant)
	current = id
	local biome = Biomes.get(id)
	local a, p = biome.atmosphere, biome.post
	ClientBus.biome = id
	ClientBus.signal:Fire("biome", id)
	local goals = {
		[atmosphere] = { Density = a.Density, Offset = a.Offset, Color = a.Color, Decay = Biomes.decayColor(id), Glare = a.Glare, Haze = Biomes.haze(id) },
		[grade] = { Saturation = p.saturation, Contrast = p.contrast, TintColor = p.tint, Brightness = 0 },
		[bloom] = { Intensity = p.bloomIntensity, Size = p.bloomSize, Threshold = Biomes.bloomThreshold(id) },
		[rays] = { Intensity = p.sunIntensity, Spread = p.sunSpread },
		[dof] = { FocusDistance = p.focusDistance, InFocusRadius = p.inFocusRadius, FarIntensity = p.farIntensity },
		[Lighting] = { ClockTime = Biomes.clockTime(id) },
	}
	for instance, goal in pairs(goals) do
		if instant then
			for key, value in pairs(goal) do
				instance[key] = value
			end
		else
			blend(instance, goal)
		end
	end
	if not instant then
		showTitle(biome)
	end
end

local function underwater()
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local p = camera.CFrame.Position
	if p.Y > 40 then
		return false
	end
	local region = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local ok, materials = pcall(function()
		return workspace.Terrain:ReadVoxels(region, 4)
	end)
	return ok and materials[1] and materials[1][1] and materials[1][1][1] == Enum.Material.Water
end

apply(Biomes.default, true)

local pending, pendingSince = nil, 0
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.25 then
		return
	end
	accumulator = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local id = Biomes.at(root.Position)
		if id ~= current then
			if pending ~= id then
				pending, pendingSince = id, os.clock()
			elseif os.clock() - pendingSince >= HOLD then
				pending = nil
				apply(id, false)
			end
		else
			pending = nil
		end
	end
	dof.Enabled = Biomes.get(current).dofAlways == true or underwater()
end)
