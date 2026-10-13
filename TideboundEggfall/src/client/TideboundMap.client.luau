-- Tidebound: Eggfall: the minimap and the sea chart (Patch 12), drawn from IslesLayout.
--   Minimap  a round map in the top-right corner that follows you, north up: the town's coast and streets,
--            every island (sand shore, land, trees), bridges, beacons, Tide Caches, geysers, wild eggs, the
--            Warden's Rock, the Maelstrom and other divers. A golden ring with a compass, zoom buttons, the name
--            of where you are on a ribbon. Nothing covers the map itself.
--   Sea chart click the minimap (or press N) for the whole map, framed in big anime clouds, with every island
--            named and a legend. M hides the minimap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local L = require(Shared:WaitForChild("IslesLayout"))

local player = Players.LocalPlayer
local T = L.Town

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(46, 30, 24)
local SEA_TOP = Color3.fromRGB(86, 196, 214)
local SEA_DEEP = Color3.fromRGB(38, 118, 168)
local SAND = Color3.fromRGB(236, 214, 160)
local SNOW = Color3.fromRGB(226, 234, 244)
local STREET = Color3.fromRGB(196, 186, 170)
local BRIDGE = Color3.fromRGB(150, 100, 64)
local RING_LAND = { Color3.fromRGB(128, 214, 112), Color3.fromRGB(86, 186, 84), Color3.fromRGB(118, 128, 132) }
local RING_EDGE = { Color3.fromRGB(70, 150, 70), Color3.fromRGB(46, 120, 56), Color3.fromRGB(70, 78, 86) }
local TREE = { Color3.fromRGB(52, 140, 62), Color3.fromRGB(38, 110, 50), Color3.fromRGB(80, 92, 84) }
-- HUD restyle (12 Oct 2026): the side buttons' gold and blue tiles (gradient top/bottom and their light outline)
local GOLD_LIGHT = Color3.fromRGB(255, 196, 30)
local GOLD_DARK = Color3.fromRGB(214, 132, 8)
local GOLD_EDGE = Color3.fromRGB(255, 226, 90)
local BLUE_TOP, BLUE_BOTTOM, BLUE_EDGE = Color3.fromRGB(40, 140, 255), Color3.fromRGB(18, 76, 214), Color3.fromRGB(90, 210, 255)
local DISPLAY = Enum.Font.FredokaOne

-- the whole charted area, a little past the play area, plus the Harbor Ring to the south
-- Updated for 2x scaled world
local MIN = Vector3.new(L.playMin.X - 120, 0, math.min(L.playMin.Z, Config.Harbor.center.Z - 680))
local MAX = Vector3.new(L.playMax.X + 120, 0, L.playMax.Z + 120)
local SPAN_X, SPAN_Z = MAX.X - MIN.X, MAX.Z - MIN.Z

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function new(className, props, children)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function round(radius)
	return new("UICorner", { CornerRadius = radius or UDim.new(1, 0) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 })
end

-- Anime clouds ------------------------------------------------------------------------------------------------
-- Overlapping round puffs on a flat base, white on top with a lavender-blue shade underneath.

local PUFFS = { { 0.2, 0.6, 0.42 }, { 0.4, 0.4, 0.6 }, { 0.62, 0.36, 0.52 }, { 0.8, 0.55, 0.4 }, { 0.5, 0.62, 0.5 }, { 0.3, 0.7, 0.34 }, { 0.7, 0.7, 0.36 } }

local function animeCloud(parent, width, z, alpha)
	local cloud = new("Frame", { Name = "Cloud", BackgroundTransparency = 1, Size = UDim2.new(0, width, 0, width * 0.55), ZIndex = z, Parent = parent })
	local function layer(color, dy, zi, shrink)
		for _, puff in ipairs(PUFFS) do
			local s = puff[3] * (shrink or 1)
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(puff[1], 0, puff[2] + dy, 0),
				Size = UDim2.new(s, 0, s * 1.8, 0),
				BackgroundColor3 = color,
				BackgroundTransparency = alpha or 0,
				BorderSizePixel = 0,
				ZIndex = zi,
				Parent = cloud,
			}, { round() })
		end
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.74 + dy, 0), Size = UDim2.new(0.74, 0, 0.26, 0), BackgroundColor3 = color, BackgroundTransparency = alpha or 0, BorderSizePixel = 0, ZIndex = zi, Parent = cloud }, { round() })
	end
	layer(Color3.fromRGB(176, 186, 232), 0.08, z, 1) -- the shade underneath
	layer(Color3.fromRGB(255, 255, 255), 0, z + 1, 0.94) -- the bright top
	-- a soft highlight on the biggest puff
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.4, 0, 0.28, 0), Size = UDim2.new(0.2, 0, 0.16, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = z + 2, Parent = cloud }, { round() })
	return cloud
