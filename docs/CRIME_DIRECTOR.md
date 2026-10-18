# Hollow Creek - The Crime Director

The crime director turns tension in the simulation into incidents that are **real** (they actually happen in the sim, leaving genuine traces and memories), **fair** (solvable from evidence the player can find) and **interesting** (with at least one believable red herring).

This is the most important system in the game. Build it with tests from day one.

## Overview

```text
every game day at 06:00:
  if drama budget allows and no case is open:
    candidates = find_motives()
    if any candidate passes its threshold:
      plans = generate_plans(candidates, n = 12)
      for each plan: simulate it on a snapshot of the town, then score it
      pick the best plan that passes the solvability check
      schedule it for its chosen night
    otherwise: do nothing (a quiet week is fine)
```

## 1. Finding motives

For each resident, compute pressure towards each possible crime:

| Motive | Pressure source | Typical crimes |
|---|---|---|
| Money | money_worry x (Greedy ? 2 : 1) | Theft, poaching, sly grog |
| Grievance | Grievance weight against a target x (Hot-headed ? 1.5 : 1) x (Proud ? 1.3 : 1) | Vandalism, theft from the target, arson (later) |
| Jealousy | Romance rivalry x (Jealous ? 2 : 1) | Vandalism, threats |
| Cover-up | Secret exposure_risk x (Secretive ? 1.3 : 1) | Theft of evidence, arson (later) |

Each candidate is `{culprit, target, motive, crime_type, pressure}`. A candidate is eligible when pressure is above the threshold for its crime type (minor 60, major 85) and the culprit's Honest trait doesn't veto it (Honest residents only commit crimes at pressure 90+).

## 2. Generating plans

