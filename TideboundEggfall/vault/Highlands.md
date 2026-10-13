---
tags: [world]
---
# Highlands

Hills, ridges and sea cliffs round [[Eggfall Town]] and a hill on every [[Sunken Shoals]] island (14 Oct 2026, `Highlands.luau`), so the world isn't one flat sheet any more. Asked for with a *Anime Vanguards*-style lobby as the reference: a hub sitting in a green valley.

## What it makes
- **Round the lobby:** gentle grass mounds between the garden's trees (up to about 5 studs), then hills climbing to ridges and peaks of about 130 studs that ring the lobby like valley walls, sloping down into the sea on the far side. The east stays open: Harbor Street, the Tidegate, the causeway and the view of the islands. A channel of sea stays open to the [[Harbor Ring]] and the [[Home Nest]] plots.
- **On each island:** a hill up to a third of its radius (at most 22 studs), rising between the paths and props.
- **Materials:** leafy grass, plain grass on high flat tops, slate and rock only on the steepest faces, sand at the waterline.
- **Dressing:** about 300 clones of the game's own 3D models: big trees, palms, cypresses and bushes low down, pines up high, rocks on steep ground and a few glowing crystal clusters (from `TideboundLobby` and `TideboundRemake`).

## Add-only
It never moves, recolours or deletes anything. It first looks down at every 4x4 stud spot:
- **Open ground** (turf, town grass, beach, an island's base) or **sea**: the land may rise there.
- **Anything standing** (paving, roads, bridges, buildings, trees, lamps, NPCs, fishing spots...): stays flat, with a clear margin round it (3 studs in the lobby and on islands, 8 to 32 studs out in the big hills).
- **The game's rock and mountain meshes** (`BackdropMountain`, `Mountain3D`, `MintRock3D`, sea stacks): the hills grow round them, so they rise out of the ridges.
- **Gameplay spots that only exist while playing** stay flat too: egg nests, beacons, fishing spots, geyser pads, Tide Caches, anemone beds, elite dens, hidden caves, viewpoints, the dive spawn, the causeway and the middle of each mob camp ([[Mobs]] walk over the hills fine).

## Running it
- **At server start** (`Main`), if there's no `Workspace.TideboundWorld.Highlands` folder yet. It builds in the background a few seconds after the server starts.
- **Or bake it into the place** (recommended): in Studio, Edit mode, run this in the command bar, look round, then save. Ctrl+Z undoes it.
  ```
  require(game.ServerScriptService.Tidebound.Highlands).build()
  ```
  Once baked, the server sees the folder and doesn't build it again.
- It never builds twice over itself. To redo it with new settings, undo or delete the old one (the folder and its terrain) first.

Tuning lives at the top of `Highlands.luau`: `townAmplitude` (how high, where), `townClearance`, `islandAmplitude`, and `DRESS` (which models). Part of the [[World Map]].
