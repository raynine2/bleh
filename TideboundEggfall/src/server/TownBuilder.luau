-- Tidebound: Eggfall: Eggfall Town, the safe spawn of the Open Isles (Patch 10). Builds
-- Workspace.TideboundWorld.Town around WorldBuilder's REF 1 fountain plaza, laid out by IslesLayout.Town:
--   the town island itself (grass, sand and cliffs down to the sea floor), with snow on the plaza (REF 1)
--   Harbor Street and the docks (east): fish market, warehouses, the Salty Egg tavern, two piers over the
--     harbor basins, moored boats, cranes and nets, and the Tidegate, where the causeway to the Shoals starts
--   Market Row (north): REF 3 neon shops, food stalls round a market square, an arcade and string lights
--   Torii Hill (west): REF 1 snowy terraces climbed by REF 5 torii stairs to a shrine overlook, where the
--     sky's light beam rises; a koi pond at its foot
--   Hatchery Farms (south-west): crop rows, a turning windmill, red egg barns, hay and fences
--   South Beach (south): sand, umbrellas, palms, a lifeguard tower and the ferry pier to the Harbor Ring
--   Lighthouse Point (north-east): a headland with the striped lighthouse and a telescope
-- Streets follow IslesLayout.Town.edges (TideboundLife walks villagers along them); where an edge crosses
-- water it becomes a boardwalk. Everything inside the plaza radius is WorldBuilder's and left alone.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local DescentBuilder = require(script.Parent:WaitForChild("DescentBuilder"))
local L = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("IslesLayout"))
local PropKit = require(script.Parent:WaitForChild("PropKit"))
local PC = PropKit.color

local TownBuilder = {}

local VERSION = 4

local K = WorldBuilder.kit
local D = DescentBuilder.kit
local P = K.color
local part, decor, disk, prompt, billboard, light, rod, surfaceText = K.part, K.decor, K.disk, K.prompt, K.billboard, K.light, K.rod, K.surfaceText
local TOP, WATER_Y = L.TOP, L.WATER_Y
local FLOOR = L.sea.floorY - 2
local T = L.Town

-- palette
local SAND = Color3.fromRGB(212, 190, 140)
local COBBLE = PC.PAVER -- Patch 14: grey studded paving, like the reference snow town
local COBBLE_EDGE = PC.PAVER_DARK
local WOOD = Color3.fromRGB(150, 104, 68)
local WOOD_DARK = Color3.fromRGB(104, 72, 50)
local SOIL = Color3.fromRGB(110, 78, 56)
local BARN_RED = Color3.fromRGB(186, 52, 44)
local WHITE = Color3.fromRGB(244, 242, 236)
local NEONS = { Color3.fromRGB(110, 236, 255), Color3.fromRGB(255, 90, 170), Color3.fromRGB(255, 214, 80), Color3.fromRGB(140, 255, 140), Color3.fromRGB(190, 130, 255) }
local SIGN_DARK = Color3.fromRGB(20, 16, 34)
local BULBS = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 140, 120), Color3.fromRGB(140, 220, 255), Color3.fromRGB(180, 255, 150) }

local function flat(position)
	return Vector3.new(position.X, 0, position.Z)
end

local function at(position, y)
	return Vector3.new(position.X, y, position.Z)
end

local function v(x, z)
	return Vector3.new(x, 0, z)
end

local function facing(position, target, y)
	y = y or TOP
	return CFrame.lookAt(at(position, y), at(target, y))
end

-- Clearance for random trees and props.
local reserved = {}
local function reserve(position, radius)
	table.insert(reserved, { flat(position), radius })
end
local function free(position, radius)
	local f = flat(position)
	for _, entry in ipairs(reserved) do
		if (f - entry[1]).Magnitude < entry[2] + radius then
			return false
		end
	end
	return true
end

-- The town island ---------------------------------------------------------------------------------------------
-- A union of grass shapes (all topped at TOP) plus the beach (a little lower, so grass wins where they meet).

local LAND = T.land -- IslesLayout (Patch 12: shared, so the sea chart draws the same coast)
local BEACH = T.beach

local function inShape(shape, p, margin)
	local f = flat(p)
	if shape.kind == "disk" then
		return (f - shape.c).Magnitude <= shape.r - margin
	end
	local d = f - shape.c
	return math.abs(d.X) <= shape.size.X / 2 - margin and math.abs(d.Z) <= shape.size.Z / 2 - margin
end

local function isLand(p, margin)
	margin = margin or 0
	for _, shape in ipairs(LAND) do
		if inShape(shape, p, margin) then
			return true
		end
	end
	return (flat(p) - BEACH.c).Magnitude <= BEACH.r - margin
end

-- Patch 13: the whole island is rasterised onto a 6-stud grid and laid as studded strips (grass, the snowy
-- plaza, the beach, the sand shore), so the coast has the reference's stepped voxel edge and no two strips
-- overlap. Grass strips are tagged TideboundGrass: TideboundFoliage grows tall voxel grass on them.
local GRID = 6
local function buildLand(parent)
	local function kindAt(x, z)
		local p = v(x, z)
		if p.Magnitude <= T.plazaRadius + 4 then
			return "plaza"
		end
		for _, shape in ipairs(LAND) do
			if inShape(shape, p, 0) then
				return "grass"
			end
		end
		if (flat(p) - BEACH.c).Magnitude <= BEACH.r then
			return "beach"
		end
		if isLand(p, -7) then
			return "shore"
		end
		return nil
	end
	-- Patch 14: the town is snow (the reference winter town): studded blue-white snow, a slightly greyer plaza,
	-- and frosted white grass (TideboundFoliage) only out on the edges, so the streets stay clean
	local STYLE = {
		grass = { top = TOP, color = PC.SNOW },
		plaza = { top = TOP, color = Color3.fromRGB(206, 216, 234) },
		beach = { top = TOP - 0.4, color = SAND },
		shore = { top = WATER_Y + 0.8, color = SAND:Lerp(Color3.fromRGB(180, 160, 120), 0.3) },
	}
	for gz = -228, 228 - GRID, GRID do
		local zc = gz + GRID / 2
		local runKind, runStart = nil, nil
		local function flush(xEnd)
			if runKind then
				local style = STYLE[runKind]
				local w = xEnd - runStart
				local strip = part({ Name = "Town_" .. runKind, Size = Vector3.new(w, style.top - FLOOR, GRID), CFrame = CFrame.new(runStart + w / 2, (style.top + FLOOR) / 2, zc), Color = style.color, Material = Enum.Material.Plastic, Parent = parent })
				strip.TopSurface = Enum.SurfaceType.Studs
				if runKind == "grass" and Vector3.new(runStart + w / 2, 0, zc).Magnitude > 130 then
					CollectionService:AddTag(strip, "TideboundGrass")
				end
			end
		end
		for gx = -228, 228, GRID do
			local kind = gx < 228 and kindAt(gx + GRID / 2, zc) or nil
			if kind ~= runKind then
				flush(gx)
				runKind, runStart = kind, gx
			end
		end
	end
	-- sea cliffs: rocks along the shore
	local rng = Random.new(91)
	for _, shape in ipairs(LAND) do
		if shape.kind == "disk" then
			for _ = 1, math.floor(shape.r / 4) do
				local a = rng:NextNumber(0, math.pi * 2)
				local p = shape.c + Vector3.new(math.cos(a), 0, math.sin(a)) * (shape.r + rng:NextNumber(2, 5))
				if not isLand(p, 1) then
					K.mintRock(parent, at(p, WATER_Y + 0.8), rng, 1.3)
				end
			end
		end
	end
end

-- Streets -----------------------------------------------------------------------------------------------------

local function lamp(parent, base, target)
	PropKit.gallowsLamp(parent, base, target) -- Patch 14: the reference's wooden lamp with a hanging lantern
end

