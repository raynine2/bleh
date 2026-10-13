-- Tidebound: Eggfall: Highlands (14 Oct 2026). Rolling hills, high ridges and sea cliffs round Eggfall Town and a
-- hill on every Shoals island, so the world stops being one flat sheet (HJHJH: "the maps are very flat ... make it
-- bigger and not flat, maybe add hills"). Made of real Roblox Terrain (grass on top, rock on the steep sides, sand
-- at the waterline) and dressed with clones of the game's own 3D models (big trees, palms, cypresses, pines,
-- bushes, rocks and glowing crystals from TideboundLobby and TideboundRemake).
--
-- ADD-ONLY. It never moves, recolours or deletes anything. It first looks at what's already in the world: every spot
-- where anything stands (a road, a tree, a building, a lamp, an NPC, a bridge, a fishing spot...) is left flat and the
-- hills only rise on open grass, sand or sea, well away from it. So the Studio-built lobby, the districts, the
-- streets the villagers walk and every gameplay spot stay exactly as they are, and the hills fill the empty space
-- round them. Its models go in Workspace.TideboundWorld.Highlands.
--
-- Built at server start if it isn't there yet (Main). To bake it into the place instead, run this once in Studio's
-- command bar (Edit mode), look round, and save; Ctrl+Z undoes it:
--   require(game.ServerScriptService.Tidebound.Highlands).build()
-- Highlands.plan is pure maths (no Roblox calls), so it can be tested outside Studio.

local Highlands = {}

local VERSION = 1

Highlands.CELL = 4 -- one height per 4x4 studs, the size of a terrain voxel
Highlands.TOWN = { center = Vector3.new(0, 0, 0), reach = 600 }
Highlands.HARBOR = Vector3.new(0, 0, -560) -- the Harbor Ring and the Home Nest plots: a channel of sea stays open to it

-- Natural ground the hills may rise from. Anything else a ray hits counts as "something stands here".
local GROUND_NAMES = { Town_grass = true, Town_beach = true, Town_shore = true, Turf = true, Baseplate = true }
-- The game's own rock and mountain meshes: the hills grow round them (they rise out of the ridges) instead of
-- keeping clear the way they do round everything built.
local NATURAL_NAMES = { BackdropMountain = true, Mountain3D = true, Iceberg3D = true, MintRock3D = true, SeaStack = true, TallStack = true }
-- Rays start this high: anything floating above it (sky islands, light beams) doesn't stop a hill under it.
local LOOK_FROM = 46

