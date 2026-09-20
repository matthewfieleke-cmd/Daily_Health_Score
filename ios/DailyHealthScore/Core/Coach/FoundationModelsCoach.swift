import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// DHS Lifestyle Coach on Apple Foundation Models. Private Cloud Compute
/// thinks and answers; the on-device model does the filing (titles, summaries,
/// pillar tags, the compiled profile, housekeeping) so it costs no quota.
@MainActor
final class FoundationModelsCoach {
    enum CoachError: LocalizedError {
        case unavailable(CoachAvailabilityStatus)
        case generationFailed(String)
        /// Both models refused the content itself (guardrail or model refusal).
        /// The app answers these, because the refusal lands on exactly the
        /// messages where care matters most.
        case declined(reason: String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let status):
                return status.guidance
            case .generationFailed(let message):
                return message
            case .declined(let reason):
                return reason
            }
        }
    }

    /// A refusal is recognized by what the framework says about it, across the
    /// error types iOS 26 and 27 use for it.
    nonisolated static func isContentDecline(_ error: Error) -> Bool {
        let text = (String(reflecting: error) + " " + error.localizedDescription).lowercased()
        return text.contains("guardrail") || text.contains("refus") || text.contains("sensitive")
    }

    var availability: CoachAvailabilityStatus {
        #if canImport(FoundationModels)
        return mapAvailability(SystemLanguageModel.default.availability)
        #else
        return .unavailable
        #endif
    }

    /// Which model answered the last request, for the UI to surface.
    private(set) var lastTierUsed: CoachModelTier = .onDevice

    /// The framework's own account of the last failure, for the line under a
    /// failed reply and the eval screen. Nil after a success.
    private(set) var lastFailureReason: String?

    // MARK: - Check-in card

    func generateCheckIn(
        kind: CoachCheckInKind,
        snapshot: CoachSnapshot,
        profile: String,
        memoryBlock: String,
        recentConversations: String,
        goalRows: [CoachCheckInGoalRow],
        trend: CoachTrendDigest?,
        goalPaceDirective: String?,
        now: Date = Date()
    ) async throws -> CoachCheckIn {
        #if canImport(FoundationModels)
        try ensureAvailable()
        // Background writes yield to chat when the daily allowance is nearly spent.
        let tier: CoachModelTier = CoachModelProvider.isServerQuotaApproaching ? .onDevice : CoachModelProvider.preferredTier()
        let budget = await CoachModelProvider.contextBudget(for: tier)
        func makePrompt(budget: CoachContextBudget) -> String {
            """
            Write today's \(kind.title.lowercased()) card for the Home screen.

            HEALTH SNAPSHOT (authoritative):
            \(snapshot.promptBlock)

            COACHING DIRECTIVES (derived from goal status — follow these):
            \(snapshot.coachingDirective)

            SMART GOALS TODAY (already computed):
            \(CoachCheckInLogic.goalsBlock(goalRows))
            \(goalPaceDirective ?? "")

            \(trend?.promptBlock ?? "TREND FACTS: none today.")

            PROFILE (compiled from the memory files):
            \(profile.isEmpty ? "None yet." : profile.limitedToCoachBudget(budget.profileCharacters))

            MEMORY FILES (dated; quote accurately):
            \(memoryBlock.limitedToCoachBudget(budget.profileCharacters))

            RECENT CONVERSATIONS (for the question; quote accurately):
            \(recentConversations.limitedToCoachBudget(budget.summaryCharacters))

            \(CoachCharter.checkInContract(kind: kind, hasTrend: trend != nil))
            """
        }
        let content: GenerableCoachCheckIn
        do {
            lastTierUsed = tier
            content = try await CoachModelProvider.respond(
                CoachModelProvider.makeSession(tier: tier, instructions: CoachCharter.instructions(for: tier)),
                to: makePrompt(budget: budget),
                generating: GenerableCoachCheckIn.self,
                tier: tier,
                depth: .light
            )
        } catch where tier == .privateCloud {
            // Network loss, quota, or a server hiccup should never cost the
            // card; the on-device model can still write it.
            lastTierUsed = .onDevice
            let retryBudget = await CoachModelProvider.contextBudget(for: .onDevice)
            content = try await CoachModelProvider
                .makeSession(tier: .onDevice, instructions: CoachCharter.instructions(for: .onDevice))
                .respond(to: makePrompt(budget: retryBudget), generating: GenerableCoachCheckIn.self)
                .content
        }
        let health = CoachMarkdown.plainText(content.healthLine).trimmedForCoach().endingOnSentence(maxCharacters: 220)
        guard !health.isEmpty else {
            throw CoachError.generationFailed("The coach returned an empty card.")
        }
        let question = CoachMarkdown.plainText(content.question).trimmedForCoach().endingOnSentence(maxCharacters: 200)
        let tomorrow = kind == .evening
            ? CoachMarkdown.plainText(content.tomorrowLine).trimmedForCoach().endingOnSentence(maxCharacters: 180)
            : ""
        let trendLine = trend != nil
            ? CoachMarkdown.plainText(content.trendLine).trimmedForCoach().endingOnSentence(maxCharacters: 220)
            : ""
        return CoachCheckIn(
            kind: kind,
            dateKey: snapshot.todayKey,
            healthLine: CoachReplyPolish.polish(health),
            question: question,
            tomorrowLine: tomorrow,
            trendLine: trendLine.isEmpty ? (trend?.sentence ?? "") : trendLine,
            isFallback: false,
            generatedAt: now
        )
        #else
        throw CoachError.unavailable(.unavailable)
        #endif
    }

    // MARK: - Chat

    func reply(
        to userMessage: String,
        intent: CoachIntent,
        snapshot: CoachSnapshot?,
        historyBlock: String?,
        profile: String,
        memoryBlock: String,
        recentTurns: [CoachChatTurn],
        goals: [SMARTGoal] = [],
        focusedGoalID: UUID? = nil,
        previousProposal: CoachGoalProposal? = nil,
        planningGoal: Bool = false,
        focus: CoachFocusContext? = nil,
        activitiesByGoal: [UUID: [SMARTGoalActivity]] = [:],
        bodyTrend: BodyTrend? = nil,
        context: CoachReplyContext
    ) async throws -> CoachReplyResult {
        #if canImport(FoundationModels)
        try ensureAvailable()
        let tier = CoachModelProvider.tier(for: intent)
        let shape = CoachReplyShape.detect(message: userMessage, intent: intent)
        let isGoalConversation = planningGoal || context.thread?.kind == .goal || CoachGoalPlanning.isGoalConversation(
            message: userMessage, focusedGoalID: focusedGoalID, hasProposal: previousProposal != nil
        )
        func instructions(for answeringTier: CoachModelTier) -> String {
            isGoalConversation
                ? CoachCharter.goalPlanningInstructions(for: answeringTier)
                : CoachCharter.instructions(for: answeringTier)
        }
        let instructions = instructions(for: tier)
        let budget = CoachContextBudget.make(
            totalTokens: await CoachModelProvider.contextTokens(for: tier),
            instructionCharacters: instructions.count
        )
        lastTierUsed = tier
        // The files reach the model only where they can be relevant; the intake
        // always sees them, since it is filling them. HRV rides along only when
        // the message is about it.
        let memoryAllowed = shape.usesMemoryFiles || context.isAcquaintance
        let loweredMessage = userMessage.lowercased()
        let asksAboutHRV = ["hrv", "heart rate variability", "variability", "recover", "resting heart", "rested", "sleep quality", "how well did i sleep"]
            .contains { loweredMessage.contains($0) }
        var snapshot = snapshot
        if !asksAboutHRV { snapshot?.hrvSummary = nil }
        let tools: [any Tool] = tier == .privateCloud
            ? CoachSessionTools.make(
                snapshot: snapshot,
                goals: goals,
                memoryBlock: memoryBlock,
                recentConversations: context.recentConversations,
                activitiesByGoal: activitiesByGoal,
                bodyTrend: bodyTrend
            )
            : []
        let session = CoachModelProvider.makeSession(
            tier: tier,
            instructions: instructions,
            tools: tools
        )
        // The server model sees everything and is trusted to use it well.
        // The small on-device model still gets the metric-gated view.
        let healthBlock: String
        if let focus, focus.isHistorical {
            healthBlock = """
            \(focus.promptBlock)
            TODAY (only if the user asks about today; do not substitute it for the selected period):
            \(snapshot?.minimalBlock ?? "No live daily record is available right now.")
            """
        } else if let snapshot {
            if tier == .privateCloud {
                healthBlock = snapshot.promptBlock + "\nThese are here for when they matter. Do not recite them unprompted."
            } else if intent.usesFullMetrics || context.allowUnpromptedHealth {
                healthBlock = snapshot.promptBlock + "\nNever print the status tokens; speak like a person."
            } else {
                healthBlock = snapshot.minimalBlock
            }
        } else {
            healthBlock = "No live daily record is available right now. Do not invent personal metrics; answer from general knowledge."
        }
        let topics = LifestyleMedicineKnowledge.retrievalTopics(
            intent: intent,
            query: userMessage,
            primaryFocus: snapshot?.primaryFocus
        )
        let chatLine: String = {
            guard let thread = context.thread else { return "CHAT: new." }
            var parts = ["CHAT: \"\(thread.title)\""]
            switch thread.kind {
            case .conversation: break
            case .acquaintance: parts.append("(getting acquainted)")
            case .checkInReply: parts.append("(reply to a Home check-in)")
            case .goal: parts.append("(about a saved SMART goal)")
            }
            if !thread.contextNote.isEmpty { parts.append("— \(thread.contextNote.limitedToCoachBudget(300))") }
            return parts.joined(separator: " ")
        }()
        let alreadySuggested = CoachRepetitionGuard.promptBlock(
            in: recentTurns.filter { $0.role == .coach }.map(\.text)
        )
        // Every block is sized against whichever model is answering, so the
        // on-device retry re-trims rather than reusing server-sized text.
        func makePrompt(compact: Bool, budget: CoachContextBudget, answeringTier: CoachModelTier) -> String {
            let notLoaded = "Not loaded for this kind of message. If they refer to something personal, use lookupWhatWeRemember."
            let profileSection: String
            let memorySection: String
            let recentSection: String
            if !memoryAllowed {
                profileSection = notLoaded
                memorySection = notLoaded
                recentSection = notLoaded
            } else if compact {
                profileSection = "Omitted."
                memorySection = "Omitted."
                recentSection = "Omitted."
            } else {
                profileSection = profile.isEmpty ? "None yet." : profile.limitedToCoachBudget(budget.profileCharacters)
                let thin = context.memoryNoteCount < 6
                    ? "\nFILES ARE THIN (\(context.memoryNoteCount) notes): you know a few facts about this person, not their life. Do not stretch them across replies."
                    : ""
                memorySection = memoryBlock.limitedToCoachBudget(budget.profileCharacters) + thin
                recentSection = context.recentConversations.limitedToCoachBudget(budget.summaryCharacters)
            }
            let acquaintance = context.isAcquaintance
                ? CoachCharter.acquaintanceContract(emptyFiles: context.emptyMemorySections)
                : ""
            let care = context.safetyConcern.map { CoachSafetyGate.careGuidance(for: $0) } ?? ""
            let opening = context.isFirstReply
                ? "This is the first exchange of a new chat. Most first replies need no callback to the files; use one only if a note genuinely bears on this message."
                : "Stay with this conversation; do not restart it."
            if isGoalConversation {
                let goalContext = CoachGoalPlanning.context(
                    goals: goals, focusedGoalID: focusedGoalID ?? context.thread?.goalId, previousProposal: previousProposal,
                    activitiesByGoal: activitiesByGoal
                ).limitedToCoachBudget(1800)
                let dialogue = Self.transcriptBlock(
                    recentTurns, maxTurns: compact ? 3 : 8,
                    maxCharactersPerTurn: compact ? 200 : 320
                )
                return """
                \(chatLine)
                \(shape.hint)
                \(care)
                USER MESSAGE: \(userMessage.limitedToCoachBudget(1200))
                \(CoachGoalPlanning.contract)
                \(goalContext)
                \(context.goalPaceDirective ?? "")
                \(focus.map { $0.promptBlock.limitedToCoachBudget(500) } ?? "")
                AVAILABLE HEALTH FACTS (only use when relevant):
                \(snapshot?.metrics.map(\.sentence).joined(separator: "\n").limitedToCoachBudget(650) ?? "No Health record; goal planning is still available.")
                PROFILE:
                \(profileSection)
                MEMORY FILES (dated; quote accurately):
                \(memorySection)
                RECENT CONVERSATION (drafts are unsaved until a save confirmation):
                \(dialogue)
                \(CoachCharter.outputContract)
                Reply in message and supply a goalProposal only for a concrete plan.
                Never invent past behavior. Set goalCheckIn only when they clearly said they did the action.
                """
            }
            let transcript = Self.transcriptBlock(
                recentTurns,
                maxTurns: budget.transcriptTurns,
                maxCharactersPerTurn: budget.transcriptCharactersPerTurn
            )
            // Background, not script: the server model's own knowledge and the
            // tools come first; the on-device model leans on it more.
            let knowledge = LifestyleMedicineKnowledge.promptBlock(
                query: userMessage,
                topics: topics,
                limit: answeringTier == .privateCloud ? 3 : (intent == .education ? 12 : 4),
                characterBudget: answeringTier == .privateCloud
                    ? budget.knowledgeCharacters / 2
                    : (intent == .education ? budget.knowledgeCharacters : budget.knowledgeCharacters * 2 / 3)
            )
            let historySection = historyBlock.map {
                """


                EARLIER DAYS THE USER ASKED ABOUT (already computed — use these numbers exactly):
                \($0.limitedToCoachBudget(budget.historyCharacters))
                """
            } ?? ""
            let focusSection = focus.map {
                """


                \($0.promptBlock.limitedToCoachBudget(budget.historyCharacters))
                """
            } ?? ""
            let toolsLine = answeringTier == .privateCloud
                ? "TOOLS: \(CoachSessionTools.toolNames). Look up any food or product they named or asked about before estimating — not foods you are merely recommending; use the calculator for totals; use the evidence tool when a claim deserves a source."
                : "TOOLS: none on this device. Estimate food values and label them approximate."
            let suggestedSection = alreadySuggested.map { "\n" + $0 } ?? ""
            return """
            Continue the DHS Lifestyle Coach conversation.

            \(chatLine)
            \(opening)
            \(shape.hint)
            Attention: this chat has mostly been about \(context.pillar.label.lowercased()). \(context.pillar.leadsWithNumbers ? "Their numbers are welcome here when they help." : "Lead with the person; numbers only if they ask.")
            Unprompted Health this turn: \(context.allowUnpromptedHealth ? "allowed, one sentence max" : "not allowed").
            \(acquaintance)
            \(care)

            USER MESSAGE:
            \(userMessage)

            \(CoachCharter.answerDepthGuidance(for: answeringTier))

            HEALTH SNAPSHOT (authoritative numbers):
            \(healthBlock)\(historySection)\(focusSection)
            \(context.goalPaceDirective ?? "")

            PROFILE (compiled from the memory files):
            \(profileSection)

            MEMORY FILES (dated; "stated" = they said it, "inferred" = your read):
            \(memorySection)

            RECENT CONVERSATIONS (other chats, newest first; for callbacks only):
            \(recentSection)

            RECENT TRANSCRIPT (this chat):
            \(compact || transcript.isEmpty ? "None yet." : transcript)
            \(suggestedSection)

            BACKGROUND (optional reference; your own knowledge and the tools come first):
            \(compact || knowledge.isEmpty ? "None." : knowledge)

            \(toolsLine)

            \(CoachCharter.outputContract)

            Reply as the coach. Your first sentence answers the message.
            """
        }

        let content: GenerableCoachReply
        var fallbackReason: String?
        lastFailureReason = nil
        do {
            content = try await CoachModelProvider.respond(
                session,
                to: makePrompt(compact: false, budget: budget, answeringTier: tier),
                generating: GenerableCoachReply.self,
                tier: tier,
                depth: shape.reasoningDepth
            )
        } catch {
            // One fallback covers every failure mode that matters: no network,
            // exhausted server quota, or context pressure. Retry on-device with
            // the shorter charter and memory and reference material dropped.
            let firstError = error
            if tier == .privateCloud {
                fallbackReason = Self.describe(error)
            }
            let retryInstructions = instructions(for: .onDevice)
            let retryBudget = CoachContextBudget.make(
                totalTokens: await CoachModelProvider.contextTokens(for: .onDevice),
                instructionCharacters: retryInstructions.count
            )
            let retrySession = CoachModelProvider.makeSession(
                tier: .onDevice,
                instructions: retryInstructions,
                tools: []
            )
            lastTierUsed = .onDevice
            do {
                content = try await retrySession.respond(
                    to: makePrompt(compact: tier == .onDevice, budget: retryBudget, answeringTier: .onDevice),
                    generating: GenerableCoachReply.self
                ).content
            } catch {
                // Both declined the content itself: the app answers, with care.
                // Anything else is size or reachability, and gets the plain message.
                lastFailureReason = "\(Self.describe(firstError)); on-device retry: \(Self.describe(error))"
                if Self.isContentDecline(error) || Self.isContentDecline(firstError) {
                    throw CoachError.declined(reason: Self.describe(error))
                }
                throw CoachError.generationFailed(Self.friendlyFailureMessage)
            }
        }
        let message = CoachReplyPolish.polish(content.message.trimmedForCoach())
        guard !message.isEmpty else {
            lastFailureReason = "empty message from \(lastTierUsed.rawValue)"
            throw CoachError.generationFailed("The coach returned an empty reply.")
        }
        let memoryUpdates = content.memoryUpdates.compactMap {
            CoachMemoryUpdate(operation: $0.operation, section: $0.section, text: $0.text, replaces: $0.replaces, basis: $0.basis)
        }
        let checkIn = content.goalCheckIn.flatMap {
            CoachGoalCheckInRequest.make(goalID: $0.goalID, when: $0.when, note: $0.note, goals: goals)
        }
        let proposal = isGoalConversation ? content.goalProposal.flatMap { draft in
            CoachGoalProposal.make(
                operation: draft.operation, goalID: draft.goalID,
                specificText: draft.specificText, targetCount: draft.targetCount,
                theme: draft.theme, daysFromToday: draft.daysFromToday, goals: goals,
                focusedGoalID: focusedGoalID,
                personalReason: draft.personalReason,
                cue: draft.cue,
                expectedBarriers: draft.expectedBarriers,
                fallbackAction: draft.fallbackAction
            )
        } : nil
        return CoachReplyResult(
            message: message,
            memoryUpdates: memoryUpdates,
            goalCheckIn: checkIn,
            goalProposal: proposal,
            proposalRejected: isGoalConversation && content.goalProposal != nil && proposal == nil,
            tier: lastTierUsed,
            shape: shape,
            fallbackReason: fallbackReason
        )
        #else
        throw CoachError.unavailable(.unavailable)
        #endif
    }

    /// The framework's error, named for the eval screen: the enum case plus its
    /// message, so a guardrail refusal reads differently from a network drop.
    nonisolated static func describe(_ error: Error) -> String {
        let mirror = String(reflecting: error)
        let described = error.localizedDescription
        if mirror.count <= 160 { return described.isEmpty ? mirror : "\(mirror): \(described)" }
        return described.isEmpty ? String(mirror.prefix(160)) : described
    }

    // MARK: - On-device filing

    /// Title, summary, and pillar for a chat after an exchange. On-device, no quota.
    func fileChat(
        userMessage: String,
        reply: String,
        currentTitle: String,
        titleIsProvisional: Bool,
        currentPillar: CoachPillar
    ) async throws -> CoachChatFiling {
        #if canImport(FoundationModels)
        try ensureAvailable()
        let prompt = """
        CURRENT TITLE: \(titleIsProvisional ? "(none yet — provisional: \(currentTitle))" : currentTitle)
        CURRENT PILLAR: \(currentPillar.rawValue)

        USER:
        \(userMessage.limitedToCoachBudget(900))

        COACH:
        \(CoachMarkdown.plainText(reply).limitedToCoachBudget(1400))

        File this chat.
        """
        let content = try await CoachModelProvider
            .makeSession(tier: .onDevice, instructions: CoachCharter.filingInstructions)
            .respond(to: prompt, generating: GenerableChatFiling.self)
            .content
        return CoachChatFiling(
            title: content.threadTitle,
            summary: content.threadSummary.trimmedForCoach(),
            pillar: CoachPillar(modelValue: content.pillar)
        )
        #else
        throw CoachError.unavailable(.unavailable)
        #endif
    }

    /// One paragraph per file, on-device. Empty when there is nothing to compile.
    func compileProfile(entryList: String) async throws -> String {
        #if canImport(FoundationModels)
        try ensureAvailable()
        guard entryList != "None." else { return "" }
        let prompt = """
        ENTRIES (id | file | date | stated/inferred | note):
        \(entryList.limitedToCoachBudget(9_000))

        Compile the profile.
        """
        let text = try await CoachModelProvider
            .makeSession(tier: .onDevice, instructions: CoachCharter.profileInstructions)
            .respond(to: prompt)
            .content
        return CoachMarkdown.plainText(text).trimmedForCoach().limitedToCoachBudget(3_000)
        #else
        throw CoachError.unavailable(.unavailable)
        #endif
    }

    /// Housekeeping proposals for the files, on-device. Never new opinions.
    func reviewFiles(entryList: String) async throws -> [CoachFileReviewOperation] {
        #if canImport(FoundationModels)
        try ensureAvailable()
        guard entryList != "None." else { return [] }
        let prompt = """
        ENTRIES (id | file | date | stated/inferred | note). Files: aboutYou, people, patterns, coaching, goals, likes, routines, body, recent.
        \(entryList.limitedToCoachBudget(9_000))

        Propose housekeeping operations, or none.
        """
        let content = try await CoachModelProvider
            .makeSession(tier: .onDevice, instructions: CoachCharter.reviewInstructions)
            .respond(to: prompt, generating: GenerableFileReview.self)
            .content
        return content.operations.prefix(6).compactMap {
            CoachFileReviewOperation(kind: $0.kind, id: $0.id, section: $0.section, text: $0.text, basis: $0.basis)
        }
        #else
        throw CoachError.unavailable(.unavailable)
        #endif
    }

    /// Shown instead of a raw framework error, which is usually a guardrail
    /// rejection rather than anything the person did wrong.
    static let friendlyFailureMessage = """
    I couldn't put a good answer together for that one. Try rephrasing it, \
    or ask me something else — I'm still here.
    """

    /// Keeps the transcript small; the on-device context window is shared with the
    /// charter, snapshot, and reference material.
    nonisolated static func transcriptBlock(
        _ turns: [CoachChatTurn],
        maxTurns: Int = 6,
        maxCharactersPerTurn: Int = 240
    ) -> String {
        turns.suffix(maxTurns).map { turn in
            let label = turn.role == .user ? "User" : "Coach"
            var text = turn.text
            if text.count > maxCharactersPerTurn {
                text = String(text.prefix(maxCharactersPerTurn)) + "…"
            }
            return "\(label): \(text)"
        }.joined(separator: "\n")
    }

    #if canImport(FoundationModels)
    private func ensureAvailable() throws {
        let status = mapAvailability(SystemLanguageModel.default.availability)
        guard status == .available else {
            throw CoachError.unavailable(status)
        }
    }

    private func mapAvailability(_ availability: SystemLanguageModel.Availability) -> CoachAvailabilityStatus {
        switch availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }
    #endif
}

