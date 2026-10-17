# Hollow Creek - House Building (Build and Buy modes)

Building is half the game, and it should offer the control and detail players expect from the best life sims: free design of every room, storey, roof, surface and object, with the ability to fuss over the colour of a single cushion. It also has to work with a mouse and keyboard and on a phone touchscreen, inside a web browser.

The grid, edges, light and sightline rules are in `docs/BUILDING.md`. UI layout reference: `docs/mockups/ui-layout-house-builder.png` (layout only, not the final art).

## Design principles

1. **Ultimate control, easy defaults.** Every detail can be changed, but every tool does something sensible with one click or drag.
2. **Direct manipulation.** Push and pull walls, drag rooms, grab roof handles. Avoid menus and number fields where a handle would do.
3. **Instant feedback.** Live cost, dimensions, snapping guides, validation hints and the effect on home scores as you hover, before you commit.
4. **Nothing is lost.** Unlimited undo and redo for the session, autosave, and a saved blueprint library.
5. **Everything matters.** Pieces change home scores, residents' feelings, sightlines, entry points and hiding spots (the mystery).

## Modes

| Mode | What it's for |
|---|---|
| **Live** | Time runs, residents live, crimes happen. Light building only (place furniture, open and close doors and curtains) |
| **Build** | Structure: rooms, walls, floors, storeys, stairs, roofs, windows, doors, trims, terrain, landscaping. Time pauses by default |
| **Buy** | The furnishing catalogue: furniture, appliances, decor, lighting, plants, outdoor items, with the Design tool for materials and colours |
| **Story building** | Crews build over in-game time with real costs (default in the story) |
| **Sandbox** | A separate save type: unlimited money, instant building, no crime director. For pure designing. Homes can be imported into the story town |

## Structure tools (Build mode)

### Rooms and walls
- **Room tool:** drag a rectangle to make a room. Hold Shift (or a toggle on mobile) for L-shapes and to add to an existing room.
- **Wall tool:** draw straight wall runs along grid lines. **Diagonal walls** at 45 degrees. A **half wall** variant (1.0 m) and a **low wall** (0.6 m).
- **Push and pull:** drag any wall face to resize its room. Furniture against the wall moves with it. Doors and windows stay attached.
- **Move room:** pick up a whole room (or house) and drag or rotate it, with everything inside.
- **Wall height per room:** 2.4 m (fibro and huts), 2.7 m (standard), 3.0 m (period homes), 3.3 m (grand rooms and halls).
- **Openings:** archways (several widths and styles), open doorways, serving hatches between kitchen and dining.
- **Columns and posts:** timber posts, turned verandah posts, brick piers.

### Storeys, levels and stairs
- **Up to 3 storeys plus a cellar.** Most 1952 homes are single-storey, but shops with residences, the hotel, the church tower and later brick homes go higher.
- **Foundations:** stumps (adjustable height 0.3 to 1.8 m, so houses sit level on sloping blocks), concrete slab, or brick base.
- **Stairs:** straight, L-shaped, U-shaped, and ladders to lofts. Choose width, material, balustrade and handrail style. Stairs place on a wall line and auto-cut the floor above.
- **Platforms:** raised floor areas, sunken living rooms (later chapters), and verandah decks at any height.
- **Floor view:** show one storey at a time, with Up and Down buttons, and "show all" for exteriors.
- **Cellars and lofts** (Levels tool): dig a cellar under a room or open a loft in the roof space. Both are hiding spots for the mystery.

### Floors and ceilings
- **Paint floors per tile, per half tile, or per quarter tile in triangles**, so players can make borders, checkerboards and patterns.
- **Rotate and offset** floor patterns (boards running north-south or east-west).
- **Floor materials:** timber boards (several species and widths), lino (checks, marbled, inlaid patterns), carpet, rugs as objects, quarry tiles, concrete, verandah decking.
- **Ceilings:** paint, pressed metal panels (several patterns), timber lining, with optional cornices and ceiling roses. Visible in first-person and walls-up views.

