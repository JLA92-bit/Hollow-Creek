# Handover - 18 October 2026

Read `CLAUDE.md`, then this, then `docs/PROGRESS.md` (newest first) and `docs/PLAN.md`.

Branch: `claude/compassionate-fermat-5ldlj5`. No PR has been opened; don't open one unless Josh asks.

## Where things stand

| Milestone | State |
|---|---|
| M0 to M6 | Done: tests, demos, browser runs, screenshots and docs committed (`docs/screens/m0` to `m6`) |
| M7 Investigation tools | Done: rules, statements from memories, investigation screen with live portrait, Cash Tin demo (57 of 57 headless and in the browser) |
| M8 The crime director | Done: motives, plans, trial on snapshots, case builder, solver bot, director, SimHost wiring. 500-seed soak met every target (`docs/soak/m8_soak.json`) |
| M9 Prologue and The Cash Tin | Done except the art that waits on Josh's animation download: the whole prologue plays through (32 of 32, browser too), settings, saves, audio, ten MPFB residents, background packs |
| M10 Tester release | Not started. Needs Josh: hosting, tester access and a feedback form (`docs/DECISIONS.md` 11 to 13) |

261 GUT tests pass. Night demo 12 of 12, residents demo 20 of 20, investigation demo 57 of 57, director demo 12 of 12, all also in the browser. Soak: `tools/director_soak.gd` (split across cores with `--from`; 125 seeds x 28 days takes about 45 minutes on a shared core). First download is 38.7 MB gzipped (budget 40 MB), so new content must go into background packs (`tools/build_packs.sh`, `data/packs.json`).

Josh needs his M9 update (and the animation download) (five lines each at most: what works, what to try, what's needed).

## Environment notes

- **Settings and saves:** Esc opens the pause menu in the world; Settings has save slots and save codes.
- **Packs:** after a web export run `bash tools/build_packs.sh`; the build serves `packs/*.pck` next to `index.html`.
- **`tools/cache/.gdignore`** must exist (setup_blender.sh makes it) or Godot scans the Python venv.
- **Lambdas capture plain variables by value** in GDScript; share a Dictionary when a signal handler must set a flag.

- **The cloud VM suspends when the session is idle, which kills background jobs.** For long runs (look tests take 12 to 25 minutes) start the job detached with `setsid nohup ... &`, save its PID, then wait in the foreground with `timeout 590 tail --pid=$PID -f /dev/null`, repeating until it finishes. Don't `pgrep -f` for it from the tool shell (it matches itself); use `ps -p $PID`.
- Playwright is global: `ln -sfn "$(npm root -g)/playwright" node_modules/playwright` before running `look_test.mjs` (`node_modules` is ignored by git).
- Godot is in `tools/bin/` and Blender (`bpy`) in `tools/cache/blender-venv/`; both git-ignored. Reinstall with `bash tools/setup_godot.sh` and `bash tools/props/setup_blender.sh`.
- Run `--import` after adding scripts (the `class_name` cache).
- Don't `pkill -f chromium` from the tool shell. Kill by PID.
- `look_test.mjs` parses lines starting `HC_PERF ` as JSON, so demos print `HC_DEMO perf ...` instead.

## Open issues

See "Known issues" in the M6 entry of `docs/PROGRESS.md` and the M5 rows in `docs/BACKLOG.md`.
