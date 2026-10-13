-- Tidebound: Eggfall: audio direction data (GDD Section 9). TideboundAudio plays all of it.
--
-- Every id below is a Roblox-licensed library sound (APM Music, Pro Sound Effects, DistroKid) or a public
-- Creator Store upload, picked by name and description. They are stand-ins until the sound designer's own mixes
-- arrive: paste a new id over any of them. A sound that fails to load is simply silent, never an error.
--
-- Music states use stems when you have them: list several `tracks` in one state and they start together and loop
-- in sync (Pad, Percussion, Bass...). Until then each state is one full mix, and `layers` documents the stems the
-- GDD asks for.

local Soundtrack = {}

local function id(n)
	return "rbxassetid://" .. tostring(n)
end

-- Section 9 Mix Bus Targets. dB is converted to SoundGroup.Volume with 10^(dB/20). Ambience isn't in the GDD
-- table; it sits under SFX so it follows the SFX target and ducks with it.
Soundtrack.buses = {
	{ name = "Master", db = -6 },
	{ name = "Music", db = -12, parent = "Master" },
	{ name = "SFX", db = -8, parent = "Master" },
	{ name = "Ambience", db = 0, parent = "SFX" },
	{ name = "UI", db = -10, parent = "Master" },
	{ name = "Voice", db = -6, parent = "Master" },
}

-- Ducking rules from the same table, in dB. Several rules on one bus don't stack: the deepest one wins.
Soundtrack.ducking = {
	important = { Music = 6 }, -- dialogue / important SFX: a gacha reveal, a guardian roar, a title card
	swell = { SFX = 3 }, -- music swells: every stinger
	gameplay = { UI = 2 }, -- UI is 2 dB down whenever no menu is open
	voice = { Music = 4, SFX = 4 }, -- a voice line (creature vocal) is playing
}
Soundtrack.duckAttack = 0.15
Soundtrack.duckRelease = 0.6

function Soundtrack.dbToVolume(db)
	return 10 ^ (db / 20)
end

-- Section 9 Table A: adaptive music. `transition` is what happens when this state starts:
--   crossfade (seconds), stinger (played first, on the next beat of the old track), duck (the old track dips
--   under the stinger instead of fading), hardCut (the old track stops dead).
-- `priority`: when several states want to play, the highest wins (Wipe > Boss > Reveal > Extract > Heist > Hunt).
Soundtrack.music = {
	Calm = {
		bpm = 70, key = "C Major", layers = { "Pad", "Ambient" }, trigger = "Default exploration",
		priority = 0, transition = { crossfade = 4 },
		tracks = { { id = id(1846078893), volume = 0.8, note = "APM: Song Of The Whales" } },
	},
	Menu = {
		bpm = 80, key = "C Major", layers = { "Lo-fi", "Pad" }, trigger = "Main menu",
		priority = 1, transition = { crossfade = 1, fadeIn = true },
		tracks = { { id = id(9046863253), volume = 0.7, note = "APM: Poolside" } },
	},
	Hunt = {
		bpm = 110, key = "A Minor", layers = { "Pad", "Percussion", "Bass" }, trigger = "Mob aggro",
		priority = 2, transition = { stinger = "HuntSting", crossfade = 2 },
		tracks = { { id = id(1840049721), volume = 0.9, note = "APM: Drum Drone (a 60)" } },
	},
	Heist = {
		bpm = 130, key = "E Minor", layers = { "Bass", "Drums", "Synth" }, trigger = "Egg steal",
		priority = 3, transition = { stinger = "HeistSting", crossfade = 1 },
		tracks = { { id = id(1840638834), volume = 0.85, note = "APM: Ultimatum (C)" } },
	},
	Extract = {
		bpm = 120, key = "G Major", layers = { "Uplifting Synth", "Drums" }, trigger = "Extraction start",
		priority = 4, transition = { crossfade = 2 },
		tracks = { { id = id(1839223151), volume = 0.85, note = "APM: Future Victory" } },
	},
	Reveal = {
		bpm = 90, key = "F Major", layers = { "Pad", "Chimes", "Choir" }, trigger = "Gacha pull",
		priority = 5, transition = { duck = true, stinger = "RevealSting", crossfade = 0.5 },
		tracks = { { id = id(1838853276), volume = 0.8, note = "APM: Sylvia Celesta" } },
	},
	Boss = {
		bpm = 140, key = "D Minor", layers = { "Orchestral", "Choir", "Drums" }, trigger = "Guardian spawn",
		priority = 6, transition = { hardCut = true, stinger = "BossSting" },
		tracks = { { id = id(1841702618), volume = 0.9, note = "APM: War of the Gods (a 60)" } },
	},
	Wipe = {
		bpm = 60, key = "N/A", layers = { "Silence", "Low Drone" }, trigger = "Player death",
		priority = 7, transition = { hardCut = true },
		tracks = { { id = id(9114353372), volume = 0.45, note = "PSE: Evil Drone Deep Rumbly Keening" } },
	},
}

