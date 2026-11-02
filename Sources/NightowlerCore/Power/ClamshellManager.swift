import Foundation
import IOKit

public final class ClamshellManager: @unchecked Sendable {
    public static let shared = ClamshellManager()

    private let lock = NSLock()
    private var _isClamshellActive: Bool = false
    public var onStateChanged: ((Bool) -> Void)?

    public var isClamshellActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isClamshellActive
    }

    public init() {
        // Register process termination hook to ensure sleep is restored
        atexit {
            ClamshellManager.shared.restoreNormalSleepSync()
        }
    }

    /// Check if this Mac has a lid (MacBook, MacBook Pro, MacBook Air)
    public var hasLid: Bool {
        // Check if there is an AppleSmartBattery or internal display
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        )
        if result == kIOReturnSuccess && iterator != 0 {
            let service = IOIteratorNext(iterator)
            IOObjectRelease(iterator)
            if service != 0 {
                IOObjectRelease(service)
                return true
            }
        }
        return false
    }

    /// Enable closed-lid execution by disabling sleep
    @discardableResult
    public func enableClosedLid() -> (success: Bool, error: String?) {
        lock.lock()
        defer { lock.unlock() }

        // Attempt via Helper XPC first, fallback to direct execution
        if HelperClient.shared.isHelperAvailable {
            let res = HelperClient.shared.setDisableSleep(true)
            if res.success {
                _isClamshellActive = true
                onStateChanged?(true)
                return (true, nil)
            }
        }

        // Direct command attempt (e.g. if run as root or via sudoers/AppleScript)
        let res = runPmset(args: ["-a", "disablesleep", "1"])
        if res.success {
            _isClamshellActive = true
            onStateChanged?(true)
            return (true, nil)
        }

        return (false, res.error ?? "Requires privileged helper or administrator permission to enable closed-lid mode.")
    }

    /// Restore normal macOS sleep behavior
    @discardableResult
    public func disableClosedLid() -> (success: Bool, error: String?) {
        lock.lock()
        defer { lock.unlock() }

        if HelperClient.shared.isHelperAvailable {
            let res = HelperClient.shared.setDisableSleep(false)
            if res.success {
                _isClamshellActive = false
                onStateChanged?(false)
                return (true, nil)
            }
        }

        let res = runPmset(args: ["-a", "disablesleep", "0"])
        _isClamshellActive = false
        onStateChanged?(false)
        return (res.success, res.error)
    }

    public func restoreNormalSleepSync() {
        _ = runPmset(args: ["-a", "disablesleep", "0"])
        if HelperClient.shared.isHelperAvailable {
            _ = HelperClient.shared.setDisableSleep(false)
        }
    }

    /// Force Mac to sleep immediately (used by emergency thermal/battery guards or user sleep command)
    @discardableResult
    public func forceSleep() -> (success: Bool, error: String?) {
        if HelperClient.shared.isHelperAvailable {
            return HelperClient.shared.forceSleep()
        }
        return runPmset(args: ["sleepnow"])
    }

    private func runPmset(args: [String]) -> (success: Bool, error: String?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = args
        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                return (true, nil)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "pmset failed with code \(task.terminationStatus)"
                return (false, output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

