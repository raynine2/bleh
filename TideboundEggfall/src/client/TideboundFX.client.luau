-- Tidebound: Eggfall: the living world (Big Update). Everything here moves only on your screen:
--   TideboundSpin    the lighthouse beam and the Maelstrom's rings and foam turn round their Pivot attribute
--   TideboundFloat   Kelp Cathedral jellies drift and bob around their Home attribute
--   TideboundSchool  schools of little glowing fish circle each anchor (Radius, Count, Color)
--   TideboundSerpent the Kelp Leviathan's long body trails behind its head along the path it swam
--   Guardians        a red telegraph fills under a guardian while it winds up (Tell), a shockwave when it
--                    strikes (StrikeAt), and a roar burst when it wakes (WokeAt)
--   Wild eggs        a gold "!" pops over an egg the first time you get close, like the video's alerts
-- Anything farther than ANIMATE_RANGE from the camera holds still, so a big map costs nothing far away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ANIMATE_RANGE = 420
local RED = Color3.fromRGB(255, 52, 52)
local GOLD = Color3.fromRGB(255, 214, 70)

local function camPos()
	camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

local function near(position, range)
	return (position - camPos()).Magnitude <= (range or ANIMATE_RANGE)
end

local function localPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

-- Runs `onAdd(inst)` for everything with the tag now and later (streaming adds and removes them as you move),
-- and `onRemove(inst)` when one leaves.
local function watchTag(tag, onAdd, onRemove)
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		task.spawn(onAdd, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
	if onRemove then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemove)
	end
end

-- Spinners ----------------------------------------------------------------------------------------------------

local spinners = {} -- [BasePart] = { pivot, rel, speed }

watchTag("TideboundSpin", function(p)
	if not p:IsA("BasePart") then
		return
	end
	local pivot = p:GetAttribute("Pivot")
	if typeof(pivot) ~= "Vector3" then
		return
	end
	spinners[p] = { pivot = pivot, rel = CFrame.new(pivot):ToObjectSpace(p.CFrame), speed = p:GetAttribute("SpinSpeed") or 0.5 }
end, function(p)
	spinners[p] = nil
end)

-- Floaters (jellies) ------------------------------------------------------------------------------------------

local floaters = {} -- [Model] = { home, seed, base }

watchTag("TideboundFloat", function(model)
	if not model:IsA("Model") then
		return
	end
	local home = model:GetAttribute("Home")
	if typeof(home) ~= "Vector3" then
		return
	end
	floaters[model] = { home = home, seed = model:GetAttribute("Seed") or 0 }
end, function(model)
	floaters[model] = nil
end)

-- Schools of fish ---------------------------------------------------------------------------------------------

local schools = {} -- [anchor] = { center, radius, fish = { { part, phase, lane, speed } } }

watchTag("TideboundSchool", function(anchor)
	if not anchor:IsA("BasePart") then
		return
	end
	local color = anchor:GetAttribute("Color")
	if typeof(color) ~= "Color3" then
		color = Color3.fromRGB(90, 255, 230)
	end
	local rng = Random.new(math.floor(anchor.Position.X * 7 + anchor.Position.Z))
	local list = {}
	for i = 1, anchor:GetAttribute("Count") or 8 do
		local fish = localPart({
			Name = "SchoolFish",
			Size = Vector3.new(0.45, 0.6, 1.3),
			Color = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.35)),
			Material = Enum.Material.Neon,
			Parent = Fx.folder(),
		})
		local tail = localPart({ Name = "Tail", Size = Vector3.new(0.15, 0.6, 0.5), Color = color, Material = Enum.Material.Neon, Parent = fish })
		table.insert(list, { part = fish, tail = tail, phase = i / 8 * math.pi * 2 + rng:NextNumber(-0.3, 0.3), lane = rng:NextNumber(-1, 1), speed = rng:NextNumber(0.55, 0.75) })
	end
	schools[anchor] = { center = anchor.Position, radius = anchor:GetAttribute("Radius") or 10, fish = list }
end, function(anchor)
	local school = schools[anchor]
	schools[anchor] = nil
	if school then
		for _, f in ipairs(school.fish) do
			f.part:Destroy()
		end
	end
end)

-- The Kelp Leviathan's body -----------------------------------------------------------------------------------

local serpents = {} -- [Model] = { history = { Vector3 }, segments = { { body, fin, belly } }, folder }

