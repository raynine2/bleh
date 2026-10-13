-- Tidebound: Eggfall loading screen. Runs from ReplicatedFirst, before anything else on the client.
-- 13 Oct 2026, second remake (HJHJH said the clean version "looks very ai"): the screen is now the game itself.
-- As soon as the world is in, the camera slowly circles the moonlit Nest plaza behind the screen, so what you see
-- while you wait is the real game, not a drawn background. The title, the bar and the DIVE IN button use the same
-- look as the HUD (UiKit.TILE: white tiles with a top/bottom gradient, a light outline, FredokaOne with a dark ink
-- stroke), so the loading screen reads like part of the game. The bar fills as the game's art and sound really
-- load (ContentProvider). DIVE IN (or a few seconds) fades it out and hands the camera back; the intro flyover
-- waits for the "Loading" attribute.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
player:SetAttribute("Loading", true)
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local IDS = {
	egg = "rbxassetid://99369591703324",
	underwater = "rbxassetid://9112889917", -- PSE underwater ambience
	splash = "rbxassetid://9117823374", -- PSE pool splash
}
-- What the loading bar waits for: the game's UI icons, VFX flipbooks, the first music and ambience.
local PRELOAD = {
	IDS.egg,
	"rbxassetid://124496090301374", "rbxassetid://104640812482656", "rbxassetid://136207976157700", "rbxassetid://80478658340493", "rbxassetid://90740689407978",
	"rbxassetid://85687393207604", "rbxassetid://112242288769077", "rbxassetid://123678832274810", "rbxassetid://113115755136893",
	"rbxassetid://120476018218464", "rbxassetid://133752124870577", "rbxassetid://117468609028579", "rbxassetid://119858810436635",
	"rbxassetid://118168912033618", "rbxassetid://136389829137353", "rbxassetid://132445039089702", "rbxassetid://113736702914864",
	"rbxassetid://72966278017118", "rbxassetid://133703177197071",
	"rbxassetid://135516216895766", "rbxassetid://129405737816125", "rbxassetid://129397562417420", "rbxassetid://81026226052666",
	"rbxassetid://91667243498952", "rbxassetid://99412514342842",
	"rbxassetid://1846078893", "rbxassetid://137826155053556",
}
local TIPS = {
	"Bank your fish at a Tide Cache. Banked Pearls can't be lost!",
	"Steal wild eggs in the Shoals, then hold at a beacon to extract.",
	"Every egg's odds are on the ODDS board. Pity never resets on a wipe.",
	"Push deeper at a beacon for more cargo... if you dare the guardian.",
	"Geysers launch you between far islands!",
	"Out at sea you can cast into any water. Hold click, let go to throw.",
	"Hit the SHAKE circles well and your reel goes faster.",
	"Daily quests reset at midnight UTC. Weekly goals reset on Monday.",
	"X swaps Fish and Fight. Every rod has its own combo!",
}

local MIN_TIME, MAX_TIME, AUTO_DIVE = 3.2, 30, 9

-- the HUD's own colours (UiKit.TILE; ReplicatedStorage isn't ready this early, so they're copied here)
local TILE = {
	gold = { top = Color3.fromRGB(255, 196, 30), bottom = Color3.fromRGB(214, 132, 8), outline = Color3.fromRGB(255, 226, 90) },
	blue = { top = Color3.fromRGB(40, 140, 255), bottom = Color3.fromRGB(18, 76, 214), outline = Color3.fromRGB(90, 210, 255) },
}
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(20, 16, 40)
local FONT = Enum.Font.FredokaOne

-- where the camera circles while you wait: the Nest plaza
local ORBIT_AT = Vector3.new(0, 16, 0)
local ORBIT_RADIUS, ORBIT_HEIGHT, ORBIT_SPEED = 120, 46, 0.045

