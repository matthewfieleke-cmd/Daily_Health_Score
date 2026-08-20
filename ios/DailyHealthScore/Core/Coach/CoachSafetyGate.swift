import Foundation

/// Deterministic escalation. Acute risk never depends on model improvisation.
enum CoachSafetyGate {
    enum Disposition: Equatable {
        case ordinary
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

        return .ordinary
    }
}
