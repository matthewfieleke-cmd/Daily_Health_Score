import Foundation

/// Deterministic escalation. Acute risk never depends on model improvisation.
enum CoachSafetyGate {
    enum Disposition: Equatable {
        case ordinary
        case escalate(message: String)
    }

    private static let emergencyPhrases = [
        "chest pain", "chest pressure", "crushing chest", "heart attack",
        "can't breathe", "cant breathe", "trouble breathing", "shortness of breath at rest",
        "stroke", "face drooping", "slurred speech", "numb on one side", "weakness on one side",
        "passed out", "fainted", "coughing blood", "vomiting blood", "severe bleeding",
        "seizure", "worst headache"
    ]

    private static let selfHarmPhrases = [
        "kill myself", "suicidal", "suicide", "end my life", "want to die",
        "hurt myself", "self harm", "self-harm", "not want to be alive", "no reason to live"
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
            I'm really glad you told me, and I want to respond to this directly rather than coach around it.

            What you're describing needs support from a person, not an app. If you're in the US, you can call or text 988 to reach the Suicide & Crisis Lifeline any time. If you're outside the US, your local emergency number or a crisis line can connect you now. If you feel you might act on these thoughts, please treat this as an emergency and call your local emergency number.

            You deserve real support, and reaching out for it is a strong move — not a failure. I'll be here for the lifestyle side whenever you want to come back to it.
            """)
        }

        if emergencyPhrases.contains(where: text.contains) {
            return .escalate(message: """
            What you're describing could be a medical emergency, so I'm going to stop coaching and be direct.

            Please seek urgent medical care now — call your local emergency number or get to an emergency department. Symptoms like these need evaluation by a clinician who can examine you, not guidance from an app.

            When you're safe and cleared, I'm glad to pick back up on sleep, nutrition, and movement with you.
            """)
        }

        if eatingDisorderPhrases.contains(where: text.contains) {
            return .escalate(message: """
            Thank you for trusting me with that. This is beyond what a wellness coach should guide, and giving you food or exercise targets right now could do harm.

            Please consider reaching out to a clinician experienced with eating concerns, or in the US, the National Alliance for Eating Disorders helpline at 1-866-662-1235. Your own physician is also a good starting point.

            I'm not going anywhere, and there's no judgment here at all. When you have that support in place, I'm glad to focus on gentle, non-numeric wellbeing with you.
            """)
        }

        if withdrawalPhrases.contains(where: text.contains) {
            return .escalate(message: """
            I want to be straight with you: withdrawal can be genuinely dangerous, and it's not something to manage with lifestyle advice.

            Please contact a clinician or urgent care before making changes on your own. In the US, SAMHSA's helpline at 1-800-662-4357 is free, confidential, and available 24/7.

            Reaching out for medical support here is the strong, self-respecting move. I'll be here for the rest whenever you're ready.
            """)
        }

        return .ordinary
    }
}
