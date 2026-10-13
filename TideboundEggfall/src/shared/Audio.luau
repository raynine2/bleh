-- Tidebound: Eggfall: sound cues (Master Patches 5 to 7), ready for the sound designer.
-- Paste each uploaded sound's asset id into `id` (for example "rbxassetid://1234567890"). A cue with an
-- empty id plays nothing, so every trigger below is already wired and safe to leave empty. Plop, Splash and
-- the Big Update body and cutscene cues use Roblox's built-in sounds until real sounds arrive.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local WATER = "rbxasset://sounds/impact_water.mp3"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local SLASH = "rbxasset://sounds/swordslash.wav"
local LUNGE = "rbxasset://sounds/swordlunge.wav"
local UNSHEATH = "rbxasset://sounds/unsheath.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
-- GDD Section 9: licensed library sounds for the reveal and title cues (stand-ins, same as Soundtrack.luau)
local RISER = "rbxassetid://1843490542" -- APM Critical Mass riser
local HEART = "rbxassetid://9043365842" -- APM heartbeat 96 BPM
local HARP = "rbxassetid://1840525370" -- APM harp glissando
local HIT = "rbxassetid://1837950656" -- APM Brute Force Sting 3
local COINS = "rbxassetid://9119218944" -- PSE slot machine coin payoff
-- Pro Sound Effects clips for the rod combo and the dash (cut and layered below)
local WOOD_HIT = "rbxassetid://9113502506" -- Body Hits 8: a 2x4 wood panel hit, crisp onset at 0.08 s
local WET_SLAP = "rbxassetid://9120085618" -- Toad Hands 5: one wet cartoon slap at 0.16 s
local CLOTH_WHOOSH = "rbxassetid://9125442175" -- Cloth Whooshes 9: swells to a peak at 0.8-1.0 s
local SPLASH_THUNK = "rbxassetid://9119481909" -- Splash Thunking Impact 1: peak at 0.25-0.5 s
local POOL_SPLASH = "rbxassetid://9117823374" -- Pool Jumps Splashes 4: splash from 0.16 s
local WATER_WAKE = "rbxassetid://9120610116" -- Water Wake Constant 2: a steady airy water rush
local BUBBLE_WHOOSH = "rbxassetid://9113605893" -- Bubble Whooshes 2: liquid pass-by, builds after 1 s
-- 12 Oct 2026 catch sounds remake (HJHJH: the catch "feels like a horror game"): the riser and heartbeat are gone,
-- and catching a fish is bright and beachy now. All APM / Pro Sound Effects library clips, checked to load.
local HARP_UP = "rbxassetid://1840525598" -- APM Harp Glissando (P): a light upward harp sweep
local SEA_BREEZE = "rbxassetid://9038648999" -- APM Sea Breeze - Sting 1: a sunny beach sting (4 s)
local WORKS_OUT = "rbxassetid://1848281800" -- APM Everything Works Out - Tag 1: an optimistic pop tag (3.5 s)
local WORKS_OUT_2 = "rbxassetid://1848281810" -- APM Everything Works Out - Tag 2 (3.7 s)
local REEL = "rbxassetid://9114451552" -- PSE Fishing Reel 2: a quick reel buzz (0.6 s)

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
		Snap = { note = "Hook-Set: the rod whips up and the hook bites in a splash", layers = {
			{ id = CLOTH_WHOOSH, volume = 0.35, pitch = 1.5, start = 0.7, length = 0.28, fadeOut = 0.12, jitter = 0.05 },
			{ id = POOL_SPLASH, volume = 0.3, pitch = 1.3, start = 0.16, length = 0.35, fadeOut = 0.15, jitter = 0.06 },
		} },
		ReelClick = { id = REEL, volume = 0.16, pitch = 1, jitter = 0.08, note = "One reel buzz per crank (Reel-Struggle)" },
		Crack = { id = "", volume = 0.8, note = "The line snaps (Reel-Break)" },
		Splash = { note = "A fish breaks the surface (fight lunges, Land-Flip)", layers = {
			{ id = POOL_SPLASH, volume = 0.45, pitch = 1.05, start = 0.14, length = 0.7, fadeOut = 0.3, jitter = 0.08 },
			{ id = WATER, volume = 0.25, pitch = 1.2, jitter = 0.08 },
		} },
		Fanfare = { id = SEA_BREEZE, volume = 0.4, length = 3.9, fadeOut = 0.6, note = "Land-Hold: a sunny beach sting as the fish lands in your hands" },
		-- Patch 6: the reveal (12 Oct 2026: a light harp sweep instead of the horror riser, and no heartbeat)
		RevealHum = { id = HARP_UP, volume = 0.35, length = 1.8, fadeOut = 0.6, note = "Phase 0: a light harp sweep up" },
		Heartbeat = { id = "", volume = 0.6, note = "Phase 1: silent since 12 Oct 2026 (it made catching feel like a horror game)" },
		-- the tier climb rings up a bright scale, one note per tier
		TierCommon = { id = PING, volume = 0.22, pitch = 1, note = "Climb note 1" },
		TierUncommon = { id = PING, volume = 0.22, pitch = 1.122, note = "Climb note 2" },
		TierRare = { id = PING, volume = 0.24, pitch = 1.26, note = "Climb note 3" },
		TierEpic = { note = "Climb note 4 with a harp sparkle", layers = {
			{ id = PING, volume = 0.24, pitch = 1.335 },
			{ id = HARP, volume = 0.45, length = 1.6, fadeOut = 0.5 },
		} },
		TierLegendary = { id = PING, volume = 0.26, pitch = 1.5, note = "Climb note 5" },
		TierMythic = { id = PING, volume = 0.26, pitch = 1.68, note = "Climb note 6" },
		TierCelestial = { note = "Climb note 7 and a harp sweep", layers = {
			{ id = PING, volume = 0.28, pitch = 2 },
			{ id = HARP_UP, volume = 0.4, length = 2, fadeOut = 0.6 },
		} },
		NearMissDrain = { id = "", volume = 0.6, note = "The climb falls back one tier" },
		CardSlide = { id = "", volume = 0.5, note = "Phase 3: name card slides in" },
		Celebrate = { note = "Phase 4 fanfare, Legendary and up: a happy pop tag and a coin shower", layers = {
			{ id = WORKS_OUT, volume = 0.6 },
			{ id = COINS, volume = 0.45, length = 2.5, fadeOut = 0.8 },
		} },
		-- Big Update: the body (TideboundMotion) and the cutscenes (TideboundCutscenes)
		HitThud = { id = THUD, volume = 0.9, pitch = 0.7, note = "You take a hit" },
		Down = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7, note = "You go down (a wipe)" },
		LandHeavy = { id = THUD, volume = 0.6, pitch = 0.85, note = "A hard landing" },
		Whoosh = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.6, pitch = 0.8, note = "The Maelstrom drags you down, or the light column lifts you" },
		Plunge = { id = WATER, volume = 0.8, pitch = 0.7, note = "You hit the water at the start of a dive or descent" },
		Roar = { id = "", volume = 0.9, note = "A guardian wakes up" },
		Sting = { id = HIT, volume = 0.7, note = "A title card lands (new area, extraction)" },
		Tally = { id = "", volume = 0.5, note = "One tick per line of the extraction tally" },
		-- Rod combo and dash, remade 11 Oct 2026 (Yangz: fit the theme, fluid, dash not too loud). Each cue is
		-- layers cut from Pro Sound Effects clips: `start` and `length` mark the useful part of the clip (measured in
		-- Studio from PlaybackLoudness), fadeIn / fadeOut smooth the cut edges, and `jitter` varies the pitch a
		-- little so repeated hits never sound robotic.
		-- Patch 17: the 3-hit rod combo (TideboundRod): a springy wooden rod, water and a wet fish
		SwingWhoosh = { note = "Hit 1 (Bonk): the rod whips down through the air", layers = {
			{ id = CLOTH_WHOOSH, volume = 0.42, pitch = 1.35, start = 0.62, length = 0.32, fadeOut = 0.12, jitter = 0.06 },
		} },
		SwingBonk = { note = "Hit 1 lands: a hollow wooden thwock with a wet edge", layers = {
			{ id = WOOD_HIT, volume = 1, pitch = 1.12, start = 0.03, length = 0.3, fadeOut = 0.1, jitter = 0.08 },
			{ id = WET_SLAP, volume = 0.22, pitch = 1.45, start = 0.13, length = 0.18, fadeOut = 0.08 },
		} },
		SwingSpin = { note = "Hit 2 (Whirl): the rod sweeps round, trailing spray", layers = {
			{ id = CLOTH_WHOOSH, volume = 0.4, pitch = 1.15, start = 0.5, length = 0.5, fadeIn = 0.05, fadeOut = 0.18, jitter = 0.05 },
			{ id = BUBBLE_WHOOSH, volume = 0.22, pitch = 1.2, start = 2.2, length = 0.45, fadeIn = 0.08, fadeOut = 0.2 },
		} },
		SwingDing = { note = "Hit 2 lands: a light tap of the rod tip", layers = {
			{ id = WOOD_HIT, volume = 0.6, pitch = 1.5, start = 0.03, length = 0.22, fadeOut = 0.08, jitter = 0.08 },
		} },
		FishPop = { note = "Hit 3: the giant fish flops out of nowhere with a splash", layers = {
			{ id = POOL_SPLASH, volume = 0.35, pitch = 1.45, start = 0.12, length = 0.35, fadeOut = 0.15, jitter = 0.05 },
		} },
		FishSlap = { note = "Hit 3 lands: a big wet fish slap", layers = {
			{ id = WET_SLAP, volume = 0.95, pitch = 0.92, start = 0.12, length = 0.32, fadeOut = 0.1, jitter = 0.06 },
			{ id = POOL_SPLASH, volume = 0.35, pitch = 1.1, start = 0.16, length = 0.45, fadeOut = 0.2 },
		} },
		SlamBoom = { note = "Hit 3 lands: water and ground shake", layers = {
			{ id = SPLASH_THUNK, volume = 0.85, pitch = 0.9, start = 0.12, length = 0.85, fadeOut = 0.35 },
			{ id = THUD, volume = 0.5, pitch = 0.5 },
		} },
		SlamDing = { id = PING, volume = 0.22, pitch = 0.9, note = "Hit 3 lands: stars ring (soft)" },
		-- Patch 18: the dash: a quiet water rush that swells in and trails off, never a hard edge
		DashWhoosh = { note = "The dash takes off: a smooth water-and-air rush", layers = {
			{ id = WATER_WAKE, volume = 0.34, pitch = 1.05, start = 0.2, length = 0.42, fadeIn = 0.06, fadeOut = 0.3, jitter = 0.05 },
			{ id = CLOTH_WHOOSH, volume = 0.45, pitch = 1.1, start = 0.7, length = 0.35, fadeIn = 0.04, fadeOut = 0.2, jitter = 0.05 },
		} },
		DashPop = { note = "A soft flick of spray as the dash leaves it behind", layers = {
			{ id = POOL_SPLASH, volume = 0.22, pitch = 1.6, start = 0.2, length = 0.16, fadeOut = 0.1, jitter = 0.1 },
		} },
		DashSkid = { note = "Sliding to a stop on a film of water", layers = {
			{ id = WATER_WAKE, volume = 0.24, pitch = 0.8, start = 1, length = 0.32, fadeIn = 0.03, fadeOut = 0.25 },
		} },
		-- Patch 19: the dash moves (kept, but quieter and watery so they sit with the dash)
		DashJump = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.45, pitch = 1.1, note = "Cannonball and Pole Vault take off" },
		DashLand = { note = "A heavy landing (BOOM, hero landing)", layers = {
			{ id = SPLASH_THUNK, volume = 0.55, pitch = 0.85, start = 0.12, length = 0.6, fadeOut = 0.3, jitter = 0.05 },
			{ id = THUD, volume = 0.45, pitch = 0.6 },
		} },
		DashZip = { id = SLASH, volume = 0.3, pitch = 1.8, note = "Hook Shot: the line zips out, hooks, reels" },
		DashCopter = { id = LUNGE, volume = 0.28, pitch = 2, note = "Rod Copter: the blades whirring" },
		DashSplash = { note = "Fish Surf: splashing along", layers = {
			{ id = POOL_SPLASH, volume = 0.5, pitch = 1.2, start = 0.15, length = 0.4, fadeOut = 0.2, jitter = 0.08 },
		} },
		DashBoop = { id = PING, volume = 0.3, pitch = 0.6, note = "Fish Rocket: BOOP" },
		DashSlap = { note = "Tail Slap: a wet SLAP", layers = {
			{ id = WET_SLAP, volume = 1, pitch = 1.05, start = 0.12, length = 0.3, fadeOut = 0.1, jitter = 0.06 },
		} },
		-- Patch 21: rod abilities
		SkillCast = { id = LUNGE, volume = 0.55, pitch = 0.9, note = "An ability starts" },
		SkillWave = { id = WATER, volume = 0.8, pitch = 0.75, note = "Tide Lash: the wave" },
		SkillCrash = { id = THUD, volume = 1, pitch = 0.5, note = "A heavy ability lands" },
		SkillZap = { id = PING, volume = 0.5, pitch = 0.45, note = "Lightning, rifts, the void" },
		SkillCaw = { id = UNSHEATH, volume = 0.6, pitch = 1.7, note = "Crimson Illusion: the crows burst out" },
		SkillCoins = { id = PING, volume = 0.45, pitch = 1.8, note = "Jackpot: coins and reels" },
		SkillDrum = { id = THUD, volume = 0.9, pitch = 0.75, note = "Sun God Bounce: the drum beats" },
	},
}

