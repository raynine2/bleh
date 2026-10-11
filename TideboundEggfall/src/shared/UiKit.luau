-- Tidebound: Eggfall UI kit: the REF 4 menu style (black panel, red neon outline, diagonal stripes, gradient bars,
-- FredokaOne captions) as reusable pieces, so new windows look like TideboundClient's menu. Scale-friendly:
-- windows size by scale with a UISizeConstraint, and every window gets a UIScale tied to the screen height.

local TweenService = game:GetService("TweenService")

local UiKit = {}

UiKit.DISPLAY = Enum.Font.FredokaOne
UiKit.BODY = Enum.Font.BuilderSansBold
UiKit.WHITE = Color3.new(1, 1, 1)

-- Section 7 Clarity Rule 3: text and bars sit on near-black panels with a dark text stroke, so contrast against
-- the panel stays well above 4.5:1 whatever the world behind looks like.
UiKit.C = {
	neon = Color3.fromRGB(255, 42, 62),
	panel = Color3.fromRGB(16, 4, 8),
	row = Color3.fromRGB(40, 8, 14),
	ink = Color3.fromRGB(26, 4, 10),
	text = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(226, 196, 200),
	good = Color3.fromRGB(120, 240, 150),
	bad = Color3.fromRGB(255, 90, 90),
	warn = Color3.fromRGB(255, 200, 70),
	gold = Color3.fromRGB(255, 206, 60),
	blue = Color3.fromRGB(70, 180, 255),
}
local C = UiKit.C

UiKit.TILE = {
	red = { top = Color3.fromRGB(240, 52, 60), bottom = Color3.fromRGB(184, 20, 32), outline = Color3.fromRGB(255, 70, 80) },
	gold = { top = Color3.fromRGB(255, 196, 30), bottom = Color3.fromRGB(214, 132, 8), outline = Color3.fromRGB(255, 226, 90) },
	blue = { top = Color3.fromRGB(40, 140, 255), bottom = Color3.fromRGB(18, 76, 214), outline = Color3.fromRGB(90, 210, 255) },
	green = { top = Color3.fromRGB(70, 210, 110), bottom = Color3.fromRGB(26, 150, 70), outline = Color3.fromRGB(130, 255, 170) },
	purple = { top = Color3.fromRGB(170, 90, 255), bottom = Color3.fromRGB(110, 40, 200), outline = Color3.fromRGB(200, 150, 255) },
	grey = { top = Color3.fromRGB(92, 92, 96), bottom = Color3.fromRGB(58, 58, 62), outline = Color3.fromRGB(134, 134, 140) },
}

function UiKit.new(className, props, children)
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
local new = UiKit.new

function UiKit.corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UiKit.stroke(color, thickness, transparency)
	return new("UIStroke", { Color = color or C.neon, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UiKit.textStroke(thickness)
	return new("UIStroke", { Color = C.ink, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function UiKit.gloss(top, bottom)
	return new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) })
end

function UiKit.padding(px)
	return new("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end

function UiKit.list(gap, horizontal, align)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function UiKit.label(props, children)
	local defaults = { BackgroundTransparency = 1, Font = UiKit.BODY, TextColor3 = C.text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local l = new("TextLabel", defaults, children)
	if not l:FindFirstChildOfClass("UIStroke") then
		UiKit.textStroke(defaults.Font == UiKit.DISPLAY and (defaults.TextSize >= 22 and 3 or 2) or 1.2).Parent = l
	end
	return l
end

-- Diagonal stripe texture, clipped by a CanvasGroup.
function UiKit.stripes(parent, spacing, width, transparency, radius)
	local group = new("CanvasGroup", { Name = "Stripes", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = transparency, ZIndex = 0, Parent = parent }, { UiKit.corner(radius or 8) })
	for i = -6, 60 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, i * spacing, 0.5, 0), Size = UDim2.new(0, width, 4, 0), Rotation = 35, BackgroundColor3 = UiKit.WHITE, BorderSizePixel = 0, Parent = group })
	end
	return group
end

