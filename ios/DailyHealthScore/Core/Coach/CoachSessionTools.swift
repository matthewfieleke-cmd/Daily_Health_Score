import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(Vision)
import Vision
#endif

/// What each tool returns. A description names the result. Whether this
/// message needs the tool is the model's judgment.
enum CoachToolCopy {
    static let lookupTodayHealth = "Today's Daily Health Score: sleep, fiber, exercise, this week's averages, and sleep HRV when nights have been recorded."
    static let lookupDays = "Sleep, fiber, exercise, the score, and sleep HRV for a past day or a stretch of days, with the averages across the window and the days that have no record. Give dates as yyyy-MM-dd, or count back from today with startDaysAgo and endDaysAgo."
    static let lookupSMARTGoals = "Saved SMART goals with exact goalIDs, progress, pace, deadlines, and cues, including a draft saved earlier in the chat. A goal this chat was opened on is marked SELECTED."
    static let lookupWhatWeRemember = "Dated notes about this person that match a topic, and summaries of other chats that match it. The topic chooses which notes come back."
    static let lookupWeightTrend = "Weight trend, BMI, age, and sex shared from Apple Health, and a kilograms figure for formulas. Age is included only when Health shared it."
    static let lookupFood = "Nutrition facts for a food or branded product from USDA FoodData Central and Open Food Facts: calories, protein, fiber, sugars, added sugars, fat, and minerals per serving when listed. The result says exact, candidates, or none. A number stated for a food should be one of these results. Candidate items are not an exact total. A food that is only being recommended does not need a lookup."
    static let searchEvidence = "PubMed records with title, journal, year, PMID, and abstract kept together. Call when the person asks for evidence or a citation, or when a current, unfamiliar, or precise claim needs verification. Ordinary explanations should use your own expertise. A keyword match is evidence only when the study actually answers the question; cite only what comes back."
    static let calculate = "Exact arithmetic and weight conversion. Use for any total, difference, percentage, unit conversion, or per-kilogram figure instead of computing in prose, e.g. '250 + 230 + 100', '20 / 50 * 100', or '268.7 lb to kg'. A g/kg formula must use kilograms, never pounds."
    static let rememberAboutPerson = "Stores one sentence this person said, under 240 characters, in one file: aboutYou, people, patterns, coaching, goals, likes, routines, body, or recent. Their framing, third person. stated means they said it; inferred means it is a read of what they said. Only what they said, not a metric, the score, or advice. An update or removal names the existing note."
    static let proposeSMARTGoal = "Hands the person a SMART goal draft to review — a new goal, or an update to a saved one by exact goalID — once the action is clear. Details the person did not supply may be useful suggestions, but identify them as suggestions in your reply and invite changes. Only one draft can be on screen at a time; a second call replaces the first. Nothing is saved until they save it."
    static let logGoalCheckIn = "Asks them to confirm a check-in on a saved SMART goal for today or yesterday, after they said they completed that action. The goalID is the one on the saved goals. It is not logged until they confirm."
    static let readTextInPhoto = "Read the text in an attached photo, such as a nutrition label, menu, or note. Use when exact words or numbers in the photo matter."
    static let readBarcodeInPhoto = "Read a barcode or QR code in an attached photo. Use when a package code would identify the product."
}

/// What the Coach can reach for during a reply, and what it can ask the app to
/// do. Facts are read live from the context so a long-lived session never sees
/// stale numbers; actions land in the context for the app to validate and show.
enum CoachSessionTools {
    #if canImport(FoundationModels)
    static func make(context: CoachLiveContext) -> [any Tool] {
        var tools: [any Tool] = [
            CoachLookupTodayTool(context: context),
            CoachLookupDaysTool(context: context),
            CoachLookupGoalsTool(context: context),
            CoachLookupPersonTool(context: context),
            CoachBodyTrendTool(context: context),
            CoachFoodLookupTool(context: context),
            CoachEvidenceSearchTool(context: context),
            CoachCalculatorTool(context: context),
            CoachRememberTool(context: context),
            CoachProposeGoalTool(context: context),
            CoachLogCheckInTool(context: context)
        ]
        // Exact digits and barcodes are what the model is weak at reading.
        // The tools are on every server session so a photo later in the chat
        // can use them without rebuilding the session.
        #if canImport(Vision)
        tools.append(OCRTool(
            name: "readTextInPhoto",
            description: CoachToolCopy.readTextInPhoto
        ))
        tools.append(BarcodeReaderTool(
            name: "readBarcodeInPhoto",
            description: CoachToolCopy.readBarcodeInPhoto
        ))
        #endif
        return tools
    }
    #endif

