-- Tidebound: Eggfall: dresses the top of every Sunken Shoals island (Patch 10, the Open Isles).
-- ShoalsBuilder lays each island's ground and gameplay objects, then calls IsleFeatures.build once per island;
-- this adds the set pieces its `feature` names (IslesLayout.islands) and the ring's supporting detail:
--   Ring 1, the Shallows (REF 2): canopy trees with crystal lanterns, the lavender tree, bamboo, lattice huts.
--   Ring 2, the Coral Maze (the video): chunky voxel trees and grass, bright stacked coral, wrecks and stacks.
--   Ring 3, the Outer Reef (stormy): dark rock, dead white trees, broken posts, ruins and old bones.
-- Every gameplay object on an island (nests, beacons, caches, beds, dens, pads, fishing spots, camps and the
-- bridge lanes) is kept clear (see `clear`), and most of each top stays open and flat for fights.
-- Everything goes into a "Features" folder inside the island's folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local DescentBuilder = require(script.Parent:WaitForChild("DescentBuilder"))
local L = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("IslesLayout"))

local IsleFeatures = {}

local K = WorldBuilder.kit
local D = DescentBuilder.kit
local P = K.color
local DP = D.color
local part, decor, disk, rod, light = K.part, K.decor, K.disk, K.rod, K.light
local windy, tag = D.windy, D.tag
local TOP, WATER_Y, SEA_FLOOR = K.TOP, K.WATER_Y, K.SEA_FLOOR

-- palette
local CORAL = { Color3.fromRGB(255, 112, 168), Color3.fromRGB(255, 150, 64), Color3.fromRGB(168, 104, 236), Color3.fromRGB(255, 214, 84), Color3.fromRGB(244, 84, 96), Color3.fromRGB(72, 214, 204) }
local DARK = Color3.fromRGB(62, 66, 76)
local DARKER = Color3.fromRGB(44, 48, 58)
local MOSS = Color3.fromRGB(78, 128, 78)
local DEAD = Color3.fromRGB(204, 202, 196)
local DEAD_DARK = Color3.fromRGB(150, 150, 146)
local SAND = Color3.fromRGB(236, 216, 160)
local WOOD = P.PLANK
local WOOD_DARK = P.PLANK_EDGE
local IRON = Color3.fromRGB(58, 58, 66)
local GOLD = Color3.fromRGB(255, 206, 70)
local BONE = DP.BONE
local RUNE = DP.RUNE
local STONE = DP.STONE
local STONE_DARK = DP.STONE_DARK
local MINT = P.MINT_ROCK
local MINT_DARK = Color3.fromRGB(150, 208, 186)
local WARM = Color3.fromRGB(255, 196, 110)
local SKY_TEXT = Color3.fromRGB(110, 236, 255)
local PALM = { Color3.fromRGB(70, 180, 80), Color3.fromRGB(96, 200, 90), Color3.fromRGB(52, 156, 70) }
local ROOT = Color3.fromRGB(106, 84, 66)
local GRASS_1 = { Color3.fromRGB(118, 214, 96), Color3.fromRGB(170, 236, 120) }
local GRASS_2 = { DP.GRASS_A, DP.GRASS_B }
local GRASS_3 = { MOSS, Color3.fromRGB(116, 150, 98) }

-- Clearance -----------------------------------------------------------------------------------------------------
-- Rebuilt for each island: the gameplay objects decor keeps away from, and the bridge lanes.

local LANE_HALF = 5 -- bridge lanes are 10 studs wide, from the landing on the rim to the island's centre
local keep = {} -- { at = flat position, r = the object's own radius }
local lanes = {} -- { a, b } flat segments

local function flat(p)
	return Vector3.new(p.X, 0, p.Z)
end

local function laneDistance(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- Room taken by something on this island: a gameplay object, or a set piece already placed.
local function claim(p, r)
	table.insert(keep, { at = flat(p), r = r or 0 })
end

-- True when `pos` is at least `margin` studs from every gameplay object here (7 for big decor, 3 for tufts and
-- flowers) and keeps out of the bridge lanes.
local function clear(pos, margin)
	local p = flat(pos)
	for _, k in ipairs(keep) do
		if (p - k.at).Magnitude < margin + k.r then
			return false
		end
	end
	for _, lane in ipairs(lanes) do
		if laneDistance(p, lane[1], lane[2]) < LANE_HALF + margin * 0.5 then
			return false
		end
	end
	return true
end

-- Gathers every gameplay position on (or just off) this island from IslesLayout.
local function prepare(island)
	keep, lanes = {}, {}
	local c = flat(island.pos)
	local function add(p, r, reach)
		if (flat(p) - c).Magnitude <= island.r + (reach or 16) then
			claim(p, r)
		end
	end
	for _, nest in ipairs(L.eggNests) do
		add(nest.at, 2.8)
	end
	for _, b in ipairs(L.beacons) do
		add(b, 6) -- the studded beacon pad is 12 x 12
	end
	for _, t in ipairs(L.tideCaches) do
		add(t, 4)
	end
	for _, bed in ipairs(L.anemoneBeds) do
		add(bed, 4) -- 8 x 8
	end
	for _, den in ipairs(L.eliteDens) do
		add(den.at, 0)
	end
	for _, pair in ipairs(L.jumpPads) do
		add(pair[1], 4)
		add(pair[2], 4)
	end
	for _, camp in ipairs(L.camps) do
		add(camp.at, 0)
	end
	for _, f in ipairs(L.fishingSpots) do
		add(f, 4, 32) -- the cast ring is 8 across, out in the water off the shore
	end
	for _, link in ipairs(L.links) do
		local other = nil
		if link[1] == island.name then
			other = L.byName[link[2]]
		elseif link[2] == island.name then
			other = L.byName[link[1]]
		end
		if other then
			-- from the centre out past the landing on the rim, so offshore decor stays off the bridge too
			local dir = (flat(other.pos) - c).Unit
			table.insert(lanes, { c, c + dir * (island.r + 24) })
		end
	end
	-- Landing Reef: where a dive drops you, and the path from the causeway east across the island
	local spawn = L.diveSpawn.Position
	if (flat(spawn) - c).Magnitude <= island.r then
		claim(spawn, 4)
		table.insert(lanes, { flat(L.causeway.to) - Vector3.new(24, 0, 0), c + Vector3.new(island.r + 24, 0, 0) })
	end
	-- Maelstrom Isle: the ascend point facing the whirlpool
	local ascend = L.ascend.Position
	if (flat(ascend) - c).Magnitude <= island.r then
		claim(ascend, 8)
	end
	-- Warden's Rock: the Warden hovers over its lair, 16 studs kept open around it
	if (flat(L.wardenLair) - c).Magnitude < 1 then
		claim(c, 9)
	end
end

-- Placement ------------------------------------------------------------------------------------------------------

local function at(island, dx, dz, y)
	return Vector3.new(island.pos.X + dx, y or TOP, island.pos.Z + dz)
end

-- ShoalsBuilder passes ctx.onLand(position, margin): true when the point is on this island's ground, `margin`
-- studs in from its coast (a negative margin reaches out past it). Without it, anything inside island.r counts.
local onLandFn = nil

local function onIsland(p, margin)
	if onLandFn then
		return onLandFn(p, margin or 0)
	end
	return true
end

-- Out in the open water off this island, past its shore rocks.
local function inWater(island, p)
	if onLandFn then
		return not onLandFn(p, -6)
	end
	return (flat(p) - flat(island.pos)).Magnitude > island.r + 4
end

-- A random clear spot on the island, `inner` to `outer` studs from its centre (nil when none turns up).
local function spot(island, rng, inner, outer, margin, y)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(inner, outer)
		local p = at(island, math.cos(a) * d, math.sin(a) * d, y)
		if clear(p, margin) and onIsland(p, math.min(margin, 4)) then
			return p
		end
	end
	return nil
end

-- Calls make(p) at up to `count` clear spots, claiming `room` around each so they don't pile up.
local function scatter(island, rng, count, inner, outer, margin, room, make, y)
	for _ = 1, count do
		local p = spot(island, rng, inner, outer, margin, y)
		if p then
			claim(p, room)
			make(p)
		end
	end
end

-- Shared props ---------------------------------------------------------------------------------------------------

-- Chunky rock of two tilted blocks; big ones are solid.
local function boulder(parent, base, rng, size, color, capColor)
	local make = size >= 2.5 and part or decor
	local cf = CFrame.new(base + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), rng:NextNumber(-0.15, 0.15))
	make({ Name = "Rock", Size = Vector3.new(size * 1.3, size * 0.9, size), CFrame = cf, Color = color, Parent = parent })
	make({ Name = "Rock", Size = Vector3.new(size * 0.8, size * 0.7, size * 0.75), CFrame = cf * CFrame.new(size * 0.35, size * 0.4, -size * 0.1) * CFrame.Angles(0, 0.6, 0.2), Color = color:Lerp(Color3.new(0, 0, 0), 0.12), Parent = parent })
	if capColor then
		decor({ Name = "RockMoss", Size = Vector3.new(size * 1.1, 0.4, size * 0.8), CFrame = cf * CFrame.new(-size * 0.1, size * 0.45 + 0.1, 0), Color = capColor, CastShadow = false, Parent = parent })
	end
end

-- Bright chunky coral, like the reference video's reefs: a stubby trunk with blocky branches and knobs.
local function coral(parent, base, rng, scale, color)
	scale = scale or 1
	color = color or CORAL[rng:NextInteger(1, #CORAL)]
	local h = rng:NextNumber(2, 3.2) * scale
	decor({ Name = "Coral", Size = Vector3.new(1.5 * scale, h, 1.5 * scale), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = color, Parent = parent })
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, rng:NextInteger(2, 3) do
		local a = turn + i * 2.1
		local bh = rng:NextNumber(1.6, 3) * scale
		local foot = base + Vector3.new(math.cos(a) * 0.6 * scale, h * rng:NextNumber(0.4, 0.8), math.sin(a) * 0.6 * scale)
		-- yaw so local X points out along `a`, then tip the branch's up axis outward
		local branch = CFrame.new(foot) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -rng:NextNumber(0.35, 0.7)) * CFrame.new(0, bh / 2, 0)
		decor({ Name = "CoralBranch", Size = Vector3.new(1.1 * scale, bh, 1.1 * scale), CFrame = branch, Color = color, Parent = parent })
		decor({ Name = "CoralKnob", Size = Vector3.new(1.5, 1.2, 1.5) * scale, CFrame = branch * CFrame.new(0, bh / 2 + 0.3 * scale, 0) * CFrame.Angles(0, math.rad(45), 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.25), CastShadow = false, Parent = parent })
	end
end

-- Dead white-grey tree: a leaning trunk and bare branches.
local function deadTree(parent, base, rng, scale, color)
	scale = scale or 1
	color = color or DEAD
	local h = rng:NextNumber(7, 11) * scale
	local trunk = CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.12, 0.12))
	part({ Name = "DeadTrunk", Size = Vector3.new(1.4 * scale, h, 1.4 * scale), CFrame = trunk * CFrame.new(0, h / 2 - 0.3, 0), Color = color, Parent = parent })
	decor({ Name = "DeadRoot", Size = Vector3.new(2.6, 0.8, 2.6) * scale, CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = color:Lerp(DEAD_DARK, 0.6), Parent = parent })
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, rng:NextInteger(2, 4) do
		local from = (trunk * CFrame.new(0, h * rng:NextNumber(0.45, 0.95), 0)).Position
		local a = turn + i * 2.3
		local len = rng:NextNumber(2.5, 4.5) * scale
		local tip = from + Vector3.new(math.cos(a) * len, len * rng:NextNumber(0.3, 0.9), math.sin(a) * len)
		rod(parent, from, tip, 0.45 * scale, i % 2 == 0 and color or color:Lerp(DEAD_DARK, 0.5))
		if rng:NextNumber() < 0.5 then
			rod(parent, tip, tip + Vector3.new(math.cos(a + 0.8) * 1.5, 1.2, math.sin(a + 0.8) * 1.5) * scale, 0.3 * scale, color)
		end
	end
end