#if canImport(FoundationModels)
@Generable
struct GenerableCoachCheckIn {
    @Guide(description: "One complete spoken sentence about today's health. No status tokens (BELOW GOAL, GOAL MET, NO DATA). No ellipses. Plain text.")
    var healthLine: String

    @Guide(description: "One question that shows you remember this person, tied to a memory note, a recent conversation, or a live goal. One sentence ending in a question mark. Plain text.")
    var question: String

    @Guide(description: "Evening only: one small specific thing for tomorrow, one sentence starting with Tomorrow. Empty string in the morning.")
    var tomorrowLine: String

    @Guide(description: "Only when TREND FACTS were provided: one sentence with plain numbers. Otherwise empty string.")
    var trendLine: String
}

@Generable
struct GenerableMemoryUpdate {
    @Guide(description: "add, update, or remove.")
    var operation: String

    @Guide(description: "aboutYou, people, patterns, coaching, goals, likes, routines, body, or recent.")
    var section: String

    @Guide(description: "The note as one full sentence with its context — the when, the why, or the person's own words — never a bare word ('Does yoga; part of what a good day looks like to him', not 'Yoga.'). Under 240 characters, third person, present tense, specific: names, products, dates as of a month. Empty for remove.")
    var text: String

    @Guide(description: "For update or remove: the existing note being replaced or removed, quoted as closely as possible. Empty for add.")
    var replaces: String

