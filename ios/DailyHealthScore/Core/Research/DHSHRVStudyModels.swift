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

    var hasAnyWeeklyData: Bool {
        weeklyPoints.contains { $0.averageDHS != nil || $0.averageHRV != nil }
    }

    var relationshipSummary: String {
        guard let value = correlation.primaryValue else {
            return "Keep collecting DHS and sleep HRV data to see whether your trends move together."
        }

        let formatted = String(format: "%.2f", value)
        switch correlation.direction {
        case "positive":
            return "Your habits and HRV appear to be moving in the same direction over this 91-day window. Spearman \(formatted) suggests a \(correlation.strength) positive relationship."
        case "negative":
            return "Your DHS and HRV are not moving together in the expected direction over this 91-day window. Spearman \(formatted) suggests a \(correlation.strength) negative relationship."
        default:
            return "Your DHS and HRV do not show a clear weekly relationship over this 91-day window. Spearman \(formatted) suggests a weak relationship."
        }
    }
}
