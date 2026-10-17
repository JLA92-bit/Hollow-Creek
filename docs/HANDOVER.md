# Handover - 17 October 2026

For the next Claude Code session. Read `CLAUDE.md` first, then this, then `docs/PROGRESS.md` (newest milestone first) and `docs/PLAN.md`.

Branch: `claude/magical-ride-4advps` (push with `git push -u origin claude/magical-ride-4advps`). No PR has been opened; don't open one unless Josh asks.

## Where things stand

| Milestone | State |
|---|---|
| M0 to M4 | Done: tests, demos, browser screenshots and docs committed (`docs/screens/m0` to `m4`) |
| M5 Residents | Code, tests and the headless demo are done (residents demo 20 of 20). **Browser run unfinished:** 6 of 7 screenshots are in `docs/screens/m5/` (`m5_07_marge` is missing) and `BROWSER_RESULT` in the M5 entry of `docs/PROGRESS.md` still needs the result |
| M6 Light, sightlines and memories | Core done and tested (168 GUT tests pass). Night demo and overlays written; demo **11 of 12** headless (see Open issues). Not yet exported, browser-tested or written up in PROGRESS |
| M7 onward | Not started |

Josh last got a five-line update after M3 and M4. **He hasn't had his M5 update yet.** Send it (five lines at most: what works, what to try, what's needed) once M5's browser run is finished.

## Next steps, in order

1. **Fix the night demo's time card check** (see Open issues), then run `tools/bin/godot --headless --path . res://scenes/resident_ui/night_demo.tscn` until it shows 12 of 12.
2. **Apply the small edits that were about to go in when the session stopped:**
   - `scenes/resident_ui/resident_panel.gd`: add `"sit_up": "Sitting up late", "loiter": "Hanging about"` to `DOING` (and `"sit_up": "Going to sit up", "loiter": "Out walking"` to `GOING`). Move the `RECENT MEMORY` block above `HOME` so the memory shows without scrolling, as in `docs/mockups/ui-layout-town.png`.
   - `scenes/resident_ui/night_demo.gd`:
     - Rain from about 7 am to noon on Wednesday, then run to 1 pm, so the prints shot is in daylight.
     - Aim the `m6_05` camera at the tile with the most bootprints (the current fixed camera shows none).
3. **Close M5:**
   - `mkdir -p build/web && tools/bin/godot --headless --path . --export-release "Web" build/web/index.html`
   - `node tools/look_test.mjs --scene residents_demo --out docs/screens/m5 --dpr 1.5 --timeout 7000000`. It takes about 25 minutes on SwiftShader, so run it in the background and log to the scratchpad.
   - Replace `BROWSER_RESULT` in PROGRESS with the result.
   - Commit, then send Josh his M5 update with a couple of screenshots.
4. **Close M6:**
   - Check desktop shots: `HC_SHOT_DIR=<dir> xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 --resolution 1280x720 res://scenes/resident_ui/night_demo.tscn`
   - Export, run `node tools/look_test.mjs --scene night_demo --out docs/screens/m6 ...` and `node tools/web_smoke_test.mjs --viewport 1280x720`.
   - Write the M6 PROGRESS entry and add the night demo to `CLAUDE.md` (commands and URL hooks).
   - Commit, then send Josh his M6 update.
5. **M7 Investigation tools** per `docs/PLAN.md`.

## What was built in M5 and M6 (where to look)

**Simulation (`scripts/sim/`).** Plain classes, deterministic, randomness only from `SimRng`.
- `sim.gd`:
  - Needs, schedules, utility choices, visits, relationships, grievances and the weekly economy (with rent).
  - Wishes and move-ins: `move_household`, `review_homes`.
  - `direct()` for scripted actions; a `hold` flag on an action stops bedtime or work cutting it short.
  - `light_now()`, `add_incident()`, traces and records.
  - Snapshot and restore are exact. Numbers go through `q()` (1/1024) and positions through 1/64 m.
