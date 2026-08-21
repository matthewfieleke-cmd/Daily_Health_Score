import XCTest
@testable import DailyHealthScore

final class ComplicationPushPolicyTests: XCTestCase {
    func test_newDayPushesEvenWhenNumbersMatch() {
        let yesterday = face(dateKey: "2026-08-19", sleep: 7.2, fiber: 0, exercise: 0, score: 3.8)
        let today = face(dateKey: "2026-08-20", sleep: 7.2, fiber: 0, exercise: 0, score: 3.8)
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: yesterday,
                to: today,
                kind: .sleep,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 40
            )
        )
    }

    func test_settledSleepChangePushes() {
        let empty = face(sleep: 0, score: 0)
        let slept = face(sleep: 7.2, score: 3.8)
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: empty,
                to: slept,
                kind: .sleep,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 40
            )
        )
    }

    func test_streamingExerciseMinutesDoNotPush() {
        let rest = face(exercise: 0, score: 3.8)
        let walking = face(exercise: 5, score: 4.1)
        XCTAssertFalse(
            ComplicationPushPolicy.shouldPushComplication(
                from: rest,
                to: walking,
                kind: .exerciseMinutes,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 40
            )
        )
    }

    func test_endedWorkoutPushesExercise() {
        let rest = face(exercise: 0, score: 3.8)
        let hike = face(exercise: 30, score: 5.8)
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: rest,
                to: hike,
                kind: .workout,
                endedWorkoutSinceLastPush: true,
                remainingTransfers: 40
            )
        )
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: rest,
                to: hike,
                kind: .exerciseMinutes,
                endedWorkoutSinceLastPush: true,
                remainingTransfers: 40
            )
        )
    }

    func test_fiberChangePushes() {
        let before = face(fiber: 0, score: 3.8)
        let after = face(fiber: 12, score: 5.0)
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: before,
                to: after,
                kind: .fiber,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 40
            )
        )
    }

    func test_sameFaceAfterRelaunchDoesNotPush() {
        let dinner = face(fiber: 24.5, score: 7.7)
        XCTAssertFalse(
            ComplicationPushPolicy.shouldPushComplication(
                from: dinner,
                to: dinner,
                kind: .foreground,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 40
            )
        )
    }

    func test_reserveKeepsASlotForEveningFiber() {
        let before = face(fiber: 24.5, score: 7.7)
        let afterDinner = face(fiber: 54.5, score: 9.3)
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: before,
                to: afterDinner,
                kind: .fiber,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: ComplicationPushPolicy.reserveTransfers
            )
        )
        let moreWalk = face(fiber: 24.5, exercise: 79, score: 7.7)
        XCTAssertFalse(
            ComplicationPushPolicy.shouldPushComplication(
                from: before,
                to: moreWalk,
                kind: .foreground,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: ComplicationPushPolicy.reserveTransfers
            )
        )
    }

    func test_lastFaceStoreRoundTrips() {
        let suite = "dhs.lastFace.tests"
        UserDefaults().removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!
        let stored = face(fiber: 54.5, score: 9.3)
        LastComplicationFaceStore.save(stored, defaults: defaults)
        let loaded = LastComplicationFaceStore.load(defaults: defaults)
        XCTAssertEqual(loaded, stored)
        LastComplicationFaceStore.save(nil, defaults: defaults)
        XCTAssertNil(LastComplicationFaceStore.load(defaults: defaults))
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func test_zeroTransfersNeverPush() {
        let empty = face(sleep: 0, score: 0)
        let slept = face(sleep: 7.2, score: 3.8)
        XCTAssertFalse(
            ComplicationPushPolicy.shouldPushComplication(
                from: empty,
                to: slept,
                kind: .sleep,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 0
            )
        )
    }

    func test_firstSnapshotPushes() {
        let today = face(sleep: 7.2, score: 3.8)
        XCTAssertTrue(
            ComplicationPushPolicy.shouldPushComplication(
                from: nil,
                to: today,
                kind: .foreground,
                endedWorkoutSinceLastPush: false,
                remainingTransfers: 50
            )
        )
        XCTAssertEqual(ComplicationPushPolicy.reserveTransfers, 4)
    }

    private func face(
        dateKey: String = "2026-08-20",
        sleep: Double = 7.2,
        fiber: Double = 0,
        exercise: Double = 0,
        score: Double = 3.8
    ) -> ComplicationPushPolicy.Face {
        ComplicationPushPolicy.Face(
            WatchSnapshot(
                dateKey: dateKey,
                totalScore: score,
                sleep: WatchPillarSnapshot(
                    name: "Sleep",
                    value: sleep,
                    goal: 7.5,
                    unit: "hr",
                    points: min(sleep / 7.5 * 4, 4),
                    maxPoints: 4
                ),
                fiber: WatchPillarSnapshot(
                    name: "Fiber",
                    value: fiber,
                    goal: 40,
                    unit: "g",
                    points: min(fiber / 40 * 4, 4),
                    maxPoints: 4
                ),
                exercise: WatchPillarSnapshot(
                    name: "Exercise",
                    value: exercise,
                    goal: 30,
                    unit: "min",
                    points: min(exercise / 30 * 2, 2),
                    maxPoints: 2
                ),
                goals: [],
                updatedAt: Date(timeIntervalSince1970: 0),
                paceNudgesEnabled: true
            )
        )
    }
}

