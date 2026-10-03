import SwiftUI

/// One day's food-group log. Closing without Save leaves the day unchanged.
struct FoodGroupLogSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var allowsDateChange: Bool

    @State private var dateKey: String
    @State private var servings = FoodGroupServings.empty
    @State private var infoGroup: FoodGroup?
    @State private var showRemoveConfirm = false

    init(dateKey: String, allowsDateChange: Bool = false) {
        self.allowsDateChange = allowsDateChange
        _dateKey = State(initialValue: dateKey)
    }

    private var isToday: Bool { dateKey == DateHelpers.localDateKey() }

    private var savedServings: FoodGroupServings {
        appState.recordStore.records.first { $0.date == dateKey }?.foodGroups ?? .empty
    }

    private var previewScore: Double {
        FoodGroupScore.previewPoints(servings)
    }

    private var oneColumn: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if allowsDateChange {
                        DatePicker(
                            "Date",
                            selection: dateBinding,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }

                    scoreHeader

                    if oneColumn {
                        ForEach(FoodGroup.allCases.filter(\.isEatMore)) { group in
                            tile(group)
                        }
                    } else {
                        tile(.vegetables)
                        HStack(alignment: .top, spacing: 12) {
                            tile(.fruit)
                            tile(.wholeGrains)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            tile(.legumesNuts)
                            tile(.fish)
                        }
                    }

                    limitRow

                    Button {
                        appState.saveFoodGroupLog(date: dateKey, servings: servings)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.leaf)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if savedServings.isLogged {
                        Button("Remove log", role: .destructive) {
                            showRemoveConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(isToday ? "Today" : DateHelpers.formatDisplayDate(dateKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { load(dateKey) }
            .sheet(item: $infoGroup) { group in
                FoodGroupInfoSheet(group: group)
            }
            .alert("Remove this log?", isPresented: $showRemoveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    appState.clearFoodGroupLog(date: dateKey)
                    dismiss()
                }
            } message: {
                Text("This day goes back to not logged. Apple Health fiber grams stay.")
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { DateHelpers.date(from: dateKey) ?? Date() },
            set: { newDate in
                let key = DateHelpers.localDateKey(from: newDate)
                dateKey = key
                load(key)
            }
        )
    }

    private var scoreHeader: some View {
        HStack(spacing: 16) {
            NutritionScoreRing(score: previewScore)
            VStack(alignment: .leading, spacing: 4) {
                Text("Food groups")
                    .font(.headline)
                Text("\(ScoreCalculator.formatDisplayScore(previewScore)) / 4")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("Whole servings. Past Full still counts, and it does not add points.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ group: FoodGroup) -> some View {
        FoodGroupTile(
            group: group,
            count: binding(for: group),
            onInfo: { infoGroup = group }
        )
    }

    private var limitRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            FoodGroupTile(
                group: .limited,
                count: binding(for: .limited),
                onInfo: { infoGroup = .limited },
                calm: true
            )
            if servings.limited == 0 {
                Text("These points stay until you log one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func binding(for group: FoodGroup) -> Binding<Int> {
        Binding(
            get: { servings[group] },
            set: { servings[group] = $0 }
        )
    }

    private func load(_ key: String) {
        servings = appState.recordStore.records.first { $0.date == key }?.foodGroups ?? .empty
    }
}

private struct NutritionScoreRing: View {
    let score: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.leaf.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score / 4, 0), 1)))
                .stroke(AppTheme.leaf, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(ScoreCalculator.formatDisplayScore(score))
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
        .frame(width: 72, height: 72)
        .accessibilityLabel("Food groups \(ScoreCalculator.formatDisplayScore(score)) of 4")
    }
}

private struct FoodGroupTile: View {
    let group: FoodGroup
    @Binding var count: Int
    var onInfo: () -> Void
    var calm: Bool = false

    private var tint: Color { calm ? AppTheme.primary : AppTheme.leaf }

    private var fill: Double { FoodGroupScore.groupFill(count, group: group) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                FoodGroupIcon(group: group)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(group.hint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About \(group.title)")
            }

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                stepButton(systemName: "minus", delta: -1)
                Text(FoodGroupScore.tileLabel(count: count, group: group))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: 52)
                stepButton(systemName: "plus", delta: 1)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityName)
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { direction in
                if direction == .increment {
                    count = min(count + 1, FoodGroupServings.maxCount)
                } else {
                    count = max(count - 1, 0)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
    }

    private var accessibilityName: String { group.title }

    private var accessibilityValue: String {
        if group == .limited {
            let noun = count == 1 ? "serving" : "servings"
            return "\(count) \(noun)"
        }
        return "\(count) of \(group.target) servings"
    }

    private func stepButton(systemName: String, delta: Int) -> some View {
        Button {
            count = min(max(count + delta, 0), FoodGroupServings.maxCount)
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14))
                .foregroundStyle(tint)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Add a \(group.title) serving" : "Remove a \(group.title) serving")
    }
}

private struct FoodGroupInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: FoodGroup

    private var guide: FoodGroupGuide { group.guide }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        FoodGroupIcon(group: group)
                            .frame(width: 76, height: 76)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title)
                                .font(.title3.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(guide.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    infoCard(title: "One serving") {
                        Text(guide.serving)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    infoCard(title: "What counts") {
                        bulletList(guide.counts, mark: "checkmark.circle.fill", tint: AppTheme.leaf)
                    }

                    infoCard(title: "What does not count") {
                        bulletList(guide.doesNotCount, mark: "minus.circle.fill", tint: AppTheme.primary)
                    }

                    if let note = guide.note {
                        Text(note)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.leaf.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Text("Drawn from the American Heart Association’s dietary guidance and the Dietary Guidelines for Americans, 2025–2030. A logging aid, not personal medical advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("About this group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func infoCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func bulletList(_ lines: [String], mark: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: mark)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
