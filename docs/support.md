# Daily Health Score — Support

**Daily Health Score** is a native iPhone app that reads sleep, dietary fiber, and exercise minutes from **Apple Health** and turns them into a daily score (up to 10 points), with Today and 7 / 30 / 90-day views.

This page is for App Store users who need help with the app.

---

## Contact

For support, feedback, or privacy questions:

**Email:** [matthew.fieleke@gmail.com](mailto:matthew.fieleke@gmail.com)

Please include your iOS version (e.g. iOS 18.x) and a short description of the issue. Screenshots help when something looks wrong on the Today screen.

---

## Requirements

- iPhone running **iOS 17 or later**
- **Apple Health** with permission to read:
  - Sleep Analysis (asleep)
  - Dietary Fiber
  - Apple Exercise Time (exercise minutes)

The app does not require an account. Data is stored on your device.

---

## Frequently asked questions

### How do I connect Apple Health?

1. Install and open **Daily Health Score**.
2. When prompted, allow the app to read the health types it requests.
3. Open the **Today** tab. The app syncs on launch and when you return to the app.
4. Tap the **refresh** button in the top bar to sync again.

If you previously denied access: **Settings → Privacy & Security → Health → Daily Health Score** and turn on the relevant categories.

### Why is my score empty or zero?

Common causes:

- Health permission was not granted for one or more types.
- There is no Health data yet for today (e.g. sleep logged tomorrow morning, fiber not logged, no exercise minutes).
- You are viewing a day with no recorded metrics.

Grant Health access and ensure Apple Health shows sleep, fiber, and exercise for that day.

### Why doesn’t sleep match Apple Health exactly?

Sleep is attributed to the calendar day when asleep samples **end** (wake-day attribution), and overlapping samples from multiple sources are merged before totaling—similar to how many users expect “time asleep” for a given day to appear. Small differences can still occur depending on sources and timing. For details, see the in-app sleep diagnostic tools in **Settings** if available in your build.

### How is the daily score calculated?

| Metric   | Max points | Default goal        |
|----------|------------|---------------------|
| Sleep    | 4          | 7.5 hours (7 / 7.5 / 8 selectable) |
| Fiber    | 4          | 40 g (30 / 40 / 50) |
| Exercise | 2          | 30 minutes          |

Your **primary focus** highlights the weakest area for the day. When all goals are met, the app emphasizes **maintain** guidance.

### Where is my data stored?

On your **iPhone only** (local storage). This version does not sync to a cloud account operated by the developer. The app retains roughly **90 days** of history locally.

You can **export** or **clear** data from **Settings** in the app.

### SMART goals and notifications

Optional SMART goals may send **local reminders** if you enable notifications for the app in iOS Settings. You can manage or remove goals in the app.

### How do I delete my data?

Open **Settings** in the app and use the option to clear local data. You can also revoke Health access under **Settings → Privacy & Security → Health**.

### Is this medical advice?

**No.** Daily Health Score is for personal wellness tracking only. It does not diagnose, treat, or prevent any condition. Talk to a qualified clinician for medical questions.

---

## Privacy

See the [Privacy Policy](privacy.html).

---

*Last updated: May 28, 2026*
