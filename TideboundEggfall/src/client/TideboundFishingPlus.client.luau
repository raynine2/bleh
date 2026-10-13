-- Tidebound: Eggfall: Fishing Overhaul screen (12 Oct 2026), copied from the Fisch "Best Money Spots" video.
--   * Roaming rare fish: glowing fish swimming near the spots, with their name in their tier's colour.
--   * Surge readout on the left, like the video's "Disturbance: +0 (+1)" lines, plus your total "Caught".
--   * MAX cast: a power bar over your head while the line flies; click at the top for a white "MAX!".
--   * The luck sum for every cast (Rod x Bait x Night x Surge).
--   * Run summary after extraction: huge green Pearls and Pearls per minute, the video's money-per-hour text.
-- The server decides everything (FishingPlusService); this only draws it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local FP = require(Shared:WaitForChild("FishingPlus"))
local Remotes = Shared:WaitForChild("Remotes")
local FishingEvent = Remotes:WaitForChild("Fishing")
local CueEvent = Remotes:WaitForChild("Cue")
local state = Shared:WaitForChild("FishingPlusState")

local player = Players.LocalPlayer
local GREEN = Color3.fromRGB(60, 255, 60) -- the video's money green
local WHITE = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "TideboundFishingPlus"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function new(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
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

local function stroke(thickness, color)
	return new("UIStroke", { Thickness = thickness, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne -- HUD restyle (12 Oct 2026): the side buttons' font
	props.TextColor3 = props.TextColor3 or WHITE
	local thickness = props.Stroke or 2
	props.Stroke = nil
	return new("TextLabel", props, { stroke(thickness) })
end

local function pop(inst, from)
	local s = inst:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = inst })
	s.Scale = from or 1.4
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function commas(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

local function tierColor(tier)
	local t = Config.Tiers[tier]
	return t and t.color or WHITE
end

-- Which biome you're in: Kelp Cathedral is everything below Config.Kelp.belowY.
local function currentBiome()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and Config.Kelp and root.Position.Y < Config.Kelp.belowY then
		return 2
	end
	return 1
end

-- 1. Roaming rare fish ---------------------------------------------------------------------------------------

local roamFolder = workspace:WaitForChild("TideboundRoamers")
local drawn = {} -- [anchor Part] = { model, gui }

local function drawRoamer(anchor)
	if drawn[anchor] then
		return
	end
	local tier = anchor:GetAttribute("Tier") or 3
	local color = tierColor(tier)
	local scale = 1 + (tier - 3) * 0.35
	local model = new("Model", { Name = "RoamerFish" })
	local function bit(size, offset, shape, transparency)
		return new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = shape or Enum.PartType.Ball, Size = size * scale, Material = Enum.Material.Neon, Color = color, Transparency = transparency or 0.25, Parent = model }), offset * scale
	end
	local body, bodyOff = bit(Vector3.new(1.6, 1.4, 4), Vector3.zero)
	local tail, tailOff = bit(Vector3.new(0.3, 1.6, 1.4), Vector3.new(0, 0, 2.4), Enum.PartType.Block, 0.35)
	-- 12 Oct 2026 FX remake: the black disc under it is hidden (HJHJH didn't like the circles on the water)
	local shadow, shadowOff = bit(Vector3.new(0.2, 6, 6), Vector3.new(0, 0.7, 0), Enum.PartType.Cylinder, 1)
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Material = Enum.Material.SmoothPlastic
	model.PrimaryPart = body
	model.Parent = workspace.CurrentCamera
	local tag = new("BillboardGui", { Size = UDim2.new(0, 200, 0, 46), StudsOffset = Vector3.new(0, 3.5 * scale, 0), AlwaysOnTop = true, MaxDistance = 140, Adornee = body, Parent = gui })
	text({ Size = UDim2.new(1, 0, 0.6, 0), Text = (tier >= 5 and "! " or "") .. (anchor:GetAttribute("Fish") or "Fish") .. (tier >= 5 and " !" or ""), TextScaled = true, TextColor3 = color, Parent = tag })
	text({ Position = UDim2.new(0, 0, 0.6, 0), Size = UDim2.new(1, 0, 0.4, 0), Text = (Config.Tiers[tier] and Config.Tiers[tier].id or "") .. " • cast here", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = WHITE, Stroke = 1.5, Parent = tag })
	drawn[anchor] = { model = model, gui = tag, parts = { { body, bodyOff }, { tail, tailOff }, { shadow, shadowOff } }, seed = math.random() * 10 }
end

local function undraw(anchor)
	local d = drawn[anchor]
	if d then
		d.model:Destroy()
		d.gui:Destroy()
		drawn[anchor] = nil
	end
end

for _, a in ipairs(roamFolder:GetChildren()) do
	drawRoamer(a)
end
roamFolder.ChildAdded:Connect(function(a)
	task.wait()
	drawRoamer(a)
end)
roamFolder.ChildRemoved:Connect(undraw)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for anchor, d in pairs(drawn) do
		if not anchor.Parent then
			undraw(anchor)
		else
			-- swim: wiggle the tail and bob just under the surface
			local base = anchor.CFrame * CFrame.new(0, math.sin(t * 2 + d.seed) * 0.25, 0)
			local wiggle = CFrame.Angles(0, math.sin(t * 8 + d.seed) * 0.35, 0)
			for i, entry in ipairs(d.parts) do
				local part, off = entry[1], entry[2]
				if i == 2 then
					part.CFrame = base * CFrame.new(off) * wiggle
				elseif i == 3 then
					part.CFrame = CFrame.new(base.Position + off) * CFrame.Angles(0, 0, math.rad(90))
				else
					part.CFrame = base * CFrame.new(off) * CFrame.Angles(0, math.sin(t * 8 + d.seed) * 0.08, 0)
				end
			end
		end
	end
end)

