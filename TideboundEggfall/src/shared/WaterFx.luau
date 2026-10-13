-- Tidebound: Eggfall: realistic water and catch effects (Fishing FX remake, 12 Oct 2026).
-- HJHJH: "i dont like the circle things and the vfx and fx are really bad ... make it feel real and good and
-- very high quality". So nothing here is a neon ring, a plastic pillar or a cube: every splash is particles. A
-- crown of liquid splash sprites, fine droplets that fly out and fall back under gravity (stretched along their
-- path), a puff of mist, and soft foam that settles flat on the surface and fades. Catches sparkle in their tier's
-- colour instead of shooting neon columns.
-- Client-only, like VfxLibrary: everything is made on this screen and scales with the VFX Quality setting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local VfxLibrary = require(Shared:WaitForChild("VfxLibrary"))

local WaterFx = {}

WaterFx.textures = {
	-- 13 Oct 2026 (HJHJH: the water FX are "still boxy"): every water texture is now a soft round one with real
	-- transparency. The splash sprite, the rain-splash streaks and the VFX Studio sheets below showed their square
	-- edges on bright water, so nothing uses them any more (kept here only for reference).
	splash = "rbxasset://textures/particles/smoke_main.dds", -- was rbxassetid://17318627145
	spray = "rbxasset://textures/particles/forcefield_glow_main.dds", -- was rbxassetid://133742935984510
	drop = "rbxasset://textures/particles/forcefield_glow_main.dds", -- a soft round droplet
	mist = "rbxasset://textures/particles/smoke_main.dds",
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	-- 12 Oct 2026 (HJHJH: use the VFX Studio plugin): animated water sheets from its Water library
	splashSheet = "rbxassetid://94781084807364", -- a splash bursting upward, 4x4 frames
	crownSheet = "rbxassetid://70779397588104", -- a splash crown opening on the surface, 4x4 frames
	spraySheet = "rbxassetid://86803327592449", -- a quick spray burst, 4x4 frames
	chunks = { "rbxassetid://107688167838598", "rbxassetid://131917326401050" }, -- clumps of water, 2x2 each
}
local TX = WaterFx.textures

local GRAVITY = 55
local WHITE = Color3.new(1, 1, 1)
local FOAM = Color3.fromRGB(235, 248, 255)
local WATER = ColorSequence.new(Color3.fromRGB(245, 252, 255), Color3.fromRGB(175, 225, 245))

local seq = VfxLibrary.seq

-- One burst from a throwaway anchor: makes the emitter, emits `count` (scaled by quality) and cleans up.
local function puff(position, life, count, props)
	local n = math.floor(count * VfxLibrary.quality() + 0.5)
	if n < 1 then
		return
	end
	local a = VfxLibrary.anchor(position, life + 0.2, Vector3.new(0.2, 0.2, 0.2))
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 1
	e.LightEmission = 0
	for key, value in pairs(props) do
		(e :: any)[key] = value
	end
	e.Parent = a
	e:Emit(n)
end

-- One animated sheet from the VFX Studio library, played once where it lands (`lift` raises it so a splash
-- rises out of the water instead of being cut in half by it).
-- 13 Oct 2026: the sheets read as boxes, so a "sheet" is now a soft white plume: round puffs of spray thrown
-- up out of the water that slow, fall back and thin out (`texture` and `lift` are ignored).
local function sheet(position, _texture, size, life, _lift, count)
	puff(position + Vector3.new(0, 0.1, 0), life + 0.4, (count or 1) * 5, {
		Texture = TX.mist, Color = ColorSequence.new(Color3.fromRGB(250, 253, 255), Color3.fromRGB(215, 240, 252)), EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(size * 2, size * 3.2), SpreadAngle = Vector2.new(16, 16), Acceleration = Vector3.new(0, -GRAVITY * 0.7, 0), Drag = 1.4,
		Size = seq(size * 0.16, size * 0.3, size * 0.4), Transparency = seq(0.2, 0.4, 1), Lifetime = NumberRange.new(life * 0.75, life * 1.15),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), LightEmission = 0.3, LightInfluence = 0.6, ZOffset = 0.4,
	})
end
WaterFx.sheet = sheet

-- Clumps of water thrown out of a splash, falling back under gravity (each clump picks a random frame).
function WaterFx.chunks(position, count, speed, size)
	-- 13 Oct 2026: big round drops instead of the boxy 2x2 clump sheets
	WaterFx.droplets(position, count, speed or 10, 35, (size or 0.6) * 0.45)
