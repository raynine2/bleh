-- Tidebound: Eggfall: the egg hatch scene (Patch 11), in the style of the reference short. Client only.
--   1. A big voxel Tide Egg with a "?" drops in front of you; a row of creature coins spins across the top
--      of the screen like a slot machine.
--   2. The egg shakes three times, harder each time, cracking and growing, and the camera pushes in and shakes.
--   3. It swells huge and glows in the rarity's colour while rounded rings pulse out from it.
--   4. It bursts: a white flash, shell chunks, a storm of yellow sparkles, lightning, shock rings, a camera kick.
--   5. The creature spins in the light with rays behind it, its rarity and name in big pixel letters.
-- HatchScene.mountBoards() also hangs the reference's pixel odds card over the Tide Egg Shrine.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local CreatureModels = require(Shared:WaitForChild("CreatureModels"))

local HatchScene = {}

local PIXEL = Enum.Font.Arcade
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 220, 70)
local SHELL = Color3.fromRGB(232, 246, 255)
local SHELL_SHADE = Color3.fromRGB(190, 222, 244)
local SPOT = Color3.fromRGB(70, 170, 230)
local TAU = math.pi * 2

local function smooth(s)
	s = math.clamp(s, 0, 1)
	return s * s * (3 - 2 * s)
end

local function newPart(parent, name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

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

local function pixelText(props)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = PIXEL,
		TextScaled = true,
		TextColor3 = props.color or WHITE,
		Text = props.text or "",
		Size = props.size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.new(),
		ZIndex = props.z or 2,
		Parent = props.parent,
	})
	new("UIStroke", { Color = props.stroke or Color3.fromRGB(20, 10, 16), Thickness = props.thickness or 3, Parent = label })
	return label
end

-- The voxel egg ----------------------------------------------------------------------------------------------
-- Stacked blocks in an egg profile, spots, and a "?" on its face. Every piece keeps its unscaled offset so the
-- egg can grow and wobble by rewriting sizes and CFrames each frame.

local PROFILE = { { -2.4, 2.2 }, { -1.6, 3.2 }, { -0.8, 3.8 }, { 0, 4.0 }, { 0.8, 3.9 }, { 1.6, 3.4 }, { 2.4, 2.6 }, { 3.1, 1.6 } }

