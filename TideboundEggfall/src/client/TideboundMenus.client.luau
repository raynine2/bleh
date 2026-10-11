-- Tidebound: Eggfall retention menus (GDD Sections 6, 7, 12): QUESTS, season PASS, SHOP, BOARDS, egg ODDS and
-- SETTINGS windows plus the launcher column beside the main menu. Display only: every reward, price and odds
-- figure comes from the server (Remotes.LiveOps / LiveOpsPush) or LiveOpsData text; the server validates all clicks.
-- Windows share one shell (REF 4 banner, tabs, scrolling content, toast) and only the open one is rebuilt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local UiKit = require(Shared:WaitForChild("UiKit"))
local ClientBus = require(Shared:WaitForChild("ClientBus"))
local LiveOpsData = require(Shared:WaitForChild("LiveOpsData"))
local Biomes = require(Shared:WaitForChild("Biomes"))
local UiIcons = require(Shared:WaitForChild("UiIcons"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local LiveOpsRemote = Remotes:WaitForChild("LiveOps")
local PushEvent = Remotes:WaitForChild("LiveOpsPush")
local Request = Remotes:WaitForChild("Request")

local new, corner, stroke, padding, list = UiKit.new, UiKit.corner, UiKit.stroke, UiKit.padding, UiKit.list
local fmt, duration = UiKit.fmt, UiKit.duration
local C, TILE, DISPLAY, BODY, WHITE = UiKit.C, UiKit.TILE, UiKit.DISPLAY, UiKit.BODY, UiKit.WHITE
local DARK_LINE = Color3.fromRGB(80, 30, 36)
local ROW_TOP, ROW_BOTTOM = Color3.fromRGB(54, 12, 20), Color3.fromRGB(34, 6, 12)
local PURPLE = Color3.fromRGB(200, 150, 255)

UiKit.onClick = function()
	ClientBus.signal:Fire("ui", "Click")
end

local gui = new("ScreenGui", { Name = "TideboundMenus", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })

-- State ---------------------------------------------------------------------------------------------------------------

local view = nil -- latest LiveOps.view
local viewClock = 0 -- os.clock() when `view` arrived
local windows = {} -- [name] = win
local dirty = {} -- [name] = true when the content needs a rebuild on next open
local openName = nil
local busy = false -- one server action at a time
local updateBadges -- forward declaration
local renderWindow, applyView -- forward declarations

local function serverNow()
	return (view and view.now or os.time()) + (os.clock() - viewClock)
end

-- Small helpers -------------------------------------------------------------------------------------------------------

-- Wrapped label: full width and auto height unless the caller gives a Size.
local function text(parent, str, size, props)
	local p = { Text = str, TextSize = size or 15, Parent = parent }
	if not (props and props.Size) then
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
	end
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return UiKit.label(p)
end

local function call(remote, ...)
	local args = table.pack(...)
	local ok, result = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return { error = "Connection problem. Try again." }
	end
	if type(result) ~= "table" then
		return {}
	end
	return result
end

-- Toast pill that slides up from the bottom of the window (green ok / red error) and hides after 2.5 s.
local TOAST_SHOWN, TOAST_HIDDEN = UDim2.new(0.5, 0, 1, -10), UDim2.new(0.5, 0, 1, 50)

local function hideToast(win)
	win.statusToken = (win.statusToken or 0) + 1
	TweenService:Create(win.toast, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = TOAST_HIDDEN }):Play()
end

local function setStatus(win, msg, good)
	win.status.Text = msg
	win.status.TextColor3 = WHITE
	win.toast.BackgroundColor3 = good and Color3.fromRGB(22, 96, 48) or Color3.fromRGB(128, 22, 30)
	win.toastStroke.Color = good and C.good or C.bad
	TweenService:Create(win.toast, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = TOAST_SHOWN }):Play()
	win.statusToken = (win.statusToken or 0) + 1
	local token = win.statusToken
	task.delay(2.5, function()
		if win.statusToken == token then
			hideToast(win)
		end
	end)
end

local function refreshView()
	local result = call(LiveOpsRemote, "Get")
	if not result.error and result.daily then
		applyView(result)
	end
end

-- Runs one server action with status + sounds, then refreshes the view.
local function act(win, okText, remote, ...)
	if busy then
		return nil
	end
	busy = true
	local result = call(remote, ...)
	busy = false
	if result.error then
		setStatus(win, tostring(result.error), false)
		ClientBus.signal:Fire("ui", "Error")
	else
		setStatus(win, result.granted and ("Claimed: " .. tostring(result.granted)) or okText or "Done.", true)
		ClientBus.signal:Fire("ui", "Claim")
		refreshView()
	end
	return result
end

local function live(win, okText, ...)
	return act(win, okText, LiveOpsRemote, ...)
end

local function rarity(tier)
	return (Biomes.rarityColor(tier or 1))
end

local function rewardParts(reward)
	local parts = {}
	if reward.pearls then
		table.insert(parts, "+" .. fmt(reward.pearls) .. " Pearls")
	end
	if reward.shards then
		table.insert(parts, "+" .. fmt(reward.shards) .. " Egg Shards")
	end
	if reward.embers then
		table.insert(parts, "+" .. fmt(reward.embers) .. " Embers")
	end
	if reward.tideglass then
		table.insert(parts, "+" .. fmt(reward.tideglass) .. " Tideglass")
	end
	if reward.bait then
		table.insert(parts, ("%s x%d"):format(reward.bait.id, reward.bait.count))
	end
	if reward.xp then
		table.insert(parts, "+" .. fmt(reward.xp) .. " XP")
	end
	if reward.cosmetic then
		local cosmetic = LiveOpsData.cosmetics[reward.cosmetic]
		table.insert(parts, cosmetic and cosmetic.name or reward.cosmetic)
	end
	return parts
end

local function setButton(b, caption, style)
	b.Text = caption
	UiKit.restyle(b, style)
end

-- Counts what could be claimed right now (badges on the launcher).
local function claimable(row)
	return row.progress >= row.goal and not row.claimed
end

local function questBadge()
	if not view then
		return 0
	end
	local n = 0
	local function count(rows)
		for _, row in ipairs(rows or {}) do
			if claimable(row) then
				n += 1
			end
		end
	end
	count(view.daily.quests)
	count(view.weekly.goals)
	count(view.event and view.event.goals)
	count(view.collection.creatures.goals)
	count(view.collection.fish.goals)
	return n
end

local function passBadge()
	if not view then
		return 0
	end
	local s, n = view.season, 0
	for tier = 1, s.tier do
		if not s.claimedFree[tostring(tier)] then
			n += 1
		end
		if s.premium and not s.claimedPremium[tostring(tier)] then
			n += 1
		end
	end
	return n
end

-- Window shell --------------------------------------------------------------------------------------------------------

local function clearContent(win)
	for _, child in ipairs(win.content:GetChildren()) do
		if not (child:IsA("UIListLayout") or child:IsA("UIPadding")) then
			child:Destroy()
		end
	end
