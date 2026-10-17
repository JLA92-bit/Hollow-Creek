# Progress

Newest milestone first. Build sizes are raw bytes, with gzip -9 in brackets.

## M2 - Build core (done)

**What works**
- **House model (`HouseData`):**
  - Walls are first-class pieces on grid edges: full, half (1.0 m) and low (0.6 m), straight or at 45 degrees. Each has its own height and a separate surface on each face.
  - Rooms are detected by flood fill over quarter-tile triangles bounded by full walls, so diagonal walls split rooms and half walls don't.
  - Floors are painted per tile or per quarter-tile triangle, with board direction.
  - Openings sit along walls at any position, with sill height and stacking. Doors have swing, hinge side, a lock, key holders, and a lock-at-night setting; windows have latch-at-night and curtains-at-dusk.
  - Up to three storeys plus a cellar, with straight, L, U and ladder stairs that cut the floor above. Posts, stumps or slab.
  - M1's room-style template (Agnes's cottage) converts automatically.
- **Edits (`BuildOps`):**
  - Room tool, plus extending a room into an L-shape. Walls of each kind.
  - Push and pull a wall run: side walls stretch, floors grow or shrink, and faces, doors, windows and furniture travel with it.
  - Move and rotate rooms; shared walls stay with the neighbour.
  - Room names, paint and wall heights. Openings with overlap and height checks. Floors, storeys, stairs (checked for walls across them and for landing on a floor), posts, foundations, and demolishing walls, openings, stairs, posts, floors or whole rooms.
- **Undo and redo:** unlimited (`UndoStack`). Each step stores the house before and after plus the cost, so undo refunds and redo charges.
- **Pathfinding (`HousePathing`):** walkable tiles across storeys. Doors, doorways and arches let people through, stairs join storeys, and stairwells aren't walkable.
- **Validation hints in plain words:** "The bedroom has no way in.", "The bedroom has no window.", "A staircase doesn't arrive on a floor.", "A window isn't sitting on a wall."
- **Mesh builder:**
  - Walls are built per 1 m edge, with corners filled, free ends capped, and openings cut with reveals. Sashes, panel and ledge doors, fanlights and architraves come from M1. Skirting and picture rails go on inside faces.
  - Floors are quarter-aware, with an upper-floor band of cladding, ceilings that face down (invisible from above), stairs with treads, risers, stringers and handrails, ladders, balustrades round stairwells, and posts and piers.
  - Walls are grouped into 8 m chunks. Edits that don't change the room layout rebuild only the chunks they touched; layout changes rebuild that storey.
- **Floor view and cutaway:** storeys above the one you're editing hide, and the cutaway applies to that storey.
- **Build mode (B, or the Build button):**
  - Tools: Room, Wall, Select (push and pull, move and turn rooms, pick doors and windows), Door, Window, Arch, Floor, Stairs, Post, Demolish.
  - Blueprint previews with snapping guides, plus floating labels with dimensions, area and live cost, which turn red with the reason when something isn't allowed.
  - Doors and windows snap to 0.25 m (hold Alt for free placement). Arrow keys nudge and raise; `,` and `.` turn stairs and rooms.
  - Ctrl+Z and Ctrl+Y undo and redo; Delete removes; Esc cancels; Shift+Page Up and Page Down change storey.
  - Time pauses while you build.
- **Panels (layout from the house-builder mockup):**
  - Tool palette.
  - Options per tool: catalogue cards with prices, paint swatches, wall heights, floors, night behaviour.
  - Options for a selection: a room's name, paint, height, turning or clearing it; a window's sill, sliding it, latch and curtains; a door's swing, hinge, lock, key holders and lock at night; removing anything.
  - House panel: storey up and down, add a storey, dig a cellar, stump height or slab, validation hints.
  - Undo, redo, Done, and on touch a Build or Cancel confirm.
