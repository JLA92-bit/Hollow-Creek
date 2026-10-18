# Progress

Newest milestone first. Build sizes are raw bytes, with gzip -9 in brackets.

## M6 - Light, sightlines and memories (in progress)

Core done: light grid, sight map, memories, noises, gossip, bootprints, records, debug overlays, night demo (12 of 12 headless). 168 GUT tests pass. Browser run and write-up still to do; see `docs/HANDOVER.md`.

## M5 - Residents (done)

**What works**
- **Simulation (`scripts/sim/`):** deterministic, plain classes, all randomness from `SimRng`.
  - `SimTown` is one walk graph over the valley floor and every storey of every house (stairs included; walls without doors block). Ground costs follow `docs/SIMULATION.md`.
  - Places advertise what they satisfy: beds, stoves, ice chests, the wireless, good chairs, vegie patches, the shop, the exchange, the mill and the creek bank.
  - `Sim` ticks once a game minute: needs (hunger, energy, social, fun) and mood, traits, jobs and schedules, sleep, utility choices among the top three, visits to friends, chatting, relationships (friend, close friend, sweethearts, enemy), grievances that fade 2 a day, wages and household costs on Mondays.
  - Snapshots are exact: numbers are kept to 1/1024 and positions to 1/64 m, so a restored town carries on identically.
- **Founding residents (`data/residents.json`):** the ten residents from `docs/RESIDENTS.md` with jobs, households, relationships, grievances, secrets, wishes and the Chapter 1 applicants (not arriving yet).
- **People in the valley:**
  - Placeholder mannequins (`tools/characters/make_mannequins.py`): dress and trouser builds with idle, walk and sit, coloured per resident from their appearance line ("grey hair in a bun, cardigan and apron").
  - **Agnes through the MPFB pipeline** (`tools/characters/make_agnes.py`): a 67-year-old woman built from MPFB's CC0 base mesh, its tights and skirt helpers as her cardigan, stockings and skirt, and the game-engine rig. 9,000 triangles at LOD0, 2,800 at LOD1 (Low quality), same animations.
  - Figures walk their routes smoothly between ticks, stand at the front of the stove or ice chest, sit in chairs, lie in bed, and stand on floors indoors and the ground outside.
- **Families and their homes (`HomeLife`):**
  - The three founding families wait at the siding with a brief ("Two bedrooms and a kitchen, handy to the mill. Two quid a week and not a penny more.").
  - The **Residents** list (P, or Residents on the toolbar) offers each family any finished, empty house and says beforehand how they'd take it. They move in delighted, content or disappointed, against bedrooms, beds, rooms, the rent they can manage, and things they hoped for. Disappointment becomes a grievance against the Administrator.
  - **Wishes** are checked against the house as built every night: a table in a room with an east window, a sleep-out with a bed, a shed, 4 m² of vegie patch, an armchair by the fire. A met wish lifts the owner's mood for a week and earns Town Trust; one ignored for four weeks turns into a grievance.
  - **Rent** (£1 to £4 a week, from the home scores) comes in on Mondays. Home scores feed mood.
  - **History card:** each home records when it was built and who moved in.
- **Resident card** (click anyone, layout from the town mockup): name, age and job, traits, needs and mood bars, what they're doing ("Off to work at the mill", "Visiting Marge"), home, rent and wishes, the people who matter to them, recent news, and Follow.

**Tests:** 146 GUT tests, all passing.
- The same seed gives identical 7-day snapshots twice; a snapshot restored mid-week carries on identically.
- Routines: mill hands at the mill and the shopkeeper in the shop at 10 am, everyone asleep at 3 am, the night owls up at 11 pm. Nobody starves; friends visit; grievances fade.
- Wishes against real houses (sewing light, sleep-out, vegie area, shed, warm sitting room), move-in reactions, rent, the history card, wish moods, Town Trust and grievances, and residents' looks.

**Acceptance demo** (`scenes/resident_ui/residents_demo.gd`; `?scene=residents_demo`). In a new story game:
- Agnes lives alone at first, drawn with her MPFB model (8,999 triangles) and animated, on Medium.
- Three houses go up and the Haywards, Pikes and Kowalskis are offered them. The Haywards are delighted; the Pikes and Kowalskis are content (a lovely home, but £3 a week is more than they hoped).
- Two vegie beds are dug for Marge: her wish comes true overnight and Town Trust rises.
- Tuesday: somebody is out walking at 6:40 am; Len and Tomasz are at the mill and Frank and Edna at the store at 10; everyone is in bed at 3 am.
- Monday's rent (£9) is banked, and a save and load leaves the town exactly as it was.
- **Result:** 20 of 20 checks pass.