-- A cobbled street from a to b (clipped to stay out of the plaza), with curbs and lamps; a boardwalk over water.
local function street(parent, a, b, width, index)
	local fa, fb = flat(a), flat(b)
	local plaza = T.plazaRadius + 1
	-- clip the part that runs inside the plaza
	local function clip(p, q)
		if p.Magnitude >= plaza then
			return p
		end
		local dir = (q - p).Unit
		for s = 0, (q - p).Magnitude, 1 do
			local x = p + dir * s
			if x.Magnitude >= plaza then
				return x
			end
		end
		return q
	end
	if fa.Magnitude < plaza and fb.Magnitude < plaza then
		return
	end
	fa, fb = clip(fa, fb), clip(fb, fa)
	local length = (fb - fa).Magnitude
	if length < 1 then
		return
	end
	local mid = (fa + fb) / 2
	if not isLand(mid, 2) then
		K.boardwalkSegment(parent, fa, fb, width)
		return
	end
	local frame = CFrame.lookAt(at(mid, TOP + 0.1), at(fb, TOP + 0.1))
	-- studded paving (queryable, so no grass grows through it) with a darker kerb either side
	local paving = decor({ Name = "Street", Size = Vector3.new(width, 0.2, length + width * 0.6), CFrame = frame, Color = COBBLE, Material = Enum.Material.Plastic, Parent = parent })
	paving.TopSurface = Enum.SurfaceType.Studs
	paving.CanQuery = true
	for _, side in ipairs({ -1, 1 }) do
		local kerb = decor({ Name = "Curb", Size = Vector3.new(1, 0.5, length), CFrame = frame * CFrame.new(side * (width / 2 + 0.5), 0.15, 0), Color = COBBLE_EDGE, Material = Enum.Material.Plastic, Parent = parent })
		kerb.TopSurface = Enum.SurfaceType.Studs
		kerb.CanQuery = true
	end
	local count = math.floor(length / 26)
	for i = 0, count do
		local z = -length / 2 + (i + 0.5) * (length / (count + 1))
		local side = ((i + index) % 2 == 0) and 1 or -1
		local base = (frame * CFrame.new(side * (width / 2 + 1.6), -0.06, z)).Position
		if isLand(base, 1) and free(base, 1.5) then
			lamp(parent, base, (frame * CFrame.new(0, 0, z)).Position)
			reserve(base, 2)
		end
	end
	-- keep trees and props off the street
	for s = 0, length, 8 do
		reserve(fa + (fb - fa).Unit * s, width / 2 + 2)
	end
end

local function buildStreets(parent)
	local main = { D1 = true, D2 = true, D3 = true, D4 = true }
	for i, edge in ipairs(T.edges) do
		local a, b = T.nodes[edge[1]], T.nodes[edge[2]]
		local width = (main[edge[1]] and main[edge[2]]) and 12 or 8
		-- the piers themselves (PN1-PN2, PS1-PS2) are wide plank piers, built with the docks
		local pierEdge = (edge[1]:sub(1, 2) == "PN" or edge[1]:sub(1, 2) == "PS") and (edge[2]:sub(1, 2) == "PN" or edge[2]:sub(1, 2) == "PS")
		if not pierEdge then
			street(parent, a, b, width, i)
		end
	end
end

-- Buildings ---------------------------------------------------------------------------------------------------

