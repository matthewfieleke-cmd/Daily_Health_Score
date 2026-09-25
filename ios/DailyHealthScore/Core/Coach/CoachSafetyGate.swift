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
        "starve myself", "starving myself", "binge and purge", "anorexia", "bulimia",
        "laxative to lose", "laxatives to lose", "laxative for weight", "laxatives for weight",
        "laxative after eating", "laxatives after eating", "laxative abuse", "abusing laxatives"
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

    /// The reply when both models declined a message. Written by the app, not
    /// the model, so it can be honest about what happened and still take care
    /// of the person. Never a generic "try rephrasing."
    static func declinedReply(concern: Concern?) -> String {
        guard let concern else {
            // No disclosure here; a model simply would not take the message.
            return "I couldn't get an answer to that one — the model I write with declined the message, which sometimes happens for no good reason. It's kept in this chat. Try sending it again in a moment, or go on to the next thing and I'll pick this up."
        }
        var parts: [String] = []
        parts.append("Thank you for telling me this — it took some honesty to write it down.")
        parts.append("I want to answer it well, and the model I write with wouldn't process this message. Your words are kept in this chat, and I'll come back to them as we go.")
        switch concern {
        case .eating:
            parts.append("""
            Here is what I can say now. Eating that follows a hard moment is a stress response looking for the fastest relief, not a character flaw — the urge is real, it peaks and passes within about twenty minutes, and the food does briefly work, which is why the loop holds. What the people who study this find helps most: eat regular meals so hunger isn't stacked on top of the stress; when the urge hits, put ten minutes between the feeling and the food — name the feeling, step outside, text someone — and then decide; keep the foods you reach for out of arm's reach rather than out of the house; and track what happens without judgment, because seeing the pattern is what loosens it. Skills-based approaches for emotional eating, including the DBT-based ones, have real evidence behind them. When it becomes a pattern, bring it to your clinician or a therapist who works with eating — not because something is wrong with you, because it eases faster with help.
            """)
        case .substance:
            parts.append("""
            Here is what I can say now. Leaning harder on alcohol or drugs under strain is common, and it usually says more about the strain than about you. What tends to help: count what you actually use for a week before changing anything; build in drink-free days rather than smaller drinks; never use alcohol to fall asleep — it fragments the second half of the night and leaves the next day harder; and tell one person. This is worth a conversation with your clinician. In the US, SAMHSA's helpline at 1-800-662-4357 is free, confidential, and open around the clock — and if stopping brings shaking, sweating, or a racing heart, that needs medical help the same day.
            """)
        case .mood:
            parts.append("""
            Here is what I can say now. What you're describing deserves more than a coach, and it also has levers a coach can name: daylight in the first hour of the day, movement of any kind, regular sleep and meals, and contact with one person a day carry the most evidence for low mood — alongside a clinician or therapist when it lasts more than a couple of weeks, not instead of one. In the US, 988 reaches the Suicide & Crisis Lifeline any time. How are you doing right this minute?
            """)
        case .strain:
            parts.append("""
            Here is what I can say now. Overwhelm narrows the field of view to whatever relieves it fastest, so reaching for the quick thing is a stress response, not a weakness. What tends to help: one physical task finished start to end, a hard stop on the workday even when the list isn't done, sleep protected before anything else gets fixed, and saying the load out loud to one person. If it has been building for weeks, a clinician or a therapist is a reasonable next step.
            """)
        }
        if concern != .mood {
            parts.append("How are you doing right now? Or tell me one part of what you wrote and we'll start there.")
        }
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n\n")
    }
}
