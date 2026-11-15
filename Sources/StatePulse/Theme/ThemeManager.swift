import SwiftUI
import AppKit

enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая (Soft White)"
        case .dark: return "Тёмная (Soft Black)"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("app_theme_mode") var themeMode: ThemeMode = .system {
        didSet {
            updateEffectiveAppearance()
        }
    }

    @Published private(set) var isDarkMode: Bool = false

    private init() {
        updateEffectiveAppearance()

        // Listen for system appearance changes
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateEffectiveAppearance()
            }
        }
    }

    func updateEffectiveAppearance() {
        switch themeMode {
        case .system:
            let appearanceName = NSApp.effectiveAppearance.name
            isDarkMode = (appearanceName == .darkAqua || appearanceName == .vibrantDark)
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        }
    }

    var theme: AppTheme {
        AppTheme(isDark: isDarkMode)
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