**Screenshots:** `docs/screens/m5/`:
- `m5_01`: Agnes in her kitchen, with her card
- `m5_02`: the Residents list with the families' briefs and offers
- `m5_03`: walking to work
- `m5_04`: Edna at the exchange
- `m5_05`: evening at home
- `m5_06`: 3 am
- `m5_07`: Marge cooking, with her wish met

**Build sizes**

| File | Raw | gzip -9 |
|---|---|---|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 34,616,200 | 28,066,461 |
| **First download** | | **about 38.2 MB** (budget 40 MB) |

**Browser run:** `node tools/look_test.mjs --scene residents_demo --out docs/screens/m5 --dpr 1.5` passed 20 of 20 checks in headless Chromium (SwiftShader) with no console errors. Seven screenshots are in `docs/screens/m5/` (`m5_01_agnes` to `m5_07_marge`). It takes about 25 minutes. The web smoke test is still to run.

**Performance** (headless desktop): a game hour of all ten residents (60 ticks) takes about 0.2 to 0.3 ms per tick batch; building the town's walk graph takes a fraction of a second. Agnes adds one skinned mesh of 9,000 triangles at Medium.

**Known issues** (more in `docs/BACKLOG.md`)
- Agnes has painted-on feet and hair, and no facial shapes; the other residents are still mannequins.
- Frank's wish (a shop sign and a bigger counter) can't be met until those pieces are in the catalogue.
- Walking is fast at 1x (1.2 m/s of game time is about 5 m/s on screen), so the walk animation runs quickly.
- Families can't yet move out or between houses.

## M4 - Buy mode and construction (done)

**What works**
- **Catalogue (`data/catalogue.json`, `Catalogue`):** 31 pieces.
  - 15 are Poly Haven models.
  - 16 are 1950s props modelled with headless Blender (`tools/props/make_props.py`; `bash tools/props/setup_blender.sh` installs `bpy`): wood stove, ice chest, wireless set, wall telephone, laminex table, chrome kitchen chair, iron bedstead, wardrobe, chest of drawers, washstand, clawfoot bath, settee, sink and drainer, pendant light, standard lamp and candle.
  - Rooms (living, bedroom, kitchen, bathroom, outdoor) and functions (seating, surfaces, storage, beds, appliances, lighting, decor, plumbing). Search, room and function filters, price and period notes.
- **Placement (Furnish tool, U, or Furnish on the toolbar):**
  - Floor pieces stay inside rooms and out of each other's way. Wall pieces hang on the nearest inside wall facing into the room, and can be raised and lowered. Ceiling pieces hang at ceiling height.
  - Surface pieces stand on tables, cabinets and the ice chest and ride along when those move. Anything can be stacked with Stack, such as fruit crates.
  - Snap to 0.5 m, 0.25 m or free (Alt). Turn in 45 degree steps (15 with Shift).
  - Live labels show price and the change to the home scores ("+4 Comfort, +3 Style").
  - Select by clicking; Ctrl-click to add to the selection. Drag to move; arrows nudge (Shift for fine); , and . turn a piece or a whole group about its centre; Delete removes a piece and whatever stands on it.
- **Design tool:**
  - Every piece has named material slots: our props have "timber", "enamel", "chrome", "fabric", "laminex" and so on, and Poly Haven pieces their own material, which can be tinted.
  - Choose any library material in the slot's family (four timbers, enamel, chrome, nickel, brass, cast iron, laminex, vinyl, bakelite, marble, china, mirror, linen, gingham, leather, velvet, chenille) and any colour, including a mixed colour.
  - Save a piece's look as a named style and apply it to anything with the same slots.
- **Lighting:** lamps, candles and lights give real light in their colour temperature (Flame 1900 K, Warm 2700 K, Neutral 3500 K, Daylight 5000 K), with brightness per lamp. Kerosene and candle light flickers.
- **Home scores (`HomeScores`):** Comfort, Style, Warmth, Light, Space, Privacy and Security, each 0 to 100.
  - Built from furniture, kitchen completeness, beds per sleeper, colour pairs from the palette, wallpaper and lace, garden and fences, stove and fireplace coverage, the roof, brick walls, window area per room, morning sun in the kitchen, curtains, locks, latches and gates.
  - Shown as bars in the Furnish panel and previewed on every placement.
