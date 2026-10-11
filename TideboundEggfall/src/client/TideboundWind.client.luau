-- Tidebound: Eggfall wind, following DevBoxy's "How to make wind effects in (Roblox Studio)" video
-- (its free "Wind effect" model by Dylian1235): white wind-line trails that drift past the camera,
-- and foliage tagged "WindShake" that sways. Direction follows Workspace.GlobalWind. Client-only visuals.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local TAG = "WindShake"
local WIND_SPEED = 20
local WIND_POWER = 0.5
local LINE_LIFETIME = 1.5
local LINES_PER_SECOND = 11
local SWAY_RADIUS = 120 -- only sway foliage near where the camera is looking
local SWAY_HZ = 1 / 30
local LINE_OFFSET = Vector3.new(0, 0.1, 0)

local terrain = workspace:FindFirstChildOfClass("Terrain")

local function windDirection()
	local wind = workspace.GlobalWind
	if wind.Magnitude < 0.01 then
		return Vector3.new(1, 0, 0.3).Unit
	end
	return wind.Unit
end

-- Wind lines -------------------------------------------------------------------------------

local lines = {}
local lastSpawn = 0

local function spawnLine()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local position = (camera.CFrame * CFrame.Angles(math.rad(math.random(-30, 70)), math.rad(math.random(-80, 80)), 0) * CFrame.new(0, 0, -math.random(20, 60))).Position
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	trail.Transparency = NumberSequence.new(0.7)
	trail.FaceCamera = true
	trail.Parent = a0
	a0.WorldPosition = position
	a1.WorldPosition = position + LINE_OFFSET
	a0.Parent = terrain
	a1.Parent = terrain
	table.insert(lines, {
		a0 = a0,
		a1 = a1,
		trail = trail,
		start = os.clock(),
		lifetime = LINE_LIFETIME + math.random(-10, 10) * 0.1,
		origin = position,
		direction = windDirection(),
		speed = WIND_SPEED + math.random(-10, 10) * 0.1,
		seed = math.random(1, 1000) * 0.1,
	})
end

local function updateLines(now)
	if now - lastSpawn > 1 / LINES_PER_SECOND then
		lastSpawn = now
		spawnLine()
	end
	for i = #lines, 1, -1 do
		local line = lines[i]
		local alive = now - line.start
		if alive >= line.lifetime then
			line.a0:Destroy()
			line.a1:Destroy()
			lines[i] = lines[#lines]
			lines[#lines] = nil
		else
			line.trail.MaxLength = 20 - 20 * (alive / line.lifetime)
			local wave = math.sin((now + line.seed) * line.speed * 0.2)
			local travelled = CFrame.new(line.origin, line.origin + line.direction) * CFrame.new(0, 0, -line.speed * alive)
			line.a0.WorldPosition = travelled.Position + Vector3.new(wave * 0.5, wave * 0.8, wave * 0.5)
			line.a1.WorldPosition = line.a0.WorldPosition + LINE_OFFSET
		end
	end
end

-- Swaying foliage --------------------------------------------------------------------------

local foliage = {} -- [BasePart] = { origin = CFrame, seed = number, current = CFrame }

local function addFoliage(part)
	if part:IsA("BasePart") and not foliage[part] then
		foliage[part] = { origin = part.CFrame, seed = math.random(1000) * 0.1 }
	end
end

local function removeFoliage(part)
	local meta = foliage[part]
	if meta then
		foliage[part] = nil
		if part.Parent then
			part.CFrame = meta.origin
		end
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(addFoliage)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeFoliage)
for _, part in ipairs(CollectionService:GetTagged(TAG)) do
	addFoliage(part)
end

local lastSway = 0
local function updateFoliage(now)
	local dt = now - lastSway
	if dt < SWAY_HZ then
		return
	end
	lastSway = now
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local focus = camera.CFrame.Position + camera.CFrame.LookVector * (SWAY_RADIUS * 0.5)
	local direction = windDirection()
	local amp = WIND_POWER * 0.1
	local freq = now * (WIND_SPEED * 0.08)
	local step = math.min(1, dt * 8)
	local parts, cframes = {}, {}
	for part, meta in pairs(foliage) do
		local origin = meta.origin
		if (origin.Position - focus).Magnitude < SWAY_RADIUS then
			local seed = meta.seed
			local rotX = math.noise(freq, 0, seed) * amp
			local rotY = math.noise(freq, 0, -seed) * amp
			local rotZ = math.noise(freq, 0, seed + seed) * amp
			local target = origin * CFrame.Angles(rotX, rotY, rotZ) + direction * ((0.5 + math.noise(freq, seed, seed)) * amp)
			meta.current = (meta.current or origin):Lerp(target, step)
			table.insert(parts, part)
			table.insert(cframes, meta.current)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	updateLines(now)
	updateFoliage(now)
end)