    /// The inventory, for tests and the eval screen.
    static let toolNames = "lookupTodayHealth, lookupDays, lookupSMARTGoals, lookupWhatWeRemember, lookupWeightTrend, lookupFood, searchEvidence, calculate, rememberAboutPerson, proposeSMARTGoal, logGoalCheckIn, readTextInPhoto, readBarcodeInPhoto"
}

#if canImport(FoundationModels)
struct CoachLookupTodayTool: Tool {
    let name = "lookupTodayHealth"
    let description = CoachToolCopy.lookupTodayHealth
    let context: CoachLiveContext

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let payload = await context.todayPayload
        await context.log(
            "lookupTodayHealth",
            outcome: payload.hasPrefix("No live") ? "unavailable" : "success"
        )
        return payload
    }
}

struct CoachLookupDaysTool: Tool {
    let name = "lookupDays"
    let description = CoachToolCopy.lookupDays
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
        let payload = await context.daysPayload(
            startDate: arguments.startDate,
            endDate: arguments.endDate,
            startDaysAgo: arguments.startDaysAgo,
            endDaysAgo: arguments.endDaysAgo
        )
        let dates = [arguments.startDate, arguments.endDate].compactMap { $0 }
        let offsets = [arguments.startDaysAgo, arguments.endDaysAgo].compactMap { $0 }
        let detail: String?
        if !dates.isEmpty {
            detail = dates.joined(separator: " through ")
        } else if !offsets.isEmpty {
            detail = offsets.map(String.init).joined(separator: " through ") + " days ago"
        } else {
            detail = nil
        }
        let outcome: String
        if payload.hasPrefix("No window") {
            outcome = "invalid window"
        } else if payload.contains("no record saved") || payload.contains("No days in this window") {
            outcome = "no record"
        } else {
            outcome = "success"
        }
        await context.log("lookupDays", detail: detail, outcome: outcome)
        return payload
    }
}

struct CoachLookupGoalsTool: Tool {
    let name = "lookupSMARTGoals"
    let description = CoachToolCopy.lookupSMARTGoals
    let context: CoachLiveContext

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let payload = await context.goalsPayload
        await context.log(
            "lookupSMARTGoals",
            outcome: payload == "No SMART goals saved." ? "none saved" : "success"
        )
        return payload
    }
}

struct CoachLookupPersonTool: Tool {
    let name = "lookupWhatWeRemember"
    let description = CoachToolCopy.lookupWhatWeRemember
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "What about this person you need to recall.")
        var topic: String
    }

    func call(arguments: Arguments) async throws -> String {
        let payload = await context.personPayload(topic: arguments.topic)
        await context.log(
            "lookupWhatWeRemember",
            detail: arguments.topic,
            outcome: payload.hasPrefix("No saved notes match this topic.")
                && !payload.contains("\n- ")
                ? "no match"
                : "success"
        )
        return payload
    }
}

struct CoachBodyTrendTool: Tool {
    let name = "lookupWeightTrend"
    let description = CoachToolCopy.lookupWeightTrend
    let context: CoachLiveContext

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let payload = await context.bodyPayload
        await context.log(
            "lookupWeightTrend",
            outcome: payload.hasPrefix("No weight") ? "unavailable" : "success"
        )
        return payload
    }
}

// MARK: - Actions

struct CoachRememberTool: Tool {
    let name = "rememberAboutPerson"
    let description = CoachToolCopy.rememberAboutPerson
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
        let result = await context.remember(
            operation: arguments.operation,
            section: arguments.section,
            text: arguments.text,
            replaces: arguments.replaces,
            basis: arguments.basis
        )
        await context.log(
            "rememberAboutPerson",
            outcome: result == "On file." ? "accepted" : "rejected"
        )
        return result
    }
}

struct CoachProposeGoalTool: Tool {
    let name = "proposeSMARTGoal"
    let description = CoachToolCopy.proposeSMARTGoal
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
        let result = await context.propose(
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
        let outcome = result.hasPrefix("Not drafted")
            ? "rejected"
            : (result.hasPrefix("Replaced") ? "replaced" : "ready")
        await context.log("proposeSMARTGoal", outcome: outcome)
        return result
    }
}

struct CoachLogCheckInTool: Tool {
    let name = "logGoalCheckIn"
    let description = CoachToolCopy.logGoalCheckIn
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
        let result = await context.logCheckIn(
            goalID: arguments.goalID,
            when: arguments.when,
            note: arguments.note
        )
        await context.log(
            "logGoalCheckIn",
            outcome: result.hasPrefix("Not offered") ? "rejected" : "ready"
        )
        return result
    }
}
#endif
