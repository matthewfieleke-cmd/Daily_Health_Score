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
