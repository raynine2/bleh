---
tags: [code]
---
# Branches

State of the GitHub branches (repo `raynine2/bleh`), 13 Oct 2026:

| Branch | What's on it |
|---|---|
| `game-current` | **The live game**, saved from Studio (newmainBEFORECLOUD.rbxl). This vault describes it. Should become `main`. |
| `claude/sharp-lamport-tblg7c` | Patch 23 on top of an older base: the summer town (Tide Lab, Tide Center, brick roads), the cartoony NPC restyle and Nurse Pip, the NPC dialogue box, the Tide Chest gacha. **Not in the game.** |
| `claude/tidebound-delta-3z36wi` | One commit: an `IsleFeatures` script plus mob and island changes. **Not in the game.** |
| `feat/gdd-audio-ui-vfx` | Your friend's UI, audio and LiveOps work. The game has newer versions of all of it. |
| `main` | Very old (Patch 10). |
| `studio-ui`, `recovered-*` | Old snapshots. |

To add Patch 23 or the island features to the game, merge them on top of `game-current` one at a time, keeping both sides ([[Rojo Workflow]]).
