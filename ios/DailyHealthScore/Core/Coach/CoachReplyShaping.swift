import Foundation

/// What kind of answer a message is asking for. A hint for the model, not a
/// contract: the charter describes each shape once and the reply names which
/// one probably applies.
enum CoachReplyShape: String, Equatable, Sendable {
    case feeling
    case howTo
    case evaluation
    case data
    case winReport
    case statement
    case writing
    case smallTalk
    case general

    static func detect(message: String, intent: CoachIntent) -> CoachReplyShape {
        let text = " " + message.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'?")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ") + " "
        let asksQuestion = message.contains("?")
        func has(_ cues: [String]) -> Bool { cues.contains { text.contains($0) } }

        if intent == .smallTalk { return .smallTalk }

        // Writing help comes before how-to: "help me word a note" is not a plan.
        let writingCues = [" word a ", " draft a ", " write a ", " write an ", " help me write ", " help me word ", " help me say ", " how do i say ", " how should i say ", " what should i say ", " what do i say ", " a note to ", " a message to ", " an email to ", " a text to ", " reword "]
        if has(writingCues) { return .writing }

        let evaluationCues = [" is this ", " is that ", " is the ", " is my ", " was this ", " was that ", " are these ", " healthy?", " good?", " okay?", " ok?", " bad?", " enough?", " reasonable?", " a good "]
        if asksQuestion, has(evaluationCues),
           text.contains("healthy") || text.contains("good") || text.contains("okay") || text.contains(" ok") || text.contains("bad") || text.contains("enough") || text.contains("reasonable") {
            return .evaluation
        }

        let howToCues = [" how do i ", " how can i ", " how should i ", " help me ", " what should i do ", " what can i do ", " how do we ", " increase the likelihood ", " make it easier ", " any tips ", " how might i ", " how to "]
        if has(howToCues) { return .howTo }

        // A named feeling is a feeling even when the classifier called it something else.
        let feelingCues = [" i feel ", " i'm feeling ", " i am feeling ", " feeling ", " i felt ", " insecure ", " anxious ", " anxiety ", " stressed ", " overwhelmed ", " discouraged ", " frustrated ", " lonely ", " i'm sad ", " worried ", " tension ", " depressed ", " burned out ", " burnt out ", " exhausted ", " ashamed ", " guilty "]
        if intent == .support || has(feelingCues) { return .feeling }

        // A data answer needs a question or a request, not a mention of the week.
        let dataCues = [" how did ", " how was ", " how many ", " how much did ", " how much have ", " what was my ", " what's my ", " what is my ", " what did my ", " show me ", " tell me my ", " my average ", " my score ", " did i hit ", " did i get "]
        if intent == .dataLookup || has(dataCues), asksQuestion || has([" show me ", " tell me my "]) {
            return .data
        }

        if !asksQuestion {
            let winCues = [" doing better ", " did better ", " i managed ", " finally ", " i've been able ", " i have been able ", " went well ", " i did it ", " proud ", " a win ", " succeeded ", " kept my ", " stuck to ", " i made it ", " i've been doing ", " i have been doing "]
            if has(winCues) { return .winReport }
            return .statement
        }
        return intent == .planning ? .howTo : .general
    }

    /// Word range the reply should land in. A range, not a count: "one sentence
    /// of expertise" was read as a ceiling and produced forty-word replies.
    var wordRange: ClosedRange<Int> {
        switch self {
        case .feeling: return 120...220
        case .howTo: return 150...300
        case .evaluation: return 120...250
        case .data: return 30...90
        case .winReport: return 90...170
        case .statement: return 100...200
        case .writing: return 60...200
        case .smallTalk: return 10...40
        case .general: return 100...220
        }
    }

    /// Whether the profile and memory files belong in this prompt at all. Where
    /// they cannot be relevant, leaving them out is the only reliable way to keep
    /// them out of the reply; the lookup tool still answers a direct reference.
    var usesMemoryFiles: Bool {
        switch self {
        case .data, .smallTalk, .writing: return false
        case .feeling, .howTo, .evaluation, .winReport, .statement, .general: return true
        }
    }

