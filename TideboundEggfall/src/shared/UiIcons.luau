-- Tidebound: Eggfall UI icons: hand-painted icons (thick dark outline, gradient body, white highlight streak) used
-- by the HUD dock and every menu instead of emoji. Painted as SVG, rendered and uploaded (the roblox-game-ui skill's
-- icon pipeline). An empty id falls back to the emoji in `fallback`, so a missing upload never shows a blank tile.

local UiIcons = {
	-- shared painted set (already uploaded)
	calendar = "rbxassetid://85687393207604",
	ticket = "rbxassetid://112242288769077",
	cart = "rbxassetid://123678832274810",
	egg = "rbxassetid://99369591703324",
	gem = "rbxassetid://113115755136893",
	coin = "rbxassetid://129476245387664",
	chest = "rbxassetid://120476018218464",
	star = "rbxassetid://95325446069707",
	stopwatch = "rbxassetid://122885268972716",
	gift = "rbxassetid://85771863251302",
	book = "rbxassetid://133752124870577",
	bolt = "rbxassetid://117468609028579",
	potion = "rbxassetid://101108195948960",
	tag = "rbxassetid://106119682560135",
	rays = "rbxassetid://124496090301374",
	-- Tidebound set (painted for this game)
	trophy = "rbxassetid://119858810436635",
	gear = "rbxassetid://118168912033618",
	scroll = "rbxassetid://136389829137353",
	pearl = "rbxassetid://132445039089702",
	rod = "rbxassetid://113736702914864",
	lock = "rbxassetid://72966278017118",
	house = "rbxassetid://133703177197071",
	eggshards = "rbxassetid://84466026238810",
}

UiIcons.fallback = {
	trophy = "🏆", gear = "⚙️", scroll = "📜", pearl = "⚪", rod = "🎣", lock = "🔒", house = "🏠",
}

-- An ImageLabel with the icon (or a TextLabel with the emoji fallback), filling `props.Size` (scale).
function UiIcons.make(name, props)
	local id = UiIcons[name]
	local inst
	if type(id) == "string" and id ~= "" then
		inst = Instance.new("ImageLabel")
		inst.Image = id
		inst.ScaleType = Enum.ScaleType.Fit
	else
		inst = Instance.new("TextLabel")
		inst.Text = UiIcons.fallback[name] or "?"
		inst.TextScaled = true
	end
	inst.Name = "Icon"
	inst.BackgroundTransparency = 1
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = props and props.Parent
	return inst
end

return UiIcons
