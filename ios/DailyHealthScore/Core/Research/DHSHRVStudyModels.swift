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

/// Least-squares best-fit line for the weekly scatterplot (HRV regressed on DHS).
struct DHSHRVScatterFit: Equatable {
    var slope: Double
    var intercept: Double
    var xMin: Double
    var xMax: Double

    func y(at x: Double) -> Double { intercept + slope * x }
}

/// Statistical helpers shared by the study models. These follow standard
/// methods so the output can withstand expert review.
enum DHSHRVStatistics {
    /// Fisher r-to-z confidence interval for a correlation coefficient.
    /// For Spearman we widen the standard error using the Bonett-Wright
    /// approximation, which is the accepted method for rank correlations.
    static func confidenceInterval(spearman r: Double, n: Int) -> (lower: Double, upper: Double)? {
        guard n >= 6, abs(r) < 0.999 else { return nil }
        let z = atanh(r)
        let standardError = sqrt((1 + (r * r) / 2) / Double(n - 3))
        let lower = tanh(z - 1.96 * standardError)
        let upper = tanh(z + 1.96 * standardError)
        return (min(lower, upper), max(lower, upper))
    }

    /// Maps a correlation magnitude to a plain-language strength word.
    static func strengthWord(forMagnitude magnitude: Double) -> String {
        if magnitude < 0.30 { return "weak" }
        if magnitude < 0.60 { return "moderate" }
        return "strong"
    }

    /// Plain-language label for a single correlation value, e.g. "moderate positive".
    static func label(for value: Double) -> String {
        if abs(value) < 0.05 { return "no" }
        let direction = value > 0 ? "positive" : "negative"
        return "\(strengthWord(forMagnitude: abs(value))) \(direction)"
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    /// Slope of a simple linear regression of `values` against their index.
    static func slopeOverIndex(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let n = Double(values.count)
        let xs = (0 ..< values.count).map(Double.init)
        let meanX = xs.reduce(0, +) / n
        let meanY = values.reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, values) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }
}

enum DHSHRVTrendDirection: Equatable {
    case strengthening
    case steady
    case easing

    var label: String {
        switch self {
        case .strengthening: return "Strengthening"
        case .steady: return "Holding steady"
        case .easing: return "Easing"
        }
    }

    var symbolName: String {
        switch self {
        case .strengthening: return "arrow.up.right"
        case .steady: return "arrow.right"
        case .easing: return "arrow.down.right"
        }
    }
}

/// A confidence interval expressed in plain language for the current window.
struct DHSHRVConfidence: Equatable {
    var pointValue: Double
    var lower: Double
    var upper: Double
    var pairedWeeks: Int

    var isClearlyPositive: Bool { lower > 0.05 }
    var isClearlyNegative: Bool { upper < -0.05 }
    var crossesZero: Bool { lower <= 0 && upper >= 0 }

    /// e.g. "likely somewhere between weak and moderate positive"
    var rangeText: String {
        let lowLabel = DHSHRVStatistics.label(for: lower)
        let highLabel = DHSHRVStatistics.label(for: upper)
        if lowLabel == highLabel {
            return "The relationship is likely \(lowLabel)."
        }
        return "The true relationship is likely somewhere between \(lowLabel) and \(highLabel)."
    }
}

/// Summary statistics across the alignment (relationship-over-time) windows.
struct DHSHRVAlignmentStats: Equatable {
    var median: Double
    var minValue: Double
    var maxValue: Double
    var positiveCount: Int
    var total: Int
    var direction: DHSHRVTrendDirection

    var typicalLabel: String { DHSHRVStatistics.label(for: median) }
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
    var scatterFit: DHSHRVScatterFit?
    var correlation: DHSHRVCorrelationResult
    var alignmentPoints: [DHSHRVAlignmentPoint]

    var hasAnyWeeklyData: Bool {
        weeklyPoints.contains { $0.averageDHS != nil || $0.averageHRV != nil }
    }

    /// Number of weekly points whose HRV average is based on 4-7 nights.
    var solidHRVWeekCount: Int {
        weeklyPoints.filter { $0.hrvCompleteness == .solid }.count
    }

    /// Number of weekly points that contributed a usable HRV average.
    var hrvWeekCount: Int {
        weeklyPoints.filter { $0.averageHRV != nil }.count
    }

    /// True when enough weeks rest on sparse data that confidence should soften.
    var hasLimitedData: Bool {
        guard hrvWeekCount > 0 else { return true }
        return solidHRVWeekCount < 8
    }

    /// Plain-language confidence interval for the primary (Spearman) statistic.
    var confidence: DHSHRVConfidence? {
        guard let value = correlation.spearman,
              let interval = DHSHRVStatistics.confidenceInterval(
                  spearman: value,
                  n: correlation.pairedWeeks
              ) else {
            return nil
        }
        return DHSHRVConfidence(
            pointValue: value,
            lower: interval.lower,
            upper: interval.upper,
            pairedWeeks: correlation.pairedWeeks
        )
    }

