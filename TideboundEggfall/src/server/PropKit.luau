-- Tidebound: Eggfall: the reference-style prop kit (Patch 14). Every piece is chunky voxel blocks with classic
-- studs, in the look of the reference shots the user picked:
--   winter town   log cabins with thick snow roofs, icicles, lattice windows that glow and smoking chimneys;
--                 gallows lamp posts with a hanging lantern; round-topped wooden fences; white studded neon shops
--                 with a red frame; vending machines; glowing ice crystals; snow mounds; igloos; voxel ice cliffs
--   ice zone      glowing ice with white crack lines; wooden scaffold beams with lanterns
--   green hub     brick houses with tiled roofs and big glowing windows; white picket fences; paving inlays and
--                 loose tiles set into the floor; striped market stalls
-- Builders call these with world positions; `facing` is the point a building's front looks at.

local CollectionService = game:GetService("CollectionService")

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local K = WorldBuilder.kit
local part, decor, light, particles, surfaceText = K.part, K.decor, K.light, K.particles, K.surfaceText

local PropKit = {}

-- palette (sampled by eye from the references)
local C = {
	SNOW = Color3.fromRGB(176, 190, 214), -- Patch 15: a soft blue-grey, so it never glares
	SNOW_SHADE = Color3.fromRGB(150, 166, 196),
	LOG = Color3.fromRGB(150, 88, 60),
	LOG_DARK = Color3.fromRGB(112, 64, 46),
	LOG_END = Color3.fromRGB(196, 140, 96),
	WOOD = Color3.fromRGB(176, 108, 68),
	WOOD_DARK = Color3.fromRGB(120, 72, 46),
	BRICK = Color3.fromRGB(200, 130, 96),
	BRICK_DARK = Color3.fromRGB(168, 104, 78),
	WINDOW = Color3.fromRGB(176, 236, 255),
	WINDOW_WARM = Color3.fromRGB(255, 230, 170),
	ICE = Color3.fromRGB(120, 220, 255),
	ICE_DEEP = Color3.fromRGB(60, 150, 230),
	PAVER = Color3.fromRGB(150, 160, 178),
	PAVER_DARK = Color3.fromRGB(112, 122, 142),
	CLIFF = Color3.fromRGB(96, 120, 186),
	CLIFF_DARK = Color3.fromRGB(70, 90, 156),
	NEON_RED = Color3.fromRGB(226, 60, 90),
	WHITE = Color3.fromRGB(214, 218, 228),
	LANTERN = Color3.fromRGB(230, 160, 90),
}
PropKit.color = C

local function studs(p)
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	return p
end
PropKit.studs = studs

local function sbrick(props)
	return studs(part(props))
end

local function sdecor(props)
	return studs(decor(props))
end

local function look(center, facing)
	return CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
end

-- Lanterns ------------------------------------------------------------------------------------------------------

-- A boxy lantern hanging at `cf` (its top), glowing warm.
local function lantern(parent, cf, scale)
	scale = scale or 1
	local s = scale
	decor({ Name = "LanternTop", Size = Vector3.new(1.4, 0.4, 1.4) * s, CFrame = cf * CFrame.new(0, -0.2 * s, 0), Color = Color3.fromRGB(40, 36, 40), Parent = parent })
	for _, x in ipairs({ -0.55, 0.55 }) do
		for _, z in ipairs({ -0.55, 0.55 }) do
			decor({ Name = "LanternBar", Size = Vector3.new(0.18, 1.6, 0.18) * s, CFrame = cf * CFrame.new(x * s, -1.2 * s, z * s), Color = Color3.fromRGB(40, 36, 40), Parent = parent })
		end
	end
	local glow = decor({ Name = "LanternGlow", Size = Vector3.new(0.9, 1.4, 0.9) * s, CFrame = cf * CFrame.new(0, -1.2 * s, 0), Color = C.LANTERN, Material = Enum.Material.Neon, Parent = parent })
	decor({ Name = "LanternBase", Size = Vector3.new(1.2, 0.3, 1.2) * s, CFrame = cf * CFrame.new(0, -2.1 * s, 0), Color = Color3.fromRGB(40, 36, 40), Parent = parent })
	light(glow, Color3.fromRGB(255, 190, 110), 20 * s, 1.3)
	return glow
end
PropKit.lantern = lantern

-- The reference's gallows lamp post: a studded wooden post, an arm with a brace, a chain and a lantern.
function PropKit.gallowsLamp(parent, base, facing)
	local cf = look(base, facing)
	sbrick({ Name = "LampFoot", Size = Vector3.new(2.2, 1, 2.2), CFrame = cf * CFrame.new(0, 0.5, 0), Color = C.PAVER, Parent = parent })
	sdecor({ Name = "LampPost", Size = Vector3.new(1.2, 13, 1.2), CFrame = cf * CFrame.new(0, 7, 0), Color = C.WOOD, Parent = parent })
	sdecor({ Name = "LampArm", Size = Vector3.new(1, 1, 5), CFrame = cf * CFrame.new(0, 12.4, -2.2), Color = C.WOOD, Parent = parent })
	decor({ Name = "LampBrace", Size = Vector3.new(0.6, 0.6, 3.6), CFrame = cf * CFrame.new(0, 10.8, -1.3) * CFrame.Angles(math.rad(45), 0, 0), Color = C.WOOD_DARK, Parent = parent })
	decor({ Name = "LampCap", Size = Vector3.new(1.6, 0.6, 1.6), CFrame = cf * CFrame.new(0, 13.7, 0), Color = C.SNOW, Parent = parent })
	decor({ Name = "Chain", Size = Vector3.new(0.2, 1.4, 0.2), CFrame = cf * CFrame.new(0, 11.2, -4.2), Color = Color3.fromRGB(60, 60, 66), Parent = parent })
	lantern(parent, cf * CFrame.new(0, 10.5, -4.2), 1)
end

-- Fences --------------------------------------------------------------------------------------------------------

