-- Tidebound: Eggfall: Crews (Master Patch 1). Solo is the default and co-op is opt-in: a Crew forms only
-- from players who accept an invite, up to 4, and matchmaking is never forced. A Crew sees the same
-- content as a solo diver; it only changes the Pearl bonus (+5% per extra member, solo gets 1.15x),
-- which leaderboard your runs count on, and that crewmates can never snatch eggs from each other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("Config"))

local M = Config.Modes
local Crew = {}

local crewOf = {} -- [Player] = { members = { Player, ... } }
local invites = {} -- [Player] = { from = Player, expires = number }
local deps = nil -- { notify = function(player, text, kind), push = function(player), canChange = function(player): string? }

local function pushAll(crew)
	for _, member in ipairs(crew.members) do
		deps.push(member)
	end
end

function Crew.members(player)
	local crew = crewOf[player]
	return crew and crew.members or { player }
end

function Crew.size(player)
	return #Crew.members(player)
end

function Crew.sameCrew(a, b)
	local crew = crewOf[a]
	return crew ~= nil and crew == crewOf[b]
end

function Crew.leave(player)
	local crew = crewOf[player]
	if not crew then
		return
	end
	crewOf[player] = nil
	local index = table.find(crew.members, player)
	if index then
		table.remove(crew.members, index)
	end
	for _, member in ipairs(crew.members) do
		deps.notify(member, ("%s left your Crew."):format(player.DisplayName), "info")
	end
	if #crew.members == 1 then
		-- a Crew of one is just a solo diver
		crewOf[crew.members[1]] = nil
	end
	pushAll(crew)
	deps.push(player)
end

function Crew.state(player)
	local now = os.clock()
	local invite = invites[player]
	if invite and (invite.expires < now or not invite.from.Parent) then
		invites[player] = nil
		invite = nil
	end
	local members = {}
	for _, member in ipairs(Crew.members(player)) do
		table.insert(members, member.DisplayName)
	end
	local others = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local theirs = invites[other]
			table.insert(others, {
				id = other.UserId,
				name = other.DisplayName,
				inMyCrew = Crew.sameCrew(player, other),
				invited = theirs ~= nil and theirs.from == player and theirs.expires >= now,
			})
		end
	end
	return { members = members, inviteFrom = invite and invite.from.DisplayName or nil, others = others, max = M.crewMax }
end

local handlers = {}

function handlers.CrewInvite(player, _data, userId)
	if type(userId) ~= "number" then
		return { error = "Bad player." }
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return { error = "That player isn't on this server." }
	end
	if Crew.sameCrew(player, target) then
		return { error = "They're already in your Crew." }
	end
	if Crew.size(player) >= M.crewMax then
		return { error = ("A Crew holds up to %d divers."):format(M.crewMax) }
	end
	local blocked = deps.canChange(player)
	if blocked then
		return { error = blocked }
	end
	invites[target] = { from = player, expires = os.clock() + M.inviteSeconds }
	deps.notify(target, ("%s invited you to their Crew. Accept in the DIVE tab (Gate Warden Sel)."):format(player.DisplayName), "info")
	deps.notify(player, ("Crew invite sent to %s."):format(target.DisplayName), "good")
	deps.push(target)
	return { ok = true }
end

function handlers.CrewAccept(player)
	local invite = invites[player]
	invites[player] = nil
	if not invite or invite.expires < os.clock() or not invite.from.Parent then
		return { error = "That invite expired." }
	end
	local blocked = deps.canChange(player) or deps.canChange(invite.from)
	if blocked then
		return { error = blocked }
	end
	local crew = crewOf[invite.from]
	if not crew then
		crew = { members = { invite.from } }
		crewOf[invite.from] = crew
	end
	if #crew.members >= M.crewMax then
		return { error = "That Crew is full." }
	end
	if crewOf[player] then
		Crew.leave(player)
	end
	table.insert(crew.members, player)
	crewOf[player] = crew
	for _, member in ipairs(crew.members) do
		deps.notify(member, ("%s joined the Crew (%d/%d). Press DIVE WITH CREW to dive together."):format(player.DisplayName, #crew.members, M.crewMax), "good")
	end
	pushAll(crew)
	return { ok = true }
end

function handlers.CrewDecline(player)
	invites[player] = nil
	return { ok = true }
end

function handlers.CrewLeave(player)
	if not crewOf[player] then
		return { error = "You're diving solo." }
	end
	Crew.leave(player)
	return { ok = true }
end

Crew.handlers = handlers

function Crew.init(dependencies)
	deps = dependencies
	Players.PlayerRemoving:Connect(function(player)
		Crew.leave(player)
		invites[player] = nil
		for target, invite in pairs(invites) do
			if invite.from == player then
				invites[target] = nil
			end
		end
	end)
end

return Crew
