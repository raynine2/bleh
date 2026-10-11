-- Tidebound: Eggfall: the fishing feel bridge (Master Patches 5 and 6), used on the client only.
-- The main client script runs the cast and the reel minigame and writes the phase here; TideboundRod reads it
-- every frame to pose your arms, bend the rod, draw the line and play the rod's effects. Other players'
-- casts are driven by the attributes the server sets on their characters (FishPhase, FishAt, ...).

local FishingFeel = {
	phase = "", -- "", "cast", "bite", "reel", "land" or "break"
	startedAt = 0, -- os.clock() when the phase began
	cast = nil, -- the server's Fishing event: biteWait, spot, rod, difficulty...
	result = nil, -- FinishCast's reply on a catch: fish, tier, mutation, weight...
	tension = 0, -- 0 to 1 while reeling: 0 when the fish sits in your bar, 1 when it pulls away
	progress = 0, -- 0 to 1 while reeling (Patch 10: TideboundRod bursts at each milestone)
	milestone = 0, -- how many of the reel's milestones (50%, 75%, 90%) you've passed
	sweet = false, -- the fish sits in the bar's sweet spot (Patch 10: gold sparkles off the line)
	kickUntil = 0, -- os.clock(): the +4 FOV kick on the cast release
	frozen = false, -- the reveal holds you still
	shake = function(_amount: number, _seconds: number) end, -- set by the main client
}

function FishingFeel.set(phase)
	FishingFeel.phase = phase
	FishingFeel.startedAt = os.clock()
end

function FishingFeel.elapsed()
	return os.clock() - FishingFeel.startedAt
end

return FishingFeel