end

local function layoutShell(win)
	local top = win.tabNames and 78 or 46
	win.content.Position = UDim2.new(0, 12, 0, top)
	win.content.Size = UDim2.new(1, -24, 1, -(top + 12 + win.footerH))
	win.footer.Position = UDim2.new(0, 12, 1, -(8 + win.footerH))
	win.footer.Size = UDim2.new(1, -24, 0, win.footerH)
	win.footer.Visible = win.footerH > 0
end

local function setFooter(win, str, height)
	win.footer.Text = str or ""
	win.footerH = (str and str ~= "") and (height or 32) or 0
	layoutShell(win)
end

local function closeWindow()
	local name = openName
	if not name then
		return
	end
	openName = nil
	local win = windows[name]
	win.session = (win.session or 0) + 1
	UiKit.show(win.frame, false)
	ClientBus.setMenu(name, false)
end

local function openWindow(name)
	if openName == name then
		return
	end
	closeWindow()
	local win = windows[name]
	if not win then
		return
	end
	openName = name
	UiKit.show(win.frame, true)
	ClientBus.setMenu(name, true)
	win.toast.Position = TOAST_HIDDEN
	if win.onOpen then
		win.onOpen(win)
	end
	if dirty[name] then
		renderWindow(win, false)
	end
	if not view then
		task.spawn(refreshView)
	end
end

local function selectTab(win, index)
	win.tab = index
	for i, b in ipairs(win.tabButtons) do
		UiKit.restyle(b, i == index and "red" or "grey")
	end
	renderWindow(win, false)
end

function renderWindow(win, keepScroll)
	dirty[win.name] = false
	win.ticks = {}
	win.shines = {}
	win.pulses = {}
	local pos = win.content.CanvasPosition
	win.render(win)
	if keepScroll then
		task.defer(function()
			win.content.CanvasPosition = pos
		end)
	else
		win.content.CanvasPosition = Vector2.zero
	end
end

-- Device scaling: one UIScale per top-level container, set at start and on viewport resize, never animated.
local deviceScales = {}

local function viewportScale()
	local camera = workspace.CurrentCamera
	return camera and math.clamp(camera.ViewportSize.Y / 1080, 0.65, 1.35) or 1
end

local function addDeviceScale(container)
	local scale = new("UIScale", { Name = "DeviceScale", Scale = viewportScale(), Parent = container })
	table.insert(deviceScales, scale)
end

do
	local connected = nil
	local function hook()
		local camera = workspace.CurrentCamera
		if not camera or camera == connected then
			return
		end
		connected = camera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local value = viewportScale()
			for _, scale in ipairs(deviceScales) do
				scale.Scale = value
			end
		end)
	end
	hook()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
end

-- Soft neon glow just outside a panel: a transparent frame whose thick stroke fades out.
local function halo(parent, color, radius)
	return new("Frame", { Name = "Halo", BackgroundTransparency = 1, Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4), ZIndex = 0, Parent = parent }, {
		corner((radius or 8) + 4),
		stroke(color, 5, 0.72),
	})
end

-- REF 4 banner: slanted red bar with stripes, diamond tip and a four-point sparkle, sticking out of the top-left.
local function buildBanner(panel, title)
	local textWidth = TextService:GetTextSize(title, 26, DISPLAY, Vector2.new(600, 60)).X
	local width = math.ceil(textWidth) + 96
	local banner = new("Frame", { Name = "Banner", BackgroundTransparency = 1, Position = UDim2.fromOffset(-26, -36), Size = UDim2.fromOffset(width, 58), Rotation = -3, ZIndex = 6, Parent = panel })
	local bar = new("Frame", { Name = "Bar", BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = banner }, {
		corner(4), UiKit.gloss(Color3.fromRGB(255, 60, 70), Color3.fromRGB(196, 16, 30)), stroke(Color3.fromRGB(255, 90, 100), 2.5),
	})
	halo(bar, C.neon, 4)
	UiKit.stripes(bar, 22, 10, 0.86, 4)
	new("Frame", { Name = "Tip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(41, 41), Rotation = 45, BackgroundColor3 = Color3.fromRGB(222, 36, 48), BorderSizePixel = 0, ZIndex = 5, Parent = banner }, { stroke(Color3.fromRGB(255, 90, 100), 2.5) })
	local star = new("Frame", { Position = UDim2.new(0, 10, 0.5, -20), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, ZIndex = 7, Parent = bar })
	for _, size in ipairs({ UDim2.new(0, 7, 1, 0), UDim2.new(1, 0, 0, 7) }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, BackgroundColor3 = WHITE, ZIndex = 7, Parent = star }, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Color = Color3.fromRGB(255, 170, 180), Thickness = 2, Transparency = 0.4 }),
		})
	end
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Rotation = 45, BackgroundColor3 = WHITE, ZIndex = 7, Parent = star })
	UiKit.label({ Text = title, Font = DISPLAY, TextSize = 26, Position = UDim2.fromOffset(58, 0), Size = UDim2.new(1, -64, 1, 0), TextWrapped = false, ZIndex = 7, Parent = bar })
end

