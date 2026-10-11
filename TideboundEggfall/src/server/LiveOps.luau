-- Tidebound: Eggfall: retention systems on the server (GDD Sections 6, 10, 12). Daily quests, weekly goals,
-- seasonal events, the season pass, collection goals, cosmetics and the shop, global leaderboards, the
-- MemoryStore pity cache and the player's saved settings. The client only ever displays what this sends and asks
-- for an action; every claim, purchase and value is checked here (Section 10 Table B: server-authoritative UI).
--
-- Saved in the player's existing profile (PlayerData, the PlayerData_<UserId> row of Section 10 Table C):
--   quests (daily), weekly, eventProgress, season, collectionClaimed, cosmetics, settings
-- Leaderboards are the Leaderboard_Coins / Leaderboard_Eggs OrderedDataStores; pity is mirrored to the
-- MemoryStore hash map GlobalPity on every pull and reconciled on join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Biomes = require(Shared:WaitForChild("Biomes"))
local Data = require(Shared:WaitForChild("LiveOpsData"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local LiveOps = {}

local deps = nil -- { notify, push, remotes }
local LiveOpsRemote, PushEvent

-- Rate limiting (Section 10 Table B, Remote Spam): a token bucket per player; a flood far past it is a kick.
local RATE = 8 -- requests per second refilled
local BURST = 16
local KICK_WINDOW, KICK_COUNT = 3, 90
local buckets = {} -- [Player] = { tokens, last, window = { times } }

local function allow(player)
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BURST, last = now, recent = {} }
		buckets[player] = b
	end
	b.tokens = math.min(BURST, b.tokens + (now - b.last) * RATE)
	b.last = now
	table.insert(b.recent, now)
	while b.recent[1] and now - b.recent[1] > KICK_WINDOW do
		table.remove(b.recent, 1)
	end
	if #b.recent > KICK_COUNT then
		player:Kick("Too many requests.")
		return false
	end
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- Profile sections ---------------------------------------------------------------------------------------------

local function dailyOf(data)
	local today = Data.dayNumber()
	if data.quests.day ~= today or type(data.quests.ids) ~= "table" then
		local ids = {}
		for _, q in ipairs(Data.dailyQuests(today)) do
			table.insert(ids, q.id)
		end
		data.quests = { day = today, ids = ids, progress = {}, claimed = {} }
	end
	return data.quests
end

local function weeklyOf(data)
	local week = Data.weekNumber()
	if data.weekly.week ~= week then
		local ids = {}
		for _, q in ipairs(Data.weeklyGoals(week)) do
			table.insert(ids, q.id)
		end
		data.weekly = { week = week, ids = ids, progress = {}, claimed = {} }
	end
	return data.weekly
end

local function eventOf(data)
	local event = Data.activeEvent()
	if not event then
		return nil, nil
	end
	if data.eventProgress.id ~= event.id then
		data.eventProgress = { id = event.id, progress = {}, claimed = {} }
	end
	return event, data.eventProgress
end

local function seasonOf(data)
	local S = Data.season
	if data.season.id ~= S.id then
		data.season = { id = S.id, xp = 0, claimedFree = {}, claimedPremium = {} }
	end
	return data.season
end

local byId = { daily = {}, weekly = {}, event = {}, collection = {} }
for _, q in ipairs(Data.daily.pool) do
	byId.daily[q.id] = q
end
for _, q in ipairs(Data.weekly.pool) do
	byId.weekly[q.id] = q
end
for _, event in ipairs(Data.seasonal) do
	for _, g in ipairs(event.goals) do
		byId.event[g.id] = g
	end
end
for _, list in pairs(Data.collection) do
	for _, g in ipairs(list) do
		byId.collection[g.id] = g
	end
end

local function count(t)
	local n = 0
	for _ in pairs(t or {}) do
		n += 1
	end
	return n
end

local function collectionCounts(data)
	return { creatures = count(data.collection), fish = count(data.bestiary) }
end

-- Premium (cosmetic-only) season track: owned through a game pass, checked once per session.
local premiumCache = {} -- [Player] = boolean
local function hasPremium(player)
	if premiumCache[player] ~= nil then
		return premiumCache[player]
	end
	local passId = Data.season.premiumPassId
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	premiumCache[player] = ok and owns == true
	return premiumCache[player]
end

-- Cosmetics on the character (server-made, so every player sees them) --------------------------------------------

local function applyCosmetics(player)
	local data = PlayerData.get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	for _, name in ipairs({ "TB_CosmeticTrail", "TB_TrailTop", "TB_TrailBottom" }) do
		local old = root and root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local oldTitle = head and head:FindFirstChild("TB_Title")
	if oldTitle then
		oldTitle:Destroy()
	end
	local trail = Data.cosmetics[data.cosmetics.trail]
	if trail and root and data.cosmetics.owned[data.cosmetics.trail] then
		local top = Instance.new("Attachment")
		top.Name = "TB_TrailTop"
		top.Position = Vector3.new(0, 0.9, 0.4)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "TB_TrailBottom"
		bottom.Position = Vector3.new(0, -0.9, 0.4)
		bottom.Parent = root
		local t = Instance.new("Trail")
		t.Name = "TB_CosmeticTrail"
		t.Attachment0, t.Attachment1 = top, bottom
		t.Color = ColorSequence.new(trail.colors[1], trail.colors[2])
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		t.Lifetime = 0.45
		t.LightEmission = 0.6
		t.MinLength = 0.2
		t.FaceCamera = true
		t.Parent = root
	end
	local title = Data.cosmetics[data.cosmetics.title]
	if title and head and data.cosmetics.owned[data.cosmetics.title] then
		local board = Instance.new("BillboardGui")
		board.Name = "TB_Title"
		board.Size = UDim2.fromOffset(200, 26)
		board.StudsOffset = Vector3.new(0, 2.6, 0)
		board.MaxDistance = 90
		board.AlwaysOnTop = false
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = title.name
		label.TextColor3 = title.color
		label.TextStrokeTransparency = 0.2
		label.Parent = board
		board.Parent = head
	end
end

-- Rewards -------------------------------------------------------------------------------------------------------

local function grant(player, data, reward)
	local parts = {}
	if reward.pearls then
		data.pearls += reward.pearls
		table.insert(parts, ("+%d Pearls"):format(reward.pearls))
	end
	if reward.shards then
		data.shards += reward.shards
		table.insert(parts, ("+%d Egg Shards"):format(reward.shards))
	end
	if reward.embers then
		data.embers += reward.embers
		table.insert(parts, ("+%d Run Embers"):format(reward.embers))
	end
	if reward.tideglass then
		data.tideglass += reward.tideglass
		table.insert(parts, ("+%d Tideglass"):format(reward.tideglass))
	end
	if reward.bait and Config.BaitById[reward.bait.id] then
		data.baitInv[reward.bait.id] = (data.baitInv[reward.bait.id] or 0) + reward.bait.count
		table.insert(parts, ("+%d %s"):format(reward.bait.count, Config.BaitById[reward.bait.id].name))
	end
	if reward.cosmetic and Data.cosmetics[reward.cosmetic] then
		data.cosmetics.owned[reward.cosmetic] = true
		table.insert(parts, Data.cosmetics[reward.cosmetic].name)
	end
	if reward.xp then
		LiveOps.addXp(player, data, reward.xp)
		table.insert(parts, ("+%d Season XP"):format(reward.xp))
	end
	return table.concat(parts, ", ")
end

function LiveOps.addXp(player, data, amount)
	if not Data.seasonActive() then
		return
	end
	local season = seasonOf(data)
	local before = Data.seasonTier(season.xp)
	season.xp += amount
	local after = Data.seasonTier(season.xp)
	if after > before and deps then
		deps.notify(player, ("Season tier %d reached! Claim it on the Season Pass."):format(after), "rare")
	end
end

-- The view the client renders ------------------------------------------------------------------------------------

local function questRows(list, section)
	local rows = {}
	for _, id in ipairs(section.ids or {}) do
		local q = list[id]
		if q then
			table.insert(rows, {
				id = q.id, text = q.text, goal = q.goal, event = q.event, reward = q.reward, tier = q.tier,
				progress = math.min(q.goal, section.progress[q.id] or 0), claimed = section.claimed[q.id] == true,
			})
		end
	end
	return rows
end

function LiveOps.dailyView(data)
	local daily = dailyOf(data)
	return { day = daily.day, resetIn = Data.secondsToNextDay(), quests = questRows(byId.daily, daily), progress = daily.progress, claimed = daily.claimed }
end

function LiveOps.view(player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local weekly = weeklyOf(data)
	local event, eventProgress = eventOf(data)
	local season = seasonOf(data)
	local counts = collectionCounts(data)
	local eventView = nil
	if event then
		local rows = {}
		for _, g in ipairs(event.goals) do
			table.insert(rows, {
				id = g.id, text = g.text, goal = g.goal, reward = g.reward, tier = g.tier,
				progress = math.min(g.goal, eventProgress.progress[g.id] or 0), claimed = eventProgress.claimed[g.id] == true,
			})
		end
		eventView = { id = event.id, name = event.name, blurb = event.blurb, color = event.color, endsAt = Data.eventEnds(event), goals = rows }
	end
	local collection = {}
	for kind, list in pairs(Data.collection) do
		local rows = {}
		for _, g in ipairs(list) do
			table.insert(rows, { id = g.id, text = g.text, goal = g.goal, reward = g.reward, tier = g.tier, progress = math.min(g.goal, counts[kind]), claimed = data.collectionClaimed[g.id] == true })
		end
		collection[kind] = { count = counts[kind], goals = rows }
	end
	return {
		now = os.time(),
		daily = LiveOps.dailyView(data),
		weekly = { week = weekly.week, resetIn = Data.secondsToNextWeek(), goals = questRows(byId.weekly, weekly) },
		event = eventView,
		season = {
			id = Data.season.id, name = Data.season.name, active = Data.seasonActive(),
			endsAt = Data.stamp(Data.season.ends) + 86400, xp = season.xp, tier = Data.seasonTier(season.xp),
			xpPerTier = Data.season.xpPerTier, maxTier = #Data.season.tiers,
			premium = hasPremium(player), premiumOnSale = Data.season.premiumPassId ~= 0,
			claimedFree = season.claimedFree, claimedPremium = season.claimedPremium,
		},
		collection = collection,
		cosmetics = { owned = data.cosmetics.owned, trail = data.cosmetics.trail, title = data.cosmetics.title },
		currencies = { pearls = data.pearls, shards = data.shards, embers = data.embers, tideglass = data.tideglass },
		settings = data.settings,
	}
end

-- Coalesced: a catch counts fish, rare fish and Pearls at once, and the client gets one push for all of them.
local pushPending = {}
function LiveOps.pushView(player)
	if pushPending[player] then
		return
	end
	pushPending[player] = true
	task.delay(0.25, function()
		pushPending[player] = nil
		local view = player.Parent and LiveOps.view(player)
		if view and PushEvent then
			PushEvent:FireClient(player, view)
		end
	end)
end

-- Tracking -------------------------------------------------------------------------------------------------------

local function bump(section, list, event, amount, player, label)
	local finished = {}
	for _, id in ipairs(section.ids or {}) do
		local q = list[id]
		if q and q.event == event and not section.claimed[id] then
			local before = section.progress[id] or 0
			section.progress[id] = math.min(q.goal, before + amount)
			if before < q.goal and section.progress[id] >= q.goal then
				table.insert(finished, q.text)
			end
		end
	end
	for _, text in ipairs(finished) do
		deps.notify(player, ("%s complete: %s. Claim it in QUESTS."):format(label, text), "good")
	end
	return #finished > 0
end

-- Counts one game event for this player's quests, goals, event and season XP.
function LiveOps.track(player, event, amount)
	local data = PlayerData.get(player)
	if not data or not Data.events[event] then
		return
	end
	amount = amount or 1
	bump(dailyOf(data), byId.daily, event, amount, player, "Daily quest")
	bump(weeklyOf(data), byId.weekly, event, amount, player, "Weekly goal")
	local activeEvent, progress = eventOf(data)
	if activeEvent then
		progress.ids = progress.ids or {}
		if #progress.ids == 0 then
			for _, g in ipairs(activeEvent.goals) do
				table.insert(progress.ids, g.id)
			end
		end
		bump(progress, byId.event, event, amount, player, activeEvent.name)
	end
	local xp = Data.season.playXp[event]
	if xp then
		LiveOps.addXp(player, data, xp * amount)
	end
	LiveOps.pushView(player)
end

-- Pity cache (Section 10 Table A: MemoryStore session cache, Heartbeat reconciliation) ------------------------------

local pityMap = nil
do
	local ok, result = pcall(function()
		return MemoryStoreService:GetHashMap("GlobalPity")
	end)
	pityMap = ok and result or nil
end
local PITY_TTL = 7 * 86400
local pityDirty = {} -- [userId] = { pity, hatched }

local function writePity(userId, entry)
	if not pityMap then
		return true
	end
	local ok = pcall(function()
		pityMap:SetAsync(tostring(userId), entry, PITY_TTL)
	end)
	return ok
end

-- Called after every gacha pull (the pull itself is untouched: Main still rolls with Gacha.rollTier).
function LiveOps.onPull(player, data)
	local entry = { pity = data.pity.TideEgg, hatched = data.stats.hatched, t = os.time() }
	pityDirty[player.UserId] = entry
	task.spawn(function()
		if writePity(player.UserId, entry) and pityDirty[player.UserId] == entry then
			pityDirty[player.UserId] = nil
		end
	end)
end

-- On join: if this server's save is behind the cache (a server shut down between a pull and its next save), the
-- cache's counters win, so pity is never lost.
local function reconcilePity(player, data)
	if not pityMap then
		return
	end
	local ok, entry = pcall(function()
		return pityMap:GetAsync(tostring(player.UserId))
	end)
	if ok and type(entry) == "table" and type(entry.pity) == "table" and (entry.hatched or 0) > (data.stats.hatched or 0) then
		for key, value in pairs(entry.pity) do
			if type(value) == "number" and data.pity.TideEgg[key] ~= nil then
				data.pity.TideEgg[key] = value
			end
		end
		warn(("[Tidebound] Restored %s's pity from the MemoryStore cache"):format(player.Name))
	end
end

local reconcileAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	reconcileAccumulator += dt
	if reconcileAccumulator < 30 then
		return
	end
	reconcileAccumulator = 0
	for userId, entry in pairs(pityDirty) do
		task.spawn(function()
			if writePity(userId, entry) and pityDirty[userId] == entry then
				pityDirty[userId] = nil
			end
		end)
	end
end)

-- Leaderboards (Section 10 Table C) --------------------------------------------------------------------------------

local boards = {} -- [id] = { updatedAt, entries = { { rank, userId, name, value } } }
local ordered = {}
for _, board in ipairs(Data.leaderboards) do
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(board.store)
	end)
	ordered[board.id] = ok and store or nil
	boards[board.id] = { updatedAt = 0, entries = {} }
