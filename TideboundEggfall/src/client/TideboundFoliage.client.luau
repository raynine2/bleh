-- Tidebound: Eggfall: thick voxel grass, on your screen only (Patch 13). Around the camera, every patch of ground
-- tagged TideboundGrass (the town's lawns, the Shallows' meadows, the Coral Maze's checkered tiles, Torii Hill's
-- terraces) fills with chunky blades in that ground's greens, with the odd flower. The blades sway in the wind
-- (Workspace.GlobalWind) and bend away from you as you wade through. Far away there's no grass to pay for: a fixed
-- pool of blades is handed out to the cells near the camera and taken back as you leave them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CELL = 6
local RADIUS = 62
local PER_CELL = 7
local POOL = 2600
local RAYS_PER_TICK = 70
local TAU = math.pi * 2
local FLOWERS = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 230, 110), Color3.fromRGB(250, 250, 255), Color3.fromRGB(180, 140, 255) }

local folder = Instance.new("Folder")
folder.Name = "TideboundFoliage"
folder.Parent = workspace

local function newPart(name, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- The pool: blades waiting to be placed (parented to nil while unused).
local free = {}
local made = 0
local function takeBlade()
	local item = table.remove(free)
	if item then
		return item
	end
	if made >= POOL then
		return nil
	end
	made += 1
	return { blade = newPart("Blade", Vector3.new(0.7, 2, 0.7), Color3.new(0, 1, 0)), head = nil }
end
local function giveBack(item)
	item.blade.Parent = nil
	if item.head then
		item.head.Parent = nil
	end
	table.insert(free, item)
end

-- What lies under each cell: the grass height and colour, or false. Found once by a ray, then remembered.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
local function refreshFilter()
	local list = { folder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, name in ipairs({ "TideboundFX", "TideboundMobs", "TideboundLife", "TideboundSky", "TideboundRodFX", "TideboundHatchFX" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	rayParams.FilterDescendantsInstances = list
end
refreshFilter()

local ground = {} -- [key] = { y, color } | false
local function key(cx, cz)
	return cx * 100000 + cz
end
local function probe(cx, cz)
	local x, z = (cx + 0.5) * CELL, (cz + 0.5) * CELL
	local result = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -260, 0), rayParams)
	if result and result.Instance and result.Normal.Y > 0.9 and CollectionService:HasTag(result.Instance, "TideboundGrass") then
		return { y = result.Position.Y, color = result.Instance.Color }
	end
	return false
end

-- Each active cell keeps its blades and where they stand.
local active = {} -- [key] = { items = { { item, base, height, yaw, phase, lean } } }
local function fill(k, cx, cz, info)
	local rng = Random.new(k)
	local items = {}
	local h0, s0, v0 = info.color:ToHSV()
	for _ = 1, PER_CELL do
		local item = takeBlade()
		if not item then
			break
		end
		local flower = rng:NextNumber() < 0.07
		local height = flower and rng:NextNumber(1.2, 1.8) or rng:NextNumber(1.4, 3.4)
		local blade = item.blade
		blade.Size = Vector3.new(rng:NextNumber(0.55, 0.85), height, rng:NextNumber(0.55, 0.85))
		-- the ground's own green, a little lighter or darker per blade, lighter toward the tips of tall ones
		blade.Color = Color3.fromHSV(h0 + rng:NextNumber(-0.02, 0.03), math.clamp(s0 * rng:NextNumber(0.9, 1.15), 0, 1), math.clamp(v0 * rng:NextNumber(0.85, 1.2), 0, 1))
		if flower then
			item.head = item.head or newPart("Flower", Vector3.new(0.9, 0.7, 0.9), Color3.new(1, 1, 1))
			item.head.Color = FLOWERS[rng:NextInteger(1, #FLOWERS)]
			item.head.Parent = folder
		elseif item.head then
			item.head.Parent = nil
		end
		blade.Parent = folder
		local base = Vector3.new((cx + rng:NextNumber(0.05, 0.95)) * CELL, info.y, (cz + rng:NextNumber(0.05, 0.95)) * CELL)
		table.insert(items, { item = item, flower = flower, base = base, height = height, yaw = rng:NextNumber(0, TAU), phase = rng:NextNumber(0, TAU), lean = rng:NextNumber(-0.12, 0.12) })
	end
	active[k] = { items = items, cx = cx, cz = cz }
end

local function empty(k)
	local cell = active[k]
	if cell then
		for _, entry in ipairs(cell.items) do
			giveBack(entry.item)
		end
		active[k] = nil
	end
end

local function center()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or camera.CFrame.Position
end

-- Every quarter second: hand blades to the cells that came into range, take them back from the ones that left.
task.spawn(function()
	local filterAt = 0
	while true do
		task.wait(0.25)
		local now = os.clock()
		if now > filterAt then
			filterAt = now + 2
			refreshFilter()
		end
		local c = center()
		if c.Y < -100 then
			-- in the Kelp: nothing on the surface to draw
			for k in pairs(active) do
				empty(k)
			end
			continue
		end
		local ccx, ccz = math.floor(c.X / CELL), math.floor(c.Z / CELL)
		local reach = math.ceil(RADIUS / CELL)
		local rays = 0
		local wanted = {}
		for dz = -reach, reach do
			for dx = -reach, reach do
				if (dx * dx + dz * dz) * CELL * CELL <= RADIUS * RADIUS then
					local cx, cz = ccx + dx, ccz + dz
					local k = key(cx, cz)
					local info = ground[k]
					if info == nil and rays < RAYS_PER_TICK then
						rays += 1
						info = probe(cx, cz)
						ground[k] = info
					end
					if info then
						wanted[k] = true
						if not active[k] then
							fill(k, cx, cz, info)
						end
					end
				end
			end
		end
		for k in pairs(active) do
			if not wanted[k] then
				empty(k)
			end
		end
	end
end)

-- The sway, 20 times a second: the wind bends every blade, gusts roll across, and you push them aside.
local lastSway = 0
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	if t - lastSway < 1 / 20 then
		return
	end
	lastSway = t
	local w = workspace.GlobalWind
	local wind = w.Magnitude > 0.1 and Vector3.new(w.X, 0, w.Z).Unit or Vector3.new(1, 0, 0.4).Unit
	local me = center()
	local parts, cframes = {}, {}
	for _, cell in pairs(active) do
		for _, e in ipairs(cell.items) do
			local base = e.base
			-- a gust is a slow wave rolling along the wind
			local gust = 0.5 + 0.5 * math.sin(t * 0.9 - (base.X * wind.X + base.Z * wind.Z) * 0.05)
			local bend = (0.08 + 0.18 * gust) * math.sin(t * 2.6 + e.phase) + 0.12 * gust
			local tilt = wind * bend
			-- bend away from you as you walk through
			local away = Vector3.new(base.X - me.X, 0, base.Z - me.Z)
			local d = away.Magnitude
			if d < 3.5 and math.abs(base.Y - (me.Y - 3)) < 4 then
				tilt += (d > 0.01 and away.Unit or Vector3.new(1, 0, 0)) * (1 - d / 3.5) * 0.9
			end
			local pivot = CFrame.new(base) * CFrame.Angles(tilt.Z + e.lean, 0, -tilt.X) * CFrame.Angles(0, e.yaw, 0)
			local cf = pivot * CFrame.new(0, e.height / 2, 0)
			table.insert(parts, e.item.blade)
			table.insert(cframes, cf)
			if e.flower and e.item.head and e.item.head.Parent then
				table.insert(parts, e.item.head)
				table.insert(cframes, pivot * CFrame.new(0, e.height + 0.25, 0))
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
