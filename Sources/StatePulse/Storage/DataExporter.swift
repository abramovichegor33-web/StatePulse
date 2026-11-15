import Foundation
import AppKit

struct BackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let checkIns: [CheckInRecord]
    let customTags: [TagModel]
    let metrics: [MetricDefinition]?
}

@MainActor
final class DataExporter {
    static let shared = DataExporter()

    private init() {}

    func exportToJSON() {
        let checkIns = DatabaseManager.shared.fetchAllCheckIns()
        let customTags = DatabaseManager.shared.fetchCustomTags()
        let metrics = MetricManager.shared.metrics

        let payload = BackupPayload(
            version: 2,
            exportedAt: Date(),
            checkIns: checkIns,
            customTags: customTags,
            metrics: metrics
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(payload) else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        savePanel.nameFieldStringValue = "StatePulse_Backup_\(formatter.string(from: Date())).json"
        savePanel.title = "Экспорт данных StatePulse (JSON)"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? data.write(to: url)
        }
    }

    func exportToCSV() {
        let checkIns = DatabaseManager.shared.fetchAllCheckIns()
        let metrics = MetricManager.shared.metrics

        var metricHeaders = metrics.map { $0.name }.joined(separator: ",")
        if metricHeaders.isEmpty {
            metricHeaders = "BodyEnergy,MentalResource,Focus"
        }

        var csvString = "ID,Timestamp,Date,Time,\(metricHeaders),CompositeScore,Tags,ScreenTimeMinutes,Note\n"

        let isoFormatter = ISO8601DateFormatter()

        for record in checkIns {
            let tagsEscaped = "\"" + record.tags.joined(separator: ", ") + "\""
            let noteEscaped = "\"" + record.note.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let screenMinutes = record.screenTimeSeconds / 60

            let metricValues = metrics.map { "\(record.score(for: $0.id))" }.joined(separator: ",")

            let line = "\(record.id.uuidString),\(isoFormatter.string(from: record.timestamp)),\(record.dateString),\(record.timeString),\(metricValues),\(String(format: "%.2f", record.compositeScore)),\(tagsEscaped),\(screenMinutes),\(noteEscaped)\n"
            csvString.append(line)
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        savePanel.nameFieldStringValue = "StatePulse_Export_\(formatter.string(from: Date())).csv"
        savePanel.title = "Экспорт данных StatePulse (CSV)"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? csvString.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func importFromJSON() -> (success: Bool, count: Int, error: String?) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.title = "Импорт данных StatePulse (JSON)"

        guard openPanel.runModal() == .OK, let url = openPanel.url else {
            return (false, 0, nil)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(BackupPayload.self, from: data)

            var importedCount = 0
            for record in payload.checkIns {
                DatabaseManager.shared.saveCheckIn(record)
                importedCount += 1
            }

            for tag in payload.customTags {
                DatabaseManager.shared.saveCustomTag(name: tag.name)
            }

            if let importedMetrics = payload.metrics, !importedMetrics.isEmpty {
                MetricManager.shared.metrics = importedMetrics
                MetricManager.shared.saveMetrics()
            }

            return (true, importedCount, nil)
        } catch {
            return (false, 0, error.localizedDescription)
        }
    }
}