-- The window root is a CanvasGroup (fades as one) with margins so the banner, X and halo stay inside its canvas.
local function buildShell(name, title, tabNames, render)
	local win = { name = name, tab = 1, ticks = {}, shines = {}, pulses = {}, tabButtons = {}, tabNames = tabNames, footerH = 0, render = render }
	local root = new("CanvasGroup", {
		Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -3, 0.5, -20), Size = UDim2.new(0.62, 34, 0.74, 72),
		BackgroundTransparency = 1, Visible = false, Parent = gui,
	}, { new("UISizeConstraint", { MaxSize = Vector2.new(814, 652), MinSize = Vector2.new(374, 392) }) })
	addDeviceScale(root)
	win.frame = root
	local frame = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -34, 1, -72), BackgroundColor3 = C.panel, Parent = root }, { corner(10), stroke(C.neon, 2.5) })
	halo(frame, C.neon, 10)
	UiKit.stripes(frame, 26, 9, 0.96, 10)
	win.panel = frame

	buildBanner(frame, title)
	UiKit.button({ Name = "Close", Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -48), Text = "X", TextSize = 20, ZIndex = 7, Parent = frame }, "red", closeWindow)
	win.pills = new("Frame", { Name = "Pills", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, -44), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 7, Parent = frame }, { list(6, true) })

	if tabNames then
		local bar = new("Frame", { Name = "Tabs", Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1, Parent = frame }, { list(6, true) })
		for i, tabName in ipairs(tabNames) do
			local b = UiKit.button({ Size = UDim2.new(1 / #tabNames, -6, 1, 0), Text = tabName, TextSize = 14, LayoutOrder = i, Parent = bar }, i == 1 and "red" or "grey", function()
				selectTab(win, i)
			end)
			table.insert(win.tabButtons, b)
		end
	end

	win.content = new("ScrollingFrame", {
		Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollBarThickness = 6, ScrollBarImageColor3 = C.neon, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = frame,
	}, { list(8), new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }) })
	win.footer = UiKit.label({ Name = "Footer", Text = "", TextSize = 13, TextColor3 = C.muted, Visible = false, TextYAlignment = Enum.TextYAlignment.Top, Parent = frame })
	win.toast = new("Frame", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 1), Position = TOAST_HIDDEN, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(22, 96, 48), ZIndex = 10, Parent = frame }, {
		new("UICorner", { CornerRadius = UDim.new(0, 16) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	})
	win.toastStroke = stroke(C.good, 2)
	win.toastStroke.Parent = win.toast
	win.status = UiKit.label({ Name = "Status", Text = "", TextSize = 15, Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = win.toast })
	layoutShell(win)

	windows[name] = win
	dirty[name] = true
	return win
end

-- Shared row pieces ---------------------------------------------------------------------------------------------------

local function header(parent, order, str, color)
	return text(parent, str, 18, { Font = DISPLAY, TextColor3 = color or C.gold, LayoutOrder = order })
end

local function countdown(win, parent, order, prefix, seconds)
	local clock = os.clock()
	local l = text(parent, "", 15, { TextColor3 = C.muted, LayoutOrder = order })
	local function tick()
		l.Text = prefix .. duration(seconds - (os.clock() - clock))
	end
	tick()
	table.insert(win.ticks, tick)
	return l
end

-- Icon + amount pill (currency strip in the SHOP / PASS headers).
local function pill(parent, order, iconName, amountText, color)
	local frame = new("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.ink, Parent = parent }, {
		new("UICorner", { CornerRadius = UDim.new(0, 15) }),
		stroke(color, 1.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 12) }),
	})
	local layout = list(5, true)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = frame
	UiIcons.make(iconName, { Size = UDim2.fromOffset(22, 22), LayoutOrder = 1, Parent = frame })
	UiKit.label({ Text = amountText, Font = DISPLAY, TextSize = 15, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 2, Parent = frame })
	return frame
end

local function setPills(win, entries)
	for _, child in ipairs(win.pills:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, e in ipairs(entries) do
		pill(win.pills, i, e[1], e[2], e[3])
	end
end

local function emptyState(parent, order, iconName, msg)
	local box = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 130), Parent = parent })
	UiIcons.make(iconName, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(60, 60), Parent = box })
	local l = UiKit.label({ Text = msg, TextSize = 15, TextColor3 = C.muted, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68), Size = UDim2.new(1, -24, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Parent = box })
	return box, l
end

-- Gold shine sweep across a claim button: a white band in a UIGradient whose Offset the Heartbeat loop moves -1 -> 1.
local function addShine(win, b)
	local shine = new("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = b.Fill }, { corner(6) })
	local gradient = new("UIGradient", {
		Rotation = 25,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	})
	table.insert(win.shines, gradient)
end

-- Green purchase button content: [caption] [currency icon] price. `price` = { icon = name or nil, text = string }.
local function buyContent(b, caption, price)
	b.Text = ""
	local layout = list(4, true, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3, Parent = b }, { layout })
	if caption ~= "" then
		UiKit.label({ Text = caption, Font = DISPLAY, TextSize = 14, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 1, Parent = inner })
	end
	if price.icon then
		UiIcons.make(price.icon, { Size = UDim2.fromOffset(20, 20), LayoutOrder = 2, Parent = inner })
	end
	UiKit.label({ Text = price.text, Font = DISPLAY, TextSize = 14, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 3, Parent = inner })
end

-- Auto-height row card: rounded, top-to-bottom gradient, 6px accent bar in `accent`, `info` column on the left
-- (leaves room for a 112px button on the right).
local function rowFrame(parent, order, accent)
	local frame = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = WHITE, Parent = parent }, {
		corner(8), UiKit.gloss(ROW_TOP, ROW_BOTTOM),
	})
	local outline = stroke(DARK_LINE, 1.5)
	outline.Parent = frame
	new("Frame", { Name = "Accent", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.new(0, 6, 1, -14), BackgroundColor3 = accent or DARK_LINE, BorderSizePixel = 0, Parent = frame }, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
	local info = new("Frame", { Name = "Info", BackgroundTransparency = 1, Size = UDim2.new(1, -134, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame }, {
		list(4), new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 8) }),
	})
	return frame, info, outline
end

local function rowButton(frame, caption, style, onClick)
	local b = UiKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(112, 34), Text = caption, TextSize = 15, Parent = frame }, style, onClick)
	if not onClick then
		b.Active = false
	end
	return b
end

local function chipRow(parent, order, parts, color)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent }, { list(4, true) })
	holder:FindFirstChildOfClass("UIListLayout").Wraps = true
	for i, part in ipairs(parts) do
		UiKit.chip(holder, part, color, i)
	end
	return holder
end

local function questRow(win, parent, order, row, action)
	local color = rarity(row.tier)
	local frame, info, outline = rowFrame(parent, order, color)
	text(info, row.text, 16, { Font = DISPLAY, LayoutOrder = 1 })
	local back, fill = UiKit.bar(info, { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2 }, color)
	fill.Size = UDim2.fromScale(math.clamp(row.progress / math.max(1, row.goal), 0, 1), 1)
	UiKit.label({ Text = ("%s / %s"):format(fmt(row.progress), fmt(row.goal)), TextSize = 12, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 2, Parent = back })
	chipRow(info, 3, rewardParts(row.reward), color)
	if row.claimed then
		rowButton(frame, "CLAIMED", "grey")
	elseif claimable(row) then
		local b = rowButton(frame, "CLAIM", "gold", function()
			live(win, nil, action, row.id)
		end)
		addShine(win, b)
		outline.Color = C.gold
		outline.Thickness = 2
		table.insert(win.pulses, outline)
	else
		rowButton(frame, "IN PROGRESS", "grey").Caption.TextSize = 13
	end
end

-- Generic row: title, sub text, button. `price` (optional) turns the button into [caption] [icon] price.
local function simpleRow(parent, order, title, sub, caption, style, onClick, color, price)
	local frame, info = rowFrame(parent, order, color)
	text(info, title, 16, { Font = DISPLAY, LayoutOrder = 1, TextColor3 = color and color:Lerp(WHITE, 0.5) or WHITE })
	if sub and sub ~= "" then
		text(info, sub, 14, { TextColor3 = C.muted, LayoutOrder = 2 })
	end
	local b = rowButton(frame, caption, style, onClick)
	b.Caption.TextSize = 14
	if price then
		buyContent(b, caption, price)
	end
	return frame, b
end

-- QUESTS --------------------------------------------------------------------------------------------------------------

