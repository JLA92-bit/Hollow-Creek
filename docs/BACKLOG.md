# Backlog

Work deliberately deferred to keep milestones tight. Each item notes where it came from.

| Item | From | Notes |
|---|---|---|
| Branded HTML loading screen (custom shell with progress bar in Josh's colours) | M0 | Default Godot shell is used, with a white background and navy theme colour. Polish in M10 |
| GitHub Actions CI has not run yet | M0 | Runs on the first push to `main` or `beta`. This session works on a feature branch |
| Per-preset texture sizes at runtime | M1 | Presets list 512, 1024 and 2048 px, but textures are capped at import (1k architecture and ground, 512 props). Ship a low-res texture pack for Low and a 2k pack for High as resource packs (M10) |
| Terrain LOD | M1 | 144 x 96 tiles at 1 m is about 28k triangles, drawn again for each shadow cascade. Coarser far chunks would help phones |
| Map slice build time | M1 | Rasterising the creek and scattering takes about 1.3 s on desktop (more in the browser). Cache the built grid in the save, or bake it to a resource at export |
| SSAO and reflection probes in the Compatibility renderer | M1 | Enabled through the environment per preset, but whether Godot 4.7's Compatibility renderer draws them needs a side-by-side check on a real GPU. Contact shadows currently come from the PBR AO maps and the per-room fill light |
| Furniture triangle budgets | M1 | Some Poly Haven pieces exceed 6,000 triangles (rocking chair 11.9k, oil lamp 7.2k, enamel pot 11.4k). Decimate or swap when the catalogue is built (M4) |
| Puddle decals and wet roofs in rain | M1 | Ground darkens and shines when wet; puddles and roof sheen later |
| Reaching ambientCG downloads | M0 | Optional now that Poly Haven covers M1. Allow `acg-download.struffelproductions.com` if more materials are wanted |
| Doors and windows in diagonal walls; pushing diagonal walls | M2 | Diagonal walls divide rooms and render, but take no openings and can't be pushed yet |
| Pathing through diagonal walls | M2 | `HousePathing` is per tile and ignores diagonals. Fine for M2 tests, refine in M5 with residents |
| Key holders as real residents | M2 | Doors store key holders as labels (Household, Constable, Landlord) until residents exist in M5 |
| Grid objects for cleared trees | M2 | Building clears trees and grass visually. The WorldGrid objects list should drop them too, for sightlines (M6) |
| Rebuild granularity | M2 | Edits that only change openings, faces or walls without changing rooms rebuild just the touched 8 m chunks. Edits that change the room layout rebuild that storey (still fast at house scale) |
| Ceiling heights per room on mixed floors | M2 | Ceilings sit at the storey height; a room with taller walls than its storey shows a gap until M3 adds ceiling options |
| Settings on the title menu | M0 | Sandbox arrived in M3; Settings in M9 |
| Dormers and lofts | M3 | Roof pieces and cellars are in. Dormers (a small gable through a slope with a window) and lofts in the roof space (a hiding spot for the mystery) are wanted before the crime milestones (M8) |
| Valley flashing where roofs meet | M3 | Equal-pitch pieces intersect cleanly but show no valley iron. A strip along the intersection line would finish it |
| Roof handles as on-screen gizmos | M3 | Pitch and edges are dragged directly on the roof. Visible grab handles (as in the mockup) would help on phones |
| Turning designs while placing | M3 | Share codes and blueprints place in their saved orientation. Rotating a whole HouseData (walls, openings, stairs, roof, verandahs, garden) by 90 degrees is a contained follow-up |
| Room and lot blueprints | M3 | The library saves whole houses with their gardens. Saving a single room is listed in the design doc |
| Gable verandahs on long walls | M3 | The gable runs across the whole verandah and gets shallow on long walls. Typical Federation style is a skillion with a small gable over the steps |
| Browser .hollow import on phones | M3 | Uses a JavaScript file input polled from GDScript. Pasting a code works everywhere; the file picker needs a check on iOS Safari and Android Chrome |
| Terrain beyond a house's lot | M3 | Landscaping belongs to a house and reaches 12 m from it. Town-wide earthworks (roads, drains) come with the Roads tool |
| Trees on raised or lowered ground | M3 | Trees and shrubs keep the height they were planted at. Building clears them from the yard, so it only shows if terrain is edited right at the bush edge |
| Story construction for M3 pieces | M3 | Roofs, verandahs and gardens cost money now. Build stages, materials at the siding and crews come in M4 |
| Handy residents and furniture-making | M4 | Residents (Tomasz the cabinetmaker) doing renovations or making furniture for less, building friendship. Needs residents (M5) |
| Dressed groups in the library | M4 | Multi-select moves and turns groups; saving a dressed dining table as a library set is still to come |
| Electricity for the town | M4 | Electric lights and the wireless work anywhere for now. A story flag should hold them back until the power comes, with kerosene before |
| Wall frames with openings | M4 | Studs run straight across where doors and windows will go. Trimmers and lintels would read better |
| Construction for gardens and furniture deliveries | M4 | Garden work is one stage at the end, and furniture arrives with joinery. A separate delivery cart and gardener visits would be nicer |
| Frank's shop sign and counter | M5 | His wish needs `shop_sign` and `shop_counter` catalogue pieces that don't exist yet. Add them with the hotel and church pieces |
| Agnes's shoes, hair and face | M5 | The MPFB test character has painted feet, hair painted on the scalp with a bun, and no facial shapes. Model shoes and hair cards, and add the six expressions, before the other residents go through the pipeline |
| MPFB for every resident | M5 | Only Agnes uses the pipeline; the other nine are placeholder mannequins coloured from their appearance lines |
| Chapter 1 applicants | M5 | The founding families apply at the start. Bert, Father Reilly, Arthur, Clara and the Russos come when the town reaches six households (story chapters, M7) |
| Life changes and envy | M5 | Marriages, births, lodgers and children growing up making new wishes, and Proud or Jealous residents envying a neighbour's Style, are designed but not simulated yet |
| Residents lighting lamps | M5 | Houses are dark inside on summer evenings unless lamps are placed and the day/night system lights them. Residents should light and blow out their own lamps (feeds sightlines in M6) |
| Walking speed versus clock speed | M5 | People walk at 1.2 m/s of game time, so at 1x a 60 m trip takes under a second of real time and the walk animation runs fast. Fine for a town sim; a slower "follow" speed could help when watching one person |
| Bed orientation | M5 | Sleepers lie along the bed's own direction, but the head end isn't checked against pillows on every model |
| Moving a family out | M5 | Families can move in but not out or between houses, and demolishing a lived-in house isn't blocked yet |
