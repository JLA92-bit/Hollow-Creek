# Case 1 - Low Water (Chapter 1 authored murder)

The first major case. It uses the crime director's authored-case mode (see `docs/CRIME_DIRECTOR.md`, section 6): the who, why and what are fixed, but the route, witnesses and some traces come from the player's own layout.

**Triggers when:** the town has 8 or more households, the hotel and church are built, Arthur Whitcombe has lived in town for at least 3 weeks, and it is summer (drought).

## Setup beats (the weeks before)

1. **The drought.** Over three weeks the creek drops. Downstream, stone foundations appear: the 1890s settlement (`lm_old_town`). Residents talk about it at the hotel.
2. **Whitcombe digs around.** The dam engineer spends evenings at the foundations with a torch and a notebook. He is seen there by anyone with a view of the creek.
3. **The pub fight.** Two days before the murder, Len Pike and Whitcombe argue at the hotel about the dam cutting mill jobs. Len shoves him. Everyone sees it.
4. **The tools.** Whitcombe accuses Tomasz Kowalski, publicly, of stealing a survey level. (Davey Pike actually took it, as a dare, and hid it in the mill.)

## What really happened (hidden truth)

Whitcombe has found, in Lands Department papers he requested, that Frank Hayward bought most of the valley's lots in **March 1951**, seven months before the town was announced, on a tip from his cousin in the Lands Department. He plans to report it.

