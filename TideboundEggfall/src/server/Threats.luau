-- Tidebound: Eggfall: Sunken Shoals threats beyond the Reef Warden (Master Patch 3, Tables B to D).
-- Elites (Table B): each den rolls a Barnacle Brute (70%) or a Snapjaw Moray (30%). Both telegraph before
-- they strike, and both are dodged, not killed: a missed charge leaves the Brute dazed and a lunge leaves the
-- Moray exposed, and either can be looted for its bait while it recovers.
-- Hazard (Table C): Stinging Anemone Beds, always on: 10 damage every 1.5 s and a 30% slow (client side).
-- Weather (Table D): Glass Calm every 15 min for 3 min, with a 20 s warning. Bites come 30% faster, the
-- riptide pauses, and your first catch during it pays +3 Brineworm. Weather never touches egg or mutation odds.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("Config"))

local Threats = {}

-- { delta, notify, notifyAll, cue, exposed(player) -> root?, damage(player, amount, fromPos, label), stun(player, seconds, fromPos), giveBait(player, baitId, count) }
local deps = nil
local TOP = 6
local rng = Random.new()

local BRUTE, MORAY = Config.Elites[1], Config.Elites[2]
local SHELL = Color3.fromRGB(150, 138, 120)
local SHELL_DARK = Color3.fromRGB(104, 96, 88)
local BARNACLE = Color3.fromRGB(226, 220, 204)
local MORAY_SKIN = Color3.fromRGB(164, 186, 60)
local MORAY_SPOT = Color3.fromRGB(96, 110, 30)

local function now()
	return workspace:GetServerTimeNow()
end

