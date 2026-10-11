-- Tidebound: Eggfall: wild mobs of the Open Isles (Patch 10). Camps of Snapper Crabs, Spike Puffers, Raider Gulls
-- and Coral Golems hold the islands (IslesLayout.camps) and Kelp Cathedral (IslesLayout.kelpCamps), and a Reef
-- Shark patrols each patch of open water (IslesLayout.sharkWaters). Unlike elites they fight back, every attack
-- has a tell first, and a rod swipe hurts them. A beaten mob may drop bait and comes back a minute later.
-- Each mob is one invisible anchored part in TideboundWorld.Mobs, tagged TideboundMob. Its CFrame and attributes
-- (Kind, Variant, MaxHp, Hp, State, TellAt, TellKind, TellRadius, HitAt, DeadAt) are everything TideboundMobs
-- needs to build and animate it. A camp only thinks while a diver is near it; asleep, it costs nothing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Isles = require(Shared:WaitForChild("IslesLayout"))

local Mobs = {}

-- { world, notify(player, text, kind), exposed(player) -> root?, damage(player, amount, fromPos, label), heatOf(player) -> number, giveBait(player, baitId, count) }
local deps = nil
local folder = nil
local rng = Random.new()

local M = Config.Mobs
local SWIPE = Config.Swipe
local WATER_Y = Isles.WATER_Y
local TAG = "TideboundMob"
local TICK = 0.05 -- awake camps think about 20 times a second
local WAKE_EVERY = 0.5 -- how often camps look for divers
local SLEEP_MARGIN = 25 -- a camp falls asleep a little farther out than it wakes
local COMBAT_SECONDS = 6
local MAX_STEP = 3 -- land mobs never step up or down more than this
local SHARK_Y = WATER_Y - 1.5
local SHARK_LEASH = 40 -- how far past its water's radius a shark will chase
local ATTACK_SECONDS = 0.3 -- how long "attack" shows after a tell lands
local INTERRUPT_SECONDS = 0.7 -- a swipe that breaks a crab's or gull's tell leaves it reeling this long
local SWIPE_HEIGHT = 7 -- a swipe reaches mobs this far above or below your root (cruising gulls are out of reach)
local DIVE_OVERSHOOT = 12 -- a gull's dive carries on this far past where you stood
local HEAT_AGGRO = 1.2 -- aggro range multiplier at Config.Heat.hazardAt and up
local KIND_ORDER = { "crab", "puffer", "gull", "shark", "golem" }
local TELLS = { crab = "snap", puffer = "blast", gull = "dive", shark = "bite", golem = "slam" }
local STEER = { 0, 0.8, -0.8, 1.6, -1.6 } -- turns (radians) a chasing mob tries when the way ahead is blocked
local SWIM_STEER = { 0, 0.7, -0.7 }

-- The invisible part's size, how high its centre rides above its walk height, extra swipe reach for its bulk,
-- and how long it stays in "recover" after an attack (nil: the puffer recovers for its whole cooldown).
local BODY = {
	crab = { size = Vector3.new(4, 2.4, 3.6), lift = 1.2, pad = 1, recover = 0.6 },
	puffer = { size = Vector3.new(3.2, 3.2, 3.2), lift = 2.5, pad = 1, recover = nil },
	gull = { size = Vector3.new(5, 1.6, 3), lift = 0, pad = 1, recover = nil },
	shark = { size = Vector3.new(3, 3, 9), lift = 0, pad = 2, recover = 0.8 },
	golem = { size = Vector3.new(6, 7, 4.5), lift = 3.5, pad = 1.5, recover = 1.2 },
}

local camps = {}
local exposed = {} -- this tick's divers: { player, root, pos, heat, swimming }
local lastCombat = {} -- [Player] = server time a mob last attacked or chased them
local awakeCount = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local filtered = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Distance from p to the segment a-b (a diving gull covers several studs a tick).
local function segmentDistance(p, a, b)
	local ab = b - a
	local length2 = ab:Dot(ab)
	if length2 < 1e-6 then
		return (p - a).Magnitude
	end
	local s = math.clamp((p - a):Dot(ab) / length2, 0, 1)
	return (p - (a + ab * s)).Magnitude
end

-- Attributes only replicate when they change.
local function setAttr(mob, name, value)
	if mob.attrs[name] ~= value then
		mob.attrs[name] = value
		mob.part:SetAttribute(name, value)
	end
