-- Tidebound: Eggfall gameplay VFX (GDD Section 8 Table B) and the VFX Clarity Rules on the client:
--   * egg auras on every wild egg (rarity colour), hidden while the egg is stolen
--   * extraction beam, guardian roar bursts, gravity rift on PUSH DEEPER, sonar pulses in the Abyssal Trench
--   * water impact when anyone hits the water, bubble trails while swimming, ability flare on every dash
--   * the LOD pass (Rule 6: continuous emitters fade out between 120 and 150 studs), the flash overlay (Rules 3 and
--     5: at most 3 full-screen flashes a second, 20% with Reduce Flashing) and camera shake (off in Settings)
-- The hatch explosion, gacha reveal and mutation burst play from HatchScene, which owns the hatch cutscene.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Biomes = require(Shared:WaitForChild("Biomes"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))
local Vfx = require(Shared:WaitForChild("VfxLibrary"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local Remotes = Shared:WaitForChild("Remotes")

local rng = Random.new()

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Flash overlay and shake ----------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TideboundFlash"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

ClientBus.signal.Event:Connect(function(kind, a, b, c)
	if kind == "flash" then
		-- strength 1 starts at `from` transparency; Reduce Flashing (0.2) starts 80% weaker
		flash.BackgroundColor3 = a
		flash.BackgroundTransparency = 1 - (1 - c) * b
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	elseif kind == "shake" then
		if ClientBus.settings.cameraShake and FishingFeel.shake then
			FishingFeel.shake(a, b)
		end
	end
end)

-- Egg auras --------------------------------------------------------------------------------------------------------
-- Wild eggs are Tide Eggs, a Common item until they hatch, so their aura is the canon White band. The tier passed
-- in can be raised per egg with an "AuraTier" attribute (event or bonus eggs).

local auras = {} -- [BasePart] = aura

local function eggOf(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		parent = parent.Parent
	end
	return parent and parent:IsA("BasePart") and parent or nil
end

local function setAuraHidden(aura, hidden)
	for _, e in ipairs({ aura.sparks, aura.halo }) do
		local entry = Vfx.tracked[e]
		if entry then
			entry.hidden = hidden
		end
		e.Enabled = not hidden
	end
	aura.light.Enabled = not hidden
end

local function addAura(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt:GetAttribute("Action") ~= "Steal" then
		return
	end
	local egg = eggOf(prompt)
	if not egg or auras[egg] then
		return
	end
	local holder = egg:GetAttribute("Taken") ~= nil and egg or (egg.Parent and egg.Parent:GetAttribute("Taken") ~= nil and egg.Parent) or egg
	local aura = Vfx.eggAura(egg, egg:GetAttribute("AuraTier") or 1)
	auras[egg] = aura
	local function refresh()
		setAuraHidden(aura, holder:GetAttribute("Taken") == true)
	end
	holder:GetAttributeChangedSignal("Taken"):Connect(refresh)
	refresh()
end

workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("ProximityPrompt") then
		task.defer(addAura, inst) -- attributes are set right after the prompt is parented
	end
end)
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("ProximityPrompt") then
		addAura(inst)
	end
end

-- Characters: water impact, bubble trail, ability flare -------------------------------------------------------------

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	local trailAttach = Instance.new("Attachment")
	trailAttach.Name = "BubbleTrail"
	trailAttach.Parent = root
	local bubbles = Vfx.emitter(trailAttach, {
		Texture = Vfx.textures.glow, Color = ColorSequence.new(Color3.fromRGB(200, 245, 255)), Size = Vfx.seq(0.25, 0.5),
		Transparency = Vfx.seq(0.3, 1), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 3),
		EmissionDirection = Enum.NormalId.Top, LightEmission = 0.5,
	})
	humanoid.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Swimming and (old == Enum.HumanoidStateType.Freefall or old == Enum.HumanoidStateType.Jumping) then
			Vfx.waterImpact(Vector3.new(root.Position.X, root.Position.Y + 1, root.Position.Z), 1.2)
		end
	end)
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not root.Parent then
			conn:Disconnect()
			return
		end
		local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
		local moving = root.AssemblyLinearVelocity.Magnitude > 2
		bubbles.Rate = 12 * Vfx.quality() -- Bubble Trail: ~1 s of bubbles behind a moving swimmer
		bubbles.Enabled = swimming and moving
	end)
	character:GetAttributeChangedSignal("DashAt"):Connect(function()
		local hand = character:FindFirstChild("RightHand") or root
		Vfx.abilityCast(hand, Color3.fromRGB(200, 240, 255))
	end)
end

local function onPlayer(p)
	p.CharacterAdded:Connect(watchCharacter)
	if p.Character then
		task.spawn(watchCharacter, p.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

-- Guardians roar ---------------------------------------------------------------------------------------------------

local function headOf(model)
	return model:FindFirstChild("Head", true) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function watchGuardian(model)
	model:GetAttributeChangedSignal("WokeAt"):Connect(function()
		local head = headOf(model)
		if head then
			local biome = Biomes.get(Biomes.at(head.Position))
			Vfx.guardianRoar(head, biome.colors.accent)
		end
	end)
end
CollectionService:GetInstanceAddedSignal("TideboundGuardian"):Connect(watchGuardian)
for _, model in ipairs(CollectionService:GetTagged("TideboundGuardian")) do
	watchGuardian(model)
end

-- Server cues: extraction beam, gravity rift ---------------------------------------------------------------------

Remotes:WaitForChild("Cue").OnClientEvent:Connect(function(name)
	local root = rootPart()
	if not root then
		return
	end
	if name == "Extract" then
		Vfx.extractionBeam(root.Position - Vector3.new(0, 3, 0))
	elseif name == "Push" then
		Vfx.gravityRift(root.Position + root.CFrame.LookVector * 6)
	end
end)

-- LOD (Rule 6) and the Abyssal sonar --------------------------------------------------------------------------------

local function positionOf(e)
	local parent = e.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local nextSonar = os.clock() + 8
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.3 then
		return
	end
	accumulator = 0
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local q = Vfx.quality()
	local far, near = Vfx.LOD_DISTANCE, Vfx.LOD_DISTANCE - 30
	for e, entry in pairs(Vfx.tracked) do
		local at = positionOf(e)
		if at and not entry.hidden then
			local d = (at - eye).Magnitude
			local fade = d <= near and 1 or math.clamp((far - d) / (far - near), 0, 1)
			e.Rate = entry.rate * q * fade
			e.Enabled = fade > 0
		end
	end
	-- Sonar Pulse: in the Abyssal Trench the deep pings now and then, and you see the pulse sweep past you
	local now = os.clock()
	local root = rootPart()
	if root and now >= nextSonar then
		nextSonar = now + rng:NextNumber(12, 20)
		if ClientBus.biome == "AbyssalTrench" then
			Vfx.sonarPulse(root.Position + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30)))
		end
	end
end)