end

-- Drawing the world ---------------------------------------------------------------------------------------------
-- Everything goes into one frame whose pixels are studs * zoom, north (+Z) up. Icons keep a fixed pixel size.

local function toPx(p, zoom)
	return Vector2.new((p.X - MIN.X) * zoom, (MAX.Z - p.Z) * zoom)
end

local function blob(parent, center, radius, zoom, color, z, edge, edgeThickness)
	local px = toPx(center, zoom)
	local d = math.max(2, radius * 2 * zoom)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, px.X, 0, px.Y),
		Size = UDim2.new(0, d, 0, d),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { round(), edge and stroke(edge, edgeThickness or 2) or nil })
end

local function box(parent, center, size, zoom, color, z, edge)
	local px = toPx(center, zoom)
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, px.X, 0, px.Y),
		Size = UDim2.new(0, size.X * zoom, 0, size.Z * zoom),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { round(UDim.new(0, math.max(2, 6 * zoom))), edge and stroke(edge, 2) or nil })
end

local function line(parent, a, b, zoom, color, width, z)
	local pa, pb = toPx(a, zoom), toPx(b, zoom)
	local mid = (pa + pb) / 2
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, mid.X, 0, mid.Y),
		Size = UDim2.new(0, (pb - pa).Magnitude + width * 0.5, 0, width),
		Rotation = math.deg(math.atan2(pb.Y - pa.Y, pb.X - pa.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { round() })
end

-- A small icon at a world point: a shape with an outline and an optional glyph.
local function icon(parent, at, zoom, shape, color, size, glyph, z)
	local px = toPx(at, zoom)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, px.X, 0, px.Y),
		Size = UDim2.new(0, size, 0, size),
		Rotation = shape == "diamond" and 45 or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 20,
		Parent = parent,
	}, { round(shape == "circle" and UDim.new(1, 0) or UDim.new(0, size * 0.25)), stroke(WHITE, 1.5) })
	if glyph then
		new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = shape == "diamond" and -45 or 0, Font = Enum.Font.GothamBlack, TextScaled = true, Text = glyph, TextColor3 = WHITE, ZIndex = (z or 20) + 1, Parent = f })
	end
	return f
end

