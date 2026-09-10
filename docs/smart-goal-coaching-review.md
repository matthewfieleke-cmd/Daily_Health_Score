# SMART goal editing and coaching review

This change makes an existing goal editable in one screen and lets the coach prepare new goals and revisions for review. The coach receives live goal IDs, recorded counts and deadlines, including when no Health record is available. Goal writes remain explicit user actions.

## Run in Cursor and Xcode

1. Check out this PR branch in the full repository. Run `xcodegen generate` from `ios/`, then open `DailyHealthScore.xcodeproj` in Xcode using the SDK required by `ios/project.yml`.
2. Select the `DailyHealthScore` scheme and an installed iPhone simulator. Run the unit tests, including `SMARTGoalEditTests`, `CoachGoalPlanningTests` and `CoachDataSummariesTests`.
3. Build the companion Watch targets. Run the interaction checks below on an Apple Intelligence-capable iPhone and paired Watch. Generated coach output needs device validation; a simulator build alone is insufficient.

Suggested Cursor task:

> Build this branch and run the DailyHealthScore tests. Fix any compiler or test failures with focused changes. Walk through docs/smart-goal-coaching-review.md. Preserve the rule that goal edits merge the latest stored check-ins, AI proposals never write directly, and missing check-ins do not prove missed actions. Report what passed and any checks that still need a physical device.

## Interaction checks

| Scenario | Expected behavior |
| --- | --- |
| Open an existing goal and tap Edit, or swipe its list row to Edit | One prefilled screen contains action, target, theme, exact deadline and reminder settings. |
| Change the action, then Cancel | The original goal and check-ins stay intact. |
| Edit a goal while logging a check-in on the Watch | Save keeps the latest check-in. The same goal ID is published back to the Watch. |
| Reduce the target while high-index circles are filled | Recorded count survives. A target below recorded count is rejected. |
| Change reminder days/time, disable reminders, or complete the goal | Pending reminders reflect the latest saved state; earlier scheduling work cannot restore old requests. |
| Enable reminders when notification permission is denied | The editor explains the issue and asks for a second Save without reminders. No goal is silently saved on the first attempt. |
| Choose Build a goal with Coach and ask for help with a vague goal | The coach asks one useful question, then uses the reply to help formulate a concrete plan. |
| Ask for “Walk for ten minutes after lunch three times over the next seven days” | A draft shows a specific action, three total check-ins and a deadline. Review opens the editor; saving creates one goal with zero check-ins. |
| From a saved goal choose Work on this with Coach; ask “Reduce the target from five to three” | The proposal targets this exact goal. The deadline, reminders and recorded progress stay intact unless explicitly edited. |
| Ask the coach to help work through a barrier | It discusses constraints, a cue or a smaller step without assuming unrecorded actions were missed. Advice alone does not require a goal mutation. |
| In goal coaching tap Log a check-in | One check-in is recorded explicitly. The banner, goal detail, daily card context and Watch receive updated state. |
| Delete or edit a goal after a proposal was generated but before saving | The review screen blocks the stale save and explains how to refresh. |
| Finish a goal, leave its detail screen, then reopen it | The completed goal remains available for celebration and reflection. Renewing an ended goal keeps the earlier attempt and starts a new identity with zero check-ins. |
| Deny Health access or open the coach before any daily record exists | Goal context is still available to the coach. Manual creation and editing remain available when Apple Intelligence is unavailable. |
| Edit a goal while a daily card is generating | The old result is discarded; a card with the updated goal context can be generated. |
| Clear coach memory while a reply or summary is generating | Late model output does not restore cleared chat, proposals or summary. |

## Scope and validation status

- The new XCTest cases cover edit invariants and structured proposal validation. They were authored but could not be run in the implementation environment, which has neither Swift nor Xcode. Native build, XCTest execution and device checks are required before merging.
- No SwiftData schema migration is introduced. Check-ins remain an aggregate bitmask without dates. The coach must not claim streaks, missed scheduled actions or causal outcomes from those counts.
- Unsaved AI proposals are held for the current app session. Saved goals and chat text use the existing local persistence; proposals are not restored after relaunch.
- PCC access is not required by this change. It keeps the existing model provider and on-device fallback.
