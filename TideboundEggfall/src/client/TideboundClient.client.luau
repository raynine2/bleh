-- Tidebound: Eggfall client: HUD, heat meter, fishing minigame, zone lighting, and the menu.
-- Menu style follows refs/REF 4: black panel with a red neon outline and diagonal stripes, a slanted red
-- banner with a sparkle star, six striped tab bars, and square trophy tiles (red locked, gold and blue unlocked).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Remotes = Shared:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("Request")
local StateEvent = Remotes:WaitForChild("State")
local NotifyEvent = Remotes:WaitForChild("Notify")
local FishingEvent = Remotes:WaitForChild("Fishing")
local HazardEvent = Remotes:WaitForChild("Hazard")
local CueEvent = Remotes:WaitForChild("Cue")
local Animations = require(Shared:WaitForChild("Animations"))

local DISPLAY = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold
local WHITE = Color3.new(1, 1, 1)
local C = {
	neon = Color3.fromRGB(255, 42, 62),
	panel = Color3.fromRGB(16, 4, 8),
	row = Color3.fromRGB(40, 8, 14),
	ink = Color3.fromRGB(26, 4, 10),
	text = WHITE,
	muted = Color3.fromRGB(226, 196, 200),
	good = Color3.fromRGB(120, 240, 150),
	bad = Color3.fromRGB(255, 90, 90),
	warn = Color3.fromRGB(255, 200, 70),
	gold = Color3.fromRGB(255, 206, 60),
	blue = Color3.fromRGB(70, 180, 255),
}

-- Tile styles from REF 4: gradient top/bottom, outline, trophy colour.
local TILE = {
	red = { top = Color3.fromRGB(240, 52, 60), bottom = Color3.fromRGB(184, 20, 32), outline = Color3.fromRGB(255, 70, 80), trophy = Color3.fromRGB(150, 14, 26) },
	gold = { top = Color3.fromRGB(255, 196, 30), bottom = Color3.fromRGB(214, 132, 8), outline = Color3.fromRGB(255, 226, 90), trophy = Color3.fromRGB(255, 222, 80) },
	blue = { top = Color3.fromRGB(40, 140, 255), bottom = Color3.fromRGB(18, 76, 214), outline = Color3.fromRGB(90, 210, 255), trophy = Color3.fromRGB(110, 190, 255) },
	grey = { top = Color3.fromRGB(92, 92, 96), bottom = Color3.fromRGB(58, 58, 62), outline = Color3.fromRGB(134, 134, 140), trophy = Color3.fromRGB(70, 70, 74) },
}

local state = nil

-- UI helpers ---------------------------------------------------------------------

local function new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", { Color = color or C.neon, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(thickness)
	return new("UIStroke", { Color = C.ink, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function gloss(top, bottom)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) })
end

local function padding(px)
	return new("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end

local function list(gap, horizontal)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
	})
end

-- Soft neon glow: a transparent frame just outside `frame` whose thick stroke fades out.
local function halo(frame, color, radius)
	return new("Frame", { Name = "Halo", BackgroundTransparency = 1, Size = UDim2.new(1, 8, 1, 8), Position = UDim2.new(0, -4, 0, -4), ZIndex = 0, Parent = frame }, {
		corner((radius or 8) + 4),
		stroke(color, 5, 0.72),
	})
end

-- Diagonal stripe texture, clipped to `parent` by a CanvasGroup.
local function stripes(parent, spacing, width, transparency, radius)
	local group = new("CanvasGroup", { Name = "Stripes", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = transparency, ZIndex = 0, Parent = parent }, { corner(radius or 8) })
	for i = -6, 60 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, i * spacing, 0.5, 0), Size = UDim2.new(0, width, 4, 0), Rotation = 35, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = group })
	end
	return group
end

local function label(props, children)
	local defaults = { BackgroundTransparency = 1, Font = BODY, TextColor3 = C.text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local l = new("TextLabel", defaults, children)
	if defaults.Font == DISPLAY then
		textStroke(defaults.TextSize >= 22 and 3 or 2).Parent = l
	end
	return l
end

-- Trophy icon built from frames so it can take any colour (REF 4 tiles).
local function trophy(parent, color, starColor)
	local box = new("Frame", { Name = "Trophy", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72), BackgroundTransparency = 1, Parent = parent })
	new("Frame", { Size = UDim2.fromScale(0.66, 0.08), Position = UDim2.fromScale(0.17, 0.04), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box }, { corner(3) })
	new("Frame", { Size = UDim2.fromScale(0.56, 0.46), Position = UDim2.fromScale(0.22, 0.06), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box }, { new("UICorner", { CornerRadius = UDim.new(0.45, 0) }) })
	for _, x in ipairs({ 0.05, 0.71 }) do
		new("Frame", { Size = UDim2.fromScale(0.24, 0.26), Position = UDim2.fromScale(x, 0.1), BackgroundTransparency = 1, Parent = box }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), stroke(color, 4) })
	end
	new("Frame", { Size = UDim2.fromScale(0.12, 0.18), Position = UDim2.fromScale(0.44, 0.5), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box })
	new("Frame", { Size = UDim2.fromScale(0.42, 0.08), Position = UDim2.fromScale(0.29, 0.66), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box }, { corner(2) })
	new("Frame", { Size = UDim2.fromScale(0.56, 0.11), Position = UDim2.fromScale(0.22, 0.75), BackgroundColor3 = color, BorderSizePixel = 0, Parent = box }, { corner(3) })
	label({ Text = "★", TextScaled = true, TextColor3 = starColor or color:Lerp(Color3.new(0, 0, 0), 0.25), Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.35, 0.13), TextXAlignment = Enum.TextXAlignment.Center, Parent = box })
	return box
end

-- Square REF 4 tile: gradient, bevel highlight, diagonal sheen, outline, trophy.
local function tile(parent, style, order)
	local s = TILE[style]
	local frame = new("Frame", { Name = "Tile", BackgroundColor3 = WHITE, LayoutOrder = order or 0, Parent = parent }, { corner(10), gloss(s.top, s.bottom) })
	local outline = stroke(s.outline, 2.5)
	outline.Parent = frame
	new("Frame", { Name = "Bevel", BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(1, -8, 0.4, 0), BorderSizePixel = 0, Parent = frame }, {
		corner(8),
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
	})
	local sheen = new("CanvasGroup", { Name = "Sheen", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 0.82, Parent = frame }, { corner(10) })
	for i, x in ipairs({ 0.12, 0.3, 0.42 }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.15), Size = UDim2.new(0, i == 1 and 14 or 6, 1.4, 0), Rotation = 35, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = sheen })
	end
	local icon = trophy(frame, s.trophy)
	return { frame = frame, outline = outline, icon = icon, style = style }
end

local function retile(t, style)
	if t.style == style then
		return
	end
	t.style = style
	local s = TILE[style]
	t.frame:FindFirstChildOfClass("UIGradient"):Destroy()
	gloss(s.top, s.bottom).Parent = t.frame
	t.outline.Color = s.outline
	t.icon:Destroy()
	t.icon = trophy(t.frame, s.trophy)
end

-- Button: a small REF 4 bar with a gradient fill child so the caption stays white.
local function button(props, style, onClick)
	local defaults = { BackgroundTransparency = 1, Font = DISPLAY, TextColor3 = C.text, TextSize = 16, AutoButtonColor = false, Text = "" }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	defaults.TextTransparency = 1
	local s = TILE[style or "red"]
	local b = new("TextButton", defaults, { corner(6) })
	local outline = stroke(s.outline, 2)
	outline.Parent = b
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 0, Parent = b }, { corner(6), gloss(s.top, s.bottom) })
	stripes(fill, 16, 5, 0.86, 6)
	local caption = label({ Name = "Caption", Text = b.Text, Font = b.Font, TextSize = b.TextSize, TextColor3 = b.TextColor3, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	b:GetPropertyChangedSignal("Text"):Connect(function()
		caption.Text = b.Text
	end)
	b.MouseEnter:Connect(function()
		fill.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
	end)
	b.MouseLeave:Connect(function()
		fill.BackgroundColor3 = WHITE
	end)
	b.MouseButton1Down:Connect(function()
		fill.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
	end)
	b.MouseButton1Up:Connect(function()
		fill.BackgroundColor3 = WHITE
	end)
	b:SetAttribute("Style", style or "red")
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function restyle(b, style)
	if b:GetAttribute("Style") == style then
		return
	end
	b:SetAttribute("Style", style)
	local s = TILE[style]
	b.Fill:FindFirstChildOfClass("UIGradient"):Destroy()
	gloss(s.top, s.bottom).Parent = b.Fill
	b:FindFirstChildOfClass("UIStroke").Color = s.outline
	b.Caption.TextColor3 = style == "grey" and Color3.fromRGB(210, 210, 214) or C.text
end

-- Dark REF 4 panel with neon outline, halo and stripe texture. Panels that use a UIListLayout pass
-- plain = true, since the halo and stripe children would otherwise be laid out as list items.
local function neonPanel(props, radius, plain)
	local defaults = { BackgroundColor3 = C.panel }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local frame = new("Frame", defaults, { corner(radius or 8), stroke(C.neon, 2.5) })
	if not plain then
		halo(frame, C.neon, radius)
		stripes(frame, 26, 9, 0.96, radius)
	end
	return frame
end

local function fmt(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

local function pct(n)
	return string.format("%.2f%%", n)
end

local gui = new("ScreenGui", { Name = "TideboundUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

-- Toasts ------------------------------------------------------------------------------

local toastList = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0.22, 0), Size = UDim2.new(0, 310, 0.6, 0), ZIndex = 30, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
})
local toastOrder = 0

local function toast(message, kind)
	toastOrder += 1
	local color = ({ good = C.good, bad = C.bad, warn = C.warn, rare = C.gold })[kind] or C.blue
	local t = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel, BackgroundTransparency = 0.05, LayoutOrder = toastOrder, Parent = toastList }, { corner(6), stroke(color, 2) })
	local text = label({ Text = message, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Parent = t }, { padding(9), textStroke(1.5) })
	local toasts = {}
	for _, child in ipairs(toastList:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 5 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(5, function()
		if t.Parent then
			TweenService:Create(text, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.4)
			t:Destroy()
		end
	end)
end

local function act(...)
	local ok, result = pcall(Request.InvokeServer, Request, ...)
	if not ok then
		toast("Request failed, try again.", "bad")
		return nil
	end
	if type(result) == "table" and result.error then
		toast(result.error, "bad")
	end
	return result
end

-- HUD ---------------------------------------------------------------------------------

local openMenu -- forward declaration
local playAnim, stopAnim -- forward declarations (defined with the minigame)
local situation = nil -- "fishing" while reeling, for the camera (Delta Section 10 Table C)

local hud = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 176, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui }, { list(8) })

