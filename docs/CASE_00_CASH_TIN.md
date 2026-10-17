# Case 0 - The Cash Tin (Prologue tutorial)

The first case teaches building, the simulation and every investigation tool. It is an **authored case run through the crime director**, with a fixed seed and plan so it plays the same every time. The tutorial makes sure the layout supports it.

Target play time from new game to case closed: 40 to 60 minutes.

## Tutorial building steps (before the crime)

1. **Arrival.** A truck drops the player at the siding. Agnes Doyle's cottage is the only building in the valley.
2. **Lay the main road** from the siding east past Agnes's cottage (guided ghost path).
3. **Build the general store** on the marked plot beside Agnes's cottage, using the store template, then customise it. The tutorial requires: a front door onto the road, a **back window facing the creek** ("for light in the storeroom"), and the exchange back room with the switchboard. New windows start unlatched, and the tutorial doesn't mention latches.
4. **Build three houses** north of the road from the cottage template, and furnish them.
5. **Approve three families** (Haywards are pre-assigned to the store) and choose which house each gets.
6. **Play the first week.** Introduce following residents, needs and relationships. Footpaths and street lamps are **locked** until this case is closed, so the creek track stays mud.

## What really happened (hidden truth)

Saturday of week 1 is the **welcome dance** in the mill shed, 7:30 pm to 11:00 pm. The exchange closes for the dance at 7:30 pm. Night calls go to the bell at the Haywards' residence.

| Time | Event |
|---|---|
| Thu 4:40 pm | Frank Hayward refuses Len Pike more credit, loudly, in front of Marge and Halina. Len owes £11 4s. Grievance: Len towards Frank, weight 70 |
| Sat 7:30 pm | Almost everyone goes to the dance: the Haywards, Len and Marge, the Kowalskis, Davey. Agnes stays home |
| 8:30 pm | Davey slips out to smoke and fish by the creek |
| 8:50 pm | Len says he's going out for a smoke and leaves the mill shed |
| 8:50 to 9:05 | Len walks the muddy creek track to the back of the store |
| 9:05 | Len climbs in through the unlatched back window and takes the cash tin (£23 10s) from under the counter |
| 9:12 | Len climbs out. **Agnes, in her lit kitchen, sees a man in a hat behind the store**, about Len's height. She recognises the walk but doesn't want to believe it |
| 9:12 to 9:30 | Len walks back along the creek track and hides the tin in the Pike woodpile |
| 9:35 | Len returns to the dance. **Halina notices fresh mud on his trouser cuffs** |
| 10:00 | Davey wanders home from the creek with muddy boots |
| 10:35 | The Haywards return. Frank finds the back window open and the cash tin gone. **Incident alert** |
| 10:40 | Agnes, upset, rings her sister in Ballarat. **Edna connects and logs the trunk call** |

**Culprit:** Len Pike. **Motive:** refused credit and humiliated, plus hidden gambling debts. **Red herring:** Davey Pike.

## Scene: Hayward's General Store (`sc_store`)

| ID | Trace | How to find it | Text |
|---|---|---|---|
| `t_window` | Back window open, unlatched | Tap the window | "The back window is pushed open. It was never latched." |
| `t_tin` | Empty space under the counter | Tap the counter | "The cash tin's gone. Frank says there was over £23 in it." |
| `t_prints_in` | Muddy bootprints on the floor, window to counter | Tap the floor near the window | "Mud, still wet. A big work boot with hobnails. Measure it?" Measuring gives **size 10, hobnail sole** |
| `t_prints_out` | Prints in the mud outside, heading for the creek track | Search outside the window | "The same hobnail prints, coming from and going back towards the creek." |
| `t_mud_track` | Second set of smaller prints on the creek track, near the water | Search the creek track | "Smaller prints, size 8, worn tread. They wander along the bank and never come near the store." |

## Records

| ID | Record | Where | Content |
|---|---|---|---|
| `rec_ledger` | Store credit ledger | Ask Frank | "PIKE, L. Owes £11 4s. Credit STOPPED Thursday." in Frank's hand |
| `rec_exchange` | Exchange log | Ask Edna | Only one call after 7:30 pm: "10:40 pm. Doyle residence to Ballarat 2214. Trunk call, 6 minutes." |

## Interviews

Composure starts at 100. Rules are in `docs/GAME_DESIGN.md`.

### Frank Hayward (victim)
- "Locked the front door at half seven, went to the dance with Edna and June. Came back at twenty-five to eleven and the window was wide open."
- Press: "Who'd do it? Half the town owes me money. Len Pike's the worst of them."
- Gives `rec_ledger`.