local function buildEgg(parent)
	local model = Instance.new("Model")
	model.Name = "HatchEgg"
	local pieces = {}
	local function add(p, offset)
		table.insert(pieces, { part = p, size = p.Size, offset = offset })
	end
	for i, row in ipairs(PROFILE) do
		local y, w = row[1], row[2]
		add(newPart(model, "Shell", Vector3.new(w, 0.82, w), (i % 2 == 0) and SHELL or SHELL_SHADE), CFrame.new(0, y, 0))
		add(newPart(model, "ShellX", Vector3.new(w * 0.8, 0.82, w * 1.08), SHELL), CFrame.new(0, y, 0))
		add(newPart(model, "ShellZ", Vector3.new(w * 1.08, 0.82, w * 0.8), SHELL), CFrame.new(0, y, 0))
	end
	-- blue spots poking out of the shell
	for _, spec in ipairs({ { 1.9, 0.4, 0.2 }, { -1.7, -0.6, 0.6 }, { 1.2, 1.5, -1.3 }, { -1.0, 1.9, 1.0 }, { 0.3, -1.5, -1.8 }, { -1.9, 0.9, -0.8 } }) do
		add(newPart(model, "Spot", Vector3.new(0.9, 0.9, 0.9), SPOT, Enum.Material.SmoothPlastic), CFrame.new(spec[1], spec[2], spec[3]))
	end
	-- the "?" on a plate on its face
	local face = newPart(model, "Face", Vector3.new(2.6, 2.6, 0.2), SHELL)
	face.Transparency = 1
	add(face, CFrame.new(0, 0.2, -2.06))
	local gui = new("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, Brightness = 2, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, Parent = face })
	local mark = pixelText({ parent = gui, text = "?", size = UDim2.fromScale(1, 1), color = Color3.fromRGB(255, 236, 120), stroke = Color3.fromRGB(150, 60, 20), thickness = 6 })
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 0
	glow.Color = WHITE
	glow.Parent = pieces[4].part
	model.Parent = parent
	return { model = model, pieces = pieces, cracks = {}, mark = mark, light = glow }
end

local function poseEgg(egg, pivot, scale)
	local parts, cframes = {}, {}
	for _, piece in ipairs(egg.pieces) do
		local target = piece.size * scale
		if (piece.part.Size - target).Magnitude > 0.01 then
			piece.part.Size = target
		end
		table.insert(parts, piece.part)
		table.insert(cframes, pivot * CFrame.new(piece.offset.Position * scale) * piece.offset.Rotation)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A glowing zig-zag crack across the shell; it grows with the egg.
local function addCrack(egg, seed, color)
	local rng = Random.new(seed)
	local a = rng:NextNumber(0, TAU)
	local y = rng:NextNumber(-1.2, 1.6)
	for i = 1, 4 do
		local ang = a + (i - 2.5) * 0.28
		local r = 2.05
		local p = newPart(egg.model, "Crack", Vector3.new(0.25, 0.9, 0.25), color, Enum.Material.Neon)
		local offset = CFrame.new(math.sin(ang) * r, y + (i % 2 == 0 and 0.35 or -0.35), -math.cos(ang) * r) * CFrame.Angles(0, -ang, (i % 2 == 0) and 0.7 or -0.7)
		table.insert(egg.pieces, { part = p, size = p.Size, offset = offset })
		table.insert(egg.cracks, p)
	end
end

-- Screen pieces --------------------------------------------------------------------------------------------

local function buildGui(playerGui)
	local gui = new("ScreenGui", { Name = "TideboundHatch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30, Parent = playerGui })
	local tint = new("Frame", { Name = "Tint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	local flash = new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = gui })
	-- the slot-machine row of creature coins across the top
	local bar = new("Frame", { Name = "Roulette", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120), Size = UDim2.new(0, 460, 0, 84), BackgroundColor3 = Color3.fromRGB(40, 26, 20), BackgroundTransparency = 0.15, ClipsDescendants = true, ZIndex = 5, Parent = gui }, {
		new("UICorner", { CornerRadius = UDim.new(0, 18) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 214, 110), Thickness = 4 }),
	})
	local strip = new("Frame", { Name = "Strip", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), ZIndex = 6, Parent = bar })
	local pointer = new("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 76, 1, 0), BackgroundTransparency = 1, ZIndex = 8, Parent = bar }, {
		new("UIStroke", { Color = WHITE, Thickness = 4 }),
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
	})
	local title = pixelText({ parent = gui, text = "", size = UDim2.new(0.8, 0, 0, 72), position = UDim2.new(0.5, 0, 0.66, 0), anchor = Vector2.new(0.5, 0.5), z = 12, thickness = 5 })
	local subtitle = pixelText({ parent = gui, text = "", size = UDim2.new(0.7, 0, 0, 40), position = UDim2.new(0.5, 0, 0.66, 56), anchor = Vector2.new(0.5, 0.5), z = 12, thickness = 4 })
	local badge = pixelText({ parent = gui, text = "", size = UDim2.new(0, 160, 0, 40), position = UDim2.new(0.5, 0, 0.66, -60), anchor = Vector2.new(0.5, 0.5), z = 12, color = GOLD, thickness = 4 })
	local hint = pixelText({ parent = gui, text = "", size = UDim2.new(0.5, 0, 0, 22), position = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 0.5), z = 12, thickness = 2 })
	for _, label in ipairs({ title, subtitle, badge }) do
		new("UIScale", { Name = "Pop", Parent = label })
	end
	return { gui = gui, tint = tint, flash = flash, bar = bar, strip = strip, pointer = pointer, title = title, subtitle = subtitle, badge = badge, hint = hint }
end

local COIN = 80
local function coin(strip, index, tierIndex, name)
	local tier = Config.Tiers[tierIndex]
	local c = new("Frame", { Position = UDim2.new(0, (index - 1) * COIN + 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, COIN - 12, 0, COIN - 12), BackgroundColor3 = tier.color, ZIndex = 6, Parent = strip }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = tier.color:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 4 }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170)) }),
	})
	-- the creature's initials, in pixel letters
	local initials = name:gsub("(%a)%a*%s*", "%1"):upper():sub(1, 2)
	pixelText({ parent = c, text = initials, size = UDim2.fromScale(0.7, 0.55), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 7, thickness = 3 })
	return c
end