local function pill(order, style, letter)
	local frame = neonPanel({ Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = hud }, 6)
	local icon = new("Frame", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 4, 0.5, -13), BackgroundColor3 = WHITE, Parent = frame }, { corner(5), gloss(TILE[style].top, TILE[style].bottom), stroke(TILE[style].outline, 1.5) })
	label({ Text = letter, Font = DISPLAY, TextSize = 16, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = icon })
	return label({ Font = DISPLAY, TextSize = 18, Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -44, 1, 0), Parent = frame })
end

local pills = {
	pearls = pill(1, "blue", "P"),
	shards = pill(2, "gold", "S"),
	embers = pill(3, "red", "E"),
	tideglass = pill(4, "grey", "T"),
}
local infoCard = neonPanel({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = hud }, 6, true)
padding(8).Parent = infoCard
list(2).Parent = infoCard
local infoRod = label({ Size = UDim2.new(1, 0, 0, 16), TextSize = 13, LayoutOrder = 1, Parent = infoCard }, { textStroke(1) })
local infoIncome = label({ Size = UDim2.new(1, 0, 0, 16), TextSize = 13, LayoutOrder = 2, Parent = infoCard }, { textStroke(1) })

-- Side menu: REF 4 tiles as buttons
local sideMenu = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 80), Size = UDim2.new(0, 74, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui }, { list(10) })
local function sideButton(order, style, text, tab, emoji)
	local holder = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(0, 72, 0, 72), LayoutOrder = order, AutoButtonColor = false, Parent = sideMenu })
	local t = tile(holder, style)
	t.frame.Size = UDim2.fromScale(1, 1)
	if emoji then
		t.icon:Destroy()
		label({ Text = emoji, TextSize = 32, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = t.frame })
	end
	label({ Text = text, Font = DISPLAY, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = t.frame })
	holder.Activated:Connect(function()
		openMenu(tab)
	end)
	return holder
end
local eggsButton = sideButton(1, "gold", "EGGS", "ODDS", "🥚")
sideButton(2, "blue", "SHOP", "RODS", "🎣")
sideButton(3, "red", "BOOK", "CREATURES")
sideButton(4, "blue", "HOME", "BASE", "🏠")
local eggBadge = new("Frame", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -16, 0, -8), BackgroundColor3 = C.neon, ZIndex = 4, Parent = eggsButton }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(WHITE, 2) })
local eggBadgeText = label({ Font = DISPLAY, TextSize = 14, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = eggBadge })

-- Heat meter
local heatFrame = neonPanel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0.4, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, 6, true)
heatFrame.Parent = gui
padding(8).Parent = heatFrame
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = heatFrame })
new("UISizeConstraint", { MinSize = Vector2.new(260, 0), MaxSize = Vector2.new(420, math.huge), Parent = heatFrame })
local heatTitle = label({ Font = DISPLAY, TextSize = 18, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = heatFrame })
local heatTrack = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(40, 40, 44), LayoutOrder = 2, Parent = heatFrame }, { corner(4), stroke(Color3.fromRGB(120, 120, 126), 1.5) })
local heatFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, Parent = heatTrack }, { corner(4) })
local heatGloss = gloss(TILE.blue.top, TILE.blue.bottom)
heatGloss.Parent = heatFill
for _, mark in ipairs({ 25, 50, 75 }) do
	new("Frame", { Size = UDim2.new(0, 2, 1, 6), Position = UDim2.new(mark / 100, -1, 0, -3), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = heatTrack })
end
local heatInfo = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = heatFrame }, { textStroke(1) })
local haulInfo = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = heatFrame }, { textStroke(1) })
-- Delta Section 9: health, lock-on, frayed rod and tide mode under the heat bar
local riskInfo = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = DISPLAY, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 5, Parent = heatFrame }, { textStroke(1.5) })
local lastHeatStyle = nil

local function refreshHUD()
	if not state then
		return
	end
	pills.pearls.Text = fmt(state.pearls)
	pills.shards.Text = fmt(state.shards)
	pills.embers.Text = fmt(state.embers)
	pills.tideglass.Text = fmt(state.tideglass)
	local rod = Config.RodsById[state.rod]
	local bait = state.bait ~= "" and Config.BaitById[state.bait]
	infoRod.Text = (rod and rod.name or "?") .. (bait and (" · %s x%d"):format(bait.name, state.baitInv[state.bait] or 0) or " · no bait")
	infoIncome.Text = ("Aquarium +%.1f Pearls/min"):format(state.incomePerMin)
	eggBadge.Visible = state.eggs > 0
	eggBadgeText.Text = state.eggs > 99 and "99+" or tostring(state.eggs)

	local heat = state.heat
	heatFill.Size = UDim2.new(heat / Config.Heat.max, 0, 1, 0)
	local style = heat >= 75 and "red" or heat >= 25 and "gold" or "blue"
	if style ~= lastHeatStyle then
		lastHeatStyle = style
		heatGloss.Color = ColorSequence.new(TILE[style].top, TILE[style].bottom)
	end
	heatTitle.Text = ("HEAT  %d / %d"):format(heat, Config.Heat.max)
	local status = "Calm waters. Heat falls by 1 every 3s while you lie low."
	for _, threshold in ipairs(Config.Heat.thresholds) do
		if heat >= threshold.at then
			status = threshold.label
		end
	end
	local closed = state.beaconsClosedUntil - workspace:GetServerTimeNow()
	if closed > 0 then
		status = ("Extraction beacons closed for %ds"):format(math.ceil(closed))
	end
	heatInfo.Text = status
	if state.carriedPearls > 0 or state.carriedEggs > 0 then
		haulInfo.Text = ("At risk: %s Pearls of fish and %d egg(s). A wipe keeps half the fish Pearls and loses the eggs."):format(fmt(state.carriedPearls), state.carriedEggs)
		haulInfo.TextColor3 = C.warn
	else
		haulInfo.Text = "Nothing at risk. Cast at a glowing spot in the Sunken Shoals or steal a wild egg."
		haulInfo.TextColor3 = C.muted
	end
	local parts = { string.rep("❤", state.health) .. string.rep("♡", state.maxHealth - state.health) }
	if state.locked then
		table.insert(parts, "LOCKED ON")
	end
	if state.frayed then
		table.insert(parts, "Rod frayed")
	end
	table.insert(parts, state.openTide and "Open Tide" or "Calm Tide")
	if state.immuneUntil > workspace:GetServerTimeNow() then
		table.insert(parts, "Snatch immune")
	end
	riskInfo.Text = table.concat(parts, "  ·  ")
	riskInfo.TextColor3 = state.locked and C.bad or (state.health < state.maxHealth and C.warn or C.text)
	infoIncome.Text = ("Aquarium +%.1f Pearls/min"):format(state.incomePerMin)
end

-- Fishing minigame (Fisch-style: hold to push the bar, keep the fish inside it) ---