local function drawWorld(parent, zoom, options)
	local world = new("Frame", { Name = "World", BackgroundTransparency = 1, Size = UDim2.new(0, SPAN_X * zoom, 0, SPAN_Z * zoom), Parent = parent })
	local iconScale = options.iconScale or 1
	local rng = Random.new(7)

	-- the play area's edge, a faint dashed line of the current
	local corners = { Vector3.new(L.playMin.X, 0, L.playMin.Z), Vector3.new(L.playMax.X, 0, L.playMin.Z), Vector3.new(L.playMax.X, 0, L.playMax.Z), Vector3.new(L.playMin.X, 0, L.playMax.Z) }
	for i = 1, 4 do
		local a, b = corners[i], corners[(i % 4) + 1]
		local steps = math.floor((b - a).Magnitude / 60)
		for k = 0, steps - 1, 2 do
			line(world, a:Lerp(b, k / steps), a:Lerp(b, (k + 1) / steps), zoom, Color3.fromRGB(200, 240, 255), 2, 2)
		end
	end
	-- little wave marks across the sea
	for _ = 1, 70 do
		local p = Vector3.new(rng:NextNumber(MIN.X, MAX.X), 0, rng:NextNumber(MIN.Z, MAX.Z))
		local px = toPx(p, zoom)
		new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, px.X, 0, px.Y), Size = UDim2.new(0, 18 * iconScale, 0, 10 * iconScale), Font = Enum.Font.GothamBold, TextScaled = true, Text = "~", TextColor3 = Color3.fromRGB(190, 236, 248), TextTransparency = 0.35, ZIndex = 2, Parent = world })
	end

	-- the town island: sand shore under the grass shapes, the beach, the snowy plaza, streets
	for _, shape in ipairs(T.land) do
		if shape.kind == "disk" then
			blob(world, shape.c, shape.r + 6, zoom, SAND, 3)
		else
			box(world, shape.c, shape.size + Vector3.new(8, 0, 12), zoom, SAND, 3)
		end
	end
	blob(world, T.beach.c, T.beach.r + 8, zoom, SAND, 3)
	blob(world, T.beach.c, T.beach.r, zoom, SAND:Lerp(Color3.fromRGB(255, 240, 200), 0.3), 4)
	for _, shape in ipairs(T.land) do
		if shape.kind == "disk" then
			blob(world, shape.c, shape.r, zoom, RING_LAND[1], 5)
		else
			box(world, shape.c, shape.size, zoom, RING_LAND[1], 5)
		end
	end
	blob(world, Vector3.new(0, 0, 0), T.plazaRadius, zoom, SNOW, 6)
	blob(world, T.districts.ToriiHill.top, 44, zoom, Color3.fromRGB(150, 116, 90), 6)
	blob(world, T.districts.ToriiHill.top, 20, zoom, SNOW, 7)
	for _, edge in ipairs(T.edges) do
		line(world, T.nodes[edge[1]], T.nodes[edge[2]], zoom, STREET, math.max(2, 8 * zoom), 8)
	end
	line(world, L.causeway.from, L.causeway.to, zoom, STREET, math.max(3, 12 * zoom), 8)
	blob(world, Vector3.new(0, 0, 0), 9, zoom, Color3.fromRGB(60, 150, 230), 9)

	-- the Harbor Ring and its lagoon
	local h = Config.Harbor.center
	blob(world, h, Config.Harbor.plotInner + Config.Harbor.plotSize + 10, zoom, SAND, 3)
	blob(world, h, Config.Harbor.plotInner + Config.Harbor.plotSize, zoom, SNOW, 4)
	blob(world, h, Config.Harbor.lagoonRadius, zoom, Color3.fromRGB(70, 170, 220), 5)

	-- bridges first, so the islands sit on top of their ends
	for _, link in ipairs(L.links) do
		local a, b = L.byName[link[1]], L.byName[link[2]]
		local dir = (b.pos - a.pos).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local from, to = a.pos + dir * (a.r - 3), b.pos - dir * (b.r - 3)
		local mid = (from + to) / 2 + side * (link[4] or 0)
		local width = math.max(2, (link[3] == "rope" and 5 or 7) * zoom)
		local color = link[3] == "rope" and Color3.fromRGB(190, 160, 110) or BRIDGE
		line(world, from, mid, zoom, color, width, 10)
		line(world, mid, to, zoom, color, width, 10)
	end
	-- the islands: sand shore, land, a few trees
	for _, island in ipairs(L.islands) do
		blob(world, island.pos, island.r + 6, zoom, SAND, 11)
		blob(world, island.pos, island.r, zoom, RING_LAND[island.ring], 12, RING_EDGE[island.ring], math.max(1, 2 * zoom))
		if island.feature == "lagoon" then
			blob(world, island.pos, island.r * 0.45, zoom, Color3.fromRGB(80, 210, 220), 13)
		end
		for _ = 1, math.max(1, math.floor(island.r / 12)) do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(island.feature == "lagoon" and island.r * 0.55 or 0, island.r * 0.7)
			blob(world, island.pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rng:NextNumber(3, 5), zoom, TREE[island.ring], 13)
		end
		if options.names then
			local px = toPx(island.pos, zoom)
			local label = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, px.X, 0, px.Y + island.r * zoom + 2), Size = UDim2.new(0, 120, 0, 14), Font = DISPLAY, TextScaled = true, Text = island.title, TextColor3 = WHITE, ZIndex = 30, Parent = world })
			stroke(INK, 2).Parent = label
		end
	end

	-- points of interest
	local s = iconScale
	for _, nest in ipairs(L.eggNests) do
		local f = icon(world, nest.at, zoom, "circle", Color3.fromRGB(250, 246, 230), 7 * s, nil, 21)
		f.Size = UDim2.new(0, 6 * s, 0, 8 * s)
	end
	for _, pair in ipairs(L.jumpPads) do
		icon(world, pair[1], zoom, "circle", Color3.fromRGB(110, 220, 255), 7 * s, nil, 21)
		icon(world, pair[2], zoom, "circle", Color3.fromRGB(110, 220, 255), 7 * s, nil, 21)
	end
	for _, b in ipairs(L.beacons) do
		icon(world, b, zoom, "diamond", Color3.fromRGB(60, 220, 170), 10 * s, nil, 22)
	end
	for _, c in ipairs(L.tideCaches) do
		icon(world, c, zoom, "square", Color3.fromRGB(255, 150, 80), 12 * s, "+", 22)
	end
	icon(world, L.wardenLair, zoom, "circle", Color3.fromRGB(230, 60, 60), 14 * s, "!", 23)
	icon(world, L.maelstrom, zoom, "circle", Color3.fromRGB(30, 70, 110), 14 * s, "@", 23)
	icon(world, T.tidegate, zoom, "square", Color3.fromRGB(176, 34, 30), 11 * s, "⛩", 23)
	icon(world, Vector3.new(-24, 0, 12), zoom, "circle", Color3.fromRGB(255, 90, 110), 10 * s, "E", 23)
	if options.names then
		for _, spec in ipairs({ { Vector3.new(0, 0, 0), "EGGFALL TOWN" }, { Config.Harbor.center, "HARBOR RING" } }) do
			local px = toPx(spec[1], zoom)
			local label = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, px.X, 0, px.Y - 40 * zoom), Size = UDim2.new(0, 160, 0, 18), Font = DISPLAY, TextScaled = true, Text = spec[2], TextColor3 = Color3.fromRGB(255, 236, 170), ZIndex = 31, Parent = world })
			stroke(INK, 2.5).Parent = label
		end
	end
	return world