-- Milestone track: bar filled to `count`, round nodes at goal/maxGoal (gold once reached).
local function milestoneTrack(parent, order, goals, count)
	local maxGoal = 1
	for _, g in ipairs(goals) do
		maxGoal = math.max(maxGoal, g.goal)
	end
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, Parent = parent })
	local track = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 12), BackgroundTransparency = 1, Parent = holder })
	local _, fill = UiKit.bar(track, { Size = UDim2.fromScale(1, 1) }, C.gold)
	fill.Size = UDim2.fromScale(math.clamp(count / maxGoal, 0, 1), 1)
	for _, g in ipairs(goals) do
		local reached = count >= g.goal
		local node = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(g.goal / maxGoal, 0.5), Size = UDim2.fromOffset(20, 20), ZIndex = 3, Parent = track,
			BackgroundColor3 = reached and C.gold or Color3.fromRGB(70, 60, 64),
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(reached and TILE.gold.outline or TILE.grey.outline, 2) })
		UiKit.label({ Text = tostring(g.goal), TextSize = 12, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(34, 14), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 3, Parent = node })
	end
end

local function renderQuests(win)
	local c = win.content
	clearContent(win)
	if not view then
		text(c, "Loading...", 16, { TextColor3 = C.muted })
		return
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local tab = win.tab
	if tab == 1 then
		countdown(win, c, nextOrder(), "New quests in ", view.daily.resetIn)
		for _, q in ipairs(view.daily.quests) do
			questRow(win, c, nextOrder(), q, "ClaimDaily")
		end
	elseif tab == 2 then
		countdown(win, c, nextOrder(), "Weekly goals reset in ", view.weekly.resetIn)
		for _, q in ipairs(view.weekly.goals) do
			questRow(win, c, nextOrder(), q, "ClaimWeekly")
		end
	elseif tab == 3 then
		local event = view.event
		if event then
			local banner = new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = event.color:Lerp(Color3.new(0, 0, 0), 0.6), Parent = c }, { corner(8), stroke(event.color, 2), list(3), padding(10) })
			text(banner, event.name, 22, { Font = DISPLAY, TextColor3 = event.color:Lerp(WHITE, 0.3), LayoutOrder = 1 })
			text(banner, event.blurb, 14, { LayoutOrder = 2 })
			countdown(win, banner, 3, "Ends in ", event.endsAt - view.now)
			for _, g in ipairs(event.goals) do
				questRow(win, c, nextOrder(), g, "ClaimEvent")
			end
		else
			emptyState(c, nextOrder(), "calendar", "No event running")
			local now = serverNow()
			for _, upcoming in ipairs(LiveOpsData.seasonal) do
				local starts = LiveOpsData.stamp(upcoming.starts)
				if starts > now then
					text(c, ("Next: %s starts %s"):format(upcoming.name, os.date("!%d %b", starts)), 16, { TextColor3 = upcoming.color, LayoutOrder = nextOrder() })
					text(c, upcoming.blurb, 14, { TextColor3 = C.muted, LayoutOrder = nextOrder() })
					break
				end
			end
		end
	else
		local col = view.collection
		header(c, nextOrder(), ("CREATURES %d / 14"):format(col.creatures.count))
		milestoneTrack(c, nextOrder(), col.creatures.goals, col.creatures.count)
		for _, g in ipairs(col.creatures.goals) do
			questRow(win, c, nextOrder(), g, "ClaimCollection")
		end
		header(c, nextOrder(), ("FISH SPECIES %d / 24"):format(col.fish.count))
		milestoneTrack(c, nextOrder(), col.fish.goals, col.fish.count)
		for _, g in ipairs(col.fish.goals) do
			questRow(win, c, nextOrder(), g, "ClaimCollection")
		end
	end
end

-- PASS ----------------------------------------------------------------------------------------------------------------

local passScrollX = nil

local function tierBlock(card, y, h, label, labelColor, reward, tierColor, purple)
	local block = new("Frame", { Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, h), BackgroundColor3 = purple and WHITE or C.ink, Parent = card }, { corner(6), stroke(tierColor, 1.5) })
	if purple then
		UiKit.gloss(Color3.fromRGB(24, 6, 18), Color3.fromRGB(62, 26, 92)).Parent = block
	end
	UiKit.label({ Text = label, Font = DISPLAY, TextSize = 13, TextColor3 = labelColor, Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 16), Parent = block })
	UiKit.label({ Text = table.concat(rewardParts(reward), ", "), TextSize = 13, TextColor3 = tierColor:Lerp(WHITE, 0.4), Position = UDim2.fromOffset(6, 20), Size = UDim2.new(1, -12, 0, 34), TextYAlignment = Enum.TextYAlignment.Top, Parent = block })
	return block
end

local function claimState(block, win, reached, claimed, tier, track)
	if claimed then
		UiKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 28), Text = "CLAIMED", TextSize = 13, Parent = block }, "grey")
	elseif reached then
		local b = UiKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 28), Text = "CLAIM", TextSize = 14, Parent = block }, "gold", function()
			live(win, nil, "ClaimSeason", tier, track)
		end)
		addShine(win, b)
	else
		UiKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 28), Text = "LOCKED", TextSize = 13, Parent = block }, "grey")
	end
end

