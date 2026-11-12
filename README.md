# Fast — fasting timer + macro tracker (Firebase PWA)

Installable, mobile-first web app for tenebris's extended fasts (24h+) and daily macros.
Firebase Hosting + Firebase Auth (Google sign-in) + Cloud Firestore. No build step.
All times shown in the device's local time; the bot CLI assumes America/Santo_Domingo (UTC-4).

> `README-canvas-legacy.md` / `data.json` belong to the earlier in-chat Page version and are not used by this app.

## Status
- **Live:** https://fasting-tracker-tx.web.app (main) — also https://acoplao-2fe95.web.app (same app, same data).
- Firebase project `acoplao-2fe95` (display name renamed to "Fasting Tracker"; the ID can't change). Firestore `(default)` standard/nam5, Spark plan.
- Deployed with: `./deploy.sh acoplao-2fe95 tenebrsx@gmail.com fasting-tracker-tx`
- Authorized domains: localhost, acoplao-2fe95.{web.app,firebaseapp.com}, fasting-tracker-tx.{web.app,firebaseapp.com}.

## Layout
```
public/              static app (deployed to Hosting)
  index.html styles.css app.js sw.js manifest.webmanifest icons/
firestore.rules      per-user security rules
firebase.json        hosting / firestore / emulators (+ auth block written by deploy.sh)
deploy.sh            one-shot setup + deploy:  ./deploy.sh <project-id> [owner-email]
tools/fast.mjs       bot CLI that reads/writes the same Firestore data
tools/config.json    { projectId, email[, uid] } for the bot CLI (no secrets)
```
The app reads its Firebase config from Hosting's reserved `/__/firebase/init.json`, so nothing project-specific is hard-coded.

## Deploy
```bash
cd /workspace/fasting
./deploy.sh <project-id> tenebrsx@gmail.com [extra-site-ids]
```
It: writes `.firebaserc`; adds the Google sign-in provider to `firebase.json` (with redirect URIs for `<id>.web.app` and `<id>.firebaseapp.com`);
creates a WEB app; creates the `(default)` Firestore database (standard edition, `nam5`, works on the free Spark plan);
runs `firebase deploy --only auth,firestore,hosting`; and sets `tools/config.json`.
Live URL: `https://<project-id>.web.app`.

Photos are stored as small (≤560px JPEG, <300 KB) data URLs on the meal doc, so Cloud Storage (which now needs the Blaze plan) is not required.

## Sign-in
"Continue with Google". Popup in a browser tab; redirect when launched from the home screen.
`authDomain` is set to the app's own domain at runtime so redirect sign-in works in iOS standalone mode/Safari.
Every Google account gets its own isolated data (`users/{uid}`); there's no shared data.

## Firestore schema
```
users/{uid}                      { email, name, lastSeen }            ← written by the app on sign-in; the bot uses it to find the uid
users/{uid}/fasts/{id}           { start: timestamp, end: timestamp|null, targetHours: number,
                                   notes: string, source: 'app'|'bot', createdAt, updatedAt }
users/{uid}/meals/{id}           { time: timestamp, description: string, calories, protein_g, carbs_g, fat_g: number|null,
                                   source: 'photo'|'manual', notes: string, photo: dataURL|null, createdAt, updatedAt }
users/{uid}/settings/main        { targets: { calories, protein_g, carbs_g, fat_g: number|null }, defaultFastHours: number, updatedAt }
```
- Active fast = the most recent fast with `end == null` (only one should be open at a time).
- Defaults: `protein_g: 120` (treated as a minimum), others `null` (no target), `defaultFastHours: 24`.
- Rules (`firestore.rules`): a signed-in user may only read/write `users/{their uid}/**`, with type checks on fasts/meals. Everything else denied.

## How the bot writes data
`tools/fast.mjs` calls the Firestore REST API as the project owner using the **Firebase CLI's existing login on this box**
(`firebase-tools` library auth — same account as `npx firebase-tools login:list`). No service-account key or token is stored or printed.
Owner credentials bypass security rules, so the CLI writes straight into `users/{uid}/...`.
The uid is found from `users/*` by `email` in `tools/config.json` (he must have signed in to the app once), or set `"uid"` there.

```bash
cd /workspace/fasting/tools
node fast.mjs status                                   # active fast, elapsed hours, today's totals vs targets
node fast.mjs start-fast --hours 36                    # start now (default length from settings)
node fast.mjs start-fast --at "2026-11-12 20:00" --hours 48 --notes "after dinner"
node fast.mjs end-fast                                 # end the running fast now
node fast.mjs end-fast --at "2026-11-14 08:30" --notes "felt great"
node fast.mjs set-target --hours 72                    # change goal of the running fast
node fast.mjs edit-fast <id> --start "2026-11-12 19:00" --end null
node fast.mjs list-fasts --n 10  |  node fast.mjs delete-fast <id>

node fast.mjs add-meal --desc "3 eggs, 2 toast, avocado" --cal 620 --protein 28 --carbs 45 --fat 36 --source photo --photo /path/to/photo.jpg
node fast.mjs add-meal --desc "Protein shake" --protein 40 --cal 220 --at "2026-11-12 13:15"
node fast.mjs list-meals --date 2026-11-12  |  node fast.mjs edit-meal <id> --protein 35  |  node fast.mjs delete-meal <id>

node fast.mjs set-targets --protein 130 --cal 2000 --carbs null --default-hours 36
```
Times: ISO, or `"YYYY-MM-DD HH:mm"` interpreted as UTC-4 (America/Santo_Domingo). Output is JSON (timestamps in UTC `Z`).
If the CLI login ever expires: `npx -y firebase-tools@latest login --no-localhost` (needs the user).

Alternative if a long-lived credential is preferred later: create a service account with role `Cloud Datastore User`
in the project, keep its key outside chat-visible paths (e.g. `~/.config/fast/sa.json`, mode 600), and switch `api()` in
`tools/fast.mjs` to `google-auth-library` with that key.

## Local testing (emulators)
```bash
export JAVA_HOME=~/.local/jre/jdk-21*  PATH=$JAVA_HOME/bin:$PATH
npx -y firebase-tools@latest emulators:start --project demo-fasting --only auth,firestore,hosting
# app:  http://localhost:5002/?emu=1     bot: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FAST_PROJECT=demo-fasting node tools/fast.mjs status
```
