# Progress

Newest milestone first. Build sizes are raw bytes, with gzip -9 in brackets.

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
- Mid-range phone profile (915 x 412, CPU throttled 4x, Medium): PHONE_RESULT
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