local function renderPass(win)
	local c = win.content
	if win.scroller then
		passScrollX = win.scroller.CanvasPosition.X
	end
	clearContent(win)
	win.scroller = nil
	if not view then
		text(c, "Loading...", 16, { TextColor3 = C.muted })
		return
	end
	local s = view.season
	setPills(win, { { "pearl", fmt(view.currencies.pearls), C.gold }, { "gem", fmt(view.currencies.tideglass), C.blue } })
	text(c, s.name, 22, { Font = DISPLAY, LayoutOrder = 1 })
	text(c, ("Tier %d / %d"):format(s.tier, s.maxTier), 17, { Font = DISPLAY, TextColor3 = C.gold, LayoutOrder = 2 })
	local into = s.xp % s.xpPerTier
	if s.tier >= s.maxTier then
		into = s.xpPerTier
	end
	local back, fill = UiKit.bar(c, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 3 }, C.gold)
	fill.Size = UDim2.fromScale(math.clamp(into / s.xpPerTier, 0, 1), 1)
	UiKit.label({ Text = ("%s/%s XP"):format(fmt(into), fmt(s.xpPerTier)), TextSize = 13, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 2, Parent = back })
	if s.active then
		countdown(win, c, 4, "Ends in ", s.endsAt - view.now)
	else
		text(c, "The season is over", 16, { TextColor3 = C.bad, LayoutOrder = 4 })
	end

	local scroller = new("ScrollingFrame", {
		LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 264), BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
		ScrollBarThickness = 6, ScrollBarImageColor3 = C.neon, ScrollingDirection = Enum.ScrollingDirection.X, Parent = c,
	}, { list(8, true), new("UIPadding", { PaddingBottom = UDim.new(0, 10) }) })
	win.scroller = scroller
	for tier = 1, s.maxTier do
		local def = LiveOpsData.season.tiers[tier]
		if def then
			local reached = tier <= s.tier
			local tierColor = rarity(def.tier)
			local current = tier == s.tier
			-- a plain Frame: a CanvasGroup inside the window's CanvasGroup renders soft and faded, and upcoming rewards must
			-- stay readable (unreached tiers show as a grey outline and badge instead)
			local card = new("Frame", { LayoutOrder = tier, Size = UDim2.fromOffset(142, 248), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = scroller }, {
				corner(8), UiKit.gloss(ROW_TOP, ROW_BOTTOM), stroke(reached and C.gold or DARK_LINE, reached and 2.5 or 1.5),
			})
			-- round tier badge
			local badge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = reached and C.gold or Color3.fromRGB(70, 60, 64), Parent = card }, {
				new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(reached and TILE.gold.outline or TILE.grey.outline, 2),
			})
			UiKit.label({ Text = tostring(tier), Font = DISPLAY, TextSize = 16, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = badge })
			if current then
				local tag = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(34, 18), BackgroundColor3 = C.ink, Parent = card }, { new("UICorner", { CornerRadius = UDim.new(0, 9) }), stroke(C.gold, 1.5) })
				UiKit.label({ Text = "YOU", Font = DISPLAY, TextSize = 12, TextColor3 = C.gold, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = tag })
			end
			local free = tierBlock(card, 44, 92, "FREE", C.good, def.free, tierColor, false)
			claimState(free, win, reached, s.claimedFree[tostring(tier)] == true, tier, "free")
			local premium = tierBlock(card, 142, 98, "PREMIUM", PURPLE, def.premium, tierColor, true)
			if s.premium then
				claimState(premium, win, reached, s.claimedPremium[tostring(tier)] == true, tier, "premium")
			else
				UiIcons.make("lock", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(28, 28), Parent = premium })
			end
		end
	end
	if passScrollX then
		local x = passScrollX
		task.defer(function()
			scroller.CanvasPosition = Vector2.new(x, 0)
		end)
	else
		local x = math.max(0, (s.tier - 1) * 150)
		task.defer(function()
			scroller.CanvasPosition = Vector2.new(x, 0)
		end)
		passScrollX = x
	end

	if s.premium then
		text(c, "Premium unlocked. Thank you!", 16, { TextColor3 = C.good, LayoutOrder = 6 })
	elseif s.premiumOnSale then
		UiKit.button({ Size = UDim2.fromOffset(220, 40), LayoutOrder = 6, Text = "UNLOCK PREMIUM", TextSize = 18, Parent = c }, "green", function()
			live(win, "Check the purchase prompt.", "BuyPremium")
		end)
	else
		local b = UiKit.button({ Size = UDim2.fromOffset(260, 40), LayoutOrder = 6, Text = "PREMIUM COMING SOON", TextSize = 16, Parent = c }, "grey")
		b.Active = false
	end
	text(c, "Premium rewards are cosmetic only. No pay-to-win.", 14, { TextColor3 = C.muted, LayoutOrder = 7 })
end

-- SHOP ----------------------------------------------------------------------------------------------------------------

local function priceInfo(price)
	if price.pearls then
		return { icon = "pearl", text = fmt(price.pearls) }
	end
	return { icon = "gem", text = fmt(price.tideglass or 0) }
end

local function shopCosmetics(win, c, order)
	local grid = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = c }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 170), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in ipairs(LiveOpsData.shop.cosmetics) do
		local cosmetic = LiveOpsData.cosmetics[item.id]
		local color = rarity(cosmetic.tier)
		local card = UiKit.panel({ LayoutOrder = i, Parent = grid }, 8, true)
		card:FindFirstChildOfClass("UIStroke").Color = color
		UiKit.gloss(ROW_TOP, ROW_BOTTOM).Parent = card
		card.BackgroundColor3 = WHITE
		local preview = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 44), BackgroundColor3 = C.ink, Parent = card }, { corner(6) })
		if cosmetic.kind == "trail" then
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.85, 0, 0, 16), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = preview }, {
				corner(8), new("UIGradient", { Color = ColorSequence.new(cosmetic.colors[1], cosmetic.colors[2]) }),
			})
		else
			UiKit.label({ Text = cosmetic.name, Font = DISPLAY, TextSize = 17, TextColor3 = cosmetic.color, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = preview })
		end
		UiKit.label({ Text = cosmetic.name, Font = DISPLAY, TextSize = 15, Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 20), TextWrapped = false, Parent = card })
		local _, band = Biomes.rarityColor(cosmetic.tier)
		UiKit.label({ Text = (cosmetic.kind == "trail" and "Trail" or "Title") .. " - " .. tostring(band), TextSize = 13, TextColor3 = color, Position = UDim2.fromOffset(10, 80), Size = UDim2.new(1, -20, 0, 16), TextWrapped = false, Parent = card })
		local owned = view.cosmetics.owned[item.id]
		local b = UiKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 36), Text = owned and "OWNED" or "BUY", TextSize = 15, Parent = card }, owned and "grey" or "green", not owned and function()
			live(win, "Bought " .. cosmetic.name .. ".", "BuyCosmetic", item.id)
		end or nil)
		if owned then
			b.Active = false
		else
			buyContent(b, "BUY", priceInfo(item.price))
		end
	end
end

local function shopSupplies(win, c, order)
	header(c, order, "BAIT")
	for _, bait in ipairs(Config.Baits) do
		if bait.shop then
			order += 1
			simpleRow(c, order, ("%s x%d"):format(bait.name, Config.BaitPackSize), ("Luck x%.2f"):format(bait.luck), "BUY", "green", function()
				act(win, "Bought " .. bait.name .. ".", Request, "BuyBait", bait.id)
			end, C.blue, { icon = "pearl", text = fmt(bait.cost) })
		end
	end
	order += 1
	header(c, order, "VIALS")
	for _, vial in ipairs(Config.Vials) do
		order += 1
		simpleRow(c, order, vial.name, vial.text, "BUY", "green", function()
			act(win, "Bought " .. vial.name .. ".", Request, "BuyVial", vial.id)
		end, C.good, { icon = "pearl", text = fmt(vial.cost) })
	end
end

local function shopTideglass(win, c, order)
	for _, pack in ipairs(LiveOpsData.shop.tideglassPacks) do
		order += 1
		local onSale = pack.productId ~= 0
		simpleRow(c, order, ("%s - %s Tideglass"):format(pack.name, fmt(pack.amount)), "R$ " .. pack.robux, onSale and "BUY" or "NOT ON SALE YET", onSale and "green" or "grey", onSale and function()
			live(win, "Check the purchase prompt.", "BuyTideglass", pack.id)
		end or nil, C.blue, onSale and { text = "R$ " .. pack.robux } or nil)
	end
end

