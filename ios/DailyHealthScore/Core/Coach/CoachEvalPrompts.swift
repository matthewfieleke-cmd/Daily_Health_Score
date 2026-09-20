import Foundation

/// One eval run: the prompt, what the Coach said, and how it got there.
struct CoachEvalResult: Identifiable, Equatable, Sendable {
    let id: UUID
    var promptID: String
    var reply: String
    var tier: CoachModelTier
    var shape: CoachReplyShape
    var memoryNotes: [String]
    var seconds: Double
    var error: String?
    /// Set when Private Cloud Compute failed and the on-device model answered.
    var fallbackReason: String?
    /// The SMART goal draft the reply carried, if any.
    var draft: String?

    init(
        id: UUID = UUID(),
        promptID: String,
        reply: String,
        tier: CoachModelTier,
        shape: CoachReplyShape,
        memoryNotes: [String],
        seconds: Double,
        error: String? = nil,
        fallbackReason: String? = nil,
        draft: String? = nil
    ) {
        self.id = id
        self.promptID = promptID
        self.reply = reply
        self.tier = tier
        self.shape = shape
        self.memoryNotes = memoryNotes
        self.seconds = seconds
        self.error = error
        self.fallbackReason = fallbackReason
        self.draft = draft
    }
}

/// A prompt the Coach is measured against, with what a good reply must do.
struct CoachEvalPrompt: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var text: String
    var rubric: [String]
}

/// The regression set. The first four are real conversations that exposed
/// specific failures; the rest cover shapes those four did not.
enum CoachEvalPrompts {
    static let all: [CoachEvalPrompt] = [
        CoachEvalPrompt(
            id: "breakfast-eval",
            title: "Breakfast evaluation",
            text: "There’s a breakfast I like to do that includes an Oatmeal Walnut Raisin Clif bar, That’s It bar, Seven Sundays Wildberry Protein Oats, and Green Tea. Is that a healthy breakfast?",
            rubric: [
                "Verdict in the first sentence (yes / mostly / no)",
                "Looks up or estimates each product with per-item numbers and a total",
                "Names the honest caveat (added sugar in the bars, modest protein)",
                "Ties fiber to the person's goal",
                "One upgrade that fits the meal they already eat, not a different cuisine",
                "No status tokens, no framework name-dropping"
            ]
        ),
        CoachEvalPrompt(
            id: "work-boundaries-win",
            title: "Work boundaries win",
            text: "I’ve been doing better recently with not bringing work home. I am a family medicine physician. I’m getting my notes and patient messages all taken care of while at work. Previously I was bringing home an hour or two of work. I think a big part is my mindset and deciding to stay on top of things and stay on my toes instead of on my heels. I’m also using our AI scribe which is helping.",
            rubric: [
                "Opens with a genuine reaction and names the win specifically; no paraphrase of the message",
                "Quotes the toes-not-heels framing and makes the expertise vivid (open loops, half-finished tasks following them home)",
                "Ends with one concrete question about how the evenings are actually going; offers no plan",
                "Memory notes: physician, notes finished at work, AI scribe, the toes-not-heels framing in quotes",
                "No trite praise for 'doing the work'"
            ]
        ),
        CoachEvalPrompt(
            id: "insecurity-positive-intent",
            title: "Insecurity and positive intent",
            text: "I find myself feeling insecure about work. My office manager is moving to a different clinic. A doctor I worked with in the past did a real good job of Assuming Positive Intent. So when interacting with someone, we should assume that they have a positive intent. Recently, I have found myself doing the opposite. When I am in a healthier frame of mind, I say the following to myself: “Seeing the best in people brings out the best in people.”",
            rubric: [
                "Validates the loss in one sentence",
                "Mechanism: an anchor leaving turns up threat detection; assuming the worst is armor, not a flaw",
                "Offers neutral intent as a stepping stone when positive feels out of reach",
                "One active move (connect before they go) and one question",
                "No forced callback to unrelated notes; no framework name-dropping",
                "Memory: office manager leaving (dated), the motto in quotes, the inferred withdrawal pattern marked inferred"
            ]
        ),
        CoachEvalPrompt(
            id: "stress-numbing",
            title: "Stress numbing and Clash Royale",
            text: "I’ve been playing way too much Clash Royale on my phone. I feel chronic stress and I think I’m using that to numb myself a bit. A better choice would be to clean the dishes or do yoga or go on a walk with my wife. How do I increase the likelihood I make the healthier choice?",
            rubric: [
                "Names the need the game serves (relief), then the mechanism (path of least resistance, depleted control)",
                "Up to four numbered levers ordered by effort: pre-decide, invert the friction, start tiny, read the urge",
                "Notes a chore is not restorative; bridge with a low-effort reset first",
                "Recruits the wife or existing rituals from memory when present",
                "Offers to track it as a SMART goal or through the evening check-in",
                "No time-of-day artifacts like 'after lunch'; no technique names; no confidence-rating homework"
            ]
        ),
        CoachEvalPrompt(
            id: "data-week",
            title: "Data question",
            text: "How did this week go for me?",
            rubric: [
                "Exact numbers from the snapshot, none invented",
                "Missing days called unlogged, never zero",
                "One or two plain sentences, then stops"
            ]
        ),
        CoachEvalPrompt(
            id: "goal-plan",
            title: "Goal conversation",
            text: "Help me set a goal around an evening walk with my wife.",
            rubric: [
                "Asks the one missing thing or drafts a SMART goal when the plan is clear",
                "Cue, count, and window are concrete; a smaller fallback is offered",
                "Never claims anything is saved"
            ]
        ),
        CoachEvalPrompt(
            id: "pushback",
            title: "Pushback",
            text: "I don’t want to walk. I hate walking.",
            rubric: [
                "Gets curious instead of arguing or re-selling walking",
                "Offers a genuine alternative only after asking",
                "Short"
            ]
        ),
        CoachEvalPrompt(
            id: "medical-adjacent",
            title: "Medical-adjacent question",
            text: "Should I take magnesium for sleep?",
            rubric: [
                "Yes/no/mostly in the first sentence, then the evidence (searchEvidence) in plain words",
                "Names magnesium-rich foods plainly; no numbered list of per-item macros from food lookups",
                "Says plainly what belongs with their clinician without deflecting the whole question",
                "No prescribing, no dosing as an instruction; no unrelated numbers (fiber) pulled in"
            ]
        ),
        CoachEvalPrompt(
            id: "curveball",
            title: "Curveball",
            text: "Help me word a short note to my team about our office manager leaving.",
            rubric: [
                "Asks first: her name, how long she has been there, when she leaves, the tone wanted — or drafts with clear placeholders",
                "Draft, when given, sounds like the person; no steer back to sleep, fiber, or exercise",
                "None of the coach's notes about the person worked into the team's message"
            ]
        ),
        CoachEvalPrompt(
            id: "small-talk",
            title: "Small talk",
            text: "Thanks, that helped.",
            rubric: [
                "One or two sentences, warm, done — no question, no memory callback"
            ]
        ),
        // General knowledge: the category where a coach becomes a progress report.
        CoachEvalPrompt(
            id: "general-walking",
            title: "General knowledge: walking outside",
            text: "How is going on walks outside good for me?",
            rubric: [
                "Answers as expertise for anyone: daylight and circadian rhythm, mood, blood pressure and post-meal glucose, joints and bone, the nature effect",
                "No progress report: no today's minutes, no gap to 30, no weakest pillar",
                "No unrequested callbacks to the files",
                "Specific mechanisms named in plain words; a position, not a survey"
            ]
        ),
        CoachEvalPrompt(
            id: "general-alcohol-sleep",
            title: "General knowledge: alcohol and sleep",
            text: "What does alcohol do to sleep?",
            rubric: [
                "Falls asleep faster, then fragmented second half, suppressed REM, more waking; dose and timing matter",
                "No progress report and no callbacks unless the person's own drinking is in the files and bears on the answer",
                "No moralizing; a clear position on timing and amount"
            ]
        ),
        CoachEvalPrompt(
            id: "general-protein",
            title: "General knowledge: protein needs",
            text: "How much protein do I actually need?",
            rubric: [
                "A real range per kilogram of body weight, adjusted for age and activity, with the weight trend used only because the question needs it",
                "Plant sources named plainly when the files say they eat that way",
                "No progress report on today's score; no unrequested callbacks"
            ]
        )
    ]

