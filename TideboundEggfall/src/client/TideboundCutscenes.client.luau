-- Tidebound: Eggfall: cutscenes (Big Update). Short camera moments that make the big beats feel good:
--   Intro      your first time in: a flyover of the Shoals, the Reef Warden's rock and the Maelstrom
--   Dive       you hit the water off the dock; "SUNKEN SHOALS" card
--   Wake       a guardian wakes: the camera shows it rising (it can't hurt you while this plays)
--   Descent    the Maelstrom swallows you; you land in Kelp Cathedral; "KELP CATHEDRAL" card
--   Ascend     the current carries you back up to the Shoals
--   Extracted  a column of light lifts you out, you land in the Nest, the tally counts up
--   Wiped      you go down, the camera pulls away, you wake up in the Nest
-- The server sends each one as a "Cutscene" cue and moves you at fixed times (Config.Cutscene); this script
-- only films it. Every cutscene can be skipped once you've arrived, and one never starts on top of another
-- or over a fish reveal. While one plays, your controls and the HUD are off and MotionBus.cutscene is set.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))
local Isles = require(Shared:WaitForChild("IslesLayout"))
local Remotes = Shared:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request")
local StateEvent = Remotes:WaitForChild("State")
local CueEvent = Remotes:WaitForChild("Cue")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local CUT = Config.Cutscene

local DISPLAY = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 210, 70)
local RED = Color3.fromRGB(255, 70, 70)
local SHOALS = Color3.fromRGB(120, 220, 255)
local KELP = Color3.fromRGB(110, 255, 200)

-- Your controls go off while a cutscene plays. The classic PlayerModule has GetControls(); Studio's newer
-- PlayerModule doesn't, and then WalkSpeed 0 (TideboundClient) and no jumping hold you still instead.
local controls = nil
local function getControls()
	if controls == nil then
		controls = false
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			local ok, api = pcall(require, module)
			if ok and type(api) == "table" and type(api.GetControls) == "function" then
				local got, result = pcall(api.GetControls, api)
				controls = got and result or false
			end
		end
	end
	return controls or nil
end

local function holdStill(still)
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not still)
	end
	local found = getControls()
	if found then
		pcall(still and found.Disable or found.Enable, found)
	end
end

-- UI ------------------------------------------------------------------------------------------------------------

local function new(className, props, children)
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		inst[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local gui = new("ScreenGui", { Name = "TideboundCutscene", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
local fade = new("Frame", { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = gui })
local topBar = new("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 10, Parent = gui })
local bottomBar = new("Frame", { Name = "BottomBar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 10, Parent = gui })
local subtitle = new("TextLabel", {
	Name = "Subtitle",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.8, 0, 0.6, 0),
	BackgroundTransparency = 1,
	Font = BODY,
	TextScaled = true,
	TextColor3 = WHITE,
	TextTransparency = 1,
	Text = "",
	ZIndex = 11,
	Parent = bottomBar,
}, { new("UITextSizeConstraint", { MaxTextSize = 26 }) })
local skipButton = new("TextButton", {
	Name = "Skip",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.new(0, 96, 0, 34),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
	BackgroundTransparency = 0.2,
	Font = DISPLAY,
	TextSize = 18,
	TextColor3 = WHITE,
	Text = "SKIP  ▶",
	Visible = false,
	ZIndex = 12,
	Parent = bottomBar,
}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }), new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.4 }) })

-- the big title card (an area name, "WIPED OUT", a guardian waking)
local card = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.9, 0, 0, 150), BackgroundTransparency = 1, Visible = false, ZIndex = 15, Parent = gui })
local cardScale = new("UIScale", { Parent = card })
local function cardText(props)
	props.BackgroundTransparency = 1
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextStrokeTransparency = 0
	props.TextStrokeColor3 = Color3.fromRGB(20, 12, 16)
	props.ZIndex = 16
	props.Parent = card
	return new("TextLabel", props)
end
local kicker = cardText({ Name = "Kicker", Font = DISPLAY, Size = UDim2.new(1, 0, 0, 26), TextColor3 = GOLD })
local title = cardText({ Name = "Title", Font = DISPLAY, Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 74) })
local titleStroke = new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(20, 12, 16), Parent = title })
local info = cardText({ Name = "Info", Font = BODY, Position = UDim2.new(0, 0, 0, 106), Size = UDim2.new(1, 0, 0, 24), TextColor3 = Color3.fromRGB(235, 235, 240) })
local rule = new("Frame", { Name = "Rule", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102), Size = UDim2.new(0, 0, 0, 3), BorderSizePixel = 0, BackgroundColor3 = GOLD, ZIndex = 16, Parent = card })
new("UISizeConstraint", { MaxSize = Vector2.new(820, 150), Parent = card })

-- the extraction tally
local tally = new("Frame", {
	Name = "Tally",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0, 340, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(16, 10, 6),
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 15,
	Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 10) }),
	new("UIStroke", { Color = GOLD, Thickness = 3 }),
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local grade = Lighting:FindFirstChild("TideboundCutsceneGrade") or new("ColorCorrectionEffect", { Name = "TideboundCutsceneGrade", Enabled = false, Parent = Lighting })

-- State --------------------------------------------------------------------------------------------------------

local camera = workspace.CurrentCamera
local playing = false
local canSkip, skipped = false, false
local queue = {}
local saved = {}

local function character()
	return player.Character
end

local function rootPart()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function trySkip()
	if playing and canSkip then
		skipped = true
	end
end
skipButton.Activated:Connect(trySkip)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonB then
		trySkip()
	end
end)

local function allowSkip(on)
	canSkip = on
	skipButton.Visible = on
end

-- films with `shot(alpha, t)` (alpha 0..1 eased) for `seconds`
local function film(seconds, shot, easing)
	local start = os.clock()
	while true do
		local t = os.clock() - start
		local s = math.clamp(t / seconds, 0, 1)
		local alpha = TweenService:GetValue(s, easing or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local ok, frame = pcall(shot, alpha, t)
		if ok and typeof(frame) == "CFrame" then
			camera.CFrame = frame
		end
		if s >= 1 or skipped then
			return not skipped
		end
		RunService.RenderStepped:Wait()
	end
end

local function fadeTo(transparency, seconds, color)
	fade.BackgroundColor3 = color or BLACK
	if seconds <= 0 then
		fade.BackgroundTransparency = transparency
		return
	end
	TweenService:Create(fade, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { BackgroundTransparency = transparency }):Play()
end

local function say(text)
	subtitle.Text = text or ""
	subtitle.TextTransparency = 1
	if text and text ~= "" then
		TweenService:Create(subtitle, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	end
end

local cardToken = 0
-- the big title card: kicker (small, coloured), title (huge), info line; hides itself after `seconds`
local function showCard(kickerText, titleText, infoText, color, seconds)
	cardToken += 1
	local token = cardToken
	kicker.Text = kickerText or ""
	kicker.TextColor3 = color or GOLD
	title.Text = titleText or ""
	title.TextColor3 = WHITE
	titleStroke.Color = (color or GOLD):Lerp(BLACK, 0.55)
	info.Text = infoText or ""
	rule.BackgroundColor3 = color or GOLD
	rule.Size = UDim2.new(0, 0, 0, 3)
	for _, label in ipairs({ kicker, title, info }) do
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0
	end
	card.Visible = true
	cardScale.Scale = 1.35
	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(rule, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0.6, 0, 0, 3) }):Play()
	Audio.play("Sting")
	task.delay(seconds or 2.5, function()
		if token ~= cardToken then
			return
		end
		for _, label in ipairs({ kicker, title, info }) do
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		TweenService:Create(rule, TweenInfo.new(0.4), { Size = UDim2.new(0, 0, 0, 3) }):Play()
		task.wait(0.45)
		if token == cardToken then
			card.Visible = false
		end
	end)
end