local fishFrame = neonPanel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.new(0.9, 0, 0, 128), Visible = false }, 8)
fishFrame.Parent = gui
new("UISizeConstraint", { MaxSize = Vector2.new(520, 128), Parent = fishFrame })
local fishTitle = label({ Font = DISPLAY, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0, 24), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Parent = fishFrame })
local reelTrack = new("Frame", { Position = UDim2.new(0, 14, 0, 40), Size = UDim2.new(1, -28, 0, 36), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = fishFrame }, { corner(6), stroke(TILE.blue.outline, 2), gloss(TILE.blue.top, TILE.blue.bottom) })
local reelBar = new("Frame", { Size = UDim2.new(0.22, 0, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, Parent = reelTrack }, { corner(6), stroke(WHITE, 2) })
local fishIcon = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 30, 0, 30), Text = "🐟", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = reelTrack })
local progressTrack = new("Frame", { Position = UDim2.new(0, 14, 0, 86), Size = UDim2.new(1, -28, 0, 10), BackgroundColor3 = Color3.fromRGB(40, 40, 44), Parent = fishFrame }, { corner(4) })
local progressFill = new("Frame", { Size = UDim2.new(0.3, 0, 1, 0), BackgroundColor3 = WHITE, Parent = progressTrack }, { corner(4), gloss(TILE.gold.top, TILE.gold.bottom) })
local fishHint = label({ Position = UDim2.new(0, 14, 0, 102), Size = UDim2.new(1, -28, 0, 18), TextSize = 13, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = fishFrame }, { textStroke(1) })

local touches = 0
UserInputService.TouchStarted:Connect(function()
	touches += 1
end)
UserInputService.TouchEnded:Connect(function()
	touches = math.max(0, touches - 1)
end)

local function isHolding()
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or touches > 0
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
end

-- Placeholder animation hooks (Delta Section 10): plays Person B's animation when its id is filled in.
local animTracks = {}
playAnim = function(name)
	local spec = Animations[name]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not spec or spec.id == "" or not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = spec.id
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if ok and track then
		track.Looped = spec.loop == true
		track:Play()
		animTracks[name] = track
	end
end
stopAnim = function(name)
	local track = animTracks[name]
	if track then
		track:Stop()
		animTracks[name] = nil
	end
end

local fishing = false
local function runMinigame(cast)
	if fishing then
		return
	end
	fishing = true
	local f = Config.Fishing
	fishFrame.Visible = true
	reelTrack.Visible, progressTrack.Visible = false, false
	fishTitle.TextColor3 = C.text
	fishTitle.Text = (cast.pier and "Pier cast" or "Casting") .. (cast.bait and (" with " .. cast.bait) or "") .. "..."
	fishHint.Text = cast.frayed and "Wait for the bite. Your rod is frayed: -20% Control until you extract." or "Wait for the bite."
	playAnim("Cast")
	situation = "fishing"
	task.wait(cast.biteWait)
	playAnim("ReelIn")

	fishTitle.Text = "BITE! Reel it in!"
	fishTitle.TextColor3 = C.gold
	fishHint.Text = "Hold click (or touch) to push the bar right. Keep the fish inside it."
	reelTrack.Visible, progressTrack.Visible = true, true
	local rng = Random.new()
	local barWidth = math.clamp(f.baseBarWidth * cast.control, 0.12, 0.5)
	reelBar.Size = UDim2.new(barWidth, 0, 1, 0)
	local barPos, barVel = 0.5 - barWidth / 2, 0
	local fishPos, fishTarget, retarget = 0.5, 0.5, 0
	local fishSpeed = 0.22 + 0.07 * cast.difficulty
	local progress = f.startProgress
	local peak = progress
	local perfect = true
	local started = os.clock()
	local caught

	while true do
		local dt = RunService.RenderStepped:Wait()
		barVel = math.clamp(barVel + (isHolding() and f.reelAccel or -f.reelAccel) * dt, -1.4, 1.4)
		barPos += barVel * dt
		if barPos < 0 then
			barPos, barVel = 0, 0
		elseif barPos > 1 - barWidth then
			barPos, barVel = 1 - barWidth, 0
		end
		retarget -= dt
		if retarget <= 0 then
			fishTarget = rng:NextNumber(0.05, 0.95)
			retarget = rng:NextNumber(0.4, math.max(0.6, 1.8 - cast.difficulty * 0.15))
		end
		fishPos += math.clamp(fishTarget - fishPos, -fishSpeed * dt, fishSpeed * dt)
		local inside = fishPos >= barPos and fishPos <= barPos + barWidth
		if inside then
			progress += f.gainPerSecond * dt
		else
			progress -= f.lossPerSecond / cast.resilience * dt
			perfect = false
		end
		reelBar.Position = UDim2.new(barPos, 0, 0, 0)
		reelBar.BackgroundColor3 = inside and Color3.fromRGB(170, 255, 200) or Color3.fromRGB(255, 180, 180)
		fishIcon.Position = UDim2.new(fishPos, 0, 0.5, 0)
		progressFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		peak = math.max(peak, progress)
		if progress >= 1 then
			caught = true
			break
		elseif progress <= 0 or os.clock() - started > 45 then
			caught = false
			break
		end
	end

	fishTitle.TextColor3 = caught and C.good or C.bad
	fishTitle.Text = caught and (perfect and "PERFECT CATCH!" or "CAUGHT!") or "It got away..."
	act("FinishCast", cast.id, caught, perfect, peak)
	stopAnim("ReelIn")
	situation = nil
	task.wait(1.2)
	fishFrame.Visible = false
	fishing = false
end

FishingEvent.OnClientEvent:Connect(function(cast)
	task.spawn(runMinigame, cast)
end)

-- Menu (REF 4) ---------------------------------------------------------------------------

local blur = Lighting:FindFirstChild("TideboundMenuBlur") or Instance.new("BlurEffect")
blur.Name = "TideboundMenuBlur"
blur.Size = 0
blur.Parent = Lighting

local menu = neonPanel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.55, 0), Size = UDim2.new(0.9, 0, 0.74, 0), Visible = false, ZIndex = 5 }, 6)
menu.Parent = gui
new("UISizeConstraint", { MaxSize = Vector2.new(780, 520), Parent = menu })
local menuScale = new("UIScale", { Scale = 1, Parent = menu })

-- slanted banner tab sticking out of the top-left, with the sparkle star
local banner = new("Frame", { Name = "Banner", BackgroundTransparency = 1, Position = UDim2.new(0, -26, 0, -62), Size = UDim2.new(0, 360, 0, 58), Rotation = -3, ZIndex = 6, Parent = menu })
local bannerBar = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.new(1, -30, 1, 0), ZIndex = 6, Parent = banner }, { corner(4), gloss(Color3.fromRGB(255, 60, 70), Color3.fromRGB(196, 16, 30)), stroke(Color3.fromRGB(255, 90, 100), 2.5) })
halo(bannerBar, C.neon, 4)
stripes(bannerBar, 22, 10, 0.86, 4)
local tip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -30, 0.5, 0), Size = UDim2.new(0, 41, 0, 41), Rotation = 45, BackgroundColor3 = Color3.fromRGB(222, 36, 48), BorderSizePixel = 0, ZIndex = 5, Parent = banner }, { stroke(Color3.fromRGB(255, 90, 100), 2.5) })
tip.Name = "Tip"
-- four-point sparkle star built from frames (the font has no sparkle glyph)
local starBox = new("Frame", { Position = UDim2.new(0, 10, 0.5, -20), Size = UDim2.new(0, 40, 0, 40), BackgroundTransparency = 1, ZIndex = 7, Parent = bannerBar })
for _, size in ipairs({ UDim2.new(0, 7, 1, 0), UDim2.new(1, 0, 0, 7) }) do
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, BackgroundColor3 = WHITE, ZIndex = 7, Parent = starBox }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 170, 180), Thickness = 2, Transparency = 0.4 }),
	})
end
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 14, 0, 14), Rotation = 45, BackgroundColor3 = WHITE, ZIndex = 7, Parent = starBox })
local bannerText = label({ Font = DISPLAY, TextSize = 26, Position = UDim2.new(0, 58, 0, 0), Size = UDim2.new(1, -64, 1, 0), ZIndex = 7, Parent = bannerBar })

local function closeMenu()
	menu.Visible = false
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
end

button({ Text = "X", TextSize = 20, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -48), Size = UDim2.new(0, 40, 0, 40), ZIndex = 7, Parent = menu }, "red", closeMenu)

local tabBar = new("Frame", { Position = UDim2.new(0, 16, 0, 16), Size = UDim2.new(1, -32, 0, 30), BackgroundTransparency = 1, Parent = menu }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})

-- Two tab groups so each bar stays readable: the egg and tackle menu, and the home and hub menu.
local TABS = {
	{ id = "ODDS", title = "TIDE EGG ODDS", group = "eggs" },
	{ id = "PITY", title = "PITY & PULLS", group = "eggs" },
	{ id = "RODS", title = "RODS", group = "eggs" },
	{ id = "BAIT", title = "BAIT & FISH ODDS", group = "eggs" },
	{ id = "CREATURES", title = "CREATURES", group = "eggs" },
	{ id = "BESTIARY", title = "BESTIARY", group = "eggs" },
	{ id = "BASE", title = "HOME NEST", group = "home" },
	{ id = "QUESTS", title = "DAILY QUESTS", group = "home" },
	{ id = "BOARDS", title = "LEADERBOARDS", group = "home" },
	{ id = "RUN", title = "RUN & RISK", group = "home" },
}
local groupSize = {}
for _, tab in ipairs(TABS) do
	groupSize[tab.group] = (groupSize[tab.group] or 0) + 1
