# Hollow Creek - Build Plan

Work through the milestones in order. Each one ends with something Josh can play in a browser. The look is warm semi-realism (`docs/ART_DIRECTION.md`), and the build tools aim for life-sim depth (`docs/HOUSE_BUILDING.md`). Follow the definition of done in `CLAUDE.md`.

**Goal of the vertical slice (end of M10):** a player can design homes in detail, watch residents live in them, and solve The Cash Tin from start to finish on a phone or computer, from a link on Josh's site.

| Milestone | Outcome | Josh involved? |
|---|---|---|
| M0 | Project runs in the browser. Tests, builds and CI automated | No |
| M1 | The valley, with the semi-realistic rendering pipeline and quality presets | **Judge the look** |
| M2 | Build core: rooms, walls, floors, doors, windows, storeys, stairs | **Play with it** |
| M3 | Build detail: surfaces, roofs, verandahs, trims, foundations, terrain, Sandbox, share codes | **Play with it** |
| M4 | Buy mode: catalogue, placement, Design tool, lighting, home scores, construction | **Play with it** |
| M5 | Residents live in the town | Look at build |
| M6 | Light, sightlines and memories | No |
| M7 | Investigation tools | Look at build |
| M8 | The crime director, with soak tests and a solver bot | No |
| M9 | Prologue and The Cash Tin, complete, with final residents and audio | **Animations needed** |
| M10 | Tester release on Josh's site | **Hosting needed** |
| M11 | Chapter 1 | Feedback |
| M12 | App store wrappers (optional) | **Accounts needed** |

---

## M0 - Foundations

**Tasks**
1. Run `bash tools/setup_godot.sh`. Confirm `tools/bin/godot --version` prints `4.7.2.stable`.
2. Copy `tools/templates/project.godot` and `tools/templates/export_presets.cfg` to the root. They're known-good (tested with 4.7.2: import, web export, and a clean load in headless Chromium). Extend: name "Hollow Creek", main scene `res://scenes/boot/boot.tscn`, typed warnings on, PWA icons, landscape, white background, offline page.
3. Install GUT 9.x (v9.7.1 tested) into `addons/gut/` from `https://github.com/bitwes/Gut`.
4. Create the folder layout from `CLAUDE.md`, `.gitignore` (`tools/bin/`, `tools/cache/`, `build/`, `.godot/`, `node_modules/`), `CREDITS.md`, `docs/PROGRESS.md`, `docs/BACKLOG.md`, `docs/ASSET_REQUESTS.md`.
5. Download the fonts (`docs/ASSET_SOURCES.md`) and make the base UI `Theme`.
6. Boot scene with the title, "Tap to begin" and a version label.
7. `npm init -y && npm i -D playwright`. Confirm `node tools/web_smoke_test.mjs` works against the export.
8. **Check network access** to Poly Haven and ambientCG (`docs/ASSET_SOURCES.md`). Record the result in `docs/PROGRESS.md`, and if blocked, write the first `docs/ASSET_REQUESTS.md` batch for Josh.
9. CI workflow: on push to `main` and `beta`, set up, import, test, export web, upload the build as an artefact.

**Acceptance:** the web export loads in headless Chromium with no console errors. One GUT test passes.

---

## M1 - The valley and the rendering pipeline

The look is judged here, before any gameplay, so it can be fixed cheaply.

**Tasks**
1. Asset fetch scripts driven by `data/asset_manifest.json`: `tools/assets/fetch_polyhaven.py`, `tools/assets/fetch_ambientcg.py`. Import settings: Basis Universal for 3D textures, 1k by default.
2. Rendering setup per `docs/ART_DIRECTION.md`: HDRI sky and ambient light, tonemapping and colour grade, directional sun and moon with shadows, SSAO, glow, fog, reflection probes. **Quality presets** (Low, Medium, High) with a 3-second benchmark on first launch.
3. The logical grid (`docs/BUILDING.md`) with save and load, and `data/map_slice.json` (144 x 96 m): siding, creek, mill landmark, Agnes's cottage.
4. Terrain with splat-painted ground (dry grass, dirt, gravel, mud), the creek as water with banks, eucalypts and shrubs.
5. A **look test scene**: Agnes's cottage built from the procedural wall and floor code with real materials, furnished with Poly Haven pieces, at morning, midday, dusk and night.
6. Camera rig: perspective, narrow field of view, orbit, pan, zoom, tilt, touch gestures.
7. Clock, time controls, day and night cycle, rain.

