import SwiftUI

@MainActor
final class MetricManager: ObservableObject {
    static let shared = MetricManager()

    @Published var metrics: [MetricDefinition] = []

    private let userDefaultsKey = "statepulse_metric_definitions"

    private init() {
        loadMetrics()
    }

    func loadMetrics() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode([MetricDefinition].self, from: data),
           !saved.isEmpty {
            metrics = saved.sorted(by: { $0.orderIndex < $1.orderIndex })
        } else {
            metrics = MetricDefinition.defaultMetrics
            saveMetrics()
        }
    }

    func saveMetrics() {
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func addMetric(name: String, subtitle: String = "", icon: String = "sparkles", colorHex: UInt32 = 0xC678DD) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newMetric = MetricDefinition(
            id: UUID().uuidString,
            name: trimmed,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            colorHex: colorHex,
            orderIndex: metrics.count,
            isEnabled: true
        )
        metrics.append(newMetric)
        saveMetrics()
    }

    func updateMetric(_ metric: MetricDefinition) {
        if let index = metrics.firstIndex(where: { $0.id == metric.id }) {
            metrics[index] = metric
            saveMetrics()
        }
    }

    func deleteMetric(id: String) {
        guard metrics.count > 1 else { return } // Keep at least 1 metric
        metrics.removeAll { $0.id == id }
        for (idx, _) in metrics.enumerated() {
            metrics[idx].orderIndex = idx
        }
        saveMetrics()
    }

    func resetToDefault() {
        metrics = MetricDefinition.defaultMetrics
        saveMetrics()
    }
}
