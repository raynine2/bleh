---
tags: [code]
---
# Builders

The world is built by server modules at startup. Each stamps a `Version` on its folder and only rebuilds when its `VERSION` changes:
- `TownBuilder` (8) → [[Eggfall Town]]
- `ExpansionBuilder` (7) → [[Harbor Ring]], [[Home Nest]], [[NPCs]]
- `ShoalsBuilder` → [[Sunken Shoals]]; `DescentBuilder` → [[Kelp Cathedral]]; `HorizonBuilder` → [[Horizon]]
- `WorldBuilder` (lighting, sky, spawn, the shared kit `K`) and `PropKit` (log cabins, brick houses, neon shops, vending machines, crystals, igloos, fences)
- `WalkwayFix` runs after the builders and patches street piers and rope bridges so nobody falls through.
