-- Tidebound: Eggfall: the Fisch-style power cast (HJHJH's video, 12 Oct 2026).
-- At a fishing spot there's no "Cast" button any more: hold click (or the screen, E, or R2) and let go to cast.
-- 13 Oct 2026: and you can cast into any water in front of you, spot or not (see waterAhead).
-- FischUI draws the bouncing power bar and the rating word; the cast itself still goes through the spot's
-- ProximityPrompt, so the server (Main.onCast) works as before. The rating's progress-speed bonus is read by
-- the reel minigame in TideboundClient.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local FischUI = require(Shared:WaitForChild("FischUI"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local RodFx = require(Shared:WaitForChild("RodFx"))
local Request = Shared:WaitForChild("Remotes"):WaitForChild("Request")
local Config = require(Shared:WaitForChild("Config"))

local player = Players.LocalPlayer

local function isCast(prompt)
	return prompt:IsA("ProximityPrompt") and prompt:GetAttribute("Action") == "Cast"
end

-- Roblox's prompt box is hidden and E or a tap on it no longer casts straight away; the hold below casts instead.
-- (These changes are on this screen only.)
local function restyle(prompt)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.Unknown
	prompt.GamepadKeyCode = Enum.KeyCode.Unknown
	prompt.ClickablePrompt = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
end

local shown = {} -- [prompt] = true: the Cast prompts in reach right now
ProximityPromptService.PromptShown:Connect(function(prompt)
	if isCast(prompt) then
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			restyle(prompt) -- one the startup pass missed (streamed in late): no Roblox box, no E-to-cast
		end
		shown[prompt] = true
	end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shown[prompt] = nil
end)
task.spawn(function()
	for i, d in ipairs(workspace:GetDescendants()) do
		if isCast(d) then
			restyle(d)
		end
		if i % 2000 == 0 then
			task.wait()
		end
	end
end)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		task.defer(function()
			if isCast(d) then
				restyle(d)
			end
		end)
	end
end)

local function rootPart()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- the closest Cast prompt in reach
local function nearest()
	local root = rootPart()
	if not root then
		return nil
	end
	local best, bestDist = nil, math.huge
	for prompt in pairs(shown) do
		local holder = prompt.Parent
		if holder and prompt.Enabled then
			local at = holder:IsA("BasePart") and holder.Position or (holder:IsA("Attachment") and holder.WorldPosition) or nil
			if at then
				local d = (at - root.Position).Magnitude
				if d < bestDist then
					best, bestDist = prompt, d
				end
			end
		else
			shown[prompt] = nil
		end
	end
	return best
end

-- 13 Oct 2026 (HJHJH): no spot needed out at sea. Any sea water in front of you works (Terrain water, outside the
-- Nest and the Harbor, where only the spots and piers fish: "im able to fish on main land including lobby, fix it"),
-- and down in the Kelp Cathedral its pools. We look a few steps ahead of you (and where the camera points) for a
-- water surface; the server checks it again (Main handlers.CastWater).
local REACH = 34
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
local function isWater(hit)
	return hit ~= nil and hit.Instance == workspace.Terrain and hit.Material == Enum.Material.Water
end
local AHEAD = { 10, 14, 7, 18, 22, 26, 4 }
local function waterAhead()
	local root = rootPart()
	if not root then
		return nil
	end
	if root.Position.Y >= -150 and Config.safeZone(root.Position) ~= nil then
		return nil -- the Nest and the Harbor: spots and piers only
	end
	rayParams.FilterDescendantsInstances = { player.Character }
	local camera = workspace.CurrentCamera
	local dirs = { root.CFrame.LookVector, camera and camera.CFrame.LookVector or root.CFrame.LookVector }
	for _, dir in ipairs(dirs) do
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude > 0.1 then
			flat = flat.Unit
			for _, dist in ipairs(AHEAD) do
				local from = root.Position + flat * dist + Vector3.new(0, 10, 0)
				local hit = workspace:Raycast(from, Vector3.new(0, -44, 0), rayParams)
				if isWater(hit) and (hit.Position - root.Position).Magnitude <= REACH then
					if hit.Position.Y < -150 or Config.safeZone(hit.Position) == nil then
						return hit.Position
					end
				end
			end
		end
	end
	return nil
end

local function canCast()
	return nearest() ~= nil or waterAhead() ~= nil
end

local function idle()
	-- the server's FishPhase too, so a click can't start a second cast while the last one is still going there
	local character = player.Character
	local serverPhase = character and character:GetAttribute("FishPhase") or ""
	-- 13 Oct 2026: and only in the fishing stance, and never while the last cast's minigame is still running
	-- or the server is still starting it (that was the "You're already reeling" toast)
	return FishingFeel.phase == ""
		and serverPhase == ""
		and FishingFeel.stance ~= "fight"
		and not FishingFeel.busy
		and os.clock() >= (FishingFeel.castLockUntil or 0)
		and not FishingFeel.frozen
		and not MotionBus.cutscene
end

-- Studio and some devices flag plain clicks on the world as "processed", so for the mouse we look for a button
-- under the pointer ourselves
local function overButton(position)
	return FishingFeel.overUi(position) -- 13 Oct 2026: any menu, window or HUD piece, not only buttons
end

-- a small hint while a spot is in reach
local hintGui = Instance.new("ScreenGui")
hintGui.Name = "TideboundFischCastHint"
hintGui.ResetOnSpawn = false
hintGui.IgnoreGuiInset = true
hintGui.DisplayOrder = 14
hintGui.Parent = player:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -150)
hint.Size = UDim2.new(0, 360, 0, 24)
hint.BackgroundTransparency = 1
hint.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
hint.TextSize = 15
hint.TextColor3 = Color3.new(1, 1, 1)
hint.Visible = false
hint.Parent = hintGui
local hintStroke = Instance.new("UIStroke")
hintStroke.Thickness = 1.6
hintStroke.Color = Color3.fromRGB(12, 12, 16)
hintStroke.Parent = hint

task.spawn(function()
	while true do
		local ready = idle() and canCast()
		FishingFeel.castReady = ready or FishingFeel.phase == "charge"
		hint.Visible = ready
		if ready then
			local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
			hint.Text = touchOnly and "Hold the screen to cast, let go to throw" or "Hold Click to cast, let go to throw"
		end
		task.wait(0.12)
	end
end)

-- The hold ---------------------------------------------------------------------------------------------------

local busy = false

local function charge(isHeld)
	busy = true
	hint.Visible = false
	FishingFeel.cast, FishingFeel.result = nil, nil
	FishingFeel.power = 0
	FishingFeel.set("charge")
	local power, rating = FischUI.charge(isHeld, function(p)
		FishingFeel.power = p
	end)
	FishingFeel.castRating, FishingFeel.castAt = rating, os.clock()
	local prompt = nearest()
	local water = (not prompt or not prompt.Parent) and waterAhead() or nil
	if ((prompt and prompt.Parent) or water) and FishingFeel.phase == "charge" and not FishingFeel.busy then
		-- the throw: a wider view and a jolt that grow with the power, and a burst off the rod tip as the line
		-- flies (in the rod's colours)
		RodFx.kick(3 + 7 * power, 0.05 + 0.15 * power, 0.4)
		task.delay(0.3, function()
			local character = player.Character
			local tip = RodFx.tipOf(character)
			if tip then
				RodFx.burst(tip, RodFx.rodOf(character), 0.5 + power)
			end
		end)
		FishingFeel.castLockUntil = os.clock() + 2
		if water then
			task.spawn(function()
				pcall(Request.InvokeServer, Request, "CastWater", water)
			end)
		else
			prompt:InputHoldBegin()
			task.wait()
			prompt:InputHoldEnd()
		end
	end
	-- the cast (TideboundClient) takes over from here; if the server turned it down, stand down
	task.delay(1.6, function()
		if FishingFeel.phase == "charge" then
			FishingFeel.set("")
			FishingFeel.power = 0
		end
	end)
	busy = false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if busy or not idle() or not canCast() then
		return
	end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 then
		if overButton(input.Position) then
			return
		end
		task.spawn(charge, function()
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end)
		return
	end
	if processed then
		return
	end
	if kind == Enum.UserInputType.Touch then
		task.spawn(charge, function()
			return input.UserInputState ~= Enum.UserInputState.End and input.UserInputState ~= Enum.UserInputState.Cancel
		end)
	elseif input.KeyCode == Enum.KeyCode.E then
		task.spawn(charge, function()
			return UserInputService:IsKeyDown(Enum.KeyCode.E)
		end)
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		task.spawn(charge, function()
			return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
		end)
	end
end)
