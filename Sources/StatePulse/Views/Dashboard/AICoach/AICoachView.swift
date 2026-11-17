import SwiftUI
import AppKit

struct AICoachView: View {
    let checkIns: [CheckInRecord]
    var onSelectTab: ((DashboardTab) -> Void)?
    var onOpenSettings: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var chatService = AIChatService.shared
    @ObservedObject private var aiCoachService = AICoachService.shared

    @State private var inputText: String = ""
    @State private var isShowingCheckIn: Bool = false
    @State private var copiedReport: Bool = false

    private var theme: AppTheme {
        themeManager.theme
    }

    private let topPromptPills = [
        "📊 Разбери мое состояние за неделю",
        "👋 Что думаешь о моем ритме?",
        "💡 Дай мне один эксперимент на сегодня",
        "🎯 Как поднять фокус на максимум?",
        "🥱 Почему я так устаю к вечеру?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()
                .background(theme.cardBorder)

            // Chat Messages Feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(chatService.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if chatService.isThinking {
                            typingIndicator
                                .id("typing_indicator")
                        }
                    }
                    .padding(20)
                }
                .onChange(of: chatService.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatService.isThinking) { _, isThinking in
                    if isThinking {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }

            Divider()
                .background(theme.cardBorder)

            // Quick Prompt Pills
            quickPillsView

            // Bottom Input Bar
            inputBarView
        }
        .background(theme.background)
        .sheet(isPresented: $isShowingCheckIn) {
            PopoverContentView(onClose: {
                isShowingCheckIn = false
            })
            .frame(width: 350, height: 490)
            .background(theme.background)
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI-Коуч StatePulse")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.textPrimary)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(aiCoachService.apiKey.isEmpty ? Color.blue : Color.purple)
                            .frame(width: 6, height: 6)

                        Text(aiCoachService.apiKey.isEmpty ? "Локальный умный режим (офлайн)" : "Google Gemini Flash")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.textSecondary)

                        if aiCoachService.apiKey.isEmpty {
                            Button("Подключить Gemini API →") {
                                onOpenSettings?()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.accent)
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    chatService.clearHistory()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Очистить чат")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.cardBackground)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Очистить историю диалога")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(theme.cardBackground)
    }

    // MARK: - Message Bubble
    @ViewBuilder
    private func messageBubble(_ msg: AIChatMessage) -> some View {
        if msg.sender == .user {
            // User Message (Right)
            HStack {
                Spacer(minLength: 40)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(msg.text)
                        .font(.system(size: 13))
                        .foregroundColor(theme.accentText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.accent)
                        )

                    Text(msg.timeFormatted)
                        .font(.system(size: 9))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                        .padding(.trailing, 4)
                }
            }
        } else {
            // Assistant Message (Left)
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundColor(theme.accent)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    // Parsed Markdown Text (bold, bullets, italics rendered properly)
                    Text(LocalizedStringKey(msg.text))
                        .font(.system(size: 13))
                        .foregroundColor(theme.textPrimary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(theme.cardBorder, lineWidth: 1)
                                )
                        )

                    // 1. Experiment Interactive Card
                    if let experiment = msg.experimentCard {
                        experimentCardView(experiment, messageId: msg.id)
                    }

                    // 2. Circadian Rhythm Interactive Card
                    if let circadian = msg.circadianCard {
                        circadianCardView(circadian, messageId: msg.id)
                    }

                    // 3. Focus Sprint Interactive Card
                    if let focus = msg.focusCard {
                        focusSprintCardView(focus, messageId: msg.id)
                    }

                    // 4. Embedded Full Stats Report
                    if msg.isStatsCard, let report = msg.statsReport {
                        statsCardView(report: report)
                    }

                    // 5. Contextual Action Pills
                    if let actions = msg.suggestedActions, !actions.isEmpty {
                        suggestedActionsView(actions)
                    }

                    Text(msg.timeFormatted)
                        .font(.system(size: 9))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                        .padding(.leading, 4)
                }

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - 🧪 Interactive Experiment Card
    @ViewBuilder
    private func experimentCardView(_ card: AIExperimentCardData, messageId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Badge
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("ПЕРСОНАЛЬНЫЙ ЭКСПЕРИМЕНТ")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.orange)
                    Text(card.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                if card.isAccepted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Принят")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            // Target metrics pill
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Текущий спад:")
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.1f/10", card.currentScore))
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)

                HStack(spacing: 4) {
                    Text("Цель:")
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.1f/10+", card.targetScore))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .font(.system(size: 11))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.background.opacity(0.6))
            .cornerRadius(8)

            // Step by Step Checklist
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(card.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(theme.accent)
                            .frame(width: 18, height: 18)
                            .background(theme.accent.opacity(0.15))
                            .clipShape(Circle())

                        Text(LocalizedStringKey(step))
                            .font(.system(size: 11.5))
                            .foregroundColor(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()
                .background(theme.cardBorder)

            // Interactive Action Buttons
            HStack(spacing: 8) {
                // Reminder Button
                if card.isReminderScheduled {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                        Text("Напоминание на \(card.reminderTime) активно")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
                } else {
                    Button(action: {
                        chatService.scheduleExperimentReminder(messageId: messageId)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.badge")
                            Text("Напомнить в \(card.reminderTime)")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.accentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Accept Challenge Button
                if !card.isAccepted {
                    Button(action: {
                        chatService.acceptExperiment(messageId: messageId)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                            Text("Принять вызов")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Check-in Button
                Button(action: {
                    isShowingCheckIn = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Чек-ин")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.cardBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    // MARK: - ☀️ Interactive Circadian Rhythm Card
    @ViewBuilder
    private func circadianCardView(_ card: AICircadianCardData, messageId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sun.horizon.fill")
                    .foregroundColor(.yellow)
                Text("СУТОЧНЫЙ БИОРИТМ СОСТОЯНИЯ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("Пик: \(card.peakWindowName)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.accent)
            }

            // 3-Phase Score Pillars
            HStack(spacing: 8) {
                // Morning
                VStack(spacing: 4) {
                    Text("☀️ Утро")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.1f", card.morningScore))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("06:00–12:00")
                        .font(.system(size: 8.5))
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.background.opacity(0.7))
                .cornerRadius(8)

                // Afternoon
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        Text("⚡️ День")
                        if card.peakWindowName.contains("День") {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.yellow)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                    Text(String(format: "%.1f", card.dayScore))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("12:00–17:00")
                        .font(.system(size: 8.5))
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.background.opacity(0.7))
                .cornerRadius(8)

                // Evening
                VStack(spacing: 4) {
                    Text("🌘 Вечер")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.1f", card.eveningScore))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(card.eveningScore < 5.5 ? .red : theme.textPrimary)
                    Text("17:00–22:00")
                        .font(.system(size: 8.5))
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.background.opacity(0.7))
                .cornerRadius(8)
            }

            if card.slumpDrop > 0.8 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .foregroundColor(.red)
                    Text("Вечерний спад ресурса: -\(String(format: "%.1f", card.slumpDrop)) балла относительно дневного пика")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }

            Divider()
                .background(theme.cardBorder)

            // Direct Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    onSelectTab?(.intraday)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Открыть «Ритм дня»")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.accentText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    sendUserMessage("Дай мне один эксперимент на сегодня")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flask")
                        Text("Подобрать эксперимент")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    // MARK: - 🎯 Interactive Focus Sprint Card
    @ViewBuilder
    private func focusSprintCardView(_ card: AIFocusSprintCardData, messageId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: "target")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("РЕЖИМ ГЛУБОКОГО ФОКУСА")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Спринт на \(card.sprintMinutes) минут")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                Text("Фокус: \(String(format: "%.1f", card.currentFocus))/10")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.background)
                    .clipShape(Capsule())
            }

            Text("Благоприятное окно концентрации: **\(card.bestWindowName)**. Закройте все лишние вкладки и посвятите спринт одной приоритетной задаче.")
                .font(.system(size: 11.5))
                .foregroundColor(theme.textSecondary)
                .lineSpacing(2)

            Divider()
                .background(theme.cardBorder)

            HStack(spacing: 8) {
                if card.isTimerStarted {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text("Таймер на \(card.sprintMinutes) мин активен! Уведомим по окончании")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
                } else {
                    Button(action: {
                        chatService.startFocusSprintTimer(messageId: messageId)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                            Text("Запустить спринт (\(card.sprintMinutes) мин)")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.accentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    isShowingCheckIn = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Оценить фокус сейчас")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    // MARK: - 📊 Embedded Stats Report Card
    @ViewBuilder
    private func statsCardView(report: AIAnalysisReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Headline
            VStack(alignment: .leading, spacing: 4) {
                Text(report.overallHeadline)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Text(report.overallSummary)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .lineSpacing(2)
            }

            Divider()
                .background(theme.cardBorder)

            // Drivers & Drains in 2 columns
            HStack(alignment: .top, spacing: 12) {
                // Drivers
                VStack(alignment: .leading, spacing: 6) {
                    Text("🚀 ДРАЙВЕРЫ")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.green)
                    ForEach(report.drivers, id: \.self) { d in
                        Text("• \(d)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Drains
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚠️ УТЕЧКИ")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.red)
                    ForEach(report.drains, id: \.self) { d in
                        Text("• \(d)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .background(theme.cardBorder)

            // Rhythm & Notes
            if !report.rhythmInsight.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("☀️ СУТОЧНЫЙ РИТМ")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.yellow)
                    Text(report.rhythmInsight)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    copyReportToClipboard(report)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedReport ? "checkmark" : "doc.on.doc")
                        Text(copiedReport ? "Скопировано!" : "Скопировать разбор")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.background)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    onSelectTab?(.overview)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Смотреть графики")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.accentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.cardBackground.opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }

    // MARK: - Suggested Follow-up Actions
    @ViewBuilder
    private func suggestedActionsView(_ actions: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(actions, id: \.self) { act in
                Button(action: {
                    sendUserMessage(act)
                }) {
                    Text(act)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(theme.cardBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(theme.accent.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(theme.accent)
            }

            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Коуч анализирует...")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.cardBackground)
            .cornerRadius(12)

            Spacer()
        }
    }

    // MARK: - Quick Pills View
    private var quickPillsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(topPromptPills, id: \.self) { pill in
                    Button(action: {
                        sendUserMessage(pill)
                    }) {
                        Text(pill)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(theme.cardBackground)
                                    .overlay(
                                        Capsule()
                                            .stroke(theme.cardBorder, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(theme.background)
    }

    // MARK: - Input Bar
    private var inputBarView: some View {
        HStack(spacing: 10) {
            TextField("Спросите что-нибудь у AI-Коуча... (Например: как поднять фокус?)", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                )
                .onSubmit {
                    sendUserMessage(inputText)
                }

            Button(action: {
                sendUserMessage(inputText)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textSecondary.opacity(0.4) : theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isThinking)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(theme.cardBackground)
    }

    private func sendUserMessage(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        inputText = ""
        Task {
            await chatService.sendMessage(clean, checkIns: checkIns)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if chatService.isThinking {
                proxy.scrollTo("typing_indicator", anchor: .bottom)
            } else if let last = chatService.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func copyReportToClipboard(_ report: AIAnalysisReport) {
        let text = """
        StatePulse — Аналитический разбор состояния
        \(report.overallHeadline)
        \(report.overallSummary)

        Драйверы:
        \(report.drivers.map { "• " + $0 }.joined(separator: "\n"))

        Утечки:
        \(report.drains.map { "• " + $0 }.joined(separator: "\n"))

        Суточный ритм:
        \(report.rhythmInsight)

        Эксперимент:
        \(report.recommendedExperiment)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedReport = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedReport = false
        }
    }
}
