import SwiftUI

// MARK: - Color Extension for Hex
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8) / 255.0
        let blue = Double(hex & 0x0000FF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Soft White / Soft Black Design System
enum AppPalette {
    // Light Theme (Soft White)
    static let lightBackground = Color(hex: 0xF7F7F5)
    static let lightCard = Color(hex: 0xFFFFFF)
    static let lightBorder = Color(hex: 0xE8E8E6)
    static let lightTextPrimary = Color(hex: 0x1C1C1E)
    static let lightTextSecondary = Color(hex: 0x8E8E93)
    static let lightAccent = Color(hex: 0x1C1C1E)
    static let lightAccentText = Color(hex: 0xFFFFFF)

    // Dark Theme (Soft Black)
    static let darkBackground = Color(hex: 0x141414)
    static let darkCard = Color(hex: 0x1E1E1E)
    static let darkBorder = Color(hex: 0x2C2C2E)
    static let darkTextPrimary = Color(hex: 0xF2F2F7)
    static let darkTextSecondary = Color(hex: 0x8E8E93)
    static let darkAccent = Color(hex: 0xF2F2F7)
    static let darkAccentText = Color(hex: 0x141414)

    // Metrics Accent Colors (Subtle & Elegant)
    static let bodyAccent = Color(hex: 0xE06C75)      // Warm Coral for Body
    static let mindAccent = Color(hex: 0x61AFEF)      // Calm Azure for Mind
    static let focusAccent = Color(hex: 0x98C379)     // Focus Green for Mind clarity
    static let compositeAccent = Color(hex: 0xC678DD) // Balanced Violet

    // Heatmap Levels (Light Mode)
    static let heatmapLightL0 = Color(hex: 0xECECE9)
    static let heatmapLightL1 = Color(hex: 0xD3D3CF)
    static let heatmapLightL2 = Color(hex: 0x9E9E9A)
    static let heatmapLightL3 = Color(hex: 0x555558)
    static let heatmapLightL4 = Color(hex: 0x1C1C1E)

    // Heatmap Levels (Dark Mode)
    static let heatmapDarkL0 = Color(hex: 0x222224)
    static let heatmapDarkL1 = Color(hex: 0x3E3E42)
    static let heatmapDarkL2 = Color(hex: 0x686870)
    static let heatmapDarkL3 = Color(hex: 0xAEAEB4)
    static let heatmapDarkL4 = Color(hex: 0xF2F2F7)
}

struct AppTheme {
    let isDark: Bool

    var background: Color { isDark ? AppPalette.darkBackground : AppPalette.lightBackground }
    var cardBackground: Color { isDark ? AppPalette.darkCard : AppPalette.lightCard }
    var cardBorder: Color { isDark ? AppPalette.darkBorder : AppPalette.lightBorder }
    var textPrimary: Color { isDark ? AppPalette.darkTextPrimary : AppPalette.lightTextPrimary }
    var textSecondary: Color { isDark ? AppPalette.darkTextSecondary : AppPalette.lightTextSecondary }
    var accent: Color { isDark ? AppPalette.darkAccent : AppPalette.lightAccent }
    var accentText: Color { isDark ? AppPalette.darkAccentText : AppPalette.lightAccentText }

    var bodyColor: Color { AppPalette.bodyAccent }
    var mindColor: Color { AppPalette.mindAccent }
    var focusColor: Color { AppPalette.focusAccent }
    var compositeColor: Color { AppPalette.compositeAccent }

    func heatmapColor(level: Int) -> Color {
        if isDark {
            switch level {
            case 1: return AppPalette.heatmapDarkL1
            case 2: return AppPalette.heatmapDarkL2
            case 3: return AppPalette.heatmapDarkL3
            case 4: return AppPalette.heatmapDarkL4
            default: return AppPalette.heatmapDarkL0
            }
        } else {
            switch level {
            case 1: return AppPalette.heatmapLightL1
            case 2: return AppPalette.heatmapLightL2
            case 3: return AppPalette.heatmapLightL3
            case 4: return AppPalette.heatmapLightL4
            default: return AppPalette.heatmapLightL0
            }
        }
    }
}