-- 2. Surge readout and "Caught" (top left, like the video's Disturbance lines) --------------------------------

-- HUD restyle (12 Oct 2026): a blue tile box like the side buttons (gradient, light outline, rounded corners)
local readout = new("Frame", { Name = "SurgeReadout", BackgroundColor3 = WHITE, Visible = false, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 172, 0.46, 0), Size = UDim2.new(0, 300, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UICorner", { CornerRadius = UDim.new(0, 10) }),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 140, 255), Color3.fromRGB(18, 76, 214)) }),
	new("UIStroke", { Color = Color3.fromRGB(90, 210, 255), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
})
local readoutScale = new("UIScale", { Scale = 0.75, Parent = readout }) -- small until you're inside the Surge
local surgeLine = text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = readout })
local disturbLine = text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 20), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = readout })
local caughtLine = text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = readout })
local nightLine = text({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), TextSize = 15, TextColor3 = Color3.fromRGB(170, 190, 255), TextXAlignment = Enum.TextXAlignment.Left, Parent = readout })

local lastDisturb = {}
local gainText, gainUntil = "", 0
task.spawn(function()
	while true do
		local biome = currentBiome()
		local def = FP.surgeFor(biome)
		local phase = state:GetAttribute("Phase" .. biome)
		local ends = state:GetAttribute("Ends" .. biome) or 0
		local dist = state:GetAttribute("Disturbance" .. biome) or 0
		local left = ends - workspace:GetServerTimeNow()
		if def and phase == "active" then
			surgeLine.Text = ("%s: %s left"):format(def.name, FP.clock(left))
			surgeLine.TextColor3 = def.color
			disturbLine.Text = ("Luck x%.1f inside it. Follow the tall light!"):format(FP.Surge.luck)
		elseif def and phase == "cooldown" then
			surgeLine.Text = ("%s returns in %s"):format(def.name, FP.clock(left))
			surgeLine.TextColor3 = Color3.fromRGB(200, 200, 210)
			disturbLine.Text = "Disturbance: resting"
		elseif def and phase == "building" then
			surgeLine.Text = def.name .. " is stirring..."
			surgeLine.TextColor3 = def.color
			local prev = lastDisturb[biome] or dist
			if dist > prev + 1 then
				gainText, gainUntil = (" (+%d)"):format(dist - prev), os.clock() + 2
			end
			disturbLine.Text = ("Disturbance: %d/%d%s"):format(dist, FP.Surge.disturbanceMax, os.clock() < gainUntil and gainText or "")
		else
			surgeLine.Text, disturbLine.Text = "", ""
		end
		lastDisturb[biome] = dist
		local caught = player:GetAttribute("FishCaught")
		caughtLine.Text = caught and ("Caught: " .. commas(caught)) or ""
		nightLine.Text = FP.isNight(game:GetService("Lighting").ClockTime) and ("Night: luck x%.2f, more roaming fish"):format(FP.Night.luck) or ""
		-- the box only shows the lines that have something to say. 12 Oct (user ask): it's hidden until you're inside
		-- the Surge's area, then it pops up as the full box (a small popup says when a Surge returns, see SurgeStart).
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local center = state:GetAttribute("Center" .. biome)
		local inside = phase == "active" and root ~= nil and typeof(center) == "Vector3" and center ~= Vector3.zero
			and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= FP.Surge.radius
		local anyLine = false
		for _, line in ipairs({ surgeLine, disturbLine, caughtLine, nightLine }) do
			line.Visible = line.Text ~= ""
			anyLine = anyLine or line.Visible
		end
		readout.Visible = anyLine and inside
		local want = inside and 1.1 or 0.75
		if readoutScale:GetAttribute("Want") ~= want then
			readoutScale:SetAttribute("Want", want)
			TweenService:Create(readoutScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = want }):Play()
		end
		task.wait(0.25)
	end
