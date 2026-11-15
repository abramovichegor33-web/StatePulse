import Foundation

struct TagModel: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let isDefault: Bool
    let createdAt: Date

    init(name: String, isDefault: Bool = false, createdAt: Date = Date()) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    var icon: String {
        switch name {
        case "Недосып": return "moon.zzz.fill"
        case "Тренировка": return "figure.run"
        case "Много работы": return "laptopcomputer"
        case "Стресс": return "bolt.fill"
        case "Результат": return "checkmark.seal.fill"
        case "Залип в экран": return "iphone"
        case "Отдых": return "cup.and.saucer.fill"
        default: return "tag.fill"
        }
    }

    static let defaultPresets: [TagModel] = [
        TagModel(name: "Недосып", isDefault: true),
        TagModel(name: "Тренировка", isDefault: true),
        TagModel(name: "Много работы", isDefault: true),
        TagModel(name: "Стресс", isDefault: true),
        TagModel(name: "Результат", isDefault: true),
        TagModel(name: "Залип в экран", isDefault: true),
        TagModel(name: "Отдых", isDefault: true)
    ]
}
