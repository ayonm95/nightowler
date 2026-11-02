import AppKit
import SwiftUI
import Combine
import NightowlerCore

public final class MenuBarController: NSObject, @unchecked Sendable {
    private var statusItem: NSStatusItem!
    private var panelController: MenuPanelWindowController?
    private var cancellables = Set<AnyCancellable>()
    private let state = AppState.shared

    public override init() {
        super.init()
        setupStatusItem()
        setupPanel()
        setupObservers()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateIcon()
        }
    }

    private func setupPanel() {
        let rootView = AnyView(MenuPanelView(state: state))
        panelController = MenuPanelWindowController(rootView: rootView)
    }

    private func setupObservers() {
        Publishers.CombineLatest3(state.$mode, state.$isClamshellActive, state.$isAssertionActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        state.$whyAwakeReason
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reason in
                self?.statusItem.button?.toolTip = "Nightowler: \(reason)"
            }
            .store(in: &cancellables)
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }

        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Right-click quick toggle
            state.toggleKeepAwake()
        } else {
            panelController?.toggle(relativeTo: button)
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName: String
        if state.isClamshellActive {
            symbolName = "lock.laptopcomputer"
        } else if state.mode == .on {
            symbolName = "eye.fill"
        } else if state.mode == .autoWatch {
            symbolName = state.activeTasks.isEmpty ? "sparkles" : "bolt.shield.fill"
        } else {
            symbolName = "moon.zzz"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Nightowler")?
            .withSymbolConfiguration(config)
        img?.isTemplate = true
        button.image = img
    }
}
