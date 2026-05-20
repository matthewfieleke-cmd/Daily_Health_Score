# Daily Health Score

Track daily **sleep**, **dietary fiber**, and **exercise minutes**, score them against adjustable goals (10 points max), and review **Today** plus **7 / 30 / 90** day trends.

## Native iOS app (recommended)

The active product is the **SwiftUI + HealthKit** app under [`ios/`](ios/README.md):

- Reads metrics directly from **Apple Health** (no Shortcut, no server).
- Same scoring logic as the original PWA.
- **Feeling discouraged?** and **Need motivation?** with 30 rotating messages each.
- Local storage only (SwiftData, 90-day retention).

See **[ios/README.md](ios/README.md)** for Xcode setup and run instructions.

## Legacy web PWA (optional)

The [`src/`](src/) Vite + React app and Vercel `/api/*` backend remain in the repo for reference. It relied on Apple Shortcuts and optional KV sync. New development targets **iOS native** only.

```bash
npm install
npm run dev
```

## Scoring (both platforms)

| Metric | Max points | Default goal |
|--------|------------|--------------|
| Sleep | 4 | 7.5 hours (7, 7.5, or 8 selectable) |
| Fiber | 4 | 40 g (30, 40, or 50) |
| Exercise | 2 | 30 minutes (fixed) |

Primary focus = weakest metric; at all goals met → maintain mode with maintenance suggestions.
