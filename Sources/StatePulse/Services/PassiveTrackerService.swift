import AppKit
import Foundation

@MainActor
final class PassiveTrackerService: ObservableObject {
    static let shared = PassiveTrackerService()

    @Published private(set) var todayActiveSeconds: Int = 0
    private var lastWakeTime: Date?
    private var isSleeping: Bool = false

    private init() {
        loadTodayContext()
        setupNotificationObservers()
    }

    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func loadTodayContext() {
        let todayStr = getTodayDateString()
        if let context = DatabaseManager.shared.fetchDailyContext(for: todayStr) {
            todayActiveSeconds = context.activeSeconds
        } else {
            todayActiveSeconds = 0
        }
        lastWakeTime = Date()
    }

    private func setupNotificationObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSleep()
            }
        }

        workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSleep()
            }
        }

        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWake()
            }
        }

        workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWake()
            }
        }
    }

    private func handleSleep() {
        guard !isSleeping else { return }
        isSleeping = true

        if let wake = lastWakeTime {
            let sessionDuration = Int(Date().timeIntervalSince(wake))
            if sessionDuration > 0 {
                todayActiveSeconds += sessionDuration
                saveCurrentState()
            }
        }
        lastWakeTime = nil
    }

    private func handleWake() {
        isSleeping = false
        lastWakeTime = Date()
    }

    func getCurrentActiveSeconds() -> Int {
        var total = todayActiveSeconds
        if !isSleeping, let wake = lastWakeTime {
            let currentSession = Int(Date().timeIntervalSince(wake))
            if currentSession > 0 {
                total += currentSession
            }
        }
        return total
    }

    func saveCurrentState() {
        let todayStr = getTodayDateString()
        let context = DailyContext(
            dateString: todayStr,
            activeSeconds: getCurrentActiveSeconds(),
            wakeTime: lastWakeTime,
            sleepTime: isSleeping ? Date() : nil
        )
        DatabaseManager.shared.saveDailyContext(context)
    }

    var formattedScreenTime: String {
        let total = getCurrentActiveSeconds()
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }
}