-- Snapped mooring post, sometimes with a fallen plank beside it.
local function brokenPost(parent, base, rng)
	local h = rng:NextNumber(2.5, 5)
	decor({ Name = "BrokenPost", Size = Vector3.new(0.9, h, 0.9), CFrame = CFrame.new(base + Vector3.new(0, h / 2 - 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25)), Color = rng:NextNumber() < 0.5 and WOOD_DARK or DEAD_DARK, Parent = parent })
	if rng:NextNumber() < 0.5 then
		decor({ Name = "FallenPlank", Size = Vector3.new(0.9, 0.3, rng:NextNumber(3, 5)), CFrame = CFrame.new(base + Vector3.new(1.2, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.1), Color = WOOD_DARK, Parent = parent })
	end
end

-- Voxel palm: a curving trunk of blocks and drooping frond slabs.
local function palm(parent, base, rng, scale)
	scale = scale or 1
	local a = rng:NextNumber(0, math.pi * 2)
	local bend = Vector3.new(math.cos(a), 0, math.sin(a))
	local pos = base
	for i = 1, 5 do
		local nextPos = pos + Vector3.new(0, 2.6 * scale, 0) + bend * (0.2 + i * 0.22) * scale
		local w = (1.7 - i * 0.1) * scale
		decor({ Name = "PalmTrunk", Size = Vector3.new(w, w, (nextPos - pos).Magnitude + 0.3), CFrame = CFrame.lookAt((pos + nextPos) / 2, nextPos), Color = i % 2 == 0 and Color3.fromRGB(150, 112, 74) or Color3.fromRGB(124, 92, 62), Parent = parent })
		pos = nextPos
	end
	decor({ Name = "PalmHeart", Size = Vector3.new(1.8, 1.2, 1.8) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color = PALM[3], Parent = parent })
	for i = 1, 6 do
		local fa = i / 6 * math.pi * 2 + a
		local tip = pos + Vector3.new(math.cos(fa) * 5.6, -1.8, math.sin(fa) * 5.6) * scale
		windy(decor({ Name = "PalmFrond", Size = Vector3.new(1.8 * scale, 0.4, (tip - pos).Magnitude), CFrame = CFrame.lookAt((pos + tip) / 2 + Vector3.new(0, 0.5, 0), tip + Vector3.new(0, 0.5, 0)), Color = PALM[(i % #PALM) + 1], CastShadow = false, Parent = parent }))
	end
	for i = 1, 2 do
		decor({ Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9) * scale, CFrame = CFrame.new(pos + Vector3.new(math.cos(a + i * 2.6) * 0.8, -0.6, math.sin(a + i * 2.6) * 0.8) * scale), Color = Color3.fromRGB(110, 76, 50), Parent = parent })
	end
end

-- Warm lantern on a post, lit.
local function lantern(parent, base, height, color)
	height = height or 6
	color = color or WARM
	decor({ Name = "LanternPost", Size = Vector3.new(0.7, height, 0.7), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)), Color = WOOD_DARK, Parent = parent })
	local glow = decor({ Name = "Lantern", Size = Vector3.new(1.1, 1.4, 1.1), CFrame = CFrame.new(base + Vector3.new(0, height + 0.7, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = color, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	decor({ Name = "LanternCap", Size = Vector3.new(1.6, 0.4, 1.6), CFrame = CFrame.new(base + Vector3.new(0, height + 1.6, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = WOOD_DARK, Parent = parent })
	light(glow, color, 14, 1)
	return glow
end

-- Lantern hanging on a short line from `from`.
local function hangingLantern(parent, from, length, color)
	color = color or WARM
	local bottom = from - Vector3.new(0, length, 0)
	rod(parent, from, bottom, 0.15, IRON)
	decor({ Name = "LanternCap", Size = Vector3.new(1, 0.3, 1), CFrame = CFrame.new(bottom), Color = IRON, Parent = parent })
	local glow = decor({ Name = "Lantern", Size = Vector3.new(0.8, 1.1, 0.8), CFrame = CFrame.new(bottom - Vector3.new(0, 0.7, 0)), Color = color, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	light(glow, color, 12, 0.9)
	return glow
end

local function barrel(parent, base)
	local cf = CFrame.new(base + Vector3.new(0, 1.5, 0))
	part({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.4, 2.4), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(140, 92, 58), Parent = parent })
	for _, y in ipairs({ -0.9, 0.9 }) do
		decor({ Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.55, 2.55), CFrame = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, CastShadow = false, Parent = parent })
	end
end

local function crate(parent, base, rng, lift)
	K.crate(parent, CFrame.new(base + Vector3.new(0, 1.3 + (lift or 0), 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0))
end

-- Chunky grass tuft in the ring's colours.
local function tuft(parent, base, rng, ring)
	local colors = ring == 3 and GRASS_3 or (ring == 2 and GRASS_2 or GRASS_1)
	D.tuft(parent, base, rng, colors[1], colors[2])
end

-- Thin sand patch on the ground (beaches under turtles, boats and palms).
local function sandPatch(parent, center, radius)
	local p = disk(parent, "Sand", Vector3.new(center.X, TOP + 0.03, center.Z), radius, 0.1, SAND)
	p.CanCollide = false
	p.CastShadow = false
	return p
end

local function lilyPad(parent, p, rng, flower)
	decor({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.6, 2.6) * rng:NextNumber(0.8, 1.3), CFrame = CFrame.new(p.X, WATER_Y + 0.08, p.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(92, 186, 84), CastShadow = false, Parent = parent })
	if flower then
		decor({ Name = "Lotus", Size = Vector3.new(0.8, 0.6, 0.8), CFrame = CFrame.new(p.X, WATER_Y + 0.45, p.Z) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(255, 160, 210), CastShadow = false, Parent = parent })
	end
end

-- Supporting detail in the island's ring style: `big` trees or rocks toward the rim and `small` tufts or
-- flowers anywhere, all clear of gameplay.
local function fill(parent, island, rng, big, small)
	local ring = island.ring or 1
	local r = island.r
	scatter(island, rng, big, r * 0.45, r - 5, 7, 3, function(p)
		local roll = rng:NextNumber()
		if ring == 1 then
			if roll < 0.55 then
				K.canopyTree(parent, p, rng)
			else
				for i = 1, 3 do
					K.mintRock(parent, p + Vector3.new(i * 1.6 - 3, -0.3, rng:NextNumber(-1.5, 1.5)), rng, 1.1)
				end
			end
		elseif ring == 2 then
			if roll < 0.6 then
				D.blockTree(parent, p, rng, rng:NextNumber(0.8, 1.1))
			else
				coral(parent, p, rng, rng:NextNumber(1.2, 1.6))
			end
		else
			if roll < 0.45 then
				deadTree(parent, p, rng, rng:NextNumber(0.8, 1.2))
			elseif roll < 0.8 then
				boulder(parent, p, rng, rng:NextNumber(2.5, 4.5), roll < 0.6 and DARK or DARKER, MOSS)
			else
				brokenPost(parent, p, rng)
			end
		end
	end)
	scatter(island, rng, small, 4, r - 3, 3, 1, function(p)
		local roll = rng:NextNumber()
		if ring == 1 and roll < 0.3 then
			K.daisies(parent, p + Vector3.new(0, 0.2, 0), rng)
		elseif ring == 1 and roll < 0.45 then
			K.flowerTuft(parent, p, rng)
		elseif ring == 3 and roll < 0.25 then
			boulder(parent, p, rng, rng:NextNumber(0.8, 1.6), DARK)
		else
			tuft(parent, p, rng, ring)
		end
	end)
end

-- Placement helpers for set pieces ---------------------------------------------------------------------------------

-- Offsets from an island's centre in a ring: `count` points `distance` out, starting at `from` degrees.
local function around(distance, from, step, count)
	local list = {}
	for i = 0, count - 1 do
		local a = math.rad(from + i * step)
		table.insert(list, { math.cos(a) * distance, math.sin(a) * distance })
	end
	return list
end

-- The first candidate offset that is clear of gameplay and on land; claims `room` there.
local function heroSpot(island, candidates, margin, room)
	for _, c in ipairs(candidates) do
		local p = at(island, c[1], c[2])
		if clear(p, margin) and onIsland(p, math.min(room * 0.5, 6)) then
			claim(p, room)
			return p
		end
	end
	return nil
end

-- The first candidate offset out in the water and clear; claims `room` there.
local function waterSpot(island, candidates, margin, room)
	for _, c in ipairs(candidates) do
		local p = at(island, c[1], c[2], WATER_Y)
		if clear(p, margin) and inWater(island, p) then
			claim(p, room)
			return p
		end
	end
	return nil
end

-- The wild egg nest on this island (at its walk height), if it has one.
local function nestOn(island, index)
	local found = 0
	for _, nest in ipairs(L.eggNests) do
		if (flat(nest.at) - flat(island.pos)).Magnitude <= island.r then
			found += 1
			if found == (index or 1) then
				return Vector3.new(nest.at.X, nest.y or TOP, nest.at.Z)
			end
		end
	end
	return nil
end

local function outward(island, p)
	local d = flat(p) - flat(island.pos)
	return d.Magnitude > 0.01 and d.Unit or Vector3.new(1, 0, 0)
end

-- More palette for the set pieces
local SHELL = Color3.fromRGB(104, 140, 84)
local SHELL_DARK = Color3.fromRGB(70, 104, 66)
local SKIN = Color3.fromRGB(150, 190, 118)
local SANDSTONE = Color3.fromRGB(206, 162, 118)
local SANDSTONE_DARK = Color3.fromRGB(170, 126, 92)
local KELP = { Color3.fromRGB(92, 140, 52), Color3.fromRGB(64, 108, 40), Color3.fromRGB(146, 190, 72) }
local MANGROVE_LEAF = { Color3.fromRGB(46, 128, 62), Color3.fromRGB(62, 150, 70), Color3.fromRGB(38, 110, 58) }
local CLAM = Color3.fromRGB(116, 146, 222)
local CLAM_DARK = Color3.fromRGB(86, 108, 184)
local CLAM_LIP = Color3.fromRGB(255, 150, 204)
local PEARL = Color3.fromRGB(255, 238, 250)
local STORM_GLOW = Color3.fromRGB(120, 210, 255)
local GULL_WHITE = Color3.fromRGB(242, 242, 238)
local GULL_GREY = Color3.fromRGB(168, 174, 186)
local BEAK = Color3.fromRGB(255, 170, 40)
local BRASS = Color3.fromRGB(206, 162, 74)
local THRONE = Color3.fromRGB(214, 150, 170)
local THRONE_DARK = Color3.fromRGB(168, 110, 138)
local SIGN_DARK = Color3.fromRGB(20, 16, 34)
local BLACK = Color3.fromRGB(26, 24, 28)

-- Set-piece props ---------------------------------------------------------------------------------------------

-- Stone lantern (a toro); at scale 2.5 it is one of the Twin Reefs' lantern towers.
local function stoneLantern(parent, base, scale)
	local s = scale or 1
	part({ Name = "LanternBase", Size = Vector3.new(2.4, 0.8, 2.4) * s, CFrame = CFrame.new(base + Vector3.new(0, 0.4 * s, 0)), Color = STONE_DARK, Parent = parent })
	part({ Name = "LanternPost", Size = Vector3.new(1, 2.8, 1) * s, CFrame = CFrame.new(base + Vector3.new(0, 2.2 * s, 0)), Color = STONE, Parent = parent })
	decor({ Name = "LanternCollar", Size = Vector3.new(2, 0.5, 2) * s, CFrame = CFrame.new(base + Vector3.new(0, 3.75 * s, 0)), Color = STONE_DARK, Parent = parent })
	for _, x in ipairs({ -0.75, 0.75 }) do
		for _, z in ipairs({ -0.75, 0.75 }) do
			decor({ Name = "LanternCorner", Size = Vector3.new(0.4, 1.6, 0.4) * s, CFrame = CFrame.new(base + Vector3.new(x, 4.8, z) * s), Color = STONE, Parent = parent })
		end
	end
	local glow = decor({ Name = "LanternLight", Size = Vector3.new(1.2, 1.2, 1.2) * s, CFrame = CFrame.new(base + Vector3.new(0, 4.8 * s, 0)), Color = WARM, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	light(glow, WARM, 10 + s * 6, 1)
	decor({ Name = "LanternRoof", Size = Vector3.new(3, 0.6, 3) * s, CFrame = CFrame.new(base + Vector3.new(0, 5.9 * s, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = STONE_DARK, Parent = parent })
	decor({ Name = "LanternRoof", Size = Vector3.new(1.8, 0.5, 1.8) * s, CFrame = CFrame.new(base + Vector3.new(0, 6.4 * s, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = STONE_DARK, Parent = parent })
	decor({ Name = "LanternFinial", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8) * s, CFrame = CFrame.new(base + Vector3.new(0, 6.9 * s, 0)), Color = STONE, Parent = parent })
	return glow
end

-- A sign board on two posts: a dark panel with glowing text on both faces.
local function signBoard(parent, base, facing, text, width, height, color)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	for _, x in ipairs({ -width / 2 + 0.4, width / 2 - 0.4 }) do
		part({ Name = "SignPost", Size = Vector3.new(0.8, height + 3, 0.8), CFrame = cf * CFrame.new(x, (height + 3) / 2, 0), Color = WOOD_DARK, Parent = parent })
	end
	local board = part({ Name = "SignBoard", Size = Vector3.new(width, height, 0.5), CFrame = cf * CFrame.new(0, 2.4 + height / 2, 0), Color = SIGN_DARK, Parent = parent })
	decor({ Name = "SignRoof", Size = Vector3.new(width + 1, 0.5, 1.4), CFrame = cf * CFrame.new(0, 2.7 + height, 0), Color = WOOD_DARK, Parent = parent })
	K.surfaceText(board, text, color or SKY_TEXT, Enum.NormalId.Front)
	K.surfaceText(board, text, color or SKY_TEXT, Enum.NormalId.Back)
	return board
end

local function seaTurtle(parent, base, facing, s)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	local solid = s >= 0.8 and part or decor
	solid({ Name = "TurtleShell", Size = Vector3.new(7, 2, 9) * s, CFrame = cf * CFrame.new(0, 1.3 * s, 0), Color = SHELL_DARK, Parent = parent })
	solid({ Name = "TurtleShell", Size = Vector3.new(5.6, 1.6, 7.4) * s, CFrame = cf * CFrame.new(0, 3 * s, 0.2 * s), Color = SHELL, Parent = parent })
	decor({ Name = "TurtleShellTop", Size = Vector3.new(3.6, 1, 5) * s, CFrame = cf * CFrame.new(0, 4.1 * s, 0.3 * s), Color = SHELL:Lerp(Color3.new(1, 1, 1), 0.15), Parent = parent })
	decor({ Name = "TurtleRim", Size = Vector3.new(7.4, 0.5, 9.4) * s, CFrame = cf * CFrame.new(0, 2.1 * s, 0), Color = Color3.fromRGB(214, 190, 126), Parent = parent })
	for _, p in ipairs({ { -1.5, -1.8 }, { 1.5, -1.8 }, { 0, 1.2 }, { -1.6, 2.6 }, { 1.6, 2.6 } }) do
		decor({ Name = "ShellPlate", Size = Vector3.new(1.8, 0.4, 1.8) * s, CFrame = cf * CFrame.new(p[1] * s, 3.85 * s, p[2] * s) * CFrame.Angles(0, math.rad(45), 0), Color = SHELL_DARK, Parent = parent })
	end
	decor({ Name = "TurtleNeck", Size = Vector3.new(1.8, 1.6, 2) * s, CFrame = cf * CFrame.new(0, 1.5 * s, -4.8 * s), Color = SKIN, Parent = parent })
	local head = cf * CFrame.new(0, 2 * s, -6.4 * s)
	decor({ Name = "TurtleHead", Size = Vector3.new(2.4, 2, 2.8) * s, CFrame = head, Color = SKIN, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "TurtleEye", Size = Vector3.new(0.5, 0.6, 0.5) * s, CFrame = head * CFrame.new(side * 1.05 * s, 0.35 * s, -0.9 * s), Color = BLACK, Parent = parent })
		decor({ Name = "Flipper", Size = Vector3.new(4.2, 0.5, 2) * s, CFrame = cf * CFrame.new(side * 4.6 * s, 0.5 * s, -2.4 * s) * CFrame.Angles(0, side * 0.45, side * -0.12), Color = SKIN, Parent = parent })
		decor({ Name = "RearFlipper", Size = Vector3.new(2.6, 0.5, 1.6) * s, CFrame = cf * CFrame.new(side * 3.7 * s, 0.4 * s, 3.8 * s) * CFrame.Angles(0, side * -0.5, 0), Color = SKIN, Parent = parent })
	end
	decor({ Name = "TurtleTail", Size = Vector3.new(0.8, 0.6, 1.6) * s, CFrame = cf * CFrame.new(0, 0.8 * s, 5.2 * s), Color = SKIN, Parent = parent })
end

-- A tall kelp column standing up out of the shallows, its top half swaying.
local function kelpColumn(parent, base, height, rng)
	local x, z, y = base.X, base.Z, base.Y
	local seg = 3
	local i = 0
	while y < base.Y + height do
		i += 1
		x += rng:NextNumber(-0.35, 0.35)
		z += rng:NextNumber(-0.35, 0.35)
		local stalk = decor({ Name = "Kelp", Size = Vector3.new(1.3, seg + 0.2, 1.3), CFrame = CFrame.new(x, y + seg / 2, z) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), rng:NextNumber(0, 3), rng:NextNumber(-0.06, 0.06)), Color = KELP[(i % 2) + 1], Parent = parent })
		if y > WATER_Y then
			windy(stalk)
		end
		if i % 2 == 0 then
			local a = rng:NextNumber(0, math.pi * 2)
			local leaf = decor({ Name = "KelpLeaf", Size = Vector3.new(2.6, 0.2, 1.2), CFrame = CFrame.new(x + math.cos(a) * 1.4, y + seg * 0.6, z + math.sin(a) * 1.4) * CFrame.Angles(0, -a, 0.35), Color = KELP[3], CastShadow = false, Parent = parent })
			if y > WATER_Y then
				windy(leaf)
			end
		end
		y += seg
	end
	decor({ Name = "KelpBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(x, y + 0.5, z), Color = Color3.fromRGB(196, 196, 74), Parent = parent })
end

-- Mangrove: a trunk lifted on arching roots that reach furthest toward the water.
local function mangrove(parent, base, out, rng)
	local hub = base + Vector3.new(0, 4.5, 0)
	local h = rng:NextNumber(7, 10)
	decor({ Name = "MangroveTrunk", Size = Vector3.new(1.8, h, 1.8), CFrame = CFrame.new(hub + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 3), rng:NextNumber(-0.08, 0.08)), Color = ROOT, Parent = parent })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local reach = rng:NextNumber(3.5, 5) + math.max(0, dir:Dot(out)) * 5
		local knee = hub + dir * reach * 0.5 + Vector3.new(0, 1.4, 0)
		local foot = Vector3.new(base.X, TOP - 2, base.Z) + dir * reach
		rod(parent, hub + Vector3.new(0, 0.8, 0), knee, 0.7, ROOT)
		rod(parent, knee, foot, 0.6, ROOT)
	end
	local crown = hub + Vector3.new(0, h, 0)
	for _ = 1, 5 do
		local s = rng:NextNumber(6, 9)
		windy(decor({ Name = "MangroveLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 1.3, s * 0.55, s), CFrame = CFrame.new(crown + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-0.5, 2), rng:NextNumber(-4, 4))), Color = MANGROVE_LEAF[rng:NextInteger(1, #MANGROVE_LEAF)], Parent = parent }))
	end
	for _ = 1, 3 do
		local from = crown + Vector3.new(rng:NextNumber(-4, 4), -1, rng:NextNumber(-4, 4))
		rod(parent, from, Vector3.new(from.X, TOP - 0.5, from.Z), 0.25, ROOT)
	end
end

-- Roots arching over a nest, meeting in a leafy knot above it.
local function rootCage(parent, center, rng)
	local top = center + Vector3.new(0, 7.5, 0)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local foot = center + dir * 5.6 - Vector3.new(0, 0.3, 0)
		local knee = center + dir * 4.4 + Vector3.new(0, 4.6, 0)
		rod(parent, foot, knee, 0.7, ROOT)
		rod(parent, knee, top + dir * 0.8, 0.6, ROOT)
	end
	windy(decor({ Name = "MangroveLeaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 4, 8), CFrame = CFrame.new(top + Vector3.new(0, 1.6, 0)), Color = MANGROVE_LEAF[2], Parent = parent }))
end

local function rowboat(parent, base, yaw, color)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	decor({ Name = "BoatBottom", Size = Vector3.new(3.4, 0.6, 7), CFrame = cf * CFrame.new(0, 0.3, 0), Color = WOOD_DARK, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "BoatSide", Size = Vector3.new(0.5, 1.3, 7), CFrame = cf * CFrame.new(side * 1.7, 0.95, 0), Color = color or WOOD, Parent = parent })
		decor({ Name = "BoatBow", Size = Vector3.new(0.5, 1.3, 2.4), CFrame = cf * CFrame.new(side * 0.85, 0.95, -4.2) * CFrame.Angles(0, side * math.rad(-38), 0), Color = color or WOOD, Parent = parent })
		rod(parent, (cf * CFrame.new(side * 1.2, 1.4, 0.6)).Position, (cf * CFrame.new(side * 3.2, 0.2, 2.6)).Position, 0.25, WOOD)
	end
	decor({ Name = "BoatStern", Size = Vector3.new(3.4, 1.3, 0.5), CFrame = cf * CFrame.new(0, 0.95, 3.6), Color = color or WOOD, Parent = parent })
	decor({ Name = "BoatSeat", Size = Vector3.new(3, 0.3, 1), CFrame = cf * CFrame.new(0, 1.2, 0.4), Color = WOOD_DARK, Parent = parent })
end

-- A small hull half sunk offshore, bow first.
local function sunkenWreck(parent, base, yaw)
	local model = Instance.new("Model")
	model.Name = "SunkenWreck"
	model.Parent = parent
	local cf = CFrame.new(base.X, WATER_Y - 1.5, base.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(-24))
	part({ Name = "Keel", Size = Vector3.new(6, 1.6, 20), CFrame = cf, Color = DP.HULL_DARK, Material = Enum.Material.WoodPlanks, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		for i = -2, 2 do
			if not (side == -1 and i == 1) then
				part({ Name = "HullPlank", Size = Vector3.new(0.9, 5, 4), CFrame = cf * CFrame.new(side * 3.2, 2.4, i * 4), Color = (i % 2 == 0) and DP.HULL or DP.HULL_DARK, Material = Enum.Material.WoodPlanks, Parent = model })
			end
		end
	end
	part({ Name = "Stern", Size = Vector3.new(7, 6, 1), CFrame = cf * CFrame.new(0, 2.8, 10), Color = DP.HULL_DARK, Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "SternDeck", Size = Vector3.new(7, 1, 5), CFrame = cf * CFrame.new(0, 5.5, 7.6), Color = DP.HULL, Material = Enum.Material.WoodPlanks, Parent = model })
	decor({ Name = "BrokenMast", Size = Vector3.new(1, 11, 1), CFrame = cf * CFrame.new(0, 6, -1) * CFrame.Angles(0.3, 0, 0.2), Color = DP.HULL_DARK, Parent = model })
	windy(decor({ Name = "TornSail", Size = Vector3.new(0.2, 4, 6), CFrame = cf * CFrame.new(0.4, 8.5, -2.4) * CFrame.Angles(0.3, 0, 0.2), Color = DP.SAIL, Parent = model }))
end

local function cannon(parent, base, facing)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	part({ Name = "CannonCarriage", Size = Vector3.new(2.4, 1.2, 3.4), CFrame = cf * CFrame.new(0, 1.1, 0), Color = WOOD_DARK, Parent = parent })
	for _, x in ipairs({ -1.4, 1.4 }) do
		for _, z in ipairs({ -1.1, 1.1 }) do
			decor({ Name = "CannonWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.6, 1.6), CFrame = cf * CFrame.new(x, 0.8, z), Color = WOOD, Parent = parent })
		end
	end
	decor({ Name = "CannonBarrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.6, 1.2, 1.2), CFrame = cf * CFrame.new(0, 2.1, -0.6) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(10)), Color = IRON, Parent = parent })
	decor({ Name = "CannonMuzzle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.5, 1.5), CFrame = cf * CFrame.new(0, 2.5, -2.8) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(10)), Color = IRON, Parent = parent })
	for _, p in ipairs({ { -0.6, 2.6 }, { 0.6, 2.6 }, { 0, 3.5 } }) do
		decor({ Name = "Cannonball", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = cf * CFrame.new(p[1] + 2.2, 0.45, p[2] - 2), Color = IRON, Parent = parent })
	end
end

local function treasurePile(parent, base, rng)
	local heap = nil
	for _ = 1, 9 do
		local s = rng:NextNumber(0.9, 1.8)
		local off = Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
		local lift = math.max(0.3, (2.2 - off.Magnitude * 0.6) * 0.5)
		heap = decor({ Name = "GoldPile", Size = Vector3.new(s, s * 0.6, s), CFrame = CFrame.new(base + off + Vector3.new(0, lift, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = GOLD, Reflectance = 0.2, Parent = parent })
	end
	for i, color in ipairs({ Color3.fromRGB(255, 60, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(80, 230, 120), Color3.fromRGB(190, 90, 255) }) do
		local a = i * 1.7
		decor({ Name = "Gem", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 1.2, 1.3, math.sin(a) * 1.2)) * CFrame.Angles(0.6, a, 0.6), Color = color, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	end
	local chest = CFrame.new(base + Vector3.new(2.6, 1, 0.4)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
	part({ Name = "Chest", Size = Vector3.new(3, 2, 2), CFrame = chest, Color = DP.HULL, Parent = parent })
	decor({ Name = "ChestBand", Size = Vector3.new(3.1, 0.3, 2.1), CFrame = chest * CFrame.new(0, 0.4, 0), Color = GOLD, Parent = parent })
	decor({ Name = "ChestLid", Size = Vector3.new(3.2, 0.6, 2.2), CFrame = chest * CFrame.new(0, 1.3, 1) * CFrame.Angles(math.rad(60), 0, 0), Color = DP.HULL_DARK, Parent = parent })
	local glow = decor({ Name = "ChestGold", Size = Vector3.new(2.6, 0.4, 1.6), CFrame = chest * CFrame.new(0, 1.05, 0), Color = GOLD, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	light(glow, GOLD, 12, 0.9)
	if heap then
		K.sparkles(heap, GOLD, 4)
	end
end

local function skeleton(parent, base, rng)
	local cf = CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local skull = cf * CFrame.new(0, 0.6, -2.6)
	decor({ Name = "Skull", Size = Vector3.new(1.2, 1.1, 1.3), CFrame = skull, Color = BONE, Parent = parent })
	for _, x in ipairs({ -0.3, 0.3 }) do
		decor({ Name = "EyeSocket", Size = Vector3.new(0.35, 0.35, 0.1), CFrame = skull * CFrame.new(x, 0.1, -0.66), Color = BLACK, Parent = parent })
	end
	decor({ Name = "Jaw", Size = Vector3.new(0.9, 0.3, 0.8), CFrame = skull * CFrame.new(0, -0.6, -0.3), Color = BONE, Parent = parent })
	decor({ Name = "Spine", Size = Vector3.new(0.4, 0.4, 3), CFrame = cf * CFrame.new(0, 0.25, -0.6), Color = BONE, Parent = parent })
	for k = 0, 2 do
		decor({ Name = "Rib", Size = Vector3.new(2, 0.25, 0.3), CFrame = cf * CFrame.new(0, 0.45, -1.6 + k * 0.55), Color = BONE, Parent = parent })
	end
	for _, side in ipairs({ -1, 1 }) do
		rod(parent, (cf * CFrame.new(side * 0.9, 0.2, -1.6)).Position, (cf * CFrame.new(side * 2.2, 0.2, -0.2)).Position, 0.3, BONE)
		rod(parent, (cf * CFrame.new(side * 0.4, 0.2, 0.9)).Position, (cf * CFrame.new(side * 0.8, 0.2, 3.2)).Position, 0.35, BONE)
	end
	decor({ Name = "PirateHat", Size = Vector3.new(1.8, 0.4, 1.2), CFrame = cf * CFrame.new(1, 0.25, -3.8) * CFrame.Angles(0, 0.4, 0.1), Color = BLACK, Parent = parent })
	decor({ Name = "HatBand", Size = Vector3.new(1.1, 0.5, 0.8), CFrame = cf * CFrame.new(1, 0.55, -3.8) * CFrame.Angles(0, 0.4, 0.1), Color = GOLD, Parent = parent })
end

local function pirateFlag(parent, base)
	part({ Name = "FlagPole", Size = Vector3.new(0.6, 16, 0.6), CFrame = CFrame.new(base + Vector3.new(0, 8, 0)), Color = WOOD_DARK, Parent = parent })
	local flag = CFrame.new(base + Vector3.new(0, 14, 3.2))
	windy(decor({ Name = "Flag", Size = Vector3.new(0.2, 4, 6), CFrame = flag, Color = BLACK, Parent = parent }))
	for _, x in ipairs({ -0.2, 0.2 }) do
		decor({ Name = "FlagSkull", Size = Vector3.new(0.1, 1.3, 1.3), CFrame = flag * CFrame.new(x, 0.5, 0), Color = GULL_WHITE, Parent = parent })
		for _, a in ipairs({ -45, 45 }) do
			decor({ Name = "FlagBone", Size = Vector3.new(0.1, 0.35, 2.6), CFrame = flag * CFrame.new(x, -0.8, 0) * CFrame.Angles(math.rad(a), 0, 0), Color = GULL_WHITE, Parent = parent })
		end
	end
end

-- Stacked coral blocks along a half-ellipse from foot `a` to foot `b`, `rise` studs high.
local function coralArch(parent, a, b, rise, rng)
	local fa, fb = Vector3.new(a.X, TOP, a.Z), Vector3.new(b.X, TOP, b.Z)
	local mid = (fa + fb) / 2
	local half = (fb - fa).Magnitude / 2
	local dir = (fb - fa).Unit
	local c1 = CORAL[rng:NextInteger(1, #CORAL)]
	local c2 = CORAL[rng:NextInteger(1, #CORAL)]
	for _, foot in ipairs({ fa, fb }) do
		part({ Name = "ArchFoot", Size = Vector3.new(4.4, 3, 4.4), CFrame = CFrame.new(foot + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = c1:Lerp(Color3.new(0, 0, 0), 0.15), Parent = parent })
	end
	local n = 12
	for k = 0, n do
		local t = k / n * math.pi
		local s = 3.4 - 1.1 * math.sin(t)
		local p = mid - dir * half * math.cos(t) + Vector3.new(0, rise * math.sin(t) + s * 0.4, 0)
		local make = (k <= 1 or k >= n - 1) and part or decor
		make({ Name = "CoralArch", Size = Vector3.new(s, s, s), CFrame = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 1.5), rng:NextNumber(-0.3, 0.3)), Color = (k % 2 == 0) and c1 or c2, Parent = parent })
		if k % 3 == 1 then
			decor({ Name = "CoralKnob", Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(p + Vector3.new(0, s * 0.6, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = c2:Lerp(Color3.new(1, 1, 1), 0.3), CastShadow = false, Parent = parent })
		end
	end
end

-- A flat fan of thin coral rods.
local function seaFan(parent, base, rng, color)
	local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	for i = -3, 3 do
		local tip = base + (turn * CFrame.Angles(0, 0, i * 0.28)).UpVector * rng:NextNumber(3.5, 5)
		rod(parent, base, tip, 0.3, color)
	end
end

-- A sandstone stack of chunky blocks, narrowing as it rises; returns the top's height.
local function seaStack(parent, base, height, rng)
	local y = TOP - 1
	local w = rng:NextNumber(7, 9)
	local i = 0
	while y < TOP + height do
		i += 1
		local h = rng:NextNumber(3, 4.5)
		part({ Name = "SeaStack", Size = Vector3.new(w, h, w * rng:NextNumber(0.85, 1.1)), CFrame = CFrame.new(base.X + rng:NextNumber(-0.5, 0.5), y + h / 2, base.Z + rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = (i % 2 == 0) and SANDSTONE or SANDSTONE_DARK, Parent = parent })
		y += h - 0.2
		w = math.max(3, w - rng:NextNumber(0.3, 0.9))
	end
	decor({ Name = "StackGrass", Size = Vector3.new(w + 0.6, 0.5, w + 0.6), CFrame = CFrame.new(base.X, y + 0.1, base.Z), Color = GRASS_2[1], Parent = parent })
	return Vector3.new(base.X, y + 0.35, base.Z)
end

local function gullNest(parent, base)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		decor({ Name = "NestTwig", Size = Vector3.new(0.3, 0.4, 1.6), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 0.9, 0.2, math.sin(a) * 0.9)) * CFrame.Angles(0, -a, 0.3), Color = Color3.fromRGB(150, 110, 66), Parent = parent })
	end
	for _, x in ipairs({ -0.3, 0.35 }) do
		K.eggShape(parent, "GullEgg", CFrame.new(base + Vector3.new(x, 0.45, x * 0.5)), Vector3.new(0.6, 0.8, 0.6), Color3.fromRGB(236, 232, 214))
	end
end

local function perchedGull(parent, base, facing)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	decor({ Name = "GullBody", Size = Vector3.new(1.3, 1.1, 2.2), CFrame = cf * CFrame.new(0, 1.1, 0), Color = GULL_WHITE, Parent = parent })
	decor({ Name = "GullHead", Size = Vector3.new(0.9, 0.9, 0.9), CFrame = cf * CFrame.new(0, 1.9, -1), Color = GULL_WHITE, Parent = parent })
	decor({ Name = "GullBeak", Size = Vector3.new(0.3, 0.3, 0.8), CFrame = cf * CFrame.new(0, 1.8, -1.8), Color = BEAK, Parent = parent })
	decor({ Name = "GullTail", Size = Vector3.new(0.9, 0.2, 0.9), CFrame = cf * CFrame.new(0, 1.3, 1.4), Color = GULL_GREY, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "GullWing", Size = Vector3.new(0.2, 0.8, 2), CFrame = cf * CFrame.new(side * 0.72, 1.2, 0.2), Color = GULL_GREY, Parent = parent })
		decor({ Name = "GullLeg", Size = Vector3.new(0.15, 0.6, 0.15), CFrame = cf * CFrame.new(side * 0.3, 0.3, 0), Color = BEAK, Parent = parent })
	end
end

local function mintSpire(parent, base, height, rng)
	local y = TOP - 1
	local w = rng:NextNumber(5, 7)
	local tilt = rng:NextNumber(-0.12, 0.12)
	local k = 0
	while y < TOP + height do
		k += 1
		local h = rng:NextNumber(4, 6)
		part({ Name = "MintSpire", Size = Vector3.new(w, h + 0.5, w * 0.8), CFrame = CFrame.new(base.X + tilt * (y - TOP), y + h / 2, base.Z) * CFrame.Angles(tilt, rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), Color = (k % 2 == 0) and MINT or MINT_DARK, Parent = parent })
		y += h
		w = math.max(1.4, w * 0.78)
	end
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2) + i * 2
		decor({ Name = "Shard", Size = Vector3.new(0.8, rng:NextNumber(1.6, 3), 0.8), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 3.6, 0.8, math.sin(a) * 3.6)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)), Color = P.CRYSTAL, Material = Enum.Material.Neon, Transparency = 0.15, CastShadow = false, Parent = parent })
	end
end

local function coralThrone(parent, base, facing, rng)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	part({ Name = "ThroneStep", Size = Vector3.new(10, 1, 3), CFrame = cf * CFrame.new(0, 0.5, -4.6), Color = THRONE_DARK, Parent = parent })
	part({ Name = "ThroneBase", Size = Vector3.new(9, 3, 7), CFrame = cf * CFrame.new(0, 1.5, 0), Color = THRONE_DARK, Parent = parent })
	part({ Name = "ThroneSeat", Size = Vector3.new(7, 1, 5), CFrame = cf * CFrame.new(0, 3.5, 0.3), Color = THRONE, Parent = parent })
	part({ Name = "ThroneBack", Size = Vector3.new(8, 10, 2), CFrame = cf * CFrame.new(0, 8, 3), Color = THRONE, Parent = parent })
	decor({ Name = "ThroneBroken", Size = Vector3.new(4.6, 4, 1.8), CFrame = cf * CFrame.new(-1.6, 14.2, 3.1) * CFrame.Angles(0, 0, 0.35), Color = THRONE, Parent = parent })
	decor({ Name = "ThroneFallen", Size = Vector3.new(4, 3, 1.8), CFrame = cf * CFrame.new(5.6, 1.5, 5.6) * CFrame.Angles(0.2, 0.5, 1.3), Color = THRONE, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "ThroneArm", Size = Vector3.new(1.8, 3, 6), CFrame = cf * CFrame.new(side * 4.2, 4.5, 0.3), Color = THRONE_DARK, Parent = parent })
		coral(parent, (cf * CFrame.new(side * 6.2, 0, 2.4)).Position, rng, 1.4)
	end
	for i = 1, 3 do
		decor({ Name = "ThroneCrack", Size = Vector3.new(0.3, rng:NextNumber(2.5, 4.5), 0.1), CFrame = cf * CFrame.new(-2.5 + i * 1.6, 8 + rng:NextNumber(-2, 2), 1.95) * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5)), Color = BLACK, Parent = parent })
	end
	-- an old crown left on the seat
	local crown = cf * CFrame.new(0, 4.3, 0.2)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		decor({ Name = "CrownPoint", Size = Vector3.new(0.4, 0.9, 0.4), CFrame = crown * CFrame.new(math.cos(a) * 0.8, 0.3, math.sin(a) * 0.8), Color = GOLD, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	end
	K.sparkles(decor({ Name = "CrownBand", Size = Vector3.new(1.9, 0.4, 1.9), CFrame = crown, Color = GOLD, Parent = parent }), GOLD, 3)
end

local function ruinedShrine(parent, base, facing, rng)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	part({ Name = "ShrineFloor", Size = Vector3.new(14, 1, 12), CFrame = cf * CFrame.new(0, 0.5, 0), Color = STONE_DARK, Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "ShrineStep", Size = Vector3.new(6, 0.5, 2), CFrame = cf * CFrame.new(0, 0.25, -7), Color = STONE_DARK, Parent = parent })
	for i, c in ipairs({ { -5.5, -4.5 }, { 5.5, -4.5 }, { -5.5, 4.5 }, { 5.5, 4.5 } }) do
		local h = (i == 2) and 3 or rng:NextNumber(6, 10)
		part({ Name = "ShrinePillar", Size = Vector3.new(1.8, h, 1.8), CFrame = cf * CFrame.new(c[1], 1 + h / 2, c[2]), Color = STONE, Parent = parent })
		decor({ Name = "PillarCap", Size = Vector3.new(2.4, 0.6, 2.4), CFrame = cf * CFrame.new(c[1], 1 + h + 0.3, c[2]), Color = STONE_DARK, Parent = parent })
	end
	decor({ Name = "FallenLintel", Size = Vector3.new(12, 1.4, 1.8), CFrame = cf * CFrame.new(1, 3, -6.5) * CFrame.Angles(0, 0.25, 0.35), Color = STONE, Parent = parent })
	part({ Name = "Altar", Size = Vector3.new(4, 2.2, 2.6), CFrame = cf * CFrame.new(0, 2.1, 2.5), Color = STONE, Parent = parent })
	local rune = decor({ Name = "AltarRune", Size = Vector3.new(3, 0.2, 1.6), CFrame = cf * CFrame.new(0, 3.3, 2.5), Color = RUNE, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
	light(rune, RUNE, 14, 1)
	K.eggShape(parent, "StoneEgg", cf * CFrame.new(0, 5, 2.5), Vector3.new(2, 2.8, 2), STONE)
	for _ = 1, 5 do
		decor({ Name = "Rubble", Size = Vector3.new(1, 1, 1) * rng:NextNumber(0.8, 1.6), CFrame = cf * CFrame.new(rng:NextNumber(-7, 7), 1.3, rng:NextNumber(-5, 5)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0), Color = STONE_DARK, Parent = parent })
	end
end

local function telescope(parent, base, toward)
	local head = base + Vector3.new(0, 4.2, 0)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		rod(parent, head, base + Vector3.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6), 0.3, WOOD_DARK)
	end
	local dir = (Vector3.new(toward.X, 0, toward.Z) - Vector3.new(base.X, 0, base.Z)).Unit + Vector3.new(0, 0.22, 0)
	rod(parent, head - dir * 1.6, head + dir * 3.4, 1, BRASS).Name = "Telescope"
	local lens = rod(parent, head + dir * 3.3, head + dir * 3.6, 1.2, SKY_TEXT)
	lens.Name = "Lens"
	lens.Material = Enum.Material.Neon
	-- the broken-off eyepiece lies in the grass
	rod(parent, base + Vector3.new(1.8, 0.35, -1.2), base + Vector3.new(3.2, 0.35, -0.4), 0.7, BRASS).Name = "Eyepiece"
end

-- A cave in a sandstone cliff, its mouth toward `facing`, the floor clear in a 6-stud circle round `center`.
local function cliffCave(parent, center, facing, island, rng)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z)) -- -Z: the mouth
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "CaveWall", Size = Vector3.new(3, 12, 15), CFrame = cf * CFrame.new(side * 8.5, 6, 1.5) * CFrame.Angles(0, 0, side * 0.04), Color = SANDSTONE_DARK, Parent = parent })
	end
	part({ Name = "CaveBack", Size = Vector3.new(20, 12, 3), CFrame = cf * CFrame.new(0, 6, 9.5), Color = SANDSTONE_DARK, Parent = parent })
	part({ Name = "CaveRoof", Size = Vector3.new(22, 3.5, 19), CFrame = cf * CFrame.new(0, 13.2, 2), Color = SANDSTONE, Parent = parent })
	decor({ Name = "CaveMoss", Size = Vector3.new(21, 0.6, 18), CFrame = cf * CFrame.new(0, 15.2, 2), Color = GRASS_2[2], Parent = parent })
	for _, x in ipairs({ -5, 0, 5 }) do
		decor({ Name = "Stalactite", Size = Vector3.new(1.2, rng:NextNumber(1.5, 3), 1.2), CFrame = cf * CFrame.new(x, 10.6, -5.6) * CFrame.Angles(0, math.rad(45), 0), Color = SANDSTONE, Parent = parent })
	end
	-- the cliff mass round and over the cave, kept off the cave's floor
	for _ = 1, 14 do
		local lx, lz = rng:NextNumber(-17, 17), rng:NextNumber(4, 20)
		local w, h = rng:NextNumber(6, 10), rng:NextNumber(12, 22)
		local inside = math.abs(lx) < 7 + w / 2 + 0.5 and lz < 8 + w / 2 + 0.5
		local p = (cf * CFrame.new(lx, h / 2 - 1, lz)).Position
		if not inside and onIsland(p, 1) and clear(p, 3) then
			part({ Name = "Cliff", Size = Vector3.new(w, h, w * rng:NextNumber(0.8, 1.2)), CFrame = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = rng:NextNumber() < 0.5 and SANDSTONE or SANDSTONE_DARK, Parent = parent })
			decor({ Name = "CliffGrass", Size = Vector3.new(w - 0.6, 0.6, w - 0.6), CFrame = CFrame.new(p + Vector3.new(0, h / 2 + 0.1, 0)), Color = GRASS_2[1], Parent = parent })
		end
	end
	-- the smugglers' den inside
	for _, x in ipairs({ -4, 4 }) do
		hangingLantern(parent, (cf * CFrame.new(x, 11.4, 2)).Position, 2.2, WARM)
	end
	for _, c in ipairs({ { -5.4, 6.2 }, { 5.6, 5.8 }, { -5.6, 3.2 } }) do
		crate(parent, (cf * CFrame.new(c[1], 0, c[2])).Position, rng, 0)
	end
	barrel(parent, (cf * CFrame.new(4.6, 0, 2.4)).Position)
	barrel(parent, (cf * CFrame.new(5.6, 0, -1.2)).Position)
	local tableCf = cf * CFrame.new(-4.2, 0, -1)
	part({ Name = "SmugglerTable", Size = Vector3.new(3.4, 0.4, 2.4), CFrame = tableCf * CFrame.new(0, 2.6, 0), Color = WOOD, Parent = parent })
	decor({ Name = "TableLegs", Size = Vector3.new(2.8, 2.4, 1.8), CFrame = tableCf * CFrame.new(0, 1.2, 0), Color = WOOD_DARK, Transparency = 0.5, Parent = parent })
	decor({ Name = "TreasureMap", Size = Vector3.new(1.8, 0.05, 1.4), CFrame = tableCf * CFrame.new(0, 2.83, 0) * CFrame.Angles(0, 0.3, 0), Color = Color3.fromRGB(236, 214, 160), Parent = parent })
	decor({ Name = "MapMark", Size = Vector3.new(0.3, 0.06, 0.3), CFrame = tableCf * CFrame.new(0.3, 2.86, 0.2), Color = Color3.fromRGB(220, 40, 40), Parent = parent })
	claim(center, 10)
	return cf
end

-- Set pieces by feature ---------------------------------------------------------------------------------------

-- Landing Reef: where every dive arrives. A welcome arch over the path east, a notice board, a dock hut.
local function landing(parent, island, rng)
	local c = island.pos
	local archX = c.X - 16
	local archCf = CFrame.lookAt(Vector3.new(archX, TOP, c.Z), Vector3.new(archX - 10, TOP, c.Z))
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "ArchPost", Size = Vector3.new(1.6, 15, 1.6), CFrame = archCf * CFrame.new(side * 8.5, 7.5, 0), Color = WOOD_DARK, Parent = parent })
		part({ Name = "ArchFoot", Size = Vector3.new(2.8, 1.2, 2.8), CFrame = archCf * CFrame.new(side * 8.5, 0.6, 0), Color = STONE_DARK, Parent = parent })
		claim((archCf * CFrame.new(side * 8.5, 0, 0)).Position, 2)
	end
	decor({ Name = "ArchBeam", Size = Vector3.new(21, 1.4, 1.8), CFrame = archCf * CFrame.new(0, 15.6, 0), Color = WOOD_DARK, Parent = parent })
	decor({ Name = "ArchBeam", Size = Vector3.new(19, 0.9, 1.3), CFrame = archCf * CFrame.new(0, 11.2, 0), Color = WOOD_DARK, Parent = parent })
	local board = decor({ Name = "ArchSign", Size = Vector3.new(14, 3.4, 0.5), CFrame = archCf * CFrame.new(0, 13.4, 0), Color = SIGN_DARK, Parent = parent })
	K.surfaceText(board, "LANDING REEF", GOLD, Enum.NormalId.Front)
	K.surfaceText(board, "LANDING REEF", GOLD, Enum.NormalId.Back)
	for _, x in ipairs({ -5.5, 5.5 }) do
		hangingLantern(parent, (archCf * CFrame.new(x, 10.7, 0)).Position, 1.4, WARM)
	end
	-- lanterns along the path east
	for _, x in ipairs({ -26, -6, 12 }) do
		for _, side in ipairs({ -1, 1 }) do
			local p = Vector3.new(c.X + x, TOP, c.Z + side * 7.5)
			if onIsland(p, 1) then
				lantern(parent, p, 5.5, WARM)
			end
		end
	end
	-- the notice board with tips, beside the path
	signBoard(parent, Vector3.new(c.X - 4, TOP, c.Z - 13), Vector3.new(c.X - 4, TOP, c.Z), "TIPS\nBank fish at a Tide Cache\nSwipe mobs with your rod (click or F)\nGeysers launch you between islands\nExtract at a beacon", 10, 6.5, SKY_TEXT)
	claim(Vector3.new(c.X - 4, TOP, c.Z - 13), 5)
	local hut = heroSpot(island, around(24, 220, 20, 8), 9, 9)
	if hut then
		K.latticeHut(parent, hut, c)
		crate(parent, hut + outward(island, hut) * 8, rng, 0)
	end
	fill(parent, island, rng, 5, 10)
end

-- Lily Pond: the giant lavender tree over the wild nest, a lattice hut and lily pads all round.
local function lavender(parent, island, rng)
	local tree = heroSpot(island, { { -22, 18 }, { -24, -2 }, { 20, 22 }, { 14, -24 } }, 9, 8)
	if tree then
		K.giantLavenderTree(parent, tree, rng)
		part({ Name = "TreeCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(24, 9, 9), CFrame = CFrame.new(tree + Vector3.new(0, 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 1, Parent = parent })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			K.daisies(parent, tree + Vector3.new(math.cos(a) * 8, 0.2, math.sin(a) * 8), rng)
		end
	end
	local hut = heroSpot(island, around(24, 30, 25, 6), 9, 9)
	if hut then
		K.latticeHut(parent, hut, island.pos)
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = at(island, math.cos(a) * (island.r + rng:NextNumber(4, 14)), math.sin(a) * (island.r + rng:NextNumber(4, 14)), WATER_Y)
		if inWater(island, p) and clear(p, 3) then
			lilyPad(parent, p, rng, rng:NextNumber() < 0.35)
		end
	end
	fill(parent, island, rng, 5, 12)
end

-- Bamboo Reef: a bamboo grove round the wild nest, stone lanterns and a lattice hut.
local function bamboo(parent, island, rng)
	local nest = nestOn(island)
	if nest then
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + rng:NextNumber(0, 0.3)
			local p = nest + Vector3.new(math.cos(a) * rng:NextNumber(7.5, 10), 0, math.sin(a) * rng:NextNumber(7.5, 10))
			if clear(p, 1) and onIsland(p, 2) then
				K.bambooCluster(parent, Vector3.new(p.X, TOP, p.Z), rng)
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			local p = nest + Vector3.new(side * 5, 0, -5)
			if clear(p, 1) and onIsland(p, 2) then
				stoneLantern(parent, Vector3.new(p.X, TOP, p.Z), 1)
			end
		end
	end
	scatter(island, rng, 3, island.r * 0.6, island.r - 4, 5, 4, function(p)
		K.bambooCluster(parent, p, rng)
	end)
	local hut = heroSpot(island, around(22, 180, 25, 8), 9, 9)
	if hut then
		K.latticeHut(parent, hut, island.pos)
	end
	fill(parent, island, rng, 3, 10)
end

-- Twin Reefs: each island holds one of a matching pair of stone lantern towers.
local function twin(parent, island, rng)
	local toward = island.name == "TwinReefNorth" and -90 or 90
	local p = heroSpot(island, around(17, toward + 90, 30, 12), 7, 5)
	if p then
		stoneLantern(parent, p, 2.6)
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2 + 0.4
			K.flowerTuft(parent, p + Vector3.new(math.cos(a) * 4.6, 0, math.sin(a) * 4.6), rng)
		end
	end
	fill(parent, island, rng, 4, 10)
end

-- Turtle Bay: big blocky sea turtles resting on the beach, babies heading for the water.
local function turtles(parent, island, rng)
	local placed = 0
	for _, c in ipairs(around(island.r - 9, 110, 47, 7)) do
		if placed < 3 then
			local p = heroSpot(island, { c }, 8, 7)
			if p then
				placed += 1
				sandPatch(parent, p, 7)
				seaTurtle(parent, p, p + outward(island, p) * 10, rng:NextNumber(0.9, 1.15))
			end
		end
	end
	for i = 1, 5 do
		local p = spot(island, rng, island.r - 10, island.r - 4, 3)
		if p then
			seaTurtle(parent, p, p + outward(island, p) * 10 + Vector3.new(i, 0, -i), 0.3)
		end
	end
	for _ = 1, 3 do
		local p = spot(island, rng, island.r * 0.5, island.r - 6, 7)
		if p then
			claim(p, 3)
			sandPatch(parent, p, 4)
			palm(parent, p, rng, rng:NextNumber(0.9, 1.15))
		end
	end
	fill(parent, island, rng, 2, 8)
end

-- Mangrove Isle: mangroves whose arching roots reach over the shore, and roots caging the wild nest.
local function mangroveIsle(parent, island, rng)
	local nest = nestOn(island)
	if nest then
		rootCage(parent, nest, rng)
	end
	local grown = 0
	for _, c in ipairs(around(island.r - 6, 30, 40, 9)) do
		if grown < 5 then
			local p = heroSpot(island, { c }, 5, 5)
			if p then
				grown += 1
				mangrove(parent, p, outward(island, p), rng)
			end
		end
	end
	fill(parent, island, rng, 2, 10)
end

-- Kelp Shallows: tall kelp standing in the shallows all round, a drying rack and a boat on the beach.
local function kelpbeds(parent, island, rng)
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local d = island.r + rng:NextNumber(5, 13)
		local p = at(island, math.cos(a) * d, math.sin(a) * d, WATER_Y - 9)
		if inWater(island, p) and clear(p, 2.5) then
			kelpColumn(parent, p, rng:NextNumber(14, 22), rng)
		end
	end
	local rack = heroSpot(island, around(16, 160, 30, 8), 6, 6)
	if rack then
		local cf = CFrame.lookAt(rack, island.pos)
		for _, x in ipairs({ -4, 4 }) do
			decor({ Name = "RackPost", Size = Vector3.new(0.6, 5, 0.6), CFrame = cf * CFrame.new(x, 2.5, 0), Color = WOOD_DARK, Parent = parent })
		end
		decor({ Name = "RackBar", Size = Vector3.new(9, 0.4, 0.4), CFrame = cf * CFrame.new(0, 4.8, 0), Color = WOOD, Parent = parent })
		for k = 1, 7 do
			local h = rng:NextNumber(2, 3.2)
			windy(decor({ Name = "DryingKelp", Size = Vector3.new(0.7, h, 0.15), CFrame = cf * CFrame.new(-3.6 + k * 0.9, 4.7 - h / 2, 0), Color = KELP[(k % #KELP) + 1], CastShadow = false, Parent = parent }))
		end
	end
	local boat = heroSpot(island, around(island.r - 5, 200, 35, 6), 5, 5)
	if boat then
		rowboat(parent, boat, rng:NextNumber(0, math.pi), P.ROOF_ORANGE)
		barrel(parent, boat + Vector3.new(3, 0, 3))
	end
	fill(parent, island, rng, 3, 10)
end

-- Shipwreck Bay: a pirate cove. The galleon on the sand holds the wild nest in its smashed hull.
local function shipwreckBay(parent, island, rng)
	local nest = nestOn(island) or island.pos
	local wreckAt = Vector3.new(nest.X + 1, 0, nest.Z - 3)
	D.shipwreck(parent, wreckAt, rng)
	claim(wreckAt, 15)
	local sunk = waterSpot(island, around(island.r + 12, -20, 25, 12), 6, 10)
	if sunk then
		sunkenWreck(parent, sunk, rng:NextNumber(0, math.pi * 2))
	end
	local pile = heroSpot(island, around(24, 150, 35, 8), 6, 5)
	if pile then
		treasurePile(parent, pile, rng)
	end
	local bones = heroSpot(island, around(30, 200, 30, 8), 5, 4)
	if bones then
		skeleton(parent, bones, rng)
	end
	for _, c in ipairs({ around(island.r - 6, 0, 40, 9), around(island.r - 7, 20, 40, 9) }) do
		local p = heroSpot(island, c, 5, 4)
		if p then
			cannon(parent, p, p + outward(island, p) * 10)
		end
	end
	local flag = heroSpot(island, around(20, 250, 30, 8), 5, 3)
	if flag then
		pirateFlag(parent, flag)
	end
	scatter(island, rng, 6, 10, island.r - 5, 5, 2, function(p)
		if rng:NextNumber() < 0.5 then
			barrel(parent, p)
		else
			crate(parent, p, rng, 0)
		end
	end)
	for _ = 1, 3 do
		local p = spot(island, rng, island.r * 0.55, island.r - 5, 7)
		if p then
			claim(p, 3)
			palm(parent, p, rng, rng:NextNumber(1, 1.2))
		end
	end
	fill(parent, island, rng, 2, 10)
end

-- Coral Arches: huge stacked-coral arches over the paths, sea fans and big coral.
local function arches(parent, island, rng)
	local built = 0
	for _, lane in ipairs(lanes) do
		local dir = (lane[2] - lane[1]).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for _, d in ipairs({ 26, 34, 20 }) do
			local mid = lane[1] + dir * d
			local a, b = mid - side * 8.5, mid + side * 8.5
			if d < island.r - 4 and clear(a, 2) and clear(b, 2) and onIsland(a, 2) and onIsland(b, 2) then
				coralArch(parent, a, b, rng:NextNumber(12, 16), rng)
				claim(a, 3)
				claim(b, 3)
				built += 1
				break
			end
		end
	end
	if built < 2 then
		for _, c in ipairs(around(island.r * 0.6, 100, 60, 6)) do
			local p = at(island, c[1], c[2])
			local side = outward(island, p)
			local a, b = p - Vector3.new(-side.Z, 0, side.X) * 8, p + Vector3.new(-side.Z, 0, side.X) * 8
			if built < 2 and clear(a, 3) and clear(b, 3) and onIsland(a, 2) and onIsland(b, 2) then
				coralArch(parent, a, b, rng:NextNumber(11, 14), rng)
				claim(p, 8)
				built += 1
			end
		end
	end
	scatter(island, rng, 6, island.r * 0.4, island.r - 4, 5, 3, function(p)
		if rng:NextNumber() < 0.5 then
			seaFan(parent, p, rng, CORAL[rng:NextInteger(1, #CORAL)])
		else
			coral(parent, p, rng, rng:NextNumber(1.6, 2.2))
		end
	end)
	fill(parent, island, rng, 3, 10)
end

-- Sea Stacks: the tallest stack carries the wild nest on its flat top (y 32) with a spiral of ledges up to it;
-- smaller stacks with gull nests stand round the island.
local function stacks(parent, island, rng)
	local nest = nestOn(island)
	if nest then
		local top = nest.Y
		local c = Vector3.new(nest.X, 0, nest.Z)
		local radius = 6.5
		local core = disk(parent, "TallestStack", Vector3.new(c.X, (TOP - 2 + top) / 2, c.Z), radius, top - TOP + 2, SANDSTONE, Enum.Material.Slate)
		core.Name = "TallestStack"
		local cap = disk(parent, "StackGrass", Vector3.new(c.X, top + 0.1, c.Z), radius + 0.2, 0.2, GRASS_2[1])
		cap.CanCollide = false
		cap.CanQuery = false
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			decor({ Name = "StackBand", Size = Vector3.new(2.6, 1.4, 0.6), CFrame = CFrame.new(c.X + math.cos(a) * radius, TOP + 4 + i * 4.4, c.Z + math.sin(a) * radius) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = SANDSTONE_DARK, Parent = parent })
		end
		-- the spiral starts on the side facing away from the bridges, toward the rim
		local away = outward(island, c)
		local start = math.atan2(away.Z, away.X) - math.rad(90)
		local steps = math.ceil((top - TOP) / 1.75)
		local rise = (top - TOP) / steps
		for k = 1, steps do
			local a = start + k * math.rad(28)
			local y = TOP + k * rise
			local r = radius + 2.2
			local cf = CFrame.new(c.X + math.cos(a) * r, y - 0.9, c.Z + math.sin(a) * r) * CFrame.Angles(0, -a, 0)
			part({ Name = "Ledge", Size = Vector3.new(4.8, 1.8, 5.2), CFrame = cf, Color = (k % 2 == 0) and SANDSTONE or SANDSTONE_DARK, Parent = parent })
			if k % 4 == 0 then
				tuft(parent, (cf * CFrame.new(1.2, 0.9, 0)).Position, rng, 2)
			end
		end
		claim(c, radius + 5)
		lantern(parent, Vector3.new(c.X - 4, top, c.Z + 3.5), 3.5, WARM)
	end
	local made = 0
	for _, c in ipairs(around(island.r - 9, 10, 45, 8)) do
		if made < 4 then
			local p = heroSpot(island, { c }, 6, 6)
			if p then
				made += 1
				local top = seaStack(parent, p, rng:NextNumber(12, 24), rng)
				gullNest(parent, top)
				if made % 2 == 0 then
					perchedGull(parent, top + Vector3.new(1.4, 0, 1), island.pos)
				end
			end
		end
	end
	fill(parent, island, rng, 3, 10)
end

-- Smugglers' Cove: a cliff with a walk-in cave round the wild nest, a smugglers' den inside, a rowboat outside.
local function cove(parent, island, rng)
	local nest = nestOn(island)
	if nest then
		cliffCave(parent, nest, island.pos, island, rng)
	end
	local boat = waterSpot(island, around(island.r + 6, 100, 40, 9), 5, 6)
	if boat then
		rowboat(parent, boat + Vector3.new(0, -0.3, 0), rng:NextNumber(0, math.pi), WOOD)
	end
	local stash = heroSpot(island, around(22, 200, 30, 8), 6, 5)
	if stash then
		for i = 1, 3 do
			crate(parent, stash + Vector3.new(i * 2.8 - 5.6, 0, 0), rng, 0)
		end
		crate(parent, stash, rng, 2.6)
		lantern(parent, stash + Vector3.new(0, 0, 3.5), 4.5, WARM)
	end
	fill(parent, island, rng, 3, 10)
end

-- Puffer Lagoon: coral round the open water in the middle, reeds and lily pads in it, a fishing deck over it.
local function lagoon(parent, island, rng)
	local hole = 16
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local p = at(island, math.cos(a) * (hole + 2.8), math.sin(a) * (hole + 2.8))
		if clear(p, 2) and onIsland(p, 0) then
			coral(parent, p, rng, rng:NextNumber(0.9, 1.3))
		end
	end
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local d = hole - rng:NextNumber(1, 3)
		local p = at(island, math.cos(a) * d, math.sin(a) * d, WATER_Y)
		if clear(p, 1) then
			if i % 3 == 0 then
				lilyPad(parent, p, rng, i % 2 == 0)
			else
				for k = 1, 3 do
					local h = rng:NextNumber(3.5, 6)
					local q = p + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
					windy(decor({ Name = "Reed", Size = Vector3.new(0.25, h, 0.25), CFrame = CFrame.new(q + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(110, 150, 70), CastShadow = false, Parent = parent }))
					if k == 1 then
						decor({ Name = "Cattail", Size = Vector3.new(0.5, 1.3, 0.5), CFrame = CFrame.new(q + Vector3.new(0, h - 1, 0)), Color = Color3.fromRGB(120, 78, 50), Parent = parent })
					end
				end
			end
		end
	end
	-- the fishing deck: from the shore out over the hole
	for _, deg in ipairs({ -85, -60, 85, 20, 200 }) do
		local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
		local landEnd = at(island, dir.X * (hole + 7), dir.Z * (hole + 7))
		local tip = at(island, dir.X * (hole - 6), dir.Z * (hole - 6))
		if clear(landEnd, 3) and clear((landEnd + tip) / 2, 2) then
			local cf = CFrame.lookAt((landEnd + tip) / 2, tip)
			local length = (tip - landEnd).Magnitude
			part({ Name = "FishingDeck", Size = Vector3.new(5, 0.6, length), CFrame = cf * CFrame.new(0, -0.3, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = parent })
			for z = -length / 2 + 1, length / 2, 3 do
				decor({ Name = "DeckPlank", Size = Vector3.new(5.2, 0.15, 0.4), CFrame = cf * CFrame.new(0, 0.05, z), Color = WOOD_DARK, Parent = parent })
			end
			for _, z in ipairs({ length / 2 - 0.6, length / 2 - 6 }) do
				for _, x in ipairs({ -2.3, 2.3 }) do
					local post = cf * CFrame.new(x, 0, z)
					local depth = post.Y - SEA_FLOOR
					decor({ Name = "DeckPost", Size = Vector3.new(0.6, depth + 2, 0.6), CFrame = post * CFrame.new(0, 1 - depth / 2, 0), Color = WOOD_DARK, Parent = parent })
				end
			end
			part({ Name = "Bench", Size = Vector3.new(3.4, 0.4, 1.2), CFrame = cf * CFrame.new(0, 1.1, length / 2 - 1.6), Color = WOOD_DARK, Parent = parent })
			decor({ Name = "Bucket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = cf * CFrame.new(1.6, 0.6, length / 2 - 3) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, Parent = parent })
			claim(landEnd, 3)
			break
		end
	end
	-- a giant puffer statue on the rim
	local statue = heroSpot(island, around(hole + 12, 60, 50, 7), 7, 6)
	if statue then
		local center = statue + Vector3.new(0, 6.5, 0)
		part({ Name = "StatuePlinth", Size = Vector3.new(5, 2, 5), CFrame = CFrame.new(statue + Vector3.new(0, 1, 0)), Color = STONE, Parent = parent })
		decor({ Name = "PufferStatue", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(center), Color = Color3.fromRGB(255, 214, 84), Parent = parent })
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local up = (i % 3) - 1
			local d = Vector3.new(math.cos(a), up * 0.6, math.sin(a)).Unit
			decor({ Name = "PufferSpike", Size = Vector3.new(0.6, 0.6, 2.2), CFrame = CFrame.lookAt(center + d * 4.4, center + d * 6), Color = Color3.fromRGB(255, 150, 60), Parent = parent })
		end
		local face = CFrame.lookAt(center, Vector3.new(island.pos.X, center.Y, island.pos.Z))
		for _, x in ipairs({ -1.4, 1.4 }) do
			decor({ Name = "PufferEye", Size = Vector3.new(1.2, 1.4, 0.3), CFrame = face * CFrame.new(x, 1, -3.8), Color = BLACK, Parent = parent })
		end
		decor({ Name = "PufferMouth", Size = Vector3.new(1.4, 0.9, 0.4), CFrame = face * CFrame.new(0, -0.8, -3.9), Color = Color3.fromRGB(255, 120, 150), Parent = parent })
	end
	fill(parent, island, rng, 3, 8)
end

-- Gull Rock: a tall streaked rock with gull nests on its ledges and gulls perched round it.
local function gulls(parent, island, rng)
	local p = heroSpot(island, { { -19, 10 }, { -16, 16 }, { -20, -4 }, { 14, 16 } }, 8, 9)
	if p then
		local y = TOP - 0.5
		local w = 13
		for i = 1, 7 do
			local h = rng:NextNumber(3.5, 5)
			local cf = CFrame.new(p.X + rng:NextNumber(-0.8, 0.8), y + h / 2, p.Z + rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
			part({ Name = "GullRock", Size = Vector3.new(w, h + 0.3, w * rng:NextNumber(0.85, 1.05)), CFrame = cf, Color = (i % 2 == 0) and DARK or Color3.fromRGB(96, 98, 108), Material = Enum.Material.Slate, Parent = parent })
			if i >= 2 then
				decor({ Name = "Streak", Size = Vector3.new(0.2, h * 1.4, rng:NextNumber(0.6, 1.2)), CFrame = cf * CFrame.new(w / 2 + 0.05, -h * 0.2, rng:NextNumber(-w / 4, w / 4)), Color = GULL_WHITE, Parent = parent })
				decor({ Name = "Streak", Size = Vector3.new(rng:NextNumber(0.6, 1.2), h * 1.2, 0.2), CFrame = cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), -h * 0.2, -w / 2 - 0.05), Color = GULL_WHITE, Parent = parent })
			end
			if i % 2 == 1 and i < 7 then
				gullNest(parent, (cf * CFrame.new(w / 2 - 1.2, h / 2, w / 2 - 1.2)).Position)
			end
			y += h
			w -= 1.4
		end
		local top = Vector3.new(p.X, y, p.Z)
		gullNest(parent, top)
		perchedGull(parent, top + Vector3.new(1.6, 0, -1), island.pos)
	end
	scatter(island, rng, 4, island.r * 0.4, island.r - 3, 5, 2, function(q)
		decor({ Name = "Perch", Size = Vector3.new(0.7, 3, 0.7), CFrame = CFrame.new(q + Vector3.new(0, 1.5, 0)), Color = WOOD_DARK, Parent = parent })
		perchedGull(parent, q + Vector3.new(0, 3, 0), island.pos + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20)))
	end)
	fill(parent, island, rng, 3, 8)
end

-- North and South Atoll: palms round the beach and a reef ring of coral out in the water.
local function atoll(parent, island, rng)
	local count = 0
	for _, c in ipairs(around(island.r - 7, rng:NextNumber(0, 360), 45, 8)) do
		if count < 5 then
			local p = heroSpot(island, { c }, 4, 3)
			if p then
				count += 1
				sandPatch(parent, p, 5)
				palm(parent, p, rng, rng:NextNumber(0.9, 1.25))
			end
		end
	end
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local d = island.r + rng:NextNumber(8, 14)
		local p = at(island, math.cos(a) * d, math.sin(a) * d, WATER_Y - 2.2)
		if inWater(island, p) and clear(p, 2) then
			decor({ Name = "ReefRock", Size = Vector3.new(3, 6, 3), CFrame = CFrame.new(p - Vector3.new(0, 3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = SANDSTONE_DARK, Parent = parent })
			coral(parent, p, rng, rng:NextNumber(1, 1.6))
		end
	end
	local fire = heroSpot(island, around(14, rng:NextNumber(0, 360), 60, 6), 6, 4)
	if fire then
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			decor({ Name = "FireStone", Size = Vector3.new(1, 0.7, 1), CFrame = CFrame.new(fire + Vector3.new(math.cos(a) * 1.6, 0.35, math.sin(a) * 1.6)), Color = DARK, Parent = parent })
		end
		local flame = decor({ Name = "Campfire", Size = Vector3.new(1.2, 1.6, 1.2), CFrame = CFrame.new(fire + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(255, 150, 50), Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
		light(flame, Color3.fromRGB(255, 160, 80), 14, 1.2)
		K.particles(flame, { Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 40)), LightEmission = 0.8, Rate = 10, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(2, 4), Size = NumberSequence.new(0.6, 0), SpreadAngle = Vector2.new(15, 15) })
	end
	fill(parent, island, rng, 2, 8)
end

-- Giant Clam Atoll: a giant open clam with a glowing pearl floating over it.
local function clam(parent, island, rng)
	local p = heroSpot(island, { { -11, -19 }, { -18, -14 }, { 4, 24 }, { -22, -2 }, { 18, -18 } }, 8, 9)
	if p then
		local s = 1.6
		local cf = CFrame.lookAt(p, Vector3.new(island.pos.X, p.Y, island.pos.Z)) -- the hinge at the back, open toward the centre
		for i = -3, 3 do
			local rib = cf * CFrame.new(0, 1 * s, 2 * s) * CFrame.Angles(0, i * math.rad(22), 0) * CFrame.new(0, 0, -4 * s)
			part({ Name = "ClamShell", Size = Vector3.new(3.2, 2, 8.5) * s, CFrame = rib, Color = (i % 2 == 0) and CLAM or CLAM_DARK, Parent = parent })
			decor({ Name = "ClamLip", Size = Vector3.new(3.3, 0.6, 1) * s, CFrame = rib * CFrame.new(0, 1 * s, -3.9 * s), Color = CLAM_LIP, Parent = parent })
			local lid = cf * CFrame.new(0, 2.2 * s, 2 * s) * CFrame.Angles(math.rad(55), 0, 0) * CFrame.Angles(0, i * math.rad(22), 0) * CFrame.new(0, 0, -4 * s)
			decor({ Name = "ClamLid", Size = Vector3.new(3.2, 1.6, 8.5) * s, CFrame = lid, Color = (i % 2 == 0) and CLAM_DARK or CLAM, Parent = parent })
			decor({ Name = "ClamLip", Size = Vector3.new(3.3, 0.6, 1) * s, CFrame = lid * CFrame.new(0, -0.8 * s, -3.9 * s), Color = CLAM_LIP, Parent = parent })
		end
		decor({ Name = "ClamFlesh", Size = Vector3.new(9, 0.8, 6) * s, CFrame = cf * CFrame.new(0, 2.1 * s, -1.4 * s), Color = Color3.fromRGB(255, 196, 214), Parent = parent })
		local home = (cf * CFrame.new(0, 7 * s, -2 * s)).Position
		local model = Instance.new("Model")
		model.Name = "ClamPearl"
		local pearl = decor({ Name = "Pearl", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(home), Color = PEARL, Material = Enum.Material.Neon, CastShadow = false, Parent = model })
		decor({ Name = "PearlHalo", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 4.4, 4.4), CFrame = CFrame.new(home), Color = CLAM_LIP, Material = Enum.Material.Neon, Transparency = 0.75, CastShadow = false, Parent = model })
		light(pearl, CLAM_LIP, 20, 1.6)
		K.sparkles(pearl, PEARL, 6)
		model.PrimaryPart = pearl
		model:SetAttribute("Home", home)
		model:SetAttribute("Seed", 3.7)
		model.Parent = parent
		tag(model, "TideboundFloat")
	end
	fill(parent, island, rng, 5, 10)
end

-- Lighthouse Isle: the striped lighthouse and its keeper's cottage.
local function lighthouseIsle(parent, island, rng)
	local tower = at(island, 14, 14)
	D.lighthouse(parent, Vector3.new(tower.X, 0, tower.Z))
	claim(tower, 7)
	local home = heroSpot(island, { { -6, 22 }, { -14, 16 }, { 10, -22 }, { -22, 6 } }, 9, 8)
	if home then
		local cf = K.timberHouse(parent, home, island.pos, 10, 8, 8, P.ROOF_SLATE)
		local chimney = decor({ Name = "Chimney", Size = Vector3.new(1.6, 4, 1.6), CFrame = cf * CFrame.new(3, 11, 1.5), Color = STONE_DARK, Parent = parent })
		K.particles(chimney, { Color = ColorSequence.new(Color3.fromRGB(200, 200, 206)), Rate = 3, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 3), Size = NumberSequence.new(1, 3), Transparency = NumberSequence.new(0.4, 1), EmissionDirection = Enum.NormalId.Top, Drag = 0.6, WindAffectsDrag = true })
		local a, b = (cf * CFrame.new(-6, 4, -5)).Position, (cf * CFrame.new(-6, 4, -12)).Position
		for _, q in ipairs({ a, b }) do
			decor({ Name = "LinePost", Size = Vector3.new(0.4, 4.2, 0.4), CFrame = CFrame.new(q - Vector3.new(0, 2, 0)), Color = WOOD_DARK, Parent = parent })
		end
		rod(parent, a, b, 0.1, Color3.fromRGB(230, 230, 230))
		for k = 1, 3 do
			windy(decor({ Name = "Washing", Size = Vector3.new(0.1, 1.6, 1.4), CFrame = CFrame.lookAt(a:Lerp(b, k / 4) - Vector3.new(0, 0.9, 0), b - Vector3.new(0, 0.9, 0)), Color = ({ P.ROOF_ORANGE, SKY_TEXT, GULL_WHITE })[k], Parent = parent }))
		end
	end
	fill(parent, island, rng, 4, 8)
end

-- Maelstrom Isle: rune stones facing the whirlpool and a ruined shrine.
local function maelstromIsle(parent, island, rng)
	local stones = 0
	for _, c in ipairs(around(24, -60, 25, 14)) do
		if stones < 5 then
			local p = heroSpot(island, { c }, 4, 2)
			if p then
				stones += 1
				local h = rng:NextNumber(6, 10)
				local cf = CFrame.lookAt(p + Vector3.new(0, h / 2, 0), Vector3.new(L.maelstrom.X, p.Y + h / 2, L.maelstrom.Z))
				part({ Name = "RuneStone", Size = Vector3.new(2.6, h, 1.8), CFrame = cf * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.08, 0.08)), Color = STONE_DARK, Parent = parent })
				decor({ Name = "Rune", Size = Vector3.new(1.2, h * 0.45, 0.2), CFrame = cf * CFrame.new(0, h * 0.1, -0.95), Color = RUNE, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
			end
		end
	end
	local shrine = heroSpot(island, { { -9, -23 }, { 0, -24 }, { -20, -12 }, { -22, 8 } }, 9, 9)
	if shrine then
		ruinedShrine(parent, shrine, island.pos, rng)
	end
	fill(parent, island, rng, 4, 8)
end

-- Warden's Rock: the arena. Huge jagged mint-rock spires ring it, a broken coral throne at the rim.
local function warden(parent, island, rng)
	for i = 0, 13 do
		local a = math.rad(i * 360 / 14 + rng:NextNumber(-6, 6))
		local d = island.r - rng:NextNumber(5, 9)
		local p = at(island, math.cos(a) * d, math.sin(a) * d)
		if clear(p, 5) and onIsland(p, 2) then
			claim(p, 4)
			mintSpire(parent, p, rng:NextNumber(18, 30), rng)
		end
	end
	local throne = heroSpot(island, { { 0, -31 }, { -6, -30 }, { 6, 30 }, { -30, -10 } }, 7, 7)
	if throne then
		coralThrone(parent, throne, island.pos, rng)
	end
	fill(parent, island, rng, 2, 6)
end

-- Storm Spire: a towering dark spire with glowing cracks and a lightning rod.
local function spire(parent, island, rng)
	local p = heroSpot(island, { { -6, -16 }, { -14, 10 }, { -10, -14 }, { 12, -6 } }, 8, 8)
	if p then
		local y = TOP - 0.5
		local w = 14
		for i = 1, 9 do
			local h = rng:NextNumber(5, 6.5)
			local cf = CFrame.new(p.X + rng:NextNumber(-0.6, 0.6), y + h / 2, p.Z + rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
			part({ Name = "Spire", Size = Vector3.new(w, h + 0.4, w * rng:NextNumber(0.85, 1)), CFrame = cf, Color = (i % 2 == 0) and DARK or DARKER, Material = Enum.Material.Slate, Parent = parent })
			decor({ Name = "Crack", Size = Vector3.new(0.25, h * 0.9, 0.5), CFrame = cf * CFrame.new(w / 2 + 0.05, 0, rng:NextNumber(-w / 4, w / 4)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, 0), Color = STORM_GLOW, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
			decor({ Name = "Crack", Size = Vector3.new(0.5, h * 0.8, 0.25), CFrame = cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), 0, -w / 2 - 0.05) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)), Color = STORM_GLOW, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
			y += h
			w = math.max(3, w - 1.3)
		end
		local top = Vector3.new(p.X, y, p.Z)
		rod(parent, top, top + Vector3.new(0, 9, 0), 0.4, IRON).Name = "LightningRod"
		local tip = decor({ Name = "RodTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(top + Vector3.new(0, 9.4, 0)), Color = STORM_GLOW, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
		light(tip, STORM_GLOW, 30, 2)
		K.sparkles(tip, STORM_GLOW, 10)
	end
	fill(parent, island, rng, 5, 8)
end

-- Bone Reef: a giant sea monster's ribcage arching over the wild nest, its skull toward the rim.
local function bones(parent, island, rng)
	local nest = nestOn(island)
	if nest then
		local n = Vector3.new(nest.X, TOP, nest.Z)
		local axis = outward(island, n)
		local side = Vector3.new(-axis.Z, 0, axis.X)
		for t = -14, 14, 2.4 do
			decor({ Name = "Vertebra", Size = Vector3.new(1.8, 1.6, 2), CFrame = CFrame.lookAt(n + axis * t + Vector3.new(0, 11.4 - t * t * 0.01, 0), n + axis * (t + 1) + Vector3.new(0, 11.4 - t * t * 0.01, 0)), Color = BONE, Parent = parent })
		end
		for _, t in ipairs({ -10, -5, 0, 5, 10 }) do
			for _, s in ipairs({ -1, 1 }) do
				local previous = n + axis * t + Vector3.new(0, 11, 0)
				for k = 1, 4 do
					local phi = k / 4 * math.pi / 2
					local point = n + axis * t + side * s * 8 * math.sin(phi) + Vector3.new(0, 11 * math.cos(phi) - 0.4, 0)
					rod(parent, previous, point, 1.1, BONE).Name = "Rib"
					previous = point
				end
			end
		end
		-- the skull toward the rim
		local head = CFrame.lookAt(n + axis * 21 + Vector3.new(0, 3, 0), n + axis * 40 + Vector3.new(0, 3, 0))
		if onIsland(head.Position, 2) then
			part({ Name = "Skull", Size = Vector3.new(8, 6, 9), CFrame = head, Color = BONE, Parent = parent })
			decor({ Name = "Snout", Size = Vector3.new(6, 3.6, 6), CFrame = head * CFrame.new(0, -0.8, -6.5), Color = BONE, Parent = parent })
			for _, x in ipairs({ -2.2, 2.2 }) do
				decor({ Name = "EyeSocket", Size = Vector3.new(1.8, 1.6, 0.4), CFrame = head * CFrame.new(x, 1.2, -4.55), Color = BLACK, Parent = parent })
				local glow = decor({ Name = "EyeGlow", Size = Vector3.new(0.7, 0.7, 0.2), CFrame = head * CFrame.new(x, 1.2, -4.75), Color = RUNE, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
				light(glow, RUNE, 8, 0.8)
			end
			for k = -2, 2 do
				decor({ Name = "Tooth", Size = Vector3.new(0.6, 1.4, 0.6), CFrame = head * CFrame.new(k * 1.1, -2.8, -9.2), Color = GULL_WHITE, Parent = parent })
			end
		end
	end
	scatter(island, rng, 6, 8, island.r - 4, 3, 1, function(p)
		local a = rng:NextNumber(0, math.pi * 2)
		rod(parent, p + Vector3.new(0, 0.4, 0), p + Vector3.new(math.cos(a) * 3, 0.4, math.sin(a) * 3), 0.6, BONE).Name = "Bone"
	end)
	fill(parent, island, rng, 4, 6)
end

-- Far Reach: the edge of the map. A ruined stone ring, a broken telescope looking out to sea, a lone lantern.
local function far(parent, island, rng)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = at(island, math.cos(a) * 13, math.sin(a) * 13)
		if clear(p, 2.5) and onIsland(p, 1.5) then
			if i % 3 == 1 then
				decor({ Name = "FallenStone", Size = Vector3.new(2.4, 1.6, 6), CFrame = CFrame.new(p + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, -a + rng:NextNumber(-0.4, 0.4), 0.1), Color = STONE_DARK, Parent = parent })
			else
				local h = rng:NextNumber(5, 9)
				part({ Name = "RingStone", Size = Vector3.new(2.4, h, 1.6), CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2, 0), island.pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), Color = STONE, Parent = parent })
			end
		end
	end
	local scope = heroSpot(island, { { 16, 4 }, { 14, 10 }, { 16, -6 } }, 5, 4)
	if scope then
		telescope(parent, scope, scope + Vector3.new(50, 0, 0))
	end
	local post = heroSpot(island, { { 20, -10 }, { 18, 14 }, { -6, 18 } }, 5, 2)
	if post then
		lantern(parent, post, 9, WARM)
		signBoard(parent, post + Vector3.new(-3, 0, 3), post + Vector3.new(30, 0, 3), "THE EDGE OF THE MAP\nOnly the current lies beyond.", 7, 2.6, SKY_TEXT)
	end
	fill(parent, island, rng, 3, 8)
end

local BUILDERS = {
	landing = landing,
	lavender = lavender,
	bamboo = bamboo,
	twin = twin,
	turtles = turtles,
	mangrove = mangroveIsle,
	kelpbeds = kelpbeds,
	shipwreck = shipwreckBay,
	arches = arches,
	stacks = stacks,
	cove = cove,
	lagoon = lagoon,
	gulls = gulls,
	atoll = atoll,
	clam = clam,
	lighthouse = lighthouseIsle,
	maelstrom = maelstromIsle,
	warden = warden,
	spire = spire,
	bones = bones,
	far = far,
}

-- Decorates one island; ctx = { rng = Random, top = TOP, onLand = function(position, margin) }.
function IsleFeatures.build(folder, island, ctx)
	ctx = ctx or {}
	local features = Instance.new("Folder")
	features.Name = "Features"
	features.Parent = folder
	local rng = ctx.rng or Random.new(math.floor(island.pos.X * 3 + island.pos.Z))
	onLandFn = ctx.onLand
	prepare(island)
	local builder = BUILDERS[island.feature]
	if builder then
		builder(features, island, rng)
	else
		fill(features, island, rng, 6, 12)
	end
	onLandFn = nil
	return features
end

return IsleFeatures
