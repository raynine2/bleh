-- Tidebound: Eggfall: the six rod models and their bobbers (Master Patch 7: the rod is a character).
-- Every rod is three segments along +Y (Handle, Mid, Tip) with a Reel under the handle. Mid and Tip hang on
-- Motor6Ds so code can bend the rod (Patch 5: one BendValue from 0 to 1 bends it 35 degrees in total).
-- The server puts your rod on your back (Rods.luau) and on your Rod Workshop rack; TideboundRod (client)
-- moves it, bends it, draws the line and plays its effects. The look only ever comes from owning the rod:
-- stats stay in Config.Rods.

local RodModels = {}

local function hex(value)
	return Color3.fromHex(value)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 80)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(110, 255, 140)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 110, 255)),
})
RodModels.RAINBOW = RAINBOW

-- Patch 7 table: line colour, trail, cast effect, glow. `aurora` = colour that never sits still,
-- `pulse` = a slow breathing glow. `castSound` names the cue in Audio.luau.
RodModels.looks = {
	Drift = { line = hex("F2F2F2"), castFx = "Dust", castSound = "CastDrift" },
	Coral = { line = hex("FFC4D6"), trail = ColorSequence.new(hex("FF7FA6"), hex("FFE2EC")), castFx = "Coral", glow = hex("FF9EC0"), castSound = "CastCoral" },
	Stormline = { line = hex("4AA0FF"), trail = ColorSequence.new(hex("E6F4FF"), hex("4AA0FF")), castFx = "Static", glow = hex("4AA0FF"), castSound = "CastStormline" },
	Abyssal = { line = hex("7A3CC8"), trail = ColorSequence.new(hex("9A5CFF"), hex("120C1C")), castFx = "Shadow", glow = hex("9A5CFF"), pulse = true, castSound = "CastAbyssal" },
	Riftcaster = { line = RAINBOW, trail = RAINBOW, castFx = "Rift", glow = hex("B4F0FF"), aurora = true, castSound = "CastRiftcaster" },
	Celestial = { line = hex("FFF1C4"), trail = RAINBOW, castFx = "Aurora", glow = hex("FFF1C4"), aurora = true, castSound = "CastCelestial" },
}

RodModels.HANDLE, RodModels.MID, RodModels.TIP = 1.6, 2.4, 2.4 -- segment lengths in studs
RodModels.GRIP = Vector3.new(0, -0.2, 0) -- where the right hand holds, in Handle space
RodModels.BEND = { mid = 12, tip = 23 } -- degrees at BendValue 1 (35 in total)

