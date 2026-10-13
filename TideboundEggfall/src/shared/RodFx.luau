-- Tidebound: Eggfall: rod-flavoured bursts, camera punches and screen shake (13 Oct 2026). Client only.
-- HJHJH asked for "animations like Catch a Brainrot with cool fov and screenshake and fx based on what rod u
-- have". Each rod's look (RodModels.looks: glow, line, trail, castFx) picks the colours and the style of its
-- burst: the Drift Rod throws spray and wood dust, Coral pink petals, Stormline crackling sparks, Abyssal and
-- the Crimson Crow dark smoke with embers, Riftcaster and Celestial rainbow glitter. RodFx.kick punches the
-- field of view (MotionBus.kick, played by TideboundClient's camera) and shakes the screen in one call.
-- Used by the cast, the bite, SHAKE hits, the catch and the stance swap.

local Debris = game:GetService("Debris")

local Shared = script.Parent
local RodModels = require(Shared:WaitForChild("RodModels"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))

local RodFx = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE = Color3.new(1, 1, 1)

local function ns(...)
	local points = { ... }
	if #points == 2 then
		return NumberSequence.new(points[1], points[2])
	end
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function firstColor(value)
	if typeof(value) == "Color3" then
		return value
	elseif typeof(value) == "ColorSequence" then
		return value.Keypoints[1].Value
	end
	return nil
end

-- the rod a character holds ("Drift" if none)
function RodFx.rodOf(character)
	local model = character and character:FindFirstChild("TideboundRod")
	return model and model:GetAttribute("RodId") or "Drift"
end

-- the rod's main colour, a colour sequence for its sparks, and its style (its cast effect's name)
function RodFx.style(rodId)
	local look = RodModels.looks[rodId] or RodModels.looks.Drift
	local main = firstColor(look.glow) or firstColor(look.line) or WHITE
	local seq = typeof(look.trail) == "ColorSequence" and look.trail or ColorSequence.new(main, main:Lerp(WHITE, 0.6))
	if look.aurora then
		seq = RodModels.RAINBOW
	end
	return { color = main, seq = seq, kind = look.castFx or "Dust" }
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	for key, value in pairs(props) do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- A burst at `position` in the rod's colours and style; `scale` 1 is a hand-sized pop, 2 to 3 a big moment.
function RodFx.burst(position, rodId, scale)
	scale = scale or 1
	local st = RodFx.style(rodId)
	local at = Instance.new("Attachment")
	at.Parent = workspace.Terrain
	at.WorldPosition = position
	local function pop(count, props)
		emitter(at, props):Emit(math.max(1, math.floor(count * scale + 0.5)))
	end
	-- a soft flash, then sparks flying out in the rod's colours
	pop(1, { Texture = SPARK, Color = ColorSequence.new(st.color:Lerp(WHITE, 0.3)), Size = ns(0, 1.5 * scale, 1, 4.5 * scale), Transparency = ns(0, 0.15, 1, 1), Lifetime = NumberRange.new(0.25), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 2, ZOffset = 1 })
	pop(14, { Texture = SPARK, Color = st.seq, Size = ns(0, 0.5, 1, 0), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 18), Drag = 5, LightEmission = 1, Brightness = 1.6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200) })
	if st.kind == "Static" then
		-- crackling sparks: fast, thin and gone in a blink
		pop(18, { Texture = SPARK, Color = ColorSequence.new(WHITE, st.color), Size = ns(0, 0.3, 1, 0.05), Transparency = ns(0, 0, 1, 0.6), Lifetime = NumberRange.new(0.1, 0.2), Speed = NumberRange.new(28, 40), LightEmission = 1, Brightness = 3 })
	elseif st.kind == "Shadow" then
		-- dark smoke rolling out, with embers
		pop(6, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(18, 12, 26), st.color:Lerp(Color3.new(0, 0, 0), 0.6)), Size = ns(0, 1, 1, 3.2), Transparency = ns(0, 0.35, 1, 1), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(4, 7), Drag = 3, LightEmission = 0, Rotation = NumberRange.new(0, 360) })
		pop(8, { Texture = SPARK, Color = ColorSequence.new(st.color), Size = ns(0, 0.25, 1, 0), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(3, 6), Acceleration = Vector3.new(0, 5, 0), LightEmission = 1, Brightness = 2 })
	elseif st.kind == "Coral" then
		-- pink petals drifting down
		pop(10, { Texture = SPARK, Color = st.seq, Size = ns(0, 0.35, 1, 0.2), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(5, 9), Drag = 2, Acceleration = Vector3.new(0, -6, 0), LightEmission = 0.6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-150, 150) })
	elseif st.kind == "Rift" or st.kind == "Aurora" then
		-- rainbow glitter hanging in the air
		pop(16, { Texture = SPARK, Color = RodModels.RAINBOW, Size = ns(0, 0.3, 0.5, 0.45, 1, 0), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(4, 10), Drag = 4, LightEmission = 1, Brightness = 2, Rotation = NumberRange.new(0, 360) })
	else
		-- the Drift Rod: spray and a puff of wood dust
		pop(10, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)), Size = ns(0, 0.3, 1, 0.1), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(8, 13), Acceleration = Vector3.new(0, -30, 0), LightEmission = 0.7 })
		pop(4, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(214, 186, 132)), Size = ns(0, 0.8, 1, 2.2), Transparency = ns(0, 0.5, 1, 1), Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(3, 5), Drag = 3, LightEmission = 0 })
	end
	Debris:AddItem(at, 2.5)
