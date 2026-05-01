# Daily Health Score

Local-first Progressive Web App that imports daily sleep, dietary fiber, and Apple Health **Exercise Minutes** from an Apple Shortcut via a URL, scores them against adjustable goals, stores the last **30 days** in **localStorage**, and shows calm Today / 7-Day / 30-Day dashboards plus Settings.

## Tech stack

- React 19 + TypeScript  
- Vite 7  
- `react-router-dom` (client-side routing)  
- Plain CSS (mobile-first, clinical minimal UI)  
- PWA `manifest.webmanifest` + **`public/DHS.png`** as install / favicon asset  
- Deployed on **Vercel**: static SPA plus **Vercel Functions** under `/api/*` backed by **Vercel KV**

Optional cloud sync: generate a **Bearer token** in **Settings** so Shortcuts can **POST** JSON to `/api/ingest`; data is stored in KV and the **Add to Home Screen** app pulls it when you return to the tab.

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

### Shortcut: POST ingest (recommended)

`POST` **`https://YOUR-VERCEL-APP.vercel.app/api/ingest`**

Headers:

- **`Authorization`**: `Bearer <your-sync-token>`  
- **`Content-Type`**: `application/json`

Body (example):

```json
{ "date": "2026-05-01", "sleep": 7.4, "fiber": 38, "exercise": 28 }
```

Zeros are rejected (`sleep`, `fiber`, `exercise` must all be &gt; 0). The server scores the day, rotates suggestions, merges into KV (last **30** days), and the PWA pulls when you focus the tab again.

Optional **`GET /api/data`** / **`PUT /api/data`** use the same Bearer token for full sync of records + settings + suggestion rotation state.

### Shortcut: Open URL (alternative)

```text
https://YOUR-VERCEL-APP.vercel.app/import?date=yyyy-MM-dd&sleep=[sleep]&fiber=[fiber]&exercise=[exercise]
```

Example:

```text
https://YOUR-VERCEL-APP.vercel.app/import?date=2026-05-01&sleep=7.4&fiber=38&exercise=28
```

## Apple Shortcut automation (8 PM)

1. **Shortcuts** → **Automation** → **+**  
2. **Time of Day** → **8:00 PM** → **Daily**  
3. Action: **Run Shortcut** → choose your Daily Health Score shortcut  
4. Prefer **Run Immediately** / disable **Ask Before Running** when available  

## Shortcuts vs “Add to Home Screen” (where data is stored)

On **iOS**, a Shortcut that **Opens URLs** usually opens **Safari**, not the standalone web app created with **Add to Home Screen**. Safari and that standalone app can use **different storage**, so data imported via the Shortcut might **not** show up in the Home Screen icon.

**Recommended fix:** Configure **POST `/api/ingest`** with your Settings sync token so metrics land in **Vercel KV**; open the **Home Screen** app afterward and data syncs into that client automatically.

**Manual URL fix:** In the **installed** app, open **Settings → Import into this app**, paste the **full import URL**, and tap **Run import**. That executes `/import` in the **same** client you use for Today (same `localStorage`).

Shortcut ideas:

- Add **Copy to Clipboard** with the URL, then you paste it into the app; or  
- Still **Open URLs** for convenience, then copy from the address bar and paste into Settings if the dashboard icon does not see the data.

Alternatively, skip the Home Screen icon and use **only Safari** so Shortcut imports and the dashboard always share one browser profile.

On **Android**, behavior varies by browser and install mode; when unsure, use the same **paste import** flow inside the installed PWA.

## Behavior notes

- If **sleep**, **fiber**, or **exercise** is **0** in the URL, the app opens **manual correction** for only the zero fields (values must be &gt; 0 before save).  
- Duplicate **date** imports **overwrite** the prior record.  
- Only the **most recent 30** calendar-dated records are kept.  
- With **cloud sync** enabled, records also sync to **KV** (last **30** days server-side); local **localStorage** still holds the working copy after pull.  
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
