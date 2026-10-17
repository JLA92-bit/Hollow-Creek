# Hollow Creek - Resident Simulation

The simulation must be **deterministic** (same seed and same inputs give the same results) and **small** (8 to 60 residents). Determinism lets the crime director test plans on a copy of the town, and lets Claude Code run thousands of automated test runs.

## Tick

- One simulation tick is **one game minute**.
- All randomness comes from one seeded RNG owned by the simulation (`SimRng`). Never call Godot's global random functions in simulation code.
- The simulation is plain GDScript classes in `scripts/sim/` with no scene or node dependencies. Scenes only read state and send player commands.
- **Snapshot and restore:** `Sim.snapshot() -> Dictionary` and `Sim.restore(Dictionary)` must round-trip exactly. The crime director relies on this.

## Residents

```text
Resident
  id, first_name, last_name, age, sex, household_id
  job_id, schedule (from job, school or retirement)
  traits: Array[String]        (2 to 4 from the trait list)
  needs: hunger, energy, social, fun (0 to 100, 100 = satisfied)
  money_worry: 0 to 100        (household level, from debt versus income)
  mood: derived from needs, home liveability, recent events
  boot: { size: int, sole: String }
  personal_items: Array[String] (pipe, hairpin, monogrammed handkerchief...)
  secrets: Array[Secret]
  memories: Array[Memory]
  position, current_action, current_route
```

## Traits (starting set of 17)

| Trait | Effect |
|---|---|
| Observant | +0.2 memory confidence, notices traces when walking past them |
| Nosy | Lingers near windows and gossip spots. More memories of other people |
| Gossip | Spreads memories to friends as rumours (marked as second-hand) |
| Honest | Lies only to protect family. Lower Composure when lying |
| Secretive | Lies readily. Higher Composure |
| Proud | Humiliations create large grievances |
| Hot-headed | Grievances turn into incidents faster |
| Greedy | Money pressure counts double |
| Kind | Builds friendships faster, lowers others' grievances |
| Loyal | Lies to protect close friends and family |
| Shy | Social need decays slower but is harder to fill |
| Drinker | Visits the pub most evenings. Drunk residents are poor witnesses |
| Night owl | Awake until midnight |
| Early riser | Awake from 5 am |
| Religious | Attends church, guilt raises their chance of confessing |
| Jealous | Romance with others creates grievances |
| Lonely | Social need decays 1.5x faster. Friendships formed are stronger and more protective |

## Needs and actions

Residents pick actions with **utility scoring**, like The Sims: objects and places advertise what they satisfy, and the resident picks from the top three scores with weighted randomness.

| Need | Decay per hour | Satisfied by |
|---|---|---|
| Hunger | 6 | Stove meal, pub meal, store purchase |
| Energy | 4 awake, recovers 12 asleep | Bed |
| Social | 5 | Chatting, pub, church, events, visiting friends |
| Fun | 4 | Wireless, pub, fishing, cards, gardening, footy |

Score for an action = sum of (need deficit x advertised amount) x trait multipliers x distance penalty x schedule fit.

**Schedules override needs** during work, school and church. Starting jobs:

| Job | Hours | Place |
|---|---|---|
| Mill hand | 07:00 to 15:30 Mon to Sat | Timber mill |
| Shopkeeper | 08:00 to 17:30 Mon to Sat | General store |
| Exchange operator | 08:00 to 20:00, plus night bell calls | Exchange room |
| Publican | 11:00 to 22:00 | Hotel |
| Teacher | 08:30 to 16:00 Mon to Fri | School |
| Seamstress (home) | Flexible | Home |
| Retired | None | - |
| School child | 09:00 to 15:30 Mon to Fri | School |

**Pathfinding:** `AStarGrid2D` over the tile grid. Doors cost 1, mud 2, grass 1.5, roads and footpaths 1. Locked doors are impassable unless the resident holds the key. Residents prefer lit routes at night unless they want to avoid being seen.

## Relationships

Per ordered pair (A towards B):