- **Touch:** one finger draws, two fingers move the camera, and placements wait for the Build button.
- **Town:**
  - Drawing a room on open ground starts a new house. It stands on the highest corner of its block, with stumps down the slope, and refuses water, mud, landmarks, blocks next to other houses, and slopes too steep for 1.8 m stumps.
  - Building clears trees and grass from the block. Agnes's cottage is heritage-locked.
  - Houses are saved in `GameState`, with autosave a second after each edit and a Continue button on the title menu.
- **Sounds:** UI sounds synthesised in Python (`tools/audio/make_ui_sfx.py`): click, tick, place, remove, error, undo, storey.
- **Tests:** 75 GUT tests (697 asserts), all passing. They cover the room tool, L-shapes, push and pull growing and shrinking rooms, faces and openings surviving push, pull and undo, moving and rotating rooms, diagonal and half walls, opening rules and stacking, room heights, quarter floors, storey limits, and stairs (cutting the floor above, connecting pathing, shapes, rejection). Also chunked meshes, the upper storey, the stairwell floor, validation, undo order, and a full acceptance build with every step undone.

**Acceptance demo** (`scenes/build_ui/build_demo.gd`; `?scene=build_demo`; it runs in CI headless). It drives the real tools with mouse events.
- **The general store:** shop, storeroom and exchange room; front door with fanlight, shop windows, inner and back doors; a first floor with living room, two bedrooms and a kitchen; and stairs up from the shop.
- **A cottage on 0.9 m stumps:** an L-shaped living room and kitchen, a bedroom wall pushed out a metre, doors, windows and a quarry-tile floor.
- **Result:** 39 steps, then every one undone back to an empty valley with every pound refunded, then all redone. **15 of 15 checks pass.**

**Screenshots:** `docs/screens/m2/` (`m2_01` to `m2_06`): the shop's ground floor, the residence above, the cottage in cutaway, both houses outside, everything undone, and redone.

**Build sizes**

| File | Raw | gzip -9 |
|---|---|---|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 31,251,452 | 24,763,982 |
| **First download** | | **about 34.8 MB** (budget 40 MB) |

**Performance** (headless desktop, Godot 4.7.2; the browser runs these several times slower)
- A full two-storey shop (6 rooms, about 80 wall edges) builds in 426 ms.
- Adding a door rebuilds 2 chunks in 30 ms.
- Pushing a wall out (which changes rooms) rebuilds the storey in 60 ms.
- Drag previews apply the edit to a copy and rebuild live on each 1 m step.

**Known issues** (more in `docs/BACKLOG.md`)
- Diagonal walls take no openings and can't be pushed yet.
- One hip roof covers the top storey only; proper roofs come with the M3 roof tools.
- Key holders are labels until residents arrive in M5.

## M1 - The valley and the rendering pipeline (done, awaiting Josh's look approval)

**What works**
- **Assets:** `tools/assets/fetch_polyhaven.py` fetches everything in `data/asset_manifest.json`: 16 textures, 4 HDRI skies and 15 furniture models, all CC0. The four ground layers are packed into Texture2DArrays. Credits are written to `data/asset_credits.json` and `CREDITS.md`. `tools/assets/fetch_ambientcg.py` is ready but optional, because its download host is blocked here.
- **Generated textures:** `tools/textures/make_foliage.py` makes the eucalypt leaf clusters, dry grass tufts, shrub leaves, a macro-variation noise map and the water ripple normal map.
- **Logical grid:** `WorldGrid` stores ground, wetness, light, corner heights, edges and objects, with compressed JSON save and load. `MapSlice` rasterises `data/map_slice.json` (144 x 96 m) into it: the siding, the mill, the creek with muddy banks and a wet reach, dirt tracks, the muddy creek track behind the store plot, Agnes's flattened lot, the hidden 1890s town, and seeded tree, shrub and tuft scatter.
- **Terrain:** splat shader blending dry grass, dirt, gravel and mud, with height-aware blending, anti-tiling, macro colour variation and wetness. An outer ring of rising bush country hides the map edge.
- **Water and vegetation:** the creek is a ribbon with scrolling ripples, soft edges and sky reflections. Gums and river red gums are procedural (pale forked trunks, drooping leaf clusters, wind sway), drawn as MultiMeshes with a cheap distant variant for the 420 backdrop trees. Trees between the camera and its focus hide themselves.
- **Landmarks:** the railway siding (track, platform, goods shed, station sign), the timber mill (iron shed, boiler stack, timber stacks, log piles), and survey pegs on the store plot.
- **Agnes's cottage:** generated from `data/houses/agnes_cottage.json` by `HouseMeshBuilder`.
  - **Structure:** stumps follow the ground, with a floor frame under the house and per-room floors in boards, pine and lino.
  - **Walls:** walls are derived from the rooms, with weatherboard outside and painted plaster inside per room. Real openings have reveals, double-hung sashes with glass, panelled and ledge-and-brace doors (interior doors swung open), a front-door fanlight, architraves, skirting and picture rails.
  - **Roof and verandah:** hip roof in corrugated iron with eaves lining, fascias, gutters and cappings. The bullnose verandah has posts, brackets and steps, and there's a brick chimney with pots.
  - **Inside:** the sitting-room fireplace has a mantel, hearth and logs. The kitchen has a stove recess with a procedural wood stove, plus rugs, a gingham tablecloth and pleated curtains with pelmets.
  - **Furniture:** 21 Poly Haven pieces.
