# Daily Health Score

Local-first Progressive Web App that imports daily sleep, dietary fiber, and Apple Health **Exercise Minutes** from an Apple Shortcut via a URL, scores them against adjustable goals, stores the last **30 days** in **localStorage**, and shows calm Today / 7-Day / 30-Day dashboards plus Settings.

## Tech stack

- React 19 + TypeScript  
- Vite 7  
- `react-router-dom` (client-side routing)  
- Plain CSS (mobile-first, clinical minimal UI)  
- PWA-ready `manifest.webmanifest` + icons  
- Deployed as a **static** site on Vercel (`vercel.json` SPA rewrite)

No backend, database, auth, HealthKit in-app usage, or AI APIs.

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
6. Confirm **`vercel.json`** is present so deep links like `/import` resolve to `index.html` (SPA fallback).

After deploy, your Shortcut should use:

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

## Behavior notes

- If **sleep**, **fiber**, or **exercise** is **0** in the URL, the app opens **manual correction** for only the zero fields (values must be &gt; 0 before save).  
- Duplicate **date** imports **overwrite** the prior record.  
- Only the **most recent 30** calendar-dated records are kept.  
- Data lives in **this browser**; export JSON from **Settings** before clearing storage or switching devices.  
- **Exercise goal** is fixed at **30 minutes** (matching the scoring formula).

## LocalStorage keys

| Key | Purpose |
|-----|---------|
| `dailyHealthScore.records` | Daily records |
| `dailyHealthScore.settings` | Sleep / fiber goals |
| `dailyHealthScore.usedSuggestions` | Rotation state for suggestions |
| `dailyHealthScore.usedDiscouragementParagraphs` | Rotation for “Feeling discouraged?” |

## Icons

Replace `public/icons/icon.svg` (and favicon) with branded PNG/SVG assets if you want broader install-card support on all platforms.
