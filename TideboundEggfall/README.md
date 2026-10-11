# Tidebound: Eggfall

Cast. Steal. Hatch. Escape. Core-loop vertical slice built from Design Doc Part A and the Canon Sheet.

## What's in this slice

- **Nest** (safe zone): Tide Egg Shrine (odds and buy), Incubator (hatch), Tackle Shop (rods and bait), Nest Beacon.
- **Sunken Shoals** (biome 1): 5 reefs joined by sandbars, 8 fishing spots, 5 wild egg nests (respawn 45s), 2 extraction beacons, the Reef Warden.
- **Fishing minigame**: hold click or touch to push the reel bar and keep the fish inside it. Rod Control widens the bar, Resilience slows progress loss, Lure Speed shortens the bite, Luck and bait raise Rare+ odds. Perfect catches pay +20%.
- **Heat 0-100**: +2 per fish, +8 per steal, -1 per 3s while lying low. 25 Warden patrols, 50 riptide pulls, 75 Warden locks on, 100 every beacon closes for 30s.
- **Extraction**: fish Pearls and stolen eggs are at risk until you extract at a beacon (5-25 Run Embers). Getting caught by the Warden wipes the haul.
- **Tide Egg gacha**: canon 7-tier odds, independent mutation roll, pity at 25/90/300/1200 per egg type, last-10 pull history, confirm modal with odds before every purchase. Shards 1 per new creature, 10 per duplicate. Hatched creatures earn passive Pearls in the aquarium (top 10).
- **Saves** via DataStore (`TideboundEggfall_v1`). Run state is never saved.

Robux sells nothing in this slice; eggs, odds and pity are all reachable by free play.

## Layout (Rojo)

| Path | Studio location |
| --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Tidebound.Config` (all canon values) |
| `src/shared/Gacha.luau` | `ReplicatedStorage.Tidebound.Gacha` (roll and pity math) |
| `src/server/Main.server.luau` | `ServerScriptService.Tidebound.Main` |
| `src/server/PlayerData.luau` | `ServerScriptService.Tidebound.PlayerData` |
| `src/server/WorldBuilder.luau` | `ServerScriptService.Tidebound.WorldBuilder` (builds the map if `Workspace.TideboundWorld` is missing) |
| `src/client/TideboundClient.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundClient` |

Sync with `rojo serve` and the Rojo Studio plugin, or paste each file into the matching script.

## Not built yet

Biomes 2-5 and their guardians, multi-biome runs, run modifiers, treadmill, incubator timers and slots, aquarium capacity upgrades, nest rooms, bestiary UI, prestige, season track.
