# Backlog

Work deliberately deferred to keep milestones tight. Each item notes where it came from.

| Item | From | Notes |
|---|---|---|
| Sandbox and Settings on the title menu | M0 | New game and Continue work from M2. Sandbox arrives in M3, Settings in M9 |
| Branded HTML loading screen (custom shell with progress bar in Josh's colours) | M0 | Default Godot shell is used, with a white background and navy theme colour. Polish in M10 |
| GitHub Actions CI has not run yet | M0 | Runs on the first push to `main` or `beta`. This session works on a feature branch |
| Per-preset texture sizes at runtime | M1 | Presets list 512, 1024 and 2048 px, but textures are capped at import (1k architecture and ground, 512 props). Ship a low-res texture pack for Low and a 2k pack for High as resource packs (M10) |
| Terrain LOD | M1 | 144 x 96 tiles at 1 m is about 28k triangles, drawn again for each shadow cascade. Coarser far chunks would help phones |
| Map slice build time | M1 | Rasterising the creek and scattering takes about 1.3 s on desktop (more in the browser). Cache the built grid in the save, or bake it to a resource at export |
| SSAO and reflection probes in the Compatibility renderer | M1 | Enabled through the environment per preset, but whether Godot 4.7's Compatibility renderer draws them needs a side-by-side check on a real GPU. Contact shadows currently come from the PBR AO maps and the per-room fill light |
| Wallpaper patterns, lace verandah frieze, dado rails, cornices, ceilings | M1 look test | Planned in M3 (surfaces and exterior detail) |
| Verandahs on sides other than north, and other roof shapes | M1 | The M1 builder does hip roofs and north-facing bullnose verandahs only. Full roof and verandah tools are M3 |
| Furniture triangle budgets | M1 | Some Poly Haven pieces exceed 6,000 triangles (rocking chair 11.9k, oil lamp 7.2k, enamel pot 11.4k). Decimate or swap when the catalogue is built (M4) |
| Puddle decals and wet roofs in rain | M1 | Ground darkens and shines when wet; puddles and roof sheen later |
| Reaching ambientCG downloads | M0 | Optional now that Poly Haven covers M1. Allow `acg-download.struffelproductions.com` if more materials are wanted |
| Doors and windows in diagonal walls; pushing diagonal walls | M2 | Diagonal walls divide rooms and render, but take no openings and can't be pushed yet |
| Pathing through diagonal walls | M2 | `HousePathing` is per tile and ignores diagonals. Fine for M2 tests, refine in M5 with residents |
| Key holders as real residents | M2 | Doors store key holders as labels (Household, Constable, Landlord) until residents exist in M5 |
| Roofs over mixed footprints | M2 | One hip roof covers the top storey. Lower wings, skillions and manual roof pieces come with the M3 roof tools |
| Grid objects for cleared trees | M2 | Building clears trees and grass visually. The WorldGrid objects list should drop them too, for sightlines (M6) |
| Rebuild granularity | M2 | Edits that only change openings, faces or walls without changing rooms rebuild just the touched 8 m chunks. Edits that change the room layout rebuild that storey (still fast at house scale) |
| Ceiling heights per room on mixed floors | M2 | Ceilings sit at the storey height; a room with taller walls than its storey shows a gap until M3 adds ceiling options |