-- bubbles rush up the screen (the Maelstrom, the current)
local function bubbles(count, seconds, upward)
	for _ = 1, count do
		local size = math.random(8, 34)
		local x = math.random()
		local b = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, upward and 1.1 or -0.1, 0),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Color3.fromRGB(210, 250, 255),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 18,
			Parent = gui,
		}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.3 }) })
		local t = seconds * (0.5 + math.random() * 0.6)
		TweenService:Create(b, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, math.random() * seconds * 0.4), {
			Position = UDim2.new(x + (math.random() - 0.5) * 0.15, 0, upward and -0.1 or 1.1, 0),
			BackgroundTransparency = 0.9,
		}):Play()
		task.delay(seconds * 1.5, b.Destroy, b)
	end
end

local function begin(skippable)
	playing, skipped = true, false
	allowSkip(skippable)
	MotionBus.cutscene = true
	camera = workspace.CurrentCamera
	local hud = playerGui:FindFirstChild("TideboundUI")
	saved.hud = hud
	if hud then
		hud.Enabled = false
	end
	holdStill(true)
	pcall(function()
		ProximityPromptService.Enabled = false
	end)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(topBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
end

local function finish()
	allowSkip(false)
	say("")
	TweenService:Create(topBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	camera = workspace.CurrentCamera
	local root = rootPart()
	if root then
		-- hand the camera back from just behind you, so it doesn't snap
		camera.CFrame = CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
	end
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
	holdStill(false)
	pcall(function()
		ProximityPromptService.Enabled = true
	end)
	if saved.hud and saved.hud.Parent then
		saved.hud.Enabled = true
	end
	grade.Enabled = false
	MotionBus.cutscene = false
	playing = false
end

-- waits until `test(root)` passes (the server moved you) or `timeout` runs out
local function arrive(test, timeout)
	local untilTime = os.clock() + (timeout or 5)
	while os.clock() < untilTime do
		local root = rootPart()
		if root and test(root) then
			return root
		end
		RunService.RenderStepped:Wait()
	end
	return rootPart()
end

local function behind(root, back, up)
	return CFrame.lookAt(root.Position - root.CFrame.LookVector * back + Vector3.new(0, up, 0), root.Position + root.CFrame.LookVector * 6 + Vector3.new(0, 1.5, 0))
end

local function atSpawn(root)
	return (root.Position - Config.World.spawnCFrame.Position).Magnitude < 40
end

-- Cutscenes ----------------------------------------------------------------------------------------------------

local scenes = {}

function scenes.Intro()
	begin(true)
	fadeTo(0, 0)
	-- Patch 10: the camera tours the Open Isles: the town, the islands, the Warden's Rock and the Maelstrom
	local warden, whirl, gate = Isles.wardenLair, Isles.maelstrom, Isles.Town.tidegate
	pcall(player.RequestStreamAroundAsync, player, Vector3.new(40, 6, 0), 2)
	task.spawn(function()
		for _, at in ipairs({ Vector3.new(500, 6, 0), Vector3.new(warden.X, 6, warden.Z), Vector3.new(whirl.X, 6, whirl.Z) }) do
			pcall(player.RequestStreamAroundAsync, player, at, 2)
		end
	end)
	fadeTo(1, 1.2)
	showCard("WELCOME TO", "TIDEBOUND: EGGFALL", "Steal eggs. Catch fish. Get out alive.", GOLD, 3.2)
	say("Eggfall Town is safe. Everything past the Tidegate is not.")
	local ok = film(4.5, function(a)
		local from = Vector3.new(-120, 90, -150):Lerp(Vector3.new(60, 60, 110), a)
		return CFrame.lookAt(from, Vector3.new(gate.X - 40, 10, gate.Z))
	end)
	if ok then
		say("The tide brought strange eggs to the 22 islands of the Sunken Shoals...")
		ok = film(4.5, function(a)
			local from = Vector3.new(230, 70, -60):Lerp(Vector3.new(420, 46, 40), a)
			return CFrame.lookAt(from, Vector3.new(660, 0, 0))
		end)
	end
	if ok then
		say("...and the Reef Warden guards every last one of them.")
		ok = film(3.6, function(a)
			local from = Vector3.new(warden.X - 55, 30, warden.Z - 40):Lerp(Vector3.new(warden.X - 30, 18, warden.Z - 16), a)
			return CFrame.lookAt(from, Vector3.new(warden.X, 10, warden.Z))
		end)
	end
	if ok then
		say("Push deeper through the Maelstrom, and Kelp Cathedral waits below.")
		ok = film(3.6, function(a)
			local from = Vector3.new(whirl.X - 45, 44, whirl.Z + 70):Lerp(Vector3.new(whirl.X - 30, 26, whirl.Z + 40), a)
			return CFrame.lookAt(from, Vector3.new(whirl.X, 2, whirl.Z))
		end)
	end
	local root = rootPart()
	if ok and root then
		say("Bank your catch, reach a beacon, and bring the eggs home.")
		local center = root.Position + Vector3.new(0, 2, 0)
		local look = root.CFrame.LookVector
		ok = film(3.4, function(a)
			local angle = math.pi * (1 - a)
			local offset = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angle):VectorToWorldSpace(-look) * (14 - a * 2)
			return CFrame.lookAt(center + offset + Vector3.new(0, 6 - a * 2, 0), center)
		end)
	end
	finish()
	task.spawn(function()
		pcall(Request.InvokeServer, Request, "IntroSeen")
	end)
end

function scenes.Dive(payload)
	begin(true)
	local root = rootPart()
	if not root then
		finish()
		return
	end
	Audio.play("Plunge", root)
	Fx.ring(root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(200, 250, 255), 8, 0.6, 0.3)
	Fx.cubes(root.Position - Vector3.new(0, 2, 0), { Color3.fromRGB(120, 220, 255), WHITE }, { spread = 7, size = 0.7, life = 0.7, up = 1, count = 16 })
	local mode = payload.mode == "Crew" and "CREW DIVE" or "SOLO DIVE"
	showCard(("%s · DEPTH 1"):format(mode), (payload.name or "Sunken Shoals"):upper(), ("Guardian: %s  ·  Hazard: %s"):format(payload.guardian or "Reef Warden", payload.hazard or "Riptide pull"), SHOALS, 3)
	local start = root.Position + Vector3.new(-30, 42, 0)
	film(CUT.diveSeconds, function(a)
		local r = rootPart() or root
		local goal = behind(r, 12, 5)
		return CFrame.lookAt(start, root.Position + root.CFrame.LookVector * 60 - Vector3.new(0, 8, 0)):Lerp(goal, a)
	end)
	finish()
end

function scenes.Wake(payload)
	local c = character()
	local fishing = c and (c:GetAttribute("FishPhase") or "") ~= ""
	local color = RED
	if fishing then
		-- you're reeling: keep your hands on the line and just show the warning
		showCard("PHASE 1", ("THE %s AWAKENS"):format((payload.name or "Guardian"):upper()), "It rises to guard the exit. Stay out of the red rings.", color, 2.4)
		return
	end
	begin(true)
	local at = typeof(payload.at) == "Vector3" and payload.at or (rootPart() and rootPart().Position) or Vector3.zero
	local root = rootPart()
	local toPlayer = root and Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z) or Vector3.new(1, 0, 0)
	if toPlayer.Magnitude < 1 then
		toPlayer = Vector3.new(1, 0, 0)
	end
	toPlayer = toPlayer.Unit
	local side = Vector3.new(-toPlayer.Z, 0, toPlayer.X)
	showCard("THE GUARDIAN WAKES", ("%s"):format((payload.name or "Guardian"):upper()), "It rises to guard the exit. Stay out of the red rings.", color, 2.6)
	local wakeTime = CUT.wakeSeconds - 0.5
	film(wakeTime, function(a, t)
		local from = at + toPlayer * (34 - a * 12) + side * (8 - a * 6) + Vector3.new(0, 14 - a * 6, 0)
		local wobble = Vector3.new(math.sin(t * 40) * 0.25, math.cos(t * 37) * 0.25, 0) * (1 - a)
		return CFrame.lookAt(from + wobble, at + Vector3.new(0, 3, 0))
	end)
	finish()
