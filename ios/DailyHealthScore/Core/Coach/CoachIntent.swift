import Foundation

/// What the user is actually asking for. Routing happens in Swift so each
/// intent gets its own response contract instead of one generic prompt.
enum CoachIntent: String, Equatable, Sendable {
    /// "What is my fiber goal?", "How did I do today?"
    case dataLookup
    /// "What is the healthiest vegetable?", "Walking or running?"
    case education
    /// "Help me get started", "What should I do tomorrow?"
    case planning
    /// "I keep failing", "I'm exhausted and discouraged"
    case support
    /// "What day is it?", "Good morning", "Thanks"
    case smallTalk
    /// Anything else conversational.
    case general

    /// Whether a suggestion belongs in the reply at all. Questions that did not
    /// ask for a plan should never collect one.
    var allowsNextStep: Bool {
        switch self {
        case .planning, .support, .general: return true
        case .dataLookup, .education, .smallTalk: return false
        }
    }

    /// Whether this message is worth spending the daily Private Cloud Compute
    /// allowance on. Data lookups read numbers Swift already computed and small
    /// talk needs a sentence, so both stay on-device; the rest is where a larger
    /// model's breadth and reasoning actually change the answer.
    var prefersServerModel: Bool {
        switch self {
        case .education, .planning, .support, .general: return true
        case .dataLookup, .smallTalk: return false
        }
    }