local function new(className, props, children)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function ink(thickness)
	return new("UIStroke", { Color = INK, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

-- a HUD tile: white background under a top/bottom gradient, light outline, rounded corners
local function tile(color, props)
	local className = props.ClassName or "Frame"
	props.ClassName = nil
	props.BackgroundColor3 = WHITE
	props.BorderSizePixel = 0
	local frame = new(className, props, {
		new("UICorner", { CornerRadius = UDim.new(0, 10) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color.top, color.bottom) }),
		new("UIStroke", { Color = color.outline, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	return frame
end

-- Hide Roblox's own HUD (chat, player list, backpack) under the screen and put back exactly what was on.
local coreTypes = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health }
local coreWas = {}
for _, t in ipairs(coreTypes) do
	local ok, on = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
	coreWas[t] = ok and on
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false)
end

local gui = new("ScreenGui", { Name = "TideboundLoading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local root = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

-- the game's own HUD stays hidden behind the loading screen (the world shows through it), and comes back after
local hiddenHud = {}
local function hideHud(g)
	if g ~= gui and g:IsA("ScreenGui") and g.Enabled then
		g.Enabled = false
		hiddenHud[g] = true
	end
end
for _, g in ipairs(player.PlayerGui:GetChildren()) do
	hideHud(g)
end
local hudConn = player.PlayerGui.ChildAdded:Connect(function(g)
	task.defer(hideHud, g)
end)

-- the night sky colour until the world is in, then it fades away and the real plaza shows through
local cover = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1, Parent = root }, {
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(20, 34, 78), Color3.fromRGB(6, 10, 30)) }),
})
-- a soft dark band along the bottom so the bar and the tips stay readable over the world
new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.34), BackgroundColor3 = Color3.fromRGB(4, 8, 22), BorderSizePixel = 0, ZIndex = 2, Parent = root }, {
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) }) }),
})

-- the logo: the egg, TIDEBOUND in big HUD letters, and EGGFALL on a gold tile
local logo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.5, 0.26), BackgroundTransparency = 1, ZIndex = 5, Parent = root })
local logoEgg = new("ImageLabel", { Image = IDS.egg, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.3, 0.42), BackgroundTransparency = 1, ZIndex = 5, Parent = logo }, {
	new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
})
local title = new("TextLabel", { Text = "TIDEBOUND", Font = FONT, TextScaled = true, TextColor3 = WHITE, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(1, 0.46), Rotation = -2, ZIndex = 6, Parent = logo }, {
	ink(5),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.55, WHITE), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 220, 255)) }) }),
})
local banner = tile(TILE.gold, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.36, 0.22), Rotation = -2, ZIndex = 7, Parent = logo })
new("TextLabel", { Text = "EGGFALL", Font = FONT, TextScaled = true, TextColor3 = WHITE, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.74), ZIndex = 8, Parent = banner }, { ink(2.5) })

-- the loading bar: a dark track with a blue HUD-tile fill, the status in HUD letters above it
local barTrack = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.new(0.4, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(10, 14, 34), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 9, Parent = root }, {
	new("UICorner", { CornerRadius = UDim.new(0, 10) }),
	new("UIStroke", { Color = WHITE, Thickness = 2.5, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local barFill = tile(TILE.blue, { Size = UDim2.fromScale(0, 1), ZIndex = 10, Parent = barTrack })
barFill:FindFirstChildOfClass("UIStroke"):Destroy()
local shine = new("Frame", { Position = UDim2.new(0, 4, 0, 3), Size = UDim2.new(1, -8, 0, 4), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 11, Parent = barFill }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
})
local status = new("TextLabel", { Text = "Loading the tides...", Font = FONT, TextSize = 20, TextColor3 = WHITE, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.8, -6), Size = UDim2.new(0.4, 0, 0, 24), ZIndex = 9, Parent = root }, { ink(2) })
local tip = new("TextLabel", { Text = "", Font = FONT, TextSize = 17, TextColor3 = Color3.fromRGB(220, 236, 255), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.9, 0, 0, 22), ZIndex = 9, Parent = root }, { ink(1.8) })

-- DIVE IN: a gold HUD tile, like the DASH button
local dive = tile(TILE.gold, { ClassName = "TextButton", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1.25), Size = UDim2.fromOffset(210, 58), ZIndex = 12, Parent = root })
new("TextLabel", { Text = "DIVE IN", Font = FONT, TextScaled = true, TextColor3 = WHITE, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.62), ZIndex = 13, Parent = dive }, { ink(2.5) })
local diveScale = new("UIScale", { Parent = dive })

-- a quiet underwater bed while you wait
local bed = new("Sound", { SoundId = IDS.underwater, Volume = 0, Looped = true, Parent = SoundService })
bed:Play()
TweenService:Create(bed, TweenInfo.new(1.5), { Volume = 0.2 }):Play()

-- The camera: circle the plaza once the world is in ----------------------------------------------------------

local camera = workspace.CurrentCamera
local orbiting = false
local function startOrbit()
	if orbiting then
		return
	end
	orbiting = true
	pcall(function()
		player:RequestStreamAroundAsync(ORBIT_AT, 5)
	end)
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(cover, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	-- give the plaza a moment to arrive before showing it
	local waited = 0
	while not workspace:FindFirstChild("TideboundLobby") and waited < 6 do
		waited += task.wait(0.2)
	end
	task.wait(0.4)
	if player:GetAttribute("Loading") then
		startOrbit()
	end
end)

