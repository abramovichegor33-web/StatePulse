import Foundation

enum MessageSender: String, Codable {
    case user
    case assistant
}

struct AIExperimentCardData: Codable, Equatable {
    var title: String
    var goal: String
    var currentScore: Double
    var targetScore: Double
    var steps: [String]
    var reminderTime: String // e.g. "17:30"
    var reminderHour: Int
    var reminderMinute: Int
    var isAccepted: Bool = false
    var isReminderScheduled: Bool = false
}

struct AICircadianCardData: Codable, Equatable {
    var morningScore: Double
    var dayScore: Double
    var eveningScore: Double
    var peakWindowName: String
    var slumpDrop: Double
    var mainLeakTag: String?
}

struct AIFocusSprintCardData: Codable, Equatable {
    var currentFocus: Double
    var bestWindowName: String
    var sprintMinutes: Int
    var isTimerStarted: Bool = false
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let sender: MessageSender
    var text: String
    let timestamp: Date
    var isStatsCard: Bool = false
    var statsReport: AIAnalysisReport? = nil
    var experimentCard: AIExperimentCardData? = nil
    var circadianCard: AICircadianCardData? = nil
    var focusCard: AIFocusSprintCardData? = nil
    var suggestedActions: [String]? = nil

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}
