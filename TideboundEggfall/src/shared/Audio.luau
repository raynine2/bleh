-- Tidebound: Eggfall: sound cues (Master Patches 5 to 7), ready for the sound designer.
-- Paste each uploaded sound's asset id into `id` (for example "rbxassetid://1234567890"). A cue with an
-- empty id plays nothing, so every trigger below is already wired and safe to leave empty. Plop and Splash
-- use Roblox's built-in water splash until real sounds arrive.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local WATER = "rbxasset://sounds/impact_water.mp3"

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
	},
}

-- Plays a cue at a part or attachment (3D), or on the listener when `parent` is nil. Returns the Sound.
function Audio.play(name, parent)
	local cue = Audio.cues[name]
	if not cue or cue.id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Cue_" .. name
	sound.SoundId = cue.id
	sound.Volume = cue.volume or 0.6
	sound.PlaybackSpeed = cue.pitch or 1
	sound.RollOffMaxDistance = 120
	sound.Parent = parent or SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
	return sound
end

return Audio