end)

-- 3. MAX cast and the luck sum -------------------------------------------------------------------------------

local function overhead()
	local character = player.Character
	return character and character:FindFirstChild("Head")
end

local function maxPop(word, color)
	local head = overhead()
	if not head then
		return
	end
	local bb = new("BillboardGui", { Size = UDim2.new(0, 220, 0, 70), StudsOffset = Vector3.new(0, 4.2, 0), AlwaysOnTop = true, Adornee = head, Parent = gui })
	local t = text({ Size = UDim2.fromScale(1, 1), Text = word, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = color or WHITE, Stroke = 3, Rotation = -4, Parent = bb })
	pop(t, 1.8)
	TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	task.delay(0.9, function()
		TweenService:Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.3, function()
		bb:Destroy()
	end)
end

local luckBanner = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -264), Size = UDim2.new(0.9, 0, 0, 26), TextSize = 20, Text = "", Visible = false, Parent = gui })
new("UISizeConstraint", { MaxSize = Vector2.new(720, 26), Parent = luckBanner })
local roleBanner = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -238), Size = UDim2.new(0.9, 0, 0, 20), TextSize = 15, TextColor3 = Color3.fromRGB(200, 170, 255), Text = "", Visible = false, Parent = gui })

local charging = false
local clicked = false
UserInputService.InputBegan:Connect(function(input, processed)
	if charging and not processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonR2) then
		clicked = true
	end
end)

local function runCharge(cast)
	local head = overhead()
	if not head then
		return
	end
	local C = FP.Cast
	local window = math.min(C.window, math.max(0.5, (cast.biteWait or 2) - 0.3))
	local bb = new("BillboardGui", { Size = UDim2.new(0, 24, 0, 110), StudsOffset = Vector3.new(2.6, 1.5, 0), AlwaysOnTop = true, Adornee = head, Parent = gui })
	local track = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 20, 26), BackgroundTransparency = 0.25, Parent = bb }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }), new("UIStroke", { Thickness = 2, Color = WHITE }) })
	new("Frame", { Size = UDim2.new(1, 0, 1 - C.maxZone, 0), BackgroundColor3 = Color3.fromRGB(255, 240, 120), BackgroundTransparency = 0.4, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	local fill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = WHITE, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(0, 6) }), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(240, 220, 255), Color3.fromRGB(140, 80, 255)) }) })
	local hint = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.new(0, 120, 0, 18), TextSize = 14, Text = "CLICK!", Parent = bb })
	charging, clicked = true, false
	local started = os.clock()
	local power = 0
	while os.clock() - started < window and not clicked do
		local u = ((os.clock() - started) / C.sweepSeconds) % 2
		power = u <= 1 and u or 2 - u
		fill.Size = UDim2.fromScale(1, power)
		RunService.RenderStepped:Wait()
	end
	charging = false
	hint.Text = ""
	local role = FP.role(cast.rod)
	local bonus = 0
	if power >= C.maxZone then
		bonus = role.maxBonus or C.maxBonus
		maxPop("MAX!", WHITE)
	elseif power >= 0.6 then
		bonus = C.goodBonus
		maxPop("GOOD!", Color3.fromRGB(150, 255, 170))
	end
	FP.castBonus = bonus
	task.delay(0.4, function()
		bb:Destroy()
	end)
