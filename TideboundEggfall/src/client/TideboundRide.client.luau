-- Tidebound: Eggfall: riding your fish and the water effects (12 Oct 2026, "Swimming + Fish Riding" update).
--   * Your ride: G (gamepad L1, or the RIDE button on touch) in the sea summons your fish under you. Glide with
--     the usual movement keys, hold Shift for turbo, Space to leap with a flip, G again to hop off. Reaching a
--     beach hops you off onto it. Fishing, a cutscene or going down also ends the ride.
--   * The mounts everyone sees: your first companion's fish (or a chunky orange loaner), wiggling, bobbing and
--     banking under its rider, with a foam wake, bow and tail spray, ripple rings and a water rush that follows
--     its speed; splashes, a word pop ("YEEHAW!") and sounds when it surfaces, leaps, lands and when you hop off.
--   * Swimmers: water flicks off each arm stroke and rings spread round anyone treading water.
-- Poses are TideboundMotion's (from WaterMoves); the server's RideService shows rides to everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local WaterMoves = require(Shared:WaitForChild("WaterMoves"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local Audio = require(Shared:WaitForChild("Audio"))
local Fx = require(Shared:WaitForChild("Fx"))
local Vfx = require(Shared:WaitForChild("VfxLibrary"))
local FishModels = require(Shared:WaitForChild("FishModels"))
local remote = Shared:WaitForChild("Remotes"):WaitForChild("Ride")

WaterMoves.addCues(Audio)
MotionBus.ride = MotionBus.ride or {}

local player = Players.LocalPlayer
local rng = Random.new()

local FOAM = Color3.fromRGB(235, 250, 255)
local WATER = ColorSequence.new(Color3.fromRGB(235, 250, 255), Color3.fromRGB(150, 215, 255))
local LOANER = Color3.fromRGB(255, 150, 60)
-- turns a hatchable fish mesh (stored standing up: long along Y, tall along X, thin along Z) so its nose points
-- along -Z and its back is up
local MESH_FIX = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0))
local NEAR = 90 -- mounts and swim effects are only animated this close to the camera

-- The water under a point ----------------------------------------------------------------------------------------

local mountsFolder = Instance.new("Folder")
mountsFolder.Name = "TideboundMounts"
mountsFolder.Parent = workspace

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false
local filterAt = 0
local function refreshFilter()
	local list = { Fx.folder(), mountsFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "TideboundCompanions", "TideboundRodFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	params.FilterDescendantsInstances = list
end

-- Returns the water's surface height under `pos`, or nil and whatever solid thing is there instead.
local function surfaceAt(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -90, 0), params)
	if hit and hit.Material == Enum.Material.Water then
		return hit.Position.Y, nil
	end
	return nil, hit
end