-- A screen-facing halo of rounded rings round the egg that pulse outward (the reference's glowing rings).
local function ringHalo(adornee, color)
	local board = new("BillboardGui", { Name = "Rings", Size = UDim2.new(28, 0, 28, 0), LightInfluence = 0, AlwaysOnTop = false, Adornee = adornee, Parent = adornee })
	local rings = {}
	for i = 1, 5 do
		local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2), BackgroundTransparency = 1, Parent = board }, {
			new("UICorner", { CornerRadius = UDim.new(0.28, 0) }),
			new("UIStroke", { Color = color, Thickness = 8, Transparency = 0.1 }),
		})
		rings[i] = r
	end
	return board, rings
end

-- Light rays fanning out behind the creature, slowly turning.
local function rayBurst(adornee, color)
	local board = new("BillboardGui", { Name = "Rays", Size = UDim2.new(26, 0, 26, 0), LightInfluence = 0, AlwaysOnTop = false, Adornee = adornee, Parent = adornee })
	local spin = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = board })
	for i = 1, 12 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.07, 0, 0.5, 0), Rotation = i * 30, BackgroundColor3 = (i % 2 == 0) and color or WHITE, BorderSizePixel = 0, Parent = spin }, {
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 0.15) }) }),
		})
	end
	return board, spin
end

local function pop(label, scale)
	local s = label:FindFirstChild("Pop")
	if s then
		s.Scale = scale or 1.6
		TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local function groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return result and result.Position.Y or position.Y - 3
end

-- The scene ---------------------------------------------------------------------------------------------------

local playing = false

function HatchScene.playing()
	return playing
end

