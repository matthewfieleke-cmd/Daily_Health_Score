import Foundation

/// How aggressively the app flags departures from a user's usual HRV range.
/// These are UX sensitivity presets, not clinical constants: a smaller
/// multiplier yields a narrower "usual range" corridor and earlier nudges.
enum HRVSensitivity: String, CaseIterable, Identifiable, Codable {
    case high
    case balanced
    case low

    var id: String { rawValue }

    /// SD multiplier that sets the half-width of the usual-range corridor.
    var multiplier: Double {
        switch self {
        case .high: return 0.5
        case .balanced: return 1.0
        case .low: return 1.5
        }
    }

    var title: String {
        switch self {
        case .high: return "High"
        case .balanced: return "Balanced"
        case .low: return "Low"
        }
    }

    var shortDescription: String {
        switch self {
        case .high: return "Narrow range — flags small changes earlier."
        case .balanced: return "One standard deviation — flags meaningful changes."
        case .low: return "Wide range — best for naturally variable HRV."
        }
    }
}

/// Where the recent 7-day trend sits relative to the personalized corridor.
enum HRVStatus: Equatable {
    case withinRange
    case belowRange
    case aboveRange
}

struct HRVBaselineResult: Equatable {
    var baselineMean: Double
    var baselineSD: Double
    var trendMean: Double
    var lowerBound: Double
    var upperBound: Double
    var cvPercent: Double
    var status: HRVStatus
    /// True when the recent week is much more variable than the user's own baseline,
    /// not an absolute CV cut-off (night-to-night SDNN CV of 10–20% is normal).
    var isHighVariability: Bool
}

enum HRVBaselineState: Equatable {
    /// Not enough history yet to trust a corridor; `validNights` counts usable
    /// nights in the combined baseline + acute lookback.
    case buildingBaseline(validNights: Int)
    case ready(HRVBaselineResult)
}

/// Full result of an analysis pass. `acuteAverageMs` is the 7-day mean shown on
/// the Today card and as the latest point of the graph's trend line — the single
/// source of truth for "your recent HRV" regardless of whether a corridor exists
/// yet. When `state` is `.ready`, `acuteAverageMs` equals the result's `trendMean`.
struct HRVAnalysis: Equatable {
    var acuteAverageMs: Double?
    var acuteNightsWithData: Int
    var acuteWindowNights: Int
    var state: HRVBaselineState
}

/// Personalized HRV baseline-vs-trend engine operating on stored daily SDNN
/// aggregates (`DailyRecord.sleepHrvSDNNMs`). Pure and dependency-free: callers
/// pass records in; nothing here touches HealthKit or SwiftData.
///
/// The baseline window deliberately ends the day before the acute window starts,
/// so the recent 7-day trend is never compared against a corridor that contains it.
enum HRVBaselineAnalyzer {
    static let baselineWindowDays = 28
    static let acuteWindowDays = 7
    static let minBaselineNights = 14
    static let minAcuteNights = 4
    /// Recent SD must exceed baseline SD by this factor to flag high variability.
    static let recentVolatilityMultiplier = 1.5

    static func analyze(
        records: [DailyRecord],
        todayKey: String,
        sensitivity: HRVSensitivity
    ) -> HRVAnalysis {
        let byDate = valuesByDate(records)
        let baseline = baselineValues(byDate: byDate, anchorKey: todayKey)
        let acute = acuteValues(byDate: byDate, anchorKey: todayKey)
        let acuteAverage = mean(acute)

        let state = baselineState(
            baseline: baseline,
            acute: acute,
            acuteAverage: acuteAverage,
            sensitivity: sensitivity
        )

        return HRVAnalysis(
            acuteAverageMs: acuteAverage,
            acuteNightsWithData: acute.count,
            acuteWindowNights: acuteWindowDays,
            state: state
        )
    }

    private static func baselineState(
        baseline: [Double],
        acute: [Double],
        acuteAverage: Double?,
        sensitivity: HRVSensitivity
    ) -> HRVBaselineState {
        guard baseline.count >= minBaselineNights,
              acute.count >= minAcuteNights,
              let baselineMean = mean(baseline), baselineMean > 0,
              let baselineSD = sampleStandardDeviation(baseline),
              let trendMean = acuteAverage else {
            return .buildingBaseline(validNights: baseline.count + acute.count)
        }

        let k = sensitivity.multiplier
        let lower = baselineMean - baselineSD * k
        let upper = baselineMean + baselineSD * k

        let status: HRVStatus
        if trendMean < lower {
            status = .belowRange
        } else if trendMean > upper {
            status = .aboveRange
        } else {
            status = .withinRange
        }

        let recentSD = sampleStandardDeviation(acute) ?? 0
        let isHighVariability = baselineSD > 0
            ? recentSD > baselineSD * recentVolatilityMultiplier
            : recentSD > 0

        return .ready(
            HRVBaselineResult(
                baselineMean: baselineMean,
                baselineSD: baselineSD,
                trendMean: trendMean,
                lowerBound: lower,
                upperBound: upper,
                cvPercent: baselineSD / baselineMean * 100,
                status: status,
                isHighVariability: isHighVariability
            )
        )
    }

    // MARK: - Window helpers (reused by the chart series builder)

    static func valuesByDate(_ records: [DailyRecord]) -> [String: Double] {
        records.reduce(into: [:]) { dict, record in
            if let value = record.sleepHrvSDNNMs {
                dict[record.date] = value
            }
        }
    }

    /// Most recent `acuteWindowDays` nights ending on `anchorKey` (inclusive).
    static func acuteValues(byDate: [String: Double], anchorKey: String) -> [Double] {
        windowValues(byDate: byDate, endingOn: anchorKey, days: acuteWindowDays)
    }

    /// `baselineWindowDays` nights ending the day before the acute window starts,
    /// so the two windows never overlap.
    static func baselineValues(byDate: [String: Double], anchorKey: String) -> [Double] {
        guard let baselineEndKey = DateHelpers.addDays(to: anchorKey, days: -acuteWindowDays) else {
            return []
        }
        return windowValues(byDate: byDate, endingOn: baselineEndKey, days: baselineWindowDays)
    }

    static func windowValues(byDate: [String: Double], endingOn endKey: String, days: Int) -> [Double] {
        guard let endDate = DateHelpers.date(from: endKey) else { return [] }
        return DateHelpers.rollingDateKeys(days: days, endingOn: endDate)
            .compactMap { byDate[$0] }
    }

    // MARK: - Statistics

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Sample (n−1) standard deviation; nil for fewer than two values.
    static func sampleStandardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2, let m = mean(values) else { return nil }
        let sumSquares = values.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (sumSquares / Double(values.count - 1)).squareRoot()
    }
}