    /// Whether today's metric lines belong in the prompt. Withholding them is the
    /// only reliable way to stop the model from steering every answer back to them.
    var usesFullMetrics: Bool {
        switch self {
        case .dataLookup, .planning, .support, .general: return true
        case .education, .smallTalk: return false
        }
    }

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
            RESPONSE CONTRACT (education or recommendation question):
            1. Lead with a direct verdict in the first sentence. Take a position the evidence
               supports rather than opening with "it depends" or "while I'm not a doctor".
            2. Then give the substance behind it, using the reference material provided:
               what the evidence actually shows, the specific numbers, foods, or amounts, and
               the trade-offs. Use as much of the reference material as genuinely answers
               the question — a real question deserves a real explanation, not three sentences.
            3. If a common counter-argument or worry exists in the reference material, name it
               and say what the evidence says about it. That is often the most useful part.
            4. Close with the practical takeaway — what this means for what someone actually
               buys, cooks, or does. One or two sentences.
            5. If the question compares two things, say what each one is better for and what
               actually decides between them.
            6. Do NOT recite the user's daily metrics, and do NOT append an unrelated next step.
            7. Never pad. If the reference material is thin, a shorter honest answer is correct,
               and saying what is genuinely uncertain is part of a good answer.
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
        case .smallTalk:
            return """
            RESPONSE CONTRACT (small talk or a simple factual question):
            1. Answer plainly in one or two sentences. Nothing else is needed.
            2. No metrics, no pillar education, no suggestion, no next step.
            3. Warmth is welcome; a lecture is not.
            """
        case .general:
            return """
            RESPONSE CONTRACT (general):
            1. Respond directly to what was actually said before adding anything else.
            2. Bring in data only when it is relevant to their message.
            3. Offer a next step only if their message invites one, and never one you
               have already suggested in this conversation.
            """
        }
    }

    var knowledgeTopics: [CoachKnowledgeTopic] {
        switch self {
        // HRV rides along because a question about their own HRV needs the
        // interpretation guidance as much as the number.
        case .dataLookup: return [.appScoring, .hrv]
        case .education, .smallTalk, .general: return []
        case .planning: return [.behaviorChange, .habits]
        case .support: return [.lapses, .motivationalInterviewing, .dbtSkills]
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
        "today's score", "todays score", "is my ", "was my ",
        // Their own goals and HRV, which the snapshot now carries. Without these
        // a question like "how's my walking goal going?" falls through to
        // education, which deliberately withholds their data.
        // Kept narrow on purpose: bare "smart goal" would swallow "what is a
        // SMART goal?", and bare "on track" would swallow "how do I stay on track?".
        "my goals", "my smart", "goal going", "goals going",
        "my progress", "my check in", "my checkin", "am i on track",
        "my hrv", "my heart rate variability", "my variability", "hrv trend"
    ]

    private static let educationPhrases = [
        "what is the", "what's the", "whats the", "healthiest", "best ",
        "should i get", "should i take", "should i try", "should i be",
        "how much sleep should", "how much fiber should",
        "how many gram", "why does", "why is", "what are", "is it true",
        "explain", "difference between", "recommend", "benefit of", "benefits of",
        "good source", "what counts as", "how does", "do i need",
        "is it worth", "is it safe", "is it bad", "is it healthy",
        "bad for", "good for you", "healthy", "unhealthy", "tell me about",
        // Comparisons.
        "is better", "which is", "better than", "better for", "versus", "vs ",
        "compare", "or should i", "as good as", "same as",
        // Concrete food and training recommendations.
        "what should i have", "what should i eat", "should i eat", "what to eat",
        "for breakfast", "for lunch", "for dinner", "good snack", "healthy snack",
        "what do you", "any good", "give me some", "ideas for"
    ]

    private static let smallTalkPhrases = [
        "what day is it", "what is the date", "what's the date", "whats the date",
        "what time is it", "hello", "hey ", "hi ", "good morning", "good afternoon",
        "good evening", "thank you", "thanks", "how are you", "who are you",
        "what can you do", "your name", "nice to meet"
    ]

    // "plan" is deliberately not bare: it would swallow "plant based".
    private static let planningPhrases = [
        "help me", "how do i start", "what should i do", "a plan ", "my plan ",
        "plan for", "plan to", "planning", "routine",
        "get started", "tomorrow", "this week", "make it easier", "any idea",
        "suggestion", "where do i begin", "how can i", "how do i "
    ]

    private static let supportPhrases = [
        "discouraged", "frustrated", "failing", "failed", "failure",
        "give up", "gave up", "giving up",
        "hopeless", "exhausted", "burned out", "burnt out", "overwhelmed",
        "stressed", "anxious", "sad ", "guilty", "ashamed", "hate myself",
        "can't keep up", "cant keep up", "struggling", "off track", "slipped",
        "no motivation", "unmotivated", "pointless", "why bother",
        "not good enough", "beating myself", "disappointed", "i suck",
        "can't do this", "cant do this", "lonely", "depressed", "miserable"
    ]

    /// Question words that start a real question, used only as a fallback so a
    /// question never lands in `general` — which would let the reply attach
    /// metrics and a next step nobody asked for.
    private static let questionStarters = [
        "what ", "what's ", "whats ", "why ", "how ", "is ", "are ", "was ",
        "were ", "does ", "do ", "did ", "can ", "could ", "would ", "should ",
        "which ", "who ", "when ", "will ", "am i", "tell me", "explain"
    ]

    /// - Parameter hasHistoryReference: true when the message points at a past
    ///   day we can resolve to a record, which makes it a data question even if
    ///   it is phrased as a comparison.
    static func classify(_ message: String, hasHistoryReference: Bool = false) -> CoachIntent {
        let text = normalize(message)

        if matches(text, supportPhrases) { return .support }
        // Small talk is checked before education so "what is the date" does not
        // trip the "what is the" education prefix.
        if matches(text, smallTalkPhrases) { return .smallTalk }
        if hasHistoryReference { return .dataLookup }
        if matches(text, dataPhrases) { return .dataLookup }
        if matches(text, planningPhrases) { return .planning }
        if matches(text, educationPhrases) { return .education }
        if isQuestion(text, original: message) { return .education }
        return .general
    }

    private static func isQuestion(_ text: String, original: String) -> Bool {
        if original.contains("?") { return true }
        return questionStarters.contains { text.hasPrefix(" " + $0) }
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