end

-- A punch of the field of view (degrees; + widens, - zooms in) and a screen shake, together.
function RodFx.kick(fov, shake, seconds)
	if fov and fov ~= 0 then
		MotionBus.kick = { at = os.clock(), amount = fov, length = seconds or 0.35 }
	end
	if shake and shake > 0 then
		FishingFeel.shake(shake, seconds or 0.25)
	end
end

-- the tip of a character's rod, or a point in front of them
function RodFx.tipOf(character)
	local model = character and character:FindFirstChild("TideboundRod")
	local tip = model and model:FindFirstChild("Tip", true)
	if tip and tip:IsA("BasePart") then
		return (tip.CFrame * CFrame.new(0, tip.Size.Y / 2, 0)).Position
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and (root.CFrame * CFrame.new(0.8, 1, -2)).Position or nil
end

-- Combo moves (13 Oct 2026) ---------------------------------------------------------------------------------
-- HJHJH: "rework the ui on this one and make it different on every single rod ... dont like the fx on the last
-- hit, its very chunky and not high quality ... make it also unique for every single different rod". Every rod
-- has its own three move names, accent colour and pip shape (TideboundRod draws the small combo readout), its own
-- swing trail, and its own finisher. All of it is soft particles, light and thin glowing beams: no neon blocks,
-- no rings, no cubes.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds"

local MOVES = {
	Drift = { names = { "Chop", "Sweep", "Driftwood Slam" }, accent = Color3.fromRGB(255, 214, 150), pip = "bar" },
	Coral = { names = { "Petal Cut", "Reef Spin", "Coral Bloom" }, accent = Color3.fromRGB(255, 140, 180), pip = "dot" },
	Stormline = { names = { "Spark", "Static Spin", "Thunderclap" }, accent = Color3.fromRGB(110, 180, 255), pip = "slant" },
	Abyssal = { names = { "Shade", "Undertow", "Abyss Drop" }, accent = Color3.fromRGB(170, 110, 255), pip = "line" },
	Riftcaster = { names = { "Rift Cut", "Prism Spin", "Rift Break" }, accent = Color3.fromRGB(140, 235, 255), pip = "slant", rainbow = true },
	Celestial = { names = { "Starfall", "Halo Spin", "Supernova" }, accent = Color3.fromRGB(255, 232, 160), pip = "diamond", rainbow = true },
	CrimsonCrow = { names = { "Talon", "Crow Spin", "Blood Moon" }, accent = Color3.fromRGB(255, 60, 80), pip = "slant" },
	Jackpot = { names = { "Coin Toss", "Lucky Spin", "Jackpot!" }, accent = Color3.fromRGB(255, 212, 80), pip = "diamond" },
	ThiefTome = { names = { "Page Cut", "Ink Spin", "Final Chapter" }, accent = Color3.fromRGB(185, 135, 255), pip = "line" },
	SunRubber = { names = { "Boing", "Sun Spin", "Solar Bounce" }, accent = Color3.fromRGB(255, 196, 70), pip = "dot" },
	Boundless = { names = { "Void Cut", "Event Horizon", "Boundless" }, accent = Color3.fromRGB(120, 205, 255), pip = "bar", rainbow = true },
}
RodFx.MOVES = MOVES

