import AppKit
import SwiftUI
import SwiftData
import KeyboardShortcuts

// Borderless windows return false for canBecomeKey by default,
// blocking all keyboard input. This subclass fixes that without
// activating the app or surfacing the main window.
private final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickAddPanelController {
    static let shared = QuickAddPanelController()

    private var panel: NSPanel?
    private var container: ModelContainer?
    private weak var appState: AppState?

    private init() {}

    func setup(container: ModelContainer, appState: AppState) {
        self.container = container
        self.appState = appState
        KeyboardShortcuts.onKeyUp(for: .quickAdd) { [weak self] in
            Task { @MainActor in self?.toggle() }
        }
        NotificationCenter.default.addObserver(forName: .plinkLanguageChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    func toggle() {
        if let panel, panel.isVisible {
            dismiss()
        } else {
            show()
        }
    }

    // MARK: – Show

    private func show() {
        guard let container else { return }

        let screenWidth = NSScreen.main?.frame.width ?? 1280
        let panelWidth = screenWidth * 0.5

        let panel = QuickPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 98),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let accentColor = appState?.accentOption.color ?? Theme.defaultAccent
        let colorScheme = appState?.appearanceMode.colorScheme

        let view = QuickAddView(smartInputEnabled: appState?.smartInputEnabled ?? false) { [weak self] in self?.dismiss() }
            .modelContainer(container)
            .environment(\.appAccent, accentColor)
            .preferredColorScheme(colorScheme)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: panelWidth, height: 98)

        // Rounded corners via layer
        host.wantsLayer = true
        host.layer?.cornerRadius = 14
        host.layer?.masksToBounds = true

        panel.contentView = host
        panel.center()

        // Nudge upward from screen center
        if let screen = NSScreen.main {
            let frame = panel.frame
            let screenFrame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.origin.x,
                y: screenFrame.midY + 80
            ))
        }

        panel.orderFrontRegardless()
        panel.makeKey()

        self.panel = panel

        // Global click-outside monitor
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    // MARK: – Dismiss

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