-- Patch 13: a detailed shopfront in the reference's style. A studded stone plinth, walls with chunky corner
-- pillars and trim bands, a cornice and parapet, big framed display windows with glass and mullions, a panelled
-- door with a glowing transom, a striped awning with a scalloped edge on brackets, a framed sign with a neon
-- border, a flag on the roof that flaps in the wind, and a potted plant, crates or a bench out front.
local function neonShop(parent, center, target, title, color, w, d, h)
	w, d, h = w or 14, d or 10, h or 10
	local cf = facing(center, target)
	local model = Instance.new("Model")
	model.Name = "Shop"
	model.Parent = parent
	local wall = color:Lerp(Color3.fromRGB(236, 230, 220), 0.55)
	local trim = color:Lerp(Color3.fromRGB(40, 30, 50), 0.45)
	local dark = Color3.fromRGB(46, 40, 52)
	local front = -d / 2
	local function studs(p)
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		return p
	end
	studs(part({ Name = "Plinth", Size = Vector3.new(w + 1.6, 1, d + 1.6), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(150, 152, 162), Parent = model }))
	part({ Name = "Body", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, 1 + h / 2, 0), Color = wall, Parent = model })
	-- corner pillars and trim bands
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			decor({ Name = "Pillar", Size = Vector3.new(1.4, h + 0.4, 1.4), CFrame = cf * CFrame.new(x, 1 + h / 2, z), Color = trim, Parent = model })
		end
	end
	decor({ Name = "TrimBand", Size = Vector3.new(w + 0.4, 0.6, d + 0.4), CFrame = cf * CFrame.new(0, 1 + h * 0.6, 0), Color = trim, Parent = model })
	decor({ Name = "Cornice", Size = Vector3.new(w + 1.6, 0.8, d + 1.6), CFrame = cf * CFrame.new(0, 1 + h + 0.4, 0), Color = trim, Parent = model })
	studs(decor({ Name = "Roof", Size = Vector3.new(w + 0.8, 0.6, d + 0.8), CFrame = cf * CFrame.new(0, 1 + h + 1.1, 0), Color = Color3.fromRGB(120, 124, 136), Parent = model }))
	for _, x in ipairs({ -w / 2 - 0.4, w / 2 + 0.4 }) do
		decor({ Name = "Parapet", Size = Vector3.new(0.6, 1, d + 1.6), CFrame = cf * CFrame.new(x, 1 + h + 1.3, 0), Color = trim, Parent = model })
	end
	-- display windows either side of the door
	local winW = (w - 5) / 2 - 1
	for _, side in ipairs({ -1, 1 }) do
		local at = cf * CFrame.new(side * (2.5 + winW / 2 + 0.3), 1 + 3.4, front - 0.12)
		decor({ Name = "WindowFrame", Size = Vector3.new(winW + 0.8, 4.6, 0.4), CFrame = at, Color = dark, Parent = model })
		decor({ Name = "Glass", Size = Vector3.new(winW, 3.8, 0.3), CFrame = at * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(150, 210, 240), Material = Enum.Material.Glass, Transparency = 0.3, Parent = model })
		decor({ Name = "WindowGlow", Size = Vector3.new(winW - 0.4, 3.4, 0.1), CFrame = at * CFrame.new(0, 0, 0.12), Color = Color3.fromRGB(255, 232, 180), Material = Enum.Material.Neon, Transparency = 0.45, Parent = model })
		decor({ Name = "Mullion", Size = Vector3.new(0.25, 3.8, 0.4), CFrame = at * CFrame.new(0, 0, -0.15), Color = dark, Parent = model })
		decor({ Name = "Sill", Size = Vector3.new(winW + 1.2, 0.4, 0.9), CFrame = at * CFrame.new(0, -2.45, -0.35), Color = trim, Parent = model })
	end
	-- the door, its frame and a glowing transom
	local door = cf * CFrame.new(0, 1 + 2.5, front - 0.12)
	decor({ Name = "DoorFrame", Size = Vector3.new(4, 5.6, 0.4), CFrame = door * CFrame.new(0, 0.3, 0), Color = dark, Parent = model })
	decor({ Name = "Door", Size = Vector3.new(3, 4.6, 0.3), CFrame = door * CFrame.new(0, -0.2, -0.12), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Parent = model })
	decor({ Name = "DoorGlass", Size = Vector3.new(1.8, 1.8, 0.2), CFrame = door * CFrame.new(0, 0.7, -0.25), Color = Color3.fromRGB(255, 232, 180), Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	decor({ Name = "Transom", Size = Vector3.new(3, 0.6, 0.2), CFrame = door * CFrame.new(0, 2.6, -0.2), Color = color, Material = Enum.Material.Neon, Parent = model })
	studs(part({ Name = "Step", Size = Vector3.new(4.4, 0.5, 1.6), CFrame = cf * CFrame.new(0, 0.25, front - 1.6), Color = Color3.fromRGB(150, 152, 162), Parent = model }))
	-- striped awning on brackets, with a scalloped edge
	local stripes = math.max(5, math.floor(w / 2))
	for i = 1, stripes do
		local x = -w / 2 + (i - 0.5) * (w / stripes)
		local c = (i % 2 == 0) and WHITE or color
		decor({ Name = "Awning", Size = Vector3.new(w / stripes + 0.02, 0.3, 3.4), CFrame = cf * CFrame.new(x, 1 + 6.4, front - 1.5) * CFrame.Angles(math.rad(-20), 0, 0), Color = c, Parent = model })
		decor({ Name = "Scallop", Size = Vector3.new(w / stripes * 0.8, 0.7, 0.3), CFrame = cf * CFrame.new(x, 1 + 5.55, front - 3.1), Color = c, Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Bracket", Size = Vector3.new(0.3, 0.3, 3), CFrame = cf * CFrame.new(side * (w / 2 - 0.4), 1 + 6, front - 1.4) * CFrame.Angles(math.rad(-30), 0, 0), Color = dark, Parent = model })
	end
	-- the sign: a framed board with a neon border, above the awning
	local signCf = cf * CFrame.new(0, 1 + h - 1.6, front - 0.5)
	local board = decor({ Name = "Sign", Size = Vector3.new(w - 3, 2.6, 0.5), CFrame = signCf, Color = Color3.fromRGB(28, 22, 40), Parent = model })
	surfaceText(board, title, color:Lerp(WHITE, 0.25))
	for _, spec in ipairs({ { 0, 1.4, w - 2.4, 0.25 }, { 0, -1.4, w - 2.4, 0.25 }, { -(w - 3) / 2 - 0.2, 0, 0.25, 3 }, { (w - 3) / 2 + 0.2, 0, 0.25, 3 } }) do
		decor({ Name = "SignNeon", Size = Vector3.new(spec[3], spec[4], 0.3), CFrame = signCf * CFrame.new(spec[1], spec[2], -0.1), Color = color, Material = Enum.Material.Neon, Parent = model })
	end
	light(board, color, 16, 1.2)
	-- a flag on the roof that flaps in the wind
	local pole = cf * CFrame.new(w / 2 - 1, 1 + h + 1.4, d / 2 - 1)
	decor({ Name = "FlagPole", Size = Vector3.new(0.3, 6, 0.3), CFrame = pole * CFrame.new(0, 3, 0), Color = Color3.fromRGB(200, 200, 206), Parent = model })
	K.windy(decor({ Name = "Flag", Size = Vector3.new(0.12, 1.6, 2.6), CFrame = pole * CFrame.new(0, 5.1, 1.3), Color = color, Parent = model }))
	-- a little life out front
	local extra = math.random(1, 3)
	local beside = cf * CFrame.new(w / 2 + 1.6, 0, front - 1)
	if extra == 1 then
		decor({ Name = "Pot", Size = Vector3.new(1.6, 1.4, 1.6), CFrame = beside * CFrame.new(0, 0.7, 0), Color = Color3.fromRGB(176, 96, 70), Parent = model })
		for k = 1, 4 do
			K.windy(decor({ Name = "Leaf", Size = Vector3.new(0.6, 1.8, 0.6), CFrame = beside * CFrame.new(math.cos(k * 1.6) * 0.4, 2.1, math.sin(k * 1.6) * 0.4) * CFrame.Angles(math.cos(k) * 0.4, 0, math.sin(k) * 0.4), Color = Color3.fromRGB(70, 160, 70), Parent = model }))
		end
	elseif extra == 2 then
		K.crate(model, beside * CFrame.new(0, 1.3, 0))
		K.crate(model, beside * CFrame.new(0.3, 3.9, 0.2) * CFrame.Angles(0, 0.4, 0))
	else
		local bench = cf * CFrame.new(-w / 2 - 2, 0, front - 1.2)
		decor({ Name = "BenchSeat", Size = Vector3.new(0.9, 0.4, 3.6), CFrame = bench * CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(150, 104, 68), Parent = model })
		decor({ Name = "BenchBack", Size = Vector3.new(0.3, 1.2, 3.6), CFrame = bench * CFrame.new(-0.4, 1.9, 0), Color = Color3.fromRGB(150, 104, 68), Parent = model })
		for _, z in ipairs({ -1.4, 1.4 }) do
			decor({ Name = "BenchLeg", Size = Vector3.new(0.9, 1, 0.3), CFrame = bench * CFrame.new(0, 0.5, z), Color = dark, Parent = model })
		end
	end
	reserve(center, math.max(w, d) * 0.75)
	return cf
end

local function warehouse(parent, center, target, w, d, h, roof)
	local cf = facing(center, target)
	local model = Instance.new("Model")
	model.Name = "Warehouse"
	model.Parent = parent
	part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = model })
	for x = -w / 2, w / 2, 4 do
		decor({ Name = "Beam", Size = Vector3.new(0.6, h, 0.4), CFrame = cf * CFrame.new(x, h / 2, -d / 2 - 0.2), Color = WOOD_DARK, Parent = model })
	end
	decor({ Name = "BigDoor", Size = Vector3.new(w * 0.4, h * 0.7, 0.3), CFrame = cf * CFrame.new(0, h * 0.35, -d / 2 - 0.3), Color = WOOD_DARK, Parent = model })
	local angle = math.rad(28)
	local half = d / 2 + 1
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "Roof", Size = Vector3.new(w + 2, 0.8, half / math.cos(angle)), CFrame = cf * CFrame.new(0, h + math.tan(angle) * half / 2, dir * half / 2) * CFrame.Angles(dir * angle, 0, 0), Color = roof, Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Gable", Size = Vector3.new(0.6, math.tan(angle) * half * 1.4, d - 1), CFrame = cf * CFrame.new(side * (w / 2 - 0.3), h + math.tan(angle) * half * 0.35, 0), Color = WOOD, Parent = model })
	end
	reserve(center, math.max(w, d) * 0.65)
	return cf
end

local function barrels(parent, base, rng, count)
	for _ = 1, count do
		local p = base + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local barrel = decor({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2, 2), CFrame = CFrame.new(at(p, TOP + 1.2)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(140, 94, 58), Parent = parent })
		for _, y in ipairs({ -0.7, 0.7 }) do
			decor({ Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.1, 2.1), CFrame = barrel.CFrame * CFrame.new(y, 0, 0), Color = Color3.fromRGB(70, 70, 76), Parent = parent })
		end
	end
end

-- A small fishing boat, moored. TideboundLife bobs anything tagged TideboundBob around its Home.
local function boat(parent, position, yaw, color, rng)
	local model = Instance.new("Model")
	model.Name = "Boat"
	local cf = CFrame.new(at(position, WATER_Y + 0.6)) * CFrame.Angles(0, yaw, 0)
	local hull = part({ Name = "Hull", Size = Vector3.new(6, 2.2, 14), CFrame = cf, Color = color, CanCollide = false, Parent = model })
	part({ Name = "Bow", Size = Vector3.new(4.2, 2.2, 4.2), CFrame = cf * CFrame.new(0, 0, -7.4) * CFrame.Angles(0, math.rad(45), 0), Color = color, CanCollide = false, Parent = model })
	decor({ Name = "Deck", Size = Vector3.new(5.2, 0.3, 13), CFrame = cf * CFrame.new(0, 1.1, 0), Color = WOOD, Parent = model })
	decor({ Name = "Trim", Size = Vector3.new(6.2, 0.4, 14.2), CFrame = cf * CFrame.new(0, 0.6, 0), Color = WHITE, Parent = model })
	if rng:NextNumber() < 0.6 then
		decor({ Name = "Mast", Size = Vector3.new(0.5, 11, 0.5), CFrame = cf * CFrame.new(0, 6.5, -1), Color = WOOD_DARK, Parent = model })
		decor({ Name = "Sail", Size = Vector3.new(0.15, 7, 5), CFrame = cf * CFrame.new(0, 7, 1.6), Color = Color3.fromRGB(248, 240, 220), Parent = model })
	else
		decor({ Name = "Cabin", Size = Vector3.new(4, 3, 4), CFrame = cf * CFrame.new(0, 2.6, 2.5), Color = WHITE, Parent = model })
		decor({ Name = "CabinRoof", Size = Vector3.new(4.6, 0.4, 4.6), CFrame = cf * CFrame.new(0, 4.3, 2.5), Color = color, Parent = model })
	end
	model.PrimaryPart = hull
	model:SetAttribute("Home", cf)
	model:SetAttribute("Seed", rng:NextNumber(0, 10))
	CollectionService:AddTag(model, "TideboundBob")
	model.Parent = parent
end

-- A wide plank pier from `a` out to `b` with a T-head and bollards.
local function pier(parent, a, b, width, rng)
	local fa, fb = flat(a), flat(b)
	local dir = (fb - fa).Unit
	local tip = fb + dir * 8
	K.boardwalkSegment(parent, fa, tip, width)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	K.boardwalkSegment(parent, tip - side * 12, tip + side * 12, 7)
	for i = 1, 4 do
		local p = fa + dir * (i * (fb - fa).Magnitude / 5)
		for _, s in ipairs({ -1, 1 }) do
			decor({ Name = "Bollard", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 1.2, 1.2), CFrame = CFrame.new(at(p + side * s * (width / 2 - 0.8), TOP + 0.7)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 60, 66), Parent = parent })
		end
	end
	barrels(parent, tip + side * 9, rng, 3)
	K.crate(parent, CFrame.new(at(tip - side * 9, TOP + 1.3)) * CFrame.Angles(0, 0.4, 0))
end

