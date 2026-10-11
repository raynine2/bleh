-- Tidebound: Eggfall: animation handoff list (Delta Section 10, Table A).
-- Person A specifies, Person B animates. Paste each uploaded animation's asset id into `id`
-- (for example "rbxassetid://1234567890"). Until an id is filled in, the game uses Roblox's default
-- R15 animations and plays nothing extra, so every trigger below is already wired and safe to leave empty.
-- Frame targets are at 30 fps unless `fps` says otherwise. P0 = first playable, P1 = before launch, P2 = after launch.
-- The ten rod animations are Master Patch 5. Until their ids are filled in, TideboundRod poses the arms and
-- bends the rod in code on every player's screen; once an id is in, that step plays the animation instead
-- and the code only bends the rod and draws the line. `bend` is the rod's BendValue during the step.

local Animations = {
	Spawn = { id = "", rig = "R15 player", priority = "P1", frames = 36, trigger = "Join or teleport arrival" },
	IdleHub = { id = "", rig = "R15 player", priority = "P1", frames = 90, loop = true, trigger = "No input for 2 s outside runs" },
	Run = { id = "", rig = "R15 player", priority = "P0", frames = 20, loop = true, trigger = "Movement input" },
	Sprint = { id = "", rig = "R15 player", priority = "P0", frames = 16, loop = true, trigger = "Sprint key while moving" },
	CastWindup = { id = "", rig = "R15 player + rod", priority = "P0", frames = 18, fps = 60, bend = "0.15", trigger = "Cast starts: rod back over the shoulder, weight on the back foot" },
	CastRelease = { id = "", rig = "R15 player + rod", priority = "P0", frames = 12, fps = 60, bend = "0.3 to 0", trigger = "Rod whips forward, wrist snaps (FOV +4 for 6 frames)" },
	CastLanding = { id = "", rig = "R15 player + rod", priority = "P0", frames = 24, fps = 60, bend = "0", trigger = "Rod settles at 30 degrees, bobber drops" },
	IdleFishing = { id = "", rig = "R15 player + rod", priority = "P0", frames = 180, fps = 60, loop = true, bend = "0.05", trigger = "Waiting for a bite: 3 degree sway, hand adjust at frame 120" },
	BiteTell = { id = "", rig = "R15 player + rod", priority = "P0", frames = 8, fps = 60, bend = "0.2", trigger = "Bite: tip twitches twice" },
	HookSet = { id = "", rig = "R15 player + rod", priority = "P0", frames = 10, fps = 60, bend = "0.4", trigger = "Yank back 40 degrees" },
	ReelStruggle = { id = "", rig = "R15 player + rod", priority = "P0", frames = 45, fps = 60, loop = true, bend = "0.6 to 0.9 with tension", trigger = "Reel minigame: one crank per loop, lean back 8 degrees" },
	ReelBreak = { id = "", rig = "R15 player + rod", priority = "P0", frames = 15, fps = 60, bend = "1.0", trigger = "The line snaps and you stumble back" },
	LandFlip = { id = "", rig = "R15 player + rod", priority = "P0", frames = 30, fps = 60, speed = 0.5, bend = "0.5 to 0", trigger = "Catch: the fish arcs out and lands in your hands (half speed)" },
	LandHold = { id = "", rig = "R15 player + rod", priority = "P0", frames = 20, fps = 60, bend = "0", trigger = "Fish held up in both hands, then the reveal" },
	FishStruggle = { id = "", rig = "Fish rig (generic)", priority = "P1", frames = 18, loop = true, trigger = "During the reel minigame" },
	EggGrab = { id = "", rig = "R15 player", priority = "P0", frames = 18, trigger = "Steal at an egg nest" },
	EggTuck = { id = "", rig = "R15 player", priority = "P0", frames = 20, loop = true, trigger = "Carrying eggs" },
	EscapeSprint = { id = "", rig = "R15 player", priority = "P1", frames = 16, loop = true, trigger = "Sprint while locked on" },
	Slide = { id = "", rig = "R15 player", priority = "P0", frames = 14, trigger = "Crouch while sprinting" },
	Jump = { id = "", rig = "R15 player", priority = "P0", frames = 18, trigger = "Jump input" },
	WardenLunge = { id = "", rig = "Warden rig", priority = "P0", frames = 30, trigger = "Player in lunge range in any phase (0.6 s = 18 frames of wind-up)" },
	HitReact = { id = "", rig = "R15 player", priority = "P0", frames = 10, trigger = "Taking a hit (Warden, Moray, anemone) or a Brute stun" },
	Down = { id = "", rig = "R15 player", priority = "P0", frames = 40, trigger = "Health reaches 0 (wipe)" },
	HatchIdle = { id = "", rig = "Egg mesh", priority = "P1", frames = 30, loop = true, trigger = "Egg in an incubator" },
	PetIdle = { id = "", rig = "Creature rigs", priority = "P1", frames = 60, loop = true, trigger = "Creature not moving" },
	PetFollow = { id = "", rig = "Creature rigs", priority = "P1", frames = 20, loop = true, trigger = "Companion follows the player" },
	PetFeed = { id = "", rig = "Creature rigs + R15 player", priority = "P2", frames = 36, trigger = "Feed at the Creature Pen trough" },
	ExtractionEmote = { id = "", rig = "R15 player", priority = "P0", frames = 48, trigger = "Extraction completes" },
	PrestigePose = { id = "", rig = "R15 player", priority = "P2", frames = 72, trigger = "Confirm prestige" },
	BaseBuild = { id = "", rig = "R15 player", priority = "P2", frames = 30, trigger = "Buying a base upgrade" },
	BaseDance = { id = "", rig = "R15 player", priority = "P2", frames = 60, loop = true, trigger = "Emote at the base or Social Plaza" },
}

return Animations
