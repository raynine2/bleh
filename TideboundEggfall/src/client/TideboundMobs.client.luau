-- Tidebound: Eggfall: draws the wild mobs of the Open Isles on your screen (Patch 10). The server (Mobs) thinks
-- and writes each mob's attributes in ReplicatedStorage.Tidebound.MobState; this script builds a chunky voxel
-- body for each one near the camera, glides it smoothly to where the server says it is, and animates it:
--   Snapper Crab   scuttles sideways on six legs, raises its claws to snap
--   Spike Puffer   bobs and wiggles its fins, swells up red before it blasts
--   Raider Gull    flaps in circles, screeches with its wings up, folds them and dives
--   Reef Shark     only its fin shows while it patrols; it rears out of the water to bite
--   Coral Golem    lumbers, lifts both fists over its head, slams the ground
-- Every attack is telegraphed: a red "!" over its head, and for blasts a red circle on the ground that fills up
-- before it goes off. Hits flash it white and knock out cubes; a beaten mob bursts and pops back later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))

local camera = workspace.CurrentCamera

local SHOW_RANGE = 280
local HIDE_RANGE = 330
local RED = Color3.fromRGB(255, 52, 52)
local YELLOW = Color3.fromRGB(255, 220, 60)
local WHITE = Color3.new(1, 1, 1)
local HIT_WORDS = { { "HIT!", "OOF!", "BONK!" }, { "SPUN!", "WHEE!", "DIZZY!" }, { "SLAPPED!", "FLATTENED!", "OUCHIE!!" } } -- Patch 17

local folder = Instance.new("Folder")
folder.Name = "TideboundMobs"
folder.Parent = workspace

local function now()
	return workspace:GetServerTimeNow()
end

