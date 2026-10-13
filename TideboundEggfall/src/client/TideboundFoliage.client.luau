-- Tidebound: Eggfall: thick voxel grass, on your screen only (Patch 13). Around the camera, every patch of ground
-- tagged TideboundGrass (the town's lawns, the Shallows' meadows, the Coral Maze's checkered tiles, Torii Hill's
-- terraces) fills with chunky blades in that ground's greens, with the odd flower. The blades sway in the wind
-- (Workspace.GlobalWind) and bend away from you as you wade through. Far away there's no grass to pay for: a fixed
-- pool of blades is handed out to the cells near the camera and taken back as you leave them.
-- 13 Oct 2026 (HJHJH: "i dont like it when im walking and i just see unloaded grass ... let me see more"): grass
-- now reaches about three times as far. Two rings: up to NEAR the tufts sway and bend as before; out to FAR they
-- stand still (placed once, nearly free) with fewer per cell. The ground is checked nearest first and much faster,
-- and new tufts rise out of the ground instead of popping in.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CELL = 6
local NEAR = 70 -- swaying tufts inside this
local RADIUS = 175 -- still tufts out to here
local PER_CELL = 5
local FAR_PER_CELL = 3
local POOL = 7500
local RAYS_PER_TICK = 260
local TICK = 0.15
local RISE = 0.45 -- seconds a new tuft takes to grow out of the ground
local TAU = math.pi * 2
local FLOWERS = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 230, 110), Color3.fromRGB(250, 250, 255), Color3.fromRGB(180, 140, 255) }

