-- Tidebound: Eggfall: the Sunken Shoals of the Open Isles (Patch 10). Builds Workspace.TideboundWorld.SunkenShoals
-- from IslesLayout: the open sea (terrain water over a sand floor), 22 islands in three rings east of Eggfall
-- Town, the bridges between them, geyser jump pads, and everything you dive for.
--   Ring 1, the Shallows (REF 2): pond-green islands, dark boardwalks with sagging rope, bamboo, the lavender
--     tree, lattice huts, crystal lanterns, lily pads.
--   Ring 2, the Coral Maze (the reference video): checkered grass, studded paths, chunky voxel trees, plank
--     bridges on stilts, coral arches, the shipwreck, sea stacks and Smugglers' Cove.
--   Ring 3, the Outer Reef (stormy): dark rock, dead trees, rickety rope bridges, the lighthouse, Storm Spire,
--     the whale bones, Warden's Rock and the Maelstrom down to Kelp Cathedral.
-- Gameplay pieces keep the contracts the server already reads: Cast / Steal / Extract / BankCatch prompts,
-- TideboundCache (heals), TideboundAnemone, TideboundEliteDen (with MorayHole children), the ReefWarden model
-- and its WardenPath. New: TideboundJumpPad (TideboundTravel launches you to the pad's Target).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local DescentBuilder = require(script.Parent:WaitForChild("DescentBuilder"))
local L = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("IslesLayout"))

local ShoalsBuilder = {}

local VERSION = 1

local K = WorldBuilder.kit
local D = DescentBuilder.kit
local P = K.color
local V = D.color
local part, decor, disk, prompt, billboard, light, rod = K.part, K.decor, K.disk, K.prompt, K.billboard, K.light, K.rod
local TOP, WATER_Y = L.TOP, L.WATER_Y
local FLOOR = L.sea.floorY - 2 -- the terrain sand floor's top (terrain snaps to a 4-stud grid)

-- palette
local BEACH = Color3.fromRGB(232, 212, 160)
local BEACH_DARK = Color3.fromRGB(120, 116, 112)
local CLIFF = Color3.fromRGB(150, 112, 78)
local CLIFF_RING1 = Color3.fromRGB(86, 158, 92)
local CLIFF_STORM = Color3.fromRGB(70, 74, 86)
local STORM_TOP = Color3.fromRGB(88, 104, 92)
local STORM_ROCK = Color3.fromRGB(96, 100, 114)
local DEAD_WOOD = Color3.fromRGB(92, 80, 72)
local CORALS = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 170, 90), Color3.fromRGB(190, 110, 255), Color3.fromRGB(90, 220, 200), Color3.fromRGB(255, 220, 110) }
local PALM_LEAF = { Color3.fromRGB(70, 176, 74), Color3.fromRGB(96, 196, 84) }
local PLANK = Color3.fromRGB(176, 126, 80)
local PLANK_DARK = Color3.fromRGB(128, 88, 58)
local ROPE = Color3.fromRGB(196, 170, 120)
local GEYSER = Color3.fromRGB(120, 230, 255)
local SIGN_DARK = Color3.fromRGB(20, 16, 34)
local RING_NAMES = { "Ring 1 · The Shallows", "Ring 2 · The Coral Maze", "Ring 3 · The Outer Reef" }

local function flat(position)
	return Vector3.new(position.X, 0, position.Z)
end

local function at(position, y)
	return Vector3.new(position.X, y, position.Z)
end

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

-- Places that must stay clear of random decoration (eggs, beacons, caches, pads, bridge mouths...).
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

-- A random point on an island's land (inside `margin` of its coast), away from anything reserved.
local function landPoint(island, rng, margin, clearance)
	for _ = 1, 24 do
		local a = rng:NextNumber(0, math.pi * 2)
		local inner = island.feature == "lagoon" and island.r * 0.5 or 0
		local d = rng:NextNumber(inner, island.r - margin)
		local p = island.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if free(p, clearance) then
			return p
		end
	end
	return nil
end

-- The sea --------------------------------------------------------------------------------------------------

local function fillSea()
	local terrain = workspace.Terrain
	local min, max = L.sea.min, L.sea.max
	local CHUNK = 512
	local x = min.X
	while x < max.X do
		local x2 = math.min(max.X, x + CHUNK)
		local z = min.Z
		while z < max.Z do
			local z2 = math.min(max.Z, z + CHUNK)
			local cx, cz = (x + x2) / 2, (z + z2) / 2
			local size = Vector3.new(x2 - x, 0, z2 - z)
			terrain:FillBlock(CFrame.new(cx, FLOOR - 2, cz), size + Vector3.new(0, 4, 0), Enum.Material.Sand)
			terrain:FillBlock(CFrame.new(cx, (FLOOR + WATER_Y) / 2, cz), size + Vector3.new(0, WATER_Y - FLOOR, 0), Enum.Material.Water)
			z = z2
		end
		x = x2
		task.wait() -- keep the server responsive while the sea pours in
	end
end

-- Islands ---------------------------------------------------------------------------------------------------

local function palmTree(parent, base, rng, scale)
	scale = scale or 1
	local lean = rng:NextNumber(-0.35, 0.35)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local pos = base
	local dir = CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, lean)
	for i = 1, 6 do
		local seg = dir * CFrame.Angles(0, 0, lean * i * 0.12)
		local nextPos = pos + seg.UpVector * 2.4 * scale
		decor({ Name = "PalmTrunk", Size = Vector3.new(1.3 - i * 0.06, 2.6, 1.3 - i * 0.06) * scale, CFrame = CFrame.lookAt((pos + nextPos) / 2, nextPos) * CFrame.Angles(math.rad(90), 0, 0), Color = (i % 2 == 0) and Color3.fromRGB(150, 112, 70) or Color3.fromRGB(128, 94, 60), Parent = parent })
		pos = nextPos
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + yaw
		local tip = pos + Vector3.new(math.cos(a) * 5.5, -1.8, math.sin(a) * 5.5) * scale
		local frond = decor({ Name = "PalmFrond", Size = Vector3.new(1.6 * scale, 0.3, (tip - pos).Magnitude), CFrame = CFrame.lookAt((pos + tip) / 2, tip), Color = PALM_LEAF[(i % 2) + 1], Parent = parent })
		K.windy(frond)
	end
	for i = 1, 3 do
		decor({ Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9) * scale, CFrame = CFrame.new(pos + Vector3.new(math.cos(i * 2.1) * 0.6, -0.6, math.sin(i * 2.1) * 0.6)), Color = Color3.fromRGB(110, 76, 44), Parent = parent })
	end
end

local function deadTree(parent, base, rng)
	local h = rng:NextNumber(7, 11)
	decor({ Name = "DeadTrunk", Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 3), rng:NextNumber(-0.1, 0.1)), Color = DEAD_WOOD, Parent = parent })
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local from = base + Vector3.new(0, h * (0.5 + i * 0.12), 0)
		rod(parent, from, from + Vector3.new(math.cos(a) * 3.5, rng:NextNumber(1, 3), math.sin(a) * 3.5), 0.6, DEAD_WOOD)
	end
end

