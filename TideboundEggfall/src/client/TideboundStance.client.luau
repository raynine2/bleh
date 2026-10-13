-- Tidebound: Eggfall: the two stances (13 Oct 2026, HJHJH). X (or the gamepad Y button, or a tap on the little
-- pill at the bottom of the screen) swaps between the fishing stance, where a click at a spot charges a cast
-- (TideboundFischCast), and the fighting stance, where a click swings your rod (TideboundRod's swipe combo) and
-- the rod stays in your hand in a low guard. The swap twirls the rod (TideboundRod), punches the camera, jolts
-- the screen and bursts in your rod's colours (RodFx). On screen it's Fisch-simple: one small pill reading
-- FISH | FIGHT with the active side lit, and a tiny X key beside it, to the right of the rod ability pill. It
-- hides while you fish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local RodFx = require(Shared:WaitForChild("RodFx"))
local Audio = require(Shared:WaitForChild("Audio"))
local Request = Shared:WaitForChild("Remotes"):WaitForChild("Request")

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(16, 16, 20)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

-- The pill ----------------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TideboundStance"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 13
gui.Parent = player:WaitForChild("PlayerGui")

local pill = Instance.new("TextButton")
pill.Name = "Stance"
-- beside the rod ability pill (TideboundSkills, 230 wide at 1, -46), level with it, clear of the stamina bar
-- under it (13 Oct 2026: it sat on top of both)
pill.AnchorPoint = Vector2.new(0, 0.5)
pill.Position = UDim2.new(0.5, 127, 1, -61)
pill.Size = UDim2.fromOffset(128, 24)
pill.BackgroundColor3 = INK
pill.BackgroundTransparency = 0.35
pill.AutoButtonColor = false
pill.Text = ""
pill.Parent = gui
Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
local pillStroke = Instance.new("UIStroke")
pillStroke.Color = WHITE
pillStroke.Transparency = 0.75
pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pillStroke.Parent = pill
local pillScale = Instance.new("UIScale")
pillScale.Parent = pill

-- the lit half slides under the active word
local knob = Instance.new("Frame")
knob.Size = UDim2.new(0.5, -4, 1, -4)
knob.Position = UDim2.fromOffset(2, 2)
knob.BackgroundColor3 = WHITE
knob.BackgroundTransparency = 0.08
knob.BorderSizePixel = 0
knob.Parent = pill
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

local function word(text, x)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.5, 1)
	label.Position = UDim2.fromScale(x, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.FontFace = FONT
	label.TextSize = 12
	label.ZIndex = 2
	label.Parent = pill
	return label
end
local fishWord = word("FISH", 0)
local fightWord = word("FIGHT", 0.5)

-- the key, small, to the right
local key = Instance.new("TextLabel")
key.AnchorPoint = Vector2.new(0, 0.5)
key.Position = UDim2.new(1, 6, 0.5, 0)
key.Size = UDim2.fromOffset(18, 18)
key.BackgroundColor3 = INK
key.BackgroundTransparency = 0.35
key.Text = "X"
key.FontFace = FONT
key.TextSize = 11
key.TextColor3 = WHITE
key.Parent = pill
Instance.new("UICorner", key).CornerRadius = UDim.new(0, 4)
local keyStroke = Instance.new("UIStroke")
keyStroke.Color = WHITE
keyStroke.Transparency = 0.6
keyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
keyStroke.Parent = key

local function refresh(animate)
	local fight = FishingFeel.stance == "fight"
	local goal = { Position = fight and UDim2.new(0.5, 2, 0, 2) or UDim2.fromOffset(2, 2) }
	if animate then
		TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), goal):Play()
	else
		knob.Position = goal.Position
	end
	fishWord.TextColor3 = fight and WHITE or INK
	fishWord.TextTransparency = fight and 0.45 or 0
	fightWord.TextColor3 = fight and INK or WHITE
	fightWord.TextTransparency = fight and 0 or 0.45
end
refresh(false)

local function pulse()
	pillScale.Scale = 1.14
	TweenService:Create(pillScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	keyStroke.Transparency = 0
	TweenService:Create(keyStroke, TweenInfo.new(0.6), { Transparency = 0.6 }):Play()
end

-- The swap ----------------------------------------------------------------------------------------------------

local pending = false

local function canSwap()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0 and FishingFeel.phase == "" and not FishingFeel.busy and not FishingFeel.frozen and not MotionBus.cutscene
end

local function tell(stance)
	task.spawn(function()
		pending = true
		local ok, result = pcall(Request.InvokeServer, Request, "Stance", stance)
		pending = false
		if (not ok or type(result) ~= "table" or result.error) and FishingFeel.stance == stance then
			-- the server said no (still reeling, say): back to fishing
			FishingFeel.stance = "fish"
			FishingFeel.stanceAt = workspace:GetServerTimeNow()
			refresh(true)
		end
	end)
end

local function setStance(stance)
	if stance == FishingFeel.stance or pending or not canSwap() then
		return
	end
	local character = player.Character
	FishingFeel.stance = stance
	FishingFeel.stanceAt = workspace:GetServerTimeNow()
	refresh(true)
	pulse()
	-- TideboundRod plays the twirl; here the camera punch, the jolt, the whoosh and a burst off the rod
	local fight = stance == "fight"
	RodFx.kick(fight and -5 or 3, fight and 0.14 or 0.06, 0.35)
	pcall(Audio.play, "SwingWhoosh", character and character:FindFirstChild("HumanoidRootPart"), fight and 1.15 or 0.9)
	task.delay(0.16, function()
		local tip = RodFx.tipOf(character)
		if tip then
			RodFx.burst(tip, RodFx.rodOf(character), fight and 1.1 or 0.6)
		end
	end)
	tell(stance)
end
FishingFeel.setStance = setStance

local function toggle()
	setStance(FishingFeel.stance == "fight" and "fish" or "fight")
end

pill.Activated:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonY then
		toggle()
	end
end)

-- a click on the world in the fishing stance, away from any spot, nudges the pill so you find X
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or FishingFeel.stance ~= "fish" then
		return
	end
	task.delay(0.05, function()
		if FishingFeel.phase == "" and not FishingFeel.castReady and canSwap() then
			if FishingFeel.overUi(input.Position) then
				return
			end
			pulse()
		end
	end)
end)

-- a new character starts where you left off (the server forgets the attribute with the old body)
player.CharacterAdded:Connect(function()
	task.wait(1)
	if FishingFeel.stance == "fight" then
		FishingFeel.stanceAt = workspace:GetServerTimeNow()
		tell("fight")
	end
end)

-- hidden while you fish or a cutscene plays; the key only shows with a keyboard
task.spawn(function()
	while true do
		pill.Visible = FishingFeel.phase == "" and not FishingFeel.busy and not MotionBus.cutscene and not FishingFeel.frozen
		key.Visible = UserInputService.KeyboardEnabled
		task.wait(0.15)
	end
end)