-- Mounts (everyone's, built on this screen only) ----------------------------------------------------------------

local function quiet(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

-- The fish: your companion's own hatchable fish mesh, or the loaner. Returns the model, the part to move with
-- its own fix, and half its height.
local function buildFish(fishName)
	local model = Instance.new("Model")
	model.Name = "Mount"
	-- 12 Oct: your companion's voxel fish (ReplicatedStorage.VoxelFish), welded to an invisible Body that already
	-- faces -Z, so no mesh fix. Its half height keeps the rider standing on its back.
	local voxel = fishName ~= "" and ReplicatedStorage:FindFirstChild("VoxelFish") and ReplicatedStorage.VoxelFish:FindFirstChild(fishName)
	if voxel then
		local fish = require(Shared:WaitForChild("CreatureModels")).build(1, "None", CFrame.new(), WaterMoves.fishLength / 1.4, fishName)
		fish.Name = "Mount"
		model:Destroy()
		-- 13 Oct 2026 (HJHJH: "im in the fish when im mounted"): tall fish like the Discus reach far above the old
		-- fixed guess (a fifth of the length; a Discus's back is 4.5 studs up, not 2), so measure where its back
		-- really is: the highest block in the column under the seat, so you sit on top of it
		local pivot = fish:GetPivot()
		local back = 0
		for _, part in ipairs(fish:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local rel = pivot:ToObjectSpace(part.CFrame)
				if math.abs(rel.X) < 1.2 and math.abs(rel.Z - 0.3) < 1.2 then
					local halfY = (math.abs(rel.RightVector.Y) * part.Size.X + math.abs(rel.UpVector.Y) * part.Size.Y + math.abs(rel.LookVector.Y) * part.Size.Z) / 2
					back = math.max(back, rel.Y + halfY)
				end
			end
		end
		return fish, CFrame.new(), math.max(back, WaterMoves.fishLength * 0.2)
	end
	local store = Shared:FindFirstChild("RideFish")
	local source = fishName ~= "" and store and store:FindFirstChild(fishName)
	if source and source:IsA("BasePart") then
		local body = source:Clone()
		quiet(body)
		body.Name = "Body"
		local size = body.Size
		body.Size = size * (WaterMoves.fishLength / math.max(size.X, size.Y, size.Z))
		body.Parent = model
		model.PrimaryPart = body
		local turned = MESH_FIX:VectorToWorldSpace(body.Size)
		return model, MESH_FIX, math.abs(turned.Y) / 2
	end
	local fish, length = FishModels.build("Ride Fish", (WaterMoves.fishLength - 1.6) / 0.3)
	FishModels.paint(fish, LOANER)
	for _, part in ipairs(fish:GetDescendants()) do
		if part:IsA("BasePart") then
			quiet(part)
		end
	end
	for _, part in ipairs(fish:GetChildren()) do
		part.Parent = model
	end
	fish:Destroy()
	model.PrimaryPart = model:FindFirstChild("Body")
	return model, CFrame.new(), 0.45 * length / 2
end

local function emitter(parent, props)
	local e = Vfx.emitter(parent, props)
	e.Enabled = true
	e.Rate = 0
	return e
end

local function newMount(character, fishName)
	local model, fix, half = buildFish(fishName)
	-- the wake rig sits on the water under the fish
	local anchor = Instance.new("Part")
	anchor.Name = "Wake"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	quiet(anchor)
	anchor.Parent = mountsFolder
	local left = Instance.new("Attachment")
	left.Position = Vector3.new(-1.5, 0.05, 1)
	left.Parent = anchor
	local right = Instance.new("Attachment")
	right.Position = Vector3.new(1.5, 0.05, 1)
	right.Parent = anchor
	-- the wake: soft foam patches lying flat on the water, left where the fish passed and spreading as they fade
	local foamProps = {
		Texture = Vfx.textures.smoke,
		Color = ColorSequence.new(FOAM, Color3.fromRGB(190, 232, 255)),
		Size = Vfx.seq(1.1, 2.6, 4.2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.5), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 1.7),
		Speed = NumberRange.new(0.01),
		SpreadAngle = Vector2.new(0, 0),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25),
		LightEmission = 0.1,
	}
	local foam = { emitter(left, foamProps), emitter(right, foamProps) }
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(0, 0.2, WaterMoves.fishLength / 2)
	tail.Orientation = Vector3.new(-60, 0, 0)
	tail.Parent = anchor
	local bow = Instance.new("Attachment")
	bow.Position = Vector3.new(0, 0.2, -WaterMoves.fishLength / 2)
	bow.Parent = anchor
	local droplet = {
		Texture = Vfx.textures.glow,
		Color = ColorSequence.new(FOAM),
		Size = Vfx.seq(0.5, 0.1),
		Transparency = Vfx.seq(0.1, 1),
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(9, 16),
		Acceleration = Vector3.new(0, -60, 0),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Back,
		LightEmission = 0.4,
	}
	local rooster = emitter(tail, droplet)
	droplet.SpreadAngle = Vector2.new(70, 10)
	droplet.EmissionDirection = Enum.NormalId.Top
	droplet.Speed = NumberRange.new(6, 11)
	local spray = emitter(bow, droplet)
	-- a soft mist hanging over the tail spray
	local mist = emitter(tail, {
		Texture = Vfx.textures.smoke,
		Color = ColorSequence.new(FOAM),
		Size = Vfx.seq(1, 3.2),
		Transparency = Vfx.seq(0.6, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 6),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Drag = 2,
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Back,
		LightEmission = 0.1,
	})
	local sound = Instance.new("Sound")
	sound.Name = "RideWake"
	sound.SoundId = WaterMoves.WAKE_LOOP
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMaxDistance = 90
	if Audio.buses and Audio.buses.SFX then
		sound.SoundGroup = Audio.buses.SFX
	end
	sound.Parent = anchor
	model.Parent = mountsFolder
	sound:Play()
	return {
		character = character,
		fish = fishName,
		model = model,
		fix = fix,
		half = half,
		anchor = anchor,
		foam = foam,
		rooster = rooster,
		spray = spray,
		mist = mist,
		sound = sound,
		lean = 0,
		lastYaw = nil,
		nextRing = 0,
		jumpKey = nil,
		landed = true,
	}
end

local mounts = {} -- [Model character] = mount

-- A rider's companion swims off while it's being ridden (it's the same fish).
local function companionOf(character)
	local p = Players:GetPlayerFromCharacter(character)
	local folder = workspace:FindFirstChild("TideboundCompanions")
	return p and folder and folder:FindFirstChild("Companion_" .. p.UserId .. "_1")
end

local function hideCompanion(character, hidden)
	local model = companionOf(character)
	if model then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

-- Water effects, all soft particles: round droplets, a misty spray column, a few glints and a thin foam ripple
-- lying flat on the water (no solid discs or cubes).
local function burst(at, life)
	return Vfx.anchor(at, life or 1.6, Vector3.new(0.2, 0.2, 0.2))
end

-- a thin foam ring that spreads out flat on the water
local function ripple(at, size, life, alpha, part)
	part = part or burst(at, life + 0.2)
	local ring = Vfx.emitter(part, {
		Texture = Vfx.textures.shockwave,
		Color = ColorSequence.new(FOAM),
		Size = Vfx.seq(size * 0.25, size),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(0.6, alpha + (1 - alpha) * 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(life),
		Speed = NumberRange.new(0.01),
		SpreadAngle = Vector2.new(0, 0),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		LightEmission = 0.25,
	})
	ring:Emit(1)
end

-- round droplets thrown up and falling back
local function droplets(part, scale, count, speed)
	local drops = Vfx.emitter(part, {
		Texture = Vfx.textures.glow,
		Color = WATER,
		Size = Vfx.seq(math.max(0.3, 0.55 * scale), 0.12),
		Transparency = Vfx.seq(0.05, 0.25, 1),
		Lifetime = NumberRange.new(0.45, 0.85),
		Speed = NumberRange.new(speed * 0.6, speed),
		SpreadAngle = Vector2.new(32, 32),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -75, 0),
		Drag = 0.6,
		LightEmission = 0.5,
	})
	Vfx.emit(drops, count)
end

local function splashAt(at, scale)
	local part = burst(at)
	droplets(part, scale, 26 * scale, 16 + 8 * scale)
	local column = Vfx.emitter(part, {
		Texture = Vfx.textures.smoke,
		Color = ColorSequence.new(FOAM),
		Size = Vfx.seq(1 * scale, 3.2 * scale),
		Transparency = Vfx.seq(0.3, 0.6, 1),
		Lifetime = NumberRange.new(0.45, 0.8),
		Speed = NumberRange.new(7 * scale, 13 * scale),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		SpreadAngle = Vector2.new(18, 18),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -35, 0),
		Drag = 2,
		LightEmission = 0.15,
	})
	Vfx.emit(column, 10 * scale)
	local glints = Vfx.emitter(part, {
		Texture = Vfx.textures.sparkle,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Size = Vfx.seq(0.7, 0),
		Transparency = Vfx.seq(0, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(8, 15),
		SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -40, 0),
		LightEmission = 1,
	})
	Vfx.emit(glints, 6 * scale)
	ripple(at + Vector3.new(0, 0.12, 0), 7 + 5 * scale, 0.9, 0.35, part)
end

local function dropMount(character)
	local m = mounts[character]
	if not m then
		return
	end
	mounts[character] = nil
	hideCompanion(character, false)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and m.model.PrimaryPart then
		local at = m.model.PrimaryPart.Position
		splashAt(at, 1)
		Audio.play("RideHop", root)
	end
	m.rooster.Enabled = false
	m.spray.Enabled = false
	m.mist.Enabled = false
	m.sound:Stop()
	m.model:Destroy()
	m.anchor:Destroy()
end

-- Your ride ----------------------------------------------------------------------------------------------------------

local me = { riding = false, vel = Vector3.zero, yaw = 0, surface = 4, readyAt = 0, lastStyle = nil, probeAt = 0 }

local function myBits()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function busy(humanoid)
	return humanoid.Health <= 0 or MotionBus.cutscene or FishingFeel.frozen or FishingFeel.phase ~= ""
end

local function inSea(humanoid, root)
	if root.Position.Y > WaterMoves.maxStartHeight then
		return false
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		return true
	end
	local y = surfaceAt(root.Position)
	return y ~= nil and root.Position.Y - y < 5
end

local function stopRide(hop)
	if not me.riding then
		return
	end
	me.riding = false
	me.readyAt = os.clock() + 0.6
	if me.mover then
		me.mover:Destroy()
		me.mover = nil
	end
	if me.align then
		me.align:Destroy()
		me.align = nil
	end
	local character, humanoid, root = myBits()
	if me.character then
		MotionBus.ride[me.character] = nil
	end
	remote:FireServer("stop")
	if humanoid and root and character == me.character and humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		if hop then
			root.AssemblyLinearVelocity = me.vel * 0.6 + Vector3.new(0, 40, 0)
		else
			root.AssemblyLinearVelocity = me.vel * 0.4 + Vector3.new(0, 16, 0)
		end
	end
	me.character = nil
end

local function startRide()
	local character, humanoid, root = myBits()
	if not humanoid or not root or me.riding or os.clock() < me.readyAt or busy(humanoid) or not inSea(humanoid, root) then
		return
	end
	-- a new goofy style every time (never the same twice in a row)
	local options = {}
	for _, s in ipairs(WaterMoves.STYLES) do
		if s ~= me.lastStyle then
			table.insert(options, s)
		end
	end
	local style = options[rng:NextInteger(1, #options)]
	me.lastStyle = style
	me.riding = true
	me.character = character
	me.style = style
	me.surface = surfaceAt(root.Position) or 4
	local v = root.AssemblyLinearVelocity
	me.vel = Vector3.new(v.X, 0, v.Z)
	local look = root.CFrame.LookVector
	me.yaw = math.atan2(-look.X, -look.Z)
	me.jumpAt = nil
	local attachment = root:FindFirstChild("RideAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RideAttachment"
		attachment.Parent = root
	end
	local mover = Instance.new("LinearVelocity")
	mover.Name = "RideVelocity"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = 200000
	mover.VectorVelocity = Vector3.new(me.vel.X, 20, me.vel.Z)
	mover.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "RideOrientation"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e7
	align.Responsiveness = 25
	align.CFrame = CFrame.Angles(0, me.yaw, 0)
	align.Parent = root
	me.mover, me.align = mover, align
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	MotionBus.ride[character] = { style = style, start = os.clock(), jumpAt = nil, jumpLength = WaterMoves.jumpLength() }
	remote:FireServer("start", style)
end

local function leap()
	local character, humanoid, root = myBits()
	if not me.riding or not root or me.jumpAt or os.clock() < (me.jumpReady or 0) then
		return
	end
	me.jumpAt = os.clock()
	me.jumpReady = me.jumpAt + WaterMoves.jumpLength() + WaterMoves.jumpCooldown
	local own = MotionBus.ride[character]
	if own then
		own.jumpAt = me.jumpAt
	end
	remote:FireServer("jump")
end

local function toggle()
	if me.riding then
		stopRide(false)
	else
		startRide()
	end
end

-- moves you, every physics step
local function drive(dt)
	if not me.riding then
		return
	end
	local character, humanoid, root = myBits()
	if not humanoid or not root or character ~= me.character or busy(humanoid) or not me.mover or not me.mover.Parent then
		stopRide(false)
		return
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	local move = humanoid.MoveDirection
	move = Vector3.new(move.X, 0, move.Z)
	local turbo = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL3)
	local target = Vector3.zero
	if move.Magnitude > 0.05 then
		target = move.Unit * math.min(1, move.Magnitude) * (turbo and WaterMoves.turbo or WaterMoves.cruise)
	end
	me.vel = me.vel:Lerp(target, math.min(1, dt * WaterMoves.accel))
	-- the water ahead: follow its height, and hop off onto a beach
	local now = os.clock()
	if now > me.probeAt then
		me.probeAt = now + 0.08
		local flat = me.vel.Magnitude > 1 and me.vel.Unit or Vector3.zero
		local y, ground = surfaceAt(root.Position + flat * 3.5)
		if y then
			me.surface = y
		elseif ground and not me.jumpAt and ground.Position.Y > me.surface - 2 and ground.Position.Y < me.surface + 7 then
			stopRide(true)
			return
		end
	end
	local vy
	if me.jumpAt then
		local u = now - me.jumpAt
		if u >= WaterMoves.jumpLength() then
			me.jumpAt = nil
			local own = MotionBus.ride[character]
			if own then
				own.jumpAt = nil
			end
			vy = 0
		else
			vy = WaterMoves.jumpSpeed - WaterMoves.jumpGravity * u
		end
	end
	if not vy then
		local targetY = me.surface + WaterMoves.heightFor(me.style)
		vy = math.clamp((targetY - root.Position.Y) * 6, -40, 40)
	end
	me.mover.VectorVelocity = Vector3.new(me.vel.X, vy, me.vel.Z)
	if me.vel.Magnitude > 1.5 then
		local d = me.vel.Unit
		me.yaw = math.atan2(-d.X, -d.Z)
	end
	me.align.CFrame = CFrame.Angles(0, me.yaw, 0)
end
RunService.PreSimulation:Connect(drive)

ContextActionService:BindAction("TideboundRide", function(_, state)
	if state == Enum.UserInputState.Begin then
		toggle()
	end
	return Enum.ContextActionResult.Sink
end, UserInputService.TouchEnabled, WaterMoves.KEY, WaterMoves.PAD)
ContextActionService:SetTitle("TideboundRide", "RIDE")
ContextActionService:SetPosition("TideboundRide", UDim2.new(1, -330, 1, -160))

local function watchMe(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
			if humanoid.Jump and me.riding then
				leap()
			end
		end)
	end
end
player.CharacterAdded:Connect(function(character)
	stopRide(false)
	watchMe(character)
end)
if player.Character then
	task.spawn(watchMe, player.Character)
end

-- The hint over the hotbar --------------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TideboundRideHint"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")
local pill = Instance.new("TextLabel")
pill.AnchorPoint = Vector2.new(0.5, 1)
pill.Position = UDim2.new(0.5, 0, 1, -100)
pill.Size = UDim2.fromOffset(250, 34)
-- HUD restyle (12 Oct 2026): the side buttons' blue tile look (gradient, light outline, rounded corners)
pill.BackgroundColor3 = Color3.new(1, 1, 1)
pill.BackgroundTransparency = 0
pill.Font = Enum.Font.FredokaOne
pill.TextSize = 17
pill.TextColor3 = Color3.new(1, 1, 1)
pill.Text = ""
pill.Visible = false
pill.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = pill
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(Color3.fromRGB(40, 140, 255), Color3.fromRGB(18, 76, 214))
gradient.Parent = pill
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 210, 255)
stroke.Thickness = 2.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = pill
local textStroke = Instance.new("UIStroke")
textStroke.Color = Color3.fromRGB(26, 4, 10)
textStroke.Thickness = 2
textStroke.Parent = pill

local hintAt = 0
local function updateHint()
	local now = os.clock()
	if now < hintAt then
		return
	end
	hintAt = now + 0.2
	local _, humanoid, root = myBits()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if me.riding then
		pill.Text = touch and "TAP JUMP TO LEAP  ·  RIDE TO HOP OFF" or "SPACE · LEAP     G · HOP OFF     SHIFT · TURBO"
		pill.Size = UDim2.fromOffset(touch and 300 or 360, 34)
		pill.Visible = true
	elseif humanoid and root and not busy(humanoid) and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		pill.Text = touch and "TAP RIDE · RIDE YOUR FISH" or "G · RIDE YOUR FISH"
		pill.Size = UDim2.fromOffset(touch and 250 or 200, 34)
		pill.Visible = true
	else
		pill.Visible = false
	end
end

-- Every frame: everyone's mounts and the swim effects -------------------------------------------------------------

local swimFx = {} -- [character] = { nextStroke, hand, nextRing, surfaceAt, surface }

local function riderInfo(character, serverNow)
	return WaterMoves.rideOf(character, MotionBus.ride[character], serverNow)
end

local function updateMount(character, root, style, jump, dt, t, eye)
	local fishName = character:GetAttribute("RideFish")
	if character == player.Character then
		local c = companionOf(character)
		fishName = c and c:GetAttribute("Creature") or ""
	end
	fishName = type(fishName) == "string" and fishName or ""
	local m = mounts[character]
	if m and m.fish ~= fishName then
		m.model:Destroy()
		m.anchor:Destroy()
		mounts[character] = nil
		m = nil
	end
	if not m then
		m = newMount(character, fishName)
		mounts[character] = m
		local at = root.Position - Vector3.new(0, WaterMoves.heightFor(style), 0)
		splashAt(at, 1.4)
		local word = WaterMoves.WORDS[style]
		if word then
			Fx.word(root.Position + Vector3.new(0, 4, 0), word[1], word[2], 1)
		end
		Audio.play("RideSummon", root)
	end
	if fishName ~= "" then
		hideCompanion(character, true)
	end
	-- how fast and how hard it's turning
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = math.clamp(flat.Magnitude / WaterMoves.cruise, 0, 1.5)
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	if m.lastYaw then
		local d = (yaw - m.lastYaw + math.pi) % (math.pi * 2) - math.pi
		local rate = d / math.max(dt, 1 / 240)
		m.lean += (math.clamp(rate * 0.12 * math.min(speed, 1), -0.6, 0.6) - m.lean) * math.min(1, dt * 6)
	end
	m.lastYaw = yaw
	local own = MotionBus.ride[character]
	if own then
		own.speed, own.lean = speed, m.lean
	end
	local flatCf = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
	local leaping = jump and jump >= 0 and jump <= 1
	local cf = WaterMoves.mountCFrame(style, flatCf, t, math.min(speed, 1), m.lean, leaping and jump or nil, m.half)
	if m.model.PrimaryPart then
		m.model:PivotTo(cf * m.fix)
	end
	-- the wake rig floats on the water under the fish
	local surface = me.riding and character == me.character and me.surface or nil
	if not surface then
		surface = root.Position.Y - WaterMoves.heightFor(style)
		if leaping then
			surface = m.surfaceY or surface
		end
	end
	if not leaping then
		m.surfaceY = surface
	end
	local onWater = not leaping or jump < 0.06 or jump > 0.94
	m.anchor.CFrame = CFrame.new(root.Position.X, surface + 0.05, root.Position.Z) * CFrame.Angles(0, yaw, 0)
	local near = (root.Position - eye).Magnitude < NEAR
	local q = Vfx.quality()
	m.rooster.Rate = (near and onWater) and 70 * math.clamp(speed - 0.1, 0, 1.4) * q or 0
	m.spray.Rate = (near and onWater) and 45 * math.clamp(speed - 0.3, 0, 1.2) * q or 0
	m.mist.Rate = (near and onWater) and 18 * math.clamp(speed - 0.2, 0, 1.3) * q or 0
	for _, e in ipairs(m.foam) do
		e.Rate = (near and onWater and speed > 0.15) and 28 * math.min(speed, 1.3) * q or 0
	end
	m.sound.Volume = onWater and (0.05 + 0.32 * math.min(speed, 1.3)) or 0.02
	m.sound.PlaybackSpeed = 0.85 + 0.3 * math.min(speed, 1.3)
	-- ripple rings behind it (or round it while it bobs in place)
	if near and onWater and t > m.nextRing then
		local moving = speed > 0.2
		m.nextRing = t + (moving and 0.3 or 1.1)
		local back = moving and (root.Position + flat.Unit * -2.5) or root.Position
		ripple(Vector3.new(back.X, surface + 0.08, back.Z), moving and 6 or 8, moving and 0.9 or 1.4, 0.55)
	end
	-- the leap: spray on the way out, a big splash on the way back in
	if leaping then
		if m.landed then
			m.landed = false
			splashAt(Vector3.new(root.Position.X, surface, root.Position.Z), 0.9)
			Audio.play("RideLeap", root)
		end
	elseif not m.landed then
		m.landed = true
		splashAt(Vector3.new(root.Position.X, surface, root.Position.Z), 1.8)
		Audio.play("RideSplash", root)
		if character == player.Character then
			MotionBus.kick = { at = os.clock(), amount = 6, length = 0.35 }
		end
	end
end

-- Arms flick water off at each stroke, and treading water sends out rings.
local function updateSwimmer(character, root, humanoid, t, eye)
	local s = swimFx[character]
	if not s then
		s = { nextStroke = 0, hand = "RightHand", nextRing = 0, probeAt = 0, surface = nil }
		swimFx[character] = s
	end
	if t > s.probeAt then
		s.probeAt = t + 0.25
		s.surface = surfaceAt(root.Position + Vector3.new(0, 2, 0))
	end
	local surface = s.surface
	if not surface or (root.Position - eye).Magnitude > NEAR then
		return
	end
	local depth = surface - root.Position.Y
	local swimming = depth > -1.2 and depth < 3
	if character == player.Character then
		swimming = swimming and humanoid:GetState() == Enum.HumanoidStateType.Swimming
	end
	if not swimming then
		return
	end
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed > 3 and t > s.nextStroke then
		s.nextStroke = t + math.clamp(0.75 - speed * 0.02, 0.32, 0.6)
		s.hand = s.hand == "RightHand" and "LeftHand" or "RightHand"
		local hand = character:FindFirstChild(s.hand)
		local at = hand and hand.Position or root.Position
		at = Vector3.new(at.X, surface + 0.1, at.Z)
		droplets(burst(at, 1.2), 0.6, 7, 11)
		if character == player.Character then
			Audio.play("SwimStroke", root)
		end
	end
	if t > s.nextRing then
		s.nextRing = t + (speed > 3 and 0.45 or 0.9)
		ripple(Vector3.new(root.Position.X, surface + 0.08, root.Position.Z), speed > 3 and 5 or 6.5, speed > 3 and 1 or 1.5, 0.6)
	end
end

local lastTick = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local dt = math.min(t - lastTick, 0.1)
	lastTick = t
	if t > filterAt then
		filterAt = t + 1
		refreshFilter()
	end
	updateHint()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local seen = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local style, jump = riderInfo(character, serverNow)
			if style and (root.Position - eye).Magnitude < 400 then
				seen[character] = true
				local ok, err = pcall(updateMount, character, root, style, jump, dt, t, eye)
				if not ok then
					warn("[TideboundRide]", err)
				end
			else
				updateSwimmer(character, root, humanoid, t, eye)
			end
		end
	end
	for character in pairs(mounts) do
		if not seen[character] then
			dropMount(character)
		end
	end
	for character in pairs(swimFx) do
		if not character.Parent then
			swimFx[character] = nil
		end
	end
end)