end

-- The minimap ---------------------------------------------------------------------------------------------------

-- Sibling: a frame's children always draw over it (under Global, the map drew under the sea it sits on)
local gui = new("ScreenGui", { Name = "TideboundMap", ResetOnSpawn = false, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

local SIZE = touch and 150 or 210
local holder = new("Frame", { Name = "Minimap", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.new(0, SIZE, 0, SIZE + 30), BackgroundTransparency = 1, Parent = gui })

-- the golden ring
local ring = new("Frame", { Name = "Ring", Size = UDim2.new(0, SIZE, 0, SIZE), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = holder }, {
	round(),
	stroke(GOLD_EDGE, 3),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_LIGHT, GOLD_DARK) }),
})
-- the round window onto the sea. A CanvasGroup's round clip isn't drawn on every PC (the map spilled out of
-- the ring), so the map is clipped by plain strips instead (see "Clipping" below).
local INSET = 9
local RING_R = SIZE / 2 -- the gold ring's outer radius
local VIEW_R = RING_R - INSET - 6 -- the radius of sea you actually see; the gold bezel covers the rest
local window = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -INSET * 2, 1, -INSET * 2), BackgroundColor3 = SEA_TOP, BorderSizePixel = 0, ZIndex = 3, Parent = ring }, {
	round(),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(SEA_TOP, SEA_DEEP) }),
})
-- inner shadow round the window's edge
new("Frame", { Name = "InnerShadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, VIEW_R * 2 - 24, 0, VIEW_R * 2 - 24), BackgroundTransparency = 1, ZIndex = 50, Parent = window }, {
	round(),
	stroke(Color3.fromRGB(16, 40, 70), 12, 0.6),
})
new("Frame", { Name = "WindowEdge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, VIEW_R * 2, 0, VIEW_R * 2), BackgroundTransparency = 1, ZIndex = 4, Parent = ring }, { round(), stroke(INK, 2.5) })

-- you, in the middle: a white arrow that points the way you face
local arrow = new("TextLabel", { Name = "You", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 20, 0, 20), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "▲", TextColor3 = WHITE, TextStrokeColor3 = Color3.fromRGB(230, 60, 40), TextStrokeTransparency = 0, ZIndex = 60, Parent = window })
local pulse = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 20, 0, 20), BackgroundTransparency = 1, ZIndex = 59, Parent = window }, { round(), stroke(WHITE, 2, 0.2) })

