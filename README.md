# Daily Health Score

Local-first Progressive Web App that imports daily sleep, dietary fiber, and Apple Health **Exercise Minutes** from an Apple Shortcut, scores them against adjustable goals, stores the last **90 days** in **localStorage**, and shows calm Today / 7-Day / 30-Day / 90-Day dashboards plus Settings.

## Tech stack

- React 19 + TypeScript  
- Vite 7  
- `react-router-dom` (client-side routing)  
- Plain CSS (mobile-first, clinical minimal UI)  
- PWA `manifest.webmanifest` + **`public/DHS.png`** as install / favicon asset  
- Deployed on **Vercel**: static SPA plus **Vercel Functions** under `/api/*` backed by **Vercel KV**

Optional cloud sync: generate a **Bearer token** in **Settings** so a Home Screen Shortcut can **POST** today’s metrics to `/api/ingest`, and then open the PWA. Data is stored in KV and the **Add to Home Screen** app pulls it when opened.

There is no traditional account system, HealthKit in-app usage, or AI APIs.

## Install & run locally

```bash
npm install
npm run dev
```

Dev server (default): [http://localhost:5173](http://localhost:5173)

Production build:

```bash
npm run build
npm run preview
```

## Test import URLs (local)

Valid import (default goals 7.5h sleep, 40g fiber → displayed **9.6 / 10**, sleep **3.9 / 4**, fiber **3.8 / 4**, exercise **1.9 / 2**):

http://localhost:5173/import?date=2026-05-01&sleep=7.4&fiber=38&exercise=28

Manual correction (sleep was `0`):

http://localhost:5173/import?date=2026-05-01&sleep=0&fiber=38&exercise=28

Invalid date:

http://localhost:5173/import?date=bad-date&sleep=7.4&fiber=38&exercise=28

## Deploy to Vercel (from GitHub)

1. Push this repository to GitHub.  
2. In [Vercel](https://vercel.com): **Add New Project** → Import the repo.  
3. Framework preset: **Vite**.  
4. Build command: `npm run build`  
5. Output directory: `dist`  
6. Confirm **`vercel.json`** is present: SPA fallback sends non-API routes to `index.html` while **`/api/*`** stays on serverless functions.

### Vercel KV (cloud backup)

1. In the Vercel project: **Storage** → **Create Database** → **KV**.  
2. Connect it to this project so **`KV_REST_API_URL`** and **`KV_REST_API_TOKEN`** are injected at build/runtime (see also **`.env.example`** for local preview).  
3. Open the deployed app → **Settings** → **Generate sync token** (same value everywhere—keep it secret).

### Shortcut: Home Screen launcher (recommended)

Use one Home Screen Shortcut icon as the app launcher. The Shortcut should:

1. Format today's local date as `yyyy-MM-dd`.
2. Read AutoSleep **Time Asleep** for the sleep episode that belongs to the **import date** (usually the night that ended when you woke up that morning—not a leftover placeholder value).
3. Read Apple Health **Dietary Fiber** for today.
4. Read Apple Health **Exercise Minutes** for today.
5. `POST` one record to `/api/ingest`.
6. Open the PWA URL.

Each run overwrites today’s record. The app stores the latest 90 days moving forward; skipped days are not backfilled.

### Shortcut: POST ingest

`POST` **`https://YOUR-VERCEL-APP.vercel.app/api/ingest`**

Body (recommended field names—real AutoSleep hours should map into **`sleepHours`**, not a fixed number left in **`sleep`**):

```json
{
  "syncToken": "<your-sync-token>",
  "date": "yyyy-MM-dd",
  "sleepHours": 7.4,
  "fiberGrams": 38,
  "exerciseMinutes": 28
}
```

The same numbers may still be sent as `sleep`, `fiber`, and `exercise`; those names are supported. When both `sleepHours` and `sleep` are present, **`sleepHours` wins** so a stale template `sleep` value cannot override real data.

Zeros are accepted and score as zero. The server scores the day, rotates suggestions, merges into KV (last **90** days), and the PWA pulls when opened or refocused.

Optional **`GET /api/data`** / **`PUT /api/data`** use the Bearer token header for full sync of records + settings + suggestion rotation state. The Shortcut-specific ingest endpoint can use `syncToken` in the JSON body to avoid iOS Shortcuts header issues.

### Shortcut: Open URL (alternative)

```text
https://YOUR-VERCEL-APP.vercel.app/import?date=yyyy-MM-dd&sleep=[sleep]&fiber=[fiber]&exercise=[exercise]
```

Example:

```text
https://YOUR-VERCEL-APP.vercel.app/import?date=2026-05-01&sleep=7.4&fiber=38&exercise=28
```

## Shortcuts vs “Add to Home Screen” (where data is stored)

On **iOS**, a Shortcut that **Opens URLs** usually opens **Safari**, not the standalone web app created with **Add to Home Screen**. Safari and that standalone app can use **different storage**, so data imported via the Shortcut might **not** show up in the Home Screen icon.

**Recommended fix:** Use the Home Screen Shortcut launcher. It sends metrics to **Vercel KV** first, then opens the PWA so the app pulls the same data regardless of browser storage buckets.

**Manual URL fix:** In the **installed** app, open **Settings → Import into this app**, paste the **full import URL**, and tap **Run import**. That executes `/import` in the **same** client you use for Today (same `localStorage`).

Shortcut ideas:

- Add **Copy to Clipboard** with the URL, then you paste it into the app; or  
- Still **Open URLs** for convenience, then copy from the address bar and paste into Settings if the dashboard icon does not see the data.

Alternatively, skip the Home Screen icon and use **only Safari** so Shortcut imports and the dashboard always share one browser profile.

On **Android**, behavior varies by browser and install mode; when unsure, use the same **paste import** flow inside the installed PWA.

## Behavior notes

- If **sleep**, **fiber**, or **exercise** is **0** in the URL, the app opens **manual correction** for only the zero fields (values must be &gt; 0 before save).  
- If **sleep**, **fiber**, or **exercise** is **0** via the cloud API, the value is accepted and scores as zero.  
- Duplicate **date** imports **overwrite** the prior record.  
- **Open URL** imports: the app prefers **`sleepHours`** (then `timeAsleep`, then `sleep`) and similar explicit names for fiber and exercise when multiple keys exist. If `sleep`, `fiber`, `exercise`, or `date` appears **more than once** for the same name, the app uses the **last** value for that name.
- Only the **most recent 90** calendar-dated records are kept.  
- With **cloud sync** enabled, records also sync to **KV** (last **90** days server-side); local **localStorage** still holds the working copy after pull.  
- The Shortcut imports today only. If you skip a day, that day is not backfilled.
- **Exercise goal** is fixed at **30 minutes** (matching the scoring formula).

### If sleep looks “stuck” but fiber and exercise change

The dashboard shows **exactly what was saved** for that calendar day—it does not re-read Apple Health by itself. Typical causes:

1. **The Shortcut is still sending the same sleep number** — Often the JSON field **`sleep`** is a typed placeholder (for example `7.7`) while AutoSleep is connected to a different field. Put AutoSleep **Time Asleep** into **`sleepHours`** in the Request body (see POST example above), or re-wire the variable so **`sleep`** is the live Health value, not fixed text.

2. **Same duration several nights** — Less common, but confirm in the Health app.

3. **Fix it in the app** — Open **Settings → Adjust a saved day**, enter the date and the correct hours/grams/minutes from Health, and tap **Save this day**.

After a URL import, **Today** shows a short confirmation line with the numbers that were stored so you can spot a mismatch right away.

## LocalStorage keys

| Key | Purpose |
|-----|---------|
| `dailyHealthScore.records` | Daily records |
| `dailyHealthScore.settings` | Sleep / fiber goals |
| `dailyHealthScore.usedSuggestions` | Rotation state for suggestions |
| `dailyHealthScore.usedDiscouragementParagraphs` | Rotation for “Feeling discouraged?” |
| `dailyHealthScore.usedMotivationParagraphs` | Rotation for “Need motivation?” |
| `dailyHealthScore.syncToken` | Sync token for `/api/*` (optional; device-local only) |

## App icon

Branding lives at **`public/DHS.png`** (linked from `manifest.webmanifest`, favicon, and `apple-touch-icon`). For faster loads you can replace it later with optimized **192×192** and **512×512** PNGs and reference both sizes in the manifest.
