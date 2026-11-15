import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupServices()
        MenuBarPanelController.shared.preload()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            if let image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "StatePulse")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "⚡︎"
            }

            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupServices() {
        // Start passive sleep/wake tracking
        _ = PassiveTrackerService.shared

        // Start smart notifications
        _ = NotificationService.shared

        // Start global hotkey monitoring (Option + Space)
        HotkeyService.shared.onHotkeyTriggered = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, let button = self.statusItem.button else { return }
                MenuBarPanelController.shared.toggle(relativeTo: button) {
                    DashboardWindowController.shared.showWindow()
                }
            }
        }
        HotkeyService.shared.startMonitoring()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            MenuBarPanelController.shared.toggle(relativeTo: sender) {
                DashboardWindowController.shared.showWindow()
            }
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Быстрый чек-ин", action: #selector(openPopoverFromMenu), keyEquivalent: " "))
        menu.addItem(NSMenuItem(title: "Аналитика и графики...", action: #selector(openDashboardFromMenu), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Завершить StatePulse", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so normal left-clicks continue to work
    }

    @objc private func openPopoverFromMenu() {
        if let button = statusItem.button {
            MenuBarPanelController.shared.show(relativeTo: button) {
                DashboardWindowController.shared.showWindow()
            }
        }
    }

    @objc private func openDashboardFromMenu() {
        DashboardWindowController.shared.showWindow()
    }

    @objc private func quitApp() {
        PassiveTrackerService.shared.saveCurrentState()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        PassiveTrackerService.shared.saveCurrentState()
        HotkeyService.shared.stopMonitoring()
    }
}