local function makeSerpent(model)
	if not model:IsA("Model") then
		return
	end
	local count = model:GetAttribute("Segments") or 12
	local size = model:GetAttribute("SegmentSize") or 5
	local skin = model:GetAttribute("SkinColor") or Color3.fromRGB(46, 104, 70)
	local finColor = model:GetAttribute("FinColor") or Color3.fromRGB(150, 70, 170)
	local bellyColor = model:GetAttribute("BellyColor") or Color3.fromRGB(196, 214, 140)
	local folder = Instance.new("Model")
	folder.Name = model.Name .. "Body"
	folder.Parent = Fx.folder()
	local segments = {}
	for i = 1, count do
		local s = size * (1 - 0.6 * (i - 1) / count)
		local body = localPart({ Name = "Segment", Size = Vector3.new(s * 1.2, s, s * 1.1), Color = (i % 2 == 0) and skin or skin:Lerp(Color3.new(0, 0, 0), 0.12), Parent = folder })
		local belly = localPart({ Name = "Belly", Size = Vector3.new(s * 0.9, s * 0.3, s * 1.0), Color = bellyColor, Parent = folder })
		local fin = localPart({ Name = "Fin", Size = Vector3.new(0.3, s * 0.7, s * 0.8), Color = finColor, Material = Enum.Material.Neon, Parent = folder })
		table.insert(segments, { body = body, belly = belly, fin = (i % 2 == 1) and fin or nil, size = s })
		if i % 2 == 0 then
			fin:Destroy()
		end
	end
	-- the tail fluke
	local fluke = localPart({ Name = "Fluke", Size = Vector3.new(size * 1.6, 0.4, size * 0.9), Color = finColor, Material = Enum.Material.Neon, Parent = folder })
	-- start coiled up beside the head, the way it sleeps in its lair
	local head = model:GetPivot()
	local start = head.Position - head.LookVector * 4.5
	local r = 9
	local center = start + head.RightVector * r
	local a0 = math.atan2((start - center).Z, (start - center).X)
	local history = {}
	for k = 0, 80 do
		local a = a0 + k * 0.09
		table.insert(history, center + Vector3.new(math.cos(a) * r, -k * 0.02, math.sin(a) * r))
	end
	serpents[model] = { history = history, segments = segments, fluke = fluke, folder = folder, spacing = model:GetAttribute("Spacing") or 3.8 }
end

watchTag("TideboundSerpent", makeSerpent, function(model)
	local serpent = serpents[model]
	serpents[model] = nil
	if serpent then
		serpent.folder:Destroy()
	end
end)

-- the point `distance` studs along the history (newest first), and the direction toward the head there
local function along(history, distance)
	local walked = 0
	for i = 1, #history - 1 do
		local a, b = history[i], history[i + 1]
		local step = (b - a).Magnitude
		if walked + step >= distance and step > 0 then
			local p = a:Lerp(b, (distance - walked) / step)
			return p, (a - b).Unit
		end
		walked += step
	end
	local last, before = history[#history], history[math.max(1, #history - 1)]
	local dir = (before - last)
	return last, dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
end

local function updateSerpent(model, serpent, t)
	local head = model:GetPivot()
	local start = head.Position - head.LookVector * 4.5
	local history = serpent.history
	if (start - history[1]).Magnitude > 0.5 then
		table.insert(history, 1, start)
		-- keep just enough path for the whole body
		local need = (#serpent.segments + 2) * serpent.spacing + 6
		local walked = 0
		for i = 1, #history - 1 do
			walked += (history[i + 1] - history[i]).Magnitude
			if walked > need then
				for j = #history, i + 2, -1 do
					history[j] = nil
				end
				break
			end
		end
	end
	local tell = model:GetAttribute("Tell") == true
	local count = #serpent.segments
	for i, seg in ipairs(serpent.segments) do
		local p, dir = along(history, i * serpent.spacing)
		local right = dir:Cross(Vector3.new(0, 1, 0))
		right = right.Magnitude > 0.01 and right.Unit or Vector3.new(1, 0, 0)
		-- a slow swimming wave down the body (faster and tighter while it winds up a strike)
		local wave = math.sin(t * (tell and 9 or 3) - i * 0.55) * (tell and 0.6 or 1.2) * (i / count)
		local frame = CFrame.lookAt(p + right * wave, p + right * wave + dir)
		seg.body.CFrame = frame
		seg.belly.CFrame = frame * CFrame.new(0, -seg.size * 0.42, 0)
		if seg.fin then
			seg.fin.CFrame = frame * CFrame.new(0, seg.size * 0.62, 0) * CFrame.Angles(math.rad(-20), 0, 0)
		end
	end
	local p, dir = along(history, (count + 0.9) * serpent.spacing)
	serpent.fluke.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, math.sin(t * 3) * 0.25)
end

-- Guardians: telegraphs, strikes and roars --------------------------------------------------------------------

local guardianParams = RaycastParams.new()
guardianParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundUnder(model)
	local pos = model:GetPivot().Position
	guardianParams.FilterDescendantsInstances = { model, Fx.folder() }
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), guardianParams)
	return hit and hit.Position + Vector3.new(0, 0.15, 0) or pos - Vector3.new(0, 4, 0)
