import AppKit
import SwiftUI
import NightowlerCore

public final class MenuPanelWindowController: NSWindowController, @unchecked Sendable {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    public init(rootView: AnyView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Theme.panelWidth, height: Theme.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: rootView)

        super.init(window: panel)

        setupOutsideClickMonitoring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
    }

    public func toggle(relativeTo statusButton: NSStatusBarButton) {
        guard let window = window else { return }

        if window.isVisible {
            close()
        } else {
            show(relativeTo: statusButton)
        }
    }

    public func show(relativeTo statusButton: NSStatusBarButton) {
        guard let window = window, let buttonWindow = statusButton.window else { return }

        let buttonFrameInScreen = buttonWindow.convertToScreen(statusButton.frame)
        let panelWidth = window.frame.width
        let panelHeight = window.frame.height

        var originX = buttonFrameInScreen.midX - (panelWidth / 2)
        let originY = buttonFrameInScreen.minY - panelHeight - 6

        // Prevent off-screen placement
        if let screen = statusButton.window?.screen ?? NSScreen.main {
            if originX + panelWidth > screen.visibleFrame.maxX {
                originX = screen.visibleFrame.maxX - panelWidth - 8
            }
            if originX < screen.visibleFrame.minX {
                originX = screen.visibleFrame.minX + 8
            }
        }

        window.setFrameOrigin(NSPoint(x: originX, y: originY))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupOutsideClickMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let window = self?.window, window.isVisible else { return }
            self?.close()
        }
    }
}