local function piece(model, name, size, cframe, color, shape, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function nameTag(adornee, title, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(0, 200, 0, 46)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(40, 20, 20)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Parent = gui
	local status = titleLabel:Clone()
	status.Name = "Status"
	status.Font = Enum.Font.BuilderSansBold
	status.Position = UDim2.new(0, 0, 0, 26)
	status.Size = UDim2.new(1, 0, 0, 18)
	status.Text = "Elite"
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Parent = gui
	gui.Parent = adornee
	return status
end

local function lootPrompt(adornee, elite)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = ("Loot %d %s"):format(elite.kind.drop.count, elite.kind.drop.bait)
	prompt.ObjectText = elite.kind.name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("Action", "EliteLoot")
	prompt:SetAttribute("Elite", elite.index)
	prompt.Parent = adornee
	return prompt
end

-- Barnacle Brute: a crab with a barnacle-crusted shell. Built in place; the server moves it with PivotTo.
local function buildBrute(elite)
	local model = Instance.new("Model")
	model.Name = "BarnacleBrute"
	local base = CFrame.new(elite.center + Vector3.new(0, 2.1, 0))
	local body = piece(model, "Body", Vector3.new(5.4, 3, 4.6), base, SHELL)
	piece(model, "ShellTop", Vector3.new(4.4, 1.2, 3.8), base * CFrame.new(0, 1.9, 0.2), SHELL_DARK)
	for i = 1, 7 do
		local a = i * math.pi * 2 / 7
		piece(model, "Barnacle", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(math.cos(a) * 1.6, 2.6, math.sin(a) * 1.3), BARNACLE, Enum.PartType.Ball)
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Claw", Vector3.new(1.6, 1.4, 2.4), base * CFrame.new(side * 2.9, 0.2, -2.4) * CFrame.Angles(0, side * 0.35, 0), SHELL_DARK)
		piece(model, "Pincer", Vector3.new(0.7, 0.7, 1.4), base * CFrame.new(side * 3.1, 0.7, -3.8), BARNACLE)
		piece(model, "Eye", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(side * 0.8, 1.9, -2.3), Color3.fromRGB(20, 20, 26), Enum.PartType.Ball)
		for leg = -1, 1 do
			piece(model, "Leg", Vector3.new(1.8, 0.4, 0.4), base * CFrame.new(side * 3, -0.9, leg * 1.2) * CFrame.Angles(0, 0, side * -0.5), SHELL_DARK)
		end
	end
	model.PrimaryPart = body
	elite.status = nameTag(body, BRUTE.name:upper(), 4.5)
	elite.prompt = lootPrompt(body, elite)
	elite.pos = elite.center
	elite.yaw = 0
	model.Parent = elite.folder
	elite.model = model
end

-- Snapjaw Moray: an eel head that peeks out of one of the den's coral holes.
local function buildMoray(elite)
	local model = Instance.new("Model")
	model.Name = "SnapjawMoray"
	local head = piece(model, "Body", Vector3.new(1.5, 3.2, 1.5), CFrame.new(elite.center), MORAY_SKIN)
	piece(model, "Jaw", Vector3.new(1.3, 0.5, 1.6), head.CFrame * CFrame.new(0, 1.1, -0.5), MORAY_SPOT)
	for _, side in ipairs({ -1, 1 }) do
		piece(model, "Eye", Vector3.new(0.45, 0.45, 0.45), head.CFrame * CFrame.new(side * 0.55, 1.3, -0.5), Color3.fromRGB(255, 220, 60), Enum.PartType.Ball, Enum.Material.Neon)
	end
	for i = 1, 3 do
		piece(model, "Spot", Vector3.new(0.4, 0.4, 0.1), head.CFrame * CFrame.new(0.3 * (i - 2), -0.6 + i * 0.4, -0.76), MORAY_SPOT)
	end
	model.PrimaryPart = head
	elite.status = nameTag(head, MORAY.name:upper(), 3.5)
	elite.prompt = lootPrompt(head, elite)
	elite.hole = rng:NextInteger(1, #elite.holes)
	model.Parent = elite.folder
	elite.model = model
end

local function spawnElite(elite)
	if elite.model then
		elite.model:Destroy()
	end
	local roll = rng:NextNumber(0, BRUTE.weight + MORAY.weight)
	elite.kind = roll < BRUTE.weight and BRUTE or MORAY
	elite.state = elite.kind == BRUTE and "wander" or "hidden"
	elite.untilTime = 0
	elite.cooldownUntil = 0
	elite.idleSince = os.clock()
	for _, glow in ipairs(elite.holes) do
		glow.Transparency = 0.7
	end
	if elite.kind == BRUTE then
		buildBrute(elite)
	else
		buildMoray(elite)
	end
end

local elites = {}
local lootedAt = {} -- ["userId:index"] = os.clock()

-- Players an elite can sense: outside the safe zones and within `range` of `position`.
local function exposedNear(position, range)
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = deps.exposed(player)
		if root then
			local offset = root.Position - position
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= range and math.abs(offset.Y) < 10 then
				table.insert(out, { player = player, root = root, distance = flat })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	return out
end

local function tell(elite, position)
	for _, near in ipairs(exposedNear(position, 50)) do
		deps.cue(near.player, "EliteTell", elite.kind.name)
	end
end

local function updateBrute(elite, dt, t)
	local status = elite.status
	local pose = CFrame.new(elite.pos + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, elite.yaw, 0)
	if elite.state == "wander" then
		status.Text = "Elite · charges after a shell rattle"
		if not elite.target or (Vector3.new(elite.target.X - elite.pos.X, 0, elite.target.Z - elite.pos.Z)).Magnitude < 1 then
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, elite.radius)
			elite.target = elite.center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		end
		local offset = Vector3.new(elite.target.X - elite.pos.X, 0, elite.target.Z - elite.pos.Z)
		if offset.Magnitude > 0.05 then
			elite.pos += offset.Unit * math.min(offset.Magnitude, 6 * dt)
			elite.yaw = math.atan2(-offset.X, -offset.Z)
		end
		if t >= elite.cooldownUntil then
			local near = exposedNear(elite.pos, BRUTE.aggroRange)[1]
			if near then
				local toward = Vector3.new(near.root.Position.X - elite.pos.X, 0, near.root.Position.Z - elite.pos.Z)
				if toward.Magnitude > 0.1 then
					elite.dir = toward.Unit
					elite.yaw = math.atan2(-toward.X, -toward.Z)
					elite.state = "rattle"
					elite.untilTime = t + BRUTE.tell
					tell(elite, elite.pos)
				end
			end
		end
		pose = CFrame.new(elite.pos + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, elite.yaw, 0)
	elseif elite.state == "rattle" then
		status.Text = "!! RATTLING · get out of its line !!"
		pose = pose * CFrame.Angles(0, math.sin(t * 50) * 0.08, math.sin(t * 37) * 0.05)
		if t >= elite.untilTime then
			elite.state = "charge"
			elite.traveled = 0
			elite.hit = {}
		end
	elseif elite.state == "charge" then
		status.Text = "CHARGING"
		local step = BRUTE.chargeSpeed * dt
		elite.pos += elite.dir * step
		elite.traveled += step
		pose = CFrame.new(elite.pos + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, elite.yaw, 0)
		for _, near in ipairs(exposedNear(elite.pos, BRUTE.hitRadius)) do
			if not elite.hit[near.player] then
				elite.hit[near.player] = true
				deps.stun(near.player, BRUTE.stun, elite.pos)
			end
		end
		local fromCenter = Vector3.new(elite.pos.X - elite.center.X, 0, elite.pos.Z - elite.center.Z).Magnitude
		if elite.traveled >= BRUTE.chargeDistance or fromCenter > elite.radius + 3 then
			elite.state = "dazed"
			elite.untilTime = t + BRUTE.daze
			elite.prompt.Enabled = true
		end
	elseif elite.state == "dazed" then
		status.Text = "DAZED · loot it now!"
		pose = pose * CFrame.Angles(0, 0, 0.35)
		if t >= elite.untilTime then
			elite.state = "wander"
			elite.cooldownUntil = t + BRUTE.cooldown
			elite.prompt.Enabled = false
			elite.target = nil
		end
	end
	elite.model:PivotTo(pose)
end

local function holePose(elite, raised, facing)
	local glow = elite.holes[elite.hole]
	local at = Vector3.new(glow.Position.X, TOP, glow.Position.Z)
	if raised then
		local look = facing and Vector3.new(facing.X - at.X, 0, facing.Z - at.Z) or Vector3.new(0, 0, -1)
		if look.Magnitude < 0.1 then
			look = Vector3.new(0, 0, -1)
		end
		return CFrame.lookAt(at + Vector3.new(0, 2.4, 0), at + Vector3.new(0, 2.4, 0) + look) * CFrame.Angles(math.rad(-25), 0, 0)
	end
	return CFrame.new(at + Vector3.new(0, 0.3, 0))
end

local function updateMoray(elite, t)
	local glow = elite.holes[elite.hole]
	local status = elite.status
	if elite.state == "hidden" then
		status.Text = "Elite · lunges from glowing holes"
		elite.model:PivotTo(holePose(elite, false))
		local near = exposedNear(glow.Position, MORAY.range)[1]
		if near then
			elite.state = "tell"
			elite.untilTime = t + MORAY.tell
			elite.facing = near.root.Position
			glow.Transparency = 0
			tell(elite, glow.Position)
		end
	elseif elite.state == "tell" then
		status.Text = "!! THE HOLE GLOWS · step back !!"
		elite.model:PivotTo(holePose(elite, false) * CFrame.new(0, math.sin(t * 40) * 0.2, 0))
		if t >= elite.untilTime then
			for _, near in ipairs(exposedNear(glow.Position, MORAY.range + 0.5)) do
				deps.damage(near.player, MORAY.damage, glow.Position, MORAY.name)
			end
			elite.state = "exposed"
			elite.untilTime = t + MORAY.exposed
			elite.prompt.Enabled = true
			glow.Transparency = 0.7
		end
	elseif elite.state == "exposed" then
		status.Text = "EXPOSED · loot it now!"
		elite.model:PivotTo(holePose(elite, true, elite.facing))
		if t >= elite.untilTime then
			elite.state = "moving"
			elite.untilTime = t + MORAY.cooldown
			elite.prompt.Enabled = false
			elite.model:PivotTo(holePose(elite, false) * CFrame.new(0, -4, 0))
		end
	elseif elite.state == "moving" then
		status.Text = "Moving between holes"
		if t >= elite.untilTime then
			local nextHole = elite.hole
			while #elite.holes > 1 and nextHole == elite.hole do
				nextHole = rng:NextInteger(1, #elite.holes)
			end
			elite.hole = nextHole
			elite.state = "hidden"
		end
	end
end

function Threats.onLoot(player, prompt)
	local elite = elites[prompt:GetAttribute("Elite")]
	if not elite or not elite.kind or (elite.state ~= "dazed" and elite.state ~= "exposed") then
		return
	end
	local key = player.UserId .. ":" .. elite.index
	local last = lootedAt[key]
	if last and os.clock() - last < Config.EliteLootCooldown then
		deps.notify(player, ("You already looted this %s. It has nothing new for %d s."):format(elite.kind.name, math.ceil(Config.EliteLootCooldown - (os.clock() - last))), "info")
		return
	end
	lootedAt[key] = os.clock()
	local drop = elite.kind.drop
	deps.giveBait(player, drop.bait, drop.count)
	deps.notify(player, ("You looted the %s: +%d %s."):format(elite.kind.name, drop.count, Config.BaitById[drop.bait].name), "good")
end

-- Weather ---------------------------------------------------------------------------------------------

local GLASS = Config.Weather.GlassCalm
local weather = nil -- { name, startsAt, endsAt } from its warning until it ends (server time)
local rewarded = {}

function Threats.weather()
	return weather
end

local function weatherActive()
	local t = now()
	return weather ~= nil and t >= weather.startsAt and t < weather.endsAt
end

function Threats.biteMult()
	return weatherActive() and GLASS.biteMult or 1
end

function Threats.riptidePaused()
	return weatherActive()
end

-- The first catch during a Glass Calm pays a bait bonus. Returns the line to add to the catch toast.
function Threats.onCatch(player)
	if weatherActive() and not rewarded[player] then
		rewarded[player] = true
		deps.giveBait(player, GLASS.reward.bait, GLASS.reward.count)
		return ("Glass Calm bonus: +%d %s."):format(GLASS.reward.count, Config.BaitById[GLASS.reward.bait].name)
	end
	return nil
end

local function runWeather()
	local nextStart = now() + GLASS.firstAfter
	while true do
		task.wait(math.max(0, nextStart - GLASS.warning - now()))
		weather = { name = GLASS.name, startsAt = nextStart, endsAt = nextStart + GLASS.duration }
		deps.notifyAll(("%s in %d s: the Shoals go still. Bites come 30%% faster and the riptide pauses."):format(GLASS.name, GLASS.warning), "info")
		task.wait(math.max(0, nextStart - now()))
		rewarded = {}
		deps.notifyAll(("%s! For 3 minutes, bites come 30%% faster, the riptide pauses, and your first catch pays +%d %s."):format(GLASS.name, GLASS.reward.count, GLASS.reward.bait), "good")
		task.wait(math.max(0, weather.endsAt - now()))
		weather = nil
		deps.notifyAll(("The %s ends. The riptide is back."):format(GLASS.name), "info")
		nextStart += GLASS.every
	end
end

-- Stinging Anemone Beds ----------------------------------------------------------------------------

local nextSting = {}

local function anemoneTick()
	local beds = {}
	for _, bed in ipairs(CollectionService:GetTagged("TideboundAnemone")) do
		if bed:IsDescendantOf(workspace) then
			table.insert(beds, bed)
		end
	end
	local t = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = deps.exposed(player)
		if root and t >= (nextSting[player] or 0) then
			for _, bed in ipairs(beds) do
				local p = bed.CFrame:PointToObjectSpace(root.Position)
				if math.abs(p.X) < bed.Size.X / 2 + 0.3 and math.abs(p.Z) < bed.Size.Z / 2 + 0.3 and p.Y > -1 and p.Y < 7 then
					nextSting[player] = t + Config.Anemone.tick
					deps.damage(player, Config.Anemone.damage, bed.Position, "Stinging Anemone")
					break
				end
			end
		end
	end
end

function Threats.init(dependencies)
	deps = dependencies
	local folder = Instance.new("Folder")
	folder.Name = "Elites"
	folder.Parent = deps.delta
	-- Patch 10: dens are tagged by ShoalsBuilder on the Open Isles (sorted by name so indices stay stable)
	local dens = CollectionService:GetTagged("TideboundEliteDen")
	table.sort(dens, function(a, b)
		return a.Name < b.Name
	end)
	for _, den in ipairs(dens) do
		if den:IsA("BasePart") then
			local holes = {}
			for _, child in ipairs(den:GetChildren()) do
				if child:GetAttribute("Hole") then
					table.insert(holes, child)
				end
			end
			table.sort(holes, function(a, b)
				return a.Name < b.Name
			end)
			local elite = {
				index = #elites + 1,
				den = den,
				center = Vector3.new(den.Position.X, TOP, den.Position.Z),
				radius = den:GetAttribute("Radius") or 12,
				holes = holes,
				folder = folder,
			}
			elites[elite.index] = elite
			spawnElite(elite)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for _, elite in ipairs(elites) do
			if elite.kind == BRUTE then
				updateBrute(elite, dt, t)
			else
				updateMoray(elite, t)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			anemoneTick()
		end
	end)

	-- Re-roll a den's elite after 5 quiet minutes, so the 70/30 pool shows over a session.
	task.spawn(function()
		while true do
			task.wait(5)
			local t = os.clock()
			for _, elite in ipairs(elites) do
				if #exposedNear(elite.center, 90) > 0 then
					elite.idleSince = t
				elseif t - elite.idleSince > 300 and (elite.state == "wander" or elite.state == "hidden") then
					spawnElite(elite)
				end
			end
		end
	end)

	task.spawn(runWeather)
	Players.PlayerRemoving:Connect(function(player)
		nextSting[player] = nil
		rewarded[player] = nil
	end)
end

return Threats
