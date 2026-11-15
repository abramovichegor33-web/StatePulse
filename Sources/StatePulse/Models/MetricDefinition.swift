import SwiftUI

struct MetricDefinition: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var subtitle: String
    var icon: String
    var colorHex: UInt32
    var orderIndex: Int
    var isEnabled: Bool

    var color: Color {
        Color(hex: colorHex)
    }

    static let defaultMetrics: [MetricDefinition] = [
        MetricDefinition(
            id: "body",
            name: "Физическая энергия",
            subtitle: "Тело и тонус",
            icon: "bolt.heart.fill",
            colorHex: 0xE06C75,
            orderIndex: 0,
            isEnabled: true
        ),
        MetricDefinition(
            id: "mind",
            name: "Моральный ресурс",
            subtitle: "Настроение и покой",
            icon: "brain.head.profile",
            colorHex: 0x61AFEF,
            orderIndex: 1,
            isEnabled: true
        ),
        MetricDefinition(
            id: "focus",
            name: "Фокус и ясность",
            subtitle: "Концентрация ума",
            icon: "target",
            colorHex: 0x98C379,
            orderIndex: 2,
            isEnabled: true
        )
    ]

    static let availableIcons: [String] = [
        "bolt.heart.fill",
        "brain.head.profile",
        "target",
        "moon.stars.fill",
        "figure.run",
        "flame.fill",
        "sparkles",
        "battery.100.bolt",
        "leaf.fill",
        "cup.and.saucer.fill",
        "dumbbell.fill",
        "heart.circle.fill"
    ]

    static let availableColors: [UInt32] = [
        0xE06C75, // Coral
        0x61AFEF, // Azure
        0x98C379, // Green
        0xC678DD, // Purple
        0xD19A66, // Orange
        0xEC407A, // Pink
        0x00ACC1, // Teal
        0xE5C07B  // Yellow
    ]
}