local function newPart(model, name, size, color, shape, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Bodies --------------------------------------------------------------------------------------------------------
-- Each builder returns a list of { part, offset, role } pieces; the animator moves each piece's offset by role.

local BUILD = {}

function BUILD.crab(model)
	local shell, dark, claw = Color3.fromRGB(232, 92, 60), Color3.fromRGB(190, 64, 44), Color3.fromRGB(250, 130, 90)
	local pieces = {}
	local function add(p, offset, role)
		table.insert(pieces, { part = p, offset = offset, role = role })
	end
	add(newPart(model, "Body", Vector3.new(3.2, 1.4, 2.6), shell), CFrame.new(0, 1.2, 0), "body")
	add(newPart(model, "Shell", Vector3.new(2.6, 0.6, 2), dark), CFrame.new(0, 2.05, 0.1), "body")
	for _, side in ipairs({ -1, 1 }) do
		add(newPart(model, "Claw", Vector3.new(1.2, 1, 1.5), claw), CFrame.new(side * 2.1, 1.5, -1.4), side < 0 and "clawL" or "clawR")
		add(newPart(model, "Pincer", Vector3.new(0.6, 0.5, 1), Color3.fromRGB(255, 220, 200)), CFrame.new(side * 2.2, 1.9, -2.2), side < 0 and "clawL" or "clawR")
		add(newPart(model, "Stalk", Vector3.new(0.25, 0.9, 0.25), shell), CFrame.new(side * 0.5, 2.3, -0.9), "body")
		add(newPart(model, "Eye", Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(20, 20, 26), Enum.PartType.Ball), CFrame.new(side * 0.5, 2.85, -0.9), "body")
		for leg = -1, 1 do
			add(newPart(model, "Leg", Vector3.new(1.5, 0.3, 0.3), dark), CFrame.new(side * 1.9, 0.7, leg * 0.8) * CFrame.Angles(0, 0, side * -0.55), "leg" .. ((leg + side) % 2 == 0 and "A" or "B"))
		end
	end
	return pieces, 3.4
end

function BUILD.puffer(model)
	local skin, belly, spike = Color3.fromRGB(250, 214, 80), Color3.fromRGB(255, 244, 200), Color3.fromRGB(230, 160, 60)
	local pieces = {}
	local function add(p, offset, role)
		table.insert(pieces, { part = p, offset = offset, role = role })
	end
	add(newPart(model, "Body", Vector3.new(2.6, 2.4, 2.6), skin, Enum.PartType.Ball), CFrame.new(), "swell")
	add(newPart(model, "Belly", Vector3.new(2, 1.2, 2), belly, Enum.PartType.Ball), CFrame.new(0, -0.6, -0.2), "swell")
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local b = (i % 2 == 0) and 0.5 or -0.3
		add(newPart(model, "Spike", Vector3.new(0.3, 0.3, 0.9), spike), CFrame.lookAt(Vector3.zero, Vector3.new(math.cos(a), b, math.sin(a))) * CFrame.new(0, 0, -1.3), "spike")
	end
	for _, side in ipairs({ -1, 1 }) do
		add(newPart(model, "Eye", Vector3.new(0.6, 0.6, 0.4), WHITE, Enum.PartType.Ball), CFrame.new(side * 0.6, 0.4, -1.15), "swell")
		add(newPart(model, "Pupil", Vector3.new(0.3, 0.3, 0.2), Color3.fromRGB(20, 20, 26), Enum.PartType.Ball), CFrame.new(side * 0.6, 0.4, -1.32), "swell")
		add(newPart(model, "Fin", Vector3.new(0.2, 0.8, 0.9), spike), CFrame.new(side * 1.35, 0, 0.1), side < 0 and "finL" or "finR")
	end
	add(newPart(model, "Tail", Vector3.new(0.2, 1, 0.9), spike), CFrame.new(0, 0, 1.5), "tail")
	return pieces, 3
end

function BUILD.gull(model)
	local white, grey, beak = Color3.fromRGB(246, 246, 250), Color3.fromRGB(150, 160, 176), Color3.fromRGB(255, 170, 50)
	local pieces = {}
	local function add(p, offset, role)
		table.insert(pieces, { part = p, offset = offset, role = role })
	end
	add(newPart(model, "Body", Vector3.new(1.4, 1.3, 3), white), CFrame.new(), "body")
	add(newPart(model, "Head", Vector3.new(1.1, 1.1, 1.1), white), CFrame.new(0, 0.5, -1.7), "body")
	add(newPart(model, "Beak", Vector3.new(0.35, 0.3, 0.9), beak), CFrame.new(0, 0.35, -2.6), "body")
	for _, side in ipairs({ -1, 1 }) do
		add(newPart(model, "Wing", Vector3.new(3.6, 0.2, 1.6), grey), CFrame.new(side * 2.4, 0.3, 0), side < 0 and "wingL" or "wingR")
		add(newPart(model, "WingTip", Vector3.new(1.4, 0.18, 1.2), Color3.fromRGB(40, 40, 46)), CFrame.new(side * 4.6, 0.3, 0.1), side < 0 and "wingL" or "wingR")
		add(newPart(model, "Eye", Vector3.new(0.25, 0.3, 0.2), RED, Enum.PartType.Ball, Enum.Material.Neon), CFrame.new(side * 0.45, 0.7, -2.15), "body")
	end
	add(newPart(model, "Tail", Vector3.new(1.2, 0.2, 1), grey), CFrame.new(0, 0.1, 1.9), "body")
	return pieces, 3
end

function BUILD.shark(model)
	local skin, belly = Color3.fromRGB(96, 116, 136), Color3.fromRGB(220, 226, 230)
	local pieces = {}
	local function add(p, offset, role)
		table.insert(pieces, { part = p, offset = offset, role = role })
	end
	add(newPart(model, "Body", Vector3.new(2.6, 2.4, 8), skin), CFrame.new(0, -1.2, 0), "rear")
	add(newPart(model, "Belly", Vector3.new(2.2, 0.8, 7), belly), CFrame.new(0, -2.3, -0.3), "rear")
	add(newPart(model, "Snout", Vector3.new(2, 1.8, 2.4), skin), CFrame.new(0, -1, -4.8), "rear")
	add(newPart(model, "Jaw", Vector3.new(1.8, 0.5, 2), Color3.fromRGB(200, 60, 70)), CFrame.new(0, -2, -4.6), "jaw")
	add(newPart(model, "Fin", Vector3.new(0.4, 2.6, 2.4), skin), CFrame.new(0, 1.1, 0.4) * CFrame.Angles(math.rad(-20), 0, 0), "rear")
	add(newPart(model, "Tail", Vector3.new(0.4, 3, 1.6), skin), CFrame.new(0, -0.8, 4.8), "tail")
	for _, side in ipairs({ -1, 1 }) do
		add(newPart(model, "Eye", Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(20, 20, 26), Enum.PartType.Ball), CFrame.new(side * 0.95, -0.7, -5.3), "rear")
		add(newPart(model, "SideFin", Vector3.new(2.2, 0.3, 1.4), skin), CFrame.new(side * 2, -2, -1.4) * CFrame.Angles(0, 0, side * 0.3), "rear")
	end
	return pieces, 4
end

function BUILD.golem(model)
	local stone, coral, glow = Color3.fromRGB(150, 128, 140), Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 90, 170)
	local pieces = {}
	local function add(p, offset, role)
		table.insert(pieces, { part = p, offset = offset, role = role })
	end
	add(newPart(model, "Torso", Vector3.new(4.4, 4, 3.2), stone), CFrame.new(0, 5.2, 0), "torso")
	add(newPart(model, "Head", Vector3.new(2.4, 2, 2.2), stone), CFrame.new(0, 8, -0.3), "torso")
	add(newPart(model, "Core", Vector3.new(1.4, 1.4, 0.4), glow, nil, Enum.Material.Neon), CFrame.new(0, 5.4, -1.65), "torso")
	for _, side in ipairs({ -1, 1 }) do
		add(newPart(model, "Eye", Vector3.new(0.5, 0.4, 0.3), glow, nil, Enum.Material.Neon), CFrame.new(side * 0.55, 8.2, -1.42), "torso")
		add(newPart(model, "Arm", Vector3.new(1.6, 3.6, 1.6), stone), CFrame.new(side * 3.1, 4.6, 0), side < 0 and "armL" or "armR")
		add(newPart(model, "Fist", Vector3.new(2.2, 2, 2.2), coral), CFrame.new(side * 3.1, 2.3, 0), side < 0 and "armL" or "armR")
		add(newPart(model, "Leg", Vector3.new(1.7, 3.2, 1.8), stone), CFrame.new(side * 1.2, 1.6, 0), side < 0 and "legL" or "legR")
		add(newPart(model, "CoralSpike", Vector3.new(0.6, 1.6, 0.6), coral), CFrame.new(side * 1.4, 7.6, 0.8) * CFrame.Angles(0, 0, side * -0.4), "torso")
	end
	return pieces, 6