end

FishingEvent.OnClientEvent:Connect(function(cast)
	FP.castBonus = 0
	-- Fisch video (12 Oct 2026): the luck now shows in the reel bar's Current Luck box (FischUI) and the power bar
	-- is the hold-to-cast before the throw (TideboundFischCast), so the old banners and the MAX bar are off
	do
		return
	end
	local info = cast.plus
	if info then
		local parts = {}
		for _, p in ipairs(info.parts) do
			table.insert(parts, ("%s %.2f"):format(p[1], p[2]))
		end
		luckBanner.Text = ("LUCK x%.2f  =  %s"):format(info.total or 1, table.concat(parts, " × "))
		luckBanner.TextColor3 = info.surge and (FP.surgeFor(currentBiome()) or { color = GREEN }).color or WHITE
		luckBanner.Visible = true
		pop(luckBanner, 1.2)
		roleBanner.Text = info.roamer and ("You cast on the roaming %s! It's on the line."):format(info.roamer) or ("Rod job: %s. %s"):format(info.role or "Steady", FP.role(cast.rod).text)
		roleBanner.TextColor3 = info.roamer and tierColor(info.roamerTier or 3) or Color3.fromRGB(200, 170, 255)
		roleBanner.Visible = true
		task.delay(math.max(2.5, (cast.biteWait or 2) + 0.5), function()
			luckBanner.Visible, roleBanner.Visible = false, false
		end)
	end
	if not cast.pier then
		task.spawn(runCharge, cast)
	end
end)

-- 4. Run summary (the video's huge green money numbers) ------------------------------------------------------

local function showSummary(s)
	local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })
	TweenService:Create(shade, TweenInfo.new(0.4), { BackgroundTransparency = 0.45 }):Play()
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(0.92, 0, 0, 380), BackgroundTransparency = 1, ZIndex = 51, Parent = shade }, {
		new("UISizeConstraint", { MaxSize = Vector2.new(760, 380) }),
	})
	local title = text({ Size = UDim2.new(1, 0, 0, 40), Text = "RUN SUMMARY", TextScaled = true, Font = Enum.Font.LuckiestGuy, ZIndex = 52, Stroke = 3, Parent = box })
	local big = text({ Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 0, 96), Text = "+0 PEARLS", TextScaled = true, Font = Enum.Font.LuckiestGuy, TextColor3 = GREEN, ZIndex = 52, Stroke = 5, Parent = box })
	local rate = text({ Position = UDim2.new(0, 0, 0, 142), Size = UDim2.new(1, 0, 0, 64), Text = ("%s PEARLS / MIN"):format(commas(s.perMinute)), TextScaled = true, Font = Enum.Font.LuckiestGuy, TextColor3 = GREEN, ZIndex = 52, Stroke = 4, Parent = box })
	rate.TextTransparency = 1
	local lines = {
		("Time %s   •   Fish %d (%d perfect)   •   Eggs %d   •   Run Embers %d"):format(FP.clock(s.seconds), s.fish, s.perfect, s.eggs or 0, s.embers or 0),
		s.best and ("Best catch: %s (%s)"):format(s.best, Config.Tiers[s.bestTier] and Config.Tiers[s.bestTier].id or "") or "No fish this run",
		(#s.surges > 0 and ("Surges fished: " .. table.concat(s.surges, ", ")) or "No Surge this run") .. (s.roamers > 0 and ("   •   Roaming fish hooked: " .. s.roamers) or ""),
	}
	for i, line in ipairs(lines) do
		local l = text({ Position = UDim2.new(0, 0, 0, 214 + (i - 1) * 30), Size = UDim2.new(1, 0, 0, 26), Text = line, TextScaled = true, Font = Enum.Font.GothamBlack, ZIndex = 52, Stroke = 2, Parent = box })
		l.TextTransparency = 1
		task.delay(0.9 + i * 0.15, function()
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end)
	end
	local close = text({ Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), Text = "Click to close", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), ZIndex = 52, Parent = box })
	pop(title, 1.3)
	pop(big, 1.6)
	-- count the Pearls up, like a money counter
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.8 do
			big.Text = ("+%s PEARLS"):format(commas(s.pearls * ((os.clock() - t0) / 0.8)))
			RunService.RenderStepped:Wait()
		end
		big.Text = ("+%s PEARLS"):format(commas(s.pearls))
		pop(big, 1.2)
		TweenService:Create(rate, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		pop(rate, 1.5)
	end)
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(box:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			end
		end
		task.delay(0.35, function()
			shade:Destroy()
		end)
	end
	local conn
	conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if conn then
				conn:Disconnect()
			end
			finish()
		end
	end)
	close.Text = "Click to close"
	task.delay(9, function()
		if conn then
			conn:Disconnect()
		end
		finish()
	end)