local function stringLights(parent, a, b, rng)
	local count = math.floor((b - a).Magnitude / 2.5)
	local previous = a
	for i = 1, count do
		local s = i / count
		local p = a:Lerp(b, s) - Vector3.new(0, 2.2 * 4 * s * (1 - s), 0)
		rod(parent, previous, p, 0.12, Color3.fromRGB(40, 40, 46))
		if i < count then
			decor({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(p - Vector3.new(0, 0.35, 0)), Color = BULBS[rng:NextInteger(1, #BULBS)], Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
		end
		previous = p
	end
end

-- Districts ---------------------------------------------------------------------------------------------------

local function buildDocks(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "HarborStreet"
	folder.Parent = parent
	local n = T.nodes

	-- north side: a warehouse, the fish market hall and a crane; south side: the Salty Egg tavern, a boat shed
	warehouse(folder, v(78, 30), v(78, 0), 22, 14, 10, P.ROOF_SLATE)
	warehouse(folder, v(176, -20), v(176, 0), 24, 16, 11, P.ROOF_ORANGE)
	neonShop(folder, v(72, -28), v(72, 0), "THE SALTY EGG", Color3.fromRGB(255, 170, 80), 18, 12, 11)
	neonShop(folder, v(140, -20), v(140, 0), "BAIT & BITS", Color3.fromRGB(140, 255, 140), 14, 10, 9)

	-- the fish market: an open hall on posts, stalls with fish on ice
	local hallCf = facing(v(160, 20), v(160, 0))
	part({ Name = "MarketFloor", Size = Vector3.new(30, 0.6, 16), CFrame = hallCf * CFrame.new(0, 0.3, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	for _, x in ipairs({ -14, -7, 0, 7, 14 }) do
		for _, z in ipairs({ -7.5, 7.5 }) do
			part({ Name = "HallPost", Size = Vector3.new(0.9, 10, 0.9), CFrame = hallCf * CFrame.new(x, 5, z), Color = WOOD_DARK, Parent = folder })
		end
	end
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "HallRoof", Size = Vector3.new(32, 0.8, 10), CFrame = hallCf * CFrame.new(0, 11.4, dir * 4.4) * CFrame.Angles(dir * math.rad(24), 0, 0), Color = Color3.fromRGB(70, 110, 160), Parent = folder })
	end
	local sign = decor({ Name = "HallSign", Size = Vector3.new(16, 2.6, 0.5), CFrame = hallCf * CFrame.new(0, 13.6, -8), Color = SIGN_DARK, Parent = folder })
	surfaceText(sign, "FISH MARKET", Color3.fromRGB(150, 236, 255))
	for i = -2, 2 do
		local stall = hallCf * CFrame.new(i * 6, 1.6, -3)
		part({ Name = "IceStall", Size = Vector3.new(4.6, 2, 3), CFrame = stall, Color = Color3.fromRGB(200, 236, 255), Parent = folder })
		for j = -1, 1 do
			decor({ Name = "FishOnIce", Size = Vector3.new(0.8, 0.5, 2.2), CFrame = stall * CFrame.new(j * 1.3, 1.25, 0) * CFrame.Angles(0, 0.2 * j, 0), Color = ({ Color3.fromRGB(255, 160, 120), Color3.fromRGB(150, 200, 255), Color3.fromRGB(255, 220, 120) })[j + 2], Parent = folder })
		end
	end
	reserve(v(160, 20), 18)

	-- the crane over the north basin
	local craneAt = v(132, 28)
	part({ Name = "CraneBase", Size = Vector3.new(4, 18, 4), CFrame = CFrame.new(at(craneAt, TOP + 9)), Color = Color3.fromRGB(220, 170, 50), Parent = folder })
	decor({ Name = "CraneArm", Size = Vector3.new(2, 2, 26), CFrame = CFrame.new(at(craneAt + v(0, 10), TOP + 18)), Color = Color3.fromRGB(220, 170, 50), Parent = folder })
	rod(folder, at(craneAt + v(0, 20), TOP + 17), at(craneAt + v(0, 20), TOP + 6), 0.25, Color3.fromRGB(60, 60, 66))
	K.crate(folder, CFrame.new(at(craneAt + v(0, 20), TOP + 4.6)))
	reserve(craneAt, 4)

	-- piers into both basins, and boats moored along them
	pier(folder, v(n.PN1.X, 24), n.PN2, 10, rng)
	pier(folder, v(n.PS1.X, -24), n.PS2, 10, rng)
	for _, spec in ipairs({
		{ v(134, 62), 0.1, Color3.fromRGB(70, 120, 200) },
		{ v(106, 70), -0.15, Color3.fromRGB(200, 70, 60) },
		{ v(136, 92), 1.5, Color3.fromRGB(240, 200, 70) },
		{ v(124, -60), 0.2, Color3.fromRGB(80, 170, 120) },
		{ v(96, -76), -0.1, Color3.fromRGB(230, 120, 70) },
		{ v(128, -96), 1.6, Color3.fromRGB(100, 90, 200) },
		{ v(170, 60), 0.6, Color3.fromRGB(240, 240, 240) },
		{ v(170, -64), -0.5, Color3.fromRGB(60, 160, 200) },
	}) do
		boat(folder, spec[1], spec[2], spec[3], rng)
	end

	-- crates, barrels, nets and lamps along Harbor Street
	for _, x in ipairs({ 92, 118, 190 }) do
		barrels(folder, v(x, 20), rng, 2)
		K.crate(folder, CFrame.new(x + 4, TOP + 1.3, -19) * CFrame.Angles(0, rng:NextNumber(0, 1), 0))
	end
	for _, x in ipairs({ 100, 122 }) do
		local net = decor({ Name = "FishingNet", Size = Vector3.new(8, 5, 0.2), CFrame = CFrame.new(x, TOP + 4, -20) * CFrame.Angles(0, 0, 0.05), Color = Color3.fromRGB(210, 196, 150), Transparency = 0.35, Parent = folder })
		net.Material = Enum.Material.Fabric
		for _, sx in ipairs({ -4.2, 4.2 }) do
			part({ Name = "NetPole", Size = Vector3.new(0.5, 7, 0.5), CFrame = CFrame.new(x + sx, TOP + 3.5, -20), Color = WOOD_DARK, Parent = folder })
		end
	end

	-- the Tidegate: two stone towers and an arch over the start of the causeway
	local gate = T.tidegate
	for _, z in ipairs({ -13, 13 }) do
		local tower = at(gate + v(0, z), TOP)
		part({ Name = "GateTower", Size = Vector3.new(10, 26, 10), CFrame = CFrame.new(tower + Vector3.new(0, 13, 0)), Color = P.STONE, Material = Enum.Material.Cobblestone, Parent = folder })
		for i = -1, 1, 2 do
			for j = -1, 1, 2 do
				decor({ Name = "Crenel", Size = Vector3.new(2.6, 2.4, 2.6), CFrame = CFrame.new(tower + Vector3.new(i * 3.6, 27.2, j * 3.6)), Color = P.STONE, Parent = folder })
			end
		end
		local brazier = decor({ Name = "Brazier", Size = Vector3.new(3, 1.4, 3), CFrame = CFrame.new(tower + Vector3.new(0, 26.8, 0)), Color = Color3.fromRGB(60, 50, 50), Parent = folder })
		local flame = decor({ Name = "Flame", Size = Vector3.new(2, 2.4, 2), CFrame = CFrame.new(tower + Vector3.new(0, 28.6, 0)), Color = Color3.fromRGB(255, 160, 60), Material = Enum.Material.Neon, Parent = folder })
		light(flame, Color3.fromRGB(255, 170, 80), 40, 2)
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 9
		fire.Parent = brazier
		-- wave banners
		decor({ Name = "Banner", Size = Vector3.new(0.2, 9, 4), CFrame = CFrame.new(tower + Vector3.new(-5.2, 15, 0)), Color = Color3.fromRGB(40, 120, 190), Parent = folder })
		decor({ Name = "BannerWave", Size = Vector3.new(0.25, 1.4, 4), CFrame = CFrame.new(tower + Vector3.new(-5.25, 13, 0)), Color = WHITE, Parent = folder })
	end
	local beam = part({ Name = "GateArch", Size = Vector3.new(6, 5, 36), CFrame = CFrame.new(at(gate, TOP + 21)), Color = P.STONE, Material = Enum.Material.Cobblestone, Parent = folder })
	surfaceText(beam, "THE TIDEGATE", Color3.fromRGB(255, 236, 170), Enum.NormalId.Left)
	surfaceText(beam, "SUNKEN SHOALS · 22 ISLANDS", Color3.fromRGB(200, 255, 230), Enum.NormalId.Right)
	decor({ Name = "Portcullis", Size = Vector3.new(1, 4, 16), CFrame = CFrame.new(at(gate, TOP + 16.5)), Color = Color3.fromRGB(70, 70, 76), Parent = folder })
	reserve(gate, 20)
	local board = part({ Name = "WarningBoard", Size = Vector3.new(10, 5, 0.6), CFrame = facing(gate + v(-14, 14), gate + v(-40, 14), TOP + 4.5), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	surfaceText(board, "PAST THIS GATE: crabs, puffers, gulls, sharks and golems.\nSwipe with click or F!", Color3.fromRGB(255, 240, 200))
	for _, x in ipairs({ -4, 4 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.8, 5, 0.8), CFrame = board.CFrame * CFrame.new(x, -3.5, 0.2), Color = WOOD_DARK, Parent = folder })
	end
end

local function buildMarket(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "MarketRow"
	folder.Parent = parent
	local n = T.nodes
	-- shops lining the walk up from the plaza
	PropKit.frameShop(folder, at(v(-17, 72), TOP), at(v(0, 72), TOP), 13, 10, 11, "SNACKS", Color3.fromRGB(226, 60, 90))
	reserve(v(-17, 72), 9)
	PropKit.frameShop(folder, at(v(17, 72), TOP), at(v(0, 72), TOP), 13, 10, 11, "POTIONS", Color3.fromRGB(150, 80, 230))
	reserve(v(17, 72), 9)
	PropKit.frameShop(folder, at(v(-17, 92), TOP), at(v(0, 92), TOP), 13, 10, 11, "SHELLS", Color3.fromRGB(60, 140, 230))
	reserve(v(-17, 92), 9)
	PropKit.frameShop(folder, at(v(17, 92), TOP), at(v(0, 92), TOP), 13, 10, 11, "CHARMS", Color3.fromRGB(40, 180, 120))
	reserve(v(17, 92), 9)
	-- food stalls round the square (the vendors TideboundLife stands behind them)
	for _, vendor in ipairs(T.vendors) do
		if vendor.at.Z > 60 then
			-- the vendor stands behind the counter, which faces the street
			local stallAt = vendor.at - (vendor.face - vendor.at).Unit * 0.5
			K.awningStall(folder, at(stallAt, TOP), vendor.face, ({ "TAKOYAKI", "EGG TARTS", "GRILLED FISH", "SHAVED ICE" })[rng:NextInteger(1, 4)], "FRESH!")
			reserve(stallAt, 9)
		end
	end
	-- the square's centrepiece: a stone egg statue on a fountain
	local square = v(0, 125)
	disk(folder, "SquareFountain", at(square, TOP + 1), 7, 2, P.STONE)
	local water = disk(folder, "SquareWater", at(square, TOP + 1.6), 6, 1.4, P.FOUNTAIN_BLUE)
	water.CanCollide = false
	K.eggShape(folder, "EggStatue", CFrame.new(at(square, TOP + 6)), Vector3.new(4, 5.4, 4), Color3.fromRGB(250, 244, 230))
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		K.eggShape(folder, "StatueSpot", CFrame.new(at(square, TOP + 6) + Vector3.new(math.cos(a) * 1.85, (i % 2) * 1.2 - 0.4, math.sin(a) * 1.85)), Vector3.new(0.7, 0.9, 0.7), NEONS[(i % #NEONS) + 1])
	end
	reserve(square, 9)
	-- an arcade and a teahouse at the ends of Market Row
	local arcadeCf = neonShop(folder, v(40, 182), n.M6, "ARCADE", NEONS[2], 18, 12, 13)
	for i = 1, 6 do
		decor({ Name = "ArcadeBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = arcadeCf * CFrame.new(-8 + i * 2.3, 13.8, -6.3), Color = NEONS[(i % #NEONS) + 1], Material = Enum.Material.Neon, Parent = folder })
	end
	K.timberHouse(folder, at(v(-40, 180), TOP), at(n.M7, TOP), 14, 10, 9, P.ROOF_ORANGE)
	local tea = decor({ Name = "TeaSign", Size = Vector3.new(8, 2, 0.4), CFrame = facing(v(-40, 174.6), n.M7, TOP + 10.5), Color = SIGN_DARK, Parent = folder })
	surfaceText(tea, "TEAHOUSE", Color3.fromRGB(255, 200, 150))
	reserve(v(-40, 180), 9)
	-- more shops round the edge of the market
	neonShop(folder, v(-62, 120), n.M3, "RODS R US", NEONS[4], 12, 10, 9)
	neonShop(folder, v(62, 120), n.M4, "EGG CARE", NEONS[1], 12, 10, 9)
	K.timberHouse(folder, at(v(-30, 158), TOP), at(n.M5, TOP), 11, 9, 9, P.ROOF_SLATE)
	K.timberHouse(folder, at(v(30, 158), TOP), at(n.M5, TOP), 11, 9, 9, P.ROOF_ORANGE)
	reserve(v(-30, 158), 8)
	reserve(v(30, 158), 8)
	-- string lights criss-crossing the square
	local h = TOP + 12
	local poles = { v(-10, 112), v(10, 112), v(10, 138), v(-10, 138) }
	for _, p in ipairs(poles) do
		part({ Name = "LightPole", Size = Vector3.new(0.6, 12, 0.6), CFrame = CFrame.new(at(p, TOP + 6)), Color = WOOD_DARK, Parent = folder })
		reserve(p, 1.5)
	end
	for i, p in ipairs(poles) do
		stringLights(folder, at(p, h), at(poles[(i % #poles) + 1], h), rng)
	end
	stringLights(folder, at(poles[1], h), at(poles[3], h), rng)
	stringLights(folder, at(poles[2], h), at(poles[4], h), rng)
end

local function buildToriiHill(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "ToriiHill"
	folder.Parent = parent
	local hill = T.districts.ToriiHill
	local c = hill.top
	local topY = hill.topY
	-- REF 1 terraces: dirt bodies, grass caps, snow dusting, trees on the ledges
	local tiers = { { 44, TOP + 8 }, { 36, TOP + 16 }, { 28, TOP + 24 }, { 20, TOP + 32 }, { 13, topY } }
	for i, tier in ipairs(tiers) do
		local r, y = tier[1], tier[2]
		-- Patch 13: stepped voxel terraces: a dirt body, a studded grass band, snow dusting the middle
		K.voxelDisk(folder, "Terrace" .. i, c, r, TOP, y - 0.2, (i % 2 == 0) and Color3.fromRGB(150, 110, 80) or Color3.fromRGB(128, 94, 70), 4)
		for _, strip in ipairs(K.voxelDisk(folder, "TerraceGrass" .. i, c, r, y - 0.2, y + 0.4, PC.SNOW, 4)) do
			CollectionService:AddTag(strip, "TideboundGrass")
		end
		K.voxelDisk(folder, "TerraceSnow" .. i, c, math.max(4, r - 6), y + 0.4, y + 0.7, P.SNOW_CAP, 4)
		if i < #tiers then
			local nextR = tiers[i + 1][1]
			for _ = 1, 3 + (5 - i) do
				local a = rng:NextNumber(0, math.pi * 2)
				if math.abs(math.cos(a)) < 0.85 or math.cos(a) < 0 then -- leave the stairway (east face) clear
					local d = rng:NextNumber(nextR + 2.5, r - 2.5)
					local base = c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
					if rng:NextNumber() < 0.5 then
						K.voxelTree(folder, at(base, y + 0.4), rng, 0.9)
					else
						K.pineTree(folder, at(base, y + 0.4), 0.9)
					end
				end
			end
		end
	end
	-- the stairway up the east face: an invisible ramp to walk on, stone steps to see, torii gates over it
	local foot = c + v(63, 0)
	local landing = c + v(12, 0)
	local bottom, topPoint = at(foot, TOP), at(landing, topY)
	local slope = topPoint - bottom
	local width = 8
	local ramp = part({ Name = "StairRamp", Size = Vector3.new(width, 1, slope.Magnitude), CFrame = CFrame.lookAt((bottom + topPoint) / 2, topPoint) * CFrame.new(0, -0.5, 0), Transparency = 1, Parent = folder })
	ramp.CanQuery = true
	local steps = 40
	for i = 0, steps - 1 do
		local s = (i + 0.5) / steps
		local p = bottom:Lerp(topPoint, s)
		local rise = slope.Y / steps
		decor({ Name = "Step", Size = Vector3.new(width, rise + 0.2, slope.Magnitude / steps * 0.8 + 0.4), CFrame = CFrame.new(Vector3.new(p.X, p.Y - rise / 2, p.Z)), Color = (i % 2 == 0) and P.STONE or COBBLE, Parent = folder })
		if i % 4 == 0 then
			-- supports where the stairs bridge over a lower ledge
			for _, side in ipairs({ -1, 1 }) do
				local post = Vector3.new(p.X, 0, p.Z + side * (width / 2 - 0.4))
				decor({ Name = "StairPost", Size = Vector3.new(0.8, p.Y - TOP, 0.8), CFrame = CFrame.new(post.X, (p.Y + TOP) / 2, post.Z), Color = WOOD_DARK, Parent = folder })
			end
		end
	end
	for _, s in ipairs({ 0.04, 0.3, 0.55, 0.8 }) do
		local p = bottom:Lerp(topPoint, s)
		K.toriiGate(folder, Vector3.new(p.X, p.Y, p.Z), 11, 14 - s * 3)
	end
	reserve(foot, 8)
	for s = 0, 1, 0.1 do
		reserve(foot:Lerp(landing, s), 7)
	end
	-- the shrine overlook on top
	local shrine = c + v(-3, 0)
	local cf = facing(shrine, c + v(40, 0), topY + 0.4)
	part({ Name = "ShrineFloor", Size = Vector3.new(14, 1, 12), CFrame = cf * CFrame.new(0, 0.5, 4), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	for _, x in ipairs({ -6, 6 }) do
		for _, z in ipairs({ 0, 8 }) do
			part({ Name = "ShrinePillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 1.2, 1.2), CFrame = cf * CFrame.new(x, 5.4, z) * CFrame.Angles(0, 0, math.rad(90)), Color = P.TORII_RED, Parent = folder })
		end
	end
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "ShrineRoof", Size = Vector3.new(18, 0.8, 9), CFrame = cf * CFrame.new(0, 11.2, 4 + dir * 3.4) * CFrame.Angles(dir * math.rad(30), 0, 0), Color = Color3.fromRGB(44, 52, 66), Parent = folder })
	end
	local bell = decor({ Name = "ShrineBell", Size = Vector3.new(2, 2.4, 2), CFrame = cf * CFrame.new(0, 7.4, 2), Color = P.GOLD, Material = Enum.Material.Metal, Parent = folder })
	light(bell, Color3.fromRGB(255, 220, 150), 18, 1)
	for _, side in ipairs({ -1, 1 }) do
		local lanternAt = cf * CFrame.new(side * 9, 0, -2)
		part({ Name = "StoneLantern", Size = Vector3.new(1.6, 4, 1.6), CFrame = lanternAt * CFrame.new(0, 2, 0), Color = P.STONE, Parent = folder })
		local glow = decor({ Name = "LanternLight", Size = Vector3.new(1.4, 1.2, 1.4), CFrame = lanternAt * CFrame.new(0, 4.6, 0), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, Parent = folder })
		light(glow, Color3.fromRGB(255, 210, 140), 14, 1)
		decor({ Name = "LanternCap", Size = Vector3.new(2.6, 0.6, 2.6), CFrame = lanternAt * CFrame.new(0, 5.5, 0), Color = P.STONE, Parent = folder })
	end
	-- a railing round the overlook
	for i = 1, 20 do
		local a = i / 20 * math.pi * 2
		if math.cos(a) < 0.8 then
			decor({ Name = "Rail", Size = Vector3.new(0.4, 2.4, 0.4), CFrame = CFrame.new(c.X + math.cos(a) * 12.4, topY + 1.2, c.Z + math.sin(a) * 12.4), Color = P.TORII_RED, Parent = folder })
		end
	end
	-- the koi pond at the foot of the hill
	local pond = v(-118, 68)
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		part({ Name = "PondStone", Size = Vector3.new(3, 1.6, 2.4), CFrame = CFrame.new(pond.X + math.cos(a) * 12.5, TOP + 0.8, pond.Z + math.sin(a) * 12.5) * CFrame.Angles(0, -a, 0), Color = (i % 2 == 0) and P.STONE or COBBLE, Parent = folder })
	end
	-- Patch 14: frozen over: glowing ice with white cracks (the reference's ice), with a crystal on the bank
	PropKit.iceSheet(folder, pond, 22, 22, TOP + 0.3, rng)
	PropKit.iceCrystal(folder, at(pond + v(15, -8), TOP), rng, 1)
	reserve(pond, 16)
	reserve(c, 46)
end

local function buildFarms(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "HatcheryFarms"
	folder.Parent = parent
	local farm = T.districts.Farms.center
	-- crop fields: tilled rows of soil with green (or golden) crops
	for _, field in ipairs({ { v(-72, -135), 0.15, Color3.fromRGB(90, 190, 70) }, { v(-128, -70), -0.25, Color3.fromRGB(230, 196, 70) }, { v(-60, -102), 0.1, Color3.fromRGB(120, 200, 90) } }) do
		local cf = CFrame.new(at(field[1], TOP + 0.15)) * CFrame.Angles(0, field[2], 0)
		decor({ Name = "Field", Size = Vector3.new(26, 0.3, 20), CFrame = cf, Color = SOIL, Parent = folder }).CanQuery = true
		for row = -4, 4 do
			decor({ Name = "Furrow", Size = Vector3.new(24, 0.5, 1), CFrame = cf * CFrame.new(0, 0.25, row * 2.2), Color = SOIL:Lerp(Color3.new(0, 0, 0), 0.15), Parent = folder })
			for col = -5, 5 do
				local h = rng:NextNumber(0.8, 1.8)
				K.windy(decor({ Name = "Crop", Size = Vector3.new(0.6, h, 0.6), CFrame = cf * CFrame.new(col * 2.2, 0.4 + h / 2, row * 2.2), Color = field[3], CastShadow = false, Parent = folder }))
			end
		end
		reserve(field[1], 16)
	end
	-- the windmill: a stone tower with four sails turning on the client (TideboundSpin about Axis)
	local mill = v(-140, -100)
	local yaw = math.rad(30)
	local millCf = CFrame.new(at(mill, TOP)) * CFrame.Angles(0, yaw, 0)
	for i = 0, 3 do
		disk(folder, "MillTower", (millCf * CFrame.new(0, 3 + i * 6, 0)).Position, 6 - i * 0.7, 6, (i % 2 == 0) and WHITE or Color3.fromRGB(230, 226, 214))
	end
	decor({ Name = "MillCap", Size = Vector3.new(7, 4, 7), CFrame = millCf * CFrame.new(0, 26, 0) * CFrame.Angles(0, math.rad(45), 0), Color = BARN_RED, Parent = folder })
	local hub = (millCf * CFrame.new(0, 22, -5)).Position
	local axis = millCf.LookVector
	decor({ Name = "MillHub", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(hub), Color = WOOD_DARK, Parent = folder })
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		local radial = CFrame.fromAxisAngle(axis, a):VectorToWorldSpace(Vector3.yAxis)
		local sailAt = hub + radial * 8
		local sail = decor({ Name = "MillSail", Size = Vector3.new(3.6, 14, 0.3), CFrame = CFrame.lookAt(sailAt, sailAt + axis, radial), Color = Color3.fromRGB(246, 240, 226), Parent = folder })
		sail:SetAttribute("Pivot", hub)
		sail:SetAttribute("Axis", axis)
		sail:SetAttribute("SpinSpeed", 0.8)
		CollectionService:AddTag(sail, "TideboundSpin")
	end
	reserve(mill, 9)
	-- two red egg barns with big painted eggs, hay bales, fences
	for _, spec in ipairs({ { v(-86, -96), v(-100, -110) }, { v(-110, -150), v(-100, -110) } }) do
		local cf = K.timberHouse(folder, at(spec[1], TOP), at(spec[2], TOP), 16, 12, 10, Color3.fromRGB(110, 60, 50))
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and child.Name == "TimberHouse" and not child:GetAttribute("Painted") then
				child:SetAttribute("Painted", true)
				local walls = child:FindFirstChild("Walls")
				if walls and walls:IsA("BasePart") then
					walls.Color = BARN_RED
				end
			end
		end
		K.eggShape(folder, "BarnEgg", cf * CFrame.new(0, 6, -6.4), Vector3.new(3, 4, 0.6), Color3.fromRGB(255, 244, 220))
		reserve(spec[1], 11)
	end
	for _ = 1, 8 do
		local p = farm + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40))
		if isLand(p, 4) and free(p, 2) then
			decor({ Name = "HayBale", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(at(p, TOP + 1.3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = Color3.fromRGB(230, 200, 110), Parent = folder })
			reserve(p, 2)
		end
	end
	-- the chicken run fence (TideboundLife keeps its chickens inside)
	local run = T.chickens
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		local p = run.center + Vector3.new(math.cos(a), 0, math.sin(a)) * (run.radius + 2)
		decor({ Name = "FencePost", Size = Vector3.new(0.5, 2.4, 0.5), CFrame = CFrame.new(at(p, TOP + 1.2)), Color = WOOD, Parent = folder })
		local q = run.center + Vector3.new(math.cos(a + math.pi / 24), 0, math.sin(a + math.pi / 24)) * (run.radius + 2)
		decor({ Name = "FenceRail", Size = Vector3.new(0.3, 0.3, (run.radius + 2) * math.pi * 2 / 24 + 0.4), CFrame = CFrame.lookAt(at(q, TOP + 1.6), at(q, TOP + 1.6) + Vector3.new(-math.sin(a + math.pi / 24), 0, math.cos(a + math.pi / 24))), Color = WOOD, Parent = folder })
	end
	local coop = run.center + v(10, 10)
	part({ Name = "Coop", Size = Vector3.new(6, 4, 5), CFrame = CFrame.new(at(coop, TOP + 2)), Color = BARN_RED, Parent = folder })
	decor({ Name = "CoopRoof", Size = Vector3.new(7, 0.6, 6), CFrame = CFrame.new(at(coop, TOP + 4.4)) * CFrame.Angles(0, 0, 0.2), Color = WOOD_DARK, Parent = folder })
	reserve(run.center, run.radius + 3)
end

local function buildBeach(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "SouthBeach"
	folder.Parent = parent
	local y = TOP - 0.4
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 210, 70), Color3.fromRGB(120, 220, 120) }
	for i = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = BEACH.c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(20, BEACH.r - 8)
		if free(p, 4) then
			local color = colors[(i % #colors) + 1]
			decor({ Name = "UmbrellaPole", Size = Vector3.new(0.3, 7, 0.3), CFrame = CFrame.new(at(p, y + 3.5)) * CFrame.Angles(0.08, 0, 0.05), Color = WHITE, Parent = folder })
			for j = 1, 8 do
				local b = j / 8 * math.pi * 2
				decor({ Name = "Umbrella", Size = Vector3.new(3.2, 0.2, 2.2), CFrame = CFrame.new(at(p, y + 7)) * CFrame.Angles(0, b, 0) * CFrame.new(0, -0.5, -1.6) * CFrame.Angles(math.rad(-18), 0, 0), Color = (j % 2 == 0) and color or WHITE, Parent = folder })
			end
			decor({ Name = "Towel", Size = Vector3.new(2.6, 0.1, 5), CFrame = CFrame.new(at(p + Vector3.new(2.5, 0, 1), y + 0.05)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = colors[((i + 1) % #colors) + 1], Parent = folder })
			reserve(p, 5)
		end
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = BEACH.c + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(10, BEACH.r - 6)
		if free(p, 3) then
			-- a palm, leaning toward the sea
			local base = at(p, y)
			local trunkTop = base + Vector3.new(math.cos(a) * 3, 13, math.sin(a) * 3)
			rod(folder, base, trunkTop, 1.2, Color3.fromRGB(150, 112, 70))
			for k = 1, 6 do
				local b = k / 6 * math.pi * 2
				local tip = trunkTop + Vector3.new(math.cos(b) * 6, -2, math.sin(b) * 6)
				K.windy(decor({ Name = "Frond", Size = Vector3.new(1.8, 0.3, (tip - trunkTop).Magnitude), CFrame = CFrame.lookAt((trunkTop + tip) / 2, tip), Color = (k % 2 == 0) and Color3.fromRGB(70, 176, 74) or Color3.fromRGB(96, 196, 84), Parent = folder }))
			end
			reserve(p, 3)
		end
	end
	-- lifeguard tower
	local tower = BEACH.c + v(-26, -28)
	for _, sx in ipairs({ -2, 2 }) do
		for _, sz in ipairs({ -2, 2 }) do
			part({ Name = "TowerLeg", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(at(tower + v(sx, sz), y + 4)), Color = WHITE, Parent = folder })
		end
	end
	part({ Name = "TowerHut", Size = Vector3.new(6, 4, 6), CFrame = CFrame.new(at(tower, y + 10)), Color = Color3.fromRGB(230, 70, 60), Parent = folder })
	decor({ Name = "TowerRoof", Size = Vector3.new(7, 0.6, 7), CFrame = CFrame.new(at(tower, y + 12.3)), Color = WHITE, Parent = folder })
	reserve(tower, 5)
	-- the ferry pier and a slide back to the Harbor Ring
	local n = T.nodes
	local pierFrom, pierTo = n.B3, v(n.B3.X, -192)
	K.boardwalkSegment(folder, pierFrom, pierTo, 8)
	boat(folder, v(n.B3.X + 9, -188), 0, Color3.fromRGB(60, 120, 200), rng)
	disk(folder, "SlideBase", at(pierTo + v(0, 2), TOP + 0.3), 4.4, 0.6, P.STONE)
	local pad = disk(folder, "FerrySlide", at(pierTo + v(0, 2), TOP + 0.7), 3.6, 0.3, P.BEACON)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.15
	K.sparkles(pad, Color3.fromRGB(200, 255, 240), 6)
	light(pad, P.BEACON, 14, 1.4)
	prompt(pad, "Ferry", "Ferry to the Harbor Ring", { Action = "Travel", Dest = "Harbor" }, 0.5, 10)
	billboard(pad, "FERRY", "To the Harbor Ring and your Home Nest", 4)
	reserve(pierFrom, 6)
end

local function buildLighthousePoint(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "LighthousePoint"
	folder.Parent = parent
	local lh = T.districts.Lighthouse.center
	D.lighthouse(folder, lh)
	reserve(lh, 8)
	-- a telescope and benches looking out to sea toward the Shoals
	local scopeAt = lh + v(-14, -8)
	part({ Name = "ScopeStand", Size = Vector3.new(0.6, 4, 0.6), CFrame = CFrame.new(at(scopeAt, TOP + 2)), Color = Color3.fromRGB(60, 60, 66), Parent = folder })
	decor({ Name = "Telescope", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 0.9, 0.9), CFrame = CFrame.new(at(scopeAt, TOP + 4.3)) * CFrame.Angles(0, 0, 0.3), Color = P.GOLD, Material = Enum.Material.Metal, Parent = folder })
	reserve(scopeAt, 2)
	for _, off in ipairs({ v(-4, -20), v(10, -24) }) do
		local p = lh + off
		part({ Name = "Bench", Size = Vector3.new(6, 0.5, 2), CFrame = CFrame.new(at(p, TOP + 1.6)), Color = WOOD, Parent = folder })
		for _, sx in ipairs({ -2.5, 2.5 }) do
			decor({ Name = "BenchLeg", Size = Vector3.new(0.5, 1.4, 1.8), CFrame = CFrame.new(at(p + v(sx, 0), TOP + 0.7)), Color = WOOD_DARK, Parent = folder })
		end
		reserve(p, 3)
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = lh + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(12, 30)
		if isLand(p, 3) and free(p, 3) then
			K.mintRock(folder, at(p, TOP + 0.5), rng, 1.4)
		end
	end
end

-- Houses in the gaps: REF 5 timber houses facing the nearest street, scattered round the core.
local function nearestStreetPoint(p)
	local best, bestD = nil, math.huge
	for _, edge in ipairs(T.edges) do
		local a, b = T.nodes[edge[1]], T.nodes[edge[2]]
		local ab = b - a
		local s = math.clamp((flat(p) - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local q = a + ab * s
		local d = (flat(p) - q).Magnitude
		if d < bestD then
			best, bestD = q, d
		end
	end
	return best, bestD
end

local function buildHouses(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Houses"
	folder.Parent = parent
	local roofs = { P.ROOF_ORANGE, P.ROOF_SLATE, Color3.fromRGB(120, 70, 140), Color3.fromRGB(70, 130, 90) }
	local placed = 0
	for _ = 1, 300 do
		if placed >= 34 then
			break
		end
		local p = v(rng:NextNumber(-170, 205), rng:NextNumber(-180, 200))
		if p.Magnitude > T.plazaRadius + 10 and isLand(p, 10) and (flat(p) - BEACH.c).Magnitude > BEACH.r - 4 and free(p, 8) then
			local q, d = nearestStreetPoint(p)
			if q and d > 11 and d < 24 then
				-- Patch 14: the reference town's houses: mostly snowy log cabins, some brick houses with tiled roofs,
				-- each with a fence round its front garden and a snow mound or two
				local w, depth, h = rng:NextNumber(11, 14), rng:NextNumber(9, 11), rng:NextNumber(8, 10)
				if rng:NextNumber() < 0.7 then
					PropKit.logCabin(folder, at(p, TOP), at(q, TOP), w, depth, h, rng)
				else
					PropKit.brickHouse(folder, at(p, TOP), at(q, TOP), w, depth, h, roofs[rng:NextInteger(1, #roofs)])
				end
				local cf = facing(p, q)
				local yard = depth / 2 + 4
				PropKit.woodFence(folder, (cf * CFrame.new(-w / 2 - 1, 0, -yard)).Position, (cf * CFrame.new(-2.4, 0, -yard)).Position, TOP)
				PropKit.woodFence(folder, (cf * CFrame.new(2.4, 0, -yard)).Position, (cf * CFrame.new(w / 2 + 1, 0, -yard)).Position, TOP)
				PropKit.snowMound(folder, (cf * CFrame.new(w / 2 + 3, 0, rng:NextNumber(-3, 3))).Position, rng, rng:NextNumber(0.8, 1.2))
				reserve(p, math.max(w, depth) * 0.8)
				placed += 1
			end
		end
	end
end

local function buildGreenery(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Greenery"
	folder.Parent = parent
	local trees = 0
	for _ = 1, 600 do
		if trees >= 150 then
			break
		end
		local p = v(rng:NextNumber(-200, 205), rng:NextNumber(-200, 205))
		if p.Magnitude > T.plazaRadius + 4 and isLand(p, 4) and (flat(p) - BEACH.c).Magnitude > BEACH.r and free(p, 4) then
			local r = rng:NextNumber()
			local base = at(p, TOP)
			-- Patch 14: a winter forest: mostly snowy pines, some voxel trees
			if r < 0.3 then
				K.voxelTree(folder, base, rng, rng:NextNumber(1, 1.4))
			else
				K.pineTree(folder, base, rng:NextNumber(1, 1.6))
			end
			reserve(p, 4)
			trees += 1
		end
	end
	for _ = 1, 160 do
		local p = v(rng:NextNumber(-200, 205), rng:NextNumber(-200, 205))
		if p.Magnitude > T.plazaRadius and isLand(p, 3) and (flat(p) - BEACH.c).Magnitude > BEACH.r and free(p, 1) then
			if rng:NextNumber() < 0.6 then
				PropKit.snowMound(folder, at(p, TOP), rng, rng:NextNumber(0.6, 1.3))
			else
				D.tuft(folder, at(p, TOP), rng, Color3.fromRGB(230, 240, 255), Color3.fromRGB(200, 220, 245))
			end
		end
	end
end

-- Patch 14: the reference winter town's dressing ---------------------------------------------------------------
-- Paving inlays and loose tiles round the plaza and squares, vending machines, ice crystals, igloos, striped
-- stalls on Harbor Street, fences, scaffold arches with lanterns over the main streets.

local function buildWinter(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Winter"
	folder.Parent = parent
	-- grey paving inlays set into the snow round the plaza, the market square and the Tidegate
	PropKit.inlays(folder, v(0, 0), T.plazaRadius + 8, TOP, rng, PC.PAVER, 22)
	PropKit.inlays(folder, v(0, 125), 30, TOP, rng, PC.PAVER, 10)
	PropKit.inlays(folder, v(170, 0), 26, TOP, rng, PC.PAVER, 8)
	-- vending machines round the plaza's edge
	for _, spec in ipairs({ { v(54, -24), "BAIT MACHINE", Color3.fromRGB(60, 120, 220) }, { v(-50, 30), "EGG MACHINE", Color3.fromRGB(230, 70, 110) }, { v(-50, -30), "XP MACHINE", Color3.fromRGB(60, 160, 230) } }) do
		local cf = facing(spec[1], v(0, 0))
		PropKit.vendingMachine(folder, cf, spec[2], spec[3])
		reserve(spec[1], 4)
	end
	-- glowing ice crystals and snowy igloos out on the edges of town
	local placed = 0
	for _ = 1, 200 do
		if placed >= 18 then
			break
		end
		local p = v(rng:NextNumber(-200, 205), rng:NextNumber(-200, 205))
		if p.Magnitude > 90 and isLand(p, 6) and (flat(p) - BEACH.c).Magnitude > BEACH.r and free(p, 5) then
			PropKit.iceCrystal(folder, at(p, TOP), rng, rng:NextNumber(0.9, 1.6))
			reserve(p, 4)
			placed += 1
		end
	end
	for _, spec in ipairs({ { v(-60, 70), v(-30, 40) }, { v(-80, -40), v(-40, -10) }, { v(70, 60), v(40, 40) } }) do
		if free(spec[1], 9) then
			PropKit.igloo(folder, at(spec[1], TOP), spec[2], 1)
			reserve(spec[1], 9)
		end
	end
	-- blue and white striped stalls along Harbor Street
	for _, x in ipairs({ 88, 112 }) do
		PropKit.stripedStall(folder, at(v(x, 16), TOP), at(v(x, 0), TOP), Color3.fromRGB(60, 120, 220), PC.WHITE)
		reserve(v(x, 16), 6)
	end
	-- scaffold arches with hanging lanterns over the main streets out of the plaza
	for _, spec in ipairs({ { v(60, -9), v(60, 9) }, { v(-9, 66), v(9, 66) }, { v(-60, -9), v(-60, 9) }, { v(-9, -62), v(9, -62) } }) do
		PropKit.scaffold(folder, spec[1], spec[2], TOP, 13)
		reserve(spec[1], 2)
		reserve(spec[2], 2)
	end
	-- wooden fences round the plaza's corners
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local mid = v(math.cos(a) * (T.plazaRadius + 3), math.sin(a) * (T.plazaRadius + 3))
		local side = v(-math.sin(a), math.cos(a)) * 9
		PropKit.woodFence(folder, mid - side, mid + side, TOP)
	end
end

-- Snow-capped voxel ice mountains rising out of the sea beyond the town (outside the play area), with glowing
-- crystals on their ledges, so the hub sits in a valley the way the references' towns do.
local function buildBackdrop(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Backdrop"
	folder.Parent = parent
	local peaks = {
		{ v(-360, -120), v(140, 120), 120 },
		{ v(-390, 80), v(160, 130), 150 },
		{ v(-350, 260), v(130, 120), 110 },
		{ v(-300, 420), v(150, 120), 95 },
		{ v(-330, -320), v(150, 130), 130 },
		{ v(-80, 420), v(170, 110), 85 },
		{ v(120, 430), v(140, 100), 75 },
	}
	for _, peak in ipairs(peaks) do
		local top = PropKit.voxelCliff(folder, peak[1], peak[2], FLOOR, peak[3], rng)
		for _ = 1, 3 do
			local p = peak[1] + v(rng:NextNumber(-25, 25), rng:NextNumber(-25, 25))
			PropKit.iceCrystal(folder, at(p, top * rng:NextNumber(0.6, 0.95)), rng, rng:NextNumber(2, 3.5))
		end
		for _ = 1, 4 do
			local p = peak[1] + v(rng:NextNumber(-50, 50), rng:NextNumber(-40, 40))
			K.pineTree(folder, at(p, rng:NextNumber(20, top * 0.5)), rng:NextNumber(1.5, 2.5))
		end
	end
end

-- Build -------------------------------------------------------------------------------------------------------

local function build(root)
	local rng = Random.new(1717)
	reserved = {}
	reserve(v(0, 0), T.plazaRadius + 2)
	buildLand(root)
	local districts = Instance.new("Folder")
	districts.Name = "Districts"
	districts.Parent = root
	buildDocks(districts, rng)
	buildMarket(districts, rng)
	buildToriiHill(districts, rng)
	buildFarms(districts, rng)
	buildBeach(districts, rng)
	buildLighthousePoint(districts, rng)
	local streets = Instance.new("Folder")
	streets.Name = "Streets"
	streets.Parent = root
	buildStreets(streets)
	buildWinter(root, rng)
	buildHouses(root, rng)
	buildGreenery(root, rng)
	buildBackdrop(root, rng)

	-- a welcome sign at the plaza's east exit, pointing the way
	local sign = part({ Name = "TownSign", Size = Vector3.new(12, 4.5, 0.6), CFrame = facing(v(56, 14), v(56, 40), TOP + 5), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = root })
	surfaceText(sign, "EGGFALL TOWN\n→ Harbor Street & the Tidegate · ↑ Market Row\n← Torii Hill · ↓ Farms & Beach", Color3.fromRGB(255, 244, 220))
	for _, x in ipairs({ -5, 5 }) do
		part({ Name = "SignPost", Size = Vector3.new(0.8, 5, 0.8), CFrame = sign.CFrame * CFrame.new(x, -4, 0.2), Color = WOOD_DARK, Parent = root })
	end

	-- big soft snowflakes drifting over the whole town (the references' winter town)
	local snow = decor({ Name = "Snowfall", Size = Vector3.new(440, 1, 440), CFrame = CFrame.new(0, 80, 0), Transparency = 1, Parent = root })
	K.particles(snow, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 236, 255)),
		LightEmission = 0.3,
		Rate = 140,
		Lifetime = NumberRange.new(14, 18),
		Speed = NumberRange.new(3, 5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.9, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(15, 15),
		Drag = 0.4,
		WindAffectsDrag = true,
	})
end

function TownBuilder.build(world)
	local existing = world:FindFirstChild("Town")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Town"
	root:SetAttribute("Version", VERSION)
	build(root)
	root.Parent = world
	return root
end

TownBuilder.isLand = isLand

return TownBuilder
