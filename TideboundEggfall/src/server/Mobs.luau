-- Tidebound: Eggfall: wild mobs of the Open Isles (Patch 10). Camps of Snapper Crabs, Spike Puffers, Raider Gulls
-- and Coral Golems sit on the islands (IslesLayout.camps) and in Kelp Cathedral (IslesLayout.kelpCamps); Reef
-- Sharks patrol open water (IslesLayout.sharkWaters) and only bite swimmers. Unlike the elites they fight back
-- and can be beaten: a rod swipe (Config.Swipe) knocks them back, and enough swipes pop them for bait.
-- Every attack is telegraphed (the client shows a red "!", or a ring on the ground for blasts) and damage grows
-- with your heat. The server thinks; each mob is a Configuration in ReplicatedStorage.Tidebound.MobState whose
-- attributes (Kind, Pos, Yaw, State, StateAt, Hp, TellPos...) TideboundMobs draws on every screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local L = require(Shared:WaitForChild("IslesLayout"))

local Mobs = {}

local M = Config.Mobs
local TICK = 0.1
local WATER_Y = L.WATER_Y

-- { world, notify, exposed(player) -> root?, damage(player, amount, fromPos, label), heatOf(player), giveBait(player, baitId, count) }
local deps = nil
local rng = Random.new()
local camps = {}
local mobs = {}
local stateFolder = nil
local lastAggro = {} -- [Player] = os.clock() a mob last went for them
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- The walkable height under (x, z), searching down from `fromY`; nil over open water.
local function groundAt(position, fromY)
	local origin = Vector3.new(position.X, fromY, position.Z)
	for _ = 1, 4 do
		local result = workspace:Raycast(origin, Vector3.new(0, -120, 0), rayParams)
		if not result then
			return nil
		end
		local hit = result.Instance
		if hit:IsA("BasePart") and hit.CanCollide then
			return result.Position.Y
		end
		origin = result.Position - Vector3.new(0, 0.05, 0)
	end
	return nil
end

-- Camps and mobs ------------------------------------------------------------------------------------------------

