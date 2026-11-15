import Foundation

struct MockDataGenerator {
    static func generateSampleData(daysCount: Int = 35) {
        let db = DatabaseManager.shared
        let calendar = Calendar.current
        let today = Date()

        for tag in ["Прогулка", "Медитация"] {
            db.saveCustomTag(name: tag)
        }

        let sampleNotesMorning = [
            "Отличная тренировка утром, чувствую заряд бодрости на весь день.",
            "Проснулся легко, голова ясная, готов к задачам.",
            "Немного не выспался, но после кофе стало лучше.",
            "Спокойное и размеренное утро."
        ]

        let sampleNotesDay = [
            "Глубокая концентрация, закрыл важный майлстоун.",
            "Много созвонов и код-ревью, но темп хороший.",
            "Сложная задача потребовала максимального фокуса.",
            "Высокая продуктивность, отличное рабочее состояние."
        ]

        let sampleNotesEvening = [
            "Прогулка в парке восстановила силы после работы.",
            "Приятная усталость к вечеру, время отдохнуть.",
            "Засиделся за экраном, нужно вовремя пойти спать.",
            "Спокойный вечер, восстанавливаю ресурс."
        ]

        for i in (0..<daysCount).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let isWeekend = calendar.isDateInWeekend(date)

            // 2 or 3 slices per day to demonstrate intraday rhythm
            let hoursAndPhases: [(Int, Int, String)] = [
                (9, Int.random(in: 15...45), "morning"),
                (14, Int.random(in: 15...45), "afternoon"),
                (21, Int.random(in: 10...45), "evening")
            ]

            let slicesCount = (i % 2 == 0) ? 3 : 2

            for sliceIdx in 0..<slicesCount {
                let (hour, minute, phaseStr) = hoursAndPhases[sliceIdx]
                let checkInDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date

                var selectedTags: [String] = []
                var body = 7
                var mental = 7
                var focus = 7
                var note = ""

                switch phaseStr {
                case "morning":
                    body = isWeekend ? Int.random(in: 7...9) : Int.random(in: 6...9)
                    mental = Int.random(in: 6...9)
                    focus = Int.random(in: 6...8)
                    if i % 3 == 0 {
                        selectedTags.append("Тренировка")
                        body = min(10, body + 1)
                        note = sampleNotesMorning[0]
                    } else if i % 5 == 0 {
                        selectedTags.append("Недосып")
                        body = max(3, body - 3)
                        focus = max(3, focus - 2)
                        note = sampleNotesMorning[2]
                    } else {
                        note = sampleNotesMorning[1]
                    }

                case "afternoon":
                    body = Int.random(in: 5...7)
                    mental = Int.random(in: 5...8)
                    focus = isWeekend ? Int.random(in: 4...6) : Int.random(in: 7...10)
                    if !isWeekend {
                        selectedTags.append("Много работы")
                        if Bool.random() { selectedTags.append("Результат") }
                        note = sampleNotesDay[sliceIdx % sampleNotesDay.count]
                    } else {
                        selectedTags.append("Отдых")
                        note = "Выходной день, свободный темп."
                    }

                default: // evening
                    body = max(3, Int.random(in: 4...6))
                    mental = isWeekend ? Int.random(in: 7...9) : Int.random(in: 5...8)
                    focus = Int.random(in: 3...6)
                    if i % 6 == 0 {
                        selectedTags.append("Залип в экран")
                        mental = max(3, mental - 2)
                        note = sampleNotesEvening[2]
                    } else {
                        selectedTags.append("Отдых")
                        if Bool.random() { selectedTags.append("Прогулка") }
                        note = sampleNotesEvening[0]
                    }
                }

                let screenSeconds = isWeekend ? Int.random(in: 7200...14400) : Int.random(in: 21600...32400)

                let record = CheckInRecord(
                    id: UUID(),
                    timestamp: checkInDate,
                    metricScores: [
                        "body": body,
                        "mind": mental,
                        "focus": focus
                    ],
                    tags: selectedTags,
                    note: note,
                    screenTimeSeconds: screenSeconds
                )
                db.saveCheckIn(record)
            }
        }
    }
}
