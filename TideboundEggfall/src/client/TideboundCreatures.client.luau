-- Tidebound: Eggfall: idle motion for Home Nest creatures (Delta Section 7) and companions (Master Patch 1).
-- Client-only visuals. Swimmers (Aquarium Hall) drift in a slow figure eight inside the tank; roamers
-- (Creature Pen) wander between points on the lawn, pause, and hop; companions swim at their owner's
-- shoulders. Real idle and follow loops come from Person B (Section 10).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local NEAR = 220 -- only animate creatures near the camera

local roamState = {} -- [Model] = { from, to, started, duration, pauseUntil }
local followState = {} -- [Model] = CFrame the companion is easing from

local function near(position)
	local camera = workspace.CurrentCamera
	return camera and (camera.CFrame.Position - position).Magnitude < NEAR
end

local function swim(model, t)
	local home = model:GetAttribute("Home")
	local range = model:GetAttribute("Range")
	if typeof(home) ~= "CFrame" or typeof(range) ~= "Vector3" or not near(home.Position) then
		return
	end
	local seed = model:GetAttribute("Seed") or 0
	local speed = 0.25 + (seed % 7) * 0.03
	local a = t * speed + seed
	local offset = Vector3.new(math.sin(a) * range.X * 0.5, math.sin(a * 2) * range.Y * 0.25, math.sin(a * 0.5) * range.Z * 0.5)
	local position = home.Position + offset
	local ahead = home.Position + Vector3.new(math.sin(a + 0.1) * range.X * 0.5, math.sin((a + 0.1) * 2) * range.Y * 0.25, math.sin((a + 0.1) * 0.5) * range.Z * 0.5)
	if (ahead - position).Magnitude > 0.001 then
		model:PivotTo(CFrame.lookAt(position, ahead))
	end
end

local function roam(model, now)
	local centre = model:GetAttribute("Centre")
	local radius = model:GetAttribute("Radius")
	if typeof(centre) ~= "Vector3" or type(radius) ~= "number" or not near(centre) then
		return
	end
	local s = roamState[model]
	if not s then
		local start = model:GetPivot().Position
		s = { from = start, to = start, started = now, duration = 0.01, pauseUntil = now + math.random() * 2 }
		roamState[model] = s
	end
	local alpha = math.clamp((now - s.started) / s.duration, 0, 1)
	if alpha >= 1 and now >= s.pauseUntil then
		local angle = math.random() * math.pi * 2
		local dist = math.random() * radius
		s.from = model:GetPivot().Position
		s.to = centre + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		s.started = now
		s.duration = math.max(1, (s.to - s.from).Magnitude / 4)
		s.pauseUntil = now + s.duration + 1 + math.random() * 3
		alpha = 0
	end
	local position = s.from:Lerp(s.to, alpha)
	local hop = alpha < 1 and math.abs(math.sin(alpha * s.duration * 6)) * 0.4 or 0
	local direction = Vector3.new(s.to.X - s.from.X, 0, s.to.Z - s.from.Z)
	local look = direction.Magnitude > 0.01 and CFrame.lookAt(position, position + direction) or CFrame.new(position) * model:GetPivot().Rotation
	model:PivotTo(look + Vector3.new(0, hop, 0))
end

-- Companions trail just behind their owner, one at each shoulder, bobbing as they swim.
local function follow(model, dt, now)
	local owner = Players:GetPlayerByUserId(model:GetAttribute("Owner") or 0)
	local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	if not root or not near(root.Position) then
		return
	end
	local slot = model:GetAttribute("Slot") or 1
	local target = root.CFrame * CFrame.new(slot == 1 and -3 or 3, 0.6 + math.sin(now * 3 + slot) * 0.3, 3.5)
	local current = followState[model] or model:GetPivot()
	local position = target.Position
	if (current.Position - position).Magnitude < 40 then
		position = current.Position:Lerp(position, math.min(1, dt * 6))
	end
	local moved = Vector3.new(position.X - current.Position.X, 0, position.Z - current.Position.Z)
	local look = moved.Magnitude > 0.02 and CFrame.lookAt(position, position + moved) or CFrame.new(position) * root.CFrame.Rotation
	followState[model] = look
	model:PivotTo(look)
end

CollectionService:GetInstanceRemovedSignal("TideboundRoamer"):Connect(function(model)
	roamState[model] = nil
end)

CollectionService:GetInstanceRemovedSignal("TideboundCompanion"):Connect(function(model)
	followState[model] = nil
end)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for _, model in ipairs(CollectionService:GetTagged("TideboundSwimmer")) do
		if model:IsA("Model") then
			swim(model, now)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("TideboundRoamer")) do
		if model:IsA("Model") then
			roam(model, now)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("TideboundCompanion")) do
		if model:IsA("Model") then
			follow(model, dt, now)
		end
	end
end)
