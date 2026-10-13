-- Tidebound: Eggfall: Delta Sections 7 and 8. Builds the Harbor Ring hub and the 8 Home Nest plots as a
-- new folder inside Workspace.TideboundWorld, without touching the Nest plaza or the Sunken Shoals.
-- Everything reuses WorldBuilder's REF 1 / REF 3 / REF 5 props and palette, so the new areas match the refs:
-- snowy voxel ground and terraces (REF 1), neon shop signage (REF 3), timber houses and lanterns (REF 5).
-- Also adds the Nest plaza's NPCs and the Tide Slide pad, inside the same folder.
-- Patch 10: the Shoals' Tide Caches, anemone beds and elite dens moved to ShoalsBuilder with the Open Isles.

local CollectionService = game:GetService("CollectionService")

local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local PlotLayout = require(script.Parent:WaitForChild("PlotLayout"))
local PropKit = require(script.Parent:WaitForChild("PropKit"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Tidebound"):WaitForChild("Config"))

local ExpansionBuilder = {}

local VERSION = 7

local K = WorldBuilder.kit
local P = K.color
local part, decor, disk, prompt, billboard, surfaceText, light = K.part, K.decor, K.disk, K.prompt, K.billboard, K.surfaceText, K.light
local TOP = K.TOP

local NEON_CYAN = Color3.fromRGB(110, 236, 255)
local NEON_RED = Color3.fromRGB(255, 60, 80)
local SIGN_DARK = Color3.fromRGB(20, 16, 34)
local SKIN = Color3.fromRGB(234, 196, 160)
local LOCK_RED = Color3.fromRGB(255, 70, 90)

local HARBOR = Config.Harbor.center
local HUB = Vector3.new(HARBOR.X, TOP, HARBOR.Z)

local function onRing(angleDeg, radius)
	local a = math.rad(angleDeg)
	return HUB + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

local function facing(at, target)
	return CFrame.lookAt(at, Vector3.new(target.X, at.Y, target.Z))
end

-- Dark sign board with neon text and a neon tube on top (REF 3).
local function neonSign(parent, cframe, width, height, text, color)
	local board = decor({ Name = "NeonSign", Size = Vector3.new(width, height, 0.5), CFrame = cframe, Color = SIGN_DARK, Parent = parent })
	surfaceText(board, text, color or NEON_CYAN)
	decor({ Name = "SignNeon", Size = Vector3.new(width + 0.6, 0.3, 0.3), CFrame = cframe * CFrame.new(0, height / 2 + 0.2, -0.2), Color = color or NEON_CYAN, Material = Enum.Material.Neon, Parent = parent })
	return board
end

-- Notice board on two posts with paper notes (REF 5 timber), used for quests and the season track.
local function noticeBoard(parent, at, target, title, color)
	local cf = facing(at, target)
	for _, x in ipairs({ -4.5, 4.5 }) do
		part({ Name = "BoardPost", Size = Vector3.new(0.9, 9, 0.9), CFrame = cf * CFrame.new(x, 4.5, 0), Color = P.TIMBER, Parent = parent })
	end
	local board = part({ Name = "Board", Size = Vector3.new(10, 5.4, 0.6), CFrame = cf * CFrame.new(0, 4.6, 0), Color = P.PLANK, Material = Enum.Material.WoodPlanks, Parent = parent })
	decor({ Name = "BoardRoof", Size = Vector3.new(11.6, 0.6, 2.4), CFrame = cf * CFrame.new(0, 9.3, 0) * CFrame.Angles(math.rad(-12), 0, 0), Color = P.ROOF_ORANGE, Parent = parent })
	for i = 1, 6 do
		decor({ Name = "Note", Size = Vector3.new(1.6, 1.9, 0.1), CFrame = cf * CFrame.new(-3.6 + ((i - 1) % 3) * 3.6, 3.5 + math.floor((i - 1) / 3) * 2.2, -0.36) * CFrame.Angles(0, 0, math.rad((i % 3 - 1) * 6)), Color = Color3.fromRGB(250, 244, 224), Parent = parent })
	end
	neonSign(parent, cf * CFrame.new(0, 11.2, 0), 10, 2, title, color)
	return board, cf
end

-- Blocky villager in the REF 1 voxel style. `kind` = "person", "crab" or "bird".
local function npc(parent, id, cframe, kind, shirt, hat)
	local info = Config.Npcs[id]
	local model = Instance.new("Model")
	model.Name = "Npc_" .. id
	model.Parent = parent
	local body
	if kind == "crab" then
		body = part({ Name = "Body", Size = Vector3.new(3.4, 1.6, 2.6), CFrame = cframe * CFrame.new(0, 1.4, 0), Color = Color3.fromRGB(226, 84, 60), CanCollide = false, Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			decor({ Name = "Claw", Size = Vector3.new(1.2, 1, 1.4), CFrame = cframe * CFrame.new(side * 2.4, 2, -1.2) * CFrame.Angles(0, 0, side * 0.4), Color = Color3.fromRGB(240, 110, 80), Parent = model })
			decor({ Name = "EyeStalk", Size = Vector3.new(0.3, 1, 0.3), CFrame = cframe * CFrame.new(side * 0.6, 2.6, -0.9), Color = Color3.fromRGB(226, 84, 60), Parent = model })
			decor({ Name = "Eye", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = cframe * CFrame.new(side * 0.6, 3.2, -0.9), Color = Color3.fromRGB(20, 20, 26), Parent = model })
			for leg = -1, 1 do
				decor({ Name = "Leg", Size = Vector3.new(1.2, 0.3, 0.3), CFrame = cframe * CFrame.new(side * 2, 0.7, leg * 0.8) * CFrame.Angles(0, 0, side * -0.6), Color = Color3.fromRGB(200, 70, 50), Parent = model })
			end
		end
	elseif kind == "bird" then
		body = part({ Name = "Body", Size = Vector3.new(2.2, 2.6, 3), CFrame = cframe * CFrame.new(0, 2.8, 0), Color = Color3.fromRGB(246, 246, 250), CanCollide = false, Parent = model })
		decor({ Name = "Head", Size = Vector3.new(1.8, 1.8, 1.8), CFrame = cframe * CFrame.new(0, 4.6, -0.8), Color = Color3.fromRGB(246, 246, 250), Parent = model })
		decor({ Name = "Beak", Size = Vector3.new(0.6, 0.5, 1.2), CFrame = cframe * CFrame.new(0, 4.4, -2.1), Color = Color3.fromRGB(255, 170, 50), Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			decor({ Name = "Wing", Size = Vector3.new(0.4, 1.8, 2.6), CFrame = cframe * CFrame.new(side * 1.3, 2.9, 0.2), Color = Color3.fromRGB(150, 160, 176), Parent = model })
			decor({ Name = "Eye", Size = Vector3.new(0.3, 0.4, 0.3), CFrame = cframe * CFrame.new(side * 0.6, 4.9, -1.6), Color = Color3.fromRGB(20, 20, 26), Parent = model })
			decor({ Name = "Leg", Size = Vector3.new(0.3, 1.6, 0.3), CFrame = cframe * CFrame.new(side * 0.5, 0.8, 0), Color = Color3.fromRGB(255, 170, 50), Parent = model })
		end
	else
		body = part({ Name = "Body", Size = Vector3.new(2.4, 2.6, 1.3), CFrame = cframe * CFrame.new(0, 3.5, 0), Color = shirt, CanCollide = false, Parent = model })
		decor({ Name = "Head", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cframe * CFrame.new(0, 5.6, 0), Color = SKIN, Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			decor({ Name = "Leg", Size = Vector3.new(1.1, 2.2, 1.2), CFrame = cframe * CFrame.new(side * 0.6, 1.1, 0), Color = Color3.fromRGB(60, 56, 70), Parent = model })
			decor({ Name = "Arm", Size = Vector3.new(0.8, 2.4, 1), CFrame = cframe * CFrame.new(side * 1.65, 3.5, 0), Color = SKIN, Parent = model })
			decor({ Name = "Eye", Size = Vector3.new(0.25, 0.35, 0.1), CFrame = cframe * CFrame.new(side * 0.4, 5.7, -0.82), Color = Color3.fromRGB(20, 20, 26), Parent = model })
		end
		if hat then
			decor({ Name = "Hat", Size = Vector3.new(2, 0.5, 2), CFrame = cframe * CFrame.new(0, 6.6, 0), Color = hat, Parent = model })
			decor({ Name = "HatTop", Size = Vector3.new(1.4, 0.8, 1.4), CFrame = cframe * CFrame.new(0, 7.2, 0), Color = hat, Parent = model })
		end
	end
	model.PrimaryPart = body
	model:SetAttribute("Kind", kind)
	CollectionService:AddTag(model, "TideboundNpc") -- TideboundLife gives them idle motion and turns them to you
	billboard(body, info.name, info.role, kind == "person" and 4.6 or 3.6)
	prompt(body, "Talk", info.name, { Npc = id }, 0, 10)
	return model
end

-- Tide Slide pad: a glowing beacon-coloured disk that sends you between the Nest and the Harbor Ring.
local function tideSlide(parent, at, destination, subtitle)
	disk(parent, "SlideBase", at + Vector3.new(0, 0.3, 0), 4.4, 0.6, P.STONE)
	local pad = disk(parent, "TideSlide", at + Vector3.new(0, 0.7, 0), 3.6, 0.3, P.BEACON)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.15
	K.sparkles(pad, Color3.fromRGB(200, 255, 240), 6)
	light(pad, P.BEACON, 14, 1.4)
	prompt(pad, "Slide", "Tide Slide", { Action = "Travel", Dest = destination }, 0.5, 10)
	billboard(pad, "TIDE SLIDE", subtitle, 4)
	return pad
end

-- Nest plaza additions (Delta Section 8) ---------------------------------------------------------

local function buildNestAdditions(root)
	local folder = Instance.new("Folder")
	folder.Name = "NestAdditions"
	folder.Parent = root
	local plaza = Vector3.new(0, TOP, 0)

	tideSlide(folder, Vector3.new(-14, TOP, -26), "Harbor", "To the Harbor Ring")
	npc(folder, "Pinch", facing(Vector3.new(-7, TOP, -21), plaza), "crab")
	-- behind the Tackle Shop counter (the stall at (18, -32) faces the plaza)
	local stall = facing(Vector3.new(18, TOP, -32), plaza)
	npc(folder, "OldHarl", stall * CFrame.new(-4.4, 0.6, 1.2), "person", Color3.fromRGB(70, 96, 140), Color3.fromRGB(90, 70, 50))
	npc(folder, "SisterCoralie", facing(Vector3.new(-31, TOP, 4), plaza), "person", Color3.fromRGB(236, 236, 244), Color3.fromRGB(255, 90, 110))
	npc(folder, "GateWardenSel", facing(Vector3.new(42, TOP, -10), Vector3.new(30, TOP, 0)), "person", Color3.fromRGB(176, 34, 30), Color3.fromRGB(44, 34, 34))
end

-- Harbor Ring hub ----------------------------------------------------------------------------

local function buildHarbor(root)
	local harbor = Instance.new("Folder")
	harbor.Name = "HarborRing"
	harbor.Parent = root
	local rng = Random.new(2026)
	local lagoonR = Config.Harbor.lagoonRadius
	local groundR = Config.Harbor.groundRadius

	-- snowy ground as a 24-sided ring so the lagoon in the middle is real water you can swim in
	local segments = 24
	local length = groundR - lagoonR
	for i = 0, segments - 1 do
		local angle = i * 360 / segments
		local mid = onRing(angle, lagoonR + length / 2)
		local ground = part({ Name = "HarborGround", Size = Vector3.new(groundR * 2 * math.pi / segments + 2, 8, length), CFrame = facing(mid - Vector3.new(0, 4, 0), HUB - Vector3.new(0, 4, 0)), Color = P.SNOW_GROUND, Material = Enum.Material.Plastic, Parent = harbor })
		ground.TopSurface = Enum.SurfaceType.Studs -- Patch 13: studded snow, like the references
	end
	workspace.Terrain:FillCylinder(CFrame.new(HARBOR.X, TOP - 4.5, HARBOR.Z), 9, lagoonR + 2, Enum.Material.Water)
	disk(harbor, "LagoonFloor", Vector3.new(HARBOR.X, 0.25, HARBOR.Z), lagoonR + 3, 0.5, Color3.fromRGB(196, 220, 170), Enum.Material.Sand)

	-- lagoon rim: grey stone blocks with a gold cap, like the plaza fountain (REF 1)
	for i = 0, 35 do
		local at = onRing(i * 10, lagoonR + 0.6)
		local cf = facing(at, HUB)
		part({ Name = "LagoonRim", Size = Vector3.new(7, 2.4, 2.2), CFrame = cf * CFrame.new(0, 1.2, 0), Color = P.STONE, Parent = harbor })
		decor({ Name = "LagoonRimCap", Size = Vector3.new(7.2, 0.5, 2.4), CFrame = cf * CFrame.new(0, 2.6, 0), Color = P.GOLD, Parent = harbor })
	end
	for i = 0, 3 do
		local at = onRing(45 + i * 90, lagoonR + 1)
		part({ Name = "FinialPillar", Size = Vector3.new(3, 6, 3), CFrame = CFrame.new(at + Vector3.new(0, 3, 0)), Color = P.STONE, Parent = harbor })
		part({ Name = "FinialBall", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(at + Vector3.new(0, 7.5, 0)), Color = P.STONE, Parent = harbor })
	end

	-- Lagoon pier fishing (no Heat): a plank pier into the lagoon with a fishing ripple at its end
	local pierStart, pierEnd = onRing(135, lagoonR + 4), onRing(135, 16)
	K.boardwalkSegment(harbor, pierStart, pierEnd, 7)
	local spot = part({
		Name = "PierSpot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(onRing(135, 9).X, TOP + 0.1, onRing(135, 9).Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 236, 255),
		Transparency = 0.55,
		CanCollide = false,
		CastShadow = false,
		Parent = harbor,
	})
	K.sparkles(spot, Color3.new(1, 1, 1), 4)
	prompt(spot, "Cast", "Lagoon Pier (no Heat)", { Action = "Cast", Pier = true }, 0, 18)
	billboard(decor({ Name = "PierSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pierStart + Vector3.new(0, 7, 0)), Transparency = 1, Parent = harbor }), "LAGOON PIER", "Safe fishing, half Pearls, no Heat", 0)

	-- arrival: the Tide Slide back to the Nest, on the side facing the Nest (north)
	tideSlide(harbor, onRing(90, 54), "Nest", "To the Nest plaza")

	-- stations around the promenade, each facing the lagoon
	local stationR = 74
	-- Daily Quest Board (Quill)
	local questBoard, questCf = noticeBoard(harbor, onRing(45, stationR), HUB, "DAILY QUESTS", Color3.fromRGB(120, 255, 140))
	questBoard.Name = "QuestBoard"
	prompt(questBoard, "Quests", "Daily Quest Board", { Panel = "QUESTS" }, 0, 12)
	npc(harbor, "Quill", questCf * CFrame.new(7, 0, -2), "bird")

	-- Season Pass Board (Captain Brask)
	local seasonBoard, seasonCf = noticeBoard(harbor, onRing(0, stationR), HUB, "SEASON TRACK", NEON_RED)
	seasonBoard.Name = "SeasonBoard"
	surfaceText(seasonBoard, "Free track opens with Season 1", Color3.fromRGB(255, 230, 200))
	npc(harbor, "CaptainBrask", seasonCf * CFrame.new(7, 0, -2), "person", Color3.fromRGB(40, 60, 110), Color3.fromRGB(30, 30, 40))

	-- Leaderboard Hall (Archivist Ophel): REF 5 timber house with a big REF 4 red neon board in front
	local hallAt = onRing(-45, stationR + 8)
	-- Patch 15: the reference town's red framed shop
	local hallCf = PropKit.frameShop(harbor, hallAt, HUB, 16, 10, 12, "LEADERBOARD HALL", NEON_RED)
	local boardCf = hallCf * CFrame.new(0, 0, -9)
	for _, x in ipairs({ -6.5, 6.5 }) do
		part({ Name = "HallBoardPost", Size = Vector3.new(0.8, 12, 0.8), CFrame = boardCf * CFrame.new(x, 6, 0), Color = Color3.fromRGB(30, 20, 34), Parent = harbor })
	end
	local hallBoard = part({ Name = "LeaderboardPanel", Size = Vector3.new(12, 8, 0.5), CFrame = boardCf * CFrame.new(0, 7.5, 0), Color = Color3.fromRGB(16, 10, 14), Parent = harbor })
	for _, y in ipairs({ -4.1, 4.1 }) do
		decor({ Name = "PanelNeon", Size = Vector3.new(12.6, 0.3, 0.3), CFrame = boardCf * CFrame.new(0, 7.5 + y, -0.3), Color = NEON_RED, Material = Enum.Material.Neon, Parent = harbor })
	end
	for _, x in ipairs({ -6.2, 6.2 }) do
		decor({ Name = "PanelNeon", Size = Vector3.new(0.3, 8.4, 0.3), CFrame = boardCf * CFrame.new(x, 7.5, -0.3), Color = NEON_RED, Material = Enum.Material.Neon, Parent = harbor })
	end
	local boardGui = surfaceText(hallBoard, "LEADERBOARDS", Color3.fromRGB(255, 220, 200))
	boardGui.Name = "BoardText"
	local boardLabel = boardGui:FindFirstChildOfClass("TextLabel")
	if boardLabel then
		boardLabel.TextScaled = false
		boardLabel.TextSize = 22
		boardLabel.Font = Enum.Font.BuilderSansBold
		boardLabel.TextWrapped = true
		boardLabel.TextYAlignment = Enum.TextYAlignment.Top
	end
	prompt(hallBoard, "Boards", "Leaderboard Hall", { Panel = "BOARDS" }, 0, 14)
	npc(harbor, "ArchivistOphel", boardCf * CFrame.new(9, 0, -1), "person", Color3.fromRGB(70, 60, 120), Color3.fromRGB(40, 30, 70))

	-- Bait Shop (Nim): the REF 3 striped awning stall
	local baitCf, baitStall = PropKit.stripedStall(harbor, onRing(-90, stationR), HUB, Color3.fromRGB(70, 180, 90), PropKit.color.WHITE)
	baitStall.Name = "BaitShop"
	local baitCounter = baitStall:FindFirstChild("Counter")
	local baitSign = decor({ Name = "BaitSign", Size = Vector3.new(10, 2.2, 0.4), CFrame = baitCf * CFrame.new(0, 10.4, -2.6), Color = SIGN_DARK, Parent = harbor })
	surfaceText(baitSign, "BAIT SHOP!", Color3.fromRGB(140, 255, 140))
	prompt(baitCounter, "Bait", "Bait Shop", { Panel = "BAIT" }, 0, 12)
	npc(harbor, "Nim", baitCf * CFrame.new(-4, 0.6, 1.2), "person", Color3.fromRGB(120, 200, 90), Color3.fromRGB(230, 200, 70))

	-- Trading Post (Tradesman Kobb)
	local tradeCf = PropKit.glassShop(harbor, onRing(-135, stationR + 6), HUB, 14, 10, 10, "TRADING POST", Color3.fromRGB(240, 196, 50))
	K.crate(harbor, tradeCf * CFrame.new(-6, 1.3, -7))
	K.crate(harbor, tradeCf * CFrame.new(-6, 3.9, -7) * CFrame.Angles(0, 0.5, 0))
	npc(harbor, "TradesmanKobb", tradeCf * CFrame.new(3, 0, -8), "person", Color3.fromRGB(150, 104, 68), Color3.fromRGB(96, 64, 46))

	-- Social Plaza: emote stage with a neon edge, a photo frame and the heist party board
	local stageCf = facing(onRing(180, stationR), HUB)
	part({ Name = "EmoteStage", Size = Vector3.new(22, 1.6, 14), CFrame = stageCf * CFrame.new(0, 0.8, 0), Color = P.PLANK, Material = Enum.Material.WoodPlanks, Parent = harbor })
	for _, z in ipairs({ -7, 7 }) do
		decor({ Name = "StageNeon", Size = Vector3.new(22.4, 0.3, 0.3), CFrame = stageCf * CFrame.new(0, 1.7, z), Color = Color3.fromRGB(255, 120, 220), Material = Enum.Material.Neon, Parent = harbor })
	end
	for _, x in ipairs({ -11, 11 }) do
		decor({ Name = "StageNeon", Size = Vector3.new(0.3, 0.3, 14.4), CFrame = stageCf * CFrame.new(x, 1.7, 0), Color = Color3.fromRGB(255, 120, 220), Material = Enum.Material.Neon, Parent = harbor })
	end
	neonSign(harbor, stageCf * CFrame.new(0, 12, 6), 14, 2.6, "SOCIAL PLAZA", Color3.fromRGB(255, 120, 220))
	for _, x in ipairs({ -7, 7 }) do
		part({ Name = "StagePost", Size = Vector3.new(0.8, 11, 0.8), CFrame = stageCf * CFrame.new(x, 5.5, 6), Color = Color3.fromRGB(30, 20, 34), Parent = harbor })
	end
	local photo = stageCf * CFrame.new(16, 0, 0)
	for _, x in ipairs({ -3, 3 }) do
		decor({ Name = "PhotoFrame", Size = Vector3.new(0.6, 8, 0.6), CFrame = photo * CFrame.new(x, 4, 0), Color = P.GOLD, Parent = harbor })
	end
	decor({ Name = "PhotoFrame", Size = Vector3.new(6.6, 0.6, 0.6), CFrame = photo * CFrame.new(0, 8, 0), Color = P.GOLD, Parent = harbor })
	billboard(decor({ Name = "PhotoSign", Size = Vector3.new(1, 1, 1), CFrame = photo * CFrame.new(0, 9, 0), Transparency = 1, Parent = harbor }), "PHOTO SPOT", "Show off your companion", 1)
	noticeBoard(harbor, (stageCf * CFrame.new(-17, 0, 0)).Position, HUB, "HEIST PARTIES", Color3.fromRGB(255, 200, 80))

	-- lamps, trees and snow between the stations, like the Nest plaza
	for i = 0, 11 do
		K.lampPost(harbor, onRing(15 + i * 30, lagoonR + 8), HUB)
	end
	for i = 0, 7 do
		local angle = 22.5 + i * 45
		for _, side in ipairs({ -1, 1 }) do
			local at = onRing(angle + side * 11, 110 + rng:NextNumber(-6, 6))
			if rng:NextNumber() < 0.6 then
				K.voxelTree(harbor, at, rng, rng:NextNumber(1, 1.3))
			else
				K.pineTree(harbor, at, rng:NextNumber(0.9, 1.2))
			end
		end
		K.plankSteps(harbor, onRing(angle, lagoonR + 6), onRing(angle, Config.Harbor.plotInner + 2), 6)
	end
	for _ = 1, 30 do
		K.flowerTuft(harbor, onRing(rng:NextNumber(0, 360), rng:NextNumber(lagoonR + 12, groundR - 8)), rng)
	end
	local snow = decor({ Name = "SnowEmitter", Size = Vector3.new(300, 1, 300), CFrame = CFrame.new(HARBOR.X, 70, HARBOR.Z), Transparency = 1, Parent = harbor })
	K.particles(snow, {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rate = 60,
		Lifetime = NumberRange.new(14, 18),
		Speed = NumberRange.new(3, 5),
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new(0.1),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(10, 10),
		Drag = 0.3,
		WindAffectsDrag = true,
	})
end

-- Home Nest plots ----------------------------------------------------------------------------------

-- Open-front pavilion in the REF 1 grey-house style: blue-grey walls, white snow roof, stone floor,
-- with a REF 3 neon name sign over the opening.
local function room(plot, origin, id, spec)
	local cf = PlotLayout.roomCFrame(origin, spec)
	local w, h, d = spec.size.X, spec.size.Y, spec.size.Z
	local lift = spec.dais or 0
	local model = Instance.new("Model")
	model.Name = "Room_" .. id
	model.Parent = plot
	if lift > 0 then
		part({ Name = "Dais", Size = Vector3.new(w + 4, lift, d + 4), CFrame = cf * CFrame.new(0, lift / 2, 0), Color = P.STONE, Parent = model })
		for i = 1, 3 do
			part({ Name = "DaisStep", Size = Vector3.new(8, lift * i / 3, 1.6), CFrame = cf * CFrame.new(0, lift * i / 6, -d / 2 - 2 - (3 - i) * 1.6 - 0.8), Color = P.STONE, Parent = model })
		end
	end
	local base = cf * CFrame.new(0, lift, 0)
	part({ Name = "Floor", Size = Vector3.new(w + 1, 0.6, d + 1), CFrame = base * CFrame.new(0, 0.3, 0), Color = P.STONE, Parent = model })
	part({ Name = "BackWall", Size = Vector3.new(w, h, 1), CFrame = base * CFrame.new(0, h / 2, d / 2), Color = P.HOUSE_WALL, Parent = model })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SideWall", Size = Vector3.new(1, h, d), CFrame = base * CFrame.new(side * w / 2, h / 2, 0), Color = P.HOUSE_WALL, Parent = model })
		part({ Name = "FrontPillar", Size = Vector3.new(2.4, h, 1.4), CFrame = base * CFrame.new(side * (w / 2 - 0.7), h / 2, -d / 2), Color = P.HOUSE_WALL, Parent = model })
		decor({ Name = "Window", Size = Vector3.new(0.3, 2.6, 2.6), CFrame = base * CFrame.new(side * (w / 2 + 0.55), h * 0.55, 0), Color = Color3.fromRGB(46, 56, 72), Parent = model })
	end
	part({ Name = "Header", Size = Vector3.new(w, 2, 1.4), CFrame = base * CFrame.new(0, h - 1, -d / 2), Color = P.HOUSE_WALL, Parent = model })
	local angle = math.rad(28)
	local half = d / 2 + 1.5
	for _, dir in ipairs({ -1, 1 }) do
		decor({ Name = "Roof", Size = Vector3.new(w + 2.4, 1.2, half / math.cos(angle)), CFrame = base * CFrame.new(0, h + math.tan(angle) * half / 2, dir * half / 2) * CFrame.Angles(dir * angle, 0, 0), Color = P.SNOW_CAP, Parent = model })
	end
	local sign = neonSign(model, base * CFrame.new(0, h - 1, -d / 2 - 0.95), math.min(w - 4, 16), 1.6, spec.title)
	sign.Name = "RoomSign"
	-- locked sign over the opening; BaseService shows it and the barrier while the room is locked
	local door = part({ Name = "Door", Size = Vector3.new(w - 4.8, h - 2, 0.4), CFrame = base * CFrame.new(0, (h - 2) / 2, -d / 2), Color = LOCK_RED, Material = Enum.Material.Neon, Transparency = 1, CanCollide = false, Parent = model })
	local info = part({ Name = "InfoPost", Size = Vector3.new(0.8, 3.6, 0.8), CFrame = base * CFrame.new(w / 2 + 1.6, 1.8 - lift, -d / 2 - 1.5), Color = P.TIMBER, Parent = model })
	prompt(info, "View", spec.title, { Panel = "BASE", Zone = id }, 0, 10)
	return model, base, door
end

local function buildPlot(root, index, origin)
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("Origin", origin)
	plot.Parent = root
	local rng = Random.new(500 + index)
	local half = PlotLayout.SIZE / 2
	local function at(v)
		return origin * CFrame.new(v.X, v.Y, v.Z)
	end

	part({ Name = "PlotGround", Size = Vector3.new(PlotLayout.SIZE, 8, PlotLayout.SIZE), CFrame = origin * CFrame.new(0, -4, 0), Color = P.SNOW_GROUND, Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs, Parent = plot })

	-- low REF 1 terraces around the sides and back, leaving the front open to the hub
	for _, edge in ipairs({ { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
		for i = -4, 4 do
			local offset = edge[2] == 1 and Vector3.new(i * 13, 0, half - 5) or Vector3.new(edge[1] * (half - 5), 0, i * 13)
			if not (edge[2] == 0 and i <= -4) then
				local height = rng:NextNumber(4, 8)
				K.terraceBlock(plot, at(offset) * CFrame.new(0, height / 2 - 2, 0) * CFrame.Angles(0, edge[2] == 1 and 0 or math.rad(90), 0), Vector3.new(rng:NextNumber(11, 14), height + 4, rng:NextNumber(9, 11)), rng)
			end
		end
	end

	-- gate: stone pillars with finial balls (REF 1 fountain), a plank lintel and the owner's sign
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "GatePillar", Size = Vector3.new(3, 10, 3), CFrame = at(PlotLayout.gate + Vector3.new(side * 8, 5, 0)), Color = P.STONE, Parent = plot })
		part({ Name = "GateBall", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = at(PlotLayout.gate + Vector3.new(side * 8, 11.5, 0)), Color = P.STONE, Parent = plot })
		K.lampPost(plot, at(PlotLayout.gate + Vector3.new(side * 13, 0, 2)).Position, origin.Position)
	end
	decor({ Name = "GateLintel", Size = Vector3.new(19, 1.4, 2), CFrame = at(PlotLayout.gate + Vector3.new(0, 9.4, 0)), Color = P.PLANK, Parent = plot })
	local ownerBoard = decor({ Name = "OwnerSign", Size = Vector3.new(14, 2.4, 0.5), CFrame = at(PlotLayout.gate + Vector3.new(0, 11.4, -0.4)), Color = SIGN_DARK, Parent = plot })
	surfaceText(ownerBoard, ("HOME NEST %d · OPEN"):format(index), NEON_CYAN).Name = "OwnerText"
	K.plankSteps(plot, (at(PlotLayout.gate)).Position, (at(Vector3.new(0, 0, 32))).Position, 6)

	-- five rooms
	for id, spec in pairs(PlotLayout.rooms) do
		local model, base = room(plot, origin, id, spec)
		local w, h, d = spec.size.X, spec.size.Y, spec.size.Z
		if id == "aquarium" then
			local tank = part({ Name = "Tank", Size = Vector3.new(w - 4, h - 3, d - 6), CFrame = base * CFrame.new(0, (h - 3) / 2 + 0.8, 1.5), Color = Color3.fromRGB(110, 200, 255), Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = true, Parent = model })
			decor({ Name = "TankSand", Size = Vector3.new(w - 4.4, 0.6, d - 6.4), CFrame = base * CFrame.new(0, 1.1, 1.5), Color = Color3.fromRGB(232, 214, 160), Parent = model })
			decor({ Name = "TankRim", Size = Vector3.new(w - 3.6, 0.4, d - 5.6), CFrame = base * CFrame.new(0, h - 1.6, 1.5), Color = P.GOLD, Parent = model })
			light(tank, Color3.fromRGB(140, 220, 255), 18, 1.2)
		elseif id == "hatch" then
			local inc = part({ Name = "HomeIncubator", Size = Vector3.new(6, 1.6, 4), CFrame = base * CFrame.new(0, 1.4, 3), Color = P.PLANK, Parent = model })
			decor({ Name = "Straw", Size = Vector3.new(5, 0.5, 3.2), CFrame = base * CFrame.new(0, 2.4, 3), Color = Color3.fromRGB(232, 200, 110), Parent = model })
			prompt(inc, "Hatch Eggs", "Hatch Chamber", { Panel = "ODDS" }, 0, 12)
		elseif id == "workshop" then
			part({ Name = "RodRack", Size = Vector3.new(w - 6, 6, 0.6), CFrame = base * CFrame.new(0, 4, d / 2 - 1.2), Color = Color3.fromRGB(124, 86, 62), Material = Enum.Material.WoodPlanks, Parent = model })
			local bench = part({ Name = "Workbench", Size = Vector3.new(8, 3, 3), CFrame = base * CFrame.new(-3, 2.1, 0), Color = Color3.fromRGB(150, 104, 68), Material = Enum.Material.WoodPlanks, Parent = model })
			prompt(bench, "Rods", "Rod Workshop", { Panel = "RODS" }, 0, 12)
		elseif id == "trophy" then
			-- REF 4 red neon trophy grid on the back wall
			for row = 0, 1 do
				for col = 0, 3 do
					decor({ Name = "TrophyFrame", Size = Vector3.new(3.4, 2.6, 0.2), CFrame = base * CFrame.new(-6 + col * 4, 5.6 + row * 3.2, d / 2 - 0.65), Color = NEON_RED, Material = Enum.Material.Neon, Transparency = 0.35, Parent = model })
				end
			end
			local streak = decor({ Name = "StreakBoard", Size = Vector3.new(6, 2.6, 0.3), CFrame = base * CFrame.new(0, 2.2, d / 2 - 0.7), Color = SIGN_DARK, Parent = model })
			surfaceText(streak, "STREAK 0", Color3.fromRGB(255, 220, 120)).Name = "StreakText"
		elseif id == "altar" then
			disk(model, "AltarRing", (base * CFrame.new(0, 0.9, 1)).Position, 5, 0.6, Color3.fromRGB(70, 66, 86))
			for i = 1, 10 do
				local a = i * math.pi * 2 / 10
				decor({ Name = "Rune" .. i, Size = Vector3.new(0.8, 1.6, 0.8), CFrame = base * CFrame.new(math.cos(a) * 4.2, 1.9, 1 + math.sin(a) * 4.2), Color = Color3.fromRGB(60, 56, 80), Parent = model })
			end
		end
	end

	-- Creature Pen: grass lawn with a plank fence and a feeding trough
	local pen = PlotLayout.pen
	disk(plot, "PenLawn", at(pen.pos + Vector3.new(0, 0.15, 0)).Position, pen.radius, 0.3, P.GRASS)
	for i = 0, 23 do
		local a = i * math.pi * 2 / 24
		if i ~= 18 then -- gap facing the gate
			decor({ Name = "FencePost", Size = Vector3.new(0.6, 2.6, 0.6), CFrame = at(pen.pos + Vector3.new(math.cos(a) * pen.radius, 1.3, math.sin(a) * pen.radius)), Color = P.PLANK_EDGE, Parent = plot })
		end
	end
	local trough = part({ Name = "Trough", Size = Vector3.new(5, 1.4, 2), CFrame = at(PlotLayout.trough + Vector3.new(0, 0.7, 0)), Color = P.PLANK, Parent = plot })
	decor({ Name = "TroughWater", Size = Vector3.new(4.4, 0.2, 1.4), CFrame = at(PlotLayout.trough + Vector3.new(0, 1.35, 0)), Color = P.FOUNTAIN_BLUE, Parent = plot })
	prompt(trough, "Feed", "Creature Pen", { Action = "Feed" }, 0.5, 10)

	-- Treadmill
	local treadCf = at(PlotLayout.treadmill)
	part({ Name = "TreadmillBase", Size = Vector3.new(4, 1, 8), CFrame = treadCf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(60, 56, 70), Parent = plot })
	decor({ Name = "TreadmillBelt", Size = Vector3.new(3.2, 0.2, 7.4), CFrame = treadCf * CFrame.new(0, 1.05, 0), Color = Color3.fromRGB(30, 30, 36), Parent = plot })
	local rail = part({ Name = "TreadmillRail", Size = Vector3.new(4, 0.4, 0.4), CFrame = treadCf * CFrame.new(0, 4, -3.6), Color = P.STONE, Parent = plot })
	for _, x in ipairs({ -1.8, 1.8 }) do
		decor({ Name = "TreadmillPost", Size = Vector3.new(0.3, 3, 0.3), CFrame = treadCf * CFrame.new(x, 2.5, -3.6), Color = P.STONE, Parent = plot })
	end
	prompt(rail, "Treadmill", "Treadmill (WalkSpeed)", { Panel = "BASE", Zone = "treadmill" }, 0, 10)

	-- Nest Vault: sunken stone vault with porthole windows
	local vault = PlotLayout.vault
	local vaultCf = at(vault.pos)
	part({ Name = "VaultBody", Size = vault.size, CFrame = vaultCf * CFrame.new(0, vault.size.Y / 2 - 1, 0), Color = P.COBBLE, Material = Enum.Material.Cobblestone, Parent = plot })
	decor({ Name = "VaultCap", Size = vault.size + Vector3.new(1, -vault.size.Y + 0.8, 1), CFrame = vaultCf * CFrame.new(0, vault.size.Y - 0.6, 0), Color = P.SNOW_CAP, Parent = plot })
	for _, x in ipairs({ -3.5, 3.5 }) do
		local ring = vaultCf * CFrame.new(x, 3.6, -vault.size.Z / 2 - 0.1) * CFrame.Angles(0, math.rad(90), 0)
		decor({ Name = "Porthole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3, 3), CFrame = ring, Color = P.GOLD, Parent = plot })
		decor({ Name = "PortholeGlass", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 2.3, 2.3), CFrame = ring, Color = Color3.fromRGB(80, 170, 230), Material = Enum.Material.Neon, Transparency = 0.3, Parent = plot })
	end
	local vaultDoor = part({ Name = "VaultDoor", Size = Vector3.new(4, 5, 0.6), CFrame = vaultCf * CFrame.new(0, 1.5, -vault.size.Z / 2 - 0.3), Color = Color3.fromRGB(70, 66, 86), Parent = plot })
	prompt(vaultDoor, "View", "Nest Vault", { Panel = "BASE", Zone = "vault" }, 0, 10)
	neonSign(plot, vaultCf * CFrame.new(0, vault.size.Y + 1, -vault.size.Z / 2), 10, 1.6, "NEST VAULT")

	-- Visitor Deck: plank pier deck with rope posts and the guestbook
	local deck = PlotLayout.deck
	local deckCf = at(deck.pos)
	part({ Name = "VisitorDeck", Size = Vector3.new(deck.size.X, 1, deck.size.Z), CFrame = deckCf * CFrame.new(0, 0.5, 0), Color = P.PLANK, Material = Enum.Material.WoodPlanks, Parent = plot })
	for _, x in ipairs({ -deck.size.X / 2, 0, deck.size.X / 2 }) do
		decor({ Name = "DeckPost", Size = Vector3.new(0.9, 3.4, 0.9), CFrame = deckCf * CFrame.new(x, 2.2, deck.size.Z / 2), Color = P.POST, Parent = plot })
	end
	local guest = part({ Name = "Guestbook", Size = Vector3.new(7, 4.6, 0.5), CFrame = deckCf * CFrame.new(-6, 3.6, deck.size.Z / 2 - 1.5), Color = SIGN_DARK, Parent = plot })
	surfaceText(guest, "GUESTBOOK", Color3.fromRGB(255, 236, 200)).Name = "GuestText"
	prompt(guest, "View", "Visitor Deck", { Panel = "BASE", Zone = "deck" }, 0, 10)

	-- Showcase Plinth: the owner's best creature, admired by visitors
	local plinthCf = at(PlotLayout.plinth)
	part({ Name = "PlinthBase", Size = Vector3.new(6, 1, 6), CFrame = plinthCf * CFrame.new(0, 0.5, 0), Color = P.STONE, Parent = plot })
	local plinth = part({ Name = "Plinth", Size = Vector3.new(4, 3, 4), CFrame = plinthCf * CFrame.new(0, 2.5, 0), Color = P.TAN, Parent = plot })
	decor({ Name = "PlinthRim", Size = Vector3.new(4.4, 0.5, 4.4), CFrame = plinthCf * CFrame.new(0, 4.1, 0), Color = P.GOLD, Parent = plot })
	prompt(plinth, "Admire", "Showcase Plinth", { Action = "Admire" }, 0.5, 10)

	for _, corner in ipairs({ Vector3.new(-50, 0, -52), Vector3.new(50, 0, -52), Vector3.new(-46, 0, -28), Vector3.new(28, 0, -52) }) do
		K.voxelTree(plot, at(corner).Position, rng, 1.1)
	end
	for _ = 1, 8 do
		K.flowerTuft(plot, at(Vector3.new(rng:NextNumber(-44, 44), 0, rng:NextNumber(-44, -20))).Position, rng)
	end

	local display = Instance.new("Folder")
	display.Name = "Display"
	display.Parent = plot
	return plot
end

local function buildPlots(root)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = root
	local radius = Config.Harbor.plotInner + Config.Harbor.plotSize / 2
	for i = 1, Config.Base.plotCount do
		local center = onRing(22.5 + (i - 1) * 45, radius)
		buildPlot(plots, i, CFrame.lookAt(center, HUB))
	end
	return plots
end

function ExpansionBuilder.build(world)
	local existing = world:FindFirstChild("Delta")
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Delta"
	root:SetAttribute("Version", VERSION)
	buildNestAdditions(root)
	buildHarbor(root)
	buildPlots(root)
	root.Parent = world
	return root
end

return ExpansionBuilder