end

local function setState(mob, state)
	mob.state = state
	setAttr(mob, "State", state)
end

-- Moves the part to the mob's position, facing `look` (a dive pitches the gull down).
local function pose(mob)
	local look = mob.look
	local level = Vector3.new(look.X, 0, look.Z)
	if level.Magnitude < 0.15 then
		-- straight up or down: keep a little of the last heading so lookAt stays well defined
		look = mob.heading * 0.3 + Vector3.new(0, look.Y, 0)
	else
		mob.heading = level.Unit
	end
	local cf = CFrame.lookAt(mob.pos, mob.pos + look)
	if cf ~= mob.cf then
		mob.cf = cf
		mob.part.CFrame = cf
	end
end

local function face(mob, toward)
	local d = flat(toward - mob.pos)
	if d.Magnitude > 0.05 then
		mob.look = d.Unit
	end
end

-- Ground ------------------------------------------------------------------------------------------------------

-- The first solid thing below `from` within `length` (passes through non-collidable decor like vines and leaves).
local function castDown(from, length)
	for _ = 1, 4 do
		local hit = workspace:Raycast(from, Vector3.new(0, -length, 0), rayParams)
		if not hit then
			return nil
		end
		if hit.Instance.CanCollide then
			return hit
		end
		local drop = from.Y - hit.Position.Y + 0.05
		length -= drop
		if length <= 0 then
			return nil
		end
		from -= Vector3.new(0, drop, 0)
	end
	return nil
end

-- Walk height at (x, z), or nil over water. Kelp Cathedral has no sea, so any floor counts there.
local function landAt(camp, x, z, fromY, length)
	local hit = castDown(Vector3.new(x, fromY, z), length)
	if not hit then
		return nil
	end
	local y = hit.Position.Y
	if not camp.kelp and y < WATER_Y + 0.5 then
		return nil
	end
	return y
end

-- A wall, trunk or pillar in the way, above step height.
local function wallAhead(mob, dir, distance)
	local origin = Vector3.new(mob.pos.X, mob.ground + MAX_STEP + 0.5, mob.pos.Z)
	local hit = workspace:Raycast(origin, dir * (distance + mob.body.pad), rayParams)
	return hit ~= nil and hit.Instance.CanCollide
end

-- One step for a land mob: never onto water, off a ledge or up a wall. Returns true if it moved.
local function tryStep(mob, dir, distance)
	local x, z = mob.pos.X + dir.X * distance, mob.pos.Z + dir.Z * distance
	local y = landAt(mob.camp, x, z, mob.ground + 8, 8 + MAX_STEP + 1)
	if not y or math.abs(y - mob.ground) > MAX_STEP or wallAhead(mob, dir, distance) then
		return false
	end
	mob.ground = y
	mob.pos = Vector3.new(x, y + mob.body.lift, z)
	return true
end

-- Walks toward `goal` (flat). With `steer`, tries angled steps around an obstacle. Returns false when blocked.
local function walk(mob, goal, speed, dt, steer)
	local offset = flat(goal - mob.pos)
	local distance = offset.Magnitude
	if distance < 0.1 then
		return true
	end
	local stepLength = math.min(distance, speed * dt)
	local dir = offset / distance
	for i = 1, steer and #STEER or 1 do
		local d = i == 1 and dir or CFrame.Angles(0, STEER[i], 0) * dir
		if tryStep(mob, d, stepLength) then
			mob.look = d
			return true
		end
	end
	return false
end

-- A shark's move: level at SHARK_Y, inside its water, never into the shallows.
local function swimStep(mob, goal, maxDistance)
	local offset = flat(goal - mob.pos)
	local distance = offset.Magnitude
	if distance < 0.05 then
		return true
	end
	local dir = offset / distance
	local stepLength = math.min(distance, maxDistance)
	local camp = mob.camp
	for _, turn in ipairs(SWIM_STEER) do
		local d = turn == 0 and dir or CFrame.Angles(0, turn, 0) * dir
		local to = Vector3.new(mob.pos.X + d.X * stepLength, SHARK_Y, mob.pos.Z + d.Z * stepLength)
		if flatDistance(to, camp.center) <= camp.radius + SHARK_LEASH and not castDown(to + Vector3.new(0, 1, 0), 2.5) then
			mob.pos = to
			mob.look = d
			return true
		end
	end
	return false
