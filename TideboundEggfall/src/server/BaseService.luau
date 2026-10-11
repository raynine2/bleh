-- Tidebound: Eggfall: Home Nest plots (Delta Section 7) and the base side of the economy (Section 11).
-- Owns plot assignment, zone unlocks and upgrades, aquarium income, storage and duplicate sales, the
-- creature displays, visitors (privacy, guestbook, Admire) and the Leaderboard Hall.
-- Nothing banked here can ever be stolen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local CreatureModels = require(Shared:WaitForChild("CreatureModels"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlotLayout = require(script.Parent:WaitForChild("PlotLayout"))

local BaseService = {}

local B = Config.Base
local ZONES, UPGRADES = {}, {}
for _, zone in ipairs(B.zones) do
	ZONES[zone.id] = zone
end
for _, upgrade in ipairs(B.upgrades) do
	UPGRADES[upgrade.id] = upgrade
end

local deps = nil -- { delta = Folder, notify = function(player, text, kind), push = function(player) }
local plots = {} -- [index] = { model, origin, owner = Player? }
local plotOf = {} -- [Player] = index
local cache = setmetatable({}, { __mode = "k" }) -- [data] = income and sale numbers, rebuilt on change
local dirtyDisplay = {} -- [index] = true while a display rebuild is queued
local friendCache = {} -- ["a:b"] = boolean
local visitedThisSession = {} -- [index] = { [userId] = true }
local MAX_TANK_MODELS = 30

BaseService.boards = { rarest = {}, streak = {}, heat = {}, hatched = {} }

local function fmt(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- Upgrades ------------------------------------------------------------------------------------

function BaseService.value(data, id)
	local upgrade = UPGRADES[id]
	local level = math.clamp(data.levels[id] or 1, 1, #upgrade.values)
	return upgrade.values[level], level
end

function BaseService.walkSpeed(data)
	return (BaseService.value(data, "treadmill"))
end

function BaseService.incubatorSlots(data)
	return (BaseService.value(data, "incubators"))
end

function BaseService.storageCap(data)
	local cap = BaseService.value(data, "aquarium")
	if data.zones.vault then
		cap += BaseService.value(data, "vault")
	end
	return math.max(B.baseStorage, cap)
end

-- Income: the top N creatures by value earn 1% of their value per minute, times the Tank Filter,
-- Legendary+ trophies (+1% each, up to +10%) and a fed pen (+5% for 30 min).
local function sortedByValue(data)
	local list = table.clone(data.aquarium)
	table.sort(list, function(a, b)
		return a.v > b.v
	end)
	return list
end

local function rebuildCache(data)
	local sorted = sortedByValue(data)
	local capacity = BaseService.value(data, "aquarium")
	local baseIncome = 0
	for i = 1, math.min(#sorted, capacity) do
		baseIncome += sorted[i].v * B.incomePct
	end
	local trophies = 0
	if data.zones.trophy then
		local pedestals = BaseService.value(data, "trophy")
		for _, creature in ipairs(sorted) do
			if creature.t >= 5 and trophies < pedestals then
				trophies += 1
			end
		end
	end
	-- duplicate sale preview: keep the earning creatures and the best copy of every creature, sell the rest
	local keepBest, saleCount, salePearls = {}, 0, 0
	for i, creature in ipairs(sorted) do
		if i <= capacity or not keepBest[creature.c] then
			keepBest[creature.c] = true
		else
			saleCount += 1
			salePearls += math.floor(creature.v * B.duplicateSellPct)
		end
	end
	local entry = { sorted = sorted, baseIncome = baseIncome, trophies = trophies, earning = math.min(#sorted, capacity), saleCount = saleCount, salePearls = salePearls }
	cache[data] = entry
	return entry
end

local function cached(data)
	return cache[data] or rebuildCache(data)
end

function BaseService.income(data)
	local c = cached(data)
	local filter = (BaseService.value(data, "filter")) / 100
	local trophy = math.min(c.trophies * B.trophyBonusPerLegendary, B.trophyBonusCap)
	local fed = (data.zones.pen and (data.fedUntil or 0) > os.time()) and B.feedBonus or 0
	local perMin = c.baseIncome * (1 + filter + trophy + fed)
	return perMin, { base = c.baseIncome, filter = filter, trophy = trophy, fed = fed, earning = c.earning, trophies = c.trophies }
end

-- Overflow beyond storage is sold at half value (the Duplicate sales faucet). Returns Pearls paid.
function BaseService.enforceStorage(data)
	local cap = BaseService.storageCap(data)
	if #data.aquarium <= cap then
		return 0, 0
	end
	table.sort(data.aquarium, function(a, b)
		return a.v > b.v
	end)
	local pearls, count = 0, 0
	while #data.aquarium > cap do
		local creature = table.remove(data.aquarium)
		pearls += math.floor(creature.v * B.duplicateSellPct)
		count += 1
	end
	data.pearls += pearls
	return pearls, count
end

-- State for the client's BASE tab.
function BaseService.state(player, data)
	local perMin, parts = BaseService.income(data)
	local c = cached(data)
	return {
		plot = plotOf[player],
		zones = data.zones,
		levels = data.levels,
		incomePerMin = perMin,
		income = parts,
		storage = #data.aquarium,
		storageCap = BaseService.storageCap(data),
		saleCount = c.saleCount,
		salePearls = c.salePearls,
		fedUntil = data.zones.pen and data.fedUntil or 0,
		privacy = data.settings.privacy,
		guestbook = data.guestbook,
		incubators = BaseService.incubatorSlots(data),
	}
end

-- Displays ----------------------------------------------------------------------------------------

local function clearChildren(parent, name)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name then
			child:Destroy()
		end
	end
end

local function setText(guiParent, guiName, text)
	local gui = guiParent and guiParent:FindFirstChild(guiName, true)
	local labelInst = gui and gui:FindFirstChildOfClass("TextLabel")
	if labelInst then
		labelInst.Text = text
	end
end

local function lockLabel(adornee, title, subtitle)
	clearChildren(adornee, "LockLabel")
	if not title then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockLabel"
	gui.Size = UDim2.new(0, 220, 0, 46)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	for i, text in ipairs({ title, subtitle }) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, i == 1 and 26 or 18)
		l.Position = UDim2.new(0, 0, 0, i == 1 and 0 or 26)
		l.Font = i == 1 and Enum.Font.FredokaOne or Enum.Font.BuilderSansBold
		l.TextScaled = true
		l.Text = text or ""
		l.TextColor3 = i == 1 and Color3.fromRGB(255, 110, 120) or Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0
		l.Parent = gui
	end
	gui.Parent = adornee
end

local function lockText(zoneId)
	local zone = ZONES[zoneId]
	if zone.requires then
		return "LOCKED", ("%s Pearls + %s"):format(fmt(zone.cost), zone.requires)
	end
	return "LOCKED", fmt(zone.cost) .. " Pearls · open the HOME menu"
end

local function placeCreature(folder, creature, cframe, scale, tag, attributes)
	local model = CreatureModels.build(creature.t, creature.m, cframe, scale)
	model.Name = creature.c
	for key, value in pairs(attributes or {}) do
		model:SetAttribute(key, value)
	end
	if tag then
		CollectionService:AddTag(model, tag)
	end
	model.Parent = folder
	return model
end

local function refreshPlot(index)
	dirtyDisplay[index] = nil
	local plot = plots[index]
	if not plot then
		return
	end
	local model, origin = plot.model, plot.origin
	local display = model:FindFirstChild("Display")
	if not display then
		return
	end
	display:ClearAllChildren()
	local owner = plot.owner
	local data = owner and PlayerData.get(owner)

	setText(model, "OwnerText", owner and (("%s'S NEST · %s"):format(owner.DisplayName:upper(), data and data.settings.privacy:upper() or "")) or ("HOME NEST %d · OPEN"):format(index))

	for id in pairs(PlotLayout.rooms) do
		local room = model:FindFirstChild("Room_" .. id)
		local door = room and room:FindFirstChild("Door")
		if door then
			local locked = data ~= nil and not data.zones[id]
			door.Transparency = locked and 0.55 or 1
			door.CanCollide = locked
			if locked then
				lockLabel(door, lockText(id))
			else
				lockLabel(door, nil)
			end
		end
	end
	local function outdoorLabel(partName, zoneId)
		local p = model:FindFirstChild(partName, true)
		if p then
			if data and not data.zones[zoneId] then
				lockLabel(p, lockText(zoneId))
			else
				lockLabel(p, nil)
			end
		end
	end
	outdoorLabel("Trough", "pen")
	outdoorLabel("VaultDoor", "vault")
	outdoorLabel("Guestbook", "deck")

	if not data then
		setText(model, "StreakText", "STREAK 0")
		setText(model, "GuestText", "GUESTBOOK")
		return
	end

	local sorted = cached(data).sorted

	-- Aquarium Hall: the earning creatures swim in the tank (client animates TideboundSwimmer)
	local tank = model:FindFirstChild("Tank", true)
	if tank then
		local count = math.min(#sorted, BaseService.value(data, "aquarium"), MAX_TANK_MODELS)
		local half = tank.Size / 2 - Vector3.new(1.6, 1.4, 1.4)
		local rng = Random.new(index * 97)
		for i = 1, count do
			local offset = Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
			local home = tank.CFrame * CFrame.new(offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			placeCreature(display, sorted[i], home, 2.2, "TideboundSwimmer", { Home = home, Range = half, Seed = rng:NextNumber(0, 100) })
		end
	end

	-- Creature Pen: roamers wander the lawn (client animates TideboundRoamer)
	if data.zones.pen then
		local seen, roamers = {}, {}
		local wanted = BaseService.value(data, "pen")
		for _, creature in ipairs(sorted) do
			if #roamers >= wanted then
				break
			end
			if not seen[creature.c] then
				seen[creature.c] = true
				table.insert(roamers, creature)
			end
		end
		local centre = (origin * CFrame.new(PlotLayout.pen.pos)).Position
		local rng = Random.new(index * 31)
		for i, creature in ipairs(roamers) do
			local a = i / #roamers * math.pi * 2
			local at = centre + Vector3.new(math.cos(a) * 7, 2, math.sin(a) * 7)
			placeCreature(display, creature, CFrame.new(at), 3, "TideboundRoamer", { Centre = centre + Vector3.new(0, 2, 0), Radius = PlotLayout.pen.radius - 3, Seed = rng:NextNumber(0, 100) })
		end
	end

	-- Trophy Room: Legendary+ creatures on pedestals under tier-coloured spotlights
	local trophyRoom = model:FindFirstChild("Room_trophy")
	if data.zones.trophy and trophyRoom then
		local roomCf = PlotLayout.roomCFrame(origin, PlotLayout.rooms.trophy)
		local pedestals = BaseService.value(data, "trophy")
		local legendaries = {}
		for _, creature in ipairs(sorted) do
			if creature.t >= 5 then
				table.insert(legendaries, creature)
			end
		end
		for i = 1, pedestals do
			local row, col = math.floor((i - 1) / 8), (i - 1) % 8
			local cf = roomCf * CFrame.new(-8.4 + col * 2.4, 0.6, 4 - row * 3.4)
			local pedestal = Instance.new("Part")
			pedestal.Name = "Pedestal"
			pedestal.Anchored = true
			pedestal.Size = Vector3.new(1.8, 1.6, 1.8)
			pedestal.CFrame = cf * CFrame.new(0, 0.8, 0)
			pedestal.Color = Color3.fromRGB(206, 208, 214)
			pedestal.Material = Enum.Material.SmoothPlastic
			pedestal.Parent = display
			local creature = legendaries[i]
			if creature then
				placeCreature(display, creature, cf * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.pi, 0), 1.6)
				local spot = Instance.new("SpotLight")
				spot.Face = Enum.NormalId.Top
				spot.Color = Config.Tiers[creature.t].color
				spot.Brightness = 3
				spot.Range = 8
				spot.Parent = pedestal
			end
		end
	end
	setText(model, "StreakText", ("CLEAN STREAK %d · BEST %d"):format(data.stats.cleanStreak, data.stats.bestStreak))

	-- Showcase Plinth: the best creature, seen from the hub
	local plinth = model:FindFirstChild("Plinth")
	if plinth then
		if data.zones.deck and sorted[1] then
			placeCreature(display, sorted[1], plinth.CFrame * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.pi, 0), 3)
			lockLabel(plinth, nil)
		elseif not data.zones.deck then
			lockLabel(plinth, "SHOWCASE", "Unlocks with the Visitor Deck")
		end
	end

	-- Hatch Chamber: one straw nest per incubator slot, with an egg in each while you have eggs
	local hatchRoom = model:FindFirstChild("Room_hatch")
	if hatchRoom then
		local roomCf = PlotLayout.roomCFrame(origin, PlotLayout.rooms.hatch)
		for i = 1, BaseService.incubatorSlots(data) do
			local cf = roomCf * CFrame.new(-7.5 + ((i - 1) % 4) * 5, 0.9, -2 - math.floor((i - 1) / 4) * 4)
			local nest = Instance.new("Part")
			nest.Name = "IncubatorNest"
			nest.Anchored = true
			nest.Shape = Enum.PartType.Cylinder
			nest.Size = Vector3.new(0.6, 3, 3)
			nest.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
			nest.Color = Color3.fromRGB(232, 200, 110)
			nest.Parent = display
			if data.eggs >= i then
				local egg = Instance.new("Part")
				egg.Name = "WaitingEgg"
				egg.Anchored = true
				egg.CanCollide = false
				egg.Size = Vector3.new(1.6, 2.1, 1.6)
				egg.CFrame = cf * CFrame.new(0, 1.3, 0)
				egg.Color = Color3.fromRGB(248, 236, 210)
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = egg
				egg.Parent = display
			end
		end
	end

	-- Rod Workshop: every owned rod hangs on the rack
	if data.zones.workshop then
		local roomCf = PlotLayout.roomCFrame(origin, PlotLayout.rooms.workshop)
		local colors = { Color3.fromRGB(74, 70, 74), Color3.fromRGB(230, 90, 100), Color3.fromRGB(80, 120, 230), Color3.fromRGB(60, 40, 110), Color3.fromRGB(255, 120, 220), Color3.fromRGB(140, 255, 250) }
		for i, rod in ipairs(Config.Rods) do
			if data.ownedRods[rod.id] then
				local stick = Instance.new("Part")
				stick.Name = "RackRod"
				stick.Anchored = true
				stick.CanCollide = false
				stick.Size = Vector3.new(0.35, 6, 0.35)
				stick.CFrame = roomCf * CFrame.new(-6 + (i - 1) * 2.4, 4.2, PlotLayout.rooms.workshop.size.Z / 2 - 1.8) * CFrame.Angles(0, 0, math.rad(8))
				stick.Color = colors[i]
				stick.Material = rod.id == "Celestial" and Enum.Material.Neon or Enum.Material.SmoothPlastic
				stick.Parent = display
			end
		end
	end

	local guests = { "GUESTBOOK" }
	for _, name in ipairs(data.guestbook) do
		table.insert(guests, name)
	end
	if #guests == 1 then
		table.insert(guests, "No visitors yet")
	end
	setText(model, "GuestText", table.concat(guests, "\n"))
end

function BaseService.refresh(player)
	local index = plotOf[player]
	if index and not dirtyDisplay[index] then
		dirtyDisplay[index] = true
		task.delay(0.25, refreshPlot, index)
	end
end

-- Call after anything that changes a player's creatures, zones or levels.
function BaseService.changed(player)
	local data = PlayerData.get(player)
	if data then
		cache[data] = nil
	end
	BaseService.refresh(player)
end

-- Plots -------------------------------------------------------------------------------------------

function BaseService.plotOrigin(player)
	local index = plotOf[player]
	return index and plots[index].origin
end

function BaseService.assign(player)
	for index = 1, #plots do
		if not plots[index].owner then
			plots[index].owner = player
			plotOf[player] = index
			visitedThisSession[index] = {}
			BaseService.changed(player)
			return index
		end
	end
	return nil
end

function BaseService.release(player)
	local index = plotOf[player]
	plotOf[player] = nil
	if index then
		plots[index].owner = nil
		visitedThisSession[index] = {}
		refreshPlot(index)
	end
end

-- Offline aquarium income: 50% of the online rate, up to 8 hours.
function BaseService.offlineIncome(player, data)
	if (data.lastSeen or 0) <= 0 then
		return 0
	end
	local seconds = math.clamp(os.time() - data.lastSeen, 0, B.offlineCapHours * 3600)
	local perMin = BaseService.income(data)
	local pearls = math.floor(perMin * seconds / 60 * B.offlineRate)
	if pearls > 0 then
		data.pearls += pearls
		deps.notify(player, ("Your aquarium earned %s Pearls while you were away (50%% rate, up to 8 h)."):format(fmt(pearls)), "good")
	end
	return pearls
end

-- Handlers (called from Main's Request remote) -----------------------------------------------------

local handlers = {}

function handlers.UnlockZone(player, data, zoneId)
	local zone = type(zoneId) == "string" and ZONES[zoneId]
	if not zone then
		return { error = "Unknown zone." }
	end
	if data.zones[zoneId] then
		return { error = zone.name .. " is already unlocked." }
	end
	if zone.requires then
		return { error = ("%s needs %s."):format(zone.name, zone.requires) }
	end
	if data.pearls < zone.cost then
		return { error = ("%s costs %s Pearls."):format(zone.name, fmt(zone.cost)) }
	end
	data.pearls -= zone.cost
	data.zones[zoneId] = true
	deps.notify(player, ("Unlocked the %s!"):format(zone.name), "good")
	BaseService.changed(player)
	return { ok = true }
end

function handlers.Upgrade(player, data, upgradeId)
	local upgrade = type(upgradeId) == "string" and UPGRADES[upgradeId]
	if not upgrade then
		return { error = "Unknown upgrade." }
	end
	local _, level = BaseService.value(data, upgradeId)
	if level >= #upgrade.values then
		return { error = upgrade.name .. " is maxed." }
	end
	if not upgrade.free and not data.zones[upgrade.zone] then
		return { error = ("Unlock the %s first."):format(ZONES[upgrade.zone].name) }
	end
	if upgrade.needs and (data.levels[upgrade.needs.id] or 1) < upgrade.needs.level then
		return { error = ("Needs %s level %d."):format(UPGRADES[upgrade.needs.id].name, upgrade.needs.level) }
	end
	local cost = upgrade.costs[level]
	if data.pearls < cost then
		return { error = ("%s costs %s Pearls."):format(upgrade.name, fmt(cost)) }
	end
	data.pearls -= cost
	data.levels[upgradeId] = level + 1
	deps.notify(player, ("%s: %s → %s %s"):format(upgrade.name, fmt(upgrade.values[level]), fmt(upgrade.values[level + 1]), upgrade.unit), "good")
	BaseService.changed(player)
	return { ok = true }
end

function handlers.SellDuplicates(player, data)
	local c = cached(data)
	if c.saleCount == 0 then
		return { error = "Nothing to sell. Earning creatures and the best copy of each are always kept." }
	end
	local capacity = BaseService.value(data, "aquarium")
	local keepBest, keep, pearls, count = {}, {}, 0, 0
	for i, creature in ipairs(c.sorted) do
		if i <= capacity or not keepBest[creature.c] then
			keepBest[creature.c] = true
			table.insert(keep, creature)
		else
			pearls += math.floor(creature.v * B.duplicateSellPct)
			count += 1
		end
	end
	data.aquarium = keep
	data.pearls += pearls
	deps.notify(player, ("Sold %d duplicate creature(s) for %s Pearls."):format(count, fmt(pearls)), "good")
	BaseService.changed(player)
	return { ok = true }
end

function handlers.SetPrivacy(player, data, privacy)
	if not table.find(B.privacy, privacy) then
		return { error = "Unknown setting." }
	end
	data.settings.privacy = privacy
	BaseService.refresh(player)
	return { ok = true }
end

BaseService.handlers = handlers

-- Prompts in plots ----------------------------------------------------------------------------------

local function plotFromPrompt(prompt)
	local node = prompt
	while node and node.Parent ~= deps.delta:FindFirstChild("Plots") do
		node = node.Parent
	end
	return node and node:GetAttribute("Index")
end

function BaseService.onFeed(player, prompt)
	local index = plotFromPrompt(prompt)
	local data = PlayerData.get(player)
	if not index or not data then
		return
	end
	if plots[index].owner ~= player then
		deps.notify(player, "Only the owner can feed these creatures. Try Admire on the Showcase Plinth!", "info")
		return
	end
	if not data.zones.pen then
		deps.notify(player, ("Unlock the Creature Pen first (%s Pearls)."):format(fmt(ZONES.pen.cost)), "info")
		return
	end
	if (data.fedUntil or 0) > os.time() then
		deps.notify(player, ("They're still full for %d min."):format(math.ceil((data.fedUntil - os.time()) / 60)), "info")
		return
	end
	data.fedUntil = os.time() + B.feedMinutes * 60
	deps.notify(player, "Fed the pen! +5% aquarium income for 30 min.", "good")
	deps.push(player)
end

function BaseService.onAdmire(player, prompt)
	local index = plotFromPrompt(prompt)
	local plot = index and plots[index]
	local owner = plot and plot.owner
	if not owner then
		deps.notify(player, "This plot is free. Nobody to admire yet.", "info")
		return
	end
	if owner == player then
		deps.notify(player, "Visitors can Admire your showcase to give you Egg Shards.", "info")
		return
	end
	local data = PlayerData.get(owner)
	if not data or not data.zones.deck then
		deps.notify(player, "Their Visitor Deck isn't open yet.", "info")
		return
	end
	local today = math.floor(os.time() / 86400)
	if data.admires.day ~= today then
		data.admires = { day = today, count = 0, visitors = {} }
	end
	local key = tostring(player.UserId)
	if data.admires.visitors[key] then
		deps.notify(player, "You already admired this showcase today.", "info")
		return
	end
	if data.admires.count >= B.admireDailyCap then
		deps.notify(player, "This showcase has been admired 10 times today!", "info")
		return
	end
	data.admires.visitors[key] = true
	data.admires.count += 1
	data.shards += B.admireShards
	deps.notify(player, ("You admired %s's showcase."):format(owner.DisplayName), "good")
	deps.notify(owner, ("%s admired your showcase! +1 Egg Shard."):format(player.DisplayName), "good")
	deps.push(owner)
end

-- Travel between the Nest plaza, the Harbor Ring and your plot. Only from a safe zone, so it can't
-- be used to escape a run with a haul.
function BaseService.travel(player, destination)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return { error = "No character." }
	end
	if not Config.safeZone(root.Position) then
		return { error = "Travel works from the Nest or the Harbor Ring. Extract at a beacon first." }
	end
	local target
	if destination == "Nest" then
		target = Config.World.spawnCFrame
	elseif destination == "Harbor" then
		local h = Config.Harbor.center
		target = CFrame.lookAt(Vector3.new(h.X, 10, h.Z + 48), Vector3.new(h.X, 10, h.Z))
	elseif destination == "Home" then
		local origin = BaseService.plotOrigin(player)
		if not origin then
			return { error = "Every Home Nest on this server is taken." }
		end
		target = origin * CFrame.new(PlotLayout.arrival + Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.pi, 0)
	else
		return { error = "Unknown destination." }
	end
	character:PivotTo(target)
	return { ok = true }
end

-- Visitors: privacy, guestbook ------------------------------------------------------------------

local function isFriend(a, b)
	local key = a.UserId < b.UserId and (a.UserId .. ":" .. b.UserId) or (b.UserId .. ":" .. a.UserId)
	if friendCache[key] == nil then
		friendCache[key] = false
		task.spawn(function()
			local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
			friendCache[key] = ok and result == true
		end)
	end
	return friendCache[key]
end

local function visitorTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for index, plot in ipairs(plots) do
				local owner = plot.owner
				if owner and owner ~= player and PlotLayout.contains(plot.origin, root.Position) then
					local data = PlayerData.get(owner)
					local privacy = data and data.settings.privacy or "Public"
					local allowed = privacy == "Public" or (privacy == "Friends" and isFriend(owner, player))
					if not allowed then
						player.Character:PivotTo(plot.origin * CFrame.new(0, 4, -PlotLayout.SIZE / 2 - 8) * CFrame.Angles(0, math.pi, 0))
						deps.notify(player, ("%s's nest is %s."):format(owner.DisplayName, privacy == "Friends" and "friends only" or "private"), "info")
					elseif data and not visitedThisSession[index][player.UserId] then
						visitedThisSession[index][player.UserId] = true
						table.insert(data.guestbook, 1, player.DisplayName)
						while #data.guestbook > B.guestbookSize do
							table.remove(data.guestbook)
						end
						deps.notify(owner, ("%s is visiting your Home Nest."):format(player.DisplayName), "info")
						BaseService.refresh(owner)
					end
				end
			end
		end
	end
end

-- Leaderboard Hall: this server's boards, refreshed every 10 s ------------------------------------

local function updateBoards()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(player)
		if data then
			table.insert(rows, { name = player.DisplayName, data = data })
		end
	end
	local function top(scoreOf, describe)
		table.sort(rows, function(a, b)
			return scoreOf(a.data) > scoreOf(b.data)
		end)
		local out = {}
		for i = 1, math.min(5, #rows) do
			if scoreOf(rows[i].data) > 0 then
				table.insert(out, { name = rows[i].name, text = describe(rows[i].data) })
			end
		end
		return out
	end
	BaseService.boards = {
		rarest = top(function(d)
			return d.stats.bestHatchValue or 0
		end, function(d)
			return ("%s (%s Pearls)"):format(d.stats.bestHatch, fmt(d.stats.bestHatchValue))
		end),
		streak = top(function(d)
			return d.stats.bestStreak or 0
		end, function(d)
			return ("%d clean extractions"):format(d.stats.bestStreak)
		end),
		heat = top(function(d)
			return d.stats.bestHeatExtract or 0
		end, function(d)
			return ("extracted at Heat %d"):format(d.stats.bestHeatExtract)
		end),
		hatched = top(function(d)
			return d.stats.hatched or 0
		end, function(d)
			return ("%s hatched"):format(fmt(d.stats.hatched))
		end),
	}
	local lines = { "THIS SERVER'S BOARDS" }
	for _, board in ipairs({ { "RAREST HATCH", "rarest" }, { "LONGEST STREAK", "streak" }, { "HIGHEST HEAT EXTRACTED", "heat" } }) do
		table.insert(lines, "")
		table.insert(lines, board[1])
		local entries = BaseService.boards[board[2]]
		if #entries == 0 then
			table.insert(lines, "  nobody yet")
		end
		for i = 1, math.min(3, #entries) do
			table.insert(lines, ("  %d. %s · %s"):format(i, entries[i].name, entries[i].text))
		end
	end
	setText(deps.delta:FindFirstChild("HarborRing"), "BoardText", table.concat(lines, "\n"))
end

function BaseService.init(dependencies)
	deps = dependencies
	local folder = deps.delta:WaitForChild("Plots")
	for _, model in ipairs(folder:GetChildren()) do
		local index = model:GetAttribute("Index")
		if index then
			plots[index] = { model = model, origin = model:GetAttribute("Origin"), owner = nil }
		end
	end
	for index in ipairs(plots) do
		visitedThisSession[index] = {}
		refreshPlot(index)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			visitorTick()
		end
	end)
	task.spawn(function()
		while true do
			updateBoards()
			task.wait(10)
		end
	end)
end

return BaseService