end

-- Records ---------------------------------------------------------------------------------------------------

local records = {} -- [Configuration] = record

local function label(rec)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MobLabel"
	gui.Size = UDim2.new(0, 120, 0, 30)
	gui.StudsOffset = Vector3.new(0, rec.height + 1.6, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 16)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = rec.inst:GetAttribute("Title") or ""
	name.TextColor3 = Color3.fromRGB(255, 200, 160)
	name.TextStrokeTransparency = 0
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0.1, 0, 0, 18)
	back.Size = UDim2.new(0.8, 0, 0, 7)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 90, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	gui.Adornee = rec.pieces[1].part
	gui.Parent = rec.model
	rec.gui, rec.fill = gui, fill
end

local function build(inst)
	local kind = inst:GetAttribute("Kind")
	local builder = BUILD[kind]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = kind
	local pieces, height = builder(model)
	local pos = inst:GetAttribute("Pos") or Vector3.zero
	local rec = {
		inst = inst,
		kind = kind,
		model = model,
		pieces = pieces,
		height = height,
		pos = pos,
		yaw = inst:GetAttribute("Yaw") or 0,
		seed = math.random() * 10,
		state = inst:GetAttribute("State"),
		stateAt = inst:GetAttribute("StateAt") or 0,
		seenHit = inst:GetAttribute("HitAt"),
		seenSpawn = inst:GetAttribute("SpawnAt"),
		walk = 0,
		visible = true,
	}
	model.Parent = folder
	label(rec)
	return rec
end

local function destroy(rec)
	if rec.telegraph then
		rec.telegraph:Destroy()
	end
	rec.model:Destroy()
end

local function setVisible(rec, visible)
	if rec.visible == visible then
		return
	end
	rec.visible = visible
	for _, piece in ipairs(rec.pieces) do
		piece.part.Transparency = visible and 0 or 1
	end
	rec.gui.Enabled = visible
end

-- Telegraphs ------------------------------------------------------------------------------------------------

local function groundY(position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, Fx.folder() }
	local result = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
	return result and result.Position.Y or position.Y
end

