-- Tidebound: Eggfall wind and weather on the server (GDD Section 8 Table C, Section 10 Table A "Wind: Server").
-- The server owns Workspace.GlobalWind and the weather. It publishes, as Workspace attributes:
--   Wind_<Biome>  the biome's wind vector from Section 8 Table C, scaled by the weather (Vector3)
--   WindGust      a slow multi-layered gust multiplier, 0.55 to 1.45 (number, updated twice a second)
--   Weather       "Clear", "Rain" or "Storm"; WeatherUntil (server time it changes)
--   LightningAt / LightningPos  a storm strike (cosmetic: the flash, bolt and thunder clients play)
-- GlobalWind itself is set to the Open Sea vector (the prevailing wind) whenever the weather changes. Clients
-- override it locally with the wind of the biome they stand in (particles are drawn per client, so each player's
-- rain and spray lean with their own biome's wind), and multiply in WindGust.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Biomes = require(Shared:WaitForChild("Biomes"))

local WindService = {}

-- How the weather scales every biome's wind, and how long each state lasts (seconds).
WindService.weather = {
	Clear = { weight = 60, wind = 1.0, duration = { 180, 360 } },
	Rain = { weight = 25, wind = 1.25, duration = { 120, 240 } },
	Storm = { weight = 15, wind = 1.7, duration = { 90, 180 }, lightningEvery = { 5, 12 } },
}
WindService.firstChange = 120 -- the first weather roll comes this long after the server starts

local rng = Random.new()
local current = "Clear"

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function publishWinds()
	local scale = WindService.weather[current].wind
	for id, biome in pairs(Biomes.list) do
		workspace:SetAttribute("Wind_" .. id, biome.wind.vector * scale)
	end
	workspace.GlobalWind = Biomes.list.OpenSea.wind.vector * scale
end

local function setWeather(name)
	current = name
	local spec = WindService.weather[name]
	workspace:SetAttribute("Weather", name)
	workspace:SetAttribute("WeatherUntil", serverNow() + rng:NextNumber(spec.duration[1], spec.duration[2]))
	publishWinds()
end

local function rollWeather()
	local total = 0
	for _, spec in pairs(WindService.weather) do
		total += spec.weight
	end
	local roll = rng:NextNumber() * total
	for name, spec in pairs(WindService.weather) do
		roll -= spec.weight
		if roll <= 0 then
			return name
		end
	end
	return "Clear"
end

-- Multi-layered sine gusts (vault: Roblox GlobalWind Comprehensive, "Multi-Layered Wind Systems").
local function gust(t)
	local slow = math.sin(t * 0.07 * math.pi * 2) * 0.28
	local mid = math.sin(t * 0.2 * math.pi * 2 + 1.3) * 0.12
	local fast = math.sin(t * 0.5 * math.pi * 2 + 2.1) * 0.05
	return math.clamp(1 + slow + mid + fast, 0.55, 1.45)
end

-- A strike somewhere a player can see it: 60 to 260 studs from a random surface player, never underground.
local function strike()
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and not Biomes.get(Biomes.at(root.Position)).underground then
			table.insert(candidates, root.Position)
		end
	end
	if #candidates == 0 then
		return
	end
	local origin = candidates[rng:NextInteger(1, #candidates)]
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(60, 260)
	local at = Vector3.new(origin.X + math.cos(angle) * distance, 4, origin.Z + math.sin(angle) * distance)
	workspace:SetAttribute("LightningPos", at)
	workspace:SetAttribute("LightningAt", serverNow())
end

function WindService.start()
	setWeather("Clear")
	workspace:SetAttribute("WeatherUntil", serverNow() + WindService.firstChange)
	local nextStrike = math.huge
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local t = serverNow()
		workspace:SetAttribute("WindGust", math.floor(gust(t) * 100 + 0.5) / 100)
		local forced = workspace:GetAttribute("ForceWeather")
		if forced then
			workspace:SetAttribute("ForceWeather", nil)
			if WindService.weather[forced] then
				setWeather(forced)
				nextStrike = t + 2
			end
		elseif t >= (workspace:GetAttribute("WeatherUntil") or 0) then
			setWeather(rollWeather())
			nextStrike = t + 3
		end
		local spec = WindService.weather[current]
		if spec.lightningEvery and t >= nextStrike then
			nextStrike = t + rng:NextNumber(spec.lightningEvery[1], spec.lightningEvery[2])
			strike()
		end
	end)
end

-- Studio testing: set workspace attribute ForceWeather = "Storm" (or "Rain", "Clear") and it switches within 0.5 s.

return WindService
