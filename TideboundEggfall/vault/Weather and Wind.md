---
tags: [world]
---
# Weather and Wind

`WindService` (server) owns the weather (**Clear**, **Rain** or **Storm**) and each biome's wind, with slow gusts and cosmetic lightning strikes. `TideboundWeather` (client) leans every wind-affected particle with the biome you're in and keeps a box of biome particles round the camera: rain, sea spray, leaves, bubbles, sand, spores, fog, plankton, ash, embers. `TideboundWind` draws wind-line trails and sways foliage. Glass Calm weather from [[Mobs|Threats]] still makes bites faster. See [[Biomes]].
