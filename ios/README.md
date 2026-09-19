# Daily Health Score — Native iOS

Native SwiftUI app with **HealthKit** — sleep, fiber, and exercise scoring with **Today** and **7 / 30 / 90-day** rolling views.

## Requirements

- macOS with **Xcode 15+**
- iPhone on **iOS 26+** with **Apple Intelligence**. The Lifestyle Coach uses on-device Foundation Models and, when the managed entitlement is present, Private Cloud Compute.
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

## Watch companion (Series 10 / Ultra 4)

The Watch app is a companion of the iPhone app (not independent). Apple Watch Ultra 4 ships with **watchOS 27** and the **S11** chip. Pairing requires **iOS 27** on iPhone. **watchOS 27 hides Watch apps that do not include a 64-bit (`arm64`) slice**, so the Watch and widget targets are pinned to `arm64`.

Apple’s App Store layout is:

`DailyHealthScore.app/Watch/DailyHealthScoreWatch.app` (widgets live in that Watch app’s own PlugIns folder).

Debug installs from Xcode 27 also copy that companion into `PlugIns/` so the on-device installer accepts it. Release/Archive keep `Watch/` only — a second copy in `PlugIns/` fails App Store validation.

After `xcodegen generate`, confirm **DailyHealthScore → Build Phases → Embed Watch Content**: Destination **Products Directory**, Subpath contains `Watch` — not “Plugins and Foundation…”. You should also see **Mirror Watch companion into PlugIns for Debug device install**.

`xcodegen generate` clears **Team**. Set Team again on **DailyHealthScore**, **DailyHealthScoreWatch**, and **DailyHealthScoreWatchWidgets** (not Tests). Enable App Group `group.com.dailyhealthscore.app.mf` on those three. On **DailyHealthScore** also add **Access to models on Private Cloud Compute** if Signing complains. Do not add Background Modes.

Then, on a **newly paired Ultra 4** (or any Watch that will not take the app):

1. On the iPhone, delete **Daily Health Score** completely (long-press → Remove App → Delete App). Overwriting an old Series 10 install can leave iOS thinking there is no Watch companion.
2. On the Ultra 4: **Settings → Privacy & Security → Developer Mode** On. Restart the watch. Developer Mode is per-watch; the Series 10 setting does not carry over.
3. On the iPhone: **Settings → General → VPN & Device Management** and trust **Apple Development: Matthew Curtis Fieleke**.
4. Xcode → **Window → Devices and Simulators**. Select the Ultra 4 (under the iPhone). Click **Use for Development** so Xcode registers this watch’s UDID. The Series 10 profile does not include the Ultra 4.
5. In Xcode: **Product → Clean Build Folder**.
6. Scheme **DailyHealthScoreWatch**, destination **Matt’s Ultra 4** (not Series 10), Run. This is what actually adds the new watch to the development profile. Unlock the watch and leave it on the charger.
7. Then scheme **DailyHealthScore**, destination **Matt’s iPhone**, Run.
8. Open the **Watch** app on the iPhone. Check the **My Watch** home list **and** **Available Apps** (alphabetically between CVS Health and ESPN).

If the Ultra 4 shows **Unable to Install “Daily Health Score”** / **integrity could not be verified**, the new watch is not in the signing profile or Developer Mode is still off. Do steps 2–6 again, then on each of **DailyHealthScore**, **DailyHealthScoreWatch**, and **DailyHealthScoreWatchWidgets** toggle **Automatically manage signing** off and on.

If the Watch **app** shows today’s score but the **complication** still says **Today / Open iPhone**, pull this build, `xcodegen generate`, set Team, Clean, and Run **DailyHealthScore** to the iPhone (build 16). Opening the iPhone app now forces a face transfer; opening the Watch app asks again after 90 seconds if the face is still the placeholder. Remove and re-add the Daily Health Score complication if an old gallery tile is still pinned.

The iPhone app can still run if the Watch companion is waiting. A missing Watch app is a packaging/install issue, not a coach or SMART-goal issue.

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