    static func prompt(id: String) -> CoachEvalPrompt? {
        all.first { $0.id == id }
    }

    /// Plain-text export of a run, for pasting into a review.
    static func export(results: [CoachEvalResult]) -> String {
        results.map { result in
            let prompt = self.prompt(id: result.promptID)
            var lines: [String] = []
            lines.append("## \(prompt?.title ?? result.promptID)")
            lines.append("Prompt: \(prompt?.text ?? "")")
            lines.append("Model: \(result.tier.rawValue) · shape: \(result.shape.rawValue) · \(String(format: "%.1f", result.seconds))s · \(CoachReplyPolish.wordCount(result.reply)) words")
            if let reason = result.fallbackReason, !reason.isEmpty {
                lines.append("Fell back to on-device because: \(reason)")
            }
            if let draft = result.draft {
                lines.append("Draft: \(draft)")
            }
            if let error = result.error, !error.isEmpty {
                lines.append("Error: \(error)")
            } else {
                lines.append("")
                lines.append(result.reply)
            }
            if !result.memoryNotes.isEmpty {
                lines.append("")
                lines.append("Memory:")
                lines.append(contentsOf: result.memoryNotes.map { "- \($0)" })
            }
            if let rubric = prompt?.rubric, !rubric.isEmpty {
                lines.append("")
                lines.append("Rubric:")
                lines.append(contentsOf: rubric.map { "- [ ] \($0)" })
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")
    }
}
