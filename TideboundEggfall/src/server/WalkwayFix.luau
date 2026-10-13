-- Tidebound: Eggfall: walkway safety pass. Runs after the builders (Main) and is safe in Edit mode; every step is
-- idempotent, so it patches a world saved with the place as well as a fresh build.
--   1. Street piers: a town street whose midpoint is on land is non-collidable paving end to end, so where it runs
--      out over the water you fell through it. Those stretches get a solid stone pier body (and legs) under them.
--   2. Rope bridges: the old sag (up to 3.5 studs) sank the middle of every Outer Reef bridge under the sea, and the
--      slats have small gaps. The slats, posts and ropes are lifted to a shallow sag that stays above the water, and
--      an invisible collision deck runs under the slats.
--   3. Z-fighting: deck tops sat exactly on the ground's top where a bridge meets land; they're lifted 0.05.
--   4. Junctions: where one walkway crosses another, the other's rail posts and ropes poking up through the
--      walking space are removed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local L = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("IslesLayout"))

local WalkwayFix = {}

local TOP, WATER_Y = L.TOP, L.WATER_Y
local FLOOR = L.sea.floorY - 2
local ROPE_SAG = 1 -- deepest a rope bridge may sag: its slats stay ~0.7 above the water
local PIER = Color3.fromRGB(104, 108, 118)
local PIER_LEG = Color3.fromRGB(84, 88, 98)

local down = RaycastParams.new()
down.RespectCanCollide = true
down.FilterType = Enum.RaycastFilterType.Exclude
down.FilterDescendantsInstances = { workspace.Terrain }

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Plastic
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function solidBelow(position, depth)
	return workspace:Raycast(position, Vector3.new(0, -depth, 0), down) ~= nil
end

local function topOf(p)
	local cf, s = p.CFrame, p.Size
	return cf.Position.Y + (math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z) / 2
end

-- 1. Street piers ------------------------------------------------------------------------------------------

local function streetPiers(town)
	local made = 0
	for _, street in ipairs(town:GetDescendants()) do
		if street:IsA("BasePart") and street.Name == "Street" and not street:GetAttribute("PierChecked") then
			street:SetAttribute("PierChecked", true)
			local cf, w, len = street.CFrame, street.Size.X, street.Size.Z
			local top = topOf(street)
			-- which 1-stud slices along the street have nothing solid under them
			local open = {}
			for i = 0, math.floor(len) do
				local z = -len / 2 + i
				for _, x in ipairs({ -w / 2 + 0.5, 0, w / 2 - 0.5 }) do
					local p = (cf * CFrame.new(x, 0, z)).Position
					if not solidBelow(Vector3.new(p.X, top + 0.3, p.Z), 2.6) then
						open[i] = true
						break
					end
				end
			end
			-- merge into runs (bridging 2-stud gaps), padded a stud onto the land at each end
			local runs, start, last = {}, nil, nil
			for i = 0, math.floor(len) do
				if open[i] then
					if start and i - last <= 3 then
						last = i
					else
						if start then
							table.insert(runs, { start, last })
						end
						start, last = i, i
					end
				end
			end
			if start then
				table.insert(runs, { start, last })
			end
			for _, run in ipairs(runs) do
				local z1 = math.max(-len / 2, -len / 2 + run[1] - 1.5)
				local z2 = math.min(len / 2, -len / 2 + run[2] + 1.5)
				local runLen = z2 - z1
				local zc = (z1 + z2) / 2
				local deckTop = top - street.Size.Y - 0.02 -- the paving sits on the pier as on the ground (just under it: no z-fight)
				local body = cf * CFrame.new(0, deckTop - cf.Position.Y - 0.8, zc)
				part({ Name = "StreetPier", Size = Vector3.new(w + 2, 1.6, runLen), CFrame = body, Color = PIER, Parent = street.Parent })
				local legH = deckTop - 1.6 - FLOOR
				for z = z1 + 2, z2 - 1, 12 do
					for _, side in ipairs({ -1, 1 }) do
						part({ Name = "StreetPierLeg", Size = Vector3.new(1.6, legH, 1.6), CFrame = cf * CFrame.new(side * (w / 2 + 0.2), deckTop - cf.Position.Y - 1.6 - legH / 2, z), Color = PIER_LEG, CanCollide = false, CanQuery = false, Parent = street.Parent })
					end
				end
				made += 1
			end
			street:SetAttribute("PierRuns", #runs)
		end
	end
	return made
end

-- A street that ends over the water just short of another walkway (a boardwalk it was meant to join) gets its
-- paving and pier carried across the gap.
local function streetEnds(town)
	local joined = 0
	for _, street in ipairs(town:GetDescendants()) do
		if street:IsA("BasePart") and street.Name == "Street" and not street:GetAttribute("EndsChecked") then
			street:SetAttribute("EndsChecked", true)
			local cf, w, len = street.CFrame, street.Size.X, street.Size.Z
			local top = topOf(street)
			local deckTop = top - street.Size.Y - 0.02
			for _, sign in ipairs({ -1, 1 }) do
				local endPos = (cf * CFrame.new(0, 0, sign * len / 2)).Position
				local out = flat(endPos - cf.Position).Unit
				local function solidAt(d)
					local p = endPos + out * d
					return solidBelow(Vector3.new(p.X, top + 0.3, p.Z), 2.6)
				end
				if solidAt(-0.5) and not solidAt(0.5) then
					local gap
					for d = 0.5, 5, 0.25 do
						if solidAt(d) then
							gap = d
							break
						end
					end
					if gap then
						local span = gap + 1
						local center = cf * CFrame.new(0, 0, sign * (len / 2 + gap / 2))
						part({ Name = "StreetPier", Size = Vector3.new(w + 2, 1.6, span), CFrame = center * CFrame.new(0, deckTop - cf.Position.Y - 0.8, 0), Color = PIER, Parent = street.Parent })
						local paving = part({ Name = "StreetJoin", Size = Vector3.new(w, street.Size.Y, span), CFrame = center, Color = street.Color, Material = street.Material, CanCollide = false, Parent = street.Parent })
						paving.TopSurface = Enum.SurfaceType.Studs
						joined += 1
					end
				end
			end
		end
	end
	return joined
end

-- 2. Rope bridges ------------------------------------------------------------------------------------------

local ROPE_COLORS = { [Color3.fromRGB(196, 170, 120):ToHex()] = true, [Color3.fromRGB(206, 182, 136):ToHex()] = true }
local function isRope(p)
	return p.Name == "Rope" and ROPE_COLORS[p.Color:ToHex()] == true
end

local function ropeBridges(bridges)
	if not bridges or bridges:FindFirstChild("RopeColliders") then
		return 0
	end
	local colliders = Instance.new("Folder")
	colliders.Name = "RopeColliders"
	local pieces = {}
	for _, p in ipairs(bridges:GetChildren()) do
		if p:IsA("BasePart") and (p.Name == "Slat" or p.Name == "RopePost" or (isRope(p) and p.Size.Y < 0.4)) then
			table.insert(pieces, p)
		end
	end
	local lifted = 0
	for _, link in ipairs(L.links) do
		if link[3] == "rope" then
			local a, b = L.byName[link[1]], L.byName[link[2]]
			local dir = (flat(b.pos) - flat(a.pos)).Unit
			local from, to = flat(a.pos) + dir * (a.r - 3), flat(b.pos) - dir * (b.r - 3)
			local mid = (from + to) / 2 + Vector3.new(-dir.Z, 0, dir.X) * (link[4] or 0)
			for _, half in ipairs({ { from, mid }, { mid, to } }) do
				local p0, p1 = half[1], half[2]
				local length = (p1 - p0).Magnitude
				local d = (p1 - p0).Unit
				local side = Vector3.new(-d.Z, 0, d.X)
				-- this half's pieces, with where along it they sit
				local mine = {}
				local oldSag = 0
				for _, p in ipairs(pieces) do
					local rel = flat(p.Position) - p0
					local s = rel:Dot(d) / length
					if s > -0.01 and s < 1.01 and math.abs(rel:Dot(side)) < 4.5 then
						s = math.clamp(s, 0, 1)
						table.insert(mine, { p, s })
						local bell = 4 * s * (1 - s)
						if p.Name == "Slat" and bell > 0.5 then
							oldSag = math.max(oldSag, (TOP - 0.3 - p.Position.Y) / bell)
						end
					end
				end
				local newSag = math.min(ROPE_SAG, length / 40)
				if oldSag > newSag + 0.05 then
					for _, entry in ipairs(mine) do
						local s = entry[2]
						entry[1].CFrame += Vector3.new(0, (oldSag - newSag) * 4 * s * (1 - s), 0)
						lifted += 1
					end
				else
					newSag = math.max(oldSag, 0)
				end
				-- the invisible deck: short chords along the sag, flush with the slat tops (slats are 6 x 0.35)
				local n = math.max(1, math.ceil(length / 6))
				local function point(s)
					local f = p0 + (p1 - p0) * s
					return Vector3.new(f.X, TOP - 0.3 + 0.175 - newSag * 4 * s * (1 - s), f.Z)
				end
				for i = 0, n - 1 do
					local q0, q1 = point(i / n), point((i + 1) / n)
					local chord = CFrame.lookAt((q0 + q1) / 2, q1)
					part({ Name = "BridgeCollider", Size = Vector3.new(6, 0.4, (q1 - q0).Magnitude + 0.4), CFrame = chord * CFrame.new(0, -0.2, 0), Transparency = 1, CastShadow = false, Parent = colliders })
				end
			end
		end
	end
	colliders.Parent = bridges
	return lifted
end

-- 3. Z-fighting ---------------------------------------------------------------------------------------------

local DECKS = { Boardwalk = true, PlankDeck = true, Joint = true, Causeway = true }

local function liftDecks(root)
	local lifted = 0
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") and DECKS[p.Name] and math.abs(topOf(p) - TOP) < 0.01 then
			p.CFrame += Vector3.new(0, 0.05, 0)
			lifted += 1
		end
	end
	return lifted
end

-- 4. Junctions ----------------------------------------------------------------------------------------------

local WALKWAYS = { Boardwalk = true, Street = true, StreetPier = true, StreetJoin = true, PlankDeck = true, Causeway = true }
local RAILING = { Post = true, ["Rail Post"] = true, Rail = true, RopePost = true }

local function junctions(root)
	local ways, rails = {}, {}
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") then
			if WALKWAYS[p.Name] then
				table.insert(ways, p)
			elseif RAILING[p.Name] or isRope(p) then
				table.insert(rails, p)
			end
		end
	end
	-- railing is decor (CanQuery off), so spatial queries can't see it: test its points against each space
	local function points(p)
		if p.Name == "Rope" or p.Name == "Rail" then
			local axis = p.Name == "Rope" and Vector3.new(p.Size.X / 2, 0, 0) or Vector3.new(0, 0, p.Size.Z / 2)
			return { p.Position, p.CFrame:PointToWorldSpace(axis), p.CFrame:PointToWorldSpace(-axis) }, 0.25
		end
		return { p.Position, p.Position + Vector3.new(0, p.Size.Y * 0.4, 0) }, math.min(p.Size.X, p.Size.Z) / 2
	end
	local removed = {}
	for _, way in ipairs(ways) do
		-- the walking space over this walkway (and a stud past its ends, where it meets the next one), kept clear
		-- of its own railing at the edges
		local inset = (way.Name == "Boardwalk" or way.Name == "PlankDeck") and 1.4 or 0.6
		local size = Vector3.new(way.Size.X - inset * 2, 2.6, way.Size.Z + 2)
		if size.X > 1 and size.Z > 1 then
			local space = way.CFrame * CFrame.new(0, way.Size.Y / 2 + 0.25 + size.Y / 2, 0)
			local reach = size.Magnitude / 2 + 3
			for _, p in ipairs(rails) do
				if not removed[p] and (p.Position - space.Position).Magnitude < reach then
					local pts, r = points(p)
					for _, pt in ipairs(pts) do
						local rel = space:PointToObjectSpace(pt)
						if math.abs(rel.X) < size.X / 2 + r and math.abs(rel.Y) < size.Y / 2 + 0.5 and math.abs(rel.Z) < size.Z / 2 + r then
							removed[p] = true
							break
						end
					end
				end
			end
		end
	end
	local count = 0
	for p in pairs(removed) do
		p:Destroy()
		count += 1
	end
	return count
end

function WalkwayFix.apply(world)
	local town = world:FindFirstChild("Town")
	local shoals = world:FindFirstChild("SunkenShoals")
	local report = {}
	report.piers = town and streetPiers(town) or 0
	report.joins = town and streetEnds(town) or 0
	report.ropePieces = ropeBridges(shoals and shoals:FindFirstChild("Bridges"))
	report.decksLifted = liftDecks(world)
	report.railingRemoved = junctions(world)
	return ("street piers %d, street joins %d, rope pieces lifted %d, decks lifted %d, junction railing removed %d"):format(report.piers, report.joins, report.ropePieces, report.decksLifted, report.railingRemoved)
end

return WalkwayFix
