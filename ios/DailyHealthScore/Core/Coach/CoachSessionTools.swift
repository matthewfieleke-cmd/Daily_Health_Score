import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// What the Coach can reach for during a reply, and what it can ask the app to
/// do. Facts are read live from the context so a long-lived session never sees
/// stale numbers; actions land in the context for the app to validate and show.
enum CoachSessionTools {
    #if canImport(FoundationModels)
    static func make(context: CoachLiveContext) -> [any Tool] {
        [
            CoachLookupTodayTool(context: context),
            CoachLookupDaysTool(context: context),
            CoachLookupGoalsTool(context: context),
            CoachLookupPersonTool(context: context),
            CoachBodyTrendTool(context: context),
            CoachFoodLookupTool(),
            CoachEvidenceSearchTool(),
            CoachCalculatorTool(),
            CoachRememberTool(context: context),
            CoachProposeGoalTool(context: context),
            CoachLogCheckInTool(context: context)
        ]
    }
    #endif

    /// The inventory, for tests and the eval screen.
    static let toolNames = "lookupTodayHealth, lookupDays, lookupSMARTGoals, lookupWhatWeRemember, lookupWeightTrend, lookupFood, searchEvidence, calculate, rememberAboutPerson, proposeSMARTGoal, logGoalCheckIn"
}

#if canImport(FoundationModels)
struct CoachLookupTodayTool: Tool {
    let name = "lookupTodayHealth"
    let description = "Today's Daily Health Score with sleep, fiber, exercise, this week's averages, HRV against their usual range, and computed SMART goal status. Call when the person asks about today or about their numbers."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "What you need the numbers for.")
        var reason: String
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("lookupTodayHealth")
        return await context.todayPayload
    }
}

struct CoachLookupDaysTool: Tool {
    let name = "lookupDays"
    let description = "Sleep, fiber, exercise, the score, and sleep HRV for any past day or stretch of days, with the averages across the window and the days that have no record. Call for a question about a particular day, a week, a month, or any window other than today."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "First day of the window as yyyy-MM-dd. Nil when counting back with startDaysAgo.")
        var startDate: String?
        @Guide(description: "Last day as yyyy-MM-dd. Nil for a single day, or when counting back with endDaysAgo.")
        var endDate: String?
        @Guide(description: "How many days back the window starts: 1 is yesterday, 7 is a week ago. Nil when giving dates.")
        var startDaysAgo: Int?
        @Guide(description: "How many days back the window ends: 0 is today, 1 is yesterday. Nil for a single day, or when giving dates.")
        var endDaysAgo: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("lookupDays")
        return await context.daysPayload(
            startDate: arguments.startDate,
            endDate: arguments.endDate,
            startDaysAgo: arguments.startDaysAgo,
            endDaysAgo: arguments.endDaysAgo
        )
    }
}

struct CoachLookupGoalsTool: Tool {
    let name = "lookupSMARTGoals"
    let description = "Saved SMART goals with exact goalIDs, progress, pace, deadlines, and cues. Call when goals come up, before proposing a change, and before offering to log a check-in. This list is the truth about what is saved, including a draft they saved earlier in the chat."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "Which goal or question you are working on.")
        var focus: String
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("lookupSMARTGoals")
        return await context.goalsPayload
    }
}

struct CoachLookupPersonTool: Tool {
    let name = "lookupWhatWeRemember"
    let description = "Your dated notes about this person — who is in their life, their patterns and what helps, how they eat, their routines, their health, recent state — plus summaries of other recent chats. Call when knowing this person would change the answer. Leave it when a stranger would have gotten the same reply."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "What about this person you need to recall.")
        var topic: String
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("lookupWhatWeRemember")
        return await context.personPayload
    }
}

