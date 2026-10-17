# Hollow Creek - Residents for the Vertical Slice

Convert this into `data/residents.json` in M5. IDs in `code font` must be kept exactly. Appearance lines drive the MPFB character pipeline and the optional portrait prompts in `docs/ASSET_SOURCES.md`.

Shoe sizes and soles matter for investigations, so keep them unique enough to tell people apart.

## Founding residents (Prologue)

### Agnes Doyle `r_agnes` (household `h_doyle`)
- **67, widow.** Lives in the **only building already in the valley**: a weatherboard cottage that predates the town. She has lived here all her life.
- **Traits:** Observant, Lonely, Loyal.
- **Job:** retired. Keeps chooks, sells eggs to the store.
- **Boot:** women's size 6, low heel.
- **Personal items:** reading glasses on a chain, a hairpin with a jet bead.
- **Secret** `s_agnes_childhood`: as a girl she lived in the 1890s settlement downstream and saw how it ended. She has never told anyone. (Chapter 2.)
- **Appearance:** small and upright, grey hair in a bun, sharp pale eyes, cardigan and apron, a knitted shawl at night.

### Hayward household `h_hayward` (lives behind the store)
**Frank Hayward** `r_frank`
- 48, shopkeeper. Traits: Proud, Greedy, Secretive.
- Boot: size 9, smooth-soled dress shoes.
- Personal items: fountain pen, gold tie pin.
- Secret `s_frank_land`: bought most of the valley's lots in March 1951 on a tip from his cousin in the Lands Department, months before the town was announced. (Chapter 1 motive.)
- Appearance: neat, balding, pencil moustache, shop apron over a white shirt and tie, rimless glasses.

**Edna Hayward** `r_edna`
- 45, telephone exchange operator (the switchboard is in the store's back room). Traits: Nosy, Loyal.
- Boot: women's size 7.
- Keeps the **exchange log**: every call with time, caller and number called.
- Appearance: tall, auburn hair in rolled curls, headset around her neck, floral dress with a cardigan.

**June Hayward** `r_june`
- 19, works in the store. Traits: Kind, Secretive.
- Boot: women's size 6, sandals in summer.
- Secret `s_june_piotr`: secretly walking out with Piotr Kowalski. Both families would object.
- Appearance: dark bobbed hair, freckles, gingham dress, quick nervous smile.

### Pike household `h_pike`
**Len Pike** `r_len`
- 44, mill hand, served in New Guinea in the war. Traits: Proud, Hot-headed, Drinker.
- Boot: size 10 work boots, hobnail sole.
- Personal items: tobacco tin, army-issue pocketknife.
- Secret `s_len_debts`: gambling debts to a bookmaker in the next town.
- Appearance: broad, sunburnt, thick forearms, battered felt hat, flannel shirt, braces.

**Marge Pike** `r_marge`
- 41, home duties. Traits: Gossip, Kind.
- Boot: women's size 7.
- Close friend of Agnes Doyle (friendship 70 both ways).
- Appearance: round-faced, laugh lines, headscarf, floral apron.

**Davey Pike** `r_davey`
- 16, apprentice at the mill. Traits: Night owl, Hot-headed.
- Boot: size 8 work boots, worn tread.
- Secret `s_davey_smoking`: sneaks off to smoke and fish by the creek at night.
- Grievance: Frank Hayward caught him pinching lollies last week (weight 40).
- Appearance: lanky, cowlick, too-big hand-me-down jacket.

### Kowalski household `h_kowalski`
Arrived in 1949 under the post-war Displaced Persons scheme.

**Tomasz Kowalski** `r_tomasz`
- 39, mill hand, a trained cabinetmaker whose qualifications aren't recognised here. Traits: Honest, Shy, Early riser.
- Boot: size 11 work boots, patched sole.
- Secret `s_tomasz_yabbies`: sets yabby traps in the creek at night without a licence to stretch the family budget. (Chapter 1 red herring.)
- Appearance: tall and lean, close-cropped fair hair, careful hands, a mended work jacket.

**Halina Kowalska** `r_halina`
- 36, seamstress working from home. Traits: Observant, Religious.
- Boot: women's size 6.
- Appearance: dark hair in a plait pinned up, steady eyes, a cardigan with a brooch.

**Piotr Kowalski** `r_piotr`
- 19, mill hand and keen footballer. Traits: Kind, Night owl.
- Boot: size 10 football boots and size 10 work boots, chevron sole.
- Secret: shared `s_june_piotr`.
- Appearance: athletic, fair hair, open grin, rolled shirtsleeves.

## Starting wishes (see `docs/HOUSE_BUILDING.md`)

| Household | Wish | Requirement |
|---|---|---|
| Kowalski | Halina: a sewing room with good morning light | A room with a table and an east-facing window |
| Kowalski | Piotr: a sleep-out on the verandah | An enclosed verandah section with a bed |
| Pike | Len: a shed of his own | A garden shed with a door |
| Pike | Marge: a veggie patch | At least 4 square metres of veggie patch |
| Doyle | Agnes: a warm sitting room | A room with a stove or fireplace and an armchair |
| Hayward | Frank: a proper shop sign and a bigger counter | Shop sign piece and a counter 3 m or longer |

## Chapter 1 applicants

These families apply once the town reaches 6 households. The player chooses who comes and where they live.

| ID | Name | Age | Role | Traits | Boot | Notes |
|---|---|---|---|---|---|---|
| `r_bert` | Bert Mullins | 55 | Publican, the Creek Hotel | Gossip, Drinker, Kind | 10, dress shoe | Knows everyone's business |
| `r_reilly` | Father Declan Reilly | 50 | Parish priest | Religious, Observant | 9, dress shoe | Hears confessions, which creates a dilemma |
| `r_arthur` | Arthur Whitcombe | 42 | Dam engineer, lodges at the hotel | Proud, Observant, Secretive | 9, ribbed field boot | **Chapter 1 victim** |
| `r_clara` | Clara Bell | 26 | Schoolteacher | Kind, Honest, Nosy | women's 6 | Lives in the Bell house |
| `r_sal` | Sal Russo | 33 | Market gardener | Kind, Early riser | 9, work boot | Arrives with wife `r_maria` (31) and two children |

## Fixed landmarks (not built by the player)

| ID | Landmark | Notes |
|---|---|---|
| `lm_siding` | Railway siding | West edge. Families and goods arrive here |
| `lm_mill` | Timber mill | North-west. The main employer |
| `lm_agnes_cottage` | Agnes Doyle's cottage | Fixed position beside the first store plot |
| `lm_old_town` | Foundations of the 1890s settlement | Downstream, under the creek until the Chapter 1 drought |
