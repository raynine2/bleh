---
tags: [code]
---
# Builders

The world is built by server modules at startup. Each stamps a `Version` on its folder and only rebuilds when its `VERSION` changes:
- `TownBuilder` (9) → [[Eggfall Town]]
- `ExpansionBuilder` (8) → [[Harbor Ring]], [[Home Nest]], [[NPCs]]
- `ShoalsBuilder` → [[Sunken Shoals]]; `DescentBuilder` → [[Kelp Cathedral]]; `HorizonBuilder` → [[Horizon]]
- `WorldBuilder` (lighting, sky, spawn, the shared kit `K`) and `PropKit` (houses, Tide Lab, Tide Center, shop house, treasure chest, fences, carved letters)
