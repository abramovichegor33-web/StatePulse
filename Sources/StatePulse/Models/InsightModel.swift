import Foundation

enum InsightCategory: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    case screenTime = "screenTime"

    var icon: String {
        switch self {
        case .positive: return "arrow.up.right.circle.fill"
        case .negative: return "arrow.down.right.circle.fill"
        case .neutral: return "info.circle.fill"
        case .screenTime: return "display"
        }
    }
}

struct InsightModel: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let deltaPercentage: Double
    let category: InsightCategory
    let factorName: String

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        deltaPercentage: Double,
        category: InsightCategory,
        factorName: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.deltaPercentage = deltaPercentage
        self.category = category
        self.factorName = factorName
    }
}