- **Cutaway:** walls up, cutaway (walls facing the camera drop to 0.5 m, with joinery hidden) and walls down. Page Up and Page Down switch modes.
- **Lighting:** a custom sky shader blends two HDRIs, plus a single sun-or-moon light with shadows, sky ambient, Filmic tonemapping, glow, fog and a warm colour grade. `data/time_of_day.json` has 13 keyframes: the Southern Hemisphere sun is due north at noon, with low warm mornings, orange dusk and blue moonlit nights.
- **Interior light:** kerosene lamps and firelight with flicker, glowing windows at night, and a tinted fill light per room as fake bounce.
- **Quality presets:** Low, Medium and High (`data/quality_presets.json`) control render scale, MSAA, shadow size, splits and distance, soft shadows, SSAO, glow, lamp budget, terrain detail and grass. There's a 3-second benchmark on first launch, and you can switch any time with the Quality chip.
- **Camera:** perspective, 35 degree field of view. Orbit (right-drag, or Q and E), pan (middle-drag, WASD or one finger), zoom (wheel or pinch), tilt (Shift-wheel or a two-finger vertical drag), and twist to orbit.
- **Time and weather:** the clock has pause, 1x, 2x and 4x (Space, 1, 2, 3). Rain (R key or the Rain chip) brings streaks near the camera, a greyer sky, dimmer sun, fog, and wet, darker ground and creek ripples, and things dry slowly afterwards.
- **HUD:** follows the town mockup: date and time, speed buttons, money, residents and Town Trust; Walls, Quality, Rain and Debug chips; a bottom toolbar (disabled until M2+); and a debug panel showing FPS, frame time, draw calls, triangles and sim time (F3).
- **How to try it:** the title menu's "Visit the valley" opens it. `?scene=world` jumps straight in, and `?scene=look_test` runs the look test.
- **Tests:** 47 GUT tests (481 asserts), all passing. They cover the grid, the map slice (including determinism and the mud behind the store), house data, wall derivation and validation, house meshes and cutaway, day and night, quality presets, the material library, asset credits and eucalypt determinism.

**Look test:** `docs/screens/m1/`
- Contact sheets: `sheet_low.png`, `sheet_medium.png` and `sheet_high.png` (morning, midday, dusk and night; outside and in cutaway).
- The 24 individual shots `<time>_<view>_<preset>.png`, plus `valley_midday_medium.png` and `valley_dusk_medium.png`.
- `world_hud.png` (the playable valley with the HUD) and `map_preview.png` (top-down map).

**Build sizes**

| File | Raw | gzip -9 |
|---|---|---|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 31,096,776 | 24,623,672 |
| **First download** | | **about 34.7 MB** (budget 40 MB) |