end
local tabButtons, tabPages = {}, {}
local currentTab = "ODDS"

local function makePage(id)
	local page = new("ScrollingFrame", {
		Name = id,
		Position = UDim2.new(0, 16, 0, 60),
		Size = UDim2.new(1, -32, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.neon,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = menu,
	}, { list(8), new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) }) })
	tabPages[id] = page
	return page
end

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function section(parent, text)
	return label({ Text = text, Font = DISPLAY, TextSize = 17, TextColor3 = WHITE, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), Parent = parent })
end

local function divider(parent)
	return new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.neon, BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = parent })
end

local function note(parent, text)
	return label({ Text = text, TextSize = 13, TextColor3 = C.muted, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = parent }, { textStroke(1) })
end

local function rowFrame(parent, height)
	return new("Frame", { Size = UDim2.new(1, 0, 0, height or 30), BackgroundColor3 = C.row, LayoutOrder = nextOrder(), Parent = parent }, { corner(6), stroke(C.neon, 1.5, 0.45) })
end

local function bar(parent, position, size, style)
	local track = new("Frame", { Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(40, 40, 44), Parent = parent }, { corner(4) })
	return new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, Parent = track }, { corner(4), gloss(TILE[style].top, TILE[style].bottom) })
end

-- Rows of six square tiles separated by thin red lines, sized to the page width.
local tileRows = {}
local function tileGrid(parent, count)
	local tiles = {}
	local row
	for i = 1, count do
		if (i - 1) % 6 == 0 then
			if i > 1 then
				divider(parent)
			end
			row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 90), LayoutOrder = nextOrder(), Parent = parent }, { list(10, true) })
			table.insert(tileRows, row)
		end
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 90, 0, 90), LayoutOrder = i, Parent = row })
		local t = tile(holder, "red")
		t.frame.Size = UDim2.fromScale(1, 1)
		t.holder = holder
		t.caption = label({ Font = DISPLAY, TextSize = 12, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.new(0, 3, 1, -32), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = t.frame })
		t.count = label({ Font = DISPLAY, TextSize = 13, Size = UDim2.new(0, 36, 0, 16), Position = UDim2.new(1, -40, 0, 4), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = t.frame })
		tiles[i] = t
	end
	return tiles
end

local function layoutTiles()
	local page = tabPages.CREATURES
	if not page then
		return
	end
	local width = page.AbsoluteSize.X - 16
	local size = math.max(48, math.floor((width - 5 * 10) / 6))
	for _, row in ipairs(tileRows) do
		row.Size = UDim2.new(1, 0, 0, size)
		for _, holder in ipairs(row:GetChildren()) do
			if holder:IsA("Frame") then
				holder.Size = UDim2.new(0, size, 0, size)
			end
		end
	end
end

local refreshers = {}

-- ODDS tab
local oddsPage = makePage("ODDS")
local confirmBuy, hatch -- forward declarations

local actionRow = rowFrame(oddsPage, 54)
local eggsLabel = label({ Font = DISPLAY, TextSize = 19, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.36, -14, 1, 0), Parent = actionRow })
local hatchButton = button({ Text = "HATCH 1", Size = UDim2.new(0.3, -8, 0, 38), Position = UDim2.new(0.36, 0, 0.5, -19), Parent = actionRow }, "blue", function()
	hatch()
end)
button({ Text = ("BUY · %d PEARLS"):format(Config.Eggs.TideEgg.pearlCost), Size = UDim2.new(0.34, -14, 0, 38), Position = UDim2.new(0.66, 2, 0.5, -19), Parent = actionRow }, "gold", function()
	confirmBuy()
end)