### Windows and doors
- **Place anywhere along a wall**, in quarter-metre steps, with free placement on hold.
- **Raise and lower** windows on the wall (sill height), and **stack** them on tall walls.
- **Sizes:** single, double, triple, and full-height. Bay windows as a special piece.
- **Styles:** double-hung, casement, louvre, leadlight, fanlights over doors, round windows for bathrooms.
- **Extras:** shutters, awnings, flyscreens, flower boxes, curtains and blinds (lace, heavy, venetian, roller), each with their own materials.
- **Doors:** panel, ledge-and-brace (sheds), flyscreen, French doors, Dutch doors, sliding doors (later). Choose swing direction, lock, and **key holders** (who can unlock it).
- **Behaviour settings** per window and door: latched or locked at night, curtains drawn at dusk. These matter for crimes.

### Roofs
- **Auto-roof** from the floor plan as a starting point: gable, hip, skillion or flat.
- **Manual roof pieces:** gable, hip, half-hip, skillion, Dutch gable, and dormers, each with handles to drag the size and pitch.
- **Pitch** (10 to 45 degrees), **overhang**, **ridge height**, and **merge** roofs where they meet.
- **Materials:** corrugated iron (plain, painted, rusty), terracotta tiles, slate, timber shingles.
- **Details:** fascias, barge boards, gable vents, finials, gutters and downpipes (which fill the water tank), chimneys you place on any wall with a fireplace or stove.
- **Roof visibility:** hidden in Cutaway and Down modes, shown in Up mode and at far zoom.

### Exterior details
- **Cladding per wall face:** weatherboard (several profiles), fibro sheet, brick, render, corrugated iron.
- **Trims:** corner boards, window and door architraves, skirting and stump covers, gable trim.
- **Verandahs:** drag along any wall. Choose roof shape (bullnose, skillion, gable), posts, brackets, **cast iron lace** or timber fretwork, rails, lattice, and steps. **Enclose part as a sleep-out** with louvres or casements.
- **Friezes and mouldings** for public buildings (the hotel's balcony lace, the church's gable).

## Surfaces: paint, wallpaper and materials

- **Every wall face is separate:** inside and outside, room by room. Click to paint one face, Shift-click to paint the whole room, Ctrl-click for the whole house.
- **Paint:** the 1950s paint chart (cream, ivory, mint, duck-egg, butter, apricot, rose, sky, sage, white, plus trim colours like Brunswick green and maroon), plus a **custom colour picker**.
- **Wallpaper:** florals, stripes, small prints, plaids and textured papers, each with colour variants.
- **Panelling and tiles:** timber panelling with a dado rail, kitchen and wash-house tiles with optional border rows.
- **Picture rails, dado rails, skirting and cornices** can be added per room, each with its own colour.
- **Eyedropper:** pick any surface or object to copy its exact materials and colours.

## Buy mode (furnishing)