-- A red circle on the ground that fills from the middle out over `seconds` (a blast's wind-up).
local function fillCircle(rec, center, radius, seconds)
	if rec.telegraph then
		rec.telegraph:Destroy()
	end
	local y = groundY(center) + 0.15
	local model = Instance.new("Model")
	model.Name = "Telegraph"
	local edge = newPart(model, "Edge", Vector3.new(0.12, radius * 2, radius * 2), RED, Enum.PartType.Cylinder, Enum.Material.Neon)
	edge.CFrame = CFrame.new(center.X, y, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	edge.Transparency = 0.6
	edge.CastShadow = false
	local fill = newPart(model, "Fill", Vector3.new(0.16, 0.2, 0.2), RED, Enum.PartType.Cylinder, Enum.Material.Neon)
	fill.CFrame = edge.CFrame
	fill.Transparency = 0.35
	fill.CastShadow = false
	model.Parent = folder
	TweenService:Create(fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = Vector3.new(0.16, radius * 2, radius * 2) }):Play()
	rec.telegraph = model
	Debris:AddItem(model, seconds + 0.6)
end

local function clearTelegraph(rec, burst)
	local model = rec.telegraph
	rec.telegraph = nil
	if not model or not model.Parent then
		return
	end
	if burst then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") then
				p.Color = WHITE
				TweenService:Create(p, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(model, 0.3)
	else
		model:Destroy()
	end
end

local COLORS = {
	crab = { Color3.fromRGB(232, 92, 60), Color3.fromRGB(255, 200, 160) },
	puffer = { Color3.fromRGB(250, 214, 80), Color3.fromRGB(230, 160, 60) },
	gull = { Color3.fromRGB(246, 246, 250), Color3.fromRGB(150, 160, 176) },
	shark = { Color3.fromRGB(96, 116, 136), Color3.fromRGB(200, 240, 255) },
	golem = { Color3.fromRGB(150, 128, 140), Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 90, 170) },
}

-- What happens the moment a mob's state changes (alerts, rings, bursts, sounds).
local function onState(rec, state, previous)
	local inst = rec.inst
	local body = rec.pieces[1].part
	local cfg = Config.Mobs.kinds[rec.kind]
	local center = rec.pos
	if state == "chase" and (previous == "idle" or previous == "return") then
		Fx.alert(body, "!", YELLOW, 0.8, rec.height * 0.5 + 1.2)
	elseif state == "tell" then
		Fx.alert(body, "!", RED, cfg.tell + 0.2, rec.height * 0.5 + 1.6)
		if rec.kind == "puffer" or rec.kind == "golem" then
			fillCircle(rec, inst:GetAttribute("TellPos") or center, cfg.radius, cfg.tell)
		end
		if (rec.pos - camera.CFrame.Position).Magnitude < 80 then
			Audio.play("TickTick", body)
		end
	elseif state == "dive" then
		local aim = inst:GetAttribute("TellPos")
		if aim then
			fillCircle(rec, aim, cfg.reach, 0.5)
		end
	elseif state == "strike" then
		if rec.kind == "puffer" or rec.kind == "golem" then
			local at = inst:GetAttribute("TellPos") or center
			local y = groundY(at)
			clearTelegraph(rec, true)
			Fx.ring(Vector3.new(at.X, y + 0.3, at.Z), rec.kind == "golem" and Color3.fromRGB(255, 120, 150) or Color3.fromRGB(255, 220, 90), cfg.radius + 1, 0.45, 0.5)
			Fx.cubes(Vector3.new(at.X, y + 1, at.Z), COLORS[rec.kind], { spread = cfg.radius, size = 0.6, life = 0.6, up = 0.7, count = 22 })
			if rec.kind == "golem" then
				Fx.cubes(Vector3.new(at.X, y + 0.5, at.Z), Color3.fromRGB(150, 128, 140), { spread = 6, size = 1, life = 0.7, up = 0.3, count = 10, material = Enum.Material.Slate })
			end
		elseif rec.kind == "gull" then
			clearTelegraph(rec, true)
			Fx.cubes(center, COLORS.gull, { spread = 4, size = 0.4, life = 0.5, count = 10 })
		elseif rec.kind == "shark" then
			Fx.cubes(center + Vector3.new(0, 1, 0), { Color3.fromRGB(200, 240, 255), WHITE }, { spread = 6, size = 0.6, life = 0.6, up = 1, count = 18, material = Enum.Material.SmoothPlastic })
			Fx.ring(Vector3.new(center.X, 4.2, center.Z), Color3.fromRGB(220, 250, 255), 6, 0.5, 0.3)
		else
			Fx.cubes(body.Position + body.CFrame.LookVector * 2, { WHITE, Color3.fromRGB(255, 200, 160) }, { spread = 3, size = 0.35, life = 0.35, count = 8 })
		end
	elseif state == "dead" then
		clearTelegraph(rec, false)
		Fx.cubes(body.Position, COLORS[rec.kind], { spread = 8, size = 0.7, life = 0.8, up = 0.9, count = 26 })
		Fx.stars(body.Position, 5)
		Fx.ring(Vector3.new(center.X, groundY(center) + 0.3, center.Z), WHITE, 6, 0.4, 0.3)
		setVisible(rec, false)
	elseif state == "idle" or state == "return" or state == "chase" or state == "hurt" then
		if previous == "tell" then
			clearTelegraph(rec, false)
		end
	end
	if previous == "dead" and state ~= "dead" then
		setVisible(rec, true)
	end
end

-- Animation -------------------------------------------------------------------------------------------------

local function smooth(s)
	s = math.clamp(s, 0, 1)
	return s * s * (3 - 2 * s)
end

local function animate(rec, t, dt)
	local state = rec.state
	local since = now() - rec.stateAt
	local cfg = Config.Mobs.kinds[rec.kind]
	local tellW = state == "tell" and smooth(since / math.max(cfg.tell, 0.1)) or 0
	local strikeW = state == "strike" and (1 - smooth(since / 0.45)) or 0
	local hurtW = state == "hurt" and (1 - smooth(since / 0.35)) or 0
	local walk = rec.walk
	local phase = t * (8 + walk * 6) + rec.seed
	local base = CFrame.new(rec.pos) * CFrame.Angles(0, rec.yaw, 0)
	-- a hit rocks the body back
	base *= CFrame.Angles(-0.4 * hurtW, 0, 0.2 * hurtW * math.sin(t * 40))

	local parts, cframes = {}, {}
	local kind = rec.kind
	if kind == "crab" then
		local bob = math.abs(math.sin(phase)) * 0.15 * walk
		local snap = math.sin(t * 30) * 0.3 * tellW
		for _, piece in ipairs(rec.pieces) do
			local cf = base * CFrame.new(0, bob, 0) * piece.offset
			if piece.role == "legA" or piece.role == "legB" then
				local s = piece.role == "legA" and 1 or -1
				cf = base * piece.offset * CFrame.Angles(0, 0.35 * math.sin(phase) * s * walk, 0.25 * math.cos(phase) * s * walk)
			elseif piece.role == "clawL" or piece.role == "clawR" then
				local side = piece.role == "clawL" and -1 or 1
				-- claws rise and open on the wind-up, then lunge forward on the snap
				cf = base * CFrame.new(0, bob + 1.4 * tellW, -1.6 * strikeW) * piece.offset * CFrame.Angles(0.6 * tellW + snap, 0, side * 0.3 * tellW)
			end
			table.insert(parts, piece.part)
			table.insert(cframes, cf)
		end
	elseif kind == "puffer" then
		-- swells to twice its size and glows red on the wind-up, stays big for a moment after the blast
		local swell = 1 + tellW * 0.9 + (state == "strike" and 0.9 * (1 - smooth(since / 0.8)) or 0)
		local bob = math.sin(t * 2 + rec.seed) * 0.25
		local shake = tellW * 0.15 * math.sin(t * 50)
		for _, piece in ipairs(rec.pieces) do
			local offset = piece.offset
			local cf
			if piece.role == "spike" then
				cf = base * CFrame.new(shake, bob, 0) * CFrame.new(offset.Position * swell) * offset.Rotation
			elseif piece.role == "finL" or piece.role == "finR" then
				local side = piece.role == "finL" and -1 or 1
				cf = base * CFrame.new(shake, bob, 0) * CFrame.new(offset.Position * swell) * CFrame.Angles(0, side * 0.6 * math.sin(t * 9 + rec.seed), 0)
			elseif piece.role == "tail" then
				cf = base * CFrame.new(shake, bob, 0) * CFrame.new(offset.Position * swell) * CFrame.Angles(0, 0.5 * math.sin(t * 6 + rec.seed), 0)
			else
				cf = base * CFrame.new(shake, bob, 0) * CFrame.new(offset.Position * swell) * offset.Rotation
			end
			table.insert(parts, piece.part)
			table.insert(cframes, cf)
		end
		local body = rec.pieces[1].part
		local target = Vector3.new(2.6, 2.4, 2.6) * swell
		if (body.Size - target).Magnitude > 0.05 then
			body.Size = target
			rec.pieces[2].part.Size = Vector3.new(2, 1.2, 2) * swell
		end
		body.Color = Color3.fromRGB(250, 214, 80):Lerp(Color3.fromRGB(255, 70, 50), tellW)
	elseif kind == "gull" then
		local diving = state == "dive"
		local flap = diving and 0 or math.sin(t * (state == "tell" and 22 or 9) + rec.seed)
		local pitch = diving and -0.9 or (state == "tell" and 0.3 or 0)
		local bank = rec.turn or 0
		for _, piece in ipairs(rec.pieces) do
			local cf = base * CFrame.Angles(pitch, 0, bank) * piece.offset
			if piece.role == "wingL" or piece.role == "wingR" then
				local side = piece.role == "wingL" and -1 or 1
				local lift = diving and 1.2 or (state == "tell" and 1.0 or 0) + 0.55 * flap
				local pivot = CFrame.new(side * 0.6, 0.3, 0)
				local local_ = pivot * CFrame.Angles(0, 0, side * lift) * pivot:Inverse() * piece.offset
				cf = base * CFrame.Angles(pitch, 0, bank) * local_
			end
			table.insert(parts, piece.part)
			table.insert(cframes, cf)
		end
	elseif kind == "shark" then
		-- under the surface only the fin shows; it rears up out of the water to bite
		local rear = tellW * 0.6 + strikeW
		local lift = 1.6 * rear
		local sway = math.sin(t * 4 + rec.seed) * 0.12
		for _, piece in ipairs(rec.pieces) do
			local cf = base * CFrame.new(0, lift, 0) * CFrame.Angles(0.5 * rear, sway, 0) * piece.offset
			if piece.role == "tail" then
				cf = base * CFrame.new(0, lift, 0) * CFrame.Angles(0.5 * rear, sway, 0) * piece.offset * CFrame.Angles(0, 0.6 * math.sin(t * 7 + rec.seed), 0)
			elseif piece.role == "jaw" then
				cf = base * CFrame.new(0, lift, 0) * CFrame.Angles(0.5 * rear, sway, 0) * piece.offset * CFrame.new(0, -0.6 * rear, 0)
			end
			table.insert(parts, piece.part)
			table.insert(cframes, cf)
		end
	elseif kind == "golem" then
		local step = math.sin(phase * 0.6)
		local stomp = math.abs(step) * 0.2 * walk
		local raise = tellW
		local slam = state == "strike" and (1 - smooth(since / 0.25)) or 0
		for _, piece in ipairs(rec.pieces) do
			local cf = base * CFrame.new(0, stomp, 0) * piece.offset
			if piece.role == "armL" or piece.role == "armR" then
				local side = piece.role == "armL" and -1 or 1
				local shoulder = CFrame.new(side * 3.1, 6.4, 0)
				local swing = -0.5 * step * walk * side + raise * 2.9 - slam * 0.4
				cf = base * CFrame.new(0, stomp, 0) * shoulder * CFrame.Angles(swing, 0, side * 0.15 * raise) * shoulder:Inverse() * piece.offset
			elseif piece.role == "legL" or piece.role == "legR" then
				local side = piece.role == "legL" and -1 or 1
				local hip = CFrame.new(side * 1.2, 3.2, 0)
				cf = base * hip * CFrame.Angles(0.45 * step * walk * side, 0, 0) * hip:Inverse() * piece.offset
			elseif piece.role == "torso" then
				cf = base * CFrame.new(0, stomp - 0.4 * slam, 0) * CFrame.Angles(0.15 * raise - 0.3 * slam, 0, 0) * piece.offset
			end
			table.insert(parts, piece.part)
			table.insert(cframes, cf)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Every frame ---------------------------------------------------------------------------------------------

local stateFolder = Shared:WaitForChild("MobState", 60)

local function angleLerp(a, b, s)
	local d = (b - a + math.pi) % (math.pi * 2) - math.pi
	return a + d * s
end

RunService.RenderStepped:Connect(function(dt)
	if not stateFolder then
		return
	end
	local t = os.clock()
	local camPos = camera.CFrame.Position
	local seen = {}
	for _, inst in ipairs(stateFolder:GetChildren()) do
		seen[inst] = true
		local pos = inst:GetAttribute("Pos")
		if typeof(pos) == "Vector3" then
			local distance = (pos - camPos).Magnitude
			local rec = records[inst]
			if not rec and distance < SHOW_RANGE then
				rec = build(inst)
				records[inst] = rec
				if rec and rec.state == "dead" then
					setVisible(rec, false)
				end
			elseif rec and distance > HIDE_RANGE then
				destroy(rec)
				records[inst] = nil
				rec = nil
			end
			if rec then
				-- glide toward the server's position (snap on a respawn or a long jump)
				local before = rec.pos
				if (pos - rec.pos).Magnitude > 40 then
					rec.pos = pos
				else
					rec.pos = rec.pos:Lerp(pos, 1 - math.exp(-dt * 12))
				end
				local moved = (Vector3.new(rec.pos.X, 0, rec.pos.Z) - Vector3.new(before.X, 0, before.Z)).Magnitude / math.max(dt, 1 / 240)
				rec.walk += (math.clamp(moved / 8, 0, 1) - rec.walk) * math.min(1, dt * 8)
				local yaw = inst:GetAttribute("Yaw") or rec.yaw
				local previousYaw = rec.yaw
				rec.yaw = angleLerp(rec.yaw, yaw, 1 - math.exp(-dt * 10))
				rec.turn = math.clamp(((rec.yaw - previousYaw + math.pi) % (math.pi * 2) - math.pi) / math.max(dt, 1 / 240) * -0.25, -0.6, 0.6)

				local state = inst:GetAttribute("State")
				if state ~= rec.state then
					local previous = rec.state
					rec.state = state
					rec.stateAt = inst:GetAttribute("StateAt") or now()
					onState(rec, state, previous)
				end
				local hitAt = inst:GetAttribute("HitAt")
				if hitAt ~= rec.seenHit then
					rec.seenHit = hitAt
					if hitAt and now() - hitAt < 1 then
						local body = rec.pieces[1].part
						-- Patch 17: the combo's slam (HitStep 3) lands a much bigger hit
						local step = inst:GetAttribute("HitStep") or 1
						Fx.flashModel(rec.model, WHITE, step == 3 and 0.4 or 0.25)
						Fx.cubes(body.Position, { WHITE, YELLOW, COLORS[rec.kind][1] }, { spread = step == 3 and 7 or 4, size = step == 3 and 0.6 or 0.4, life = 0.4, count = step == 3 and 18 or 10 })
						Fx.number(body, HIT_WORDS[step][math.random(1, #HIT_WORDS[step])], step == 3 and Color3.fromRGB(255, 120, 60) or YELLOW)
						if step == 3 then
							Fx.stars(body.Position + Vector3.new(0, 1.5, 0), 5)
						end
						Audio.play("HitThud", body, step == 3 and 0.8 or math.random(95, 125) / 100)
					end
				end
				local spawnAt = inst:GetAttribute("SpawnAt")
				if spawnAt ~= rec.seenSpawn then
					rec.seenSpawn = spawnAt
					if spawnAt and now() - spawnAt < 2 then
						Fx.cubes(rec.pos + Vector3.new(0, 1, 0), { WHITE, Color3.fromRGB(200, 240, 255) }, { spread = 4, size = 0.5, life = 0.5, count = 14 })
					end
				end
				if rec.visible then
					local hp, maxHp = inst:GetAttribute("Hp") or 1, inst:GetAttribute("MaxHp") or 1
					rec.fill.Size = UDim2.new(math.clamp(hp / maxHp, 0, 1), 0, 1, 0)
					rec.gui.Enabled = distance < 70 and (hp < maxHp or (state ~= "idle" and state ~= "return"))
					if distance < SHOW_RANGE then
						animate(rec, t, dt)
					end
				end
			end
		end
	end
	for inst, rec in pairs(records) do
		if not seen[inst] then
			destroy(rec)
			records[inst] = nil
		end
	end
end)
