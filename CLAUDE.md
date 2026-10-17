# Hollow Creek - project rules for Claude Code

Read this at the start of every session. The design lives in `docs/`. Progress is tracked in `docs/PROGRESS.md`.

## The game in one paragraph

Country Victoria, 1952. You are the Administrator and only Constable of a brand-new town in a quiet valley. You build it by hand with life-sim depth, designing each home room by room down to the cushions, and you watch a small population of named residents live in it, with needs, routines, relationships, memories and secrets. When tension boils over, a crime director plans a real, fair crime in the simulation, and you solve it with scene searches, interviews and a case board. What you built decides who saw what. Detail is in `docs/GAME_DESIGN.md`.

## Stack (pinned, do not change without asking)

| Item | Choice |
|---|---|
| Engine | Godot **4.7.2-stable**, standard build (not .NET) |
| Language | **GDScript only**, statically typed |
| Renderer | **Compatibility** (WebGL 2, required for the web) |
| Look | **Warm semi-realism**: PBR materials, soft lighting with SSAO, perspective camera, cutaway walls, quality presets (`docs/ART_DIRECTION.md`) |
| Build tools | Life-sim depth: storeys, stairs, push-pull walls, per-face surfaces, roofs, Buy mode with a Design tool (`docs/HOUSE_BUILDING.md`) |
| Primary target | Web, **single-threaded** export, **PWA enabled**, landscape |
| Later targets | Optional app store wrappers (`docs/DEPLOY.md`) |
| Tests | GUT 9.x in `addons/gut` |
| Base resolution | 1280 x 720 landscape, stretch `canvas_items`, aspect `expand` |

Hard rules: no C#, no GDExtension, no threads, no Forward+-only features (SDFGI, VoxelGI, SSIL, SSR, volumetric fog, TAA don't exist on the web), no stylised or toon assets, no 4k textures.

## Commands

```bash
bash tools/setup_godot.sh                          # install Godot + web templates (idempotent)
WITH_ANDROID=1 bash tools/setup_godot.sh           # also Android templates (M12, optional)
tools/bin/godot --headless --path . --import       # import assets after adding or changing files
tools/bin/godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
tools/bin/godot --headless --path . -s tools/director_soak.gd -- --seeds 500     # from M8
mkdir -p build/web && tools/bin/godot --headless --path . --export-release "Web" build/web/index.html
node tools/web_smoke_test.mjs --viewport 1280x720  # load the build in headless Chromium, screenshot
```

`tools/bin/`, `tools/cache/` and `build/` are git-ignored. Run `--import` before tests or exports in a fresh checkout. The engine is about 9.6 MB gzipped on its own (`index.wasm`, 4.7.2).

Headless Chromium in Claude Code cloud sessions: if Playwright's bundled browser doesn't match, `tools/web_smoke_test.mjs` falls back to `/opt/pw-browsers/chromium`. Never run `playwright install`. WebGL works there through SwiftShader, so 3D screenshots are possible, just slow.

## Folder layout

```
project.godot  export_presets.cfg
addons/gut/
autoload/          game_state.gd, clock.gd, event_bus.gd, save_system.gd, settings.gd, sim_host.gd
scripts/
  world/           grid, terrain, light grid, sightlines, ground traces
  build/           pieces, procedural wall and roof meshes, validation, home scores, build queue
  sim/             SimRng, Sim, residents, needs, actions, schedules, relationships, memories, statements
  crime/           director, plans, evidence graph, solvability, authored cases
  investigation/   cases, scenes, interviews, case board, accusation
scenes/            boot, title, world, build_ui, resident_ui, investigation, case_board, settings
data/              pieces, catalogue, materials, palettes, wishes, briefs, residents, map_slice, cases, dialogue, asset_manifest
assets/
  materials/       ambientCG PBR materials and our tinted variants
  models/          Poly Haven models and our own 1950s props
  hdri/            Poly Haven skies
  characters/      MPFB residents and animations
  fonts/  audio/  icons/  portraits/
  incoming/        files Josh drops in (portraits, downloaded packs)
shaders/           ground, water, rain, glow, torch
tests/             GUT tests mirroring scripts/
tools/             setup, smoke test, soak test, assets/ (fetch scripts), props/ (Blender scripts), characters/ (MPFB pipeline), audio/, cache/ (git-ignored)
docs/
```

## Code conventions

- Typed GDScript everywhere. Untyped declaration warnings on.
- **Simulation, crime director and scoring are plain classes** in `scripts/` with no scene dependencies, so they're testable headlessly and can run on snapshots.
- **Determinism:** all simulation randomness comes from `SimRng`. Never use the global random functions in `scripts/sim/` or `scripts/crime/`.
- **Content is data.** Pieces, palettes, wishes, residents and cases live in `data/*.json`. No case-specific logic in code.
- Systems talk through signals on `EventBus`.
- The logical grid is the source of truth. 3D meshes are views of it, rebuilt when the grid changes.
- Touch targets at least 44 px at base resolution. UI text in Australian English. Dialogue can use 1950s country slang.
- Saves are versioned JSON in `user://` (IndexedDB on the web), with a save-code export and import.

## Asset rules

Follow `docs/ASSET_SOURCES.md`. In short:
1. **Fetch** CC0 materials, models and HDRIs from ambientCG and Poly Haven with the scripts in `tools/assets/`, driven by `data/asset_manifest.json`. Copy only what's used into `assets/`.
2. **Make** what's missing: all architecture procedurally, 1950s props with Blender scripts (`pip install bpy`), residents with the MPFB pipeline, sound effects in Python.
3. **Ask Josh** (via `docs/ASSET_REQUESTS.md`) for anything blocked by the network or needing a login (such as Mixamo animations), and keep working with placeholders.

Only CC0, CC BY, SIL OFL, Apache 2.0, MIT or public domain. Record everything in `CREDITS.md`.

## Web performance budget

See `docs/ART_DIRECTION.md`: quality presets (Low, Medium, High), Basis Universal textures at 1k by default, residents under 10,000 triangles at LOD0 and 3,000 at LOD1, merged static meshes per storey after building, first download under 40 MB compressed with later content in background resource packs, 60 fps on computers at High and 30 fps on a mid-range phone at Medium. Log draw calls, triangles, frame time and sim time in the debug panel.

## Definition of done for every milestone

1. Acceptance criteria in `docs/PLAN.md` met.
2. All GUT tests pass, with new tests for new rules. From M8, the soak test meets its targets.
3. A fresh web export builds cleanly.
4. `tools/web_smoke_test.mjs` loads the build with no console errors and saves a screenshot in `docs/screens/`.
5. `docs/PROGRESS.md` updated: what's done, build sizes, performance numbers, screenshot paths, known issues.
6. Committed with a clear message.

## Working with Josh

- Keep updates short: what works, what to look at, what you need.
- Items marked "needs Josh" in `docs/DECISIONS.md` wait for him. Everything else uses the default.
- Don't deploy publicly or create accounts without his go-ahead.
