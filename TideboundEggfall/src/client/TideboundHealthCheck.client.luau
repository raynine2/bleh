-- Tidebound: Eggfall health check (Studio only).
-- 12 Oct: an AI edit replaced TideboundClient with a 462-line fragment (syntax error + everything after line 462 cut off),
-- so the whole HUD silently vanished. A client script that fails to parse never runs, so it can't report itself:
-- this separate script checks that the main GUIs exist after join and shows a big red banner if one is missing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

-- ScreenGui name -> script that builds it
local EXPECTED = {
	TideboundUI = "TideboundClient",
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
task.wait(15)

local missing = {}
for guiName, scriptName in EXPECTED do
	if not playerGui:FindFirstChild(guiName) then
		table.insert(missing, ("%s (built by %s)"):format(guiName, scriptName))
	end
end
if #missing == 0 then
	return
end

local text = "UI MISSING: " .. table.concat(missing, ", ") .. ". The script probably has a syntax error or was cut off. Check Output, compare its line count with ServerStorage.TideboundBackups."
warn("[HealthCheck] " .. text)
local gui = Instance.new("ScreenGui")
gui.Name = "TideboundHealthCheck"
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 60)
label.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextWrapped = true
label.TextSize = 18
label.Font = Enum.Font.GothamBold
label.Text = text
label.Parent = gui
gui.Parent = playerGui