-- One-shot stingers. They play on the Music bus and swell it, so SFX ducks 3 dB under them.
Soundtrack.stingers = {
	HuntSting = { id = id(1837950656), volume = 0.7, length = 2.5, note = "APM: Brute Force Sting 3" },
	HeistSting = { id = id(1843490542), volume = 0.7, length = 2, note = "APM: Critical Mass - SFX Riser 1" },
	RevealSting = { id = id(1840525370), volume = 0.8, length = 2, note = "APM: Harp Glissando (C)" },
	BossSting = { id = id(1843492737), volume = 0.9, length = 3, note = "APM: Ghost Resurrection - SFX Riser 3" },
}

-- Section 9 Table B: ambient beds. The bed loops on the Ambience bus; detail layers are 3D one-shots placed
-- around you every `every` seconds (min, max) and are occluded like any world sound.
Soundtrack.ambience = {
	OpenSea = {
		bed = { id = id(137826155053556), volume = 0.55, note = "DistroKid: Ocean waves on the beach" },
		details = {
			{ name = "Seagulls", id = id(9112870701), volume = 0.35, every = { 9, 18 }, distance = { 30, 70 }, height = { 15, 35 } },
			{ name = "Wind", id = id(9113286969), volume = 0.3, every = { 14, 26 }, distance = { 10, 25 }, height = { 4, 10 } },
			{ name = "Hull Creak", id = id(9114400707), volume = 0.25, pitch = 0.7, every = { 16, 30 }, distance = { 15, 40 }, height = { 0, 4 } },
		},
	},
	CoralReef = {
		bed = { id = id(9120572579), volume = 0.5, note = "PSE: Water Lap Small Waves 2" },
		details = {
			{ name = "Fish Bubbles", id = id(9112752570), volume = 0.35, every = { 6, 12 }, distance = { 8, 25 }, height = { -4, 1 } },
			{ name = "Coral Crackle", id = id(9112752575), volume = 0.25, pitch = 1.7, every = { 8, 16 }, distance = { 8, 25 }, height = { -3, 1 } },
		},
	},
	KelpForest = {
		bed = { id = id(9112889917), volume = 0.55, note = "PSE: Underwater Ambience 1" },
		details = {
			{ name = "Kelp Sway", id = id(9113605893), volume = 0.25, pitch = 0.8, every = { 7, 14 }, distance = { 10, 30 }, height = { 0, 12 } },
			{ name = "Distant Whales", id = id(7971842732), volume = 0.35, every = { 20, 40 }, distance = { 80, 140 }, height = { -10, 10 } },
		},
	},
	AbyssalTrench = {
		bed = { id = id(9125485206), volume = 0.6, note = "PSE: Deep Synth Drone Modulating Sub Rumble" },
		details = {
			{ name = "Sonar Pings", id = id(75886285262316), volume = 0.3, every = { 10, 20 }, distance = { 40, 90 }, height = { -10, 10 } },
			{ name = "Pressure Creaks", id = id(9120367738), volume = 0.3, pitch = 0.6, every = { 12, 24 }, distance = { 15, 40 }, height = { -6, 6 } },
		},
	},
	VolcanicIsle = {
		bed = { id = id(318794788), volume = 0.5, note = "Lava Bubbling Boiling Loop" },
		details = {
			{ name = "Ash Fall", id = id(9113286782), volume = 0.25, pitch = 0.75, every = { 8, 16 }, distance = { 6, 20 }, height = { 8, 20 } },
			{ name = "Distant Eruptions", id = id(9112823552), volume = 0.5, every = { 18, 36 }, distance = { 90, 160 }, height = { 0, 20 } },
		},
	},
}
Soundtrack.ambienceFade = 3 -- seconds to cross between two biomes' beds

-- Weather (Section 8 Table B): the rain loop and the thunder after a lightning strike.
Soundtrack.weather = {
	Rain = { id = id(9112855079), volume = 0.45, note = "PSE: Rain On Water 1" },
	Thunder = { id = id(72113341430811), volume = 0.8, note = "WX_Thunder_Rolling_01" },
	ThunderClose = { id = id(91289467382888), volume = 0.9, note = "WX_Thunder_Close_03" },
}