- **Construction in the story (`Construction`):**
  - Whatever you design is the plan. The house as it stands lags behind it.
  - Materials ordered today arrive at the siding at 7 am tomorrow; until then the new work shows as sky-blue blueprints.
  - Two crews then work 8 am to 4 pm, Monday to Saturday, at 5 units a day each (5 m of wall or 5 m² of floor). They go through demolition, stumps, floor frame, floors, wall frames, roof frame (rafters), roofing, cladding and lining (raw boards and unpainted linings), doors and windows, and paint and garden.
  - Each stage is drawn as it stands, with a toast as it starts.
  - Rain slows outdoor stages to 30%. Rough, Standard and Fine work change cost (0.8x, 1x, 1.3x), time (faster, normal, slower) and Style (-6, 0, +6).
  - New furniture is carried in once the doors and windows are in.
  - The house panel shows the stage, percentage and days left. Undo and redo are building work too. Sandbox still builds instantly.

**Tests:** 131 GUT tests, all passing.
- Catalogue search and filters, and every item's model and slots.
- Floor, wall, ceiling and surface placement, riders, stacking, group moves, design slots, styles and lamps.
- Home scores for a bare shell and a furnished cottage, and score inputs and previews.
- Construction work, stage drawing, demolition order, days to build, rain, Sundays and quality tiers.

**Acceptance demo** (`scenes/build_ui/construction_demo.gd`; `?scene=construction_demo`). In a story game:
- **Design:** a three-room cottage drawn with the real tools goes on the build queue as blueprints.
- **Furnishing:** 15 pieces are bought with the Furnish tool. The wireless lands on the table, the bed gets a rose chenille spread, and the table top turns blue.
- **Scores:** Comfort 94, Style 49, Warmth 71, Light 83, Space 100, Privacy 85, Security 40.
- **Building:** the clock is run and the crews build it over 16 in-game days, stage by stage. The finished house matches the design exactly.
- **Result:** 13 of 13 checks pass.

**Screenshots:** `docs/screens/m4/`:
- `m4_01`: blueprints
- `m4_02`: floor frame
- `m4_03`: wall frames
- `m4_04`: roof frame and roofing
- `m4_05`: cladding
- `m4_06`: finished
- `m4_07`: furnished, at dusk

**Build sizes**

| File | Raw | gzip -9 |
|---|---|---|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 34,213,212 | 27,670,171 |
| **First download** | | **about 37.75 MB** (budget 40 MB) |

The browser run (`node tools/look_test.mjs --scene construction_demo --out docs/screens/m4`) passed 13 of 13 checks in headless Chromium with no console errors.

**Known issues** (more in `docs/BACKLOG.md`)
- Handy residents doing renovations and building furniture wait for residents in M5.
- No dressed groups saved to the library yet; groups move and turn together.
- Electric lights work everywhere for now; the town's electricity arrives with a later chapter.
- Wall frames ignore door and window openings until joinery (the studs run straight across).

## M3 - Build detail (done)