The four 1k HDR skies make up 11 MB of the pack. Halving them is the first lever if the budget gets tight (`docs/BACKLOG.md`).

**Performance**
- Desktop profile, Medium, 1280 x 720 at a device pixel ratio of 1.5, midday exterior: 255 draw calls and about 487k triangles a frame. That counts every shadow-cascade pass; the cottage's view without the backdrop is about 340k. Sim and lighting update time is 0.4 ms.
- Frame time in headless Chromium is about 5.4 s a frame. That's SwiftShader (WebGL 2 rendered on the CPU), so it says nothing about a real GPU. It's recorded in `perf_desktop_medium.json`.
- Mid-range phone profile (915 x 412, CPU throttled 4x, Medium): median 2,588 ms a frame (p95 2,741 ms), 255 draw calls, 462k triangles, sim 0.3 ms. The game renders at 1599 x 720 because the stretch mode expands to fill the width. This is SwiftShader again, so it only shows the CPU side isn't the bottleneck (sim 0.3 ms). `perf_phone_medium.json`
- **A real phone is needed** to confirm 30 fps on Medium. The debug panel (F3, or the Debug chip) shows live FPS, frame time, draw calls and triangles.

**Known issues**
- Whether Godot 4.7's Compatibility renderer actually draws SSAO and reflection probes is unconfirmed under SwiftShader. Corners and contact shadows currently rely on the PBR AO maps and the per-room fill light.
- Textures are WebP rather than Basis Universal (decision 17), so GPU memory use is higher than planned.
- The map builds at runtime in about 1.3 s on desktop. It should be baked or cached later.
- Distant grass tufts can read as small blobs at low sun.

## M0 - Foundations (done, 17 October 2026)

**What works**
- Godot 4.7.2-stable (standard build) and the web export templates install with `bash tools/setup_godot.sh`.
- Project: "Hollow Creek", Compatibility renderer, 1280 x 720 landscape, `canvas_items` stretch, white background, typed-code warnings on (untyped declarations and unsafe access).
- Web export: single-threaded, PWA on (icons 144, 180, 512, landscape, white background, offline page, navy theme colour). GUT, tests, tools and docs are excluded from the pack.
- Boot scene with the title, "Tap to begin" and the version. A tap goes to a title menu shell.
- Base UI theme from Josh's colours (white panels, 14 px radius, navy outline buttons, maroon primary buttons, chips, bars), built reproducibly by `tools/make_theme.gd`. Fonts: Fraunces, Atkinson Hyperlegible, Courier Prime, Caveat (SIL OFL).
- Autoloads: EventBus, Settings (user://settings.cfg), GameState, Clock (dates from Mon 2 June 1952, 4 game minutes a second at 1x), SaveSystem (versioned JSON, migration hook, compressed save codes), SimHost.
- Deterministic `SimRng` (seeded PCG32 with exact snapshot and restore through JSON) and a `Sim` skeleton with snapshot and restore.
- GUT 9.7.1: **13 tests, 125 asserts, all passing** (RNG determinism, snapshot round-trips, boot scene, clock labels, save codes, save migration).
- Headless Chromium smoke test: no console errors on boot, and none after tapping through to the title.
- CI workflow (`.github/workflows/ci.yml`): on push to `main` and `beta` it sets up Godot, imports, runs GUT, exports web, smoke-tests and uploads the build.

**Network check (decision 6):** Poly Haven fully reachable. ambientCG's API is reachable but its file host `acg-download.struffelproductions.com` is blocked. Details and a fallback download batch are in `docs/ASSET_REQUESTS.md`.

**Build sizes**
| File | Raw | gzip -9 |
|---|---|---|
| index.wasm | 39514754 | 10,084,297 |
| index.pck | 719224 | 703,417 |

**Screenshots:** `docs/screens/m0/boot.png`, `docs/screens/m0/title.png`

**Known issues**
- CI hasn't run yet (no push to `main` or `beta` from this branch).
- Performance numbers start in M1, when there's a 3D scene to measure.
