---
tags: [code]
---
# Scripts

Every script in `TideboundEggfall/src`, with links to the notes about what it does. See [[Rojo Workflow]] before editing.

## Client (`src/client` → StarterPlayerScripts)

| Script | Lines | What it does | Notes |
|---|---|---|---|
| `TideboundClient` | 3067 | HUD, heat pill, fishing minigame, zone lighting, the stamina/sprint, and the whole menu (every tab). | [[Fishing]], [[Heat]], [[Stamina and Sprint]], [[Menu Tabs]] |
| `TideboundDialogue` | 213 | The NPC dialogue box (Patch 23). | [[NPCs]], [[Dialogue Box]] |
| `TideboundDash` | 1083 | Q rolls an equipped dash; moves you and plays its effects. | [[Dashes]] |
| `TideboundSkills` | 1650 | R casts your rod ability; cinematics and effects. | [[Rod Abilities]] |
| `TideboundRod` | 1384 | The rod in motion: cast steps, bending, line, the 3-hit combo. | [[Rod Combo]], [[Fishing]] |
| `TideboundMotion` | 1290 | Owns every R15 joint: idle, run, sprint, jump, swim, poses. Others publish on MotionBus. | [[MotionBus]] |
| `TideboundLife` | 720 | Villagers walking the streets, fishers, vendors, NPC idle motion, leaping fish. | [[Eggfall Town]], [[NPCs]] |
| `TideboundMap` | 525 | The round minimap and the sea chart. | [[Minimap]] |
| `TideboundMobs` | 584 | Draws and animates the mobs the server runs. | [[Mobs]] |
| `TideboundCutscenes` | 760 | Intro flyover, dive, guardian wake, descent, extraction, wipe. | [[Cutscenes]] |
| `TideboundFX` | 449 | Spinning, floating, bobbing and sailing world props. |  |
| `TideboundFoliage` | 233 | Voxel grass on ground tagged TideboundGrass. |  |
| `TideboundTravel` | 257 | Geyser jump pads, the edge current. | [[Sunken Shoals]] |
| `TideboundWind` | 157 | Wind-line trails and swaying foliage. |  |
| `TideboundCreatures` | 141 | Idle motion for Home Nest creatures and companions. | [[Companions]], [[Home Nest]] |

## Server (`src/server` → ServerScriptService.Tidebound)

| Script | Lines | What it does | Notes |
|---|---|---|---|
| `Main` | 2400 | Dives, fishing, egg stealing, heat, the Reef Warden, extraction, every gacha handler. | [[Core Loop]], [[Gacha]] |
| `PlayerData` | 172 | The DataStore save and its template. | [[Saves]] |
| `BaseService` | 831 | Home Nest plots, upgrades, aquarium income, storage, visitors, leaderboards. | [[Home Nest]], [[Economy]] |
| `Companions` | 176 | Companion creatures that follow you and carry eggs. | [[Companions]] |
| `Crew` | 170 | Crews: invite-only co-op up to 4. | [[Crews and Contested Waters]] |
| `Mobs` | 620 | Wild mob AI: crabs, puffers, gulls, golems, sharks. | [[Mobs]] |
| `Threats` | 485 | Elites (Barnacle Brute, Snapjaw Moray), anemones. | [[Mobs]] |
| `Rods` | 98 | Puts your rod on your back / in your hand. | [[Rods]] |
| `TownBuilder` | 1208 | Builds Eggfall Town and the spawn plaza (VERSION 9). | [[Eggfall Town]] |
| `ExpansionBuilder` | 653 | Builds the Harbor Ring, Home Nest plots and the plaza NPCs (VERSION 8). | [[Harbor Ring]], [[Home Nest]], [[NPCs]] |
| `WorldBuilder` | 1051 | Lighting, sky, the spawn and the shared prop kit (K). | [[Builders]] |
| `PropKit` | 963 | The reference-style props: houses, Tide Lab, Tide Center, shop house, chest, fences, letters. | [[Builders]] |
| `ShoalsBuilder` | 1220 | The Sunken Shoals: 22 islands, bridges, geysers. | [[Sunken Shoals]] |
| `DescentBuilder` | 866 | Kelp Cathedral and shared pieces. | [[Kelp Cathedral]] |
| `HorizonBuilder` | 609 | Scenery ring hiding the edge of the world. | [[Horizon]] |
| `PlotLayout` | 43 | One Home Nest plot's layout. | [[Home Nest]] |

## Shared (`src/shared` → ReplicatedStorage.Tidebound)

| Script | Lines | What it does | Notes |
|---|---|---|---|
| `Config` | 568 | Every number: tiers, odds, pity, rods, bait, heat, NPCs, prices. | [[Config]] |
| `Gacha` | 110 | Roll maths shared by server and client. | [[Gacha]] |
| `HatchScene` | 993 | The hatch cutscene for eggs, capsules and chests. | [[Hatch Scene]] |
| `DashMoves` | 364 | The 12 dash moves. | [[Dashes]] |
| `RodSkills` | 289 | The 11 rod abilities. | [[Rod Abilities]] |
| `RodModels` | 469 | Rod models and bobbers. | [[Rods]] |
| `MotionBus` | 33 | How client scripts share joints and state. | [[MotionBus]] |
| `IslesLayout` | 315 | The map plan everything reads. | [[World Map]] |
| `Audio` | 109 | Sound cues (paste asset ids here). | [[Audio]] |
| `Fx` | 280 | One-shot cube bursts, bolts, rings, alerts. |  |
| `CreatureModels` | 83 | Placeholder voxel creatures. |  |
| `FishModels` | 180 | Placeholder fish models. | [[Fishing]] |
| `FishingFeel` | 29 | Bridge between the fishing minigame and TideboundRod. | [[Fishing]] |
| `Animations` | 44 | Animation id handoff list. |  |

**Limit to remember:** `TideboundClient`'s main chunk is near Luau's 200-local limit. New code there goes inside `do ... end` blocks with its state in one table.
