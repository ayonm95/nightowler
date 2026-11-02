import AppKit
import UserNotifications
import NightowlerCore

public final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var menuBar: MenuBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance: prevent duplicate menu bar icons and processes
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "com.nightowler.app"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let otherInstances = runningApps.filter { $0.processIdentifier != currentPID }
        if !otherInstances.isEmpty {
            fputs("Nightowler is already running (PID: \(otherInstances.first?.processIdentifier ?? 0)). Exiting duplicate instance.\n", stderr)
            exit(0)
        }

        // Run as menu-bar accessory app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Request local notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // Start core systems
        _ = AppState.shared
        menuBar = MenuBarController()

        ActivityLog.shared.logEvent(kind: "launched", text: "Nightowler guardian initialized")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        ActivityLog.shared.logEvent(kind: "terminated")

        // Critical safety: release all assertions and restore standard sleep
        PowerAssertionManager.shared.releaseAll()
        ClamshellManager.shared.restoreNormalSleepSync()
        _ = SMCController.shared.setFanMode(.auto)
        IPCServer.shared.stop()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
