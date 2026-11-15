import Foundation

struct DailyContext: Identifiable, Codable {
    var id: String { dateString }
    let dateString: String         // YYYY-MM-DD
    var activeSeconds: Int
    var wakeTime: Date?
    var sleepTime: Date?

    var formattedHoursAndMinutes: String {
        let hours = activeSeconds / 3600
        let minutes = (activeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }
}