-- a rod's moves: { names = {3}, accent = Color3, pip = "bar"|"dot"|"slant"|"line"|"diamond", rainbow = bool }
function RodFx.move(rodId)
	return MOVES[rodId] or MOVES.Drift
end

local function anchorAt(position)
	local at = Instance.new("Attachment")
	at.Parent = workspace.Terrain
	at.WorldPosition = position
	return at
end

local function popAt(position, list, keep)
	local at = anchorAt(position)
	for _, item in ipairs(list) do
		emitter(at, item[2]):Emit(item[1])
	end
	Debris:AddItem(at, keep or 3)
end

-- a quick glow of light on everything around
local function light(position, color, brightness, range, life)
	local at = anchorAt(position + Vector3.new(0, 1.5, 0))
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = at
	TweenService:Create(l, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, Range = range * 0.6 }):Play()
	Debris:AddItem(at, life + 0.1)
end

-- soft puffs pushed along the ground in a circle (inward = true pulls them into the middle instead)
local function puffs(position, color, count, speed, size, life, alpha, inward, glow)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.35
		local dir = Vector3.new(math.cos(a), 0.1, math.sin(a))
		local from = inward and position + dir * (speed * life * 0.75) or position
		local at = Instance.new("Attachment")
		at.Parent = workspace.Terrain
		at.WorldCFrame = CFrame.lookAt(from, inward and position or position + dir)
		emitter(at, {
			Texture = SMOKE,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(10, 5),
			Color = ColorSequence.new(color),
			Size = inward and ns(0, size * 1.5, 1, size * 0.3) or ns(0, size * 0.6, 1, size * 1.7),
			Transparency = ns(0, 1, 0.15, alpha, 1, 1),
			Lifetime = NumberRange.new(life * 0.8, life),
			Speed = NumberRange.new(speed * 0.85, speed),
			Drag = inward and 0 or 4,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			LightEmission = glow or 0.15,
		}):Emit(2)
		Debris:AddItem(at, life + 0.3)
	end
end

local function flash(position, color, size, life)
	popAt(position, {
		{ 1, { Texture = GLOW, Color = ColorSequence.new(color:Lerp(WHITE, 0.4)), Size = ns(0, size * 0.3, 1, size), Transparency = ns(0, 0.1, 1, 1), Lifetime = NumberRange.new(life), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 3, ZOffset = 2 } },
		{ 1, { Texture = SPARK, Color = ColorSequence.new(WHITE), Size = ns(0, size * 0.2, 1, size * 0.6), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(life * 0.7), Speed = NumberRange.new(0), LightEmission = 1, Brightness = 3, ZOffset = 3 } },
	}, 1)
end

