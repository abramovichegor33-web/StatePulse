import Foundation

struct AIAnalysisReport: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let generatedAt: Date
    let periodDays: Int
    let modelName: String
    let overallHeadline: String
    let overallSummary: String
    let drivers: [String]
    let drains: [String]
    let rhythmInsight: String
    let notesInsight: String?
    let recommendedExperiment: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: generatedAt)
    }
}
