# Audio manifest — Timberline Express

242 files (111 in batch 1 + 131 in batch 2), all Ogg Vorbis at 44.1 kHz, about 13 MB in total. Every file is a real recording.
Sources and licenses are in `../CREDITS.md`.

Processing:
- Every file is cut from the source and has its DC offset removed.
- One-shots start at the first transient (2 ms pre-roll) and have their silent tail trimmed.
- Each file is peak-normalized to −1 dBFS and encoded with `oggenc -q 4` (music uses `-q 3`).
- Loops (`*_loop`) use an equal-power crossfade of the tail onto the head, so the file loops without a click.

Everything is mono except `amb_forest_day_loop`, `night_forest_loop`, `morning_birds_loop`, `music_calm_1` and `music_calm_2`, which are stereo.

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


## Survival (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| eat_crunch_1..3 | 0.85–1.01 | Bite into a green apple (×2) and a raw carrot | Apple/carrot rather than berries |
| eat_meat_1..2 | 2.55–2.55 | A man chewing food with his mouth open | Generic wet chewing; the food isn't meat |
| drink_gulp_1..3 | 0.84–0.95 | Single swallows while drinking from a flask | Quiet, some mouth noise |
| hurt_male_1..4 | 0.50–0.69 | Short male pain grunts, voice recordings (EmoPreben) | Acted |
| death_male_1 | 2.21 | Long acted male dying groan | Acted |
| heartbeat_loop | 9.86 | Slow real heartbeat, 12 beats cut on the beat period (~73 bpm) | Very quiet between beats; raise in mixer |
| stomach_growl_1..2 | 2.25–3.30 | Real stomach gurgles | — |
| berries_pick_1..3 | 0.83–1.83 | **Layered**: dry-leaf/bush rustle + twigs snapped by hand in a forest | No real berry-picking recording found; rustle + snap stands in for pluck |
| splash_water_1..3 | 1.10–2.32 | Small stones thrown into a pond (×2), a big stone into a water tank | — |
| footstep_water_1..4 | 0.76–0.77 | Walking shoes through shallow water after a storm | Shallow puddles, not knee-deep |
| bucket_fill_pond_1 | 2.58 | Hand sloshing through bathtub water | No bucket-dipping recording found; slosh only, no bucket clank |

## Fire & crafting (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| campfire_loop | 22.00 | A big branch fire crackling outdoors | Soft-limited before normalizing (one huge pop dominated the peak) |
| fire_ignite_1 | 3.22 | 350 ml of gasoline catching fire (whoomph + burn) | Bigger than a campfire lighting |
| cooking_sizzle_loop | 10.00 | Steak frying in hot oil | — |
| furnace_loop | 9.00 | Blacksmith forge blower roaring through the coals (WWS, CC BY) | Blower roar more than flame roar |
| craft_wood_1..3 | 0.72–1.01 | Wheelwright chisel-and-mallet hits into wood (WWS, CC BY) | Chiseling, not sawing/whittling |
| craft_stone_1..3 | 0.57–0.70 | Single 1–3 kg stones dropped on a stone pile | **Not knapping** — stone-on-stone clacks; same source as rock_debris_2 (different hits) |
| craft_metal_1..3 | 1.01–1.05 | Blacksmith hammer strikes on an anvil | — |
| craft_rope_1 | 1.12 | Rope sliding through hands | — |
| craft_rope_2 | 1.75 | Rope handling/tension noise | — |
| craft_complete_1 | 0.31 | Kenney heavy wooden thud | — |

## Building (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| build_place_wood_1..3 | 0.42–0.44 | Kenney wooden plank impacts | Placed, not nailed |
| build_place_metal_1..2 | 0.20–0.36 | Kenney heavy metal impacts | — |
| build_remove_1..2 | 0.21–0.36 | Wood cracking / wood squeak (rubberduck) | Short; no crowbar prying recording found |
| hammer_hit_1..3 | 0.55–0.55 | Nail hammered into a wooden board | — |
| saw_wood_1..2 | 3.05–3.57 | Hand saw cutting wood, ~6 strokes each | — |
| door_wood_open_1 | 2.84 | Creaking wooden door opening | — |
| door_wood_close_1 | 2.54 | Heavy wooden barn door closing | — |
| chest_open_1 | 1.55 | Creaking wooden closet door | Closet door stands in for a chest lid |
| bed_creak_1 | 0.76 | Single creak of an oak floor | Floor creak, not a bed frame |

