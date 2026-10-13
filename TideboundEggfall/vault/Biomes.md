---
tags: [world]
---
# Biomes

The five canon biomes (`Biomes.luau`), laid over the built map. Lighting, post-processing ([[Weather and Wind]], `TideboundBiomeLook`), music and ambience ([[Audio]]) and VFX budgets all read this table.

| Biome | Where |
|---|---|
| Open Sea | [[Eggfall Town]], ring 1 (the Shallows) and the water between rings |
| Coral Reef | ring 2 (the Coral Maze) and Giant Clam Atoll |
| Kelp Forest | [[Kelp Cathedral]] and Kelp Shallows |
| Abyssal Trench | Maelstrom Isle and Bone Reef |
| Volcanic Isle | Warden's Rock, Storm Spire and Far Reach |

Each biome sets its own clock (14:00, or 20:00 for the glowing biomes), atmosphere and colour grade, and shows a small title when you enter. A part tagged `BiomeVolume` with a `Biome` attribute overrides everything inside its box. Each biome can have a Surge ([[Fishing Overhaul]]).
