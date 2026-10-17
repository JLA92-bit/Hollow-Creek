# Kickoff prompt

Paste everything inside the box into Claude Code for the first session.

```
You are the lead developer on Hollow Creek, a semi-realistic 3D town builder, life sim
and detective game set in 1952 country Victoria, built in Godot 4 with GDScript. It runs
in the web browser on phones and computers, installable as a Progressive Web App.

Before writing any code, read these files in full:
  CLAUDE.md
  docs/PLAN.md
  docs/GAME_DESIGN.md
  docs/HOUSE_BUILDING.md
  docs/BUILDING.md
  docs/SIMULATION.md
  docs/CRIME_DIRECTOR.md
  docs/RESIDENTS.md
  docs/CASE_00_CASH_TIN.md
  docs/CASE_01_LOW_WATER.md
  docs/ART_DIRECTION.md
  docs/ASSET_SOURCES.md
  docs/DEPLOY.md
  docs/DECISIONS.md
Then look at the images in docs/mockups/. They are UI layout references only, not the
art style. The art style is in docs/ART_DIRECTION.md.

Work through docs/PLAN.md milestone by milestone, starting at M0.

How to work:
- Source and set up everything yourself: the Godot binary, export templates, GUT,
  fonts, ambientCG materials and Poly Haven models and skies (docs/ASSET_SOURCES.md).
  Build the architecture, 1950s props, residents and sounds yourself. If something is
  blocked or needs a login, add it to docs/ASSET_REQUESTS.md and use a placeholder.
- Use the defaults in docs/DECISIONS.md. Only stop and ask me when a decision is marked
  "needs Josh" and you have reached the milestone where it matters.
- Building homes is half the game, with life-sim depth and control. Treat M2, M3 and M4
  as the heart of the experience: every tool should feel direct, precise and satisfying,
  with handles, snapping guides, live costs and score previews, sound and undo.
- Stop after M1 and show me the look test screenshots before going further.
- The simulation and crime director must be deterministic and tested from the start.
  Never ship an unsolvable case.
- Every milestone ends with: tests passing, a fresh web export, a headless-browser
  screenshot, a commit, and an update to docs/PROGRESS.md.
- After each milestone, tell me in no more than five lines what now works, what I should
  try, and anything you need from me. Then continue unless I've asked you to pause.
- Keep scope tight. If something is bigger than expected, build the simplest version that
  meets the acceptance criteria and log the rest in docs/BACKLOG.md.

Start now with M0.
```

## Prompt for later sessions

```
Continue building Hollow Creek. Read CLAUDE.md and docs/PROGRESS.md, then carry on from
the next unfinished milestone in docs/PLAN.md, following the same working rules.
```

## Handy one-liners

- "Pause after this milestone and give me a link to try the build."
- "Make me a Sandbox save so I can play with the build tools."
- "Run the director soak test and show me the numbers."
- "I've put downloaded assets in assets/incoming. Import them and update CREDITS.md."
- "Make a tester build and deploy it following docs/DEPLOY.md."
