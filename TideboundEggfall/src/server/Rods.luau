-- Tidebound: Eggfall: you wear your rod everywhere (Master Patch 7). It rides on your back in the Nest, the
-- Harbor Ring, your Home Nest and on dives, and moves to your right hand when you cast, so other players
-- always see what you fish with. A broken rod keeps its look. The model comes from RodModels; the
-- TideboundRod client script bends it and draws the line.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RodModels = require(ReplicatedStorage:WaitForChild("Tidebound"):WaitForChild("RodModels"))

local Rods = {}

local inHand = {} -- [Player] = true while the rod is in the hand

-- Where the rod sits: across the back (the middle of the rod behind the shoulders, tilted 40 degrees),
-- or gripped in the right hand with the tip forward and up (about 30 degrees above level at rest).
local BACK = { CFrame.new(0, 0.1, 0.62) * CFrame.Angles(0, 0, math.rad(40)), CFrame.new(0, 2.4, 0) }
local HAND = { CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(-130), 0, 0), CFrame.new(RodModels.GRIP) }
local R6_HAND = { CFrame.new(0, -0.9, 0) * CFrame.Angles(math.rad(-130), 0, 0), CFrame.new(RodModels.GRIP) }

local function mountOn(character, hand)
	if hand then
		local rightHand = character:FindFirstChild("RightHand")
		if rightHand then
			return rightHand, HAND
		end
		local rightArm = character:FindFirstChild("Right Arm")
		if rightArm then
			return rightArm, R6_HAND
		end
	end
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"), BACK
end

local function place(player, model)
	local character = player.Character
	local weld = model.PrimaryPart and model.PrimaryPart:FindFirstChild("RodMount")
	if not character or not weld then
		return
	end
	local part0, spot = mountOn(character, inHand[player] == true)
	if not part0 then
		return
	end
	weld.Part0 = part0
	weld.C0 = spot[1]
	weld.C1 = spot[2]
end

function Rods.model(player)
	local character = player.Character
	return character and character:FindFirstChild("TideboundRod")
end

-- Puts `rodId` on the player's character (or swaps it). Safe to call often: keeps the same model.
function Rods.attach(player, rodId)
	local character = player.Character
	if not character or not (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) then
		return nil
	end
	local old = Rods.model(player)
	if old and old:GetAttribute("RodId") == rodId then
		return old
	end
	if old then
		old:Destroy()
	end
	local model = RodModels.build(rodId)
	model.Name = "TideboundRod"
	model:SetAttribute("Owner", player.UserId)
	local weld = Instance.new("Weld")
	weld.Name = "RodMount"
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	local part0, spot = mountOn(character, inHand[player] == true)
	if part0 then
		model:PivotTo(part0.CFrame * spot[1] * spot[2]:Inverse())
	end
	place(player, model)
	CollectionService:AddTag(model, "TideboundRod")
	model.Parent = character
	return model
end

-- Moves the rod between the back and the right hand.
function Rods.hold(player, hand)
	inHand[player] = hand or nil
	local model = Rods.model(player)
	if model then
		place(player, model)
	end
end

function Rods.release(player)
	inHand[player] = nil
end

return Rods
