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
local CollectionService = game:GetService("CollectionService")

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
local FishingFeel = require(Shared:WaitForChild("FishingFeel")) -- Master Patch 5: TideboundRod reads it
local Fx = require(Shared:WaitForChild("Fx"))
local HatchScene = require(Shared:WaitForChild("HatchScene")) -- Patch 11: the hatch cutscene and the shrine's odds card
local ClientBus = require(Shared:WaitForChild("ClientBus")) -- GDD Section 9: Menu music and UI-bus ducking follow the menu
HatchScene.mountBoards()

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
	-- HUD restyle (12 Oct 2026): the side launcher's green and purple tiles (UiKit), for the HUD boxes
	green = { top = Color3.fromRGB(70, 210, 110), bottom = Color3.fromRGB(26, 150, 70), outline = Color3.fromRGB(130, 255, 170), trophy = Color3.fromRGB(130, 255, 170) },
	purple = { top = Color3.fromRGB(170, 90, 255), bottom = Color3.fromRGB(110, 40, 200), outline = Color3.fromRGB(200, 150, 255), trophy = Color3.fromRGB(200, 150, 255) },
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

-- HUD restyle (12 Oct 2026): the side buttons' look for a HUD box: the tile's top-to-bottom gradient, its light
-- outline, rounded corners and a soft bevel highlight across the top. Returns the outline. `plain` skips the bevel
-- (for boxes whose children a UIListLayout lays out).
local function tileSkin(frame, style, radius, plain)
	local s = TILE[style or "blue"]
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = 0
	corner(radius or 10).Parent = frame
	gloss(s.top, s.bottom).Parent = frame
	local outline = stroke(s.outline, 2.5)
	outline.Parent = frame
	if not plain then
		new("Frame", { Name = "Bevel", BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(1, -6, 0.45, 0), BorderSizePixel = 0, ZIndex = 0, Parent = frame }, {
			corner(math.max(2, (radius or 10) - 3)),
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
		})
	end
	return outline
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

local toastList = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 300), Size = UDim2.new(0, 310, 0.6, 0), ZIndex = 30, Parent = gui }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
})
local toastOrder = 0

local function toast(message, kind)
	toastOrder += 1
	local style = ({ good = "green", bad = "red", warn = "gold", rare = "purple" })[kind] or "blue"
	local t = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = toastOrder, Parent = toastList })
	tileSkin(t, style, 10, true)
	local text = label({ Text = message, Font = DISPLAY, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 15, Parent = t }, { padding(9) })
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
local playAnim -- forward declaration (defined with the minigame)
local situation = nil -- "fishing" while reeling, for the camera (Delta Section 10 Table C)

local hud = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 176, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui }, { list(8) })
new("UIScale", { Scale = 0.8, Parent = hud }) -- 12 Oct: the top-left bars a bit smaller (user ask)

local function pill(order, style, letter, iconName)
	local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = hud })
	tileSkin(frame, style, 10)
	if iconName then
		-- GUI revamp: a painted currency icon that pokes out of the pill's left edge
		require(Shared:WaitForChild("UiIcons")).make(iconName, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.new(0, 34, 0, 34), ZIndex = 3, Parent = frame })
	else
		local icon = new("Frame", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(0, 4, 0.5, -13), BackgroundColor3 = WHITE, Parent = frame }, { corner(5), gloss(TILE[style].top, TILE[style].bottom), stroke(TILE[style].outline, 1.5) })
		label({ Text = letter, Font = DISPLAY, TextSize = 16, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = icon })
	end
	return label({ Font = DISPLAY, TextSize = 18, Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -44, 1, 0), Parent = frame })
end

local pills = {
	pearls = pill(1, "blue", "P", "pearl"),
	shards = pill(2, "gold", "S", "egg"),
	embers = pill(3, "red", "E", "eggshards"),
	tideglass = pill(4, "purple", "T", "gem"),
}
local infoCard = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = hud })
tileSkin(infoCard, "blue", 10, true)
padding(8).Parent = infoCard
list(2).Parent = infoCard
local infoRod = label({ Font = DISPLAY, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 14, LayoutOrder = 1, Parent = infoCard })
local infoIncome = label({ Font = DISPLAY, Size = UDim2.new(1, 0, 0, 17), TextSize = 14, LayoutOrder = 2, Parent = infoCard })

-- Side menu: REF 4 tiles as buttons
local sideMenu = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 80), Size = UDim2.new(0, 74, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui }, { list(10) })
-- GUI revamp (11 Oct): painted icons (UiIcons) instead of emoji; each icon pokes out above its tile and bobs gently
-- (Rotation and Position only, never Size, so no text re-fits).
local sideIcons = { list = {}, UiIcons = require(Shared:WaitForChild("UiIcons")) }
local function sideButton(order, style, text, tab, icon)
	local holder = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(0, 72, 0, 72), LayoutOrder = order, AutoButtonColor = false, Parent = sideMenu })
	local t = tile(holder, style)
	t.frame.Size = UDim2.fromScale(1, 1)
	t.icon:Destroy()
	local image = sideIcons.UiIcons.make(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.86, 0.86), ZIndex = 3, Parent = t.frame })
	table.insert(sideIcons.list, { icon = image, seed = order * 1.7 })
	label({ Text = text, Font = DISPLAY, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = t.frame })
	holder.MouseEnter:Connect(function()
		TweenService:Create(image, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.3) }):Play()
	end)
	holder.MouseLeave:Connect(function()
		TweenService:Create(image, TweenInfo.new(0.2), { Position = UDim2.fromScale(0.5, 0.36) }):Play()
	end)
	holder.Activated:Connect(function()
		openMenu(tab)
	end)
	return holder
end
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, entry in ipairs(sideIcons.list) do
		entry.icon.Rotation = math.sin(t * 1.6 + entry.seed) * 4
	end
end)
local eggsButton = sideButton(1, "gold", "EGGS", "ODDS", "egg")
sideButton(2, "blue", "TACKLE", "RODS", "rod")
sideButton(3, "red", "BOOK", "CREATURES", "book")
sideButton(4, "blue", "HOME", "BASE", "house")
sideButton(5, "gold", "DASH", "DASHES", "bolt") -- Patch 20
local eggBadge = new("Frame", { Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -16, 0, -8), BackgroundColor3 = C.neon, ZIndex = 4, Parent = eggsButton }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(WHITE, 2) })
local eggBadgeText = label({ Font = DISPLAY, TextSize = 14, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = eggBadge })

-- Heat meter (Patch 17): a slim pill at the top that only appears on a dive or while something is at stake, with
-- small chips under it for what matters right now (health, cargo, eggs, the guardian's phase, closed beacons...).
-- The long explanations went: crossing a heat threshold already pops a toast.
local heatFrame = new("Frame", { Name = "HeatHud", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 340, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = gui })
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = heatFrame })
local heatPill = new("Frame", { Name = "Pill", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = heatFrame })
tileSkin(heatPill, "blue", 10)
label({ Text = "🔥", TextSize = 18, Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(0, 8, 0, 0), TextXAlignment = Enum.TextXAlignment.Center, Parent = heatPill })
label({ Font = DISPLAY, Text = "HEAT", TextSize = 15, Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(0, 36, 0, 0), Parent = heatPill }, { textStroke(1) })
local heatTrack = new("Frame", { Position = UDim2.new(0, 84, 0.5, -6), Size = UDim2.new(1, -134, 0, 12), BackgroundColor3 = Color3.fromRGB(12, 40, 110), Parent = heatPill }, { corner(6), stroke(Color3.fromRGB(8, 28, 80), 1.5) })
local heatFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(90, 190, 255), Parent = heatTrack }, { corner(6), new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 200)) }) })
for _, mark in ipairs({ 25, 50, 75 }) do
	new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.new(mark / 100, -1, 0, 0), BackgroundColor3 = Color3.fromRGB(16, 20, 32), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 2, Parent = heatTrack })
end
local heatValue = label({ Font = DISPLAY, TextSize = 18, Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -46, 0, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = heatPill }, { textStroke(1) })
local chipRow = new("Frame", { Name = "Chips", Size = UDim2.new(1, 120, 0, 24), BackgroundTransparency = 1, LayoutOrder = 2, Parent = heatFrame }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local chips = {}
local function chip(id, order, text, color, visible)
	local c = chips[id]
	if not c then
		c = new("Frame", { Name = id, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, LayoutOrder = order, Parent = chipRow }, {
			corner(10),
			gloss(TILE.blue.top, TILE.blue.bottom),
			new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
		c:SetAttribute("Stroke", true)
		new("UIStroke", { Color = WHITE, Thickness = 2, Parent = c })
		label({ Name = "Text", Font = DISPLAY, TextSize = 14, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = c }, { textStroke(1) })
		chips[id] = c
	end
	c.Visible = visible ~= false
	if c.Visible then
		local t = c:FindFirstChild("Text")
		t.Text = text
		t.TextColor3 = color or C.text
		c.UIStroke.Color = color or WHITE
	end
	return c
end
local heatShown = false
local function showHeat(show)
	if show == heatShown then
		return
	end
	heatShown = show
	if show then
		heatFrame.Visible = true
		heatFrame.Position = UDim2.new(0.5, 0, 0, -70)
		TweenService:Create(heatFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 8) }):Play()
	else
		local tween = TweenService:Create(heatFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -70) })
		tween:Play()
		tween.Completed:Connect(function()
			if not heatShown then
				heatFrame.Visible = false
			end
		end)
	end
end
local HEAT_COLORS = { Color3.fromRGB(90, 190, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 120, 50), Color3.fromRGB(255, 60, 60) }
local hudExtra = {}
do
	hudExtra.weather = label({ Size = UDim2.new(1, 60, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = DISPLAY, TextSize = 14, TextColor3 = Color3.fromRGB(150, 230, 255), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Visible = false, Parent = heatFrame }, { textStroke(1.5) })
	-- vial buttons under the currency pills: Mending during a dive, Revive whenever a companion is out
	local vialRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 6, Visible = false, Parent = hud })
	hudExtra.vialRow = vialRow
	hudExtra.mend = button({ Size = UDim2.new(1, 0, 1, 0), TextSize = 13, Parent = vialRow }, "blue", function()
		act("UseVial", "Mending")
	end)
	hudExtra.revive = button({ Size = UDim2.new(1, 0, 1, 0), TextSize = 13, Parent = vialRow }, "gold", function()
		act("UseVial", "Revive")
	end)
	hudExtra.reveal = function(_result) end -- the fish reveal (Master Patch 6), set further down
	hudExtra.clock = function(seconds)
		seconds = math.max(0, math.ceil(seconds))
		return ("%d:%02d"):format(seconds // 60, seconds % 60)
	end
end

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
	local dura = state.rodDura[state.rod] or Config.Durability.max
	infoRod.Text = (rod and rod.name or "?") .. (state.rodBroken and " BROKEN" or (" %d%%"):format(dura)) .. (bait and (" · %s x%d"):format(bait.name, state.baitInv[state.bait] or 0) or " · no bait")
	infoRod.TextColor3 = state.rodBroken and C.bad or (dura < 25 and C.warn or C.text)
	infoIncome.Text = ("Aquarium +%.1f Pearls/min"):format(state.incomePerMin)
	eggBadge.Visible = state.eggs > 0
	eggBadgeText.Text = state.eggs > 99 and "99+" or tostring(state.eggs)

	local now = workspace:GetServerTimeNow()
	local heat = state.heat
	local closed = state.beaconsClosedUntil - now
	local atStake = state.carriedPearls > 0 or state.carriedEggs > 0 or state.bankedPearls > 0
	showHeat(state.started or heat > 0 or atStake or state.health < state.maxHealth or state.locked or closed > 0)
	TweenService:Create(heatFill, TweenInfo.new(0.3), { Size = UDim2.new(heat / Config.Heat.max, 0, 1, 0) }):Play()
	local band = heat >= 100 and 4 or heat >= 75 and 3 or heat >= 50 and 2 or heat >= 25 and 2 or 1
	heatFill.BackgroundColor3 = heat >= 25 and heat < 50 and HEAT_COLORS[1]:Lerp(HEAT_COLORS[2], 0.5) or HEAT_COLORS[band]
	heatValue.Text = tostring(heat)
	heatValue.TextColor3 = heat >= 75 and C.bad or heat >= 50 and C.warn or C.text

	-- the chips: only what matters right now
	chip("hp", 1, ("❤ %d"):format(state.health), state.health < state.maxHealth * 0.35 and C.bad or (state.health < state.maxHealth and C.warn or C.good), state.health < state.maxHealth or state.started)
	chip("fish", 2, ("🐟 %d · %s"):format(state.carriedFish, fmt(state.carriedPearls)), C.warn, state.carriedPearls > 0)
	chip("eggs", 3, ("🥚 %d"):format(state.carriedEggs), C.warn, state.carriedEggs > 0)
	chip("banked", 4, ("✔ %s banked"):format(fmt(state.bankedPearls)), C.good, state.bankedPearls > 0 and state.carriedPearls == 0)
	chip("cargo", 5, ("x%.1f cargo"):format(state.cargoMult), C.gold, state.cargoMult > 1)
	chip("phase", 6, ("%s P%d"):format(state.depth == 2 and "LEVIATHAN" or "WARDEN", state.phase), C.bad, state.phase > 0)
	chip("locked", 7, "LOCKED ON", C.bad, state.locked)
	chip("stun", 8, "STUNNED", C.warn, state.stunUntil > now)
	local closedText = ("BEACONS CLOSED %ds"):format(math.max(0, math.ceil(closed)))
	if state.graceUntil > now then
		closedText ..= (" · GRACE %ds"):format(math.ceil(state.graceUntil - now))
	end
	chip("closed", 9, closedText, C.bad, closed > 0)
	chip("depth", 10, state.biomeName or "", Color3.fromRGB(140, 255, 220), state.started and (state.depth or 1) > 1)
	chip("contested", 11, "CONTESTED", Color3.fromRGB(255, 140, 200), (state.started and state.runContested) or (not state.started and state.contested))
	chip("debt", 12, ("Carried heat %d"):format(state.heatDebt), C.warn, state.heatDebt > 0)
	chip("immune", 13, "Snatch immune", C.good, state.immuneUntil > now)
	chip("mode", 14, ("%s x%.2f"):format(state.mode, state.modeMult), C.muted, state.started)
	local lockPulse = state.locked and (0.2 + 0.2 * math.sin(os.clock() * 8)) or 0
	heatPill.BackgroundTransparency = lockPulse

	-- Glass Calm banner from its 20 s warning until it ends
	local weather = state.weather
	hudExtra.weather.Visible = weather ~= nil and now < weather.endsAt
	if hudExtra.weather.Visible then
		local glass = Config.Weather.GlassCalm
		local faster = math.floor((1 - glass.biteMult) * 100 + 0.5)
		if now < weather.startsAt then
			hudExtra.weather.Text = ("%s in %ds: bites %d%% faster, no riptide"):format(weather.name:upper(), math.ceil(weather.startsAt - now), faster)
		else
			hudExtra.weather.Text = ("%s %s: bites %d%% faster, no riptide, first catch +%d %s"):format(weather.name:upper(), hudExtra.clock(weather.endsAt - now), faster, glass.reward.count, Config.BaitById[glass.reward.bait].name)
		end
	end

	-- vials: Mending on a dive, Revive while a companion is knocked out
	local knockedOut = false
	for _, slot in ipairs(state.companions.slots) do
		if slot.name ~= "" and slot.koLeft > 0 then
			knockedOut = true
		end
	end
	local showMend = state.started and (state.vials.Mending or 0) > 0
	local showRevive = knockedOut and (state.vials.Revive or 0) > 0
	local both = showMend and showRevive
	hudExtra.vialRow.Visible = showMend or showRevive
	hudExtra.mend.Visible = showMend
	hudExtra.revive.Visible = showRevive
	hudExtra.mend.Size = UDim2.new(both and 0.5 or 1, both and -3 or 0, 1, 0)
	hudExtra.revive.Size = hudExtra.mend.Size
	hudExtra.revive.Position = UDim2.new(both and 0.5 or 0, both and 3 or 0, 0, 0)
	hudExtra.mend.Text = ("MEND x%d"):format(state.vials.Mending or 0)
	hudExtra.revive.Text = ("REVIVE x%d"):format(state.vials.Revive or 0)
	local spent = state.started and state.vialsUsed >= Config.VialsPerRun
	restyle(hudExtra.mend, spent and "grey" or "blue")
	restyle(hudExtra.revive, spent and "grey" or "gold")
end

-- Fishing minigame (Fisch-style: hold to push the bar, keep the fish inside it) ---

-- Reel bar look (HJHJH's reference picture, 2026-10-12): a long dark track with small grey arrow caps
-- at both ends, a white catch zone with an arrow inside, a thin slate fish line with a faint blue fish
-- above it, and a thin progress bar underneath. No title or hint text.
local REEL_TRACK = Color3.fromRGB(46, 42, 38)
local REEL_PROGRESS_BG = Color3.fromRGB(44, 39, 36)
local fishFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.new(0, 540, 0, 64), BackgroundTransparency = 1, Visible = false, Parent = gui })
local fishTitle = label({ Visible = false, Parent = gui })
local reelTrack = new("Frame", { Name = "ReelTrack", Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(1, -40, 0, 20), BackgroundColor3 = REEL_TRACK, BorderSizePixel = 0, Parent = fishFrame }, { corner(2) })
for i, cap in ipairs({ "▶", "◀" }) do
	label({ Name = "ArrowCap", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(i == 1 and 0 or 1, i == 1 and -13 or 13, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), Text = cap, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(82, 76, 68), TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = reelTrack })