end

local function randomPoint(camp, scale)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(rng:NextNumber()) * camp.radius * scale
	return Vector3.new(camp.center.X + math.cos(a) * r, camp.center.Y, camp.center.Z + math.sin(a) * r)
end

-- A spot on land in the camp, preferring the island's walk height (not a treetop or a rock).
local function findSpot(camp)
	local ref = camp.center.Y
	local fallback = nil
	for _ = 1, 12 do
		local p = randomPoint(camp, 0.85)
		local y
		if camp.kelp then
			y = landAt(camp, p.X, p.Z, ref + 6, 26)
		else
			y = landAt(camp, p.X, p.Z, ref + 120, 160)
		end
		if y then
			local spot = Vector3.new(p.X, y, p.Z)
			if math.abs(y - ref) <= 4 then
				return spot
			end
			fallback = fallback or spot
		end
	end
	return fallback
end

-- The ground or the sea under a gull, whichever is higher.
local function gullBase(camp, x, z)
	local hit = castDown(Vector3.new(x, camp.center.Y + 120, z), 160)
	local y = hit and hit.Position.Y or WATER_Y
	return math.clamp(y, WATER_Y, camp.center.Y + 30)
end

-- Gulls and sharks follow a wobbly loop round their camp.
local function orbitPoint(mob, y)
	local c = mob.camp.center
	local r = mob.orbitR * (1 + 0.15 * math.sin(mob.angle * 3 + mob.seed))
	return Vector3.new(c.X + math.cos(mob.angle) * r, y, c.Z + math.sin(mob.angle) * r)
end

-- Moves toward its loop and along it. Returns how far it still is from the loop.
local function orbitStep(mob, dt, speed, y)
	local goal = orbitPoint(mob, y)
	local offset = goal - mob.pos
	local distance = offset.Magnitude
	if distance < 8 then
		mob.angle += mob.spin * speed * dt / mob.orbitR
	end
	if distance > 0.05 then
		mob.pos += offset / distance * math.min(distance, speed * dt)
		mob.look = offset / distance
	end
	return distance
end

-- Life and death --------------------------------------------------------------------------------------------

local function spawnMob(mob, t)
	local camp, kind = mob.camp, mob.kind
	mob.hp = mob.cfg.hp
	mob.target = nil
	mob.returning = false
	mob.wanderTo = nil
	mob.stuckFor = 0
	mob.cooldownUntil = t + rng:NextNumber(0.5, 1.5)
	mob.pauseUntil = t + rng:NextNumber(0.5, 2.5)
	mob.unplaced = false
	if kind == "gull" or kind == "shark" then
		mob.angle = rng:NextNumber(0, math.pi * 2)
		if kind == "gull" then
			local p = orbitPoint(mob, 0)
			mob.base = gullBase(camp, p.X, p.Z)
			mob.baseGoal = mob.base
			mob.pos = Vector3.new(p.X, mob.base + mob.cfg.height, p.Z)
		else
			mob.pos = orbitPoint(mob, SHARK_Y)
		end
		mob.look = Vector3.new(-math.sin(mob.angle), 0, math.cos(mob.angle)) * mob.spin
	else
		local spot = findSpot(camp)
		if not spot then
			-- the island isn't there yet (or this camp sits in the sea): try again when the camp wakes
			spot = camp.center
			mob.unplaced = true
		end
		mob.ground = spot.Y
		mob.pos = spot + Vector3.new(0, mob.body.lift, 0)
		local a = rng:NextNumber(0, math.pi * 2)
		mob.look = Vector3.new(math.cos(a), 0, math.sin(a))
	end
	pose(mob)
	setAttr(mob, "Hp", mob.hp)
	setState(mob, "idle")
end

local function kill(mob, player, t)
	mob.hp = 0
	mob.target = nil
	mob.returning = false
	mob.respawnAt = t + rng:NextNumber(M.respawn[1], M.respawn[2])
	setState(mob, "dead")
	setAttr(mob, "DeadAt", t)
	local drop = M.drop
	if rng:NextNumber() < drop.chance then
		deps.giveBait(player, drop.bait, drop.count)
		local bait = Config.BaitById[drop.bait]
		deps.notify(player, ("%s dropped %d %s!"):format(mob.cfg.name, drop.count, bait and bait.name or drop.bait), "good")
	end