local function shopWardrobe(win, c, order)
	local owned = {}
	for id in pairs(view.cosmetics.owned) do
		if LiveOpsData.cosmetics[id] then
			table.insert(owned, id)
		end
	end
	table.sort(owned, function(a, b)
		return LiveOpsData.cosmetics[a].name < LiveOpsData.cosmetics[b].name
	end)
	if #owned == 0 then
		emptyState(c, order, "gift", "Nothing here yet. Buy a trail in COSMETICS.")
		return
	end
	for _, kind in ipairs({ "trail", "title" }) do
		local heading = false
		for _, id in ipairs(owned) do
			local cosmetic = LiveOpsData.cosmetics[id]
			if cosmetic.kind == kind then
				if not heading then
					heading = true
					order += 1
					header(c, order, kind == "trail" and "TRAILS" or "TITLES")
				end
				order += 1
				local equipped = view.cosmetics[kind] == id
				simpleRow(c, order, cosmetic.name, "", equipped and "EQUIPPED" or "EQUIP", equipped and "green" or "blue", function()
					if equipped then
						live(win, "Unequipped.", "Equip", "", kind)
					else
						live(win, "Equipped " .. cosmetic.name .. ".", "Equip", id)
					end
				end, rarity(cosmetic.tier))
			end
		end
	end
end

local function renderShop(win)
	local c = win.content
	clearContent(win)
	setFooter(win, LiveOpsData.shop.note, 34)
	if not view then
		text(c, "Loading...", 16, { TextColor3 = C.muted })
		return
	end
	setPills(win, { { "pearl", fmt(view.currencies.pearls), C.gold }, { "gem", fmt(view.currencies.tideglass), C.blue } })
	if win.tab == 1 then
		shopCosmetics(win, c, 1)
	elseif win.tab == 2 then
		shopSupplies(win, c, 1)
	elseif win.tab == 3 then
		shopTideglass(win, c, 1)
	else
		shopWardrobe(win, c, 1)
	end
end

-- BOARDS --------------------------------------------------------------------------------------------------------------

local MEDAL = { C.gold, Color3.fromRGB(200, 208, 224), Color3.fromRGB(205, 127, 50) }

local function makeBoardRow(parent, i)
	local gradient = UiKit.gloss(ROW_TOP, ROW_BOTTOM)
	local frame = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = WHITE, Visible = false, Parent = parent }, { corner(8), gradient })
	local outline = stroke(DARK_LINE, 1.5)
	outline.Parent = frame
	local medal = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(26, 26), Visible = false, Parent = frame }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(WHITE, 1.5),
	})
	local medalText = UiKit.label({ Font = DISPLAY, TextSize = 15, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = medal })
	-- Instances can't hold extra fields, so the row is a table of its parts
	return {
		frame = frame,
		gradient = gradient,
		outline = outline,
		medal = medal,
		medalText = medalText,
		Rank = UiKit.label({ Font = DISPLAY, TextSize = 16, Size = UDim2.new(0, 48, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = frame }),
		Name_ = UiKit.label({ TextSize = 15, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -170, 1, 0), TextWrapped = false, Parent = frame }),
		Value = UiKit.label({ TextSize = 15, TextColor3 = C.gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 112, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = frame }),
	}
end

