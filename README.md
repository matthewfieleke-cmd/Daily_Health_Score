# Daily Health Score

A native iOS app that scores each day on three pillars — **sleep**, **dietary fiber**, and **exercise minutes** — against adjustable goals (10 points max), with **Today** and **7 / 30 / 90-day** rolling views.

All metrics are read directly from **Apple Health**. Data stays on the device (SwiftData, 90-day retention). No server, no account, no Apple Shortcut required.

See **[ios/README.md](ios/README.md)** for Xcode setup and run instructions.

## Scoring

| Metric | Max points | Default goal |
|--------|------------|--------------|
| Sleep | 4 | 7.5 hours (7, 7.5, or 8 selectable) |
| Fiber | 4 | 40 g (30, 40, or 50) |
| Exercise | 2 | 30 minutes (fixed) |

Primary focus = the weakest metric (ties resolve sleep → fiber → exercise). When every goal is met, the day enters **maintain** mode with maintenance-oriented suggestions.

## HealthKit reads

- **Sleep**: `HKCategoryTypeIdentifierSleepAnalysis` asleep samples whose end falls on the calendar day (wake-day attribution). Samples from multiple sources (e.g. Apple Watch + AutoSleep + iPhone Bedtime) are **merged as a union of time ranges** before summing, so the total matches Apple Health's "Time Asleep" display rather than double-counting overlapping samples.
- **Fiber**: `HKQuantityTypeIdentifierDietaryFiber` cumulative sum for the day.
- **Exercise**: `HKQuantityTypeIdentifierAppleExerciseTime` cumulative sum for the day.

The pure attribution logic lives in `ios/DailyHealthScore/Core/Health/SleepAttribution.swift` and is covered by `ios/DailyHealthScoreTests/SleepAttributionTests.swift`.

## Tests

The Xcode project includes a `DailyHealthScoreTests` unit-test bundle:

```bash
cd ios
xcodegen generate
xcodebuild test \
  -project DailyHealthScore.xcodeproj \
  -scheme DailyHealthScore \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Suites:

- `ScoreCalculatorTests` — score math, clamping, primary-focus tie-breaking, display formatting.
- `SleepAttributionTests` — wake-day attribution, window clipping, overlap merging across HealthKit sources.
- `DateHelpersTests` — date-key parsing, day arithmetic, rolling windows.
- `RollingStatsTests` — averages, partial windows, ordering, recomputation from raw metrics.

## Content

- **80** rotating daily suggestions across sleep / fiber / exercise / maintain.
- **30** rotating "Feeling discouraged?" paragraphs.
- **30** rotating "Need motivation?" paragraphs.
