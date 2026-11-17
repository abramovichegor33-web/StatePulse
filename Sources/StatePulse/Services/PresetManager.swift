import SwiftUI

@MainActor
final class PresetManager: ObservableObject {
    static let shared = PresetManager()

    @Published var presets: [QuickPreset] = []

    private let userDefaultsKey = "statepulse_quick_presets"

    private init() {
        loadPresets()
    }

    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode([QuickPreset].self, from: data),
           !saved.isEmpty {
            presets = saved
        } else {
            presets = QuickPreset.defaultPresets
            savePresets()
        }
    }

    func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func updatePreset(_ preset: QuickPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }

    func addPreset(icon: String = "⚡️", label: String = "Новый", body: Int = 7, mind: Int = 7, focus: Int = 7, tag: String? = nil) {
        let newPreset = QuickPreset(
            id: UUID().uuidString,
            icon: icon,
            label: label,
            bodyScore: body,
            mindScore: mind,
            focusScore: focus,
            customScores: nil,
            tag: tag
        )
        presets.append(newPreset)
        savePresets()
    }

    func deletePreset(id: String) {
        guard presets.count > 1 else { return }
        presets.removeAll { $0.id == id }
        savePresets()
    }

    func resetToDefault() {
        presets = QuickPreset.defaultPresets
        savePresets()
    }
}
