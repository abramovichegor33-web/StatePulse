import SwiftUI

struct QuickPreset: Identifiable, Equatable {
    let id: String
    let icon: String
    let label: String
    let baseScore: Int
    let bodyScore: Int
    let mindScore: Int
    let focusScore: Int
    let tag: String?
}

private let quickPresets: [QuickPreset] = [
    QuickPreset(id: "flow", icon: "⚡️", label: "В потоке", baseScore: 9, bodyScore: 9, mindScore: 9, focusScore: 9, tag: "Результат"),
    QuickPreset(id: "normal", icon: "☕️", label: "В норме", baseScore: 7, bodyScore: 7, mindScore: 7, focusScore: 7, tag: nil),
    QuickPreset(id: "tired", icon: "🥱", label: "Устал", baseScore: 3, bodyScore: 3, mindScore: 4, focusScore: 3, tag: "Недосып"),
    QuickPreset(id: "chill", icon: "🎮", label: "Отдых", baseScore: 7, bodyScore: 8, mindScore: 8, focusScore: 4, tag: "Отдых")
]

struct PopoverContentView: View {
    var onClose: (() -> Void)?
    var onOpenDashboard: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var passiveTracker = PassiveTrackerService.shared
    @ObservedObject private var metricManager = MetricManager.shared
    @ObservedObject private var panelController = MenuBarPanelController.shared

    @State private var scores: [String: Int] = [:]
    @State private var selectedTags: Set<String> = []
    @State private var note: String = ""

    @State private var selectedPhase: TimeOfDayPhase = TimeOfDayPhase.current()
    @State private var todayCheckIns: [CheckInRecord] = []
    @State private var selectedPresetId: String? = nil

    @State private var isSavedAnimation: Bool = false
    @State private var currentStreak: Int = 0

    @State private var editingMetric: MetricDefinition? = nil
    @State private var isAddingNewMetric: Bool = false