end

-- Damage grows with the diver's heat.
local function hurt(mob, e, t)
	local amount = math.floor(mob.cfg.damage * (1 + e.heat / 100 * M.heatDamage) + 0.5)
	lastCombat[e.player] = t
	task.spawn(deps.damage, e.player, amount, mob.pos, mob.cfg.name)
end

-- TellKind and TellRadius go out before TellAt, so the client reads them when TellAt changes.
local function startTell(mob, t)
	mob.untilAt = t + mob.cfg.tell
	setAttr(mob, "TellKind", TELLS[mob.kind])
	setAttr(mob, "TellRadius", mob.cfg.radius or 0)
	setState(mob, "tell")
	setAttr(mob, "TellAt", t)
	if mob.target then
		lastCombat[mob.target] = t
	end
end

-- Targets -----------------------------------------------------------------------------------------------------

-- The mob's target, if it is still a diver near this camp.
local function targetEntry(mob)
	local player = mob.target
	if not player then
		return nil
	end
	local e = mob.camp.nearBy[player]
	if not e then
		mob.target = nil
	end
	return e
end

-- Sharks only notice divers in the water: low, with no land just under them.
local function swimming(e)
	if e.swimming == nil then
		e.swimming = e.pos.Y < WATER_Y + 1.5 and castDown(e.pos, 4) == nil
	end
	return e.swimming
end

-- The closest diver within aggro (flat), within `vertical` up or down, and within `fromCenter` of the camp.
local function nearest(mob, vertical, fromCenter, needSwim)
	local camp, cfg = mob.camp, mob.cfg
	local best, bestDistance = nil, math.huge
	for _, e in ipairs(camp.near) do
		local range = cfg.aggro * (e.heat >= Config.Heat.hazardAt and HEAT_AGGRO or 1)
		local d = flatDistance(e.pos, mob.pos)
		if d <= range and d < bestDistance and math.abs(e.pos.Y - mob.pos.Y) <= vertical and flatDistance(e.pos, camp.center) <= fromCenter and (not needSwim or swimming(e)) then
			best, bestDistance = e, d
		end
	end
	return best
end

local function goHome(mob)
	mob.target = nil
	mob.returning = true
	mob.stuckFor = 0
	mob.wanderTo = nil
end

-- Land mobs: crab, puffer, golem ------------------------------------------------------------------------------

local function wander(mob, dt, t)
	local cfg, camp = mob.cfg, mob.camp
	if mob.returning then
		setState(mob, "wander")
		if flatDistance(mob.pos, camp.center) <= camp.radius * 0.6 then
			mob.returning = false
			mob.pauseUntil = t + rng:NextNumber(0.5, 1.5)
		elseif walk(mob, camp.center, cfg.speed * 0.8, dt, true) then
			mob.stuckFor = 0
		else
			mob.stuckFor += dt
			if mob.stuckFor > 4 then
				mob.returning = false
			end
		end
		return
	end
	if t < mob.pauseUntil then
		setState(mob, "idle")
		return
	end
	if not mob.wanderTo then
		mob.wanderTo = randomPoint(camp, 0.9)
	end
	setState(mob, "wander")
	if not walk(mob, mob.wanderTo, math.max(3, cfg.speed * 0.45), dt, false) or flatDistance(mob.pos, mob.wanderTo) < 0.5 then
		mob.wanderTo = nil
		mob.pauseUntil = t + rng:NextNumber(1, 3.5)
	end
end

-- The tell is over: a crab snaps at its target, a puffer blasts and a golem slams everyone in the radius.
local function landStrike(mob, t)
	local cfg, kind = mob.cfg, mob.kind
	mob.cooldownUntil = t + cfg.cooldown
	if kind == "crab" then
		local e = targetEntry(mob)
		if e and flatDistance(e.pos, mob.pos) <= cfg.reach + 1.5 and math.abs(e.pos.Y - mob.pos.Y) <= 6 then
			hurt(mob, e, t)
		end
	else
		for _, e in ipairs(mob.camp.near) do
			local inside
			if kind == "puffer" then
				inside = (e.pos - mob.pos).Magnitude <= cfg.radius
			else
				-- a ground shockwave: jump it
				inside = flatDistance(e.pos, mob.pos) <= cfg.radius and math.abs(e.pos.Y - (mob.ground + 3)) <= 5
			end
			if inside then
				hurt(mob, e, t)
			end
		end
	end
	mob.untilAt = t + ATTACK_SECONDS
	setState(mob, "attack")