section(oddsPage, "DROP RATES · per pull")
for _, tier in ipairs(Config.Tiers) do
	local row = rowFrame(oddsPage, 30)
	new("Frame", { Position = UDim2.new(0, 10, 0.5, -7), Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = tier.color, Parent = row }, { corner(3), stroke(WHITE, 1) })
	label({ Text = tier.id, Font = DISPLAY, TextColor3 = tier.color, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), TextSize = 15, Parent = row })
	label({ Text = pct(tier.rate), Font = DISPLAY, Position = UDim2.new(0.28, 10, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), TextSize = 15, Parent = row })
	label({ Text = table.concat(tier.creatures, ", "), Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -10, 1, 0), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
end
local totalRates = 0
for _, tier in ipairs(Config.Tiers) do
	totalRates += tier.rate
end
label({ Text = "TOTAL  " .. pct(totalRates), Font = DISPLAY, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextOrder(), Parent = oddsPage })
divider(oddsPage)
section(oddsPage, "MUTATIONS · independent roll on every hatch")
local totalMutations = 0
for _, mutation in ipairs(Config.Mutations) do
	totalMutations += mutation.rate
	local row = rowFrame(oddsPage, 30)
	label({ Text = mutation.id, Font = DISPLAY, TextColor3 = mutation.color, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.26, 0, 1, 0), TextSize = 15, Parent = row })
	label({ Text = pct(mutation.rate), Font = DISPLAY, Position = UDim2.new(0.28, 10, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), TextSize = 15, Parent = row })
	label({ Text = ("x%.2f value · %s"):format(mutation.mult, mutation.visual), Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -10, 1, 0), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
end
label({ Text = "TOTAL  " .. pct(totalMutations), Font = DISPLAY, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextOrder(), Parent = oddsPage })
note(oddsPage, Config.LegalText)

-- one egg per incubator slot hatches at once (Hatch Chamber upgrade)
local function hatchCount()
	return math.max(1, math.min(state.eggs, state.base and state.base.incubators or 1))
end

refreshers.ODDS = function()
	eggsLabel.Text = ("x%d TIDE EGGS"):format(state.eggs)
	hatchButton.Text = ("HATCH %d"):format(hatchCount())
end

-- PITY tab
local pityPage = makePage("PITY")
section(pityPage, "PITY · always visible, resets only on a hit")
local pityRows = {}
for _, pity in ipairs(Config.Pity) do
	local row = rowFrame(pityPage, 46)
	label({ Text = ("%s by pull %d"):format(pity.label, pity.at), Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.6, -12, 0, 20), TextSize = 15, Parent = row }, { textStroke(1) })
	local remaining = label({ Font = DISPLAY, Position = UDim2.new(0.6, 0, 0, 2), Size = UDim2.new(0.4, -12, 0, 22), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	local fill = bar(row, UDim2.new(0, 12, 0, 28), UDim2.new(1, -24, 0, 10), pity.tier >= 6 and "blue" or "gold")
	pityRows[pity.key] = { remaining = remaining, fill = fill }
end
divider(pityPage)
section(pityPage, "YOUR LAST 10 PULLS")
local historyLabels = {}
for i = 1, 10 do
	historyLabels[i] = label({ Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder(), Parent = pityPage }, { textStroke(1) })
end

refreshers.PITY = function()
	for _, row in ipairs(Gacha.pityProgress(state.pity)) do
		local ui = pityRows[row.key]
		ui.remaining.Text = row.remaining <= 1 and "NEXT PULL!" or ("%d left"):format(row.remaining)
		ui.remaining.TextColor3 = row.remaining <= 1 and C.gold or C.text
		ui.fill.Size = UDim2.new(math.clamp(row.count / row.at, 0, 1), 0, 1, 0)
	end
	for i, labelInst in ipairs(historyLabels) do
		local entry = state.history[i]
		if entry then
			local tier = Config.Tiers[entry.tier]
			local mutation = entry.mutation ~= "None" and (entry.mutation .. " ") or ""
			labelInst.Text = ("%d. %s%s · %s · %s Pearls%s"):format(i, mutation, entry.creature, tier.id, fmt(entry.value), entry.pity and " · pity" or "")
			labelInst.TextColor3 = tier.color
		else
			labelInst.Text = i == 1 and "No pulls yet." or ""
			labelInst.TextColor3 = C.muted
		end
	end
end

-- RODS tab
local rodsPage = makePage("RODS")
section(rodsPage, "RODS · locked stats, bought with Pearls")
local rodRows = {}
for i, rod in ipairs(Config.Rods) do
	local row = rowFrame(rodsPage, 56)
	label({ Text = rod.name, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 5), Size = UDim2.new(0.66, -12, 0, 22), TextSize = 17, Parent = row })
	label({ Text = ("Lure %.2fx · Luck %.2fx · Control %.2fx · Resil %.2fx · %d biomes"):format(rod.lureSpeed, rod.luck, rod.control, rod.resilience, rod.biomes), Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(0.66, -12, 0, 24), TextSize = 12, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
	rodRows[i] = button({ Size = UDim2.new(0.32, -10, 0, 36), Position = UDim2.new(0.68, 0, 0.5, -18), TextSize = 14, Parent = row }, "gold", function()
		if not state then
			return
		end
		if state.ownedRods[rod.id] then
			act("EquipRod", rod.id)
		else
			act("BuyRod", rod.id)
		end
	end)
end
note(rodsPage, "Robux never buys rods, bait, luck or odds.")

refreshers.RODS = function()
	for i, rod in ipairs(Config.Rods) do
		local b = rodRows[i]
		local owned = state.ownedRods[rod.id]
		local previousOwned = i == 1 or state.ownedRods[Config.Rods[i - 1].id]
		if state.rod == rod.id then
			b.Text = "EQUIPPED"
			restyle(b, "grey")
		elseif owned then
			b.Text = "EQUIP"
			restyle(b, "blue")
		elseif rod.prestigeOnly then
			b.Text = "PRESTIGE"
			restyle(b, "grey")
		elseif not previousOwned then
			b.Text = "LOCKED"
			restyle(b, "grey")
		else
			b.Text = "BUY · " .. fmt(rod.cost)
			restyle(b, state.pearls >= rod.cost and "gold" or "grey")
		end
	end
end

-- BAIT tab
local baitPage = makePage("BAIT")
section(baitPage, "BAIT · multiplies rod Luck, 1 used per cast")
local baitRows = {}
for i, bait in ipairs(Config.Baits) do
	local row = rowFrame(baitPage, 56)
	label({ Text = ("%s  x%.2f"):format(bait.name, bait.luck), Font = DISPLAY, Position = UDim2.new(0, 12, 0, 5), Size = UDim2.new(0.5, -12, 0, 22), TextSize = 16, Parent = row })
	local owned = label({ Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(0.5, -12, 0, 20), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
	local buy = button({ Size = UDim2.new(0.25, -8, 0, 36), Position = UDim2.new(0.5, 0, 0.5, -18), TextSize = 13, Parent = row }, "gold", function()
		act("BuyBait", bait.id)
	end)
	local equip = button({ Size = UDim2.new(0.25, -10, 0, 36), Position = UDim2.new(0.75, 0, 0.5, -18), TextSize = 13, Parent = row }, "blue", function()
		if state and state.bait == bait.id then
			act("EquipBait", "")
		else
			act("EquipBait", bait.id)
		end
	end)
	baitRows[i] = { owned = owned, buy = buy, equip = equip }
end
divider(baitPage)
section(baitPage, "SUNKEN SHOALS FISH ODDS · with your rod and bait")
local fishOddsRows = {}
for i, tier in ipairs(Config.Tiers) do
	local row = rowFrame(baitPage, 28)
	label({ Text = tier.id, Font = DISPLAY, TextColor3 = tier.color, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), TextSize = 14, Parent = row })
	fishOddsRows[i] = label({ Font = DISPLAY, Position = UDim2.new(0.26, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), TextSize = 14, Parent = row })
	label({ Text = ("%s · %d Pearls"):format(table.concat(Config.Biomes[1].fish[i], ", "), tier.fishPearls), Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -10, 1, 0), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
end

refreshers.BAIT = function()
	for i, bait in ipairs(Config.Baits) do
		local ui = baitRows[i]
		local count = state.baitInv[bait.id] or 0
		ui.owned.Text = ("Owned %d · %s"):format(count, bait.source)
		ui.buy.Visible = bait.shop
		ui.buy.Text = ("BUY %d · %d"):format(Config.BaitPackSize, bait.cost * Config.BaitPackSize)
		ui.equip.Visible = count > 0
		ui.equip.Text = state.bait == bait.id and "UNEQUIP" or "EQUIP"
	end
	local rod = Config.RodsById[state.rod] or Config.Rods[1]
	local bait = state.bait ~= "" and (state.baitInv[state.bait] or 0) > 0 and Config.BaitById[state.bait]
	local fishOdds = Gacha.fishOdds(rod.luck * (bait and bait.luck or 1))
	for i, labelInst in ipairs(fishOddsRows) do
		labelInst.Text = pct(fishOdds[i])
	end
end

-- CREATURES tab: trophy tiles, gold when hatched
local creaturesPage = makePage("CREATURES")
local creatureHeader = label({ Font = DISPLAY, TextSize = 16, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), Parent = creaturesPage })
local creatureList = {}
for tierIndex, tier in ipairs(Config.Tiers) do
	for _, creature in ipairs(tier.creatures) do
		table.insert(creatureList, { name = creature, tier = tierIndex })
	end
end
local creatureTiles = tileGrid(creaturesPage, #creatureList)

refreshers.CREATURES = function()
	local owned = 0
	for i, entry in ipairs(creatureList) do
		local t = creatureTiles[i]
		local n = state.collection[entry.name]
		if n then
			owned += 1
			retile(t, "gold")
			t.caption.Text = entry.name
			t.count.Text = "x" .. n
		else
			retile(t, "red")
			t.caption.Text = Config.Tiers[entry.tier].id
			t.count.Text = ""
		end
	end
	creatureHeader.Text = ("CREATURES %d/%d · Aquarium +%.1f Pearls/min"):format(owned, #creatureList, state.incomePerMin)
end

-- BESTIARY tab: trophy tiles, blue when caught
local bestiaryPage = makePage("BESTIARY")
local bestiaryHeader = label({ Font = DISPLAY, TextSize = 16, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), Parent = bestiaryPage })
local fishList = {}
for tierIndex, names in ipairs(Config.Biomes[1].fish) do
	for _, fishName in ipairs(names) do
		table.insert(fishList, { name = fishName, tier = tierIndex })
	end
end
local fishTiles = tileGrid(bestiaryPage, #fishList)

refreshers.BESTIARY = function()
	local caught = 0
	for i, entry in ipairs(fishList) do
		local t = fishTiles[i]
		if state.bestiary[entry.name] then
			caught += 1
			retile(t, "blue")
			t.caption.Text = entry.name
		else
			retile(t, "red")
			t.caption.Text = Config.Tiers[entry.tier].id
		end
	end
	bestiaryHeader.Text = ("SUNKEN SHOALS · %d/%d fish caught"):format(caught, #fishList)
end

do
	-- BASE tab: Home Nest zones, upgrades and storage (Delta Section 7)
	local basePage = makePage("BASE")
	local baseHeader = rowFrame(basePage, 54)
	local baseTitle = label({ Font = DISPLAY, TextSize = 17, Position = UDim2.new(0, 14, 0, 4), Size = UDim2.new(0.44, -14, 0, 24), Parent = baseHeader })
	local baseIncome = label({ TextSize = 12, TextColor3 = C.muted, Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(0.44, -14, 0, 20), Parent = baseHeader }, { textStroke(1) })
	button({ Text = "GO HOME", Size = UDim2.new(0.27, -8, 0, 38), Position = UDim2.new(0.44, 0, 0.5, -19), TextSize = 14, Parent = baseHeader }, "blue", function()
		local result = act("Travel", "Home")
		if result and result.ok then
			closeMenu()
		end
	end)
	local privacyButton = button({ Size = UDim2.new(0.29, -14, 0, 38), Position = UDim2.new(0.71, 0, 0.5, -19), TextSize = 13, Parent = baseHeader }, "grey", function()
		if not state then
			return
		end
		local options = Config.Base.privacy
		local index = table.find(options, state.base.privacy) or 1
		act("SetPrivacy", options[index % #options + 1])
	end)
	note(basePage, "Nothing in your Home Nest can be stolen. Visitors can look around and Admire your showcase, but never take anything.")

	section(basePage, "ZONES · 5 rooms + 3 outdoor zones")
	local zoneRows = {}
	for _, zone in ipairs(Config.Base.zones) do
		local row = rowFrame(basePage, 40)
		label({ Text = zone.name, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.38, -12, 1, 0), TextSize = 15, Parent = row })
		local status = label({ Position = UDim2.new(0.38, 0, 0, 0), Size = UDim2.new(0.34, 0, 1, 0), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, Parent = row }, { textStroke(1) })
		local unlock = button({ Size = UDim2.new(0.28, -10, 0, 30), Position = UDim2.new(0.72, 0, 0.5, -15), TextSize = 13, Parent = row }, "gold", function()
			act("UnlockZone", zone.id)
		end)
		zoneRows[zone.id] = { status = status, unlock = unlock }
	end

	divider(basePage)
	section(basePage, "UPGRADES · Pearls only, Robux can't buy any of these")
	local upgradeRows = {}
	for _, upgrade in ipairs(Config.Base.upgrades) do
		local row = rowFrame(basePage, 40)
		label({ Text = upgrade.name, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.34, -12, 1, 0), TextSize = 15, Parent = row })
		local status = label({ Position = UDim2.new(0.34, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, Parent = row }, { textStroke(1) })
		local buy = button({ Size = UDim2.new(0.28, -10, 0, 30), Position = UDim2.new(0.72, 0, 0.5, -15), TextSize = 13, Parent = row }, "gold", function()
			act("Upgrade", upgrade.id)
		end)
		upgradeRows[upgrade.id] = { status = status, buy = buy, upgrade = upgrade }
	end

	divider(basePage)
	section(basePage, "STORAGE & SALES")
	local storageRow = rowFrame(basePage, 46)
	local storageLabel = label({ Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.62, -12, 1, 0), TextSize = 13, TextWrapped = true, Parent = storageRow }, { textStroke(1) })
	local sellArmedUntil = 0
	local sellButton
	sellButton = button({ Size = UDim2.new(0.38, -10, 0, 34), Position = UDim2.new(0.62, 0, 0.5, -17), TextSize = 13, Parent = storageRow }, "gold", function()
		if os.clock() < sellArmedUntil then
			sellArmedUntil = 0
			act("SellDuplicates")
		else
			sellArmedUntil = os.clock() + 3
			sellButton.Text = "TAP AGAIN TO SELL"
		end
	end)
	local baseNotes = note(basePage, "")

	local zoneById, upgradeById = {}, {}
	for _, zone in ipairs(Config.Base.zones) do
		zoneById[zone.id] = zone
	end
	for _, upgrade in ipairs(Config.Base.upgrades) do
		upgradeById[upgrade.id] = upgrade
	end

	refreshers.BASE = function()
		local b = state.base
		baseTitle.Text = b.plot and ("HOME NEST %d"):format(b.plot) or "NO FREE PLOT"
		local inc = b.income
		baseIncome.Text = ("+%.1f Pearls/min · %d earning · filter +%d%% · trophies +%d%% · fed +%d%%"):format(b.incomePerMin, inc.earning, inc.filter * 100, inc.trophy * 100, inc.fed * 100)
		privacyButton.Text = "VISITORS: " .. b.privacy:upper()
		for id, row in pairs(zoneRows) do
			local zone = zoneById[id]
			if b.zones[id] then
				row.status.Text = zone.kind == "room" and "Unlocked room" or "Unlocked"
				row.unlock.Visible = false
			else
				row.unlock.Visible = true
				row.status.Text = zone.requires and ("Needs " .. zone.requires) or ("%s Pearls"):format(fmt(zone.cost))
				row.unlock.Text = zone.requires and "LOCKED" or ("UNLOCK · " .. fmt(zone.cost))
				restyle(row.unlock, (not zone.requires and state.pearls >= zone.cost) and "gold" or "grey")
			end
		end
		for id, row in pairs(upgradeRows) do
			local upgrade = row.upgrade
			local level = math.clamp(b.levels[id] or 1, 1, #upgrade.values)
			local current = upgrade.values[level]
			if level >= #upgrade.values then
				row.status.Text = ("%s %s · MAX"):format(fmt(current), upgrade.unit)
				row.buy.Text = "MAXED"
				restyle(row.buy, "grey")
			else
				local cost = upgrade.costs[level]
				local blocked = nil
				if not upgrade.free and not b.zones[upgrade.zone] then
					blocked = "Unlock " .. zoneById[upgrade.zone].name
				elseif upgrade.needs and (b.levels[upgrade.needs.id] or 1) < upgrade.needs.level then
					blocked = ("Needs %s Lv %d"):format(upgradeById[upgrade.needs.id].name, upgrade.needs.level)
				end
				row.status.Text = ("Lv %d/%d · %s → %s %s"):format(level, #upgrade.values, fmt(current), fmt(upgrade.values[level + 1]), upgrade.unit) .. (blocked and ("\n" .. blocked) or "")
				row.buy.Text = fmt(cost) .. " P"
				restyle(row.buy, (not blocked and state.pearls >= cost) and "gold" or "grey")
			end
		end
		storageLabel.Text = ("Stored %d / %d creatures. Earning creatures and the best copy of each are always kept; overflow sells at 50%% value."):format(b.storage, b.storageCap)
		if os.clock() >= sellArmedUntil then
			sellButton.Text = b.saleCount > 0 and ("SELL %d DUPES · +%s"):format(b.saleCount, fmt(b.salePearls)) or "NO DUPLICATES"
			restyle(sellButton, b.saleCount > 0 and "gold" or "grey")
		end
		local lines = {}
		if b.zones.pen then
			local left = b.fedUntil - os.time()
			table.insert(lines, left > 0 and ("Creature Pen fed: +5%% income for %d more min."):format(math.ceil(left / 60)) or "Creature Pen is hungry: feed it at the trough for +5% income for 30 min.")
		end
		table.insert(lines, #b.guestbook > 0 and ("Recent visitors: " .. table.concat(b.guestbook, ", ")) or "No visitors yet. Friends can walk in from the Harbor Ring.")
		table.insert(lines, "Prestige Altar opens after a Rift Sovereign defeat; Aurora Rift isn't built yet.")
		baseNotes.Text = table.concat(lines, "\n")
	end
end

do
	-- QUESTS tab: Quill's daily quests and the season board (Delta Sections 8 and 11)
	local questsPage = makePage("QUESTS")
	section(questsPage, "DAILY QUESTS · reset at 00:00 UTC")
	local questRows = {}
	for _, quest in ipairs(Config.Quests) do
		local row = rowFrame(questsPage, 52)
		label({ Text = quest.text, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.66, -12, 0, 22), TextSize = 15, Parent = row })
		local progressText = label({ Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(0.2, 0, 0, 20), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
		local fill = bar(row, UDim2.new(0.2, 12, 0, 32), UDim2.new(0.46, -24, 0, 10), "gold")
		local claim = button({ Size = UDim2.new(0.34, -10, 0, 36), Position = UDim2.new(0.66, 0, 0.5, -18), TextSize = 13, Parent = row }, "gold", function()
			act("ClaimQuest", quest.id)
		end)
		questRows[quest.id] = { progress = progressText, fill = fill, claim = claim, quest = quest }
	end
	local questReset = note(questsPage, "")
	divider(questsPage)
	section(questsPage, "SEASON TRACK · Captain Brask")
	note(questsPage, "The free season track opens with Season 1. It will pay Pearls, cosmetics and 100 Tideglass per 10 tiers, and nothing on it changes stats.")

	refreshers.QUESTS = function()
		for id, row in pairs(questRows) do
			local count = state.quests.progress[id] or 0
			local claimed = state.quests.claimed[id]
			row.progress.Text = ("%d / %d"):format(count, row.quest.goal)
			row.fill.Size = UDim2.new(math.clamp(count / row.quest.goal, 0, 1), 0, 1, 0)
			if claimed then
				row.claim.Text = "CLAIMED"
				restyle(row.claim, "grey")
			else
				row.claim.Text = ("CLAIM · %d P"):format(row.quest.reward)
				restyle(row.claim, count >= row.quest.goal and "gold" or "grey")
			end
		end
		local secondsLeft = 86400 - (os.time() % 86400)
		questReset.Text = ("New quests in %dh %dm."):format(secondsLeft // 3600, (secondsLeft % 3600) // 60)
	end
end

do
	-- BOARDS tab: the Leaderboard Hall (this server)
	local boardsPage = makePage("BOARDS")
	local boardLabels = {}
	for _, board in ipairs({ { "rarest", "RAREST HATCH" }, { "streak", "LONGEST CLEAN EXTRACTION STREAK" }, { "heat", "HIGHEST HEAT EXTRACTED AT" }, { "hatched", "MOST HATCHED" } }) do
		section(boardsPage, board[2])
		boardLabels[board[1]] = label({ Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = boardsPage }, { textStroke(1) })
		divider(boardsPage)
	end
	section(boardsPage, "YOUR RECORD")
	local myRecord = label({ Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = boardsPage }, { textStroke(1) })

	refreshers.BOARDS = function()
		for key, labelInst in pairs(boardLabels) do
			local entries = state.boards[key] or {}
			local lines = {}
			for i, entry in ipairs(entries) do
				table.insert(lines, ("%d. %s · %s"):format(i, entry.name, entry.text))
			end
			labelInst.Text = #lines > 0 and table.concat(lines, "\n") or "Nobody yet. Be the first!"
		end
		local st = state.stats
		myRecord.Text = ("Extractions %d · wipes %d · clean streak %d (best %d) · best Heat extracted %d · fish caught %d · hatched %d"):format(st.extractions, st.wipes, st.cleanStreak, st.bestStreak, st.bestHeatExtract or 0, st.fishCaught, st.hatched)
	end
end

do
	-- RUN tab: Calm or Open Tide, travel and the risk rules (Delta Section 9)
	local runPage = makePage("RUN")
	section(runPage, "TIDE MODE · pick before your run")
	local tideRow = rowFrame(runPage, 50)
	local calmButton = button({ Text = "CALM TIDE", Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new(0, 8, 0.5, -19), TextSize = 15, Parent = tideRow }, "blue", function()
		act("SetOpenTide", false)
	end)
	local openButton = button({ Text = "OPEN TIDE", Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new(0.5, 6, 0.5, -19), TextSize = 15, Parent = tideRow }, "grey", function()
		act("SetOpenTide", true)
	end)
	note(runPage, "Calm Tide (default): no PvP. Open Tide: a rival 6 studs behind you can hold for 1 s to snatch one carried egg, never near a beacon (40 studs), and you get 5 s of immunity and a speed burst. Egg nests can hold a bonus egg (x1.20).")
	divider(runPage)
	section(runPage, "TRAVEL · from the Nest or the Harbor Ring")
	local travelRow = rowFrame(runPage, 50)
	for i, dest in ipairs({ { "NEST PLAZA", "Nest" }, { "HARBOR RING", "Harbor" }, { "MY HOME NEST", "Home" } }) do
		button({ Text = dest[1], Size = UDim2.new(1 / 3, -12, 0, 38), Position = UDim2.new((i - 1) / 3, 6, 0.5, -19), TextSize = 13, Parent = travelRow }, "blue", function()
			local result = act("Travel", dest[2])
			if result and result.ok then
				closeMenu()
			end
		end)
	end
	divider(runPage)
	section(runPage, "RISK RULES")
	note(runPage, table.concat({
		"Health: 3. Each Reef Warden hit costs 1; the third hit is a wipe.",
		"Wipe: you lose every carried egg and half the run's fish Pearls. You keep the other half, your bestiary and every pity counter.",
		"Heat: +8 per steal, +2 per fish, -1 per 3 s while lying low. 25 patrol, 50 riptide, 75 lock-on, 100 all beacons close for 30 s.",
		"Lock-on breaks after 6 s out of the Warden's sight. Each carried egg costs 2 WalkSpeed; hold Shift (or SPRINT) to run faster.",
		"Extract: hold 3 s at a beacon. Then stay for the Greed Window: every 5 s adds +15% payout and +5 Heat; all 15 s adds +2 Embers. Walk away or press BANK NOW to leave.",
		"Beacon grace: within 10 studs of a beacon when Heat hits 100, you get 10 s to extract.",
		"A lost fish frays your rod (-20% Control) until you extract. An escaped fish that passed 90% drops a Lucky Scale (+25 Pearls).",
		"Clean Extraction streak: +1 Ember per 3 extractions in a row, up to +3. A wipe resets it.",
	}, "\n"))
	local runStats = note(runPage, "")

	refreshers.RUN = function()
		restyle(calmButton, state.openTide and "grey" or "blue")
		restyle(openButton, state.openTide and "red" or "grey")
		runStats.Text = ("Clean streak %d · best %d · extractions %d · wipes %d"):format(state.stats.cleanStreak, state.stats.bestStreak, state.stats.extractions, state.stats.wipes)
	end
end

local function selectTab(id)
	currentTab = id
	local group
	for _, tab in ipairs(TABS) do
		if tab.id == id then
			group = tab.group
		end
	end
	for _, tab in ipairs(TABS) do
		local selected = tab.id == id
		tabButtons[tab.id].Visible = tab.group == group
		tabPages[tab.id].Visible = selected
		restyle(tabButtons[tab.id], selected and "red" or "grey")
		if selected then
			bannerText.Text = tab.title
		end
	end
	layoutTiles()
	if state then
		refreshers[id]()
	end
end

for i, tab in ipairs(TABS) do
	tabButtons[tab.id] = button({ Text = tab.id, Size = UDim2.new(1 / groupSize[tab.group], -10, 1, 0), LayoutOrder = i, TextSize = 13, Parent = tabBar }, "grey", function()
		selectTab(tab.id)
	end)
end

menu:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTiles)

openMenu = function(id)
	selectTab(id)
	if not menu.Visible then
		menu.Visible = true
		menuScale.Scale = 0.88
		TweenService:Create(menuScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(blur, TweenInfo.new(0.22), { Size = 16 }):Play()
		task.defer(layoutTiles)
	end
end

-- Confirm purchase modal: odds and pity on screen before any purchase
local modal = neonPanel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.86, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 8 }, 6, true)
modal.Parent = gui
padding(18).Parent = modal
list(10).Parent = modal
new("UISizeConstraint", { MaxSize = Vector2.new(430, math.huge), Parent = modal })
label({ Text = "BUY 1 TIDE EGG?", Font = DISPLAY, TextSize = 22, TextColor3 = C.gold, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = modal })
local modalBody = label({ TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = modal }, { textStroke(1) })
local modalButtons = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 3, Parent = modal })
button({ Text = "CONFIRM", Size = UDim2.new(0.5, -5, 1, 0), Parent = modalButtons }, "gold", function()
	modal.Visible = false
	act("BuyEgg")
end)
button({ Text = "CANCEL", Size = UDim2.new(0.5, -5, 1, 0), Position = UDim2.new(0.5, 5, 0, 0), Parent = modalButtons }, "grey", function()
	modal.Visible = false
end)

confirmBuy = function()
	if not state then
		return
	end
	local lines = { ("Cost: %d Pearls (you have %s). Robux can't buy eggs."):format(Config.Eggs.TideEgg.pearlCost, fmt(state.pearls)), "", "Odds per pull:" }
	for _, tier in ipairs(Config.Tiers) do
		table.insert(lines, ("  %s  %s"):format(tier.id, pct(tier.rate)))
	end
	table.insert(lines, "")
	local floorTier = Gacha.pityFloor(state.pity)
	for _, row in ipairs(Gacha.pityProgress(state.pity)) do
		table.insert(lines, ("%s guaranteed in %d pull(s)"):format(row.label, row.remaining))
	end
	if floorTier > 1 then
		table.insert(lines, ("Your next hatch is guaranteed %s or better."):format(Config.Tiers[floorTier].id))
	end
	modalBody.Text = table.concat(lines, "\n")
	modal.Visible = true
end

-- Hatch reveal: a big REF 4 tile that flips from red to gold on reveal
local reveal = neonPanel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 320, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 9 }, 6, true)
reveal.Parent = gui
padding(18).Parent = reveal
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = reveal })
local revealScale = new("UIScale", { Scale = 1, Parent = reveal })
local revealHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 120, 0, 120), LayoutOrder = 0, Parent = reveal })
local revealTile = tile(revealHolder, "red")
revealTile.frame.Size = UDim2.fromScale(1, 1)
local revealTier = label({ Font = DISPLAY, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, Parent = reveal })
local revealName = label({ Font = DISPLAY, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 2, Parent = reveal })
local revealMutation = label({ Font = DISPLAY, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 3, Parent = reveal })
local prismatic = new("UIGradient", {
	Enabled = false,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 110, 255)),
	}),
	Parent = revealMutation,
})
local revealDetails = label({ TextSize = 15, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = reveal }, { textStroke(1) })
local revealClose = button({ Text = "NICE!", TextSize = 18, Size = UDim2.new(0.6, 0, 0, 38), LayoutOrder = 5, Parent = reveal }, "gold", function()
	reveal.Visible = false
end)

