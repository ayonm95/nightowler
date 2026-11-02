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

        let isAwake = state.mode == .on || state.isAssertionActive || (state.mode == .autoWatch && !state.activeTasks.isEmpty)
        let isClamshell = state.isClamshellActive

        let icon = OwlIconGenerator.makeIcon(isAwake: isAwake, isClamshell: isClamshell)
        button.image = icon
    }
}

// MARK: - Minimalist Vector Owl Menu Bar Icon Generator

public enum OwlIconGenerator {
    public static func makeIcon(isAwake: Bool, isClamshell: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.saveGState()

            // 1. Owl Head & Ear Tufts Silhouette
            let path = CGMutablePath()
            // Bottom chin
            path.move(to: CGPoint(x: 9.0, y: 2.2))
            // Right lower body & cheek
            path.addCurve(
                to: CGPoint(x: 16.0, y: 8.5),
                control1: CGPoint(x: 13.2, y: 2.2),
                control2: CGPoint(x: 16.0, y: 5.2)
            )
            // Right ear tuft (tip)
            path.addCurve(
                to: CGPoint(x: 14.8, y: 15.8),
                control1: CGPoint(x: 16.0, y: 12.0),
                control2: CGPoint(x: 15.5, y: 14.8)
            )
            // Top head dip (between ear tufts)
            path.addCurve(
                to: CGPoint(x: 3.2, y: 15.8),
                control1: CGPoint(x: 11.5, y: 13.6),
                control2: CGPoint(x: 6.5, y: 13.6)
            )
            // Left ear tuft down to left cheek
            path.addCurve(
                to: CGPoint(x: 2.0, y: 8.5),
                control1: CGPoint(x: 2.5, y: 14.8),
                control2: CGPoint(x: 2.0, y: 12.0)
            )
            // Left lower body back to chin
            path.addCurve(
                to: CGPoint(x: 9.0, y: 2.2),
                control1: CGPoint(x: 2.0, y: 5.2),
                control2: CGPoint(x: 4.8, y: 2.2)
            )
            path.closeSubpath()

            // Fill solid silhouette
            ctx.addPath(path)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()

            // 2. Cutouts (using destination-out so it cleanly cuts through the silhouette)
            ctx.setBlendMode(.destinationOut)

            if isAwake {
                // Wide open alert eyes
                let leftEye = CGRect(x: 4.2, y: 7.2, width: 3.4, height: 3.4)
                let rightEye = CGRect(x: 10.4, y: 7.2, width: 3.4, height: 3.4)
                ctx.fillEllipse(in: leftEye)
                ctx.fillEllipse(in: rightEye)
            } else {
                // Sleepy curved eye slits
                let leftSleep = CGMutablePath()
                leftSleep.move(to: CGPoint(x: 4.2, y: 8.8))
                leftSleep.addQuadCurve(to: CGPoint(x: 7.4, y: 8.8), control: CGPoint(x: 5.8, y: 7.5))

                let rightSleep = CGMutablePath()
                rightSleep.move(to: CGPoint(x: 10.6, y: 8.8))
                rightSleep.addQuadCurve(to: CGPoint(x: 13.8, y: 8.8), control: CGPoint(x: 12.2, y: 7.5))

                ctx.setLineWidth(1.1)
                ctx.setLineCap(.round)
                ctx.addPath(leftSleep)
                ctx.addPath(rightSleep)
                ctx.strokePath()
            }

            // Downward beak cutout
            let beakPath = CGMutablePath()
            beakPath.move(to: CGPoint(x: 8.0, y: 7.6))
            beakPath.addLine(to: CGPoint(x: 10.0, y: 7.6))
            beakPath.addLine(to: CGPoint(x: 9.0, y: 5.2))
            beakPath.closeSubpath()
            ctx.addPath(beakPath)
            ctx.fillPath()

            // Clamshell badge (crown dot on forehead)
            if isClamshell {
                let crownDot = CGRect(x: 8.2, y: 13.0, width: 1.6, height: 1.6)
                ctx.fillEllipse(in: crownDot)
            }

            // 3. For awake mode: restore normal blend mode and add pupils
            if isAwake {
                ctx.setBlendMode(.normal)
                ctx.setFillColor(NSColor.black.cgColor)
                let leftPupil = CGRect(x: 5.3, y: 8.3, width: 1.2, height: 1.2)
                let rightPupil = CGRect(x: 11.5, y: 8.3, width: 1.2, height: 1.2)
                ctx.fillEllipse(in: leftPupil)
                ctx.fillEllipse(in: rightPupil)
            }

            ctx.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }
}
