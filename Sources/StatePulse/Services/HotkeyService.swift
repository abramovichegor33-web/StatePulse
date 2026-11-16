import AppKit
import Carbon

@MainActor
final class HotkeyService: ObservableObject {
    static let shared = HotkeyService()

    @Published var currentKeyCode: UInt32
    @Published var currentModifiers: UInt32

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var localMonitor: Any?
    var onHotkeyTriggered: (() -> Void)?

    private let keyCodeKey = "statepulse_hotkey_keycode"
    private let modifiersKey = "statepulse_hotkey_modifiers"

    private init() {
        let savedCode = UserDefaults.standard.object(forKey: keyCodeKey) as? Int ?? Int(kVK_Space)
        let savedMods = UserDefaults.standard.object(forKey: modifiersKey) as? Int ?? Int(optionKey)
        self.currentKeyCode = UInt32(savedCode)
        self.currentModifiers = UInt32(savedMods)
    }

    var displayString: String {
        Self.formatHotkey(keyCode: UInt16(currentKeyCode), carbonModifiers: currentModifiers)
    }

    var isDefault: Bool {
        currentKeyCode == UInt32(kVK_Space) && currentModifiers == UInt32(optionKey)
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodeKey)
        UserDefaults.standard.set(Int(modifiers), forKey: modifiersKey)
        registerCarbonHotKey()
    }

    func resetToDefault() {
        updateHotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
    }

    func startMonitoring() {
        registerCarbonHotKey()
        registerLocalMonitor()
    }

    private func registerCarbonHotKey() {
        stopCarbonHotKey()

        let hotKeyID = EventHotKeyID(signature: OSType(0x5354504C), id: UInt32(1)) // 'STPL'

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if status == noErr && hkID.id == 1 {
                DispatchQueue.main.async {
                    HotkeyService.shared.onHotkeyTriggered?()
                }
            }
            return noErr
        }

        _ = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        let regStatus = RegisterEventHotKey(
            currentKeyCode,
            currentModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            print("StatePulse: RegisterEventHotKey returned code \(regStatus)")
        } else {
            print("StatePulse: Carbon Global HotKey (\(displayString)) active")
        }
    }

    private func registerLocalMonitor() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                if self.isCurrentHotkey(event: event) {
                    self.onHotkeyTriggered?()
                    return nil
                }
                return event
            }
        }
    }

    private func isCurrentHotkey(event: NSEvent) -> Bool {
        guard UInt32(event.keyCode) == currentKeyCode else { return false }
        var carbonMods: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return carbonMods == currentModifiers
    }

    private func stopCarbonHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    func stopMonitoring() {
        stopCarbonHotKey()
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    static func carbonModifiers(from event: NSEvent) -> UInt32 {
        var carbonMods: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        return carbonMods
    }

    static func formatHotkey(keyCode: UInt16, carbonModifiers: UInt32) -> String {
        var parts: [String] = []

        if (carbonModifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (carbonModifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }

        let key = keyName(for: keyCode)
        parts.append(key)

        return parts.joined(separator: " ")
    }

    static func keyName(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Пробел"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "Esc"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            return "Клавиша \(keyCode)"
        }
    }
}
