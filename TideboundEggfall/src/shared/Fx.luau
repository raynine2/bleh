-- Tidebound: Eggfall: blocky one-shot effects for the client scripts (Big Update), in the voxel style of the
-- reference video: bursts of glowing cubes, gold lightning bolts, shock rings, "!" alerts, damage numbers and
-- a red flash on a hit body. Everything here is made on this screen only and cleans itself up.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Fx = {}

local folder = nil
local function fxFolder()
	if not folder or not folder.Parent then
		folder = workspace:FindFirstChild("TideboundFX")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "TideboundFX"
			folder.Parent = workspace
		end
	end
	return folder
end
Fx.folder = fxFolder

local rng = Random.new()

local function bit(size, color, cframe, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.CFrame = cframe
	p.Parent = fxFolder()
	return p
end

local function pick(color)
	if type(color) == "table" then
		return color[rng:NextInteger(1, #color)]
	end
	return color
end

local function spin()
	return CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
end

-- A burst of glowing cubes flying out of `at`. opts: spread (studs), size, life (s), up (0 flat .. 1 tall
-- dome), count, material.
function Fx.cubes(at, color, opts)
	opts = opts or {}
	local spread, size, life, up = opts.spread or 6, opts.size or 0.6, opts.life or 0.6, opts.up or 0.6
	for _ = 1, opts.count or 12 do
		local s = size * rng:NextNumber(0.6, 1.4)
		local p = bit(Vector3.new(s, s, s), pick(color), CFrame.new(at) * spin(), opts.material)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.15, 1) * up, rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.05 then
			dir = Vector3.new(0, 1, 0)
		end
		local goal = CFrame.new(at + dir.Unit * spread * rng:NextNumber(0.45, 1)) * spin()
		local t = life * rng:NextNumber(0.7, 1.3)
		TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = goal, Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 0.4 }):Play()
		Debris:AddItem(p, t + 0.1)
	end
end

-- A flat ring that grows out from `at` and fades (landings, shockwaves, guardian strikes).
function Fx.ring(at, color, radius, life, thickness)
	life = life or 0.45
	local p = bit(Vector3.new(thickness or 0.25, 1, 1), color, CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)))
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.2
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(thickness or 0.25, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.1)
	return p
end

-- Gold zig-zag lightning bolts that pop out around `at` and fade (the catch celebration in the video).
function Fx.bolts(at, count, color)
	color = color or Color3.fromRGB(255, 226, 70)
	for i = 1, count or 4 do
		local angle = (i / (count or 4)) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = at + out * rng:NextNumber(2, 3.5) + Vector3.new(0, rng:NextNumber(-0.5, 1.5), 0)
		local frame = CFrame.lookAt(base, base + out) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4))
		local model = Instance.new("Model")
		model.Name = "Bolt"
		for j, offset in ipairs({ CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, -0.5), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0.5), CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, -0.5) }) do
			local seg = bit(Vector3.new(0.35, 1.5, 0.35), color, frame * offset)
			seg.Name = "Seg" .. j
			seg.Parent = model
		end
		model.Parent = fxFolder()
		for _, seg in ipairs(model:GetChildren()) do
			local p = seg :: BasePart
			local goal = p.CFrame + out * 1.6 + Vector3.new(0, 1.2, 0)
			TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = goal }):Play()
			TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { Transparency = 1 }):Play()
		end
		Debris:AddItem(model, 0.9)
	end
end

-- A spinning star of light (two crossed neon cubes) that flies up from `at`.
function Fx.stars(at, count, color)
	color = color or Color3.fromRGB(255, 236, 120)
	for _ = 1, count or 6 do
		local s = rng:NextNumber(0.5, 0.9)
		local start = CFrame.new(at + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)))
		local a = bit(Vector3.new(s, s, 0.2), color, start * CFrame.Angles(0, 0, math.rad(45)))
		local goal = start + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(3, 6), rng:NextNumber(-4, 4))
		local t = rng:NextNumber(0.6, 0.9)
		TweenService:Create(a, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal * CFrame.Angles(0, rng:NextNumber(2, 5), math.rad(45)), Transparency = 1 }):Play()
		Debris:AddItem(a, t + 0.1)
	end
end

-- A "!" (or any short text) that pops up over `adornee` and floats there for `seconds`.
function Fx.alert(adornee, text, color, seconds, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "TideboundAlert"
	gui.Size = UDim2.fromOffset(10, 10)
	gui.StudsOffset = Vector3.new(0, offset or 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = color or Color3.fromRGB(255, 60, 60)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text or "!"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 20)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = label
	label.Parent = gui
	gui.Adornee = adornee
	gui.Parent = fxFolder()
	local size = (#(text or "!") > 2) and UDim2.fromOffset(110, 40) or UDim2.fromOffset(46, 46)
	TweenService:Create(gui, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size, StudsOffset = Vector3.new(0, (offset or 3) + 1, 0) }):Play()
	task.delay(seconds or 1, function()
		if gui.Parent then
			TweenService:Create(gui, TweenInfo.new(0.15), { Size = UDim2.fromOffset(4, 4) }):Play()
			Debris:AddItem(gui, 0.2)
		end
	end)
	return gui
end

-- A number (like "-25") that jumps out of `adornee` and fades.
function Fx.number(adornee, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "TideboundNumber"
	gui.Size = UDim2.fromOffset(120, 44)
	gui.StudsOffset = Vector3.new(rng:NextNumber(-1, 1), 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 100
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 70, 70)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Adornee = adornee
	gui.Parent = fxFolder()
	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

-- Flashes a whole model a colour (a hit body flashes red), fading out over `seconds`.
function Fx.flashModel(model, color, seconds)
	local h = Instance.new("Highlight")
	h.Name = "TideboundFlash"
	h.FillColor = color or Color3.fromRGB(255, 60, 60)
	h.FillTransparency = 0.15
	h.OutlineColor = Color3.new(1, 1, 1)
	h.OutlineTransparency = 0.3
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = fxFolder()
	TweenService:Create(h, TweenInfo.new(seconds or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(h, (seconds or 0.4) + 0.1)
end

return Fx
