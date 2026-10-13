---
tags: [code]
---
# Scripts

All 76 scripts in the game (`TideboundEggfall/src` on `game-current`), with the first line of each script's own description. See [[Rojo Workflow]] before editing.

## Client (`src/client` → StarterPlayerScripts)

| Script | Lines | What it says it does | Notes |
|---|---|---|---|
| `TideboundAudio` | 712 | audio director (GDD Section 9). Everything you hear that isn't a one-off cue: | [[Audio]] |
| `TideboundBiomeLook` | 160 | biome look (GDD Section 7, Section 10 "Client" rows for Atmosphere, ColorCorrection, Bloom, DOF | [[Biomes]] |
| `TideboundClient` | 3167 | client: HUD, heat meter, fishing minigame, zone lighting, and the menu. | [[Fishing]], [[Heat]], [[Stamina and Sprint]], [[Menu Tabs]] |
| `TideboundCreatures` | 141 | idle motion for Home Nest creatures (Delta Section 7) and companions (Master Patch 1). | [[Companions]], [[Home Nest]] |
| `TideboundCutscenes` | 764 | cutscenes (Big Update). Short camera moments that make the big beats feel good: | [[Cutscenes]] |
| `TideboundDash` | 1083 | the dash (Patch 19). Q (DASH on touch, B on a gamepad) rolls one of the moves in | [[Dashes]] |
| `TideboundFX` | 449 | the living world (Big Update). Everything here moves only on your screen: |  |
| `TideboundFischCast` | 281 | the Fisch-style power cast (HJHJH's video, 12 Oct 2026). | [[Fishing]] |
| `TideboundFishingPlus` | 458 | Fishing Overhaul screen (12 Oct 2026), copied from the Fisch "Best Money Spots" video. | [[Fishing Overhaul]] |
| `TideboundFoliage` | 326 | thick voxel grass, on your screen only (Patch 13). Around the camera, every patch of ground |  |
| `TideboundHealthCheck` | 47 | health check (Studio only). | [[Health Check]] |
| `TideboundLife` | 705 | Eggfall Town comes alive (Patch 10). Everything here exists only on your screen: | [[Eggfall Town]], [[NPCs]] |
| `TideboundMap` | 566 | the minimap and the sea chart (Patch 12), drawn from IslesLayout. | [[Minimap]] |
| `TideboundMenus` | 1334 | retention menus (GDD Sections 6, 7, 12): QUESTS, season PASS, SHOP, BOARDS, egg ODDS and | [[LiveOps]], [[Menu Tabs]] |
| `TideboundMobs` | 584 | draws the wild mobs of the Open Isles on your screen (Patch 10). The server (Mobs) thinks | [[Mobs]] |
| `TideboundMotion` | 1306 | every player's body in motion (Big Update), on your screen, posed in code. | [[MotionBus]] |
| `TideboundRide` | 833 | riding your fish and the water effects (12 Oct 2026, "Swimming + Fish Riding" update). | [[Swimming and Riding]] |
| `TideboundRod` | 1931 | the rod in motion (Master Patches 5 and 7), for every player on your screen. | [[Rod Combo]], [[Fishing]] |
| `TideboundSkills` | 1661 | rod abilities (Patch 21). R (Y on a gamepad, SKILL on touch) casts your rod's ability | [[Rod Abilities]] |
| `TideboundStance` | 216 | the two stances (13 Oct 2026, HJHJH). X (or the gamepad Y button, or a tap on the little | [[Stances]] |
| `TideboundTravel` | 257 | getting around the Open Isles (Patch 10), all on your own screen: | [[Sunken Shoals]] |
| `TideboundUnderwater` | 215 | the underwater look. Every frame it finds where the camera sits against the sea's surface | [[Underwater]] |
| `TideboundVfx` | 239 | gameplay VFX (GDD Section 8 Table B) and the VFX Clarity Rules on the client: | [[Visual Effects]] |
| `TideboundWeather` | 334 | wind, weather and biome particles on the client (GDD Section 8 Table B and Table C, and the | [[Weather and Wind]] |
| `TideboundWind` | 157 | wind, following DevBoxy's "How to make wind effects in (Roblox Studio)" video | [[Weather and Wind]] |

## ReplicatedFirst (`src/first`)

| Script | Lines | What it says it does | Notes |
|---|---|---|---|
| `TideboundLoading` | 359 | loading screen. Runs from ReplicatedFirst, before anything else on the client. | [[Loading Screen]] |

## Server (`src/server` → ServerScriptService.Tidebound)

| Script | Lines | What it says it does | Notes |
|---|---|---|---|
| `BaseService` | 831 | Home Nest plots (Delta Section 7) and the base side of the economy (Section 11). | [[Home Nest]], [[Economy]] |
| `Companions` | 176 | companion creatures (Master Patch 1 step 4 and Patch 2's loss table). | [[Companions]] |
| `Crew` | 170 | Crews (Master Patch 1). Solo is the default and co-op is opt-in: a Crew forms only | [[Crews and Contested Waters]] |
| `DescentBuilder` | 866 | the Big Update map. Builds Kelp Cathedral into Workspace.TideboundWorld.Descent, and | [[Kelp Cathedral]] |
| `ExpansionBuilder` | 519 | Delta Sections 7 and 8. Builds the Harbor Ring hub and the 8 Home Nest plots as a | [[Harbor Ring]], [[Home Nest]], [[NPCs]] |
| `FishingPlusService` | 494 | Fishing Overhaul server (12 Oct 2026). Surges, roaming rare fish, stacked conditions, | [[Fishing Overhaul]] |
| `HorizonBuilder` | 609 | the horizon (Patch 17). Before this the sea simply stopped a few hundred studs past the | [[Horizon]] |
| `LiveOps` | 867 | retention systems on the server (GDD Sections 6, 10, 12). Daily quests, weekly goals, | [[LiveOps]] |
| `Main` | 2593 | server: dives, fishing sessions, egg stealing, heat, the Reef Warden, extraction, gacha. | [[Core Loop]], [[Gacha]] |
| `Mobs` | 620 | wild mobs of the Open Isles (Patch 10). Camps of Snapper Crabs, Spike Puffers, Raider Gulls | [[Mobs]] |
| `PlayerData` | 221 | persistent player saves (DataStore). Run state lives in Main and is never saved. | [[Saves]] |
| `PlotLayout` | 43 | one Home Nest plot's layout (Delta Section 7), shared by ExpansionBuilder (the shell) | [[Home Nest]] |
| `PropKit` | 781 | the reference-style prop kit (Patch 14). Every piece is chunky voxel blocks with classic | [[Builders]] |
| `RideService` | 123 | fish riding on the server (12 Oct 2026, "Swimming + Fish Riding" update). | [[Swimming and Riding]] |
| `Rods` | 107 | you wear your rod everywhere (Master Patch 7). It rides on your back in the Nest, the | [[Rods]] |
| `ShoalsBuilder` | 1220 | the Sunken Shoals of the Open Isles (Patch 10). Builds Workspace.TideboundWorld.SunkenShoals | [[Sunken Shoals]] |
| `Threats` | 485 | Sunken Shoals threats beyond the Reef Warden (Master Patch 3, Tables B to D). | [[Mobs]] |
| `TownBuilder` | 1162 | Eggfall Town, the safe spawn of the Open Isles (Patch 10). Builds | [[Eggfall Town]] |
| `WalkwayFix` | 313 | walkway safety pass. Runs after the builders (Main) and is safe in Edit mode; every step is | [[Eggfall Town]] |
| `WindService` | 129 | wind and weather on the server (GDD Section 8 Table C, Section 10 Table A "Wind: Server"). | [[Weather and Wind]] |
| `WorldBuilder` | 1053 | builds the Nest plaza at the heart of Eggfall Town, the sky, and the shared prop kit. | [[Builders]] |

## Shared (`src/shared` → ReplicatedStorage.Tidebound)

| Script | Lines | What it says it does | Notes |
|---|---|---|---|
| `Animations` | 44 | animation handoff list (Delta Section 10, Table A). |  |
| `Audio` | 271 | sound cues (Master Patches 5 to 7), ready for the sound designer. | [[Audio]] |
| `BaseBuilder` | 111 | BaseBuilder - Player base customization, building, and equipment display system | [[Base Builder]] |
| `Biomes` | 272 | the five canon biomes (GDD Sections 7, 8 and 9) and which one a position is in. | [[Biomes]] |
| `ClientBus` | 106 | how the client scripts tell the audio, VFX and UI layers what is happening (GDD Sections 8-9). | [[Audio]], [[Visual Effects]] |
| `Config` | 565 | every locked value from the Canon Sheet lives here. | [[Config]] |
| `CreatureModels` | 97 | creature models for companions, the Home Nest and the hatch fallback. |  |
| `DashMoves` | 364 | the dash moves (Patch 19). Q rolls one of these (never the same twice in a row), from the | [[Dashes]] |
| `FischUI` | 738 | the Fisch-style fishing screens (HJHJH's video, 12 Oct 2026). Client only. | [[Fishing]] |
| `FishModels` | 180 | placeholder fish models for the landing flip and the reveal (Master Patches 5 and 6). | [[Fishing]] |
| `FishThumbs` | 34 | voxel fish thumbnails (12 Oct), rendered from C:\OBS\fish_models\voxel\build_voxel_fish.py | [[Rarity Tiers]] |
| `FishView` | 222 | fish thumbnails + 3D fish in the UI (Phase 4/5, 12 Oct). | [[Rarity Tiers]] |
| `FishingFeel` | 83 | the fishing feel bridge (Master Patches 5 and 6), used on the client only. | [[Fishing]] |
| `FishingPlus` | 121 | the Fishing Overhaul (12 Oct 2026), copied from the Fisch "Best Money Spots" video. | [[Fishing Overhaul]] |
| `Fx` | 280 | blocky one-shot effects for the client scripts (Big Update), in the voxel style of the |  |
| `Gacha` | 110 | pure roll math shared by server (rolls) and client (odds display). | [[Gacha]] |
| `HatchScene` | 966 | the egg hatch scene (Patch 11), in the style of the reference short. Client only. | [[Hatch Scene]] |
| `IslesLayout` | 462 | the Open Isles map plan (Patch 10). One table that the builders (TownBuilder, | [[World Map]] |
| `LiveOpsData` | 269 | retention tables (GDD Sections 6, 7, 12): daily quests, weekly goals, seasonal events, the | [[LiveOps]] |
| `MotionBus` | 33 | how the client scripts share a character's joints (Big Update). | [[MotionBus]] |
| `RodFx` | 446 | rod-flavoured bursts, camera punches and screen shake (13 Oct 2026). Client only. | [[Visual Effects]] |
| `RodModels` | 469 | the six rod models and their bobbers (Master Patch 7: the rod is a character). | [[Rods]] |
| `RodSkills` | 289 | rod abilities (Patch 21). Every rod has its own ability on R (Y on a gamepad, SKILL on | [[Rod Abilities]] |
| `Soundtrack` | 234 | audio direction data (GDD Section 9). TideboundAudio plays all of it. | [[Audio]] |
| `UiIcons` | 61 | UI icons: hand-painted icons (thick dark outline, gradient body, white highlight streak) used | [[Menu Tabs]] |
| `UiKit` | 269 | UI kit: the REF 4 menu style (black panel, red neon outline, diagonal stripes, gradient bars, | [[Menu Tabs]] |
| `VfxLibrary` | 442 | VFX library (GDD Section 8 Table B, VFX Clarity Rules, Section 10 particle rows). | [[Visual Effects]] |
| `WaterFx` | 217 | realistic water and catch effects (Fishing FX remake, 12 Oct 2026). | [[Visual Effects]] |
| `WaterMoves` | 390 | swimming and fish riding (12 Oct 2026, "Swimming + Fish Riding" update). | [[Swimming and Riding]] |

**Not in the repo on purpose:** the Superbullet Studio plugin's scripts (and its Knit, ProfileStore and Packages files) and the `ServerStorage.TideboundBackups` folders. They stay in Studio; Rojo never touches them.

**Limit to remember:** `TideboundClient`'s main chunk is near Luau's 200-local limit. New code there goes inside `do ... end` blocks with its state in one table. [[Health Check]] shows a red banner if the HUD ever goes missing.
