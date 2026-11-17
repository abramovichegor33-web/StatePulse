import Foundation
import AppKit
import UserNotifications

struct ReminderTime: Identifiable, Codable, Equatable {
    var id: String { "\(hour):\(minute)" }
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    var displayString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published var reminders: [ReminderTime] = []
    @Published var isNotificationsAuthorized: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let userDefaultsKey = "statepulse_reminder_times"

    private override init() {
        super.init()
        loadReminders()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorization()
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor [weak self] in
                self?.authorizationStatus = settings.authorizationStatus
                self?.isNotificationsAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor [weak self] in
                self?.checkAuthorization()
                if granted {
                    self?.rescheduleAll()
                }
                completion?(granted)
            }
        }
    }

    func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode([ReminderTime].self, from: data) {
            reminders = saved
        } else {
            // Default reminders: 10:00, 15:00, 21:00
            reminders = [
                ReminderTime(hour: 10, minute: 0, isEnabled: true),
                ReminderTime(hour: 15, minute: 0, isEnabled: true),
                ReminderTime(hour: 21, minute: 0, isEnabled: true)
            ]
            saveReminders()
        }
    }

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        rescheduleAll()
    }

    func addReminder(hour: Int, minute: Int) {
        let reminder = ReminderTime(hour: hour, minute: minute, isEnabled: true)
        if !reminders.contains(where: { $0.hour == hour && $0.minute == minute }) {
            reminders.append(reminder)
            reminders.sort { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
            saveReminders()
        }
    }

    func toggleReminder(id: String) {
        if let idx = reminders.firstIndex(where: { $0.id == id }) {
            reminders[idx].isEnabled.toggle()
            saveReminders()
        }
    }

    func deleteReminder(id: String) {
        reminders.removeAll { $0.id == id }
        saveReminders()
    }

    func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard isNotificationsAuthorized else { return }

        for reminder in reminders where reminder.isEnabled {
            var dateComponents = DateComponents()
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = "Как ваше самочувствие?"
            content.body = "Сделайте быстрый чек-ин за 5 секунд, чтобы зафиксировать ритм."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "StatePulse_Reminder_\(reminder.id)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    print("StatePulse: Error scheduling reminder: \(error)")
                }
            }
        }
    }

    func sendTestNotification() {
        // Immediate audio feedback
        NSSound(named: "Glass")?.play()

        requestAuthorization { [weak self] granted in
            guard granted else {
                self?.checkAuthorization()
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Чек-ин состояния"
            content.body = "Тестовое напоминание: время зафиксировать уровень энергии и фокуса!"
            content.sound = .default

            // nil trigger sends immediately
            let request = UNNotificationRequest(
                identifier: "StatePulse_Test_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("StatePulse: Error sending notification: \(error)")
                }
            }
        }
    }

    func scheduleOneShotReminder(hour: Int, minute: Int, title: String, body: String) {
        requestAuthorization { granted in
            guard granted else { return }
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "StatePulse_Experiment_\(hour)_\(minute)_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    func scheduleSprintTimer(minutes: Int) {
        requestAuthorization { granted in
            guard granted else { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)

            let content = UNMutableNotificationContent()
            content.title = "🎯 Фокус-спринт завершён (\(minutes) мин)!"
            content.body = "Отличная работа! Сделайте 5-10 минутную паузу без экрана, чтобы перезагрузить внимание."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "StatePulse_Sprint_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    // Deliver notification banner even if app is frontmost
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list, .badge])
    }

    // Open check-in panel when notification is clicked
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            if let delegate = NSApp.delegate as? AppDelegate,
               let button = delegate.statusItem.button {
                MenuBarPanelController.shared.show(relativeTo: button) {
                    DashboardWindowController.shared.showWindow()
                }
            }
        }
        completionHandler()
    }
}
