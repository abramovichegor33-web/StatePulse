import SwiftUI

struct EditMetricSheet: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var metricManager = MetricManager.shared

    let metricToEdit: MetricDefinition?
    var onDismiss: () -> Void

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var selectedIcon: String = "sparkles"
    @State private var selectedColorHex: UInt32 = 0xC678DD

    private var theme: AppTheme {
        themeManager.theme
    }

    private var isEditing: Bool {
        metricToEdit != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(isEditing ? "Редактирование шкалы" : "Новая шкала оценки")
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

            // Name Field
            VStack(alignment: .leading, spacing: 6) {
                Text("НАЗВАНИЕ ШКАЛЫ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.5)

                TextField("Например: Уровень сна, Спорт, Дисциплина...", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                    )
            }

            // Subtitle Field
            VStack(alignment: .leading, spacing: 6) {
                Text("ПОДЗАГОЛОВОК (ОПЦИОНАЛЬНО)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.5)

                TextField("Например: Качество отдыха, Тонус...", text: $subtitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.cardBorder, lineWidth: 1)
                            )
                    )
            }

            // Icon Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("ВЫБОР ИКОНКИ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MetricDefinition.availableIcons, id: \.self) { icon in
                            let isSelected = selectedIcon == icon
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 15))
                                    .foregroundColor(isSelected ? theme.accentText : theme.textPrimary)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? theme.accent : theme.cardBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(theme.cardBorder, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Color Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("ЦВЕТ ШКАЛЫ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.5)

                HStack(spacing: 10) {
                    ForEach(MetricDefinition.availableColors, id: \.self) { colorHex in
                        let isSelected = selectedColorHex == colorHex
                        Button(action: { selectedColorHex = colorHex }) {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(theme.textPrimary, lineWidth: isSelected ? 2.5 : 0)
                                        .padding(-3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // Bottom Actions
            HStack {
                if isEditing, metricManager.metrics.count > 1 {
                    Button("Удалить шкалу") {
                        if let id = metricToEdit?.id {
                            metricManager.deleteMetric(id: id)
                        }
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.system(size: 12, weight: .medium))
                }

                Spacer()

                Button("Отмена") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Button("Сохранить") {
                    commitSave()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.accent)
                )
                .foregroundColor(theme.accentText)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 360, height: 420)
        .background(theme.background)
        .onAppear {
            if let existing = metricToEdit {
                name = existing.name
                subtitle = existing.subtitle
                selectedIcon = existing.icon
                selectedColorHex = existing.colorHex
            }
        }
    }

    private func commitSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let existing = metricToEdit {
            var updated = existing
            updated.name = trimmedName
            updated.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.icon = selectedIcon
            updated.colorHex = selectedColorHex
            metricManager.updateMetric(updated)
        } else {
            metricManager.addMetric(
                name: trimmedName,
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: selectedIcon,
                colorHex: selectedColorHex
            )
        }
        onDismiss()
    }
}