local function newMob(kind, camp, home)
	local cfg = M.kinds[kind]
	local inst = Instance.new("Configuration")
	inst.Name = "Mob" .. (#mobs + 1)
	local mob = {
		id = #mobs + 1,
		kind = kind,
		cfg = cfg,
		camp = camp,
		home = home,
		pos = home,
		yaw = rng:NextNumber(0, math.pi * 2),
		state = "idle",
		stateAt = 0,
		hp = cfg.hp,
		target = nil,
		readyAt = 0,
		wander = nil,
		wanderAt = 0,
		orbit = rng:NextNumber(0, math.pi * 2),
		inst = inst,
		sent = {},
	}
	inst:SetAttribute("Kind", kind)
	inst:SetAttribute("Title", cfg.name)
	inst:SetAttribute("MaxHp", cfg.hp)
	inst:SetAttribute("Hp", cfg.hp)
	inst:SetAttribute("State", "idle")
	inst:SetAttribute("StateAt", 0)
	inst:SetAttribute("Pos", home)
	inst:SetAttribute("Yaw", mob.yaw)
	inst:SetAttribute("Kelp", camp.kelp == true)
	inst.Parent = stateFolder
	table.insert(mobs, mob)
	table.insert(camp.mobs, mob)
	return mob
end

local function send(mob, key, value)
	if mob.sent[key] ~= value then
		mob.sent[key] = value
		mob.inst:SetAttribute(key, value)
	end
end

local function setState(mob, state)
	mob.state = state
	mob.stateAt = now()
	send(mob, "State", state)
	send(mob, "StateAt", mob.stateAt)
end

-- Where a land mob may stand: on its camp's island (or within its camp in the Kelp).
local function clampLand(mob, p)
	local camp = mob.camp
	local island = camp.island
	if island then
		local d = flat(p) - island.pos
		local inner = island.feature == "lagoon" and island.r * 0.45 + 2 or 0
		local outer = island.r - 3
		local m = d.Magnitude
		if m > outer then
			p = island.pos + d.Unit * outer + Vector3.new(0, p.Y, 0)
		elseif m < inner and m > 0.01 then
			p = island.pos + d.Unit * inner + Vector3.new(0, p.Y, 0)
		end
	else
		local d = flat(p) - flat(camp.center)
		local limit = camp.radius + 16
		if d.Magnitude > limit then
			p = flat(camp.center) + d.Unit * limit + Vector3.new(0, p.Y, 0)
		end
	end
	return p
end

local function heightFor(mob, p)
	local kind = mob.kind
	local camp = mob.camp
	if kind == "shark" then
		return WATER_Y - 0.6
	end
	local ground = groundAt(p, camp.rayFrom) or (camp.kelp and camp.center.Y or WATER_Y)
	if kind == "gull" then
		local diving = mob.state == "dive"
		return diving and p.Y or math.max(ground, WATER_Y) + mob.cfg.height
	elseif kind == "puffer" then
		return math.max(ground, camp.kelp and ground or WATER_Y) + 2.6 + 0.4 * math.sin(os.clock() * 2 + mob.id)
	end
	return ground
end

local function moveToward(mob, goal, speed, dt)
	local d = flat(goal) - flat(mob.pos)
	local m = d.Magnitude
	if m < 0.05 then
		return 0
	end
	local stepLen = math.min(m, speed * dt)
	local p = mob.pos + d.Unit * stepLen
	if mob.kind == "crab" or mob.kind == "golem" then
		p = clampLand(mob, p)
	elseif mob.kind == "shark" then
		-- sharks keep to open water: a beach shelf or a shore stops them (bridges pass overhead)
		local below = groundAt(p, WATER_Y + 1)
		if below and below > WATER_Y - 1.5 then
			return m
		end
	end
	p = Vector3.new(p.X, heightFor(mob, p), p.Z)
	mob.pos = p
	mob.yaw = math.atan2(-d.X, -d.Z)
	return m - stepLen
end

local function spawnCamp(spec, kelp)
	local center = spec.at
	local island = not kelp and L.island(center) or nil
	local camp = {
		center = center,
		radius = spec.radius,
		island = island,
		kelp = kelp,
		rayFrom = kelp and Config.Kelp.center.Y + 40 or 80,
		mobs = {},
		awake = false,
	}
	if kelp then
		camp.center = Vector3.new(center.X, Config.Kelp.center.Y, center.Z)
	end
	for kind, count in pairs(spec.mobs) do
		for _ = 1, count do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(2, spec.radius * 0.7)
			local home = Vector3.new(center.X + math.cos(a) * d, 0, center.Z + math.sin(a) * d)
			local mob = newMob(kind, camp, home)
			if kind == "crab" or kind == "golem" then
				mob.home = clampLand(mob, home)
			end
		end
	end
	table.insert(camps, camp)
	return camp
end

local function placeHome(mob)
	local p = mob.home
	mob.pos = Vector3.new(p.X, heightFor(mob, p), p.Z)
	mob.home = mob.pos
end

-- Targets -------------------------------------------------------------------------------------------------------

local function swimming(root)
	return root.Position.Y < WATER_Y + 2.5 and Config.zoneOf(root.Position) == "Shoals"
end

local function canTarget(mob, root)
	local inKelp = Config.zoneOf(root.Position) == "Kelp"
	if (mob.camp.kelp == true) ~= inKelp then
		return false
	end
	if mob.kind == "shark" then
		return swimming(root)
	end
	return true
end

local function pickTarget(mob, exposed)
	local best, bestD = nil, mob.cfg.aggro
	for player, root in pairs(exposed) do
		if canTarget(mob, root) then
			local d = (root.Position - mob.pos).Magnitude
			if mob.kind == "gull" then
				d = (flat(root.Position) - flat(mob.pos)).Magnitude
			end
			local leash = mob.cfg.leash or (mob.camp.radius + 30)
			if d < bestD and (flat(root.Position) - flat(mob.camp.center)).Magnitude < leash + 10 then
				best, bestD = player, d
			end
		end
	end
	return best
end

local function scaled(mob, player)
	local heat = deps.heatOf(player) or 0
	return math.floor(mob.cfg.damage * (1 + heat / 100 * M.heatDamage) + 0.5)
end

local function hit(mob, player, from)
	deps.damage(player, scaled(mob, player), from, mob.cfg.name)
end

local function blast(mob, center, radius, exposed)
	for player, root in pairs(exposed) do
		if canTarget(mob, root) and (root.Position - center).Magnitude <= radius + 1.5 then
			hit(mob, player, center)
		end
	end
end

-- Thinking ------------------------------------------------------------------------------------------------------

local function wanderStep(mob, dt, t)
	local cfg = mob.cfg
	if mob.kind == "gull" then
		mob.orbit += dt * 0.6
		local r = math.max(8, mob.camp.radius * 0.6)
		local goal = flat(mob.camp.center) + Vector3.new(math.cos(mob.orbit) * r, 0, math.sin(mob.orbit) * r)
		moveToward(mob, goal, cfg.speed * 0.6, dt)
		return
	end
	if mob.kind == "shark" then
		mob.orbit += dt * 0.18
		local r = mob.camp.radius * 0.65
		local goal = flat(mob.camp.center) + Vector3.new(math.cos(mob.orbit + mob.id) * r, 0, math.sin(mob.orbit + mob.id) * r)
		moveToward(mob, goal, cfg.speed * 0.7, dt)
		return
	end
	if not mob.wander or t > mob.wanderAt then
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, mob.camp.radius * 0.8)
		mob.wander = flat(mob.camp.center) + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		mob.wanderAt = t + rng:NextNumber(2.5, 6)
	end
	moveToward(mob, mob.wander, cfg.speed * 0.35, dt)
