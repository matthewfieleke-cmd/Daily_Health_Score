import PhotosUI
import SwiftUI
import UIKit

struct LifestyleCoachChatView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var pendingPhotos: [CoachPendingPhoto] = []
    @State private var libraryItems: [PhotosPickerItem] = []
    @State private var showPhotoSource = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var isLoadingPhotos = false
    @State private var photoError: String?
    @State private var focusedGoalID: UUID?
    @State private var planningGoal = false
    @State private var goalEdit: SMARTGoalEdit?
    @State private var focus: CoachFocusContext?
    @State private var showMemory = false
    @State private var launch: CoachChatLaunch
    @State private var didOpen = false
    @FocusState private var isInputFocused: Bool

    init(
        initialMessage: String = "",
        focus: CoachFocusContext? = nil,
        focusedGoalID: UUID? = nil,
        launch: CoachChatLaunch? = nil
    ) {
        let resolved: CoachChatLaunch
        if let launch {
            resolved = launch
        } else if let focusedGoalID {
            resolved = .goal(focusedGoalID)
        } else if let focus {
            resolved = .focus(focus)
        } else if !initialMessage.isEmpty {
            resolved = .compose(initialMessage)
        } else {
            resolved = .newChat
        }
        var resolvedFocus = focus
        var goalID = focusedGoalID ?? focus?.goalId
        var prefill = initialMessage
        var isPlanning = focusedGoalID != nil || focus?.feature == .goal || initialMessage.lowercased().contains("smart goal")
        switch resolved {
        case .goal(let id):
            goalID = id
            isPlanning = true
        case .compose(let text):
            prefill = text
            isPlanning = isPlanning || text.lowercased().contains("smart goal")
        case .focus(let context):
            resolvedFocus = context
            goalID = goalID ?? context.goalId
            isPlanning = isPlanning || context.feature == .goal
        default:
            break
        }
        _draft = State(initialValue: prefill)
        _focusedGoalID = State(initialValue: goalID)
        _planningGoal = State(initialValue: isPlanning)
        _focus = State(initialValue: resolvedFocus)
        _launch = State(initialValue: resolved)
    }

    private var selectedGoal: SMARTGoal? {
        appState.smartGoalStore.goals.first { $0.id == focusedGoalID }
    }

    private var todayKey: String { DateHelpers.localDateKey() }
    private var todayRecord: DailyRecord? {
        appState.recordStore.records.first { $0.date == todayKey }
    }

    private var title: String {
        if let thread = coach.memory.openThread { return thread.title }
        if let seed = coach.memory.pendingSeed, !seed.provisionalTitle.isEmpty { return seed.provisionalTitle }
        return "New chat"
    }

    private var visibleTurns: [CoachChatTurn] { coach.memory.visibleTurns }

    var body: some View {
        VStack(spacing: 0) {
            if coach.availability != .available {
                availabilityBanner
            }
            if let focus {
                focusBanner(focus)
            }
            if planningGoal { goalFocusBanner }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if visibleTurns.isEmpty {
                            emptyIntro
                        }
                        ForEach(visibleTurns) { turn in
                            bubble(for: turn)
                                .id(turn.id)
                        }
                        if coach.isChatBusy {
                            HStack {
                                ProgressView()
                                Text("Coach is thinking…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)
                            .id("pending")
                        }
                        if let request = coach.pendingGoalCheckIn, !coach.isChatBusy {
                            goalCheckInCard(request)
                                .id("goal-check-in")
                        }
                        if let proposal = coach.goalProposal, !coach.isChatBusy {
                            goalProposalCard(proposal)
                                .id("goal-proposal")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: visibleTurns.count) { _, _ in
                    scrollToEnd(proxy)
                }
                .onChange(of: coach.isChatBusy) { _, _ in
                    scrollToEnd(proxy)
                }
                .onChange(of: coach.goalProposal?.id) { _, _ in
                    scrollToEnd(proxy)
                }
                .onChange(of: coach.pendingGoalCheckIn?.id) { _, _ in
                    scrollToEnd(proxy)
                }
            }

            if let error = coach.chatError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            suggestionRow
            composer
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Create goal manually") { goalEdit = SMARTGoalEdit() }
                    if let selectedGoal {
                        Button("Edit this goal") { goalEdit = SMARTGoalEdit(goal: selectedGoal) }
                    }
                    Button("What your coach remembers") { showMemory = true }
                    if let thread = coach.memory.openThread {
                        Divider()
                        Button("Delete this chat", role: .destructive) {
                            coach.forgetSession(for: thread.id)
                            coach.memory.deleteThread(thread.id)
                            dismiss()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Chat actions")
                .disabled(coach.isChatBusy)
            }
        }
        .sheet(item: $goalEdit) { edit in
            NavigationStack {
                SMARTGoalEditorView(edit: edit) { saved in
                    coach.recordGoalSaved(saved)
                    focusedGoalID = saved.id
                    planningGoal = true
                }
            }
        }
        .sheet(isPresented: $showMemory) {
            NavigationStack {
                CoachMemoryListView()
                    .environmentObject(appState)
            }
        }
        .onDisappear {
            // The library and camera covers can notify disappearance while the
            // photos are still the message being composed.
            guard !showCamera, !showLibrary, !showMemory, goalEdit == nil else { return }
            let names = pendingPhotos.map(\.fileName)
            pendingPhotos = []
            CoachPhotoStore.delete(fileNames: names)
        }
        .confirmationDialog("Add a photo", isPresented: $showPhotoSource, titleVisibility: .visible) {
            Button("Photo Library") { showLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showLibrary,
            selection: $libraryItems,
            maxSelectionCount: max(1, CoachPhotoStore.maxPerMessage - pendingPhotos.count),
            matching: .images
        )
        .onChange(of: libraryItems) { _, items in
            guard !items.isEmpty else { return }
            let picked = items
            libraryItems = []
            Task { await addLibraryPhotos(picked) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CoachCameraPicker(
                onImageData: { data in
                    showCamera = false
                    addPreparedPhoto(data)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            coach.refreshAvailability()
            // Once per presentation: coming back from a pushed goal screen must
            // not reset a chat that has already started.
            guard !didOpen else { return }
            didOpen = true
            // An error belongs to the chat it happened in, not the next one.
            coach.chatError = nil
            coach.memory.open(launch)
        }
    }

    /// A new chat before anything is said: the coach, the philosophy, an invitation.
    private var emptyIntro: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("DHSLifestyleCoach")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            Text(CoachCharter.philosophy)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
            Text(focus != nil
                 ? "Ask about this, or anything else on your mind."
                 : "What’s on your mind? Ask anything, or start with a question below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var goalFocusBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedGoal?.specificText ?? (focusedGoalID == nil ? "Plan a SMART goal" : "This goal is no longer saved"))
                    .font(.subheadline.weight(.semibold))
                if let selectedGoal {
                    Text("\(selectedGoal.filledCount) of \(selectedGoal.targetCount) check-ins · ends \(selectedGoal.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        if selectedGoal.status == .active && !selectedGoal.isComplete && !selectedGoal.isExpired {
                            Button("Log a check-in") {
                                appState.smartGoalStore.fillNextEmpty(on: selectedGoal.id, source: .iPhone)
                            }
                            .buttonStyle(.bordered)
                            .disabled(coach.isChatBusy)
                            if !selectedGoal.plan.fallbackAction.isEmpty {
                                Button("Log smaller step") {
                                    _ = appState.smartGoalStore.recordFallback(goalId: selectedGoal.id)
                                }
                                .buttonStyle(.bordered)
                                .disabled(coach.isChatBusy)
                            }
                        }
                        NavigationLink("View goal") {
                            SMARTGoalDetailView(goalId: selectedGoal.id)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                planningGoal = false
                focusedGoalID = nil
                coach.dismissGoalProposal()
            } label: { Image(systemName: "xmark.circle") }
                .accessibilityLabel("Leave goal planning")
                .disabled(coach.isChatBusy)
        }
        .padding(12)
        .background(AppTheme.primary.opacity(0.08))
    }

    private func focusBanner(_ focus: CoachFocusContext) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Talking about \(focus.title)")
                    .font(.subheadline.weight(.semibold))
                if let start = focus.startDateKey, let end = focus.endDateKey {
                    Text(start == end ? DateHelpers.formatDisplayDate(start) : "\(DateHelpers.formatDisplayDate(start)) – \(DateHelpers.formatDisplayDate(end))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !focus.valueSummary.isEmpty {
                    Text(CoachFocusPresentation.spoken(focus.valueSummary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
            Button {
                self.focus = nil
            } label: { Image(systemName: "xmark.circle") }
            .accessibilityLabel("Remove this coaching context")
            .disabled(coach.isChatBusy)
        }
        .padding(12)
        .background(AppTheme.leaf.opacity(0.10))
    }

    private func goalCheckInCard(_ request: CoachGoalCheckInRequest) -> some View {
        let when = Calendar.current.isDateInToday(request.occurredAt) ? "today" : "yesterday"
        return VStack(alignment: .leading, spacing: 10) {
            Text("Log a check-in?")
                .font(.headline)
            Text("“\(request.goalTitle)” — \(when)")
                .font(.subheadline)
            if !request.note.isEmpty {
                Text(request.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Log it") {
                    coach.confirmGoalCheckIn(request, goals: appState.smartGoalStore)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                Button("Not now") { coach.dismissGoalCheckIn() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.leaf.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func goalProposalCard(_ proposal: CoachGoalProposal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(proposal.isUpdate ? "Suggested goal changes" : "Draft SMART goal")
                .font(.headline)
            if let original = proposal.edit.original {
                Text("Currently: \(original.generatedSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(proposal.edit.summary)
                .font(.subheadline)
            Text("Review the details before saving. This is a proposal, not a saved goal. Existing check-ins are kept.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Review goal") { goalEdit = proposal.edit }
                    .buttonStyle(.borderedProminent)
                Button("Dismiss") { coach.dismissGoalProposal() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var availabilityBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coach.availability.title)
                .font(.footnote.weight(.semibold))
            Text(coach.availability.guidance)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
    }

    /// A blank text field is the hardest moment in the feature — people do not
    /// know what a coach is for until they see a good question. These are built
    /// from today's real numbers, and they get out of the way once typing starts.
    @ViewBuilder
    private var suggestionRow: some View {
        let suggestions = planningGoal ? CoachGoalPlanning.starterQuestions(for: selectedGoal) : CoachPromptSuggestions.build(
            record: todayRecord,
            goals: appState.smartGoalStore.goals,
            focus: focus
        )
        if coach.availability == .available,
           !coach.isChatBusy,
           draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           pendingPhotos.isEmpty,
           !suggestions.isEmpty,
           coach.memory.openThread?.kind != .acquaintance {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            send(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.primary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 2)
        }
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let photos = pendingPhotos
        guard (!trimmed.isEmpty || !photos.isEmpty), !coach.isChatBusy, !isLoadingPhotos else { return }
        planningGoal = planningGoal || CoachGoalPlanning.isGoalConversation(
            message: trimmed, focusedGoalID: focusedGoalID, hasProposal: coach.goalProposal != nil
        )
        draft = ""
        pendingPhotos = []
        photoError = nil
        coach.beginChatSend()
        Task {
            await coach.sendChatMessage(
                trimmed,
                photoFileNames: photos.map(\.fileName),
                todayRecord: todayRecord,
                records: appState.recordStore.records,
                goals: appState.smartGoalStore.goals,
                hrvSensitivity: appState.settingsStore.hrvSensitivity,
                focusedGoalID: focusedGoalID,
                planningGoal: planningGoal,
                focus: focus,
                activities: appState.smartGoalStore.activities,
                bodyTrend: appState.bodyTrend
            )
        }
    }

    private var canSend: Bool {
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return coach.availability == .available
            && !coach.isChatBusy
            && !isLoadingPhotos
            && (hasText || !pendingPhotos.isEmpty)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !pendingPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingPhotos) { photo in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photo.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Button {
                                    CoachPhotoStore.delete(fileNames: [photo.fileName])
                                    pendingPhotos.removeAll { $0.id == photo.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.55))
                                }
                                .offset(x: 4, y: -4)
                                .accessibilityLabel("Remove photo")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
            if let photoError {
                Text(photoError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    showPhotoSource = true
                } label: {
                    if isLoadingPhotos {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 28, height: 28)
                    }
                }
                .disabled(
                    coach.isChatBusy
                        || isLoadingPhotos
                        || pendingPhotos.count >= CoachPhotoStore.maxPerMessage
                        || coach.availability != .available
                )
                .accessibilityLabel("Add a photo")

                TextField("Message your coach…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($isInputFocused)
                    .lineLimit(1...5)

                Button {
                    send(draft)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(AppTheme.primary)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func addLibraryPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        photoError = nil
        defer { isLoadingPhotos = false }
        let room = CoachPhotoStore.maxPerMessage - pendingPhotos.count
        guard room > 0 else { return }
        for item in items.prefix(room) {
            do {
                let data: Data?
                if let file = try await item.loadTransferable(type: CoachImageFile.self) {
                    data = file.data
                } else {
                    data = try await item.loadTransferable(type: Data.self)
                }
                guard let data else {
                    photoError = "That photo couldn't be read."
                    continue
                }
                addPreparedPhoto(data)
            } catch {
                photoError = "That photo couldn't be read."
            }
        }
    }

    private func addPreparedPhoto(_ data: Data) {
        let room = CoachPhotoStore.maxPerMessage - pendingPhotos.count
        guard room > 0 else { return }
        guard let jpeg = CoachPhotoPrep.jpegData(from: data), let image = UIImage(data: jpeg) else {
            photoError = "That photo couldn't be read."
            return
        }
        do {
            let name = try CoachPhotoStore.saveJPEG(jpeg)
            pendingPhotos.append(CoachPendingPhoto(id: UUID(), fileName: name, image: image))
            photoError = nil
        } catch {
            photoError = "That photo couldn't be saved."
        }
    }

    private func bubble(for turn: CoachChatTurn) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if turn.role == .user {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(turn.photoFileNames, id: \.self) { name in
                        if let url = CoachPhotoStore.fileURL(named: name),
                           let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityLabel("Photo you sent")
                        }
                    }
                    if !turn.text.isEmpty {
                        Text(turn.text)
                            .font(.body)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            } else {
                Image("DHSLifestyleCoach")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    CoachMarkdownText(text: turn.text)
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .textSelection(.enabled)
                    if turn.modelTier == .onDevice, CoachModelProvider.serverModelExists {
                        // Honest about the fallback, and specific about why.
                        Text("Answered on-device — \(turn.fallbackReason ?? "Private Cloud Compute was unavailable or at today’s limit.")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                }
                Spacer(minLength: 24)
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if coach.isChatBusy {
                withAnimation { proxy.scrollTo("pending", anchor: .bottom) }
            } else if coach.pendingGoalCheckIn != nil {
                withAnimation { proxy.scrollTo("goal-check-in", anchor: .bottom) }
            } else if coach.goalProposal != nil {
                withAnimation { proxy.scrollTo("goal-proposal", anchor: .bottom) }
            } else if let last = visibleTurns.last {
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
}

struct CoachPendingPhoto: Identifiable, Equatable {
    var id: UUID
    var fileName: String
    var image: UIImage

    static func == (lhs: CoachPendingPhoto, rhs: CoachPendingPhoto) -> Bool {
        lhs.id == rhs.id && lhs.fileName == rhs.fileName
    }
}

/// The metric sentence the app builds for the model carries status tokens;
/// people should see the same fact in plain words.
enum CoachFocusPresentation {
    static func spoken(_ sentence: String) -> String {
        sentence
            .replacingOccurrences(of: "Status: NO DATA — unlogged, not necessarily zero behavior.", with: "Unlogged so far.")
            .replacingOccurrences(of: "— BELOW GOAL by", with: "— short by")
            .replacingOccurrences(of: "— GOAL EXCEEDED by", with: "— over by")
            .replacingOccurrences(of: "— GOAL MET", with: "— goal met")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