## Animals (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| deer_call_1..2 | 3.65–7.25 | Bull elk bugling, Yellowstone (NPS) | Elk (wapiti), not roe/red deer |
| deer_flee_1 | 8.05 | Horse galloping past through tall grass | **Horse**, not deer; fades in/out |
| hooves_run_loop | 20.00 | Horse galloping in tall grass | Horse, not deer |
| boar_grunt_1..3 | 0.65–0.91 | Real farm pig grunt (erdie, CC BY 3.0) | **Domestic pig.** Only one grunt exists: `_2` and `_3` are the same grunt pitched down (−3 and −6 semitones) |
| boar_squeal_1 | 1.42 | Real piglet squeal (Foleyhaven) | Piglet, higher than an adult boar |
| rabbit_squeak_1 | 0.83 | Pet rabbit oink/squeak | Contented grunt-squeak, not a distress scream |
| wolf_howl_1 | 9.05 | Wolf chorus howling (USFWS) | Several wolves |
| wolf_howl_2 | 10.05 | Wolves howling near houses in Yellowstone, winter (NPS) | Wind noise; fades in/out |
| wolf_howl_3 | 10.05 | Captive wolf pack howling (Wolfcenter Dörverden) | Several wolves; fades in/out |
| wolf_growl_1 | 2.10 | Large dog growl (research sample, CC BY 2.5) | **Dog**, not wolf |
| wolf_growl_2 | 0.61 | Dog growling (bonebrah) | **Dog**, not wolf; phone recording |
| wolf_bark_attack_1..2 | 0.67–0.71 | Big dog barking at 2 m; sled dog barking | **Dogs**, not wolves |
| wolf_whimper_death_1 | 2.45 | A dog crying/whining | **Dog**; quiet source, noise floor raised by normalization |
| bear_roar_1..2 | 5.55–6.55 | Two grizzly bears roaring at each other over a bison carcass (NPS) | Some background ambience |
| bear_growl_1 | 3.60 | Trapped grizzly huffing and low growl, phone recording (NPS/Dan Bergum) | Lo-fi |
| bear_growl_2 | 1.17 | Bear growl (USFWS) | — |
| animal_hit_flesh_1 | 0.78 | Gore Foley: grapefruit struck | Foley, not real flesh |
| animal_hit_flesh_2 | 0.44 | Kenney heavy punch impact | — |
| animal_hit_flesh_3 | 1.20 | Wet squish impact (Independent.nu) | — |
| animal_body_fall_1..2 | 0.85–1.29 | Human body falling on a tiled floor | Indoor tiles, human weight |
| paws_run_1..3 | 0.85–0.85 | 2–3 quick human running steps in tall grass | **No real animal paw-running recording found (CC0/CC BY).** Human steps in grass |

## Weapons (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| bow_draw_1..2 | 2.05–2.55 | Real English longbow / Scythian recurve being drawn (Still North Media) | — |
| bow_release_1..2 | 0.66–0.79 | Longbow / recurve shot (string release) | — |
| arrow_whoosh_1..2 | 0.56–0.65 | Arrow passing the microphone (normal / heavy arrow) | — |
| arrow_hit_wood_1..2 | 0.50–0.50 | Arrow hitting a straw target | Straw target, not wood |
| arrow_hit_flesh_1 | 0.94 | Wet squish impact | Foley |
| arrow_hit_flesh_2 | 1.42 | Gore Foley: grapefruit | Foley |
| spear_throw_1 | 0.65 | Real spear swung through the air | Swing, not a throw |
| spear_stab_1 | 0.61 | Sword cutting something soft (Foley) | — |
| spear_stab_2 | 1.63 | Gore Foley: grapefruit pierced | — |

## Weather & time (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| rain_loop | 20.00 | Heavy rain (France) | Garden/terrace rain, not specifically forest |
| rain_on_roof_loop | 20.00 | Rain drops on a car roof recorded from inside | Car roof stands in for a metal roof |
| thunder_1 | 4.08 | Short close thunderclap | — |
| thunder_2 | 10.02 | Close thunderclap with rumble | — |
| thunder_3 | 12.01 | Long rolling thunder | — |
| thunder_4 | 17.90 | Very long distant rolling thunder | — |
| wind_strong_loop | 20.00 | Strong storm wind in trees | — |
| blizzard_loop | 20.00 | Wind whistling in a chimney | **No snow in it** — howling wind only |
| night_forest_loop | 28.00 | Meadow at night, field crickets and a few frogs (stereo) | Meadow, not forest; no owls (use owl_hoot on top) |
| owl_hoot_1..2 | 6.34–6.40 | Tawny owl song, 2 phrases each | ~4 s silence between phrases |
| morning_birds_loop | 28.00 | Countryside dawn chorus at 6:45, April (stereo) | Farmland birds |

## Rails & damage (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| boiler_explosion_1 | 3.42 | **Layered real recordings**: festival explosion (Fg2) + gas-cannon bang at 10 m + steel scrap crash + steam hiss | No real large-explosion recording under CC0/CC BY was found; this is a mix of 4 real recordings |
| steam_burst_1 | 3.05 | Pressure cooker steam jet | Smaller vessel than a locomotive |
| steam_burst_2 | 6.54 | Steam locomotive hiss | — |
| metal_crash_1..2 | 1.30–1.42 | Two sheet-steel bars falling on a path | Medium weight |
| metal_crash_2 | 2.25 | Grab bucket dropping steel scrap (WWS, CC BY) | — |
| wood_crash_1 | 3.55 | Truck tipping a load of logs | Logs falling, not a structure breaking |
| wood_crash_2 | 0.40 | Wood breaking (rubberduck) | Short |
| coupling_clank_1..2 | 1.25–1.55 | Heavy / medium chain being moved | **Chains, not train couplers** |
| plow_impact_1..2 | 2.25–3.55 | Steel scrap loaded / tipped from a truck: crash + scraping (WWS, CC BY) | Scrap metal, not a vehicle hitting debris |
| rail_repair_1..2 | 0.55–0.73 | Two blacksmiths' sledgehammers on hot steel in a water smithy (WWS, CC BY) | Hot steel on anvil — duller than cold rail |
| wheel_screech_curve_loop | 4.00 | Train arriving at a station: rolling + high wheel/brake squeal | 4 s loop (shortest allowed); squeal is mixed with rolling noise |
| tunnel_rumble_loop | 20.00 | Inside a steam train passing through a small tunnel | — |

## UI (batch 2)

| File | Dur (s) | What it actually is | Compromise notes |
|---|---|---|---|
| ui_hover_1 | 0.22 | MacBook trackpad click | — |
| ui_error_1 | 0.13 | Kenney soft medium impact (dull thud) | — |