end

local function updateLand(mob, dt, t)
	local cfg, camp = mob.cfg, mob.camp
	local state = mob.state
	if state == "tell" then
		-- it stands its ground and turns to follow you
		local e = targetEntry(mob)
		if e then
			face(mob, e.pos)
		end
		if t >= mob.untilAt then
			landStrike(mob, t)
		end
		return
	elseif state == "attack" then
		if t >= mob.untilAt then
			mob.untilAt = t + (mob.body.recover or math.max(0.2, cfg.cooldown - ATTACK_SECONDS))
			setState(mob, "recover")
		end
		return
	elseif state == "recover" then
		if t >= mob.untilAt then
			setState(mob, targetEntry(mob) and "chase" or "idle")
		end
		return
	end
	local leash = cfg.leash or camp.radius + 20
	local e = targetEntry(mob)
	if e and (flatDistance(mob.pos, camp.center) > leash or flatDistance(e.pos, camp.center) > leash + 6) then
		goHome(mob)
		e = nil
	end
	if not e and not mob.returning then
		e = nearest(mob, 10, leash, false)
		if e then
			mob.target = e.player
		end
	end
	if not e then
		wander(mob, dt, t)
		return
	end
	lastCombat[e.player] = t
	setState(mob, "chase")
	local d = flatDistance(e.pos, mob.pos)
	local strike = cfg.reach or cfg.trigger
	if d <= strike and t >= mob.cooldownUntil then
		face(mob, e.pos)
		startTell(mob, t)
		return
	end
	if d > strike * 0.7 then
		walk(mob, e.pos, cfg.speed, dt, true)
	end
	face(mob, e.pos)
end

-- Raider Gull ---------------------------------------------------------------------------------------------------

local function startDive(mob, t)
	local offset = mob.aim and mob.aim - mob.pos
	if not offset or offset.Magnitude < 1 then
		mob.cooldownUntil = t + mob.cfg.cooldown
		setState(mob, "recover")
		return
	end
	mob.diveDir = offset.Unit
	mob.diveLeft = offset.Magnitude + DIVE_OVERSHOOT
	mob.diveFloor = mob.aim.Y
	mob.diveHit = {}
	mob.look = mob.diveDir
	setState(mob, "attack")
end

local function diveStep(mob, dt, t)
	local cfg = mob.cfg
	local from = mob.pos
	local stepLength = math.min(cfg.diveSpeed * dt, mob.diveLeft)
	local to = from + mob.diveDir * stepLength
	if to.Y < mob.diveFloor then
		-- past where you stood: skim on at that height
		to = Vector3.new(to.X, mob.diveFloor, to.Z)
		local level = flat(mob.diveDir)
		if level.Magnitude > 0.05 then
			mob.diveDir = level.Unit
		end
	end
	mob.diveLeft -= stepLength
	mob.pos = to
	mob.look = mob.diveDir
	for _, e in ipairs(mob.camp.near) do
		if not mob.diveHit[e.player] and segmentDistance(e.pos, from, to) <= cfg.reach then
			mob.diveHit[e.player] = true
			hurt(mob, e, t)
		end
	end
	if mob.diveLeft <= 0 then
		mob.cooldownUntil = t + cfg.cooldown
		mob.target = nil
		setState(mob, "recover")
	end
end