local function part(model, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A decoration welded to `base` at `offset` (in base space).
local function deco(base, name, size, offset, color, material, shape)
	local p = part(base.Parent, name, size, base.CFrame * offset, color, material, shape)
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	return p
end

local function joint(name, part0, part1, c0, c1)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	return motor
end

local function light(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Name = "Glow"
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

-- A ring of `count` neon blocks around a small invisible core that a Motor6D can spin.
local function ring(base, name, offset, radius, color, count, thickness)
	local core = part(base.Parent, name .. "Core", Vector3.new(0.05, 0.05, 0.05), base.CFrame * offset, color)
	core.Transparency = 1
	local motor = joint(name, base, core, offset, CFrame.new())
	local arc = 2 * math.pi * radius / count
	for i = 1, count do
		local angle = (i - 1) / count * 2 * math.pi
		local segOffset = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		local seg = deco(core, "Glow", Vector3.new(arc * 1.05, thickness, thickness), segOffset, color, Enum.Material.Neon)
		seg.Transparency = 0.1
	end
	return motor
end

local BUILDERS = {}

function BUILDERS.Drift(model, h, m, t, reel)
	-- a plain pole you could cut from a tree: rough wood, a twine grip, a tin reel
	for _, seg in ipairs({ h, m, t }) do
		seg.Material = Enum.Material.Wood
	end
	h.Color, m.Color, t.Color = Color3.fromRGB(116, 80, 48), Color3.fromRGB(140, 100, 60), Color3.fromRGB(160, 120, 74)
	deco(h, "Grip", Vector3.new(0.36, 0.8, 0.36), CFrame.new(0, -0.3, 0), Color3.fromRGB(214, 186, 132), Enum.Material.Fabric)
	deco(m, "Knot", Vector3.new(0.26, 0.2, 0.26), CFrame.new(0, -0.2, 0), Color3.fromRGB(110, 76, 44), Enum.Material.Wood)
	reel.Color = Color3.fromRGB(150, 150, 156)
	reel.Material = Enum.Material.Metal
end

function BUILDERS.Coral(model, h, m, t, reel, look)
	-- curved, with coral growing along it, and a soft pink glow at the tip
	h.Material, h.Color = Enum.Material.Wood, Color3.fromRGB(108, 66, 48)
	m.Material, m.Color = Enum.Material.Wood, Color3.fromRGB(150, 96, 70)
	t.Color = Color3.fromRGB(255, 136, 160)
	deco(h, "Grip", Vector3.new(0.36, 0.8, 0.36), CFrame.new(0, -0.3, 0), Color3.fromRGB(255, 170, 190), Enum.Material.Fabric)
	local coral = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 176, 120), Color3.fromRGB(255, 150, 190) }
	for i, spec in ipairs({ { m, 0.1, 0.5 }, { m, -0.6, -0.45 }, { t, -0.5, 0.55 }, { t, 0.3, -0.6 } }) do
		local seg, y, tilt = spec[1], spec[2], spec[3]
		local side = (i % 2 == 0) and -1 or 1
		local branch = deco(seg, "Coral", Vector3.new(0.14, 0.5, 0.14), CFrame.new(side * 0.16, y, 0) * CFrame.Angles(0, 0, tilt), coral[(i - 1) % 3 + 1])
		deco(branch, "Coral", Vector3.new(0.12, 0.3, 0.12), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, -tilt * 1.2), coral[i % 3 + 1])
	end
	local tip = deco(t, "Glow", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, RodModels.TIP / 2, 0), look.glow, Enum.Material.Neon, Enum.PartType.Ball)
	light(tip, look.glow, 1.2, 7)
	reel.Color = Color3.fromRGB(240, 200, 210)
	model:SetAttribute("Curve", 6) -- degrees the tip curls at rest
end

