-- Tidebound: Eggfall: fish thumbnails + 3D fish in the UI (Phase 4/5, 12 Oct).
-- Models: ReplicatedStorage.VoxelFish.<Name> (voxel Parts, pivot centred, head +X).
-- Thumbs: Tidebound.FishThumbs (rendered from the same voxel data, painted outline).
--   FishView.thumb(parent, name, owned)  -> ImageLabel (black silhouette when not owned)
--   FishView.viewport(parent, name, opts) -> ViewportFrame, opts.spin (deg/s), opts.drag (click-drag to rotate)
--   FishView.open(gui, name, tierColor, subtitle) -> big modal with the drag-to-rotate viewer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Thumbs = require(script.Parent:WaitForChild("FishThumbs"))
local models = ReplicatedStorage:WaitForChild("VoxelFish")

local FishView = {}

function FishView.thumb(parent, name, owned)
	local img = Instance.new("ImageLabel")
	img.Name = "FishThumb"
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.42)
	img.Size = UDim2.fromScale(0.86, 0.86)
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = Thumbs[name] or ""
	img.ImageColor3 = owned and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	img.ImageTransparency = owned and 0 or 0.45
	img.ZIndex = 2
	img.Parent = parent
	return img
end

-- A ViewportFrame showing the fish, lit like the thumbnails (warm key from the top-left, cool ambient).
function FishView.viewport(parent, name, opts)
	opts = opts or {}
	local source = models:FindFirstChild(name)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "FishViewport"
	vp.BackgroundTransparency = 1
	vp.Size = opts.size or UDim2.fromScale(1, 1)
	vp.Position = opts.position or UDim2.fromScale(0.5, 0.5)
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Ambient = Color3.fromRGB(150, 160, 185)
	vp.LightColor = Color3.fromRGB(255, 248, 235)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
	vp.ZIndex = opts.zindex or 3
	vp.Parent = parent
	if not source then
		return vp
	end
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local fish = source:Clone()
	fish:PivotTo(CFrame.new())
	fish.Parent = world
	local _, size = fish:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = size.Magnitude / (2 * math.tan(math.rad(cam.FieldOfView / 2))) * (opts.zoom or 1.05)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.12, dist), Vector3.zero)
	cam.Parent = vp
	vp.CurrentCamera = cam

	-- yaw/pitch, spun or dragged; the fish starts at a 3/4 view facing right
	local yaw, pitch = math.rad(-35), math.rad(12)
	local dragging, last
	local function apply()
		fish:PivotTo(CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, yaw, 0))
	end
	apply()
	local conns = {}
	if opts.spin then
		table.insert(conns, RunService.RenderStepped:Connect(function(dt)
			if not dragging then
				yaw += math.rad(opts.spin) * dt
				apply()
			end
		end))
	end
	if opts.drag then
		vp.Active = true
		table.insert(conns, vp.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, last = true, input.Position
			end
		end))
		table.insert(conns, UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - last
				last = input.Position
				yaw += math.rad(delta.X * 0.6)
				pitch = math.clamp(pitch + math.rad(delta.Y * 0.4), math.rad(-80), math.rad(80))
				apply()
			end
		end))
		table.insert(conns, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end))
	end
	vp.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
	return vp
end

-- Full-screen-ish modal: dark backdrop, framed viewer, name + tier, drag hint, close button. One at a time.
local current
function FishView.open(gui, name, tierColor, subtitle)
	if current then
		current:Destroy()
	end
	tierColor = tierColor or Color3.fromRGB(255, 196, 40)
	local back = Instance.new("TextButton")
	back.Name = "FishViewer"
	back.Text = ""
	back.AutoButtonColor = false
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 50
	back.Parent = gui
	current = back

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.42, 0.62)
	panel.BackgroundColor3 = Color3.fromRGB(24, 14, 22)
	panel.ZIndex = 51
	panel.Active = true -- clicks on the panel must not reach the backdrop (that closes it)
	panel.Parent = back
	Instance.new("UIAspectRatioConstraint", panel).AspectRatio = 0.9
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke", panel)
	stroke.Color = tierColor
	stroke.Thickness = 4
	local glow = Instance.new("UIGradient", panel)
	glow.Rotation = 90
	glow.Color = ColorSequence.new(Color3.fromRGB(70, 45, 70), Color3.fromRGB(20, 12, 20))
	local scale = Instance.new("UIScale", panel)
	scale.Scale = 0.7

	-- light rays behind the fish, slowly turning
	local rays = Instance.new("ImageLabel")
	rays.BackgroundTransparency = 1
	rays.Image = "rbxassetid://124496090301374"
	rays.ImageColor3 = tierColor
	rays.ImageTransparency = 0.55
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.45)
	rays.Size = UDim2.fromScale(1.05, 1.05 * 0.9)
	rays.ZIndex = 52
	rays.Parent = panel
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += 12 * dt
	end)
	back.Destroying:Connect(function()
		spin:Disconnect()
	end)

	FishView.viewport(panel, name, { drag = true, spin = 18, zindex = 53, size = UDim2.fromScale(0.95, 0.72), position = UDim2.fromScale(0.5, 0.44) })

	local function text(t, size, y, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.Text = t
		l.TextSize = size
		l.TextColor3 = color
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.new(1, -20, 0, size + 4)
		l.ZIndex = 54
		l.Parent = panel
		local s = Instance.new("UIStroke", l)
		s.Thickness = 2
		s.Color = Color3.fromRGB(20, 10, 18)
		return l
	end
	text(name, 30, 0.8, Color3.new(1, 1, 1))
	text(subtitle or "", 20, 0.885, tierColor)
	text("Drag to rotate", 14, 0.04, Color3.fromRGB(200, 190, 210))

	local close = Instance.new("TextButton")
	close.Text = "X"
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 22
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(40, 40)
	close.ZIndex = 56
	close.Parent = panel
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
	local cs = Instance.new("UIStroke", close)
	cs.Thickness = 2.5
	cs.Color = Color3.fromRGB(90, 10, 20)

	local function shut()
		if current == back then
			current = nil
		end
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0.7 }):Play()
		TweenService:Create(back, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
		task.delay(0.15, function()
			back:Destroy()
		end)
	end
	close.Activated:Connect(shut)
	back.Activated:Connect(shut)
	TweenService:Create(back, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return back
end

return FishView
