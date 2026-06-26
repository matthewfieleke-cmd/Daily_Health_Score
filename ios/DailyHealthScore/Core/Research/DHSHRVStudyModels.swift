import Foundation

enum StudyPointCompleteness: Equatable {
    case none
    case sparse
    case solid

    static func classify(validCount: Int) -> StudyPointCompleteness {
        if validCount >= 4 { return .solid }
        if validCount >= 1 { return .sparse }
        return .none
    }
}

struct DHSHRVDailyPair: Identifiable, Equatable {
    var id: String { dhsDate }
    var dhsDate: String
    var hrvDate: String
    var dhsScore: Double?
    var followingNightHRV: Double?
}

struct DHSHRVWeeklyPoint: Identifiable, Equatable {
    var id: Int { weekIndex }
    var weekIndex: Int
    var dhsStartDate: String
    var dhsEndDate: String
    var hrvStartDate: String
    var hrvEndDate: String
    var averageDHS: Double?
    var averageHRV: Double?
    var dhsValueCount: Int
    var hrvValueCount: Int

    var dhsCompleteness: StudyPointCompleteness {
        StudyPointCompleteness.classify(validCount: dhsValueCount)
    }

    var hrvCompleteness: StudyPointCompleteness {
        StudyPointCompleteness.classify(validCount: hrvValueCount)
    }
}

struct DHSHRVZScorePoint: Identifiable, Equatable {
    var id: String { "\(weekIndex)-\(series)" }
    var weekIndex: Int
    var series: String
    var zScore: Double
}

struct DHSHRVScatterPoint: Identifiable, Equatable {
    var id: Int { weekIndex }
    var weekIndex: Int
    var averageDHS: Double
    var averageHRV: Double
}

struct DHSHRVAlignmentPoint: Identifiable, Equatable {
    var id: String { windowEndDate }
    var index: Int
    var windowStartDate: String
    var windowEndDate: String
    var spearman: Double?
    var pearson: Double?
    var pairedWeeks: Int
}

struct DHSHRVCorrelationChange: Equatable {
    var current: Double?
    var previous: Double?

    var delta: Double? {
        guard let current, let previous else { return nil }
        return current - previous
    }

    var directionText: String {
        guard let delta else { return "No previous window yet" }
        if abs(delta) < 0.01 { return "About the same as the previous window" }
        return delta > 0 ? "More positive than the previous window" : "Less positive than the previous window"
    }

    var formattedDelta: String? {
        guard let delta else { return nil }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", delta))"
    }
}

struct DHSHRVCorrelationResult: Equatable {
    var spearman: Double?
    var pearson: Double?
    var pairedWeeks: Int

    var primaryValue: Double? { spearman }

    var direction: String {
        guard let value = primaryValue, abs(value) >= 0.05 else { return "neutral" }
        return value > 0 ? "positive" : "negative"
    }

    var strength: String {
        guard let value = primaryValue else { return "not enough data" }
        let magnitude = abs(value)
        if magnitude < 0.30 { return "weak" }
        if magnitude < 0.60 { return "moderate" }
        return "strong"
    }

    var displayLabel: String {
        guard primaryValue != nil else { return "Not enough data yet" }
        if direction == "neutral" { return "Weak relationship" }
        return "\(strength.capitalized) \(direction)"
    }
}

struct DHSHRVStudyResult: Equatable {
    static let studyWindowDays = 91
    static let blockDays = 7
    static let weeklyPointCount = 13
    static let alignmentWindowCount = 30

    var todayKey: String
    var dhsStartDate: String
    var dhsEndDate: String
    var hrvStartDate: String
    var hrvEndDate: String
    var dailyPairs: [DHSHRVDailyPair]
    var weeklyPoints: [DHSHRVWeeklyPoint]
    var zScorePoints: [DHSHRVZScorePoint]
    var scatterPoints: [DHSHRVScatterPoint]
    var correlation: DHSHRVCorrelationResult
    var alignmentPoints: [DHSHRVAlignmentPoint]

    var hasAnyWeeklyData: Bool {
        weeklyPoints.contains { $0.averageDHS != nil || $0.averageHRV != nil }
    }

    var previousAlignmentPoint: DHSHRVAlignmentPoint? {
        guard alignmentPoints.count >= 2 else { return nil }
        return alignmentPoints[alignmentPoints.count - 2]
    }

    var spearmanChange: DHSHRVCorrelationChange {
        DHSHRVCorrelationChange(
            current: correlation.spearman,
            previous: previousAlignmentPoint?.spearman
        )
    }

    var pearsonChange: DHSHRVCorrelationChange {
        DHSHRVCorrelationChange(
            current: correlation.pearson,
            previous: previousAlignmentPoint?.pearson
        )
    }

    var relationshipSummary: String {
        guard let value = correlation.primaryValue else {
            return "Keep collecting DHS and sleep HRV data to see whether your trends move together."
        }

        let formatted = String(format: "%.2f", value)
        switch correlation.direction {
        case "positive":
            return "Your Daily Health Score and sleep HRV are moving in the same direction over this 91-day window. Spearman \(formatted) suggests a \(correlation.strength) positive relationship."
        case "negative":
            return "Your Daily Health Score and sleep HRV are not moving together in the expected direction over this 91-day window. Spearman \(formatted) suggests a \(correlation.strength) negative relationship."
        default:
            return "Your Daily Health Score and sleep HRV do not show a clear weekly relationship over this 91-day window. Spearman \(formatted) suggests a weak relationship."
        }
    }

    var alignmentSummary: String {
        let validSpearman = alignmentPoints.compactMap(\.spearman)
        guard !validSpearman.isEmpty else {
            return "Keep collecting data to see whether the DHS-HRV relationship stays positive over time."
        }

        let positiveCount = validSpearman.filter { $0 > 0 }.count
        let percentPositive = Double(positiveCount) / Double(validSpearman.count)

        if percentPositive >= 0.75 {
            return "The relationship has been positive in most recent windows, which is encouraging because higher HRV trends are linked in research with better cardiovascular fitness and lower cardiovascular risk."
        }
        if percentPositive >= 0.50 {
            return "The relationship has been positive in about half of recent windows. This suggests some alignment, but the pattern is still developing."
        }
        return "The relationship has not been consistently positive yet. This can happen when HRV is being influenced by sleep disruption, stress, illness, alcohol, or training strain."
    }
}