-- A gradient bar button. `onClick` runs on Activated. Sound: fires ClientBus "ui" Click if a bus is given.
function UiKit.button(props, style, onClick)
	local defaults = { BackgroundTransparency = 1, Font = UiKit.DISPLAY, TextColor3 = C.text, TextSize = 16, AutoButtonColor = false, Text = "" }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	defaults.TextTransparency = 1
	local s = UiKit.TILE[style or "red"]
	local b = new("TextButton", defaults, { UiKit.corner(6) })
	UiKit.stroke(s.outline, 2).Parent = b
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UiKit.WHITE, ZIndex = 0, Parent = b }, { UiKit.corner(6), UiKit.gloss(s.top, s.bottom) })
	UiKit.stripes(fill, 16, 5, 0.86, 6)
	local caption = UiKit.label({ Name = "Caption", Text = b.Text, Font = b.Font, TextSize = b.TextSize, TextColor3 = b.TextColor3, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	b:GetPropertyChangedSignal("Text"):Connect(function()
		caption.Text = b.Text
	end)
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		fill.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
	end)
	b.MouseLeave:Connect(function()
		fill.BackgroundColor3 = UiKit.WHITE
		scale.Scale = 1
	end)
	b.MouseButton1Down:Connect(function()
		fill.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.95 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		fill.BackgroundColor3 = UiKit.WHITE
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	b:SetAttribute("Style", style or "red")
	if onClick then
		b.Activated:Connect(function()
			if UiKit.onClick then
				UiKit.onClick()
			end
			onClick()
		end)
	end
	return b
end

function UiKit.restyle(b, style)
	if b:GetAttribute("Style") == style then
		return
	end
	b:SetAttribute("Style", style)
	local s = UiKit.TILE[style]
	b.Fill:FindFirstChildOfClass("UIGradient"):Destroy()
	UiKit.gloss(s.top, s.bottom).Parent = b.Fill
	b:FindFirstChildOfClass("UIStroke").Color = s.outline
	b.Caption.TextColor3 = style == "grey" and Color3.fromRGB(210, 210, 214) or C.text
end

-- Dark neon panel. `plain` skips the halo and stripes (for panels with a UIListLayout inside).
function UiKit.panel(props, radius, plain)
	local defaults = { BackgroundColor3 = C.panel }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local frame = new("Frame", defaults, { UiKit.corner(radius or 8), UiKit.stroke(C.neon, 2.5) })
	if not plain then
		UiKit.stripes(frame, 26, 9, 0.96, radius)
	end
	return frame
end

-- A progress bar: returns the background frame and the fill (set fill.Size.X.Scale).
function UiKit.bar(parent, props, color)
	local defaults = { BackgroundColor3 = Color3.fromRGB(30, 10, 14), BorderSizePixel = 0 }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local back = new("Frame", defaults, { UiKit.corner(5), UiKit.stroke(Color3.fromRGB(80, 30, 36), 1.5) })
	back.Parent = parent
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = UiKit.WHITE, BorderSizePixel = 0, Parent = back }, {
		UiKit.corner(5),
		UiKit.gloss((color or C.gold):Lerp(UiKit.WHITE, 0.25), color or C.gold),
	})
	return back, fill
end

-- A small rounded chip coloured by the canon rarity spectrum.
function UiKit.chip(parent, text, color, order)
	local chip = new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 22), BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55), LayoutOrder = order or 0, Parent = parent }, {
		UiKit.corner(11),
		UiKit.stroke(color, 1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	UiKit.label({ Text = text, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextSize = 13, TextColor3 = UiKit.WHITE, TextWrapped = false, Parent = chip })
	return chip
end

function UiKit.fmt(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

function UiKit.duration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%dm %ds"):format(m, seconds % 60)
end

-- Opens a window: Position slides up from +0.06 Y (Back Out 0.3 s) while the CanvasGroup fades in; closing slides down
-- (Quad In 0.16 s) and fades, then hides. Only Position and GroupTransparency move: tweening Size or a UIScale of a
-- window full of text re-fits every label each frame. A BlurEffect in Lighting follows the open state.
local Lighting = game:GetService("Lighting")
local blur = Lighting:FindFirstChild("TideboundMenusBlur") or Instance.new("BlurEffect")
blur.Name = "TideboundMenusBlur"
blur.Size = 0
blur.Parent = Lighting

function UiKit.show(window, visible)
	local base = window:GetAttribute("BasePos")
	if not base then
		base = window.Position
		window:SetAttribute("BasePos", base)
	end
	local token = (window:GetAttribute("ShowToken") or 0) + 1
	window:SetAttribute("ShowToken", token)
	local below = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale + 0.06, base.Y.Offset)
	local isGroup = window:IsA("CanvasGroup")
	if visible then
		window.Position = below
		if isGroup then
			window.GroupTransparency = 1
		end
		window.Visible = true
		TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = base }):Play()
		if isGroup then
			TweenService:Create(window, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
		end
		TweenService:Create(blur, TweenInfo.new(0.3), { Size = 12 }):Play()
	else
		local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(window, info, { Position = below }):Play()
		if isGroup then
			TweenService:Create(window, info, { GroupTransparency = 1 }):Play()
		end
		TweenService:Create(blur, TweenInfo.new(0.16), { Size = 0 }):Play()
		task.delay(0.16, function()
			if window:GetAttribute("ShowToken") == token then
				window.Visible = false
			end
		end)
	end
end

return UiKit
