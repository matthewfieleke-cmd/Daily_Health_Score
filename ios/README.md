# Daily Health Score — Native iOS

Native SwiftUI app with **HealthKit** — sleep, fiber, and exercise scoring with **Today** and **7 / 30 / 90-day** rolling views.

## Requirements

- macOS with **Xcode 27+** (the project targets the iOS 27 SDK)
- iPhone on **iOS 27** (the app's minimum; it runs on every iPhone that ran iOS 26). The Lifestyle Coach needs **Apple Intelligence** (iPhone 15 Pro or later) and answers on Private Cloud Compute when the managed entitlement is present, falling back to the on-device Foundation Model.
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
2. Product name: `DailyHealthScore`, bundle ID: `com.dailyhealthscore.app.mf`, minimum deployment iOS 27.
3. Drag the `DailyHealthScore/` source folder into the target.
4. Add **HealthKit** capability (Signing & Capabilities).
5. Set **Info.plist** `NSHealthShareUsageDescription` (included in this repo).
6. Set **Code Signing Entitlements** to `DailyHealthScore/DailyHealthScore.entitlements`.
7. Link Apple’s **FoundationModels** framework (DHS Lifestyle Coach).

## Pull latest `main` on the Mac

Xcode rewrites signing files locally. `git pull` aborts if those files differ from GitHub. Stash **all six**, then pull, then regenerate. Use `&&` so `xcodegen` does not run after a failed pull.

```bash
cd ~/Daily_Health_Score
git stash push -u -- \
  ios/DailyHealthScore/Info.plist \
  ios/DailyHealthScore/DailyHealthScore.entitlements \
  ios/DailyHealthScoreWatch/Info.plist \
  ios/DailyHealthScoreWatch/DailyHealthScoreWatch.entitlements \
  ios/DailyHealthScoreWatchWidgets/Info.plist \
  ios/DailyHealthScoreWatchWidgets/DailyHealthScoreWatchWidgets.entitlements
git pull origin main && cd ios && xcodegen generate
```

Do **not** `git stash pop` afterward. `main` already has the Private Cloud Compute entitlement and the Watch/widget HealthKit + `WKAppBundleIdentifier` entries; popping would put the old local copies back and block the next pull. Set **Team** again in Xcode after `xcodegen generate`.

## Run on device

1. Select your iPhone as the run destination.
2. Build & Run.
3. When prompted, allow **read** access to Sleep, Fiber, and Exercise.
4. **Today** syncs from Health on launch and when returning to the app.

## Watch companion (Series 10 / Ultra 4)

The Watch app is a companion of the iPhone app (not independent). Apple Watch Ultra 4 ships with **watchOS 27** and the **S11** chip. Pairing requires **iOS 27** on iPhone. **watchOS 27 hides Watch apps that do not include a 64-bit (`arm64`) slice**, and an upload whose Watch minimum is 26 is rejected without an `arm64_32` slice. The Watch and widget targets ship both, with `ONLY_ACTIVE_ARCH` off so a connected watch cannot thin the archive.

Apple’s App Store layout is:

`DailyHealthScore.app/Watch/DailyHealthScoreWatch.app` (widgets live in that Watch app’s own PlugIns folder).

Debug installs from Xcode 27 also copy that companion into `PlugIns/` so the on-device installer accepts it. Release/Archive keep `Watch/` only — a second copy in `PlugIns/` fails App Store validation.

After `xcodegen generate`, confirm **DailyHealthScore → Build Phases → Embed Watch Content**: Destination **Products Directory**, Subpath contains `Watch` — not “Plugins and Foundation…”. You should also see **Mirror Watch companion into PlugIns for Debug device install**.

`xcodegen generate` clears **Team**. Set Team again on **DailyHealthScore**, **DailyHealthScoreWatch**, and **DailyHealthScoreWatchWidgets** (not Tests). Enable App Group `group.com.dailyhealthscore.app.mf` on those three, and **HealthKit** on the Watch and widget targets (iPhone already has it). On **DailyHealthScore** also add **Access to models on Private Cloud Compute** if Signing complains. Do not add Background Modes. After generate, confirm the widget Info plist has `WKAppBundleIdentifier` = `com.dailyhealthscore.app.mf.watchkitapp`.

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

If the Watch **app** shows today’s score but a face slot still says **Today / Open iPhone**, pull the current build (20 or later), `xcodegen generate`, set Team, Clean, and Run **DailyHealthScore** to the iPhone. In Settings tap **Refresh Watch face** — it stays enabled and must show a result (Sent 3.3 / Watch is connecting / not paired). Raise the Ultra 4. The face now also reads the same Watch Connectivity feed the Watch app uses, and HealthKit if that feed is empty. You do not need to remove and re-add the slot.

Lifestyle Coach (build 21): Private Cloud Compute now **reasons** before it answers (moderate by default, deep for "how do I" and "is this healthy" questions) and can call tools mid-reply: **lookupFood** (USDA FoodData Central, then Open Food Facts), **searchEvidence** (PubMed), **calculate** (exact arithmetic), and **lookupWeightTrend** (weight, trend, BMI from Apple Health, coaching only). The charter is a third of its old length: identity, standards, safety; no per-intent scripts. PCC writes the reply and the memory notes; the on-device model files each chat (title, summary, pillar), compiles a one-paragraph-per-file **profile**, and tidies the files daily with every edit logged and undoable. Memory is nine files (About you, People, Patterns & triggers, How to coach me, Goals & plans, Likes & staples, Routines & rhythms, Body & health, Recent), dated entries up to 240 characters, each marked as something you said or the Coach’s read (tap **Confirm** on the second kind). Replies answered on-device say so under the bubble. Settings → **Coach eval (developer)** runs the regression prompt set through the live pipeline without saving anything and copies the results as text. Build 20 introduced the check-in card, the flat Chats list, and the memory files.

**USDA key (optional, recommended).** Sign up at https://fdc.nal.usda.gov/api-key-signup/, then copy `ios/DailyHealthScore/Secrets.example.plist` to `ios/DailyHealthScore/Secrets.plist` and paste the key into `USDAFoodDataKey`. The file is gitignored and XcodeGen bundles it automatically; without it the Coach uses USDA’s shared `DEMO_KEY` (30 lookups an hour) and Open Food Facts.

The iPhone app can still run if the Watch companion is waiting. A missing Watch app is a packaging/install issue, not a coach or SMART-goal issue.

## Features

| Tab | Description |
|-----|-------------|
| Today | Score, metrics, DHS Lifestyle Coach, SMART goals, HRV |
| 7 / 30 / 90-Day | Rolling averages + daily list |
| Settings | Goals, coach memory, delete all chats, manual day edit, export JSON, clear data |

## Data

- Stored locally with **SwiftData** (roughly the last **125** days).
- No cloud sync in v1.

## HealthKit notes

- **Sleep**: asleep samples whose **end** falls on the calendar day (wake-day attribution).
- **Fiber**: `dietaryFiber` sum for the day.
- **Exercise**: `appleExerciseTime` (Exercise Minutes).

Tune `HealthKitService.swift` if your sleep totals differ from the Health app.

## Content

- **DHS Lifestyle Coach** — one coach (three doctorates, one voice, ABLM/ACLM Lifestyle Medicine). Home is a twice-daily check-in with Reply; Chats is a flat Messages-style list. Private Cloud Compute reasons, calls tools (USDA / Open Food Facts food facts, PubMed evidence, a calculator, the weight trend), writes the reply and the memory notes; the on-device model titles chats, compiles the profile, and tidies the files. On-device answers everything when PCC is unavailable or at its daily limit, and says so. Light Markdown in replies (bold, short lists), 350-word ceiling.
- Rotating suggestion libraries remain available to the record builder.