final class WatchPendingSendMergeTests: XCTestCase {
    func test_firstSendIsKeptAsIs() {
        let incoming = pending(sleep: 7.2, kind: .sleep)
        let merged = WatchPendingSendMerge.replacing(nil, with: incoming)
        XCTAssertEqual(merged, incoming)
    }

    func test_newerSnapshotReplacesOlderAndRemembersWorkout() {
        let first = pending(sleep: 0, exercise: 30, kind: .workout, endedWorkout: true, workoutEnd: 100)
        let second = pending(sleep: 7.2, exercise: 30, kind: .sleep, endedWorkout: false, workoutEnd: nil)
        let merged = WatchPendingSendMerge.replacing(first, with: second)
        XCTAssertEqual(merged.snapshot.sleep.value, 7.2)
        XCTAssertEqual(merged.kind, .workout)
        XCTAssertTrue(merged.endedWorkoutSinceLastPush)
        XCTAssertEqual(merged.latestWorkoutEnd, Date(timeIntervalSince1970: 100))
    }

    func test_preferredKindKeepsForeground() {
        XCTAssertEqual(WatchPendingSendMerge.preferredKind(.sleep, .foreground), .foreground)
        XCTAssertEqual(WatchPendingSendMerge.preferredKind(.workout, .fiber), .workout)
        XCTAssertEqual(WatchPendingSendMerge.preferredKind(.fiber, .sleep), .sleep)
    }

    private func pending(
        sleep: Double,
        exercise: Double = 0,
        kind: HealthChangeKind,
        endedWorkout: Bool = false,
        workoutEnd: TimeInterval? = nil
    ) -> WatchPendingSend {
        WatchPendingSend(
            snapshot: WatchSnapshot(
                dateKey: "2026-08-20",
                totalScore: sleep + exercise / 10,
                sleep: WatchPillarSnapshot(
                    name: "Sleep", value: sleep, goal: 7.5, unit: "hr", points: 0, maxPoints: 4
                ),
                fiber: WatchPillarSnapshot(
                    name: "Fiber", value: 0, goal: 40, unit: "g", points: 0, maxPoints: 4
                ),
                exercise: WatchPillarSnapshot(
                    name: "Exercise", value: exercise, goal: 30, unit: "min", points: 0, maxPoints: 2
                ),
                goals: [],
                updatedAt: Date(timeIntervalSince1970: 1),
                paceNudgesEnabled: true
            ),
            kind: kind,
            endedWorkoutSinceLastPush: endedWorkout,
            latestWorkoutEnd: workoutEnd.map { Date(timeIntervalSince1970: $0) }
        )
    }
}
