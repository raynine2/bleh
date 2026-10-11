-- Tidebound: Eggfall: anime clouds in the sky (Patch 12), on your screen only. Big fluffy cumulus built from
-- round puffs: bright white tops, a flat lavender-blue underside, a few wisps, drifting slowly with the wind
-- over the whole map. Low ones float over the islands; high ones tower on the horizon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local L = require(Shared:WaitForChild("IslesLayout"))

local camera = workspace.CurrentCamera
local rng = Random.new(1234)

local TOP = Color3.fromRGB(255, 255, 255)
local MID = Color3.fromRGB(236, 240, 252)
local SHADE = Color3.fromRGB(184, 192, 236)
local COUNT = 46
local MIN_X, MAX_X = L.sea.min.X - 300, L.sea.max.X + 300
local MIN_Z, MAX_Z = L.sea.min.Z - 300, L.sea.max.Z + 300

local folder = Instance.new("Folder")
folder.Name = "TideboundSky"
folder.Parent = workspace

local function puff(model, size, color, offset, pieces)
	local p = Instance.new("Part")
	p.Name = "Puff"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	table.insert(pieces, { part = p, offset = offset })
end

-- One cumulus: a row of big puffs along its length, smaller ones heaped on top, and a flat shaded base.
local function cloud(width)
	local model = Instance.new("Model")
	model.Name = "AnimeCloud"
	local pieces = {}
	local n = rng:NextInteger(5, 8)
	local depth = width * rng:NextNumber(0.45, 0.6)
	for i = 1, n do
		local s = (i - 0.5) / n
		local x = (s - 0.5) * width
		local bulge = math.sin(s * math.pi)
		local size = width * (0.22 + 0.2 * bulge) * rng:NextNumber(0.85, 1.15)
		local z = rng:NextNumber(-depth * 0.25, depth * 0.25)
		puff(model, size, MID, CFrame.new(x, size * 0.25, z), pieces)
		-- the shaded underside: a squashed puff just below, a touch wider
		puff(model, size * 1.05, SHADE, CFrame.new(x, -size * 0.05, z), pieces)
	end
	for _ = 1, rng:NextInteger(3, 5) do
		local x = rng:NextNumber(-0.3, 0.3) * width
		local size = width * rng:NextNumber(0.22, 0.34)
		puff(model, size, TOP, CFrame.new(x, width * rng:NextNumber(0.16, 0.26), rng:NextNumber(-depth * 0.2, depth * 0.2)), pieces)
	end
	-- squash the shaded layer flat so the cloud has the anime flat bottom
	for _, piece in ipairs(pieces) do
		if piece.part.Color == SHADE then
			piece.part.Shape = Enum.PartType.Block
			local s = piece.part.Size
			piece.part.Size = Vector3.new(s.X, s.Y * 0.28, s.Z * 0.8)
			piece.offset *= CFrame.new(0, s.Y * 0.1, 0)
			local corner = Instance.new("SpecialMesh")
			corner.MeshType = Enum.MeshType.Sphere
			corner.Parent = piece.part
		end
	end
	model.Parent = folder
	return model, pieces
end

local clouds = {}
for _ = 1, COUNT do
	local high = rng:NextNumber() < 0.35
	local width = high and rng:NextNumber(140, 240) or rng:NextNumber(60, 130)
	local model, pieces = cloud(width)
	table.insert(clouds, {
		model = model,
		pieces = pieces,
		pos = Vector3.new(rng:NextNumber(MIN_X, MAX_X), high and rng:NextNumber(300, 420) or rng:NextNumber(150, 240), rng:NextNumber(MIN_Z, MAX_Z)),
		yaw = rng:NextNumber(0, math.pi * 2),
		speed = rng:NextNumber(0.7, 1.3),
		seed = rng:NextNumber(0, 10),
	})
end

local function wind()
	local w = workspace.GlobalWind
	if w.Magnitude < 0.1 then
		return Vector3.new(1, 0, 0.4).Unit
	end
	return Vector3.new(w.X, 0, w.Z).Unit
end

local lastMove = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local drift = wind() * 3.5
	-- deep under the sea there's no sky to see
	local cam = camera.CFrame.Position
	folder.Parent = cam.Y > -100 and workspace or nil
	for _, c in ipairs(clouds) do
		c.pos += drift * c.speed * dt
		if c.pos.X > MAX_X then
			c.pos -= Vector3.new(MAX_X - MIN_X, 0, 0)
		elseif c.pos.X < MIN_X then
			c.pos += Vector3.new(MAX_X - MIN_X, 0, 0)
		end
		if c.pos.Z > MAX_Z then
			c.pos -= Vector3.new(0, 0, MAX_Z - MIN_Z)
		elseif c.pos.Z < MIN_Z then
			c.pos += Vector3.new(0, 0, MAX_Z - MIN_Z)
		end
	end
	-- moving every puff is cheap, but there's no need to do it more than 15 times a second
	if t - lastMove < 1 / 15 or not folder.Parent then
		return
	end
	lastMove = t
	local parts, cframes = {}, {}
	for _, c in ipairs(clouds) do
		local base = CFrame.new(c.pos + Vector3.new(0, math.sin(t * 0.2 + c.seed) * 2, 0)) * CFrame.Angles(0, c.yaw, 0)
		for _, piece in ipairs(c.pieces) do
			table.insert(parts, piece.part)
			table.insert(cframes, base * piece.offset)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)