local function showReveal(result)
	local tier = Config.Tiers[result.tier]
	local mutation
	for _, m in ipairs(Config.Mutations) do
		if m.id == result.mutation then
			mutation = m
		end
	end
	reveal.Visible = true
	revealClose.Visible = false
	retile(revealTile, "red")
	revealTier.Text = "HATCHING..."
	revealTier.TextColor3 = C.text
	revealName.Text, revealMutation.Text, revealDetails.Text = "", "", ""
	prismatic.Enabled = false
	for _ = 1, 5 do
		revealHolder.Rotation = 8
		task.wait(0.08)
		revealHolder.Rotation = -8
		task.wait(0.08)
	end
	revealHolder.Rotation = 0
	revealScale.Scale = 0.6
	TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	retile(revealTile, result.tier >= 4 and "gold" or "blue")
	revealTier.Text = tier.id:upper()
	revealTier.TextColor3 = tier.color
	revealName.Text = result.creature
	if mutation and mutation.id ~= "None" then
		revealMutation.Text = ("%s mutation · x%.2f"):format(mutation.id, mutation.mult)
		revealMutation.TextColor3 = mutation.id == "Prismatic" and WHITE or mutation.color
		prismatic.Enabled = mutation.id == "Prismatic"
	else
		revealMutation.Text = "No mutation"
		revealMutation.TextColor3 = C.muted
	end
	local lines = {
		("Value %s Pearls"):format(fmt(result.value)),
		result.isNew and ("New creature! +%d Egg Shard"):format(result.shards) or ("Duplicate · +%d Egg Shards"):format(result.shards),
	}
	if result.pity then
		table.insert(lines, "Pity guarantee triggered")
	end
	for _, other in ipairs(result.others or {}) do
		local otherTier = Config.Tiers[other.tier]
		table.insert(lines, ("Also: %s%s %s"):format(other.mutation ~= "None" and (other.mutation .. " ") or "", otherTier.id, other.creature))
	end
	revealDetails.Text = table.concat(lines, "\n")
	revealClose.Visible = true