end

local function think(mob, dt, t, exposed)
	local cfg = mob.cfg
	local state = mob.state
	local since = now() - mob.stateAt
	if state == "dead" then
		return
	end
	if state == "hurt" then
		if since >= 0.35 then
			setState(mob, mob.target and "chase" or "idle")
		end
		return
	end

	-- keep (or drop) the target
	local target, root = mob.target, nil
	if target then
		root = exposed[target]
		local leash = cfg.leash or (mob.camp.radius + 30)
		if not root or not canTarget(mob, root) or (flat(root.Position) - flat(mob.camp.center)).Magnitude > leash + 14 then
			target, root = nil, nil
			mob.target = nil
			if state ~= "tell" and state ~= "dive" then
				setState(mob, "return")
				state = "return"
			end
		end
	end
	if not target and (state == "idle" or state == "return") then
		target = pickTarget(mob, exposed)
		if target then
			mob.target = target
			root = exposed[target]
			setState(mob, "chase")
			state = "chase"
		end
	end
	if target then
		lastAggro[target] = os.clock()
	end

	if state == "idle" then
		wanderStep(mob, dt, t)
	elseif state == "return" then
		local left = moveToward(mob, mob.home, cfg.speed, dt)
		if mob.kind == "gull" or mob.kind == "shark" or left < 1 then
			mob.hp = cfg.hp
			send(mob, "Hp", mob.hp)
			setState(mob, "idle")
		end
	elseif state == "chase" and root then
		local d = (root.Position - mob.pos).Magnitude
		local ready = t >= mob.readyAt
		if mob.kind == "crab" or mob.kind == "shark" then
			if d <= cfg.reach and ready then
				setState(mob, "tell")
			else
				moveToward(mob, root.Position, mob.kind == "shark" and cfg.chaseSpeed or cfg.speed, dt)
			end
		elseif mob.kind == "puffer" or mob.kind == "golem" then
			if d <= cfg.trigger and ready then
				send(mob, "TellPos", mob.pos)
				setState(mob, "tell")
			else
				moveToward(mob, root.Position, cfg.speed, dt)
			end
		elseif mob.kind == "gull" then
			-- circle over the target, then wind up a dive
			mob.orbit += dt * 1.4
			local goal = flat(root.Position) + Vector3.new(math.cos(mob.orbit) * 10, 0, math.sin(mob.orbit) * 10)
			moveToward(mob, goal, cfg.speed, dt)
			if ready and (flat(root.Position) - flat(mob.pos)).Magnitude < 16 then
				setState(mob, "tell")
			end
		end
	elseif state == "tell" then
		if root then
			local d = flat(root.Position) - flat(mob.pos)
			if d.Magnitude > 0.1 and mob.kind ~= "puffer" then
				mob.yaw = math.atan2(-d.X, -d.Z)
			end
		end
		if since >= cfg.tell then
			if mob.kind == "crab" or mob.kind == "shark" then
				-- the snap: lands if you're still in reach
				if root and (root.Position - mob.pos).Magnitude <= cfg.reach + 1.5 then
					hit(mob, target, mob.pos)
				end
				mob.readyAt = t + cfg.cooldown
				setState(mob, "strike")
			elseif mob.kind == "puffer" or mob.kind == "golem" then
				blast(mob, mob.inst:GetAttribute("TellPos") or mob.pos, cfg.radius, exposed)
				mob.readyAt = t + cfg.cooldown
				setState(mob, "strike")
			elseif mob.kind == "gull" then
				local aim = root and root.Position or mob.pos
				send(mob, "TellPos", aim)
				mob.diveTo = aim
				setState(mob, "dive")
			end
		end
	elseif state == "dive" then
		-- the gull plunges at where you stood when it screeched
		local goal = mob.diveTo or mob.pos
		local d = goal - mob.pos
		local stepLen = math.min(d.Magnitude, cfg.diveSpeed * dt)
		if d.Magnitude > 0.05 then
			mob.pos += d.Unit * stepLen
			mob.yaw = math.atan2(-d.X, -d.Z)
		end
		if d.Magnitude < 1.5 or since > 1.4 then
			for player, r in pairs(exposed) do
				if canTarget(mob, r) and (r.Position - mob.pos).Magnitude <= cfg.reach + 1.5 then
					hit(mob, player, mob.pos)
				end
			end
			mob.readyAt = t + cfg.cooldown
			setState(mob, "strike")
		end
	elseif state == "strike" then
		if mob.kind == "gull" then
			-- climb back up
			local p = mob.pos
			local up = math.max(groundAt(p, mob.camp.rayFrom) or WATER_Y, WATER_Y) + cfg.height
			mob.pos = Vector3.new(p.X, p.Y + (up - p.Y) * math.min(1, dt * 2.5), p.Z)
		end
		if since >= (mob.kind == "gull" and 1.4 or mob.kind == "golem" and 1.1 or 0.5) then
			setState(mob, mob.target and "chase" or "return")
		end
	elseif state == "chase" then
		setState(mob, "return")
	end