end
local names = {} -- [userId] = display name

local function statOf(data, board)
	if board.stat == "pearls" then
		return math.floor(data.pearls)
	end
	return math.floor(data.stats.hatched or 0)
end

local function writeBoards(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	for _, board in ipairs(Data.leaderboards) do
		local store = ordered[board.id]
		if store then
			pcall(function()
				store:SetAsync(tostring(player.UserId), statOf(data, board))
			end)
		end
	end
end

local function resolveNames(ids)
	local missing = {}
	for _, id in ipairs(ids) do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and type(infos) == "table" then
		for _, info in ipairs(infos) do
			names[info.Id] = info.DisplayName
		end
	end
end

local function readBoards()
	for _, board in ipairs(Data.leaderboards) do
		local store = ordered[board.id]
		local entries = {}
		local ok = store and pcall(function()
			local page = store:GetSortedAsync(false, Data.leaderboardSize):GetCurrentPage()
			local ids = {}
			for _, row in ipairs(page) do
				table.insert(ids, tonumber(row.key))
			end
			resolveNames(ids)
			for rank, row in ipairs(page) do
				local userId = tonumber(row.key)
				table.insert(entries, { rank = rank, userId = userId, name = names[userId] or ("Diver " .. row.key), value = row.value })
			end
		end)
		if not ok then
			-- no DataStore access (an unpublished Studio place): rank this server's players instead
			entries = {}
			local rows = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local data = PlayerData.get(p)
				if data then
					table.insert(rows, { userId = p.UserId, name = p.DisplayName, value = statOf(data, board) })
				end
			end
			table.sort(rows, function(a, b)
				return a.value > b.value
			end)
			for rank, row in ipairs(rows) do
				row.rank = rank
				table.insert(entries, row)
			end
		end
		boards[board.id] = { updatedAt = os.time(), entries = entries, live = ok == true }
	end
end

task.spawn(function()
	task.wait(10)
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			writeBoards(p)
			task.wait(0.5)
		end
		readBoards()
		task.wait(Data.leaderboardEvery)
	end
end)

-- Actions ----------------------------------------------------------------------------------------------------------

local actions = {}

local function claimFrom(player, data, section, list, id, label)
	local q = type(id) == "string" and list[id]
	if not q or not table.find(section.ids or {}, id) then
		return { error = "That isn't one of your current " .. label .. "." }
	end
	if section.claimed[id] then
		return { error = "Already claimed." }
	end
	if (section.progress[id] or 0) < q.goal then
		return { error = "Not finished yet." }
	end
	section.claimed[id] = true
	local text = grant(player, data, q.reward)
	deps.notify(player, ("Claimed: %s"):format(text), "good")
	return { ok = true, granted = text }
end

function actions.Get(player)
	return LiveOps.view(player)
end

function actions.ClaimDaily(player, data, id)
	return claimFrom(player, data, dailyOf(data), byId.daily, id, "daily quests")
end

-- The old QUESTS tab claims through Main's Request remote; it lands here too.
function LiveOps.claimDaily(player, data, id)
	local result = actions.ClaimDaily(player, data, id)
	LiveOps.pushView(player)
	return result
end

function actions.ClaimWeekly(player, data, id)
	return claimFrom(player, data, weeklyOf(data), byId.weekly, id, "weekly goals")
end

function actions.ClaimEvent(player, data, id)
	local event, progress = eventOf(data)
	if not event then
		return { error = "No event is running right now." }
	end
	progress.ids = progress.ids or {}
	if #progress.ids == 0 then
		for _, g in ipairs(event.goals) do
			table.insert(progress.ids, g.id)
		end
	end
	return claimFrom(player, data, progress, byId.event, id, "event goals")
end

function actions.ClaimCollection(player, data, id)
	local goal = type(id) == "string" and byId.collection[id]
	if not goal then
		return { error = "Unknown collection goal." }
	end
	if data.collectionClaimed[id] then
		return { error = "Already claimed." }
	end
	local counts = collectionCounts(data)
	local kind = Data.collection.creatures[1] and table.find(Data.collection.creatures, goal) and "creatures" or "fish"
	if counts[kind] < goal.goal then
		return { error = "Not there yet." }
	end
	data.collectionClaimed[id] = true
	local text = grant(player, data, goal.reward)
	deps.notify(player, ("Collection goal: %s"):format(text), "rare")
	return { ok = true, granted = text }
end

function actions.ClaimSeason(player, data, tier, track)
	tier = tonumber(tier)
	if not tier or tier ~= math.floor(tier) or not Data.season.tiers[tier] or (track ~= "free" and track ~= "premium") then
		return { error = "Unknown season reward." }
	end
	local season = seasonOf(data)
	if Data.seasonTier(season.xp) < tier then
		return { error = "Reach that tier first." }
	end
	local claimed = track == "free" and season.claimedFree or season.claimedPremium
	local key = tostring(tier)
	if claimed[key] then
		return { error = "Already claimed." }
	end
	if track == "premium" and not hasPremium(player) then
		return { error = "The premium track is cosmetic only and isn't unlocked." }
	end
	claimed[key] = true
	local text = grant(player, data, Data.season.tiers[tier][track])
	deps.notify(player, ("Season tier %d: %s"):format(tier, text), "good")
	return { ok = true, granted = text }
end

function actions.BuyCosmetic(player, data, id)
	for _, item in ipairs(Data.shop.cosmetics) do
		if item.id == id then
			if data.cosmetics.owned[id] then
				return { error = "You already own it." }
			end
			if item.price.pearls then
				if data.pearls < item.price.pearls then
					return { error = "Not enough Pearls." }
				end
				data.pearls -= item.price.pearls
			elseif item.price.tideglass then
				if data.tideglass < item.price.tideglass then
					return { error = "Not enough Tideglass." }
				end
				data.tideglass -= item.price.tideglass
			end
			data.cosmetics.owned[id] = true
			deps.notify(player, ("Bought %s. Equip it in the shop's WARDROBE."):format(Data.cosmetics[id].name), "good")
			return { ok = true }
		end
	end
	return { error = "That isn't in the shop." }
end

function actions.Equip(player, data, id, kind)
	if id == "" and (kind == "trail" or kind == "title") then
		data.cosmetics[kind] = ""
	else
		local item = type(id) == "string" and Data.cosmetics[id]
		if not item or not data.cosmetics.owned[id] then
			return { error = "You don't own that." }
		end
		data.cosmetics[item.kind] = id
	end
	applyCosmetics(player)
	return { ok = true }
end

local SETTING_RULES = {
	musicVolume = "volume", sfxVolume = "volume", ambienceVolume = "volume", uiVolume = "volume",
	reduceFlashing = "boolean", cameraShake = "boolean",
	vfxQuality = { Auto = true, High = true, Medium = true, Low = true },
}
function actions.SetSettings(player, data, settings)
	if type(settings) ~= "table" then
		return { error = "Bad settings." }
	end
	for key, rule in pairs(SETTING_RULES) do
		local value = settings[key]
		if rule == "volume" and type(value) == "number" and value == value then
			data.settings[key] = math.clamp(value, 0, 1)
		elseif rule == "boolean" and type(value) == "boolean" then
			data.settings[key] = value
		elseif type(rule) == "table" and rule[value] then
			data.settings[key] = value
		end
	end
	return { ok = true }
end

function actions.GetOdds(player, data)
	-- Section 10: the server sends the authoritative table; the client only draws the bars
	local tiers = {}
	for i, tier in ipairs(Config.Tiers) do
		local color, band = Biomes.rarityColor(i)
		table.insert(tiers, { index = i, id = tier.id, rate = tier.rate, color = color, band = band, creatures = tier.creatures, value = tier.pearlValue })
	end
	local mutations = {}
	for _, m in ipairs(Config.Mutations) do
		table.insert(mutations, { id = m.id, rate = m.rate, mult = m.mult, color = m.color, visual = m.visual })
	end
	local pity = {}
	for _, p in ipairs(Config.Pity) do
		local countNow = data.pity.TideEgg[p.key] or 0
		table.insert(pity, { key = p.key, label = p.label, at = p.at, count = countNow, remaining = p.at - countNow, tier = p.tier })
	end
	return {
		egg = Config.Eggs.TideEgg.name, cost = Config.Eggs.TideEgg.pearlCost,
		tiers = tiers, mutations = mutations, pity = pity, legal = Config.LegalText,
	}
end

function actions.GetLeaderboards(player, data)
	local me = {}
	for _, board in ipairs(Data.leaderboards) do
		me[board.id] = statOf(data, board)
	end
	return { boards = boards, me = me, every = Data.leaderboardEvery }
end

function actions.BuyTideglass(player, data, packId)
	for _, pack in ipairs(Data.shop.tideglassPacks) do
		if pack.id == packId then
			if pack.productId == 0 then
				return { error = "Tideglass packs aren't on sale yet." }
			end
			MarketplaceService:PromptProductPurchase(player, pack.productId)
			return { ok = true }
		end
	end
	return { error = "Unknown pack." }
end

function actions.BuyPremium(player)
	if Data.season.premiumPassId == 0 then
		return { error = "The premium track isn't on sale yet." }
	end
	MarketplaceService:PromptGamePassPurchase(player, Data.season.premiumPassId)
	return { ok = true }
end

-- Robux receipts for Tideglass packs. Granted once per receipt; the save carries the receipt ids.
local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and PlayerData.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.receipts = data.receipts or {}
	if data.receipts[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	for _, pack in ipairs(Data.shop.tideglassPacks) do
		if pack.productId ~= 0 and pack.productId == info.ProductId then
			data.tideglass += pack.amount
			data.receipts[info.PurchaseId] = os.time()
			PlayerData.save(player)
			deps.notify(player, ("+%d Tideglass. Thank you!"):format(pack.amount), "rare")
			LiveOps.pushView(player)
			deps.push(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Lifecycle ------------------------------------------------------------------------------------------------------

function LiveOps.init(dependencies)
	deps = dependencies
	local remotes = dependencies.remotes
	LiveOpsRemote = remotes:FindFirstChild("LiveOps") or Instance.new("RemoteFunction")
	LiveOpsRemote.Name = "LiveOps"
	LiveOpsRemote.Parent = remotes
	PushEvent = remotes:FindFirstChild("LiveOpsPush") or Instance.new("RemoteEvent")
	PushEvent.Name = "LiveOpsPush"
	PushEvent.Parent = remotes

	LiveOpsRemote.OnServerInvoke = function(player, action, ...)
		if not allow(player) then
			return { error = "Slow down a little." }
		end
		local handler = type(action) == "string" and actions[action]
		local data = PlayerData.get(player)
		if not handler then
			return { error = "Unknown action." }
		end
		if not data then
			return { error = "Still loading your save." }
		end
		local ok, result = pcall(handler, player, data, ...)
		if not ok then
			warn("[Tidebound] LiveOps action failed:", action, result)
			return { error = "Something went wrong." }
		end
		if action ~= "Get" and action ~= "GetOdds" and action ~= "GetLeaderboards" then
			LiveOps.pushView(player)
			deps.push(player)
		end
		return result
	end

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Data.season.premiumPassId then
			premiumCache[player] = true
			deps.notify(player, "Premium season track unlocked (cosmetics only).", "rare")
			LiveOps.pushView(player)
		end
	end)
end

function LiveOps.onPlayerAdded(player, data)
	reconcilePity(player, data)
	dailyOf(data)
	weeklyOf(data)
	seasonOf(data)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Head", 10)
		applyCosmetics(player)
	end)
	if player.Character then
		task.spawn(applyCosmetics, player)
	end
	task.delay(2, LiveOps.pushView, player)
end

function LiveOps.onPlayerRemoving(player)
	writeBoards(player)
	local entry = pityDirty[player.UserId]
	if entry then
		writePity(player.UserId, entry)
		pityDirty[player.UserId] = nil
	end
	buckets[player] = nil
	premiumCache[player] = nil
end

return LiveOps
