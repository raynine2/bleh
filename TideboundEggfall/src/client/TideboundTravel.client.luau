-- Tidebound: Eggfall: getting around the Open Isles (Patch 10), all on your own screen:
--   Geysers     step on a geyser pad (TideboundJumpPad) and it throws you in a high arc to its partner pad on
--               a far island, with a front flip at the top (TideboundMotion reads MotionBus.launch)
--   The edge    past the edge of the charts a current turns you back toward the islands
--   Island cards entering a new island pops its name and ring; leaving town warns you, coming home says so
--   Sea chart   a minimap of the whole map in the corner (M to show or hide): the town, every island, the
--               beacons, the Tide Caches, the geysers and you. Click it for a big view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Fx = require(Shared:WaitForChild("Fx"))
local Audio = require(Shared:WaitForChild("Audio"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))
local FishingFeel = require(Shared:WaitForChild("FishingFeel"))
local L = require(Shared:WaitForChild("IslesLayout"))

local player = Players.LocalPlayer
local GEYSER = Color3.fromRGB(120, 230, 255)
local WHITE = Color3.new(1, 1, 1)
local DISPLAY = Enum.Font.FredokaOne

local function rootAndHumanoid()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid, character
	end
	return nil
end

-- Geysers -----------------------------------------------------------------------------------------------------

local pads = {}
local function watchPad(pad)
	if pad:IsA("BasePart") then
		pads[pad] = true
	end
end
for _, pad in ipairs(CollectionService:GetTagged("TideboundJumpPad")) do
	watchPad(pad)
end
CollectionService:GetInstanceAddedSignal("TideboundJumpPad"):Connect(watchPad)
CollectionService:GetInstanceRemovedSignal("TideboundJumpPad"):Connect(function(pad)
	pads[pad] = nil
end)

local flight = nil -- { start, duration, from, v0, target, character }
local padCooldown = 0

local function burst(at, big)
	Fx.cubes(at, { GEYSER, WHITE, Color3.fromRGB(200, 245, 255) }, { spread = big and 9 or 5, size = 0.6, life = 0.7, up = 1, count = big and 26 or 14, material = Enum.Material.SmoothPlastic })
	Fx.ring(at + Vector3.new(0, 0.2, 0), GEYSER, big and 9 or 5, 0.5, 0.3)
end

