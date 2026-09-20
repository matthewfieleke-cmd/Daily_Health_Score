import Foundation

/// Deterministic escalation. Acute risk never depends on model improvisation,
/// and a disclosure that deserves care is recognized even when the model
/// declines to answer it.
enum CoachSafetyGate {
    /// Something to handle with care, short of an emergency.
    enum Concern: String, Equatable, Sendable {
        /// Bingeing, restricting, or eating driven by emotion, without purging signals.
        case eating
        /// Heavy or escalating alcohol or drug use, without withdrawal signals.
        case substance
        /// Hopelessness, worthlessness, numbness, without self-harm signals.
        case mood
        /// Overwhelm, burnout, not coping.
        case strain
    }

    enum Disposition: Equatable {
        case ordinary
        case concern(Concern)
        case escalate(message: String)
    }

    /// First line of every escalation. The model is instructed to use this
    /// exact sentence if a crisis slips past the gate.
    static let immediateHelpSentence =
        "Please seek immediate medical attention or professional help."

    private static let emergencyPhrases = [
        "chest pain", "chest pressure", "crushing chest", "heart attack",
        "can't breathe", "cant breathe", "trouble breathing", "shortness of breath at rest",
        "stroke", "face drooping", "slurred speech", "numb on one side", "weakness on one side",
        "passed out", "fainted", "coughing blood", "vomiting blood", "severe bleeding",
        "seizure", "worst headache"
    ]

    private static let selfHarmPhrases = [
        "kill myself", "suicidal", "suicide", "end my life", "want to die",
        "hurt myself", "self harm", "self-harm", "not want to be alive", "no reason to live",
        "better off dead", "ending it all", "don't want to be here anymore", "dont want to be here anymore"
    ]

    private static let harmToOthersPhrases = [
        "kill them", "kill him", "kill her", "kill someone", "kill somebody",
        "hurt someone", "hurt somebody", "hurt them", "hurt other people",
        "homicidal", "want to kill him", "want to kill her", "want to kill them",
        "going to hurt him", "going to hurt her", "going to hurt someone",
        "harm others", "shoot someone", "stab someone"
    ]

    private static let eatingDisorderPhrases = [
        "purge", "purging", "make myself throw up", "throwing up after eating",
        "starve myself", "starving myself", "laxative", "binge and purge", "anorexia", "bulimia"
    ]

    private static let withdrawalPhrases = [
        "alcohol withdrawal", "shaking without alcohol", "detoxing", "withdrawal symptoms",
        "dts", "delirium tremens"
    ]

    static func evaluate(_ message: String) -> Disposition {
        let text = message.lowercased()

        if selfHarmPhrases.contains(where: text.contains) {
            return .escalate(message: """
            \(immediateHelpSentence)

            If you're in the US, call or text 988 to reach the Suicide & Crisis Lifeline any time. If you feel you might act on these thoughts, call your local emergency number now.
            """)
        }

        if harmToOthersPhrases.contains(where: text.contains) {
            return .escalate(message: """
            \(immediateHelpSentence)

            If you or someone else may be in danger, call your local emergency number now.
            """)
        }

        if emergencyPhrases.contains(where: text.contains) {
            return .escalate(message: """
            \(immediateHelpSentence)

            Call your local emergency number or go to an emergency department now.
            """)
        }

        if eatingDisorderPhrases.contains(where: text.contains) {
            return .escalate(message: """
            \(immediateHelpSentence)

            In the US, the National Alliance for Eating Disorders helpline is 1-866-662-1235.
            """)
        }

        if withdrawalPhrases.contains(where: text.contains) {
            return .escalate(message: """
            \(immediateHelpSentence)

            Withdrawal can be dangerous. In the US, SAMHSA's helpline at 1-800-662-4357 is free, confidential, and available 24/7.
            """)
        }

        if let concern = concern(in: text) {
            return .concern(concern)
        }
        return .ordinary
    }

    // MARK: - Concern

    /// "binge" itself is handled separately so a TV binge does not count.
    private static let eatingConcernPhrases = [
        "gorge", "gorging", "overeat when", "overeating when", "eat when i'm stressed",
        "eat when im stressed", "stress eat", "stress-eat", "emotional eating", "can't stop eating",
        "cant stop eating", "hate my body", "skip meals to", "skipping meals to", "restricting food",
        "punish myself with food", "eat my feelings"
    ]

    private static let substanceConcernPhrases = [
        "drinking too much", "drink too much", "drinking every night", "drunk every", "blackout",
        "too much alcohol", "can't stop drinking", "cant stop drinking", "relapse", "relapsed",
        "high every day", "using again", "hungover most"
    ]

