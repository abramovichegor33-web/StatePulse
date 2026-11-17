import Foundation
import SwiftUI

@MainActor
final class AICoachService: ObservableObject {
    static let shared = AICoachService()

    @Published var latestReport: AIAnalysisReport?
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var apiKey: String = ""
    @Published var selectedModel: String = "gemini-1.5-flash"

    private let apiKeyStorageKey = "statepulse_gemini_api_key"
    private let modelStorageKey = "statepulse_ai_model"
    private let reportStorageKey = "statepulse_latest_ai_report"

    private init() {
        loadSettings()
        loadLatestReport()
    }

    func loadSettings() {
        apiKey = UserDefaults.standard.string(forKey: apiKeyStorageKey) ?? ""
        selectedModel = UserDefaults.standard.string(forKey: modelStorageKey) ?? "gemini-1.5-flash"
    }

    func saveApiKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(apiKey, forKey: apiKeyStorageKey)
    }

    func saveModel(_ model: String) {
        selectedModel = model
        UserDefaults.standard.set(selectedModel, forKey: modelStorageKey)
    }

    private func loadLatestReport() {
        if let data = UserDefaults.standard.data(forKey: reportStorageKey),
           let report = try? JSONDecoder().decode(AIAnalysisReport.self, from: data) {
            latestReport = report
        }
    }

    private func saveReport(_ report: AIAnalysisReport) {
        latestReport = report
        if let data = try? JSONEncoder().encode(report) {
            UserDefaults.standard.set(data, forKey: reportStorageKey)
        }
    }

    func generateReport(checkIns: [CheckInRecord], period: AnalyticsPeriod) async {
        isGenerating = true
        errorMessage = nil

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -period.rawValue, to: Date()) ?? Date()
        var targetRecords = checkIns.filter { $0.timestamp >= cutoff }

        if targetRecords.isEmpty {
            targetRecords = checkIns
        }

        guard !targetRecords.isEmpty else {
            errorMessage = "Нет данных для анализа. Добавьте хотя бы несколько чек-инов."
            isGenerating = false
            return
        }

        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanKey.isEmpty {
            do {
                let report = try await generateWithGemini(records: targetRecords, period: period, apiKey: cleanKey)
                saveReport(report)
                isGenerating = false
                return
            } catch {
                print("Gemini API call failed: \(error.localizedDescription). Falling back to local smart engine.")
            }
        }

        // Run Local Smart Heuristic Coach
        try? await Task.sleep(nanoseconds: 600_000_000) // Smooth UX feedback
        let report = generateLocalAnalysis(records: targetRecords, period: period)
        saveReport(report)
        isGenerating = false
    }

    // MARK: - Gemini API Neural Integration
    private func generateWithGemini(records: [CheckInRecord], period: AnalyticsPeriod, apiKey: String) async throws -> AIAnalysisReport {
        let statsPrompt = buildStatsPrompt(records: records, period: period)

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(selectedModel):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        let systemInstruction = """
        Ты профессиональный биохакер, спортивный психолог и эксперт по продуктивности и суточным биоритмам человека.
        Проанализируй предоставленный сжатый статистический отчет пользователя за \(period.title).
        Найди неочевидные взаимосвязи, триггеры спадов и точки максимального фокуса.
        Ответь СТРОГО в формате валидного JSON без разметки markdown и без ```json блоков:
        {
          "overallHeadline": "Короткий вывод одной емкой фразой (до 60 знаков)",
          "overallSummary": "Краткая выжимка (2-3 предложения) о текущем паттерне энергии и продуктивности.",
          "drivers": ["Фактор или привычка, дающая максимум ресурса", "Второй положительный триггер"],
          "drains": ["Главный источник утечки сил или фокуса", "Второй фактор спада"],
          "rhythmInsight": "Наблюдение о суточных фазах (утро, день, вечер, ночь). Когда пик, когда провал.",
          "notesInsight": "Анализ текстовых заметок пользователя (если есть): ключевые темы, эмоции и триггеры.",
          "recommendedExperiment": "Один конкретный, легко проверяемый эксперимент на следующую неделю (например: прогулка 15 мин в 15:30 перед спадом фокуса)."
        }
        """

        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemInstruction)\n\nДАННЫЕ ПОЛЬЗОВАТЕЛЯ:\n\(statsPrompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1000,
                "responseMimeType": "application/json"
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

        // Clean any stray backticks if model wrapped in markdown
        var cleanJSON = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJSON.hasPrefix("```json") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
        }
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
        }
        cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let innerData = cleanJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return AIAnalysisReport(
            id: UUID(),
            generatedAt: Date(),
            periodDays: period.rawValue,
            modelName: "Google Gemini (\(selectedModel))",
            overallHeadline: dict["overallHeadline"] as? String ?? "Сбалансированный темп с вечерней перезагрузкой",
            overallSummary: dict["overallSummary"] as? String ?? "На основе ваших записей наблюдается стабильная динамика показателей.",
            drivers: dict["drivers"] as? [String] ?? ["Физическая активность", "Регулярный отдых"],
            drains: dict["drains"] as? [String] ?? ["Длительное экранное время", "Смещение сна"],
            rhythmInsight: dict["rhythmInsight"] as? String ?? "Пик ясности приходится на дневные часы.",
            notesInsight: dict["notesInsight"] as? String,
            recommendedExperiment: dict["recommendedExperiment"] as? String ?? "Попробуйте делать 10-минутную паузу без экрана перед вечерним блоком задач."
        )
    }

    // MARK: - Local Smart Heuristic Engine (100% Offline)
    private func generateLocalAnalysis(records: [CheckInRecord], period: AnalyticsPeriod) -> AIAnalysisReport {
        let totalCount = records.count

        // Metric Averages
        let metrics = MetricManager.shared.metrics
        var averages: [String: Double] = [:]
        for m in metrics {
            let sum = records.reduce(0.0) { $0 + Double($1.score(for: m.id)) }
            averages[m.id] = sum / Double(max(1, totalCount))
        }

        let bodyAvg = averages["body"] ?? 7.0
        let mindAvg = averages["mind"] ?? 7.0
        let focusAvg = averages["focus"] ?? 7.0
        let composite = (bodyAvg + mindAvg + focusAvg) / 3.0

        // Phase analysis
        var morningScores: [Double] = []
        var afternoonScores: [Double] = []
        var eveningScores: [Double] = []
        var nightScores: [Double] = []

        for r in records {
            let avg = r.compositeScore
            switch r.phase {
            case .morning: morningScores.append(avg)
            case .afternoon: afternoonScores.append(avg)
            case .evening: eveningScores.append(avg)
            case .night: nightScores.append(avg)
            }
        }

        let mAvg = morningScores.isEmpty ? composite : morningScores.reduce(0, +) / Double(morningScores.count)
        let aAvg = afternoonScores.isEmpty ? composite : afternoonScores.reduce(0, +) / Double(afternoonScores.count)
        let eAvg = eveningScores.isEmpty ? composite : eveningScores.reduce(0, +) / Double(eveningScores.count)

        // Tag impact analysis
        let insights = AnalyticsEngine.shared.generateInsights(records: records)
        let positiveTag = insights.first(where: { $0.category == .positive })
        let negativeTag = insights.first(where: { $0.category == .negative })

        // Drivers & Drains
        var drivers: [String] = []
        var drains: [String] = []

        if let pos = positiveTag {
            drivers.append("\(pos.title): \(pos.description)")
        } else {
            drivers.append("Стабильное поддержание физического тонуса (среднее \(String(format: "%.1f", bodyAvg))/10)")
        }

        if aAvg >= mAvg && aAvg >= eAvg {
            drivers.append("Дневное окно (12:00–17:00): время наивысшей концентрации (\(String(format: "%.1f", aAvg))/10)")
        } else if mAvg >= aAvg {
            drivers.append("Утреннее окно (06:00–12:00): максимальная ментальная свежесть (\(String(format: "%.1f", mAvg))/10)")
        } else {
            drivers.append("Вечерняя продуктивность: способность сохранять рабочий темп в конце дня")
        }

        if let neg = negativeTag {
            drains.append("\(neg.title): \(neg.description)")
        } else {
            drains.append("Неравномерность распределения нагрузки в течение дня")
        }

        if eAvg < 5.5 {
            drains.append("Вечерний спад ресурса: к 17:00–22:00 средний балл опускается до \(String(format: "%.1f", eAvg))/10")
        } else {
            drains.append("Фактор экранной усталости при непрерывной работе")
        }

        // Rhythm insight
        var rhythmText = ""
        if aAvg > eAvg + 1.2 {
            rhythmText = "Ярко выраженный циркадный спад: после дневного пика (\(String(format: "%.1f", aAvg))) к вечеру ресурс снижается на \(String(format: "%.1f", aAvg - eAvg)) балла. Требуется защищенный переходный период между работой и отдыхом."
        } else if mAvg > aAvg + 1.0 {
            rhythmText = "Утренний пик активности (\(String(format: "%.1f", mAvg))). К середине дня энергия рассеивается. Рекомендуется планировать самые сложные когнитивные задачи до 13:00."
        } else {
            rhythmText = "Относительно ровный суточный профиль без критических обрывов (Утро: \(String(format: "%.1f", mAvg)), День: \(String(format: "%.1f", aAvg)), Вечер: \(String(format: "%.1f", eAvg)))."
        }

        // Notes analysis
        let notes = records.map { $0.note }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var notesText: String? = nil
        if !notes.isEmpty {
            let sampleCount = min(notes.count, 5)
            let noteSnippet = notes.prefix(sampleCount).joined(separator: "; ")
            notesText = "В ваших последних заметках (\(notes.count) записей) ключевой фокус на текущих задачах и контексте: «\(noteSnippet)». Это указывает на высокую осознанность происходящего."
        }

        // Headline & Summary
        var headline = "Устойчивый продуктивный темп"
        var summary = "Средний суммарный ресурс за период составил \(String(format: "%.1f", composite))/10. "

        if composite >= 7.5 {
            headline = "Высокая ресурсность и устойчивый тонус"
            summary += "Вы находитесь в верхней зоне продуктивности. Баланс физической энергии (\(String(format: "%.1f", bodyAvg))) и фокуса (\(String(format: "%.1f", focusAvg))) позволяет решать стратегические задачи без выгорания."
        } else if composite <= 5.0 {
            headline = "Признаки накопительной усталости"
            summary += "Показатели сигнализируют о сниженном ресурсе. Рекомендуется снизить планку задач и уделить внимание восстановлению сна и базового физического тонуса."
        } else {
            headline = "Рабочая норма с потенциалом роста фокуса"
            summary += "Состояние находится в рабочей норме. Основной резерв роста кроется в сглаживании вечерних спадов и регулярных микро-паузах."
        }

        // Recommended Experiment
        let experiment: String
        if eAvg < 5.5 {
            experiment = "Эксперимент на неделю: устройте «цифровой закат» — за 30 минут до конца рабочего дня закройте экран и сделайте 10-минутную прогулку или растяжку. Это предотвратит вечернюю апатию."
        } else if bodyAvg < 6.0 {
            experiment = "Эксперимент на неделю: добавьте стакан воды и 5-минутную зарядку сразу после пробуждения. Отслеживайте, как это повлияет на утреннюю оценку тела."
        } else {
            experiment = "Эксперимент на неделю: в дни с высокой нагрузкой ставьте таймер на 45 минут непрерывного фокуса и 5 минут полного отвлечения от экрана."
        }

        return AIAnalysisReport(
            id: UUID(),
            generatedAt: Date(),
            periodDays: period.rawValue,
            modelName: "Локальный AI-движок StatePulse",
            overallHeadline: headline,
            overallSummary: summary,
            drivers: drivers,
            drains: drains,
            rhythmInsight: rhythmText,
            notesInsight: notesText,
            recommendedExperiment: experiment
        )
    }

    private func buildStatsPrompt(records: [CheckInRecord], period: AnalyticsPeriod) -> String {
        let metrics = MetricManager.shared.metrics
        var text = "Период: \(period.title), Всего записей: \(records.count)\n"

        text += "\nСРЕДНИЕ ПОКАЗАТЕЛИ:\n"
        for m in metrics {
            let avg = records.reduce(0.0) { $0 + Double($1.score(for: m.id)) } / Double(max(1, records.count))
            text += "- \(m.name): \(String(format: "%.1f", avg)) / 10\n"
        }

        text += "\nВРЕМЯ СУТОК (РИТМ):\n"
        for phase in TimeOfDayPhase.allCases {
            let subset = records.filter { $0.phase == phase }
            if !subset.isEmpty {
                let avg = subset.reduce(0.0) { $0 + $1.compositeScore } / Double(subset.count)
                text += "- \(phase.title) (\(subset.count) записей): средний балл \(String(format: "%.1f", avg))\n"
            }
        }

        let insights = AnalyticsEngine.shared.generateInsights(records: records)
        if !insights.isEmpty {
            text += "\nВЛИЯНИЕ ТЕГОВ И ФАКТОРОВ НА ЭНЕРГИЮ:\n"
            for t in insights.prefix(6) {
                text += "- \(t.title): \(t.description)\n"
            }
        }

        let notes = records.compactMap { r -> String? in
            let clean = r.note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            return "[\(r.phase.title)]: \"\(clean)\""
        }

        if !notes.isEmpty {
            text += "\nПОСЛЕДНИЕ ЗАМЕТКИ ПОЛЬЗОВАТЕЛЯ:\n"
            for n in notes.prefix(12) {
                text += "- \(n)\n"
            }
        }

        return text
    }
}