end

CueEvent.OnClientEvent:Connect(function(name, payload)
	if name == "RunSummary" and type(payload) == "table" then
		showSummary(payload)
	elseif name == "SurgeStart" and type(payload) == "table" then
		-- 12 Oct (user ask): a small popup in the buttons' blue tile style instead of the big banner
		local def = FP.surgeFor(payload.biome)
		local note = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, Parent = gui }, {
			new("UICorner", { CornerRadius = UDim.new(0, 10) }),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 140, 255), Color3.fromRGB(18, 76, 214)) }),
			new("UIStroke", { Color = Color3.fromRGB(90, 210, 255), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
		})
		local line = text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = 18, Text = (payload.name or "A Surge") .. " is back! Follow the tall light.", TextColor3 = def and def.color or GREEN, Parent = note })
		pop(note, 1.25)
		task.delay(4, function()
			TweenService:Create(note, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(line, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(note.UIStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			task.delay(0.5, function()
				note:Destroy()
			end)
		end)
	end
end)

-- Fishing Fight (12 Oct 2026): cheer a catch streak with a big word over your head ("STREAK x3!"), and say how
-- much it leans your next cast. The server counts it (FishingPlusService, FishStreak attribute).
do
	local Fx = require(Shared:WaitForChild("Fx"))
	local lastStreak = player:GetAttribute("FishStreak") or 0
	player:GetAttributeChangedSignal("FishStreak"):Connect(function()
		local count = player:GetAttribute("FishStreak") or 0
		local grew = count > lastStreak
		lastStreak = count
		if not grew or count < FP.Streak.from then
			return
		end
		task.delay(0.7, function()
			local head = player.Character and player.Character:FindFirstChild("Head")
			if not head then
				return
			end
			local hot = count >= FP.Streak.maxSteps + 1
			Fx.word(head.Position + Vector3.new(0, 3.2, 0), ("STREAK x%d!"):format(count), hot and { Color3.fromRGB(255, 150, 250), Color3.fromRGB(150, 90, 255) } or { Color3.fromRGB(255, 250, 140), Color3.fromRGB(255, 140, 40) }, hot and 1.25 or 1)
			task.delay(0.5, function()
				if head.Parent then
					Fx.word(head.Position + Vector3.new(0, 1.6, 0), ("next cast luck x%.2f"):format(FP.streakLuck(count + 1)), { Color3.fromRGB(190, 255, 200), Color3.fromRGB(80, 220, 120) }, 0.6)
				end
			end)
		end)
	end)
end
