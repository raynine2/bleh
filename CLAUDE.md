# Tidebound: Eggfall: rules for Claude

A Roblox game built with Rojo. The code is in `TideboundEggfall/src` and the docs vault is in `TideboundEggfall/vault`
(start at `Home.md`). Two people work on it, each with their own Claude sessions, in a shared Team Create
Studio. **Losing someone's work is the worst thing that can happen here. It has already happened twice.**

## Never lose a teammate's work

1. **Read the TEAM SAFETY CHECK** that the session start hook prints. It lists branches with recent work that
   isn't on your branch. If a file you're about to change is on that list, tell the user and ask whether to
   merge that branch in first. Never quietly build on an old copy.
2. **Never revert, reset or overwrite.** No `git reset --hard`, `git push --force`, `git checkout -- <file>`,
   `git restore`, `git stash drop` or `git clean`. Never copy an older version of a file over a newer one, and
   never "revert" or "undo" a change without the user naming exactly which change. If something has to be
   undone, use a new commit (`git revert <commit>`) and say what it removes.
3. **Merge, don't replace.** When combining branches, use `git merge`. In a conflict, keep both sides' features.
   If you can't tell how to keep both, stop and ask. Merging a teammate's branch counts as touching their work:
   ask the user first.
4. **Edit, don't rewrite.** Change the lines you need. Don't regenerate or re-paste whole files, which is how
   other people's additions get dropped. Before editing a shared file (`TideboundClient`, `Main`, `Config`,
   `PlayerData`, `Audio`, `HatchScene`, `WorldBuilder`), check `git log -3 -- <file>` for recent work by others.
5. **Rojo overwrites Studio.** When the user connects Rojo, the files replace any script that comes from `src/`.
   Before telling the user to sync, confirm the branch they'll sync has all of their and their teammate's
   recent work (compare it with the other branches), and tell them to save a backup first (File → Save to
   File As → `.rbxl`). Never say "it's safe to sync" without checking.
6. **Commit and push often** to the branch you were given, with clear messages, so nothing exists only in the
   container. Don't open a pull request unless asked.

## Talking to the user

The user isn't a git expert and works on Windows in `C:\Users\Rayan\Downloads\TideboundEggfall`. Give exact
PowerShell commands, explain what each one does in plain words, and say clearly whether a step can lose
anything.

## Checks before every commit

```bash
lune run tools/compile-check.luau $(find TideboundEggfall/src -name "*.luau")   # syntax and the 200-local limit
cd TideboundEggfall && rojo build default.project.json -o /tmp/test.rbxlx       # the project builds
```

The session start hook installs `rojo` and `lune` in cloud sessions.

## Code notes

- Rojo mapping: `src/shared` → ReplicatedStorage.Tidebound, `src/server` → ServerScriptService.Tidebound,
  `src/client` → StarterPlayerScripts, `src/first` → ReplicatedFirst. All four keep unknown Studio instances
  (`$ignoreUnknownInstances`).
- `game-current` is the live game, saved from Studio. The Superbullet plugin's scripts and
  `ServerStorage.TideboundBackups` live only in Studio on purpose; don't add them to `src/`.
- `TideboundClient`'s main chunk is right at Luau's 200-local limit. Put new code inside `do ... end` blocks
  with its state in one table, or the whole UI breaks.
- Builders (`TownBuilder`, `ExpansionBuilder`, `ShoalsBuilder`, ...) only rebuild when their `VERSION` changes.
  Bump it when you change what they build.
- Studio-only test helpers stay behind `RunService:IsStudio()`.
- Use original names for anime-inspired content.
- The fish creature names in `Config.Tiers` (LuffyFish, PikachuFish...) are placeholders the team will change
  themselves. Don't rename them and don't raise them as an issue.