end

hatch = function()
	if not state then
		return
	end
	local result = act("Hatch", hatchCount())
	if result and result.ok then
		local best = result.result
		best.others = {}
		local skippedBest = false
		for _, other in ipairs(result.results or {}) do
			local isBest = not skippedBest and other.creature == best.creature and other.value == best.value and other.mutation == best.mutation
			if isBest then
				skippedBest = true
			elseif #best.others < 7 then
				table.insert(best.others, other)
			end
		end
		situation = "hatch"
		task.spawn(function()
			showReveal(best)
			situation = nil
		end)
	end
end

-- Zone lighting: snowy pink haze over the Nest (REF 1), bright turquoise over the Shoals (REF 2) ---

local ZONES = {
	Nest = {
		atmosphere = { Density = 0.36, Color = Color3.fromRGB(226, 214, 222), Decay = Color3.fromRGB(196, 184, 196), Haze = 1.4 },
		grade = { Saturation = 0.12, TintColor = Color3.fromRGB(255, 248, 250) },
		bloom = 0.3,
	},
	Shoals = {
		atmosphere = { Density = 0.28, Color = Color3.fromRGB(206, 242, 250), Decay = Color3.fromRGB(120, 214, 232), Haze = 0.7 },
		grade = { Saturation = 0.28, TintColor = Color3.fromRGB(246, 255, 252) },
		bloom = 0.55,
	},
}
local currentZone = nil
local function applyZone(name)
	if currentZone == name then
		return
	end
	currentZone = name
	local zone = ZONES[name]
	local info = TweenInfo.new(2)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, zone.atmosphere):Play()
	end
	local grade = Lighting:FindFirstChild("TideboundGrade")
	if grade then
		TweenService:Create(grade, info, zone.grade):Play()
	end
	local bloom = Lighting:FindFirstChild("TideboundBloom")
	if bloom then
		TweenService:Create(bloom, info, { Intensity = zone.bloom }):Play()
	end
