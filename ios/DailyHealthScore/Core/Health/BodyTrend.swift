import Foundation

/// One weight reading from Health.
struct BodyWeightSample: Equatable, Sendable {
    var date: Date
    var kilograms: Double
}

/// The unit the person sees weight in. Kilograms stay canonical underneath;
/// this only decides the words.
enum BodyMassUnit: String, Equatable, Codable, Sendable {
    case kilograms
    case pounds

    /// What Health would show when it has not told us: pounds in the US.
    static func preferred(for locale: Locale = .current) -> BodyMassUnit {
        locale.measurementSystem == .us ? .pounds : .kilograms
    }

    var symbol: String { self == .pounds ? "lb" : "kg" }

    func value(fromKilograms kilograms: Double) -> Double {
        self == .pounds ? kilograms * 2.20462262 : kilograms
    }

    /// "269.2 lb" or "122.1 kg", one decimal either way.
    func text(fromKilograms kilograms: Double) -> String {
        "\(BodyTrend.round1(value(fromKilograms: kilograms))) \(symbol)"
    }

    /// The noise band in this unit's words.
    var noiseBandDescription: String {
        self == .pounds ? "within about a pound" : "within half a kilogram"
    }
}

/// Weight, height, and BMI as Health reports them, before any interpretation.
struct BodyMeasurements: Equatable, Sendable {
    var weights: [BodyWeightSample] = []
    var heightMeters: Double?
    var latestBMISample: Double?
    var latestBMIDate: Date?
    var unit: BodyMassUnit = .preferred()
    /// From Health's characteristics, so the Coach never has to guess either.
    var ageYears: Int?
    var biologicalSex: String?

    var isEmpty: Bool {
        weights.isEmpty && heightMeters == nil && latestBMISample == nil && ageYears == nil && biologicalSex == nil
    }
}

/// What the Coach is allowed to know about someone's weight: a smoothed
/// level, a direction over four and twelve weeks, BMI as a screening number,
/// and how fresh it all is. Never the daily wobble.
struct BodyTrend: Equatable, Sendable {
    enum Direction: String, Equatable, Sendable {
        case steady
        case down
        case up
    }

    /// Below this, a change is noise, not a trend.
    static let noiseBandKilograms = 0.5
    static let smoothingDays = 7
    static let staleAfterDays = 14

    var latestKilograms: Double?
    var latestDate: Date?
    var smoothedKilograms: Double?
    var changeOverFourWeeks: Double?
    var changeOverTwelveWeeks: Double?
    var bmi: Double?
    var heightMeters: Double?
    var daysSinceLatest: Int?
    var readingCount: Int
    var unit: BodyMassUnit = .kilograms
    var ageYears: Int?
    var biologicalSex: String?

    var direction4w: Direction? { changeOverFourWeeks.map(Self.direction) }
    var direction12w: Direction? { changeOverTwelveWeeks.map(Self.direction) }

    static func direction(_ change: Double) -> Direction {
        if change <= -noiseBandKilograms { return .down }
        if change >= noiseBandKilograms { return .up }
        return .steady
    }

