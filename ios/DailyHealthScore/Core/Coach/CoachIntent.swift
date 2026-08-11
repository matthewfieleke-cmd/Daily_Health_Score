import Foundation

/// What the user is actually asking for. Routing happens in Swift so each
/// intent gets its own response contract instead of one generic prompt.
enum CoachIntent: String, Equatable, Sendable {
    /// "What is my fiber goal?", "How did I do today?"
    case dataLookup
    /// "What is the healthiest vegetable?", "How much sleep should I get?"
    case education
    /// "Help me get started", "What should I do tomorrow?"
    case planning
    /// "I keep failing", "I'm exhausted and discouraged"
    case support
    /// Anything else conversational.
    case general

    /// Response shape appended to the chat prompt.
    var contract: String {
        switch self {
        case .dataLookup:
            return """
            RESPONSE CONTRACT (data question):
            1. First sentence answers the question with the exact numbers from the snapshot,
               including the goal value when the question involves a goal.
            2. State the correct comparison exactly as the status line says (below / met / exceeded).
            3. At most one short follow-on sentence. No coaching lecture. No new plan unless asked.
            """
        case .education:
            return """
            RESPONSE CONTRACT (education question):
            1. Answer the question directly and substantively first, in 2–4 sentences, using the
               reference material provided. Give real content, not a deflection.
            2. Do NOT recite the user's daily metrics in an education answer.
            3. Optionally close with ONE short sentence connecting it to them, only if genuinely useful.
            """
        case .planning:
            return """
            RESPONSE CONTRACT (planning request):
            1. Briefly acknowledge where they are, using correct goal status if relevant.
            2. Offer two or three concrete options, then let them choose. Never issue commands.
            3. Phrase any implementation intention as THEIR plan and in second person, e.g.
               "You could try: after dinner, walk 10 minutes." Never write "I will ..." as yourself.
            4. Keep the plan smaller than feels necessary.
            """
        case .support:
            return """
            RESPONSE CONTRACT (emotional support):
            1. Validate the feeling first, specifically and without rushing to fix it.
            2. Normalize ambivalence or setback; a lapse is information, never a character verdict.
            3. Offer one small optional restart, or simply ask what would help. Advice is optional here.
            4. No metrics dump. No cheerleading clichés.
            """
        case .general:
            return """
            RESPONSE CONTRACT (general):
            1. Respond directly to what was actually said before adding anything else.
            2. Bring in data only when it is relevant to their message.
            3. End with at most one question or one optional next step.
            """
        }
    }

    var knowledgeTopics: [CoachKnowledgeTopic] {
        switch self {
        case .dataLookup: return [.appScoring]
        case .education: return []
        case .planning: return [.behaviorChange, .habits]
        case .support: return [.lapses, .motivationalInterviewing, .dbtSkills]
        case .general: return []
        }
    }
}

/// Deterministic keyword routing. A phrase ending in a space requires a word
/// boundary on the right ("did i " must not match "did in"); a phrase without
/// one also matches suffixed forms ("recommend" matches "recommended").
enum CoachIntentClassifier {
    private static let dataPhrases = [
        "my goal", "my score", "my fiber", "my sleep", "my exercise",
        "my average", "my week", "my data", "my number", "my streak",
        "how did i do", "how am i doing", "what did i ", "how much did i ",
        "did i ", "have i ", "am i above", "am i below", "am i at ",
        "today's score", "todays score", "is my ", "was my "
    ]

    private static let educationPhrases = [
        "what is the", "what's the", "whats the", "healthiest", "best ",
        "should i get", "how much sleep should", "how much fiber should",
        "how many gram", "why does", "why is", "what are", "is it true",
        "explain", "difference between", "recommend", "benefit of", "benefits of",
        "good source", "what counts as", "is it better", "how does"
    ]

    private static let planningPhrases = [
        "help me", "how do i start", "what should i do", "plan", "routine",
        "get started", "tomorrow", "this week", "make it easier", "any idea",
        "suggestion", "where do i begin", "how can i", "how do i "
    ]

    private static let supportPhrases = [
        "discouraged", "frustrated", "failing", "failed", "give up", "gave up",
        "hopeless", "exhausted", "burned out", "burnt out", "overwhelmed",
        "stressed", "anxious", "sad ", "guilty", "ashamed", "hate myself",
        "can't keep up", "cant keep up", "struggling", "off track", "slipped",
        "no motivation", "unmotivated", "pointless", "why bother"
    ]

    static func classify(_ message: String) -> CoachIntent {
        let text = normalize(message)

        if matches(text, supportPhrases) { return .support }
        if matches(text, dataPhrases) { return .dataLookup }
        if matches(text, planningPhrases) { return .planning }
        if matches(text, educationPhrases) { return .education }
        return .general
    }

    private static func matches(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains(" " + $0) }
    }

    /// Lowercases, collapses punctuation to spaces, and pads the ends so phrase
    /// matching can rely on a leading word boundary.
    private static func normalize(_ message: String) -> String {
        var result = " "
        for character in message.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
            } else if character == "'" || character == "\u{2019}" {
                result.append("'")
            } else {
                result.append(" ")
            }
        }
        return result + " "
    }
}