-- A smooth glowing arc (curved beams, no parts) that draws itself along the swing and fades.
-- `base`: the arc lies in base's X/Y plane around base's position; angles in radians (0 = base's X axis).
function RodFx.swoosh(base, radius, fromAngle, sweep, rodId, width, life)
	local mv = RodFx.move(rodId)
	local seqColor = mv.rainbow and RodModels.RAINBOW or ColorSequence.new(mv.accent:Lerp(WHITE, 0.55), mv.accent)
	local n = math.max(1, math.ceil(math.abs(sweep) / (math.pi / 2)))
	local step = sweep / n
	local k = 4 / 3 * math.tan(math.abs(step) / 4) * radius
	local sign = sweep >= 0 and 1 or -1
	local holder = Instance.new("Folder")
	holder.Name = "RodSwoosh"
	holder.Parent = workspace.Terrain
	local points = {}
	for i = 0, n do
		local a = fromAngle + step * i
		local p = base:PointToWorldSpace(Vector3.new(math.cos(a), math.sin(a), 0) * radius)
		local t = base:VectorToWorldSpace(Vector3.new(-math.sin(a), math.cos(a), 0) * sign)
		local at = Instance.new("Attachment")
		at.Parent = workspace.Terrain
		at.WorldCFrame = CFrame.fromMatrix(p, t, base.ZVector)
		points[i] = at
	end
	local beams = {}
	for i = 1, n do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = points[i - 1], points[i]
		b.CurveSize0, b.CurveSize1 = k, k
		b.FaceCamera = true
		b.Segments = 14
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = seqColor
		b.Transparency = NumberSequence.new(1)
		b.Parent = holder
		beams[i] = b
	end
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - start) / life
		if u >= 1 then
			connection:Disconnect()
			holder:Destroy()
			for _, at in pairs(points) do
				at:Destroy()
			end
			return
		end
		-- draw along the swing in the first 35%, then thin out and fade
		local drawn = math.clamp(u / 0.35, 0, 1) * n
		local fade = u < 0.35 and 0.05 or 0.05 + 0.95 * ((u - 0.35) / 0.65) ^ 1.4
		local thin = u < 0.35 and 1 or 1 - 0.7 * ((u - 0.35) / 0.65)
		for i, b in ipairs(beams) do
			local seen = math.clamp(drawn - (i - 1), 0, 1)
			if seen <= 0 then
				b.Transparency = NumberSequence.new(1)
			else
				if seen >= 0.98 then
					b.Transparency = NumberSequence.new(fade)
				else
					local edge = math.max(seen, 0.03)
					b.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, fade),
						NumberSequenceKeypoint.new(edge - 0.02, fade),
						NumberSequenceKeypoint.new(edge, 1),
						NumberSequenceKeypoint.new(1, 1),
					})
				end
				-- the leading end of the arc is the widest, the tail tapers away
				b.Width0 = width * thin * (0.25 + 0.75 * (i - 1) / n)
				b.Width1 = width * thin * (0.25 + 0.75 * i / n)
			end
		end
	end)
end

-- a jagged bolt from the sky (thin glowing beams)
local function lightning(position, color, life)
	local holder = Instance.new("Folder")
	holder.Name = "RodBolt"
	holder.Parent = workspace.Terrain
	local prev = nil
	local height = 34
	for i = 0, 6 do
		local f = i / 6
		local jitter = (i == 0 or i == 6) and Vector3.zero or Vector3.new(math.random(-20, 20) / 10, 0, math.random(-20, 20) / 10)
		local at = Instance.new("Attachment")
		at.Parent = workspace.Terrain
		at.WorldPosition = position + Vector3.new(0, height * (1 - f), 0) + jitter
		if prev then
			for _, w in ipairs({ 0.9, 0.25 }) do
				local b = Instance.new("Beam")
				b.Attachment0, b.Attachment1 = prev, at
				b.FaceCamera = true
				b.Width0, b.Width1 = w, w
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Color = ColorSequence.new(w < 0.5 and WHITE or color)
				b.Transparency = NumberSequence.new(w < 0.5 and 0 or 0.35)
				b.Parent = holder
			end
		end
		Debris:AddItem(at, life)
		prev = at
	end
	Debris:AddItem(holder, life)
end

-- Hits 1 and 2: a small pop in the rod's colours where the swing lands.
function RodFx.hit(position, rodId, step)
	local mv = RodFx.move(rodId)
	flash(position, mv.accent, 4 + step, 0.18)
	light(position, mv.accent, 3, 12, 0.25)
	RodFx.burst(position, rodId, 0.6 + 0.2 * step)
	if step >= 2 then
		puffs(position - Vector3.new(0, 1, 0), mv.accent:Lerp(WHITE, 0.6), 8, 12, 1, 0.45, 0.55, false, 0.3)
	end
end

-- The finisher: each rod's own big moment at `position` (on the ground in front of you).
local FINISH = {}
function FINISH.Drift(at, mv)
	puffs(at, Color3.fromRGB(214, 190, 150), 14, 18, 1.6, 0.7, 0.4)
	popAt(at, {
		{ 26, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(225, 242, 255)), Size = ns(0, 0.35, 1, 0.1), Transparency = ns(0, 0, 1, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(14, 24), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, -60, 0), LightEmission = 0.7 } },
		{ 12, { Texture = SPARK, Color = ColorSequence.new(mv.accent, Color3.fromRGB(150, 110, 70)), Size = ns(0, 0.4, 1, 0.2), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(10, 16), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -45, 0), RotSpeed = NumberRange.new(-300, 300), LightEmission = 0.3 } },
	})