local function renderBoards(win)
	local c = win.content
	local def = LiveOpsData.leaderboards[win.tab]
	win.pool = win.pool or {}
	if not win.empty then
		win.empty, win.emptyLabel = emptyState(c, 0, "trophy", "No entries yet.")
	end
	local data = win.data
	local board = data and data.boards and data.boards[def.id]
	if not board then
		win.emptyLabel.Text = data and "No entries yet." or "Loading..."
		win.empty.Visible = true
		for _, row in ipairs(win.pool) do
			row.frame.Visible = false
		end
		setFooter(win, "", 0)
		return
	end
	local entries = board.entries or {}
	win.empty.Visible = #entries == 0
	for i = 1, math.max(#entries, #win.pool) do
		local e = entries[i]
		local row = win.pool[i]
		if e then
			if not row then
				row = makeBoardRow(c, i)
				win.pool[i] = row
			end
			local mine = e.userId == player.UserId
			row.frame.Visible = true
			local rank = e.rank or i
			row.gradient.Color = mine and ColorSequence.new(Color3.fromRGB(26, 78, 138), Color3.fromRGB(14, 44, 88)) or ColorSequence.new(ROW_TOP, ROW_BOTTOM)
			row.outline.Color = mine and C.blue or DARK_LINE
			row.outline.Thickness = mine and 2.5 or 1.5
			row.medal.Visible = rank <= 3
			row.medal.BackgroundColor3 = MEDAL[rank] or C.ink
			row.medalText.Text = tostring(rank)
			row.Rank.Visible = rank > 3
			row.Rank.Text = "#" .. tostring(rank)
			row.Name_.Text = tostring(e.name or "?") .. (mine and " (you)" or "")
			row.Name_.TextColor3 = WHITE -- white on the blue "you" row keeps contrast above 4.5:1
			row.Value.Text = fmt(e.value or 0) .. " " .. def.unit
		elseif row then
			row.frame.Visible = false
		end
	end
	local lines = { ("You: %s %s"):format(fmt(data.me and data.me[def.id] or 0), def.unit) }
	if board.updatedAt and board.updatedAt > 0 then
		local minutes = math.max(0, math.floor((serverNow() - board.updatedAt) / 60))
		lines[1] ..= ("   -   Updated %d min ago"):format(minutes)
	else
		lines[1] ..= "   -   Not updated yet"
	end
	if board.live == false then
		table.insert(lines, "Showing this server only (global boards need a published place with API access).")
	end
	setFooter(win, table.concat(lines, "\n"), #lines * 18 + 6)
end

local function fetchBoards(win)
	local result = call(LiveOpsRemote, "GetLeaderboards")
	if result.error then
		setStatus(win, tostring(result.error), false)
		return
	end
	win.data = result
	if openName == "Boards" then
		renderWindow(win, true)
	end
end

-- ODDS ----------------------------------------------------------------------------------------------------------------

-- REF 4 odds row: colour square, rarity name, bold %, small detail text, thin sqrt-scaled bar underneath.
local function oddsRow(parent, order, name, color, frac, valueText, sub)
	local row = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = WHITE, Parent = parent }, { corner(8), UiKit.gloss(ROW_TOP, ROW_BOTTOM), stroke(DARK_LINE, 1.5) })
	new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = color, BorderSizePixel = 0, Parent = row }, { corner(3), stroke(color:Lerp(WHITE, 0.4), 1) })
	UiKit.label({ Text = name, Font = DISPLAY, TextSize = 15, TextColor3 = color:Lerp(WHITE, 0.2), Position = UDim2.fromOffset(34, 4), Size = UDim2.fromOffset(100, 24), TextWrapped = false, Parent = row })
	UiKit.label({ Text = valueText, Font = DISPLAY, TextSize = 16, Position = UDim2.fromOffset(138, 4), Size = UDim2.fromOffset(82, 24), TextWrapped = false, Parent = row })
	UiKit.label({ Text = sub or "", TextSize = 13, TextColor3 = C.muted, Position = UDim2.fromOffset(224, 4), Size = UDim2.new(1, -234, 0, 24), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local _, fill = UiKit.bar(row, { Position = UDim2.new(0, 10, 1, -14), Size = UDim2.new(1, -20, 0, 6) }, color)
	fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
end

local function renderOdds(win)
	local c = win.content
	clearContent(win)
	local odds = win.odds
	if not odds then
		text(c, "Loading odds...", 16, { TextColor3 = C.muted })
		return
	end
	local card = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = WHITE, Parent = c }, { corner(8), UiKit.gloss(ROW_TOP, ROW_BOTTOM), stroke(DARK_LINE, 1.5) })
	UiIcons.make("egg", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(46, 46), Parent = card })
	UiKit.label({ Text = odds.egg, Font = DISPLAY, TextSize = 20, Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -76, 0, 26), TextWrapped = false, Parent = card })
	UiKit.label({ Text = ("Costs %s Pearls (or steal one free in the Shoals)"):format(fmt(odds.cost)), TextSize = 14, TextColor3 = C.muted, Position = UDim2.fromOffset(66, 32), Size = UDim2.new(1, -76, 0, 28), TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	local order = 2
	local function nextOrder()
		order += 1
		return order
	end
	header(c, nextOrder(), "DROP RATES - per pull")
	local maxRate = 0.0001
	for _, t in ipairs(odds.tiers) do
		maxRate = math.max(maxRate, t.rate)
	end
	for _, t in ipairs(odds.tiers) do
		oddsRow(c, nextOrder(), t.id, t.color, math.sqrt(t.rate / maxRate), ("%.2f%%"):format(t.rate), t.creatures and table.concat(t.creatures, ", ") or "")
	end
	header(c, nextOrder(), "MUTATIONS")
	local maxMut = 0.0001
	for _, m in ipairs(odds.mutations) do
		maxMut = math.max(maxMut, m.rate)
	end
	for _, m in ipairs(odds.mutations) do
		oddsRow(c, nextOrder(), m.id, m.color, math.sqrt(m.rate / maxMut), ("%.2f%%"):format(m.rate), ("x%.2f - %s"):format(m.mult, tostring(m.visual)))
	end
	header(c, nextOrder(), "PITY")
	for _, p in ipairs(odds.pity) do
		oddsRow(c, nextOrder(), p.label, rarity(p.tier), p.count / math.max(1, p.at), ("%d / %d"):format(p.count, p.at), ("%d pulls to guaranteed %s"):format(p.remaining, p.label))
	end
	text(c, odds.legal, 13, { TextColor3 = C.muted, LayoutOrder = nextOrder() })
end

-- SETTINGS ------------------------------------------------------------------------------------------------------------

local ui = { sliders = {}, toggles = {} } -- settings controls, refreshed from ClientBus.settings
local dragging = nil -- key of the slider being dragged
local saveToken, pendingSave = 0, false
local VFX_CYCLE = { "Auto", "High", "Medium", "Low" }

local function refreshSettingsControls()
	local s = ClientBus.settings
	for key, slider in pairs(ui.sliders) do
		local v = math.clamp(s[key] or 0, 0, 1)
		slider.fill.Size = UDim2.fromScale(v, 1)
		slider.knob.Position = UDim2.fromScale(v, 0.5)
		slider.pct.Text = ("%d%%"):format(math.floor(v * 100 + 0.5))
	end
	for key, b in pairs(ui.toggles) do
		setButton(b, s[key] and "ON" or "OFF", s[key] and "green" or "grey")
	end
	if ui.vfx then
		ui.vfx.Text = tostring(s.vfxQuality)
	end
end

local function changeSetting(key, value)
	ClientBus.applySettings({ [key] = value })
	refreshSettingsControls()
	saveToken += 1
	pendingSave = true
	local token = saveToken
	task.delay(1, function()
		if token ~= saveToken then
			return
		end
		pendingSave = false
		call(LiveOpsRemote, "SetSettings", table.clone(ClientBus.settings))
	end)
end

local function settingsRowFrame(parent, order, h)
	return new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = WHITE, Parent = parent }, { corner(8), UiKit.gloss(ROW_TOP, ROW_BOTTOM), stroke(DARK_LINE, 1.5) })
end

local function buildSlider(parent, order, key, title)
	local row = settingsRowFrame(parent, order, 62)
	UiKit.label({ Text = title, Font = DISPLAY, TextSize = 16, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 20), TextWrapped = false, Parent = row })
	local pct = UiKit.label({ Text = "100%", TextSize = 15, TextColor3 = C.gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(60, 20), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = row })
	local hit = new("Frame", { Position = UDim2.fromOffset(18, 28), Size = UDim2.new(1, -36, 0, 30), BackgroundTransparency = 1, Parent = row })
	local _, fill = UiKit.bar(hit, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 12) }, C.neon)
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = WHITE, ZIndex = 3, Parent = hit }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(C.neon, 2) })
	ui.sliders[key] = { fill = fill, knob = knob, pct = pct }

	local function setFromX(x)
		local v = math.clamp((x - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
		changeSetting(key, math.floor(v * 100 + 0.5) / 100)
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = key
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging == key and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
end

local function buildToggle(parent, order, key, title, note)
	local row = settingsRowFrame(parent, order, note and 62 or 48)
	UiKit.label({ Text = title, Font = DISPLAY, TextSize = 16, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -120, 0, 20), TextWrapped = false, Parent = row })
	if note then
		UiKit.label({ Text = note, TextSize = 13, TextColor3 = C.muted, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -120, 0, 30), TextYAlignment = Enum.TextYAlignment.Top, Parent = row })
	end
	ui.toggles[key] = UiKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(84, 34), Text = "ON", TextSize = 15, Parent = row }, "green", function()
		changeSetting(key, not ClientBus.settings[key])
	end)
end

local function renderSettings(win)
	if win.built then
		refreshSettingsControls()
		return
	end
	win.built = true
	local c = win.content
	buildSlider(c, 1, "musicVolume", "Music")
	buildSlider(c, 2, "sfxVolume", "SFX")
	buildSlider(c, 3, "ambienceVolume", "Ambience")
	buildSlider(c, 4, "uiVolume", "UI")
	buildToggle(c, 5, "reduceFlashing", "Reduce Flashing", "Cuts full-screen flash strength by 80%.")
	buildToggle(c, 6, "cameraShake", "Camera Shake")
	local row = settingsRowFrame(c, 7, 48)
	UiKit.label({ Text = "VFX Quality", Font = DISPLAY, TextSize = 16, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -140, 0, 20), TextWrapped = false, Parent = row })
	ui.vfx = UiKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(104, 34), Text = "Auto", TextSize = 15, Parent = row }, "blue", function()
		local index = table.find(VFX_CYCLE, ClientBus.settings.vfxQuality) or 1
		changeSetting("vfxQuality", VFX_CYCLE[index % #VFX_CYCLE + 1])
	end)
	refreshSettingsControls()
end

UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = nil
	end
end)

