# Hollow Creek - Game Design

All numbers are starting values to tune in playtests. Keep them in data files, not code.

## Premise

**Country Victoria, 1952.** The government wants a new town in a quiet valley to house the families coming for the new dam and timber mill. You are its **Administrator and only Constable**. You build the town with your own hands: every road, house, room and street lamp. When something goes wrong, you investigate it.

**The hook:** every crime grows out of the town you built and the lives lived in it. Your layout decides who sees what, how a thief gets in, and which alibis hold up. No two playthroughs have the same mysteries.

**Look:** warm semi-realism, like a modern life sim: realistic proportions and materials, soft lighting, cutaway walls, and a clean white interface. Runs in the browser on phones and computers (`docs/ART_DIRECTION.md`).

**Tone:** warm, wry and grounded, with real moral weight. Country-town humour, post-war hope, secrets under the surface. Violence happens off-screen. Target rating 12+.

## The three pillars

1. **You build it.** Hands-on construction, from laying roads to designing each home room by room: walls, windows, paint and wallpaper, roofs, verandahs and sleep-outs, gardens and furniture. Homes have scores, residents have wishes, and houses change over the years. See `docs/HOUSE_BUILDING.md` and `docs/BUILDING.md`.
2. **They live in it.** A small population of named residents with needs, routines, relationships, memories and secrets. See `docs/SIMULATION.md`.
3. **Something goes wrong.** A crime director plans fair, solvable incidents from the simulation, and you investigate them with scene searches, interviews and a case board. See `docs/CRIME_DIRECTOR.md`.

## Core loop

| Layer | Loop | Timescale |
|---|---|---|
| Moment | Place pieces, follow a resident, read a memory, find a trace | Seconds |
| Day | Residents live their routines while you build and manage | ~4.5 real minutes at 1x |
| Week | Rates and rent come in, new families apply, tensions build | ~30 minutes |
| Incident | Something happens, then investigate, accuse and live with the outcome | One session |
| Chapter | Town milestones unlock new buildings, crime types and the next story beat | Several hours |

## Time

- In-game day runs 06:00 to 24:00. Overnight (00:00 to 06:00) is simulated quickly unless an incident is happening.
- Speeds: **Pause**, **1x** (4 game minutes per second), **2x**, **4x**.
- Opening build mode pauses time automatically. Players can switch on "build while time runs" in settings.
- A week has 7 days. Four seasons of 13 weeks. Weather (rain, frost, heat) affects mud, routines and moods.

## The player's two roles

| Role | What you do |
|---|---|
| **Administrator** | Build, approve applicant families, set where they live, set rates, organise events (dances, footy, church fete), spend grants |
| **Constable** | Respond to incidents, search scenes, interview residents, request search warrants, make arrests, decide on charges or restitution |

The roles pull against each other: arresting a family's breadwinner hurts the town's economy, and favouring friends hurts Town Trust.

## Key resources

| Resource | Start | Notes |
|---|---|---|
| Money (£ pounds) | £1,500 | Government grant. Income from rates (£5 a household a week), shop rents (£8 a week) and a £50 grant for each new family that settles |
| Materials | Unlimited timber once the mill opens | Before the mill opens, timber costs double |
| Builders | 2 crews | Each crew builds 5 m of wall or 5 square metres of floor a day (or switch on instant building in Sandbox mode). Extra crews cost £10 a week |
| **Town Trust** | 50 / 100 | Rises with solved cases, fair decisions and good amenities. Falls with wrong arrests, unsolved crimes, unfair favours and neglect. Affects applicants, witness honesty and grant size |

## Crime types

| Type | Severity | When it unlocks | Typical motives |
|---|---|---|---|
| Petty theft | Minor | Week 1 | Debt, envy, desperation |
| Vandalism | Minor | Week 3 | Grudge, humiliation, rivalry |
| Poaching or sly grog | Minor | Chapter 1 | Money, defiance |
| Arson | Major | Chapter 2 | Revenge, insurance, cover-up |
| Disappearance | Major | Chapter 2 | Secrets, running away, foul play |
| Murder | Major, authored | Chapter climaxes | Written in case files, adapted to the layout |

