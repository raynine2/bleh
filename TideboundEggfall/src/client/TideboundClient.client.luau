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
		haulInfo.Text = ("At risk: %s Pearls of fish and %d egg(s). Extract at a beacon to keep them."):format(fmt(state.carriedPearls), state.carriedEggs)
		haulInfo.TextColor3 = C.warn
	else
		haulInfo.Text = "Nothing at risk. Cast at a glowing spot in the Sunken Shoals or steal a wild egg."
		haulInfo.TextColor3 = C.muted
	end
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
	fishTitle.Text = "Casting" .. (cast.bait and (" with " .. cast.bait) or "") .. "..."
	fishHint.Text = "Wait for the bite."
	task.wait(cast.biteWait)

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
	act("FinishCast", cast.id, caught, perfect)
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

local TABS = {
	{ id = "ODDS", title = "TIDE EGG ODDS" },
	{ id = "PITY", title = "PITY & PULLS" },
	{ id = "RODS", title = "RODS" },
	{ id = "BAIT", title = "BAIT & FISH ODDS" },
	{ id = "CREATURES", title = "CREATURES" },
	{ id = "BESTIARY", title = "BESTIARY" },
}
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
button({ Text = "HATCH 1", Size = UDim2.new(0.3, -8, 0, 38), Position = UDim2.new(0.36, 0, 0.5, -19), Parent = actionRow }, "blue", function()
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

refreshers.ODDS = function()
	eggsLabel.Text = ("x%d TIDE EGGS"):format(state.eggs)
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

local function selectTab(id)
	currentTab = id
	for _, tab in ipairs(TABS) do
		local selected = tab.id == id
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
	tabButtons[tab.id] = button({ Text = tab.id, Size = UDim2.new(1 / #TABS, -10, 1, 0), LayoutOrder = i, TextSize = 13, Parent = tabBar }, "grey", function()
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
	revealDetails.Text = table.concat(lines, "\n")
	revealClose.Visible = true
end

hatch = function()
	local result = act("Hatch")
	if result and result.ok then
		task.spawn(showReveal, result.result)
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

-- Wiring -------------------------------------------------------------------------------

local PANEL_TO_TAB = { Odds = "ODDS", Tackle = "RODS" }

local function refreshAll()
	refreshHUD()
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
	if kind == "Riptide" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = direction.Unit * Config.Heat.riptideForce + Vector3.new(0, 18, 0)
		end
		toast("Riptide! The current drags you toward deep water.", "warn")
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
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
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			applyZone(root.Position.X > 55 and "Shoals" or "Nest")
		end
	end
end)
