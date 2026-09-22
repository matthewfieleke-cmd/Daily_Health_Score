import Foundation

/// What kind of message this looks like. A label for the eval screen and the
/// tests; nothing about the reply is steered by it.
enum CoachReplyShape: String, Equatable, Sendable {
    case feeling
    case howTo
    case evaluation
    case data
    case winReport
    case statement
    /// A refusal of a suggestion or a whole category of advice.
    case pushback
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
            let pushbackCues = [" i don't want to ", " i dont want to ", " i hate ", " i'm not going to ", " im not going to ", " i won't ", " i wont ", " i refuse ", " not doing that ", " that won't work ", " that wont work ", " doesn't work for me ", " doesnt work for me ", " stop suggesting ", " no thanks "]
            if has(pushbackCues) { return .pushback }
            let winCues = [" doing better ", " did better ", " i managed ", " finally ", " i've been able ", " i have been able ", " went well ", " i did it ", " proud ", " a win ", " succeeded ", " kept my ", " stuck to ", " i made it ", " i've been doing ", " i have been doing "]
            if has(winCues) { return .winReport }
            return .statement
        }
        return intent == .planning ? .howTo : .general
    }

}

/// Mirrors the framework's reasoning levels without importing it, so policy
/// stays testable on any platform.
enum CoachReasoningDepth: String, CaseIterable, Equatable, Sendable {
    case light
    case moderate
    case deep
}

enum CoachReplyPolish {
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
    private static let statusTokens = [
        "GOAL EXCEEDED", "BELOW GOAL", "GOAL MET", "NO DATA"
    ]

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Field names from the structured reply. When the model starts writing the
    /// next field inside the message string, everything from that name on is
    /// noise to the person reading it.
    private static let leakedFieldPattern = try? NSRegularExpression(
        pattern: #"(^|\n)\s*(memoryUpdates|goalCheckIn|goalProposal|message|threadTitle|threadSummary|pillar)\s*:.*$"#,
        options: [.dotMatchesLineSeparators]
    )

    /// Drops a leaked structured-output fragment and any dangling brackets left
    /// where it started.
    static func stripLeakedFields(_ text: String) -> String {
        var cleaned = text
        // A label at the very start is just a label; drop it and keep the words.
        for label in ["message:", "Message:"] where cleaned.hasPrefix(label) {
            cleaned = String(cleaned.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let pattern = leakedFieldPattern {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            if let match = pattern.firstMatch(in: cleaned, range: range),
               match.range.location > 0,
               let cut = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[..<cut.lowerBound])
            }
        }
        while let last = cleaned.last, "[{(:,".contains(last) || last.isWhitespace || last.isNewline {
            cleaned.removeLast()
        }
        return cleaned
    }

    /// Strips status tokens the model was told never to print, removes leaked
    /// output fields, and caps runaway length at a sentence boundary well past
    /// the charter ceiling.
    static func polish(_ text: String, maxWords: Int = CoachCharter.maxReplyWords) -> String {
        var cleaned = stripLeakedFields(text)
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
                    for sentence in Self.sentences(in: paragraph) {
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
