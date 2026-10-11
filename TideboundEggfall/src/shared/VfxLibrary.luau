-- Tidebound: Eggfall VFX library (GDD Section 8 Table B, VFX Clarity Rules, Section 10 particle rows).
-- Every effect in Table B as a function. Shared rules every effect follows:
--   * Rule 1: colours come from the canon rarity spectrum (Biomes.rarityColor) or the biome's Table D colours
--   * Rule 2 / Visual Rule 4: one player action spawns at most 500 particles (VfxLibrary.ACTION_BUDGET), and the
--     device tier / VFX Quality setting scales every count and rate (VfxLibrary.quality)
--   * Rule 3 / 5: screen flashes go through ClientBus.flash (3 per second, 20% with Reduce Flashing)
--   * Rule 6: continuous emitters register with VfxLibrary.track and fade out past 150 studs (TideboundVfx)
-- Flipbooks are 2x2 sprite sheets (Grid2x2) made for this game: assets/vfx/*.png, uploaded as the ids below.
-- Client-only: effects are made locally, so they never replicate or cost the server anything.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Biomes = require(Shared:WaitForChild("Biomes"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))

local VfxLibrary = {}

VfxLibrary.ACTION_BUDGET = 500
VfxLibrary.LOD_DISTANCE = 150

VfxLibrary.textures = {
	-- 2x2 flipbooks (assets/vfx)
	wind = "rbxassetid://135516216895766",
	kelp = "rbxassetid://129405737816125",
	burst = "rbxassetid://129397562417420",
	bolt = "rbxassetid://81026226052666",
	aurora = "rbxassetid://91667243498952",
	rift = "rbxassetid://99412514342842",
	-- Roblox's built-in particle textures
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	spark = "rbxasset://textures/particles/fire_sparks_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	shockwave = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",
}
local T = VfxLibrary.textures

local WHITE = Color3.new(1, 1, 1)

-- Particle count scale: the setting wins; "Auto" reads the device (touch devices and low graphics get less).
function VfxLibrary.quality()
	local q = ClientBus.settings.vfxQuality
	if q == "High" then
		return 1
	elseif q == "Medium" then
		return 0.6
	elseif q == "Low" then
		return 0.3
	end
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	local graphics = ok and level or 0 -- 0 = automatic
	if graphics > 0 and graphics <= 3 then
		return 0.35
	elseif graphics > 0 and graphics <= 6 then
		return 0.65
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and 0.6 or 1
end

-- A per-action budget: emit through it and the action never passes 500 particles in total.
function VfxLibrary.budget(limit)
	return { left = math.floor((limit or VfxLibrary.ACTION_BUDGET) * VfxLibrary.quality()) }
end

local function emit(emitter, count, budget)
	local n = math.max(1, math.floor(count * VfxLibrary.quality()))
	if budget then
		n = math.min(n, budget.left)
		budget.left -= n
	end
	if n > 0 then
		emitter:Emit(n)
	end
end
VfxLibrary.emit = emit

local function seq(...)
	local points = { ... }
	local keys = {}
	for i, v in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new((i - 1) / math.max(1, #points - 1), v))
	end
	return NumberSequence.new(keys)
end
VfxLibrary.seq = seq

-- A ParticleEmitter with sensible defaults. `flipbook` = "Loop" or "OneShot" turns on the Grid2x2 layout.
function VfxLibrary.emitter(parent, props, flipbook)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 0.6
	e.LockedToPart = false
	for key, value in pairs(props or {}) do
		e[key] = value
	end
	if flipbook then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode[flipbook]
		e.FlipbookFramerate = props and props.FlipbookFramerate or NumberRange.new(8, 12)
		e.FlipbookStartRandom = flipbook == "Loop"
	end
	e.Parent = parent
	return e
end
local emitter = VfxLibrary.emitter

-- Rule 6: continuous emitters are tracked so TideboundVfx can fade them out past 150 studs. `rate` is the
-- emitter's full Rate at the current quality.
VfxLibrary.tracked = {} -- [ParticleEmitter] = { rate = number, at = BasePart | Attachment }
function VfxLibrary.track(e, rate)
	VfxLibrary.tracked[e] = { rate = rate }
	e.Rate = rate * VfxLibrary.quality()
	e.Enabled = true
	e.Destroying:Connect(function()
		VfxLibrary.tracked[e] = nil
	end)
	return e
end

-- An invisible, non-colliding anchor part at a position (cleaned up after `life` seconds when given).
function VfxLibrary.anchor(position, life, size)
	local p = Instance.new("Part")
	p.Name = "VfxAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = typeof(position) == "CFrame" and position or CFrame.new(position)
	p.Parent = workspace.Terrain:FindFirstChild("TideboundVfx") or (function()
		local folder = Instance.new("Folder")
		folder.Name = "TideboundVfx"
		folder.Parent = workspace.Terrain
		return folder
	end)()
	if life then
		Debris:AddItem(p, life)
	end
	return p
end
local anchor = VfxLibrary.anchor

local function ring(position, color, size, seconds, transparency)
	local p = anchor(CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), seconds + 0.1, Vector3.new(0.3, 1, 1))
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0.2
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, size, size), Transparency = 1 }):Play()
	return p
end
VfxLibrary.ring = ring

-- Table B effects -------------------------------------------------------------------------------------------------

-- Egg Aura (Rarity): continuous, on the egg. Gold tiers shimmer gold to white; the rarest add a light pulse.
function VfxLibrary.eggAura(part, tierIndex)
	local color = Biomes.rarityColor(tierIndex)
	local attachment = Instance.new("Attachment")
	attachment.Name = "EggAura"
	attachment.Parent = part
	local shimmer = tierIndex >= 6 and ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, color) }) or ColorSequence.new(color)
	local sparks = emitter(attachment, {
		Texture = T.sparkle, Color = shimmer, Size = seq(0.5, 0.25, 0), Transparency = seq(0.1, 0.3, 1),
		Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(1.2, 2.4), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 1.5, 0), LightEmission = 1,
	})
	VfxLibrary.track(sparks, 3 + tierIndex * 2)
	local halo = emitter(attachment, {
		Texture = T.glow, Color = ColorSequence.new(color), Size = seq(3.2, 3.8), Transparency = seq(0.75, 0.9),
		Lifetime = NumberRange.new(1.2), Speed = NumberRange.new(0), LockedToPart = true, LightEmission = 1,
	})
	VfxLibrary.track(halo, 1.5)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8 + tierIndex
	light.Brightness = 0.8
	light.Parent = part
	return { attachment = attachment, light = light, sparks = sparks, halo = halo }
end

-- Hatch Explosion: flipbook burst, sparkles and smoke at the egg, 2.5 s, inside the 500 budget.
function VfxLibrary.hatchExplosion(position, tierIndex)
	local color = Biomes.rarityColor(tierIndex)
	local budget = VfxLibrary.budget()
	local a = anchor(position, 2.6)
	local flip = emitter(a, {
		Texture = T.burst, Color = ColorSequence.new(WHITE, color), Size = seq(6, 22), Transparency = seq(0, 0.2, 1),
		Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0), LightEmission = 1, ZOffset = 2,
		FlipbookFramerate = NumberRange.new(6),
	}, "OneShot")
	emit(flip, 1, budget)
	local sparks = emitter(a, {
		Texture = T.spark, Color = ColorSequence.new(color, WHITE), Size = seq(0.6, 0.2), Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(18, 34), SpreadAngle = Vector2.new(180, 180),
		Drag = 3, Acceleration = Vector3.new(0, -12, 0), LightEmission = 1,
	})
	emit(sparks, 140, budget)
	local smoke = emitter(a, {
		Texture = T.smoke, Color = ColorSequence.new(color:Lerp(WHITE, 0.6)), Size = seq(3, 9), Transparency = seq(0.5, 1),
		Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(3, 8), SpreadAngle = Vector2.new(180, 180),
		Drag = 2, LightEmission = 0.2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
	})
	emit(smoke, 24, budget)
	ring(position, color, 30, 0.8, 0.3)
	return budget
end

-- Mutation Burst: a beam spiral and particle storm on the player for 3.0 s, plus shake and a tinted flash
-- (the GDD's chromatic aberration: Roblox has no such post effect, so a split tint flash stands in for it).
function VfxLibrary.mutationBurst(rootPart, color)
	local budget = VfxLibrary.budget()
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, -2.5, 0)
	base.Parent = rootPart
	local beams = {}
	for i = 1, 3 do
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(math.cos(i * 2.1) * 2.5, 5, math.sin(i * 2.1) * 2.5)
		top.Parent = rootPart
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = base, top
		beam.Texture = T.bolt
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = 2
		beam.Color = ColorSequence.new(color, WHITE)
		beam.LightEmission = 1
		beam.Width0, beam.Width1 = 2.5, 0.6
		beam.CurveSize0, beam.CurveSize1 = 3, -3
		beam.FaceCamera = true
		beam.Parent = rootPart
		table.insert(beams, beam)
		Debris:AddItem(top, 3)
		Debris:AddItem(beam, 3)
		TweenService:Create(beam, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
	end
	Debris:AddItem(base, 3)
	local storm = emitter(base, {
		Texture = T.rift, Color = ColorSequence.new(color), Size = seq(2, 7), Transparency = seq(0.2, 1),
		Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top, LightEmission = 1, FlipbookFramerate = NumberRange.new(10),
	}, "Loop")
	Debris:AddItem(storm, 3.2)
	for i = 0, 5 do
		task.delay(i * 0.45, function()
			if storm.Parent then
				emit(storm, 14, budget)
			end
		end)
	end
	local sparks = emitter(base, {
		Texture = T.sparkle, Color = ColorSequence.new(color, WHITE), Size = seq(0.8, 0), Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(180, 180), Drag = 2, LightEmission = 1,
	})
	emit(sparks, 160, budget)
	ClientBus.flash(color, 0.55)
	ClientBus.signal:Fire("shake", 1.8, 0.5)
	return budget
end

-- Ability Cast: a quick flare at a hand or weapon, 1.5 s.
function VfxLibrary.abilityCast(attachTo, color)
	local a = Instance.new("Attachment")
	a.Parent = attachTo
	Debris:AddItem(a, 1.6)
	local e = emitter(a, {
		Texture = T.sparkle, Color = ColorSequence.new(color or WHITE), Size = seq(1, 0), Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
	})
	emit(e, 40)
end

-- Extraction Beam: a column of light from the sky onto the player, 5.0 s.
function VfxLibrary.extractionBeam(position, color)
	color = color or Color3.fromRGB(90, 255, 200)
	local ground = anchor(position, 5.2)
	local sky = anchor(position + Vector3.new(0, 320, 0), 5.2)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = ground, sky
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Texture = T.glow
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 20
	beam.TextureSpeed = -1.5
	beam.Color = ColorSequence.new(WHITE, color)
	beam.LightEmission = 1
	beam.Width0, beam.Width1 = 0.5, 10
	beam.FaceCamera = true
	beam.Transparency = seq(0, 0.4)
	beam.Parent = ground
	TweenService:Create(beam, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Width0 = 8, Width1 = 12 }):Play()
	task.delay(4.2, function()
		TweenService:Create(beam, TweenInfo.new(0.8), { Width0 = 0, Width1 = 0 }):Play()
	end)
	local rise = emitter(a0, {
		Texture = T.sparkle, Color = ColorSequence.new(color, WHITE), Size = seq(0.8, 0.2), Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(14, 24), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Top, LightEmission = 1,
	})
	rise.Rate = 40 * VfxLibrary.quality() -- 40/s for 4 s = 160, well inside the budget
	rise.Enabled = true
	task.delay(4, function()
		rise.Enabled = false
	end)
	ring(position, color, 24, 1, 0.2)
end

-- Gacha Reveal: a shockwave and a flipbook burst, 2.0 s. `position` in the world (the UI side is HatchScene's).
function VfxLibrary.gachaReveal(position, tierIndex)
	local color = Biomes.rarityColor(tierIndex)
	local budget = VfxLibrary.budget()
	local a = anchor(position, 2.1)
	local shock = emitter(a, {
		Texture = T.shockwave, Color = ColorSequence.new(color), Size = seq(2, 26), Transparency = seq(0.1, 1),
		Lifetime = NumberRange.new(0.9), Speed = NumberRange.new(0), LightEmission = 1, Orientation = Enum.ParticleOrientation.FacingCamera,
	})
	emit(shock, 2, budget)
	local flip = emitter(a, {
		Texture = T.burst, Color = ColorSequence.new(color, WHITE), Size = seq(4, 16), Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.6), Speed = NumberRange.new(0), LightEmission = 1, FlipbookFramerate = NumberRange.new(7),
	}, "OneShot")
	emit(flip, 1, budget)
	ring(position, color, 36, 1.2, 0.25)
	return budget
end

-- Guardian Roar: flipbook bursts and shock rings from the guardian's head, 2.0 s.
function VfxLibrary.guardianRoar(head, color)
	color = color or Color3.fromRGB(255, 80, 60)
	local position = head:IsA("BasePart") and head.Position or head:GetPivot().Position
	local budget = VfxLibrary.budget()
	local a = anchor(position, 2.1)
	local flip = emitter(a, {
		Texture = T.burst, Color = ColorSequence.new(color), Size = seq(6, 30), Transparency = seq(0.3, 1),
		Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0), LightEmission = 0.8, FlipbookFramerate = NumberRange.new(6),
	}, "OneShot")
	for i = 0, 2 do
		task.delay(i * 0.5, function()
			emit(flip, 1, budget)
			ring(position, color, 40 + i * 12, 0.9, 0.35)
		end)
	end
	local dust = emitter(a, {
		Texture = T.smoke, Color = ColorSequence.new(color:Lerp(WHITE, 0.5)), Size = seq(2, 6), Transparency = seq(0.6, 1),
		Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(16, 28), SpreadAngle = Vector2.new(180, 30), Drag = 3,
	})
	emit(dust, 60, budget)
	ClientBus.signal:Fire("shake", 2.2, 0.8)
end

-- Water Impact: a splash crown where something hits the water, 1.0 s.
function VfxLibrary.waterImpact(position, scale)
	scale = scale or 1
	local a = anchor(position, 1.2)
	local spray = emitter(a, {
		Texture = T.smoke, Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)), Size = seq(0.8 * scale, 2 * scale), Transparency = seq(0.2, 1),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(10 * scale, 18 * scale), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -40, 0), Drag = 1, LightEmission = 0.3,
		WindAffectsDrag = true,
	})
	emit(spray, 30 * scale)
	ring(position + Vector3.new(0, 0.2, 0), Color3.fromRGB(220, 245, 255), 8 * scale, 0.8, 0.4)
end

-- Bait Splash: a small plop at the bobber, 0.5 s.
function VfxLibrary.baitSplash(position)
	local a = anchor(position, 0.7)
	local drops = emitter(a, {
		Texture = T.sparkle, Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)), Size = seq(0.35, 0.1), Transparency = seq(0, 1),
		Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -30, 0),
	})
	emit(drops, 14)
	ring(position + Vector3.new(0, 0.1, 0), Color3.fromRGB(230, 250, 255), 4, 0.5, 0.45)
end

-- Storm Lightning: a flipbook bolt from the sky and a flash, 0.2 s.
function VfxLibrary.lightning(position)
	local top = position + Vector3.new(0, 260, 0)
	local mid = anchor(CFrame.new((position + top) / 2), 0.4)
	local bolt = emitter(mid, {
		Texture = T.bolt, Color = ColorSequence.new(Color3.fromRGB(220, 230, 255)), Size = NumberSequence.new(140),
		Transparency = seq(0, 0.2, 1), Lifetime = NumberRange.new(0.2), Speed = NumberRange.new(0), LightEmission = 1,
		FlipbookFramerate = NumberRange.new(20), Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
	}, "OneShot")
	emit(bolt, 1)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 8
	light.Color = Color3.fromRGB(200, 215, 255)
	light.Parent = anchor(position + Vector3.new(0, 40, 0), 0.25)
	ClientBus.flash(Color3.fromRGB(220, 230, 255), 0.75)
end

-- Sonar Pulse: an expanding glass sphere and a ring of motes from the player, 1.5 s.
function VfxLibrary.sonarPulse(position, color)
	color = color or Color3.fromRGB(143, 0, 255)
	local p = anchor(position, 1.6, Vector3.new(2, 2, 2))
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Transparency = 0
	TweenService:Create(p, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(70, 70, 70), Transparency = 1 }):Play()
	local motes = emitter(p, {
		Texture = T.glow, Color = ColorSequence.new(color), Size = seq(0.8, 0), Lifetime = NumberRange.new(1, 1.4),
		Speed = NumberRange.new(20, 26), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
	})
	emit(motes, 50)
end

-- Gravity Rift: a swirling flipbook vortex that pulls motes in, 2.0 s.
function VfxLibrary.gravityRift(position, color)
	color = color or Color3.fromRGB(170, 90, 255)
	local a = anchor(position, 2.1)
	local vortex = emitter(a, {
		Texture = T.rift, Color = ColorSequence.new(color, WHITE), Size = seq(10, 14, 0), Transparency = seq(0.1, 0.3, 1),
		Lifetime = NumberRange.new(2), Speed = NumberRange.new(0), LightEmission = 1, RotSpeed = NumberRange.new(-120),
		FlipbookFramerate = NumberRange.new(8), Orientation = Enum.ParticleOrientation.FacingCamera,
	}, "Loop")
	emit(vortex, 1)
	local pull = emitter(a, {
		Texture = T.sparkle, Color = ColorSequence.new(color), Size = seq(0.5, 0.1), Lifetime = NumberRange.new(0.9),
		Speed = NumberRange.new(-16, -12), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
	})
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emit(pull, 70)
end

return VfxLibrary
