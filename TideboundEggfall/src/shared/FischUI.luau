-- Tidebound: Eggfall: the Fisch-style fishing screens (HJHJH's video, 12 Oct 2026). Client only.
-- 1. Power cast: hold click (or touch) at a fishing spot and a slim white bar with a green tip beside you bounces up and down; let go
--    to cast. The higher it is, the better the word over your head (Perfect!, Amazing!!, Great!, Good, Okay)
--    and the faster you reel (up to +30% progress speed). It never changes Pearls or the odds.
-- 2. SHAKE (13 Oct 2026: osu! style): while you wait for the bite, numbered circles pop up with rings closing
--    in; hit each as its ring meets it. Rarer fish bring more, faster circles. Rare fish and up also fight back
--    mid-reel with a short burst of circles (TideboundClient).
-- 3. Around the reel bar: "Click & Hold Anywhere!", "+20% Progress Speed" and a Current Luck box.
-- 4. The catch: you hold the fish over your head in a burst of light, a word pops over you ("Awesome!"), and
--    lines along the bottom say what you caught, its weight and your bestiary progress, with a Pearls pop.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = script.Parent
local Config = require(Shared:WaitForChild("Config"))
local Audio = require(Shared:WaitForChild("Audio"))

local player = Players.LocalPlayer
local FischUI = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(12, 12, 16)
local DARK = Color3.fromRGB(18, 18, 22)
local GREEN = Color3.fromRGB(130, 255, 150)
local ITALIC = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local HEAVY = Font.fromEnum(Enum.Font.FredokaOne)

local function new(class, props, children)
	local inst = Instance.new(class)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function textStroke(thickness, transparency)
	return new("UIStroke", { Thickness = thickness, Color = BLACK, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function borderStroke(thickness, color, transparency)
	return new("UIStroke", { Thickness = thickness, Color = color or WHITE, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function round(radius)
	return new("UICorner", { CornerRadius = radius or UDim.new(1, 0) })
end

local function playerGui()
	return player:WaitForChild("PlayerGui")
end

local gui
local function screen()
	if gui and gui.Parent then
		return gui
	end
	gui = new("ScreenGui", { Name = "TideboundFisch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui() })
	return gui
end

local function bodyPart(name)
	local character = player.Character
	return character and character:FindFirstChild(name)
end

local function popIn(obj, from, seconds)
	local scale = obj:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = obj })
	scale.Scale = from or 0.2
	TweenService:Create(scale, TweenInfo.new(seconds or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return scale
end

-- fades every label, frame and stroke under `root` to invisible
local function fadeAll(root, seconds)
	local info = TweenInfo.new(seconds)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
end

-- 1. Power cast ---------------------------------------------------------------------------------------------

FischUI.RATINGS = {
	{ min = 0.95, word = "Perfect!", color = Color3.fromRGB(255, 220, 90), bonus = 0.3 },
	{ min = 0.8, word = "Amazing!!", color = Color3.fromRGB(120, 255, 170), bonus = 0.2 },
	{ min = 0.6, word = "Great!", color = Color3.fromRGB(110, 205, 255), bonus = 0.1 },
	{ min = 0.35, word = "Good", color = Color3.fromRGB(235, 235, 240), bonus = 0.05 },
	{ min = 0, word = "Okay", color = Color3.fromRGB(190, 190, 196), bonus = 0 },
}

function FischUI.rate(power)
	for _, rating in ipairs(FischUI.RATINGS) do
		if power >= rating.min then
			return rating
		end
	end
	return FischUI.RATINGS[#FischUI.RATINGS]
end

-- A word that pops over your head and floats away ("Amazing!!", "Awesome!").
function FischUI.word(text, color, big)
	local head = bodyPart("Head")
	if not head then
		return
	end
	local bb = new("BillboardGui", { Name = "FischWord", Size = UDim2.new(0, big and 320 or 250, 0, big and 84 or 64), StudsOffset = Vector3.new(0, big and 5.6 or 3.4, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 250, Adornee = head, Parent = playerGui() })
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextScaled = true, FontFace = HEAVY, TextColor3 = WHITE, Rotation = -3, Parent = bb }, {
		textStroke(3),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, color or WHITE) }),
	})
	popIn(label, 0.3, 0.4)
	TweenService:Create(bb, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = bb.StudsOffset + Vector3.new(0, 1.3, 0) }):Play()
	task.delay(1.35, function()
		fadeAll(bb, 0.35)
	end)
	task.delay(1.8, function()
		bb:Destroy()
	end)
end

FischUI.charging = false

-- Hold to charge. `held()` says whether the button is still down; `onPower(power)` (optional) hears the power
-- every frame. Returns the power (0 to 1) and its rating.
function FischUI.charge(held, onPower)
	-- 13 Oct 2026 (HJHJH: "make it like the second photo with green tip, cleaner, not that low quality"): a slim
	-- Fisch-style bar drawn in screen pixels (a stud-sized billboard went blurry and chunky): thin black outline,
	-- dark track and a white fill; only the very top of the bar is green (the Perfect! zone), and it lights up
	-- when the fill reaches it (HJHJH: "only the top of the bar should be green").
	local root = bodyPart("HumanoidRootPart")
	local bb, fill, perfect
	if root then
		bb = new("BillboardGui", { Name = "FischPower", Size = UDim2.fromOffset(14, 118), StudsOffset = Vector3.new(2.6, 0.9, 0), AlwaysOnTop = true, LightInfluence = 0, Adornee = root, Parent = playerGui() })
		local track = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 24, 22), BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true, Parent = bb }, {
			round(UDim.new(0, 3)),
			borderStroke(1.5, BLACK, 0),
		})
		perfect = new("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 0.06, 0), BackgroundColor3 = Color3.fromRGB(70, 220, 100), BorderSizePixel = 0, ZIndex = 4, Parent = track }, { round(UDim.new(0, 2)) })
		fill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, -2), Size = UDim2.new(1, -4, 0, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = track }, {
			round(UDim.new(0, 2)),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(214, 220, 216)) }),
		})
		popIn(track, 0.7, 0.18)
	end
	FischUI.charging = true
	local started = os.clock()
	local power = 0
	while held() and os.clock() - started < 6 do
		-- up in 0.95 s, back down in 0.95 s, like Fisch's bar
		local u = ((os.clock() - started) / 0.95) % 2
		power = u <= 1 and u or 2 - u
		if onPower then
			onPower(power)
		end
		if fill then
			-- the fill, inside a 2 px margin
			fill.Size = UDim2.new(1, -4, power, -4 * power)
			perfect.BackgroundColor3 = power >= 0.95 and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(70, 220, 100)
		end
		RunService.RenderStepped:Wait()
	end
	FischUI.charging = false
	local rating = FischUI.rate(power)
	FischUI.word(rating.word, rating.color)
	if bb then
		task.delay(0.2, function()
			bb:Destroy()
		end)
	end
	return power, rating
