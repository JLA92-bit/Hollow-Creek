# Hollow Creek - Building

The player builds everything by hand. Building is also how the player shapes every future crime and investigation, so these rules are shared with the simulation and the crime director.

## The grid

- A logical grid under a semi-realistic 3D world. **1 tile is 1 metre** (1 world unit is 1 metre), with half-tile placement for furniture and free placement when wanted. Walls are procedural meshes on tile edges, with heights set per room. See `docs/ART_DIRECTION.md` for rendering and `docs/HOUSE_BUILDING.md` for the full house design tools.
- Vertical slice map: **144 x 96 tiles** (144 m by 96 m), with a railway siding on the west edge, a creek winding across the south, gentle hills and bushland.
- Each tile stores: `ground` (grass, dirt, gravel, mud, water, sealed road, footpath, floor type), `wet` (0 to 1), `light` (0 to 1, updated each game hour and on changes), `occupant` (building, furniture or object id), `edges` (wall pieces on each of the four sides).

Walls, doors and windows live on **tile edges**, not on tiles. That keeps rooms clean and makes sightlines simple.

## Build tools (costs)

The full tool set, construction stages, home scores, wishes and hidden spaces are in `docs/HOUSE_BUILDING.md`. This table sets the base costs.

| Tool | What it does | Cost |
|---|---|---|
| **Roads** | Dirt road (free, turns to mud in rain), gravel road £2 a tile, footpath £1 a tile, footbridge £30 | As listed |
| **Build** | Walls (weatherboard £2, fibro £2, brick £4 per edge), doors (front £3, back £3, lockable £5), windows (£4, latchable, curtains optional), floors (timber £1, lino £1, concrete £2) | Per piece |
| **Furnish** | Beds, tables, stoves, iceboxes, wireless sets, wardrobes, cash tins and safes, lamps, shelves, counters, pews, bar | £2 to £40 |
| **Lights** | Street lamp £15 (light radius 7 m), verandah lamp £6 (radius 4 m), interior lamps come with furniture | As listed |
| **Outdoors** | Fences £1 an edge, gates £3, trees £2, garden beds £2, water tanks £10, chook pens £8, benches £3, dunny £12 | As listed |
| **Zone and assign** | Mark a building's purpose (home, shop, pub, church, school) and choose which household or business uses it | Free |
| **Demolish** | Refunds 50% of materials. Demolishing an occupied home needs the household rehoused first | - |

**Templates:** one-click starting designs (two-bedroom cottage, workers' hut, general store, small church) that the player can then edit piece by piece.

**Building happens over time.** Placed pieces appear as blueprints first. Builder crews work through them in order at 5 m of wall or 5 square metres of floor each a day. Furniture is delivered next day. The player can reorder the queue.

## Validation

Run validation on every change and show problems in plain words.

- **Room detection:** flood fill enclosed floor areas bounded by walls, doors and windows. A room needs at least one door.
- **Room type** comes from contents: a bed makes a bedroom, a stove and icebox make a kitchen, a counter makes a shop front.
- **Home liveability** (0 to 100): one bed per couple or per child, kitchen, front door, at least one window per room, a dunny or bathroom within 15 m. Below 50, the household's mood drops each day and they may leave.
- **Business requirements:** a store needs a counter, shelves and a cash tin. The pub needs a bar and tables. The telephone exchange needs a switchboard. The church needs pews.

## Doors, windows and locks

These matter a lot for crimes.

| Piece | States | Who changes it |
|---|---|---|
| Door | open, closed, locked | Residents lock based on traits, Town Trust and recent crimes. The player can set a building's default |
| Window | closed and latched, closed and unlatched, open; curtains open or drawn | Residents latch windows at night depending on traits and recent crimes. New windows start **unlatched** |
| Lockable door, safe | locked or unlocked, with a key holder | Keys belong to named residents |

**Entry options for intruders:** unlocked door, unlatched window, forced lock (leaves a trace, needs a tool), smashed window (loud, leaves glass, wakes nearby residents).

## Light

- Daytime: all outdoor tiles fully lit.
- Night: base light 0.1 (moonlight 0.2 on clear nights near full moon).
- Street lamps light a radius of 7 m with a falloff. Verandah lamps 4 m.
- Interior lamps light their room while a resident is awake in it. Light spills 3 m out through windows.
- The light grid is a simple per-tile value used by the simulation and sightline system. The 3D renderer uses real lights and emissive windows (`docs/ART_DIRECTION.md`), and the two must agree: if a tile looks lit, its light value is 0.4 or more.

## Sightlines

Used for witness memories and for the crime director's planning.

- Line of sight is a grid line (Bresenham) from the observer's tile to the target tile.
- **Blocked by:** walls, closed doors, drawn curtains, solid fences, large furniture (wardrobes, shelves), buildings, dense trees.
- **Not blocked by:** windows with curtains open, open doors, low fences, gardens.
- **Seen if** the line is clear, the distance is within range (outdoors: 18 m by day, 9 m at night if the target tile's light is 0.4 or more, otherwise 3 m), and the observer is awake and not busy with a focused action (sleeping, cooking a meal, working the switchboard).
- **Confidence** (0 to 1) depends on distance, light and the observer's traits. Observant +0.2, drunk -0.4, elderly at night -0.1.

## Ground and traces

| Ground | Dry | Wet (after rain, or near the creek) |
|---|---|---|
| Grass | No prints | Faint prints (50% chance per step) |
| Dirt road | Faint prints | Clear prints |
| Mud | Clear prints | Clear prints |
| Gravel, sealed road, footpath | None | None |
| Floors | None | Muddy prints if the walker came from mud in the last 30 m |

Bootprints record the walker's **boot size** and **sole pattern** (work boot, dress shoe, child's shoe, bare feet). They fade after 2 days, or 6 hours of rain.

**This is deliberate:** a player who builds footpaths and gravel roads makes a neater town with fewer clues. A player who leaves the creek path as mud gets more evidence, and more muddy floors.

## Building as investigation

The build view and the investigation view share data, so the player can:
- Toggle a **sightline overlay** from any resident's position at a chosen time during an investigation, to check whether a witness could really have seen what they claim.
- Toggle a **light overlay** for any past hour of the incident night.
- Replay residents' routes as dotted lines once they've been confirmed by evidence.

## Data files

| File | Contents |
|---|---|
| `data/pieces.json` | Every piece: id, category, cost, build time, blocks_sight, blocks_movement, light radius, states |
| `data/templates.json` | Starter building designs as piece lists relative to an origin |
| `data/map_slice.json` | The vertical slice terrain: ground types, creek, trees, railway |
