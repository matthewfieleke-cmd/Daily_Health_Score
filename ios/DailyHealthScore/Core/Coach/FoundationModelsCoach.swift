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

            WHO THEY ARE (orientation for this card; use a detail only when it fits today):
            \(profile.isEmpty ? "None yet." : profile.limitedToCoachBudget(budget.profileCharacters))

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

    /// One conversation per chat, held by the framework the way any assistant
    /// holds a thread. Rebuilt when the tier changes or after a context overflow;
    /// seeded from the stored turns on a cold start. Who the person is stays in
    /// the tools, so a new note does not throw the conversation away.
    #if canImport(FoundationModels)
    private struct LiveSession {
        var session: LanguageModelSession
        var tier: CoachModelTier
        var turnsSeen: Int
    }
    private var sessions: [UUID: LiveSession] = [:]
    #endif

    /// Drop a chat's session: the chat was deleted, or memory changed underneath it.
    func forgetSession(for threadID: UUID) {
        #if canImport(FoundationModels)
        sessions[threadID] = nil
        #endif
    }

    func forgetAllSessions() {
        #if canImport(FoundationModels)
        sessions.removeAll()
        #endif
    }

    /// The reply. The model sees the conversation and a set of tools for facts
    /// and actions; it decides what this message needs.
    func reply(
        to userMessage: String,
        recentTurns: [CoachChatTurn],
        live: CoachLiveContext,
        focus: CoachFocusContext? = nil,
        context: CoachReplyContext
    ) async throws -> CoachReplyResult {
        #if canImport(FoundationModels)
        try ensureAvailable()
        let tier = CoachModelProvider.preferredTier()
        let shape = CoachReplyShape.detect(message: userMessage, intent: CoachIntentClassifier.classify(userMessage))
        lastTierUsed = tier
        lastFailureReason = nil
        live.beginTurn()

        // Framing the model would not otherwise know: which chat this is, what
        // the person tapped to open it, and the intake. Past days are a tool.
        var framing: [String] = []
        if let thread = context.thread {
            switch thread.kind {
            case .conversation: break
            case .acquaintance: framing.append(CoachCharter.acquaintanceContract(emptyFiles: context.emptyMemorySections))
            case .checkInReply: framing.append("This chat began from today's Home check-in card; the person is replying to it.")
            case .goal: framing.append("This chat is about one saved SMART goal (see lookupSMARTGoals; the focused goal is marked). Updates go to that goal only.")
            }
            if !thread.contextNote.isEmpty, context.isFirstReply {
                framing.append("Context for this chat: \(thread.contextNote.limitedToCoachBudget(300))")
            }
        }
        if let focus {
            framing.append(focus.promptBlock.limitedToCoachBudget(CoachContextBudget.maxHistoryCharacters))
        }

        func prompt(seedingTranscript turns: [CoachChatTurn]?, budget: CoachContextBudget) -> String {
            var parts: [String] = []
            if let turns, !turns.isEmpty {
                parts.append("EARLIER IN THIS CHAT (oldest first):\n" + Self.transcriptBlock(turns, maxTurns: budget.transcriptTurns, maxCharactersPerTurn: budget.transcriptCharactersPerTurn))
            }
            parts.append(contentsOf: framing)
            parts.append(userMessage)
            return parts.joined(separator: "\n\n")
        }

        // Server: a persistent session per chat.
        if tier == .privateCloud {
            let instructions = CoachCharter.instructions(for: .privateCloud)
            let budget = CoachContextBudget.make(
                totalTokens: await CoachModelProvider.contextTokens(for: .privateCloud),
                instructionCharacters: instructions.count
            )
            let threadID = context.thread?.id
            var seed: [CoachChatTurn]? = nil
            var liveSession: LiveSession
            if let threadID, let existing = sessions[threadID], existing.tier == .privateCloud {
                liveSession = existing
            } else {
                // Cold start: the stored turns (minus the message being sent) seed
                // the first prompt; from here on the session carries the thread.
                seed = Array(recentTurns.dropLast(recentTurns.last?.role == .user ? 1 : 0))
                liveSession = LiveSession(
                    session: CoachModelProvider.makeSession(tier: .privateCloud, instructions: instructions, tools: CoachSessionTools.make(context: live)),
                    tier: .privateCloud,
                    turnsSeen: 0
                )
            }

            func attempt(_ session: LanguageModelSession, seed: [CoachChatTurn]?) async throws -> String {
                try await CoachModelProvider.respondText(
                    session,
                    to: prompt(seedingTranscript: seed, budget: budget),
                    tier: .privateCloud,
                    depth: .deep
                )
            }

            do {
                let text: String
                do {
                    text = try await attempt(liveSession.session, seed: seed)
                } catch where Self.isContextOverflow(error) {
                    // The thread outgrew the window: start a fresh session seeded
                    // with the recent turns and continue.
                    let fresh = CoachModelProvider.makeSession(tier: .privateCloud, instructions: instructions, tools: CoachSessionTools.make(context: live))
                    liveSession = LiveSession(session: fresh, tier: .privateCloud, turnsSeen: 0)
                    text = try await attempt(fresh, seed: Array(recentTurns.suffix(8).dropLast(recentTurns.last?.role == .user ? 1 : 0)))
                } catch where !Self.isContentDecline(error) {
                    // A server hiccup is usually gone a second later.
                    text = try await attempt(liveSession.session, seed: seed)
                }
                liveSession.turnsSeen += 1
                if let threadID { sessions[threadID] = liveSession }
                return finish(text, tier: .privateCloud, shape: shape, live: live, fallbackReason: nil)
            } catch {
                if let threadID { sessions[threadID] = nil }
                return try await onDeviceReply(
                    userMessage: userMessage,
                    recentTurns: recentTurns,
                    framing: framing,
                    live: live,
                    shape: shape,
                    firstError: error,
                    fallbackReason: Self.describe(error)
                )
            }
        }

        return try await onDeviceReply(
            userMessage: userMessage,
            recentTurns: recentTurns,
            framing: framing,
            live: live,
            shape: shape,
            firstError: nil,
            fallbackReason: nil
        )
        #else
        throw CoachError.unavailable(.unavailable)
        #endif
    }

    #if canImport(FoundationModels)
    /// The small model gets a fresh session each time with the recent turns as
    /// text, and one more try at half the budget if the window overflows. When
    /// the content itself is refused, one attempt with the input classifier
    /// relaxed, then the app answers.
    private func onDeviceReply(
        userMessage: String,
        recentTurns: [CoachChatTurn],
        framing: [String],
        live: CoachLiveContext,
        shape: CoachReplyShape,
        firstError: Error?,
        fallbackReason: String?
    ) async throws -> CoachReplyResult {
        lastTierUsed = .onDevice
        // Anything a failed server attempt asked for is void; this turn starts over.
        live.beginTurn()
        let instructions = CoachCharter.instructions(for: .onDevice)
        let fullBudget = CoachContextBudget.make(
            totalTokens: await CoachModelProvider.contextTokens(for: .onDevice),
            instructionCharacters: instructions.count
        )
        let halfBudget = CoachContextBudget.make(totalTokens: fullBudget.totalTokens / 2, instructionCharacters: instructions.count)
        let history = Array(recentTurns.dropLast(recentTurns.last?.role == .user ? 1 : 0))

        func prompt(budget: CoachContextBudget) -> String {
            var parts: [String] = []
            let turns = Self.transcriptBlock(history, maxTurns: min(budget.transcriptTurns, 6), maxCharactersPerTurn: budget.transcriptCharactersPerTurn)
            if !turns.isEmpty { parts.append("EARLIER IN THIS CHAT (oldest first):\n" + turns) }
            parts.append(contentsOf: framing.map { $0.limitedToCoachBudget(budget.historyCharacters) })
            parts.append(userMessage)
            return parts.joined(separator: "\n\n")
        }

        var lastError: Error? = firstError
        for (budget, permissive) in [(fullBudget, false), (halfBudget, false), (fullBudget, true)] {
            if permissive {
                guard let declined = lastError ?? firstError, Self.isContentDecline(declined) else { break }
            }
            // No tools on the small model: eleven schemas would eat a 4K window,
            // and it answers from the recent turns instead.
            let session = CoachModelProvider.makeSession(
                tier: .onDevice,
                instructions: instructions,
                tools: [],
                permissiveGuardrails: permissive
            )
            do {
                let text = try await CoachModelProvider.respondText(session, to: prompt(budget: budget), tier: .onDevice, depth: .light)
                return finish(text, tier: .onDevice, shape: shape, live: live, fallbackReason: fallbackReason)
            } catch {
                lastError = error
                if !permissive, !Self.isContextOverflow(error), !Self.isContentDecline(error) { break }
            }
        }

        let lastFailure: Error = lastError ?? CoachError.generationFailed(Self.friendlyFailureMessage)
        lastFailureReason = [firstError.map(Self.describe), "on-device: " + Self.describe(lastFailure)].compactMap { $0 }.joined(separator: "; ")
        if Self.isContentDecline(lastFailure) || (firstError.map(Self.isContentDecline) ?? false) {
            throw CoachError.declined(reason: Self.describe(lastFailure))
        }
        throw CoachError.generationFailed(Self.friendlyFailureMessage)
    }

    private func finish(_ text: String, tier: CoachModelTier, shape: CoachReplyShape, live: CoachLiveContext, fallbackReason: String?) -> CoachReplyResult {
        let message = CoachReplyPolish.polish(text.trimmedForCoach())
        return CoachReplyResult(
            message: message.isEmpty ? Self.friendlyFailureMessage : message,
            memoryUpdates: live.pendingMemoryUpdates,
            goalCheckIn: live.pendingCheckIn,
            goalProposal: live.pendingProposal,
            proposalRejected: live.proposalRejected,
            tier: tier,
            shape: shape,
            fallbackReason: fallbackReason,
            toolsUsed: live.toolLog
        )
    }
    #endif

    /// The framework's error, named for the eval screen: the enum case plus its
    /// message, so a guardrail refusal reads differently from a network drop.
    nonisolated static func describe(_ error: Error) -> String {
        var mirror = String(reflecting: error)
        // Swift wraps private types in an anonymous context; that is noise here.
        while let noise = mirror.range(of: #"\(unknown context at \$[0-9a-fA-F]+\)\."#, options: .regularExpression) {
            mirror.removeSubrange(noise)
        }
        let described = error.localizedDescription
        // The case name is the useful part; the payload can run to paragraphs.
        let caseName = String(mirror.prefix { $0 != "(" }).trimmingCharacters(in: .whitespacesAndNewlines)
        let head = caseName.isEmpty ? String(mirror.prefix(120)) : String(caseName.prefix(120))
        if described.isEmpty || described.hasPrefix("The operation couldn’t be completed") {
            return described.isEmpty ? head : "\(head): \(described)"
        }
        return head == described ? described : "\(head): \(described)"
    }

    /// The window was too small for the prompt; a smaller prompt can still work.
    nonisolated static func isContextOverflow(_ error: Error) -> Bool {
        let text = (String(reflecting: error) + " " + error.localizedDescription).lowercased()
        return text.contains("context") && (text.contains("exceed") || text.contains("window") || text.contains("size"))
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

    @Guide(description: "One easy question about the day ahead. One sentence ending in a question mark. Plain text. A memory only when it genuinely fits this day. A commute is driving; never suggest doing anything during it other than listening.")
    var question: String

    @Guide(description: "Evening only: one small specific thing for tomorrow, one sentence starting with Tomorrow. Empty string in the morning. A commute is driving; never suggest doing anything during it other than listening.")
    var tomorrowLine: String

    @Guide(description: "Only when TREND FACTS were provided: one sentence with plain numbers. Otherwise empty string.")
    var trendLine: String
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

#endif

private extension String {
    func trimmedForCoach() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? { isEmpty ? nil : self }
}
