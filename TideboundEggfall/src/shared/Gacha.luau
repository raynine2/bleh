-- Tidebound: Eggfall: pure roll math shared by server (rolls) and client (odds display).

local Config = require(script.Parent.Config)

local Gacha = {}

function Gacha.newCounters()
	local counters = {}
	for _, pity in ipairs(Config.Pity) do
		counters[pity.key] = 0
	end
	return counters
end

-- Picks an index from `weights`, considering only indices >= startIndex.
local function pickWeighted(weights, startIndex, rng)
	local total = 0
	for i = startIndex, #weights do
		total += weights[i]
	end
	local roll = rng:NextNumber() * total
	for i = startIndex, #weights do
		roll -= weights[i]
		if roll < 0 then
			return i
		end
	end
	return #weights
end

-- Returns the tier floor forced by pity for the next pull (1 = no guarantee) and the pity key that forced it.
function Gacha.pityFloor(counters)
	for i = #Config.Pity, 1, -1 do
		local pity = Config.Pity[i]
		if (counters[pity.key] or 0) + 1 >= pity.at then
			return pity.tier, pity.key
		end
	end
	return 1, nil
end

-- Rolls one egg pull and updates `counters` in place.
function Gacha.rollTier(counters, rng)
	local floorTier, pityKey = Gacha.pityFloor(counters)
	local weights = {}
	for i, tier in ipairs(Config.Tiers) do
		weights[i] = tier.rate
	end
	local tierIndex = pickWeighted(weights, floorTier, rng)
	for _, pity in ipairs(Config.Pity) do
		if tierIndex >= pity.tier then
			counters[pity.key] = 0
		else
			counters[pity.key] = (counters[pity.key] or 0) + 1
		end
	end
	return tierIndex, pityKey
end

function Gacha.rollMutation(rng)
	local weights = {}
	for i, mutation in ipairs(Config.Mutations) do
		weights[i] = mutation.rate
	end
	return Config.Mutations[pickWeighted(weights, 1, rng)]
end

-- Fishing: luck multiplies the weight of Rare and above.
function Gacha.fishWeights(luck)
	local weights = {}
	for i, tier in ipairs(Config.Tiers) do
		weights[i] = tier.fishRate * (i >= 3 and luck or 1)
	end
	return weights
end

function Gacha.fishOdds(luck)
	local weights = Gacha.fishWeights(luck)
	local total = 0
	for _, w in ipairs(weights) do
		total += w
	end
	local odds = {}
	for i, w in ipairs(weights) do
		odds[i] = w / total * 100
	end
	return odds
end

function Gacha.rollFishTier(luck, rng)
	return pickWeighted(Gacha.fishWeights(luck), 1, rng)
end

-- For the odds panel: how far each pity guarantee is.
function Gacha.pityProgress(counters)
	local rows = {}
	for _, pity in ipairs(Config.Pity) do
		local count = counters[pity.key] or 0
		table.insert(rows, {
			key = pity.key,
			label = pity.label,
			at = pity.at,
			count = count,
			remaining = pity.at - count,
		})
	end
	return rows
end

return Gacha