end
-- the white catch zone sits 2 px proud of the track on both edges
local reelBar = new("Frame", { Name = "CatchZone", Position = UDim2.new(0, 0, 0, -2), Size = UDim2.new(0.18, 0, 1, 4), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = reelTrack }, { corner(2), stroke(Color3.fromRGB(225, 222, 218), 1, 0.3) })
local reelArrow = label({ Name = "Arrow", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 22, 0, 22), Text = "→", Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = Color3.fromRGB(134, 132, 133), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 3, Parent = reelBar })
local sweetSpot = new("Frame", { Visible = false, Parent = reelBar })
local treasure = label({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 20, 0, 20), Text = "✦", TextSize = 22, TextColor3 = Color3.fromRGB(255, 214, 70), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 5, Visible = false, Parent = reelTrack })
local comboLabel = label({ Visible = false, Parent = gui })
-- the fish: a thin slate line through the bar with a faint blue fish shape hovering above it
local fishIcon = new("Frame", { Name = "FishLine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 4, 1, 8), BackgroundColor3 = Color3.fromRGB(62, 66, 82), BorderSizePixel = 0, ZIndex = 4, Parent = reelTrack }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Color3.fromRGB(150, 160, 185), 1, 0.55) })
local fishGhost = new("Frame", { Name = "FishGhost", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 2, 0, 1), Size = UDim2.new(0, 13, 0, 26), Rotation = 18, BackgroundColor3 = Color3.fromRGB(125, 152, 210), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 3, Parent = fishIcon }, {
	new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 0.9) }) }),
})
local progressTrack = new("Frame", { Name = "ReelProgress", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.new(0, 274, 0, 5), BackgroundColor3 = REEL_PROGRESS_BG, BorderSizePixel = 0, Visible = false, Parent = fishFrame }, { corner(1), stroke(Color3.fromRGB(215, 208, 202), 1, 0.25) })
local progressFill = new("Frame", { Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(205, 201, 197), BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = progressTrack }, { corner(1) })
local fishHint = label({ Visible = false, Parent = gui })

-- Patch 10: only touches the game didn't take (the thumbstick and buttons) count as holding the reel
local touches = {}
UserInputService.TouchStarted:Connect(function(input, processed)
	if not processed then
		touches[input] = true
	end
end)
UserInputService.TouchEnded:Connect(function(input)
	touches[input] = nil
end)

local function isHolding()
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		or next(touches) ~= nil
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
end

-- Little bubbles that rise through the reel track while you fight a fish.
local function trackBubble(x, color)
	do
		return -- the reference reel bar is clean, so no bubbles on the track
	end
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, 1, 0), Size = UDim2.new(0, 6, 0, 6), BackgroundColor3 = color or WHITE, BackgroundTransparency = 0.3, ZIndex = 2, Parent = reelTrack }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	TweenService:Create(b, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(x + (math.random() - 0.5) * 0.04, 0, 0, 0), BackgroundTransparency = 1, Size = UDim2.new(0, 10, 0, 10) }):Play()
	task.delay(0.85, function()
		b:Destroy()
	end)
end

local function punch(frame, amount)
	local scale = frame:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = frame })
	scale.Scale = 1 + amount
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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

-- Fisch video (12 Oct 2026): the power cast's rating, SHAKE buttons, the reel bar's extra lines and the quick catch
hudExtra.fisch = require(Shared:WaitForChild("FischUI"))