-- Plays the hatch for `result` ({ tier, creature, mutation, isNew, ... }). Yields until it finishes.
function HatchScene.play(result)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or playing then
		return
	end
	playing = true
	local tierIndex = math.clamp(tonumber(result.tier) or 1, 1, #Config.Tiers)
	local tier = Config.Tiers[tierIndex]
	local color = tier.color
	local mutation = nil
	for _, m in ipairs(Config.Mutations) do
		if m.id == result.mutation then
			mutation = m
		end
	end
	local rare = tierIndex >= 4
	local camera = workspace.CurrentCamera
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:FindFirstChild("TideboundUI")
	local hudWasOn = hud and hud.Enabled
	if hud then
		hud.Enabled = false
	end
	MotionBus.cutscene = true
	pcall(function()
		ProximityPromptService.Enabled = false
	end)
	local savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable

	local folder = Instance.new("Folder")
	folder.Name = "TideboundHatchFX"
	folder.Parent = workspace
	local ui = buildGui(playerGui)

	-- where the egg sits: a few studs in front of you, standing on the ground
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local spot = root.Position + look * 11
	local floorY = groundBelow(spot, { character, folder, Fx.folder() })
	local eggBase = Vector3.new(spot.X, floorY, spot.Z)
	local facing = CFrame.lookAt(eggBase, Vector3.new(root.Position.X, floorY, root.Position.Z))
	local egg = buildEgg(folder)
	local anchor = newPart(folder, "Anchor", Vector3.new(0.2, 0.2, 0.2), WHITE)
	anchor.Transparency = 1

	-- the camera's moves, shake and FOV, written every frame after everyone else's camera code
	local cam = {
		from = camera.CFrame.Position,
		at = eggBase + Vector3.new(0, 3, 0),
		fov = savedFov,
		shake = 0,
		orbit = nil, -- { center, radius, height, angle, speed }
	}
	local camGoal = nil
	local function shot(position, target, fov, seconds)
		camGoal = { fromPos = cam.from, fromAt = cam.at, fromFov = cam.fov, toPos = position, toAt = target, toFov = fov, start = os.clock(), seconds = seconds }
	end
	local function shake(amount)
		cam.shake = math.max(cam.shake, amount)
	end
	RunService:BindToRenderStep("TideboundHatchCamera", Enum.RenderPriority.Camera.Value + 10, function(dt)
		if camGoal then
			local s = smooth((os.clock() - camGoal.start) / math.max(camGoal.seconds, 0.01))
			cam.from = camGoal.fromPos:Lerp(camGoal.toPos, s)
			cam.at = camGoal.fromAt:Lerp(camGoal.toAt, s)
			cam.fov = camGoal.fromFov + (camGoal.toFov - camGoal.fromFov) * s
		end
		if cam.orbit then
			local o = cam.orbit
			o.angle += o.speed * dt
			cam.from = o.center + Vector3.new(math.cos(o.angle) * o.radius, o.height, math.sin(o.angle) * o.radius)
			cam.at = o.center + Vector3.new(0, o.lookY or 0, 0)
		end
		local jitter = Vector3.new((math.random() - 0.5), (math.random() - 0.5), (math.random() - 0.5)) * cam.shake
		cam.shake = math.max(0, cam.shake - dt * 2.2)
		camera.CFrame = CFrame.lookAt(cam.from + jitter, cam.at + jitter * 0.5) * CFrame.Angles(0, 0, (math.random() - 0.5) * cam.shake * 0.05)
		camera.FieldOfView = cam.fov
	end)

	local skip = false
	local canSkip = false
	local inputConn = UserInputService.InputBegan:Connect(function(input)
		if canSkip and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
			skip = true
		end
	end)

	local ok, err = pcall(function()
		-- 1. the egg drops in, the camera frames you and the egg, the coins slide down from the top
		local behind = root.Position - look * 7 + right * 3 + Vector3.new(0, 5, 0)
		shot(behind, eggBase + Vector3.new(0, 3, 0), 62, 0.6)
		TweenService:Create(ui.bar, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 24) }):Play()
		TweenService:Create(ui.tint, TweenInfo.new(0.6), { BackgroundTransparency = 0.75 }):Play()
		-- the slot strip: random creatures, landing on yours
		local slots = 44
		local landing = slots - 3
		for i = 1, slots do
			local t = (i == landing) and tierIndex or math.clamp(Random.new(i * 31 + tierIndex):NextInteger(1, 5), 1, #Config.Tiers)
			local names = Config.Tiers[t].creatures
			local name = (i == landing) and result.creature or names[(i % #names) + 1]
			coin(ui.strip, i, t, name)
		end
		ui.strip.Size = UDim2.new(0, slots * COIN, 1, 0)
		local endX = -((landing - 1) * COIN + COIN / 2) + 230
		ui.strip.Position = UDim2.new(0, 230 - COIN / 2, 0, 0)

		local dropStart = os.clock()
		local spinTween = TweenService:Create(ui.strip, TweenInfo.new(3.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, endX, 0, 0) })
		spinTween:Play()
		local lastCoin = 0
		Audio.play("Whoosh", root)

		local scale, wobble = 0.05, 0
		local stage = "drop"
		local stageAt = os.clock()
		local rings, ringBoard = nil, nil
		local function setStage(name)
			stage = name
			stageAt = os.clock()
		end
		local shakes = { 1.0, 2.0, 2.9 }
		local shook = 0
		local eggPivot = facing * CFrame.new(0, 2.4, 0)

		-- drive the egg until it bursts
		while true do
			local dt = RunService.RenderStepped:Wait()
			local t = os.clock() - dropStart
			local u = os.clock() - stageAt
			-- the coins tick as they pass the pointer
			local passed = math.floor((-(ui.strip.Position.X.Offset) + 230) / COIN)
			if passed ~= lastCoin then
				lastCoin = passed
				ui.pointer.UIStroke.Color = (passed % 2 == 0) and WHITE or GOLD
			end
			if stage == "drop" then
				-- falls from above and lands with a squash
				local s = math.clamp(u / 0.45, 0, 1)
				local h = (1 - s * s) * 14
				scale = 1
				eggPivot = facing * CFrame.new(0, 2.4 + h, 0)
				if s >= 1 then
					Fx.ring(eggBase + Vector3.new(0, 0.2, 0), WHITE, 7, 0.5, 0.4)
					Fx.cubes(eggBase + Vector3.new(0, 0.5, 0), { WHITE, SHELL_SHADE }, { spread = 6, size = 0.5, life = 0.5, up = 0.3, count = 16, material = Enum.Material.SmoothPlastic })
					shake(0.5)
					Audio.play("LandHeavy", root)
					setStage("wait")
				end
			elseif stage == "wait" or stage == "shake" then
				-- three shakes, harder each time; each one cracks it and makes it bigger
				local nextShake = shakes[shook + 1]
				if nextShake and t >= nextShake then
					shook += 1
					setStage("shake")
					u = 0
					addCrack(egg, shook * 13 + tierIndex, shook == 3 and color or Color3.fromRGB(255, 250, 220))
					Fx.cubes(eggPivot.Position, { SHELL, SHELL_SHADE, SPOT }, { spread = 4 + shook * 2, size = 0.5, life = 0.5, up = 0.8, count = 8 + shook * 4, material = Enum.Material.SmoothPlastic })
					Fx.ring(eggBase + Vector3.new(0, 0.2, 0), shook == 3 and color or WHITE, 6 + shook * 2, 0.4, 0.3)
					shake(0.35 + shook * 0.3)
					Audio.play("HitThud", root)
					-- the camera pushes in a little closer each time
					local d = 13 - shook * 2.2
					shot(eggBase + (root.Position - eggBase).Unit * d + right * (2.5 - shook * 0.6) + Vector3.new(0, 4.2 - shook * 0.5, 0), eggPivot.Position, 60 - shook * 4, 0.35)
				end
				local strength = 0.18 + shook * 0.14
				wobble = (stage == "shake" and u < 0.55) and math.sin(u * 38) * strength * (1 - u / 0.55) or wobble * 0.85
				scale += ((1 + shook * 0.16) - scale) * math.min(1, dt * 10)
				local hop = (stage == "shake" and u < 0.3) and math.sin(u / 0.3 * math.pi) * 0.6 * shook or 0
				eggPivot = facing * CFrame.new(0, 2.4 * scale + hop, 0) * CFrame.Angles(wobble * 0.4, 0, wobble)
				egg.light.Brightness = shook * 0.6
				if shook >= 3 and u > 0.6 then
					-- 2. it swells and glows in the rarity's colour, rings pulse out, the screen darkens
					setStage("charge")
					ringBoard, rings = ringHalo(anchor, color)
					for _, crack in ipairs(egg.cracks) do
						crack.Color = color
					end
					egg.light.Color = color
					shot(eggBase + (root.Position - eggBase).Unit * 8.5 + right * 1.2 + Vector3.new(0, 2.6, 0), eggBase + Vector3.new(0, 5, 0), 50, 0.9)
					TweenService:Create(ui.tint, TweenInfo.new(0.8), { BackgroundTransparency = 0.45 }):Play()
					Audio.play("RevealHum", root)
				end
			elseif stage == "charge" then
				local s = math.clamp(u / 1.3, 0, 1)
				scale = 1.48 + 0.9 * smooth(s) + 0.05 * math.sin(u * 30)
				local tremble = (0.04 + 0.12 * s) * math.sin(u * 55)
				eggPivot = facing * CFrame.new(0, 2.4 * scale, 0) * CFrame.Angles(tremble, 0, tremble * 1.3)
				egg.light.Brightness = 1.5 + 4 * s
				egg.light.Range = 14 + 20 * s
				for _, piece in ipairs(egg.pieces) do
					if piece.part.Name ~= "Crack" and piece.part.Name ~= "Face" then
						piece.part.Color = piece.part.Color:Lerp(color:Lerp(WHITE, 0.4), dt * 1.2 * s)
					end
				end
				egg.mark.TextColor3 = color:Lerp(WHITE, 0.5 + 0.5 * math.sin(u * 20))
				shake(0.15 + 0.35 * s)
				-- the rings pulse outward in waves
				if rings then
					for i, r in ipairs(rings) do
						local phase = (u * (1.4 + s) + i / #rings) % 1
						r.Size = UDim2.fromScale(0.15 + phase * 0.85, 0.15 + phase * 0.85)
						r.UIStroke.Transparency = phase
						r.UIStroke.Thickness = 10 - phase * 6
					end
				end
				if os.clock() % 0.18 < dt then
					Fx.cubes(eggPivot.Position, { color, WHITE }, { spread = 3 + 6 * s, size = 0.35, life = 0.4, up = 1, count = 3 })
				end
				if s >= 1 then
					break
				end
			end
			anchor.CFrame = CFrame.new(eggPivot.Position)
			poseEgg(egg, eggPivot, scale)
		end

		-- 3. BURST: flash, shell chunks, a storm of yellow sparkles, lightning and shock rings
		local burstAt = eggPivot.Position
		egg.model:Destroy()
		if ringBoard then
			ringBoard:Destroy()
		end
		ui.flash.BackgroundTransparency = 0
		TweenService:Create(ui.flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(ui.tint, TweenInfo.new(0.5), { BackgroundTransparency = 0.7 }):Play()
		Fx.cubes(burstAt, { SHELL, SHELL_SHADE, SPOT, WHITE }, { spread = 22, size = 1.2, life = 1.1, up = 0.9, count = 40, material = Enum.Material.SmoothPlastic })
		Fx.cubes(burstAt, { GOLD, Color3.fromRGB(255, 250, 160), color }, { spread = 26, size = 0.7, life = 1.3, up = 1, count = 50 })
		Fx.stars(burstAt, rare and 18 or 12, GOLD)
		Fx.bolts(burstAt, rare and 10 or 6)
		for i = 0, 3 do
			task.delay(i * 0.12, function()
				Fx.ring(Vector3.new(burstAt.X, floorY + 0.3, burstAt.Z), (i % 2 == 0) and GOLD or color, 14 + i * 6, 0.7, 0.6)
			end)
		end
		Audio.play("Celebrate", root)
		Audio.play("Tier" .. tier.id, root)
		shake(rare and 2.4 or 1.6)
		-- the camera kicks back, then settles into a slow orbit round the creature
		shot(burstAt + (root.Position - eggBase).Unit * 15 + Vector3.new(0, 4, 0), burstAt, 76, 0.12)
		task.wait(0.15)

		-- 4. the creature: spinning in the light, rays behind it, its rarity and name in big letters
		local creatureAt = eggBase + Vector3.new(0, 4, 0)
		local creature = CreatureModels.build(tierIndex, result.mutation, CFrame.new(creatureAt), 5)
		creature.Parent = folder
		local body = creature.PrimaryPart
		local rays, raySpin = rayBurst(anchor, color)
		anchor.CFrame = CFrame.new(creatureAt - (camera.CFrame.Position - creatureAt).Unit * 3)
		local toCam = (root.Position - eggBase).Unit
		cam.orbit = { center = creatureAt, radius = 11, height = 2.5, angle = math.atan2(toCam.Z, toCam.X), speed = 0.35, lookY = 0.5 }
		camGoal = nil
		cam.fov = 60
		ui.title.Text = tier.id:upper() .. "!"
		ui.title.TextColor3 = color
		ui.subtitle.Text = result.creature
		ui.subtitle.TextColor3 = WHITE
		pop(ui.title, 2.2)
		task.delay(0.15, pop, ui.subtitle, 1.8)
		local badgeBits = {}
		if result.isNew then
			table.insert(badgeBits, "NEW!")
		end
		if mutation and mutation.id ~= "None" then
			table.insert(badgeBits, mutation.id:upper())
			ui.badge.TextColor3 = mutation.color
		end
		ui.badge.Text = table.concat(badgeBits, " · ")
		if ui.badge.Text ~= "" then
			task.delay(0.3, pop, ui.badge, 1.8)
		end
		ui.hint.Text = "click to continue"
		local hold = 2.6 + math.max(0, tierIndex - 3) * 0.6
		local revealStart = os.clock()
		local nextConfetti = 0
		canSkip = false
		while true do
			RunService.RenderStepped:Wait()
			local u = os.clock() - revealStart
			if u > 0.6 then
				canSkip = true
			end
			-- pops up, then bobs and spins
			local rise = smooth(u / 0.35)
			local s = 0.2 + 0.8 * rise + 0.12 * math.max(0, 1 - u / 0.5) * math.sin(u * 30)
			body.CFrame = CFrame.new(creatureAt + Vector3.new(0, math.sin(u * 2.4) * 0.4, 0)) * CFrame.Angles(0, u * 1.6, 0)
			if creature:GetScale() ~= s then
				creature:ScaleTo(math.max(0.05, s))
			end
			raySpin.Rotation = u * 25
			anchor.CFrame = CFrame.new(creatureAt - (camera.CFrame.Position - creatureAt).Unit * 3)
			ui.title.Rotation = math.sin(u * 3) * 3
			if rare and u > (nextConfetti or 0) then
				nextConfetti = u + 0.25
				Fx.cubes(creatureAt + Vector3.new(0, 6, 0), { color, GOLD, WHITE, Color3.fromRGB(255, 120, 200) }, { spread = 12, size = 0.5, life = 1.4, up = 0.2, count = 6 })
			end
			if tierIndex >= 5 and u % 0.9 < 0.02 then
				Fx.ring(Vector3.new(creatureAt.X, floorY + 0.3, creatureAt.Z), color, 12, 0.6, 0.4)
			end
			if skip or u > hold + 4 or (u > hold and not rare) then
				break
			end
		end
		rays:Destroy()
		Fx.cubes(creatureAt, { color, WHITE }, { spread = 8, size = 0.5, life = 0.5, count = 16 })
	end)
	if not ok then
		warn("[HatchScene]", err)
	end

	-- hand everything back
	RunService:UnbindFromRenderStep("TideboundHatchCamera")
	inputConn:Disconnect()
	folder:Destroy()
	ui.gui:Destroy()
	camera.FieldOfView = savedFov
	if root.Parent then
		camera.CFrame = CFrame.lookAt(root.Position - root.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), root.Position + Vector3.new(0, 1.5, 0))
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	pcall(function()
		ProximityPromptService.Enabled = true
	end)
	if hud and hudWasOn then
		hud.Enabled = true
	end
	MotionBus.cutscene = false
	playing = false
end

-- The pixel odds card over the Tide Egg Shrine ---------------------------------------------------------------

local function oddsCard(adornee)
	if adornee:FindFirstChild("OddsCard") then
		return
	end
	local board = new("BillboardGui", { Name = "OddsCard", Size = UDim2.new(9, 0, 12, 0), StudsOffset = Vector3.new(0, 11.5, 0), MaxDistance = 70, LightInfluence = 0, Adornee = adornee, Parent = adornee })
	local panel = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 20, 40), BackgroundTransparency = 0.08, Parent = board }, {
		new("UICorner", { CornerRadius = UDim.new(0.06, 0) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 120, 150), Thickness = 4 }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 120, 140), Color3.fromRGB(140, 40, 70)) }),
	})
	pixelText({ parent = panel, text = "TIDE EGG", size = UDim2.new(0.9, 0, 0.09, 0), position = UDim2.new(0.5, 0, 0.03, 0), anchor = Vector2.new(0.5, 0), color = Color3.fromRGB(255, 230, 230), stroke = Color3.fromRGB(80, 10, 20) })
	pixelText({ parent = panel, text = "x1", size = UDim2.new(0.3, 0, 0.06, 0), position = UDim2.new(0.5, 0, 0.125, 0), anchor = Vector2.new(0.5, 0), color = WHITE })
	local list = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.06, 0, 0.2, 0), Size = UDim2.new(0.88, 0, 0.64, 0), Parent = panel }, {
		new("UIListLayout", { Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, tier in ipairs(Config.Tiers) do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.13, 0), LayoutOrder = i, Parent = list })
		local icon = new("Frame", { Size = UDim2.new(0.16, 0, 0.9, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = tier.color, Parent = row }, {
			new("UIStroke", { Color = tier.color:Lerp(Color3.new(0, 0, 0), 0.5), Thickness = 2 }),
		})
		pixelText({ parent = icon, text = tier.creatures[1]:sub(1, 1), size = UDim2.fromScale(0.8, 0.8), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), thickness = 2 })
		pixelText({ parent = row, text = tier.id:upper(), size = UDim2.new(0.5, 0, 0.62, 0), position = UDim2.new(0.18, 0, 0.5, 0), anchor = Vector2.new(0, 0.5), color = tier.color:Lerp(WHITE, 0.3), thickness = 2 })
		local pct = tier.rate >= 1 and ("%d%%"):format(math.floor(tier.rate + 0.5)) or (tostring(tier.rate) .. "%")
		pixelText({ parent = row, text = pct, size = UDim2.new(0.3, 0, 0.8, 0), position = UDim2.new(1, 0, 0.5, 0), anchor = Vector2.new(1, 0.5), color = tier.color:Lerp(WHITE, 0.15), thickness = 3 })
	end
	pixelText({ parent = panel, text = "CONTAINS A RANDOM", size = UDim2.new(0.9, 0, 0.045, 0), position = UDim2.new(0.5, 0, 0.86, 0), anchor = Vector2.new(0.5, 0), color = WHITE, thickness = 2 })
	pixelText({ parent = panel, text = "TIDEBOUND CREATURE", size = UDim2.new(0.9, 0, 0.05, 0), position = UDim2.new(0.5, 0, 0.91, 0), anchor = Vector2.new(0.5, 0), color = GOLD, thickness = 2 })
end

-- Hangs the odds card over every Tide Egg Shrine egg as it streams in.
function HatchScene.mountBoards()
	task.spawn(function()
		while true do
			local world = workspace:FindFirstChild("TideboundWorld")
			local nest = world and world:FindFirstChild("Nest")
			local egg = nest and nest:FindFirstChild("ShrineEgg")
			if egg and egg:IsA("BasePart") then
				oddsCard(egg)
			end
			task.wait(2)
		end
	end)
end

return HatchScene