local function launch(pad, root, humanoid, character)
	local target = pad:GetAttribute("Target")
	if typeof(target) ~= "Vector3" then
		return
	end
	local from = root.Position
	local goal = target + Vector3.new(0, root.Position.Y - pad.Position.Y, 0)
	local distance = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	local duration = math.clamp(distance / 105, 1.7, 3.4)
	local g = Vector3.new(0, -workspace.Gravity, 0)
	local v0 = (goal - from - 0.5 * g * duration * duration) / duration
	flight = { start = os.clock(), duration = duration, from = from, v0 = v0, g = g, goal = goal, character = character }
	MotionBus.launch[character] = { start = flight.start, duration = duration }
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	burst(pad.Position, true)
	-- a column of water shoots up with you
	local column = Instance.new("Part")
	column.Name = "GeyserColumn"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Shape = Enum.PartType.Cylinder
	column.Material = Enum.Material.SmoothPlastic
	column.Color = Color3.fromRGB(210, 245, 255)
	column.Transparency = 0.2
	column.Size = Vector3.new(1, 5, 5)
	column.CFrame = CFrame.new(pad.Position) * CFrame.Angles(0, 0, math.rad(90))
	column.Parent = Fx.folder()
	TweenService:Create(column, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(30, 4, 4), CFrame = CFrame.new(pad.Position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)) }):Play()
	TweenService:Create(column, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(column, 1.1)
	Audio.play("Whoosh", root)
	FishingFeel.shake(0.25, 0.3)
end

RunService.PreSimulation:Connect(function()
	local root, humanoid, character = rootAndHumanoid()
	if flight then
		if not root or character ~= flight.character then
			flight = nil
			return
		end
		local u = os.clock() - flight.start
		if u >= flight.duration then
			-- land on the partner pad
			root.AssemblyLinearVelocity = flight.v0 * Vector3.new(0.15, 0, 0.15)
			burst(flight.goal - Vector3.new(0, 2.5, 0), true)
			FishingFeel.shake(0.3, 0.25)
			MotionBus.launch[character] = nil
			flight = nil
			padCooldown = os.clock() + 2
			return
		end
		local pos = flight.from + flight.v0 * u + 0.5 * flight.g * u * u
		local vel = flight.v0 + flight.g * u
		local flatVel = Vector3.new(vel.X, 0, vel.Z)
		local look = flatVel.Magnitude > 0.1 and flatVel.Unit or root.CFrame.LookVector
		root.CFrame = CFrame.lookAt(pos, pos + look)
		root.AssemblyLinearVelocity = vel
		if math.random() < 0.5 then
			Fx.cubes(pos - Vector3.new(0, 2, 0), { WHITE, GEYSER }, { spread = 1.5, size = 0.35, life = 0.35, up = 0, count = 2 })
		end
		return
	end
	if not root or os.clock() < padCooldown or MotionBus.cutscene or FishingFeel.phase ~= "" then
		return
	end
	for pad in pairs(pads) do
		if pad.Parent then
			local offset = root.Position - pad.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < pad.Size.Y / 2 + 0.6 and offset.Y > -1 and offset.Y < 6 then
				launch(pad, root, humanoid, character)
				return
			end
		end
	end
end)

-- The edge of the charts --------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TideboundTravel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "IslandCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 70)
card.Size = UDim2.new(0, 420, 0, 74)
card.BackgroundTransparency = 1
card.Visible = false
card.Parent = gui
local cardTitle = Instance.new("TextLabel")
cardTitle.BackgroundTransparency = 1
cardTitle.Size = UDim2.new(1, 0, 0, 46)
cardTitle.Font = DISPLAY
cardTitle.TextScaled = true
cardTitle.TextColor3 = WHITE
cardTitle.TextStrokeTransparency = 0
cardTitle.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
cardTitle.Parent = card
local cardSub = cardTitle:Clone()
cardSub.Position = UDim2.new(0, 0, 0, 46)
cardSub.Size = UDim2.new(1, 0, 0, 24)
cardSub.Font = Enum.Font.BuilderSansBold
cardSub.Parent = card
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

local cardToken = 0
local function showCard(title, subtitle, color)
	cardToken += 1
	local token = cardToken
	cardTitle.Text = title
	cardTitle.TextColor3 = color or WHITE
	cardSub.Text = subtitle or ""
	card.Visible = true
	cardTitle.TextTransparency, cardSub.TextTransparency = 0, 0
	cardTitle.TextStrokeTransparency, cardSub.TextStrokeTransparency = 0, 0
	cardScale.Scale = 0.6
	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if cardToken ~= token then
			return
		end
		local info = TweenInfo.new(0.5)
		for _, label in ipairs({ cardTitle, cardSub }) do
			TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.wait(0.5)
		if cardToken == token then
			card.Visible = false
		end
	end)
end

local RING_COLOR = { Color3.fromRGB(200, 255, 230), Color3.fromRGB(255, 236, 150), Color3.fromRGB(255, 190, 170) }
local RING_NAME = { "Ring 1 · The Shallows", "Ring 2 · The Coral Maze", "Ring 3 · The Outer Reef · stormy" }

local lastIsland = nil
local lastSafe = nil
local edgeWarnAt = 0
task.spawn(function()
	while true do
		task.wait(0.25)
		local root = rootAndHumanoid()
		if root and not MotionBus.cutscene then
			local p = root.Position
			if p.Y > Config.Kelp.belowY then
				-- island cards
				local island = L.island(p)
				if island and island ~= lastIsland and not flight then
					showCard(island.title:upper(), RING_NAME[island.ring], RING_COLOR[island.ring])
				end
				if island or not lastIsland then
					lastIsland = island
				end
				-- leaving and coming back to town
				local safe = Config.safeZone(p)
				if lastSafe ~= nil and safe ~= lastSafe then
					if safe == "Nest" then
						showCard("EGGFALL TOWN", "Safe zone: no mobs, no heat. Heal up!", Color3.fromRGB(255, 236, 170))
					elseif not safe and lastSafe == "Nest" then
						showCard("THE SUNKEN SHOALS", "Danger! Mobs attack. Swipe with click or F.", Color3.fromRGB(255, 130, 120))
					end
				end
				lastSafe = safe
				-- the current at the edge of the charts
				local min, max = L.playMin, L.playMax
				local inward = Vector3.zero
				if p.X < min.X then
					inward += Vector3.new(1, 0, 0)
				elseif p.X > max.X then
					inward += Vector3.new(-1, 0, 0)
				end
				if p.Z < min.Z then
					inward += Vector3.new(0, 0, 1)
				elseif p.Z > max.Z then
					inward += Vector3.new(0, 0, -1)
				end
				if inward.Magnitude > 0 then
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0) + inward.Unit * 28
					if os.clock() > edgeWarnAt then
						edgeWarnAt = os.clock() + 6
						showCard("THE EDGE OF THE CHARTS", "A strong current turns you back.", Color3.fromRGB(150, 220, 255))
					end
				end
			end
		end
	end
