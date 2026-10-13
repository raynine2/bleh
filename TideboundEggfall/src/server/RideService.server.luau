-- Tidebound: Eggfall: fish riding on the server (12 Oct 2026, "Swimming + Fish Riding" update).
-- Your own client moves you while you ride (it owns your character's physics); the server only checks a ride
-- can start and puts it on your character as attributes, so every other screen shows the fish and the pose:
--   Riding = style name ("" or nil when not riding), RideAt (server time), RideFish (your first companion's
--   creature, "" for the loaner fish), RideJumpAt (server time of the last leap).
-- It also copies the hatchable fish models into ReplicatedStorage.Tidebound.RideFish, because with streaming on a
-- client far from the origin never receives workspace.HatchableFish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local WaterMoves = require(Shared:WaitForChild("WaterMoves"))
local remotes = Shared:WaitForChild("Remotes")

local remote = remotes:FindFirstChild("Ride")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "Ride"
	remote.Parent = remotes
end

-- Fish models for the mounts -----------------------------------------------------------------------------------------

task.spawn(function()
	local source = workspace:WaitForChild("HatchableFish", 30)
	if not source or Shared:FindFirstChild("RideFish") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "RideFish"
	for _, rarity in ipairs(source:GetChildren()) do
		for _, model in ipairs(rarity:GetChildren()) do
			local part = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
			if part and not folder:FindFirstChild(model.Name) then
				local copy = part:Clone()
				copy.Name = model.Name
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanTouch = false
				copy.CanQuery = false
				copy:ClearAllChildren()
				copy.Parent = folder
			end
		end
	end
	folder.Parent = Shared
end)

-- Rides ----------------------------------------------------------------------------------------------------------------

local lastCall = {} -- [Player] = os.clock() of their last accepted request

local function companionFish(player)
	local folder = workspace:FindFirstChild("TideboundCompanions")
	local model = folder and folder:FindFirstChild("Companion_" .. player.UserId .. "_1")
	local name = model and model:GetAttribute("Creature")
	return type(name) == "string" and name or ""
end

local function stop(character)
	if character then
		character:SetAttribute("Riding", nil)
		character:SetAttribute("RideAt", nil)
		character:SetAttribute("RideFish", nil)
		character:SetAttribute("RideJumpAt", nil)
	end
end

remote.OnServerEvent:Connect(function(player, action, style)
	local now = os.clock()
	if now - (lastCall[player] or 0) < 0.2 then
		return
	end
	lastCall[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	if action == "start" then
		if humanoid.Health <= 0 or type(style) ~= "string" or not table.find(WaterMoves.STYLES, style) then
			return
		end
		if root.Position.Y > WaterMoves.maxStartHeight then
			return -- only in the sea
		end
		character:SetAttribute("RideFish", companionFish(player))
		character:SetAttribute("RideJumpAt", nil)
		character:SetAttribute("RideAt", workspace:GetServerTimeNow())
		character:SetAttribute("Riding", style)
	elseif action == "jump" then
		if character:GetAttribute("Riding") then
			character:SetAttribute("RideJumpAt", workspace:GetServerTimeNow())
		end
	elseif action == "stop" then
		stop(character)
	end
end)

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			stop(character)
		end)
	end
end
local function onPlayer(player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)
