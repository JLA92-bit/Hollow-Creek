# Progress

Newest milestone first. Build sizes are raw bytes, with gzip -9 in brackets.

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