end

function scenes.Descent(payload)
	begin(false)
	local root = rootPart()
	local c = character()
	if c then
		MotionBus.pose[c] = { name = "brace", untilTime = os.clock() + CUT.descentTeleport }
	end
	Audio.play("Whoosh")
	if root then
		Fx.ring(root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(90, 220, 255), 14, 0.9, 0.4)
		Fx.cubes(root.Position, { Color3.fromRGB(90, 220, 255), WHITE }, { spread = 10, size = 0.8, life = 0.9, up = 1, count = 22 })
	end
	bubbles(40, CUT.descentTeleport + 0.4, true)
	local center = root and root.Position or camera.CFrame.Position
	film(CUT.descentTeleport - 0.15, function(a, t)
		-- the camera spins down onto you as the whirlpool drags you under
		local angle = t * (2 + a * 6)
		local offset = Vector3.new(math.cos(angle) * (12 - a * 8), 22 - a * 16, math.sin(angle) * (12 - a * 8))
		return CFrame.lookAt(center + offset, center) * CFrame.Angles(0, 0, a * 1.2)
	end, Enum.EasingStyle.Quad)
	fadeTo(0, 0.15)
	root = arrive(function(r)
		return r.Position.Y < Config.Kelp.belowY
	end, 6)
	fadeTo(1, 0.7)
	allowSkip(true)
	showCard(("DEPTH %d"):format(payload.depth or 2), (payload.name or "Kelp Cathedral"):upper(), ("Guardian: %s  ·  Hazard: %s  ·  Luck x%.1f"):format(payload.guardian or "Kelp Leviathan", payload.hazard or "Grasping vines", payload.luck or 1.3), KELP, 3.4)
	say("Fish the holy-water pools, raid the chapels, and find a beacon past the apse.")
	if root then
		local high = Config.Kelp.arrival.Position + Vector3.new(0, 70, -24)
		local nave = Config.Kelp.center + Vector3.new(0, 20, 120)
		film(2.8, function(a)
			local r = rootPart() or root
			return CFrame.lookAt(high, nave):Lerp(behind(r, 12, 5), a)
		end)
	end
	finish()
