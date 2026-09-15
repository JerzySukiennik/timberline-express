# Timberline Express

Co-op survival on rails in a mountain pine forest, first person, built in Godot 4.6 for Windows.
Start with a pump handcar, move on to steam and then electric, and carve resources out of the forest along the way.

## v1: test yard
- A 400 m loop with a hill and three sidings with working switch stands and buffer stops
- **Handcar:** pump the beam in rhythm with the crank, plus a brake lever and a direction lever. Pulls a flatcar.
- **Steam locomotive + tender:** fire it with coal or logs, keep water in the tender (bucket from the barrel), and watch boiler pressure and the safety valve. Controls are regulator, reverser, brake and whistle.
- **Electric locomotive:** main breaker, notched controller and reverser, with a battery charged by a petrol generator you refuel from jerrycans
- Walk around on moving vehicles; momentum carries over when you jump off
- Weighty first-person movement: sprint with stamina, crouch, jump, mantle onto ledges
- Two-bone IK arms: the right hand grips high on the handle and the left hand low. Each tool has its own draw animation (the knife spins in the fingers) and swings land on the impact frame.
- Mining: a boulder cracks into 3 tumbling chunks, then 9 smaller ones, then stones. Chop a fir until it creaks, falls and splits into logs. Cut bushes with the knife for fiber.
- Hotbar 1–9, backpack on E/Tab with drag & drop, split and quick move, plus crates
- Slash console (`/help`)

## Controls
WASD move · Shift sprint · Ctrl crouch · Space jump / climb · LMB tool / hold + drag controls · E interact / backpack · 1–9 tools · Q drop · / console · Esc menu

## Layout
- `game/` Godot project
- `blender/` scripts that generate every custom model (run with `Blender -b --factory-startup --python blender/<script>.py`)
- Asset licenses: `game/assets/CREDITS.md`
