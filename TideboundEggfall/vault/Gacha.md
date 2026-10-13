---
tags: [gacha]
---
# Gacha

Two gachas, both on the same [[Rarity Tiers]] and [[Pity]] rules, each with its own pity counters. Both play the [[Hatch Scene]].

| Gacha | Cost | Gives | Where |
|---|---|---|---|
| [[Tide Eggs]] | 300 Pearls, or steal one in the Shoals | a creature (a voxel fish) | Egg shrine and incubator in [[Eggfall Town]] |
| [[Dash Capsules]] | 400 Pearls | a dash move | Dash Capsule machine on the plaza |

- **Duplicates** give Shards: 1 for a new item, 10 for a duplicate (`Config.Shards`).
- **Code:** `Gacha.luau` (shared roll maths), the handlers in `Main.server.luau` (`Hatch`, `OpenCapsule`), and `HatchScene.luau`.
- The Tide Chest gacha from Patch 23 isn't in the game ([[Branches]]).