end

local function respawn(mob)
	mob.hp = mob.cfg.hp
	mob.target = nil
	mob.pos = mob.home
	send(mob, "Hp", mob.hp)
	send(mob, "Pos", mob.pos)
	setState(mob, "idle")
	mob.inst:SetAttribute("SpawnAt", now())
end

local function sleep(camp)
	camp.awake = false
	for _, mob in ipairs(camp.mobs) do
		if mob.state ~= "dead" then
			mob.target = nil
			mob.hp = mob.cfg.hp
			mob.pos = mob.home
			send(mob, "Hp", mob.hp)
			send(mob, "Pos", mob.pos)
			setState(mob, "idle")
		end
	end
end

local function tick(dt)
	local t = os.clock()
	local exposed = {}
	local characters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(characters, player.Character)
		end
		local root = deps.exposed(player)
		if root then
			exposed[player] = root
		end
	end
	rayParams.FilterDescendantsInstances = characters
	for _, camp in ipairs(camps) do
		local near = false
		for _, root in pairs(exposed) do
			local inKelp = Config.zoneOf(root.Position) == "Kelp"
			if inKelp == (camp.kelp == true) and (flat(root.Position) - flat(camp.center)).Magnitude < M.wakeRange then
				near = true
				break
			end
		end
		if near then
			camp.awake = true
			for _, mob in ipairs(camp.mobs) do
				local ok, err = pcall(think, mob, dt, t, exposed)
				if not ok then
					warn("[Mobs]", err)
					setState(mob, "idle")
				end
				send(mob, "Pos", Vector3.new(math.floor(mob.pos.X * 10) / 10, math.floor(mob.pos.Y * 10) / 10, math.floor(mob.pos.Z * 10) / 10))
				send(mob, "Yaw", math.floor(mob.yaw * 50) / 50)
			end
		elseif camp.awake then
			sleep(camp)
		end
	end
