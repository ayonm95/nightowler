import Foundation
import AppKit

public struct WatchedTask: Codable, Identifiable, Sendable {
    public var id: String { "\(pid)-\(name)" }
    public let pid: Int32
    public let name: String
    public let pattern: String
    public let command: String
    public let cpuPercent: Double
    public let firstSeenAt: Date

    public init(pid: Int32, name: String, pattern: String, command: String, cpuPercent: Double = 0.0, firstSeenAt: Date = Date()) {
        self.pid = pid
        self.name = name
        self.pattern = pattern
        self.command = command
        self.cpuPercent = cpuPercent
        self.firstSeenAt = firstSeenAt
    }
}

public final class ProcessWatcher: @unchecked Sendable {
    public static let shared = ProcessWatcher()

    public static let defaultPatterns = [
        "claude",
        "cursor",
        "codex",
        "ollama",
        "lmstudio",
        "docker",
        "dockerd",
        "python",
        "python3",
        "node",
        "npm",
        "pnpm",
        "yarn",
        "bun",
        "vite",
        "xcodebuild",
        "cargo",
        "rustc",
        "go",
        "ffmpeg",
        "vllm",
        "goose"
    ]

    private let lock = NSLock()
    private var _patterns: Set<String> = Set(defaultPatterns)
    private var _activeTasks: [WatchedTask] = []
    private var _lastActiveAt: Date = Date()
    private var pollTimer: DispatchSourceTimer?
    public var onTasksChanged: (([WatchedTask]) -> Void)?

    public var patterns: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_patterns).sorted()
    }

    public var activeTasks: [WatchedTask] {
        lock.lock()
        defer { lock.unlock() }
        return _activeTasks
    }

    public var hasActiveWorkloads: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !_activeTasks.isEmpty
    }

    public var lastActiveAt: Date {
        lock.lock()
        defer { lock.unlock() }
        return _lastActiveAt
    }

    public init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func addPattern(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        lock.lock()
        _patterns.insert(trimmed)
        lock.unlock()
        scan()
    }

    public func removePattern(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        _patterns.remove(trimmed)
        lock.unlock()
        scan()
    }

    public func startMonitoring(interval: TimeInterval = 3.0) {
        lock.lock()
        defer { lock.unlock() }

        if pollTimer != nil { return }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now() + 0.5, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.scan()
        }
        timer.resume()
        pollTimer = timer
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        pollTimer?.cancel()
        pollTimer = nil
    }

    public func scan() {
        let currentPatterns: Set<String>
        lock.lock()
        currentPatterns = _patterns
        lock.unlock()

        var found: [WatchedTask] = []

        // Method 1: Scan GUI running applications
        for app in NSWorkspace.shared.runningApplications {
            let appName = (app.localizedName ?? "").lowercased()
            let bundleID = (app.bundleIdentifier ?? "").lowercased()
            let exeURL = app.executableURL?.lastPathComponent.lowercased() ?? ""

            for pat in currentPatterns {
                if appName.contains(pat) || bundleID.contains(pat) || exeURL.contains(pat) {
                    found.append(
                        WatchedTask(
                            pid: app.processIdentifier,
                            name: app.localizedName ?? "App",
                            pattern: pat,
                            command: app.executableURL?.path ?? appName
                        )
                    )
                    break
                }
            }
        }

        // Method 2: Scan terminal & command line background processes via ps
        let processLines = getProcessList()
        for (pid, cmd) in processLines {
            let cmdLower = cmd.lowercased()
            for pat in currentPatterns {
                // Ensure word boundary or sub-command match
                if cmdLower.contains(pat) {
                    // Check if already found in GUI apps
                    if !found.contains(where: { $0.pid == pid }) {
                        let name = cmd.split(separator: " ").first?.split(separator: "/").last.map(String.init) ?? pat
                        found.append(
                            WatchedTask(
                                pid: pid,
                                name: name,
                                pattern: pat,
                                command: cmd
                            )
                        )
                        break
                    }
                }
            }
        }

        lock.lock()
        _activeTasks = found
        if !found.isEmpty {
            _lastActiveAt = Date()
        }
        let callback = onTasksChanged
        lock.unlock()

        callback?(found)
    }

    private func getProcessList() -> [(pid: Int32, command: String)] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid,command"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            guard let text = String(data: data, encoding: .utf8) else { return [] }
            var results: [(pid: Int32, command: String)] = []

            for line in text.split(separator: "\n").dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2, let pid = Int32(parts[0]) {
                    // Don't watch Nightowler itself or ps
                    let cmd = String(parts[1])
                    if !cmd.contains("Nightowler") && !cmd.contains("nightowler") && !cmd.starts(with: "ps ") {
                        results.append((pid: pid, command: cmd))
                    }
                }
            }
            return results
        } catch {
            return []
        }
    }
}