-- Clipping: ClipsDescendants only clips rectangles, so the map is drawn once into each of a few horizontal
-- strips whose widths follow the circle. Each strip's corners stay inside the ring, and a gold bezel from VIEW_R
-- out to the ring covers them, so the map ends on a clean circle and nothing reaches past the ring.
local strips = {}
do
	local slack = RING_R * RING_R - VIEW_R * VIEW_R
	local edges = { 0 }
	while edges[#edges] < VIEW_R do
		local a = edges[#edges]
		table.insert(edges, math.min(VIEW_R, math.sqrt(a * a + slack)))
	end
	local function strip(top, bottom, outer)
		top, bottom = math.floor(top), math.ceil(bottom)
		local width = math.floor(2 * math.sqrt(RING_R * RING_R - outer * outer))
		table.insert(strips, new("Frame", { Name = "Strip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, top), Size = UDim2.new(0, width, 0, bottom - top), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = window }))
	end
	strip(-edges[2], edges[2], edges[2])
	for i = 2, #edges - 1 do
		strip(-edges[i + 1], -edges[i], edges[i + 1])
		strip(edges[i], edges[i + 1], edges[i + 1])
	end
end
new("Frame", { Name = "Bezel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, VIEW_R * 2, 0, VIEW_R * 2), BackgroundTransparency = 1, ZIndex = 58, Parent = window }, {
	round(),
	new("UIStroke", { Color = WHITE, Thickness = RING_R - VIEW_R }, { new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_LIGHT, GOLD_DARK) }) }),
})


-- the compass, the zoom buttons and the ribbon with the place name
local compass = new("Frame", { Name = "Compass", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0, 26, 0, 26), BackgroundColor3 = Color3.fromRGB(220, 60, 50), ZIndex = 70, Parent = ring }, { round(), stroke(INK, 2.5) })
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextScaled = true, Text = "N", TextColor3 = WHITE, ZIndex = 71, Parent = compass }, { new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })

local function zoomButton(text, position)
	local b = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.new(0, 28, 0, 28), BackgroundColor3 = WHITE, AutoButtonColor = true, Font = Enum.Font.GothamBlack, TextScaled = true, Text = text, TextColor3 = INK, ZIndex = 70, Parent = ring }, {
		round(),
		stroke(INK, 2.5),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_LIGHT, GOLD_DARK) }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	return b
end
local zoomIn = zoomButton("+", UDim2.new(0.08, 0, 0.78, 0))
local zoomOut = zoomButton("–", UDim2.new(0.2, 0, 0.93, 0))

local ribbon = new("Frame", { Name = "Ribbon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, SIZE - 14), Size = UDim2.new(0.9, 0, 0, 30), BackgroundColor3 = WHITE, ZIndex = 72, Parent = holder }, {
	round(UDim.new(0, 10)),
	stroke(BLUE_EDGE, 2.5),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(BLUE_TOP, BLUE_BOTTOM) }),
})
local placeLabel = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, -6), Position = UDim2.new(0, 5, 0, 3), Font = DISPLAY, TextScaled = true, Text = "EGGFALL TOWN", TextColor3 = WHITE, ZIndex = 73, Parent = ribbon }, { stroke(INK, 2) })


new("TextLabel", { Name = "Hint", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, SIZE + 18), Size = UDim2.new(1, 0, 0, 15), Font = DISPLAY, TextScaled = true, Text = touch and "tap the map: sea chart" or "N: sea chart · M: hide", TextColor3 = WHITE, ZIndex = 72, Parent = holder }, { stroke(INK, 1.5) })

-- Adjusted zoom levels for 2x scaled world (halved to compensate for larger coordinates)
local ZOOMS = { 0.09, 0.15, 0.25, 0.4 }
local zoomIndex = 2
local miniWorlds = {} -- one copy of the map per clipping strip
local function redrawMini()
	for _, world in ipairs(miniWorlds) do
		world:Destroy()
	end
	table.clear(miniWorlds)
	for _, strip in ipairs(strips) do
		table.insert(miniWorlds, drawWorld(strip, ZOOMS[zoomIndex], { iconScale = 0.9 + 0.15 * zoomIndex, names = false }))
	end