    private var theme: AppTheme {
        themeManager.theme
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        let str = formatter.string(from: Date())
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    var body: some View {
        VStack(spacing: 9) {
            // Header Bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("StatePulse")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)

                        if currentStreak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text("\(currentStreak) дн")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }

                    Text(currentDateFormatted)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                // Passive Screen Time Indicator (if available)
                if passiveTracker.getCurrentActiveSeconds() > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "display")
                            .font(.system(size: 9))
                        Text(passiveTracker.formattedScreenTime)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.cardBackground)
                    .cornerRadius(5)
                }
            }

            // Phase of Day Selector & Milestone dots
            HStack(spacing: 4) {
                ForEach(TimeOfDayPhase.allCases) { phase in
                    let isSelected = selectedPhase == phase
                    let countInPhase = todayCheckIns.filter { $0.phase == phase }.count

                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                            selectedPhase = phase
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: phase.icon)
                                .font(.system(size: 8))
                                .foregroundColor(isSelected ? theme.accentText : phase.color)
                            Text(phase.title)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))

                            if countInPhase > 0 {
                                Circle()
                                    .fill(isSelected ? theme.accentText : phase.color)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? theme.accent : theme.cardBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : theme.cardBorder, lineWidth: 0.8)
                                )
                        )
                        .foregroundColor(isSelected ? theme.accentText : theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Quick Presets (1-Click State)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("БЫСТРЫЙ ЧЕК-ИН")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .tracking(0.6)

                    Spacer()

                    if let selectedId = selectedPresetId,
                       let p = quickPresets.first(where: { $0.id == selectedId }) {
                        Text("«\(p.label)» выбран • ⏎ для сохранения")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundColor(theme.accent)
                    } else {
                        Text("кликните дважды для мгновенного сохранения")
                            .font(.system(size: 8.5))
                            .foregroundColor(theme.textSecondary.opacity(0.7))
                    }
                }

                HStack(spacing: 5) {
                    ForEach(quickPresets) { preset in
                        let isSelected = selectedPresetId == preset.id

                        Button(action: {
                            if selectedPresetId == preset.id {
                                applyPreset(preset, instantSave: true)
                            } else {
                                applyPreset(preset, instantSave: false)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Text(preset.icon)
                                    .font(.system(size: 10))
                                Text(preset.label)
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? theme.accent.opacity(0.18) : theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? theme.accent : theme.cardBorder, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(isSelected ? theme.accent : theme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()
                .background(theme.cardBorder)

            // Dynamic Sliders Section Header
            HStack {
                Text("ПОКАЗАТЕЛИ СОСТОЯНИЯ")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.6)

                Spacer()

                Button(action: {
                    isAddingNewMetric = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Шкала")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Sliders Container (Scrollable if > 3 metrics)
            if metricManager.metrics.count > 3 {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(metricManager.metrics) { metric in
                            sliderRow(for: metric)
                        }
                    }
                }
                .frame(maxHeight: 195)
                .contentShape(Rectangle())
                .contextMenu {
                    slidersContextMenu
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(metricManager.metrics) { metric in
                        sliderRow(for: metric)
                    }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    slidersContextMenu
                }
            }

            // Context Tags
            TagChipsView(selectedTags: $selectedTags)

            // Quick Note Field
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("ЗАМЕТКА")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .tracking(0.6)
                    Spacer()
                }

                TextField("Мысли, ключевое событие или инсайт...", text: $note)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                    )
            }

            // Bottom Action Bar
            HStack(spacing: 8) {
                // Dashboard Button
                Button(action: {
                    onOpenDashboard?()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 11, weight: .medium))
                        Text("Аналитика")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(theme.textPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                // Save Check-in Button
                Button(action: saveCheckIn) {
                    HStack(spacing: 5) {
                        if isSavedAnimation {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Сохранено!")
                                .font(.system(size: 12, weight: .semibold))
                        } else {
                            let label: String = {
                                if let id = selectedPresetId, let p = quickPresets.first(where: { $0.id == id }) {
                                    return "Сохранить «\(p.label)»"
                                }
                                return "Сохранить"
                            }()
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .foregroundColor(theme.accentText)
                    .frame(minWidth: 110)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSavedAnimation ? Color.green : theme.accent)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(isSavedAnimation)
            }
            .padding(.top, 2)
        }
        .padding(13)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .opacity(panelController.isShowingCard ? 1.0 : 0.05)
        .offset(y: panelController.isShowingCard ? 0 : -8)
        .scaleEffect(panelController.isShowingCard ? 1.0 : 0.98)
        .sheet(item: $editingMetric) { metric in
            EditMetricSheet(metricToEdit: metric) {
                editingMetric = nil
            }
        }
        .sheet(isPresented: $isAddingNewMetric) {
            EditMetricSheet(metricToEdit: nil) {
                isAddingNewMetric = false
            }
        }
        .onAppear {
            refreshStreak()
            initializeDefaultScores()
            loadTodayCheckIns()
            selectedPhase = TimeOfDayPhase.current()
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseDidChange)) { _ in
            refreshStreak()
            loadTodayCheckIns()
        }
        .onChange(of: panelController.isShowingCard) { _, isShowing in
            if isShowing {
                refreshStreak()
                loadTodayCheckIns()
                selectedPhase = TimeOfDayPhase.current()
            }
        }
    }

    @ViewBuilder
    private func sliderRow(for metric: MetricDefinition) -> some View {
        CustomSliderView(
            metric: metric,
            value: Binding(
                get: { scores[metric.id] ?? 7 },
                set: {
                    scores[metric.id] = $0
                    selectedPresetId = nil
                }
            ),
            onEdit: {
                editingMetric = metric
            },
            onDelete: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    metricManager.deleteMetric(id: metric.id)
                }
            },
            onAddNew: {
                isAddingNewMetric = true
            },
            onResetToDefault: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    metricManager.resetToDefault()
                }
            }
        )
    }

    @ViewBuilder
    private var slidersContextMenu: some View {
        Button {
            isAddingNewMetric = true
        } label: {
            Label("Добавить новую шкалу...", systemImage: "plus")
        }

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                metricManager.resetToDefault()
            }
        } label: {
            Label("Восстановить стандартные шкалы", systemImage: "arrow.counterclockwise")
        }
    }

    private func initializeDefaultScores() {
        for metric in metricManager.metrics {
            if scores[metric.id] == nil {
                scores[metric.id] = 7
            }
        }
    }

    private func refreshStreak() {
        let records = DatabaseManager.shared.fetchAllCheckIns()
        currentStreak = AnalyticsEngine.shared.calculateStreak(records: records)
    }

    private func loadTodayCheckIns() {
        let calendar = Calendar.current
        let all = DatabaseManager.shared.fetchAllCheckIns()
        todayCheckIns = all.filter { calendar.isDateInToday($0.timestamp) }.sorted(by: { $0.timestamp < $1.timestamp })
    }

    private func saveCheckIn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isSavedAnimation = true
        }

        var finalScores = scores
        for metric in metricManager.metrics {
            if finalScores[metric.id] == nil {
                finalScores[metric.id] = 7
            }
        }

        var recordTimestamp = Date()
        let currentPhase = TimeOfDayPhase.current()
        if selectedPhase != currentPhase {
            let calendar = Calendar.current
            var targetHour = 10
            switch selectedPhase {
            case .morning: targetHour = 9
            case .afternoon: targetHour = 14
            case .evening: targetHour = 19
            case .night: targetHour = 23
            }
            recordTimestamp = calendar.date(bySettingHour: targetHour, minute: 0, second: 0, of: Date()) ?? Date()
        }

        let record = CheckInRecord(
            id: UUID(),
            timestamp: recordTimestamp,
            metricScores: finalScores,
            tags: Array(selectedTags),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            screenTimeSeconds: passiveTracker.getCurrentActiveSeconds()
        )

        DatabaseManager.shared.saveCheckIn(record)
        refreshStreak()
        loadTodayCheckIns()

        note = ""
        selectedPresetId = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isSavedAnimation = false
            onClose?()
        }
    }

    private func applyPreset(_ preset: QuickPreset, instantSave: Bool = false) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            selectedPresetId = preset.id
            scores["body"] = preset.bodyScore
            scores["mind"] = preset.mindScore
            scores["focus"] = preset.focusScore
            for metric in metricManager.metrics {
                if metric.id != "body" && metric.id != "mind" && metric.id != "focus" {
                    scores[metric.id] = preset.baseScore
                }
            }
            if let tag = preset.tag {
                selectedTags.insert(tag)
            }
        }
        if instantSave {
            saveCheckIn()
        }
    }
}
