import Foundation

/// Which window Home is writing for. Morning runs until 5pm; evening after
/// that and through the night. The card does not print this label. The window
/// only decides when the thoughts are rewritten.
enum CoachCheckInKind: String, Codable, Sendable {
    case morning
    case evening
}

/// The Home card. Up to three thoughts the Coach chooses, rewritten for each
/// window of the day and again when the day's shape changes. A deterministic
/// line stands in when the model is unavailable. Reply opens a chat that
/// starts with this text.
struct CoachCheckIn: Equatable, Codable, Sendable {
    var kind: CoachCheckInKind
    var dateKey: String
    /// First thought, kept so a reader that only knows the older field still
    /// has something to say. New cards put the full feed in `thoughts`.
    var healthLine: String
    /// Older cards: one question. Empty when `thoughts` carries the card.
    var question: String
    /// Older cards: one line for tomorrow. Empty on a thought feed.
    var tomorrowLine: String
    /// Older cards: last week in one sentence. Empty on a thought feed.
    var trendLine: String
    /// The thoughts on the card, most useful first. Empty on a card saved
    /// before the feed, which still speaks through the four older fields.
    var thoughts: [String]
    var replyThreadID: UUID?
    var isFallback: Bool
    var generatedAt: Date

    init(
        kind: CoachCheckInKind,
        dateKey: String,
        healthLine: String,
        question: String = "",
        tomorrowLine: String = "",
        trendLine: String = "",
        thoughts: [String] = [],
        replyThreadID: UUID? = nil,
        isFallback: Bool = false,
        generatedAt: Date = Date()
    ) {
        self.kind = kind
        self.dateKey = dateKey
        self.healthLine = healthLine
        self.question = question
        self.tomorrowLine = tomorrowLine
        self.trendLine = trendLine
        self.thoughts = thoughts
        self.replyThreadID = replyThreadID
        self.isFallback = isFallback
        self.generatedAt = generatedAt
    }

    /// What the card shows. Thoughts when the Coach wrote them; otherwise the
    /// older fields, in the order a reply used to speak them.
    var displayLines: [String] {
        let chosen = thoughts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !chosen.isEmpty {
            return Array(chosen.prefix(3))
        }
        return [healthLine, trendLine, tomorrowLine, question]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Everything the card says, as the first message of the reply chat.
    var spokenText: String {
        displayLines.joined(separator: " ")
    }

    var hasReply: Bool { replyThreadID != nil }

    private enum CodingKeys: String, CodingKey {
        case kind, dateKey, healthLine, question, tomorrowLine, trendLine, thoughts, replyThreadID, isFallback, generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(CoachCheckInKind.self, forKey: .kind)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        healthLine = try container.decode(String.self, forKey: .healthLine)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        tomorrowLine = try container.decodeIfPresent(String.self, forKey: .tomorrowLine) ?? ""
        trendLine = try container.decodeIfPresent(String.self, forKey: .trendLine) ?? ""
        thoughts = try container.decodeIfPresent([String].self, forKey: .thoughts) ?? []
        replyThreadID = try container.decodeIfPresent(UUID.self, forKey: .replyThreadID)
        isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback) ?? false
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(dateKey, forKey: .dateKey)
        try container.encode(healthLine, forKey: .healthLine)
        try container.encode(question, forKey: .question)
        try container.encode(tomorrowLine, forKey: .tomorrowLine)
        try container.encode(trendLine, forKey: .trendLine)
        try container.encode(thoughts, forKey: .thoughts)
        try container.encodeIfPresent(replyThreadID, forKey: .replyThreadID)
        try container.encode(isFallback, forKey: .isFallback)
        try container.encode(generatedAt, forKey: .generatedAt)
    }
}

/// One active SMART goal on the evening card, with a tap to log today.
struct CoachCheckInGoalRow: Identifiable, Equatable, Sendable {
    var goalId: UUID
    var title: String
    var progressText: String
    var loggedToday: Bool
    var canLog: Bool

    var id: UUID { goalId }
}

enum CoachCheckInLogic {
    /// Morning until 5pm local; evening reflection after that and overnight.
    static func kind(for date: Date = Date(), calendar: Calendar = .current) -> CoachCheckInKind {
        let hour = calendar.component(.hour, from: date)
        return (5..<17).contains(hour) ? .morning : .evening
    }

    static func isMonday(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 2
    }

    /// Health has synced something for today. Before that, writing a card
    /// would describe an empty day as a bad one.
    static func hasData(_ record: DailyRecord) -> Bool {
        record.sleepHours > 0 || record.fiberGrams > 0 || record.exerciseMinutes > 0
    }

    /// The shape of the day as the card describes it: whether sleep is in, and
    /// which pillars are met versus still open. It changes a few times a day
    /// at most (first sync, a pillar crossing its goal), and each change earns
    /// a rewrite so the card never contradicts the tiles above it. The weakest
    /// pillar is deliberately not part of it: fiber and movement leapfrog each
    /// other all day, and the card speaks in open-versus-in-hand terms instead.
    static func statusSignature(for record: DailyRecord) -> String {
        let sleep = record.sleepHours <= 0
            ? "none"
            : (record.sleepHours >= record.sleepGoal.rawValue ? "met" : "below")
        let fiber = record.fiberGrams >= Double(record.fiberGoal.rawValue) ? "met" : "open"
        let exercise = record.exerciseMinutes >= Double(record.exerciseGoalMinutes) ? "met" : "open"
        return "sleep=\(sleep),fiber=\(fiber),exercise=\(exercise)"
    }