    @Guide(description: "stated when the person said it; inferred when it is your read of them.")
    var basis: String
}

@Generable
struct GenerableGoalCheckIn {
    @Guide(description: "Exact goalID from CURRENT GOALS or the SMART goals lookup.")
    var goalID: String

    @Guide(description: "today or yesterday.")
    var when: String

    @Guide(description: "Short note in the person's words. Empty if none.")
    var note: String
}

@Generable
struct GenerableCoachReply {
    @Guide(description: "The coach's reply, in second person, following the charter. Light Markdown only. Hard ceiling 350 words; most replies far shorter.")
    var message: String

    @Guide(description: "Memory file edits learned in this exchange, at most five. Empty when nothing durable was learned. Never today's numbers.")
    var memoryUpdates: [GenerableMemoryUpdate]

    @Guide(description: "Only when the person clearly said they completed a saved SMART goal action today or yesterday. Nil otherwise.")
    var goalCheckIn: GenerableGoalCheckIn?

    @Guide(description: "An unsaved SMART goal draft to review. Nil for advice, questions, progress reports or unsafe requests.")
    var goalProposal: GenerableSMARTGoalProposal?
}

@Generable
struct GenerableChatFiling {
    @Guide(description: "Two to five Title Case words naming this chat like a note to self, for example Fiber at Dinner. No quotes, no trailing punctuation.")
    var threadTitle: String

