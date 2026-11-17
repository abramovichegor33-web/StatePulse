import SwiftUI

struct EditPresetSheet: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var metricManager = MetricManager.shared
    @ObservedObject private var presetManager = PresetManager.shared

    let presetToEdit: QuickPreset
    var onDismiss: () -> Void

    @State private var label: String = ""
    @State private var selectedIcon: String = "⚡️"
    @State private var scores: [String: Int] = [:]
    @State private var tag: String = ""

    private var theme: AppTheme {
        themeManager.theme
    }

    private let commonTags = ["Результат", "В норме", "Недосып", "Отдых", "Много работы", "Стресс", "Тренировка"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Настройка пресета")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Preset Name & Icon
                    VStack(alignment: .leading, spacing: 6) {
                        Text("НАЗВАНИЕ И ИКОНКА")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            // Icon Preview & Input
                            TextField("Иконка", text: $selectedIcon)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .frame(width: 44, height: 32)
                                .multilineTextAlignment(.center)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(theme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(theme.cardBorder, lineWidth: 1)
                                        )
                                )

                            // Label Field
                            TextField("Например: В потоке, Устал, Отдых...", text: $label)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(theme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(theme.cardBorder, lineWidth: 1)
                                        )
                                )
                        }

                        // Available Emojis
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(QuickPreset.availableIcons, id: \.self) { emoji in
                                    let isSelected = selectedIcon == emoji
                                    Button(action: { selectedIcon = emoji }) {
                                        Text(emoji)
                                            .font(.system(size: 14))
                                            .frame(width: 28, height: 28)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(isSelected ? theme.accent.opacity(0.2) : theme.cardBackground)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(isSelected ? theme.accent : theme.cardBorder, lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Divider()

                    // 2. Positions / Scores for this preset
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("ЗНАЧЕНИЯ ШКАЛ ПРИ ВЫБОРЕ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.textSecondary)
                                .tracking(0.5)
                            Spacer()
                            Text("1...10 баллов")
                                .font(.system(size: 9))
                                .foregroundColor(theme.textSecondary)
                        }

                        ForEach(metricManager.metrics) { metric in
                            let currentVal = scores[metric.id] ?? 7

                            VStack(spacing: 4) {
                                HStack {
                                    HStack(spacing: 5) {
                                        Image(systemName: metric.icon)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(metric.color)
                                        Text(metric.name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(theme.textPrimary)
                                    }

                                    Spacer()

                                    Text("\(currentVal)/10")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(metric.color)
                                }

                                // 1..10 Segmented selector
                                HStack(spacing: 3) {
                                    ForEach(1...10, id: \.self) { num in
                                        let isSelected = num == currentVal
                                        let isFilled = num <= currentVal

                                        Button(action: {
                                            scores[metric.id] = num
                                        }) {
                                            Text("\(num)")
                                                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 20)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(isFilled ? metric.color.opacity(isSelected ? 0.95 : 0.4) : theme.cardBackground)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 4)
                                                                .stroke(isSelected ? Color.white.opacity(0.8) : theme.cardBorder.opacity(0.5), lineWidth: 1)
                                                        )
                                                )
                                                .foregroundColor(isFilled ? Color.white : theme.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.cardBackground.opacity(0.6))
                            )
                        }
                    }

                    Divider()

                    // 3. Tag Binding (Optional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ПРИВЯЗАННЫЙ ТЕГ (ОПЦИОНАЛЬНО)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                            .tracking(0.5)

                        TextField("Тег (например: Результат, Недосып...)", text: $tag)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(theme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(theme.cardBorder, lineWidth: 1)
                                    )
                            )

                        // Quick tag suggestions
                        HStack(spacing: 4) {
                            ForEach(commonTags, id: \.self) { t in
                                let isSelected = tag == t
                                Button(action: {
                                    tag = (tag == t) ? "" : t
                                }) {
                                    Text(t)
                                        .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(isSelected ? theme.accent.opacity(0.25) : theme.cardBackground)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 5)
                                                        .stroke(isSelected ? theme.accent : theme.cardBorder, lineWidth: 0.8)
                                                )
                                        )
                                        .foregroundColor(isSelected ? theme.accent : theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Отмена") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)

                Spacer()

                Button(action: savePreset) {
                    Text("Сохранить пресет")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.accent)
                        )
                        .foregroundColor(theme.accentText)
                }
                .buttonStyle(.plain)
                .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380, height: 480)
        .background(theme.background)
        .onAppear {
            label = presetToEdit.label
            selectedIcon = presetToEdit.icon
            tag = presetToEdit.tag ?? ""

            // Initialize scores
            var loadedScores: [String: Int] = [:]
            loadedScores["body"] = presetToEdit.bodyScore
            loadedScores["mind"] = presetToEdit.mindScore
            loadedScores["focus"] = presetToEdit.focusScore

            if let custom = presetToEdit.customScores {
                for (k, v) in custom {
                    loadedScores[k] = v
                }
            }

            for metric in metricManager.metrics {
                if loadedScores[metric.id] == nil {
                    loadedScores[metric.id] = 7
                }
            }

            scores = loadedScores
        }
    }

    private func savePreset() {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLabel.isEmpty else { return }

        var updated = presetToEdit
        updated.label = cleanLabel
        updated.icon = selectedIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "⚡️" : selectedIcon
        updated.bodyScore = scores["body"] ?? 7
        updated.mindScore = scores["mind"] ?? 7
        updated.focusScore = scores["focus"] ?? 7

        var customMap: [String: Int] = [:]
        for metric in metricManager.metrics {
            if metric.id != "body" && metric.id != "mind" && metric.id != "focus" {
                customMap[metric.id] = scores[metric.id] ?? 7
            }
        }
        updated.customScores = customMap.isEmpty ? nil : customMap

        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tag = cleanTag.isEmpty ? nil : cleanTag

        presetManager.updatePreset(updated)
        onDismiss()
    }
}