    /// One write per window and per shape of the day. Tapping a goal Done must
    /// not rewrite the card, so progress masks stay out of the key; only which
    /// goals exist matters. Notes are read when the card is written. A new note
    /// shows up on the next window, the next change in shape, or a pull to refresh.
    static func cacheKey(
        dateKey: String,
        kind: CoachCheckInKind,
        goals: [SMARTGoal],
        signature: String = ""
    ) -> String {
        let ids = goals
            .filter { $0.status == .active && !$0.isComplete && !$0.isExpired }
            .map(\.id.uuidString)
            .sorted()
            .joined(separator: ",")
        return "\(dateKey)#\(kind.rawValue)#checkin4#\(ids)#\(signature)"
    }

    /// Active goals a person could still log today, unlogged ones first.
    static func goalRows(
        goals: [SMARTGoal],
        activities: [SMARTGoalActivity],
        todayKey: String
    ) -> [CoachCheckInGoalRow] {
        let byGoal = Dictionary(grouping: activities, by: \.goalId)
        let rows = goals
            .filter { $0.status == .active && !$0.isComplete && !$0.isExpired }
            .map { goal -> CoachCheckInGoalRow in
                let today = SMARTGoalActivityLogic.activeCheckIns(in: byGoal[goal.id] ?? [])
                    .contains { $0.localDateKey == todayKey }
                return CoachCheckInGoalRow(
                    goalId: goal.id,
                    title: goal.specificText.trimmingCharacters(in: .whitespacesAndNewlines),
                    progressText: "\(goal.filledCount) of \(goal.targetCount)",
                    loggedToday: today,
                    canLog: goal.canLogCheckIn && !today
                )
            }
        return rows.sorted { lhs, rhs in
            if lhs.loggedToday != rhs.loggedToday { return !lhs.loggedToday }
            return lhs.title < rhs.title
        }
    }

    /// Goal facts for the check-in prompt.
    static func goalsBlock(_ rows: [CoachCheckInGoalRow]) -> String {
        guard !rows.isEmpty else { return "No active SMART goals." }
        return rows.map { row in
            "- \"\(row.title.limitedToCoachBudget(70))\": \(row.progressText) check-ins; \(row.loggedToday ? "logged today" : "not logged today (a missing check-in is not a missed action)")"
        }.joined(separator: "\n")
    }
}

/// Last week against the week before, computed here so the Coach only phrases it.
struct CoachTrendDigest: Equatable, Sendable {
    var facts: [String]
    var sentence: String

    static let minimumDaysPerWeek = 4

    static func build(
        records: [DailyRecord],
        goals: [SMARTGoal],
        activities: [SMARTGoalActivity],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachTrendDigest? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let lastWeekKeys = DateHelpers.rollingDateKeys(days: 7, endingOn: yesterday)
        let twoWeeks = DateHelpers.rollingDateKeys(days: 14, endingOn: yesterday)
        let priorWeekKeys = Array(twoWeeks.prefix(7))
        guard let recent = RollingStatsCalculator.compute(records: records, windowKeys: lastWeekKeys),
              recent.daysWithData >= minimumDaysPerWeek else { return nil }
        let prior = RollingStatsCalculator.compute(records: records, windowKeys: priorWeekKeys)
        let priorUsable = (prior?.daysWithData ?? 0) >= minimumDaysPerWeek

        var facts: [String] = []
        var spoken: [String] = []

        let score = String(format: "%.1f", recent.avgTotalScore)
        if priorUsable, let prior {
            let delta = recent.avgTotalScore - prior.avgTotalScore
            let direction = delta >= 0.3 ? "up from" : (delta <= -0.3 ? "down from" : "about even with")
            let priorScore = String(format: "%.1f", prior.avgTotalScore)
            facts.append("Average score last week \(score) of 10 across \(recent.daysWithData) days, \(direction) \(priorScore) the week before.")
            spoken.append("Last week averaged \(score) of 10, \(direction) \(priorScore).")
        } else {
            facts.append("Average score last week \(score) of 10 across \(recent.daysWithData) days. No usable week before it for comparison.")
            spoken.append("Last week averaged \(score) of 10.")
        }

        let sleep = String(format: "%.1f", recent.avgSleepHours)
        facts.append("Average sleep \(sleep) h.")

        let fiberGoalDays = recent.recordsInWindow.filter { $0.fiberGrams >= Double($0.fiberGoal.rawValue) }.count
        facts.append("Fiber goal reached on \(fiberGoalDays) of \(recent.daysWithData) logged days.")
        spoken.append("Sleep averaged \(sleep) hours and fiber hit goal on \(fiberGoalDays) of \(recent.daysWithData) days.")

        let exercise = String(format: "%.0f", recent.avgExerciseMinutes)
        facts.append("Average exercise \(exercise) min per logged day.")

        if let best = recent.recordsInWindow.max(by: { $0.totalScore < $1.totalScore }),
           let bestDate = DateHelpers.date(from: best.date) {
            let weekday = bestDate.formatted(.dateTime.weekday(.wide))
            facts.append("Best day: \(weekday) at \(String(format: "%.1f", best.totalScore)).")
        }

        let lastWeekSet = Set(lastWeekKeys)
        let priorWeekSet = Set(priorWeekKeys)
        let dated = SMARTGoalActivityLogic.activeCheckIns(in: activities).filter(\.hasKnownOccurrenceDate)
        let recentCheckIns = dated.filter { lastWeekSet.contains($0.localDateKey) }.count
        let priorCheckIns = dated.filter { priorWeekSet.contains($0.localDateKey) }.count
        let hasLiveGoals = goals.contains { $0.status == .active && !$0.isComplete }
        if hasLiveGoals || recentCheckIns > 0 {
            facts.append("SMART check-ins with dates: \(recentCheckIns) last week, \(priorCheckIns) the week before. Counts do not imply a daily schedule.")
            if recentCheckIns > 0 || priorCheckIns > 0 {
                let plural = recentCheckIns == 1 ? "check-in" : "check-ins"
                spoken.append("You logged \(recentCheckIns) SMART \(plural), \(priorCheckIns == recentCheckIns ? "same as" : (recentCheckIns > priorCheckIns ? "up from" : "down from")) \(priorCheckIns).")
            }
        }

        return CoachTrendDigest(facts: facts, sentence: spoken.joined(separator: " "))
    }