**Acceptance:** screenshots of the look test scene at four times of day, on Low, Medium and High, saved to `docs/screens/m1/`. Medium holds 30 fps in a mid-range phone browser profile (log the frame time). **Pause for Josh to approve the look before M2.**

---

## M2 - Build core

**Tasks**
1. `HouseData` (storeys, rooms, wall edges with per-face surfaces, openings, roofs, stairs, objects) and the procedural mesh generator, with local rebuilds.
2. Tools: Room (rectangles and L-shapes), Wall (straight and diagonal, half and low walls), push and pull walls, move and rotate rooms, wall heights per room, archways and columns.
3. Floors per tile, half tile and quarter-tile triangles, with rotation and offset. Ceilings.
4. Doors and windows: free placement along walls, sill height, stacking, sizes and styles, swing direction, locks and key holders, night behaviour settings.
5. Storeys (up to 3 plus cellar), floor view, stairs (straight, L, U, ladder) that cut the floor above and connect pathfinding.
6. Walls up, cutaway and down modes. Floor visibility.
7. Validation hints, unlimited undo and redo, autosave.
8. Controls for mouse and keyboard and for touch, as in `docs/HOUSE_BUILDING.md`.

**Acceptance:** a player can design a two-storey shop with a residence above and a single-storey cottage on stumps from scratch, edit them freely, and undo every step. Tests from `docs/HOUSE_BUILDING.md` for rooms, push and pull, and stairs pass.

---

## M3 - Build detail

**Tasks**
1. Surfaces: per-face paint (chart plus custom colour), wallpapers with colourways, panelling, tiles, skirting, picture and dado rails, cornices. Room and whole-house painting shortcuts. The eyedropper.
2. Roofs: auto-roof, manual pieces with handles, pitch, overhang, merge, materials, fascias and gutters, chimneys, dormers.
3. Exterior: cladding per face, trims, verandahs (roof shapes, posts, lace or fretwork, rails, steps), sleep-out enclosures.
4. Foundations and levels: stumps with adjustable height, slabs, cellars and lofts.
5. Terrain tools (raise, lower, flatten, smooth, paint) and landscaping (plants, fences, gates, paths, outbuildings, outdoor items).
6. Blueprint library, share codes (`.hollow` file and text code), screenshot mode.
7. **Sandbox mode** save type (unlimited money, instant build, no crime director).

**Acceptance:** in Sandbox, a player can turn a bare cottage into a fully finished period home and garden, export it as a share code, and import it into another save identically.

---

## M4 - Buy mode and construction

**Tasks**
1. Catalogue from `data/catalogue.json`: Poly Haven furniture plus the custom 1950s props modelled with Blender scripts (`docs/ASSET_SOURCES.md`). Categories, search, filters and object info.
2. Placement: grid, half grid and free, rotation steps and free rotation, raise and lower, wall-mounted items, decor on surfaces, stacking, multi-select and groups.
3. **Design tool:** named material slots on every object, the material library, custom colours, saved styles.
4. Lighting design: placeable lights with brightness and colour temperature, kerosene lamps before electricity.
5. Home scores, with live "+3 Comfort" previews while hovering.
6. Story construction: blueprints, the build queue, materials at the siding, visible build stages, weather delays, quality tiers, handy residents.

**Acceptance:** a furnished cottage built in story mode scores as expected, every catalogue object can be recoloured per slot, and construction stages play out visibly over in-game days.