### Edna Hayward (witness, honest)
- "Exchange closed for the dance. Only one call all night, after we got home." Gives `rec_exchange`.
- Press: "Mrs Doyle rang her sister. Sounded upset. I didn't listen in." (She did, a little: "She said, 'I don't know what to do, Win.'")

### Agnes Doyle (witness, lying to protect Marge)
| ID | Statement | Contradicted by | Result |
|---|---|---|---|
| `st_agnes_1` | "I didn't go to the dance. My knees aren't what they were." | - | Press: "I had my tea and listened to the wireless." |
| `st_agnes_2` | "I was in bed by nine, dear. I didn't hear a thing all night." | `rec_exchange` (Composure -40) | "All right. I was up. I... saw someone behind the store. A man in a hat, just after nine." |
| `st_agnes_3` | "It was dark. I couldn't say who." | `t_prints_in` measured as size 10 hobnail (Composure -60, she breaks) | "Big work boots... He walked like Len. God forgive me, Marge is my dearest friend." Unlocks `st_agnes_saw_len` |

### Halina Kowalska (witness, honest)
- "We were at the dance all evening. Tomasz danced with me twice, which is a miracle."
- Press about Len: "He went out around ten to nine. When he came back his trousers were muddy to here." Unlocks `st_halina_mud`.

### Davey Pike (red herring, lying about his own secret)
| ID | Statement | Contradicted by | Result |
|---|---|---|---|
| `st_davey_1` | "I was at the dance the whole time." | `t_mud_track`, or Halina when pressed about Davey | "Fine. I went down the creek for a smoke. Don't tell Mum." |
| `st_davey_2` | "I never went near the store." | - (true) | Press: "Saw Dad on the track, actually. Heading back to the shed. Said to mind my business." Unlocks `st_davey_saw_dad` |

### Len Pike (culprit)
| ID | Statement | Contradicted by | Result |
|---|---|---|---|
| `st_len_1` | "I was at the dance all night. Ask anyone." | `st_halina_mud` or `st_davey_saw_dad` (Composure -30) | "Went out for a smoke. Ten minutes." |
| `st_len_2` | "Ten minutes, I was back by nine." | `st_agnes_saw_len` (Composure -35) | "She's an old woman, she sees things." |
| `st_len_3` | "I don't owe Hayward a penny he won't get back." | `rec_ledger` (Composure -35) | Composure 0: confession below |

**Confession:** "He shamed me in front of my wife. In front of the whole town. I've got debts Marge doesn't know about. I just... I was going to put it back."

## Search warrant

Searching the Pike house (costs 5 Town Trust if wrong) finds `t_tin_woodpile`: the cash tin, £23 10s intact, under the woodpile, and Len's hobnail boots, size 10, still muddy.

## Deductions

| ID | Sentence | Proven by linking | Answer |
|---|---|---|---|
| `d_entry` | "The thief came in through the [entry]." | `t_window` + `t_prints_in` | back window |
| `d_size` | "The bootprints belong to someone with size [size] [sole] boots." | `t_prints_in` (measured) | 10, hobnail |
| `d_agnes_awake` | "[person] was awake at [time]." | `rec_exchange` + `r_agnes` | Agnes Doyle, 10:40 pm |
| `d_len_out` | "Len Pike left the dance between [time] and [time]." | `st_halina_mud` + `st_len_1` | 8:50 pm, 9:35 pm |
| `d_davey_cleared` (optional) | "The size 8 prints never reached the store." | `t_mud_track` + `t_prints_out` | - |
| `d_motive` | "Len Pike had reason: [motive]." | `rec_ledger` | refused credit and in debt |

## Accusation and outcome

The accusation needs Opportunity (`d_len_out` or `st_agnes_saw_len`), Means (`d_size` plus Len's boots, from the warrant or by asking to see them), Motive (`d_motive`) and a broken lie (any of Len's).

After the accusation, the player chooses:
- **Charge Len.** He goes to the district court for 4 weeks. The Pikes' income drops, Marge is cold towards the player, and Agnes feels guilty. Frank is satisfied. Town Trust +10.
- **Restitution.** Len repays from his wages and does a month of community work. Frank thinks the player is soft (grievance 30 towards the player). The Pikes are grateful. Town Trust +6, and Len's grievance against Frank resets.

**Then the lesson unlocks:** footpaths and street lamps become available. A tip appears: "Residents have started latching their windows. A lamp behind the store wouldn't hurt either."