local function smoothstep(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Smooth noise in 0..1 (Luau's own Perlin noise: the same in Studio, on servers and in tests).
local function valueNoise(x, z, seed)
	return math.clamp(math.noise(x, z, seed * 0.731 + 0.37) * 0.9 + 0.5, 0, 1)
end
local function fbm(x, z, seed)
	local total, amp, freq, norm = 0, 1, 1, 0
	for o = 1, 4 do
		total += valueNoise(x * freq, z * freq, seed + o * 17) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return total / norm
end

-- How high the land may rise at a spot, before clearance and noise: nothing in the lobby's heart, low rolling
-- ground in the garden ring, then hills climbing to high ridges and sea cliffs at the edge of town. The east (the
-- Harbor Street view toward the Shoals and the causeway) and the south beach stay open.
function Highlands.townAmplitude(x, z)
	local r = math.sqrt(x * x + z * z)
	local a
	if r < 115 then
		a = 0
	elseif r < 200 then
		a = 5 * smoothstep(115, 150, r) -- gentle mounds between the garden's trees
	elseif r < 260 then
		a = 5 + 25 * smoothstep(200, 260, r)
	elseif r < 340 then
		a = 30 + 45 * smoothstep(260, 340, r)
	elseif r < 480 then
		a = 75 + 45 * smoothstep(340, 440, r) -- the valley walls
	else
		a = 120 * (1 - smoothstep(470, 595, r)) -- the far side slopes down into the sea
	end
	-- keep the view east (Harbor Street, the Tidegate, the causeway, the Shoals on the horizon)
	local angle = math.abs(math.atan2(z, x))
	a *= smoothstep(math.rad(26), math.rad(44), angle)
	-- keep a channel of sea open to the Harbor Ring and its plots
	local hx, hz = x - Highlands.HARBOR.X, z - Highlands.HARBOR.Z
	a *= smoothstep(290, 340, math.sqrt(hx * hx + hz * hz))
	return a
end

-- How close to things the land may start to rise (studs): right up to the garden's trees in the lobby (small
-- mounds), well clear of everything further out (where the hills are big).
function Highlands.townClearance(x, z)
	local r = math.sqrt(x * x + z * z)
	if r < 230 then
		return 3, 14
	end
	return 8, 32
end

-- A small hill in the middle of an island: up to a third of its radius high, falling to nothing at its shore.
function Highlands.islandAmplitude(island, x, z)
	local dx, dz = x - island.pos.X, z - island.pos.Z
	local d = math.sqrt(dx * dx + dz * dz) / island.r
	return math.min(island.r * 0.3, 22) * (1 - smoothstep(0.25, 0.9, d))
end

-- Gameplay spots that only exist while the game runs (mobs, wild eggs) or that must stay level (beacons, geysers,
-- caches, the dive spawn): each is a circle the hills leave flat, read from IslesLayout.
function Highlands.keepFlat(L)
	local spots = {}
	local function add(at, radius)
		if typeof(at) == "Vector3" then
			table.insert(spots, { at = at, radius = radius })
		end
	end
	for _, c in ipairs(L.camps or {}) do add(c.at, (c.radius or 30) * 0.45) end
	for _, n in ipairs(L.eggNests or {}) do add(n.at, 10) end
	for _, b in ipairs(L.beacons or {}) do add(b, 16) end
	for _, f in ipairs(L.fishingSpots or {}) do add(f, 12) end
	for _, pair in ipairs(L.jumpPads or {}) do add(pair[1], 10); add(pair[2], 10) end
	for _, c in ipairs(L.tideCaches or {}) do add(c, 16) end
	for _, a in ipairs(L.anemoneBeds or {}) do add(a, 8) end
	for _, d in ipairs(L.eliteDens or {}) do add(d.at, d.radius or 30) end
	for _, c in ipairs(L.hiddenCaves or {}) do add(c.at, (c.radius or 20) + 6) end
	for _, v in ipairs(L.viewpoints or {}) do add(v.at, (v.radius or 10) + 6) end
	if L.diveSpawn then add(Vector3.new(L.diveSpawn.Position.X, 0, L.diveSpawn.Position.Z), 18) end
	if L.causeway then
		local a, b = L.causeway.from, L.causeway.to
		for t = 0, 1, 0.05 do add(a:Lerp(b, t), (L.causeway.width or 28) / 2 + 6) end
	end
	return spots
end

-- Islands are busy (paths, camps, caches, nests), so their hills come right up to things, like the garden's mounds.
function Highlands.islandClearance()
	return 3, 12
end

-- Distance (in cells) from every cell to the nearest cell where something stands, by two chamfer passes.
local function distanceToBlocked(kind, nx, nz)
	local INF = 1e9
	local dist = table.create(nx * nz, INF)
	for i = 1, nx * nz do
		if kind[i] == 3 then
			dist[i] = 0
		end
	end
	local D, DD = 1, 1.414
	for z = 1, nz do
		for x = 1, nx do
			local i = (z - 1) * nx + x
			local d = dist[i]
			if x > 1 then d = math.min(d, dist[i - 1] + D) end
			if z > 1 then
				d = math.min(d, dist[i - nx] + D)
				if x > 1 then d = math.min(d, dist[i - nx - 1] + DD) end
				if x < nx then d = math.min(d, dist[i - nx + 1] + DD) end
			end
			dist[i] = d
		end
	end
	for z = nz, 1, -1 do
		for x = nx, 1, -1 do
			local i = (z - 1) * nx + x
			local d = dist[i]
			if x < nx then d = math.min(d, dist[i + 1] + D) end
			if z < nz then
				d = math.min(d, dist[i + nx] + D)
				if x < nx then d = math.min(d, dist[i + nx + 1] + DD) end
				if x > 1 then d = math.min(d, dist[i + nx - 1] + DD) end
			end
			dist[i] = d
		end
	end
	return dist
end

-- The plan: for a grid of cells (`sample`), how high the new land stands over each one.
--   sample = { x0, z0, cell, nx, nz, kind = { 0 nothing / 1 ground / 2 water / 3 something stands here }, groundY,
--              waterY, floorY, amplitude = function(x, z) -> studs, seed }
-- Returns { base = {}, top = {} } (0 where nothing is added) and slope = {} (rise per stud, for materials).
function Highlands.plan(sample)
	local nx, nz, cell = sample.nx, sample.nz, sample.cell
	local kind, groundY = sample.kind, sample.groundY
	local dist = distanceToBlocked(kind, nx, nz)
	local h = table.create(nx * nz, 0)
	for z = 1, nz do
		for x = 1, nx do
			local i = (z - 1) * nx + x
			local k = kind[i]
			if k == 1 or k == 2 then
				local wx = sample.x0 + (x - 0.5) * cell
				local wz = sample.z0 + (z - 0.5) * cell
				local a = sample.amplitude(wx, wz)
				if a > 0.5 then
					-- clearance: flat right round anything standing, full height further out
					local near, far = 8, 32
					if sample.clearance then
						near, far = sample.clearance(wx, wz)
					end
					local clear = smoothstep(near, far, dist[i] * cell)
					-- rolling hills low down; broad ridges and peaks where the land is high (bigger shapes, so the
					-- slopes stay green and walkable instead of turning to cliff everywhere)
					local tall = smoothstep(20, 80, a)
					local seed = sample.seed or 7
					local n = fbm(wx / (60 + 80 * tall), wz / (60 + 80 * tall), seed)
					local ridge = 1 - math.abs(fbm(wx / 220, wz / 220, seed + 99) * 2 - 1)
					local shape = (0.35 + 0.45 * n) * (1 - 0.4 * tall) + ridge * ridge * 0.75 * tall
					h[i] = a * shape * clear
				end
			end
		end
	end
	-- soften: three passes of a 3x3 blur, never raising a spot where something stands
	for _ = 1, 3 do
		local out = table.clone(h)
		for z = 2, nz - 1 do
			for x = 2, nx - 1 do
				local i = (z - 1) * nx + x
				if kind[i] == 1 or kind[i] == 2 then
					local s = 0
					for dz = -1, 1 do
						for dx = -1, 1 do
							s += h[i + dz * nx + dx]
						end
					end
					out[i] = math.min(s / 9, h[i] + 2)
				end
			end
		end
		h = out
	end
	local base = table.create(nx * nz, 0)
	local top = table.create(nx * nz, 0)
	for i = 1, nx * nz do
		if h[i] >= 1 and kind[i] == 1 then
			base[i] = groundY[i] - 2
			top[i] = groundY[i] + h[i]
		elseif h[i] >= 3 and kind[i] == 2 then
			-- out at sea the hill climbs out of the water from the sea floor
			base[i] = sample.floorY
			top[i] = sample.waterY - 1 + h[i]
		end
	end
	local slope = table.create(nx * nz, 0)
	for z = 2, nz - 1 do
		for x = 2, nx - 1 do
			local i = (z - 1) * nx + x
			if top[i] > 0 then
				local function t(j)
					if top[j] > 0 then
						return top[j]
					elseif kind[j] == 2 then
						return sample.waterY
					elseif kind[j] == 1 then
						return groundY[j]
					end
					return top[i] -- next to something standing: don't count it as a drop
				end
				local gx = (t(i + 1) - t(i - 1)) / (2 * cell)
				local gz = (t(i + nx) - t(i - nx)) / (2 * cell)
				slope[i] = math.sqrt(gx * gx + gz * gz)
			end
		end
	end
	return { base = base, top = top, slope = slope, dist = dist }
end

-- Roblox side ------------------------------------------------------------------------------------------------------

-- Looks down at every cell and says what's there: natural ground, sea, or something standing. `extraGround` adds
-- part names that count as ground (an island's own land strips).
local function survey(x0, z0, cell, nx, nz, skip, extraGround)
	local terrain = workspace.Terrain
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { skip }
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = false
	local kind = table.create(nx * nz, 0)
	local groundY = table.create(nx * nz, 0)
	for z = 1, nz do
		for x = 1, nx do
			local i = (z - 1) * nx + x
			local origin = Vector3.new(x0 + (x - 0.5) * cell, LOOK_FROM, z0 + (z - 0.5) * cell)
			for _ = 1, 8 do
				local hit = workspace:Raycast(origin, Vector3.new(0, -(LOOK_FROM + 60), 0), params)
				if not hit then
					break
				end
				local inst = hit.Instance
				if inst:IsA("BasePart") and (inst.Transparency >= 0.9 or not inst.CanCollide and inst.Size.Y < 0.2 and inst.Transparency > 0.5) then
					-- invisible emitters, light volumes and the like: look through them
					table.insert(excluded, inst)
					params.FilterDescendantsInstances = excluded
				elseif inst == terrain then
					kind[i] = hit.Material == Enum.Material.Water and 2 or 1
					groundY[i] = hit.Position.Y
					break
				elseif (GROUND_NAMES[inst.Name] or (extraGround and extraGround[inst.Name])) and hit.Normal.Y > 0.9 then
					kind[i] = 1
					groundY[i] = hit.Position.Y
					break
				elseif NATURAL_NAMES[inst.Name] then
					-- a rock or mountain: look through it to the ground or sea under it, and let the hill grow round it
					table.insert(excluded, inst)
					params.FilterDescendantsInstances = excluded
				else
					kind[i] = 3
					break
				end
			end
		end
		if z % 20 == 0 then
			task.wait()
		end
	end
	return kind, groundY
end

-- Writes the planned land into the terrain, chunk by chunk, keeping every voxel it doesn't change.
local function writeTerrain(x0, z0, cell, nx, nz, plan, waterY)
	local terrain = workspace.Terrain
	local RES = 4
	local CHUNK = 32 -- cells per side per write
	local M = Enum.Material
	for cz = 1, nz, CHUNK do
		for cx = 1, nx, CHUNK do
			local ex, ez = math.min(cx + CHUNK - 1, nx), math.min(cz + CHUNK - 1, nz)
			local lo, hi = math.huge, -math.huge
			for z = cz, ez do
				for x = cx, ex do
					local i = (z - 1) * nx + x
					if plan.top[i] > 0 then
						lo = math.min(lo, plan.base[i])
						hi = math.max(hi, plan.top[i])
					end
				end
			end
			if hi > lo then
				lo = math.floor(lo / RES) * RES
				hi = math.ceil(hi / RES) * RES + RES
				local region = Region3.new(
					Vector3.new(x0 + (cx - 1) * cell, lo, z0 + (cz - 1) * cell),
					Vector3.new(x0 + ex * cell, hi, z0 + ez * cell)
				):ExpandToGrid(RES)
				local materials, occupancy = terrain:ReadVoxels(region, RES)
				local size = materials.Size
				local minY = region.CFrame.Position.Y - region.Size.Y / 2
				local minX = region.CFrame.Position.X - region.Size.X / 2
				local minZ = region.CFrame.Position.Z - region.Size.Z / 2
				for vx = 1, size.X do
					local wx = minX + (vx - 0.5) * RES
					local gx = math.floor((wx - x0) / cell) + 1
					for vz = 1, size.Z do
						local wz = minZ + (vz - 0.5) * RES
						local gz = math.floor((wz - z0) / cell) + 1
						if gx >= 1 and gx <= nx and gz >= 1 and gz <= nz then
							local i = (gz - 1) * nx + gx
							local top, base = plan.top[i], plan.base[i]
							if top > 0 then
								local s = plan.slope[i]
								local surface
								if top < waterY + 2.5 then
									surface = M.Sand
								elseif s > 1.5 then
									surface = M.Rock
								elseif s > 1.05 then
									surface = M.Slate
								elseif top > 60 and s < 0.35 then
									surface = M.Grass
								else
									surface = M.LeafyGrass
								end
								for vy = 1, size.Y do
									local y0 = minY + (vy - 1) * RES
									local y1 = y0 + RES
									if y1 > base and y0 < top then
										local fill = math.clamp((top - y0) / RES, 0, 1)
										if fill > occupancy[vx][vy][vz] or materials[vx][vy][vz] == M.Water or materials[vx][vy][vz] == M.Air then
											materials[vx][vy][vz] = (top - y1 > 6) and (s > 1.05 and M.Rock or M.Ground) or surface
											occupancy[vx][vy][vz] = math.max(fill, 0.05)
										end
									end
								end
							end
						end
					end
				end
				terrain:WriteVoxels(region, RES, materials, occupancy)
				task.wait()
			end
		end
	end
end

-- The game's own 3D models to dress the hills with, by height band. Missing ones are simply skipped.
local DRESS = {
	low = { "TideboundLobby/Trees/GenBigTree", "TideboundLobby/Trees/GenPalm", "TideboundLobby/Trees3D/GenBush", "TideboundLobby/Bushes3D/GenBush", "TideboundRemake/Town/GreeneryTrees" },
	mid = { "TideboundLobby/Trees/GenCypress", "TideboundLobby/Trees3D/GenCypress2", "TideboundRemake/Town/GreeneryTrees", "TideboundLobby/Trees/GenBigTree" },
	high = { "TideboundRemake/Town/BackdropPines", "TideboundRemake/Town/GreeneryPines", "TideboundLobby/Trees3D/GenCypress2" },
	rock = { "TideboundRemake/Round6/HarborExtras/MintRock3D" },
	glow = { "TideboundRemake/Round6/Crystals/CrystalCluster" },
}

local function template(path)
	local node = workspace
	local segments = string.split(path, "/")
	for k, seg in ipairs(segments) do
		local child = node:FindFirstChild(seg)
		if not child then
			return nil
		end
		node = child
		-- a folder full of copies: take its first model or mesh
		if k == #segments and node:IsA("Folder") then
			for _, c in ipairs(node:GetChildren()) do
				if c:IsA("Model") or c:IsA("BasePart") then
					return c
				end
			end
			return nil
		end
	end
	return (node:IsA("Model") or node:IsA("BasePart")) and node or nil
end

local function dress(folder, x0, z0, cell, nx, nz, plan, waterY, rng)
	local pools = {}
	for band, paths in pairs(DRESS) do
		pools[band] = {}
		for _, p in ipairs(paths) do
			local t = template(p)
			if t then
				table.insert(pools[band], t)
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local placed = {}
	local SPACING = 20 -- at most one model per 20x20 studs, so the hills stay light on the server
	local count = 0
	for z = 3, nz - 2, 3 do
		for x = 3, nx - 2, 3 do
			local i = (z - 1) * nx + x
			local top, s = plan.top[i], plan.slope[i]
			if top > waterY + 3 and plan.dist[i] * cell > 14 and rng:NextNumber() < 0.35 then
				local band
				local rise = top - waterY
				if s > 0.9 then
					band = rng:NextNumber() < 0.6 and "rock" or nil
				elseif rng:NextNumber() < 0.04 then
					band = "glow"
				elseif rise > 55 then
					band = "high"
				elseif rise > 22 then
					band = "mid"
				else
					band = "low"
				end
				local pool = band and pools[band]
				if pool and #pool > 0 then
					local wx = x0 + (x - 0.5 + rng:NextNumber(-1, 1)) * cell
					local wz = z0 + (z - 0.5 + rng:NextNumber(-1, 1)) * cell
					local key = math.floor(wx / SPACING) .. ":" .. math.floor(wz / SPACING)
					if not placed[key] then
						local hit = workspace:Raycast(Vector3.new(wx, top + 40, wz), Vector3.new(0, -120, 0), params)
						if hit and hit.Normal.Y > 0.55 then
							placed[key] = true
							local copy = pool[rng:NextInteger(1, #pool)]:Clone()
							local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
							if copy:IsA("Model") then
								local scale = rng:NextNumber(0.85, 1.25)
								copy:ScaleTo(copy:GetScale() * scale)
								local bbCf, bbSize = copy:GetBoundingBox()
								local lift = copy:GetPivot().Position.Y - (bbCf.Position.Y - bbSize.Y / 2)
								copy:PivotTo(CFrame.new(hit.Position + Vector3.new(0, lift - 0.6, 0)) * yaw)
							else
								copy.Size *= rng:NextNumber(0.85, 1.25)
								copy.Anchored = true
								copy.CFrame = CFrame.new(hit.Position + Vector3.new(0, copy.Size.Y / 2 - 0.6, 0)) * yaw
							end
							copy.Parent = folder
							count += 1
							if count % 40 == 0 then
								task.wait()
							end
						end
					end
				end
			end
		end
	end
	return count
end

local function region(folder, center, reach, amplitude, clearance, seed, L, rng, extraGround)
	local cell = Highlands.CELL
	local x0 = math.floor((center.X - reach) / cell) * cell
	local z0 = math.floor((center.Z - reach) / cell) * cell
	local n = math.ceil(reach * 2 / cell)
	local kind, groundY = survey(x0, z0, cell, n, n, folder, extraGround)
	for _, spot in ipairs(Highlands.keepFlat(L)) do
		local r = spot.radius
		if math.abs(spot.at.X - center.X) < reach + r and math.abs(spot.at.Z - center.Z) < reach + r then
			for z = math.max(1, math.floor((spot.at.Z - r - z0) / cell)), math.min(n, math.ceil((spot.at.Z + r - z0) / cell) + 1) do
				for x = math.max(1, math.floor((spot.at.X - r - x0) / cell)), math.min(n, math.ceil((spot.at.X + r - x0) / cell) + 1) do
					local wx, wz = x0 + (x - 0.5) * cell, z0 + (z - 0.5) * cell
					if (wx - spot.at.X) ^ 2 + (wz - spot.at.Z) ^ 2 <= r * r then
						kind[(z - 1) * n + x] = 3
					end
				end
			end
		end
	end
	local sample = { x0 = x0, z0 = z0, cell = cell, nx = n, nz = n, kind = kind, groundY = groundY, waterY = L.WATER_Y, floorY = L.sea.floorY, amplitude = amplitude, clearance = clearance, seed = seed }
	local plan = Highlands.plan(sample)
	writeTerrain(x0, z0, cell, n, n, plan, L.WATER_Y)
	return dress(folder, x0, z0, cell, n, n, plan, L.WATER_Y, rng)
end

-- Builds the highlands (once: a Highlands folder with this VERSION means it's already there).
function Highlands.build(world)
	world = world or workspace:WaitForChild("TideboundWorld")
	local existing = world:FindFirstChild("Highlands")
	if existing then
		if existing:GetAttribute("Version") ~= VERSION then
			-- an older build is baked into the place: building again would pile new hills on its terrain. Undo it
			-- in Studio (or delete the folder and its hills) first.
			warn("[Tidebound] Highlands: an older version is already in the place; not building over it")
		end
		return existing
	end
	local L = require(game:GetService("ReplicatedStorage"):WaitForChild("Tidebound"):WaitForChild("IslesLayout"))
	local ChangeHistory = game:GetService("ChangeHistoryService")
	local editing = not game:GetService("RunService"):IsRunning()
	local recording
	if editing then
		local ok, id = pcall(ChangeHistory.TryBeginRecording, ChangeHistory, "Tidebound Highlands")
		recording = ok and id or nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Highlands"
	folder:SetAttribute("Version", VERSION)
	folder:SetAttribute("Note", "Add-only hills (Highlands.luau). Terrain + clones of the game's 3D models.")
	folder.Parent = world
	local rng = Random.new(1414)
	local t = os.clock()
	local town = region(folder, Highlands.TOWN.center, Highlands.TOWN.reach, Highlands.townAmplitude, Highlands.townClearance, 7, L, rng)
	local islands = 0
	for _, island in ipairs(L.islands) do
		-- an island's ground: ShoalsBuilder's land strips (LandingReef, LandingReefTop, LandingReefShelf) or the 3D
		-- base the Studio remake stood it on (TideboundRemake.Round6.IslandBases.LandingReefBase)
		local ground = { [island.name] = true, [island.name .. "Top"] = true, [island.name .. "Shelf"] = true, [island.name .. "Base"] = true }
		islands += region(folder, island.pos, island.r + 12, function(x, z)
			return Highlands.islandAmplitude(island, x, z)
		end, Highlands.islandClearance, #island.name, L, rng, ground)
	end
	if recording then
		pcall(ChangeHistory.FinishRecording, ChangeHistory, recording, Enum.FinishRecordingOperation.Commit)
	end
	print(("[Tidebound] Highlands built in %.1f s: %d models round town, %d on the islands"):format(os.clock() - t, town, islands))
	return folder
end

return Highlands