    /// One line for the prompt: the move, described, never scripted.
    var hint: String {
        let range = "About \(wordRange.lowerBound) to \(wordRange.upperBound) words."
        switch self {
        case .feeling:
            return "Likely shape: a feeling or a disclosure. Meet it as a wise friend would: a genuine reaction first, the strain or the loop they described named in your own words, one honest insight that reframes it as a human response rather than a flaw, the strengths and tools they have already told you about, then a small concrete move or simply presence, and a caring question about how they are right now. No numbered levers. Advice only if they ask. \(range)"
        case .howTo:
            return "Likely shape: how-do-I. The need the behavior serves, the real levers ordered by effort (a short list is fine), the smallest first step, an offer to track it. Anchor cues to when the behavior actually happens for them. \(range)"
        case .evaluation:
            return "Likely shape: evaluation. Verdict first, what is working with numbers, the honest caveat, one upgrade that fits what they already eat. \(range)"
        case .data:
            return "Likely shape: a data question. Open with the numbers, not a reaction: the exact figures from the snapshot or tools in plain sentences, then stop. Only the metrics they asked about; no HRV unless they asked. No memory callback, no question. \(range)"
        case .winReport:
            return "Likely shape: a win report. A genuine reaction in your own words, the win named specifically and connected to what it makes possible, real expertise made vivid and specific, and one concrete question about how it is going. No plan. \(range)"
        case .statement:
            return "Likely shape: a statement with no question. React in your own words rather than restating it; add what it implies and what you would try or watch for; no plan unless invited. \(range)"
        case .writing:
            return "Likely shape: writing help. Gather what matters first — who, what they meant to people, timing, tone — in one short set of questions unless the message already holds it; then draft in their voice. No levers, no health steer, none of your notes about them in someone else's message. \(range)"
        case .smallTalk:
            return "Likely shape: small talk. One or two warm sentences. No question, no memory callback. \(range)"
        case .general:
            return "Likely shape: a general question. Answer it directly with real substance; structure only if they asked how. \(range)"
        }
    }

    /// How hard the server model should think before answering.
    var reasoningDepth: CoachReasoningDepth {
        switch self {
        case .howTo, .evaluation: return .deep
        case .feeling, .winReport, .statement, .writing, .general: return .moderate
        case .data, .smallTalk: return .light
        }
    }
}

/// Mirrors the framework's reasoning levels without importing it, so policy
/// stays testable on any platform.
enum CoachReasoningDepth: String, Equatable, Sendable {
    case light
    case moderate
    case deep
}

/// Deterministic guards around a reply.
enum CoachRepetitionGuard {
    private static let suggestionCues = [
        "you could", "you might", "try ", "swap", "consider", "what if you",
        "one option", "instead", "you can ", "start with", "keep the", "add "
    ]

    /// Sentences from earlier Coach turns that read as suggestions, so the
    /// model is shown what it already said instead of being asked to remember.
    static func alreadySuggested(in coachTexts: [String], limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for text in coachTexts.reversed() {
            let plain = CoachMarkdown.plainText(text)
            for sentence in sentences(in: plain) {
                let lower = sentence.lowercased()
                guard suggestionCues.contains(where: { lower.contains($0) }) else { continue }
                let key = CoachMemoryFingerprint.normalize(sentence)
                guard key.count >= 20, seen.insert(key).inserted else { continue }
                result.append(String(sentence.prefix(160)))
                if result.count >= limit { return result }
            }
        }
        return result
    }

    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == "." || character == "!" || character == "?" || character == "\n" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    /// Prompt block, or nil when the chat has no suggestions yet.
    static func promptBlock(in coachTexts: [String]) -> String? {
        let lines = alreadySuggested(in: coachTexts)
        guard !lines.isEmpty else { return nil }
        return "ALREADY SUGGESTED IN THIS CHAT (do not repeat these, even reworded):\n"
            + lines.map { "- \($0)" }.joined(separator: "\n")
    }
}

/// Last-mile cleanup of a reply that the prompt could not fully guarantee.
enum CoachReplyPolish {
    private static let statusTokens = [
        "GOAL EXCEEDED", "BELOW GOAL", "GOAL MET", "NO DATA"
    ]

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Strips status tokens the model was told never to print and caps runaway
    /// length at a sentence boundary well past the charter ceiling.
    static func polish(_ text: String, maxWords: Int = CoachCharter.maxReplyWords) -> String {
        var cleaned = text
        for token in statusTokens {
            cleaned = cleaned.replacingOccurrences(of: " — \(token)", with: "")
            cleaned = cleaned.replacingOccurrences(of: "— \(token)", with: "")
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let hardCap = maxWords + maxWords / 3
        guard wordCount(cleaned) > hardCap else { return cleaned }
        // Cut at paragraph boundaries so lists and breaks survive; only a single
        // oversized paragraph is cut at a sentence.
        var kept: [String] = []
        var count = 0
        for paragraph in cleaned.components(separatedBy: "\n\n") {
            let words = wordCount(paragraph)
            if count + words > maxWords {
                if kept.isEmpty {
                    var sentences: [String] = []
                    for sentence in CoachRepetitionGuard.sentences(in: paragraph) {
                        let sentenceWords = wordCount(sentence)
                        if count + sentenceWords > maxWords, !sentences.isEmpty { break }
                        sentences.append(sentence)
                        count += sentenceWords
                    }
                    kept.append(sentences.joined(separator: " "))
                }
                break
            }
            kept.append(paragraph)
            count += words
        }
        return kept.joined(separator: "\n\n")
    }
}