Drama budget: at most one minor incident every 7 to 10 in-game days, and one major incident per chapter. The director can skip a slot if nothing is brewing.

## Investigation

1. **Respond.** An incident alert appears. Time pauses on the first alert.
2. **Search the scene.** The camera zooms into the location with walls down, with a torch at night. Tap tiles and objects to find traces: bootprints, forced entry, dropped items, disturbed objects.
3. **Gather records.** Shop credit ledger, telephone exchange log, mill time cards, pub tab, church roster.
4. **Interview.** Residents give statements built from their real memories. Those with something to hide lie. Present evidence that contradicts a statement to break it. The Composure and Pressure rules are below.
5. **Case board.** Link facts to prove the four requirements: **Opportunity**, **Means**, **Motive** and a **broken lie**.
6. **Search warrant (optional).** Search a resident's property. A wrong search costs 5 Town Trust and sours that household.
7. **Accuse.** Choose who, how and why.

**Interview rules:** Composure starts at 100. Correct contradictions lower it by 25 to 40. At 0 the person tells the truth. Pressure starts at 0. Wrong presentations add 20, and at 100 the person refuses to talk until tomorrow. Witnesses who are not suspects have no Pressure meter.

**Investigation time:** each scene search, interview or records check costs 30 to 60 in-game minutes. Cases have a soft deadline. The longer it takes, the more Town Trust slips and the more likely the culprit hides or destroys evidence.

## Outcomes and consequences

| Result | Effect |
|---|---|
| Right person, all four requirements proven | Town Trust +10. Choose: **charge** (sent to the district court) or **restitution** (repay, apologise, community work). Each choice changes relationships across the town |
| Right person, case incomplete | Town Trust +3. The magistrate may throw it out, and the culprit's grudge against you grows |
| Wrong person | Town Trust -15. The accused family may leave. The real culprit's pressure eases, and they may strike again |
| Unsolved by the deadline | Town Trust -8. Residents start locking doors, shops close earlier, and trust between neighbours drops |

**Prevention is part of play.** Lamps, footpaths, latched windows and a busier main street make some crimes harder. A town with nothing to do and no one looking out for each other breeds trouble. A perfectly peaceful town is possible for a while, but the chapter stories always bring trouble eventually.

## Story structure

| Chapter | Town milestone | Story |
|---|---|---|
| Prologue | 4 houses, store, telephone exchange | Arrival and The Cash Tin (`docs/CASE_00_CASH_TIN.md`) |
| 1 - Low Water | 8+ households, pub, church | Drought lowers the creek and reveals the foundations of an older, abandoned settlement. The dam engineer is found dead there (`docs/CASE_01_LOW_WATER.md`) |
| 2 - The Old Town | School, dance hall, 12+ households | Who lived here in the 1890s and why they left. A fire, a disappearance |
| 3 - The Dam | Mill expansion, 16+ households | The dam's true plans and who profits from the valley |
| 4 - High Water | Endgame | Flood season. The town, and its secrets, are tested |

Emergent minor incidents run alongside every chapter.

## Cultural care

- The valley is on Country. Any First Nations history or characters must be developed with consultation and respect, never invented as a plot device. The "older settlement" in the story is an abandoned 1890s gold-mining settlement.
- Post-war migrant families (such as the Kowalskis) are written as full people, not stereotypes. Prejudice can exist in the town, but the game never treats it as a joke.
- No real people or real towns are depicted.

## Accessibility

- Text size options, colour-blind safe indicators (shape plus colour), reduce motion, hints toggle.
- No reflex challenges. Deadlines are in-game days.
- Autosave every in-game hour and after every build or investigation action.

## Business model (later)

Prologue and Chapter 1 free. The full game is a single purchase. No ads, no loot boxes, no energy timers.