    var promptBlock: String {
        "TREND FACTS (last week vs. the week before; already computed — phrase, never recompute):\n"
            + facts.map { "- \($0)" }.joined(separator: "\n")
    }
}

/// Even-pace arithmetic for a goal window, so the Coach can offer to shrink a
/// plan that is slipping without ever inventing a missed day.
enum SMARTGoalPace {
    static let shrinkOfferThreshold = 2

    static func behindCount(goal: SMARTGoal, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard goal.status == .active, !goal.isComplete, goal.endDate > now, goal.timeWindowDays > 0 else { return 0 }
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: goal.createdAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        guard elapsed > 0 else { return 0 }
        let fraction = min(Double(elapsed) / Double(goal.timeWindowDays), 1)
        let expected = Int((Double(goal.targetCount) * fraction).rounded(.down))
        return max(expected - goal.filledCount, 0)
    }

    /// Prompt lines for goals far enough behind that a smaller plan is worth offering.
    static func directive(goals: [SMARTGoal], now: Date = Date(), calendar: Calendar = .current) -> String? {
        let lines = goals.compactMap { goal -> String? in
            let behind = behindCount(goal: goal, now: now, calendar: calendar)
            guard behind >= shrinkOfferThreshold else { return nil }
            return "- \"\(goal.specificText.limitedToCoachBudget(70))\" is \(behind) check-ins behind an even pace (\(goal.filledCount) of \(goal.targetCount)). If it comes up, offer once to shrink the plan — fewer check-ins or a smaller action — as a goalProposal update. A plan change is not a failure and not a completed action."
        }
        guard !lines.isEmpty else { return nil }
        return "GOAL PACE:\n" + lines.joined(separator: "\n")
    }

    /// The same lag, as a fact. The Home card does not tell the Coach to offer
    /// a plan change; he can mention the pace when it is the useful thought.
    static func paceFacts(goals: [SMARTGoal], now: Date = Date(), calendar: Calendar = .current) -> String? {
        let lines = goals.compactMap { goal -> String? in
            let behind = behindCount(goal: goal, now: now, calendar: calendar)
            guard behind >= shrinkOfferThreshold else { return nil }
            let title = goal.specificText.limitedToCoachBudget(70)
            return "- \"\(title)\" is \(behind) check-ins behind an even pace (\(goal.filledCount) of \(goal.targetCount))."
        }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}

/// The first conversation. One short intake, once, then never again.
enum CoachAcquaintance {
    /// With this many live notes the Coach already knows enough to skip the intake.
    static let notesThatSkipIntake = 3

    /// Names what is useful up front, so a short answer can still be specific,
    /// then asks the two things every later reply leans on.
    static let opener = """
    Before we get to any numbers, I'd like to know you a little — the things a good coach actually uses: what you do and how your week runs, who's at home, what tends to trip you up and what helps, what lifts you. Nothing here is a test, and you can skip anything.

    To start: what should I call you, and what do you do for work — including which days tend to run heaviest?
    """

    static func existingThread(in threads: [CoachThread]) -> CoachThread? {
        CoachThreadLogic.sorted(threads).first { $0.kind == .acquaintance }
    }

    static func isNeeded(threads: [CoachThread], liveMemoryCount: Int) -> Bool {
        guard existingThread(in: threads) == nil else { return false }
        return liveMemoryCount < notesThatSkipIntake
    }
}
