import Foundation

enum MessageSender: String, Codable {
    case user
    case assistant
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let sender: MessageSender
    let text: String
    let timestamp: Date
    var isStatsCard: Bool = false
    var statsReport: AIAnalysisReport? = nil

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}
