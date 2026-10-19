# Handover - 19 October 2026

Read `CLAUDE.md`, then this, then `docs/PROGRESS.md` (newest first), `docs/PLAN.md` and `docs/DEPLOY.md`.

Branch: `claude/compassionate-fermat-5ldlj5`. No PR has been opened; don't open one unless Josh asks.

## First point: connect Cloudflare (blocks the tester release)

Josh wants the game hosted on his domain **https://joshmakesgames.app/** (Cloudflare). This session had no access, so before anything else check whether it is now set up:

1. `env | grep -i cloudflare` should show `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
2. `curl -sS -m 15 -I https://api.cloudflare.com/client/v4/user/tokens/verify` should not return 403 from the proxy.
3. If either fails, tell Josh what is missing (do not work around it). He needs to:
   - In the cloud environment settings, Network access: allow `joshmakesgames.app`, `api.cloudflare.com` and `*.pages.dev` (or a broader level). See `read_documentation` topic `environment.network`.
   - Create a Cloudflare API token (template "Edit Cloudflare Workers", plus R2 edit) and add it as a secret in the environment, with the account ID.
   - Say which subdomain to use (suggested `play.joshmakesgames.app`, leaving the main site alone).

Plan once connected: Pages and Workers assets cap single files at 25 MiB and `index.wasm` is 39.5 MB raw, so serve the build from an **R2 bucket behind a small Worker** on the subdomain (correct `application/wasm` type, cache headers, edge compression). Fallback is GitHub Pages plus CNAME (`docs/DEPLOY.md` Option A, needs a public `hollow-creek-play` repo and a token from Josh).
Steps: re-export web, `bash tools/build_packs.sh`, upload `build/web/` including `packs/`, run `node tools/web_smoke_test.mjs` against the live URL, give Josh the link. Do not announce or share it publicly; it is a test build. Add the deploy to CI only with his go-ahead.

## Where things stand

| Milestone | State |
|---|---|
| M0 to M9 | Done and pushed: build tools, residents, night and sightlines, investigation, crime director (500-seed soak met targets), prologue and The Cash Tin, settings, saves, audio, background packs |
| Post-M9 | Done: Quaternius animations retargeted (shared set), street-lamp tool (deters robbery), interview portraits with five expression shapes, automatic UI scale for phones |
| M10 Tester release | Not started. Needs Josh: hosting (above), who the testers are, a feedback form (`docs/DECISIONS.md` 11 to 13) |

278 GUT tests pass on desktop. First download is about 39.1 MB gzipped of the 40 MB budget, so new content goes into background packs (`tools/build_packs.sh`, `data/packs.json`). The characters pack is about 5.3 MB.

## Known gaps (honest list)

- Browser run of `scenes/story/phone_demo.tscn` at `--viewport 844x390 --dpr 2` stalls at the case-screen step under SwiftShader (twice); desktop xvfb at 844x390 passes 8/8. Likely a software-renderer limit; confirm on a real phone.
- Not re-done since the last changes: fresh web export, packs rebuild, smoke test, browser prologue playtest (about 60 min on SwiftShader) and its lamp screenshot.
- Hair is a cap or bun with a rough edge; clothes are MPFB helper shells.
- No timed human playtest; the 40 to 60 minute target is only a clock estimate.
- Only theft crimes; generated cases do not use the exchange log or time cards; authored beats and fallbacks are missing; music is simple synthesis.
- Estimate to a tester build: two to three focused sessions after Josh's M10 decisions.

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

## Josh's requests, 19 October 2026 (not started)

- **Android APK that checks for updates (in progress, blocked on network):** built so far: Android export preset (landscape, arm64, `app.joshmakesgames.hollowcreek`), launcher icons, `autoload/update_checker.gd` (Android only: reads `version.json` from the test site, offers a Download card; 5 tests), `data/update.json`, `tools/build_apk.sh`, `tools/make_version_json.py`, `tools/android/make_keystore.sh`. Godot's Android templates are installed. Blocked: the Android SDK (`dl.google.com`) is not reachable, so no APK yet. Next: allow `dl.google.com`, install cmdline-tools, build-tools and platform-tools into `~/android-sdk`, run `bash tools/build_apk.sh`, publish `hollow-creek.apk` and `version.json` to `hollow-creek-play`. The signing key must be the same for every release (Josh keeps a backup; the cloud copy is in `tools/cache/android`, git-ignored). Android never installs silently: the player taps Download, then Install.
- **A controllable player character:** the Administrator and Constable should walk where the player directs (tap to move or a stick). Design needed first: camera, how it interacts with build mode and sightlines (what the player is seen doing).
- **Phone layout:** UI scale now uses CSS pixels, upright phones get a turn-sideways cover, and build mode has a compact layout (tool and House buttons, prologue pill). Verified on a desktop renderer at 844x390, 667x375 and 932x430 and in headless Chromium with a 3x phone; not yet on a real phone.
