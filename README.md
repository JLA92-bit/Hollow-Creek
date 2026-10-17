# Hollow Creek - Starter Kit for Claude Code

A semi-realistic 3D town builder, life sim and detective game that runs in the browser on phones and computers. Country Victoria, 1952. You design every home with life-sim depth, from storeys and roofs to the colour of each cushion. Residents live real lives in your homes, and when something goes wrong you solve the crime, using clues that come from the town you built.

Built with Godot 4 and GDScript. Plays from a link on your site and installs on phones as a web app.

## How to start (about 10 minutes of your time)

1. **Create a private GitHub repository** called `hollow-creek`.
2. **Copy every file in this kit** into the repository root, keeping the folders. Commit and push.
3. **Open the repository in Claude Code.**
4. **Paste the prompt in `KICKOFF_PROMPT.md`** and let it run.

Claude Code works through `docs/PLAN.md` one milestone at a time, and after each one gives you a short summary and a build to play.

## What you'll need to do along the way

| When | What | Time |
|---|---|---|
| M0 | If Claude Code can't reach Poly Haven or ambientCG, download the asset batches it lists | A few minutes per batch |
| End of M1 | **Approve the look** from screenshots of a furnished cottage at four times of day | 10 minutes |
| M2 to M4 | **Play with the build tools** and say what feels wrong. This is the heart of the game | As long as you like |
| Before M9 | Download Mixamo animations (free Adobe account) | 20 minutes |
| Before M10 | Choose hosting, add one DNS record, make a feedback form (`docs/DEPLOY.md`) | 30 minutes |

Everything else, including materials, furniture, 1950s props, residents, sounds, the build system, the simulation and the first two cases, is sourced or built by Claude Code.

## What's in the kit

| File | Purpose |
|---|---|
| `KICKOFF_PROMPT.md` | The prompt to paste into Claude Code |
| `CLAUDE.md` | Project rules Claude Code reads every session |
| `docs/PLAN.md` | Milestones, tasks and acceptance checks |
| `docs/GAME_DESIGN.md` | The whole game: loop, resources, crimes, consequences, story |
| `docs/HOUSE_BUILDING.md` | Build and Buy modes in full: storeys, stairs, walls, surfaces, roofs, verandahs, the Design tool, terrain, Sandbox, share codes, scores, wishes |
| `docs/BUILDING.md` | The grid, walls, doors, windows, light, sightlines and ground traces |
| `docs/SIMULATION.md` | Residents: needs, traits, routines, relationships, memories, statements |
| `docs/CRIME_DIRECTOR.md` | How fair, solvable crimes are planned from the simulation, and how they're tested |
| `docs/RESIDENTS.md` | The founding families, their secrets, shoe sizes and wishes |
| `docs/CASE_00_CASH_TIN.md` | The tutorial case, written in full |
| `docs/CASE_01_LOW_WATER.md` | The Chapter 1 murder, written in full |
| `docs/ART_DIRECTION.md` | The semi-realistic look within the web renderer, quality presets, budgets |
| `docs/ASSET_SOURCES.md` | Every asset source and licence: ambientCG, Poly Haven, MPFB, Mixamo, fonts, sound |
| `docs/DEPLOY.md` | Getting it onto your site and testers' phones |
| `docs/DECISIONS.md` | Decisions, defaults, and what waits for you |
| `docs/mockups/` | UI layout references (panel layouts only, not the final art) |
| `tools/` | Verified setup script, smoke test and Godot templates |