For each eligible candidate, generate several concrete plans by varying:
- **Night:** the next 1 to 4 nights, preferring rain (more prints, fewer people out) or events (the dance, when homes are empty).
- **Time window:** when the target place is empty or asleep and the culprit's own routine has a gap.
- **Route:** pathfind home to target and back. Variants: shortest, darkest (avoids light 0.4+), quietest (avoids windows of awake residents).
- **Entry:** whichever the layout allows: unlocked door, unlatched window, forced lock (needs a tool the culprit owns), smashed window.
- **Disposal:** where the stolen item or evidence goes (the culprit's hiding spot, buried, thrown in the creek, sold out of town).
- **Cover story:** a false alibi the culprit will give, chosen from places they could plausibly have been.

## 3. Simulating each plan

For each plan:
1. Snapshot the town.
2. Inject the plan into the culprit's schedule and run the simulation through the night and the morning after.
3. Everything that happens is real: bootprints on wet ground, the window left open, the noise of breaking glass, residents who happen to be awake and see a figure under a lamp, the exchange operator's log.
4. Record the outcome: traces created, memories formed, records changed, whether the crime succeeded, whether someone intervened.
5. Restore the snapshot.

## 4. The evidence graph and solvability

Build a graph of **discoverable facts** from the simulated outcome:

| Fact source | Examples |
|---|---|
| Scene traces | Entry point, bootprint size and sole, dropped personal item, missing object |
| Records | Exchange log entries, credit ledger, time cards, pub tab |
| Honest memories | "Saw a man in a hat at 9:12 pm behind the store" |
| Contradictable lies | The culprit's alibi, plus anything others lie about |
| Property search | The stolen item at the culprit's hiding spot |

Each fact supports one or more **propositions** about each suspect:
- `opportunity(X)`: X was near the scene during the window, or X's alibi is false.
- `means(X)`: the entry and traces fit X (boot size, height, has the tool, has the key).
- `motive(X)`: a discoverable record or statement shows X's reason.
- `lie(X)`: at least one of X's statements is contradicted by a discoverable fact.

**A plan is solvable when:**
1. The culprit can be shown to satisfy all four propositions from discoverable facts.
2. No other resident can be shown to satisfy all four.
3. Every proposition for the culprit has at least one supporting fact that doesn't rely on a single witness of confidence below 0.5.
4. The total number of discoverable facts is between 5 and 12 (enough to be interesting, not overwhelming).

**A plan is interesting when** at least one other resident (the red herring) can be shown to satisfy two or three propositions. For example, Davey Pike was out late with muddy boots, but they're the wrong size.

**Scoring:** solvable plans score on interest (red herrings 2 or 3 propositions deep), variety (different from the last three incidents), drama (involves residents the player has followed recently) and fit with the chapter. Unsolvable plans are discarded. If none of the 12 plans is solvable, generate 12 more. If still none, cancel the incident and lower the culprit's pressure slightly. **Never ship an unsolvable case.**

## 5. Running the incident

The chosen plan runs for real in the live simulation. If the player changes something before the night (builds a lamp, latches the window), re-plan at the start of the night using the same process. The town genuinely responds to the player.

At discovery (usually the next morning, when the victim notices), raise the incident alert and open a case with:
- `case_id`, crime type, victim, location, time window, the discoverable fact list (hidden from the player), suspects (every resident who satisfies one proposition or more).

## 6. Authored cases

Authored cases (such as `docs/CASE_01_LOW_WATER.md`) fix the **who, why and what**, plus some authored clues, but still let the director choose the **when, where and how** from the player's actual layout. Each authored case defines:
- Culprit, victim, motive and crime, with authored backstory facts.
- **Required beats** (for example "the victim phones the culprit's house before going out").
- **Authored clues** that always exist (records, letters, an object).
- **Fallback clues** to add if the player's layout removes an emergent one (for example, no mud on the route means no bootprints, so the fallback is a torn sleeve on a fence).
- The red herring suspects and why they look guilty.

The director then plans and simulates as normal, and runs the same solvability check with authored clues included.

## 7. Consequences

After the accusation, apply the outcome from `docs/GAME_DESIGN.md` and update the simulation:
- **Charged:** the culprit leaves for the district court for 2 to 8 weeks, depending on the crime. Household income drops. The family's friendship towards the player drops. The victim's household likes the player more.
- **Restitution:** the culprit repays and does community work. The culprit's grievance against the victim resets. The victim may resent the softness.
- **Wrong accusation:** the accused gains a strong grievance against the player and the accuser. The real culprit's pressure halves and their memory records "got away with it", which makes repeat offending more likely.
- **Town reaction:** residents lock doors and latch windows more often for 2 weeks. Lamps get requested.

## 8. Testing (essential)

Write a headless soak test: `tools/director_soak.gd`, run with `tools/bin/godot --headless --path . -s tools/director_soak.gd -- --seeds 500`.

For each seed: generate a random small town from the slice templates, run 28 days, and record every incident. Report:

| Metric | Target |
|---|---|
| Incidents shipped that are unsolvable | **0** |
| Plans discarded as unsolvable | Report only |
| Average discoverable facts per case | 6 to 9 |
| Cases with at least one red herring | 80% or more |
| Average director time per planning day | Under 300 ms on desktop |
| Determinism (same seed twice) | Identical |

Also write a **solver bot** that plays investigations using only discoverable facts and the deduction rules. The bot must solve every shipped case, and must fail to convict the red herring when it plays honestly. Run it in CI.


## Implementation notes (M8)

Where the code differs from the plan above, and why.

- **Planning happens at nightfall.** At 06:00 the director only finds who's under pressure and whether the drama budget allows an incident (`Director.morning`). At 21:00 it generates plans, tries them on snapshots, and starts the best fair one (`Director.nightfall`). This is the "re-plan at the start of the night" step, and it means the town the plan was tested on is the town it runs in. The trial and the live run use the same `PlanRunner`, so they match exactly (tested).
- **Shared prefix.** Plans start at 23:30, 1:00 or 2:30. The quiet hours before each start are simulated once and snapshotted, so 12 plans cost about 2 hours of simulation instead of 12 nights.
- **Fairness is decided by playing the case.** `CaseBuilder` turns what really happened into an investigation case with a `proof` table for every resident, and `Solvability` has the solver bot play it with only discoverable facts. Solvable means the culprit meets all four requirements, nobody else can, and there are 5 to 24 discoverable facts. Interesting means somebody else meets two or three (a red herring).
- **Where red herrings come from.** In three plans out of four a resident with a night-time secret (`night_out` in `data/residents.json`) is out near the scene, leaves a personal item, and lies about it. They meet opportunity and a broken lie, and motive if they bear the victim a grudge, but not means.
- **Plan variety:** careless plans drop a personal item and make a noise; others rely on whoever happens to be awake. On dry nights most plans leave nothing to find and are discarded, which is correct; the director then tries 12 more, and if none is fair the night passes quietly and the culprit's pressure drops by 10.
- **Consequences** are in `Director.apply_outcome`: charged residents go away for the weeks in `data/crime_types.json` and come back, families grieve, restitution resets the grudge, a wrong accusation gives the accused a grievance and eases the real culprit, and the town latches half its windows for 14 days.