    private static let moodConcernPhrases = [
        "hopeless", "worthless", "no point in", "what's the point", "whats the point", "empty inside",
        "numb all the time", "can't get out of bed", "cant get out of bed", "crying every",
        "i'm depressed", "im depressed", "feeling depressed", "panic attack", "panic attacks"
    ]

    private static let strainConcernPhrases = [
        "overwhelmed", "overwhelm", "burned out", "burnt out", "burnout", "can't cope", "cant cope",
        "falling apart", "end of my rope", "drowning", "can't keep up", "cant keep up", "chronic stress"
    ]

    /// Watching a series is not a disclosure.
    private static func mentionsBingeEating(_ text: String) -> Bool {
        guard text.contains("binge") else { return false }
        let viewing = ["binge-watch", "binge watch", "bingewatch", "binge-watching", "binge watching", "binged the", "binge the show", "binge a show"]
        return !viewing.contains(where: text.contains) || text.contains("binge eat") || text.contains("binge-eat")
    }

    static func concern(in lowercasedText: String) -> Concern? {
        let text = lowercasedText
        if mentionsBingeEating(text) || eatingConcernPhrases.contains(where: text.contains) { return .eating }
        if substanceConcernPhrases.contains(where: text.contains) { return .substance }
        if moodConcernPhrases.contains(where: text.contains) { return .mood }
        if strainConcernPhrases.contains(where: text.contains) { return .strain }
        return nil
    }

    /// What the model is told when a concern is present. Care, not alarm; the
    /// professional pointer once; the coaching continues.
    static func careGuidance(for concern: Concern) -> String {
        switch concern {
        case .eating:
            return "CARE NOTE: this message describes eating driven by emotion or stress. Respond with care and without shame or a diet; name the pattern as a human response, not a flaw. Say once, plainly, that a recurring pattern like this is worth bringing to their clinician or a therapist who works with eating — then keep coaching the person in front of you."
        case .substance:
            return "CARE NOTE: this message describes heavy or escalating alcohol or drug use. Respond with care and without judgment. Say once, plainly, that this is worth a conversation with their clinician, and that in the US SAMHSA's helpline (1-800-662-4357) is free and confidential — then keep coaching."
        case .mood:
            return "CARE NOTE: this message carries hopelessness, worthlessness, or numbness. Ask directly and gently how they are doing right now. Name the 988 Suicide & Crisis Lifeline as there any time in the US, and a clinician or therapist as a reasonable next step rather than a last resort — then keep coaching, with presence over plans."
        case .strain:
            return "CARE NOTE: this message describes overwhelm or burnout. Treat it as a stress response reaching for the fastest relief, not a flaw. Care first, then the smallest real step; mention a professional only if it has persisted or is deepening."
        }
    }

    /// The reply when both models declined a message. Written by the app, not
    /// the model, so it can be honest about what happened and still take care
    /// of the person. Never a generic "try rephrasing."
    static func declinedReply(concern: Concern?) -> String {
        var parts: [String] = []
        parts.append("Thank you for telling me this — it took some honesty to write it down.")
        parts.append("I want to answer it well, and the model I write with wouldn't process this message. Your words are kept in this chat, and I'll come back to them as we go.")
        switch concern {
        case .eating:
            parts.append("One thing I can say now: eating that follows a hard moment is a stress response looking for the fastest relief, not a character flaw. When it becomes a pattern, it's worth bringing to your clinician or a therapist who works with eating — not because something is wrong with you, because it's the kind of thing that eases faster with help.")
        case .substance:
            parts.append("One thing I can say now: leaning harder on alcohol or drugs under strain is common and it's worth a conversation with your clinician. In the US, SAMHSA's helpline at 1-800-662-4357 is free, confidential, and open around the clock.")
        case .mood:
            parts.append("One thing I can say now: what you're describing deserves more than a coach. In the US, 988 reaches the Suicide & Crisis Lifeline any time, and a clinician or therapist is a reasonable next step, not a last resort. How are you doing right this minute?")
        case .strain:
            parts.append("One thing I can say now: feeling overwhelmed and reaching for whatever relieves it fastest is a stress response, not a weakness. The way out is usually smaller than it looks — one real, physical thing done.")
        case nil:
            break
        }
        if concern != .mood {
            parts.append("How are you doing right now? Or tell me one part of what you wrote and we'll start there.")
        }
        return parts.joined(separator: "\n\n")
    }
}