end

function scenes.Ascend(payload)
	begin(false)
	Audio.play("Whoosh")
	bubbles(50, CUT.descentTeleport + 0.6, true)
	local root = rootPart()
	local center = root and root.Position or camera.CFrame.Position
	film(CUT.descentTeleport - 0.15, function(a)
		return CFrame.lookAt(center + Vector3.new(6, 3 + a * 30, 6), center + Vector3.new(0, 4 + a * 40, 0))
	end, Enum.EasingStyle.Quad)
	fadeTo(0, 0.15)
	root = arrive(function(r)
		return r.Position.Y > Config.Kelp.belowY
	end, 6)
	fadeTo(1, 0.7)
	allowSkip(true)
	showCard("DEPTH 1", (payload.name or "Sunken Shoals"):upper(), ("Guardian: %s  ·  Hazard: %s"):format(payload.guardian or "Reef Warden", payload.hazard or "Riptide pull"), SHOALS, 3)
	if root then
		Audio.play("Plunge", root)
		Fx.cubes(root.Position, { Color3.fromRGB(120, 220, 255), WHITE }, { spread = 8, size = 0.7, life = 0.7, up = 1, count = 18 })
		local start = root.Position + Vector3.new(30, 30, -20)
		film(2.2, function(a)
			local r = rootPart() or root
			return CFrame.lookAt(start, r.Position):Lerp(behind(r, 12, 5), a)
		end)
	end
	finish()
end

local function tallyLine(order, left, right, color)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 16, Parent = tally })
	new("TextLabel", { Size = UDim2.new(0.62, 0, 1, 0), BackgroundTransparency = 1, Font = BODY, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WHITE, Text = left, ZIndex = 16, Parent = row })
	local value = new("TextLabel", { Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), BackgroundTransparency = 1, Font = DISPLAY, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = color or GOLD, Text = "", ZIndex = 16, Parent = row })
	return function(s)
		if type(right) == "number" then
			value.Text = ("+%d"):format(math.floor(right * s + 0.5))
		else
			value.Text = s >= 1 and tostring(right) or ""
		end
	end
