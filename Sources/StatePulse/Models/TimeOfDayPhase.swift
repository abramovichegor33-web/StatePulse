import SwiftUI

enum TimeOfDayPhase: String, CaseIterable, Identifiable, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Утро"
        case .afternoon: return "День"
        case .evening: return "Вечер"
        case .night: return "Ночь"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning: return Color(hex: 0xF6AD55) // Morning Amber
        case .afternoon: return Color(hex: 0x63B3ED) // Midday Sky
        case .evening: return Color(hex: 0xED64A6) // Sunset Rose
        case .night: return Color(hex: 0x9F7AEA) // Night Violet
        }
    }

    var timeRangeString: String {
        switch self {
        case .morning: return "06:00 – 12:00"
        case .afternoon: return "12:00 – 17:00"
        case .evening: return "17:00 – 22:00"
        case .night: return "22:00 – 06:00"
        }
    }

    static func current(for date: Date = Date()) -> TimeOfDayPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}