end
redrawMini()
zoomIn.Activated:Connect(function()
	zoomIndex = math.min(#ZOOMS, zoomIndex + 1)
	redrawMini()
end)
zoomOut.Activated:Connect(function()
	zoomIndex = math.max(1, zoomIndex - 1)
	redrawMini()
end)

-- The sea chart -------------------------------------------------------------------------------------------------

local chartOpen = false
local chart = new("Frame", { Name = "SeaChart", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.82, 0.82), BackgroundTransparency = 1, Visible = false, ZIndex = 100, Parent = gui })
new("UIAspectRatioConstraint", { AspectRatio = SPAN_X / SPAN_Z, Parent = chart })
local chartScale = new("UIScale", { Scale = 1, Parent = chart })
local chartFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 100, Parent = chart }, {
	round(UDim.new(0, 24)),
	stroke(INK, 4),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(GOLD_LIGHT, GOLD_DARK) }),
})
local chartWindow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 1, -20), BackgroundColor3 = SEA_TOP, ClipsDescendants = true, ZIndex = 101, Parent = chartFrame }, {
	round(UDim.new(0, 18)),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(SEA_TOP, SEA_DEEP) }),
})
local chartTitle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 260, 0, 46), BackgroundColor3 = Color3.fromRGB(70, 140, 210), ZIndex = 140, Parent = chart }, {
	round(UDim.new(0, 14)),
	stroke(INK, 3),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(110, 180, 240), Color3.fromRGB(50, 110, 190)) }),
})
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 8, 0, 4), Font = DISPLAY, TextScaled = true, Text = "SEA CHART", TextColor3 = WHITE, ZIndex = 141, Parent = chartTitle }, { stroke(INK, 2.5) })
local close = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.new(0, 40, 0, 40), BackgroundColor3 = Color3.fromRGB(230, 70, 60), Font = Enum.Font.GothamBlack, TextScaled = true, Text = "X", TextColor3 = WHITE, ZIndex = 142, Parent = chart }, {
	round(),
	stroke(INK, 3),
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
})
-- the legend along the bottom
local legend = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.92, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(255, 248, 230), BackgroundTransparency = 0.1, ZIndex = 130, Parent = chartWindow }, {
	round(UDim.new(0, 10)),
	stroke(INK, 2),
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14) }),
})
for _, spec in ipairs({ { "diamond", Color3.fromRGB(60, 220, 170), "Beacon" }, { "square", Color3.fromRGB(255, 150, 80), "Tide Cache" }, { "circle", Color3.fromRGB(110, 220, 255), "Geyser" }, { "circle", Color3.fromRGB(250, 246, 230), "Wild egg" }, { "circle", Color3.fromRGB(230, 60, 60), "Warden" }, { "circle", Color3.fromRGB(30, 70, 110), "Maelstrom" } }) do
	local item = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 104, 1, 0), ZIndex = 131, Parent = legend })
	new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(0, 12, 0, 12), Rotation = spec[1] == "diamond" and 45 or 0, BackgroundColor3 = spec[2], ZIndex = 132, Parent = item }, { round(spec[1] == "circle" and UDim.new(1, 0) or UDim.new(0, 3)), stroke(INK, 1.5) })
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -22, 1, 0), Font = DISPLAY, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = spec[3], TextColor3 = INK, ZIndex = 132, Parent = item })
end
-- big anime clouds framing the chart, half over its edges
local chartClouds = {}
for i, spec in ipairs({ { -0.08, -0.08, 0.26 }, { 0.82, -0.1, 0.24 }, { -0.1, 0.78, 0.3 }, { 0.84, 0.76, 0.26 }, { 0.42, 0.9, 0.2 }, { 0.3, -0.12, 0.16 } }) do
	local c = animeCloud(chart, 10, 150 + i * 3, 0)
	c.Size = UDim2.new(spec[3], 0, spec[3] * 0.55 * (SPAN_X / SPAN_Z), 0)
	c.Position = UDim2.new(spec[1], 0, spec[2], 0)
	table.insert(chartClouds, { frame = c, base = c.Position, seed = i * 2.3 })