end

local function _oldChunks(position, count, speed, size)
	speed = speed or 10
	size = size or 0.6
	puff(position, 1.3, count, {
		Texture = TX.chunks[math.random(1, #TX.chunks)], FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.Random, Color = WATER, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(speed * 0.5, speed), SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, -GRAVITY, 0),
		Size = seq(size, size * 0.9, size * 0.4), Transparency = seq(0.05, 0.2, 1), Lifetime = NumberRange.new(0.5, 0.9),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), LightEmission = 0.15, LightInfluence = 0.7,
	})
end

-- Foam that lands flat on the water and spreads a little as it fades (soft, never a hard ring).
function WaterFx.foam(position, size, count)
	size = math.max(0.6, size or 2)
	puff(position + Vector3.new(0, 0.08, 0), 2, count or 3, {
		Texture = TX.mist, Color = ColorSequence.new(FOAM), Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), SpreadAngle = Vector2.new(0, 0),
		Size = seq(size * 0.35, size * 0.8, size), Transparency = seq(0.45, 0.65, 1), Lifetime = NumberRange.new(1, 1.6),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25), LightInfluence = 0.8,
	})
end

-- Droplets: round drops thrown up and out, stretched along their flight, falling back into the sea.
function WaterFx.droplets(position, count, speed, spread, size)
	speed = speed or 10
	size = size or 0.16
	puff(position, 1.2, count, {
		Texture = TX.drop, Color = WATER, Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(speed * 0.55, speed), SpreadAngle = Vector2.new(spread or 38, spread or 38),
		Acceleration = Vector3.new(0, -GRAVITY, 0), Drag = 0.4, Size = seq(size, size * 0.8, size * 0.3), Squash = NumberSequence.new(-0.55),
		Transparency = seq(0.05, 0.15, 1), Lifetime = NumberRange.new(0.45, 0.9), LightEmission = 0.25, LightInfluence = 0.7,
	})
end

-- A splash where something breaks the surface. `scale` 0.4 is a bobber plop, 1 a fish, 3 a sea monster.
function WaterFx.splash(position, scale)
	scale = math.clamp(scale or 1, 0.25, 4)
	local s = math.sqrt(scale)
	-- a soft white plume bursting up, and big round drops thrown out of it
	sheet(position, nil, 3.4 * scale, 0.6 * s)
	WaterFx.chunks(position, 3 + 3 * scale, 7 + 4 * s, 0.35 + 0.25 * s)
	-- the crown: liquid sheets thrown up, turning and falling apart
	puff(position, 1, 2 + 2 * scale, {
		Texture = TX.splash, Color = WATER, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(4 * s, 9 * s), SpreadAngle = Vector2.new(22, 22), Acceleration = Vector3.new(0, -GRAVITY, 0),
		Size = seq(0.7 * scale, 1.6 * scale, 2.2 * scale), Transparency = seq(0.1, 0.35, 1), Lifetime = NumberRange.new(0.35 * s, 0.6 * s),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), LightEmission = 0.1, ZOffset = 0.5,
	})
	-- fine spray streaks at the moment of impact
	puff(position + Vector3.new(0, 0.4 * scale, 0), 0.5, 2, {
		Texture = TX.spray, Color = ColorSequence.new(WHITE), Speed = NumberRange.new(0, 1),
		Size = seq(1 * scale, 2.2 * scale), Transparency = seq(0.55, 1), Lifetime = NumberRange.new(0.2, 0.3),
		Rotation = NumberRange.new(0, 360), LightEmission = 0.3,
	})
	WaterFx.droplets(position, 10 + 14 * scale, 8 + 5 * s, 40, 0.12 + 0.06 * s)
	-- a breath of mist hanging over it
	puff(position + Vector3.new(0, 0.5 * scale, 0), 1.8, 2 + 2 * scale, {
		Texture = TX.mist, Color = ColorSequence.new(FOAM), Speed = NumberRange.new(0.5, 2.5 * s), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Drag = 2, Size = seq(0.8 * scale, 2.6 * scale), Transparency = seq(0.6, 1),
		Lifetime = NumberRange.new(0.8, 1.4), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
	})
	WaterFx.foam(position, 1.6 + 1.8 * scale, 2 + math.floor(scale))
end