local fishing = false
local function runMinigame(cast)
	-- a cast can arrive as the last reveal is closing; let that finish first
	local waited = 0
	while fishing and waited < 5 do
		waited += task.wait(0.1)
	end
	if fishing then
		return
	end
	fishing = true
	FishingFeel.busy = true -- TideboundFischCast won't start another cast until this one is over
	local castStarted = os.clock()
	local f = Config.Fishing
	fishFrame.Visible = true
	reelTrack.Visible, progressTrack.Visible = false, false
	fishTitle.TextColor3 = C.text
	fishTitle.Text = (cast.pier and "Pier cast" or "Casting") .. (cast.bait and (" with " .. cast.bait) or "") .. "..."
	fishHint.Text = cast.broken and "Wait for the bite. Your rod is broken, so it fishes like a Drift Rod until Old Harl repairs it." or "Wait for the bite."
	-- Fisch video: a power cast's rating (TideboundFischCast) speeds up the reel, and its windup already played
	local rating = os.clock() - (FishingFeel.castAt or 0) < 3 and FishingFeel.castRating or nil
	local fromCharge = FishingFeel.phase == "charge"
	-- Master Patch 5: windup, release and landing take 0.9 s, then the rod idles until the bite
	FishingFeel.cast, FishingFeel.result, FishingFeel.tension = cast, nil, 0
	FishingFeel.set("cast")
	if fromCharge then
		FishingFeel.startedAt -= 18 / 60 -- straight into the release
	end
	FishingFeel.castRating = nil
	situation = "fishing"
	-- osu! SHAKE (13 Oct 2026, HJHJH): while you wait, numbered circles pop up with rings closing in
	-- (FischUI.osu); hit each as its ring meets it. Rarer fish bring more circles, faster rings and bigger jumps.
	-- Every hit shakes the rod; the bite comes as the chart ends (never before the 35% of the wait the server
	-- allows). 13 Oct 2026 (HJHJH): the circles only come here, at the start, and a good SHAKE is a bonus, never
	-- a penalty: 95%+ accuracy gives +25% progress speed on the reel, 85% +15%, 70% +8%.
	task.wait(0.9)
	local Rfx = require(Shared.RodFx)
	local rodId = cast.rod or "Drift"
	local tierColor = (Config.Tiers[cast.difficulty] or Config.Tiers[1]).color
	fishHint.Text = "SHAKE! Click each circle as its ring closes in."
	local shakeScore = hudExtra.fisch.osu(hudExtra.fisch.chart(cast.difficulty), tierColor, "SHAKE", function(judge)
		if judge.score > 0 then
			FishingFeel.shake(0.04 + judge.score / 300 * 0.05, 0.12)
			if typeof(cast.spot) == "Vector3" then
				require(Shared.WaterFx).droplets(cast.spot + Vector3.new(0, 0.3, 0), 8, 7, 45, 0.12)
				if judge.score == 300 then
					Rfx.burst(cast.spot + Vector3.new(0, 0.8, 0), rodId, 0.6)
				end
			end
		else
			FishingFeel.shake(0.1, 0.15)
		end
	end)
	local shakeBonus = shakeScore.accuracy >= 0.95 and 0.25 or shakeScore.accuracy >= 0.85 and 0.15 or shakeScore.accuracy >= 0.7 and 0.08 or 0
	if shakeBonus > 0 then
		hudExtra.fisch.word(("+%d%% Speed!"):format(math.floor(shakeBonus * 100 + 0.5)), Color3.fromRGB(130, 255, 150))
	end
	local biteFloor = castStarted + math.max(cast.biteWait * 0.35, 0.9) + 0.05
	while os.clock() < biteFloor do
		task.wait()
	end

	-- the bite tell and the hook set (18 frames) come before the reel bar
	FishingFeel.set("bite")
	-- the camera punches in, the screen jolts and the rod tip bursts in its colours
	Rfx.kick(-5, 0.22, 0.35)
	do
		local tip = Rfx.tipOf(player.Character)
		if tip then
			Rfx.burst(tip, rodId, 0.8)
		end
	end
	fishTitle.Text = "BITE! Reel it in!"
	fishTitle.TextColor3 = C.gold
	-- Patch 10: the bite pops the panel
	punch(fishFrame, 0.12)
	task.wait(0.3)
	FishingFeel.set("reel")
	fishHint.Text = "Hold click (or touch) to push the bar right. Keep the fish inside it."
	reelTrack.Visible, progressTrack.Visible = true, true
	hudExtra.fisch.reelShow(fishFrame, (rating and rating.bonus or 0) + shakeBonus, cast.plus and cast.plus.total or nil, cast.plus and cast.plus.roamer or nil)
	local rng = Random.new()
	-- 13 Oct 2026: rarer fish give you a narrower bar (a Celestial's is 27% narrower than a Common's)
	local barWidth = math.clamp(f.baseBarWidth * cast.control * (1 - 0.045 * (cast.difficulty - 1)), f.barMin, f.barMax)
	reelBar.Size = UDim2.new(barWidth, 0, 1, 0)
	local barPos, barVel = 0.5 - barWidth / 2, 0
	local fishPos, fishTarget, retarget = 0.5, 0.5, 0.6
	local fishSpeed = f.fishBaseSpeed + f.fishSpeedPerDifficulty * cast.difficulty
	local progress = f.startProgress
	local peak = progress
	local perfect = true
	local started = os.clock()
	local caught
	local milestones = { 0.5, 0.75, 0.9 }
	local cheers = { "Halfway! Keep it there!", "Almost! Don't let go!", "One more pull!" }
	FishingFeel.progress, FishingFeel.milestone = progress, 0
	-- Patch 10: the sweet spot, treasure pearls, a gentle assist and a fish that tires at each milestone
	local tiredUntil = 0
	local treasureAt, treasureUntil = nil, 0
	local nextTreasure = os.clock() + rng:NextNumber(f.treasureEvery[1], f.treasureEvery[2])
	local sweetTime = 0
	local nextBubble = 0
	local spot = cast.spot
	treasure.Visible = false
	comboLabel.Text = ""
	-- Fishing Fight (12 Oct 2026): rarer fish fight longer, and every few seconds the fish warns (a splash and a
	-- red "!!" over it in the water, TideboundRod) and then lunges hard for the far side. Keep it in the bar
	-- through the whole lunge for a burst of progress. TideboundRod reads FishingFeel to move the fish in the
	-- water and to pose you straining against it.
	-- a fight lasts about 3 s for a Common and 6 s for a Celestial (it was over in about a second), and the fish
	-- swims a third faster, so even a wide bar has to chase it
	local fightGain = f.gainPerSecond * 0.5 / (1 + 0.12 * cast.difficulty)
	fightGain *= 1 + (rating and rating.bonus or 0) + shakeBonus -- "+X% Progress Speed": a good cast and a good SHAKE
	fishSpeed *= 1.3
	local nextThrash = os.clock() + rng:NextNumber(0.8, 1.4)
	local thrashWarnAt, thrashUntil, thrashHeld = nil, 0, true
	FishingFeel.thrash, FishingFeel.thrashAt, FishingFeel.heldAt = 0, 0, 0
	FishingFeel.fishPos, FishingFeel.barPos, FishingFeel.barWidth = fishPos, barPos, barWidth

	while true do
		local dt = RunService.RenderStepped:Wait()
		barVel += (isHolding() and f.reelAccel or -f.reelAccel) * dt
		-- while the fish is in the bar the bar leans toward it a little, so small slips don't cost you
		local barCenter = barPos + barWidth / 2
		if math.abs(fishPos - barCenter) < barWidth / 2 + f.edgeGrace then
			barVel += (fishPos - barCenter) * f.assist * dt
		end
		barVel = math.clamp(barVel * (1 - math.min(1, f.barDamping * dt)), -f.barMaxSpeed, f.barMaxSpeed)
		barPos += barVel * dt
		if barPos < 0 then
			barPos, barVel = 0, 0
		elseif barPos > 1 - barWidth then
			barPos, barVel = 1 - barWidth, 0
		end
		retarget -= dt
		if retarget <= 0 then
			fishTarget = math.clamp(fishPos + rng:NextNumber(-f.fishJump, f.fishJump), 0.05, 0.95)
			retarget = rng:NextNumber(0.6, math.max(0.9, 2.2 - cast.difficulty * 0.15))
		end
		local fightNow = os.clock()
		if not thrashWarnAt and fightNow >= nextThrash and progress < 0.95 then
			thrashWarnAt = fightNow
			FishingFeel.thrash, FishingFeel.thrashAt = 1, fightNow
		elseif thrashWarnAt and FishingFeel.thrash == 1 and fightNow - thrashWarnAt >= 0.55 then
			FishingFeel.thrash, FishingFeel.thrashAt = 2, fightNow
			thrashUntil = fightNow + 0.6 + 0.08 * cast.difficulty
			fishTarget = fishPos < 0.5 and rng:NextNumber(0.78, 0.95) or rng:NextNumber(0.05, 0.22)
			retarget = thrashUntil - fightNow + 0.25
			thrashHeld = true
		elseif FishingFeel.thrash == 2 and fightNow >= thrashUntil then
			if thrashHeld then
				progress += 0.06
				FishingFeel.heldAt = fightNow
				punch(fishFrame, 0.06)
			end
			FishingFeel.thrash = 0
			thrashWarnAt = nil
			nextThrash = fightNow + math.max(1.0, rng:NextNumber(1.6, 3.0) - 0.16 * cast.difficulty)
		end
		local speedNow = os.clock() < tiredUntil and fishSpeed * f.tiredMult or fishSpeed
		if FishingFeel.thrash == 2 then
			speedNow = math.max(fishSpeed * 2.6, 0.75)
		end
		fishPos += math.clamp(fishTarget - fishPos, -speedNow * dt, speedNow * dt)
		local inside = fishPos >= barPos - f.edgeGrace and fishPos <= barPos + barWidth + f.edgeGrace
		if FishingFeel.thrash == 2 and not inside then
			thrashHeld = false
		end
		FishingFeel.fishPos, FishingFeel.barPos = fishPos, barPos
		local sweet = inside and math.abs(fishPos - (barPos + barWidth / 2)) <= barWidth * f.sweetSpot / 2
		if inside then
			progress += fightGain * (sweet and f.sweetMult or 1) * dt
			sweetTime = sweet and sweetTime + dt or 0
		else
			sweetTime = 0
			progress -= f.lossPerSecond / cast.resilience * dt
			perfect = false
		end
		-- the rod bends 0.6 while the fish sits in the bar and up to 0.9 as it pulls away; the screen shakes
		-- with it, harder for rarer fish
		local away = inside and 0 or math.clamp(0.5 + math.min(math.abs(fishPos - barPos), math.abs(fishPos - barPos - barWidth)) * 2, 0, 1)
		FishingFeel.tension += (away - FishingFeel.tension) * math.min(1, dt * 6)
		FishingFeel.shake(0.015 + 0.04 * FishingFeel.tension * (0.6 + 0.15 * cast.difficulty), 0.05)
		FishingFeel.progress = progress
		local clock = os.clock()
		reelBar.Position = UDim2.new(barPos, 0, 0, -2)
		-- the white zone stays solid while you hold the fish and dims a touch when it slips out;
		-- its arrow points the way the bar is moving
		reelBar.BackgroundColor3 = inside and WHITE or Color3.fromRGB(236, 234, 232)
		reelArrow.Text = barVel < -0.02 and "←" or "→"
		reelArrow.Position = barVel < -0.02 and UDim2.new(0, 30, 0.5, 0) or UDim2.new(1, -8, 0.5, 0)
		fishIcon.Position = UDim2.new(fishPos, 0, 0.5, 0)
		fishGhost.Rotation = 18 + math.sin(clock * 11) * (8 + 20 * FishingFeel.tension)
		fishGhost.Position = UDim2.new(0.5, 2, 0, 1 + math.sin(clock * 17) * (1 + 2 * FishingFeel.tension))
		progressFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		FishingFeel.sweet = sweet
		sweetSpot.BackgroundTransparency = sweet and (0.15 + 0.15 * math.sin(clock * 14)) or 0.55
		comboLabel.Text = sweetTime > 0.4 and ("SWEET x%.1f"):format(f.sweetMult) or ""
		if clock >= nextBubble then
			nextBubble = clock + (inside and 0.08 or 0.25)
			trackBubble(fishPos, sweet and Color3.fromRGB(255, 236, 140) or (inside and Color3.fromRGB(200, 255, 220) or Color3.fromRGB(255, 190, 190)))
		end
		-- a treasure pearl floats up somewhere on the track: cover it with the bar to grab a burst of progress
		if not treasureAt and clock >= nextTreasure then
			treasureAt = rng:NextNumber(0.08, 0.92)
			treasureUntil = clock + f.treasureLife
			treasure.Position = UDim2.new(treasureAt, 0, 0.5, 0)
			treasure.Visible = true
			treasure.TextTransparency = 0
		end
		if treasureAt then
			treasure.Rotation = clock * 120
			treasure.TextSize = 22 + 4 * math.sin(clock * 10)
			if treasureAt >= barPos and treasureAt <= barPos + barWidth then
				progress += f.treasureGain
				treasureAt = nil
				treasure.Visible = false
				nextTreasure = clock + rng:NextNumber(f.treasureEvery[1], f.treasureEvery[2])
				fishTitle.Text = ("TREASURE! +%d%%"):format(math.floor(f.treasureGain * 100))
				fishTitle.TextColor3 = C.gold
				punch(fishFrame, 0.08)
				for _ = 1, 6 do
					trackBubble(rng:NextNumber(barPos, barPos + barWidth), Color3.fromRGB(255, 214, 70))
				end
				if spot then
					-- 12 Oct 2026: a gold glimmer off the water (HJHJH didn't like the cube bursts)
					require(Shared.WaterFx).glimmer(spot + Vector3.new(0, 1, 0), Color3.fromRGB(255, 214, 70), 1.4)
				end
			elseif clock >= treasureUntil then
				treasureAt = nil
				treasure.Visible = false
				nextTreasure = clock + rng:NextNumber(f.treasureEvery[1], f.treasureEvery[2])
			end
		end
		local nextMilestone = milestones[FishingFeel.milestone + 1]
		if nextMilestone and progress >= nextMilestone then
			-- TideboundRod bursts at the bobber; the progress bar flashes gold and the fish tires for a moment
			FishingFeel.milestone += 1
			tiredUntil = clock + f.tiredSeconds
			progressTrack.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
			TweenService:Create(progressTrack, TweenInfo.new(0.4), { BackgroundColor3 = REEL_PROGRESS_BG }):Play()
			fishTitle.Text = cheers[FishingFeel.milestone]
			fishTitle.TextColor3 = C.gold
			punch(fishFrame, 0.06)
		end
		if os.clock() < tiredUntil then
			fishHint.Text = "The fish is tiring! Reel now!"
		elseif sweet then
			fishHint.Text = "Sweet spot! Keep the fish in the gold stripe to reel faster."
		else
			fishHint.Text = perfect and "PERFECT so far! The fish hasn't slipped once." or "Hold to push the bar right, let go to drift left. Grab the ✦ for a bonus!"
		end
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
	reelTrack.Visible, progressTrack.Visible = false, false
	hudExtra.fisch.reelHide()
	treasure.Visible = false
	comboLabel.Text = ""
	fishHint.Text = ""
	FishingFeel.sweet = false
	FishingFeel.thrash = 0
	if caught then
		punch(fishFrame, 0.15)
		-- the server checks a catch can't be quicker than the bite plus a moment; hold the fish until then
		local earliest = math.max(cast.biteWait * 0.35, 0.9) + f.minReelSeconds + 0.2
		local waitFor = earliest - (os.clock() - castStarted)
		if waitFor > 0 then
			fishHint.Text = "Landing it..."
			task.wait(waitFor)
		end
	end
	if not caught then
		FishingFeel.set("break")
	end
	local result = act("FinishCast", cast.id, caught, perfect, peak)
	if caught and type(result) == "table" and result.caught then
		-- Master Patches 5 and 6: the fish flips into your hands, then the reveal plays
		FishingFeel.result = result
		FishingFeel.set("land")
		-- Fisch video: the quick catch (the fish held over your head in a burst of light, a word over you and
		-- lines along the bottom) replaces the long cinematic reveal (hudExtra.reveal stays, unused)
		fishFrame.Visible = false
		-- Catch a Brainrot style: the camera punches in as the fish flies out, then out with a shake and a burst
		-- in your rod's colours as it lands in your hands (bigger for rarer fish)
		local catchTier = math.clamp(tonumber(result.tier) or 1, 1, 7)
		Rfx.kick(-6, 0.15, 0.5)
		task.delay(0.95, function()
			Rfx.kick(6 + catchTier, 0.15 + 0.05 * catchTier, 0.5)
			local character = player.Character
			local head = character and character:FindFirstChild("Head")
			if head then
				Rfx.burst(head.Position + Vector3.new(0, 1.8, 0), rodId, 1 + 0.25 * catchTier)
			end
		end)
		hudExtra.fisch.catch(result)
		task.spawn(act, "RevealDone")
		situation = nil
	else
		if caught then
			FishingFeel.set("break")
			fishTitle.TextColor3 = C.bad
			fishTitle.Text = "The line snapped..."
		end
		situation = nil
		task.wait(1.2)
	end
	FishingFeel.set("")
	FishingFeel.result = nil
	fishFrame.Visible = false
	fishing = false
	FishingFeel.busy = false
	FishingFeel.castLockUntil = os.clock() + 0.4
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
	ClientBus.setMenu("Main", false)
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
	{ id = "DIVE", title = "DIVE & CREW", group = "home" },
	{ id = "DASHES", title = "DASHES", group = "dash" }, -- Patch 20
	{ id = "CAPSULES", title = "DASH CAPSULE ODDS", group = "dash" },
	{ id = "TRIALS", title = "ROD TRIALS", group = "dash" }, -- Patch 21
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
local RodSkillsLib = require(Shared:WaitForChild("RodSkills")) -- Patch 21: each rod's ability (R)
local rodsPage = makePage("RODS")
section(rodsPage, "RODS · locked stats, bought with Pearls")
local rodRows = {}
for i, rod in ipairs(Config.Rods) do
	local row = rowFrame(rodsPage, 56)
	label({ Text = rod.name, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 5), Size = UDim2.new(0.66, -12, 0, 22), TextSize = 17, Parent = row })
	label({ Text = ("R: %s · Lure %.2fx · Luck %.2fx · Control %.2fx · Resil %.2fx · %d biomes"):format(RodSkillsLib.get(rod.id).name, rod.lureSpeed, rod.luck, rod.control, rod.resilience, rod.biomes), Position = UDim2.new(0, 12, 0, 28), Size = UDim2.new(0.66, -12, 0, 24), TextSize = 12, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
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
		elseif rod.trial then
			b.Text = "ROD TRIAL"
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

do
	-- Master Patch 2: rod durability and Old Harl's repairs, pinned above the rack
	local D = Config.Durability
	local repairRow = rowFrame(rodsPage, 54)
	repairRow.LayoutOrder = -1
	local duraTitle = label({ Font = DISPLAY, TextSize = 16, Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.64, -12, 0, 22), Parent = repairRow })
	local duraFill = bar(repairRow, UDim2.new(0, 12, 0, 32), UDim2.new(0.64, -24, 0, 10), "blue")
	local repairButton = button({ Size = UDim2.new(0.36, -10, 0, 36), Position = UDim2.new(0.64, 0, 0.5, -18), TextSize = 13, Parent = repairRow }, "gold", function()
		act("RepairRod")
	end)
	note(rodsPage, ("Durability: -%d per cast and -%d when a fish snaps the line. A broken rod fishes like a Drift Rod until Old Harl repairs it, for Pearls only. Swap rods between dives."):format(D.perCast, D.perSnap))
	local rodsRefresh = refreshers.RODS
	refreshers.RODS = function()
		rodsRefresh()
		local rod = Config.RodsById[state.rod] or Config.Rods[1]
		local dura = state.rodDura[rod.id] or D.max
		duraTitle.Text = ("%s · durability %d/%d%s"):format(rod.name, dura, D.max, state.rodBroken and " · BROKEN" or "")
		duraTitle.TextColor3 = state.rodBroken and C.bad or (dura < 25 and C.warn or C.text)
		duraFill.Size = UDim2.new(math.clamp(dura / D.max, 0, 1), 0, 1, 0)
		if dura >= D.max then
			repairButton.Text = "FULL"
			restyle(repairButton, "grey")
		else
			local cost = math.ceil(D.repairCost[rod.id] * (D.max - dura) / D.max)
			repairButton.Text = ("REPAIR · %s P"):format(fmt(cost))
			restyle(repairButton, state.pearls >= cost and "gold" or "grey")
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
local fishOddsRows = {} -- [biome index][tier index]: each built biome's odds (deeper biomes multiply your luck)
for b, biome in ipairs(Config.Biomes) do
	if biome.built and biome.fish then
		if b > 1 then
			divider(baitPage)
		end
		section(baitPage, ("%s FISH ODDS · with your rod and bait%s"):format(biome.name:upper(), (biome.luck or 1) ~= 1 and (" · luck x%.1f here"):format(biome.luck) or ""))
		fishOddsRows[b] = {}
		for i, tier in ipairs(Config.Tiers) do
			local row = rowFrame(baitPage, 28)
			label({ Text = tier.id, Font = DISPLAY, TextColor3 = tier.color, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), TextSize = 14, Parent = row })
			fishOddsRows[b][i] = label({ Font = DISPLAY, Position = UDim2.new(0.26, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), TextSize = 14, Parent = row })
			label({ Text = ("%s · %d Pearls"):format(table.concat(biome.fish[i], ", "), tier.fishPearls), Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -10, 1, 0), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
		end
	end
end
do
	-- Master Patch 6: fish roll the same mutation table as eggs, so its odds are shown here too
	local parts = {}
	for _, m in ipairs(Config.Mutations) do
		table.insert(parts, m.id == "None" and ("None %g%%"):format(m.rate) or ("%s %g%% x%.2f"):format(m.id, m.rate, m.mult))
	end
	note(baitPage, ("Every catch also rolls the mutation table: %s. A mutation multiplies the fish's Pearls, still capped at %d per fish. Weight is for show and never changes Pearls."):format(table.concat(parts, ", "), Config.Tiers[#Config.Tiers].fishPearls))
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
	for b, rows in pairs(fishOddsRows) do
		local fishOdds = Gacha.fishOdds(rod.luck * (bait and bait.luck or 1) * (Config.Biomes[b].luck or 1))
		for i, labelInst in ipairs(rows) do
			labelInst.Text = pct(fishOdds[i])
		end
	end
end

do
	-- Master Patch 2: Nim's vials, Pearls only, up to 3 used per dive
	divider(baitPage)
	section(baitPage, ("VIALS · Pearls only, up to %d per dive"):format(Config.VialsPerRun))
	local vialRows = {}
	for _, vial in ipairs(Config.Vials) do
		local row = rowFrame(baitPage, 56)
		label({ Text = vial.name, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 5), Size = UDim2.new(0.5, -12, 0, 22), TextSize = 16, Parent = row })
		local owned = label({ Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(0.5, -12, 0, 20), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
		local buy = button({ Size = UDim2.new(0.25, -8, 0, 36), Position = UDim2.new(0.5, 0, 0.5, -18), TextSize = 13, Parent = row }, "gold", function()
			act("BuyVial", vial.id)
		end)
		local use = button({ Text = "USE", Size = UDim2.new(0.25, -10, 0, 36), Position = UDim2.new(0.75, 0, 0.5, -18), TextSize = 13, Parent = row }, "blue", function()
			act("UseVial", vial.id)
		end)
		vialRows[vial.id] = { owned = owned, buy = buy, use = use, vial = vial }
	end
	local baitRefresh = refreshers.BAIT
	refreshers.BAIT = function()
		baitRefresh()
		for id, row in pairs(vialRows) do
			local count = state.vials[id] or 0
			row.owned.Text = ("Owned %d · %s"):format(count, row.vial.text)
			row.buy.Text = ("BUY · %d P"):format(row.vial.cost)
			restyle(row.buy, state.pearls >= row.vial.cost and "gold" or "grey")
			row.use.Visible = count > 0 and (id ~= "Mending" or state.started)
		end
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
-- Phase 4 (12 Oct): click an owned fish to open the drag-to-rotate 3D viewer (Tidebound.FishView)
for i, entry in ipairs(creatureList) do
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = creatureTiles[i].frame })
	hit.Activated:Connect(function()
		local n = state and state.collection[entry.name]
		if n then
			local tier = Config.Tiers[entry.tier]
			require(Shared:WaitForChild("FishView")).open(gui, entry.name, tier.color, ("%s · x%d"):format(tier.id, n))
		else
			toast(("Hatch a %s first to inspect it."):format(entry.name), "info")
		end
	end)
end

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
		-- Phase 4: the fish thumbnail replaces the trophy (black silhouette until hatched)
		t.icon.Visible = false
		if t.thumbOwned ~= (n ~= nil) then
			if t.thumb then
				t.thumb:Destroy()
			end
			t.thumb = require(Shared:WaitForChild("FishView")).thumb(t.frame, entry.name, n ~= nil)
			t.thumbOwned = n ~= nil
		end
	end
	creatureHeader.Text = ("CREATURES %d/%d · Aquarium +%.1f Pearls/min"):format(owned, #creatureList, state.incomePerMin)
end

-- BESTIARY tab: trophy tiles, blue when caught
local bestiaryPage = makePage("BESTIARY")
local bestiaryHeader = label({ Font = DISPLAY, TextSize = 16, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = nextOrder(), Parent = bestiaryPage })
local fishList = {}
for b, biome in ipairs(Config.Biomes) do
	for tierIndex, names in ipairs(biome.built and biome.fish or {}) do
		for _, fishName in ipairs(names) do
			table.insert(fishList, { name = fishName, tier = tierIndex, biome = b })
		end
	end
end
local fishTiles = tileGrid(bestiaryPage, #fishList)

refreshers.BESTIARY = function()
	local caught = { 0, 0 }
	for i, entry in ipairs(fishList) do
		local t = fishTiles[i]
		if state.bestiary[entry.name] then
			caught[entry.biome] = (caught[entry.biome] or 0) + 1
			retile(t, "blue")
			t.caption.Text = entry.name
		else
			retile(t, "red")
			t.caption.Text = Config.Tiers[entry.tier].id
		end
	end
	local G, L = Config.Guardian, Config.Leviathan
	bestiaryHeader.Text = ("SHOALS %d/12 · KELP %d/12 fish · %ss %d/%d · %ss %d/%d"):format(caught[1], caught[2], G.dropName, state.trophies[G.drop] or 0, G.dropsForPage, L.dropName, state.trophies[L.drop] or 0, L.dropsForPage)
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
	-- QUESTS tab: Quill's daily quests (LiveOps picks 3 a day from a pool). The full quest log, weekly goals, the
	-- live event, collection goals and the season pass are in TideboundMenus; the button below opens it.
	local questsPage = makePage("QUESTS")
	section(questsPage, "DAILY QUESTS · reset at 00:00 UTC")
	local questRows = {}
	for i = 1, 3 do
		local row = rowFrame(questsPage, 52)
		local title = label({ Font = DISPLAY, Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.66, -12, 0, 22), TextSize = 15, Parent = row })
		local progressText = label({ Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(0.2, 0, 0, 20), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
		local fill = bar(row, UDim2.new(0.2, 12, 0, 32), UDim2.new(0.46, -24, 0, 10), "gold")
		local entry = { row = row, title = title, progress = progressText, fill = fill }
		entry.claim = button({ Size = UDim2.new(0.34, -10, 0, 36), Position = UDim2.new(0.66, 0, 0.5, -18), TextSize = 13, Parent = row }, "gold", function()
			if entry.quest then
				act("ClaimQuest", entry.quest.id)
			end
		end)
		questRows[i] = entry
	end
	local questReset = note(questsPage, "")
	divider(questsPage)
	section(questsPage, "QUEST LOG · weekly goals, events, collection, season pass")
	local logRow = rowFrame(questsPage, 52)
	button({ Text = "OPEN QUEST LOG", Size = UDim2.new(0.5, -12, 0, 38), Position = UDim2.new(0, 8, 0.5, -19), TextSize = 15, Parent = logRow }, "blue", function()
		closeMenu()
		ClientBus.signal:Fire("open", "Quests")
	end)
	button({ Text = "SEASON PASS", Size = UDim2.new(0.5, -12, 0, 38), Position = UDim2.new(0.5, 4, 0.5, -19), TextSize = 15, Parent = logRow }, "gold", function()
		closeMenu()
		ClientBus.signal:Fire("open", "Pass")
	end)

	refreshers.QUESTS = function()
		local list = state.quests and state.quests.quests or {}
		for i, entry in ipairs(questRows) do
			local quest = list[i]
			entry.quest = quest
			entry.row.Visible = quest ~= nil
			if quest then
				entry.title.Text = quest.text
				entry.progress.Text = ("%d / %d"):format(quest.progress, quest.goal)
				entry.fill.Size = UDim2.new(math.clamp(quest.progress / quest.goal, 0, 1), 0, 1, 0)
				if quest.claimed then
					entry.claim.Text = "CLAIMED"
					restyle(entry.claim, "grey")
				else
					entry.claim.Text = quest.reward.pearls and ("CLAIM · %d P"):format(quest.reward.pearls) or "CLAIM"
					restyle(entry.claim, quest.progress >= quest.goal and "gold" or "grey")
				end
			end
		end
		local secondsLeft = 86400 - (os.time() % 86400)
		questReset.Text = ("New quests in %dh %dm."):format(secondsLeft // 3600, (secondsLeft % 3600) // 60)
	end
end

do
	-- BOARDS tab: the Leaderboard Hall (this server), with separate Solo and Crew boards (Master Patch 1)
	local boardsPage = makePage("BOARDS")
	local boardMode = "Solo"
	local refreshBoards -- set below
	local modeRow = rowFrame(boardsPage, 50)
	local modeButtons = {}
	for i, mode in ipairs({ "Solo", "Crew" }) do
		modeButtons[mode] = button({ Text = mode:upper() .. " BOARDS", Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new((i - 1) / 2, i == 1 and 8 or 6, 0.5, -19), TextSize = 15, Parent = modeRow }, "grey", function()
			boardMode = mode
			if state then
				refreshBoards()
			end
		end)
	end
	note(boardsPage, "Solo dives and Crew dives are ranked separately, so a Crew never pushes a solo diver off the board.")
	local boardLabels = {}
	for _, board in ipairs({ { "rarest", "RAREST HATCH" }, { "streak", "LONGEST CLEAN EXTRACTION STREAK" }, { "heat", "HIGHEST HEAT EXTRACTED AT" }, { "push", "DEEPEST GREED PUSH" } }) do
		section(boardsPage, board[2])
		boardLabels[board[1]] = label({ Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = boardsPage }, { textStroke(1) })
		divider(boardsPage)
	end
	section(boardsPage, "YOUR RECORD")
	local myRecord = label({ Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = boardsPage }, { textStroke(1) })

	refreshBoards = function()
		for mode, b in pairs(modeButtons) do
			restyle(b, mode == boardMode and "red" or "grey")
		end
		local boards = state.boards[boardMode] or {}
		for key, labelInst in pairs(boardLabels) do
			local lines = {}
			for i, entry in ipairs(boards[key] or {}) do
				table.insert(lines, ("%d. %s · %s"):format(i, entry.name, entry.text))
			end
			labelInst.Text = #lines > 0 and table.concat(lines, "\n") or "Nobody yet. Be the first!"
		end
		local st = state.stats
		local m = st.modes[boardMode]
		myRecord.Text = ("%s: extractions %d · clean streak %d (best %d) · best Heat extracted %d · deepest push %d · rarest hatch %s\nAll dives: wipes %d · fish caught %d · hatched %d · %ss %d · %ss %d"):format(
			boardMode,
			m.extractions,
			m.cleanStreak,
			m.bestStreak,
			m.bestHeatExtract,
			m.deepestPush,
			m.bestHatch ~= "" and m.bestHatch or "none yet",
			st.wipes,
			st.fishCaught,
			st.hatched,
			Config.Guardian.dropName,
			state.trophies[Config.Guardian.drop] or 0,
			Config.Leviathan.dropName,
			state.trophies[Config.Leviathan.drop] or 0
		)
	end
	refreshers.BOARDS = refreshBoards
end

do
	-- DIVE tab (Gate Warden Sel): Dive Solo or With Crew, Contested Waters, Crew invites, companions,
	-- loadout, travel and the risk rules (Master Patches 1-3)
	local divePage = makePage("DIVE")
	local M, CT, G, R = Config.Modes, Config.Contested, Config.Guardian, Config.Risk

	section(divePage, "BIOMES")
	local biomeLabels = {}
	for i, biome in ipairs(Config.Biomes) do
		local row = rowFrame(divePage, 30)
		label({ Text = biome.name, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.36, -12, 1, 0), TextSize = 15, Parent = row })
		biomeLabels[i] = label({ Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.64, -12, 1, 0), TextSize = 13, Parent = row }, { textStroke(1) })
	end

	divider(divePage)
	section(divePage, "DIVE · from the Nest or the Harbor Ring")
	local diveRow = rowFrame(divePage, 50)
	local function dive(mode)
		local result = act("Dive", mode)
		if result and result.ok then
			closeMenu()
		end
	end
	local soloDive = button({ Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new(0, 8, 0.5, -19), TextSize = 15, Parent = diveRow }, "blue", function()
		dive("Solo")
	end)
	local crewDive = button({ Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new(0.5, 6, 0.5, -19), TextSize = 15, Parent = diveRow }, "gold", function()
		dive("Crew")
	end)
	local diveNote = note(divePage, "")

	divider(divePage)
	section(divePage, "CONTESTED WATERS · this dive only, back to OFF after")
	local contestRow = rowFrame(divePage, 50)
	local offButton = button({ Text = "OFF · SAFE", Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new(0, 8, 0.5, -19), TextSize = 15, Parent = contestRow }, "blue", function()
		act("SetContested", false)
	end)
	local onButton = button({ Text = "ON · PVP", Size = UDim2.new(0.5, -14, 0, 38), Position = UDim2.new(0.5, 6, 0.5, -19), TextSize = 15, Parent = contestRow }, "grey", function()
		act("SetContested", true)
	end)
	note(divePage, ("OFF (default): nobody can take anything from you. ON: a rival %d studs behind you can hold for %d s to snatch one carried egg, never within %d studs of a beacon, and you then get %d s of immunity and a speed burst. Egg nests pay x%.2f (a %d%% chance of a bonus egg). Crewmates can never snatch from each other."):format(CT.snatchRange, CT.snatchHold, CT.beaconSafeRadius, CT.immunity, 1 + CT.bonusEggChance, math.round(CT.bonusEggChance * 100)))

	divider(divePage)
	section(divePage, ("CREW · invite only, up to %d divers"):format(M.crewMax))
	local crewInfo = note(divePage, "")
	local inviteRow = rowFrame(divePage, 46)
	local inviteText = label({ Font = DISPLAY, TextSize = 14, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.5, -12, 1, 0), Parent = inviteRow })
	button({ Text = "ACCEPT", Size = UDim2.new(0.25, -8, 0, 34), Position = UDim2.new(0.5, 0, 0.5, -17), TextSize = 13, Parent = inviteRow }, "gold", function()
		act("CrewAccept")
	end)
	button({ Text = "DECLINE", Size = UDim2.new(0.25, -10, 0, 34), Position = UDim2.new(0.75, 0, 0.5, -17), TextSize = 13, Parent = inviteRow }, "grey", function()
		act("CrewDecline")
	end)
	local leaveButton = button({ Text = "LEAVE CREW", Size = UDim2.new(1, 0, 0, 34), TextSize = 13, LayoutOrder = nextOrder(), Parent = divePage }, "grey", function()
		act("CrewLeave")
	end)
	local playerRows = {}
	for i = 1, 11 do
		local row = rowFrame(divePage, 40)
		local slot = { row = row, id = nil }
		slot.name = label({ Font = DISPLAY, TextSize = 14, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.6, -12, 1, 0), Parent = row })
		slot.button = button({ Size = UDim2.new(0.4, -10, 0, 30), Position = UDim2.new(0.6, 0, 0.5, -15), TextSize = 13, Parent = row }, "blue", function()
			if slot.id then
				act("CrewInvite", slot.id)
			end
		end)
		playerRows[i] = slot
	end
	local nobodyNote = note(divePage, "Nobody else is on this server yet. Crews are always optional.")

	divider(divePage)
	section(divePage, ("COMPANIONS · %d slots, each carries one egg for you"):format(Config.Companions.slots))
	local function cycleCompanion(i)
		if not state then
			return
		end
		local owned = state.companions.owned
		local current = state.companions.slots[i].name
		local taken = {}
		for j, slot in ipairs(state.companions.slots) do
			if j ~= i then
				taken[slot.name] = true
			end
		end
		local start = 0
		for k, entry in ipairs(owned) do
			if entry.name == current then
				start = k
			end
		end
		for step = 1, #owned do
			local entry = owned[(start + step - 1) % #owned + 1]
			if entry.name ~= current and not taken[entry.name] then
				act("EquipCompanion", i, entry.name)
				return
			end
		end
		toast(#owned == 0 and "Hatch a Tide Egg first. Companions come from your creature collection." or "No other creature to pick. Hatch more eggs!", "info")
	end
	local slotRows = {}
	for i = 1, Config.Companions.slots do
		local row = rowFrame(divePage, 46)
		local slotUi = {}
		slotUi.text = label({ Font = DISPLAY, TextSize = 14, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.5, -12, 1, 0), Parent = row })
		slotUi.pick = button({ Text = "PICK", Size = UDim2.new(0.25, -8, 0, 34), Position = UDim2.new(0.5, 0, 0.5, -17), TextSize = 13, Parent = row }, "blue", function()
			cycleCompanion(i)
		end)
		slotUi.clear = button({ Text = "EMPTY", Size = UDim2.new(0.25, -10, 0, 34), Position = UDim2.new(0.75, 0, 0.5, -17), TextSize = 13, Parent = row }, "grey", function()
			act("EquipCompanion", i, "")
		end)
		slotRows[i] = slotUi
	end
	local companionNote = note(divePage, "")

	divider(divePage)
	section(divePage, "LOADOUT")
	local loadout = note(divePage, "")

	divider(divePage)
	section(divePage, "TRAVEL · from the Nest or the Harbor Ring")
	local travelRow = rowFrame(divePage, 50)
	for i, dest in ipairs({ { "NEST PLAZA", "Nest" }, { "HARBOR RING", "Harbor" }, { "MY HOME NEST", "Home" } }) do
		button({ Text = dest[1], Size = UDim2.new(1 / 3, -12, 0, 38), Position = UDim2.new((i - 1) / 3, 6, 0.5, -19), TextSize = 13, Parent = travelRow }, "blue", function()
			local result = act("Travel", dest[2])
			if result and result.ok then
				closeMenu()
			end
		end)
	end

	divider(divePage)
	section(divePage, "RISK RULES")
	local moray = Config.Elites[2]
	note(divePage, table.concat({
		("Health: %d. The %s hits for %d and knocks your newest egg back to its shrine and a companion home. Stinging Anemone beds sting for %d and slow you; a Snapjaw Moray bites for %d. You heal fully between dives."):format(R.maxHealth, G.name, G.damage, Config.Anemone.damage, moray.damage),
		"Wipe: you lose all unbanked cargo, every carried fish and egg. Fish banked at the Tide Cache, pity, Bestiary, rods and your base are always safe.",
		("Wipe at heat %d or more and your next dive starts at heat %d, until you rest %d min at your Home Nest."):format(Config.HeatCarry.wipeAt, Config.HeatCarry.startHeat, Config.HeatCarry.drainSeconds // 60),
		("Heat: +%d per steal, +%d per fish, -1 per 3 s while you lie low. 25 patrol, 50 riptide (%d s pulls every %d s), 75 lock-on, 100 all beacons close for %d s."):format(Config.Heat.perSteal, Config.Heat.perFish, Config.Heat.riptideSeconds, Config.Heat.riptideEvery, Config.Heat.beaconCloseSeconds),
		("%s: Phase 1 when you steal your %drd egg (it guards the exit), Phase 2 at heat 75 (it chases; break sight for %d s), Phase 3 at heat 100 (faster). Every strike winds up for %.1f s: step aside."):format(G.name, G.triggerEggs, R.lockLoseSight, G.tell),
		("Extract: hold %d s at a beacon, then choose within %d s. EXTRACT NOW, or PUSH DEEPER for +%d%% cargo, +%d heat and an angrier %s, then extract at a different beacon. No choice means extract."):format(R.beaconChannel, Config.Greed.choiceSeconds, math.round(Config.Greed.cargoPct * 100), Config.Greed.heat, G.name),
		"Elites: dodge a Barnacle Brute's charge (it stuns you) or a Snapjaw Moray's bite, then loot their bait while they're dazed.",
		("Each carried egg costs %d WalkSpeed unless a companion carries it. Hold Shift (or SPRINT) to run, Q (or DASH) for a random dash move (rod and companion moves too): both use stamina. Clean Extraction streak: +1 Ember per %d in a row, up to +%d."):format(R.carrySlowPerEgg, R.streakEmberEvery, R.streakEmberMax),
	}, "\n"))
	local runStats = note(divePage, "")

	refreshers.DIVE = function()
		local rod = Config.RodsById[state.rod] or Config.Rods[1]
		for i, biome in ipairs(Config.Biomes) do
			local labelInst = biomeLabels[i]
			if not biome.built then
				labelInst.Text, labelInst.TextColor3 = ("Not built yet · %s"):format(biome.guardian), C.muted
			elseif i > rod.biomes then
				labelInst.Text, labelInst.TextColor3 = ("Needs a rod that reaches %d biomes"):format(i), C.warn
			else
				labelInst.Text, labelInst.TextColor3 = ("OPEN · %s · %s%s"):format(biome.guardian, biome.hazard, i > 1 and (" · PUSH DEEPER at a beacon · luck x%.1f"):format(biome.luck or 1) or ""), C.good
			end
		end

		local crew = state.crew
		local crewSize = #crew.members
		soloDive.Text = ("DIVE SOLO · x%.2f"):format(M.soloPearlMult)
		crewDive.Text = crewSize >= 2 and ("DIVE WITH CREW · x%.2f"):format(1 + M.crewPerMember * (crewSize - 1)) or "DIVE WITH CREW"
		restyle(soloDive, state.started and "grey" or "blue")
		restyle(crewDive, (crewSize >= 2 and not state.started) and "gold" or "grey")
		if state.started then
			diveNote.Text = ("You're on a %s dive%s. Extract at a beacon to finish it."):format(state.mode, state.runContested and " in Contested Waters" or "")
		else
			diveNote.Text = ("Solo dives pay x%.2f Pearls. A Crew pays +%d%% per extra member (x%.2f with %d). Canon caps still apply: %d Pearls per fish, %d per run payout. Same Shoals, same odds either way."):format(M.soloPearlMult, math.round(M.crewPerMember * 100), 1 + M.crewPerMember * (M.crewMax - 1), M.crewMax, Config.Tiers[#Config.Tiers].fishPearls, Config.Extraction.payoutCap)
		end
		restyle(offButton, state.contested and "grey" or "blue")
		restyle(onButton, state.contested and "red" or "grey")

		crewInfo.Text = crewSize >= 2 and ("Your Crew (%d/%d): %s"):format(crewSize, crew.max, table.concat(crew.members, ", ")) or "You're diving solo. Invite players below to form a Crew."
		inviteRow.Visible = crew.inviteFrom ~= nil
		inviteText.Text = crew.inviteFrom and (crew.inviteFrom .. " invited you") or ""
		leaveButton.Visible = crewSize >= 2
		for i, slot in ipairs(playerRows) do
			local other = crew.others[i]
			slot.row.Visible = other ~= nil
			slot.id = other and other.id
			if other then
				slot.name.Text = other.name
				if other.inMyCrew then
					slot.button.Text = "IN YOUR CREW"
					restyle(slot.button, "grey")
				elseif other.invited then
					slot.button.Text = "INVITED"
					restyle(slot.button, "grey")
				elseif crewSize >= crew.max then
					slot.button.Text = "CREW FULL"
					restyle(slot.button, "grey")
				else
					slot.button.Text = "INVITE"
					restyle(slot.button, "blue")
				end
			end
		end
		nobodyNote.Visible = #crew.others == 0

		local awake = 0
		for i, slotUi in ipairs(slotRows) do
			local slot = state.companions.slots[i]
			if slot.name == "" then
				slotUi.text.Text = ("Slot %d · empty"):format(i)
				slotUi.text.TextColor3 = C.muted
			elseif slot.koLeft > 0 then
				slotUi.text.Text = ("%s · knocked out %s"):format(slot.name, hudExtra.clock(slot.koLeft))
				slotUi.text.TextColor3 = C.bad
			else
				awake += 1
				slotUi.text.Text = ("%s · %s · awake"):format(slot.name, Config.Tiers[slot.tier].id)
				slotUi.text.TextColor3 = Config.Tiers[slot.tier].color
			end
			slotUi.clear.Visible = slot.name ~= ""
		end
		companionNote.Text = ("%d awake: they carry %d egg(s) without slowing you. A %s hit knocks one out for %d min; a Revive Vial (you have %d) wakes it. PICK cycles through your hatched creatures."):format(awake, awake, G.name, Config.Companions.koSeconds // 60, state.vials.Revive or 0)

		local dura = state.rodDura[rod.id] or Config.Durability.max
		local bait = state.bait ~= "" and Config.BaitById[state.bait]
		local lines = {
			("Rod: %s · durability %d/%d%s (Old Harl repairs it)"):format(rod.name, dura, Config.Durability.max, state.rodBroken and ", BROKEN: fishes like a Drift Rod" or ""),
			("Bait: %s"):format(bait and ("%s x%d"):format(bait.name, state.baitInv[state.bait] or 0) or "none"),
			("Vials: Mending x%d · Revive x%d · up to %d per dive (Nim sells them)"):format(state.vials.Mending or 0, state.vials.Revive or 0, Config.VialsPerRun),
			state.heatDebt > 0 and ("Carried heat: your next dive starts at heat %d. Rest at your Home Nest for %s to clear it."):format(state.heatDebt, hudExtra.clock(Config.HeatCarry.drainSeconds - state.heatDebtRest)) or "Carried heat: none. Your next dive starts at heat 0.",
		}
		loadout.Text = table.concat(lines, "\n")
		local m = state.stats.modes[state.mode] or state.stats.modes.Solo
		runStats.Text = ("%s record: clean streak %d · best %d · extractions %d · deepest push %d · wipes (all dives) %d"):format(state.mode, m.cleanStreak, m.bestStreak, m.extractions, m.deepestPush, state.stats.wipes)
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
		ClientBus.setMenu("Main", true)
		menuScale.Scale = 0.88
		TweenService:Create(menuScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(blur, TweenInfo.new(0.22), { Size = 16 }):Play()
		task.defer(layoutTiles)
	end
end

-- Patch 20: the DASHES and CAPSULES tabs. Open Dash Capsules (the egg hatch, with a capsule), see every dash
-- and its rarity, and equip up to Config.Capsules.slots of them. Everything lives in one table inside this block:
-- this script's main chunk is at Luau's limit of 200 locals.
do
	local dz = { DashMoves = require(Shared:WaitForChild("DashMoves")), rows = {}, slots = {}, pity = {} }
	dz.page = makePage("DASHES")
	dz.odds = makePage("CAPSULES")

	function dz.open()
		if not state or HatchScene.playing() then
			return
		end
		local result = act("OpenCapsule")
		if result and result.ok then
			if menu.Visible then
				closeMenu()
			end
			task.spawn(function()
				HatchScene.play(result.result)
				local move = dz.DashMoves.byId[result.result.dash]
				if move then
					local tier = Config.Tiers[result.result.tier]
					toast(("%s %s dash: %s%s"):format(result.result.isNew and "New" or "Duplicate", tier.id, move.name, result.result.isNew and (result.result.equipped and " (equipped)" or ": equip it in DASHES") or (" · +%d Shards"):format(result.result.shards)), result.result.isNew and "good" or "info")
				end
			end)
		end
	end

	-- the capsule row: how many you have, OPEN, BUY
	dz.action = rowFrame(dz.page, 54)
	dz.count = label({ Font = DISPLAY, TextSize = 19, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.36, -14, 1, 0), Parent = dz.action })
	button({ Text = "OPEN CAPSULE", Size = UDim2.new(0.3, -8, 0, 38), Position = UDim2.new(0.36, 0, 0.5, -19), Parent = dz.action }, "blue", dz.open)
	button({ Text = ("BUY · %d PEARLS"):format(Config.Capsules.pearlCost), Size = UDim2.new(0.34, -14, 0, 38), Position = UDim2.new(0.66, 2, 0.5, -19), Parent = dz.action }, "gold", function()
		act("BuyCapsule")
	end)

	-- the equipped slots
	section(dz.page, ("EQUIPPED · Q rolls one of these (%d slots)"):format(Config.Capsules.slots))
	dz.slotRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = nextOrder(), Parent = dz.page }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, Config.Capsules.slots do
		local slot = new("Frame", { Size = UDim2.new(1 / Config.Capsules.slots, -7, 1, 0), BackgroundColor3 = C.row, LayoutOrder = i, Parent = dz.slotRow }, { corner(8), stroke(C.neon, 2, 0.3) })
		dz.slots[i] = { frame = slot, text = label({ Font = DISPLAY, TextSize = 16, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = slot }) }
	end

	-- every dash, rarest last
	section(dz.page, "YOUR DASHES")
	note(dz.page, "🎣 rod dashes need your rod (everyone has one). 🐟 fish dashes need a companion out. In the air only air dashes roll.")
	local sorted = table.clone(dz.DashMoves.list)
	table.sort(sorted, function(a, b)
		return a.tier < b.tier or (a.tier == b.tier and a.id < b.id)
	end)
	for _, move in ipairs(sorted) do
		local tier = Config.Tiers[move.tier]
		local row = rowFrame(dz.page, 44)
		new("Frame", { Position = UDim2.new(0, 10, 0.5, -9), Size = UDim2.new(0, 18, 0, 18), BackgroundColor3 = tier.color, Parent = row }, { corner(4), stroke(WHITE, 1) })
		local icon = move.rod and "🎣 " or move.fish and "🐟 " or ""
		local name = label({ Text = icon .. move.name, Font = DISPLAY, TextSize = 16, TextColor3 = tier.color, Position = UDim2.new(0, 36, 0, 2), Size = UDim2.new(0.5, -36, 0, 22), Parent = row })
		local info = label({ Text = ("%s · %d stamina%s"):format(tier.id, move.cost, move.air and " · air" or ""), TextSize = 12, TextColor3 = C.muted, Position = UDim2.new(0, 36, 0, 22), Size = UDim2.new(0.5, -36, 0, 18), Parent = row }, { textStroke(1) })
		local owned = label({ Font = DISPLAY, TextSize = 14, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		local equip = button({ Text = "EQUIP", Size = UDim2.new(0.3, -12, 0, 32), Position = UDim2.new(0.7, 0, 0.5, -16), TextSize = 14, Parent = row }, "blue", function()
			act("EquipDash", move.key)
		end)
		dz.rows[move.key] = { name = name, info = info, owned = owned, equip = equip, move = move }
	end

	-- the CAPSULES tab: odds per pull, pity, the rules
	section(dz.odds, "DROP RATES · per capsule (same as Tide Eggs)")
	for t, tier in ipairs(Config.Tiers) do
		local row = rowFrame(dz.odds, 30)
		new("Frame", { Position = UDim2.new(0, 10, 0.5, -7), Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = tier.color, Parent = row }, { corner(3), stroke(WHITE, 1) })
		label({ Text = tier.id, Font = DISPLAY, TextColor3 = tier.color, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), TextSize = 15, Parent = row })
		label({ Text = pct(tier.rate), Font = DISPLAY, Position = UDim2.new(0.28, 10, 0, 0), Size = UDim2.new(0.15, 0, 1, 0), TextSize = 15, Parent = row })
		local names = {}
		for _, move in ipairs(dz.DashMoves.byTier[t] or {}) do
			table.insert(names, move.name)
		end
		label({ Text = #names > 0 and table.concat(names, ", ") or "(none yet: rolls the rarity below)", Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -10, 1, 0), TextSize = 13, TextColor3 = C.muted, Parent = row }, { textStroke(1) })
	end
	divider(dz.odds)
	section(dz.odds, "PITY · counted separately from eggs")
	for _, pity in ipairs(Config.Pity) do
		local row = rowFrame(dz.odds, 30)
		label({ Text = pity.label, Font = DISPLAY, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.3, 0, 1, 0), TextSize = 14, Parent = row })
		dz.pity[pity.key] = label({ Font = DISPLAY, TextSize = 14, Position = UDim2.new(0.3, 0, 0, 0), Size = UDim2.new(0.7, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	end
	note(dz.odds, ("A new dash goes straight into a free slot. A duplicate gives %d Shards. Capsules cost %d Pearls; Robux can't buy them."):format(Config.Shards.duplicate, Config.Capsules.pearlCost))

	refreshers.DASHES = function()
		dz.count.Text = ("CAPSULES: %d"):format(state.capsules or 0)
		local equipped = state.equippedDashes or {}
		for i, slot in ipairs(dz.slots) do
			local move = equipped[i] and dz.DashMoves.byKey[equipped[i]]
			slot.text.Text = move and move.name or "empty"
			slot.text.TextColor3 = move and Config.Tiers[move.tier].color or C.muted
		end
		for key, ui in pairs(dz.rows) do
			local count = state.dashes and state.dashes[key] or 0
			local on = table.find(equipped, key) ~= nil
			ui.owned.Text = count > 0 and ("x%d"):format(count) or "LOCKED"
			ui.owned.TextColor3 = count > 0 and C.text or C.muted
			ui.equip.Visible = count > 0
			ui.equip.Caption.Text = on and "UNEQUIP" or "EQUIP"
			restyle(ui.equip, on and "gold" or "blue")
		end
	end
	refreshers.CAPSULES = function()
		for _, row in ipairs(Gacha.pityProgress(state.dashPity or {})) do
			local labelInst = dz.pity[row.key]
			if labelInst then
				labelInst.Text = row.remaining <= 1 and "NEXT CAPSULE!" or ("%d / %d · %d left"):format(row.count, row.at, row.remaining)
				labelInst.TextColor3 = row.remaining <= 1 and C.gold or C.text
			end
		end
	end
end

-- Patch 21: the TRIALS tab. Each trial rod, its ability, and how far along its goals you are (counted from the
-- mobs you've defeated, state.mobKills). Kept in one table inside this block: this script is at the 200-local limit.
do
	local tr = { rows = {} }
	tr.page = makePage("TRIALS")
	note(tr.page, "Trial rods can't be bought: each one unlocks the moment you finish its trial. Defeat mobs out in the Shoals and Kelp Cathedral (swipes, the combo and rod abilities all count). Then equip it in RODS and press R.")
	tr.order = {}
	for rodId, trial in pairs(Config.RodTrials) do
		table.insert(tr.order, { id = rodId, trial = trial })
	end
	table.sort(tr.order, function(a, b)
		return a.trial.order < b.trial.order
	end)
	tr.KIND = { any = "mobs of any kind", crab = "Snapper Crabs", puffer = "Spike Puffers", gull = "Raider Gulls", shark = "Reef Sharks", golem = "Coral Golems" }
	function tr.build(entry)
		local rod = Config.RodsById[entry.id]
		local skill = RodSkillsLib.get(entry.id)
		local row = rowFrame(tr.page, 40 + 26 * (#entry.trial.goals + ((entry.trial.rods and 1) or 0)))
		label({ Text = rod.name, Font = DISPLAY, TextSize = 17, TextColor3 = skill.colors[1]:Lerp(WHITE, 0.3), Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(0.6, -12, 0, 22), Parent = row })
		local status = label({ Font = DISPLAY, TextSize = 14, Position = UDim2.new(0.6, 0, 0, 4), Size = UDim2.new(0.4, -12, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		label({ Text = ("R: %s · %s"):format(skill.name, entry.trial.text), TextSize = 12, TextColor3 = C.muted, Position = UDim2.new(0, 12, 0, 24), Size = UDim2.new(1, -24, 0, 16), Parent = row }, { textStroke(1) })
		local goals = {}
		for i, goal in ipairs(entry.trial.goals) do
			local y = 42 + (i - 1) * 26
			local text = label({ TextSize = 13, Position = UDim2.new(0, 12, 0, y), Size = UDim2.new(0.5, -12, 0, 20), Parent = row }, { textStroke(1) })
			local fill = bar(row, UDim2.new(0.5, 0, 0, y + 6), UDim2.new(0.5, -12, 0, 10), "gold")
			goals[i] = { goal = goal, text = text, fill = fill }
		end
		local needs = nil
		if entry.trial.rods then
			needs = label({ TextSize = 13, Position = UDim2.new(0, 12, 0, 42 + #entry.trial.goals * 26), Size = UDim2.new(1, -24, 0, 20), Parent = row }, { textStroke(1) })
		end
		tr.rows[entry.id] = { status = status, goals = goals, needs = needs, trial = entry.trial }
	end
	for _, entry in ipairs(tr.order) do
		tr.build(entry)
	end
	refreshers.TRIALS = function()
		local kills = state.mobKills or {}
		for rodId, ui in pairs(tr.rows) do
			local owned = state.ownedRods[rodId]
			ui.status.Text = owned and "✓ UNLOCKED" or "IN PROGRESS"
			ui.status.TextColor3 = owned and C.good or C.warn
			for _, g in ipairs(ui.goals) do
				local have = math.min(kills[g.goal.kind] or 0, g.goal.count)
				if owned then
					have = g.goal.count
				end
				g.text.Text = ("Defeat %d %s: %d / %d"):format(g.goal.count, tr.KIND[g.goal.kind] or g.goal.kind, have, g.goal.count)
				g.fill.Size = UDim2.new(have / g.goal.count, 0, 1, 0)
			end
			if ui.needs then
				local names = {}
				for _, need in ipairs(ui.trial.rods) do
					table.insert(names, (state.ownedRods[need] and "✓ " or "") .. Config.RodsById[need].name)
				end
				ui.needs.Text = "Own first: " .. table.concat(names, ", ")
			end
		end
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

local function showReveal(result, instant)
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
	local oldFish = revealTile.frame:FindFirstChild("FishViewport")
	if oldFish then
		oldFish:Destroy()
	end
	revealTier.Text = "HATCHING..."
	revealTier.TextColor3 = C.text
	revealName.Text, revealMutation.Text, revealDetails.Text = "", "", ""
	prismatic.Enabled = false
	-- after the hatch scene the card just lands; on its own it shakes first
	for _ = 1, instant and 0 or 5 do
		revealHolder.Rotation = 8
		task.wait(0.08)
		revealHolder.Rotation = -8
		task.wait(0.08)
	end
	revealHolder.Rotation = 0
	revealScale.Scale = 0.6
	TweenService:Create(revealScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	retile(revealTile, result.tier >= 4 and "gold" or "blue")
	-- Phase 5 (12 Oct): the hatched fish in 3D pops out of the card and slowly turns
	revealTile.icon.Visible = false
	local fishVp = require(Shared:WaitForChild("FishView")).viewport(revealTile.frame, result.creature, { spin = 40, zindex = 4, size = UDim2.fromScale(1.3, 1.3), zoom = 0.95 })
	local fishPop = new("UIScale", { Scale = 0.2, Parent = fishVp })
	TweenService:Create(fishPop, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
		-- Patch 11: the egg hatches in front of you, then the summary card lands
		if menu.Visible then
			closeMenu()
		end
		task.spawn(function()
			HatchScene.play(best)
			showReveal(best, true)
		end)
	end
end

-- Zone lighting moved to TideboundBiomeLook (GDD Section 7: lighting, atmosphere and post-processing per canon
-- biome). This script no longer touches Lighting's atmosphere, grade or bloom.

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
		-- GDD Section 8 Rules 3 and 5: at most 3 full-screen flashes a second, 80% weaker with Reduce Flashing
		local strength = ClientBus.flashAllowed()
		if strength <= 0 then
			return
		end
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = 1 - (1 - (from or 0.4)) * strength
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end

	local shakeUntil, shakeAmount = 0, 0
	local function shake(amount, seconds)
		shakeAmount = amount
		shakeUntil = os.clock() + seconds
	end
	FishingFeel.shake = shake

	local function pulseHeat()
		local scale = heatFrame:FindFirstChild("Pulse") or new("UIScale", { Name = "Pulse", Parent = heatFrame })
		scale.Scale = 1.08
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-- Greed card (Master Patch 2): after the 3 s beacon hold, extract now or push deeper. No answer extracts.
	local greedFrame = neonPanel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(0, 380, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, 6, true)
	greedFrame.Parent = gui
	padding(10).Parent = greedFrame
	list(6).Parent = greedFrame
	local greedTitle = label({ Font = DISPLAY, TextSize = 20, TextColor3 = C.gold, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = greedFrame })
	local greedText = label({ TextSize = 13, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = greedFrame }, { textStroke(1) })
	local greedFill = bar(new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 3, Parent = greedFrame }), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), "gold")
	local greedButtons = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = greedFrame })
	local extractButton = button({ Text = "EXTRACT NOW", Size = UDim2.new(0.5, -4, 1, 0), Parent = greedButtons }, "blue", function()
		act("GreedChoice", "extract")
	end)
	local pushButton = button({ Text = "PUSH DEEPER", Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0), Parent = greedButtons }, "red", function()
		act("GreedChoice", "push")
	end)

	refreshGreed = function()
		local choice = state and state.choice
		greedFrame.Visible = choice ~= nil
		if not choice then
			return
		end
		local G = Config.Greed
		local elapsed = workspace:GetServerTimeNow() - choice.started
		greedTitle.Text = ("EXTRACT OR PUSH DEEPER?  %ds"):format(math.max(0, math.ceil(G.choiceSeconds - elapsed)))
		if choice.canPush and state.depth == 1 then
			local deeper = Config.Biomes[2]
			greedText.Text = ("Extract now: bank your cargo at x%.1f. Push deeper: dive down the Maelstrom into %s (rarer fish, luck x%.1f) with cargo x%.1f and +%d heat, where the %s waits. No answer extracts."):format(state.cargoMult, deeper.name, deeper.luck, state.cargoMult + G.cargoPct, G.heat, Config.Leviathan.name)
		elseif choice.canPush then
			greedText.Text = ("Extract now: bank your cargo at x%.1f. Push deeper: cargo x%.1f, +%d heat and the %s gets one phase angrier, then extract at a different beacon. No answer extracts."):format(state.cargoMult, state.cargoMult + G.cargoPct, G.heat, state.guardianName or Config.Guardian.name)
		else
			greedText.Text = ("Your rod can't go deeper (%d of %d pushes used). Extract now to bank your cargo at x%.1f."):format(state.pushes, state.maxPushes, state.cargoMult)
		end
		pushButton.Visible = choice.canPush
		extractButton.Size = choice.canPush and UDim2.new(0.5, -4, 1, 0) or UDim2.new(1, 0, 1, 0)
		greedFill.Size = UDim2.new(math.clamp(elapsed / G.choiceSeconds, 0, 1), 0, 1, 0)
	end

	-- Big centre call-outs for tells and phase changes (every strike telegraphs for at least 0.6 s)
	local callout = label({ Font = DISPLAY, TextSize = 38, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.34, 0), Size = UDim2.new(0, 560, 0, 48), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 35, Parent = gui })
	local calloutScale = new("UIScale", { Parent = callout })
	local calloutToken = 0
	local function call(text, color, seconds)
		calloutToken += 1
		local token = calloutToken
		callout.Text = text
		callout.TextColor3 = color
		callout.Visible = true
		calloutScale.Scale = 1.3
		TweenService:Create(calloutScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(seconds or 1, function()
			if token == calloutToken then
				callout.Visible = false
			end
		end)
	end

	-- Riptide (Master Patch 3 Table C): a steady pull toward open water you can walk against
	local riptide = { untilTime = 0, direction = Vector3.zero, speed = 0 }
	HazardEvent.OnClientEvent:Connect(function(kind, direction, seconds, speed)
		if kind == "Riptide" and typeof(direction) == "Vector3" then
			riptide.direction = Vector3.new(direction.X, 0, direction.Z).Unit
			riptide.speed = speed or Config.Heat.riptideSpeed
			riptide.untilTime = os.clock() + (seconds or Config.Heat.riptideSeconds)
			toast("Riptide! The current pulls you toward open water. Walk against it.", "warn")
			call("RIPTIDE", C.blue, 1.2)
		end
	end)

	-- Stinging Anemone beds (the server deals the sting) and Kelp Cathedral's grasping vines slow you while
	-- you stand in them
	local MotionBus = require(Shared:WaitForChild("MotionBus"))
	local function onPatch(root, tag)
		for _, bed in ipairs(CollectionService:GetTagged(tag)) do
			if bed:IsA("BasePart") then
				local p = bed.CFrame:PointToObjectSpace(root.Position)
				if math.abs(p.X) < bed.Size.X / 2 + 0.3 and math.abs(p.Z) < bed.Size.Z / 2 + 0.3 and p.Y > -1 and p.Y < 7 then
					return true
				end
			end
		end
		return false
	end

	-- Sprint: Shift on keyboard, a SPRINT toggle on touch screens
	local sprintHeld, sprintToggle = false, false
	-- Patch 18: stamina (Config.Stamina). The dash itself is TideboundDash (Patch 19), which spends from the
	-- same MotionBus.stamina. Everything lives in one table: this script's main chunk is at Luau's limit of 200
	-- locals, and a script over it doesn't compile at all (no HUD, nothing).
	local mv = {
		ST = Config.Stamina,
		s = MotionBus.stamina,
		sprintBlend = 0,
		dashEvent = Remotes:FindFirstChild("Dash") :: RemoteEvent?,
		warned = false,
	}
	mv.s.value = Config.Stamina.max
	if not mv.dashEvent then
		task.spawn(function()
			mv.dashEvent = Remotes:WaitForChild("Dash") :: RemoteEvent
		end)
	end
	function mv.tell(what, value)
		if mv.dashEvent then
			mv.dashEvent:FireServer(what, value)
		end
	end

	-- the stamina bar: a slim pill at the bottom of the screen that only shows while it isn't full
	mv.bar = new("Frame", { Name = "Stamina", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(0, 230, 0, 14), BackgroundColor3 = Color3.fromRGB(12, 40, 110), Visible = false, Parent = gui }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = TILE.blue.outline, Thickness = 2 }),
	})
	mv.fill = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(120, 230, 120), BorderSizePixel = 0, Parent = mv.bar }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200)), Rotation = 90 }),
	})
	mv.icon = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.new(0, 20, 0, 20), Text = "⚡", TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 230, 90), Parent = mv.bar })

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

	player.CharacterAdded:Connect(function()
		mv.s.value, mv.s.winded, mv.sprintBlend = mv.ST.max, false, 0
		mv.tell("tired", false)
	end)

	-- stamina drains while you sprint, refills after a short rest (faster standing still); dashes spend it too
	function mv.update(dt, humanoid, wantSprint)
		local ST, s = mv.ST, mv.s
		local now = os.clock()
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local sprinting = wantSprint and moving and not s.winded and s.value > 0
		if sprinting then
			s.value = math.max(0, s.value - ST.sprintDrain * dt)
			s.lastDrain = now
		elseif now - s.lastDrain > ST.regenDelay then
			s.value = math.min(ST.max, s.value + ST.regen * (moving and 1 or ST.regenStill) * dt)
		end
		if s.value <= 0 and not s.winded then
			s.winded = true
			MotionBus.tired[humanoid.Parent] = true
			mv.tell("tired", true)
		elseif s.winded and s.value >= ST.recoverAt then
			s.winded = false
			MotionBus.tired[humanoid.Parent] = nil
			mv.tell("tired", false)
		end
		-- the bar
		if s.value < ST.max - 0.5 then
			s.shownAt = now
		end
		local show = now - s.shownAt < 1.2
		mv.bar.Visible = show
		if show then
			local frac = s.value / ST.max
			mv.fill.Size = UDim2.new(math.max(frac, 0.04), 0, 1, 0)
			local color = s.winded and Color3.fromRGB(255, 80, 80) or (frac > 0.5 and Color3.fromRGB(120, 230, 120) or frac > 0.25 and Color3.fromRGB(255, 210, 70) or Color3.fromRGB(255, 120, 60))
			mv.fill.BackgroundColor3 = s.winded and color:Lerp(Color3.new(1, 1, 1), 0.3 + 0.3 * math.sin(now * 12)) or color
			mv.icon.TextColor3 = s.winded and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 230, 90)
		end
		return sprinting
	end

	-- every frame: WalkSpeed (carry slowdown, treadmill, sprint, stun, anemone), riptide pull, camera
	-- FOV and shake, vignette
	local currentFov = Config.Camera.exploration
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and state then
			local wantSprint = sprintHeld or sprintToggle
			local ok, result = pcall(mv.update, dt, humanoid, wantSprint)
			if not ok and not mv.warned then
				mv.warned = true
				warn("[Tidebound] stamina:", result)
			end
			-- if stamina ever breaks, sprinting still works
			local sprinting = if ok then result else wantSprint and humanoid.MoveDirection.Magnitude > 0.1
			-- Patch 18: the sprint eases in and out instead of snapping
			mv.sprintBlend += ((sprinting and 1 or 0) - mv.sprintBlend) * math.min(1, dt * (sprinting and mv.ST.sprintEase or mv.ST.sprintEase * 1.6))
			local speed = state.walkSpeed + Config.Risk.sprintBonus * mv.sprintBlend
			if workspace:GetServerTimeNow() < state.stunUntil or FishingFeel.frozen or MotionBus.cutscene then
				speed = 0
			elseif onPatch(root, "TideboundAnemone") then
				speed *= 1 - Config.Anemone.slow
			elseif onPatch(root, "TideboundVines") then
				speed *= 1 - Config.Kelp.vineSlow
			end
			humanoid.WalkSpeed = speed
			if os.clock() < riptide.untilTime and humanoid.Health > 0 and not FishingFeel.frozen and not MotionBus.cutscene then
				root.CFrame += riptide.direction * riptide.speed * dt
			end
			if shakeUntil > os.clock() then
				humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * shakeAmount, (math.random() - 0.5) * shakeAmount, 0)
			elseif humanoid.CameraOffset.Magnitude > 0 then
				humanoid.CameraOffset = Vector3.zero
			end
		end
		local camera = workspace.CurrentCamera
		if camera and state and not MotionBus.cutscene then
			local target = Config.Camera.exploration
			if situation == "fishing" then
				target = Config.Camera.fishing
			elseif situation == "hatch" then
				target = Config.Camera.hatch
			elseif state.locked then
				target = Config.Camera.chase
			end
			currentFov += (target - currentFov) * math.min(1, dt * 4)
			-- Master Patch 5: +4 FOV for 6 frames as the cast releases
			local extra = os.clock() < FishingFeel.kickUntil and 4 or 0
			-- Patch 18: the sprint widens the view a little; dashes and slams punch it
			extra += mv.ST.sprintFov * mv.sprintBlend
			local kick = MotionBus.kick
			if kick then
				local u = (os.clock() - kick.at) / kick.length
				if u >= 1 then
					MotionBus.kick = nil
				else
					extra += kick.amount * (1 - u) ^ 2
				end
			end
			camera.FieldOfView = currentFov + extra
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
			call("EXTRACT OR PUSH?", C.gold, 1.2)
		elseif name == "Push" then
			pulseHeat()
			shake(0.2, 0.3)
			call("PUSHED DEEPER", C.bad, 1.4)
		elseif name == "Bank" then
			screenFlash(C.good, 0.6)
			call("CATCH BANKED", C.good, 1.2)
		elseif name == "WardenTell" then
			shake(0.15, 0.6)
			call(("%s: DODGE!"):format(tostring(payload or Config.Guardian.name):upper()), C.bad, 0.8)
		elseif name == "EliteTell" then
			shake(0.1, 0.4)
			call(("%s: DODGE!"):format(tostring(payload or "ELITE"):upper()), C.warn, 0.9)
		elseif name == "Stun" then
			playAnim("HitReact")
			screenFlash(C.warn, 0.5)
			shake(0.35, 0.4)
			call("STUNNED", C.warn, tonumber(payload) or 1.5)
		elseif name == "Phase" then
			pulseHeat()
			shake(0.25, 0.5)
			local info = type(payload) == "table" and payload or { phase = tonumber(payload) or 1 }
			local phase = tonumber(info.phase) or 1
			call(("%s PHASE %d"):format(tostring(info.guardian or Config.Guardian.name):upper(), phase), phase >= 2 and C.bad or C.warn, 1.6)
		elseif name == "LockLost" then
			call("YOU SHOOK IT OFF", C.good, 1.2)
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

do
	-- Fish reveal (Master Patch 6) ----------------------------------------------------------------------
	-- The server has already rolled the fish; this only shows it. After the Land-Flip and Land-Hold, Phase 0
	-- drains the world to 20% colour and hides the HUD, Phase 1 shows a dark silhouette, Phase 2 climbs the
	-- tiers 0.3 s at a time (on a near-miss it climbs one too high and drains back), Phase 3 slides in the
	-- name card, Phase 4 celebrates by tier and Phase 5 brings you back. Click or tap after the silhouette
	-- to skip to the card. You can't be hurt until it ends (the server holds the same window).
	local FishModels = require(Shared:WaitForChild("FishModels"))
	local Audio = require(Shared:WaitForChild("Audio"))
	local RV = Config.Reveal
	local rv = {} -- the reveal's UI and state share one table: this script is near Luau's 200-local limit
	rv.TIER_SOUNDS = { "TierCommon", "TierUncommon", "TierRare", "TierEpic", "TierLegendary", "TierMythic", "TierCelestial" }
	rv.RAINBOW = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 140)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 110, 255)),
	})

	rv.revealGui = new("ScreenGui", { Name = "TideboundFishReveal", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	rv.grade = Lighting:FindFirstChild("TideboundRevealGrade") or new("ColorCorrectionEffect", { Name = "TideboundRevealGrade", Parent = Lighting })
	rv.soft = Lighting:FindFirstChild("TideboundRevealBlur") or new("BlurEffect", { Name = "TideboundRevealBlur", Size = 0, Parent = Lighting })
	rv.grade.Saturation = 0

	-- aurora ribbons across the top of the screen (Celestial climb, Mythic+ celebration)
	rv.aurora = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = rv.revealGui })
	rv.ribbons = {}
	for i, spec in ipairs({ { 0.04, -5 }, { 0.14, 3 }, { 0.24, -2 } }) do
		local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, spec[1]), Size = UDim2.new(1.3, 0, 0.09, 0), Rotation = spec[2], BackgroundColor3 = WHITE, BackgroundTransparency = 0.5 + i * 0.08, BorderSizePixel = 0, Parent = rv.aurora })
		rv.ribbons[i] = new("UIGradient", { Color = rv.RAINBOW, Parent = ribbon })
	end

	rv.tierLabel = label({ Font = DISPLAY, TextSize = 46, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.new(0.9, 0, 0, 54), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = rv.revealGui })
	rv.tierScale = new("UIScale", { Parent = rv.tierLabel })

	rv.stage = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = rv.revealGui }, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		new("UISizeConstraint", { MaxSize = Vector2.new(360, 360) }),
	})
	rv.circle = function(size, transparency, z)
		return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size), BackgroundColor3 = WHITE, BackgroundTransparency = transparency, BorderSizePixel = 0, ZIndex = z, Parent = rv.stage }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	-- soft spotlight, with a faint tier outline from Uncommon up
	rv.circle(1, 0.93, 1)
	rv.circle(0.78, 0.9, 1)
	rv.outline = new("UIStroke", { Thickness = 3, Transparency = 1, Color = WHITE, Parent = rv.circle(0.56, 0.86, 1) })
	rv.aura = rv.circle(0.8, 1, 2)
	rv.auraScale = new("UIScale", { Parent = rv.aura })
	rv.beams = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2, Parent = rv.stage })
	for i = 1, 8 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 10, 2, 0), Rotation = i * 22.5, BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = rv.beams }, {
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }) }),
		})
	end
	rv.wave = rv.circle(0, 1, 3)
	rv.waveStroke = new("UIStroke", { Thickness = 6, Transparency = 1, Color = WHITE, Parent = rv.wave })
	rv.view = new("ViewportFrame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 170, 180), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -1, -0.6), ZIndex = 4, Parent = rv.stage })
	rv.viewCamera = new("Camera", { FieldOfView = 40, Parent = rv.view })
	rv.view.CurrentCamera = rv.viewCamera
	rv.sparkles = {}
	for i = 1, 6 do
		rv.sparkles[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Rotation = 45, BackgroundColor3 = WHITE, BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = rv.stage }, { corner(2) })
	end

	-- name card: tier-coloured border, the tier's trophy, 1 to 7 stars
	rv.card = neonPanel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(-0.6, 0.74), Size = UDim2.new(0.92, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 6 }, 8, true)
	new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge), Parent = rv.card })
	padding(12).Parent = rv.card
	rv.card.Parent = rv.revealGui
	rv.cardStroke = rv.card:FindFirstChildOfClass("UIStroke")
	rv.cardIcon = new("Frame", { Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 7, Parent = rv.card })
	rv.cardText = new("Frame", { Position = UDim2.new(0, 76, 0, 0), Size = UDim2.new(1, -76, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 7, Parent = rv.card }, { list(2) })
	rv.cardLine = function(order, props)
		props.Size = UDim2.new(1, 0, 0, 0)
		props.AutomaticSize = Enum.AutomaticSize.Y
		props.LayoutOrder = order
		props.ZIndex = 7
		props.Parent = rv.cardText
		return label(props, props.Font ~= DISPLAY and { textStroke(1) } or nil)
	end
	rv.cardTitle = rv.cardLine(1, { Font = DISPLAY, TextSize = 19, RichText = true })
	rv.cardStars = rv.cardLine(2, { TextSize = 18 })
	rv.cardMutation = rv.cardLine(3, { TextSize = 15 })
	rv.cardWeight = rv.cardLine(4, { TextSize = 15, TextColor3 = C.muted })
	rv.cardNew = rv.cardLine(5, { Font = DISPLAY, TextSize = 16, TextColor3 = C.gold, Text = "New Bestiary entry!" })

	rv.skipHint = label({ Text = "Click to skip", TextSize = 14, TextColor3 = C.muted, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(0, 200, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = rv.revealGui }, { textStroke(1) })
	rv.flashFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 9, Parent = rv.revealGui })

	rv.shown = nil -- the fish in the viewport
	rv.shownTier = 0
	rv.skippable, rv.skipping = false, false
	UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if rv.skippable and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then
			rv.skipping = true
		end
	end)

	rv.hold = function(seconds)
		local untilTime = os.clock() + seconds
		while os.clock() < untilTime and not (rv.skippable and rv.skipping) do
			RunService.RenderStepped:Wait()
		end
	end

	rv.shockwave = function(color)
		rv.wave.Size = UDim2.fromScale(0.2, 0.2)
		rv.waveStroke.Color = color
		rv.waveStroke.Transparency = 0
		TweenService:Create(rv.wave, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(2.4, 2.4) }):Play()
		TweenService:Create(rv.waveStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end

	-- one tier of the climb: colour, name, sound and that tier's effects (each tier keeps the ones below)
	rv.showTier = function(index, quiet)
		local tier = Config.Tiers[index]
		rv.shownTier = index
		rv.tierLabel.Text = tier.id:upper()
		rv.tierLabel.TextColor3 = tier.color
		rv.tierLabel.TextTransparency = 0
		rv.tierScale.Scale = 1.25
		TweenService:Create(rv.tierScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if rv.shown then
			FishModels.paint(rv.shown, tier.color, index >= 5 and Enum.Material.Neon or nil)
		end
		if not quiet then
			Audio.play(rv.TIER_SOUNDS[index])
		end
		rv.outline.Color = tier.color
		rv.outline.Transparency = index >= 2 and 0.5 or 1
		for _, sparkle in ipairs(rv.sparkles) do
			sparkle.Visible = index >= 3
			sparkle.BackgroundColor3 = tier.color:Lerp(WHITE, 0.5)
		end
		rv.aura.BackgroundColor3 = tier.color
		rv.aura.BackgroundTransparency = index >= 4 and 0.72 or 1
		if index == 5 and not quiet then
			rv.shockwave(tier.color)
		end
		rv.beams.Visible = index >= 6
		for _, beam in ipairs(rv.beams:GetChildren()) do
			if beam:IsA("Frame") then
				beam.BackgroundColor3 = tier.color
			end
		end
		rv.aurora.Visible = index >= 7
	end

	rv.confetti = function()
		for _ = 1, 40 do
			local bit = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.random(-40, 40), 0.42, math.random(-20, 20)), Size = UDim2.fromOffset(8, 14), Rotation = math.random(0, 360), BackgroundColor3 = Color3.fromHSV(math.random(), 0.7, 1), BorderSizePixel = 0, ZIndex = 8, Parent = rv.revealGui })
			local up = TweenService:Create(bit, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.7, 0, 0.12 + math.random() * 0.2, 0) })
			up.Completed:Connect(function()
				TweenService:Create(bit, TweenInfo.new(1 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(bit.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0), Rotation = bit.Rotation + math.random(-400, 400) }):Play()
			end)
			up:Play()
			task.delay(2.2, bit.Destroy, bit)
		end
	end

	-- NPCs within 60 studs stop and turn to look (Mythic and up). Only on your screen.
	rv.npcsLook = function(root, turn)
		local world = workspace:FindFirstChild("TideboundWorld")
		local turned = {}
		if not world then
			return turned
		end
		for _, model in ipairs(world:GetDescendants()) do
			if model:IsA("Model") and model.Name:sub(1, 4) == "Npc_" and model.PrimaryPart then
				local pivot = model:GetPivot()
				if (pivot.Position - root.Position).Magnitude <= RV.npcLookRadius then
					table.insert(turned, { model = model, from = pivot, to = CFrame.lookAt(pivot.Position, Vector3.new(root.Position.X, pivot.Position.Y, root.Position.Z)) })
				end
			end
		end
		turn(turned, false)
		return turned
	end
	rv.turnNpcs = function(turned, back)
		task.spawn(function()
			local start = os.clock()
			while os.clock() - start < 0.4 do
				local s = (os.clock() - start) / 0.4
				for _, entry in ipairs(turned) do
					if entry.model.Parent then
						entry.model:PivotTo(back and entry.to:Lerp(entry.from, s) or entry.from:Lerp(entry.to, s))
					end
				end
				RunService.RenderStepped:Wait()
			end
			for _, entry in ipairs(turned) do
				if entry.model.Parent then
					entry.model:PivotTo(back and entry.from or entry.to)
				end
			end
		end)
	end

	-- the camera's 45-degree side view of you holding the fish
	rv.sideView = function(root, distance, height)
		local look, right = root.CFrame.LookVector, root.CFrame.RightVector
		local focus = root.Position + Vector3.new(0, 1.3, 0) + look * 1.4
		return CFrame.lookAt(focus + (look + right).Unit * distance + Vector3.new(0, height, 0), focus)
	end

	hudExtra.reveal = function(result)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		local tierIndex = math.clamp(tonumber(result.tier) or 1, 1, #Config.Tiers)
		local tier = Config.Tiers[tierIndex]
		FishingFeel.frozen = true
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		if menu.Visible then
			closeMenu()
		end

		-- Land-Flip (1.0 s at half speed): TideboundRod flips the fish into your hands
		task.wait(1.0)
		-- Land-Hold: the camera swings to a 45-degree side view and zooms to FOV 55
		situation = "hatch"
		local saved = camera.CFrame
		if root then
			camera.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(camera, TweenInfo.new(RV.landSeconds - 1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rv.sideView(root, 9, 1.5) }):Play()
		end
		task.wait(RV.landSeconds - 1.0)

		-- Phase 0: the world drains to 20% colour behind a soft blur, the HUD hides
		Audio.play("RevealHum")
		gui.Enabled = false
		rv.grade.Enabled = true
		-- 12 Oct 2026: the world stays bright and warm (draining it to grey felt like a horror game)
		TweenService:Create(rv.grade, TweenInfo.new(0.25), { Saturation = 0.15, Brightness = 0.03, TintColor = Color3.fromRGB(255, 250, 238) }):Play()
		TweenService:Create(rv.soft, TweenInfo.new(0.25), { Size = 4 }):Play()
		if rv.shown then
			rv.shown:Destroy()
		end
		local model, length = FishModels.build(result.fish, tierIndex)
		rv.shown, rv.shownTier = model, 0
		model.Parent = rv.view
		-- a three-quarter view from just above and ahead, far enough back that a Marlin's bill fits
		rv.viewCamera.CFrame = CFrame.lookAt(Vector3.new(length * 1.9, length * 0.8, -length * 0.45), Vector3.zero)
		rv.tierLabel.Text = ""
		rv.outline.Transparency = 1
		rv.aura.BackgroundTransparency = 1
		rv.beams.Visible, rv.aurora.Visible = false, false
		for _, sparkle in ipairs(rv.sparkles) do
			sparkle.Visible = false
		end
		for _, child in ipairs(rv.cardIcon:GetChildren()) do
			child:Destroy()
		end
		rv.card.Position = UDim2.fromScale(-0.6, 0.74)
		rv.skipping, rv.skippable = false, false
		rv.revealGui.Enabled = true

		-- everything that moves while the reveal is up
		local started = os.clock()
		local loop = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			if rv.shown and rv.shown.Parent then
				rv.shown:PivotTo(CFrame.new(0, math.sin(t * 2) * length * 0.03, 0) * CFrame.Angles(0, math.sin(t * 0.8) * 0.5, math.sin(t * 1.3) * 0.06))
				if rv.shownTier >= #Config.Tiers then
					FishModels.paint(rv.shown, Color3.fromHSV((t * 0.35) % 1, 0.35, 1):Lerp(Config.Tiers[#Config.Tiers].color, 0.3), Enum.Material.Neon)
				end
			end
			for i, sparkle in ipairs(rv.sparkles) do
				local a = t * 1.6 + i / #rv.sparkles * math.pi * 2
				sparkle.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.42, 0.5 + math.sin(a) * 0.3)
				sparkle.Rotation = 45 + t * 90
			end
			rv.auraScale.Scale = 1 + math.sin(t * 4) * 0.05
			rv.beams.Rotation = t * 12
			for i, ribbon in ipairs(rv.ribbons) do
				ribbon.Offset = Vector2.new(math.sin(t * 0.6 + i) * 0.3, 0)
			end
		end)

		-- Phase 1: a dark silhouette turns slowly under the spotlight; its size hints at the catch
		Audio.play("Heartbeat")
		rv.hold(RV.silhouette)
		rv.skippable = true
		rv.skipHint.Visible = true

		-- Phase 2: the tier climb, 0.3 s per tier, with the near-miss on top
		local top = result.nearMiss and math.min(tierIndex + 1, #Config.Tiers) or tierIndex
		for index = 1, top do
			if rv.skipping then
				break
			end
			rv.showTier(index)
			rv.hold(RV.step)
		end
		if not rv.skipping and top > tierIndex then
			-- the near-miss: it holds one tier too high, then drains back down
			rv.hold(RV.nearMissHold - RV.step)
			Audio.play("NearMissDrain")
			local from, to = Config.Tiers[top].color, tier.color
			local drainStart = os.clock()
			while os.clock() - drainStart < RV.nearMissDrain and not rv.skipping do
				local s = (os.clock() - drainStart) / RV.nearMissDrain
				FishModels.paint(rv.shown, from:Lerp(to, s))
				rv.tierLabel.TextTransparency = s
				RunService.RenderStepped:Wait()
			end
		end
		if rv.shownTier ~= tierIndex or rv.tierLabel.TextTransparency > 0 then
			-- a skip lands on the final tier with its sound; a near-miss already played the drain
			rv.showTier(tierIndex, rv.shownTier >= tierIndex)
		end
		rv.skippable = false
		rv.skipHint.Visible = false

		-- Phase 3: the name card slides in from the left
		Audio.play("CardSlide")
		rv.cardStroke.Color = tier.color
		trophy(rv.cardIcon, tier.color, WHITE)
		rv.cardTitle.Text = ("%s · %s · <font color=\"#%s\">%s</font>"):format(result.biome or Config.Biomes[1].name, result.fish, tier.color:ToHex(), tier.id)
		rv.cardStars.Text = string.rep("★", tierIndex)
		rv.cardStars.TextColor3 = tier.color
		if result.mutation and result.mutation ~= "None" then
			rv.cardMutation.Text = ("Mutation: %s (x%.2f)"):format(result.mutation, result.mult or 1)
			for _, m in ipairs(Config.Mutations) do
				if m.id == result.mutation then
					rv.cardMutation.TextColor3 = m.color
				end
			end
		else
			rv.cardMutation.Text = "No mutation"
			rv.cardMutation.TextColor3 = C.muted
		end
		local weight = tonumber(result.weight) or 0
		local rank = tonumber(result.top) or 100
		rv.cardWeight.Text = rank <= 50 and ("Weight: %.1f kg (Top %d%%)"):format(weight, rank) or ("Weight: %.1f kg"):format(weight)
		rv.cardNew.Visible = result.isNew == true
		TweenService:Create(rv.card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.74) }):Play()
		task.wait(RV.card)

		-- Phase 4: the celebration grows with the tier
		local turned = nil
		if tierIndex >= 4 then
			rv.confetti()
			rv.flashFrame.BackgroundTransparency = 0.5 -- never past 50% white
			TweenService:Create(rv.flashFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		if tierIndex >= 5 then
			Audio.play("Celebrate")
			rv.shockwave(tier.color)
			if root then
				TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rv.sideView(root, 15, 4) }):Play()
			end
		end
		if tierIndex >= 6 then
			rv.aurora.Visible = true
			if root then
				turned = rv.npcsLook(root, rv.turnNpcs)
			end
		end
		task.wait(RV.celebrate)

		-- Phase 5: colour floods back, the camera returns and you can move again
		task.spawn(act, "RevealDone")
		TweenService:Create(rv.grade, TweenInfo.new(RV.back), { Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(rv.soft, TweenInfo.new(RV.back), { Size = 0 }):Play()
		TweenService:Create(rv.card, TweenInfo.new(RV.back * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.6, 0.74) }):Play()
		if root then
			TweenService:Create(camera, TweenInfo.new(RV.back, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = saved }):Play()
		end
		task.wait(RV.back)
		loop:Disconnect()
		rv.revealGui.Enabled = false
		gui.Enabled = true
		camera.CameraType = Enum.CameraType.Custom
		situation = nil
		FishingFeel.frozen = false
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		if turned then
			rv.turnNpcs(turned, true)
		end
		if result.note then
			toast(result.note, result.noteKind or "good")
		end
	end
end

-- Wiring -------------------------------------------------------------------------------

local PANEL_TO_TAB = { Odds = "ODDS", Tackle = "RODS", Dashes = "DASHES" }

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

-- Beacon countdown between server pushes
task.spawn(function()
	while true do
		task.wait(0.5)
		refreshHUD()
		refreshGreed()
	end
end)
