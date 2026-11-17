import SwiftUI

struct AICoachView: View {
    let checkIns: [CheckInRecord]
    var onOpenSettings: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var aiCoach = AICoachService.shared

    @State private var selectedPeriod: AnalyticsPeriod = .days7
    @State private var copiedToClipboard: Bool = false

    private var theme: AppTheme {
        themeManager.theme
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.accent)

                            Text("AI-Коуч состояния")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                        }

                        Text("Нейросетевой поиск скрытых паттернов, утечек энергии и точек роста")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()

                    // Period Selector & Generate Action
                    HStack(alignment: .center, spacing: 10) {
                        HStack(spacing: 3) {
                            ForEach(AnalyticsPeriod.allCases) { period in
                                let isSelected = selectedPeriod == period
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedPeriod = period
                                    }
                                }) {
                                    Text(period.title)
                                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? theme.accent : Color.clear)
                                        )
                                        .foregroundColor(isSelected ? theme.accentText : theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(
                            Capsule()
                                .fill(theme.cardBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(theme.cardBorder, lineWidth: 1)
                                )
                        )

                        Button(action: {
                            Task {
                                await aiCoach.generateReport(checkIns: checkIns, period: selectedPeriod)
                            }
                        }) {
                            HStack(spacing: 6) {
                                if aiCoach.isGenerating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 11, weight: .semibold))
                                }

                                Text(aiCoach.isGenerating ? "Анализирую..." : "Сгенерировать разбор")
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.accent)
                            )
                            .foregroundColor(theme.accentText)
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: true)
                        .disabled(aiCoach.isGenerating || checkIns.isEmpty)
                    }
                }

                // Engine Badge & Status Banner
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(aiCoach.apiKey.isEmpty ? Color.blue : Color.purple)
                            .frame(width: 8, height: 8)

                        Text(aiCoach.apiKey.isEmpty ? "Режим: Локальный эвристический ИИ (100% офлайн)" : "Режим: Нейросеть Google Gemini Flash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textSecondary)

                        if aiCoach.apiKey.isEmpty {
                            Button("Подключить Gemini API →") {
                                onOpenSettings?()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.accent)
                        }
                    }

                    Spacer()

                    if let report = aiCoach.latestReport {
                        Text("Обновлено: \(report.formattedDate)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.cardBackground)
                .cornerRadius(8)

                if let err = aiCoach.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
                }

                // Main Report Content
                if aiCoach.isGenerating {
                    loadingShimmerCard
                } else if let report = aiCoach.latestReport {
                    reportView(report: report)
                } else {
                    emptyStateView
                }
            }
            .padding(24)
        }
    }

    // MARK: - Report Presentation View
    @ViewBuilder
    private func reportView(report: AIAnalysisReport) -> some View {
        VStack(spacing: 16) {
            // 1. Executive Summary Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("ИТОГОВЫЙ ВЫВОД", systemImage: "quote.opening")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.accent)
                        .tracking(0.6)

                    Spacer()

                    Text(report.modelName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }

                Text(report.overallHeadline)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Text(report.overallSummary)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textPrimary.opacity(0.9))
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .cornerRadius(12)

            // 2. Pillars Grid (Drivers & Drains)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                // Drivers Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                        Text("ДРАЙВЕРЫ ЭНЕРГИИ И ФОКУСА")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .tracking(0.6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.drivers, id: \.self) { driver in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                                    .padding(.top, 2)
                                Text(driver)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(nil)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)

                // Drains Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.forward.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                        Text("УТЕЧКИ И ТОЧКИ СПАДА")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                            .tracking(0.6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.drains, id: \.self) { drain in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                                    .padding(.top, 2)
                                Text(drain)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(nil)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)

                // Rhythm Pattern Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.and.horizon.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text("СУТОЧНЫЙ ЦИРКАДНЫЙ РИТМ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .tracking(0.6)
                    }

                    Text(report.rhythmInsight)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textPrimary)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
                .cornerRadius(12)

                // Notes Insight Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .foregroundColor(.purple)
                            .font(.system(size: 13))
                        Text("АНАЛИЗ ЗАМЕТОК И МЫСЛЕЙ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .tracking(0.6)
                    }

                    Text(report.notesInsight ?? "В анализируемом периоде не было подробных заметок. Добавляйте короткие заметки при чек-инах, чтобы ИИ находил скрытые триггеры.")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textPrimary)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
                .cornerRadius(12)
            }

            // 3. Recommended Experiment
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("РЕКОМЕНДОВАННЫЙ ЭКСПЕРИМЕНТ НА НЕДЕЛЮ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                        .tracking(0.6)
                }

                Text(report.recommendedExperiment)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)

            // Copy Action
            HStack {
                Spacer()

                Button(action: {
                    copyReportToClipboard(report: report)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        Text(copiedToClipboard ? "Скопировано в буфер!" : "Скопировать сводку")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.cardBackground)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Loading Shimmer
    private var loadingShimmerCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 20)

            Text("AI-Коуч изучает динамику ваших шкал, время суток и заметки...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Сопоставляем корреляции и ищем неочевидные взаимосвязи")
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(theme.accent)
                .padding(.top, 20)

            Text("Персональный нейросетевой разбор")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Text("ИИ проанализирует ваши чек-ины за выбранный период, выявит скрытые утечки энергии, определит идеальное время для сложной работы и предложит один микро-эксперимент на неделю.")
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .lineSpacing(3)

            Button(action: {
                Task {
                    await aiCoach.generateReport(checkIns: checkIns, period: selectedPeriod)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                    Text("Сгенерировать первый разбор")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.accent)
                .foregroundColor(theme.accentText)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func copyReportToClipboard(report: AIAnalysisReport) {
        var text = "### 🧠 Разбор состояния от AI-Коуча (\(report.modelName))\n"
        text += "**\(report.overallHeadline)**\n\n"
        text += "\(report.overallSummary)\n\n"
        text += "#### 🚀 Драйверы энергии:\n"
        for d in report.drivers { text += "- \(d)\n" }
        text += "\n#### ⚠️ Утечки ресурса:\n"
        for d in report.drains { text += "- \(d)\n" }
        text += "\n#### 🌅 Суточный ритм:\n\(report.rhythmInsight)\n"
        if let n = report.notesInsight {
            text += "\n#### 📝 Заметки:\n\(n)\n"
        }
        text += "\n#### 💡 Рекомендованный эксперимент:\n\(report.recommendedExperiment)\n"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        withAnimation {
            copiedToClipboard = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}