- `sim_town.gd`:
  - The walk graph and places. Object places carry `pose`, `stand` and `face` for drawing.
  - It also builds `sight: SightMap` and keeps `grid`.
- `home_life.gd`: wish checks against the house as built, move-in reactions to a family's brief, rent and the history card.
- `memories.gd`:
  - Notable sightings (through `SightMap.look`), lights on at odd hours, noises, decay, gossip and the 200 cap.
  - `describe()` and `confidence_word()` produce text for the UI.
- `traces.gd`: bootprints by ground and wetness, muddy floors and fading. Faint steps use a string hash, not the RNG.

**World (`scripts/world/`).**
- `sight_map.gd`:
  - Edge blockers (walls, doors, windows with curtains drawn at night, solid fences) and tile blockers (tree trunks, wardrobe, dresser).
  - Rooms with their windows and lamps.
  - Bresenham lines with the corner rule; `look()` gives range and confidence.
- `light_grid.gd`:
  - Daylight, night and moonlight.
  - From dusk, lamps are lit in rooms where somebody is awake. Window spill reaches 3 m (1.5 m through curtains) and verandah lamps 4 m.

**Host and UI.**
- `autoload/sim_host.gd`:
  - Builds the town from the world's houses as drawn and keeps the sim in step with the clock.
  - Runs a daily home review, banks rent and Town Trust, and handles offers to families.
  - Its `lights_changed` signal drives `HouseView.lit_filter`, so drawn lamps match the logic.
- `scenes/resident_ui/`:
  - `resident_views.gd`: the figures, with LOD1 on Low.
  - `resident_panel.gd`: the resident card.
  - `residents_list.gd`: households and the families waiting with their briefs.
  - `resident_look.gd`: colours from each resident's appearance line.
  - Demos: `residents_demo` and `night_demo`.
- `scenes/world/debug_overlays.gd`: light, sightlines (from the selected resident), routes and prints. F4 or the button in the debug panel cycles them.
- Keys: P opens the Residents list. Click a resident for their card.

**Characters (`tools/characters/`).**
- `make_mannequins.py` makes the placeholders.
- `setup_mpfb.sh` and `make_agnes.py` are the MPFB pipeline:
  - The tights and skirt helpers are her clothes.
  - She's normalised to 1.76 m.
  - 9,000 triangles at LOD0 and 2,800 at LOD1.
  - Animations are keyed as world-space swings from the A-pose.
- Preview: `xvfb-run -a tools/bin/godot --path . --rendering-driver opengl3 -s tools/previews/people_preview.gd -- out.png`

## Open issues

- **Night demo time cards:**
  - In headless runs, Wednesday's mill time cards keep `"out": -1` at 6 pm, though a desktop run passed 12 of 12.
  - Clock-out happens in `Sim._finished()` when a work action ends.
  - Suspect: the demo turns rain on, and `SimHost` reads `rain.intensity`, which ramps with real frame time. That makes the run frame-dependent.
  - Check first whether work actions are ending or being replaced without `_finished`. Also consider letting the demo set `sim.raining` directly.
- **Lonely Agnes visits Marge every day,** so the event log repeats ("went to visit Marge"). It's de-duplicated within a day only.
- **Sightlines and light cover the ground storey only.** Upper floors are left out.
- See `docs/BACKLOG.md` (M5 rows) for the rest: Agnes's painted feet and hair, Frank's shop sign wish, moving families out, walking speed at 1x.

## Environment notes

- Godot is in `tools/bin/` and Blender (`bpy`) in `tools/cache/blender-venv/`. Both are git-ignored; reinstall with `bash tools/setup_godot.sh` and `bash tools/props/setup_blender.sh`.
- Run `--import` after adding scripts (the `class_name` cache).
- Browser runs use SwiftShader and are slow. `look_test.mjs` parses lines starting `HC_PERF ` as JSON, so demos print `HC_DEMO perf ...` instead.
- Don't `pkill -f chromium` from the tool shell; it kills the shell. Kill by PID.
- The first download was about 38.2 MB at the last export (budget 40 MB).
