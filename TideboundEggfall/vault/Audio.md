---
tags: [code]
---
# Audio

- **`TideboundAudio`:** the audio director. Mix buses with ducking, adaptive music (Calm, Menu, Hunt, Heist, Extract, Reveal, Boss, Wipe) with crossfades and stingers, the 5 biome ambience beds ([[Biomes]]), the gacha stages ([[Hatch Scene]]), creature vocals, weather sounds, and a heartbeat that climbs with [[Heat]].
- **`Soundtrack.luau`:** which sound plays for each state: Roblox-licensed library tracks as stand-ins. Paste a new id over any of them.
- **`Audio.luau`:** one-shot sound cues. Paste an uploaded sound's id into a cue's `id`; empty ids play nothing.
- Scripts ask for music through `ClientBus`.
