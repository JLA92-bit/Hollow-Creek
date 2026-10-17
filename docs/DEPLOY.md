# Hollow Creek - Getting it to testers

The plan has three stages. Stage 1 is free, works on every phone and needs no app store.

| Stage | What testers get | Cost | When |
|---|---|---|---|
| 1. Web app on your site | A link that plays in the browser and installs to the home screen | Free | M10 |
| 2. Android APK | A download from your site, installed directly | Free | Optional, M12 |
| 3. App stores | Google Play testing and Apple TestFlight | US$25 once (Google), US$99 a year (Apple) | When you're close to launch |

## Facts that shape these choices

- The build is **single-threaded**, so it needs **no special server headers**. It works on any normal web host.
- Godot's **PWA option** adds an install icon, full-screen mode and offline play after the first visit.
- The engine file `index.wasm` is about **39.5 MB raw** and **9.6 MB gzipped**. Use a host that compresses files, or loads will be slow on phones.
- **Cloudflare Pages is not suitable as-is:** it caps single files at 25 MiB, which the raw `.wasm` exceeds.
- Saves live in the browser's storage. Clearing browser data deletes them. That's why the game has an **export and import save code** feature.
- Hollow Creek is **landscape** and **3D**. Phones play it sideways (the game shows a "rotate your phone" prompt), and older phones may need the lower graphics setting (shorter shadows, fewer lamps as real lights). Test on a real phone before inviting testers.

---

## Stage 1: web app on your site

Pick the option that matches your site. Claude Code sets up whichever you choose in M10.

### Option A (default): GitHub Pages on a subdomain, like `play.yoursite.com`

Works whatever your main site runs on, because only a DNS record changes.

1. **Josh** creates a second, **public**, empty repository called `hollow-creek-play`. It holds **only the built game**, never the source. (GitHub Pages on a private repository needs a paid plan, so this keeps the code private for free.)
2. The GitHub Actions workflow in the private `hollow-creek` repo builds the game and pushes it to `hollow-creek-play`. Pushes to `beta` publish to `/beta/` and pushes to `main` publish to the root.
3. **Josh, once:** add a CNAME record at your domain's DNS provider: `play` pointing to `<your-github-username>.github.io`. Then in `hollow-creek-play` settings, Pages, set the custom domain and tick "Enforce HTTPS".
4. Claude Code needs a fine-grained GitHub token with write access to `hollow-creek-play`, stored as the secret `PLAY_REPO_TOKEN` in `hollow-creek`. **Josh creates the token** (Settings, Developer settings, Fine-grained tokens).

Why it's the default: free, HTTPS, compresses `.wasm` automatically, files up to 100 MB, and separate beta and stable links.

### Option B: a folder on your existing site, like `yoursite.com/hollow-creek/`

Use this if your site is on ordinary web hosting (cPanel, Apache, Nginx) and you can upload files.

1. Upload everything in `build/web/` to a folder on the site.
2. Make sure `.wasm` files are served with the right type and compressed. On Apache, put this in `.htaccess` in that folder:

```apache
AddType application/wasm .wasm
AddType application/octet-stream .pck
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/javascript application/javascript application/json application/wasm application/octet-stream
</IfModule>
```

3. Optional: Claude Code can add an SFTP deploy step to CI. **Josh provides** the host, username and an SSH key or password as GitHub secrets.

If your site is on a site builder (Squarespace, Wix, Google Sites and so on) you can't host the game files there. Use Option A for the game and add a button or link on your site.

### Option C: itch.io, linked or embedded on your site

The quickest to set up, with a built-in comments section and password protection for restricted pages.

1. **Josh:** create an itch.io account and a new HTML game project, set it to restricted with a password.
2. Claude Code builds a zip of `build/web/` for upload. With an API key from Josh, it can publish automatically using itch's `butler` tool in CI.
3. Downside: itch.io doesn't compress files, so first loads are slower on phones.

### Keeping it to invited testers

| Approach | Effort | How secure |
|---|---|---|
| **Unlisted link (default)** | None. Only share the link with testers | Anyone with the link can play |
| Tester code screen in the game | Claude Code adds it | Keeps casual visitors out. Not truly secure |
| itch.io restricted page with a password | A few clicks | Simple and good enough for most betas |
| Cloudflare Access in front of Option A | Move DNS to Cloudflare, set up an email login rule | Real invite-only. The Zero Trust free plan covers up to 50 users |

### What testers do

Claude Code builds a simple landing page with these instructions.

- **iPhone or iPad (Safari):** open the link, tap **Share**, then **Add to Home Screen**. Open it from the new icon.
- **Android (Chrome):** open the link, tap **Install** when prompted, or use the menu then **Add to Home screen**.
- **Computer:** just play in the browser, or use the install icon in Chrome or Edge.
- **Feedback:** the **Feedback** button in the pause menu opens your form with the version and screen filled in. **Josh:** make a Google Form, Microsoft Form or Tally form and give Claude Code the link.

### Updating testers

Every push to `beta` or `main` redeploys. The game shows a "What's new" card when the version changes. Installed web apps pick up the new version the next time they're opened with an internet connection.

---

## Stage 2: Android APK from your site (optional)

Native performance and a proper app icon, with no store involved.

1. Claude Code sets up the Android export (`WITH_ANDROID=1 bash tools/setup_godot.sh`, OpenJDK 17, Android SDK) and creates a release keystore. **Josh keeps a backup of the keystore and its password.** Losing it means testers have to uninstall and reinstall.
2. CI builds a signed APK and puts it on the landing page as a download.
3. Testers allow "Install unknown apps" for their browser when Android asks. Some people won't be comfortable with this, so keep the web version as the main route.

## Stage 3: app stores (when you're closer to launch)

### Google Play

- Registration is a one-off **US$25**.
- **Internal testing** gets builds to a small group quickly.
- New **personal** developer accounts (created after 13 November 2023) must run a **closed test with at least 12 testers for 14 days in a row** before they can apply for production. Google also checks testers actually used the app. Start this early with your most engaged web testers.

### Apple TestFlight

- Needs the **Apple Developer Program**, **US$99 a year** (charged in local currency).
- Exporting for iOS must be done **on a Mac with Xcode**. Claude Code can prepare everything else, but the final export, archive and upload happen on a Mac.
- Up to **10,000 external testers**, invited by email or a **public link**. The first build must pass a beta app review before external testers can use it. Builds expire after 90 days.

---

## Josh's checklist for M10 (default path)

- [ ] Create the empty public `hollow-creek-play` repository
- [ ] Pick a subdomain, such as `play.yoursite.com`
- [ ] Add the CNAME record at your DNS provider
- [ ] Create the fine-grained GitHub token and add it as `PLAY_REPO_TOKEN`
- [ ] Make a feedback form and send Claude Code the link
- [ ] Try the build on your own iPhone or Android phone before sharing
- [ ] Send the link to your first five testers