end

local function cfgFor(model)
	return model.Name == "KelpLeviathan" and Config.Leviathan or Config.Guardian
end

local hooked = setmetatable({}, { __mode = "k" })
local telegraphs = {} -- [Model] = { outer, inner, started, length }

local function clearTelegraph(model)
	local tg = telegraphs[model]
	telegraphs[model] = nil
	if tg then
		tg.outer:Destroy()
		tg.inner:Destroy()
	end
end

local function hookGuardian(model)
	if hooked[model] then
		return
	end
	hooked[model] = true
	local cfg = cfgFor(model)
	model:GetAttributeChangedSignal("Tell"):Connect(function()
		if model:GetAttribute("Tell") ~= true then
			return
		end
		if not near(model:GetPivot().Position, 220) then
			return
		end
		clearTelegraph(model)
		local ground = groundUnder(model)
		local radius = (cfg.strikeRadius or 8) + 6
		local flatRing = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
		local outer = localPart({ Name = "TellRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, radius * 2, radius * 2), CFrame = flatRing, Color = RED, Material = Enum.Material.Neon, Transparency = 0.7, Parent = Fx.folder() })
		local inner = localPart({ Name = "TellFill", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.5, 0.5), CFrame = flatRing * CFrame.new(0.05, 0, 0), Color = RED, Material = Enum.Material.Neon, Transparency = 0.35, Parent = Fx.folder() })
		local length = cfg.tell or 0.6
		TweenService:Create(inner, TweenInfo.new(length, Enum.EasingStyle.Linear), { Size = Vector3.new(0.25, radius * 2, radius * 2) }):Play()
		telegraphs[model] = { outer = outer, inner = inner, ground = ground }
		Fx.alert(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"), "!", RED, length, 7)
		Fx.flashModel(model, RED, length)
		Debris:AddItem(outer, length + 1)
		Debris:AddItem(inner, length + 1)
	end)
	model:GetAttributeChangedSignal("StrikeAt"):Connect(function()
		local tg = telegraphs[model]
		local ground = tg and tg.ground or groundUnder(model)
		clearTelegraph(model)
		if not near(ground, 220) then
			return
		end
		local radius = (cfg.strikeRadius or 8) + 6
		Fx.ring(ground + Vector3.new(0, 0.2, 0), RED, radius, 0.4, 0.4)
		Fx.ring(ground + Vector3.new(0, 0.3, 0), Color3.new(1, 1, 1), radius * 0.7, 0.3, 0.25)
		Fx.cubes(ground + Vector3.new(0, 1, 0), { RED, Color3.fromRGB(255, 140, 90), Color3.new(1, 1, 1) }, { spread = radius, size = 0.9, life = 0.6, up = 0.5, count = 18, material = Enum.Material.Neon })
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - ground).Magnitude < 40 then
			-- a short camera kick
			task.spawn(function()
				for i = 1, 6 do
					camera = workspace.CurrentCamera
					camera.CFrame *= CFrame.Angles(math.rad((7 - i) * 0.25 * (i % 2 == 0 and 1 or -1)), 0, 0)
					RunService.RenderStepped:Wait()
				end
			end)
		end
	end)
	model:GetAttributeChangedSignal("WokeAt"):Connect(function()
		local pos = model:GetPivot().Position
		if not near(pos, 300) then
			return
		end
		local ground = groundUnder(model)
		Audio.play("Roar", model.PrimaryPart)
		for i = 0, 2 do
			task.delay(i * 0.25, function()
				Fx.ring(ground + Vector3.new(0, 0.3, 0), (i == 1) and Color3.new(1, 1, 1) or RED, 26 + i * 8, 0.7, 0.5)
			end)
		end
		Fx.cubes(pos, { RED, Color3.fromRGB(255, 200, 80) }, { spread = 18, size = 1.2, life = 0.9, up = 1, count = 24, material = Enum.Material.Neon })
		Fx.flashModel(model, Color3.fromRGB(255, 220, 120), 0.8)
		Fx.alert(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"), "!!", RED, 2, 8)
	end)
end

-- the Warden lives in the Shoals and the Leviathan in the Kelp; either can stream in and out
task.spawn(function()
	while true do
		local world = workspace:FindFirstChild("TideboundWorld")
		if world then
			local shoals = world:FindFirstChild("SunkenShoals")
			local warden = shoals and shoals:FindFirstChild("ReefWarden")
			if warden then
				hookGuardian(warden)
			end
			local descent = world:FindFirstChild("Descent")
			local kelp = descent and descent:FindFirstChild("KelpCathedral")
			local leviathan = kelp and kelp:FindFirstChild("KelpLeviathan")
			if leviathan then
				hookGuardian(leviathan)
			end
		end
		task.wait(1)
	end
end)

-- Wild egg alerts ---------------------------------------------------------------------------------------------

local eggs = {} -- [BasePart] = last time we alerted
local function maybeEgg(inst)
	if inst:IsA("ProximityPrompt") and inst:GetAttribute("Action") == "Steal" and inst.Parent and inst.Parent:IsA("BasePart") then
		eggs[inst.Parent] = eggs[inst.Parent] or 0
	end
end
task.spawn(function()
	local world = workspace:WaitForChild("TideboundWorld")
	for _, inst in ipairs(world:GetDescendants()) do
		maybeEgg(inst)
	end
	world.DescendantAdded:Connect(maybeEgg)
	while true do
		task.wait(0.4)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for egg, last in pairs(eggs) do
				if not egg.Parent then
					eggs[egg] = nil
				elseif not egg:GetAttribute("Taken") and os.clock() - last > 25 and (egg.Position - root.Position).Magnitude < 26 then
					eggs[egg] = os.clock()
					Fx.alert(egg, "!", GOLD, 1.4, 3.5)
					Fx.stars(egg.Position + Vector3.new(0, 1, 0), 4, GOLD)
				end
			end
		end
	end
end)

-- The frame loop ----------------------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = camPos()
	for p, spin in pairs(spinners) do
		if p.Parent and (spin.pivot - cam).Magnitude < ANIMATE_RANGE then
			p.CFrame = CFrame.new(spin.pivot) * CFrame.Angles(0, t * spin.speed, 0) * spin.rel
		end
	end
	for model, float in pairs(floaters) do
		if model.Parent and (float.home - cam).Magnitude < ANIMATE_RANGE then
			local s = float.seed
			local offset = Vector3.new(math.sin(t * 0.21 + s) * 5, math.sin(t * 0.7 + s) * 2.4, math.cos(t * 0.17 + s * 1.3) * 5)
			-- the bell pulses: a quick push up, then a slow sink
			local pulse = math.max(0, math.sin(t * 1.6 + s)) ^ 3 * 0.8
			model:PivotTo(CFrame.new(float.home + offset + Vector3.new(0, pulse, 0)) * CFrame.Angles(math.sin(t * 0.5 + s) * 0.15, t * 0.2 + s, math.cos(t * 0.4 + s) * 0.15))
		end
	end
	for _, school in pairs(schools) do
		if (school.center - cam).Magnitude < ANIMATE_RANGE * 0.7 then
			for _, f in ipairs(school.fish) do
				local a = t * f.speed + f.phase
				local r = school.radius * (1 + 0.18 * f.lane + 0.12 * math.sin(t * 0.9 + f.phase))
				local pos = school.center + Vector3.new(math.cos(a) * r, math.sin(a * 2 + f.lane) * 1.6 + f.lane * 1.5, math.sin(a) * r)
				local ahead = school.center + Vector3.new(math.cos(a + 0.1) * r, math.sin((a + 0.1) * 2 + f.lane) * 1.6 + f.lane * 1.5, math.sin(a + 0.1) * r)
				local frame = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, math.sin(t * 9 + f.phase) * 0.25, 0)
				f.part.CFrame = frame
				f.tail.CFrame = frame * CFrame.new(0, 0, 0.8) * CFrame.Angles(0, math.sin(t * 14 + f.phase) * 0.6, 0)
			end
		end
	end
	for model, serpent in pairs(serpents) do
		if model.Parent and near(model:GetPivot().Position) then
			updateSerpent(model, serpent, t)
		end
	end
	-- a telegraph follows its guardian until it strikes
	for model, tg in pairs(telegraphs) do
		if model.Parent and tg.outer.Parent then
			local pos = model:GetPivot().Position
			local ground = Vector3.new(pos.X, tg.ground.Y, pos.Z)
			tg.ground = ground
			local flatRing = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
			tg.outer.CFrame = flatRing
			tg.inner.CFrame = flatRing * CFrame.new(0.05, 0, 0)
		else
			telegraphs[model] = nil
		end
	end
end)
