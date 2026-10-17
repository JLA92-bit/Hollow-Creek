# Hollow Creek - Decisions

Claude Code uses the default for anything not marked "needs Josh". For "needs Josh" items it uses the default until the listed milestone, then asks.

| # | Decision | Default | Status | Needed by |
|---|---|---|---|---|
| 1 | Engine and language | Godot 4.7.2, GDScript | Decided | - |
| 2 | Platform | Web and phones only: single-threaded web build, PWA, landscape | Decided | - |
| 3 | Look | Warm semi-realism within the web renderer (`docs/ART_DIRECTION.md`) | Decided | - |
| 4 | Build depth | Life-sim level: storeys, stairs, per-face surfaces, roofs, Buy mode with Design tool, Sandbox (`docs/HOUSE_BUILDING.md`) | Decided | - |
| 5 | Art sources | ambientCG and Poly Haven (CC0), procedural architecture, Blender-scripted 1950s props | Decided | - |
| 6 | Network access to Poly Haven and ambientCG | Check in M0. If blocked, Josh downloads batches | **Needs Josh** if blocked | M0 |
| 7 | Residents | MPFB characters (CC0) | Decided | - |
| 8 | Animations | Mixamo plus Quaternius Universal Animation Library | **Needs Josh** to download Mixamo animations | M9 |
| 9 | Interview portraits | Live 3D close-ups. Gemini portraits optional | Default | - |
| 10 | Approve the look | Screenshots from the M1 look test scene | **Needs Josh** | End of M1 |
| 11 | Hosting | GitHub Pages on `play.<your site>` (`docs/DEPLOY.md`) | **Needs Josh** | M10 |
| 12 | Tester access | Unlisted link | **Needs Josh** | M10 |
| 13 | Feedback form link | None until provided | **Needs Josh** | M10 |
| 14 | Analytics | None. Feedback form only | Default | - |
| 15 | Monetisation | None while testing | Default | - |
| 16 | App store wrappers | Not planned | **Needs Josh** | M12 |
| 17 | 3D texture format | Lossy WebP in the pack, size-capped (1k architecture and ground, 512 props), instead of Basis Universal. Godot 4.7's Basis encoder is UASTC-only: about 2.2 MB per 1k texture even with RDO, against 0.3 MB for WebP, which would break the 40 MB first download. Trade-off: WebP decodes to uncompressed RGBA in GPU memory. Revisit with per-preset texture packs (`docs/BACKLOG.md`) | Default (M1) | - |
| 18 | Season of the opening week | The slice opens on Mon 2 June 1952 (winter). Daylight keyframes use a generic temperate day (sunrise about 6:30 am, sunset about 6 pm) until seasons arrive in Chapter 1 | Default (M1) | - |

## Josh's answers

Write answers here and Claude Code will pick them up.

- Poly Haven and ambientCG reachable from Claude Code (yes or no):
- Look approved after M1 (yes, or what to change):
- Mixamo animations downloaded:
- Site address and hosting option:
- Tester access:
- Feedback form link:
