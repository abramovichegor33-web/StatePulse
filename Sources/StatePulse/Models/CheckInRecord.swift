import Foundation

struct CheckInRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var timestamp: Date
    var metricScores: [String: Int]  // [metricId: score (1 ... 10)]
    var tags: [String]
    var note: String
    var screenTimeSeconds: Int   // Active screen time on this day in seconds

    // Backward-compatible properties
    var bodyEnergy: Int {
        get { metricScores["body"] ?? 7 }
        set { metricScores["body"] = max(1, min(10, newValue)) }
    }

    var mentalResource: Int {
        get { metricScores["mind"] ?? 7 }
        set { metricScores["mind"] = max(1, min(10, newValue)) }
    }

    var focus: Int {
        get { metricScores["focus"] ?? 7 }
        set { metricScores["focus"] = max(1, min(10, newValue)) }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        metricScores: [String: Int] = ["body": 7, "mind": 7, "focus": 7],
        tags: [String] = [],
        note: String = "",
        screenTimeSeconds: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.metricScores = metricScores
        self.tags = tags
        self.note = note
        self.screenTimeSeconds = screenTimeSeconds
    }

    // Convenience initializer for standard 3 metrics
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        bodyEnergy: Int,
        mentalResource: Int,
        focus: Int,
        tags: [String] = [],
        note: String = "",
        screenTimeSeconds: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.metricScores = [
            "body": max(1, min(10, bodyEnergy)),
            "mind": max(1, min(10, mentalResource)),
            "focus": max(1, min(10, focus))
        ]
        self.tags = tags
        self.note = note
        self.screenTimeSeconds = screenTimeSeconds
    }

    func score(for metricId: String) -> Int {
        metricScores[metricId] ?? 7
    }

    mutating func setScore(_ val: Int, for metricId: String) {
        metricScores[metricId] = max(1, min(10, val))
    }

    var phase: TimeOfDayPhase {
        TimeOfDayPhase.current(for: timestamp)
    }

    var compositeScore: Double {
        guard !metricScores.isEmpty else { return 7.0 }
        let total = metricScores.values.reduce(0, +)
        return Double(total) / Double(metricScores.count)
    }

    var heatmapLevel: Int {
        switch compositeScore {
        case 0..<2.5: return 1
        case 2.5..<5.0: return 2
        case 5.0..<7.5: return 3
        default: return 4
        }
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    var formattedDateDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var dayAndMonthDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: timestamp)
    }
}
