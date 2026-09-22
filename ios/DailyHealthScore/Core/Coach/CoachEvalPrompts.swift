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
    /// Tools the model reached for, in order.
    var toolsUsed: [String] = []
    /// Server reasoning selected for this run; on-device still uses light.
    var reasoningDepth: CoachReasoningDepth?

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
        draft: String? = nil,
        toolsUsed: [String] = [],
        reasoningDepth: CoachReasoningDepth? = nil
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
        self.toolsUsed = toolsUsed
        self.reasoningDepth = reasoningDepth
    }
}

/// A prompt the Coach is measured against, with what a good reply must do.
struct CoachEvalPrompt: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var text: String
    var rubric: [String]
    /// Follow-up messages in the same throwaway conversation.
    var followUps: [String] = []
    /// Used only to exercise the honest no-tools fallback.
    var forcedTier: CoachModelTier? = nil

    var messages: [String] { [text] + followUps }
    var requestCount: Int { messages.count }
    var displayText: String {
        guard !followUps.isEmpty else { return text }
        return messages.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }
}

/// The regression set. Rubrics measure outcomes, not one scripted route to
/// them: directness, accuracy, appropriate tools, and earned personalization.
enum CoachEvalPrompts {
    static let sharedRubric = [
        "Answers the actual request and adds value beyond restating it",
        "Claims, calculations, and citations are accurate; uncertainty is honest",
        "Uses only tools that materially improve the answer; no duplicate searches or tool narration",
        "Personalizes only when it changes the answer; no unrelated metrics or memories",
        "General health education is answered directly without an automatic referral",
        "Length and depth fit the moment; no forced format or closing question"
    ]

