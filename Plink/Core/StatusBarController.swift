import AppKit
import SwiftData

@MainActor
final class StatusBarController {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var container: ModelContainer?
    private(set) var isRunning: Bool = true {
        didSet { updateIcon() }
    }

    private init() {}

    func setup(container: ModelContainer) {
        self.container = container

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.action = #selector(handleClick)
        item.button?.target = self
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = item

        updateIcon()
        buildMenu()
    }

    // MARK: – Icon

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusImage(running: isRunning)
    }

    private func makeStatusImage(running: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Checklist symbol
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let symbol = NSImage(systemSymbolName: "checklist", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            symbol?.draw(in: NSRect(x: 1, y: 2, width: 13, height: 13))

            // Status dot
            let dotRadius: CGFloat = 3.5
            let dotCenter = NSPoint(x: rect.maxX - dotRadius - 0.5, y: rect.minY + dotRadius + 0.5)
            let dotRect = NSRect(
                x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            )
            (running ? NSColor.systemGreen : NSColor.systemRed).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: – Click

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem?.menu = buildMenu()
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleMainWindow()
        }
    }

    // MARK: – Menu

    @discardableResult
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Plink", action: #selector(openApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quickAddItem = NSMenuItem(title: "New Task", action: #selector(triggerQuickAdd), keyEquivalent: "")
        quickAddItem.target = self
        quickAddItem.keyEquivalentModifierMask = .option
        menu.addItem(quickAddItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Plink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        return menu
    }

    // MARK: – Actions

    @objc private func openApp() {
        toggleMainWindow()
    }

    @objc private func triggerQuickAdd() {
        QuickAddPanelController.shared.toggle()
    }

    private func toggleMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) ?? NSApp.windows.first(where: { !($0 is NSPanel) }) {
            if window.isVisible && NSApp.isActive {
                NSApp.hide(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: – State

    func setError(_ hasError: Bool) {
        isRunning = !hasError
    }
}
