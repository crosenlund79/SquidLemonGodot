# Progress report — Eight Arms Up

_Branch: `claude/kind-turing-ppl19c`._

## Status: complete and playable

- **The whole game works start to finish** on Godot 4.3 and 4.7.2: title → camera pan down the
  light shaft → squid's intro → six car-park levels → street → crown → 1937 radio (also a
  checkpoint) → blue lemon → lemon drop → squid cured → tentacle rises → end card → title.
- **Player:** walk, jump, swim, climb (follows curved trunks and sloped limbs, centres on ladders),
  tentacle swing, ink dash, moisture as health and timer, procedural arms, camouflage.
- **Level:** sleeves force a detour through a deck on every storey. 20 chestnuts, mop-bucket
  checkpoints, and hazards: car, ambulance, pigeons, vents, fan, gusts, hot pipe.
- **Audio:** fully procedural (`tools/gen_audio.py`), including an original waltz through a
  1937 radio filter that opens up as you climb.
- **Verification:** 11 scripted route tests all pass. The `showcase` route plays the entire game
  deterministically, and a gameplay video was recorded from it with Movie Maker.

## Fixed during testing

- Otto fell off after dialogues while clinging. Clinging is now restored after a dialogue.
- Ivy didn't reach the floor, and a hook sat flush with the ceiling (failed line-of-sight).
- Keyboard aim was overridden for 4 s at startup by a phantom "mouse".
- Stalls at limb/trunk junctions and curved trunk edges were fixed with surface sliding and a
  sideways nudge.

## Possible next steps (optional polish)

- Human playtesting for difficulty and moisture balance; mixing levels by ear (the audio has only
  been checked via spectrograms).
- Export presets (Windows/Linux/Web) and a few more secrets or chestnut spots.

## How to resume

1. Open in Godot 4.3+ (or run `godot --headless --path . --import`).
2. Run a route test: `godot --headless --path . -- --dev-test=res://tests/route.gd --route=lemon`
   (add `--trace` to debug).
3. Full playthrough: add `--fixed-fps 30` with `--route=showcase`, and add `--write-movie out.avi`
   to record it (needs a display or `xvfb-run` plus `--rendering-driver opengl3`).
4. Regenerate the audio with `python3 tools/gen_audio.py` (numpy), then re-import.
