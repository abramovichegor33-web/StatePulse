import AppKit
import Carbon

@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onHotkeyTriggered: (() -> Void)?

    private init() {}

    func startMonitoring() {
        // Local monitor when application is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isOptionSpace(event: event) == true {
                self?.onHotkeyTriggered?()
                return nil
            }
            return event
        }

        // Global monitor when other applications are active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isOptionSpace(event: event) == true {
                Task { @MainActor [weak self] in
                    self?.onHotkeyTriggered?()
                }
            }
        }
    }

    private func isOptionSpace(event: NSEvent) -> Bool {
        // Space keyCode is 49
        let isSpaceKey = event.keyCode == 49
        let hasOptionModifier = event.modifierFlags.contains(.option)
        let hasNoOtherModifiers = !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control)

        return isSpaceKey && hasOptionModifier && hasNoOtherModifiers
    }

    func stopMonitoring() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    deinit {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
