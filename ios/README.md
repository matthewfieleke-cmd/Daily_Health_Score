# Daily Health Score — Native iOS

Native SwiftUI app with **HealthKit** — sleep, fiber, and exercise scoring with **Today** and **7 / 30 / 90-day** rolling views.

## Requirements

- macOS with **Xcode 15+**
- iPhone on **iOS 26+** with **Apple Intelligence** (DHS Lifestyle Coach uses on-device Foundation Models)
- Apple Developer account (for device testing and App Store)

## Open the project

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen
cd ios
xcodegen generate
open DailyHealthScore.xcodeproj
```

### Option B — Manual Xcode project

1. **File → New → Project → App** (SwiftUI, Swift, iOS 17).
2. Product name: `DailyHealthScore`, bundle ID: `com.dailyhealthscore.app`, iOS 26.
3. Drag the `DailyHealthScore/` source folder into the target.
4. Add **HealthKit** capability (Signing & Capabilities).
5. Set **Info.plist** `NSHealthShareUsageDescription` (included in this repo).
6. Set **Code Signing Entitlements** to `DailyHealthScore/DailyHealthScore.entitlements`.
7. Link Apple’s **FoundationModels** framework (DHS Lifestyle Coach).

## Run on device

1. Select your iPhone as the run destination.
2. Build & Run.
3. When prompted, allow **read** access to Sleep, Fiber, and Exercise.
4. **Today** syncs from Health on launch and when returning to the app.

## Features

| Tab | Description |
|-----|-------------|
| Today | Score, metrics, DHS Lifestyle Coach, SMART goals, HRV |
| 7 / 30 / 90-Day | Rolling averages + daily list |
| Settings | Goals, coach memory clear, manual day edit, export JSON, clear data |

## Data

- Stored locally with **SwiftData** (roughly the last **125** days).
- No cloud sync in v1.

## HealthKit notes

- **Sleep**: asleep samples whose **end** falls on the calendar day (wake-day attribution).
- **Fiber**: `dietaryFiber` sum for the day.
- **Exercise**: `appleExerciseTime` (Exercise Minutes).

Tune `HealthKitService.swift` if your sleep totals differ from the Health app.

## Content

- **DHS Lifestyle Coach** — on-device daily card and Ask-the-coach chat (Apple Intelligence).
- Rotating suggestion libraries remain available to the record builder.