function BUILDERS.Stormline(model, h, m, t, reel, look)
	-- angular brushed steel, wrapped in bands, with a blue arc at the reel
	local steel = Color3.fromRGB(150, 160, 172)
	for _, seg in ipairs({ h, m, t }) do
		seg.Material, seg.Color = Enum.Material.Metal, steel
	end
	deco(h, "Grip", Vector3.new(0.38, 0.9, 0.38), CFrame.new(0, -0.25, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(44, 48, 58), Enum.Material.Fabric)
	for _, spec in ipairs({ { m, -0.7 }, { m, 0.4 }, { t, -0.6 }, { t, 0.4 } }) do
		deco(spec[1], "Wrap", Vector3.new(0.3, 0.12, 0.3), CFrame.new(0, spec[2], 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(44, 48, 58), Enum.Material.Metal)
		deco(spec[1], "Glow", Vector3.new(0.26, 0.05, 0.26), CFrame.new(0, spec[2] + 0.1, 0) * CFrame.Angles(0, math.rad(45), 0), look.glow, Enum.Material.Neon)
	end
	for _, side in ipairs({ -1, 1 }) do
		deco(h, "Fin", Vector3.new(0.06, 0.6, 0.3), CFrame.new(side * 0.17, 0.45, 0.06) * CFrame.Angles(0, 0, side * 0.3), Color3.fromRGB(110, 120, 134), Enum.Material.Metal)
	end
	reel.Material, reel.Color = Enum.Material.Metal, Color3.fromRGB(70, 78, 92)
	local arc = deco(reel, "Glow", Vector3.new(0.26, 0.08, 0.46), CFrame.new(0, 0.12, 0), look.glow, Enum.Material.Neon)
	light(arc, look.glow, 1.4, 6)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Arc"
	sparks.Color = ColorSequence.new(Color3.fromRGB(200, 236, 255), look.glow)
	sparks.LightEmission = 1
	sparks.Rate = 5
	sparks.Lifetime = NumberRange.new(0.08, 0.16)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.08, 0)
	sparks.Parent = arc
end

function BUILDERS.Abyssal(model, h, m, t, reel, look)
	-- dark, organic and ribbed: chitin over metal, with a purple pulse running down it
	local chitin = Color3.fromRGB(34, 26, 46)
	h.Material, h.Color = Enum.Material.Metal, Color3.fromRGB(62, 56, 78)
	m.Color, t.Color = chitin, chitin
	deco(h, "Grip", Vector3.new(0.36, 0.9, 0.36), CFrame.new(0, -0.25, 0), Color3.fromRGB(46, 34, 62), Enum.Material.Fabric)
	for _, spec in ipairs({ { m, -0.9 }, { m, -0.3 }, { m, 0.3 }, { m, 0.9 }, { t, -0.8 }, { t, -0.1 }, { t, 0.6 } }) do
		local width = spec[1] == m and 0.3 or 0.2
		deco(spec[1], "Rib", Vector3.new(width, 0.14, width), CFrame.new(0, spec[2], 0), Color3.fromRGB(60, 40, 90))
	end
	deco(m, "Glow", Vector3.new(0.06, RodModels.MID * 0.9, 0.06), CFrame.new(0, 0, 0.1), look.glow, Enum.Material.Neon)
	deco(t, "Glow", Vector3.new(0.05, RodModels.TIP * 0.9, 0.05), CFrame.new(0, 0, 0.06), look.glow, Enum.Material.Neon)
	reel.Material, reel.Color = Enum.Material.Metal, Color3.fromRGB(40, 34, 54)
	local core = deco(reel, "Glow", Vector3.new(0.24, 0.2, 0.2), CFrame.new(), look.glow, Enum.Material.Neon)
	light(core, look.glow, 1.2, 7)
end

function BUILDERS.Riftcaster(model, h, m, t, reel, look)
	-- geometric crystal over metal, with parts that float free of the rod
	h.Material, h.Color = Enum.Material.Metal, Color3.fromRGB(58, 62, 80)
	for _, seg in ipairs({ m, t }) do
		seg.Material, seg.Color, seg.Transparency = Enum.Material.Glass, Color3.fromRGB(200, 226, 255), 0.35
		deco(seg, "Glow", Vector3.new(0.06, seg.Size.Y * 0.92, 0.06), CFrame.new(), look.glow, Enum.Material.Neon)
	end
	deco(h, "Grip", Vector3.new(0.36, 0.9, 0.36), CFrame.new(0, -0.25, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(34, 36, 50), Enum.Material.Fabric)
	deco(h, "Glow", Vector3.new(0.34, 0.08, 0.34), CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.rad(45), 0), look.glow, Enum.Material.Neon)
	reel.Material, reel.Color = Enum.Material.Metal, Color3.fromRGB(80, 86, 110)
	for i, spec in ipairs({ { m, Vector3.new(0.5, -0.4, 0) }, { m, Vector3.new(-0.45, 0.6, 0.1) }, { t, Vector3.new(0.35, 0.2, -0.2) } }) do
		local seg, offset = spec[1], spec[2]
		local cf = CFrame.new(offset)
		local shard = part(model, "Shard", Vector3.new(0.18, 0.42, 0.18), seg.CFrame * cf * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(190, 230, 255), Enum.Material.Glass)
		shard.Transparency = 0.2
		joint("RodFloat" .. i, seg, shard, cf, CFrame.Angles(0, 0, math.rad(-45)))
		deco(shard, "Glow", Vector3.new(0.06, 0.3, 0.06), CFrame.new(), look.glow, Enum.Material.Neon)
	end
	light(t, look.glow, 1.3, 8)
end

function BUILDERS.Celestial(model, h, m, t, reel, look)
	-- gold and light, ringed with halos, the tip barely held to the rod
	local gold = Color3.fromRGB(255, 212, 110)
	h.Material, h.Color = Enum.Material.Metal, gold
	m.Color, t.Color = Color3.fromRGB(255, 244, 214), Color3.fromRGB(255, 250, 232)
	deco(h, "Grip", Vector3.new(0.36, 0.9, 0.36), CFrame.new(0, -0.25, 0), Color3.fromRGB(250, 246, 236), Enum.Material.Fabric)
	deco(m, "Glow", Vector3.new(0.06, RodModels.MID * 0.9, 0.06), CFrame.new(0, 0, 0.08), look.glow, Enum.Material.Neon)
	deco(t, "Glow", Vector3.new(0.05, RodModels.TIP * 0.9, 0.05), CFrame.new(0, 0, 0.06), look.glow, Enum.Material.Neon)
	deco(t, "Glow", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, RodModels.TIP / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(45)), look.glow, Enum.Material.Neon)
	reel.Material, reel.Color = Enum.Material.Metal, gold
	ring(t, "RodHalo", CFrame.new(0, 0.5, 0), 0.5, look.glow, 10, 0.07)
	ring(h, "RodHalo2", CFrame.new(0, 0.62, 0) * CFrame.Angles(math.rad(20), 0, 0), 0.38, gold, 8, 0.06)
	light(t, look.glow, 1.5, 9)
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Color = RAINBOW
	motes.LightEmission = 1
	motes.Rate = 4
	motes.Lifetime = NumberRange.new(0.8, 1.4)
	motes.Speed = NumberRange.new(0.3, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Size = NumberSequence.new(0.12, 0)
	motes.Parent = t
end

-- Builds a rod model for `rodId`. Its PrimaryPart is the Handle; parts are unanchored and massless, so weld
-- the Handle to a character (or an anchored peg) and the rest follows.
function RodModels.build(rodId)
	local look = RodModels.looks[rodId] or RodModels.looks.Drift
	local model = Instance.new("Model")
	model.Name = "Rod_" .. rodId
	local base = CFrame.new()
	local h = part(model, "Handle", Vector3.new(0.3, RodModels.HANDLE, 0.3), base, Color3.new(1, 1, 1))
	model.PrimaryPart = h
	local midOffset = CFrame.new(0, RodModels.HANDLE / 2, 0)
	local m = part(model, "Mid", Vector3.new(0.2, RodModels.MID, 0.2), base * midOffset * CFrame.new(0, RodModels.MID / 2, 0), Color3.new(1, 1, 1))
	joint("RodMid", h, m, midOffset, CFrame.new(0, -RodModels.MID / 2, 0))
	local tipOffset = CFrame.new(0, RodModels.MID / 2, 0)
	local t = part(model, "Tip", Vector3.new(0.12, RodModels.TIP, 0.12), m.CFrame * tipOffset * CFrame.new(0, RodModels.TIP / 2, 0), Color3.new(1, 1, 1))
	joint("RodTip", m, t, tipOffset, CFrame.new(0, -RodModels.TIP / 2, 0))
	-- the reel hangs under the rod (the -Z side) just ahead of the grip; the crank is on the left
	local reel = deco(h, "Reel", Vector3.new(0.22, 0.4, 0.4), CFrame.new(0, 0.3, -0.32), Color3.new(1, 1, 1))
	deco(reel, "ReelFoot", Vector3.new(0.08, 0.3, 0.14), CFrame.new(0, 0, 0.2), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	deco(reel, "Crank", Vector3.new(0.22, 0.06, 0.06), CFrame.new(-0.2, 0, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	deco(reel, "Knob", Vector3.new(0.1, 0.14, 0.1), CFrame.new(-0.3, 0.08, 0), Color3.fromRGB(30, 30, 34))
	local decorate = BUILDERS[rodId] or BUILDERS.Drift
	decorate(model, h, m, t, reel, look)
	-- the line leaves the tip; its axis (X) is pointed down every frame so the slack sags
	local lineAttachment = Instance.new("Attachment")
	lineAttachment.Name = "LineAttachment"
	lineAttachment.Position = Vector3.new(0, RodModels.TIP / 2, 0)
	lineAttachment.Parent = t
	-- the cast trail runs along the tip and is switched on for the whip
	if look.trail then
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, RodModels.TIP / 2, 0)
		top.Parent = t
		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -RodModels.TIP / 4, 0)
		bottom.Parent = t
		local trail = Instance.new("Trail")
		trail.Name = "CastTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = look.trail
		trail.LightEmission = 0.8
		trail.Lifetime = 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = t
	end
	model:SetAttribute("RodId", rodId)
	RodModels.setBend(model, 0)
	return model
end

-- BendValue 0 to 1 (Patch 5). Negative X rotation bends the tip toward the reel side, which faces the water.
function RodModels.setBend(model, bend)
	local h = model.PrimaryPart
	local m = model:FindFirstChild("Mid")
	local midJoint = h and h:FindFirstChild("RodMid")
	local tipJoint = m and m:FindFirstChild("RodTip")
	if not midJoint or not tipJoint then
		return
	end
	local curve = model:GetAttribute("Curve") or 0
	midJoint.Transform = CFrame.Angles(-math.rad(RodModels.BEND.mid * bend), 0, 0)
	tipJoint.Transform = CFrame.Angles(-math.rad(RodModels.BEND.tip * bend + curve), 0, 0)
end

-- The rod's Glow parts and lights, for the aurora cycle and the Abyssal pulse (see RodModels.tint).
function RodModels.glows(model)
	local out = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p.Name == "Glow" and (p:IsA("BasePart") or p:IsA("PointLight")) then
			table.insert(out, p)
		end
	end
	return out
end

function RodModels.tint(glows, color, brightness)
	for _, p in ipairs(glows) do
		p.Color = color
		if brightness and p:IsA("PointLight") then
			p.Brightness = brightness
		end
	end
end

-- Bobbers are client-side: anchored, moved with PivotTo. The line ties on at "LineAttachment".
function RodModels.bobber(rodId)
	local model = Instance.new("Model")
	model.Name = "Bobber_" .. (rodId or "Drift")
	local function piece(name, size, offset, color, material, shape)
		local p = part(model, name, size, offset, color, material, shape)
		p.Anchored = true
		return p
	end
	local float
	if rodId == "Coral" then
		float = piece("Float", Vector3.new(0.45, 0.45, 0.45), CFrame.new(), Color3.fromRGB(255, 130, 160), nil, Enum.PartType.Ball)
		piece("Branch", Vector3.new(0.1, 0.35, 0.1), CFrame.new(0.12, 0.25, 0) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(255, 180, 120))
		piece("Branch", Vector3.new(0.1, 0.3, 0.1), CFrame.new(-0.12, 0.22, 0.05) * CFrame.Angles(0.3, 0, 0.6), Color3.fromRGB(255, 160, 200))
	elseif rodId == "Stormline" then
		float = piece("Float", Vector3.new(0.5, 0.5, 0.5), CFrame.new(), Color3.fromRGB(170, 178, 190), Enum.Material.Metal, Enum.PartType.Ball)
		piece("Band", Vector3.new(0.54, 0.1, 0.54), CFrame.new(0, 0.04, 0), hex("4AA0FF"), Enum.Material.Neon)
	elseif rodId == "Abyssal" then
		float = piece("Float", Vector3.new(0.5, 0.5, 0.5), CFrame.new(), Color3.fromRGB(16, 12, 24), Enum.Material.Glass, Enum.PartType.Ball)
		float.Reflectance = 0.25
		light(float, hex("9A5CFF"), 1.5, 5)
		piece("Core", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, 0.1, 0), hex("9A5CFF"), Enum.Material.Neon, Enum.PartType.Ball)
	elseif rodId == "Riftcaster" then
		float = piece("Float", Vector3.new(0.3, 0.7, 0.3), CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(190, 230, 255), Enum.Material.Glass)
		float.Transparency = 0.15
		light(float, Color3.fromRGB(180, 240, 255), 1.5, 5)
	elseif rodId == "Celestial" then
		float = piece("Float", Vector3.new(0.7, 0.18, 0.18), CFrame.new(), Color3.fromRGB(255, 216, 100), Enum.Material.Neon)
		for _, angle in ipairs({ 45, 90, 135 }) do
			piece("Ray", Vector3.new(angle == 90 and 0.7 or 0.5, 0.18, 0.18), CFrame.Angles(0, 0, math.rad(angle)), Color3.fromRGB(255, 226, 130), Enum.Material.Neon)
		end
		light(float, Color3.fromRGB(255, 230, 150), 2, 6)
	else
		float = piece("Float", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.06, 0), Color3.fromRGB(230, 40, 40), nil, Enum.PartType.Ball)
		piece("Bottom", Vector3.new(0.48, 0.48, 0.48), CFrame.new(0, -0.08, 0), Color3.fromRGB(245, 245, 245), nil, Enum.PartType.Ball)
		piece("Stem", Vector3.new(0.06, 0.25, 0.06), CFrame.new(0, 0.38, 0), Color3.fromRGB(245, 245, 245))
	end
	model.PrimaryPart = float
	local attachment = Instance.new("Attachment")
	attachment.Name = "LineAttachment"
	attachment.Position = Vector3.new(0, 0.25, 0)
	attachment.Parent = float
	return model
end

return RodModels
