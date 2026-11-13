# Progress report — Eight Arms Up

_Recovery checkpoint. Branch: `claude/kind-turing-ppl19c`._

## Complete

- **Playable game, start to finish** (Godot 4.3+; tested with 4.7.2 and 4.3):
  title → camera pan down the light shaft → squid's intro dialogue → six car-park levels
  (Ebene −6 … −1) → street level → tree crown → 1937 radio → blue lemon → the lemon drops
  down the shaft → the squid is cured → her tentacle rises → end card → back to the title.
- **Player (Otto)** in `scripts/player.gd`: walking, variable jump, swimming, climbing (bark, ivy,
  pipes, ladders) with surface-following slides, a tentacle grapple to brass rings and lamps
  (hold to swing, W/S reel), an ink dash, a moisture meter (dry out → respawn at the last bucket),
  hurt/knockback, procedural IK arms, camouflage colours.
- **Level** in `scripts/world.gd`: all geometry, the tree with metal sleeves, branches, nets,
  checkpoints (mop buckets, plus the radio), 20 chestnuts, hazards (car, ambulance, pigeons, hot
  vents, jet fan, wind gusts, a hot pipe), refills (drips, sprinkler, puddles, rain, squid geyser).
- **UI**: HUD (moisture, ink, chestnuts, timer, altimeter, level banners, toasts), dialogue box,
  title, pause menu, ending stats.
- **Audio**: `tools/gen_audio.py` generates every sound plus the original waltz
  (`assets/audio/*.wav`, committed along with the `.import` files, loops enabled). The music bus
  low-pass opens up as you climb toward the radio and closes under water.
- **Tests**: `tests/route.gd` holds scripted-input route tests. All 11 sections pass:
  `e6 e5 grapple5 dash4 van4 car3 vent2 amb1 crown crown_lamp lemon`.
  `tests/flow.gd` runs the full title → ending flow, and `tests/shots.gd` takes screenshots.

## In progress / unfinished

- `showcase` route in `tests/route.gd`: a full scripted playthrough meant for recording a gameplay
  video with Godot's Movie Maker (`--write-movie`). It reaches the radio. Still to finish: the
  tail after the radio dialogue (right limb → swing → lemon → ending), then recording and
  converting to MP4 with ffmpeg.
- Possible polish: more playtesting of difficulty and moisture balance by a human, tuning the
  sound mix, and an optional export preset.

## How to resume

1. Open the project in Godot 4.3+ (or run `godot --headless --path . --import` once).
2. Run the route tests:
   ```bash
   godot --headless --path . -- --dev-test=res://tests/route.gd --route=lemon
   ```
3. Debug a route with per-0.15 s traces by adding `--trace`.
4. For the showcase: `--route=showcase`, then record with
   `godot --path . --write-movie out.avi --fixed-fps 30 -- --dev-test=res://tests/route.gd --route=showcase`
   (needs a display, or `xvfb-run` plus `--rendering-driver opengl3`).
5. Regenerate the audio: `python3 tools/gen_audio.py` (needs numpy), then re-import.