local rng = Random.new()

-- A bank of loaded sounds, one per clip: cues clone from it, so a hit starts the instant it's triggered instead
-- of waiting ~0.3 s for a fresh Sound to load. Filled by Audio.preload.
local bank = {}

local function newSound(id)
	local template = bank[id]
	if template and template.IsLoaded then
		return template:Clone()
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	return sound
end

-- One sound of a cue. A layer with `start` plays from that point of the clip; `length` cuts it off with a fade.
-- The cut and the fades are timed from the moment the clip is actually loaded and playing.
local function playLayer(name, layer, parent, pitch)
	local sound = newSound(layer.id)
	sound.Name = "Cue_" .. name
	local volume = layer.volume or 0.6
	sound.Volume = layer.fadeIn and 0 or volume
	local jitter = layer.jitter and rng:NextNumber(-layer.jitter, layer.jitter) or 0
	sound.PlaybackSpeed = (layer.pitch or 1) * (pitch or 1) * (1 + jitter)
	sound.RollOffMaxDistance = 120
	-- GDD Section 9: every cue plays on the SFX bus, and a 3D cue behind a wall is muffled (TideboundAudio sets these)
	if Audio.buses and Audio.buses.SFX then
		sound.SoundGroup = Audio.buses.SFX
	end
	sound.Parent = parent or SoundService
	if parent and Audio.occluder then
		Audio.occluder(sound, parent)
	end
	local speed = sound.PlaybackSpeed
	local function begin()
		if not sound.Parent then
			return
		end
		sound.TimePosition = layer.start or 0
		if layer.fadeIn then
			TweenService:Create(sound, TweenInfo.new(layer.fadeIn, Enum.EasingStyle.Sine), { Volume = volume }):Play()
		end
		if layer.length then
			-- `length` is in clip seconds; the playback speed changes how long that takes
			local fadeOut = layer.fadeOut or 0.05
			local hold = math.max(0, layer.length - fadeOut) / speed
			task.delay(hold, function()
				if sound.Parent then
					TweenService:Create(sound, TweenInfo.new(fadeOut / speed, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
				end
			end)
			Debris:AddItem(sound, hold + fadeOut / speed + 0.2)
		end
	end
	sound:Play()
	if sound.IsLoaded then
		begin()
	else
		sound.Loaded:Once(begin)
	end
	Debris:AddItem(sound, 6)
	return sound
end

-- Plays a cue at a part or attachment (3D), or on the listener when `parent` is nil. Returns the (first) Sound.
-- `pitch` multiplies the cue's own pitch (for a little random variety).
function Audio.play(name, parent, pitch: number?)
	local cue = Audio.cues[name]
	if not cue then
		return nil
	end
	if cue.layers then
		local first = nil
		for _, layer in ipairs(cue.layers) do
			local sound = playLayer(name, layer, parent, pitch)
			first = first or sound
		end
		return first
	end
	if cue.id == "" then
		return nil
	end
	return playLayer(name, cue, parent, pitch)
end

-- Loads every cue's clips into the bank up front (call once per client), so cues start at their cut point at once.
function Audio.preload()
	local folder = SoundService:FindFirstChild("TideboundCueBank") or Instance.new("Folder")
	folder.Name = "TideboundCueBank"
	folder.Parent = SoundService
	local list = {}
	for _, cue in pairs(Audio.cues) do
		for _, layer in ipairs(cue.layers or { cue }) do
			if layer.id and layer.id ~= "" and not bank[layer.id] then
				local sound = Instance.new("Sound")
				sound.SoundId = layer.id
				sound.Volume = 0
				sound.Parent = folder
				bank[layer.id] = sound
				table.insert(list, sound)
			end
		end
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

return Audio
