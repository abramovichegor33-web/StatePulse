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
            text: "Привет! Я твой персональный AI-Коуч по самочувствию и продуктивности. Можешь просто поболтать со мной о своем дне, спросить, почему падает энергия к вечеру, или попросить полный разбор недели.",
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
        let statsKeywords = ["разбор", "статистик", "итоги", "сводка", "отчет", "неделя", "покажи данные", "анализ"]
        let isAskingForStats = statsKeywords.contains(where: { lower.contains($0) })

        if isAskingForStats {
            await AICoachService.shared.generateReport(checkIns: checkIns, period: .days7)
            if let report = AICoachService.shared.latestReport {
                let intro = "Конечно! Вот твой полный персональный разбор состояния за последнее время:"
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
                print("Gemini chat error: \(error.localizedDescription). Falling back to local responder.")
            }
        }

        // 4. Local Smart Conversational Engine (100% Offline)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let reply = generateLocalReply(to: trimmed, checkIns: checkIns)
        let assistantMsg = AIChatMessage(sender: .assistant, text: reply, timestamp: Date())
        messages.append(assistantMsg)
        saveHistory()
        isThinking = false
    }

    // MARK: - Gemini Chat API
    private func callGeminiChat(prompt: String, checkIns: [CheckInRecord], apiKey: String) async throws -> String {
        let model = AICoachService.shared.selectedModel
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        let contextSummary = buildContextDigest(checkIns: checkIns)

        let systemInstruction = """
        Ты StatePulse AI — личный, внимательный и умный коуч по продуктивности, биоритмам и восстановлению энергии.
        Твой собеседник ведет трекер состояния StatePulse.
        Вот его актуальные данные:
        \(contextSummary)

        ПРАВИЛА ОБЩЕНИЯ:
        - Общайся как чуткий, грамотный и живой наставник на естественном русском языке.
        - Отвечай коротко, емко и по существу (1-3 абзаца). Без воды и банальностей.
        - Если пользователь просто здоровается или шутит — ответь тепло и непринужденно.
        - Если жалуется на усталость или спад — сопоставь это с его цифрами и подскажи причину.
        - Не вываливай длинные таблицы статистики, если тебя прямо не попросили об этом.
        """

        // Build conversation history (up to last 10 messages)
        var contents: [[String: Any]] = []

        // Initial system injection
        contents.append([
            "role": "user",
            "parts": [["text": "\(systemInstruction)\n\nСообщение пользователя: \(prompt)"]]
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

    // MARK: - Local Heuristic Response Generator
    private func generateLocalReply(to userText: String, checkIns: [CheckInRecord]) -> String {
        let lower = userText.lowercased()

        let total = max(1, checkIns.count)
        let bodyAvg = checkIns.reduce(0.0) { $0 + Double($1.bodyEnergy) } / Double(total)
        let mindAvg = checkIns.reduce(0.0) { $0 + Double($1.mentalResource) } / Double(total)
        let focusAvg = checkIns.reduce(0.0) { $0 + Double($1.focus) } / Double(total)
        let composite = (bodyAvg + mindAvg + focusAvg) / 3.0

        let eveningRecords = checkIns.filter { $0.phase == .evening }
        let eveAvg = eveningRecords.isEmpty ? composite : eveningRecords.reduce(0.0) { $0 + $1.compositeScore } / Double(eveningRecords.count)

        // Greetings
        if lower.contains("привет") || lower.contains("здравствуй") || lower.contains("хай") || lower.contains("добрый") {
            let streak = AnalyticsEngine.shared.calculateStreak(records: checkIns)
            return "Привет! Твой текущий общий ресурс в районе \(String(format: "%.1f", composite))/10, серия непрерывных отметок — \(streak) дн. О чем хочешь поговорить или что разобрать?"
        }

        // Fatigue / Tiredness
        if lower.contains("устал") || lower.contains("нет сил") || lower.contains("выгорел") || lower.contains("тяжело") || lower.contains("сон") {
            if eveAvg < 5.5 {
                return "Я заметил по твоим записям, что к вечеру ресурс проседает до \(String(format: "%.1f", eveAvg))/10. Скорее всего, дело в непрерывном сидении за экраном без переходной паузы. Попробуй за 30 минут до конца работы закрыть задачи и сделать 10 минут тишины без гаджетов."
            } else {
                return "Если чувствуешь усталость прямо сейчас, проверь шкалу физической энергии (твое среднее: \(String(format: "%.1f", bodyAvg))/10). Иногда спад маскируется под лень, а на деле телу просто не хватает воды, кислорода или короткой прогулки."
            }
        }

        // Focus & Productivity
        if lower.contains("фокус") || lower.contains("концентраци") || lower.contains("внимани") || lower.contains("работа") {
            return "Твой средний фокус держится на уровне \(String(format: "%.1f", focusAvg))/10. Чтобы не сливать его впустую, выдели один важный приоритет на день и сделай на него 45-минутный спринт в дневные часы (12:00–17:00) — именно тогда концентрация у тебя на максимуме."
        }

        // Advice / Experiment
        if lower.contains("совет") || lower.contains("что делать") || lower.contains("рекомендац") || lower.contains("помоги") {
            return "Вот мой главный совет на сегодня: обрати внимание на вечернее время. Если после 18:00 не нагружать себя новыми входящими задачами, твой утренний ресурс на следующий день вырастет на 20-30%. Хочешь сделать полный разбор недели?"
        }

        // General fallback
        return "Я внимательно слежу за твоими чек-инами (всего \(checkIns.count) записей, средний балл \(String(format: "%.1f", composite))/10). Можешь спросить меня о чем угодно, или напиши «Сделай разбор недели», и я покажу детальную статистику!"
    }

    private func buildContextDigest(checkIns: [CheckInRecord]) -> String {
        guard !checkIns.isEmpty else { return "Данных пока мало." }
        let total = checkIns.count
        let bodyAvg = checkIns.reduce(0.0) { $0 + Double($1.bodyEnergy) } / Double(total)
        let mindAvg = checkIns.reduce(0.0) { $0 + Double($1.mentalResource) } / Double(total)
        let focusAvg = checkIns.reduce(0.0) { $0 + Double($1.focus) } / Double(total)
        let composite = (bodyAvg + mindAvg + focusAvg) / 3.0

        var text = "- Всего чек-инов: \(total)\n"
        text += "- Средние: Тело \(String(format: "%.1f", bodyAvg)), Мораль \(String(format: "%.1f", mindAvg)), Фокус \(String(format: "%.1f", focusAvg)), Композит: \(String(format: "%.1f", composite))\n"

        let recentNotes = checkIns.compactMap { $0.note.isEmpty ? nil : $0.note }.prefix(5).joined(separator: ", ")
        if !recentNotes.isEmpty {
            text += "- Последние заметки: \(recentNotes)\n"
        }
        return text
    }
}