-- Window definitions --------------------------------------------------------------------------------------------------

buildShell("Quests", "QUESTS", { "DAILY", "WEEKLY", "EVENT", "COLLECTION" }, renderQuests)
buildShell("Pass", "SEASON PASS", nil, renderPass)
buildShell("Shop", "SHOP", { "COSMETICS", "SUPPLIES", "TIDEGLASS", "WARDROBE" }, renderShop)
do
	local titles = {}
	for _, board in ipairs(LiveOpsData.leaderboards) do
		table.insert(titles, board.title)
	end
	local boards = buildShell("Boards", "LEADERBOARDS", titles, renderBoards)
	boards.onOpen = function(win)
		win.session = (win.session or 0) + 1
		local session = win.session
		task.spawn(function()
			while openName == "Boards" and win.session == session do
				fetchBoards(win)
				task.wait(60)
			end
		end)
	end
end
do
	local odds = buildShell("Odds", "TIDE EGG ODDS", nil, renderOdds)
	odds.onOpen = function(win)
		task.spawn(function()
			local result = call(LiveOpsRemote, "GetOdds")
			if result.error then
				setStatus(win, tostring(result.error), false)
				return
			end
			win.odds = result
			if openName == "Odds" then
				renderWindow(win, true)
			end
		end)
	end
end
buildShell("Settings", "SETTINGS", nil, renderSettings)

-- Launcher ------------------------------------------------------------------------------------------------------------

local badges = {} -- [windowName] = { frame, label }
local bobs = {} -- launcher icons with a gentle idle bob (Rotation and Position only)

do
	local column = new("Frame", {
		Name = "Launcher", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 96, 0.5, 80), Size = UDim2.fromOffset(64, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = gui,
	}, { list(8, false, Enum.HorizontalAlignment.Center) })
	addDeviceScale(column)
	local tiles = {
		{ "Quests", "QUESTS", "scroll", "red", 64 },
		{ "Pass", "PASS", "chest", "gold", 64 },
		{ "Shop", "SHOP", "cart", "green", 64 },
		{ "Boards", "BOARDS", "trophy", "blue", 64 },
		{ "Odds", "ODDS", "egg", "purple", 64 },
		{ "Settings", "", "gear", "grey", 40 },
	}
	for i, t in ipairs(tiles) do
		local name, caption, icon, style, size = t[1], t[2], t[3], t[4], t[5]
		local b = UiKit.button({ Name = name, Size = UDim2.fromOffset(size, size), LayoutOrder = i, Parent = column }, style, function()
			if openName == name then
				closeWindow()
			else
				openWindow(name)
			end
		end)
		local big = size == 64
		-- the icon is ~1.15x the tile and pokes out above its top edge
		local iconSize = math.floor(size * 1.15)
		local iconY = big and 0.4 or 0.5
		local img = UiIcons.make(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, iconY, 0), Size = UDim2.fromOffset(iconSize, iconSize), ZIndex = 3, Parent = b })
		table.insert(bobs, { icon = img, y = iconY, phase = i * 1.1 })
		if caption ~= "" then
			UiKit.label({ Text = caption, Font = DISPLAY, TextSize = 13, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 4, Parent = b })
		end
		if name == "Quests" or name == "Pass" then
			local badge = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(230, 30, 40), Visible = false, ZIndex = 8, Parent = b }, {
				new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(WHITE, 1.5),
			})
			local n = UiKit.label({ Text = "0", Font = DISPLAY, TextSize = 13, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 9, Parent = badge })
			badges[name] = { frame = badge, label = n }
		end
	end
end

-- One throttled Heartbeat loop drives the cosmetic motion: icon bob, claim-button shine sweeps and row stroke pulses
-- (the last two only while a window is open). Only Rotation / Position / Offset / Transparency change.
do
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 1 / 30 then
			return
		end
		accumulated = 0
		local t = os.clock()
		for _, bob in ipairs(bobs) do
			local phase = t * 1.7 + bob.phase
			bob.icon.Rotation = 4 * math.sin(phase)
			bob.icon.Position = UDim2.new(0.5, 0, bob.y, math.sin(phase + 1.2) * 2)
		end
		local win = openName and windows[openName]
		if not win then
			return
		end
		local sweep = math.clamp(((t % 2.5) / 2.5) / 0.6, 0, 1) * 2 - 1
		for _, gradient in ipairs(win.shines) do
			gradient.Offset = Vector2.new(sweep, 0)
		end
		local pulse = 0.2 + 0.35 * (0.5 + 0.5 * math.sin(t * 4))
		for _, outline in ipairs(win.pulses) do
			outline.Transparency = pulse
		end
	end)
end

function updateBadges()
	for name, count in pairs({ Quests = questBadge(), Pass = passBadge() }) do
		local badge = badges[name]
		badge.frame.Visible = count > 0
		badge.label.Text = count > 99 and "99+" or tostring(count)
	end
end

-- View updates --------------------------------------------------------------------------------------------------------

function applyView(v)
	view = v
	viewClock = os.clock()
	if dragging == nil and not pendingSave then
		ClientBus.applySettings(v.settings)
	end
	updateBadges()
	for name in pairs(windows) do
		dirty[name] = true
	end
	if openName and windows[openName] then
		local win = windows[openName]
		if openName == "Settings" then
			refreshSettingsControls()
			dirty[openName] = false
		else
			renderWindow(win, true)
		end
	end
end

PushEvent.OnClientEvent:Connect(function(v)
	if type(v) == "table" and v.daily then
		applyView(v)
	end
end)

-- The game's State push (every second or so) keeps the header currency pills live between LiveOps pushes
-- (aquarium income, catches). Only the pills are redrawn, never the whole window.
Remotes:WaitForChild("State").OnClientEvent:Connect(function(state)
	if not view or type(state) ~= "table" or type(state.pearls) ~= "number" then
		return
	end
	local c = view.currencies
	if c.pearls == state.pearls and c.tideglass == state.tideglass then
		return
	end
	c.pearls, c.tideglass, c.shards, c.embers = state.pearls, state.tideglass or c.tideglass, state.shards or c.shards, state.embers or c.embers
	local win = openName and windows[openName]
	if win and (openName == "Shop" or openName == "Pass") and win.pills then
		setPills(win, { { "pearl", fmt(c.pearls), C.gold }, { "gem", fmt(c.tideglass), C.blue } })
	end
end)

ClientBus.signal.Event:Connect(function(kind, name)
	if kind == "open" and windows[name] then
		openWindow(name)
	end
end)

-- one-second tick for countdown labels
task.spawn(function()
	while true do
		task.wait(1)
		local win = openName and windows[openName]
		if win and win.frame.Visible then
			for _, tick in ipairs(win.ticks) do
				tick()
			end
		end
	end
end)

task.spawn(refreshView)