local function updateGull(mob, dt, t)
	local cfg, camp = mob.cfg, mob.camp
	-- its cruising height follows the island or the sea below, a couple of rays a second
	if t >= mob.nextGround then
		mob.nextGround = t + rng:NextNumber(0.5, 0.8)
		mob.baseGoal = gullBase(camp, mob.pos.X, mob.pos.Z)
	end
	mob.base += (mob.baseGoal - mob.base) * math.min(1, dt * 1.5)
	local cruise = mob.base + cfg.height + math.sin(t * 1.3 + mob.seed) * 1.2
	local state = mob.state
	if state == "tell" then
		-- hovering and shrieking, watching where you go
		local e = targetEntry(mob)
		if e then
			mob.aim = e.pos
			face(mob, e.pos)
		end
		if t >= mob.untilAt then
			startDive(mob, t)
		end
		return
	elseif state == "attack" then
		diveStep(mob, dt, t)
		return
	elseif state == "recover" then
		-- climbs back up to its loop
		if orbitStep(mob, dt, cfg.speed * 0.8, cruise) < 4 then
			setState(mob, "wander")
		end
		return
	end
	setState(mob, "wander")
	orbitStep(mob, dt, cfg.speed, cruise)
	if t >= mob.cooldownUntil then
		local e = nearest(mob, cfg.height + 24, camp.radius + cfg.aggro, false)
		if e then
			mob.target = e.player
			mob.aim = e.pos
			face(mob, e.pos)
			startTell(mob, t)
		end
	end
end

-- Reef Shark ------------------------------------------------------------------------------------------------------

local function updateShark(mob, dt, t)
	local cfg, camp = mob.cfg, mob.camp
	local state = mob.state
	local e = targetEntry(mob)
	if e and (not swimming(e) or flatDistance(mob.pos, camp.center) > camp.radius + SHARK_LEASH) then
		mob.target = nil
		e = nil
	end
	if state == "tell" then
		-- jaws open, still closing in
		if e then
			swimStep(mob, e.pos, cfg.speed * 0.4 * dt)
			face(mob, e.pos)
		end
		if t >= mob.untilAt then
			mob.cooldownUntil = t + cfg.cooldown
			if e and flatDistance(e.pos, mob.pos) <= cfg.reach + 1.5 and math.abs(e.pos.Y - mob.pos.Y) <= 6 then
				hurt(mob, e, t)
			end
			mob.untilAt = t + ATTACK_SECONDS
			setState(mob, "attack")
		end
		return
	elseif state == "attack" then
		if t >= mob.untilAt then
			mob.untilAt = t + mob.body.recover
			setState(mob, "recover")
		end
		return
	elseif state == "recover" then
		-- peels away, then comes round again
		if e then
			local away = flat(mob.pos - e.pos)
			if away.Magnitude > 0.05 then
				swimStep(mob, mob.pos + away.Unit * 4, cfg.speed * dt)
			end
		end
		if t >= mob.untilAt then
			setState(mob, e and "chase" or "wander")
		end
		return
	end
	if not e then
		e = nearest(mob, 8, camp.radius + SHARK_LEASH, true)
		if e then
			mob.target = e.player
		end
	end
	if not e then
		setState(mob, "wander")
		orbitStep(mob, dt, cfg.speed, SHARK_Y)
		return
	end
	lastCombat[e.player] = t
	setState(mob, "chase")
	local d = flatDistance(e.pos, mob.pos)
	if d <= cfg.reach and t >= mob.cooldownUntil then
		face(mob, e.pos)
		startTell(mob, t)
		return
	end
	if d > cfg.reach * 0.6 then
		swimStep(mob, e.pos, cfg.chaseSpeed * dt)
	end
	face(mob, e.pos)
end

local UPDATE = { crab = updateLand, puffer = updateLand, golem = updateLand, gull = updateGull, shark = updateShark }

-- Camps ------------------------------------------------------------------------------------------------------------

local function wake(camp, t)
	camp.awake = true
	awakeCount += 1
	for _, mob in ipairs(camp.mobs) do
		if mob.unplaced and mob.state ~= "dead" then
			spawnMob(mob, t)
		end
	end
end

-- Asleep, a camp calms down; a land mob that strayed is quietly put back (no diver is near enough to see).
local function sleep(camp, t)
	camp.awake = false
	awakeCount -= 1
	table.clear(camp.near)
	table.clear(camp.nearBy)
	for _, mob in ipairs(camp.mobs) do
		if mob.state ~= "dead" then
			mob.target = nil
			mob.returning = false
			mob.wanderTo = nil
			mob.pauseUntil = t
			local land = mob.kind ~= "gull" and mob.kind ~= "shark"
			if land and flatDistance(mob.pos, camp.center) > camp.radius + 4 then
				spawnMob(mob, t)
			elseif mob.kind == "gull" then
				-- a gull caught mid-dive goes back up to its loop
				mob.pos = orbitPoint(mob, mob.base + mob.cfg.height)
				mob.look = mob.heading
				pose(mob)
			end
			setState(mob, "idle")
		end
	end
