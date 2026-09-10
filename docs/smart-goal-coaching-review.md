# SMART goal editing, coach memory, and follow-through

This change keeps the PR #43 editor and review-before-save flow, then adds dated activity, inspectable coach memory, optional follow-through plans, and “Ask Coach about this” context from history, sleep, and HRV screens.

Goal writes remain explicit user actions. Arithmetic, dates, progress, reminder eligibility, and persistence stay in Swift.

## Run in Cursor and Xcode

1. Check out this branch. Run `xcodegen generate` from `ios/`, then open `DailyHealthScore.xcodeproj` in Xcode using the SDK required by `ios/project.yml`.
2. Select the `DailyHealthScore` scheme and an installed iPhone simulator. Run the unit tests, including `SMARTGoalEditTests`, `CoachGoalPlanningTests`, `SMARTGoalActivityTests`, `CoachMemoryAndFollowThroughTests`, `CoachDataSummariesTests`, and `WatchCompanionTests`.
3. Build the iPhone app and the companion Watch targets. Generated coach output still needs an Apple Intelligence–capable iPhone. Simulator tests cover persistence, eligibility, and context rules.

Suggested Cursor task:

> Build this branch and run the DailyHealthScore tests. Fix any compiler or test failures with focused changes. Walk through docs/smart-goal-coaching-review.md. Preserve dated activity as the source of truth, undated migrated check-ins, review-before-save, and the rule that missing check-ins and missing Health data are not failures. Report what passed and any checks that still need a physical device.

## Migration behavior

SMART goal schema version is now `2` (`dhs.smartGoals.schemaVersion`).

- The previous schema-change path deleted every stored goal. Version 2 **does not delete goals, chat, or Health records**.
- Existing `filledMask` counts become undated `checkIn` events with source `migration`. Occurrence dates stay unknown until the user supplies them.
- Display circles compact to the recorded count (`N` filled circles). Sparse high-index bits are not kept as identities.
- Coach prompts must not treat migrated undated events as streaks, missed days, or a daily schedule.
- Watch snapshots still send a compact bitmask derived from the ledger. Delayed Watch messages keep the Watch tap time as `occurredAt` and use a stable `eventId` so retries do not add extra check-ins.
- Reducing a target stores a **revision** event. That is a plan change, not another completed action.
- A smaller fallback is a separate event and does not count toward the accepted target unless the user reviews and saves a revised plan.
- Coach profile notes become structured memories with provenance `legacyCoachNotes`. They are not labeled user-confirmed.

## User workflows

| Scenario | Expected behavior |
| --- | --- |
| Open an existing goal and tap Edit | One prefilled screen includes action, target, theme, deadline, reminders, optional reason/cue/barriers/fallback, confidence, follow-through opt-in, and pause. |
| Change the action, then Cancel | The original goal, check-ins, and activity history stay intact. |
| Edit a goal while logging a check-in on the Watch | Save keeps the Watch check-in. The same goal ID is published back to the Watch. Duplicate Watch retries do not add a second check-in. |
| Reduce the target while check-ins exist | Recorded count survives. A target below recorded count is rejected. The save writes a revision, not extra progress. |
| Log a smaller fallback | The fallback is listed in Activity and does not fill an accepted check-in circle. |
| Undo a circle or an activity row | History keeps the original event plus an undo. Counts decrease. |
| Add a date to an undated migrated check-in | On the goal’s Activity list, tap **Add action date**. Correction stores the user-supplied occurrence time. Migration or Watch delivery time is not the action time. |
| Enable follow-through reminders | Local notifications use the chosen time, skip quiet hours, and stay off for paused, complete, expired, or deleted goals. Notification copy does not treat a missing log as a missed action. Tapping a check-in reminder opens the goal; reflection and weekly review open Coach with that goal. |
| Open Settings → What your coach remembers | Each memory shows content, provenance, and dates. Correct, delete, or confirm a temporary circumstance. Deletion tombstones the note so late model output cannot recreate it. |
| Clear coach chat & memory | Conversations, memories, and summaries clear. Health records and SMART goals stay. |
| 7/30/90-Day, a history day, Sleep diagnostic, or DHS + HRV → Ask Coach about this | Chat shows a removable context chip for that period or metric. The coach must not silently switch to today. |
| Long-press Today’s Sleep/Fiber/Exercise card | Ask Coach about this metric using today’s saved record, including NO DATA when unlogged. |
| Coach proposes a goal | Review still opens the editor. Saving is the first write. |

## Interaction checks from the previous review

The PR #43 editor, Watch merge, reminder permission, Build a goal with Coach, Work on this with Coach, Log a check-in, stale-proposal blocking, completed-goal retention, and clear-memory-during-generation checks still apply. Missing Health access still leaves goal coaching available.

## Remaining device checks

- Apple Intelligence replies, Home card generation, and PCC entitlement behavior.
- Paired Watch: delayed check-in delivery, complication bitmask, and notification Log check-in.
- Notification permission, quiet hours on a physical clock, and tapping a follow-through banner to open the matching goal or coach sheet.
- Dynamic Type and VoiceOver on the memory list, activity history, and Ask Coach buttons.

Native XCTest, iPhone, and Watch builds could not be run in this Cloud Agent environment: it is Linux and `xcodebuild` is not installed. Treat the new XCTest cases as authored but unexecuted until a Mac with the SDK in `ios/project.yml` is available.
