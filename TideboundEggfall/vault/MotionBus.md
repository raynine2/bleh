---
tags: [code]
---
# MotionBus

`MotionBus.luau`: how client scripts share a character's joints and some state. `TideboundMotion` owns every joint write; others publish here and Motion layers it.

- `arms`, `pose`, `launch`, `dash`, `skill`, `tired`: body poses from fishing, cutscenes, geysers, [[Dashes]], [[Rod Abilities]]
- `kick`: a field-of-view punch
- `stamina`: shared [[Stamina and Sprint]]
- `cutscene`: true while a cutscene owns the camera
- `dialogue`, `openPanel`: the [[Dialogue Box]] (Patch 23)
