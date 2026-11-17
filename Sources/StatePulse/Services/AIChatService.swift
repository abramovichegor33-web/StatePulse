import Foundation
import SwiftUI

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
            text: "Привет! Я твой персональный AI-Коуч StatePulse по энергии, фокусу и биоритмам. Спроси меня о чем угодно — например: «Почему я так устаю к вечеру?», «Что думаешь о моем ритме?» или попроси «Разбери мое состояние за неделю».",
            timestamp: Date()
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
                let intro = "Конечно! Вот твой полный персональный разбор состояния за последнее время:\n\n**\(report.overallHeadline)**\n\(report.overallSummary)"
                let reportMsg = AIChatMessage(
                    sender: .assistant,
                    text: intro,
                    timestamp: Date(),
                    isStatsCard: true,
                    statsReport: report
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
        try? await Task.sleep(nanoseconds: 400_000_000)
        let reply = generateSmartLocalReply(to: trimmed, checkIns: checkIns)
        let assistantMsg = AIChatMessage(sender: .assistant, text: reply, timestamp: Date())
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

    // MARK: - Smart Local Conversational Coach Engine
    private func generateSmartLocalReply(to userText: String, checkIns: [CheckInRecord]) -> String {
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
        let nightRecords = checkIns.filter { $0.phase == .night }

        let mAvg = morningRecords.isEmpty ? composite : morningRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(morningRecords.count)
        let aAvg = afternoonRecords.isEmpty ? composite : afternoonRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(afternoonRecords.count)
        let eAvg = eveningRecords.isEmpty ? composite : eveningRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(eveningRecords.count)

        let streak = AnalyticsEngine.shared.calculateStreak(records: checkIns)
        let insights = AnalyticsEngine.shared.generateInsights(records: checkIns)
        let positiveTag = insights.first(where: { $0.category == .positive })
        let negativeTag = insights.first(where: { $0.category == .negative })

        // Recent notes
        let recentNotes = checkIns.compactMap { $0.note.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 0. Meta / Humor / "Тупой" / Bot Identity
        if containsAny(lower, stems: ["туп", "глуп", "дурак", "бот", "кто ты", "зачем ты", "что умеешь", "бесишь", "херн", "фигн"]) {
            var reply = "Я работаю прямо на твоем Mac в 100% локальном и конфиденциальном режиме, опираясь на математику и эвристики твоих \(checkIns.count) чек-инов.\n\n"
            reply += "Если ты хочешь свободные рассуждения большой нейросети — вставь ключ Gemini API в Настройках (это бесплатно), и я переключусь на модель Google Gemini Flash с живым диалогом.\n\n"
            reply += "Но и прямо здесь я точно знаю твои данные: средний ресурс **\(String(format: "%.1f", composite))/10**, пик энергии в **\(mAvg >= aAvg ? "утренние часы" : "дневные часы")**, а спад к вечеру до **\(String(format: "%.1f", eAvg))/10**. Спроси меня про биоритм или нажми «Разбери неделю»!"
            return reply
        }

        // 1. Circadian Rhythm / Time of Day
        if containsAny(lower, stems: ["ритм", "циркад", "биоритм", "время", "часы", "утр", "вечер", "ноч", "дневн", "пик", "спад", "распорядок", "график"]) {
            var peakName = "день (12:00–17:00)"
            var peakVal = aAvg
            if mAvg >= aAvg && mAvg >= eAvg {
                peakName = "утро (06:00–12:00)"
                peakVal = mAvg
            }

            var reply = "По твоим \(checkIns.count) чек-инам твой суточный биоритм имеет чёткую структуру:\n\n"
            reply += "☀️ **Утро (06:00–12:00):** \(String(format: "%.1f", mAvg))/10\n"
            reply += "⚡️ **День (12:00–17:00):** \(String(format: "%.1f", aAvg))/10\n"
            reply += "🌘 **Вечер (17:00–22:00):** \(String(format: "%.1f", eAvg))/10\n\n"

            reply += "**Ключевые выводы:**\n"
            reply += "• **Пик ресурса:** приходится на \(peakName) с баллом \(String(format: "%.1f", peakVal))/10. В это окно лучше всего ставить самые сложные задачи и принятие решений.\n"

            if aAvg > eAvg + 1.2 {
                let drop = aAvg - eAvg
                reply += "• **Вечерний спад:** после 17:00 ресурс снижается на \(String(format: "%.1f", drop)) балла. Это типичный спад от накопленного умственного напряжения.\n"
            } else {
                reply += "• **Ровный тонус:** у тебя нет резких обвалов к вечеру, темп достаточно равномерный.\n"
            }

            if let neg = negativeTag {
                reply += "• **Фактор риска:** \(neg.title) (\(neg.description)).\n"
            }

            reply += "\n💡 **Совет:** запланируй 15-минутный буфер в районе 17:30 (без экрана и задач), чтобы плавно переключиться на вечерний отдых."
            return reply
        }

        // 2. Fatigue, Burnout, Sleep & Physical Energy
        if containsAny(lower, stems: ["устал", "устаю", "утом", "сил", "выгор", "тяжел", "сон", "спать", "энерги", "тело", "физическ", "вял", "истощен", "разбит", "задолб", "заеб"]) {
            var reply = ""
            if eAvg < 5.5 {
                reply += "Я вижу по данным, что к вечеру твой средний балл опускается до **\(String(format: "%.1f", eAvg))/10** (при норме \(String(format: "%.1f", composite))/10 днём).\n\n"
            } else {
                reply += "Твой средний физический тонус держится на уровне **\(String(format: "%.1f", bodyAvg))/10**.\n\n"
            }

            reply += "**Почему так происходит:**\n"
            if let neg = negativeTag {
                reply += "1. **Главная утечка:** \(neg.title) — в такие дни проседание энергии особенно заметно.\n"
            } else {
                reply += "1. **Непрерывный экран:** без физических микро-пауз мозг перегревается, а тело цепенеет.\n"
            }

            if bodyAvg < mindAvg {
                reply += "2. **Физический дисбаланс:** тело (\(String(format: "%.1f", bodyAvg))) устаёт сильнее ментального ресурса (\(String(format: "%.1f", mindAvg))). Это признак нехватки движения или кислорода.\n"
            } else {
                reply += "2. **Когнитивный перегруз:** ментальная усталость часто маскируется под лень, хотя на деле мозгу просто нужна тишина.\n"
            }

            reply += "\n💡 **Что сделать прямо сейчас:**\n"
            reply += "Выпей стакан прохладной воды, отойди от монитора на 5 минут и посмотри вдаль в окно. Если вечер — отключи уведомления за 40 минут до сна."
            return reply
        }

        // 3. Focus, Concentration & Work
        if containsAny(lower, stems: ["фокус", "концентр", "внимани", "продуктив", "задач", "работ", "спринт", "прокрастинац", "отвлека", "эффективн"]) {
            var reply = "Твой средний уровень фокуса составляет **\(String(format: "%.1f", focusAvg))/10**.\n\n"
            reply += "**Стратегия для максимальной концентрации:**\n"

            let bestWindow = mAvg >= aAvg ? "утренние часы (09:00–12:30)" : "дневное окно (12:00–16:30)"
            reply += "• **Лучшее время для глубокой работы:** \(bestWindow), когда твоя свежесть максимальна.\n"
            reply += "• **Протокол спринтов:** ставь таймер на 45 минут полного погружения в одну задачу, затем жесткий 10-минутный перерыв без телефона.\n"

            if let pos = positiveTag {
                reply += "• **Твой драйвер фокуса:** \(pos.title) — используй его в качестве утреннего триггера.\n"
            }

            reply += "\nХочешь, чтобы я разложил полную статистику динамики фокуса за неделю?"
            return reply
        }

        // 4. Experiment, Biohack & Advice
        if containsAny(lower, stems: ["эксперимент", "совет", "посовет", "что делать", "рекомендац", "помоги", "лайфхак", "привычк", "план", "как улучшить", "как поднять", "что предпринять"]) {
            var reply = "Вот твой персонализированный эксперимент на основе твоих данных:\n\n"

            if eAvg < 5.5 {
                reply += "🧪 **Эксперимент «Цифровой буфер в 17:30»:**\n"
                reply += "За 30 минут до окончания рабочего дня полностью закрой рабочие чаты. Сделай 10 минут физической активности (прогулка, душ или растяжка).\n"
                reply += "**Цель:** поднять вечерний ресурс с \(String(format: "%.1f", eAvg)) до 6.0+.\n\n"
            } else if bodyAvg < 6.0 {
                reply += "🧪 **Эксперимент «Утренний гидрант»:**\n"
                reply += "Первые 30 минут после пробуждения — без экрана смартфона. Выпей 400 мл воды и сделай 3 минуты суставной разминки.\n"
                reply += "**Цель:** вывести утреннюю шкалу тела выше 7.0.\n\n"
            } else {
                reply += "🧪 **Эксперимент «Монофокус на 1 приоритет»:**\n"
                reply += "Выбери с утра ровно одну главную задачу. До 13:00 не открывай почту и соцсети, пока эта задача не будет закрыта.\n"
                reply += "**Цель:** закрепить фокус на отметке 8.0+.\n\n"
            }

            reply += "Попробуй провести этот эксперимент сегодня и отметь результат в следующем чек-ине!"
            return reply
        }

        // 5. Holistic Assessment / "Что думаешь?"
        if containsAny(lower, stems: ["что думаешь", "как тебе", "оцени", "мнение", "взгляд", "как я", "как дела", "как мои дела", "ну как", "скажи", "как считаешь", "твое мнение"]) {
            var reply = "Оцениваю твое текущее состояние в целом:\n\n"
            reply += "Твой средний композитный индекс — **\(String(format: "%.1f", composite))/10** (Тело: \(String(format: "%.1f", bodyAvg)), Ментал: \(String(format: "%.1f", mindAvg)), Фокус: \(String(format: "%.1f", focusAvg))).\n"
            reply += "Текущая серия чек-инов: **\(streak) дн подряд** 🔥\n\n"

            if composite >= 7.0 {
                reply += "Ты находишься в отличной форме и держишь устойчивую продуктивность. Главное сейчас — не перегореть и вовремя восстанавливаться.\n"
            } else if composite >= 5.0 {
                reply += "Ты в стабильной рабочей норме. Ресурс достаточен для рутины, но есть скрытые утечки к вечеру, которые сдерживают пиковый фокус.\n"
            } else {
                reply += "Показатели сигнализируют о накопившейся усталости. Организму требуется более бережный режим и качественный сон.\n"
            }

            if let pos = positiveTag {
                reply += "\n✅ Твоя сильная опора: \(pos.title)."
            }
            if let neg = negativeTag {
                reply += "\n⚠️ Главная зона риска: \(neg.title)."
            }

            reply += "\n\nМожешь спросить меня про ритм дня, фокус или написать «Сделай разбор недели» для полной аналитической сводки!"
            return reply
        }

        // 6. Notes, Thoughts & Emotions
        if containsAny(lower, stems: ["заметк", "настроени", "эмоци", "стресс", "мысл", "пережива", "мораль", "психол", "чувств", "тревог"]) {
            var reply = "Твой текущий показатель морального ресурса: **\(String(format: "%.1f", mindAvg))/10**.\n\n"
            if !recentNotes.isEmpty {
                let snippet = recentNotes.prefix(3).joined(separator: " • ")
                reply += "В твоих последних заметках зафиксировано: *«\(snippet)»*.\n"
                reply += "Это отличный знак осознанности: когда ты выписываешь состояние словами, мозг перестаёт варить тревогу внутри.\n\n"
            }

            reply += "Если чувствуешь моральное напряжение, попробуй технику «выгрузки мыслей»: запиши на бумагу всё, что крутится в голове, и выдели ровно одну вещь, на которую ты реально влияешь прямо сейчас."
            return reply
        }

        // 7. Greeting & Casual Chat
        if containsAny(lower, stems: ["привет", "здравствуй", "хай", "добрый", "салют", "хей", "ку"]) {
            return "Привет! Я на связи. Твой средний ресурс сейчас в районе **\(String(format: "%.1f", composite))/10**, непрерывная серия — **\(streak) дн.**\n\nО чем хочешь поговорить? Могу рассказать про твой суточный ритм, разобрать причины усталости или выдать персональный эксперимент на день."
        }

        // 8. Smart Synthesis Fallback (Never robotic or repetitive)
        var reply = "Я проанализировал твои данные StatePulse (\(checkIns.count) чек-инов):\n\n"
        reply += "• **Текущий суммарный ресурс:** \(String(format: "%.1f", composite))/10\n"
        reply += "• **Баланс шкал:** Тело \(String(format: "%.1f", bodyAvg)), Ментальный тонус \(String(format: "%.1f", mindAvg)), Фокус \(String(format: "%.1f", focusAvg))\n"

        if aAvg > eAvg + 1.0 {
            reply += "• **Паттерн:** у тебя заметен переход с дневного пика (\(String(format: "%.1f", aAvg))) на вечерний спад (\(String(format: "%.1f", eAvg))).\n"
        }

        reply += "\nСпроси меня о ритме дня, фокусе, вечерней усталости, или напиши «Сделай разбор недели», чтобы я вывел подробные карточки аналитики!"
        return reply
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
}