end

local refreshGreed -- set in the block below
do
	-- Tension and feel (Delta Sections 9 and 10) --------------------------------------------------

	-- Screen-edge tint that climbs with Heat: faint gold at 25, orange at 50, pulsing red at lock-on.
	local vignette = new("Frame", { Name = "Vignette", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = gui })
	local edges = {}
	for _, spec in ipairs({
		{ UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0, 0), 90 },
		{ UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.82, 0), -90 },
		{ UDim2.new(0.12, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
		{ UDim2.new(0.12, 0, 1, 0), UDim2.new(0.88, 0, 0, 0), 180 },
	}) do
		local edge = new("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = C.bad, BorderSizePixel = 0, BackgroundTransparency = 0, Parent = vignette })
		new("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new(0, 1), Parent = edge })
		table.insert(edges, edge)
	end
	local flash = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = gui })
	local function screenFlash(color, from)
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = from or 0.4
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end

	local shakeUntil, shakeAmount = 0, 0
	local function shake(amount, seconds)
		shakeAmount = amount
		shakeUntil = os.clock() + seconds
	end

	local function pulseHeat()
		local scale = heatFrame:FindFirstChild("Pulse") or new("UIScale", { Name = "Pulse", Parent = heatFrame })
		scale.Scale = 1.08
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-- Greed Window panel: shows after the 3 s beacon channel while you hold position
	local greedFrame = neonPanel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(0, 360, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, 6, true)
	greedFrame.Parent = gui
	padding(10).Parent = greedFrame
	list(6).Parent = greedFrame
	local greedTitle = label({ Font = DISPLAY, TextSize = 20, TextColor3 = C.gold, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = greedFrame })
	local greedText = label({ TextSize = 13, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = greedFrame }, { textStroke(1) })
	local greedFill = bar(new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 3, Parent = greedFrame }), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), "gold")
	button({ Text = "BANK NOW", Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 4, Parent = greedFrame }, "blue", function()
		act("BankNow")
	end)

	refreshGreed = function()
		local greed = state and state.greed
		greedFrame.Visible = greed ~= nil
		if not greed then
			return
		end
		local elapsed = workspace:GetServerTimeNow() - greed.started
		local window = Config.Risk.greedSeconds
		greedTitle.Text = ("GREED WINDOW  %ds"):format(math.max(0, math.ceil(window - elapsed)))
		greedText.Text = ("Bonus so far: +%d%% payout%s. Every 5 s adds +15%% and +5 Heat. Walk away or bank to leave."):format(greed.steps * 15, greed.steps >= 3 and " and +2 Embers" or "")
		greedFill.Size = UDim2.new(math.clamp(elapsed / window, 0, 1), 0, 1, 0)
	end

	-- Sprint: Shift on keyboard, a SPRINT toggle on touch screens
	local sprintHeld, sprintToggle = false, false
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3) then
			sprintHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			sprintHeld = false
		end
	end)
	if UserInputService.TouchEnabled then
		local sprintButton
		sprintButton = button({ Text = "SPRINT", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -150, 1, -40), Size = UDim2.new(0, 84, 0, 44), TextSize = 15, Parent = gui }, "grey", function()
			sprintToggle = not sprintToggle
			restyle(sprintButton, sprintToggle and "gold" or "grey")
		end)
	end

	-- every frame: WalkSpeed (carry slowdown, treadmill, sprint), camera FOV and shake, vignette
	local currentFov = Config.Camera.exploration
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and state then
			local sprinting = (sprintHeld or sprintToggle) and humanoid.MoveDirection.Magnitude > 0.1
			humanoid.WalkSpeed = state.walkSpeed + (sprinting and Config.Risk.sprintBonus or 0)
			if shakeUntil > os.clock() then
				humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * shakeAmount, (math.random() - 0.5) * shakeAmount, 0)
			elseif humanoid.CameraOffset.Magnitude > 0 then
				humanoid.CameraOffset = Vector3.zero
			end
		end
		local camera = workspace.CurrentCamera
		if camera and state then
			local target = Config.Camera.exploration
			if situation == "fishing" then
				target = Config.Camera.fishing
			elseif situation == "hatch" then
				target = Config.Camera.hatch
			elseif state.locked then
				target = Config.Camera.chase
			end
			currentFov += (target - currentFov) * math.min(1, dt * 4)
			camera.FieldOfView = currentFov
		end
		local heat = state and state.heat or 0
		local color, alpha = C.bad, 1
		if state and state.locked then
			alpha = 0.55 + 0.2 * math.sin(os.clock() * 6)
		elseif heat >= Config.Heat.hazardAt then
			color, alpha = Color3.fromRGB(255, 140, 50), 0.75
		elseif heat >= Config.Heat.patrolAt then
			color, alpha = C.gold, 0.88
		end
		for _, edge in ipairs(edges) do
			edge.BackgroundColor3 = color
			edge.BackgroundTransparency = alpha
		end
	end)

	-- Feel cues from the server: animations (placeholders until Person B delivers), screen effects
	CueEvent.OnClientEvent:Connect(function(name, payload)
		if name == "Steal" then
			playAnim("EggGrab")
			pulseHeat()
			shake(0.15, 0.15)
		elseif name == "Hit" then
			playAnim("HitReact")
			screenFlash(C.bad, 0.5)
			shake(0.4, 0.3)
		elseif name == "Down" then
			playAnim("Down")
			screenFlash(C.bad, 0.2)
		elseif name == "Extract" then
			playAnim("ExtractionEmote")
			screenFlash(WHITE, 0.2)
		elseif name == "Greed" then
			pulseHeat()
		elseif name == "Snatched" then
			screenFlash(C.warn, 0.5)
			shake(0.25, 0.2)
		elseif name == "Threshold" then
			pulseHeat()
			if payload == Config.Heat.lockAt then
				shake(0.2, 0.4)
			end
		end
	end)

	-- Your own Snatch prompt is for rivals, so hide it locally
	local function hideOwnSnatch(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local snatch = root and root:WaitForChild("SnatchPrompt", 10)
		if snatch then
			snatch.Enabled = false
			snatch:GetPropertyChangedSignal("Enabled"):Connect(function()
				if snatch.Enabled then
					snatch.Enabled = false
				end
			end)
		end
	end
	player.CharacterAdded:Connect(hideOwnSnatch)
	if player.Character then
		task.spawn(hideOwnSnatch, player.Character)
	end
end

-- Wiring -------------------------------------------------------------------------------

local PANEL_TO_TAB = { Odds = "ODDS", Tackle = "RODS" }

local function refreshAll()
	refreshHUD()
	refreshGreed()
	if menu.Visible then
		refreshers[currentTab]()
	end
end

StateEvent.OnClientEvent:Connect(function(newState)
	state = newState
	refreshAll()
end)

NotifyEvent.OnClientEvent:Connect(toast)

HazardEvent.OnClientEvent:Connect(function(kind, direction)
	if kind == "Hit" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = direction.Unit * Config.Risk.knockback + Vector3.new(0, 25, 0)
		end
	elseif kind == "Riptide" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = direction.Unit * Config.Heat.riptideForce + Vector3.new(0, 18, 0)
		end
		toast("Riptide! The current drags you toward deep water.", "warn")
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local npcId = prompt:GetAttribute("Npc")
	if npcId then
		local npc = Config.Npcs[npcId]
		if npc then
			toast(("%s: %s"):format(npc.name, npc.lines[math.random(1, #npc.lines)]), "info")
			if npc.panel then
				openMenu(npc.panel)
			end
		end
		return
	end
	local panel = prompt:GetAttribute("Panel")
	if panel then
		openMenu(PANEL_TO_TAB[panel] or panel)
	end
end)

selectTab("ODDS")

task.spawn(function()
	local initial = act("GetState")
	if type(initial) == "table" and initial.pearls then
		state = initial
		refreshAll()
	end
end)

-- Beacon countdown between server pushes, and the zone lighting check
task.spawn(function()
	while true do
		task.wait(0.5)
		refreshHUD()
		refreshGreed()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			applyZone((root.Position.X > 55 and not Config.safeZone(root.Position)) and "Shoals" or "Nest")
		end
	end
end)