end)

-- The sea chart (minimap) -------------------------------------------------------------------------------------

local CHART_MIN = Vector3.new(L.playMin.X - 40, 0, L.playMin.Z - 40)
local CHART_MAX = Vector3.new(L.playMax.X + 40, 0, L.playMax.Z + 40)
local spanX, spanZ = CHART_MAX.X - CHART_MIN.X, CHART_MAX.Z - CHART_MIN.Z

local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local chart = Instance.new("Frame")
chart.Name = "SeaChart"
chart.AnchorPoint = Vector2.new(1, 0)
chart.Position = UDim2.new(1, -14, 0, 14)
chart.BackgroundColor3 = Color3.fromRGB(40, 120, 150)
chart.BackgroundTransparency = 0.15
chart.ClipsDescendants = true
chart.Parent = gui
local chartCorner = Instance.new("UICorner")
chartCorner.CornerRadius = UDim.new(0, 12)
chartCorner.Parent = chart
local chartStroke = Instance.new("UIStroke")
chartStroke.Color = Color3.fromRGB(240, 230, 200)
chartStroke.Thickness = 3
chartStroke.Parent = chart
local chartAspect = spanZ / spanX

local function chartSize(big)
	local w = big and 520 or (touch and 120 or 180)
	return UDim2.new(0, w, 0, math.floor(w * chartAspect))
end
local big = false
chart.Size = chartSize(false)

-- map x (east) to the chart's right and z (north, +Z) to its top
local function toChart(p)
	return UDim2.new((p.X - CHART_MIN.X) / spanX, 0, 1 - (p.Z - CHART_MIN.Z) / spanZ, 0)
end

local function dot(parent, p, size, color, zindex, shape)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = toChart(p)
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = zindex or 2
	if shape ~= "square" then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local RING_FILL = { Color3.fromRGB(120, 210, 110), Color3.fromRGB(96, 190, 84), Color3.fromRGB(110, 120, 120) }
local function relSize(radius)
	return UDim2.new(radius * 2 / spanX, 0, radius * 2 / spanZ, 0)
end
-- the town and the islands, drawn to scale
dot(chart, Vector3.new(-25, 0, 0), relSize(150), Color3.fromRGB(236, 216, 164), 2)
dot(chart, Vector3.new(0, 0, 0), relSize(60), Color3.fromRGB(246, 244, 248), 3)
local harbor = Config.Harbor.center
dot(chart, harbor, relSize(170), Color3.fromRGB(236, 230, 220), 2)
for _, island in ipairs(L.islands) do
	dot(chart, island.pos, relSize(island.r + 6), RING_FILL[island.ring], 2)
end
for _, link in ipairs(L.links) do
	local a, b = L.byName[link[1]].pos, L.byName[link[2]].pos
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Color3.fromRGB(150, 104, 68)
	line.ZIndex = 1
	line.Parent = chart
	line:SetAttribute("A", a)
	line:SetAttribute("B", b)
end
local beaconDots = {}
for _, b in ipairs(L.beacons) do
	table.insert(beaconDots, dot(chart, b, UDim2.new(0, 6, 0, 6), Color3.fromRGB(90, 255, 200), 5, "square"))
end
for _, c in ipairs(L.tideCaches) do
	dot(chart, c, UDim2.new(0, 7, 0, 7), Color3.fromRGB(255, 150, 90), 5)
