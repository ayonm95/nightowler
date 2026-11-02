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

    /// Verify whether SleepDisabled is actually enabled in macOS kernel power management
    public func isSleepActuallyDisabled() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g"]
        task.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return false }
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.starts(with: "SleepDisabled") {
                    return trimmed.contains("1")
                }
            }
        } catch {
            return false
        }
        return false
    }

    private func updateState(active: Bool) {
        lock.lock()
        _isClamshellActive = active
        lock.unlock()
        onStateChanged?(active)
    }

    /// Enable closed-lid execution by disabling sleep
    @discardableResult
    public func enableClosedLid() -> (success: Bool, error: String?) {
        // Attempt 1: Privileged Helper Daemon via XPC
        if HelperClient.shared.isHelperAvailable {
            let res = HelperClient.shared.setDisableSleep(true)
            if res.success && isSleepActuallyDisabled() {
                updateState(active: true)
                PowerAssertionManager.shared.createSystemAssertion(reason: "Nightowler Clamshell Active")
                return (true, nil)
            }
        }

        // Attempt 2: Direct / Sudo / AppleScript command execution
        let res = runPmset(args: ["-a", "disablesleep", "1"])
        
        // Strict Kernel Verification: Confirm SleepDisabled is 1
        if isSleepActuallyDisabled() {
            updateState(active: true)
            PowerAssertionManager.shared.createSystemAssertion(reason: "Nightowler Clamshell Active")
            return (true, nil)
        }

        updateState(active: false)
        let errMsg = res.error ?? "Failed to set SleepDisabled=1 in macOS kernel. Run 'sudo pmset -a disablesleep 1' or 'nightowler setup'."
        return (false, errMsg)
    }

    /// Restore normal macOS sleep behavior
    @discardableResult
    public func disableClosedLid() -> (success: Bool, error: String?) {
        if HelperClient.shared.isHelperAvailable {
            _ = HelperClient.shared.setDisableSleep(false)
        }

        let res = runPmset(args: ["-a", "disablesleep", "0"])
        updateState(active: false)
        return (res.success, res.error)
    }

    public func restoreNormalSleepSync() {
        if HelperClient.shared.isHelperAvailable {
            _ = HelperClient.shared.setDisableSleep(false)
        }
        _ = runPmset(args: ["-a", "disablesleep", "0"])
        lock.lock()
        _isClamshellActive = false
        lock.unlock()
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
        // Tier 1: Try passwordless sudo (/usr/bin/sudo -n /usr/bin/pmset <args>)
        let sudoTask = Process()
        sudoTask.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        sudoTask.arguments = ["-n", "/usr/bin/pmset"] + args
        sudoTask.standardInput = FileHandle.nullDevice
        let sudoPipe = Pipe()
        sudoTask.standardError = sudoPipe
        sudoTask.standardOutput = sudoPipe

        if let _ = try? sudoTask.run() {
            sudoTask.waitUntilExit()
            let data = sudoPipe.fileHandleForReading.readDataToEndOfFile()
            let output = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if sudoTask.terminationStatus == 0 && !output.contains("must be run as root") && !output.contains("password is required") {
                return (true, nil)
            }
        }

        // Tier 2: Try direct /usr/bin/pmset (works if running as root or privileged)
        let directTask = Process()
        directTask.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        directTask.arguments = args
        directTask.standardInput = FileHandle.nullDevice
        let directPipe = Pipe()
        directTask.standardError = directPipe
        directTask.standardOutput = directPipe

        if let _ = try? directTask.run() {
            directTask.waitUntilExit()
            let data = directPipe.fileHandleForReading.readDataToEndOfFile()
            let output = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if directTask.terminationStatus == 0 && !output.contains("must be run as root") {
                return (true, nil)
            }
        }

        // Tier 3: If running in interactive GUI context, prompt via AppleScript administrator privileges
        if Bundle.main.bundleIdentifier != nil {
            let fullCmd = "/usr/bin/pmset " + args.joined(separator: " ")
            let scriptSource = "do shell script \"\(fullCmd)\" with administrator privileges"
            if let appleScript = NSAppleScript(source: scriptSource) {
                var errorDict: NSDictionary?
                appleScript.executeAndReturnError(&errorDict)
                if errorDict == nil {
                    return (true, nil)
                } else if let err = errorDict?[NSAppleScript.errorMessage] as? String {
                    return (false, err)
                }
            }
        }

        return (false, "Administrator privileges required to execute pmset \(args.joined(separator: " ")). Run 'nightowler setup'.")
    }
}

