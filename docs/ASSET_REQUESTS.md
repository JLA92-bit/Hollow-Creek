# Asset requests for Josh

Things Claude Code couldn't fetch itself. Each batch lists exact files with direct links. Drop downloads (still zipped is fine) into `assets/incoming/` and say "I've put downloaded assets in assets/incoming". Placeholders are used until then, so nothing is blocked.

## Network check (M0, 17 October 2026)

| Host | Result |
|---|---|
| `polyhaven.com`, `api.polyhaven.com`, `dl.polyhaven.org` | **Reachable.** HDRIs, models and textures download fine |
| `ambientcg.com` (website and API) | Reachable |
| `acg-download.struffelproductions.com` (where ambientCG's download links redirect to) | **Blocked** by the environment's network policy (proxy returns 403) |

**Easiest fix (2 minutes):** in Claude Code, open the cloud environment menu in the session title bar, choose Edit, and under Network access add `acg-download.struffelproductions.com` to Allowed domains (keep "Allow package managers" ticked). Steps: https://code.claude.com/docs/en/cloud-environments#network-access. Then Claude Code fetches everything itself and Batch 1 below isn't needed.

**Update (M1):** Poly Haven covered everything M1 needed (weatherboard, plaster, floorboards, lino, corrugated iron, brick, bark, fabrics and all four ground layers), so **nothing is blocked and no download is needed right now.** Batch 1 below is optional, for extra variety later. `tools/assets/fetch_ambientcg.py` picks up any of these zips dropped into `assets/incoming/`.

## Batch 1 - ambientCG materials (optional, only if the domain can't be allowed)

Click each link, which downloads a 1K JPG zip. About 5 to 8 MB each.

| Use | Asset | Link |
|---|---|---|
| Weatherboard cladding | WoodSiding008 | https://ambientcg.com/get?file=WoodSiding008_1K-JPG.zip |
| Weatherboard (alternative) | WoodSiding005 | https://ambientcg.com/get?file=WoodSiding005_1K-JPG.zip |
| Painted timber (trims, joinery) | PaintedWood007C | https://ambientcg.com/get?file=PaintedWood007C_1K-JPG.zip |
| Timber floorboards | WoodFloor051 | https://ambientcg.com/get?file=WoodFloor051_1K-JPG.zip |
| Timber floorboards (pine) | WoodFloor043 | https://ambientcg.com/get?file=WoodFloor043_1K-JPG.zip |
| Verandah decking | Planks037A | https://ambientcg.com/get?file=Planks037A_1K-JPG.zip |
| Corrugated iron roof | CorrugatedSteel007A | https://ambientcg.com/get?file=CorrugatedSteel007A_1K-JPG.zip |
| Corrugated iron (painted) | CorrugatedSteel005 | https://ambientcg.com/get?file=CorrugatedSteel005_1K-JPG.zip |
| Interior plaster (paint base) | PaintedPlaster017 | https://ambientcg.com/get?file=PaintedPlaster017_1K-JPG.zip |
| Wallpaper base paper | Wallpaper001A | https://ambientcg.com/get?file=Wallpaper001A_1K-JPG.zip |
| Kitchen and wash-house tiles | Tiles107 | https://ambientcg.com/get?file=Tiles107_1K-JPG.zip |
| Brick (chimneys) | Bricks075A | https://ambientcg.com/get?file=Bricks075A_1K-JPG.zip |
| Fabric (curtains, upholstery) | Fabric061 | https://ambientcg.com/get?file=Fabric061_1K-JPG.zip |
| Carpet | Carpet016 | https://ambientcg.com/get?file=Carpet016_1K-JPG.zip |
| Dry grass | Grass004 | https://ambientcg.com/get?file=Grass004_1K-JPG.zip |
| Dirt | Ground037 | https://ambientcg.com/get?file=Ground037_1K-JPG.zip |
| Mud | Ground054 | https://ambientcg.com/get?file=Ground054_1K-JPG.zip |
| Gravel | Gravel023 | https://ambientcg.com/get?file=Gravel023_1K-JPG.zip |
| Roof tiles (later chapters) | RoofingTiles013A | https://ambientcg.com/get?file=RoofingTiles013A_1K-JPG.zip |

## Later

- **Before M9: animations.** The M5 to M8 residents use three placeholder animations (idle, walk, sit) keyed by hand in Blender. M9 needs real ones, either from Mixamo (needs an Adobe login, so Josh downloads) or the **Quaternius Universal Animation Library** (CC0, no login). Either source works; Quaternius alone is the simpler route and covers most of the list.

  What the simulation and the investigation actually use, in priority order:

  | Needed for | Animation | Used by |
  |---|---|---|
  | Everyday life | idle (standing, relaxed), walk, sit down, sit idle, stand up | every resident, all day |
  | Home | sleep (lying), cook (stirring), sweep, eat, listen to the wireless (seated), garden (dig / weed) | `sleep`, `cook`, `snack`, `wireless`, `garden` actions |
  | Work | hammer or saw (mill), serve at a counter (store), switchboard (exchange), carry a box | `work` at the mill, store and exchange |
  | People | talk (gesturing), listen, wave, argue (pointing), laugh | chats, visits, interviews |
  | Investigation | nervous idle (shifting, hand wringing), look down / away, arms crossed | the live portrait (composure and pressure) |
  | Crime | sneak (crouched walk), climb through a window, crouch and pick up | the director's plans (`sneak` legs) |
  | Town life | dance (a simple two-step), carry (arms full) | the welcome dance, shopping |

  Download as FBX or GLB, **with skin**, at 30 fps, in place (no root motion), and put them in `assets/incoming/animations/`. Claude Code retargets them onto the MPFB rig in the character pipeline. For Mixamo please download the "Y Bot" or "X Bot" version of each so the rig is consistent. Facial expressions don't come from either library; they are blend shapes made in the MPFB pipeline.
