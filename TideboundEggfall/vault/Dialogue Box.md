---
tags: [npc, ui]
---
# Dialogue Box

Patch 23 (`TideboundDialogue.client.luau`), copied from *Catch a Brainrot*: a white rounded box at the bottom of the screen with the NPC's name on a coloured tag and their role on the right. Lines type out letter by letter in a pixel font with a little blip, and a bobbing red ▼ shows when a line is done.

- **Next line / skip typing:** click, tap, E, Space or Enter.
- **Close:** Escape, or walk away (more than 22 studs).
- After the last line the NPC's menu tab opens through `MotionBus.openPanel` ([[MotionBus]]).

Used by every one of the [[NPCs]].