end

-- the tally counts up line by line; it stays a few seconds after you can move again
local function showTally(payload)
	for _, child in ipairs(tally:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Font = DISPLAY, TextSize = 26, TextColor3 = GOLD, Text = ("EXTRACTED FROM %s"):format(tostring(payload.biome or "the Shoals"):upper()), TextScaled = true, LayoutOrder = 0, ZIndex = 16, Parent = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 16, Parent = tally }) })
	local lines = {
		tallyLine(1, "Fish Pearls", tonumber(payload.fishPearls) or 0),
		tallyLine(2, "Run payout", tonumber(payload.payout) or 0),
		tallyLine(3, "Tide Eggs", tonumber(payload.eggs) or 0, Color3.fromRGB(200, 240, 255)),
		tallyLine(4, "Run Embers", tonumber(payload.embers) or 0, Color3.fromRGB(255, 150, 80)),
	}
	if (tonumber(payload.mult) or 1) > 1 then
		table.insert(lines, tallyLine(5, "Greed bonus", ("x%.1f cargo"):format(payload.mult), RED))
	end
	table.insert(lines, tallyLine(6, "Clean streak", tostring(payload.streak or 1), Color3.fromRGB(120, 240, 150)))
	tally.Visible = true
	local tallyScale = tally:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = tally })
	tallyScale.Scale = 0.6
	TweenService:Create(tallyScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		for _, line in ipairs(lines) do
			line(0)
		end
		for _, line in ipairs(lines) do
			Audio.play("Tally")
			local start = os.clock()
			while os.clock() - start < 0.35 do
				line((os.clock() - start) / 0.35)
				RunService.RenderStepped:Wait()
			end
			line(1)
		end
		task.wait(3)
		TweenService:Create(tallyScale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		tally.Visible = false
	end)
end

function scenes.Extracted(payload)
	begin(false)
	local root = rootPart()
	local column = nil
	if root then
		local base = root.Position - Vector3.new(0, 3, 0)
		column = new("Part", {
			Name = "ExtractColumn",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 230, 140),
			Transparency = 0.35,
			Size = Vector3.new(300, 0.5, 0.5),
			CFrame = CFrame.new(base + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = Fx.folder(),
		})
		TweenService:Create(column, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(300, 9, 9) }):Play()
		Audio.play("Whoosh", root)
		Fx.ring(base + Vector3.new(0, 0.3, 0), GOLD, 12, 0.7, 0.4)
		task.spawn(function()
			for _ = 1, 4 do
				local r = rootPart()
				if not r then
					break
				end
				Fx.stars(r.Position, 5, GOLD)
				Fx.bolts(r.Position + Vector3.new(0, 1, 0), 4)
				task.wait(0.5)
			end
		end)
	end
	local center = root and root.Position + Vector3.new(0, 1.5, 0) or camera.CFrame.Position
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	showCard("YOU MADE IT", "EXTRACTED!", "", GOLD, 2.2)
	film(CUT.extractTeleport - 0.45, function(a)
		local angle = a * math.pi * 0.8
		local offset = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angle):VectorToWorldSpace(look) * (10 + a * 8)
		return CFrame.lookAt(center + offset + Vector3.new(0, 1 + a * 9, 0), center + Vector3.new(0, a * 4, 0))
	end)
	fadeTo(0, 0.3, WHITE)
	root = arrive(atSpawn, 6)
	if column then
		column:Destroy()
	end
	fadeTo(1, 0.8, WHITE)
	if root then
		Fx.cubes(root.Position, { GOLD, WHITE }, { spread = 9, size = 0.8, life = 0.8, up = 1, count = 24 })
		Fx.ring(root.Position - Vector3.new(0, 2.6, 0), GOLD, 10, 0.6, 0.3)
		local start = root.Position + Vector3.new(0, 22, 0) - root.CFrame.LookVector * 6
		film(1.2, function(a)
			local r = rootPart() or root
			return CFrame.lookAt(start, r.Position):Lerp(behind(r, 12, 5), a)
		end)
	end
	finish()
	showTally(payload)