-- Animation ---------------------------------------------------------------------------------------------------

local started = os.clock()
local shown = 0 -- the bar's displayed progress, easing toward `progress`
local progress = 0
local animating = true
local conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - started
	if orbiting and camera then
		local a = t * ORBIT_SPEED + 2.2
		local eye = ORBIT_AT + Vector3.new(math.cos(a) * ORBIT_RADIUS, ORBIT_HEIGHT + math.sin(t * 0.2) * 4, math.sin(a) * ORBIT_RADIUS)
		camera.CFrame = CFrame.lookAt(eye, ORBIT_AT)
	end
	logoEgg.Position = UDim2.fromScale(0.5, 0.36 + math.sin(t * 1.8) * 0.03)
	logoEgg.Rotation = math.sin(t * 1.2) * 6
	logo.Rotation = math.sin(t * 0.7) * 0.8
	shown += (progress - shown) * math.min(1, dt * 4)
	barFill.Size = UDim2.fromScale(math.max(shown, 0.04), 1)
	if dive.Position.Y.Scale < 1 then
		diveScale.Scale = 1 + math.sin(t * 3) * 0.03
	end
end)

-- tips cycle every 4 s
task.spawn(function()
	local order = {}
	for i = 1, #TIPS do
		table.insert(order, i)
	end
	local rng = Random.new()
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local i = 0
	while animating do
		i = i % #order + 1
		tip.Text = TIPS[order[i]]
		tip.TextTransparency = 1
		TweenService:Create(tip, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		task.wait(4)
	end
end)

-- Loading: assets (70% of the bar), then the game itself (30%) --------------------------------------------------

local function say(text)
	status.Text = ("%s %d%%"):format(text, math.floor(progress * 100))
end

local function load()
	local total = #PRELOAD
	local done = 0
	say("Loading the tides...")
	pcall(function()
		ContentProvider:PreloadAsync(PRELOAD, function()
			done += 1
			progress = 0.7 * done / total
			say("Loading the tides...")
		end)
	end)
	progress = math.max(progress, 0.7)
	say("Filling the sea...")
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	progress = 0.8
	say("Waking the islands...")
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("Tidebound", MAX_TIME)
	local remotes = shared and shared:WaitForChild("Remotes", MAX_TIME)
	if remotes then
		remotes:WaitForChild("State", MAX_TIME)
	end
	progress = 0.9
	say("Finding your boat...")
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", MAX_TIME)
	progress = 1
	status.Text = "Ready!"
end

local loaded = false
task.spawn(function()
	load()
	loaded = true
end)
while not loaded and os.clock() - started < MAX_TIME do
	task.wait(0.1)
end
while os.clock() - started < MIN_TIME do
	task.wait(0.1)
end
progress = 1
status.Text = "Ready!"

-- Dive in -----------------------------------------------------------------------------------------------------

local diving = false
local function diveIn()
	if diving then
		return
	end
	diving = true
	local splash = new("Sound", { SoundId = IDS.splash, Volume = 0.5, Parent = SoundService })
	splash.TimePosition = 0.12
	splash:Play()
	game:GetService("Debris"):AddItem(splash, 3)
	TweenService:Create(dive, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.25) }):Play()
	TweenService:Create(bed, TweenInfo.new(0.9), { Volume = 0 }):Play()
	-- a quick fade through the night colour, the camera goes back to you, and fade into the game
	cover.BackgroundTransparency = 1
	TweenService:Create(cover, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 }):Play()
	task.wait(0.4)
	orbiting = false
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		cam.CameraSubject = humanoid
	end
	player:SetAttribute("Loading", nil)
	hudConn:Disconnect()
	for g in pairs(hiddenHud) do
		if g.Parent then
			g.Enabled = true
		end
	end
	for t, on in pairs(coreWas) do
		if on then
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, true)
		end
	end
	TweenService:Create(root, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 }):Play()
	task.wait(0.65)
	animating = false
	conn:Disconnect()
	bed:Destroy()
	gui:Destroy()
end

local DIVE_Y = 0.9
TweenService:Create(dive, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, DIVE_Y) }):Play()
TweenService:Create(tip, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 1, -4) }):Play()
dive.Activated:Connect(diveIn)
dive.MouseEnter:Connect(function()
	TweenService:Create(dive, TweenInfo.new(0.15), { Rotation = -2 }):Play()
end)
dive.MouseLeave:Connect(function()
	TweenService:Create(dive, TweenInfo.new(0.15), { Rotation = 0 }):Play()
end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space then
		diveIn()
	end
end)
task.delay(AUTO_DIVE, diveIn)