| Value | Range | Changes from |
|---|---|---|
| friendship | -100 to 100 | Chats, shared events, favours, insults |
| romance | 0 to 100 | Compatible traits, time together, dances |
| respect | -100 to 100 | Work status, public behaviour, debts paid or unpaid |

Labels shown in the UI: Close friend (friendship 60+), Friend (30+), Neutral, Wary (-30 or below), Enemy (-60 or below), Sweethearts (romance 50+).

**Grievances:** a list per resident: `{ target, reason, weight 0 to 100, created_day }`. Created by events such as public humiliation, refused credit, a stolen sweetheart, being reported, losing a job. Weight decays by 2 a day, or 4 if the target apologises or makes amends.

## Secrets

`Secret { id, owner, kind, involves[], exposure_risk 0 to 100, consequence }`

Kinds: debt, affair, past crime, illegal activity (sly grog, poaching), family scandal, hidden identity. Exposure risk rises when someone who knows comes close to telling. Secrets are motives (protect the secret) and reasons to lie in interviews.

## Memories (the heart of investigations)

```text
Memory
  id, observer_id, day, minute
  kind: saw_person | heard_noise | saw_light | saw_object | was_told
  subject_id (if a person), place_tile, place_label
  detail: String               ("wearing a hat", "carrying a sack", "back window")
  confidence: 0 to 1
  source: firsthand | rumour (from resident id)
```

- **Recording:** every simulated minute, each awake resident checks sightlines (see `docs/BUILDING.md`) to residents in range. A memory is recorded when something **notable** happens: a person somewhere unusual for their routine, at an unusual hour, carrying something, entering a building that isn't theirs, or any person within 9 m of an incident location during the incident window.
- **Noises:** smashed windows, shouting and dogs barking create `heard_noise` memories for anyone awake within 15 m, or asleep within 6 m (they wake).
- **Decay:** confidence drops by 0.05 a day. Below 0.2 the memory is forgotten.
- **Rumours:** Gossip residents pass memories to friends as `was_told` with confidence x 0.6.
- **Cap:** keep the 200 most recent memories per resident, plus any memory linked to an open case.

## Statements in interviews

Statements are built from memories, then filtered by what the resident is willing to say.

1. Collect the resident's memories inside the case window (incident time plus or minus 3 hours) and their own whereabouts.
2. For each, decide **honest, omit or lie**:
   - They protect themselves if the truth exposes their crime or a secret.
   - They protect family or a close friend (friendship 60+) if Loyal, or if the person is family.
   - They omit if afraid of the culprit (grievance from culprit, or culprit is Hot-headed and friendship below -30).
   - Otherwise honest.
3. **Lies** must be specific and checkable: a false location ("I was home"), a false time ("I left the pub at nine"), or a denial ("I saw nothing"). The statement keeps a link to the true memory so a contradiction can be detected.
4. **Contradictions** are pieces of evidence that disprove a statement: a record (exchange log, time card), another resident's honest memory, or a physical trace.
5. Statements are rendered from templates with variables, in Australian English with a 1950s country voice. Keep templates in `data/dialogue/statements.json`.

## Town Trust effects on the simulation

| Town Trust | Effect |
|---|---|
| 70+ | Witnesses volunteer information. More applicants |
| 40 to 69 | Normal |
| Below 40 | Witnesses omit more readily. Residents lock doors. Fewer applicants |
| Below 20 | Families start leaving |

## Performance targets (web build)

- 60 residents ticking at 4x speed must stay under 4 ms per frame on a mid-range phone.
- Batch sightline checks: only check residents within 18 m of each other, using a spatial hash.
- Memory recording only on notable events, never every minute for every pair.

## Tests (GUT)

- Determinism: run 7 days from the same seed twice and compare snapshots.
- Snapshot round-trip.
- Sightline cases: through a window, blocked by a wall, blocked by curtains, lit versus unlit at night.
- Statement generation: an honest resident, a Loyal resident protecting a friend, a culprit lying about location.
- Grievance creation and decay.