    static let all: [CoachEvalPrompt] = [
        CoachEvalPrompt(
            id: "breakfast-eval",
            title: "Breakfast evaluation",
            text: "There’s a breakfast I like to do that includes an Oatmeal Walnut Raisin Clif bar, That’s It bar, Seven Sundays Wildberry Protein Oats, and Green Tea. Is that a healthy breakfast?",
            rubric: [
                "Gives a clear verdict early and explains the main strength and tradeoff",
                "Every branded number comes from an exact database match; candidates stay unresolved",
                "Calls any total partial when an item is unresolved and never invents a package label",
                "Any suggested adjustment fits the meal they already eat and is offered only if useful"
            ]
        ),
        CoachEvalPrompt(
            id: "work-boundaries-win",
            title: "Work boundaries win",
            text: "I’ve been doing better recently with not bringing work home. I am a family medicine physician. I’m getting my notes and patient messages all taken care of while at work. Previously I was bringing home an hour or two of work. I think a big part is my mindset and deciding to stay on top of things and stay on my toes instead of on my heels. I’m also using our AI scribe which is helping.",
            rubric: [
                "Recognizes what materially changed and why it matters beyond work hours",
                "Adds insight rather than returning a compressed version of the message",
                "Does not force a plan or question when a genuine response is enough",
                "Any memory is grounded, preserves distinctive framing, and invents no date"
            ]
        ),
        CoachEvalPrompt(
            id: "insecurity-positive-intent",
            title: "Insecurity and positive intent",
            text: "I find myself feeling insecure about work. My office manager is moving to a different clinic. A doctor I worked with in the past did a real good job of Assuming Positive Intent. So when interacting with someone, we should assume that they have a positive intent. Recently, I have found myself doing the opposite. When I am in a healthier frame of mind, I say the following to myself: “Seeing the best in people brings out the best in people.”",
            rubric: [
                "Responds to both the insecurity and the transition underneath it",
                "Offers useful understanding or a feasible next move without imposing one predetermined mechanism",
                "Treats the motto as the person's resource without merely repeating the whole message",
                "Any memory preserves stated facts and quotations; no unsupported inferred pattern or invented date"
            ]
        ),
        CoachEvalPrompt(
            id: "stress-numbing",
            title: "Stress numbing and Clash Royale",
            text: "I’ve been playing way too much Clash Royale on my phone. I feel chronic stress and I think I’m using that to numb myself a bit. A better choice would be to clean the dishes or do yoga or go on a walk with my wife. How do I increase the likelihood I make the healthier choice?",
            rubric: [
                "Understands the relief the game provides and why the easier path wins under stress",
                "Offers a feasible way to make one preferred choice easier without a canned framework",
                "Uses the options in the current message; does not pretend they came from memory",
                "Does not force tracking, a SMART goal, a citation, or an arbitrary time of day"
            ]
        ),
        CoachEvalPrompt(
            id: "data-week",
            title: "Data question",
            text: "How did this week go for me?",
            rubric: [
                "Names the exact date window and uses authoritative day-range numbers",
                "Missing days called unlogged, never zero",
                "Concise, comparative, and free of unrelated advice"
            ]
        ),
        CoachEvalPrompt(
            id: "goal-plan",
            title: "Goal conversation",
            text: "Help me set a goal around an evening walk with my wife.",
            rubric: [
                "Either asks one useful clarification or offers a concrete reviewable draft",
                "Clearly identifies frequency, timing, or fallback details that are Coach suggestions rather than user agreements",
                "Never claims the draft is saved; invites changes without making the flow bureaucratic"
            ]
        ),
        CoachEvalPrompt(
            id: "pushback",
            title: "Pushback",
            text: "I don’t want to walk. I hate walking.",
            rubric: [
                "Accepts the preference without arguing or re-selling walking",
                "Naturally explores alternatives, with or without a question",
                "Brief because the moment is simple"
            ]
        ),
        CoachEvalPrompt(
            id: "medical-adjacent",
            title: "Medical-adjacent question",
            text: "Should I take magnesium for sleep?",
            rubric: [
                "Gives a direct, evidence-calibrated answer before caveats or citations",
                "Uses evidence search only if verification materially improves the answer; every citation is relevant and exact",
                "Offers a useful food-first option or safety caveat when relevant, not as a fixed template",
                "Sets a personal-medical boundary without turning a general answer into an automatic referral",
                "No prescribing, no dosing as an instruction; no unrelated numbers (fiber) pulled in"
            ]
        ),
        CoachEvalPrompt(
            id: "curveball",
            title: "Curveball",
            text: "Help me word a short note to my team about our office manager leaving.",
            rubric: [
                "Produces a natural ready-to-send note with placeholders, or asks only for context genuinely needed",
                "Completes the writing task rather than describing how to write it",
                "Uses known personal facts only when directly relevant and reliable; never inserts health context"
            ]
        ),
        CoachEvalPrompt(
            id: "small-talk",
            title: "Small talk",
            text: "Thanks, that helped.",
            rubric: [
                "Warm and complete without manufacturing another task, question, or memory callback"
            ]
        ),
        // General knowledge: the category where a coach becomes a progress report.
        CoachEvalPrompt(
            id: "general-walking",
            title: "General knowledge: walking outside",
            text: "How is going on walks outside good for me?",
            rubric: [
                "Explains several meaningful benefits in plain language, including at least one benefit specific to being outside",
                "Uses general expertise rather than searching merely to decorate the answer",
                "No progress report or unrequested callback to app data or memory"
            ]
        ),
        CoachEvalPrompt(
            id: "general-alcohol-sleep",
            title: "General knowledge: alcohol and sleep",
            text: "What does alcohol do to sleep?",
            rubric: [
                "Gets the core direction right: faster sleep onset can give way to poorer, more fragmented sleep later",
                "Explains that amount and timing matter; mentions sleep architecture only as accurately as useful",
                "No progress report and no callbacks unless the person's own drinking is in the files and bears on the answer",
                "No moralizing or automatic referral"
            ]
        ),
        CoachEvalPrompt(
            id: "general-protein",
            title: "General knowledge: protein needs",
            text: "How much protein do I actually need?",
            rubric: [
                "Gives a defensible range and explains the basis, including age and activity when known",
                "Converts pounds to kilograms before every g/kg calculation; dimensional math is correct",
                "No progress report on today's score; no unrequested callbacks"
            ]
        ),
        CoachEvalPrompt(
            id: "conversation-medicine-correction",
            title: "Conversation: corrected medicine name",
            text: "How does Founduayo work?",
            rubric: [
                "Clarifies the unknown term without pretending it is in app memory",
                "After correction, explains orforglipron and GLP-1 medicines as general education",
                "Does not carry a refusal template forward or repeatedly redirect to a care team"
            ],
            followUps: [
                "It is a medicine. Also called orforglipron.",
                "What are GLP-1 receptor agonists?",
                "What are some common weight-loss medications? I’m asking for general information."
            ]
        ),
        CoachEvalPrompt(
            id: "conversation-general-then-personal",
            title: "Conversation: general then personal weight help",
            text: "How can I lose weight?",
            rubric: [
                "First answers from broad weight-management expertise without a score report or dossier",
                "Personalizes only after being asked and selects a few facts that materially change the plan",
                "Does not dump goals, today's three metrics, or unrelated routines"
            ],
            followUps: [
                "Now use the information in this app to make that more specific to me."
            ]
        ),
        CoachEvalPrompt(
            id: "conversation-topic-change",
            title: "Conversation: data then topic change",
            text: "How did this week go for me?",
            rubric: [
                "Uses the day-range tool for the first answer",
                "Answers the alcohol question from general expertise without carrying the week's metrics forward",
                "Hidden tool output from the first turn does not steer the second"
            ],
            followUps: [
                "Thanks. What does alcohol do to sleep?"
            ]
        ),
        CoachEvalPrompt(
            id: "on-device-general-medicine",
            title: "On-device fallback: general medicine",
            text: "What are GLP-1 receptor agonist medications?",
            rubric: [
                "Answers from general knowledge despite having no app tools",
                "Does not say the subject is missing from tools, notes, or memory",
                "Explains without prescribing or automatically redirecting to a care team"
            ],
            forcedTier: .onDevice
        )
    ]

    static func prompt(id: String) -> CoachEvalPrompt? {
        all.first { $0.id == id }
    }

    static func rubric(for prompt: CoachEvalPrompt) -> [String] {
        sharedRubric + prompt.rubric
    }

    /// Plain-text export of a run, for pasting into a review.
    static func export(results: [CoachEvalResult]) -> String {
        results.map { result in
            let prompt = self.prompt(id: result.promptID)
            var lines: [String] = []
            lines.append("## \(prompt?.title ?? result.promptID)")
            lines.append("Prompt: \(prompt?.displayText ?? "")")
            let reasoning = result.reasoningDepth.map { " · reasoning: \($0.rawValue)" } ?? ""
            lines.append("Model: \(result.tier.rawValue) · shape: \(result.shape.rawValue)\(reasoning) · \(String(format: "%.1f", result.seconds))s · \(CoachReplyPolish.wordCount(result.reply)) words")
            if let reason = result.fallbackReason, !reason.isEmpty {
                lines.append("Fell back to on-device because: \(reason)")
            }
            if let draft = result.draft {
                lines.append("Draft: \(draft)")
            }
            lines.append("Tools: \(result.toolsUsed.isEmpty ? "none" : result.toolsUsed.joined(separator: ", "))")
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
            if let prompt {
                let rubric = self.rubric(for: prompt)
                lines.append("")
                lines.append("Rubric:")
                lines.append(contentsOf: rubric.map { "- [ ] \($0)" })
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")
    }
}
