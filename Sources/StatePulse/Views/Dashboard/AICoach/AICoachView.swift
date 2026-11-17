import SwiftUI

struct AICoachView: View {
    let checkIns: [CheckInRecord]
    var onOpenSettings: (() -> Void)?

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var chatService = AIChatService.shared
    @ObservedObject private var aiCoachService = AICoachService.shared

    @State private var inputText: String = ""

    private var theme: AppTheme {
        themeManager.theme
    }

    private let promptPills = [
        "📊 Разбери мое состояние за неделю",
        "🥱 Почему я так устаю к вечеру?",
        "🎯 Как поднять фокус на максимум?",
        "💡 Дай мне один эксперимент на сегодня",
        "👋 Что думаешь о моем ритме?"
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
                    LazyVStack(spacing: 16) {
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
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accent)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(msg.text)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textPrimary)
                        .lineSpacing(3)
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

                    // If stats card was requested
                    if msg.isStatsCard, let report = msg.statsReport {
                        statsCardView(report: report)
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

    // MARK: - Embedded Stats Report Card
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

            // Experiment
            VStack(alignment: .leading, spacing: 4) {
                Text("💡 ЭКСПЕРИМЕНТ НА НЕДЕЛЮ")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.yellow)
                Text(report.recommendedExperiment)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(theme.textPrimary)
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
                Text("Коуч думает...")
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
                ForEach(promptPills, id: \.self) { pill in
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
            TextField("Спросите что-нибудь у AI-Коуча... (Например: почему я устаю? или разбери неделю)", text: $inputText)
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
}