-- Round-topped brown fence posts with two rails (the snow town's fences).
function PropKit.woodFence(parent, a, b, y)
	local fa, fb = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	local length = (fb - fa).Magnitude
	local frame = CFrame.lookAt((fa + fb) / 2, fb)
	local n = math.max(1, math.floor(length / 2.6))
	for i = 0, n do
		local z = -length / 2 + i * length / n
		local post = frame * CFrame.new(0, 1.6, z)
		sdecor({ Name = "FencePost", Size = Vector3.new(1, 3.2, 0.8), CFrame = post, Color = (i % 2 == 0) and C.WOOD or C.WOOD_DARK, Parent = parent })
		decor({ Name = "FenceTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 1, 1), CFrame = post * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(90), 0), Color = C.WOOD, Parent = parent })
	end
	for _, h in ipairs({ 1.1, 2.3 }) do
		sbrick({ Name = "FenceRail", Size = Vector3.new(0.5, 0.5, length), CFrame = frame * CFrame.new(0, h, -0.5), Color = C.WOOD_DARK, Parent = parent })
	end
end

-- A white picket fence (the green hub's).
function PropKit.picketFence(parent, a, b, y)
	local fa, fb = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	local length = (fb - fa).Magnitude
	local frame = CFrame.lookAt((fa + fb) / 2, fb)
	local n = math.max(1, math.floor(length / 1.4))
	for i = 0, n do
		local z = -length / 2 + i * length / n
		decor({ Name = "Picket", Size = Vector3.new(0.8, 2.8, 0.3), CFrame = frame * CFrame.new(0, 1.4, z), Color = C.WHITE, Parent = parent })
		decor({ Name = "PicketTip", Size = Vector3.new(0.56, 0.56, 0.3), CFrame = frame * CFrame.new(0, 2.85, z) * CFrame.Angles(0, 0, math.rad(45)), Color = C.WHITE, Parent = parent })
	end
	for _, h in ipairs({ 0.9, 2 }) do
		part({ Name = "PicketRail", Size = Vector3.new(0.3, 0.4, length), CFrame = frame * CFrame.new(0, h, 0.25), Color = Color3.fromRGB(226, 226, 232), Parent = parent })
	end
end

-- Buildings -----------------------------------------------------------------------------------------------------

-- Snow on a roof: a thick white slab with a soft overhang and icicles hanging off the eave.
local function snowRoof(parent, cf, w, length, rng)
	sdecor({ Name = "RoofSnow", Size = Vector3.new(w + 0.6, 1.2, length + 0.4), CFrame = cf * CFrame.new(0, 0.9, 0), Color = C.SNOW, Parent = parent })
	sdecor({ Name = "RoofSnowLump", Size = Vector3.new(w * 0.6, 0.7, length * 0.5), CFrame = cf * CFrame.new(rng:NextNumber(-w * 0.15, w * 0.15), 1.7, rng:NextNumber(-length * 0.2, length * 0.2)), Color = C.SNOW, Parent = parent })
	for x = -w / 2 + 0.8, w / 2 - 0.8, 1.6 do
		local len = rng:NextNumber(0.6, 1.8)
		decor({ Name = "Icicle", Size = Vector3.new(0.35, len, 0.35), CFrame = cf * CFrame.new(x, 0.2 - len / 2, length / 2 + 0.1), Color = Color3.fromRGB(200, 236, 255), Material = Enum.Material.Glass, Transparency = 0.15, Parent = parent })
	end
end

-- The reference's log cabin: a stone base, walls of stacked studded logs with lighter crossed ends at the
-- corners, glowing diamond-lattice windows, a door under a snowy porch with a lantern, a steep roof buried in
-- snow with icicles, and a chimney puffing smoke.
function PropKit.logCabin(parent, center, facing, w, d, h, rng)
	local cf = look(center, facing)
	local model = Instance.new("Model")
	model.Name = "LogCabin"
	model.Parent = parent
	sbrick({ Name = "Base", Size = Vector3.new(w + 1.2, 1.2, d + 1.2), CFrame = cf * CFrame.new(0, 0.6, 0), Color = C.PAVER, Parent = model })
	part({ Name = "Core", Size = Vector3.new(w - 0.6, h, d - 0.6), CFrame = cf * CFrame.new(0, 1.2 + h / 2, 0), Color = C.LOG_DARK, Parent = model })
	-- logs, alternating long sides and short sides like real stacked logs
	local log = 1.1
	local rows = math.floor(h / log)
	for i = 0, rows - 1 do
		local y = 1.2 + log / 2 + i * log
		local color = (i % 2 == 0) and C.LOG or C.LOG:Lerp(C.LOG_DARK, 0.4)
		for _, side in ipairs({ -1, 1 }) do
			sdecor({ Name = "LogLong", Size = Vector3.new(w + (i % 2 == 0 and 1.2 or 0), log, 1), CFrame = cf * CFrame.new(0, y, side * d / 2), Color = color, Parent = model })
			sdecor({ Name = "LogShort", Size = Vector3.new(1, log, d + (i % 2 == 1 and 1.2 or 0)), CFrame = cf * CFrame.new(side * w / 2, y, 0), Color = color, Parent = model })
		end
	end
	-- glowing lattice windows
	local function window(at, ww, wh)
		decor({ Name = "WindowFrame", Size = Vector3.new(ww + 0.8, wh + 0.8, 0.4), CFrame = at, Color = C.WOOD_DARK, Parent = model })
		decor({ Name = "WindowGlow", Size = Vector3.new(ww, wh, 0.3), CFrame = at * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(230, 236, 255), Material = Enum.Material.Neon, Transparency = 0.1, Parent = model })
		for k = -2, 2 do
			decor({ Name = "Lattice", Size = Vector3.new(0.16, wh * 1.42, 0.2), CFrame = at * CFrame.new(k * ww / 5, 0, -0.3) * CFrame.Angles(0, 0, math.rad(45)), Color = C.WOOD_DARK, Parent = model })
			decor({ Name = "Lattice", Size = Vector3.new(0.16, wh * 1.42, 0.2), CFrame = at * CFrame.new(k * ww / 5, 0, -0.3) * CFrame.Angles(0, 0, math.rad(-45)), Color = C.WOOD_DARK, Parent = model })
		end
		sdecor({ Name = "SillSnow", Size = Vector3.new(ww + 1.2, 0.4, 0.8), CFrame = at * CFrame.new(0, -wh / 2 - 0.5, -0.4), Color = C.SNOW, Parent = model })
	end
	for _, x in ipairs({ -w / 3.2, w / 3.2 }) do
		window(cf * CFrame.new(x, 1.2 + h * 0.55, -d / 2 - 0.55), 2.6, 2.6)
	end
	for _, side in ipairs({ -1, 1 }) do
		window(cf * CFrame.new(side * (w / 2 + 0.55), 1.2 + h * 0.55, 0) * CFrame.Angles(0, side * math.rad(-90), 0), 2.2, 2.2)
	end
	-- the door, porch roof, steps and a lantern
	local door = cf * CFrame.new(0, 1.2 + 2.3, -d / 2 - 0.55)
	decor({ Name = "DoorFrame", Size = Vector3.new(3.4, 5, 0.4), CFrame = door * CFrame.new(0, 0.2, 0), Color = C.WOOD_DARK, Parent = model })
	sdecor({ Name = "Door", Size = Vector3.new(2.6, 4.4, 0.3), CFrame = door * CFrame.new(0, -0.1, -0.1), Color = C.WOOD, Parent = model })
	decor({ Name = "DoorWindow", Size = Vector3.new(1.2, 1.2, 0.2), CFrame = door * CFrame.new(0, 1, -0.3), Color = C.WINDOW_WARM, Material = Enum.Material.Neon, Parent = model })
	sbrick({ Name = "Step", Size = Vector3.new(4.4, 0.6, 1.6), CFrame = cf * CFrame.new(0, 0.3, -d / 2 - 1.4), Color = C.PAVER, Parent = model })
	sdecor({ Name = "Porch", Size = Vector3.new(5, 0.5, 2.4), CFrame = cf * CFrame.new(0, 1.2 + 5.2, -d / 2 - 1.3), Color = C.WOOD_DARK, Parent = model })
	sdecor({ Name = "PorchSnow", Size = Vector3.new(5.2, 0.5, 2.6), CFrame = cf * CFrame.new(0, 1.2 + 5.7, -d / 2 - 1.3), Color = C.SNOW, Parent = model })
	lantern(model, cf * CFrame.new(2.6, 1.2 + 5, -d / 2 - 1.2), 0.7)
	-- the roof: two slopes of studded planks under a thick layer of snow, gables filled with logs
	local half = d / 2 + 1.4
	local rise = math.min(h * 0.9, half * 1.1)
	local slope = math.atan2(rise, half)
	local length = math.sqrt(half * half + rise * rise)
	for _, dir in ipairs({ -1, 1 }) do
		local roof = cf * CFrame.new(0, 1.2 + h + rise / 2, dir * half / 2) * CFrame.Angles(dir * slope, 0, 0)
		sdecor({ Name = "Roof", Size = Vector3.new(w + 2.4, 0.8, length), CFrame = roof, Color = C.WOOD_DARK, Parent = model })
		-- snowRoof hangs icicles off its local +Z edge: turn it so that's the eave
		snowRoof(model, roof * CFrame.Angles(0, dir < 0 and math.pi or 0, 0), w + 2.4, length, rng)
	end
	for _, side in ipairs({ -1, 1 }) do
		local steps = 5
		for i = 0, steps - 1 do
			local s = i / steps
			decor({ Name = "Gable", Size = Vector3.new(0.8, rise / steps + 0.05, 2 * half * (1 - s) - 1.2), CFrame = cf * CFrame.new(side * (w / 2), 1.2 + h + rise * s + rise / steps / 2, 0), Color = C.LOG, Parent = model })
		end
	end
	local chimney = sdecor({ Name = "Chimney", Size = Vector3.new(2, rise + 4, 2), CFrame = cf * CFrame.new(w / 3, 1.2 + h + (rise + 4) / 2, d / 5), Color = Color3.fromRGB(110, 110, 124), Parent = model })
	sdecor({ Name = "ChimneySnow", Size = Vector3.new(2.4, 0.6, 2.4), CFrame = chimney.CFrame * CFrame.new(0, (rise + 4) / 2 + 0.3, 0), Color = C.SNOW, Parent = model })
	particles(chimney, {
		Color = ColorSequence.new(Color3.fromRGB(236, 240, 250)),
		Rate = 4,
		Lifetime = NumberRange.new(3.5, 5.5),
		Speed = NumberRange.new(2, 3.5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 0.4,
		WindAffectsDrag = true,
	})
	-- a little snow drift against the walls and a stack of firewood
	sdecor({ Name = "Drift", Size = Vector3.new(w * 0.5, 1, 2), CFrame = cf * CFrame.new(-w / 4, 1.4, d / 2 + 1), Color = C.SNOW, Parent = model })
	for k = 0, 2 do
		decor({ Name = "Firewood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.8, 0.8), CFrame = cf * CFrame.new(-w / 2 - 1.2, 1.6 + k * 0.7, 1 + (k % 2) * 0.4) * CFrame.Angles(0, math.rad(90), 0), Color = C.LOG_END, Parent = model })
	end
	return cf
end

-- The green hub's brick house: studded brick walls with a darker band, white corners, big glowing light-blue
-- windows in white frames, a door, and a roof of coloured tile rows stepping up to a ridge with a dormer window.
function PropKit.brickHouse(parent, center, facing, w, d, h, roofColor)
	local cf = look(center, facing)
	local model = Instance.new("Model")
	model.Name = "BrickHouse"
	model.Parent = parent
	sbrick({ Name = "Base", Size = Vector3.new(w + 1, 1, d + 1), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(150, 150, 160), Parent = model })
	part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, 1 + h / 2, 0), Color = C.BRICK, Material = Enum.Material.Plastic, Parent = model })
	-- brick courses: staggered blocks across the front
	local course = 1
	for i = 0, math.floor(h / course) - 1 do
		local offset = (i % 2 == 0) and 0 or 1.2
		for x = -w / 2 + offset, w / 2 - 1.2, 2.4 do
			if (math.floor(x * 7 + i * 3) % 3) == 0 then
				sdecor({ Name = "Brick", Size = Vector3.new(2.2, course - 0.15, 0.2), CFrame = cf * CFrame.new(x + 1.1, 1 + course / 2 + i * course, -d / 2 - 0.1), Color = C.BRICK_DARK, Parent = model })
			end
		end
	end
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			sdecor({ Name = "Corner", Size = Vector3.new(1.2, h, 1.2), CFrame = cf * CFrame.new(x, 1 + h / 2, z), Color = C.WHITE, Parent = model })
		end
	end
	decor({ Name = "Band", Size = Vector3.new(w + 0.3, 0.6, d + 0.3), CFrame = cf * CFrame.new(0, 1 + h * 0.5, 0), Color = C.WHITE, Parent = model })
	local function window(at, ww, wh)
		decor({ Name = "WindowFrame", Size = Vector3.new(ww + 0.8, wh + 0.8, 0.4), CFrame = at, Color = C.WHITE, Parent = model })
		decor({ Name = "WindowGlow", Size = Vector3.new(ww, wh, 0.3), CFrame = at * CFrame.new(0, 0, -0.1), Color = C.WINDOW, Material = Enum.Material.Neon, Transparency = 0.05, Parent = model })
		decor({ Name = "Mullion", Size = Vector3.new(0.3, wh, 0.35), CFrame = at * CFrame.new(0, 0, -0.15), Color = C.WHITE, Parent = model })
		sdecor({ Name = "Sill", Size = Vector3.new(ww + 1.2, 0.4, 0.8), CFrame = at * CFrame.new(0, -wh / 2 - 0.5, -0.35), Color = C.WHITE, Parent = model })
	end
	for _, x in ipairs({ -w / 3.2, w / 3.2 }) do
		window(cf * CFrame.new(x, 1 + h * 0.3, -d / 2 - 0.15), 2.8, 3)
		window(cf * CFrame.new(x, 1 + h * 0.76, -d / 2 - 0.15), 2.8, 2.4)
	end
	local door = cf * CFrame.new(0, 1 + 2.3, -d / 2 - 0.15)
	decor({ Name = "DoorFrame", Size = Vector3.new(3.4, 5, 0.4), CFrame = door * CFrame.new(0, 0.2, 0), Color = C.WHITE, Parent = model })
	sdecor({ Name = "Door", Size = Vector3.new(2.6, 4.4, 0.3), CFrame = door * CFrame.new(0, -0.1, -0.1), Color = Color3.fromRGB(150, 90, 60), Parent = model })
	-- the roof: rows of tiles stepping up to a ridge, with a fascia along the eaves
	local half = d / 2 + 1.6
	local rise = h * 0.7
	local rows = 6
	for _, dir in ipairs({ -1, 1 }) do
		for i = 0, rows - 1 do
			local s = i / rows
			local tile = sbrick({ Name = "RoofTiles", Size = Vector3.new(w + 2.4, 0.9, half / rows + 0.6), CFrame = cf * CFrame.new(0, 1 + h + rise * s + 0.45, dir * (half - (i + 0.5) * half / rows)), Color = (i % 2 == 0) and roofColor or roofColor:Lerp(Color3.new(0, 0, 0), 0.15), CanCollide = false, Parent = model })
			tile.CanQuery = false
		end
		decor({ Name = "Fascia", Size = Vector3.new(w + 2.6, 0.6, 0.6), CFrame = cf * CFrame.new(0, 1 + h + 0.1, dir * (half + 0.2)), Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.35), Parent = model })
	end
	sdecor({ Name = "Ridge", Size = Vector3.new(w + 2.8, 0.9, 1.4), CFrame = cf * CFrame.new(0, 1 + h + rise + 0.7, 0), Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.3), Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, rows - 1 do
			local s = i / rows
			decor({ Name = "Gable", Size = Vector3.new(0.6, rise / rows + 0.05, 2 * (half - i * half / rows) - 1.6), CFrame = cf * CFrame.new(side * (w / 2 - 0.3), 1 + h + rise * s + rise / rows / 2, 0), Color = C.BRICK, Parent = model })
		end
	end
	-- a dormer with a glowing window
	local dormer = cf * CFrame.new(0, 1 + h + rise * 0.45, -half * 0.45)
	part({ Name = "Dormer", Size = Vector3.new(3.6, 3, 2.6), CFrame = dormer, Color = C.BRICK, Parent = model })
	decor({ Name = "DormerWindow", Size = Vector3.new(2, 1.8, 0.3), CFrame = dormer * CFrame.new(0, 0, -1.4), Color = C.WINDOW, Material = Enum.Material.Neon, Parent = model })
	sdecor({ Name = "DormerRoof", Size = Vector3.new(4.4, 0.6, 3.4), CFrame = dormer * CFrame.new(0, 1.8, 0), Color = roofColor, Parent = model })
	return cf
end

-- The snow town's neon shop: white studded walls, a thick red frame round a huge glowing cyan window, a red
-- canopy, and a big neon sign.
function PropKit.frameShop(parent, center, facing, w, d, h, title, frameColor)
	local cf = look(center, facing)
	frameColor = frameColor or C.NEON_RED
	local model = Instance.new("Model")
	model.Name = "FrameShop"
	model.Parent = parent
	sbrick({ Name = "Base", Size = Vector3.new(w + 1.4, 1, d + 1.4), CFrame = cf * CFrame.new(0, 0.5, 0), Color = frameColor, Parent = model })
	local walls = part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, 1 + h / 2, 0), Color = C.WHITE, Material = Enum.Material.Plastic, Parent = model })
	walls.FrontSurface = Enum.SurfaceType.Studs
	walls.LeftSurface = Enum.SurfaceType.Studs
	walls.RightSurface = Enum.SurfaceType.Studs
	local front = -d / 2
	-- the thick frame round the window, bevelled at the corners
	local winW, winH = w - 4, h * 0.5
	local win = cf * CFrame.new(0, 1 + h * 0.42, front - 0.3)
	sdecor({ Name = "FrameTop", Size = Vector3.new(winW + 3, 1.4, 1.2), CFrame = win * CFrame.new(0, winH / 2 + 0.7, 0), Color = frameColor, Parent = model })
	sdecor({ Name = "FrameBottom", Size = Vector3.new(winW + 3, 1.4, 1.2), CFrame = win * CFrame.new(0, -winH / 2 - 0.7, 0), Color = frameColor, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		sdecor({ Name = "FrameSide", Size = Vector3.new(1.4, winH + 2.8, 1.2), CFrame = win * CFrame.new(side * (winW / 2 + 0.8), 0, 0), Color = frameColor, Parent = model })
	end
	decor({ Name = "ShopWindow", Size = Vector3.new(winW, winH, 0.3), CFrame = win * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(110, 230, 250), Material = Enum.Material.Neon, Transparency = 0.15, Parent = model })
	decor({ Name = "WindowShine", Size = Vector3.new(winW * 0.12, winH * 0.8, 0.2), CFrame = win * CFrame.new(-winW * 0.3, 0, -0.3) * CFrame.Angles(0, 0, math.rad(20)), Color = Color3.fromRGB(230, 252, 255), Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	-- a thick canopy over the top with a bevelled lip, and the sign on it
	local canopy = cf * CFrame.new(0, 1 + h - 0.6, front - 1.6)
	sdecor({ Name = "Canopy", Size = Vector3.new(w + 1.6, 1.6, 3.6), CFrame = canopy, Color = frameColor, Parent = model })
	decor({ Name = "CanopyLip", Size = Vector3.new(w + 1.6, 0.8, 0.8), CFrame = canopy * CFrame.new(0, -1.1, -1.4), Color = frameColor:Lerp(Color3.new(0, 0, 0), 0.25), Parent = model })
	local sign = decor({ Name = "Sign", Size = Vector3.new(w - 2, 2.4, 0.4), CFrame = canopy * CFrame.new(0, 2, 0.6), Color = Color3.fromRGB(30, 24, 40), Parent = model })
	surfaceText(sign, title, frameColor:Lerp(Color3.new(1, 1, 1), 0.35))
	light(model:FindFirstChild("ShopWindow"), Color3.fromRGB(120, 230, 255), 22, 1.4)
	return cf
end

-- A vending machine (the reference's XP MACHINE): a coloured cabinet, a glowing screen with a sparkle, a keypad,
-- a coin slot and a lit sign across the top.
function PropKit.vendingMachine(parent, cf, title, color)
	local model = Instance.new("Model")
	model.Name = "VendingMachine"
	model.Parent = parent
	sbrick({ Name = "Body", Size = Vector3.new(5, 9, 3.4), CFrame = cf * CFrame.new(0, 4.5, 0), Color = color, Parent = model })
	decor({ Name = "Trim", Size = Vector3.new(5.3, 0.6, 3.6), CFrame = cf * CFrame.new(0, 0.3, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.35), Parent = model })
	local screen = decor({ Name = "Screen", Size = Vector3.new(2.6, 5, 0.3), CFrame = cf * CFrame.new(-0.7, 4.8, -1.75), Color = Color3.fromRGB(20, 24, 40), Parent = model })
	decor({ Name = "ScreenGlow", Size = Vector3.new(2.2, 4.6, 0.2), CFrame = screen.CFrame * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(40, 60, 120), Material = Enum.Material.Neon, Transparency = 0.3, Parent = model })
	decor({ Name = "Sparkle", Size = Vector3.new(0.9, 0.2, 0.2), CFrame = screen.CFrame * CFrame.new(0, -1, -0.2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
	decor({ Name = "Sparkle", Size = Vector3.new(0.2, 0.9, 0.2), CFrame = screen.CFrame * CFrame.new(0, -1, -0.2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
	for row = 0, 3 do
		for col = 0, 1 do
			decor({ Name = "Key", Size = Vector3.new(0.5, 0.4, 0.2), CFrame = cf * CFrame.new(1.4 + col * 0.7, 5.6 - row * 0.6, -1.75), Color = Color3.fromRGB(220, 230, 240), Parent = model })
		end
	end
	decor({ Name = "Slot", Size = Vector3.new(1.4, 0.8, 0.2), CFrame = cf * CFrame.new(1.7, 2.6, -1.75), Color = Color3.fromRGB(30, 30, 40), Parent = model })
	decor({ Name = "Tray", Size = Vector3.new(3.6, 0.8, 0.4), CFrame = cf * CFrame.new(0, 1.4, -1.8), Color = Color3.fromRGB(30, 30, 40), Parent = model })
	local sign = decor({ Name = "Sign", Size = Vector3.new(5, 1.4, 0.4), CFrame = cf * CFrame.new(0, 8.6, -1.85), Color = color:Lerp(Color3.new(0, 0, 0), 0.45), Parent = model })
	surfaceText(sign, title, Color3.fromRGB(230, 245, 255))
	light(screen, Color3.fromRGB(120, 170, 255), 12, 1)
	return model
end

-- A striped market stall on posts with goods on the counter (blue and white, or any two colours).
function PropKit.stripedStall(parent, center, facing, colorA, colorB)
	local cf = look(center, facing)
	local model = Instance.new("Model")
	model.Name = "StripedStall"
	model.Parent = parent
	sbrick({ Name = "Counter", Size = Vector3.new(9, 3, 3), CFrame = cf * CFrame.new(0, 1.5, -1), Color = C.WOOD, Parent = model })
	for _, x in ipairs({ -4.2, 4.2 }) do
		for _, z in ipairs({ -2.2, 2.2 }) do
			sdecor({ Name = "Post", Size = Vector3.new(0.7, 8, 0.7), CFrame = cf * CFrame.new(x, 4, z), Color = C.WOOD_DARK, Parent = model })
		end
	end
	for i = 1, 6 do
		sdecor({ Name = "Stripe", Size = Vector3.new(10 / 6, 0.5, 5.8), CFrame = cf * CFrame.new(-5 + (i - 0.5) * 10 / 6, 8.3, 0) * CFrame.Angles(math.rad(-10), 0, 0), Color = (i % 2 == 0) and colorB or colorA, Parent = model })
		decor({ Name = "Flap", Size = Vector3.new(10 / 6, 1, 0.3), CFrame = cf * CFrame.new(-5 + (i - 0.5) * 10 / 6, 7.4, -3), Color = (i % 2 == 0) and colorB or colorA, Parent = model })
	end
	local goods = { Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(140, 255, 160), Color3.fromRGB(255, 220, 90) }
	for i = 1, 6 do
		decor({ Name = "Goods", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(-3.4 + i * 1.1, 3.5, -1.4), Color = goods[(i % #goods) + 1], Material = Enum.Material.Neon, Parent = model })
	end
	return cf, model
end

-- The reference's glass shop (the big "SELL" building): a thick studded frame in a bright colour round glass
-- walls, a glowing floor inside, a display plinth with something on it, a slanted roof sign with huge letters.
function PropKit.glassShop(parent, center, facing, w, d, h, title, frameColor)
	local cf = look(center, facing)
	local model = Instance.new("Model")
	model.Name = "GlassShop"
	model.Parent = parent
	local frame = frameColor or Color3.fromRGB(240, 196, 50)
	local dark = Color3.fromRGB(60, 64, 78)
	sbrick({ Name = "Base", Size = Vector3.new(w + 2, 1.2, d + 2), CFrame = cf * CFrame.new(0, 0.6, 0), Color = dark, Parent = model })
	decor({ Name = "GlowFloor", Size = Vector3.new(w - 1, 0.2, d - 1), CFrame = cf * CFrame.new(0, 1.3, 0), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, Transparency = 0.4, Parent = model })
	-- the frame: corner columns, top and bottom beams on every side
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			sbrick({ Name = "Column", Size = Vector3.new(1.6, h, 1.6), CFrame = cf * CFrame.new(x, 1.2 + h / 2, z), Color = frame, Parent = model })
		end
	end
	for _, y in ipairs({ 1.2 + 0.5, 1.2 + h - 0.6 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			sbrick({ Name = "Beam", Size = Vector3.new(w + 1.6, 1.2, 1.4), CFrame = cf * CFrame.new(0, y, z), Color = frame, Parent = model })
		end
		for _, x in ipairs({ -w / 2, w / 2 }) do
			sbrick({ Name = "Beam", Size = Vector3.new(1.4, 1.2, d + 1.6), CFrame = cf * CFrame.new(x, y, 0), Color = frame, Parent = model })
		end
	end
	-- glass walls with mullions; the front has a doorway in the middle
	for _, spec in ipairs({ { 0, d / 2, w, 0 }, { -w / 2, 0, d, 90 }, { w / 2, 0, d, 90 } }) do
		local at = cf * CFrame.new(spec[1], 1.2 + h / 2, spec[2]) * CFrame.Angles(0, math.rad(spec[4]), 0)
		part({ Name = "Glass", Size = Vector3.new(spec[3] - 1.6, h - 2.4, 0.3), CFrame = at, Color = Color3.fromRGB(150, 220, 245), Material = Enum.Material.Glass, Transparency = 0.55, Parent = model })
	end
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "FrontGlass", Size = Vector3.new(w / 2 - 3.2, h - 2.4, 0.3), CFrame = cf * CFrame.new(side * (w / 4 + 1.2), 1.2 + h / 2, -d / 2), Color = Color3.fromRGB(150, 220, 245), Material = Enum.Material.Glass, Transparency = 0.55, Parent = model })
		sdecor({ Name = "Mullion", Size = Vector3.new(0.6, h - 2.4, 0.6), CFrame = cf * CFrame.new(side * 2.4, 1.2 + h / 2, -d / 2), Color = frame, Parent = model })
	end
	-- the roof slab and the slanted sign on top with huge letters
	sbrick({ Name = "Roof", Size = Vector3.new(w + 2, 1, d + 2), CFrame = cf * CFrame.new(0, 1.2 + h + 0.5, 0), Color = dark, Parent = model })
	local signCf = cf * CFrame.new(0, 1.2 + h + 4.5, -d / 4) * CFrame.Angles(math.rad(-15), 0, 0)
	local sign = sdecor({ Name = "RoofSign", Size = Vector3.new(w + 1, 6, 1), CFrame = signCf, Color = frame:Lerp(Color3.new(0, 0, 0), 0.25), Parent = model })
	decor({ Name = "SignFace", Size = Vector3.new(w - 0.6, 4.8, 0.4), CFrame = signCf * CFrame.new(0, 0, -0.55), Color = Color3.fromRGB(30, 30, 44), Parent = model })
	surfaceText(model:FindFirstChild("SignFace"), title, frame:Lerp(Color3.new(1, 1, 1), 0.2))
	light(sign, frame, 20, 1)
	for _, x in ipairs({ -w / 3, w / 3 }) do
		decor({ Name = "SignLeg", Size = Vector3.new(0.8, 4, 0.8), CFrame = cf * CFrame.new(x, 1.2 + h + 2.4, -d / 4 + 0.6), Color = dark, Parent = model })
	end
	light(model:FindFirstChild("GlowFloor"), Color3.fromRGB(120, 220, 255), 18, 1)
	return cf, model
end

-- Nature --------------------------------------------------------------------------------------------------------

-- A cluster of glowing ice crystals: tall prisms leaning out from a common base.
function PropKit.iceCrystal(parent, base, rng, scale)
	scale = scale or 1
	local s = scale
	for i = 1, rng:NextInteger(4, 7) do
		local h = rng:NextNumber(3, 8) * s * (i == 1 and 1.6 or 1)
		local w = rng:NextNumber(0.9, 1.8) * s
		local tilt = CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, math.pi), rng:NextNumber(-0.35, 0.35))
		local cf = CFrame.new(base) * tilt * CFrame.new(0, h / 2, 0)
		decor({ Name = "Crystal", Size = Vector3.new(w, h, w), CFrame = cf, Color = (i % 2 == 0) and C.ICE or C.ICE_DEEP, Material = Enum.Material.Glass, Transparency = 0.15, Parent = parent })
		decor({ Name = "CrystalCore", Size = Vector3.new(w * 0.45, h * 0.85, w * 0.45), CFrame = cf, Color = Color3.fromRGB(200, 250, 255), Material = Enum.Material.Neon, Transparency = 0.25, Parent = parent })
		decor({ Name = "CrystalTip", Size = Vector3.new(w * 0.7, w * 0.7, w * 0.7), CFrame = cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = C.ICE, Material = Enum.Material.Glass, Transparency = 0.15, Parent = parent })
	end
	local glow = decor({ Name = "CrystalLight", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(base + Vector3.new(0, 3 * s, 0)), Transparency = 1, Parent = parent })
	light(glow, Color3.fromRGB(120, 220, 255), 18 * s, 1.4)
	K.sparkles(glow, Color3.fromRGB(210, 250, 255), 3)
end

-- A stepped mound of snow blocks.
function PropKit.snowMound(parent, base, rng, scale)
	scale = scale or 1
	local s = scale
	local layers = rng:NextInteger(2, 3)
	for i = 0, layers - 1 do
		local w = (5 - i * 1.6) * s * rng:NextNumber(0.9, 1.2)
		local d = (4 - i * 1.2) * s * rng:NextNumber(0.9, 1.2)
		sbrick({ Name = "SnowMound", Size = Vector3.new(w, 1.1 * s, d), CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-0.4, 0.4) * s, (0.55 + i * 1.1) * s, rng:NextNumber(-0.4, 0.4) * s)) * CFrame.Angles(0, rng:NextNumber(0, 0.4), 0), Color = (i % 2 == 0) and C.SNOW or C.SNOW_SHADE, CanCollide = i == 0, Parent = parent })
	end
end

-- An igloo: a stepped dome of snow-block rings with a little tunnel entrance facing `facing`.
function PropKit.igloo(parent, base, facing, scale)
	scale = scale or 1
	local s = scale
	local cf = look(base, facing)
	for ring = 0, 4 do
		local r = (6 - ring * 1.2) * s
		local y = (0.7 + ring * 1.3) * s
		local n = math.max(6, math.floor(r * 2.2))
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			if not (ring < 2 and math.abs(math.sin(a)) < 0.3 and math.cos(a) > 0) then
				sdecor({ Name = "IglooBlock", Size = Vector3.new(r * 2 * math.pi / n + 0.1, 1.3 * s, 1.4 * s), CFrame = cf * CFrame.new(math.sin(a) * r, y, -math.cos(a) * r) * CFrame.Angles(0, -a, 0), Color = (ring + i) % 2 == 0 and C.SNOW or C.SNOW_SHADE, Parent = parent }).CanCollide = true
			end
		end
	end
	sdecor({ Name = "IglooTop", Size = Vector3.new(2.6, 0.8, 2.6) * s, CFrame = cf * CFrame.new(0, 6.9 * s, 0), Color = C.SNOW, Parent = parent })
	for _, x in ipairs({ -1.6, 1.6 }) do
		sdecor({ Name = "Tunnel", Size = Vector3.new(1, 3, 3) * s, CFrame = cf * CFrame.new(x * s, 1.5 * s, -6.6 * s), Color = C.SNOW, Parent = parent })
	end
	sdecor({ Name = "TunnelTop", Size = Vector3.new(4.2, 1, 3) * s, CFrame = cf * CFrame.new(0, 3.4 * s, -6.6 * s), Color = C.SNOW, Parent = parent })
	local glow = decor({ Name = "IglooGlow", Size = Vector3.new(2, 2, 0.2) * s, CFrame = cf * CFrame.new(0, 1.4 * s, -4.8 * s), Color = C.LANTERN, Material = Enum.Material.Neon, Transparency = 0.3, Parent = parent })
	light(glow, C.LANTERN, 12, 1)
end

-- A stepped voxel cliff or mountain: stacked studded blocks shrinking as they rise, each layer jittered, snow on
-- the ledges, ice crystals here and there. `size` is the footprint; `height` the top.
function PropKit.voxelCliff(parent, center, size, bottom, height, rng, colors)
	colors = colors or { C.CLIFF, C.CLIFF_DARK }
	local layer = 6
	local y = bottom
	local w, d = size.X, size.Z
	local i = 0
	while y < height and w > 6 and d > 6 do
		local top = math.min(height, y + layer)
		for k = 1, rng:NextInteger(2, 4) do
			local bw = w * rng:NextNumber(0.55, 1)
			local bd = d * rng:NextNumber(0.55, 1)
			local ox = rng:NextNumber(-(w - bw) / 2, (w - bw) / 2)
			local oz = rng:NextNumber(-(d - bd) / 2, (d - bd) / 2)
			sbrick({ Name = "Cliff", Size = Vector3.new(bw, top - y, bd), CFrame = CFrame.new(center.X + ox, (y + top) / 2, center.Z + oz), Color = colors[((i + k) % #colors) + 1], Parent = parent })
			if rng:NextNumber() < 0.45 then
				sdecor({ Name = "CliffSnow", Size = Vector3.new(bw * 0.7, 0.8, bd * 0.7), CFrame = CFrame.new(center.X + ox + rng:NextNumber(-1, 1), top + 0.4, center.Z + oz + rng:NextNumber(-1, 1)), Color = C.SNOW, Parent = parent })
			end
		end
		y = top
		w *= rng:NextNumber(0.78, 0.9)
		d *= rng:NextNumber(0.78, 0.9)
		i += 1
	end
	return y
end

-- Ground --------------------------------------------------------------------------------------------------------

-- A sheet of glowing ice with white crack lines across it (the reference's frozen water). `y` is its top.
function PropKit.iceSheet(parent, center, w, d, y, rng)
	local sheet = part({ Name = "Ice", Size = Vector3.new(w, 1, d), CFrame = CFrame.new(center.X, y - 0.5, center.Z), Color = Color3.fromRGB(110, 210, 250), Material = Enum.Material.Glass, Transparency = 0.25, Parent = parent })
	decor({ Name = "IceGlow", Size = Vector3.new(w - 0.4, 0.2, d - 0.4), CFrame = CFrame.new(center.X, y - 1.2, center.Z), Color = Color3.fromRGB(40, 200, 255), Material = Enum.Material.Neon, Transparency = 0.2, Parent = parent })
	-- a web of cracks: random walks of short white neon segments
	for _ = 1, math.floor(w * d / 60) do
		local p = Vector3.new(center.X + rng:NextNumber(-w / 2 + 2, w / 2 - 2), y + 0.02, center.Z + rng:NextNumber(-d / 2 + 2, d / 2 - 2))
		local a = rng:NextNumber(0, math.pi * 2)
		for _ = 1, rng:NextInteger(3, 6) do
			a += rng:NextNumber(-1, 1)
			local len = rng:NextNumber(2, 5)
			local q = p + Vector3.new(math.cos(a) * len, 0, math.sin(a) * len)
			if math.abs(q.X - center.X) < w / 2 - 0.5 and math.abs(q.Z - center.Z) < d / 2 - 0.5 then
				decor({ Name = "Crack", Size = Vector3.new(0.25, 0.06, len), CFrame = CFrame.lookAt((p + q) / 2, q), Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.Neon, Transparency = 0.1, Parent = parent })
				p = q
			end
		end
	end
	light(sheet, Color3.fromRGB(110, 220, 255), 16, 0.8)
	return sheet
end

-- Paving inlays: raised outline shapes and slabs set into the floor (the references' floors are full of these),
-- plus loose tiles scattered round the edges.
function PropKit.inlays(parent, center, radius, y, rng, color, count)
	color = color or C.PAVER
	for _ = 1, count or 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius)
		local p = Vector3.new(center.X + math.cos(a) * r, y, center.Z + math.sin(a) * r)
		local yaw = CFrame.Angles(0, rng:NextInteger(0, 3) * math.pi / 2, 0)
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			-- an outline frame
			local w, d = rng:NextInteger(3, 6) * 2, rng:NextInteger(2, 4) * 2
			for _, spec in ipairs({ { 0, -d / 2, w, 1 }, { 0, d / 2, w, 1 }, { -w / 2, 0, 1, d }, { w / 2, 0, 1, d } }) do
				sdecor({ Name = "Inlay", Size = Vector3.new(spec[3], 0.4, spec[4]), CFrame = CFrame.new(p) * yaw * CFrame.new(spec[1], 0.2, spec[2]), Color = color, Parent = parent }).CanQuery = true
			end
		elseif kind == 2 then
			-- a solid slab
			sdecor({ Name = "Inlay", Size = Vector3.new(rng:NextInteger(2, 4) * 2, 0.4, rng:NextInteger(2, 3) * 2), CFrame = CFrame.new(p) * yaw * CFrame.new(0, 0.2, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.1), Parent = parent }).CanQuery = true
		else
			-- a T or L of slabs
			sdecor({ Name = "Inlay", Size = Vector3.new(8, 0.4, 2), CFrame = CFrame.new(p) * yaw * CFrame.new(0, 0.2, 0), Color = color, Parent = parent }).CanQuery = true
			sdecor({ Name = "Inlay", Size = Vector3.new(2, 0.4, 4), CFrame = CFrame.new(p) * yaw * CFrame.new(rng:NextNumber() < 0.5 and 0 or 3, 0.2, 3), Color = color, Parent = parent }).CanQuery = true
		end
	end
	for _ = 1, math.floor((count or 10) * 1.5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(radius * 0.6, radius * 1.15)
		local p = Vector3.new(center.X + math.cos(a) * r, y, center.Z + math.sin(a) * r)
		local s = rng:NextNumber(1.2, 2.2)
		sdecor({ Name = "LooseTile", Size = Vector3.new(s, 0.3, s * rng:NextNumber(0.6, 1)), CFrame = CFrame.new(p + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color = rng:NextNumber() < 0.5 and color or C.PAVER_DARK, Parent = parent })
	end
end

-- Wooden scaffold beams (the ice zone's): two studded posts and a cross beam, with lanterns hanging off it.
function PropKit.scaffold(parent, a, b, y, height)
	local fa, fb = Vector3.new(a.X, y, a.Z), Vector3.new(b.X, y, b.Z)
	for _, p in ipairs({ fa, fb }) do
		sbrick({ Name = "ScaffoldPost", Size = Vector3.new(1.6, height, 1.6), CFrame = CFrame.new(p + Vector3.new(0, height / 2, 0)), Color = C.WOOD, Parent = parent })
	end
	local length = (fb - fa).Magnitude
	local beam = CFrame.lookAt((fa + fb) / 2 + Vector3.new(0, height - 0.8, 0), fb + Vector3.new(0, height - 0.8, 0))
	sdecor({ Name = "ScaffoldBeam", Size = Vector3.new(1.4, 1.4, length + 1.6), CFrame = beam, Color = C.WOOD, Parent = parent })
	for _, side in ipairs({ -1, 1 }) do
		decor({ Name = "ScaffoldBrace", Size = Vector3.new(0.8, 0.8, 5), CFrame = beam * CFrame.new(0, -1.8, side * (length / 2 - 1.8)) * CFrame.Angles(side * math.rad(-45), 0, 0), Color = C.WOOD_DARK, Parent = parent })
	end
	for _, s in ipairs({ -0.25, 0.25 }) do
		local at = beam * CFrame.new(0, -0.7, s * length)
		decor({ Name = "Chain", Size = Vector3.new(0.2, 1.4, 0.2), CFrame = at * CFrame.new(0, -0.7, 0), Color = Color3.fromRGB(60, 60, 66), Parent = parent })
		lantern(parent, at * CFrame.new(0, -1.4, 0), 0.9)
	end
end

-- Tag ground for TideboundFoliage (frosted or green grass grows on it).
function PropKit.grassy(p)
	CollectionService:AddTag(p, "TideboundGrass")
	return p
end

return PropKit