- **Catalogue** browsable by room (kitchen, bedroom, living, bathroom and wash house, outdoor, shop, public) and by function (seating, surfaces, storage, beds, appliances, lighting, decor, plants, plumbing). **Search** by name, and **filter** by price, style tag and colour.
- **Object info:** price, effect on home scores (Comfort, Style, Warmth and so on), needs it satisfies, and any period notes.
- **Placement:** snap to grid, half grid, or **free placement** (hold Alt, or toggle on mobile). Rotate in 45 degree steps, or 15 degrees with a modifier, or freely.
- **Raise and lower** wall-mounted items (pictures, shelves, mirrors, sconces), and place decor **on surfaces** (tables, shelves, mantels) using snap points or freely.
- **Stacking and grouping:** stack items, multi-select, group a set (a dressed dining table) and save it to the library.
- **Lighting design:** ceiling lights, wall lights, lamps, kerosene lamps and candles before electricity. Set **brightness** and **colour temperature** per light.
- **Design tool:** every object has named material slots (for example a chair's "frame" and "seat"). Pick any material from the library (timbers, enamels, chrome, fabrics, leathers) and any colour for each slot. Save favourite styles as swatches.

## Terrain and landscaping

- **Terrain:** raise, lower, flatten and smooth within a lot, with soft brush sizes. Retaining walls where levels change.
- **Ground paint:** grass (dry or green), dirt, gravel, garden soil, mud, river stones, and paving. Ground type matters for bootprints.
- **Plants:** eucalypts, wattles, fruit trees (lemon, apple, plum), hedges, roses, geraniums, vegetables in rows. Plants grow over seasons, and gardens need watering in drought.
- **Fences and gates:** picket, paling, post-and-wire, brick, hedge. Choose height and colour. Gates with latches or locks.
- **Paths:** stepping stones, gravel, brick paving, concrete.
- **Outbuildings:** woodshed, wash house with copper and troughs, dunny, chook pen, water tank on a stand, garage or carport (later), sleep-out cabin.
- **Outdoor items:** rotary clothes line, benches, letterboxes, birdbaths, garden gnomes (fine to include).

## Camera and controls

| Action | Mouse and keyboard | Touch |
|---|---|---|
| Orbit | Right-drag, or Q and E | Two-finger twist |
| Pan | Middle-drag or WASD | Two-finger drag |
| Zoom | Wheel | Pinch |
| Tilt | Shift and wheel | Two-finger vertical drag |
| Place, draw | Left click or drag | Tap, or drag with one finger |
| Rotate object | `,` and `.`, or right-click while holding | Rotate handle on the selection |
| Fine adjust | Arrow keys nudge by a quarter tile | Nudge arrows on the selection |
| Free placement | Hold Alt | "Free" toggle |
| Undo, redo | Ctrl+Z, Ctrl+Y | Buttons in the toolbar |
| Walls up, cutaway, down | Page Up, Page Down, or the toggle | Toggle button |
| Storey up and down | Shift+Page Up/Down | Floor buttons |

Phones get the same tools with larger handles, a radial menu on long-press, and a confirm button for placements. Detailed work is most comfortable on a tablet or computer, and that's fine.

## Construction in story mode

- Placing pieces creates **blueprints** (sky-blue, dashed) and adds them to the **build queue** with total cost and time.
- Materials arrive at the siding the next day. Crews build in **visible stages**: stumps or slab, floor frame, wall frames, roof frame, roofing, cladding and lining, joinery, paint.
- **Weather** delays outdoor stages. **Quality tiers** (Rough, Standard, Fine) change cost, time and Style.
- **Residents can help:** handy residents (Tomasz is a trained cabinetmaker) can do renovations or build furniture for less, which builds friendship.
- A **Sandbox** toggle lets players skip all of this when they just want to design.

## Home scores

Recalculated on every change. Shown live while hovering a piece ("+3 Comfort").

| Score | 0 to 100, built from | Effects |
|---|---|---|
| **Comfort** | Bed and seating quality, room sizes, kitchen completeness, furniture quality | Mood, energy recovery |
| **Style** | Harmony of colours and materials (the palette pairs in `data/palettes.json`), decor, trims, garden, upkeep | Pride, envy, Best Kept Home judging |
| **Warmth** | Stove or fireplace coverage, cladding, lining, ceiling height, roof, room size | Winter mood and illness |
| **Light** | Window area per room, lamps, aspect (morning sun in kitchens) | Mood, some wishes |
| **Space** | Square metres per resident, bedrooms per sleeper | Family arguments, wishes |
| **Privacy** | Bedrooms per couple and child, curtains, fences, distance from neighbours | Romance, secrets kept |
| **Security** | Locks, latched windows, nearby lamps, fences and gates | The crime director's target choice |
| **Value** | Build cost, Style, garden and position | Rates, sale price, applicants |

**Envy:** a Proud or Jealous resident whose neighbour's Style is 25 or more points higher gains a small grievance towards that neighbour. That feeds the crime director.

## Wishes, briefs and life changes

- **Wishes:** each household carries 1 to 3 wishes from traits, jobs and life events (examples in `docs/RESIDENTS.md`). Fulfilled: mood +20 for a week and Town Trust +1. Ignored for 4 weeks: a small grievance against the player.
- **Briefs:** every new family applies with a brief and budget ("Two bedrooms, a big kitchen, near the school. £350."). They react on move-in: delighted, content or disappointed.
- **Life changes:** marriages, births, deaths, lodgers and children growing up create new wishes. Homes are extended and changed over the years.
- **History card:** each home records who built it, when, and every change ("Sleep-out added 1953 for Piotr").

## Sharing designs

- **Blueprint library:** save any room, house or lot. Includes the materials and furniture.
- **Share codes:** export a house as a compact text code or `.hollow` file, and import other players' designs, in Sandbox or (if affordable) in the story. Testers can swap homes.
- **Screenshot mode** for showing off.

## Hidden spaces (the crime connection)

Only exist when the layout creates them. The crime director uses them as hiding spots, and search warrants check them.

| Space | Created by |
|---|---|
| Underfloor | Any house on stumps (more room on sloping blocks) |
| Cellar, loft | The Levels tool |
| Woodpile, woodshed, wash house copper, chook pen | Garden tools |
| Wardrobes, cabinets, under beds | Furniture |
| Loose floorboard | A resident with a secret during a "small repair" event |

## Unlocks over the story

| Chapter | New options |
|---|---|
| Prologue | Cottages, the store, basic furniture, kerosene lamps |
| 1 | Fibro, the hotel and church pieces, cellars, more wallpapers |
| 2 | Mains electricity (electric lights, refrigerators, radiograms, street lights, which change night visibility), brick villas, second storeys for homes |
| 3 | Telephones in homes (changes the exchange log), garages, a picture theatre |

## Technical notes

- **One source of truth:** a `HouseData` resource per building (storeys, rooms, wall edges with per-face surfaces, openings, roofs, stairs, trims, objects). All meshes are generated from it.
- **Mesh rebuilds are local:** changing one wall rebuilds that wall's segment and its neighbours, not the whole house.
- **Merge for speed:** when leaving Build mode, merge static wall, floor and trim meshes per storey into a few meshes by material, to keep draw calls within budget.
- **Material library:** a small set of base PBR materials, tinted by swatch colour in a shared shader, so hundreds of colour options cost no extra textures.
- **Undo** is a command stack of reversible edits on `HouseData`.
- **Validation** runs in the background and shows plain-language hints ("This bedroom has no window").

## Data

| File | Contents |
|---|---|
| `data/pieces.json` | Structural pieces: walls, cladding, openings, stairs, roofs, trims, fences, with costs, stages, score effects and unlocks |
| `data/catalogue.json` | Buy mode objects: model, material slots, default materials, price, score effects, needs, tags, unlocks |
| `data/materials.json` | The material library: base PBR material, default tint, category, cost tier |
| `data/palettes.json` | The paint chart, wallpaper colourways, and harmonious pairs for Style |
| `data/wishes.json`, `data/briefs.json` | Wishes and applicant briefs |
| `user://blueprints/*.json` | Saved designs and imported share codes |

## Tests

- Room tool, push and pull, and move room keep valid closed rooms.
- Stairs cut the right floor opening and connect pathfinding between storeys.
- Roof generation for rectangles, L-shapes and T-shapes.
- Per-face surfaces survive push and pull and undo.
- Score calculations for a reference cottage match expected values.
- Share code round-trip (export then import gives an identical house).
- Hidden spaces appear only when their pieces exist.