| Time | Event |
|---|---|
| 9:02 pm | Whitcombe telephones the store from the hotel. **Edna connects the call and logs it.** He asks Frank to meet him at the old foundations at ten |
| 9:45 pm | Frank tells Edna he's "checking the storeroom" and leaves by the back door. **June notices.** |
| 9:50 pm | Whitcombe leaves the hotel with a torch. **Bert sees him go towards the creek** |
| 9:45 to 10:00 | Frank walks to the foundations (route chosen from the player's layout, darkest route preferred) |
| ~10:05 | The argument. Frank grabs Whitcombe's notebook. Whitcombe grabs back. Frank shoves him, and he falls and strikes his head on the foundation stones. Frank grazes his knuckles on the stone |
| 10:05 to 10:20 | Frank panics, takes the notebook, and walks home. Bootprints, **size 9, smooth dress sole**, in the damp mud at the waterline |
| 10:30 | Edna, frightened by what she guesses, **tears that evening's page out of the exchange log** |
| 11:15 | June finds the notebook in Frank's coat. She can't bring herself to burn it and **hides it in the store's flour bin** |
| 6:10 am | Davey and Piotr, out fishing early, find the body. **Incident alert** |

**Culprit:** Frank Hayward. **Crime:** manslaughter (he didn't plan to kill, but he left a man to die). **Motive:** hiding the land deal (`s_frank_land`).

## Authored clues (always present)

| ID | Clue | Where | Text |
|---|---|---|---|
| `c_torch` | Whitcombe's torch, switched off | At the body | "His torch is switched off. He turned it off himself, or someone did." |
| `c_wound` | Head wound consistent with a fall onto stone | Body (district doctor's report next morning) | "Struck his head on the stones. Bruising on the chest, as if pushed. Died between ten and eleven." |
| `c_lands_file` | Lands Department file in Whitcombe's hotel room | Search his room (no warrant needed, he's the victim) | "Lots 4 to 11, Hollow Creek parish. Purchaser: F. Hayward. Date of transfer: 12 March 1951." |
| `c_clipping` | Newspaper clipping on the hotel wall | Hotel | "New Town for Dam Workers. Announced 9 October 1951." |
| `c_log_gap` | Exchange log with a page missing | Ask Edna for the log | "Page 47 is missing. The next page has pencil marks pressed through." |
| `c_log_rubbing` | Pencil rubbing of page 48 | Use the **pencil rubbing** action on `c_log_gap` | "9:02 pm. Hotel to Store. Local." |
| `c_knuckles` | Frank's grazed, bandaged knuckles | Visible in Frank's interview portrait. Press to ask | "Caught them on a crate. Shopkeeping's rough work." |
| `c_notebook` | Whitcombe's notebook | Search warrant on the store (flour bin), or June gives it when she breaks | Notes on the land purchase, and a final page (the Chapter 2 hook, below) |

## Emergent clues (from the player's layout)

The director plans Frank's route and simulates the night. Depending on the layout, these may exist:

| Clue | Exists if | Fallback if it doesn't |
|---|---|---|
| Size 9 smooth-sole prints at the foundations | Always (damp mud at the waterline) | - |
| Size 9 prints along Frank's route | Frank's route crosses dirt, mud or wet grass | `c_thread`: grey wool thread from Frank's cardigan caught on a fence or bush along the route |
| A witness who saw a figure walking towards the creek | Someone is awake with a sightline to the lit or moonlit part of Frank's route | Bert's statement: "Heard someone go past the back of the hotel about quarter to ten. Walked like a man in a hurry." |
| A witness who saw Frank returning | Someone awake with a sightline between 10:05 and 10:30 | Father Reilly, walking back from a sick visit, saw "a man with his hand wrapped in a handkerchief" near the store |

## Red herrings

| Suspect | Why they look guilty | What clears them |
|---|---|---|
| **Len Pike** | Fought Whitcombe two days ago. Walked home drunk along the creek track at 10:15. Size 10 prints on the track | Prints are hobnail, and never reach the foundations. Bert confirms Len was too drunk to walk straight. Len lies about how much he drank (embarrassment), which is the lie to break |
| **Tomasz Kowalski** | Publicly accused of theft by the victim. Was at the creek at night. Size 11 prints near the water | His yabby traps are 200 metres upstream. Halina covers for him (Loyal is not her trait, but family protection applies). Once Tomasz admits the traps, the trap line puts him away from the foundations at the right time |

## Interviews (key statements)

### Frank Hayward (culprit)
| ID | Statement | Contradicted by | Result |
|---|---|---|---|
| `st_frank_1` | "Doing the books all evening. Didn't set foot outside." | June's statement `st_june_out`, or a witness sighting (Composure -25) | "I stepped out for some air. That's all." |
| `st_frank_2` | "Whitcombe? Barely knew the man. Never spoke to him on the telephone." | `c_log_rubbing` (Composure -30) | "He rang about an order. Nothing more." |
| `st_frank_3` | "I've nothing to hide about my business." | `c_lands_file` plus `c_clipping` (Composure -25) | "Every man in my position would have done the same." |
| `st_frank_4` | "I was never down at that creek." | Size 9 smooth-sole prints matched to Frank's shoes (Composure -40) | Composure 0: confession |

**Confession:** "He was going to ruin us. I only wanted the notebook. He fell. I heard his head hit the stone and I... I ran. I left him there. God help me, I left him there."

### Edna Hayward (lying to protect Frank)
- "No calls last night. Quiet as the grave." Contradicted by `c_log_gap` and `c_log_rubbing`. She breaks: "I tore it out. I didn't know why he'd gone out, and I didn't want to know."

### June Hayward (torn)
- "I went to bed early." Contradicted by `st_piotr_june` (Piotr was with her by the back gate until 9:40, their secret).
- When pressed after that: `st_june_out`: "Dad went out the back about quarter to ten. He came back with his hand wrapped up."
- At Composure 0 she hands over `c_notebook`.

### Bert Mullins, Father Reilly, Len, Tomasz, Halina, Davey, Piotr
Generate their statements from simulation memories, with these authored additions:
- Bert: "Whitcombe took a telephone call at the bar at nine, then went out with his torch at ten to ten."
- Piotr: `st_piotr_june` (only given once June's lie is exposed, or if the player has high friendship with Piotr).
- Davey: confesses to taking the survey level if pressed about Tomasz. This clears Tomasz of the theft accusation.

## Deductions

| ID | Sentence | Answer |
|---|---|---|
| `d_meeting` | "Whitcombe arranged to meet [person] by telephone at [time]." | Frank Hayward, 9:02 pm |
| `d_died` | "Whitcombe died between [time] and [time] after [cause]." | 10:00, 11:00, a fall onto the stones after being pushed |
| `d_prints` | "The prints at the foundations are size [size], [sole]." | 9, smooth dress sole |
| `d_motive` | "[person] wanted to hide [secret]." | Frank Hayward, buying the valley before the town was announced |
| `d_frank_out` | "Frank left the store at [time]." | 9:45 pm |
| `d_len_cleared` (optional) | "Len's prints never reached the foundations." | - |
| `d_tomasz_cleared` (optional) | "Tomasz was at his traps, upstream." | - |

## Outcome

The accusation needs all four requirements proven for Frank.
- **Charge Frank with manslaughter.** He goes to trial in the district. The store is run by Edna and June, prices rise, and Town Trust is +12. The Haywards' friendship with the player collapses, but June later thanks the player privately.
- **Charge Frank with murder.** Harsher, and the jury acquits him for lack of intent. Frank returns in 8 weeks with a strong grievance against the player. Town Trust +4.
- **Wrong accusation (Len or Tomasz):** standard wrong-accusation consequences. Frank's secret stays safe, and the notebook pages are burnt.

## The Chapter 2 hook

The last page of Whitcombe's notebook:

> *The foundations are not the only thing down here. Skeleton under the old assay office floor. Not 1890s flood damage, as the inquest claimed. Someone was buried. Ask Mrs Doyle. She was here.*

The player now knows Agnes Doyle has a secret, and the creek is still dropping.
