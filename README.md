# Daily Health Score

Local-first Progressive Web App that imports daily sleep, dietary fiber, and Apple Health **Exercise Minutes** from an Apple Shortcut, scores them against adjustable goals, stores the last **90 days** in **localStorage**, and shows calm Today / 7-Day / 30-Day / 90-Day dashboards plus Settings.

## Tech stack

- React 19 + TypeScript  
- Vite 7  
- `react-router-dom` (client-side routing)  
- Plain CSS (mobile-first, clinical minimal UI)  
- PWA `manifest.webmanifest` + **`public/DHS.png`** as install / favicon asset  
- Deployed on **Vercel**: static SPA plus **Vercel Functions** under `/api/*` backed by **Vercel KV**

Optional cloud sync: generate a **Bearer token** in **Settings** so a Home Screen Shortcut can ask `/api/sync-status` what dates need refresh, **POST** JSON to `/api/ingest`, and then open the PWA. Data is stored in KV and the **Add to Home Screen** app pulls it when opened.

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
2. `GET` **`https://YOUR-VERCEL-APP.vercel.app/api/sync-status?today=yyyy-MM-dd`** with the Bearer token.
3. For each returned date, read:
   - AutoSleep **Time Asleep** for the sleep session ending on that date.
   - Apple Health **Dietary Fiber** for that date.
   - Apple Health **Exercise Minutes** for that date.
4. `POST` each date to `/api/ingest`.
5. Open the PWA URL.

The first run imports the latest 90 days. Later runs import today, missing dates, and dates previously marked partial. Today is partial; prior dates are complete.

### Shortcut: POST ingest

`POST` **`https://YOUR-VERCEL-APP.vercel.app/api/ingest`**

Headers:

- **`Authorization`**: `Bearer <your-sync-token>`  
- **`Content-Type`**: `application/json`

Body (example):

```json
{
  "date": "2026-05-01",
  "sleep": 7.4,
  "fiber": 38,
  "exercise": 28,
  "completionStatus": "complete"
}
```

Zeros are accepted and score as zero. The server scores the day, rotates suggestions, merges into KV (last **90** days), and the PWA pulls when opened or refocused.

Optional **`GET /api/data`** / **`PUT /api/data`** use the same Bearer token for full sync of records + settings + suggestion rotation state.

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
- Only the **most recent 90** calendar-dated records are kept.  
- With **cloud sync** enabled, records also sync to **KV** (last **90** days server-side); local **localStorage** still holds the working copy after pull.  
- Today is marked **partial**. Prior dates imported after they end are marked **complete** and are not re-imported unless they were missing or previously partial.
- **Exercise goal** is fixed at **30 minutes** (matching the scoring formula).

## LocalStorage keys

| Key | Purpose |
|-----|---------|
| `dailyHealthScore.records` | Daily records |
| `dailyHealthScore.settings` | Sleep / fiber goals |
| `dailyHealthScore.usedSuggestions` | Rotation state for suggestions |
| `dailyHealthScore.usedDiscouragementParagraphs` | Rotation for “Feeling discouraged?” |
| `dailyHealthScore.syncToken` | Bearer token for `/api/*` (optional; device-local only) |

## App icon

Branding lives at **`public/DHS.png`** (linked from `manifest.webmanifest`, favicon, and `apple-touch-icon`). For faster loads you can replace it later with optimized **192×192** and **512×512** PNGs and reference both sizes in the manifest.