end
function FINISH.Coral(at, mv)
	puffs(at, mv.accent:Lerp(WHITE, 0.5), 12, 16, 1.4, 0.6, 0.45, false, 0.4)
	popAt(at, {
		{ 34, { Texture = SPARK, Color = ColorSequence.new(mv.accent, Color3.fromRGB(255, 225, 235)), Size = ns(0, 0.5, 1, 0.3), Transparency = ns(0, 0, 0.7, 0.2, 1, 1), Lifetime = NumberRange.new(1.0, 1.6), Speed = NumberRange.new(10, 18), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Drag = 2, Acceleration = Vector3.new(0, -5, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-220, 220), LightEmission = 0.6 } },
		{ 16, { Texture = GLOW, Color = ColorSequence.new(WHITE), Size = ns(0, 0.3, 1, 0.5), Transparency = ns(0, 0.3, 1, 1), Lifetime = NumberRange.new(1.0, 1.5), Speed = NumberRange.new(3, 6), Acceleration = Vector3.new(0, 7, 0), LightEmission = 0.8 } },
	})
end
function FINISH.Stormline(at, mv)
	lightning(at, mv.accent, 0.16)
	task.delay(0.09, function()
		lightning(at, mv.accent, 0.12)
		flash(at, mv.accent, 10, 0.2)
	end)
	puffs(at, Color3.fromRGB(200, 220, 255), 12, 20, 1.3, 0.5, 0.5, false, 0.3)
	popAt(at, {
		{ 40, { Texture = SPARK, Color = ColorSequence.new(WHITE, mv.accent), Size = ns(0, 0.35, 1, 0.05), Lifetime = NumberRange.new(0.15, 0.35), Speed = NumberRange.new(30, 46), Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 2, 1, 2), LightEmission = 1, Brightness = 3 } },
	})
end
function FINISH.Abyssal(at, mv)
	puffs(at, Color3.fromRGB(30, 16, 50), 14, 16, 1.8, 0.35, 0.3, true)
	task.delay(0.3, function()
		flash(at, mv.accent, 12, 0.3)
		puffs(at, Color3.fromRGB(24, 12, 40), 14, 20, 1.8, 0.7, 0.3)
		popAt(at, {
			{ 24, { Texture = SPARK, Color = ColorSequence.new(mv.accent), Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(1.0, 1.6), Speed = NumberRange.new(4, 9), Acceleration = Vector3.new(0, 6, 0), Drag = 1, LightEmission = 1, Brightness = 2 } },
		})
	end)
end
function FINISH.Riftcaster(at, _mv)
	puffs(at, Color3.fromRGB(200, 240, 255), 12, 18, 1.3, 0.55, 0.5, false, 0.6)
	popAt(at, {
		{ 30, { Texture = SPARK, Color = RodModels.RAINBOW, Size = ns(0, 0.4, 1, 0.1), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(26, 40), Drag = 6, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 2.5, 1, 1), LightEmission = 1, Brightness = 2 } },
		{ 30, { Texture = SPARK, Color = RodModels.RAINBOW, Size = ns(0, 0.3, 0.5, 0.45, 1, 0), Lifetime = NumberRange.new(1.0, 1.5), Speed = NumberRange.new(5, 12), Drag = 4, Rotation = NumberRange.new(0, 360), LightEmission = 1, Brightness = 2 } },
	})
end
function FINISH.Celestial(at, mv)
	flash(at, mv.accent, 18, 0.35)
	puffs(at, mv.accent, 16, 18, 1.4, 0.7, 0.45, false, 0.9)
	popAt(at + Vector3.new(0, 1.5, 0), {
		{ 40, { Texture = SPARK, Color = ColorSequence.new(WHITE, mv.accent), Size = ns(0, 0.2, 0.3, 0.55, 1, 0), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(6, 14), Drag = 3, Acceleration = Vector3.new(0, 2, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), LightEmission = 1, Brightness = 2.5 } },
	})