struct CoachBodyTrendTool: Tool {
    let name = "lookupWeightTrend"
    let description = "The person's weight trend, BMI, age, and sex as shared from Apple Health. Call when weight, age, protein, or energy needs come up. Never guess an age instead of calling this."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "Why the trend is needed.")
        var reason: String
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("lookupWeightTrend")
        return await context.bodyPayload
    }
}

// MARK: - Actions

struct CoachRememberTool: Tool {
    let name = "rememberAboutPerson"
    let description = "Keep a dated note about this person in one of nine files. One full sentence with its context, in their own framing (a struggle they are working on is not a habit they keep), third person, under 240 characters, their phrases in quotes. Date a fact only when they gave the date; never invent a month. Never their metrics, the score, or your own advice. Only what they actually said."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "add, update, or remove.")
        var operation: String
        @Guide(description: "aboutYou, people, patterns, coaching, goals, likes, routines, body, or recent.")
        var section: String
        @Guide(description: "The note. Empty for remove.")
        var text: String
        @Guide(description: "For update or remove: the existing note being replaced or removed, quoted as closely as possible. Empty for add.")
        var replaces: String
        @Guide(description: "stated when they said it; inferred when it is your read.")
        var basis: String
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("rememberAboutPerson")
        return await context.remember(
            operation: arguments.operation,
            section: arguments.section,
            text: arguments.text,
            replaces: arguments.replaces,
            basis: arguments.basis
        )
    }
}

struct CoachProposeGoalTool: Tool {
    let name = "proposeSMARTGoal"
    let description = "Hand the person a SMART goal draft to review — a new goal, or an update to a saved one by exact goalID — once a concrete plan is agreed. Only one draft can be on screen at a time; a second call replaces the first. Nothing is saved until they save it."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "create or update.")
        var operation: String
        @Guide(description: "Exact goalID from lookupSMARTGoals for update; nil for create.")
        var goalID: String?
        @Guide(description: "One specific action per check-in, at most 500 characters. Required for create; nil to keep on update.")
        var specificText: String?
        @Guide(description: "Total target check-ins, 1 through 30. Required for create; nil to keep on update.")
        var targetCount: Int?
        @Guide(description: "marriage, parenting, health, relationships, finances, career, or choresMisc. Required for create; nil to keep on update.")
        var theme: String?
        @Guide(description: "Days from today until the deadline, 1 through 30. Required for create; nil for update unless the deadline changes.")
        var daysFromToday: Int?
        @Guide(description: "Their reason, in their words. Optional.")
        var personalReason: String?
        @Guide(description: "The moment it happens, such as after dinner. Optional.")
        var cue: String?
        @Guide(description: "What they said might get in the way. Optional; never invented.")
        var expectedBarriers: String?
        @Guide(description: "A smaller version for hard days. Optional.")
        var fallbackAction: String?
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("proposeSMARTGoal")
        return await context.propose(
            operation: arguments.operation,
            goalID: arguments.goalID,
            specificText: arguments.specificText,
            targetCount: arguments.targetCount,
            theme: arguments.theme,
            daysFromToday: arguments.daysFromToday,
            personalReason: arguments.personalReason,
            cue: arguments.cue,
            expectedBarriers: arguments.expectedBarriers,
            fallbackAction: arguments.fallbackAction
        )
    }
}

struct CoachLogCheckInTool: Tool {
    let name = "logGoalCheckIn"
    let description = "Offer to record a check-in on a saved SMART goal, only when the person clearly said they completed that action today or yesterday. Call lookupSMARTGoals first; that list is what is saved. Never say the check-in is already logged."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "Exact goalID from lookupSMARTGoals.")
        var goalID: String
        @Guide(description: "today or yesterday.")
        var when: String
        @Guide(description: "A short note in their words. Empty if none.")
        var note: String
    }

    func call(arguments: Arguments) async throws -> String {
        await context.log("logGoalCheckIn")
        return await context.logCheckIn(goalID: arguments.goalID, when: arguments.when, note: arguments.note)
    }
}
#endif