end
local chartMarker = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 22, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "▲", TextColor3 = WHITE, TextStrokeColor3 = Color3.fromRGB(230, 60, 40), TextStrokeTransparency = 0, ZIndex = 125, Parent = chartWindow })
local chartWorld = nil
local chartZoom = 0.2

local function openChart(open)
	chartOpen = open
	if open then
		chart.Visible = true
		task.defer(function()
			-- fit the whole map in the window
			local size = chartWindow.AbsoluteSize
			chartZoom = math.min(size.X / SPAN_X, size.Y / SPAN_Z)
			if chartWorld then
				chartWorld:Destroy()
			end
			chartWorld = drawWorld(chartWindow, chartZoom, { iconScale = 1.1, names = true })
		end)
		chartScale.Scale = 0.85
		TweenService:Create(chartScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		chart.Visible = false
	end
end
close.Activated:Connect(function()
	openChart(false)
end)
local openButton = new("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 65, Parent = window })
openButton.Activated:Connect(function()
	openChart(not chartOpen)
end)

local shown = true
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		shown = not shown
	elseif input.KeyCode == Enum.KeyCode.N then
		openChart(not chartOpen)
	end
end)

-- Every frame ---------------------------------------------------------------------------------------------------

local function placeName(p)
	if p.Y < Config.Kelp.belowY then
		return "KELP CATHEDRAL"
	end
	local safe = Config.safeZone(p)
	if safe == "Nest" then
		return "EGGFALL TOWN"
	elseif safe == "Harbor" then
		return "HARBOR RING"
	end
	local island = L.island(p)
	if island then
		return island.title:upper()
	end
	return "THE OPEN SEA"
end

local others = {}
local nameAt = 0
RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inKelp = root and root.Position.Y < Config.Kelp.belowY
	holder.Visible = shown and not MotionBus.cutscene and not inKelp
	if chartOpen and MotionBus.cutscene then
		openChart(false)
	end
	local t = os.clock()
	if holder.Visible and root and #miniWorlds > 0 then
		local zoom = ZOOMS[zoomIndex]
		local px = toPx(root.Position, zoom)
		local half = window.AbsoluteSize / 2
		local origin = window.AbsolutePosition
		for i, strip in ipairs(strips) do
			local offset = strip.AbsolutePosition - origin
			miniWorlds[i].Position = UDim2.new(0, half.X - px.X - offset.X, 0, half.Y - px.Y - offset.Y)
		end
		local look = root.CFrame.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, look.Z))
		local beat = (t * 1.2) % 1
		pulse.Size = UDim2.new(0, 20 + 26 * beat, 0, 20 + 26 * beat)
		pulse.UIStroke.Transparency = beat
		if t > nameAt then
			nameAt = t + 0.4
			placeLabel.Text = placeName(root.Position)
		end
		-- other divers as yellow dots
		local seen = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r then
				seen[p] = true
				local dot = others[p]
				if not dot or not dot.Parent then
					dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 9, 0, 9), BackgroundColor3 = Color3.fromRGB(255, 220, 70), ZIndex = 55, Parent = window }, { round(), stroke(INK, 1.5) })
					others[p] = dot
				end
				local q = toPx(r.Position, zoom) - px
				dot.Position = UDim2.new(0, half.X + q.X, 0, half.Y + q.Y)
				dot.Visible = q.Magnitude <= VIEW_R - 6 -- other divers past the edge aren't drawn outside the map
			end
		end
		for p, dot in pairs(others) do
			if not seen[p] then
				dot:Destroy()
				others[p] = nil
			end
		end
	end
	if chartOpen then
		for _, c in ipairs(chartClouds) do
			c.frame.Position = c.base + UDim2.new(0, math.sin(t * 0.5 + c.seed) * 6, 0, math.cos(t * 0.4 + c.seed) * 4)
		end
		if root then
			local q = toPx(root.Position, chartZoom)
			chartMarker.Position = UDim2.new(0, q.X, 0, q.Y)
			local look = root.CFrame.LookVector
			chartMarker.Rotation = math.deg(math.atan2(look.X, look.Z))
			local size = 22 + 5 * math.sin(t * 6)
			chartMarker.Size = UDim2.new(0, size, 0, size)
		end
	end
end)
