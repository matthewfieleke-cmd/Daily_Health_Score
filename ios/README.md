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
2. Product name: `DailyHealthScore`, bundle ID: `com.dailyhealthscore.app.mf`, iOS 26.
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

## Watch companion (Series 10 / Ultra)

The Watch app is a companion of the iPhone app (not independent). Apple’s layout is:

`DailyHealthScore.app/Watch/DailyHealthScoreWatch.app` (widgets live in that Watch app’s own PlugIns folder).

After `xcodegen generate`, confirm **DailyHealthScore → Build Phases → Embed Watch Content**: Destination **Products Directory**, Subpath contains `Watch` — not “Plugins and Foundation…”.

`xcodegen generate` clears **Team**. Set Team again on **DailyHealthScore**, **DailyHealthScoreWatch**, and **DailyHealthScoreWatchWidgets** (not Tests). Enable App Group `group.com.dailyhealthscore.app.mf` on those three. Do not add Background Modes.

Then:

1. On the iPhone, delete **Daily Health Score** completely (long-press → Remove App → Delete App). Overwriting an old install can leave iOS thinking there is no Watch companion.
2. In Xcode: **Product → Clean Build Folder**.
3. Scheme **DailyHealthScore**, destination **Matt’s iPhone**, Run.
4. Open the **Watch** app on the iPhone. Check the **My Watch** home list (apps already on the wrist) **and** **Available Apps** (alphabetically between CVS Health and ESPN).
5. If it is still missing, switch the scheme to **DailyHealthScoreWatch**, destination **Matt’s Series 10**, and Run. Developer Mode must be on on the Watch.

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