-- Spray off a running fish or a tight line cutting the water: a few droplets and a fleck of foam.
function WaterFx.spray(position, count, speed)
	WaterFx.droplets(position, count, speed, 50, 0.12)
	if math.random() < 0.5 then
		sheet(position, TX.spraySheet, 1.6 + (count or 4) * 0.08, 0.4, 0.3)
	end
	if math.random() < 0.35 then
		WaterFx.foam(position, 1.2, 1)
	end
end

-- Water running off something lifted out of the sea.
function WaterFx.drip(position, count)
	puff(position, 1, count or 2, {
		Texture = TX.drop, Color = WATER, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(0, 1.5), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -GRAVITY, 0),
		Size = seq(0.12, 0.08), Squash = NumberSequence.new(-0.5), Transparency = seq(0.1, 1), Lifetime = NumberRange.new(0.4, 0.7),
		LightEmission = 0.2,
	})
end

-- A geyser: a column of real spray that climbs to `height` and rains back down.
function WaterFx.spout(position, height, width)
	height = math.max(2, height or 8)
	width = math.max(0.8, width or 2)
	local v = math.sqrt(2 * GRAVITY * height)
	local up = v / GRAVITY
	-- the VFX Studio splash sheet, stretched to the spout's height
	sheet(position, TX.splashSheet, math.max(width * 2.5, height * 0.9), 0.75, 0.45)
	WaterFx.chunks(position, 4 + width * 2, v * 0.7, 0.5)
	puff(position, up * 2 + 0.4, 6 + width * 4, {
		Texture = TX.splash, Color = WATER, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(v * 0.75, v), SpreadAngle = Vector2.new(6, 6), Acceleration = Vector3.new(0, -GRAVITY, 0),
		Size = seq(width * 0.8, width * 1.3, width * 0.6), Transparency = seq(0.15, 0.3, 1), Lifetime = NumberRange.new(up * 1.2, up * 1.9),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60), LightEmission = 0.1, Drag = 0.3,
	})
	WaterFx.droplets(position, 18 + width * 8, v, 12, 0.18)
	puff(position + Vector3.new(0, height * 0.6, 0), up * 2 + 1, 4, {
		Texture = TX.mist, Color = ColorSequence.new(FOAM), Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180),
		Drag = 1.5, Size = seq(width, width * 2.6), Transparency = seq(0.65, 1), Lifetime = NumberRange.new(1, 1.6),
		Rotation = NumberRange.new(0, 360), Acceleration = Vector3.new(0, -2, 0),
	})
	WaterFx.foam(position, width * 2.2, 3)
end

-- A glimmer of light in a catch's colour: soft sparkles that float out and fade, and a gentle glow.
function WaterFx.glimmer(position, color, amount)
	amount = amount or 1
	color = color or WHITE
	puff(position, 1.6, 10 + 10 * amount, {
		Texture = TX.sparkle, Color = ColorSequence.new(color:Lerp(WHITE, 0.55), color), Speed = NumberRange.new(2, 4 + 2 * amount),
		SpreadAngle = Vector2.new(180, 180), Drag = 2.5, Acceleration = Vector3.new(0, 1.5, 0),
		Size = seq(0.45, 0.3, 0), Transparency = seq(0, 0.2, 1), Lifetime = NumberRange.new(0.7, 1.3), LightEmission = 1, LightInfluence = 0,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120),
	})
	puff(position, 0.8, 1, {
		Texture = TX.drop, Color = ColorSequence.new(color), Speed = NumberRange.new(0), Size = seq(1.5 + amount, 3 + amount * 1.5),
		Transparency = seq(0.55, 1), Lifetime = NumberRange.new(0.5), LightEmission = 1, LightInfluence = 0,
	})
end

-- Motes of light that lift off the water where a rare fish came from (replaces the old neon pillar).
function WaterFx.rise(position, color, height)
	height = height or 20
	color = color or WHITE
	local speed = 9 + height * 0.25
	puff(position, height / speed + 0.6, 14 + height * 0.6, {
		Texture = TX.sparkle, Color = ColorSequence.new(WHITE, color), EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(speed * 0.5, speed), SpreadAngle = Vector2.new(12, 12), Drag = 0.4,
		Size = seq(0.5, 0.35, 0), Transparency = seq(0, 0.25, 1), Lifetime = NumberRange.new(height / speed * 0.6, height / speed),
		LightEmission = 1, LightInfluence = 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
	})
end

return WaterFx