---

## M5 - Residents

**Tasks**
1. `scripts/sim/` per `docs/SIMULATION.md`: `SimRng`, `Sim` (tick, snapshot, restore), residents, needs, traits, utility actions, schedules, pathfinding across storeys, relationships, grievances, secrets.
2. Founding residents from `docs/RESIDENTS.md` into `data/residents.json`.
3. **Placeholder people:** simple realistic-proportion mannequins with walk and idle animation, so the sim can be built while the final characters are made.
4. Start the MPFB character pipeline (`docs/ASSET_SOURCES.md`) with one test resident (Agnes) to prove it works in the browser within budget.
5. Applications, briefs, move-in reactions, wishes and home history (`docs/HOUSE_BUILDING.md`).
6. Resident panel (layout in `docs/mockups/ui-layout-town.png`), social events, the weekly economy.

**Acceptance:** 7 in-game days from a fixed seed give identical snapshots twice. Residents follow their routines and react to their homes. The Agnes test character renders and animates on Medium within budget.

---

## M6 - Light, sightlines and memories

1. The logical light grid (lamps, lit rooms, window spill, moonlight), kept in agreement with the rendered lights.
2. Sightlines, memory recording, noises, decay and rumours (`docs/SIMULATION.md`).
3. Ground traces: bootprints by size and sole, fading over time and in rain.
4. Debug overlays (sightlines, light, routes) and records (ledger, exchange log, time cards).

**Acceptance:** GUT tests for every sightline case. A scripted night produces the expected memory with the right confidence.

---

## M7 - Investigation tools

Build with a hand-written test case first.
1. Incident flow, scene view (walls down, torch at night), traces, measure tool, numbered markers.
2. Statements from memories with honest, omit and lie decisions.
3. Interview screen (layout in `docs/mockups/ui-layout-investigation.png`) with a **live 3D portrait** of the resident under a portrait light rig and facial expressions.
4. Case board, warrants, accusation, outcomes and consequences.

**Acceptance:** the test case is solvable with scripted taps in the headless browser.

---

## M8 - The crime director

Follow `docs/CRIME_DIRECTOR.md`. Motives, plans, simulation on snapshots, evidence graph, solvability, scoring, re-planning at nightfall, authored-case mode, the soak test and the solver bot in CI.

**Acceptance:** 500 seeds ship zero unsolvable cases, and the other targets are met.

---

## M9 - Prologue and The Cash Tin

**Needs Josh:** Mixamo animations (or confirm Quaternius only).
1. The tutorial and Case 0 from `docs/CASE_00_CASH_TIN.md`.
2. Final residents from the MPFB pipeline, with 1950s clothes, hair, facial blend shapes, LODs and animations.
3. Final props for the prologue, audio (synthesised plus Freesound CC0 recordings), music.
4. Title, settings (quality presets, text size, audio, reduce motion, hints), credits, saves and save codes.
5. Headless playtest of the full prologue with screenshots in `docs/screens/m9/`.

**Acceptance:** a new player finishes the prologue in 40 to 60 minutes. First download under 40 MB compressed, with later content in background resource packs.

---

## M10 - Tester release

**Needs Josh:** hosting, DNS and a feedback form (`docs/DEPLOY.md`).
PWA polish, install instructions, rotate-your-phone prompt, version and What's New, feedback button, deployment with CI, tester landing page, and a real-phone performance pass.

**Acceptance:** Josh plays the prologue on an iPhone and an Android phone from the home screen and continues a saved game.

---

## M11 - Chapter 1

Applicants, the hotel, church and school, seasons and the drought, emergent minor incidents, Case 1 (`docs/CASE_01_LOW_WATER.md`), the Best Kept Home competition, and the Chapter 2 hook.

## M12 - App store wrappers (optional)

If Josh later wants store listings, wrap the same build as Android and iOS apps (`docs/DEPLOY.md`).