end

-- 2. SHAKE, osu! style (13 Oct 2026, rebuilt the same day for feel) ------------------------------------------
-- HJHJH asked for SHAKE "like an osu minigame", then for it to be "very good and smooth": when you click a
-- circle it goes away at once and tells you Perfect, Good or Bad. So, like osu!:
--  * Numbered circles fade in with an approach ring closing on each; hit the circle as the ring meets it.
--  * Timing windows follow osu!'s Overall Difficulty (300: 80 - 6 x OD ms, 100: 140 - 8 x OD, 50: 200 - 10 x OD,
--    plus 25 ms for Roblox's input delay): Perfect, Good, Bad. Past the Bad window the circle is a Miss.
--  * Approach time follows osu!'s Approach Rate (1.2 s at AR 5; faster above it, slower below).
--  * A hit pops the circle on the spot (it swells and fades in 0.18 s with a flash in the judgement's colour),
--    and the word appears where it was. A click far too early just wiggles the circle (osu!'s note lock); a
--    click on a later circle while an earlier one is overdue counts the earlier one as a Miss.
-- Rarer fish raise both numbers and add circles and bigger jumps (FischUI.chart). Each circle is a real button,
-- so Roblox itself decides what you clicked (no screen-maths); Enter, Z or the gamepad A button hit the next one.

FischUI.JUDGE = {
	{ key = "perfect", score = 300, text = "Perfect!", color = Color3.fromRGB(120, 215, 255) },
	{ key = "good", score = 100, text = "Good", color = Color3.fromRGB(130, 255, 150) },
	{ key = "bad", score = 50, text = "Bad", color = Color3.fromRGB(255, 196, 90) },
}
local MISS = { key = "miss", score = 0, text = "Miss", color = Color3.fromRGB(255, 84, 96) }
local INPUT_DELAY = 0.025

FischUI.RANKS = {
	{ id = "SS", min = 1, color = Color3.fromRGB(255, 236, 140) },
	{ id = "S", min = 0.93, color = Color3.fromRGB(255, 214, 90) },
	{ id = "A", min = 0.85, color = Color3.fromRGB(130, 255, 150) },
	{ id = "B", min = 0.75, color = Color3.fromRGB(120, 215, 255) },
	{ id = "C", min = 0.6, color = Color3.fromRGB(200, 140, 255) },
	{ id = "D", min = 0, color = Color3.fromRGB(255, 90, 100) },
}

-- osu!'s Approach Rate: how long a circle shows before its beat, and how long it takes to fade in
local function approachOf(ar)
	if ar < 5 then
		return 1.2 + 0.6 * (5 - ar) / 5, 0.8 + 0.4 * (5 - ar) / 5
	end
	return 1.2 - 0.75 * (ar - 5) / 5, 0.8 - 0.5 * (ar - 5) / 5
end

-- The chart for a fish of tier 1 (Common) to 7 (Celestial). 13 Oct 2026, HJHJH: "the osu is way too hard", so
-- it's gentle now: a Common is 3 slow circles (AR 2, rings closing in 1.56 s, OD 0: Perfect within 105 ms), a
-- Celestial 7 (AR 5, 1.2 s, OD 1.8). Big circles, small jumps, room between beats. (`short` is no longer used.)
function FischUI.chart(tier, _short)
	local t = math.clamp(math.floor(tonumber(tier) or 1), 1, 7) - 1
	local ar, od = 2 + 0.5 * t, 0.3 * t
	local approach, fadeIn = approachOf(ar)
	return {
		tier = t + 1,
		count = 3 + math.floor(t * 0.67),
		approach = approach,
		fadeIn = fadeIn * 0.6,
		windows = { (80 - 6 * od) / 1000 + INPUT_DELAY, (140 - 8 * od) / 1000 + INPUT_DELAY, (200 - 10 * od) / 1000 + INPUT_DELAY },
		spacing = 0.75 - 0.03 * t,
		size = 96 - 2 * t,
		jump = 0.1 + 0.015 * t,
	}
end

-- circle centres (screen scale) wandering around the middle of the screen, jumping further for rarer fish
local function chartPath(count, jump)
	local points = {}
	local x, y = 0.5, 0.42
	local angle = math.random() * math.pi * 2
	for i = 1, count do
		if i > 1 then
			for _ = 1, 12 do
				local a = angle + (math.random() - 0.5) * math.pi * 1.2
				local nx, ny = x + math.cos(a) * jump, y + math.sin(a) * jump * 1.25
				if nx > 0.22 and nx < 0.78 and ny > 0.2 and ny < 0.62 then
					x, y, angle = nx, ny, a
					break
				end
				angle += math.pi * 0.5
			end
		end
		points[i] = Vector2.new(x, y)
	end
	return points
end

local EASE_OUT = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Plays a chart. `color` tints the circles (the fish's tier colour), `title` sits small over them ("SHAKE"),
-- `onJudge(judge, index)` hears every hit and miss (judge.score is 300, 100, 50 or 0), and `stop()` (optional)
-- ends it early. Returns { accuracy = 0 to 1, rank = FischUI.RANKS entry, misses, maxCombo, count }.
function FischUI.osu(chart, color, title, onJudge, stop)
	local g = screen()
	local layer = new("Frame", { Name = "FischOsu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = g })
	color = color or WHITE
	local colors = { color, color:Lerp(WHITE, 0.5) }
	-- small and clean like Fisch: a title over the circles, the combo bottom-left, accuracy top-right
	local heading = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12, 0), Size = UDim2.fromOffset(260, 24), BackgroundTransparency = 1, Text = "", FontFace = ITALIC, TextSize = 18, TextColor3 = WHITE, Parent = layer }, { textStroke(1.5, 0.15) })
	local comboLabel = new("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 0.74, 0), Size = UDim2.fromOffset(120, 30), BackgroundTransparency = 1, Text = "", FontFace = HEAVY, TextSize = 24, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = layer }, { textStroke(1.8, 0.1) })
	local comboScale = new("UIScale", { Parent = comboLabel })
	local accLabel = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 64), Size = UDim2.fromOffset(120, 22), BackgroundTransparency = 1, Text = "100.00%", FontFace = HEAVY, TextSize = 17, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = layer }, { textStroke(1.5, 0.15) })

	local size = chart.size
	local windows = chart.windows
	local notes = {}
	local score = { [300] = 0, [100] = 0, [50] = 0, misses = 0, combo = 0, maxCombo = 0, points = 0, judged = 0 }
	local nextNote = 1
	local judge -- forward declaration

	local function accuracy()
		return score.judged == 0 and 1 or score.points / (300 * score.judged)
	end

	-- the moment a circle is pressed: judge it by how far off its beat the press was
	local function press(note, at)
		if note.judged or not note.shown then
			return
		end
		-- an earlier circle still waiting: if it's overdue it's a Miss and this one counts; if not, note lock
		for i = nextNote, note.index - 1 do
			local earlier = notes[i]
			if not earlier.judged then
				if at > earlier.hit then
					judge(earlier, MISS, at)
				else
					note.wiggle = at
					return
				end
			end
		end
		local offset = at - note.hit
		if offset < -windows[3] then
			note.wiggle = at -- far too early: it wiggles and nothing counts
			return
		end
		local result = MISS
		for i, judgement in ipairs(FischUI.JUDGE) do
			if math.abs(offset) <= windows[i] then
				result = judgement
				break
			end
		end
		judge(note, result, at)
	end

	-- Build every circle up front (hidden), so nothing is made mid-chart and the frames stay smooth.
	local start = os.clock() + 0.2
	for i, at in ipairs(chartPath(chart.count, chart.jump)) do
		local note = { index = i, at = at, hit = start + chart.approach + (i - 1) * chart.spacing, number = (i - 1) % 4 + 1 }
		local tint = colors[math.floor((i - 1) / 4) % 2 + 1]
		-- the circle is one button the size of the circle; Roblox tells us when it's pressed
		local button = new("TextButton", { Name = "Circle" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at.X, at.Y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 100 - i, Parent = layer })
		-- the body fades and pops as one piece (a CanvasGroup), with room around it for its white rim
		local group = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.12, 1.12), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 2, Parent = button })
		local groupScale = new("UIScale", { Parent = group })
		-- 13 Oct 2026: Fisch-simple: a dark glass disc with a thin white rim and a white number, a thin white ring
		-- closing in, and only a hint of the fish's colour in the rim's glow
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86), BackgroundColor3 = DARK, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = group }, {
			round(),
			new("UIStroke", { Thickness = 2.5, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.74, 0.74), BackgroundTransparency = 1, Parent = group }, {
			round(),
			new("UIStroke", { Thickness = 1.5, Color = tint, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = tostring(note.number), FontFace = HEAVY, TextSize = math.floor(size * 0.36), TextColor3 = WHITE, Parent = group })
		-- the approach ring closing in
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(3.2, 3.2), BackgroundTransparency = 1, ZIndex = 3, Parent = button }, {
			round(),
			new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		note.button, note.group, note.groupScale, note.ring = button, group, groupScale, ring
		note.ringStroke = ring:FindFirstChildOfClass("UIStroke")
		note.tint = tint
		notes[i] = note
	end

	-- follow points: a dotted trail from each circle to the next, faded in with the next one
	local function follow(note)
		local prev = notes[note.index - 1]
		if not prev or prev.judged then
			return
		end
		local px = layer.AbsoluteSize
		local a = Vector2.new(prev.at.X * px.X, prev.at.Y * px.Y)
		local b = Vector2.new(note.at.X * px.X, note.at.Y * px.Y)
		local length = (b - a).Magnitude
		if length <= size + 24 then
			return
		end
		local unit = (b - a).Unit
		local dots = new("CanvasGroup", { Name = "Follow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 1, Parent = layer })
		for d = size / 2 + 12, length - size / 2 - 12, 20 do
			local p = a + unit * d
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = dots }, { round() })
		end
		TweenService:Create(dots, TweenInfo.new(0.25), { GroupTransparency = 0.2 }):Play()
		prev.follow = dots
	end

	-- the word where the circle was: Perfect!, Good, Bad or Miss, popping in and floating up
	local function popWord(note, result)
		local label = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(note.at.X, note.at.Y), Size = UDim2.fromOffset(110, 26), BackgroundTransparency = 1, Text = result.text, FontFace = HEAVY, TextSize = 21, TextColor3 = result.color, ZIndex = 200, Parent = layer }, { textStroke(2, 0.1) })
		local scale = new("UIScale", { Scale = 0.55, Parent = label })
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(note.at.X, 0, note.at.Y, result.score > 0 and -24 or 14) }):Play()
		task.delay(0.42, function()
			TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			TweenService:Create(label:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end)
		task.delay(0.7, function()
			label:Destroy()
		end)
	end

	function judge(note, result, at)
		if note.judged then
			return
		end
		note.judged = true
		while notes[nextNote] and notes[nextNote].judged do
			nextNote += 1
		end
		score.judged += 1
		score.points += result.score
		local hit = result.score > 0
		if hit then
			score[result.score] += 1
			score.combo += 1
			score.maxCombo = math.max(score.maxCombo, score.combo)
			pcall(Audio.play, "FishPop", nil, 1.05 + math.min(score.combo, 12) * 0.035)
			comboScale.Scale = 1.25
			TweenService:Create(comboScale, EASE_OUT, { Scale = 1 }):Play()
		else
			score.misses += 1
			score.combo = 0
		end
		comboLabel.Text = score.combo > 1 and (score.combo .. "x") or ""
		accLabel.Text = ("%.2f%%"):format(accuracy() * 100)

		-- the circle goes away at once
		local button = note.button
		button.Active = false
		note.ring.Visible = false
		if note.follow then
			local dots = note.follow
			note.follow = nil
			TweenService:Create(dots, TweenInfo.new(0.15), { GroupTransparency = 1 }):Play()
			task.delay(0.2, function()
				dots:Destroy()
			end)
		end
		if hit then
			-- osu!'s hit burst: it swells and fades, with a flash ring in the judgement's colour
			note.group.GroupTransparency = 0
			TweenService:Create(note.groupScale, EASE_OUT, { Scale = 1.45 }):Play()
			TweenService:Create(note.group, EASE_OUT, { GroupTransparency = 1 }):Play()
			local flash = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = button }, {
				round(),
				new("UIStroke", { Thickness = 3, Color = result.color:Lerp(WHITE, 0.4), Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
			TweenService:Create(flash, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.9, 1.9) }):Play()
			TweenService:Create(flash:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.28), { Transparency = 1, Thickness = 1 }):Play()
		else
			-- a miss sinks a little and fades out red
			local body = note.group:FindFirstChildOfClass("Frame")
			if body then
				TweenService:Create(body, TweenInfo.new(0.12), { BackgroundColor3 = MISS.color }):Play()
			end
			TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(note.at.X, 0, note.at.Y, 10) }):Play()
			TweenService:Create(note.group, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
		end
		task.delay(0.35, function()
			button:Destroy()
		end)
		popWord(note, result)
		if onJudge then
			task.spawn(pcall, onJudge, result, note.index)
		end
	end

	-- 13 Oct 2026 (HJHJH: "sometimes the osu minigame just says missed on everything"): clicks used to reach a
	-- circle only through its own button, which never fires when the mouse is locked to the middle of the screen
	-- (shift lock, first person, or holding right click to turn the camera) or when another screen layer sits on
	-- top, so every circle timed out as a Miss. Now every click or tap anywhere is checked against the circles
	-- ourselves, and the mouse is kept free and visible while the chart runs.
	local GuiService = game:GetService("GuiService")
	local function pointerOf(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			return UserInputService:GetMouseLocation() -- full-screen pixels, like this IgnoreGuiInset screen
		end
		return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	end
	local function noteAt(point)
		local reach = size * 0.62
		for i = nextNote, #notes do
			local note = notes[i]
			if note.shown and not note.judged and note.button.Parent then
				local centre = note.button.AbsolutePosition + note.button.AbsoluteSize / 2
				if (centre - point).Magnitude <= reach then
					return note
				end
			end
		end
		return nil
	end
	local keys = UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			local note = noteAt(pointerOf(input))
			if note then
				press(note, os.clock())
			end
			return
		end
		-- Enter, Z or the gamepad A button hit the next circle wherever it is
		local code = input.KeyCode
		if code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter or code == Enum.KeyCode.Z or code == Enum.KeyCode.ButtonA then
			local note = notes[nextNote]
			if note then
				press(note, os.clock())
			end
		end
	end)
	local iconWas = UserInputService.MouseIconEnabled
	local freeMouse = "TideboundOsuMouse" .. tostring(os.clock())
	RunService:BindToRenderStep(freeMouse, Enum.RenderPriority.Last.Value, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)

	local late = windows[3]
	while nextNote <= #notes and not (stop and stop()) do
		local now = os.clock()
		for i = nextNote, #notes do
			local note = notes[i]
			local appear = note.hit - chart.approach
			if now < appear then
				break
			end
			if not note.judged then
				if not note.shown then
					note.shown = true
					note.button.Visible = true
					follow(note)
				end
				local u = now - appear
				-- fade in over osu!'s fade-in time; the ring shrinks from 3.2x to the circle's edge on the beat
				local fade = math.clamp(u / chart.fadeIn, 0, 1)
				note.group.GroupTransparency = 1 - fade
				note.ringStroke.Transparency = 1 - 0.9 * fade
				local k = math.clamp(u / chart.approach, 0, 1)
				local ringScale = 1 + 2.2 * (1 - k)
				note.ring.Size = UDim2.fromScale(ringScale, ringScale)
				if note.wiggle then
					local w = now - note.wiggle
					note.button.Position = UDim2.new(note.at.X, w < 0.15 and math.sin(w * 90) * 5 * (1 - w / 0.15) or 0, note.at.Y, 0)
					if w >= 0.15 then
						note.wiggle = nil
					end
				end
				if now > note.hit + late then
					judge(note, MISS, now)
				end
			end
		end
		RunService.RenderStepped:Wait()
	end
	keys:Disconnect()
	RunService:UnbindFromRenderStep(freeMouse)
	UserInputService.MouseIconEnabled = iconWas

	local acc = accuracy()
	local rank = FischUI.RANKS[#FischUI.RANKS]
	for _, r in ipairs(FischUI.RANKS) do
		if acc >= r.min and (r.min < 0.93 or score.misses == 0) then
			rank = r
			break
		end
	end
	-- the rank, small, where the title was
	task.wait(0.15)
	local RANK_WORDS = { SS = "PERFECT SHAKE!", S = "Amazing!", A = "Great!", B = "Good", C = "Okay", D = "Missed..." }
	heading.Text = RANK_WORDS[rank.id] or rank.id
	heading.TextColor3 = rank.color
	heading.TextSize = 21
	popIn(heading, 0.6, 0.25)
	task.delay(0.9, function()
		fadeAll(layer, 0.3)
	end)
	task.delay(1.25, function()
		layer:Destroy()
	end)
	return { accuracy = acc, rank = rank, misses = score.misses, maxCombo = score.maxCombo, count = #notes }
end

-- 3. Around the reel bar ----------------------------------------------------------------------------------

local extras = nil

-- `frame` is the reel bar's frame (TideboundClient's fishFrame); `bonus` the cast's progress-speed bonus
-- (0.2 = +20%); `luck` the cast's total luck, or nil to hide the box.
function FischUI.reelShow(frame, bonus, luck, roamer)
	if not extras or extras.hint.Parent ~= frame then
		extras = {}
		extras.hint = new("TextLabel", { Name = "FischHint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 340, 0, 22), BackgroundTransparency = 1, Text = "Click & Hold Anywhere!", FontFace = ITALIC, TextSize = 18, TextColor3 = WHITE, Parent = frame }, { textStroke(1.6, 0.15) })
		extras.speed = new("TextLabel", { Name = "FischSpeed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 63), Size = UDim2.new(0, 340, 0, 20), BackgroundTransparency = 1, Text = "", FontFace = ITALIC, TextSize = 16, TextColor3 = GREEN, Parent = frame }, { textStroke(1.5, 0.15) })
		extras.luck = new("Frame", { Name = "FischLuck", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 4, 0, 22), Size = UDim2.fromOffset(138, 46), BackgroundColor3 = DARK, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = frame }, { round(UDim.new(0, 6)), borderStroke(1.5, WHITE, 0.55) })
		extras.luckTitle = new("TextLabel", { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "Current Luck:", FontFace = ITALIC, TextSize = 13, TextColor3 = Color3.fromRGB(205, 205, 212), Parent = extras.luck }, { textStroke(1, 0.4) })
		extras.luckValue = new("TextLabel", { Position = UDim2.new(0, 0, 0, 19), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "x1", FontFace = HEAVY, TextSize = 22, TextColor3 = GREEN, Parent = extras.luck }, { textStroke(1.5, 0.2) })
	end
	extras.hint.Text = roamer and ("Roaming " .. roamer .. "! Click & Hold Anywhere!") or "Click & Hold Anywhere!"
	extras.hint.Visible = true
	local pct = math.floor((bonus or 0) * 100 + 0.5)
	extras.speed.Text = pct > 0 and ("+%d%% Progress Speed"):format(pct) or ""
	extras.speed.Visible = pct > 0
	extras.luck.Visible = luck ~= nil
	if luck then
		extras.luckValue.Text = ("x%s"):format(("%.2f"):format(luck):gsub("%.?0+$", ""))
	end
	popIn(extras.hint, 0.5, 0.3)
end

function FischUI.reelHide()
	if extras then
		extras.hint.Visible, extras.speed.Visible, extras.luck.Visible = false, false, false
	end
end

-- 4. The catch ---------------------------------------------------------------------------------------------

local TIER_WORDS = { "Nice!", "Great!", "Awesome!", "Amazing!", "Incredible!", "UNREAL!!", "CELESTIAL!!" }

-- light rays turning behind the fish over your head, in the tier's colour
local function rays(color, tierIndex, seconds)
	local head = bodyPart("Head")
	if not head then
		return
	end
	local size = 7 + tierIndex * 0.6
	local bb = new("BillboardGui", { Name = "FischRays", Size = UDim2.new(size, 0, size, 0), StudsOffset = Vector3.new(0, 2.3, -1.6), AlwaysOnTop = false, LightInfluence = 0, Brightness = 1.6, Adornee = head, Parent = playerGui() })
	local spin = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	local tint = color:Lerp(WHITE, 0.45)
	local fadeOut = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.32, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(0.68, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 1, 8 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(i % 2 == 0 and 0.07 or 0.04, 1), Rotation = (i - 1) * 22.5, BackgroundColor3 = tint, BorderSizePixel = 0, Parent = spin }, {
			new("UIGradient", { Rotation = 90, Transparency = fadeOut }),
		})
	end
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = tint, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = bb }, {
		round(),
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.9) }) }),
	})
	local sparkle = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), BackgroundTransparency = 1, Image = "rbxasset://textures/particles/sparkles_main.dds", ImageColor3 = WHITE, ImageTransparency = 0.2, Parent = bb })
	local scale = popIn(spin, 0.1, 0.45)
	local started = os.clock()
	local loop
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		spin.Rotation = t * 28
		sparkle.Rotation = -t * 50
		sparkle.Size = UDim2.fromScale(0.55 + 0.08 * math.sin(t * 6), 0.55 + 0.08 * math.sin(t * 6))
		if t > seconds then
			loop:Disconnect()
			bb:Destroy()
		end
	end)
	task.delay(seconds - 0.35, function()
		if bb.Parent then
			fadeAll(bb, 0.3)
			TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 1.2 }):Play()
		end
	end)
