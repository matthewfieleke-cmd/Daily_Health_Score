# Daily Health Score — Native iOS

SwiftUI app with **HealthKit** (no Apple Shortcut, no Vercel). Same scoring and 7 / 30 / 90 day views as the web PWA.

## Requirements

- macOS with **Xcode 15+**
- iPhone on **iOS 17+** (SwiftData)
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
2. Product name: `DailyHealthScore`, bundle ID: `com.dailyhealthscore.app`.
3. Drag the `DailyHealthScore/` source folder into the target.
4. Add **HealthKit** capability (Signing & Capabilities).
5. Set **Info.plist** `NSHealthShareUsageDescription` (included in this repo).
6. Set **Code Signing Entitlements** to `DailyHealthScore/DailyHealthScore.entitlements`.

## Run on device

1. Select your iPhone as the run destination.
2. Build & Run.
3. When prompted, allow **read** access to Sleep, Fiber, and Exercise.
4. **Today** syncs from Health on launch and when returning to the app.

## Code signing troubleshooting

If the build fails with **Command CodeSign failed** and messages like **unable to build chain to self-signed root** or **errSecInternalComponent**, Xcode cannot trust your Apple Development certificate. This is a **Mac Keychain / certificate** issue, not a Swift compile error.

### 1. Confirm the paid team in Xcode

1. **Xcode → Settings → Accounts** — sign in with your Apple ID.
2. Select your account → **Manage Certificates…** — you should see **Apple Development** under team **MATTHEW CURTIS FIELEKE** (Team ID `X243J42DAR`), not only **Personal Team**.
3. In the project → **Signing & Capabilities** → **Team** = **MATTHEW CURTIS FIELEKE**, **Automatically manage signing** = on, bundle ID e.g. `com.matthewfieleke.DailyHealthScore`.

### 2. Install Apple’s intermediate certificates (WWDR)

Codesign needs Apple’s Worldwide Developer Relations (WWDR) certs in your login keychain.

1. Download (Apple PKI):
   - https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
   - https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer
2. Double-click each `.cer` file — if Keychain Access does not open, run in **Terminal**:

```bash
security import ~/Downloads/AppleWWDRCAG3.cer -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/security
security import ~/Downloads/AppleWWDRCAG4.cer -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign -T /usr/bin/security
```

3. In **Keychain Access**, search **Apple Worldwide**. For each WWDR cert: **Get Info → Trust → When using this certificate: Always Trust** (you may need to unlock the keychain).

### 3. Trust your development certificate

1. **Keychain Access → login → My Certificates**.
2. Expand **Apple Development: matthew.fieleke@gmail.com (…)** — there must be a **private key** under it.
3. Select the **certificate** (not only the key) → **Get Info → Trust → Always Trust**.
4. Quit and reopen Xcode.

### 4. Refresh the development certificate

If it still fails:

1. **Xcode → Settings → Accounts → Manage Certificates**.
2. Select the bad **Apple Development** cert → **−** to remove, then **+ → Apple Development** to create a new one.
3. Or at https://developer.apple.com/account/resources/certificates/list — revoke the old Development cert, then let Xcode create a new one.

### 5. Clean build artifacts

1. **Product → Clean Build Folder** (hold Option if needed).
2. Delete Derived Data: **Xcode → Settings → Locations → Derived Data → arrow → delete** the `DailyHealthScore-…` folder.
3. Unplug/replug the iPhone, unlock it, tap **Trust** if asked.
4. Build again.

### 6. Mac-specific gotchas

- **Non-admin Mac**: importing WWDR into the **System** keychain may require an admin; login keychain + Terminal `security import` above usually works without admin.
- **Wrong app**: open `DailyHealthScore.xcodeproj` under `ios/`, not the repo root.
- **Debug dylib signing**: if you see `Sign DailyHealthScore.debug.dylib` fail, set **ENABLE_DEBUG_DYLIB = NO** in Build Settings.
- **Passwords app popup** during sign: cancel it and fix trust in **Keychain Access**, not the Passwords app.

### 7. Verify from Terminal (optional)

```bash
security find-certificate -c "Apple Worldwide Developer Relations" -a ~/Library/Keychains/login.keychain-db
security find-identity -v -p codesigning
```

You should see **Apple Development: matthew.fieleke@gmail.com** with a valid hash, not `(0 valid identities found)`.

When signing works, warnings in `HealthTypes.swift` or deprecated `asleep` in HealthKit are non-blocking; pull latest `main` for fixes.

## Features

| Tab | Description |
|-----|-------------|
| Today | Score, metrics, primary focus, suggestion, discouragement / motivation |
| 7 / 30 / 90-Day | Rolling averages + daily list |
| Settings | Goals, manual day edit, export JSON, clear data |

## Data

- Stored locally with **SwiftData** (last **90** days).
- No cloud sync in v1.

## HealthKit notes

- **Sleep**: asleep samples whose **end** falls on the calendar day (wake-day attribution).
- **Fiber**: `dietaryFiber` sum for the day.
- **Exercise**: `appleExerciseTime` (Exercise Minutes).

Tune `HealthKitService.swift` if your sleep totals differ from the Health app.

## Content

- **30** “Feeling discouraged?” paragraphs (20 original + 10 new).
- **30** “Need motivation?” paragraphs (20 original + 10 new, DBT-informed).
- **80** rotating daily suggestions (sleep / fiber / exercise / maintain).
