import AppKit
import SwiftUI

private final class CustomMenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class MenuBarPanelController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = MenuBarPanelController()

    @Published var isShowingCard: Bool = false

    private var panel: CustomMenuBarPanel?
    private var eventMonitor: Any?
    private var localKeyMonitor: Any?
    private var onOpenDashboardHandler: (() -> Void)?
    private var isHiding: Bool = false

    private override init() {
        super.init()
    }

    func preload() {
        if panel == nil {
            setupPanel()
        }
    }

    private func setupPanel() {
        let p = CustomMenuBarPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 490),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.delegate = self

        let contentView = PopoverContentView(
            onClose: { [weak self] in
                self?.hide()
            },
            onOpenDashboard: { [weak self] in
                self?.hide()
                self?.onOpenDashboardHandler?()
            }
        )

        let hosting = NSHostingController(rootView: contentView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        p.contentViewController = hosting

        self.panel = p
    }

    func toggle(relativeTo statusButton: NSStatusBarButton, onOpenDashboard: @escaping () -> Void) {
        if let p = panel, p.isVisible, isShowingCard {
            hide()
        } else {
            show(relativeTo: statusButton, onOpenDashboard: onOpenDashboard)
        }
    }

    func show(relativeTo statusButton: NSStatusBarButton, onOpenDashboard: @escaping () -> Void) {
        self.onOpenDashboardHandler = onOpenDashboard
        self.isHiding = false

        Task {
            await CloudSyncService.shared.syncAll()
        }

        if panel == nil {
            setupPanel()
        }

        guard let p = panel else { return }

        // Position window strictly below status bar
        let screen = statusButton.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let buttonScreenRect: NSRect
        if let buttonWindow = statusButton.window {
            buttonScreenRect = buttonWindow.convertToScreen(statusButton.bounds)
        } else {
            buttonScreenRect = NSRect(x: screen.visibleFrame.maxX - 120, y: screen.visibleFrame.maxY, width: 24, height: 24)
        }

        let panelWidth: CGFloat = 340
        let bottomSafeLimit = screen.visibleFrame.minY + 12
        let topSafeLimit = buttonScreenRect.minY - 6
        let maxAvailableHeight = max(380, topSafeLimit - bottomSafeLimit)
        let panelHeight = min(490, maxAvailableHeight)

        var x = buttonScreenRect.midX - panelWidth / 2
        let minX = screen.visibleFrame.minX + 8
        let maxX = screen.visibleFrame.maxX - panelWidth - 8
        x = max(minX, min(maxX, x))

        let targetY = topSafeLimit - panelHeight

        p.setFrame(NSRect(x: x, y: targetY, width: panelWidth, height: panelHeight), display: true)
        p.alphaValue = 1.0

        // Reset state so animation fires cleanly
        isShowingCard = false
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Smooth perceptible fade-in and micro-slide
        withAnimation(.easeOut(duration: 0.28)) {
            self.isShowingCard = true
        }

        // Setup event monitors
        removeMonitors()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let p = self.panel, p.isVisible, self.isShowingCard, !self.isHiding else { return }
            let mouseLoc = NSEvent.mouseLocation
            if !p.frame.contains(mouseLoc) && !buttonScreenRect.contains(mouseLoc) {
                Task { @MainActor [weak self] in
                    self?.hide()
                }
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hide()
                return nil
            }
            return event
        }
    }

    func hide() {
        guard let p = panel, p.isVisible, !isHiding else { return }

        isHiding = true
        removeMonitors()

        withAnimation(.easeIn(duration: 0.16)) {
            self.isShowingCard = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self = self else { return }
            if self.isHiding {
                p.orderOut(nil)
                self.isHiding = false
            }
        }
    }

    private func removeMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let keyMon = localKeyMonitor {
            NSEvent.removeMonitor(keyMon)
            localKeyMonitor = nil
        }
    }

    var isVisible: Bool {
        (panel?.isVisible ?? false) && isShowingCard
    }
}
