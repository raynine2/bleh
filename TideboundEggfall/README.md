# Tidebound: Eggfall

Cast. Steal. Hatch. Escape. Core-loop vertical slice built from Design Doc Part A, the Part A Delta, the Master Patch (Patches 1-8), the Big Update and the Canon Sheet.

## What's in this slice

- **Nest** (safe zone, the Spawn Plaza): Tide Egg Shrine (odds and buy), Incubator (hatch), Tackle Shop (rods and bait), Nest Beacon, the Tide Slide to the Harbor Ring, and NPCs Pinch, Old Harl, Sister Coralie and Gate Warden Sel.
- **Sunken Shoals** (biome 1): 5 reefs joined by sandbars, 8 fishing spots, 5 wild egg nests (respawn 45s), 2 extraction beacons, the Tide Cache, 5 Stinging Anemone beds, 3 elite dens, the Reef Warden.
- **Outer Shoals (Big Update)**: 3 more islands on boardwalks: Shipwreck Reef (a wrecked galleon with an egg in its hull), Lighthouse Isle (a sweeping beam and a third beacon) and Maelstrom Isle beside the Maelstrom, the whirlpool PUSH DEEPER drags you down. 5 more fishing spots and 2 more egg nests.
- **Kelp Cathedral (Big Update, biome 2)**: PUSH DEEPER at a Shoals beacon plays the descent and drops you into a sunken cathedral in a cavern 480 studs across: a studded nave between stone pillars and giant kelp, a rose window over the apse, 3 holy-water pools (4 fishing spots, luck x1.3, 12 new fish), 4 ruined chapels and the apse with 5 wild eggs, a whale skeleton, a Tide Cache, 2 beacons, grasping vines (Canon hazard: 40% slower), glowing jellies, fish schools and light shafts. Its guardian, the Kelp Leviathan, hits for 30 with a 0.7 s tell and only hunts divers in the Kelp. The Current at the Descent dais takes you back up. Extracting anywhere lands you back in the Nest.
- **Animation (Big Update)**: every player gets code-driven body motion until the animator's ids arrive: breathing idle with fidgets, a run that leans and strides with your speed, sprint, jump and fall, landing squash, swimming, carrying eggs, grabbing an egg, getting hit, stunned stars, going down, the extraction cheer, and the fishing arms. Voxel effects in the reference video's style: footstep puffs, landing rings, a red "!" over the bobber on a bite, cube splashes and tier-coloured bursts on a catch, guardian telegraph rings that fill before a strike, and roar bursts.
- **Cutscenes (Big Update)**: a first-join flyover, the dive off the dock, a guardian waking (it can't hurt you while it plays), the descent and the ascent, extraction (a column of light, then a tally) and a wipe. Each one can be skipped once you've arrived.
- **Diving (Master Patch 1)**: talk to Gate Warden Sel (DIVE tab) and pick DIVE SOLO (x1.15 Pearls) or DIVE WITH CREW (+5% per extra member, up to 4, invite only). Walking out of the Nest also starts a solo dive. Canon caps hold: 120 Pearls per fish, 400 per run payout. Solo and Crew dives have separate leaderboards.
- **Contested Waters (opt-in PvP)**: OFF by default, set per dive, back to OFF after it. When ON, a rival behind you can hold 1 s to snatch one carried egg; never within 40 studs of a beacon; the victim gets 5 s immunity and a speed burst. Egg nests can hold a bonus egg (x1.20). Crewmates never snatch from each other.
- **Companions**: pick 2 hatched creatures in the DIVE tab. They follow you, and each awake one carries an egg so it doesn't slow you. A Reef Warden hit knocks one out for 10 min (or use a Revive Vial).
- **Fishing minigame**: hold click or touch to push the reel bar and keep the fish inside it. Rod Control widens the bar, Resilience slows progress loss, Lure Speed shortens the bite, Luck and bait raise Rare+ odds. Perfect catches pay +20%. A fish that escapes after passing 90% drops a Lucky Scale (+25 Pearls).
- **Rod animation (Master Patch 5)**: every cast plays the 10 steps of the rod table on every player's screen: windup, release (with the rod's trail, cast effect and a +4 FOV kick), landing, idle sway, the bite tell, the hook set, the struggle (the rod bends 0.6 to 0.9 with the fish's pull and the screen shakes harder for rarer fish), the snap and the landing flip into your hands. Until the animator's ids are pasted into `Animations.luau`, code poses the arms and bends the rod; the line is a spring that whips, sags and snaps taut.
- **Fish reveal (Master Patch 6)**: every catch plays a 2.8 to 4.6 s reveal: the world drains to 20% colour, the camera swings to a 45-degree side view, a silhouette climbs the tiers 0.3 s at a time, then a name card shows the biome, fish, tier, stars, mutation and weight. Epic+ adds confetti, Legendary+ a shockwave and camera pull-back, Mythic+ aurora and NPCs turning to look, and a Celestial is announced to the whole server. On 40% of catches below Celestial the climb overshoots one tier and drains back (fish only, never eggs, set by `Config.Reveal.nearMissChance`). Fish roll the egg mutation table (shown on the BAIT tab too), which multiplies Pearls inside the 120 cap. Click or tap after the silhouette to skip to the card. Nothing can hurt you while it plays.
- **Rods you can see (Master Patch 7)**: each of the 6 rods has its own model, glow, line colour, trail, cast effect and bobber. Your rod rides on your back everywhere and moves to your hand when you cast; your Rod Workshop rack shows every rod you own. Sound cues are listed in `Audio.luau` with empty ids, ready for the sound designer.
- **Rod durability (Master Patch 2)**: 100 per rod, -1 per cast, -10 when a fish snaps the line. A broken rod fishes like a Drift Rod until Old Harl repairs it for Pearls (RODS tab).
- **Heat 0-100**: +2 per fish, +8 per steal, -1 per 3s while lying low. 25 Warden patrols, 50 riptide (a 6 s pull toward open water every 20 s), 75 Warden locks on, 100 every beacon closes for 30s (10 s grace if you're within 10 studs of one).
- **Risk (Master Patch 2)**: 100 health, healed between dives. The Reef Warden hits for 25, knocks your newest egg back to its shrine and knocks out a companion. Fish are cargo until you bank them at the Tide Cache; a wipe loses 100% of unbanked cargo. Wiping at heat 75+ starts your next dive at heat 15 until you rest 3 min at your Home Nest. Each carried egg costs 2 WalkSpeed; Shift (or SPRINT on touch) adds 6. Mending Vials heal 25 (Nim, Pearls only, 3 vials per dive).
- **Reef Warden (Master Patch 3)**: Phase 1 on your 3rd stolen egg (it guards the exit), Phase 2 at heat 75 (it chases; 6 s out of sight drops it back), Phase 3 at heat 100 (faster). Every strike has a 0.6 s wind-up. Escaping Phase 3 earns a Reef Core.
- **Shoals threats (Master Patch 3)**: Barnacle Brutes rattle, then charge (a hit stuns 1.5 s); Snapjaw Morays lunge from glowing holes (10 damage). Both can be looted for bait while dazed. Anemone beds sting for 10 and slow you. Glass Calm weather every 15 min: bites 30% faster, no riptide, first catch +3 Brineworm.
- **Extraction and the Greed Window (Master Patch 2)**: hold 3 s at a beacon, then choose within 10 s: EXTRACT NOW, or PUSH DEEPER for +40% cargo, +25 heat and an angrier Warden, then extract at a different beacon. No answer extracts. Payout is 50 + 30 per egg (cap 400), plus fish Pearls and 5-25 Run Embers. Clean Extraction streak adds up to +3 Embers.
- **Harbor Ring hub (Delta Section 8)**: a ring town around a swimmable lagoon south of the Nest (reach it by the Tide Slide). Lagoon pier fishing (no Heat, half Pearls, banked at once), Daily Quest Board (Quill), Season Track board (Captain Brask), Leaderboard Hall (Archivist Ophel), Bait Shop (Nim), Trading Post (Tradesman Kobb), Social Plaza with stage, photo spot and heist board.
- **Home Nest plots (Delta Section 7)**: 8 plots of 120 x 120 around the Harbor Ring, one per player. Hatch Chamber, Aquarium Hall, Rod Workshop, Trophy Room and Prestige Altar (the 5 rooms), plus Creature Pen, Nest Vault and Visitor Deck outdoors. Zone unlocks and 7 upgrade tracks (incubator slots, aquarium capacity, Tank Filter, treadmill, pen size, trophy pedestals, vault capacity) on the HOME tab. Creatures swim in the tank, roam the pen, stand on trophy pedestals and on the Showcase Plinth. Visitors (Public / Friends / Private) appear in the guestbook and can Admire the showcase for +1 Egg Shard to the owner (10 per day). Nothing in a base can be stolen.
- **Tide Egg gacha**: canon 7-tier odds, independent mutation roll, pity at 25/90/300/1200 per egg type, last-10 pull history, confirm modal with odds before every purchase. Hatch one egg per incubator slot at once. Shards 1 per new creature, 10 per duplicate.
- **Economy (Delta Section 11)**: aquarium income (1% of value per minute for the earning creatures, plus filter, trophy and fed bonuses), offline income at 50% for up to 8 h, duplicate sales at 50% value, 3 daily quests (300-800 Pearls), run payout and Greed pushes, Lucky Scales and pier fishing. Sinks: rods, repairs, bait, vials, eggs, zone unlocks and upgrades.
- **Feel (Delta Section 10)**: camera FOV per situation (70 explore, 65 fishing, 80 chase, 55 hatch), screen-edge tint by Heat, hit shake and flash, extraction flash, big call-outs for every strike tell and Warden phase. `src/shared/Animations.luau` lists every animation from Table A with an empty id: paste the animator's asset ids there and they play on their triggers.
- **Saves** via DataStore (`TideboundEggfall_v1`). Run state is never saved.

Robux sells nothing in this slice; eggs, odds, pity, upgrades and power are all reachable by free play.

## Layout (Rojo)

| Path | Studio location |
| --- | --- |
| `src/shared/Config.luau` | `ReplicatedStorage.Tidebound.Config` (all canon values) |
| `src/shared/Gacha.luau` | `ReplicatedStorage.Tidebound.Gacha` (roll and pity math) |
| `src/server/Main.server.luau` | `ServerScriptService.Tidebound.Main` |
| `src/server/PlayerData.luau` | `ServerScriptService.Tidebound.PlayerData` |
| `src/server/WorldBuilder.luau` | `ServerScriptService.Tidebound.WorldBuilder` (builds the map if `Workspace.TideboundWorld` is missing) |
| `src/server/ExpansionBuilder.luau` | `ServerScriptService.Tidebound.ExpansionBuilder` (adds `TideboundWorld.Delta`: Harbor Ring, plots, Nest NPCs) |
| `src/server/BaseService.luau` | `ServerScriptService.Tidebound.BaseService` (plots, upgrades, income, visitors, boards) |
| `src/server/PlotLayout.luau` | `ServerScriptService.Tidebound.PlotLayout` (where each zone sits in a plot) |
| `src/server/Crew.luau` | `ServerScriptService.Tidebound.Crew` (invites and Crews) |
| `src/server/Companions.luau` | `ServerScriptService.Tidebound.Companions` (companion slots, knock-outs) |
| `src/server/Threats.luau` | `ServerScriptService.Tidebound.Threats` (elites, anemone beds, Glass Calm) |
| `src/shared/Animations.luau` | `ReplicatedStorage.Tidebound.Animations` (animation handoff list) |
| `src/shared/CreatureModels.luau` | `ReplicatedStorage.Tidebound.CreatureModels` (placeholder voxel creatures) |
| `src/shared/RodModels.luau` | `ReplicatedStorage.Tidebound.RodModels` (the 6 rods and their bobbers) |
| `src/shared/FishModels.luau` | `ReplicatedStorage.Tidebound.FishModels` (placeholder fish for the flip and the reveal) |
| `src/shared/FishingFeel.luau` | `ReplicatedStorage.Tidebound.FishingFeel` (links the reel minigame to the rod animation) |
| `src/shared/Audio.luau` | `ReplicatedStorage.Tidebound.Audio` (sound cue list) |
| `src/server/Rods.luau` | `ServerScriptService.Tidebound.Rods` (puts your rod on your back or in your hand) |
| `src/client/TideboundRod.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundRod` (rod poses, bend, line, bobber and effects) |
| `src/client/TideboundCreatures.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundCreatures` (tank, pen and companion motion) |
| `src/client/TideboundClient.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundClient` |
| `src/server/DescentBuilder.luau` | `ServerScriptService.Tidebound.DescentBuilder` (adds `TideboundWorld.Descent`: Outer Shoals and Kelp Cathedral) |
| `src/shared/MotionBus.luau` | `ReplicatedStorage.Tidebound.MotionBus` (how client scripts share the body joints) |
| `src/shared/Fx.luau` | `ReplicatedStorage.Tidebound.Fx` (voxel cube bursts, rings, bolts, stars, alerts) |
| `src/client/TideboundMotion.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundMotion` (every player's body motion) |
| `src/client/TideboundFX.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundFX` (moving world: lighthouse, Maelstrom, jellies, fish schools, the Leviathan's body, telegraphs) |
| `src/client/TideboundCutscenes.client.luau` | `StarterPlayer.StarterPlayerScripts.TideboundCutscenes` (the cutscenes) |

Sync with `rojo serve` (from this folder or the repo root) and the Rojo Studio plugin, or paste each file into the matching script. The Delta and Big Update areas build into their own folders, so the existing Nest and Shoals are left exactly as they are.

## Not built yet

Biomes 3-5 and their guardians (so the Prestige Altar stays locked, and a push inside Kelp Cathedral keeps you there), run modifiers, co-op heists, cosmetics and the Trading Post window, the season track, Shard Eggs, incubator timers (and so Heat Lamps and hatch rush), Feeding Trough, Rod Rack, Bait Locker, Visitor slots, prestige, real animations and audio (the hooks are in `Animations.luau` and `Audio.luau`), and the three "prior" Patch 8 fixes (the scale patch, the 600 x 600 plot and the hex lock), which have no spec yet.