end

local function gather()
	table.clear(exposed)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = deps.exposed(player)
		if root then
			local heat = deps.heatOf and deps.heatOf(player) or 0
			table.insert(exposed, { player = player, root = root, pos = root.Position, heat = tonumber(heat) or 0 })
		end
	end
end

-- Rays skip the mobs and every character; the list only changes when characters do.
local function refreshFilter()
	local list = { folder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local same = #list == #filtered
	if same then
		for i, inst in ipairs(list) do
			if filtered[i] ~= inst then
				same = false
				break
			end
		end
	end
	if not same then
		filtered = list
		rayParams.FilterDescendantsInstances = list
	end
end

local function wakeCheck(t)
	for _, camp in ipairs(camps) do
		local range = camp.wake + (camp.awake and SLEEP_MARGIN or 0)
		local near = false
		for _, e in ipairs(exposed) do
			if (e.pos - camp.center).Magnitude <= range then
				near = true
				break
			end
		end
		if near and not camp.awake then
			wake(camp, t)
		elseif not near and camp.awake then
			sleep(camp, t)
		end
	end
end

local function thinkCamp(camp, dt, t)
	table.clear(camp.near)
	table.clear(camp.nearBy)
	local range = camp.wake + SLEEP_MARGIN
	for _, e in ipairs(exposed) do
		if (e.pos - camp.center).Magnitude <= range then
			table.insert(camp.near, e)
			camp.nearBy[e.player] = e
		end
	end
	for _, mob in ipairs(camp.mobs) do
		if mob.state == "dead" then
			if t >= mob.respawnAt then
				spawnMob(mob, t)
			end
		else
			UPDATE[mob.kind](mob, dt, t)
			pose(mob)
		end
	end
end

local wakeClock = 0
local function step(dt)
	wakeClock -= dt
	local due = wakeClock <= 0
	if awakeCount == 0 and not due then
		return
	end
	local t = now()
	gather()
	if due then
		wakeClock = WAKE_EVERY
		refreshFilter()
		wakeCheck(t)
	end
	for _, camp in ipairs(camps) do
		if camp.awake then
			thinkCamp(camp, dt, t)
		end
	end
end

local function newMob(camp, kind, t)
	local cfg = M.kinds[kind]
	local body = BODY[kind]
	local part = Instance.new("Part")
	part.Name = (camp.variant == "Kelp" and "Kelp" or "") .. (string.gsub(cfg.name, " ", ""))
	part.Size = body.size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local mob = {
		kind = kind,
		cfg = cfg,
		body = body,
		camp = camp,
		part = part,
		attrs = {},
		state = "",
		hp = cfg.hp,
		pos = camp.center,
		ground = camp.center.Y,
		look = Vector3.new(0, 0, -1),
		heading = Vector3.new(0, 0, -1),
		untilAt = 0,
		cooldownUntil = 0,
		pauseUntil = 0,
		respawnAt = 0,
		stuckFor = 0,
		seed = rng:NextNumber(0, 100),
		spin = rng:NextNumber() < 0.5 and -1 or 1,
		angle = 0,
		-- a shark's loop stays well inside its water (clear of the islands near its edge)
		orbitR = camp.radius * (kind == "shark" and rng:NextNumber(0.35, 0.5) or rng:NextNumber(0.55, 0.95)),
		base = WATER_Y,
		baseGoal = WATER_Y,
		nextGround = 0,
	}
	setAttr(mob, "Kind", kind)
	setAttr(mob, "Variant", camp.variant)
	setAttr(mob, "MaxHp", cfg.hp)
	setAttr(mob, "TellAt", 0)
	setAttr(mob, "TellKind", "")
	setAttr(mob, "TellRadius", 0)
	setAttr(mob, "HitAt", 0)
	setAttr(mob, "DeadAt", 0)
	spawnMob(mob, t)
	CollectionService:AddTag(part, TAG)
	part.Parent = folder
	table.insert(camp.mobs, mob)
end

local function addCamp(spec, kelp, water)
	local y = kelp and Config.Kelp.center.Y or (water and SHARK_Y or Isles.TOP)
	local camp = {
		center = Vector3.new(spec.at.X, y, spec.at.Z),
		radius = spec.radius,
		kelp = kelp,
		variant = kelp and "Kelp" or "Shoals",
		wake = M.wakeRange + spec.radius, -- within wakeRange of the camp's edge
		reach = spec.radius + 120, -- no mob of this camp is ever farther from its centre than this
		awake = false,
		mobs = {},
		near = {},
		nearBy = {},
	}
	table.insert(camps, camp)
	local t = now()
	for _, kind in ipairs(KIND_ORDER) do
		local count = spec.mobs[kind]
		if count and M.kinds[kind] then
			for _ = 1, count do
				newMob(camp, kind, t)
			end
		end
	end
end

-- Swipes ---------------------------------------------------------------------------------------------------------

local function inSwipe(mob, origin, forward)
	local offset = mob.pos - origin
	local level = flat(offset)
	local reach = SWIPE.range + mob.body.pad
	if mob.kind == "shark" then
		if offset.Magnitude > reach then
			return false
		end
	elseif level.Magnitude > reach or math.abs(offset.Y) > SWIPE_HEIGHT then
		return false
	end
	local distance = level.Magnitude
	return distance < 1.5 or forward:Dot(level / distance) >= SWIPE.cone
end

local function knock(mob, origin)
	local away = flat(mob.pos - origin)
	if away.Magnitude < 0.05 then
		return
	end
	away = away.Unit
	if mob.kind == "gull" then
		mob.pos += away * SWIPE.knock
	elseif mob.kind == "shark" then
		swimStep(mob, mob.pos + away * SWIPE.knock, SWIPE.knock)
	else
		-- in short steps, so it stops at the shore or a ledge
		for _ = 1, 4 do
			if not tryStep(mob, away, SWIPE.knock / 4) then
				break
			end
		end
	end
	face(mob, origin)
	pose(mob)
end

local function hitMob(mob, player, origin, t)
	mob.hp -= SWIPE.damage
	lastCombat[player] = t
	setAttr(mob, "Hp", math.max(0, mob.hp))
	setAttr(mob, "HitAt", t)
	if mob.hp <= 0 then
		kill(mob, player, t)
		return
	end
	knock(mob, origin)
	if mob.state == "tell" and (mob.kind == "crab" or mob.kind == "gull") then
		mob.untilAt = t + INTERRUPT_SECONDS
		mob.cooldownUntil = math.max(mob.cooldownUntil, t + INTERRUPT_SECONDS + 0.4)
		setState(mob, "recover")
	end
	mob.target = player
	mob.returning = false
	if mob.camp.awake and mob.kind ~= "gull" and (mob.state == "idle" or mob.state == "wander") then
		setState(mob, "chase")
	end
end

-- A rod swipe from `root`: hits every live mob in range and in front. Returns how many it hit.
function Mobs.swipe(player, root)
	if not deps or not root then
		return 0
	end
	local t = now()
	local look = root.CFrame.LookVector
	local forward = flat(look)
	forward = forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0, 0, -1)
	local origin = root.Position
	local hits = 0
	for _, camp in ipairs(camps) do
		if (camp.center - origin).Magnitude <= camp.reach then
			for _, mob in ipairs(camp.mobs) do
				if mob.state ~= "dead" and inSwipe(mob, origin, forward) then
					hits += 1
					hitMob(mob, player, origin, t)
				end
			end
		end
	end
	return hits
end

-- True while a mob has attacked or chased this player in the last few seconds (no out-of-combat healing).
function Mobs.inCombat(player)
	local last = lastCombat[player]
	return last ~= nil and now() - last < COMBAT_SECONDS
end

function Mobs.init(dependencies)
	if deps then
		return
	end
	deps = dependencies
	folder = deps.world:FindFirstChild("Mobs")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Mobs"
	folder.Parent = deps.world
	refreshFilter()

	for _, spec in ipairs(Isles.camps) do
		addCamp(spec, false, false)
	end
	for _, spec in ipairs(Isles.kelpCamps) do
		addCamp(spec, true, false)
	end
	for _, water in ipairs(Isles.sharkWaters) do
		addCamp({ at = water.at, radius = water.radius, mobs = { shark = 1 } }, false, true)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK * 0.9 then
			return
		end
		local elapsed = math.min(accumulator, 0.25)
		accumulator = 0
		step(elapsed)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCombat[player] = nil
	end)
end

return Mobs