    /// Honest-but-encouraging note about statistical certainty.
    var significanceText: String {
        guard let confidence else {
            return "Keep logging DHS and sleep HRV so the app can estimate how confident this relationship is."
        }

        if confidence.isClearlyPositive {
            let base = "This positive relationship is statistically clear for this 91-day window."
            return hasLimitedData
                ? base + " A few weeks rest on only a handful of nights, so keep wearing your watch to firm it up."
                : base
        }

        if confidence.isClearlyNegative {
            return "For this window the values lean negative. With only 13 weekly points this is not conclusive, and HRV can be pushed down by sleep loss, stress, illness, alcohol, or training strain."
        }

        // Crosses zero: suggestive, not conclusive — framed encouragingly.
        var text = "With 13 weekly points this pattern is suggestive rather than statistically conclusive, which is normal. It is still encouraging: it draws on a full 91 days of data, and the link between higher HRV and better health is well established in research."
        if hasLimitedData {
            text += " Some weeks rest on only a few nights, so treat it as preliminary."
        }
        return text
    }

    var alignmentStats: DHSHRVAlignmentStats? {
        let values = alignmentPoints.compactMap(\.spearman)
        guard let median = DHSHRVStatistics.median(values),
              let minValue = values.min(),
              let maxValue = values.max() else {
            return nil
        }

        let direction: DHSHRVTrendDirection
        if let slope = DHSHRVStatistics.slopeOverIndex(values) {
            let totalChange = slope * Double(values.count - 1)
            if totalChange > 0.10 {
                direction = .strengthening
            } else if totalChange < -0.10 {
                direction = .easing
            } else {
                direction = .steady
            }
        } else {
            direction = .steady
        }

        return DHSHRVAlignmentStats(
            median: median,
            minValue: minValue,
            maxValue: maxValue,
            positiveCount: values.filter { $0 > 0 }.count,
            total: values.count,
            direction: direction
        )
    }

    /// One data-driven sentence summarizing the whole study for the top of the screen.
    var headline: String {
        guard let value = correlation.primaryValue else {
            return "Keep logging DHS and sleep HRV. Once the app has enough data it will tell you, in plain English, whether your healthier weeks line up with higher overnight HRV."
        }

        let label = DHSHRVStatistics.label(for: value)
        let core: String
        switch correlation.direction {
        case "positive":
            core = "Over your latest 91 days, higher-DHS weeks have tended to be followed by higher sleep HRV — a \(label) pattern."
        case "negative":
            core = "Over your latest 91 days, higher-DHS weeks have tended to be followed by lower sleep HRV — a \(label) pattern."
        default:
            core = "Over your latest 91 days, DHS and sleep HRV have not shown a clear weekly pattern yet."
        }

        if let stats = alignmentStats {
            return core + " Across the last \(stats.total) windows it stayed positive \(stats.positiveCount) of \(stats.total) times."
        }
        return core
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

    /// How strongly and how consistently higher DHS has lined up with higher HRV.
    var alignmentStrengthText: String {
        guard let stats = alignmentStats else {
            return "Keep collecting data to see whether higher DHS lines up with higher overnight HRV over time."
        }

        let medianText = String(format: "%.2f", stats.median)
        let rangeText = "\(String(format: "%.2f", stats.minValue)) to \(String(format: "%.2f", stats.maxValue))"
        return "Higher DHS lined up with higher overnight HRV in \(stats.positiveCount) of the last \(stats.total) windows. The link is typically \(stats.typicalLabel) (Spearman \(medianText), where +1 is a perfect match), ranging from \(rangeText). The trend is \(stats.direction.label.lowercased())."
    }

    /// Why this stability view matters, with health framing.
    var alignmentSummary: String {
        guard let stats = alignmentStats else {
            return "Keep collecting data to see whether higher DHS lines up with higher overnight HRV over time."
        }

        let percentPositive = Double(stats.positiveCount) / Double(stats.total)
        if percentPositive >= 0.75 {
            return "The closer these lines stay to +1 across many overlapping windows, the more dependable the “higher DHS, higher HRV” link is — far more convincing than one good window alone. That is encouraging, because higher HRV trends are linked in research with better cardiovascular fitness and lower cardiovascular risk."
        }
        if percentPositive >= 0.50 {
            return "Higher DHS has lined up with higher HRV in about half of recent windows, so the link is showing but still settling. The closer the lines climb toward +1 and stay there, the more dependable that link becomes."
        }
        return "Higher DHS and higher HRV have not consistently lined up yet — the lines are not staying above zero. Tracking this as your habits change shows whether the link strengthens; HRV can also be pushed down by sleep disruption, stress, illness, alcohol, or training strain."
    }
}
