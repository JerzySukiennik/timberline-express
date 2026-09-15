# Audio manifest — Timberline Express

111 files, all Ogg Vorbis at 44.1 kHz, about 7.4 MB in total. Every file is a real recording.
Sources and licenses are in `../CREDITS.md`.

Processing:
- Every file is cut from the source and has its DC offset removed.
- One-shots start at the first transient (2 ms pre-roll) and have their silent tail trimmed.
- Each file is peak-normalized to −1 dBFS and encoded with `oggenc -q 4` (music uses `-q 3`).
- Loops (`*_loop`) use an equal-power crossfade of the tail onto the head, so the file loops without a click.

Everything is mono except `amb_forest_day_loop`, `music_calm_1` and `music_calm_2`, which are stereo.

Because each file is normalized on its own peak, relative loudness is **not** preserved. Balance levels in the game mixer.

## Player movement

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| footstep_grass_1..5 | 0.59–0.77 | Kenney Foley steps on grass | — |
| footstep_gravel_1..5 | 0.48–0.50 | Single shoe steps on gravel (BSB s0085) | Garden gravel, not coarse ballast |
| footstep_wood_1..5 | 0.25–0.42 | Person walking on an outdoor wooden pontoon deck (BSB s1845) | — |
| footstep_metal_1..5 | 0.49–0.65 | Kenney "impactPlate_light": light hits on a metal plate | **No real boot-on-steel-plate recording was found under CC0 or CC BY.** These are plate impacts, which read as steps on a steel deck. |
| land_soft_1..2 | 0.59–0.61 | Human jump landing, feet together, on grass | — |
| land_hard_1..2 | 0.14 / 0.53 | Jump landing on concrete | `_1` is very short and dry |
| jump_cloth_1..2, crouch_cloth_1..2 | 0.37–0.57 | Kenney cloth-rustle Foley | — |
| breath_exhausted_1..2 | 2.85 / 2.90 | A man out of breath after exercise, 2 breath cycles each | Cut at breath gaps, 30–60 ms fades |

## Tools

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| equip_pickaxe_1 / equip_axe_1 | 0.25 / 0.37 | Kenney "beltHandle": leather belt and buckle handling | Generic gear handling, not an actual pickaxe or axe |
| equip_knife_1 | 0.29 | Kenney "drawKnife3": blade drawn from a sheath | — |
| equip_hand_1 | 0.59 | Kenney cloth/belt rustle | — |
| swing_heavy_1..3 | 0.42–0.47 | Real whooshes of a metal tube (×2) and a long rope | — |
| swing_light_1..3 | 0.18–0.27 | Real whooshes of a wooden stick, a bamboo stick and a wooden sheet | — |
| pickaxe_hit_rock_1..4 | 0.57–0.65 | Kenney "impactMining": pick striking rock, with a metallic ring | — |
| rock_crack_1..3 | 0.45–0.84 | Stone breaking and cracking Foley (OGA, rubberduck) | The author doesn't say how the sounds were made. Spectra look like real recordings with hard noise-gating. |
| rock_debris_1 | 2.57 | Wheelbarrow of limestone gravel tipped over | — |
| rock_debris_2 | 1.34 | 1–3 kg stones dropped onto a stone pile | — |
| axe_chop_wood_1..4 | 1.18–1.39 | Axe blows into a large tree trunk | — |
| tree_creak_1 | 3.01 | A big tree in wind with one branch grinding and creaking | Wind noise underneath. It is a branch creak, not a trunk cracking before a fall. |
| tree_fall_1 | 4.30 | A real tree falling after a chainsaw cut: crack, crash through branches, impact | **The chainsaw idles quietly in the background (~15 dB down) for the whole clip.** |
| knife_cut_foliage_1..3 | 0.61–0.89 | Kenney knife-slice Foley **layered** with real dry-leaf/bush rustles (qubodup) | Two real recordings mixed, since no single knife-through-bush recording was found |
| pickup_item_1..3 | 0.23–0.69 | Kenney leather and cloth handling | — |
| tool_hit_miss_1..2 | 0.86 / 0.38 | Shovel digging into soil | `_2` is quiet and short |

## Inventory / UI

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| backpack_open_1 / backpack_close_1 | 0.95 / 0.66 | Jacket (K-way) zipper: a fast pull, then a very fast pull | Zipper stands in for the backpack |
| slot_pick_1 | 0.40 | Kenney book page flip (short paper/leather flick) | — |
| slot_drop_1 | 0.33 | Kenney leather item dropped | — |
| ui_click_1 | 0.39 | Kenney recorded metal click | — |
| crate_open_1 | 0.60 | Kenney wood creak | — |
| crate_close_1 | 0.44 | Kenney wooden plank impact | — |

