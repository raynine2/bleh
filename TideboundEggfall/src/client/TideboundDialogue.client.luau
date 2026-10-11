-- Tidebound: Eggfall: NPC dialogue (Patch 23), in the style of the Catch a Brainrot reference: talking to an NPC
-- opens a white rounded box at the bottom of the screen with their name on a coloured tag, their lines typing out
-- letter by letter in a pixel font, and a bobbing red ▼ when a line is done. Click, tap, E, Space or Enter skips
-- the typing or goes to the next line. After the last line the NPC's panel opens (Config.Npcs[id].panel) through
-- MotionBus.openPanel, which TideboundClient sets. Walking away or pressing Escape closes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Tidebound")
local Config = require(Shared:WaitForChild("Config"))
local Audio = require(Shared:WaitForChild("Audio"))
local MotionBus = require(Shared:WaitForChild("MotionBus"))

local player = Players.LocalPlayer
local PIXEL = Enum.Font.Arcade
local INK = Color3.fromRGB(34, 30, 44)
local RED = Color3.fromRGB(230, 50, 60)
local TAG_COLORS = { Color3.fromRGB(60, 130, 230), Color3.fromRGB(230, 70, 90), Color3.fromRGB(60, 170, 110), Color3.fromRGB(240, 150, 40), Color3.fromRGB(150, 90, 210) }
local CHARS_PER_SECOND = 45
local WALK_AWAY = 22

MotionBus.dialogue = true -- tells TideboundClient not to toast NPC lines itself

local function new(className, props, children)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local gui = new("ScreenGui", { Name = "TideboundDialogue", ResetOnSpawn = false, DisplayOrder = 40, IgnoreGuiInset = true, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local box = new("TextButton", {
	Name = "Box",
	AutoButtonColor = false,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.new(0.66, 0, 0, 150),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	Parent = gui,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 20) }),
	new("UIStroke", { Color = INK, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UISizeConstraint", { MaxSize = Vector2.new(780, 170), MinSize = Vector2.new(300, 120) }),
})
-- an inner pale border, like the reference's double-edged box
new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, Parent = box }, {
	new("UICorner", { CornerRadius = UDim.new(0, 15) }),
	new("UIStroke", { Color = Color3.fromRGB(210, 214, 226), Thickness = 2 }),
})
local tag = new("Frame", { Name = "Tag", Position = UDim2.new(0, 22, 0, -20), Size = UDim2.fromOffset(220, 38), BackgroundColor3 = TAG_COLORS[1], ZIndex = 3, Parent = box }, {
	new("UICorner", { CornerRadius = UDim.new(0, 12) }),
	new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local nameLabel = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Font = PIXEL, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = tag }, {
	new("UIStroke", { Color = INK, Thickness = 2 }),
})
local roleLabel = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 10), Size = UDim2.new(0.5, 0, 0, 18), Font = PIXEL, TextSize = 14, TextColor3 = Color3.fromRGB(150, 150, 168), TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
local text = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(26, 32),
	Size = UDim2.new(1, -70, 1, -46),
	Font = PIXEL,
	TextSize = 22,
	TextColor3 = INK,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	LineHeight = 1.15,
	Parent = box,
})
local arrow = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -12), Size = UDim2.fromOffset(28, 24), Font = Enum.Font.GothamBlack, Text = "▼", TextSize = 24, TextColor3 = RED, Visible = false, Parent = box })
local pageLabel = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -54, 1, -14), Size = UDim2.fromOffset(60, 18), Font = PIXEL, TextSize = 14, TextColor3 = Color3.fromRGB(170, 170, 186), TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
local scale = new("UIScale", { Scale = 1, Parent = box })

local talk = nil -- { id, npc, lines, index, shown, typing, at, adornee }

local function close(openPanel)
	if not talk then
		return
	end
	local panel = openPanel and talk.npc.panel
	talk = nil
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
	task.delay(0.12, function()
		if not talk then
			gui.Enabled = false
		end
	end)
	if panel and MotionBus.openPanel then
		MotionBus.openPanel(panel)
	end
end

local function showLine()
	local line = talk.lines[talk.index]
	text.Text = line
	text.MaxVisibleGraphemes = 0
	talk.shown = 0
	talk.typing = true
	talk.lastBlip = 0
	arrow.Visible = false
	pageLabel.Text = #talk.lines > 1 and ("%d/%d"):format(talk.index, #talk.lines) or ""
end

local function advance()
	if not talk then
		return
	end
	if talk.typing then
		-- skip the typing
		talk.shown = utf8.len(talk.lines[talk.index]) or #talk.lines[talk.index]
		return
	end
	if talk.index >= #talk.lines then
		Audio.play("TalkNext")
		close(true)
		return
	end
	talk.index += 1
	Audio.play("TalkNext")
	showLine()
end

local function open(id, adornee)
	local npc = Config.Npcs[id]
	if not npc or #npc.lines == 0 then
		return
	end
	local seed = 0
	for i = 1, #id do
		seed += string.byte(id, i)
	end
	talk = { id = id, npc = npc, lines = npc.lines, index = 1, adornee = adornee }
	nameLabel.Text = npc.name:upper()
	tag.BackgroundColor3 = TAG_COLORS[seed % #TAG_COLORS + 1]
	tag.Size = UDim2.fromOffset(math.max(140, #npc.name * 15 + 30), 38)
	roleLabel.Text = (npc.role or ""):upper()
	gui.Enabled = true
	scale.Scale = 0.8
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	showLine()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local id = prompt:GetAttribute("Npc")
	if id then
		if talk and talk.id == id then
			advance()
		else
			open(id, prompt.Parent)
		end
	end
end)

box.Activated:Connect(advance)

UserInputService.InputBegan:Connect(function(input, processed)
	if not talk then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Escape or key == Enum.KeyCode.ButtonB then
		close(false)
	elseif not processed and (key == Enum.KeyCode.Space or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA) then
		advance()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not talk then
		return
	end
	if talk.typing then
		local line = talk.lines[talk.index]
		local total = utf8.len(line) or #line
		talk.shown = math.min(total, talk.shown + dt * CHARS_PER_SECOND)
		local visible = math.floor(talk.shown)
		if visible ~= text.MaxVisibleGraphemes then
			text.MaxVisibleGraphemes = visible
			if visible - talk.lastBlip >= 2 then
				talk.lastBlip = visible
				Audio.play("TalkBlip", nil, 0.9 + math.random() * 0.25)
			end
		end
		if visible >= total then
			talk.typing = false
			text.MaxVisibleGraphemes = -1
		end
	else
		arrow.Visible = true
		arrow.Position = UDim2.new(1, -22, 1, -12 - math.abs(math.sin(os.clock() * 5)) * 5)
	end
	-- walking away or a cutscene closes it
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local adornee = talk.adornee
	if MotionBus.cutscene or not root or not adornee or not adornee.Parent or (adornee:IsA("BasePart") and (adornee.Position - root.Position).Magnitude > WALK_AWAY) then
		close(false)
	end
end)
