# Tidebound: Eggfall

Cast. Steal. Hatch. Escape. Core-loop vertical slice built from Design Doc Part A and the Canon Sheet.

## What's in this slice

- **Nest** (safe zone, the Spawn Plaza): Tide Egg Shrine (odds and buy), Incubator (hatch), Tackle Shop (rods and bait), Nest Beacon, the Tide Slide to the Harbor Ring, and NPCs Pinch, Old Harl, Sister Coralie and Gate Warden Sel.
- **Sunken Shoals** (biome 1): 5 reefs joined by sandbars, 8 fishing spots, 5 wild egg nests (respawn 45s), 2 extraction beacons, the Reef Warden.
- **Fishing minigame**: hold click or touch to push the reel bar and keep the fish inside it. Rod Control widens the bar, Resilience slows progress loss, Lure Speed shortens the bite, Luck and bait raise Rare+ odds. Perfect catches pay +20%. A lost fish frays the rod (-20% Control) until you extract; a fish that escapes after passing 90% drops a Lucky Scale (+25 Pearls).
- **Heat 0-100**: +2 per fish, +8 per steal, -1 per 3s while lying low. 25 Warden patrols, 50 riptide pulls, 75 Warden locks on, 100 every beacon closes for 30s (10 s grace if you're within 10 studs of one).
- **Risk (Delta Section 9)**: 3 health, a Warden hit costs 1 and knocks you back, the third is a wipe. Each carried egg costs 2 WalkSpeed; Shift (or the SPRINT button on touch) adds 6. Lock-on drops after 6 s out of the Warden's sight. A wipe loses carried eggs and half the run's fish Pearls, and keeps the other half, the bestiary and pity.
- **Extraction**: hold 3 s at a beacon, then the Greed Window: every 5 s you stay adds +15% run payout and +5 Heat, all 15 s adds +2 Embers. Walk away or press BANK NOW to leave. Payout is 50 + 30 per egg (cap 400), plus fish Pearls and 5-25 Run Embers. Clean Extraction streak adds up to +3 Embers.
- **Open Tide (opt-in PvP)**: pick Calm or Open Tide at Gate Warden Sel (RUN tab). In Open Tide a rival behind you can hold 1 s to snatch one carried egg; never within 40 studs of a beacon; the victim gets 5 s immunity and a speed burst. Open Tide nests can hold a bonus egg (x1.20).
- **Harbor Ring hub (Delta Section 8)**: a ring town around a swimmable lagoon south of the Nest (reach it by the Tide Slide). Lagoon pier fishing (no Heat, half Pearls, banked at once), Daily Quest Board (Quill), Season Track board (Captain Brask), Leaderboard Hall (Archivist Ophel), Bait Shop (Nim), Trading Post (Tradesman Kobb), Social Plaza with stage, photo spot and heist board.
- **Home Nest plots (Delta Section 7)**: 8 plots of 120 x 120 around the Harbor Ring, one per player. Hatch Chamber, Aquarium Hall, Rod Workshop, Trophy Room and Prestige Altar (the 5 rooms), plus Creature Pen, Nest Vault and Visitor Deck outdoors. Zone unlocks and 7 upgrade tracks (incubator slots, aquarium capacity, Tank Filter, treadmill, pen size, trophy pedestals, vault capacity) on the HOME tab. Creatures swim in the tank, roam the pen, stand on trophy pedestals and on the Showcase Plinth. Visitors (Public / Friends / Private) appear in the guestbook and can Admire the showcase for +1 Egg Shard to the owner (10 per day). Nothing in a base can be stolen.
- **Tide Egg gacha**: canon 7-tier odds, independent mutation roll, pity at 25/90/300/1200 per egg type, last-10 pull history, confirm modal with odds before every purchase. Hatch one egg per incubator slot at once. Shards 1 per new creature, 10 per duplicate.
- **Economy (Delta Section 11)**: aquarium income (1% of value per minute for the earning creatures, plus filter, trophy and fed bonuses), offline income at 50% for up to 8 h, duplicate sales at 50% value, 3 daily quests (300-800 Pearls), run payout and Greed Window, Lucky Scales and pier fishing. Sinks: rods, bait, eggs, zone unlocks and upgrades.
- **Feel (Delta Section 10)**: camera FOV per situation (70 explore, 65 fishing, 80 chase, 55 hatch), screen-edge tint by Heat, hit shake and flash, extraction flash. `src/shared/Animations.luau` lists every animation from Table A with an empty id: paste the animator's asset ids there and they play on their triggers.
- **Saves** via DataStore (`TideboundEggfall_v1`). Run state is never saved.

Robux sells nothing in this slice; eggs, odds, pity, upgrades and power are all reachable by free play.

## Layout (Rojo)

| Path | Studio location |
| --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Tidebound.Config` (all canon values) |
| `src/shared/Gacha.luau` | `ReplicatedStorage.Tidebound.Gacha` (roll and pity math) |
| `src/server/Main.server.luau` | `ServerScriptService.Tidebound.Main` |
| `src/server/PlayerData.luau` | `ServerScriptService.Tidebound.PlayerData` |
| `src/server/WorldBuilder.luau` | `ServerScriptService.Tidebound.WorldBuilder` (builds the map if `Workspace.TideboundWorld` is missing) |
| `src/server/ExpansionBuilder.luau` | `ServerScriptService.Tidebound.ExpansionBuilder` (adds `TideboundWorld.Delta`: Harbor Ring, plots, Nest NPCs) |
| `src/server/BaseService.luau` | `ServerScriptService.Tidebound.BaseService` (plots, upgrades, income, visitors, boards) |
| `src/server/PlotLayout.luau` | `ServerScriptService.Tidebound.PlotLayout` (where each zone sits in a plot) |
| `src/shared/Animations.luau` | `ReplicatedStorage.Tidebound.Animations` (animation handoff list) |
| `src/shared/CreatureModels.luau` | `ReplicatedStorage.Tidebound.CreatureModels` (placeholder voxel creatures) |
| `src/client/TideboundCreatures.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundCreatures` (tank and pen motion) |
| `src/client/TideboundClient.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundClient` |

Sync with `rojo serve` (from this folder or the repo root) and the Rojo Studio plugin, or paste each file into the matching script. The Delta areas build into their own folder, so the existing Nest and Shoals are left exactly as they are.

## Not built yet

Biomes 2-5 and their guardians (so the Prestige Altar stays locked), multi-biome runs, run modifiers, co-op heists and parties, cosmetics and the Trading Post window, the season track, Shard Eggs, companions, incubator timers (and so Heat Lamps and hatch rush), Feeding Trough, Rod Rack, Bait Locker, Visitor slots, prestige, real animations and audio.
