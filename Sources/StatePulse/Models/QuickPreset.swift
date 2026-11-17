import SwiftUI

struct QuickPreset: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var icon: String
    var label: String
    var bodyScore: Int
    var mindScore: Int
    var focusScore: Int
    var customScores: [String: Int]?
    var tag: String?

    func score(for metricId: String) -> Int {
        if let custom = customScores, let val = custom[metricId] {
            return val
        }
        switch metricId {
        case "body": return bodyScore
        case "mind": return mindScore
        case "focus": return focusScore
        default: return 7
        }
    }

    mutating func setScore(_ val: Int, for metricId: String) {
        switch metricId {
        case "body": bodyScore = val
        case "mind": mindScore = val
        case "focus": focusScore = val
        default:
            if customScores == nil { customScores = [:] }
            customScores?[metricId] = val
        }
    }

    static let defaultPresets: [QuickPreset] = [
        QuickPreset(id: "flow", icon: "⚡️", label: "В потоке", bodyScore: 9, mindScore: 9, focusScore: 9, customScores: nil, tag: "Результат"),
        QuickPreset(id: "normal", icon: "☕️", label: "В норме", bodyScore: 7, mindScore: 7, focusScore: 7, customScores: nil, tag: nil),
        QuickPreset(id: "tired", icon: "🥱", label: "Устал", bodyScore: 3, mindScore: 4, focusScore: 3, customScores: nil, tag: "Недосып"),
        QuickPreset(id: "chill", icon: "🎮", label: "Отдых", bodyScore: 8, mindScore: 8, focusScore: 4, customScores: nil, tag: "Отдых")
    ]

    static let availableIcons: [String] = [
        "⚡️", "☕️", "🥱", "🎮", "🚀", "🧘‍♂️", "🔥", "🔋", "💡", "🧠", "💪", "🌱", "🎯", "🎧", "🌊", "💤", "✨", "🥊", "💻", "🏖️"
    ]
}
