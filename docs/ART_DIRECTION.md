# Hollow Creek - Art Direction

**Style name:** Warm Semi-Realism.

The look of a modern life sim: realistic proportions, real materials (timber grain, painted weatherboard, lino, fabric, corrugated iron), soft lighting and gentle ambient occlusion, with a slightly idealised, warm, storybook polish. Not photoreal. Think "a lovingly lit dolls' house of 1952 country Victoria".

It must run in a **web browser on phones and computers** (Godot's Compatibility renderer, WebGL 2), so the realism comes from **good materials, careful lighting and good models**, not from expensive effects.

## References

- **Mood and level of realism:** modern life-sim build mode screenshots (soft daylight, cutaway walls, rich materials), and simple Godot archviz interiors.
- **Period:** 1950s Australian country homes: weatherboard and fibro cottages on stumps, corrugated iron roofs, verandahs with posts and lace or fretwork, lino kitchens, wood stoves, iceboxes, chenille bedspreads, floral curtains, pressed metal ceilings, timber floors with rugs.
- `docs/mockups/` contains **UI layout references only**. The world art in them was an earlier stylised direction and is **not** the target. Keep the panel layouts, ignore the art.

## What the web renderer can and can't do

From Godot's renderer comparison (Compatibility column):

| Available on the web | Not available on the web |
|---|---|
| PBR materials (albedo, normal, roughness, metallic, AO maps) | Real-time global illumination (SDFGI, VoxelGI, SSIL) |
| Directional, omni and spot lights with shadows | Screen-space reflections |
| **SSAO** (screen-space ambient occlusion) | Volumetric fog |
| Glow, tonemapping, colour adjustments, depth and height fog | TAA, FXAA and SMAA (use MSAA 3D or SSAA instead) |
| Reflection probes (2 per mesh) | Subsurface scattering (fake soft skin in the shader instead) |
| Rendering baked lightmaps | Particle trails |
| Decals (8 per mesh) | Depth of field |

**How realism is achieved anyway:**
1. **Image-based ambient light** from an HDRI sky (Poly Haven) for soft, coloured ambient light and reflections.
2. **SSAO** on Medium and High quality for contact shadows in corners and under furniture.
3. **Fake bounce light:** each room gets one cheap fill light, tinted by its dominant wall and floor colour, recalculated when the room changes. This is the most important trick for interiors.
4. **Reflection probes** per room for glossy floors, glass and tiles, updated after building changes.
5. **Baked lightmaps** only for fixed landmarks (the mill, the siding, the old town ruins), never for player-built homes.
6. **Good tonemapping** (AgX or ACES, filmic), gentle glow on lamps, and a warm colour grade.

## Quality presets (essential for phones)

| Setting | Low (older phones) | Medium (default phones) | High (computers) |
|---|---|---|---|
| Render scale | 0.75 | 0.9 | 1.0 |
| Shadows | 1 cascade, 1024 px, short distance | 2 cascades, 2048 px | 3 cascades, 4096 px, soft |
| SSAO | Off | Half resolution | Full |
| Real lamp lights | 4 nearest | 8 nearest | 16 nearest |
| Texture size | 512 px | 1024 px | 2048 px |
| Anti-aliasing | Off | MSAA 2x | MSAA 4x |
| Resident LOD | Low mesh beyond 15 m | Low beyond 25 m | Low beyond 40 m |

Pick the preset automatically on first launch from a 3-second benchmark, and let players change it in Settings.

## Camera

- **Perspective** camera with a narrow field of view (about 35 degrees), which reads as more realistic than orthographic.
- **Free orbit** (drag with right mouse or two fingers), plus snap buttons for 45 degree steps. **Zoom** from street level to the whole valley. **Pan** with drag or WASD.
- **Floor view:** in buildings with more than one storey, show one storey at a time with the floors above hidden.
- **Walls:** Up, Cutaway and Down modes, as in life sims. Cutaway lowers walls facing the camera to 0.5 m, with a clean painted top edge.
- **Screenshot mode:** hides the UI, lets players set the time of day and adds a light vignette.

## Palette and materials

The world uses realistic materials, tinted towards a warm 1950s palette.

| Material family | Examples | Notes |
|---|---|---|
| Weatherboard | Painted pine in cream, mint, duck-egg, butter, white with green or maroon trim | Real board profile in the normal map. Slight paint wear on Low-tier houses |
| Fibro | Flat sheets with cover strips | Matte, cool, slightly cheaper look |
| Brick | Red and cream brick, tuckpointed | For prestige buildings and chimneys |
| Corrugated iron | Galvanised grey, painted red or green | Strong normal map, low roughness, a little rust on old roofs |
| Floors | Jarrah and pine boards, lino in checks and marbled patterns, carpet squares, concrete | Rugs on top |
| Walls inside | Flat paint, floral and striped wallpaper, timber panelling, tiles in kitchens and wash houses | Picture rails and skirting boards |
| Fabrics | Chenille, floral cotton, gingham, wool, lace | For curtains, bedding and upholstery |
| Metal | Enamel (stoves, iceboxes), chrome (kitchen chairs), cast iron | |
| Ground | Dry grass, green winter grass, red-brown dirt, gravel, mud, garden soil | Terrain splat painting |

### Interface (Josh's colours)

| Token | Hex | Use |
|---|---|---|
| `ui_bg` | `#FFFFFF` | All panels |
| `navy` | `#00294D` | Text, headings, selected tools, selection outlines |
| `maroon` | `#940E16` | Incidents, evidence, the Present button |
| `green` | `#5CBD6C` | Proven deductions, good scores |
| `sky` | `#4BC9F5` | Blueprints and build guides |
| `amber` | `#FBAD45` | Warnings |
| `orange` | `#F26839` | Urgent needs, fire |
| `paper` | `#F6F3EA` | Records, statements, memories |

Secondary text `#3D5670`. White panels always.

## Typography (from the `google/fonts` repository)

Fraunces for headings and names, Atkinson Hyperlegible for UI and body, Courier Prime for records and statements, Caveat for handwritten case board notes.

## Models

- **Realistic proportions and real-world scale.** 1 unit is 1 metre. Doors 2.04 m, period ceilings 3.0 m, a grid tile 1.0 m (with half-tile placement, see `docs/HOUSE_BUILDING.md`).
- **Polygon budget per item:** small props under 2,000 triangles, furniture under 6,000, residents under 10,000 at LOD0 with LOD1 under 3,000.
- **Materials:** PBR with up to 4 maps (albedo, normal, ORM packed occlusion, roughness and metallic). Share materials across items wherever possible.
- **Every customisable object** exposes named material slots (for example "frame" and "upholstery") so the Design tool can change them (`docs/HOUSE_BUILDING.md`).
- **Architecture is procedural:** walls, floors, ceilings, roofs, stairs, trims, mouldings, window sashes and door frames are generated in code from the building data, with real profiles (skirting, architrave, weatherboard lap) and PBR materials.

## Residents

- Semi-realistic people with realistic proportions and gentle, appealing faces. Made with **MPFB** (MakeHuman for Blender, CC0 core assets) and animated with Mixamo or the Quaternius Universal Animation Library (`docs/ASSET_SOURCES.md`).
- 1950s clothing, hair and hats. Each resident's look is data in `data/residents.json`.
- Expressions through a small set of facial blend shapes (neutral, happy, sad, angry, nervous, surprised) used in live mode and interviews.
- Interview portraits can be **live 3D close-ups** of the resident with a portrait light rig, so portraits always match the world. Gemini portraits become optional (for menus and the case file).

## Lighting and time

| Time | Sun or moon | Ambient (HDRI) | Interior |
|---|---|---|---|
| Morning | Low warm sun, long shadows | Soft blue-gold sky | Lamps off |
| Midday | High neutral sun | Bright sky | Lamps off |
| Dusk | Orange, very long shadows | Pink-orange sky | Lamps switching on |
| Night | Cool moonlight, faint | Dark blue sky | Warm lamps and lit windows dominate |

Weather: rain (particles near the camera, wet roughness on ground and roofs, puddle decals), frost in winter mornings, heat haze and dry grass in drought.

## UI components

White panels with a 14 px radius and soft shadow, pill chips, rounded bars, line icons, maroon incident banners and `paper` record cards, as in the layout references.

## Web delivery

- **Texture compression:** import 3D textures as **Basis Universal** so one small file works on desktop and phone GPUs.
- **First download under 40 MB compressed:** the engine, the valley, the starting catalogue and the founding residents.
- **More downloads on demand:** later catalogue items, chapters and extra residents ship as additional resource packs, downloaded in the background and loaded with `ProjectSettings.load_resource_pack()`, with a small progress chip.
- **Frame rate targets:** 60 fps on computers at High, 30 fps on a mid-range phone at Medium with a 6-house street and 20 residents.

## What not to do

- No stylised low-poly or toon art. Everything should look like real objects with real materials.
- No effects that need Forward+ (SDFGI, SSR, volumetric fog). They don't exist on the web.
- No huge textures. 2048 px maximum, and only on High.
- No AI-generated 3D models or textures. AI is only for optional 2D portraits.
- No dark UI panels.