end
function FINISH.CrimsonCrow(at, mv)
	puffs(at, Color3.fromRGB(40, 8, 14), 14, 16, 1.6, 0.65, 0.35)
	popAt(at + Vector3.new(0, 1, 0), {
		{ 22, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(30, 6, 10), Color3.fromRGB(90, 10, 20)), Size = ns(0, 0.6, 1, 0.4), Transparency = ns(0, 0, 0.8, 0.1, 1, 1), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(8, 14), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(75, 75), Drag = 2.5, Acceleration = Vector3.new(0, -4, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260), LightEmission = 0 } },
		{ 20, { Texture = SPARK, Color = ColorSequence.new(mv.accent), Size = ns(0, 0.25, 1, 0), Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(4, 8), Acceleration = Vector3.new(0, 7, 0), LightEmission = 1, Brightness = 2.5 } },
	})
end
function FINISH.Jackpot(at, mv)
	puffs(at, mv.accent:Lerp(WHITE, 0.4), 10, 14, 1.2, 0.5, 0.5, false, 0.5)
	popAt(at, {
		{ 34, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 236, 140), mv.accent), Size = ns(0, 0.55, 1, 0.4), Lifetime = NumberRange.new(0.9, 1.2), Speed = NumberRange.new(22, 32), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, -55, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400), LightEmission = 1, Brightness = 2 } },
		{ 14, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(90, 230, 120)), Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(8, 14), Drag = 3, LightEmission = 1 } },
	})
end
function FINISH.ThiefTome(at, mv)
	puffs(at, Color3.fromRGB(40, 22, 70), 14, 15, 1.7, 0.7, 0.3)
	popAt(at + Vector3.new(0, 1, 0), {
		{ 18, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(240, 232, 255)), Size = ns(0, 0.7, 1, 0.5), Transparency = ns(0, 0.1, 0.8, 0.2, 1, 1), Lifetime = NumberRange.new(1.3, 1.9), Speed = NumberRange.new(7, 12), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Drag = 2.5, Acceleration = Vector3.new(0, -3, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), LightEmission = 0.4 } },
		{ 16, { Texture = SPARK, Color = ColorSequence.new(mv.accent), Size = ns(0, 0.3, 1, 0), Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(5, 10), Drag = 2, LightEmission = 1, Brightness = 2 } },
	})
end
function FINISH.SunRubber(at, mv)
	flash(at, mv.accent, 14, 0.3)
	puffs(at, Color3.fromRGB(255, 236, 190), 12, 18, 1.3, 0.55, 0.45, false, 0.6)
	local function rays(scale)
		popAt(at + Vector3.new(0, 0.8, 0), {
			{ math.floor(24 * scale), { Texture = SPARK, Color = ColorSequence.new(WHITE, mv.accent), Size = ns(0, 0.5 * scale, 1, 0.1), Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(24 * scale, 34 * scale), Drag = 5, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 2, 1, 1), LightEmission = 1, Brightness = 2.5 } },
		})
	end
	rays(1)
	task.delay(0.28, function()
		rays(0.6) -- the bounce
		light(at, mv.accent, 4, 16, 0.3)
	end)
end
function FINISH.Boundless(at, mv)
	puffs(at, Color3.fromRGB(150, 210, 255), 16, 18, 1.6, 0.35, 0.4, true, 0.8)
	task.delay(0.3, function()
		flash(at, mv.accent, 20, 0.35)
		light(at, mv.accent, 10, 30, 0.6)
		puffs(at, Color3.fromRGB(210, 235, 255), 16, 24, 1.5, 0.6, 0.45, false, 0.9)
		popAt(at, {
			{ 30, { Texture = SPARK, Color = RodModels.RAINBOW, Size = ns(0, 0.4, 1, 0.1), Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(30, 44), Drag = 6, Orientation = Enum.ParticleOrientation.VelocityParallel, Squash = ns(0, 2.5, 1, 1), LightEmission = 1, Brightness = 2 } },
			{ 30, { Texture = SPARK, Color = ColorSequence.new(WHITE, mv.accent), Size = ns(0, 0.25, 0.4, 0.5, 1, 0), Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(5, 12), Drag = 3, Rotation = NumberRange.new(0, 360), LightEmission = 1, Brightness = 2.5 } },
		})
	end)
end

function RodFx.finisher(position, rodId)
	local mv = RodFx.move(rodId)
	flash(position, mv.accent, 12, 0.25)
	light(position, mv.accent, 8, 24, 0.5)
	RodFx.burst(position + Vector3.new(0, 1, 0), rodId, 1.6)
	local fn = FINISH[rodId] or FINISH.Drift
	fn(position, mv)
end

return RodFx
