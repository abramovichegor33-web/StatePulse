import AppKit
import Carbon

@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var localMonitor: Any?
    var onHotkeyTriggered: (() -> Void)?

    private init() {}

    func startMonitoring() {
        registerCarbonHotKey()
        registerLocalMonitor()
    }

    private func registerCarbonHotKey() {
        stopCarbonHotKey()

        // Carbon global HotKey: Option + Space
        // kVK_Space = 49 (Spacebar)
        // optionKey = 2048 (0x0800)
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
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            print("StatePulse: RegisterEventHotKey returned code \(regStatus)")
        } else {
            print("StatePulse: Carbon Global HotKey (Option+Space) active")
        }
    }

    private func registerLocalMonitor() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.isOptionSpace(event: event) == true {
                    self?.onHotkeyTriggered?()
                    return nil
                }
                return event
            }
        }
    }

    private func isOptionSpace(event: NSEvent) -> Bool {
        let isSpaceKey = event.keyCode == 49
        let hasOptionModifier = event.modifierFlags.contains(.option)
        let hasNoOtherModifiers = !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control)
        return isSpaceKey && hasOptionModifier && hasNoOtherModifiers
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
}
