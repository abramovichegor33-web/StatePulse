import SwiftUI

struct EditCheckInSheet: View {
    @Binding var record: CheckInRecord
    var onSave: (CheckInRecord) -> Void
    var onCancel: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var metricManager = MetricManager.shared

    @State private var scores: [String: Int] = [:]
    @State private var selectedTags: Set<String> = []
    @State private var note: String = ""

    private var theme: AppTheme {
        themeManager.theme
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Редактирование чек-ина")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Text(record.formattedDateDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }

            Divider()

            // Dynamic Sliders
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(metricManager.metrics) { metric in
                        CustomSliderView(
                            metric: metric,
                            value: Binding(
                                get: { scores[metric.id] ?? record.score(for: metric.id) },
                                set: { scores[metric.id] = $0 }
                            )
                        )
                    }
                }
            }
            .frame(maxHeight: 260)

            // Tags
            TagChipsView(selectedTags: $selectedTags)

            // Note
            VStack(alignment: .leading, spacing: 4) {
                Text("ЗАМЕТКА")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .tracking(0.6)

                TextField("Заметка...", text: $note)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
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

            Spacer()

            // Action Buttons
            HStack(spacing: 10) {
                Button("Отмена") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Spacer()

                Button("Сохранить изменения") {
                    var updated = record
                    updated.metricScores = scores
                    updated.tags = Array(selectedTags)
                    updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(updated)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.accentText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.accent)
                )
            }
        }
        .padding(20)
        .frame(width: 420, height: 580)
        .background(theme.background)
        .onAppear {
            scores = record.metricScores
            // Ensure all current metrics have a score
            for metric in metricManager.metrics {
                if scores[metric.id] == nil {
                    scores[metric.id] = record.score(for: metric.id)
                }
            }
            selectedTags = Set(record.tags)
            note = record.note
        }
    }
}
