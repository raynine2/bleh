---
tags: [skills]
---
# Rod Abilities

Every rod has one ability on **R** (Y on a gamepad, SKILL on touch), added in Patch 21. A pill above the stamina bar shows it and its cooldown. Inspired by anime moves, with original names.

| Ability | Rod | Cooldown | Type | What it does |
|---|---|---|---|---|
| Tide Lash | [[Drift Rod]] | 6 s | quick | Whip a curling wave forward. |
| Coral Bloom | [[Coral Rod]] | 7 s | quick | Stab the rod down; coral spikes erupt in a ring. |
| Thunder Hook | [[Stormline Rod]] | 8 s | quick | Three lightning strikes march out ahead. |
| Abyss Maw | [[Abyssal Rod]] | 9 s | quick | A vortex drags mobs in, then shadow jaws snap shut. |
| Rift Slash | [[Riftcaster]] | 9 s | quick | Three slashes tear space open, then it shatters. |
| Starfall | [[Celestial Rod]] | 10 s | quick | Stars rain down all around. |
| Crimson Illusion | [[Crimson Crow Rod]] | 14 s | ultimate | A crimson spiral eye opens; a storm of crows; everything nearby is frozen. |
| Jackpot Rush | [[Jackpot Rod]] | 15 s | ultimate | The reels spin; on a jackpot you're healed and untouchable for a while. |
| Stolen Page | [[Thief's Tome Rod]] | 12 s | ultimate | The book flips to a stolen page and casts another rod's ability. |
| Sun God Bounce | [[Sun Rubber Rod]] | 14 s | ultimate | Drums, cartoon clouds and white flames, then a giant stretching rubber fist. |
| Boundless Void | [[Boundless Rod]] | 25 s | ultimate | A dome of endless void; red and blue merge into a violet core that's fired. |

- **Quick abilities** (the six shop [[Rods]]) cast at once with a caption.
- **Ultimates** (the five trial rods from [[Rod Trials]]) open with a short cinematic first. Boundless Void and Sun God Bounce were remade as real 3D effects in Patch 22.
- **How it works:** the server checks the cooldown and lands the hit (`Mobs.area`); `TideboundSkills` plays the effects for everyone; `TideboundMotion` poses you ([[MotionBus]]). Data in `RodSkills.luau`.
- Hits [[Mobs]]. Works alongside the [[Rod Combo]] and [[Dashes]].