end

function scenes.Wiped(payload)
	begin(false)
	local root = rootPart()
	grade.Enabled = true
	grade.Saturation = 0
	grade.TintColor = WHITE
	TweenService:Create(grade, TweenInfo.new(0.6), { Saturation = -0.7, TintColor = Color3.fromRGB(255, 190, 190) }):Play()
	showCard(payload.reason or "", "WIPED OUT", ("Lost %d Pearls of unbanked fish and %d egg(s)"):format(tonumber(payload.lostPearls) or 0, tonumber(payload.lostEggs) or 0), RED, 3.2)
	say("Banked Pearls, pity, rods and your base are safe.")
	local center = root and root.Position or camera.CFrame.Position
	local from = camera.CFrame.Position
	film(CUT.wipeTeleport - 0.35, function(a)
		local goal = center + Vector3.new(0, 26, 0) - (root and root.CFrame.LookVector or Vector3.new(0, 0, -1)) * 8
		return CFrame.lookAt(from:Lerp(goal, a), center)
	end, Enum.EasingStyle.Quad)
	fadeTo(0, 0.35)
	root = arrive(atSpawn, 5)
	TweenService:Create(grade, TweenInfo.new(0.6), { Saturation = 0, TintColor = WHITE }):Play()
	fadeTo(1, 0.9)
	if root then
		say("You wake up in the Nest.")
		local start = root.Position + Vector3.new(8, 3, 8)
		film(1.4, function(a)
			local r = rootPart() or root
			return CFrame.lookAt(start, r.Position + Vector3.new(0, 1, 0)):Lerp(behind(r, 12, 5), a)
		end)
	end
	finish()
end

-- The queue ----------------------------------------------------------------------------------------------------
-- One at a time, never over a fish reveal. A cutscene that waited too long (the moment passed) is dropped,
-- except the ones that move you, which always play so the screen follows you.

local MUST_PLAY = { Descent = true, Ascend = true, Extracted = true, Wiped = true, Intro = true }

local function enqueue(kind, payload)
	if not scenes[kind] then
		return
	end
	table.insert(queue, { kind = kind, payload = type(payload) == "table" and payload or {}, at = os.clock() })
end

task.spawn(function()
	while true do
		local item = table.remove(queue, 1)
		if item then
			while FishingFeel.frozen do
				task.wait(0.1)
			end
			if MUST_PLAY[item.kind] or os.clock() - item.at < 2 then
				local ok, err = pcall(scenes[item.kind], item.payload)
				if not ok then
					warn("[Tidebound] cutscene " .. item.kind .. " failed: " .. tostring(err))
				end
				if playing then
					pcall(finish)
				end
				fadeTo(1, 0.3)
			end
		else
			task.wait(0.1)
		end
	end
end)

CueEvent.OnClientEvent:Connect(function(name, payload)
	if name == "Cutscene" and type(payload) == "table" then
		enqueue(payload.kind, payload)
	end
end)

-- the first time you join, the intro plays once your character is in
local introQueued = false
local function checkIntro(state)
	if introQueued or type(state) ~= "table" or state.seenIntro ~= false then
		return
	end
	introQueued = true
	task.spawn(function()
		local c = player.Character or player.CharacterAdded:Wait()
		c:WaitForChild("HumanoidRootPart", 10)
		-- the loading screen (ReplicatedFirst.TideboundLoading) is up: start the flyover once it's gone
		while player:GetAttribute("Loading") do
			task.wait(0.2)
		end
		task.wait(1.5)
		enqueue("Intro", {})
	end)
end
StateEvent.OnClientEvent:Connect(checkIntro)
task.spawn(function()
	local ok, state = pcall(Request.InvokeServer, Request, "GetState")
	if ok then
		checkIntro(state)
	end
end)

-- a respawn mid-cutscene hands the camera back
player.CharacterAdded:Connect(function()
	if playing then
		skipped = true
	end
end)
