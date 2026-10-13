-- Tidebound: Eggfall: the fishing feel bridge (Master Patches 5 and 6), used on the client only.
-- The main client script runs the cast and the reel minigame and writes the phase here; TideboundRod reads it
-- every frame to pose your arms, bend the rod, draw the line and play the rod's effects. Other players'
-- casts are driven by the attributes the server sets on their characters (FishPhase, FishAt, ...).

local FishingFeel = {
	phase = "", -- "", "charge", "cast", "bite", "reel", "land" or "break"
	startedAt = 0, -- os.clock() when the phase began
	cast = nil, -- the server's Fishing event: biteWait, spot, rod, difficulty...
	result = nil, -- FinishCast's reply on a catch: fish, tier, mutation, weight...
	tension = 0, -- 0 to 1 while reeling: 0 when the fish sits in your bar, 1 when it pulls away
	progress = 0, -- 0 to 1 while reeling (Patch 10: TideboundRod bursts at each milestone)
	milestone = 0, -- how many of the reel's milestones (50%, 75%, 90%) you've passed
	sweet = false, -- the fish sits in the bar's sweet spot (Patch 10: gold sparkles off the line)
	kickUntil = 0, -- os.clock(): the +4 FOV kick on the cast release
	frozen = false, -- the reveal holds you still
	-- Fishing Fight (12 Oct 2026): the reel bar's state, so TideboundRod can move the fish in the water and pose you
	fishPos = 0.5, -- 0 to 1: the fish's place on the reel bar (left to right = your left to right in the water)
	barPos = 0.5, -- 0 to 1: the left edge of your catch zone
	barWidth = 0.3,
	thrash = 0, -- 0 swimming, 1 the fish is about to lunge ("!!"), 2 it's lunging
	thrashAt = 0, -- os.clock() the current thrash state began
	heldAt = 0, -- os.clock() you last kept the fish in the bar through a whole lunge (+6% progress)
	shake = function(_amount: number, _seconds: number) end, -- set by the main client
	-- Fisch video (12 Oct 2026): the power cast (TideboundFischCast)
	castReady = false, -- a fishing spot is in reach, so a click charges a cast instead of swiping the rod
	power = 0, -- 0 to 1 while charging
	castRating = nil, -- the last cast's rating from FischUI.RATINGS (word, colour, progress-speed bonus)
	castAt = 0, -- os.clock() of that cast
	busy = false, -- the reel minigame is running (so a click can't start a second cast)
	castLockUntil = 0, -- os.clock(): no new cast before this (the server is still starting the last one)
	-- Stances (13 Oct 2026): X swaps them (TideboundStance). "fish": a click at a spot charges a cast;
	-- "fight": a click swings the rod, which stays in your hand
	stance = "fish",
	stanceAt = -10, -- workspace:GetServerTimeNow() of the last swap (TideboundRod plays the swap from it)
	setStance = function(_stance: string) end, -- set by TideboundStance
}

-- 13 Oct 2026 (HJHJH: "when i click buttons on the menu it starts fishing"): is the pointer on any part of the
-- UI? Buttons, text boxes, scrolling lists, any solid panel or picture (menus, windows, the HUD), or Roblox's own
-- menu. Big see-through overlays don't count. Checked at the click point both with and without the top bar inset,
-- since Studio and devices disagree about which one GetGuiObjectsAtPosition wants.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
function FishingFeel.overUi(position)
	local player = game:GetService("Players").LocalPlayer
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return false
	end
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
		return true
	end
	local camera = workspace.CurrentCamera
	local screenArea = camera and camera.ViewportSize.X * camera.ViewportSize.Y or 1e7
	local inset = GuiService:GetGuiInset()
	for _, y in ipairs({ position.Y, position.Y + inset.Y }) do
		for _, gui in ipairs(pg:GetGuiObjectsAtPosition(position.X, y)) do
			if gui.Visible then
				if gui:IsA("GuiButton") or gui:IsA("TextBox") or gui:IsA("ScrollingFrame") then
					return true
				end
				local size = gui.AbsoluteSize
				local solid = gui.BackgroundTransparency < 0.9 or ((gui:IsA("ImageLabel") or gui:IsA("ViewportFrame")) and (gui :: any).ImageTransparency ~= nil and (gui :: any).ImageTransparency < 0.9)
				if solid and size.X * size.Y < screenArea * 0.45 then
					return true
				end
			end
		end
	end
	return false
end

function FishingFeel.set(phase)
	FishingFeel.phase = phase
	FishingFeel.startedAt = os.clock()
end

function FishingFeel.elapsed()
	return os.clock() - FishingFeel.startedAt
end

return FishingFeel
