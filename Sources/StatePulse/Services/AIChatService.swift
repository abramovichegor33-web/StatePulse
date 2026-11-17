import Foundation
import SwiftUI
import AppKit

@MainActor
final class AIChatService: ObservableObject {
    static let shared = AIChatService()

    @Published var messages: [AIChatMessage] = []
    @Published var isThinking: Bool = false

    private let chatStorageKey = "statepulse_ai_chat_history_v1"

    private init() {
        loadHistory()
        if messages.isEmpty {
            addInitialGreeting()
        }
    }

    private func addInitialGreeting() {
        let greeting = AIChatMessage(
            sender: .assistant,
            text: "Привет! Я твой персональный AI-Коуч StatePulse. Я помогаю находить скрытые паттерны усталости, настраивать биоритмы и запускать микро-эксперименты.\n\nЗадай вопрос или нажми на одну из карточек действий ниже:",
            timestamp: Date(),
            suggestedActions: [
                "📊 Разбери мое состояние за неделю",
                "👋 Что думаешь о моем ритме?",
                "💡 Дай мне один эксперимент на сегодня",
                "🎯 Как поднять фокус на максимум?"
            ]
        )
        messages.append(greeting)
        saveHistory()
    }

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: chatStorageKey),
           let saved = try? JSONDecoder().decode([AIChatMessage].self, from: data) {
            messages = saved
        }
    }

    func saveHistory() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: chatStorageKey)
        }
    }

    func clearHistory() {
        messages = []
        addInitialGreeting()
    }

    // MARK: - Interactive Actions
    func acceptExperiment(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }), messages[idx].experimentCard != nil {
            messages[idx].experimentCard?.isAccepted = true
            saveHistory()
            NSSound(named: "Glass")?.play()
        }
    }

    func scheduleExperimentReminder(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }),
           let card = messages[idx].experimentCard {
            NotificationService.shared.scheduleOneShotReminder(
                hour: card.reminderHour,
                minute: card.reminderMinute,
                title: "StatePulse: Эксперимент «\(card.title)»",
                body: "Время начать: \(card.steps.first ?? "сделайте паузу для отдыха")"
            )
            messages[idx].experimentCard?.isReminderScheduled = true
            saveHistory()
            NSSound(named: "Hero")?.play()
        }
    }

    func startFocusSprintTimer(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }),
           let card = messages[idx].focusCard {
            NotificationService.shared.scheduleSprintTimer(minutes: card.sprintMinutes)
            messages[idx].focusCard?.isTimerStarted = true
            saveHistory()
            NSSound(named: "Hero")?.play()
        }
    }

    // MARK: - Sending Messages
    func sendMessage(_ userText: String, checkIns: [CheckInRecord]) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. Add user message
        let userMsg = AIChatMessage(sender: .user, text: trimmed, timestamp: Date())
        messages.append(userMsg)
        saveHistory()

        isThinking = true

        let lower = trimmed.lowercased()

        // 2. Check if user explicitly asked for a full stats / debrief report
        if isStatsIntent(lower) {
            await AICoachService.shared.generateReport(checkIns: checkIns, period: .days7)
            if let report = AICoachService.shared.latestReport {
                let intro = "Я подготовил твой полный персональный разбор состояния на основе \(checkIns.count) чек-инов.\n\nНиже наглядная сводка ключевых драйверов, утечек и циркадного ритма 👇"
                let reportMsg = AIChatMessage(
                    sender: .assistant,
                    text: intro,
                    timestamp: Date(),
                    isStatsCard: true,
                    statsReport: report,
                    suggestedActions: [
                        "💡 Дай мне один эксперимент на сегодня",
                        "👋 Что думаешь о моем ритме?"
                    ]
                )
                messages.append(reportMsg)
                saveHistory()
                isThinking = false
                return
            }
        }

        // 3. If Gemini API Key is configured -> call neural LLM in conversational mode
        let apiKey = AICoachService.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            do {
                let aiResponseText = try await callGeminiChat(prompt: trimmed, checkIns: checkIns, apiKey: apiKey)
                let assistantMsg = AIChatMessage(sender: .assistant, text: aiResponseText, timestamp: Date())
                messages.append(assistantMsg)
                saveHistory()
                isThinking = false
                return
            } catch {
                print("Gemini chat error: \(error.localizedDescription). Falling back to local smart engine.")
            }
        }

        // 4. Local Smart Conversational Coach (100% Offline with Deep Personal Data Context)
        try? await Task.sleep(nanoseconds: 350_000_000)
        let assistantMsg = generateSmartAssistantMessage(for: trimmed, checkIns: checkIns)
        messages.append(assistantMsg)
        saveHistory()
        isThinking = false
    }

    // MARK: - Intent Recognition
    private func isStatsIntent(_ lower: String) -> Bool {
        let stems = [
            "разбор", "разбер", "разобр", "итог", "сводк", "отчет", "отчёт",
            "статистик", "график", "данны", "анализ", "недел", "покажи все",
            "полный отчет", "сгенерир", "по цифрам"
        ]
        return stems.contains(where: { lower.contains($0) })
    }

    // MARK: - Smart Local Assistant Message Generator
    private func generateSmartAssistantMessage(for userText: String, checkIns: [CheckInRecord]) -> AIChatMessage {
        let lower = userText.lowercased()

        let total = max(1, checkIns.count)
        let bodyAvg = checkIns.reduce(0.0) { $0 + Double($1.bodyEnergy) } / Double(total)
        let mindAvg = checkIns.reduce(0.0) { $0 + Double($1.mentalResource) } / Double(total)
        let focusAvg = checkIns.reduce(0.0) { $0 + Double($1.focus) } / Double(total)
        let composite = (bodyAvg + mindAvg + focusAvg) / 3.0

        // Intraday phase breakdown
        let morningRecords = checkIns.filter { $0.phase == .morning }
        let afternoonRecords = checkIns.filter { $0.phase == .afternoon }
        let eveningRecords = checkIns.filter { $0.phase == .evening }

        let mAvg = morningRecords.isEmpty ? composite : morningRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(morningRecords.count)
        let aAvg = afternoonRecords.isEmpty ? composite : afternoonRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(afternoonRecords.count)
        let eAvg = eveningRecords.isEmpty ? composite : eveningRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(eveningRecords.count)

        let streak = AnalyticsEngine.shared.calculateStreak(records: checkIns)
        let insights = AnalyticsEngine.shared.generateInsights(records: checkIns)
        let positiveTag = insights.first(where: { $0.category == .positive })
        let negativeTag = insights.first(where: { $0.category == .negative })

        let recentNotes = checkIns.compactMap { $0.note.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // --- 0. Meta / Humor / Bot Identity ---
        if containsAny(lower, stems: ["туп", "глуп", "дурак", "бот", "кто ты", "зачем ты", "что умеешь", "бесишь", "херн", "фигн"]) {
            let reply = "Я работаю прямо на твоем Mac в 100% локальном и автономном режиме без сторонних серверов, анализируя реальные математические метрики твоих \(checkIns.count) записей.\n\nЕсли ты хочешь свободные рассуждения большой нейросети — вставь ключ Gemini API в Настройках (это бесплатно), и я переключусь на модель Google Gemini Flash.\n\nНо и прямо здесь я знаю твои ключевые паттерны: дневной пик в районе **\(String(format: "%.1f", max(mAvg, aAvg)))/10**, вечерний спад до **\(String(format: "%.1f", eAvg))/10** и серию **\(streak) дн.**"
            return AIChatMessage(
                sender: .assistant,
                text: reply,
                timestamp: Date(),
                suggestedActions: ["👋 Что думаешь о моем ритме?", "💡 Дай мне один эксперимент на сегодня"]
            )
        }

        // --- 1. Experiment & Biohack ---
        if containsAny(lower, stems: ["эксперимент", "совет", "посовет", "что делать", "рекомендац", "помоги", "лайфхак", "привычк", "план", "как улучшить", "как поднять", "что предпринять"]) {
            let experimentTitle: String
            let goalText: String
            let targetScore: Double
            let currentScore: Double
            let steps: [String]
            let reminderHour: Int
            let reminderMin: Int
            let reminderTime: String

            if eAvg < 5.5 {
                experimentTitle = "Цифровой буфер в 17:30"
                goalText = "Сгладить вечерний спад ресурса с \(String(format: "%.1f", eAvg)) до 6.0+"
                currentScore = eAvg
                targetScore = 6.0
                reminderHour = 17
                reminderMin = 30
                reminderTime = "17:30"
                steps = [
                    "За 30 минут до конца рабочего дня (в 17:30) закрыть все рабочие вкладки и чаты.",
                    "Сделать 10 минут физической разгрузки (прогулка, душ, вода или растяжка).",
                    "Зафиксировать вечернее самочувствие в StatePulse."
                ]
            } else if bodyAvg < 6.0 {
                experimentTitle = "Утренний гидрант и разминка"
                goalText = "Вывести утренний тонус тела с \(String(format: "%.1f", bodyAvg)) до 7.0+"
                currentScore = bodyAvg
                targetScore = 7.0
                reminderHour = 8
                reminderMin = 0
                reminderTime = "08:00"
                steps = [
                    "Первые 30 минут после пробуждения провести без экрана смартфона.",
                    "Выпить 400 мл воды комнатной температуры и сделать 3 минуты разминки.",
                    "Отметить самочувствие тела в первом утреннем чек-ине."
                ]
            } else {
                experimentTitle = "Спринт монофокуса до полудня"
                goalText = "Увеличить средний фокус с \(String(format: "%.1f", focusAvg)) до 8.0+"
                currentScore = focusAvg
                targetScore = 8.0
                reminderHour = 10
                reminderMin = 30
                reminderTime = "10:30"
                steps = [
                    "Выбрать ровно одну главную задачу до полудня.",
                    "Поставить 45-минутный таймер непрерывного фокуса без отвлечений на мессенджеры.",
                    "Сделать 10 минут честного отдыха без гаджетов."
                ]
            }

            let card = AIExperimentCardData(
                title: experimentTitle,
                goal: goalText,
                currentScore: currentScore,
                targetScore: targetScore,
                steps: steps,
                reminderTime: reminderTime,
                reminderHour: reminderHour,
                reminderMinute: reminderMin
            )

            return AIChatMessage(
                sender: .assistant,
                text: "Вот твой персонализированный микро-эксперимент на сегодня. Он устраняет твое главное узкое место. Нажми «Поставить напоминание» или «Принять челлендж» прямо в карточке 👇",
                timestamp: Date(),
                experimentCard: card,
                suggestedActions: ["👋 Что думаешь о моем ритме?", "📊 Разбери мое состояние за неделю"]
            )
        }

        // --- 2. Circadian Rhythm / Time of Day ---
        if containsAny(lower, stems: ["ритм", "циркад", "биоритм", "время", "часы", "утр", "вечер", "ноч", "дневн", "пик", "спад", "распорядок", "график"]) {
            let peakName = (mAvg >= aAvg && mAvg >= eAvg) ? "Утро (06:00–12:00)" : "День (12:00–17:00)"
            let slumpDrop = max(0, max(mAvg, aAvg) - eAvg)

            let card = AICircadianCardData(
                morningScore: mAvg,
                dayScore: aAvg,
                eveningScore: eAvg,
                peakWindowName: peakName,
                slumpDrop: slumpDrop,
                mainLeakTag: negativeTag?.title
            )

            return AIChatMessage(
                sender: .assistant,
                text: "По твоим \(checkIns.count) чек-инам суточный ритм имеет выраженный пик в окно **\(peakName)** (\(String(format: "%.1f", max(mAvg, aAvg)))/10) и спад к вечеру на **\(String(format: "%.1f", slumpDrop)) балла**.\n\nНиже наглядная карта суточного ритма с кнопками действий 👇",
                timestamp: Date(),
                circadianCard: card,
                suggestedActions: ["💡 Дай мне один эксперимент на сегодня", "🎯 Как поднять фокус на максимум?"]
            )
        }

        // --- 3. Focus & Productivity ---
        if containsAny(lower, stems: ["фокус", "концентр", "внимани", "продуктив", "задач", "работ", "спринт", "прокрастинац", "отвлека", "эффективн"]) {
            let bestWindow = mAvg >= aAvg ? "Утро (09:00–12:30)" : "День (12:00–16:30)"
            let card = AIFocusSprintCardData(
                currentFocus: focusAvg,
                bestWindowName: bestWindow,
                sprintMinutes: 45
            )

            return AIChatMessage(
                sender: .assistant,
                text: "Твой средний фокус держится на уровне **\(String(format: "%.1f", focusAvg))/10**. Самое благоприятное окно для глубокой работы — **\(bestWindow)**.\n\nЧтобы сфокусироваться прямо сейчас, запусти 45-минутный спринт по таймеру 👇",
                timestamp: Date(),
                focusCard: card,
                suggestedActions: ["💡 Дай мне один эксперимент на сегодня", "📊 Разбери мое состояние за неделю"]
            )
        }

        // --- 4. Fatigue, Burnout, Sleep & Physical Energy ---
        if containsAny(lower, stems: ["устал", "устаю", "утом", "сил", "выгор", "тяжел", "сон", "спать", "энерги", "тело", "физическ", "вял", "истощен", "разбит", "задолб", "заеб"]) {
            var reply = "Я вижу по данным, что к вечеру твой средний балл опускается до **\(String(format: "%.1f", eAvg))/10** (при дневной норме \(String(format: "%.1f", composite))/10).\n\n"
            reply += "**Главные факторы:**\n"
            if let neg = negativeTag {
                reply += "• **Утечка энергии:** \(neg.title) — в такие дни проседание энергии выражено сильнее всего.\n"
            }
            if bodyAvg < mindAvg {
                reply += "• **Физический спад:** тело (\(String(format: "%.1f", bodyAvg))) устаёт быстрее ментального ресурса (\(String(format: "%.1f", mindAvg))). Требуется кислород и физическая разгрузка.\n"
            } else {
                reply += "• **Сенсорный перегруз:** непрерывный экран утомляет зрение и нервную систему.\n"
            }
            reply += "\n💡 **Совет:** отойди от монитора на 5 минут и выпей стакан воды. А в 17:30 устрой цифровую паузу."

            return AIChatMessage(
                sender: .assistant,
                text: reply,
                timestamp: Date(),
                suggestedActions: ["💡 Дай мне один эксперимент на сегодня", "👋 Что думаешь о моем ритме?"]
            )
        }

        // --- 5. Holistic Assessment / "Что думаешь?" ---
        if containsAny(lower, stems: ["что думаешь", "как тебе", "оцени", "мнение", "взгляд", "как я", "как дела", "как мои дела", "ну как", "скажи", "как считаешь", "твое мнение"]) {
            var reply = "Твой текущий композитный индекс: **\(String(format: "%.1f", composite))/10** (Тело: \(String(format: "%.1f", bodyAvg)), Ментал: \(String(format: "%.1f", mindAvg)), Фокус: \(String(format: "%.1f", focusAvg))).\n"
            reply += "Текущая непрерывная серия: **\(streak) дн.** 🔥\n\n"

            if composite >= 7.0 {
                reply += "Ты находишься в отличной форме. Главное — вовремя восстанавливаться и не накапливать скрытую усталость."
            } else if composite >= 5.0 {
                reply += "Ты в стабильной рабочей норме. Ресурс достаточен для работы, но вечерний спад до \(String(format: "%.1f", eAvg)) сдерживает твой полный потенциал."
            } else {
                reply += "Показатели говорят о накопившейся усталости. Организму требуется качественный сон и бережный режим."
            }

            return AIChatMessage(
                sender: .assistant,
                text: reply,
                timestamp: Date(),
                suggestedActions: ["💡 Дай мне один эксперимент на сегодня", "📊 Разбери мое состояние за неделю"]
            )
        }

        // --- 6. Notes, Thoughts & Emotions ---
        if containsAny(lower, stems: ["заметк", "настроени", "эмоци", "стресс", "мысл", "пережива", "мораль", "психол", "чувств", "тревог"]) {
            var reply = "Твой текущий показатель морального ресурса: **\(String(format: "%.1f", mindAvg))/10**.\n\n"
            if !recentNotes.isEmpty {
                let snippet = recentNotes.prefix(3).joined(separator: " • ")
                reply += "В твоих последних заметках зафиксировано: *«\(snippet)»*.\n"
                reply += "Регулярная фиксация мыслей отлично разгружает рабочую память мозга."
            } else {
                reply += "Старайся добавлять короткие заметки к чек-инам — они помогают находить скрытые триггеры стресса."
            }
            return AIChatMessage(
                sender: .assistant,
                text: reply,
                timestamp: Date(),
                suggestedActions: ["💡 Дай мне один эксперимент на сегодня", "👋 Что думаешь о моем ритме?"]
            )
        }

        // --- 7. Greeting & Casual Chat ---
        if containsAny(lower, stems: ["привет", "здравствуй", "хай", "добрый", "салют", "хей", "ку"]) {
            return AIChatMessage(
                sender: .assistant,
                text: "Привет! Твой средний ресурс сейчас в районе **\(String(format: "%.1f", composite))/10**, непрерывная серия — **\(streak) дн.**\n\nО чем хочешь поговорить? Могу разложить твой суточный биоритм, разобрать причины вечерней усталости или выдать эксперимент на сегодня.",
                timestamp: Date(),
                suggestedActions: [
                    "👋 Что думаешь о моем ритме?",
                    "💡 Дай мне один эксперимент на сегодня",
                    "📊 Разбери мое состояние за неделю"
                ]
            )
        }

        // --- 8. Smart Synthesis Fallback ---
        var reply = "Я проанализировал твои данные StatePulse (\(checkIns.count) чек-инов):\n\n"
        reply += "• **Средний общий ресурс:** \(String(format: "%.1f", composite))/10\n"
        reply += "• **Шкалы:** Тело \(String(format: "%.1f", bodyAvg)), Моральный тонус \(String(format: "%.1f", mindAvg)), Фокус \(String(format: "%.1f", focusAvg))\n"
        if aAvg > eAvg + 1.0 {
            reply += "• **Биоритм:** выраженный спад к вечеру до \(String(format: "%.1f", eAvg))/10."
        }

        return AIChatMessage(
            sender: .assistant,
            text: reply,
            timestamp: Date(),
            suggestedActions: [
                "💡 Дай мне один эксперимент на сегодня",
                "👋 Что думаешь о моем ритме?",
                "📊 Разбери мое состояние за неделю"
            ]
        )
    }

    private func containsAny(_ text: String, stems: [String]) -> Bool {
        return stems.contains(where: { text.contains($0) })
    }

    private func buildContextDigest(checkIns: [CheckInRecord]) -> String {
        guard !checkIns.isEmpty else { return "Данных пока мало." }
        let total = checkIns.count
        let bodyAvg = checkIns.reduce(0.0) { $0 + Double($1.bodyEnergy) } / Double(total)
        let mindAvg = checkIns.reduce(0.0) { $0 + Double($1.mentalResource) } / Double(total)
        let focusAvg = checkIns.reduce(0.0) { $0 + Double($1.focus) } / Double(total)
        let composite = (bodyAvg + mindAvg + focusAvg) / 3.0

        var text = "- Всего чек-инов: \(total)\n"
        text += "- Средние показатели: Тело \(String(format: "%.1f", bodyAvg)), Мораль \(String(format: "%.1f", mindAvg)), Фокус \(String(format: "%.1f", focusAvg)), Композит: \(String(format: "%.1f", composite))\n"

        let recentNotes = checkIns.compactMap { $0.note.isEmpty ? nil : $0.note }.prefix(5).joined(separator: ", ")
        if !recentNotes.isEmpty {
            text += "- Последние заметки: \(recentNotes)\n"
        }
        return text
    }

    // MARK: - Gemini Chat API
    private func callGeminiChat(prompt: String, checkIns: [CheckInRecord], apiKey: String) async throws -> String {
        let model = AICoachService.shared.selectedModel
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        let contextSummary = buildContextDigest(checkIns: checkIns)

        let systemInstruction = """
        Ты StatePulse AI — чуткий, внимательный и умный коуч по продуктивности, биоритмам и восстановлению энергии.
        Твой собеседник ведет персональный трекер состояния StatePulse на macOS.
        Вот его реальные данные:
        \(contextSummary)

        ПРАВИЛА ОБЩЕНИЯ:
        - Общайся как чуткий, высококомпетентный наставник на естественном, живом русском языке.
        - Отвечай емко и по существу (1-3 компактных абзаца). Без канцеляризмов и банальностей.
        - Опирайся на его реальные цифры и заметки.
        - Если пользователь спросил про усталость или спад — объясни причину по его данным и дай 1 конкретное действие.
        - Если спросил про биоритм — разложи утро, день и вечер.
        - Не вываливай сухие таблицы статистики, если тебя не попросили о полном отчёте.
        """

        var contents: [[String: Any]] = []
        contents.append([
            "role": "user",
            "parts": [["text": "\(systemInstruction)\n\nВопрос пользователя: \(prompt)"]]
        ])

        let payload: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 600
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