end

local function article(word)
	return word:sub(1, 1):match("[AEIOUaeiou]") and "an" or "a"
end

-- The Fisch catch. Call it as the fish flies out of the water; it returns about 3.3 s later, when you're free
-- to move again (the lines along the bottom fade a moment after).
function FischUI.catch(result)
	local g = screen()
	local tierIndex = math.clamp(tonumber(result.tier) or 1, 1, #Config.Tiers)
	local tier = Config.Tiers[tierIndex]
	local color = tier.color
	task.wait(0.95) -- the flip: the fish arcs out and lands in your raised hands
	rays(color, tierIndex, 2.4)
	FischUI.word(TIER_WORDS[tierIndex] or "Nice!", color, tierIndex >= 6)
	pcall(Audio.play, "Tier" .. tostring(tier.id))
	if tierIndex >= 5 then
		task.delay(0.25, pcall, Audio.play, "Celebrate")
	end

	-- the lines along the bottom
	local box = new("Frame", { Name = "FischCatch", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -176), Size = UDim2.new(0.92, 0, 0, 90), BackgroundTransparency = 1, Parent = g }, {
		new("UISizeConstraint", { MaxSize = Vector2.new(900, 90) }),
		new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
	})
	local name = result.fish or "fish"
	if result.mutation and result.mutation ~= "None" then
		name = result.mutation .. " " .. name
	end
	local count = (tonumber(result.of) or 0) > 0 and (" (%d/%d)"):format(result.found or 0, result.of) or ""
	local line1 = ("You just caught %s <font color=\"#%s\">%s</font> at %.1fkg!%s"):format(article(name), color:ToHex(), name, tonumber(result.weight) or 0, count)
	local lines = { { line1, WHITE, 25 } }
	if result.isNew then
		table.insert(lines, { "Bestiary: New Fish Discovered!", Color3.fromRGB(255, 220, 90), 21 })
	elseif result.heaviest then
		table.insert(lines, { "Bestiary: New Highest Weight!", Color3.fromRGB(255, 220, 90), 21 })
	else
		table.insert(lines, { ("%s %s"):format(tier.id, string.rep("★", tierIndex)), color, 19 })
	end
	if result.extra and result.extra ~= "" then
		table.insert(lines, { result.extra, Color3.fromRGB(215, 215, 225), 15 })
	end
	for i, spec in ipairs(lines) do
		local label = new("TextLabel", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, spec[3] + 6), BackgroundTransparency = 1, RichText = true, Text = spec[1], FontFace = ITALIC, TextSize = spec[3], TextColor3 = spec[2], TextTransparency = 1, Parent = box }, { textStroke(2, 1) })
		task.delay(0.08 * (i - 1), function()
			TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
			TweenService:Create(label:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.25), { Transparency = 0.1 }):Play()
		end)
	end
	popIn(box, 0.85, 0.3)

	-- the Pearls pop, floating up beside the middle of the screen
	if tonumber(result.pearls) and result.pearls > 0 then
		local pop = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 170, 0.56, 0), Size = UDim2.fromOffset(240, 46), BackgroundTransparency = 1, Text = ("+%d Pearls"):format(result.pearls), FontFace = HEAVY, TextSize = 34, TextColor3 = GREEN, Rotation = 4, Parent = g }, { textStroke(2.5) })
		popIn(pop, 0.3, 0.35)
		TweenService:Create(pop, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 170, 0.47, 0) }):Play()
		task.delay(1.3, function()
			TweenService:Create(pop, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(pop:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		task.delay(1.9, function()
			pop:Destroy()
		end)
	end
	task.delay(3.6, function()
		fadeAll(box, 0.5)
	end)
	task.delay(4.2, function()
		box:Destroy()
	end)
	task.wait(2.35)
end

return FischUI
