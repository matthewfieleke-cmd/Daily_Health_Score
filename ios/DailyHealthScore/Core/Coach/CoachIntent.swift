import Foundation

/// A label for the eval screen. It does not steer a reply.
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

    /// Every chat turn prefers Private Cloud Compute. On-device is only the
    /// fallback when the server model is unavailable or the request fails.
    var prefersServerModel: Bool { true }
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
        "can't do this", "cant do this", "lonely", "depressed", "miserable",
        "overeat", "overeating", "binge", "emotional eat",
        "disagreement", "arguing", "we argued", "fight with",
        "fighting with", "we fought", "conflict with"
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