end
for _, pair in ipairs(L.jumpPads) do
	dot(chart, pair[1], UDim2.new(0, 4, 0, 4), GEYSER, 4)
	dot(chart, pair[2], UDim2.new(0, 4, 0, 4), GEYSER, 4)
end
dot(chart, L.wardenLair, UDim2.new(0, 8, 0, 8), Color3.fromRGB(255, 70, 60), 5)
dot(chart, L.maelstrom, UDim2.new(0, 10, 0, 10), Color3.fromRGB(20, 60, 90), 4)
local townLabel = Instance.new("TextLabel")
townLabel.BackgroundTransparency = 1
townLabel.AnchorPoint = Vector2.new(0.5, 0.5)
townLabel.Position = toChart(Vector3.new(0, 0, 60))
townLabel.Size = UDim2.new(0, 60, 0, 12)
townLabel.Font = DISPLAY
townLabel.TextScaled = true
townLabel.Text = "TOWN"
townLabel.TextColor3 = Color3.fromRGB(60, 40, 30)
townLabel.ZIndex = 6
townLabel.Parent = chart

-- you: an arrow pointing the way you face
local me = Instance.new("TextLabel")
me.AnchorPoint = Vector2.new(0.5, 0.5)
me.Size = UDim2.new(0, 16, 0, 16)
me.BackgroundTransparency = 1
me.Font = Enum.Font.GothamBlack
me.TextScaled = true
me.Text = "▲"
me.TextColor3 = WHITE
me.TextStrokeColor3 = Color3.fromRGB(255, 60, 40)
me.TextStrokeTransparency = 0
me.ZIndex = 8
me.Parent = chart
local others = {}

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -2)
hint.Size = UDim2.new(1, 0, 0, 12)
hint.Font = Enum.Font.BuilderSansBold
hint.TextScaled = true
hint.Text = touch and "tap: big map" or "M: hide · click: big map"
hint.TextColor3 = WHITE
hint.TextStrokeTransparency = 0.3
hint.ZIndex = 9
hint.Parent = chart

local function layoutLinks()
	local size = chart.AbsoluteSize
	for _, line in ipairs(chart:GetChildren()) do
		local a, b = line:GetAttribute("A"), line:GetAttribute("B")
		if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			local pa = Vector2.new((a.X - CHART_MIN.X) / spanX * size.X, (1 - (a.Z - CHART_MIN.Z) / spanZ) * size.Y)
			local pb = Vector2.new((b.X - CHART_MIN.X) / spanX * size.X, (1 - (b.Z - CHART_MIN.Z) / spanZ) * size.Y)
			local mid = (pa + pb) / 2
			line.Position = UDim2.new(0, mid.X, 0, mid.Y)
			line.Size = UDim2.new(0, (pb - pa).Magnitude, 0, big and 3 or 2)
			line.Rotation = math.deg(math.atan2(pb.Y - pa.Y, pb.X - pa.X))
		end
	end
end
chart:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLinks)
task.defer(layoutLinks)

local shown = true
local function setBig(value)
	big = value
	TweenService:Create(chart, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = chartSize(big) }):Play()
	hint.Text = big and (touch and "tap: close" or "click: close") or (touch and "tap: big map" or "M: hide · click: big map")
end
chart.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		setBig(not big)
	end
end)
chart.Active = true
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		shown = not shown
		chart.Visible = shown
	end
end)

RunService.RenderStepped:Connect(function()
	local root = rootAndHumanoid()
	local inKelp = root and root.Position.Y < Config.Kelp.belowY
	chart.Visible = shown and not MotionBus.cutscene and not inKelp
	if not chart.Visible then
		return
	end
	if root then
		me.Position = toChart(root.Position)
		local look = root.CFrame.LookVector
		me.Rotation = math.deg(math.atan2(look.X, look.Z))
	end
	-- other divers
	local seen = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local r = p.Character:FindFirstChild("HumanoidRootPart")
			if r then
				seen[p] = true
				local d = others[p]
				if not d then
					d = dot(chart, r.Position, UDim2.new(0, 7, 0, 7), Color3.fromRGB(255, 220, 90), 7)
					others[p] = d
				end
				d.Position = toChart(r.Position)
			end
		end
	end
	for p, d in pairs(others) do
		if not seen[p] then
			d:Destroy()
			others[p] = nil
		end
	end
end)
