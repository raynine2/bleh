---
tags: [code]
---
# Rojo Workflow

**Read this before syncing.** Rojo makes Studio match the files in `src/`. When it syncs, **the files win**: any script that comes from `src/` and was edited only in Studio is overwritten.

| Studio | Files |
|---|---|
| ReplicatedStorage.Tidebound | `src/shared` |
| ServerScriptService.Tidebound | `src/server` |
| StarterPlayer.StarterPlayerScripts | `src/client` |
| ReplicatedFirst | `src/first` (the [[Loading Screen]]) |

New scripts made in Studio inside those folders are kept (`$ignoreUnknownInstances`), but **edits** to scripts from `src/` are replaced.

## Rules
1. Change code in the files, never in Studio.
2. Commit before you pull: `git add -A`, `git commit -m "..."`, `git pull`.
3. One person runs Rojo, and only after checking nobody has unsaved script edits in Studio.
4. **Before connecting, check which branch you're on** (`git branch`). Syncing a branch that doesn't have someone's work replaces it in Studio. That's how the UI went missing: see [[Branches]].
5. Save a backup first: File → Save to File As… → `.rbxl`.

## Commands
```
cd C:\Users\Rayan\Downloads\TideboundEggfall
git fetch
git checkout <branch>
rojo serve
```
Then in Studio: Plugins → Rojo → Connect. Stop with Ctrl+C.