## Handcar

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| handcar_pump_1..3 | 0.45–0.67 | Squeaks of an iron hand-brake lever on a horse trailer | **A different squeaky iron lever, not a handcar.** The one real handcar recording has lever and wheels mixed together. |
| rail_roll_loop | 15.00 | A real **hand-lever rail trolley (handcar)** rolling on track, Bochum Railway Museum (WWS) | The lever mechanism is audible in the mix, and there is a bit of wheel squeal |
| rail_clack_1..3 | 0.60–0.65 | Double "clack-clack" at rail joints from a mine battery locomotive (WWS) | High-passed at 350 Hz. Some wheel and motor rumble stays underneath. |
| brake_squeal_loop | 4.25 | A real bicycle brake squeal (2 takes), strung together and looped | **Bike brake, not a rail brake.** A 4 s loop built from two sustained squeals, one played in reverse. Pitch it down for heavier metal. |
| lever_clunk_1..2 | 0.49 / 0.61 | Car handbrake pulled: ratchet and clunk | Car handbrake stands in for a heavy iron lever |
| buffer_hit_1 | 2.06 | A large metal barn barrier slammed shut | — |
| switch_throw_1 | 1.02 | A heavy metal barrier sliding and grinding open | Metal-on-metal slide stands in for switch points. There is no lever clunk, so layer `lever_clunk_1` in code. |

## Steam locomotive

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| steam_chuff_1..4 | 1.25 | Individual steam blasts from a real steam locomotive starting off (Martel, France) | Long, soft puffs (cylinder cocks open), not sharp chuffs. Shorten or pitch up for running speed. |
| steam_idle_loop | 6.75 | Rhythmic air pump of a stationary Prussian P-8 steam locomotive (WWS) | The classic sound of an idling loco, but a pump rather than pure boiler hiss. Loop length is 10 pump cycles. |
| safety_valve_loop | 12.00 | Continuous full-pressure steam release from steam locomotive 06-018 (WWS) | — |
| steam_whistle_1 | 3.45 | Real steam train whistle (Martel tourist railway), a long blast then short toots | — |
| firebox_door_open_1 | 1.10 | A metal gate door creaking open | Gate hinge stands in for the firebox door |
| firebox_door_close_1 | 0.74 | A large metal bin lid closing | Metal lid stands in for the firebox door |
| fire_roar_loop | 15.00 | Fire in a log-fed wood boiler | Quiet and steady with one louder crackle |
| coal_shovel_1..2 | 1.20 / 1.06 | Shovel scooping limestone gravel into a wheelbarrow | Limestone, not coal |
| wood_toss_fire_1..2 | 0.31 | Kenney heavy wood impact | Short wood thump, with no fire in the recording |
| water_pour_tank_1 | 6.00 | A tap gushing into a sink as it fills | Tap, not a bucket |
| bucket_fill_1 | 6.00 | A hand pump filling a metal bucket | Pump strokes are audible |
| pressure_release_1 | 1.65 | Steam hiss from a steam locomotive stopping | — |

## Electric locomotive

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| electric_motor_loop | 14.00 | A 60 kW mine battery locomotive running at steady speed (traction motor and wheels, WWS) | More rumble than whine. Pitch is steady, so pitch-shifting works. |
| breaker_switch_1 | 1.50 | A main electrical circuit breaker tripping | A chunky click rather than a huge knife switch |
| generator_start_1 / generator_loop / generator_stop_1 | 3.00 / 12.00 / 3.00 | A 1 kW petrol generator: start, running, stop (one recording) | — |
| electric_horn_1 | 1.74 | A powerful train horn | — |
| electric_hum_loop | 10.00 | High-voltage transformer hum | — |
| fuel_pour_1 | 5.00 | Liquid poured and flowing onto soil | Pour onto ground, not into a canister, so there is no glugging |

## Ambience / music

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| amb_forest_day_loop | 44.50 (stereo) | Forest ambience with dense birdsong and light wind (France) | A European mixed forest, not specifically mountain pines. 2 s loop crossfade. |
| amb_wind_pines_loop | 35.00 (mono) | Gusts of wind in a large tree, with a little birdsong | Mono source. The tree species is unknown. |
| music_calm_1 | 166.10 (stereo) | "Romance Anónimo" (Spanish Romance), solo classical guitar, performed by Jim Greeninger (Musopen) | — |
| music_calm_2 | 161.48 (stereo) | J.S. Bach, Prelude No. 1 in C major BWV 846, solo piano, Kimiko Ishizaka | — |
