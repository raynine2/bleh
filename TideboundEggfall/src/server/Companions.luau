-- Tidebound: Eggfall: companion creatures (Master Patch 1 step 4 and Patch 2's loss table).
-- You pick 2 creatures from your collection. They follow you everywhere (the client animates them), and
-- each awake companion carries one egg for you, so it doesn't cost WalkSpeed. A Reef Warden hit knocks one
-- out: it goes home to your base for 10 minutes, or a Revive Vial wakes it. Companions come from hatching,
-- never from Robux.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local CreatureModels = require(Shared:WaitForChild("CreatureModels"))

local C = Config.Companions
local Companions = {}

local folder = workspace:FindFirstChild("TideboundCompanions") or Instance.new("Folder")
folder.Name = "TideboundCompanions"
folder.Parent = workspace

local built = {} -- [Player] = signature of the companions currently spawned

local function tierOf(name)
	for index, tier in ipairs(Config.Tiers) do
		if table.find(tier.creatures, name) then
			return index
		end
	end
	return 1
end

-- The best copy you own decides the companion's look (its mutation trail shows on the follower).
local function bestCopy(data, name)
	local best = nil
	for _, creature in ipairs(data.aquarium) do
		if creature.c == name and (not best or creature.v > best.v) then
			best = creature
		end
	end
	return best
end

local function koLeft(data, name)
	local untilTime = data.companions.ko[name]
	return untilTime and math.max(0, untilTime - os.time()) or 0
end

-- Equipped, still owned and not knocked out, in slot order.
function Companions.awake(data)
	local out = {}
	for _, name in ipairs(data.companions.slots) do
		if name ~= "" and data.collection[name] and koLeft(data, name) <= 0 then
			table.insert(out, name)
		end
	end
	return out
end

function Companions.carry(data)
	return #Companions.awake(data)
end

-- A Warden hit knocks out the first awake companion. Returns its name.
function Companions.knockOut(data)
	local name = Companions.awake(data)[1]
	if name then
		data.companions.ko[name] = os.time() + C.koSeconds
	end
	return name
end

-- A Revive Vial wakes the knocked-out companion with the longest wait left. Returns its name.
function Companions.revive(data)
	local best, bestLeft = nil, 0
	for _, name in ipairs(data.companions.slots) do
		local left = name ~= "" and koLeft(data, name) or 0
		if left > bestLeft then
			best, bestLeft = name, left
		end
	end
	if best then
		data.companions.ko[best] = nil
	end
	return best
end

function Companions.state(data)
	local slots = {}
	for i = 1, C.slots do
		local name = data.companions.slots[i] or ""
		slots[i] = { name = name, tier = name ~= "" and tierOf(name) or 0, koLeft = name ~= "" and koLeft(data, name) or 0 }
	end
	local owned = {}
	for name, count in pairs(data.collection) do
		table.insert(owned, { name = name, tier = tierOf(name), count = count })
	end
	table.sort(owned, function(a, b)
		if a.tier ~= b.tier then
			return a.tier > b.tier
		end
		return a.name < b.name
	end)
	return { slots = slots, owned = owned }
end

-- Spawns (or clears) the follower models when the awake set changes.
function Companions.refresh(player, data, force)
	local awake = Companions.awake(data)
	local signature = table.concat(awake, "|")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not force and built[player] == signature and (signature == "" or root == nil or folder:FindFirstChild("Companion_" .. player.UserId .. "_1")) then
		return
	end
	built[player] = signature
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Owner") == player.UserId then
			model:Destroy()
		end
	end
	if not root then
		return
	end
	for i, name in ipairs(awake) do
		local copy = bestCopy(data, name)
		local side = i == 1 and -3 or 3
		local model = CreatureModels.build(tierOf(name), copy and copy.m or "None", root.CFrame * CFrame.new(side, 0, 3), 2)
		model.Name = "Companion_" .. player.UserId .. "_" .. i
		model:SetAttribute("Owner", player.UserId)
		model:SetAttribute("Slot", i)
		model:SetAttribute("Creature", name)
		-- clients move companions locally, so they must never bump players or block the Warden's sight
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
		CollectionService:AddTag(model, "TideboundCompanion")
		model.Parent = folder
	end
end

function Companions.release(player)
	built[player] = nil
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Owner") == player.UserId then
			model:Destroy()
		end
	end
end

local handlers = {}

function handlers.EquipCompanion(player, data, slot, name)
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > C.slots or slot % 1 ~= 0 or type(name) ~= "string" then
		return { error = "Bad companion slot." }
	end
	if name ~= "" and not data.collection[name] then
		return { error = "Hatch that creature first." }
	end
	for i, other in ipairs(data.companions.slots) do
		if i ~= slot and other == name and name ~= "" then
			data.companions.slots[i] = ""
		end
	end
	data.companions.slots[slot] = name
	Companions.refresh(player, data, true)
	return { ok = true }
end

Companions.handlers = handlers

return Companions