local function coral(parent, base, rng, scale)
	scale = scale or 1
	local color = CORALS[rng:NextInteger(1, #CORALS)]
	for _ = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(1.5, 3.5) * scale
		decor({ Name = "Coral", Size = Vector3.new(0.7, h, 0.7) * Vector3.new(scale, 1, scale), CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-1, 1), h / 2, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), Color = color, Parent = parent })
	end
	decor({ Name = "CoralTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2) * scale, CFrame = CFrame.new(base + Vector3.new(0, 2.6 * scale, 0)), Color = color:Lerp(Color3.new(1, 1, 1), 0.35), Material = Enum.Material.Neon, Parent = parent })
end

local function stormRock(parent, base, rng, scale)
	scale = scale or 1
	local h = rng:NextNumber(4, 9) * scale
	part({ Name = "StormRock", Size = Vector3.new(rng:NextNumber(3, 5), h, rng:NextNumber(3, 5)) * Vector3.new(scale, 1, scale), CFrame = CFrame.new(base + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = STORM_ROCK, Parent = parent })
end

-- The land itself: a cliff body down to the sea floor, a beach shelf just above the water, and the top.
local function islandLand(parent, island, rng)
	local pos, r, ring = island.pos, island.r, island.ring
	local body = ring == 1 and CLIFF_RING1 or ring == 2 and CLIFF or CLIFF_STORM
	local beachColor = ring == 3 and BEACH_DARK or BEACH
	local top = ring == 1 and P.POND_GRASS or ring == 3 and STORM_TOP or V.GRASS_A
	disk(parent, island.name .. "Shelf", Vector3.new(pos.X, (FLOOR + WATER_Y + 0.7) / 2, pos.Z), r + 6, WATER_Y + 0.7 - FLOOR, beachColor, Enum.Material.Sand)
	if island.feature == "lagoon" then
		-- a ring of land around a round lagoon (Puffer Lagoon): segments, so the middle is open water
		local inner = r * 0.45
		local segments = 22
		local length = r - inner
		local mid = (r + inner) / 2
		local shelf = parent:FindFirstChild(island.name .. "Shelf")
		if shelf then
			shelf:Destroy()
		end
		for i = 1, segments do
			local a = i / segments * math.pi * 2
			local c = pos + Vector3.new(math.cos(a) * mid, 0, math.sin(a) * mid)
			local w = r * 2 * math.pi / segments + 2
			local look = CFrame.lookAt(at(c, 0), at(pos, 0))
			part({ Name = "LagoonRing", Size = Vector3.new(w + 3, TOP - 0.5 - FLOOR, length + 1), CFrame = look + Vector3.new(0, (TOP - 0.5 + FLOOR) / 2, 0), Color = body, Parent = parent })
			part({ Name = "LagoonBeach", Size = Vector3.new(w + 4, WATER_Y + 0.7 - FLOOR, length + 10), CFrame = look + Vector3.new(0, (WATER_Y + 0.7 + FLOOR) / 2, 0), Color = beachColor, Material = Enum.Material.Sand, Parent = parent })
			part({ Name = "LagoonGrass", Size = Vector3.new(w, 0.6, length), CFrame = look + Vector3.new(0, TOP - 0.3, 0), Color = top, Parent = parent })
		end
		return
	end
	disk(parent, island.name, Vector3.new(pos.X, (FLOOR + TOP - 0.5) / 2, pos.Z), r, TOP - 0.5 - FLOOR, body)
	if ring == 2 then
		D.checkerDisk(parent, pos, r - 0.5, 6, TOP - 0.5)
	else
		disk(parent, island.name .. "Top", Vector3.new(pos.X, TOP - 0.25, pos.Z), r, 0.5, top, ring == 3 and Enum.Material.Slate or Enum.Material.Grass)
	end
	-- shore rocks around the rim
	for _ = 1, math.floor(r / 3) do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = pos + Vector3.new(math.cos(a) * (r + rng:NextNumber(0, 3)), 0, math.sin(a) * (r + rng:NextNumber(0, 3)))
		if free(p, 3) then
			if ring == 3 then
				stormRock(parent, at(p, WATER_Y), rng, 0.8)
			else
				K.mintRock(parent, at(p, WATER_Y + 0.6), rng, 1)
			end
		end
	end
end

-- A floating name over each island, readable from far away so you can find your way across the sea.
local function islandTitle(parent, island)
	local anchor = decor({ Name = island.name .. "Title", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(island.pos.X, TOP + 30, island.pos.Z), Transparency = 1, Parent = parent })
	local gui = Instance.new("BillboardGui")
	gui.Name = "IslandTitle"
	gui.Size = UDim2.new(0, 260, 0, 54)
	gui.MaxDistance = 320
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = island.title
	title.TextColor3 = island.ring == 3 and Color3.fromRGB(255, 190, 170) or island.ring == 2 and Color3.fromRGB(255, 236, 150) or Color3.fromRGB(200, 255, 230)
	title.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	title.TextStrokeTransparency = 0
	title.Parent = gui
	local sub = title:Clone()
	sub.Font = Enum.Font.BuilderSansBold
	sub.Position = UDim2.new(0, 0, 0, 34)
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.Text = RING_NAMES[island.ring]
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Parent = gui
	gui.Parent = anchor
end

-- Ring decoration: trees, grass and flowers in each ring's style.
local function decorate(parent, island, rng)
	local r, ring = island.r, island.ring
	local trees = math.floor(r / 9)
	for _ = 1, trees do
		local p = landPoint(island, rng, 6, 6)
		if p then
			reserve(p, 4)
			local base = at(p, TOP)
			if ring == 1 then
				if rng:NextNumber() < 0.6 then
					K.canopyTree(parent, base, rng)
				else
					K.voxelTree(parent, base, rng, 1.1)
				end
			elseif ring == 2 then
				D.blockTree(parent, base, rng, rng:NextNumber(0.8, 1.15))
			else
				if rng:NextNumber() < 0.6 then
					deadTree(parent, base, rng)
				else
					stormRock(parent, base, rng, 1.3)
				end
			end
		end
	end
	for _ = 1, math.floor(r / 3) do
		local p = landPoint(island, rng, 3, 2)
		if p then
			local base = at(p, TOP)
			if ring == 1 then
				if rng:NextNumber() < 0.5 then
					K.daisies(parent, base - Vector3.new(0, 0.4, 0), rng)
				else
					D.tuft(parent, base, rng, Color3.fromRGB(90, 196, 90), Color3.fromRGB(150, 224, 110))
				end
			elseif ring == 2 then
				D.tuft(parent, base, rng, V.LEAVES[rng:NextInteger(1, #V.LEAVES)], rng:NextNumber() < 0.3 and Color3.fromRGB(255, 120, 150) or nil)
			else
				D.tuft(parent, base, rng, Color3.fromRGB(110, 126, 96))
			end
		end
	end
	-- coral and bamboo in the water around the island
	for _ = 1, math.floor(r / 6) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = r + rng:NextNumber(9, 22)
		local p = island.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if free(p, 4) then
			if ring == 1 then
				if rng:NextNumber() < 0.5 then
					K.bambooCluster(parent, at(p, WATER_Y - 6), rng)
				else
					decor({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.8, 2.8), CFrame = CFrame.new(p.X, WATER_Y + 0.08, p.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(92, 186, 84), CastShadow = false, Parent = parent })
					K.clovers(parent, p, rng)
				end
			elseif ring == 2 then
				coral(parent, at(p, FLOOR), rng, 1.6)
			else
				stormRock(parent, at(p, WATER_Y - 7), rng, 1.6)
			end
		end
	end
end

-- Bridges ---------------------------------------------------------------------------------------------------

local function bridgeEnds(a, b)
	local dir = (flat(b.pos) - flat(a.pos)).Unit
	return flat(a.pos) + dir * (a.r - 3), flat(b.pos) - dir * (b.r - 3), dir
end

-- The video's plank bridge on stilts: planks across the path, a handrail on posts, every board its own block.
local function plankSegment(parent, a, b, width)
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt(at((a + b) / 2, TOP - 0.4), at(b, TOP - 0.4))
	part({ Name = "PlankDeck", Size = Vector3.new(width, 0.8, length + 1), CFrame = frame, Color = PLANK_DARK, Parent = parent })
	local count = math.floor(length / 1.6)
	for i = 0, count do
		local z = -length / 2 + i * (length / math.max(count, 1))
		D.studded({ Name = "Plank", Size = Vector3.new(width + 0.6, 0.3, 1.3), CFrame = frame * CFrame.new(0, 0.5, z), Color = (i % 3 == 0) and PLANK_DARK or PLANK, CanCollide = false, CanQuery = false, Parent = parent })
	end
	local posts = math.max(1, math.floor(length / 8))
	for i = 0, posts do
		local z = -length / 2 + i * (length / posts)
		for _, side in ipairs({ -1, 1 }) do
			local base = frame * CFrame.new(side * (width / 2 + 0.2), 0, z)
			decor({ Name = "Rail Post", Size = Vector3.new(0.7, 3.4, 0.7), CFrame = base * CFrame.new(0, 1.9, 0), Color = PLANK_DARK, Parent = parent })
			local depth = base.Y - FLOOR
			decor({ Name = "Stilt", Size = Vector3.new(0.9, depth, 0.9), CFrame = base * CFrame.new(0, -depth / 2, 0), Color = PLANK_DARK, Parent = parent })
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "Rail", Size = Vector3.new(0.4, 0.4, length), CFrame = frame * CFrame.new(side * (width / 2 + 0.2), 3.4, 0), Color = PLANK, Parent = parent })
	end
end

-- A rickety rope bridge that sags toward the middle: slats with gaps, rope rails, the odd missing board.
local function ropeBridge(parent, a, b, rng)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local count = math.floor(length / 1.5)
	local sag = math.min(3.5, length / 40)
	local width = 6
	local previous = { [-1] = nil, [1] = nil }
	for i = 0, count do
		local s = i / count
		local p = a + (b - a) * s
		local y = TOP - 0.3 - sag * 4 * s * (1 - s)
		local frame = CFrame.lookAt(at(p, y), at(p + dir, y))
		-- slats are always walkable (collidable); a few look broken
		local broken = rng:NextNumber() < 0.06 and i > 2 and i < count - 2
		part({ Name = "Slat", Size = Vector3.new(width, 0.35, 1.2), CFrame = frame * CFrame.Angles(0, 0, broken and 0.12 or rng:NextNumber(-0.03, 0.03)), Color = broken and PLANK_DARK or (i % 2 == 0 and PLANK or Color3.fromRGB(160, 116, 74)), Material = Enum.Material.WoodPlanks, Parent = parent })
		if i % 4 == 0 then
			for _, sd in ipairs({ -1, 1 }) do
				local postBase = at(p, y) + side * sd * (width / 2 + 0.3)
				decor({ Name = "RopePost", Size = Vector3.new(0.5, 3.4, 0.5), CFrame = CFrame.new(postBase + Vector3.new(0, 1.6, 0)), Color = DEAD_WOOD, Parent = parent })
				local topPoint = postBase + Vector3.new(0, 3.2, 0)
				if previous[sd] then
					local mid = (previous[sd] + topPoint) / 2 - Vector3.new(0, 0.6, 0)
					rod(parent, previous[sd], mid, 0.3, ROPE)
					rod(parent, mid, topPoint, 0.3, ROPE)
				end
				previous[sd] = topPoint
			end
		end
	end
	-- thick anchor posts at both ends
	for _, endPoint in ipairs({ a, b }) do
		for _, sd in ipairs({ -1, 1 }) do
			part({ Name = "AnchorPost", Size = Vector3.new(1.4, 6, 1.4), CFrame = CFrame.new(at(endPoint, TOP + 2.5) + side * sd * (width / 2 + 0.8)), Color = DEAD_WOOD, Parent = parent })
		end
	end
end

local function buildLink(parent, link, rng)
	local a, b = L.byName[link[1]], L.byName[link[2]]
	local kind, bend = link[3], link[4] or 0
	local from, to, dir = bridgeEnds(a, b)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local mid = (from + to) / 2 + side * bend
	reserve(from, 5)
	reserve(to, 5)
	if kind == "boardwalk" then
		K.boardwalkSegment(parent, from, mid, 7)
		K.boardwalkSegment(parent, mid, to, 7)
		K.bambooCluster(parent, at(mid + side * 10, WATER_Y - 6), rng)
		K.crystalLantern(parent, at(mid + side * 4.5, TOP + 6), 2.5)
	elseif kind == "plank" then
		plankSegment(parent, from, mid, 6)
		plankSegment(parent, mid, to, 6)
		decor({ Name = "Joint", Size = Vector3.new(7, 0.8, 7), CFrame = CFrame.new(at(mid, TOP - 0.4)) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0), Color = PLANK_DARK, Parent = parent }).CanCollide = true
		coral(parent, at(mid - side * 9, FLOOR), rng, 2)
	else
		ropeBridge(parent, from, mid, rng)
		ropeBridge(parent, mid, to, rng)
		part({ Name = "BridgeRock", Size = Vector3.new(9, TOP - FLOOR, 9), CFrame = CFrame.new(at(mid, (TOP + FLOOR) / 2 - 0.4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = STORM_ROCK, Parent = parent })
	end
	return mid
end

-- Gameplay pieces --------------------------------------------------------------------------------------------

local function nearestIsland(position)
	local best, bestD = nil, math.huge
	for _, island in ipairs(L.islands) do
		local d = (flat(position) - island.pos).Magnitude - island.r
		if d < bestD then
			best, bestD = island, d
		end
	end
	return best, bestD
end

-- A short plank jetty from the shore out toward a fishing spot, so you stand at the water's edge to cast.
local function jetty(parent, spot)
	local island, gap = nearestIsland(spot)
	if not island then
		return
	end
	local fromCenter = flat(spot) - island.pos
	local startR, dir
	if island.feature == "lagoon" and fromCenter.Magnitude < island.r * 0.45 then
		dir = Vector3.new(-1, 0, 0)
		startR = island.r * 0.45 - 1
		local from = island.pos + dir * startR
		local to = island.pos + dir * 6
		plankSegment(parent, from, to, 4)
		return
	end
	if gap < 8 or fromCenter.Magnitude < 1 then
		return
	end
	dir = fromCenter.Unit
	local from = island.pos + dir * (island.r - 2)
	local to = flat(spot) - dir * 5.5
	if (to - from):Dot(dir) > 2 then
		plankSegment(parent, from, to, 4)
		decor({ Name = "JettyLamp", Size = Vector3.new(0.5, 5, 0.5), CFrame = CFrame.new(at(to, TOP + 2.5) + Vector3.new(-dir.Z, 0, dir.X) * 2.4), Color = PLANK_DARK, Parent = parent })
		K.crystalLantern(parent, at(to, TOP + 5) + Vector3.new(-dir.Z, 0, dir.X) * 2.4, 0.6)
	end
end

local function tideCache(parent, index, position)
	local cacheAt = at(position, TOP)
	disk(parent, "CacheBase", cacheAt + Vector3.new(0, 0.4, 0), 3.4, 0.8, P.MINT_ROCK)
	part({ Name = "CachePost", Size = Vector3.new(0.8, 8, 0.8), CFrame = CFrame.new(cacheAt + Vector3.new(0, 4.6, 0)), Color = P.POST, Parent = parent })
	part({ Name = "CacheArm", Size = Vector3.new(3.4, 0.5, 0.5), CFrame = CFrame.new(cacheAt + Vector3.new(1.4, 8.4, 0)), Color = P.POST, Parent = parent })
	K.crystalLantern(parent, cacheAt + Vector3.new(2.8, 8.2, 0), 1.2)
	local ring = decor({ Name = "CacheRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5.6, 5.6), CFrame = CFrame.new(cacheAt + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 120, 80), Parent = parent })
	decor({ Name = "CacheRingHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 3.8, 3.8), CFrame = ring.CFrame, Color = P.MINT_ROCK, Parent = parent })
	local chest = part({ Name = "TideCache" .. index, Size = Vector3.new(3, 2.2, 2.2), CFrame = CFrame.new(cacheAt + Vector3.new(0, 2.7, 0)), Color = P.PLANK, Material = Enum.Material.WoodPlanks, Parent = parent })
	decor({ Name = "CacheLid", Size = Vector3.new(3.2, 0.5, 2.4), CFrame = chest.CFrame * CFrame.new(0, 1.3, 0), Color = P.GOLD, Parent = parent })
	light(chest, P.BEACON, 16, 1.2)
	K.sparkles(chest, Color3.fromRGB(200, 255, 240), 4)
	-- a soft green healing circle: stand inside it to heal (Config.Isles.cacheRadius)
	local heal = disk(parent, "HealCircle", cacheAt + Vector3.new(0, 0.08, 0), 11, 0.15, Color3.fromRGB(120, 255, 170))
	heal.CanCollide = false
	heal.CanQuery = false
	heal.Material = Enum.Material.Neon
	heal.Transparency = 0.78
	K.particles(heal, {
		Color = ColorSequence.new(Color3.fromRGB(150, 255, 190)),
		LightEmission = 0.8,
		Rate = 6,
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(1.5, 3),
		Size = NumberSequence.new(0.35, 0),
		EmissionDirection = Enum.NormalId.Right,
	})
	prompt(chest, "Bank Catch", "Tide Cache", { Action = "BankCatch" }, 1, 12)
	billboard(chest, "TIDE CACHE", "Bank fish · stand here to heal", 5)
	tag(chest, "TideboundCache")
	reserve(position, 8)
end

local function anemoneBed(parent, position, rng)
	local base = Color3.fromRGB(196, 64, 126)
	local tip = Color3.fromRGB(255, 120, 200)
	local pad = decor({ Name = "AnemoneBed", Size = Vector3.new(8, 0.3, 8), CFrame = CFrame.new(position.X, TOP + 0.35, position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = base, Parent = parent })
	tag(pad, "TideboundAnemone")
	for _ = 1, 9 do
		local x, z = rng:NextNumber(-3.3, 3.3), rng:NextNumber(-3.3, 3.3)
		local h = rng:NextNumber(0.8, 1.8)
		local stalk = pad.CFrame * CFrame.new(x, h / 2, z)
		decor({ Name = "Stalk", Size = Vector3.new(0.4, h, 0.4), CFrame = stalk, Color = base, Parent = parent })
		decor({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = stalk * CFrame.new(0, h / 2, 0), Color = tip, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	end
	reserve(position, 5)
end

local function eliteDen(parent, index, den, rng)
	local island = nearestIsland(den.at)
	local center = at(den.at, TOP + 1)
	local slot = decor({ Name = ("EliteDen%02d"):format(index), Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center), Transparency = 1, Parent = parent })
	slot:SetAttribute("Island", island and island.name or "")
	slot:SetAttribute("Radius", den.radius)
	tag(slot, "TideboundEliteDen")
	for j = 1, 3 do
		local a = math.rad(j * 120 + rng:NextNumber(-25, 25))
		local d = den.radius * 0.7
		local p = den.at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if island and (flat(p) - island.pos).Magnitude > island.r - 4 then
			p = island.pos + (flat(p) - island.pos).Unit * (island.r - 4)
		end
		local holeAt = at(p, TOP)
		disk(slot, "HoleRim", holeAt + Vector3.new(0, 0.6, 0), 2.4, 1.2, Color3.fromRGB(70, 58, 84)).CanCollide = false
		local glow = disk(slot, "MorayHole" .. j, holeAt + Vector3.new(0, 1.25, 0), 1.6, 0.15, Color3.fromRGB(255, 190, 70))
		glow.CanCollide = false
		glow.CanQuery = false
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.7
		glow:SetAttribute("Hole", true)
		for _ = 1, 3 do
			local b = rng:NextNumber(0, math.pi * 2)
			decor({ Name = "Coral", Size = Vector3.new(0.5, rng:NextNumber(1, 2.2), 0.5), CFrame = CFrame.new(holeAt + Vector3.new(math.cos(b) * 2.6, 1.2, math.sin(b) * 2.6)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(255, 140, 120), Parent = slot })
		end
		reserve(p, 3.5)
	end
	reserve(den.at, 4)
end

-- Geyser jump pads: a ring of stone round a bubbling vent. TideboundTravel launches you to the partner pad.
local function jumpPad(parent, index, from, to)
	local base = at(from, TOP)
	disk(parent, "GeyserRing", base + Vector3.new(0, 0.5, 0), 4.6, 1, P.MINT_ROCK)
	local pad = disk(parent, "JumpPad" .. index, base + Vector3.new(0, 1.05, 0), 3.4, 0.3, GEYSER)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.2
	pad:SetAttribute("Target", at(to, TOP + 1.2))
	tag(pad, "TideboundJumpPad")
	light(pad, GEYSER, 18, 1.6)
	K.particles(pad, {
		Color = ColorSequence.new(Color3.fromRGB(230, 250, 255), Color3.fromRGB(150, 230, 255)),
		LightEmission = 0.4,
		Rate = 22,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(10, 18),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) }),
		Transparency = NumberSequence.new(0.3, 1),
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, -14, 0),
		EmissionDirection = Enum.NormalId.Right,
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		decor({ Name = "GeyserStone", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 4.6, 1.2, math.sin(a) * 4.6)) * CFrame.Angles(0, a, 0.2), Color = Color3.fromRGB(150, 180, 190), Parent = parent })
	end
	local destination = nearestIsland(to)
	billboard(pad, "GEYSER", destination and ("Step on: launch to " .. destination.title) or "Step on to launch", 4)
	reserve(from, 7)
end

-- Set pieces -------------------------------------------------------------------------------------------------

local function signPost(parent, position, facing, text, color)
	local cf = CFrame.lookAt(at(position, TOP + 4.5), at(facing, TOP + 4.5))
	local sign = part({ Name = "Sign", Size = Vector3.new(11, 4, 0.6), CFrame = cf, Color = SIGN_DARK, Parent = parent })
	K.surfaceText(sign, text, color or V.RUNE)
	for _, x in ipairs({ -4, 4 }) do
		part({ Name = "SignPost", Size = Vector3.new(0.8, 5, 0.8), CFrame = cf * CFrame.new(x, -3.5, 0.2), Color = V.HULL_DARK, Parent = parent })
	end
end

local function coralArch(parent, a, b, rise, color)
	local pieces = 10
	local previous = a
	for i = 1, pieces do
		local s = i / pieces
		local p = a:Lerp(b, s) + Vector3.new(0, rise * math.sin(s * math.pi), 0)
		local seg = part({ Name = "CoralArch", Size = Vector3.new(3.2, 3.2, (p - previous).Magnitude + 1), CFrame = CFrame.lookAt((p + previous) / 2, p), Color = (i % 2 == 0) and color or color:Lerp(Color3.new(1, 1, 1), 0.2), Parent = parent })
		seg.CanCollide = i == 1 or i == pieces
		previous = p
	end
end

local function cave(parent, center, facing, rng)
	local cf = CFrame.lookAt(at(center, TOP), at(facing, TOP))
	-- a dome of big blocks with the mouth toward `facing`
	for ring = 0, 2 do
		local r = 10 - ring * 3
		local y = 2 + ring * 4
		local n = 12 - ring * 3
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			local front = math.cos(a) -- 1 points at the mouth (-Z of cf)
			if not (front > 0.72 and ring < 2) then
				local p = cf * CFrame.new(math.sin(a) * r, y, -math.cos(a) * r)
				part({ Name = "CaveRock", Size = Vector3.new(6, 5, 6) * (1 - ring * 0.12), CFrame = p * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = (i % 2 == 0) and STORM_ROCK or Color3.fromRGB(120, 112, 104), Parent = parent })
			end
		end
	end
	part({ Name = "CaveRoof", Size = Vector3.new(9, 3, 9), CFrame = cf * CFrame.new(0, 14, 0), Color = STORM_ROCK, Parent = parent })
	for i = 1, 3 do
		local lantern = decor({ Name = "CaveLantern", Size = Vector3.new(0.8, 1.2, 0.8), CFrame = cf * CFrame.new(math.cos(i * 2) * 4, 3 + i, math.sin(i * 2) * 4), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, Parent = parent })
		light(lantern, Color3.fromRGB(255, 180, 90), 12, 1)
	end
	for _ = 1, 5 do
		K.crate(parent, cf * CFrame.new(rng:NextNumber(-6, 6), 1.3, rng:NextNumber(0, 6)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0))
	end
end

local function ribcage(parent, center, rng)
	local spine = 22
	for i = -3, 3 do
		local z = i * spine / 6
		for _, side in ipairs({ -1, 1 }) do
			local base = at(center, TOP) + Vector3.new(side * 6, 0, z)
			local top = at(center, TOP + 9) + Vector3.new(side * 1.5, 0, z)
			local mid = (base + top) / 2 + Vector3.new(side * 2.5, 0, 0)
			rod(parent, base, mid, 1.3, V.BONE)
			rod(parent, mid, top, 1.1, V.BONE)
		end
	end
	decor({ Name = "Spine", Size = Vector3.new(1.6, 1.6, spine + 6), CFrame = CFrame.new(at(center, TOP + 9.4)), Color = V.BONE, Parent = parent })
	local skull = at(center, TOP + 3) + Vector3.new(0, 0, spine / 2 + 7)
	part({ Name = "Skull", Size = Vector3.new(10, 6, 12), CFrame = CFrame.new(skull) * CFrame.Angles(0.15, rng:NextNumber(-0.2, 0.2), 0), Color = V.BONE, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "EyeHole", Size = Vector3.new(2, 2, 0.6), CFrame = CFrame.new(skull + Vector3.new(side * 2.4, 1, 6)), Color = Color3.fromRGB(30, 30, 36), Parent = parent })
	end
end

local function seaStacks(parent, island, eggTop, rng)
	-- a spiral of stepping stacks rising to the tallest one, where the egg sits
	local egg = L.eggNests[7].at
	local steps = 9
	for i = 1, steps do
		local s = i / steps
		local a = s * math.pi * 1.6 + 0.5
		local d = 14 - s * 9
		local p = egg + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local top = TOP + s * (eggTop - TOP - 3)
		disk(parent, "StepStack" .. i, Vector3.new(p.X, (FLOOR + top) / 2, p.Z), 2.6, top - FLOOR, (i % 2 == 0) and STORM_ROCK or Color3.fromRGB(150, 140, 126))
		D.studded({ Name = "StackTop", Size = Vector3.new(4.2, 0.4, 4.2), CFrame = CFrame.new(p.X, top + 0.2, p.Z) * CFrame.Angles(0, a, 0), Color = V.PATH, Parent = parent })
	end
	disk(parent, "TallStack", Vector3.new(egg.X, (FLOOR + eggTop) / 2, egg.Z), 5, eggTop - FLOOR, Color3.fromRGB(150, 140, 126))
	D.checkerDisk(parent, egg, 4.5, 3, eggTop - 0.5)
	-- more stacks standing in the water around the island
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = island.r + rng:NextNumber(8, 24)
		local p = island.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local h = rng:NextNumber(14, 30)
		disk(parent, "SeaStack", Vector3.new(p.X, (FLOOR + h) / 2, p.Z), rng:NextNumber(3, 6), h - FLOOR, Color3.fromRGB(140, 130, 118))
		disk(parent, "StackCap", Vector3.new(p.X, h + 0.3, p.Z), 3, 0.6, V.GRASS_A)
	end
end

local function giantClam(parent, center)
	local base = at(center, TOP)
	local shell = Color3.fromRGB(196, 170, 230)
	part({ Name = "ClamBottom", Size = Vector3.new(14, 3, 11), CFrame = CFrame.new(base + Vector3.new(0, 1.5, 0)), Color = shell, Parent = parent })
	part({ Name = "ClamTop", Size = Vector3.new(14, 1.6, 11), CFrame = CFrame.new(base + Vector3.new(0, 7, 4)) * CFrame.Angles(math.rad(-50), 0, 0), Color = shell:Lerp(Color3.new(1, 1, 1), 0.2), Parent = parent })
	for i = -3, 3 do
		decor({ Name = "ClamRidge", Size = Vector3.new(0.6, 0.6, 11.2), CFrame = CFrame.new(base + Vector3.new(i * 1.8, 3.1, 0)), Color = shell:Lerp(Color3.new(0, 0, 0), 0.15), Parent = parent })
	end
	local pearl = decor({ Name = "GiantPearl", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(base + Vector3.new(0, 4.6, -1)), Color = Color3.fromRGB(255, 250, 240), Material = Enum.Material.Neon, Parent = parent })
	light(pearl, Color3.fromRGB(255, 240, 220), 22, 1.6)
	K.sparkles(pearl, Color3.fromRGB(255, 255, 255), 6)
end

local function stormSpire(parent, center, rng)
	local base = at(center, TOP)
	local y = TOP
	for i = 1, 6 do
		local h = 8 - i * 0.6
		local w = 9 - i * 1.3
		part({ Name = "Spire", Size = Vector3.new(w, h, w), CFrame = CFrame.new(base.X + rng:NextNumber(-0.8, 0.8), y + h / 2, base.Z + rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(0, i * 0.4, 0), Color = STORM_ROCK, Parent = parent })
		y += h
	end
	local tip = decor({ Name = "LightningRod", Size = Vector3.new(0.6, 10, 0.6), CFrame = CFrame.new(base.X, y + 5, base.Z), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Parent = parent })
	local orb = decor({ Name = "StormOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(base.X, y + 10.6, base.Z), Color = Color3.fromRGB(150, 200, 255), Material = Enum.Material.Neon, Parent = parent })
	light(orb, Color3.fromRGB(150, 200, 255), 40, 2.2)
	K.particles(orb, {
		Color = ColorSequence.new(Color3.fromRGB(200, 230, 255)),
		LightEmission = 1,
		Rate = 14,
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(8, 14),
		Size = NumberSequence.new(0.4, 0),
		SpreadAngle = Vector2.new(180, 180),
	})
	return tip
end

local function wardenRock(parent, island, rng)
	local c = island.pos
	-- ruined pillars in a broken ring round the lair, and a glowing seal on the ground
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24)
		if free(p, 3) and i % 3 ~= 0 then
			local h = rng:NextNumber(6, 14)
			part({ Name = "RuinPillar", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(at(p, TOP + h / 2)), Color = V.STONE_DARK, Parent = parent })
			decor({ Name = "Rune", Size = Vector3.new(1.4, 2.4, 0.2), CFrame = CFrame.lookAt(at(p, TOP + h * 0.6), at(c, TOP + h * 0.6)) * CFrame.new(0, 0, -1.6), Color = Color3.fromRGB(255, 90, 80), Material = Enum.Material.Neon, Parent = parent })
		end
	end
	local seal = disk(parent, "WardenSeal", at(c, TOP + 0.1), 12, 0.2, Color3.fromRGB(255, 80, 70))
	seal.CanCollide = false
	seal.Material = Enum.Material.Neon
	seal.Transparency = 0.7
	signPost(parent, c + Vector3.new(-island.r + 8, 0, 6), c, "WARDEN'S ROCK\nTwo eggs. One very angry guardian.", Color3.fromRGB(255, 140, 120))
end

local function mangroves(parent, island, rng)
	for _ = 1, 6 do
		local p = landPoint(island, rng, 8, 5)
		if p then
			local base = at(p, TOP)
			local trunkTop = base + Vector3.new(0, 8, 0)
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local foot = base + Vector3.new(math.cos(a) * 4, -0.5, math.sin(a) * 4)
				local knee = base + Vector3.new(math.cos(a) * 3, 3.5, math.sin(a) * 3)
				rod(parent, foot, knee, 0.7, Color3.fromRGB(110, 90, 70))
				rod(parent, knee, trunkTop - Vector3.new(0, 3, 0), 0.8, Color3.fromRGB(110, 90, 70))
			end
			decor({ Name = "MangroveTrunk", Size = Vector3.new(1.4, 5, 1.4), CFrame = CFrame.new(trunkTop - Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(110, 90, 70), Parent = parent })
			for _ = 1, 4 do
				local s = rng:NextNumber(5, 8)
				K.windy(decor({ Name = "MangroveLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.3, s * 0.6, s), CFrame = CFrame.new(trunkTop + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 2), rng:NextNumber(-3, 3))), Color = Color3.fromRGB(60, 130, 70), Parent = parent }))
			end
			reserve(p, 4)
		end
	end
end

local function turtles(parent, island, rng)
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = island.pos + Vector3.new(math.cos(a) * (island.r + 2), 0, math.sin(a) * (island.r + 2))
		local base = at(p, WATER_Y + 0.9)
		local cf = CFrame.new(base) * CFrame.Angles(0, -a, 0)
		decor({ Name = "TurtleShell", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 1.6, 4), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(70, 130, 80), Parent = parent })
		decor({ Name = "TurtleHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1, 1.4), CFrame = cf * CFrame.new(0, 0.4, -2.4), Color = Color3.fromRGB(150, 196, 120), Parent = parent })
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				decor({ Name = "Flipper", Size = Vector3.new(1.4, 0.3, 0.8), CFrame = cf * CFrame.new(sx * 1.8, 0.1, sz * 1.2) * CFrame.Angles(0, sx * sz * 0.4, 0), Color = Color3.fromRGB(150, 196, 120), Parent = parent })
			end
		end
	end
	for _ = 1, 3 do
		local p = landPoint(island, rng, 5, 4)
		if p then
			palmTree(parent, at(p, TOP), rng, 1)
			reserve(p, 3)
		end
	end
end

local function kelpBeds(parent, island, rng)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = island.r + rng:NextNumber(4, 26)
		local p = island.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if free(p, 2) then
			local h = rng:NextNumber(WATER_Y - FLOOR + 1, WATER_Y - FLOOR + 6)
			local stalk = decor({ Name = "KelpStalk", Size = Vector3.new(0.9, h, 0.9), CFrame = CFrame.new(p.X, FLOOR + h / 2, p.Z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(92, 150, 60), Parent = parent })
			K.windy(stalk)
			K.windy(decor({ Name = "KelpLeaf", Size = Vector3.new(0.3, 1.8, 3.2), CFrame = CFrame.new(p.X, WATER_Y + 0.3, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(80)), Color = Color3.fromRGB(146, 190, 72), Parent = parent }))
		end
	end
end

local function gullRock(parent, island, rng)
	for _ = 1, 5 do
		local p = landPoint(island, rng, 4, 4)
		if p then
			stormRock(parent, at(p, TOP), rng, 1.4)
			local nest = at(p, TOP) + Vector3.new(0, 0.4, 0)
			disk(parent, "GullNest", nest + Vector3.new(3, 0, 0), 1.6, 0.6, Color3.fromRGB(170, 140, 90))
			for i = 1, 2 do
				K.eggShape(parent, "GullEgg", CFrame.new(nest + Vector3.new(3 + i * 0.6 - 0.9, 0.7, 0)), Vector3.new(0.6, 0.8, 0.6), Color3.fromRGB(220, 214, 196))
			end
			decor({ Name = "Guano", Size = Vector3.new(2.5, 0.1, 1.8), CFrame = CFrame.new(nest + Vector3.new(-2, -0.25, 1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = Color3.fromRGB(240, 240, 236), Parent = parent })
			reserve(p, 5)
		end
	end
end

local function lagoon(parent, island, rng)
	-- the lagoon glows a little, and a stone puffer statue stands guard on the ring
	local glow = disk(parent, "LagoonGlow", at(island.pos, WATER_Y - 2.5), island.r * 0.42, 0.2, Color3.fromRGB(90, 230, 220))
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.5
	local statueAt = island.pos + Vector3.new(0, 0, island.r * 0.72)
	part({ Name = "StatuePlinth", Size = Vector3.new(5, 3, 5), CFrame = CFrame.new(at(statueAt, TOP + 1.5)), Color = V.STONE, Parent = parent })
	part({ Name = "PufferStatue", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(at(statueAt, TOP + 6)), Color = V.STONE_DARK, Parent = parent })
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		decor({ Name = "StatueSpike", Size = Vector3.new(0.6, 0.6, 2), CFrame = CFrame.lookAt(at(statueAt, TOP + 6), at(statueAt, TOP + 6) + Vector3.new(math.cos(a), math.sin(a * 2) * 0.4, math.sin(a))) * CFrame.new(0, 0, -3.4), Color = V.STONE, Parent = parent })
	end
	reserve(statueAt, 4)
	for _ = 1, 3 do
		local p = landPoint(island, rng, 4, 4)
		if p then
			palmTree(parent, at(p, TOP), rng, 0.9)
		end
	end
end

local function farReach(parent, island)
	local c = island.pos
	local shrine = c + Vector3.new(6, 0, -6)
	part({ Name = "ShrineBase", Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(at(shrine, TOP + 0.5)), Color = V.STONE, Parent = parent })
	for _, sx in ipairs({ -3, 3 }) do
		for _, sz in ipairs({ -3, 3 }) do
			part({ Name = "ShrinePillar", Size = Vector3.new(1, 7, 1), CFrame = CFrame.new(at(shrine, TOP + 4.5) + Vector3.new(sx, 0, sz)), Color = V.STONE_DARK, Parent = parent })
		end
	end
	decor({ Name = "ShrineRoof", Size = Vector3.new(9, 1, 9), CFrame = CFrame.new(at(shrine, TOP + 8.5)) * CFrame.Angles(0, math.rad(45), 0), Color = P.TORII_RED, Parent = parent })
	signPost(parent, c + Vector3.new(-10, 0, 8), c + Vector3.new(30, 0, 8), "FAR REACH\nThe edge of the charts. Turn back, diver.", Color3.fromRGB(255, 220, 140))
	reserve(shrine, 6)
end

local FEATURES = {}

function FEATURES.landing(parent, island, rng)
	local c = island.pos
	-- the causeway lands here: a stone welcome arch and the REF 2 lattice hut
	local gate = c + Vector3.new(-island.r + 6, 0, 0)
	for _, z in ipairs({ -9.5, 9.5 }) do
		part({ Name = "ArchPillar", Size = Vector3.new(3, 14, 3), CFrame = CFrame.new(at(gate + Vector3.new(0, 0, z), TOP + 7)), Color = P.MINT_ROCK, Parent = parent })
		K.crystalLantern(parent, at(gate + Vector3.new(2, 0, z), TOP + 13), 2.5)
	end
	local arch = decor({ Name = "ArchBeam", Size = Vector3.new(3.4, 3, 23), CFrame = CFrame.new(at(gate, TOP + 15)), Color = P.DECK, Parent = parent })
	K.surfaceText(arch, "SUNKEN SHOALS", Color3.fromRGB(200, 255, 230), Enum.NormalId.Left)
	K.surfaceText(arch, "EGGFALL TOWN", Color3.fromRGB(255, 236, 170), Enum.NormalId.Right)
	reserve(gate, 9)
	K.latticeHut(parent, at(c + Vector3.new(8, 0, -20), TOP), c)
	reserve(c + Vector3.new(8, 0, -20), 10)
	signPost(parent, c + Vector3.new(-14, 0, 18), c + Vector3.new(-40, 0, 18), "RING 1 · THE SHALLOWS\nCast at glowing spots. Steal eggs. Get out alive.", Color3.fromRGB(200, 255, 230))
end

function FEATURES.lavender(parent, island, rng)
	local tree = island.pos + Vector3.new(4, 0, 12)
	K.giantLavenderTree(parent, at(tree, TOP - 0.5), rng)
	reserve(tree, 8)
end

function FEATURES.bamboo(parent, island, rng)
	for _ = 1, 8 do
		local p = landPoint(island, rng, 4, 3)
		if p then
			K.bambooCluster(parent, at(p, TOP), rng)
			reserve(p, 3)
		end
	end
end

function FEATURES.twin(parent, island, rng)
	if island.name == "TwinReefNorth" then
		K.latticeHut(parent, at(island.pos + Vector3.new(-8, 0, 14), TOP), island.pos)
		reserve(island.pos + Vector3.new(-8, 0, 14), 9)
	end
	for _ = 1, 2 do
		local p = landPoint(island, rng, 6, 6)
		if p then
			K.canopyTree(parent, at(p, TOP), rng)
			reserve(p, 4)
		end
	end
end

FEATURES.turtles = turtles
FEATURES.mangrove = mangroves
FEATURES.kelpbeds = kelpBeds

function FEATURES.shipwreck(parent, island, rng)
	D.shipwreck(parent, island.pos, rng)
	reserve(island.pos, 16)
end

function FEATURES.arches(parent, island, rng)
	local c = island.pos
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + 0.4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local mid = c + dir * (island.r * 0.55)
		coralArch(parent, at(mid - side * 9, TOP), at(mid + side * 9, TOP), 14, CORALS[i])
		reserve(mid - side * 9, 3)
		reserve(mid + side * 9, 3)
	end
	for _ = 1, 8 do
		local p = landPoint(island, rng, 3, 3)
		if p then
			coral(parent, at(p, TOP), rng, 1.2)
		end
	end
end

function FEATURES.stacks(parent, island, rng)
	seaStacks(parent, island, L.eggNests[7].y or 32, rng)
	reserve(L.eggNests[7].at, 15)
end

function FEATURES.cove(parent, island, rng)
	local egg = L.eggNests[8].at
	cave(parent, egg, egg + (flat(egg) - island.pos).Unit * 20 + Vector3.new(0, 0, -20), rng)
	reserve(egg, 12)
	signPost(parent, island.pos + Vector3.new(-14, 0, -14), island.pos + Vector3.new(-40, 0, -40), "SMUGGLERS' COVE\nThe egg is in the cave. So are the crabs.", Color3.fromRGB(255, 200, 120))
end

FEATURES.lagoon = lagoon
FEATURES.gulls = gullRock

function FEATURES.atoll(parent, island, rng)
	for _ = 1, 5 do
		local p = landPoint(island, rng, 4, 4)
		if p then
			palmTree(parent, at(p, TOP), rng, rng:NextNumber(0.9, 1.2))
			reserve(p, 3)
		end
	end
end

function FEATURES.clam(parent, island)
	local clamAt = island.pos + Vector3.new(-6, 0, -14)
	giantClam(parent, clamAt)
	reserve(clamAt, 9)
end

function FEATURES.lighthouse(parent, island)
	local lh = island.pos + Vector3.new(10, 0, 10)
	D.lighthouse(parent, at(lh, 0))
	reserve(lh, 8)
end

function FEATURES.maelstrom(parent, island, rng)
	D.maelstrom(parent, L.maelstrom, rng)
	local c = island.pos
	signPost(parent, c + Vector3.new(18, 0, -6), L.maelstrom, "THE MAELSTROM\nPush deeper at any beacon to dive to Kelp Cathedral", V.RUNE)
	reserve(c + Vector3.new(18, 0, -6), 5)
end

function FEATURES.warden(parent, island, rng)
	wardenRock(parent, island, rng)
end

function FEATURES.spire(parent, island, rng)
	local spire = island.pos + Vector3.new(-6, 0, -6)
	stormSpire(parent, spire, rng)
	reserve(spire, 7)
end

function FEATURES.bones(parent, island, rng)
	ribcage(parent, L.eggNests[15].at, rng)
	reserve(L.eggNests[15].at, 12)
end

FEATURES.far = farReach

-- Schools of glowing fish under the surface, for life (TideboundFX circles them).
local function schools(parent, rng)
	local colors = { Color3.fromRGB(90, 255, 230), Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 120, 190), Color3.fromRGB(150, 200, 255) }
	for i, island in ipairs(L.islands) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = island.r + rng:NextNumber(14, 30)
		local p = island.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local anchor = decor({ Name = "School", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(p.X, WATER_Y - 2.5, p.Z), Transparency = 1, Parent = parent })
		anchor:SetAttribute("Radius", rng:NextNumber(6, 11))
		anchor:SetAttribute("Count", rng:NextInteger(6, 10))
		anchor:SetAttribute("Color", colors[(i % #colors) + 1])
		tag(anchor, "TideboundSchool")
	end
end

-- Build -------------------------------------------------------------------------------------------------------

local function build(root)
	local rng = Random.new(2026)
	reserved = {}

	-- reserve every gameplay spot first so decoration keeps clear of them
	for _, nest in ipairs(L.eggNests) do
		reserve(nest.at, 5)
	end
	for _, b in ipairs(L.beacons) do
		reserve(b, 8)
	end
	for _, c in ipairs(L.tideCaches) do
		reserve(c, 8)
	end
	for _, pair in ipairs(L.jumpPads) do
		reserve(pair[1], 7)
		reserve(pair[2], 7)
	end
	for _, bed in ipairs(L.anemoneBeds) do
		reserve(bed, 5)
	end
	for _, spot in ipairs(L.fishingSpots) do
		local island = nearestIsland(spot)
		if island then
			local fromCenter = flat(spot) - island.pos
			if fromCenter.Magnitude > 1 then
				reserve(island.pos + fromCenter.Unit * (island.r - 3), 5)
			end
		end
	end

	local islands = Instance.new("Folder")
	islands.Name = "Islands"
	islands.Parent = root
	for _, island in ipairs(L.islands) do
		local folder = Instance.new("Folder")
		folder.Name = island.name
		folder.Parent = islands
		islandLand(folder, island, rng)
		islandTitle(folder, island)
	end

	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = root
	for _, link in ipairs(L.links) do
		buildLink(bridges, link, rng)
	end

	-- the causeway from the Tidegate to Landing Reef: a wide stone road on piers with lamp posts
	local cw = L.causeway
	local from, to = at(cw.from, 0), at(cw.to, 0)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(at((from + to) / 2, TOP - 1), at(to, TOP - 1))
	part({ Name = "Causeway", Size = Vector3.new(cw.width, 2, length + 4), CFrame = frame, Color = P.STONE, Material = Enum.Material.Cobblestone, Parent = bridges })
	for i = 0, math.floor(length / 12) do
		local z = -length / 2 + i * 12
		part({ Name = "CausewayPier", Size = Vector3.new(cw.width - 2, TOP - FLOOR, 3), CFrame = frame * CFrame.new(0, -(TOP - FLOOR) / 2, z), Color = P.STONE:Lerp(Color3.new(0, 0, 0), 0.15), Parent = bridges })
		for _, side in ipairs({ -1, 1 }) do
			decor({ Name = "CausewayWall", Size = Vector3.new(1, 1.6, 12), CFrame = frame * CFrame.new(side * (cw.width / 2 - 0.5), 1.8, z + 6), Color = P.TAN, Parent = bridges })
			if i % 2 == 0 then
				K.lampPost(bridges, (frame * CFrame.new(side * (cw.width / 2 - 0.5), 1, z)).Position, (frame * CFrame.new(0, 1, z)).Position)
			end
		end
	end

	-- every island's own set piece, then decoration around what's reserved
	for _, island in ipairs(L.islands) do
		local folder = islands:FindFirstChild(island.name)
		local feature = FEATURES[island.feature]
		if feature then
			feature(folder, island, rng)
		end
	end

	local gameplay = Instance.new("Folder")
	gameplay.Name = "Gameplay"
	gameplay.Parent = root

	local spots = Instance.new("Folder")
	spots.Name = "FishingSpots"
	spots.Parent = gameplay
	for i, spot in ipairs(L.fishingSpots) do
		local p = D.fishingSpot(spots, 200 + i, spot, WATER_Y, 1)
		local cast = p:FindFirstChildOfClass("ProximityPrompt")
		if cast then
			cast.MaxActivationDistance = 20
		end
		light(p, Color3.fromRGB(150, 236, 255), 12, 0.8)
		jetty(spots, spot)
	end

	local nests = Instance.new("Folder")
	nests.Name = "EggNests"
	nests.Parent = gameplay
	for i, nest in ipairs(L.eggNests) do
		D.wildEgg(nests, 200 + i, nest.at, nest.y or TOP)
	end

	local beacons = Instance.new("Folder")
	beacons.Name = "Beacons"
	beacons.Parent = gameplay
	for i, b in ipairs(L.beacons) do
		D.beacon(beacons, 200 + i, b, TOP, 1)
	end

	for i, c in ipairs(L.tideCaches) do
		tideCache(gameplay, i, c)
	end

	local hazards = Instance.new("Folder")
	hazards.Name = "AnemoneBeds"
	hazards.Parent = gameplay
	for _, bed in ipairs(L.anemoneBeds) do
		anemoneBed(hazards, bed, rng)
	end

	local dens = Instance.new("Folder")
	dens.Name = "EliteDens"
	dens.Parent = gameplay
	for i, den in ipairs(L.eliteDens) do
		eliteDen(dens, i, den, rng)
	end

	local pads = Instance.new("Folder")
	pads.Name = "JumpPads"
	pads.Parent = gameplay
	for i, pair in ipairs(L.jumpPads) do
		jumpPad(pads, i * 2 - 1, pair[1], pair[2])
		jumpPad(pads, i * 2, pair[2], pair[1])
	end

	for _, island in ipairs(L.islands) do
		decorate(islands:FindFirstChild(island.name), island, rng)
	end

	local life = Instance.new("Folder")
	life.Name = "Life"
	life.Parent = root
	schools(life, rng)

	-- the Reef Warden at its rock, and its patrol across the Coral Maze and the Outer Reef
	K.reefWarden(root, L.wardenLair)
	local path = Instance.new("Folder")
	path.Name = "WardenPath"
	path.Parent = root
	for i, wp in ipairs(L.wardenPath) do
		part({ Name = ("WP%02d"):format(i), Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(wp.X, 8, wp.Z), Transparency = 1, CanCollide = false, CanQuery = false, Parent = path })
	end

	-- petals over the Shallows, sea spray and storm drizzle over the Outer Reef
	local petals = decor({ Name = "PetalEmitter", Size = Vector3.new(500, 1, 900), CFrame = CFrame.new(500, 60, 0), Transparency = 1, Parent = life })
	K.particles(petals, {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 255, 230)),
		Rate = 40,
		Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(2, 4),
		Size = NumberSequence.new(0.35),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		EmissionDirection = Enum.NormalId.Bottom,
		Drag = 0.4,
		WindAffectsDrag = true,
	})
	local rain = decor({ Name = "StormRain", Size = Vector3.new(700, 1, 1300), CFrame = CFrame.new(1600, 90, 0), Transparency = 1, Parent = life })
	K.particles(rain, {
		Color = ColorSequence.new(Color3.fromRGB(200, 214, 236)),
		Rate = 260,
		Lifetime = NumberRange.new(1.6, 2),
		Speed = NumberRange.new(60, 70),
		Size = NumberSequence.new(0.12),
		Transparency = NumberSequence.new(0.35),
		EmissionDirection = Enum.NormalId.Bottom,
		Squash = NumberSequence.new(4),
	})
end

function ShoalsBuilder.build(world)
	local existing = world:FindFirstChild("SunkenShoals")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	fillSea()
	local root = Instance.new("Folder")
	root.Name = "SunkenShoals"
	root:SetAttribute("Version", VERSION)
	build(root)
	root.Parent = world
	return root
end

return ShoalsBuilder
