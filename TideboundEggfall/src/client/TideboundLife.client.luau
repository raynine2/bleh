-- Tidebound: Eggfall: Eggfall Town comes alive (Patch 10). Everything here exists only on your screen:
--   villagers   walk the town's streets (IslesLayout.Town.edges), stop to chat, wave when you pass, and
--               sometimes say something useful
--   fishers     stand on the piers and the koi pond with rods, cast, wait, and now and then land a fish
--   vendors     call out from the market stalls and wave you over
--   chickens    peck and potter round the farm's run; gulls wheel over the harbor and the beach
--   boats       bob at their moorings (TideboundBob), the named NPCs breathe and turn to face you
--               (TideboundNpc), butterflies flit over the town, and fish leap out of the sea near you
-- Far from the camera nothing is drawn, so the big map costs nothing where you aren't.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("Fx"))
local L = require(Shared:WaitForChild("IslesLayout"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()
local T = L.Town
local TOP = L.TOP

local DRAW_RANGE = 240
local TAU = math.pi * 2

local folder = Instance.new("Folder")
folder.Name = "TideboundLife"
folder.Parent = workspace

local function newPart(parent, name, size, color, shape, material)
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function refreshFilter()
	local list = { folder, Fx.folder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "TideboundMobs", "TideboundRodFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	rayParams.FilterDescendantsInstances = list
end
refreshFilter()

local function groundY(x, z, fallback)
	local result = workspace:Raycast(Vector3.new(x, TOP + 20, z), Vector3.new(0, -40, 0), rayParams)
	return result and result.Position.Y or fallback
end

local function camPos()
	return camera.CFrame.Position
end

local function rootPos()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Speech bubbles ----------------------------------------------------------------------------------------------

local function say(adornee, text, seconds, color)
	local old = adornee:FindFirstChild("LifeBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LifeBubble"
	gui.Size = UDim2.new(0, 200, 0, 46)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local box = Instance.new("TextLabel")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Color3.fromRGB(255, 252, 244)
	box.BackgroundTransparency = 0.05
	box.TextColor3 = color or Color3.fromRGB(40, 34, 40)
	box.Font = Enum.Font.FredokaOne
	box.TextScaled = true
	box.TextWrapped = true
	box.Text = text
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = box
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = gui
	gui.Parent = adornee
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Debris:AddItem(gui, seconds or 3)
end

local CHATTER = {
	"Lovely day for fishing!",
	"Did you hear? A golem on Smugglers' Cove!",
	"The market has egg tarts today.",
	"Mind the gulls past the Tidegate. Thieves, all of them.",
	"My cousin saw the Reef Warden. Never the same since.",
	"Bank your fish at a Tide Cache, dear. It heals you too.",
	"Geysers on the far islands throw you sky high!",
	"The Outer Reef is stormy. Bring a good rod.",
	"Sharks only bite swimmers. Stay on the bridges!",
	"Puffers swell up red before they pop. Step away!",
	"Have you climbed Torii Hill? The view!",
	"The lighthouse keeper waves at every boat.",
}
local GREETINGS = { "Hello!", "Hi there!", "Off diving?", "Good luck out there!", "Nice rod!", "Welcome to Eggfall!" }

-- Villagers ---------------------------------------------------------------------------------------------------

local SHIRTS = { Color3.fromRGB(230, 90, 80), Color3.fromRGB(80, 140, 220), Color3.fromRGB(240, 200, 80), Color3.fromRGB(120, 200, 120), Color3.fromRGB(190, 120, 220), Color3.fromRGB(250, 160, 90), Color3.fromRGB(90, 200, 200), Color3.fromRGB(240, 240, 240) }
local SKINS = { Color3.fromRGB(255, 220, 180), Color3.fromRGB(234, 196, 160), Color3.fromRGB(196, 150, 110), Color3.fromRGB(150, 104, 72), Color3.fromRGB(110, 76, 52) }
local PANTS = { Color3.fromRGB(60, 56, 70), Color3.fromRGB(70, 90, 130), Color3.fromRGB(110, 90, 70), Color3.fromRGB(40, 40, 46) }
local HATS = { Color3.fromRGB(230, 200, 120), Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 90, 160), Color3.fromRGB(250, 250, 250) }

-- A blocky townsperson. Returns { model, parts = { name = { part, offset } } } posed by `posePerson`.
local function makePerson(scale)
	local model = Instance.new("Model")
	model.Name = "Villager"
	local shirt, skin, pants = SHIRTS[rng:NextInteger(1, #SHIRTS)], SKINS[rng:NextInteger(1, #SKINS)], PANTS[rng:NextInteger(1, #PANTS)]
	local s = scale
	local parts = {}
	local function add(name, size, color, offset, shape)
		parts[name] = { part = newPart(model, name, size * s, color, shape), offset = CFrame.new(offset * s) }
	end
	add("Body", Vector3.new(2, 2.2, 1.1), shirt, Vector3.new(0, 3.3, 0))
	add("Head", Vector3.new(1.5, 1.5, 1.5), skin, Vector3.new(0, 5.2, 0))
	add("LegL", Vector3.new(0.9, 2.2, 1), pants, Vector3.new(-0.5, 1.1, 0))
	add("LegR", Vector3.new(0.9, 2.2, 1), pants, Vector3.new(0.5, 1.1, 0))
	add("ArmL", Vector3.new(0.7, 2.1, 0.8), skin, Vector3.new(-1.4, 3.3, 0))
	add("ArmR", Vector3.new(0.7, 2.1, 0.8), skin, Vector3.new(1.4, 3.3, 0))
	add("EyeL", Vector3.new(0.22, 0.3, 0.1), Color3.fromRGB(20, 20, 26), Vector3.new(-0.35, 5.3, -0.76))
	add("EyeR", Vector3.new(0.22, 0.3, 0.1), Color3.fromRGB(20, 20, 26), Vector3.new(0.35, 5.3, -0.76))
	if rng:NextNumber() < 0.55 then
		local hat = HATS[rng:NextInteger(1, #HATS)]
		add("Hat", Vector3.new(2.1, 0.35, 2.1), hat, Vector3.new(0, 6.05, 0))
		add("HatTop", Vector3.new(1.4, 0.6, 1.4), hat, Vector3.new(0, 6.4, 0))
	end
	model.PrimaryPart = parts.Body.part
	model.Parent = folder
	return { model = model, parts = parts, scale = s }
end

-- Poses a person at `cf` (feet on the ground). walk 0..1 swings the limbs; wave raises the right arm.
local LIMB_PIVOT = { LegL = Vector3.new(-0.5, 2.2, 0), LegR = Vector3.new(0.5, 2.2, 0), ArmL = Vector3.new(-1.4, 4.2, 0), ArmR = Vector3.new(1.4, 4.2, 0) }
local function posePerson(person, cf, phase, walk, wave, t, extra)
	local partsList, cframes = {}, {}
	local s = person.scale
	local bob = math.abs(math.sin(phase)) * 0.18 * walk
	local breathe = math.sin(t * 1.8 + (person.seed or 0)) * 0.04
	local base = cf * CFrame.new(0, bob + breathe * (1 - walk), 0)
	for name, entry in pairs(person.parts) do
		local offset = entry.offset
		local pivot = LIMB_PIVOT[name]
		local result = base * offset
		if pivot then
			local swing = 0
			if name == "LegL" then
				swing = math.sin(phase) * 0.7 * walk
			elseif name == "LegR" then
				swing = -math.sin(phase) * 0.7 * walk
			elseif name == "ArmL" then
				swing = -math.sin(phase) * 0.6 * walk + (extra and extra.armL or 0)
			elseif name == "ArmR" then
				swing = math.sin(phase) * 0.6 * walk + (extra and extra.armR or 0)
			end
			local roll = 0
			if name == "ArmR" and wave > 0 then
				swing = swing * (1 - wave) + wave * 2.9
				roll = wave * (0.4 + 0.3 * math.sin(t * 12))
			end
			local p = CFrame.new(pivot * s)
			result = base * p * CFrame.Angles(swing, 0, roll) * p:Inverse() * offset
		elseif name == "Head" or name == "EyeL" or name == "EyeR" or name == "Hat" or name == "HatTop" then
			local p = CFrame.new(Vector3.new(0, 4.5, 0) * s)
			result = base * p * CFrame.Angles(extra and extra.nod or 0, extra and extra.look or 0, 0) * p:Inverse() * offset
		end
		table.insert(partsList, entry.part)
		table.insert(cframes, result)
	end
	workspace:BulkMoveTo(partsList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- the street graph
local neighbors = {}
for name in pairs(T.nodes) do
	neighbors[name] = {}
end
for _, edge in ipairs(T.edges) do
	table.insert(neighbors[edge[1]], edge[2])
	table.insert(neighbors[edge[2]], edge[1])
end
local nodeNames = {}
for name in pairs(T.nodes) do
	table.insert(nodeNames, name)
end
table.sort(nodeNames)

local villagers = {}
for i = 1, T.villagers do
	local person = makePerson(rng:NextNumber(0.85, 1.05))
	person.seed = rng:NextNumber(0, 10)
	local from = nodeNames[rng:NextInteger(1, #nodeNames)]
	local options = neighbors[from]
	local to = options[rng:NextInteger(1, #options)]
	local a, b = T.nodes[from], T.nodes[to]
	villagers[i] = {
		person = person,
		from = from,
		to = to,
		s = rng:NextNumber(0, 1),
		speed = rng:NextNumber(5, 8),
		side = rng:NextNumber(-2.5, 2.5), -- keep to one side of the street
		pos = a:Lerp(b, 0.5),
		y = TOP,
		yAt = 0,
		phase = rng:NextNumber(0, TAU),
		pauseUntil = 0,
		wave = 0,
		yaw = 0,
		nextChat = os.clock() + rng:NextNumber(4, 20),
		greeted = 0,
	}
end

local function stepVillager(v, dt, t, me)
	local a, b = T.nodes[v.from], T.nodes[v.to]
	local length = (b - a).Magnitude
	local moving = t >= v.pauseUntil
	local walk = 0
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local close = me and (Vector3.new(me.X, 0, me.Z) - v.pos).Magnitude < 10
	if close and t - v.greeted > 20 then
		-- someone passes: stop, turn, wave, say hello
		v.greeted = t
		v.pauseUntil = t + 2.4
		v.waveUntil = t + 1.8
		say(v.person.parts.Head.part, rng:NextNumber() < 0.35 and CHATTER[rng:NextInteger(1, #CHATTER)] or GREETINGS[rng:NextInteger(1, #GREETINGS)], 3)
	end
	if moving then
		v.s += v.speed * dt / math.max(length, 1)
		if v.s >= 1 then
			-- at a corner: maybe pause, then pick a new street (rarely turning straight back)
			v.s = 0
			local options = neighbors[v.to]
			local nextNode = options[rng:NextInteger(1, #options)]
			if nextNode == v.from and #options > 1 and rng:NextNumber() < 0.8 then
				nextNode = options[rng:NextInteger(1, #options)]
			end
			v.from, v.to = v.to, nextNode
			if rng:NextNumber() < 0.25 then
				v.pauseUntil = t + rng:NextNumber(1.5, 4)
			end
			return 0
		end
		walk = 1
	end
	v.pos = a:Lerp(b, v.s) + side * v.side
	local wantYaw = math.atan2(-dir.X, -dir.Z)
	if close and me then
		local d = Vector3.new(me.X, 0, me.Z) - v.pos
		if d.Magnitude > 0.1 then
			wantYaw = math.atan2(-d.X, -d.Z)
		end
	end
	local dy = (wantYaw - v.yaw + math.pi) % TAU - math.pi
	v.yaw += dy * math.min(1, dt * 6)
	v.phase += dt * v.speed * 1.4 * walk
	return walk
end

-- Fishers on the piers -------------------------------------------------------------------------------------

local fishers = {}
for _, spec in ipairs(T.fishers) do
	local person = makePerson(1)
	person.seed = rng:NextNumber(0, 10)
	local rodPart = newPart(person.model, "Rod", Vector3.new(0.25, 0.25, 7), Color3.fromRGB(120, 84, 56))
	local bobber = newPart(person.model, "Bobber", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 70, 60), Enum.PartType.Ball)
	local line = Instance.new("Beam")
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -3.5)
	a0.Parent = rodPart
	a1.Parent = bobber
	line.Attachment0, line.Attachment1 = a0, a1
	line.Width0, line.Width1 = 0.06, 0.06
	line.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
	line.FaceCamera = true
	line.Parent = rodPart
	local fish = newPart(person.model, "Catch", Vector3.new(0.6, 0.8, 1.6), Color3.fromRGB(255, 170, 90))
	fish.Transparency = 1
	table.insert(fishers, {
		person = person,
		at = spec.at,
		face = spec.face,
		rod = rodPart,
		bobber = bobber,
		fish = fish,
		y = nil,
		nextCatch = os.clock() + rng:NextNumber(6, 16),
		catchAt = -100,
	})
end

-- Vendors ---------------------------------------------------------------------------------------------------

local CALLS = { "Fresh fish! Fresh fish!", "Egg tarts, warm egg tarts!", "Takoyaki here!", "Shaved ice! Beat the heat!", "Best prices in Eggfall!", "Come try, come try!" }
local vendors = {}
for _, spec in ipairs(T.vendors) do
	local person = makePerson(1)
	person.seed = rng:NextNumber(0, 10)
	local apron = newPart(person.model, "Apron", Vector3.new(1.8, 1.8, 0.2), Color3.fromRGB(250, 250, 250))
	person.parts.Apron = { part = apron, offset = CFrame.new(0, 3.1, -0.62) }
	table.insert(vendors, { person = person, at = spec.at, face = spec.face, y = nil, nextCall = os.clock() + rng:NextNumber(3, 12), waveUntil = 0 })
end

-- Chickens --------------------------------------------------------------------------------------------------

local chickens = {}
for _ = 1, 9 do
	local model = Instance.new("Model")
	model.Name = "Chicken"
	local body = newPart(model, "Body", Vector3.new(1.1, 1, 1.4), Color3.fromRGB(250, 250, 246))
	local head = newPart(model, "Head", Vector3.new(0.6, 0.7, 0.6), Color3.fromRGB(250, 250, 246))
	local comb = newPart(model, "Comb", Vector3.new(0.2, 0.35, 0.45), Color3.fromRGB(230, 50, 50))
	local beak = newPart(model, "Beak", Vector3.new(0.25, 0.2, 0.35), Color3.fromRGB(255, 180, 40))
	model.Parent = folder
	local a = rng:NextNumber(0, TAU)
	local d = rng:NextNumber(0, T.chickens.radius - 3)
	table.insert(chickens, {
		parts = { body, head, comb, beak },
		pos = T.chickens.center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d),
		goal = nil,
		goalAt = 0,
		yaw = 0,
		peck = 0,
		seed = rng:NextNumber(0, 10),
	})
end

-- Gulls over the harbor and beach ------------------------------------------------------------------------

local gulls = {}
for i = 1, 10 do
	local model = Instance.new("Model")
	model.Name = "TownGull"
	local body = newPart(model, "Body", Vector3.new(0.9, 0.8, 2), Color3.fromRGB(250, 250, 252))
	local wingL = newPart(model, "WingL", Vector3.new(2.4, 0.15, 1), Color3.fromRGB(170, 180, 190))
	local wingR = newPart(model, "WingR", Vector3.new(2.4, 0.15, 1), Color3.fromRGB(170, 180, 190))
	model.Parent = folder
	local center = (i % 2 == 0) and Vector3.new(130, 0, 0) or Vector3.new(30, 0, -150)
	table.insert(gulls, { body = body, wingL = wingL, wingR = wingR, center = center + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30)), radius = rng:NextNumber(18, 40), height = rng:NextNumber(30, 55), speed = rng:NextNumber(0.25, 0.45) * (rng:NextNumber() < 0.5 and -1 or 1), phase = rng:NextNumber(0, TAU) })
end

-- Butterflies -----------------------------------------------------------------------------------------------

local butterflies = {}
local BUTTERFLY = { Color3.fromRGB(255, 160, 220), Color3.fromRGB(255, 230, 110), Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 255, 255) }
for _ = 1, 16 do
	local color = BUTTERFLY[rng:NextInteger(1, #BUTTERFLY)]
	local wl = newPart(folder, "Wing", Vector3.new(0.5, 0.05, 0.4), color, nil, Enum.Material.Neon)
	local wr = newPart(folder, "Wing", Vector3.new(0.5, 0.05, 0.4), color, nil, Enum.Material.Neon)
	local home = Vector3.new(rng:NextNumber(-150, 150), 0, rng:NextNumber(-150, 170))
	table.insert(butterflies, { wl = wl, wr = wr, home = home, seed = rng:NextNumber(0, 100) })
end

-- Boats and named NPCs ---------------------------------------------------------------------------------------

local bobbing = {}
local function watchTag(tagName, added, removed)
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		task.spawn(added, inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(removed)
end
watchTag("TideboundBob", function(model)
	if model:IsA("Model") and typeof(model:GetAttribute("Home")) == "CFrame" then
		bobbing[model] = { home = model:GetAttribute("Home"), seed = model:GetAttribute("Seed") or 0 }
	end
end, function(model)
	bobbing[model] = nil
end)

local npcs = {}
watchTag("TideboundNpc", function(model)
	if model:IsA("Model") then
		npcs[model] = { home = model:GetPivot(), yaw = 0, kind = model:GetAttribute("Kind") or "person", seed = rng:NextNumber(0, 10) }
	end
end, function(model)
	npcs[model] = nil
end)

-- Leaping fish ------------------------------------------------------------------------------------------------

local LEAP_COLORS = { Color3.fromRGB(255, 170, 90), Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 230, 120), Color3.fromRGB(190, 255, 170) }
local nextLeap = os.clock() + 3
local function leapingFish(center)
	-- a spot of open water 25-70 studs away
	for _ = 1, 8 do
		local a = rng:NextNumber(0, TAU)
		local d = rng:NextNumber(25, 70)
		local p = Vector3.new(center.X + math.cos(a) * d, L.WATER_Y + 2, center.Z + math.sin(a) * d)
		local result = workspace:Raycast(p, Vector3.new(0, -6, 0), rayParams)
		if not result then
			local fish = newPart(folder, "LeapFish", Vector3.new(0.6, 0.8, 1.8), LEAP_COLORS[rng:NextInteger(1, #LEAP_COLORS)])
			local dir = Vector3.new(math.cos(a + 1.6), 0, math.sin(a + 1.6))
			local start = Vector3.new(p.X, L.WATER_Y, p.Z)
			local finish = start + dir * rng:NextNumber(5, 9)
			local height = rng:NextNumber(3, 6)
			Fx.cubes(start, { Color3.fromRGB(200, 240, 255), Color3.new(1, 1, 1) }, { spread = 2.5, size = 0.4, life = 0.4, up = 1, count = 8, material = Enum.Material.SmoothPlastic })
			local began = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local s = (os.clock() - began) / 0.9
				if s >= 1 then
					conn:Disconnect()
					fish:Destroy()
					Fx.cubes(finish, { Color3.fromRGB(200, 240, 255), Color3.new(1, 1, 1) }, { spread = 2.5, size = 0.4, life = 0.4, up = 1, count = 8, material = Enum.Material.SmoothPlastic })
					Fx.ring(finish + Vector3.new(0, 0.1, 0), Color3.fromRGB(220, 250, 255), 2.5, 0.5, 0.15)
					return
				end
				local pos = start:Lerp(finish, s) + Vector3.new(0, height * 4 * s * (1 - s), 0)
				fish.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(70) - s * math.rad(140), 0, math.sin(s * 30) * 0.2)
			end)
			return
		end
	end
end

-- Every frame ---------------------------------------------------------------------------------------------

local filterAt = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	if t > filterAt then
		filterAt = t + 2
		refreshFilter()
	end
	local cam = camPos()
	local me = rootPos()
	local inTown = me and Config.safeZone(me) == "Nest"

	-- villagers
	for _, v in ipairs(villagers) do
		local walk = stepVillager(v, dt, t, inTown and me or nil)
		local distance = (v.pos - Vector3.new(cam.X, 0, cam.Z)).Magnitude
		local visible = distance < DRAW_RANGE
		local model = v.person.model
		if visible ~= (model.Parent == folder) then
			model.Parent = visible and folder or nil
		end
		if visible then
			if t > v.yAt then
				v.yAt = t + 0.4
				v.y = groundY(v.pos.X, v.pos.Z, TOP)
			end
			if t >= v.nextChat then
				v.nextChat = t + rng:NextNumber(10, 25)
				if distance < 50 and rng:NextNumber() < 0.6 then
					say(v.person.parts.Head.part, CHATTER[rng:NextInteger(1, #CHATTER)], 3.5)
				end
			end
			local wave = (v.waveUntil and t < v.waveUntil) and math.min(1, (v.waveUntil - t) * 3, (t - (v.waveUntil - 1.8)) * 4) or 0
			posePerson(v.person, CFrame.new(v.pos.X, v.y, v.pos.Z) * CFrame.Angles(0, v.yaw, 0), v.phase, walk, wave, t)
		end
	end

	-- fishers: cast out, wait with a bobbing float, and now and then land one
	for _, f in ipairs(fishers) do
		local distance = (f.at - Vector3.new(cam.X, 0, cam.Z)).Magnitude
		local visible = distance < DRAW_RANGE
		if visible ~= (f.person.model.Parent == folder) then
			f.person.model.Parent = visible and folder or nil
		end
		if visible then
			f.y = f.y or groundY(f.at.X, f.at.Z, TOP)
			local dir = (f.face - f.at).Unit
			local cf = CFrame.lookAt(Vector3.new(f.at.X, f.y, f.at.Z), Vector3.new(f.at.X, f.y, f.at.Z) + dir)
			local u = t - f.catchAt
			local reeling = u < 1.6
			local armR = reeling and (1.2 + 0.4 * math.sin(u * 14)) or (0.9 + 0.05 * math.sin(t * 1.5))
			posePerson(f.person, cf, 0, 0, 0, t, { armR = armR, armL = armR * 0.8, nod = reeling and 0.2 or -0.15 })
			local hand = cf * CFrame.new(1.4, 3.6, -1.6)
			local tip = hand * CFrame.Angles(math.rad(reeling and 55 or 30) + 0.05 * math.sin(t * 2), 0, 0)
			f.rod.CFrame = tip * CFrame.new(0, 0, -3.5)
			if not f.bobY then
				-- the sea, or the koi pond up on the land
				local spot = f.at + dir * 9
				local ground = groundY(spot.X, spot.Z, L.WATER_Y)
				f.bobY = ground > L.WATER_Y + 1 and ground + 0.95 or L.WATER_Y + 0.15
			end
			local bobAt = Vector3.new(f.at.X, f.bobY, f.at.Z) + dir * 9
			local nibble = math.max(0, math.sin(t * 7 + f.person.seed)) ^ 8
			f.bobber.CFrame = CFrame.new(bobAt + Vector3.new(0, 0.12 * math.sin(t * 2.4) - 0.3 * nibble * (f.nextCatch - t < 2 and 1 or 0), 0))
			if t >= f.nextCatch then
				f.nextCatch = t + rng:NextNumber(10, 22)
				f.catchAt = t
				Fx.cubes(bobAt, { Color3.fromRGB(200, 240, 255), Color3.new(1, 1, 1) }, { spread = 3, size = 0.4, life = 0.5, up = 1, count = 10, material = Enum.Material.SmoothPlastic })
				f.fish.Color = LEAP_COLORS[rng:NextInteger(1, #LEAP_COLORS)]
				if distance < 60 then
					task.delay(1.2, function()
						say(f.person.parts.Head.part, ({ "Got one!", "A big one!", "Ha! Dinner!", "Look at this beauty!" })[rng:NextInteger(1, 4)], 2.5)
					end)
				end
			end
			if u < 1.6 then
				-- the fish flies out of the water into the fisher's hand
				local s = math.clamp(u / 1.1, 0, 1)
				local handPos = (cf * CFrame.new(0.8, 4.2, -1.2)).Position
				local pos = bobAt:Lerp(handPos, s) + Vector3.new(0, 5 * 4 * s * (1 - s), 0)
				f.fish.Transparency = 0
				f.fish.CFrame = CFrame.new(pos) * CFrame.Angles(s * 8, 0, math.sin(t * 30) * 0.3)
			else
				f.fish.Transparency = 1
			end
		end
	end

	-- vendors call out and wave
	for _, vendor in ipairs(vendors) do
		local distance = (vendor.at - Vector3.new(cam.X, 0, cam.Z)).Magnitude
		local visible = distance < DRAW_RANGE
		if visible ~= (vendor.person.model.Parent == folder) then
			vendor.person.model.Parent = visible and folder or nil
		end
		if visible then
			vendor.y = vendor.y or groundY(vendor.at.X, vendor.at.Z, TOP)
			if t >= vendor.nextCall then
				vendor.nextCall = t + rng:NextNumber(6, 14)
				vendor.waveUntil = t + 1.6
				if distance < 55 then
					say(vendor.person.parts.Head.part, CALLS[rng:NextInteger(1, #CALLS)], 3, Color3.fromRGB(180, 60, 40))
				end
			end
			local wave = t < vendor.waveUntil and math.min(1, (vendor.waveUntil - t) * 3, (t - (vendor.waveUntil - 1.6)) * 4) or 0
			local target = vendor.face
			if me and (Vector3.new(me.X, 0, me.Z) - vendor.at).Magnitude < 18 then
				target = Vector3.new(me.X, 0, me.Z)
			end
			local cf = CFrame.lookAt(Vector3.new(vendor.at.X, vendor.y, vendor.at.Z), Vector3.new(target.X, vendor.y, target.Z))
			posePerson(vendor.person, cf, 0, 0, wave, t)
		end
	end

	-- chickens
	local run = T.chickens
	local nearFarm = (run.center - Vector3.new(cam.X, 0, cam.Z)).Magnitude < DRAW_RANGE
	for _, c in ipairs(chickens) do
		local model = c.parts[1].Parent
		if model then
			if nearFarm ~= (model.Parent == folder) then
				model.Parent = nearFarm and folder or nil
			end
		end
		if nearFarm then
			if not c.goal or t > c.goalAt then
				local a = rng:NextNumber(0, TAU)
				local d = rng:NextNumber(0, run.radius - 3)
				c.goal = run.center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				c.goalAt = t + rng:NextNumber(2, 5)
				c.peck = t + rng:NextNumber(0, 1.5)
			end
			local d = c.goal - c.pos
			local walking = d.Magnitude > 0.5 and t > c.peck
			if walking then
				c.pos += d.Unit * math.min(d.Magnitude, 4 * dt)
				c.yaw = math.atan2(-d.X, -d.Z)
			end
			local pecking = not walking and math.sin(t * 9 + c.seed) > 0.3
			local hop = walking and math.abs(math.sin(t * 14 + c.seed)) * 0.25 or 0
			local cf = CFrame.new(c.pos.X, TOP + 0.55 + hop, c.pos.Z) * CFrame.Angles(0, c.yaw, 0)
			local headCf = cf * CFrame.new(0, pecking and 0 or 0.65, pecking and -0.95 or -0.75) * CFrame.Angles(pecking and -0.9 or 0, 0, 0)
			workspace:BulkMoveTo(c.parts, { cf, headCf, headCf * CFrame.new(0, 0.45, 0), headCf * CFrame.new(0, -0.05, -0.45) }, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- gulls wheel overhead
	for _, g in ipairs(gulls) do
		local a = t * g.speed + g.phase
		local pos = g.center + Vector3.new(math.cos(a) * g.radius, g.height + math.sin(t * 0.7 + g.phase) * 3, math.sin(a) * g.radius)
		if (pos - cam).Magnitude < DRAW_RANGE * 1.4 then
			local dir = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(g.speed)
			local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, -0.35 * math.sign(g.speed))
			local flap = math.sin(t * 7 + g.phase) * 0.5
			workspace:BulkMoveTo({ g.body, g.wingL, g.wingR }, {
				cf,
				cf * CFrame.new(-0.4, 0.2, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.2, 0, 0),
				cf * CFrame.new(0.4, 0.2, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.2, 0, 0),
			}, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- butterflies flit near flowers in town
	for _, b in ipairs(butterflies) do
		local s = b.seed
		local pos = b.home + Vector3.new(math.sin(t * 0.3 + s) * 6 + math.sin(t * 1.3 + s) * 1.5, TOP + 2.5 + math.sin(t * 2.1 + s) * 1, math.cos(t * 0.27 + s) * 6)
		if (pos - cam).Magnitude < 90 then
			local flap = math.sin(t * 24 + s) * 0.9
			local cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(t * 0.3 + s), 0, -math.sin(t * 0.27 + s)))
			workspace:BulkMoveTo({ b.wl, b.wr }, { cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.25, 0, 0), cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.25, 0, 0) }, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- boats bob at their moorings
	for model, b in pairs(bobbing) do
		if model.Parent and (b.home.Position - cam).Magnitude < DRAW_RANGE * 1.3 then
			local s = b.seed
			model:PivotTo(b.home * CFrame.new(0, math.sin(t * 1.1 + s) * 0.25, 0) * CFrame.Angles(math.sin(t * 0.8 + s) * 0.04, 0, math.sin(t * 1.0 + s * 2) * 0.06))
		end
	end

	-- the named NPCs breathe, bounce a little and turn to face you when you come close
	for model, npc in pairs(npcs) do
		if model.Parent then
			local pos = npc.home.Position
			if (pos - cam).Magnitude < 120 then
				local wantYaw = 0
				if me and (me - pos).Magnitude < 16 then
					local local_ = npc.home:PointToObjectSpace(me)
					wantYaw = math.clamp(math.atan2(-local_.X, -local_.Z), -1.2, 1.2)
				end
				npc.yaw += (wantYaw - npc.yaw) * math.min(1, dt * 4)
				local bounce = npc.kind == "crab" and math.abs(math.sin(t * 3 + npc.seed)) * 0.15 or math.sin(t * 1.8 + npc.seed) * 0.06
				model:PivotTo(npc.home * CFrame.new(0, bounce, 0) * CFrame.Angles(0, npc.yaw, 0))
			end
		end
	end

	-- fish leap out of the sea now and then, wherever you are near open water
	if me and t > nextLeap then
		nextLeap = t + rng:NextNumber(2.5, 6)
		leapingFish(me)
	end
end)