    @Guide(description: "One third-person sentence on what this chat is about and where it stands.")
    var threadSummary: String

    @Guide(description: "One of: relationships, nutrition, sleep, activity, stress, hobbies, general.")
    var pillar: String
}

@Generable
struct GenerableFileReviewOperation {
    @Guide(description: "refile, update, retire, or add.")
    var kind: String

    @Guide(description: "The 8-character id of the entry, exactly as listed. Empty for add.")
    var id: String

    @Guide(description: "Target file for refile or add: aboutYou, people, patterns, coaching, goals, likes, routines, body, recent. Empty otherwise.")
    var section: String

    @Guide(description: "New text for update or add. Empty otherwise.")
    var text: String

    @Guide(description: "stated or inferred, for add. Empty otherwise.")
    var basis: String
}

@Generable
struct GenerableFileReview {
    @Guide(description: "Housekeeping operations, at most six. Empty when the files are tidy.")
    var operations: [GenerableFileReviewOperation]
}

@Generable
struct GenerableSMARTGoalProposal {
    @Guide(description: "Exactly create or update.")
    var operation: String
    @Guide(description: "Exact goalID from CURRENT GOALS for update; nil for create. Never invent an ID.")
    var goalID: String?
    @Guide(description: "One specific action per check-in, at most 500 characters. Required for create; nil to preserve the action on update.")
    var specificText: String?
    @Guide(description: "Total target check-ins, 1 through 30, at least the recorded count. Required for create; nil to preserve on update.")
    var targetCount: Int?
    @Guide(description: "marriage, parenting, health, relationships, finances, career, or choresMisc. Required for create; nil to preserve on update.")
    var theme: String?
    @Guide(description: "Days from today until the deadline, 1 through 30. Required for create; nil for update unless a deadline change was requested.")
    var daysFromToday: Int?
    @Guide(description: "Optional personal reason. Nil to preserve on update.")
    var personalReason: String?
    @Guide(description: "Optional cue such as after lunch. Nil to preserve on update.")
    var cue: String?
    @Guide(description: "Optional expected barriers. Ask; do not invent. Nil to preserve on update.")
    var expectedBarriers: String?
    @Guide(description: "Optional smaller fallback that does not silently satisfy a larger accepted action.")
    var fallbackAction: String?
}
#endif

private extension String {
    func trimmedForCoach() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