-- Soft 3D grass tufts and flower clumps (generated meshes) replace the old block blades when present.
local meshes = game:GetService("ReplicatedStorage"):WaitForChild("TideboundFoliageMeshes", 10)
local TUFT = meshes and meshes:FindFirstChild("GrassTuft")
local FLOWER_TUFT = meshes and meshes:FindFirstChild("FlowerTuft")

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
	if TUFT then
		local tuft = TUFT:Clone()
		tuft.Name = "Blade"
		return { blade = tuft, head = nil }
	end
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
	for _, name in ipairs({ "TideboundFX", "TideboundMobs", "TideboundLife", "TideboundRodFX", "TideboundHatchFX" }) do
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
local active = {} -- [key] = { items = { { item, base, height, yaw, phase, lean } }, near = bool }
local function fill(k, cx, cz, info, near, had)
	local rng = Random.new(k)
	local items = {}
	local h0, s0, v0 = info.color:ToHSV()
	for _ = 1, near and PER_CELL or FAR_PER_CELL do
		local item = takeBlade()
		if not item then
			break
		end
		local flower = rng:NextNumber() < 0.07
		local height = flower and rng:NextNumber(1.2, 1.8) or rng:NextNumber(1.4, 3.4)
		local blade = item.blade
		if TUFT then
			height = rng:NextNumber(0.8, 1.5)
			local w = rng:NextNumber(1.6, 2.6)
			blade.Size = Vector3.new(w, height, w * rng:NextNumber(0.85, 1.15))
		else
			blade.Size = Vector3.new(rng:NextNumber(0.55, 0.85), height, rng:NextNumber(0.55, 0.85))
		end
		-- the ground's own green, a little lighter or darker per blade, lighter toward the tips of tall ones
		blade.Color = Color3.fromHSV(h0 + rng:NextNumber(-0.02, 0.03), math.clamp(s0 * rng:NextNumber(0.9, 1.15), 0, 1), math.clamp(v0 * rng:NextNumber(0.85, 1.2), 0, 1))
		if flower then
			if FLOWER_TUFT then
				if not item.head then
					item.head = FLOWER_TUFT:Clone()
					item.head.Name = "Flower"
				end
				local fs = rng:NextNumber(1.3, 1.9)
				item.head.Size = Vector3.new(fs, fs * 1.1, fs)
			else
				item.head = item.head or newPart("Flower", Vector3.new(0.9, 0.7, 0.9), Color3.new(1, 1, 1))
				item.head.Color = FLOWERS[rng:NextInteger(1, #FLOWERS)]
			end
			item.head.Parent = folder
		elseif item.head then
			item.head.Parent = nil
		end
		blade.Parent = folder
		local base = Vector3.new((cx + rng:NextNumber(0.05, 0.95)) * CELL, info.y, (cz + rng:NextNumber(0.05, 0.95)) * CELL)
		table.insert(items, { item = item, flower = flower, base = base, height = height, yaw = rng:NextNumber(0, TAU), phase = rng:NextNumber(0, TAU), lean = rng:NextNumber(-0.12, 0.12), born = #items < (had or 0) and -10 or os.clock() })
	end
	active[k] = { items = items, cx = cx, cz = cz, near = near }
end

-- where a tuft (and its flower) stands for a given tilt; `sink` pushes it into the ground while it grows in
local function placeOf(e, tiltX, tiltZ, sink)
	local pivot = CFrame.new(e.base - Vector3.new(0, sink, 0)) * CFrame.Angles(tiltZ + e.lean, 0, -tiltX) * CFrame.Angles(0, e.yaw, 0)
	local cf = pivot * CFrame.new(0, e.height / 2 - (TUFT and 0.08 or 0), 0)
	local headCf = nil
	if e.flower and e.item.head and e.item.head.Parent then
		if FLOWER_TUFT then
			headCf = pivot * CFrame.new(0.9, e.item.head.Size.Y / 2 - 0.1, 0.4)
		else
			headCf = pivot * CFrame.new(0, e.height + 0.25, 0)
		end
	end
	return cf, headCf
end

-- far tufts don't sway: stand them up once
local function standStill(cell)
	local parts, cframes = {}, {}
	for _, e in ipairs(cell.items) do
		local cf, headCf = placeOf(e, 0, 0, 0)
		table.insert(parts, e.item.blade)
		table.insert(cframes, cf)
		if headCf then
			table.insert(parts, e.item.head)
			table.insert(cframes, headCf)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
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

-- The cells around you, nearest first, so the ground right ahead is always checked before the far rings.
local OFFSETS = {}
do
	local reach = math.ceil(RADIUS / CELL)
	for dz = -reach, reach do
		for dx = -reach, reach do
			local d2 = (dx * dx + dz * dz) * CELL * CELL
			if d2 <= RADIUS * RADIUS then
				table.insert(OFFSETS, { dx, dz, d2 <= NEAR * NEAR, d2 })
			end
		end
	end
	table.sort(OFFSETS, function(a, b)
		return a[4] < b[4]
	end)
end

-- Every few frames: hand blades to the cells that came into range, take them back from the ones that left.
task.spawn(function()
	local filterAt = 0
	while true do
		task.wait(TICK)
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
		local rays = 0
		local wanted = {}
		for _, off in ipairs(OFFSETS) do
			local cx, cz = ccx + off[1], ccz + off[2]
			local k = key(cx, cz)
			local info = ground[k]
			if info == nil and rays < RAYS_PER_TICK then
				rays += 1
				info = probe(cx, cz)
				ground[k] = info
			end
			if info then
				wanted[k] = true
				local near = off[3]
				local cell = active[k]
				local had = 0
				if cell and cell.near ~= near then
					had = #cell.items
					-- crossing between the rings: the same seed puts the first tufts back in the same places
					empty(k)
					cell = nil
				end
				if not cell then
					fill(k, cx, cz, info, near, had)
					if not near then
						standStill(active[k])
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
		if not cell.near then
			continue
		end
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
			local grow = math.clamp((t - e.born) / RISE, 0, 1)
			local sink = (1 - grow * grow * (3 - 2 * grow)) * (e.height + 0.3)
			local cf, headCf = placeOf(e, tilt.X, tilt.Z, sink)
			table.insert(parts, e.item.blade)
			table.insert(cframes, cf)
			if headCf then
				table.insert(parts, e.item.head)
				table.insert(cframes, headCf)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
