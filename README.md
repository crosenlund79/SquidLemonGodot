# EIGHT ARMS UP
### *Otto und die blaue Zitrone*

A 2D climbing platformer made in **Godot 4** where you play **Otto, an octopus**, climbing a
**1937 horse-chestnut tree** that grows up the light shaft of the **underground car park of a
large hospital in Vienna**.

Down in the flooded bottom level lives **Frau Hofrätin Kalmar**, a dignified old **giant squid**
with a monocle, a lace handkerchief and a terrible cold. She swears that only a **blue lemon**,
which grows at the very top of the tree, can cure her. Somewhere up there an old **radio from 1937**
is playing a waltz. Follow the music.

> The three required objects used: 🦑 the giant squid, 🍋 the blue lemon, 📻 the 1937 radio.
> Setting: underground car park of a hospital in Vienna. You: an octopus. Doing: climbing a tree.

---

## How to run

1. Install **Godot 4.3 or newer** (standard build, no .NET needed). Developed and tested with 4.7.2.
2. In the Godot project manager choose **Import**, then pick this folder's `project.godot`.
3. Press **F5** (Run Project).

The first time you open it, Godot imports the generated audio. That takes a few seconds.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Walk / swim | `A` `D` (or arrow keys) | left stick / d-pad |
| Climb bark, ivy, pipes, ladders | hold `W` / `S` | stick up/down |
| Jump (hold for higher) | `Space` | A |
| Tentacle: grab a brass ring or lamp, **hold** to swing | Left click (aims at the cursor) or `J` | X / RB |
| Reel the tentacle in / out | `W` / `S` while swinging | stick |
| Ink dash (once per jump) | Right click, `K` or `Shift` | B / LB |
| Pause | `Esc` / `P` | Start |

## How it plays

- **Climbing.** Otto clings to anything with grip: the trunk, branches, ivy, sprinkler pipes and
  ladders. The trunk is wrapped in **metal tree-protection sleeves** ("Baumschutz") on every level,
  so to get past each one you take a detour through a parking deck.
- **Moisture is your health and your timer.** Otto dries out slowly, faster while climbing and very
  fast in hot air. Water, dripping pipes, sprinklers, puddles and the cleaners' **mop buckets**
  (which are also the checkpoints) keep him going. If he dries out completely, he respawns at the last bucket.
- **The tentacle** fires at brass rings, hooks and lamps. Hold the button to swing, use `W`/`S` to
  reel in or out, and release (or jump) to let go.
- **The ink dash** gives one burst in any direction per jump. Use it to clear gaps that are too wide to jump.
- **The squid's sneezes** ("Ha... ha... HATSCHI!") blast a geyser up the shaft. That's how you get
  past the first sleeve.
- **Hazards:** cars that drive in and back out (their roofs are safe), an ambulance with blue
  lights, Viennese pigeons, hot exhaust vents, jet fans and gusts of wind in the crown.
- **20 horse chestnuts** (Kastanien) are hidden around the car park for completionists.

### The levels

| Level | Theme |
|---|---|
| Ebene −6 | Flooded by the Wien river. The squid's pit, the first sleeve, sneeze geysers |
| Ebene −5 | Visitor parking: puddles, drips, ivy, pipes, your first swing |
| Ebene −4 | Construction site: a hole in the floor (ink dash), a van, swinging lamps, a pigeon |
| Ebene −3 | Short-stay parking: a car that comes and goes, a pillar of ivy, a jet fan |
| Ebene −2 | Boiler room: hot-air vents that lift you and dry you out, a sprinkler test run, a red-hot pipe |
| Ebene −1 | Ambulance bay: wait for the ambulance, then climb the emergency ladder to the street |
| Street & crown | Night, drizzle, the Ferris wheel and the cathedral spire on the skyline, wind, pigeons, the radio and the lemon |

## Everything is generated

There are **no image or sound files made by hand**. Every visual, from the octopus with its
inverse-kinematics arms to the squid, cars, ivy, the Vienna skyline and the night sky, is drawn
with Godot's 2D drawing API in `scripts/art.gd` and the object scripts.

All audio comes from `tools/gen_audio.py` (needs only `numpy`), including **»Kastanienwalzer«**,
an original Viennese waltz (3/4, oom-pah-pah with the slightly early second beat) put through a
1937 radio filter with wow, hiss and crackle. In the game the radio's waltz is muffled by distance
and opens up the higher Otto climbs, and it's muffled again under water.

To regenerate the sounds:

```bash
pip install numpy
```

```bash
python3 tools/gen_audio.py
```

## Project layout

```
project.godot           Godot project (GL Compatibility renderer, 1280x720)
scenes/main.tscn        Single entry scene; everything else is built from code
scripts/
  main.gd               Game flow: title, intro pan, dialogues, ending
  game.gd               Autoload "Game": run stats, checkpoint, input map
  audio.gd              Autoload "Audio": buses, SFX pools, the radio low-pass
  world.gd              The whole level: geometry, the tree, all six storeys and the crown
  player.gd             Otto: movement states, grapple, ink dash, moisture, animated arms
  squid.gd              Frau Hofrätin Kalmar and her sneezes
  water.gd, fx.gd       Flood water and geyser, particles and floating text
  art.gd, painter.gd    Procedural drawing helpers
  objects/              Buckets, chestnuts, cars, pigeons, vents, fans, sprinklers, radio, lemon...
  ui/                   HUD, dialogue box, title, pause and ending screens
tools/gen_audio.py      Procedural sound and music generator
tests/                  Developer tools: scripted-input route tests, screenshots
assets/audio/           Generated .wav files
```

## Developer tools

The `tests/` scripts drive the real game with simulated input, so you can check that every part of
the climb is still possible after you change the level:

```bash
godot --headless --path . -- --dev-test=res://tests/route.gd --route=van4
```

Routes: `e6 e5 grapple5 dash4 van4 car3 vent2 amb1 crown crown_lamp lemon`.
`tests/flow.gd` plays title → intro → ending, and `tests/shots.gd` takes screenshots. Both need a
rendering driver, so don't pass `--headless`. `-- --dev-start=x,y` skips straight to playing at a position.

---

*Gute Besserung, Frau Hofrätin!*
