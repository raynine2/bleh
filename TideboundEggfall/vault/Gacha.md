---
tags: [gacha]
---
# Gacha

Three gachas, all on the same [[Rarity Tiers]] and [[Pity]] rules, each with its own pity counters. All three play the [[Hatch Scene]].

| Gacha | Cost | Gives | Where |
|---|---|---|---|
| [[Tide Eggs]] | 300 Pearls, or steal one in the Shoals | a creature | Egg shrine and incubator in [[Eggfall Town]] |
| [[Dash Capsules]] | 400 Pearls | a dash move | Dash Capsule machine in the Tide Lab yard |
| [[Tide Chest]] | 600 Pearls | a creature **or** (50%) a dash | Treasure chest in front of the Tide Lab |

- **Duplicates** give Shards: 1 for a new item, 10 for a duplicate (`Config.Shards`).
- **Code:** `Gacha.luau` (shared roll maths), the handlers in `Main.server.luau` (`Hatch`, `OpenCapsule`, `OpenChest`), and `HatchScene.luau`.