    /// WHO screening bands. A label, not a verdict; the charter says so too.
    static func bmiBand(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "below the usual range"
        case 18.5..<25: return "in the usual range"
        case 25..<30: return "in the overweight screening range"
        default: return "in the obesity screening range"
        }
    }

    static func build(
        from measurements: BodyMeasurements,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BodyTrend? {
        let weights = measurements.weights
            .filter { $0.kilograms > 20 && $0.kilograms < 400 }
            .sorted { $0.date < $1.date }
        var trend = BodyTrend(readingCount: weights.count)
        trend.heightMeters = measurements.heightMeters
        trend.unit = measurements.unit
        trend.ageYears = measurements.ageYears
        trend.biologicalSex = measurements.biologicalSex

        if let latest = weights.last {
            trend.latestKilograms = round1(latest.kilograms)
            trend.latestDate = latest.date
            trend.daysSinceLatest = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: latest.date), to: calendar.startOfDay(for: now)
            ).day
            trend.smoothedKilograms = windowAverage(weights, ending: latest.date, days: smoothingDays, calendar: calendar)
            if let recent = trend.smoothedKilograms {
                if let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: latest.date),
                   let earlier = windowAverage(weights, ending: fourWeeksAgo, days: smoothingDays, calendar: calendar) {
                    trend.changeOverFourWeeks = round1(recent - earlier)
                }
                if let twelveWeeksAgo = calendar.date(byAdding: .day, value: -84, to: latest.date),
                   let earlier = windowAverage(weights, ending: twelveWeeksAgo, days: smoothingDays, calendar: calendar) {
                    trend.changeOverTwelveWeeks = round1(recent - earlier)
                }
            }
        }

        if let height = measurements.heightMeters, height > 1.0, height < 2.6, let kilograms = trend.smoothedKilograms ?? trend.latestKilograms {
            trend.bmi = round1(kilograms / (height * height))
        } else if let sample = measurements.latestBMISample, sample > 10, sample < 80 {
            trend.bmi = round1(sample)
        }

        guard trend.latestKilograms != nil || trend.bmi != nil || trend.ageYears != nil || trend.biologicalSex != nil else { return nil }
        return trend
    }

    /// Average of readings in the `days` ending on `end`; nil when there are none.
    static func windowAverage(
        _ weights: [BodyWeightSample],
        ending end: Date,
        days: Int,
        calendar: Calendar
    ) -> Double? {
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: end)) else { return nil }
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        let inWindow = weights.filter { $0.date >= start && $0.date < endOfDay }
        guard !inWindow.isEmpty else { return nil }
        return inWindow.map(\.kilograms).reduce(0, +) / Double(inWindow.count)
    }

    static func round1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    // MARK: - Words for the model

    /// Sentences, not readings, in the unit the person uses. The daily number
    /// appears only as "latest".
    var promptBlock: String {
        var lines: [String] = []
        let person = [ageYears.map { "age \($0)" }, biologicalSex].compactMap { $0 }
        if !person.isEmpty {
            lines.append("Person: \(person.joined(separator: ", ")) per Health — the only source for either; never guess an age.")
        }
        if let smoothed = smoothedKilograms ?? latestKilograms {
            var line = "Weight: about \(unit.text(fromKilograms: smoothed)), seven-day average"
            if let days = daysSinceLatest {
                if days > BodyTrend.staleAfterDays {
                    line += "; the last reading is \(days) days old, so treat it as background"
                } else if days > 0 {
                    line += "; last reading \(days) day\(days == 1 ? "" : "s") ago"
                }
            }
            lines.append(line + ".")
        }
        if let change = changeOverFourWeeks, let direction = direction4w {
            lines.append(changeSentence(change, direction: direction, period: "four weeks"))
        }
        if let change = changeOverTwelveWeeks, let direction = direction12w {
            lines.append(changeSentence(change, direction: direction, period: "twelve weeks"))
        }
        if changeOverFourWeeks == nil, changeOverTwelveWeeks == nil, readingCount > 0 {
            lines.append("Not enough readings yet for a trend; say so if asked.")
        }
        if let bmi {
            lines.append("BMI about \(bmi), \(BodyTrend.bmiBand(bmi)) — a screening number blind to build and muscle, never a verdict.")
        }
        guard !lines.isEmpty else { return "No weight or height data shared." }
        if smoothedKilograms != nil || latestKilograms != nil {
            lines.append("Speak in \(unit == .pounds ? "pounds" : "kilograms"); that is how this person weighs themselves.")
        }
        return lines.joined(separator: " ")
    }

    private func changeSentence(_ change: Double, direction: Direction, period: String) -> String {
        switch direction {
        case .steady:
            return "Steady over the last \(period) (\(unit.noiseBandDescription))."
        case .down:
            return "Down about \(unit.text(fromKilograms: abs(change))) over the last \(period), gradual."
        case .up:
            return "Up about \(unit.text(fromKilograms: abs(change))) over the last \(period)."
        }
    }
}