-- Section 9 Table C: the three gacha stages. HatchScene plays them on its own beats; durations are the GDD's.
Soundtrack.gacha = {
	PreReveal = {
		duration = 2.0, purpose = "Build anticipation",
		sounds = {
			{ id = id(1843490542), volume = 0.7, note = "Rising synth (APM Critical Mass riser)" },
			{ id = id(9043365842), volume = 0.8, note = "Heartbeat (APM HEARTBEAT 02 96BPM)" },
		},
	},
	Reveal = {
		duration = 0.5, purpose = "Dopamine release",
		sounds = {
			{ id = id(1837950656), volume = 0.9, note = "Choir hit (APM Brute Force Sting 3)" },
			{ id = id(118987440163311), volume = 0.7, note = "Glass shatter" },
		},
	},
	RarityConfirm = {
		duration = 1.5, purpose = "Reinforce reward value",
		sounds = {
			{ id = id(1840525598), volume = 0.8, note = "Harp glissando (APM Harp Glissando P)" },
			{ id = id(9119218944), volume = 0.6, note = "Coin payoff (PSE Slot Machine 2)" },
		},
	},
}

-- Section 9 Creature Vocals: each guardian layers two or three sounds into one signature. `roar` plays when it
-- wakes or roars, `call` is the short sound on a strike tell, `idle` an occasional call while it's near.
-- Built guardians point at their signature through `guardianVocal`.
Soundtrack.vocals = {
	TideGuardian = {
		text = "Deep, resonant whale-song layered with stone grinding",
		roar = { { id = id(7971841997), volume = 0.9, pitch = 0.8 }, { id = id(9113807259), volume = 0.6, pitch = 0.6 } },
		call = { { id = id(9113807632), volume = 0.6, pitch = 0.7 } },
		idle = { { id = id(7971843171), volume = 0.5, pitch = 0.85 } },
	},
	CoralTitan = {
		text = "High-pitched chittering clicks mixed with crashing waves",
		roar = { { id = id(9112752575), volume = 0.8, pitch = 2.2 }, { id = id(9119679789), volume = 0.8 } },
		call = { { id = id(9112752570), volume = 0.6, pitch = 2.4 } },
		idle = { { id = id(9112752575), volume = 0.4, pitch = 2 } },
	},
	KelpWraith = {
		text = "Whispered, breathy vocals with rustling leaf undertones",
		roar = { { id = id(9125440168), volume = 0.9 }, { id = id(9113286782), volume = 0.5, pitch = 1.3 } },
		call = { { id = id(9125440168), volume = 0.6, pitch = 1.2 } },
		idle = { { id = id(9125711718), volume = 0.35, pitch = 0.8 } },
	},
	AbyssalMaw = {
		text = "Distorted, low-frequency growls with sonar pings",
		roar = { { id = id(9114353261), volume = 0.9, pitch = 0.6 }, { id = id(75886285262316), volume = 0.6 } },
		call = { { id = id(9114353534), volume = 0.7, pitch = 0.7 } },
		idle = { { id = id(75886285262316), volume = 0.4, pitch = 0.8 } },
	},
	VolcanicBehemoth = {
		text = "Guttural roars mixed with lava bubbling and cracking rock",
		roar = { { id = id(71120404192383), volume = 1 }, { id = id(9112823552), volume = 0.7 }, { id = id(9113220677), volume = 0.6 } },
		call = { { id = id(71120404192383), volume = 0.7, pitch = 1.2 } },
		idle = { { id = id(318794788), volume = 0.4, pitch = 0.7 } },
	},
}
Soundtrack.guardianVocal = {
	ReefWarden = "TideGuardian", -- the Shoals guardian
	KelpLeviathan = "KelpWraith", -- Kelp Cathedral's guardian
}
Soundtrack.idleCallRange = 120 -- an awake guardian this close calls now and then

-- The tension layer (Section 9, Audio Supports Tension): a heartbeat that grows with heat and with the escape
-- clock (the Greed Window and closed beacons), while the music loses its highs.
Soundtrack.tension = {
	heartbeat = { id = id(9043365842), volume = 0.9 },
	startHeat = 50, -- heat where the heartbeat comes in
	maxHighCut = -24, -- dB taken off the music's highs at full tension
	minSpeed = 0.9, -- heartbeat playback speed at the start of tension and at full tension
	maxSpeed = 1.45,
}

-- UI bus sounds for the menus (built-in sounds, so they always load).
Soundtrack.ui = {
	Click = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 1.4 },
	Open = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitch = 1.1 },
	Claim = { id = id(9119218944), volume = 0.4, length = 1.2 },
	Error = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 0.6 },
}


-- 2026-10-12 lobby remake: the Nest hub (Biomes.list.Nest) plays the Open Sea ambience.
Soundtrack.ambience.Nest = Soundtrack.ambience.OpenSea

return Soundtrack