**What works**
- **Surfaces (Paint tool, P):**
  - Every wall face is separate. Click one face, Shift for the room (or that storey's outside), Ctrl for the whole house (or every outside wall), or pick the scope on the panel.
  - The 1950s paint chart (`data/palettes.json`): 12 wall colours and 8 trim colours, plus a custom colour picker.
  - Wallpapers: cabbage roses, Regency stripe, sprig, tartan and garden trellis, each in two or three colourways. One generated mask per pattern (`tools/textures/make_wallpapers.py`) is coloured by a shader, so colourways cost nothing to download.
  - Linings (kitchen and wash-house tiles, VJ panelling) and claddings (weatherboard, fibro, red brick, render, corrugated iron).
  - "Lower wall" puts tiles or panelling to dado height (0.9, 1.0 or 1.2 m) with a dado rail, and keeps the paint or paper above.
  - Picture rails (on by default for tall rooms) and cornices per room. The eyedropper (I) picks up any face's finish.
- **Roofs (Roof tool, O):**
  - Shapes: hip, gable, half-hip, Dutch gable, skillion and flat (`scripts/build/roofs.gd`). Pitch runs 10 to 45 degrees, with eaves of 0.3 to 0.9 m.
  - Roofing: galvanised iron, iron painted red or green, second-hand iron, terracotta tiles, slate and timber shingles.
  - Auto-roof splits the plan into rectangles. Wings reach into the main roof so they meet in valleys, and the parts of a lower storey beyond the one above get lean-to skillions against its wall. The roof follows the plan as you build until you change a piece by hand.
  - Draw extra pieces, or change one: drag on it for pitch, drag near an edge to stretch it, turn the ridge, or change shape and roofing.
  - Fascias, gutters, barge boards, ridge and hip cappings, finials, gable vents, lined eaves, and gables clad to match the walls.
  - Chimneys go on any wall. Inside walls get a stack through the roof; outside walls get a full brick chimney from the ground. Stacks always clear the roof by 0.6 m.
- **Exterior (Verandah tool, E):**
  - Click any outside wall for a verandah along it, or drag for part of it.
  - Roofs: bullnose, skillion or gable. Posts: square, turned or cast iron. Cast iron lace or timber fretwork friezes and brackets. Timber or lace rails, lattice underneath, and steps wherever you click.
  - Enclose part as a sleep-out: a real room with louvres, under a skillion.
  - Corner boards and trims in the house's trim colour.
- **Landscaping (Terrain, Garden and Fence tools):**
  - Garden work belongs to a house and reaches 12 m round it, so it travels in share codes.
  - Terrain: raise, lower, flatten and smooth with three brush sizes. The ground under the house stays below its floor. Paint lawn, dirt paths, gravel or turned-soil garden beds.
  - Plants (`data/garden.json`): roses, hydrangeas, lavender, agapanthus, geraniums, box hedge, a vegie patch, and lemon, apple and wattle trees. Leaf cards are generated by `tools/textures/make_garden.py`.
  - Outbuildings: dunny, woodshed, wash house with copper chimney, chook pen, and water tank on a stand.
  - Yard: Hills Hoist, letterbox, bench, birdbath, wheelbarrow and woodpile.
  - Fences: picket, paling, post and wire, corrugated iron and cypress hedge, dragged along the grid. Click a metre of fence to turn it into a gate.
  - The bush is cleared back to the fence line.
- **Sandbox:** its own save type and autosave slot on the title menu, with unlimited money ("Sandbox" in the money chip) and instant building.
- **Share codes:**
  - Share (house panel) shows a `HOLLOW1:` text code for the house and garden, with Copy and Save .hollow file (downloads on the web).
  - Library lists saved designs to place, copy or delete, and imports a pasted code or a `.hollow` file.
  - A design follows the pointer until you click. In the story it costs roughly what building it would.
- **Photo mode (F2, or Photo):** hides the interface. Enter or Take photo saves a PNG (downloaded on the web).

**Tests:** 113 GUT tests (4,103 asserts), all passing.
- New tests cover surfaces, roof geometry (every shape covers its plan with no holes or steps), auto-roof for rectangles, L and T plans and two storeys, follow-the-plan and hand edits, and chimneys.
- They also cover verandahs on every side, steps, sleep-outs, terrain limits, paths, plants, sheds, fences and gates, share code round trips, broken codes, and the library.

**Acceptance demo** (`scenes/build_ui/sandbox_demo.gd`; `?scene=sandbox_demo`). It drives the real tools with mouse events in a Sandbox save.
- **The cottage:** four bare rooms with doors and windows, then wallpaper in the parlour and bedroom and kitchen tiles under mint paint.
- **Outside:** cream weatherboards with Brunswick green trims, a terracotta hip roof and a chimney, and a lace verandah with turned posts, rails, lattice and steps.
- **The garden:** a gravel path, garden beds and a rise in the front garden; 21 plants, sheds and yard things; 88 m of fences with a gate on the path.
- **The share code:** the design is exported, a fresh Sandbox save is started, and the code is placed there. The copy is identical.
- **Result:** 18 of 18 checks pass, headless and in Chromium.

**Screenshots:** `docs/screens/m3/`:
- `m3_01`: the bare cottage
- `m3_02`: interiors
- `m3_03`: the finished front
- `m3_04`: the back yard
- `m3_05`: the verandah up close
- `m3_06`: the imported copy

**Build sizes**

| File | Raw | gzip -9 |
|---|---|---|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 33,801,020 | 27,288,668 |
| **First download** | | **about 37.4 MB** (budget 40 MB) |

To stay under budget, the new materials' normal and ORM maps import at 512 px (`detail_limit` in the manifest), shingles reuse the slate texture tinted, and garden cards are 256 px.

**Performance** (headless desktop, materials warm; the browser is several times slower)
- A four-room cottage with a verandah and 20 garden items rebuilds its roof in 5 ms, its storey structure (floors, stumps, verandah deck, posts, lace and rails) in 28 ms, and its garden in 34 ms.
- A share code round trip takes 5 ms; a finished cottage and garden is about 2,800 characters.

**Known issues** (more in `docs/BACKLOG.md`)
- No dormers or lofts yet; cellars work as a storey below.
- Roofs that meet show their intersection but have no valley flashing.
- A gabled verandah along a long wall comes out low-pitched.
- Designs can't be turned while placing.
- Importing a `.hollow` file in the browser uses a JavaScript file picker that hasn't been tried on a real phone.

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
