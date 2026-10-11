-- Tidebound: Eggfall: sound cues (Master Patches 5 to 7), ready for the sound designer.
-- Paste each uploaded sound's asset id into `id` (for example "rbxassetid://1234567890"). A cue with an
-- empty id plays nothing, so every trigger below is already wired and safe to leave empty. Plop, Splash and
-- the Big Update body and cutscene cues use Roblox's built-in sounds until real sounds arrive.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local WATER = "rbxasset://sounds/impact_water.mp3"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local SLASH = "rbxasset://sounds/swordslash.wav"
local LUNGE = "rbxasset://sounds/swordlunge.wav"
local UNSHEATH = "rbxasset://sounds/unsheath.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"

local Audio = {
	cues = {
		-- Patch 5: the rod
		CastWindup = { id = "", volume = 0.5, note = "Whoosh build (Cast-Windup)" },
		CastDrift = { id = "", volume = 0.6, note = "Release whoosh: Drift Rod" },
		CastCoral = { id = "", volume = 0.6, note = "Release whoosh: Coral Rod" },
		CastStormline = { id = "", volume = 0.6, note = "Release whoosh: Stormline Rod, with a static crackle" },
		CastAbyssal = { id = "", volume = 0.6, note = "Release whoosh: Abyssal Rod, deep and breathy" },
		CastRiftcaster = { id = "", volume = 0.6, note = "Release whoosh: Riftcaster, crystal shimmer" },
		CastCelestial = { id = "", volume = 0.7, note = "Release whoosh: Celestial Rod, choir swell" },
		Plop = { id = WATER, volume = 0.35, pitch = 1.6, note = "Bobber lands (Cast-Landing)" },
		TickTick = { id = "", volume = 0.6, note = "Bite-Tell: two ticks" },
		Snap = { id = "", volume = 0.7, note = "Hook-Set" },
		ReelClick = { id = "", volume = 0.3, note = "One reel click per crank (Reel-Struggle)" },
		Crack = { id = "", volume = 0.8, note = "The line snaps (Reel-Break)" },
		Splash = { id = WATER, volume = 0.7, pitch = 1, note = "Land-Flip: the fish leaves the water" },
		Fanfare = { id = "", volume = 0.6, note = "Land-Hold" },
		-- Patch 6: the reveal
		RevealHum = { id = "", volume = 0.5, note = "Phase 0: rising hum under the ducked music" },
		Heartbeat = { id = "", volume = 0.6, note = "Phase 1: low tone and heartbeat" },
		TierCommon = { id = "", volume = 0.6, note = "Dull thud" },
		TierUncommon = { id = "", volume = 0.6, note = "Soft chime" },
		TierRare = { id = "", volume = 0.6, note = "Bright chime" },
		TierEpic = { id = "", volume = 0.7, note = "Harp sting" },
		TierLegendary = { id = "", volume = 0.8, note = "Orchestral hit" },
		TierMythic = { id = "", volume = 0.8, note = "Choir swell" },
		TierCelestial = { id = "", volume = 0.9, note = "Full orchestra" },
		NearMissDrain = { id = "", volume = 0.6, note = "The climb falls back one tier" },
		CardSlide = { id = "", volume = 0.5, note = "Phase 3: name card slides in" },
		Celebrate = { id = "", volume = 0.8, note = "Phase 4 fanfare, Legendary and up" },
		-- Big Update: the body (TideboundMotion) and the cutscenes (TideboundCutscenes)
		HitThud = { id = THUD, volume = 0.9, pitch = 0.7, note = "You take a hit" },
		Down = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7, note = "You go down (a wipe)" },
		LandHeavy = { id = THUD, volume = 0.6, pitch = 0.85, note = "A hard landing" },
		Whoosh = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.6, pitch = 0.8, note = "The Maelstrom drags you down, or the light column lifts you" },
		Plunge = { id = WATER, volume = 0.8, pitch = 0.7, note = "You hit the water at the start of a dive or descent" },
		Roar = { id = "", volume = 0.9, note = "A guardian wakes up" },
		Sting = { id = "", volume = 0.7, note = "A title card lands (new area, extraction)" },
		Tally = { id = "", volume = 0.5, note = "One tick per line of the extraction tally" },
		-- Patch 17: the 3-hit rod combo (TideboundRod). Built-in sounds, pitched up to sound cartoony.
		SwingWhoosh = { id = SLASH, volume = 0.55, pitch = 1.25, note = "Hit 1 (Bonk): the chop whooshes down" },
		SwingBonk = { id = THUD, volume = 0.9, pitch = 1.9, note = "Hit 1 lands: a cartoon bonk" },
		SwingSpin = { id = LUNGE, volume = 0.6, pitch = 1.35, note = "Hit 2 (Whirl): the spin" },
		SwingDing = { id = PING, volume = 0.35, pitch = 1.6, note = "Hit 2 lands: a little ding" },
		FishPop = { id = UNSHEATH, volume = 0.6, pitch = 0.75, note = "Hit 3: the giant fish pops into your hands" },
		FishSlap = { id = WATER, volume = 1, pitch = 1.7, note = "Hit 3 lands: a wet fish slap" },
		SlamBoom = { id = THUD, volume = 1, pitch = 0.45, note = "Hit 3 lands: the ground shakes" },
		SlamDing = { id = PING, volume = 0.45, pitch = 0.9, note = "Hit 3 lands: stars ring" },
		-- Patch 18: the dash
		DashWhoosh = { id = LUNGE, volume = 0.55, pitch = 0.8, note = "The dash takes off" },
		DashPop = { id = PING, volume = 0.25, pitch = 2.2, note = "A cartoon pop as the dust cloud is left behind" },
		DashSkid = { id = SLASH, volume = 0.4, pitch = 0.55, note = "Skidding to a stop" },
		-- Patch 19: the dash moves
		DashJump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.7, pitch = 1.1, note = "Cannonball and Pole Vault take off" },
		DashLand = { id = THUD, volume = 1, pitch = 0.6, note = "A heavy landing (BOOM, hero landing)" },
		DashZip = { id = SLASH, volume = 0.5, pitch = 1.8, note = "Hook Shot: the line zips out, hooks, reels" },
		DashCopter = { id = LUNGE, volume = 0.4, pitch = 2, note = "Rod Copter: the blades whirring" },
		DashSplash = { id = WATER, volume = 0.6, pitch = 1.3, note = "Fish Surf: splashing along" },
		DashBoop = { id = PING, volume = 0.5, pitch = 0.6, note = "Fish Rocket: BOOP" },
		DashSlap = { id = WATER, volume = 0.9, pitch = 2, note = "Tail Slap: a wet SLAP" },
	},
}

-- Plays a cue at a part or attachment (3D), or on the listener when `parent` is nil. Returns the Sound.
-- `pitch` multiplies the cue's own pitch (for a little random variety).
function Audio.play(name, parent, pitch: number?)
	local cue = Audio.cues[name]
	if not cue or cue.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Cue_" .. name
	sound.SoundId = cue.id
	sound.Volume = cue.volume or 0.6
	sound.PlaybackSpeed = (cue.pitch or 1) * (pitch or 1)
	sound.RollOffMaxDistance = 120
	sound.Parent = parent or SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
	return sound
end

return Audio