end

-- API -----------------------------------------------------------------------------------------------------------

function Mobs.init(dependencies)
	deps = dependencies
	stateFolder = Shared:FindFirstChild("MobState")
	if stateFolder then
		stateFolder:ClearAllChildren()
	else
		stateFolder = Instance.new("Folder")
		stateFolder.Name = "MobState"
		stateFolder.Parent = Shared
	end
	for _, spec in ipairs(L.camps) do
		spawnCamp(spec, false)
	end
	for _, spec in ipairs(L.kelpCamps) do
		spawnCamp(spec, true)
	end
	for _, water in ipairs(L.sharkWaters) do
		spawnCamp({ at = water.at, radius = water.radius, mobs = { shark = 2 } }, false)
	end
	-- settle everyone onto the ground once the world has finished building
	for _, mob in ipairs(mobs) do
		placeHome(mob)
		send(mob, "Pos", mob.pos)
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local t = os.clock()
			tick(math.min(t - last, 0.3))
			last = t
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAggro[player] = nil
		for _, mob in ipairs(mobs) do
			if mob.target == player then
				mob.target = nil
			end
		end
	end)
end

-- A rod swipe from `player`: every living mob in front of them within reach takes a hit and is knocked back.
function Mobs.swipe(player, root)
	local S = Config.Swipe
	local look = flat(root.CFrame.LookVector).Unit
	local hits = 0
	for _, mob in ipairs(mobs) do
		if mob.state ~= "dead" and mob.camp.awake then
			local offset = mob.pos - root.Position
			local d = flat(offset)
			local reach = S.range + (mob.kind == "golem" and 2 or 0)
			if d.Magnitude <= reach and math.abs(offset.Y) < 7 and (d.Magnitude < 2.5 or d.Unit:Dot(look) >= S.cone) then
				hits += 1
				mob.hp -= S.damage
				send(mob, "Hp", mob.hp)
				mob.inst:SetAttribute("HitAt", now())
				mob.target = player
				lastAggro[player] = os.clock()
				if mob.hp <= 0 then
					setState(mob, "dead")
					local drop = M.drop
					if rng:NextNumber() < drop.chance then
						deps.giveBait(player, drop.bait, drop.count)
						deps.notify(player, ("You beat the %s! It dropped %d %s."):format(mob.cfg.name, drop.count, drop.bait), "good")
					end
					task.delay(rng:NextNumber(M.respawn[1], M.respawn[2]), respawn, mob)
				else
					-- knocked back (a golem barely budges), and a wind-up is interrupted
					local push = (d.Magnitude > 0.1 and d.Unit or look) * (mob.kind == "golem" and S.knock * 0.3 or S.knock)
					local p = mob.pos + push
					if mob.kind == "crab" or mob.kind == "golem" then
						p = clampLand(mob, p)
					end
					mob.pos = Vector3.new(p.X, heightFor(mob, p), p.Z)
					if mob.kind ~= "golem" or mob.state ~= "tell" then
						setState(mob, "hurt")
					end
				end
			end
		end
	end
	return hits
end

-- True while a mob has gone for this player recently (out-of-combat healing waits for this to clear).
function Mobs.inCombat(player)
	return os.clock() - (lastAggro[player] or -100) < 6
end

return Mobs
