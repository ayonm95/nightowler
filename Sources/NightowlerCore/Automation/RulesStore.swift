import Foundation

public final class RulesStore: @unchecked Sendable {
    public static let shared = RulesStore()

    private let lock = NSLock()
    private var _rules: [Rule] = []
    private let fileURL: URL

    public var rules: [Rule] {
        lock.lock()
        defer { lock.unlock() }
        return _rules
    }

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Nightowler")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("rules.json")

        load()
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([Rule].self, from: data)
                self._rules = decoded
                return
            } catch {
                print("Failed to decode rules.json: \(error), recreating defaults")
            }
        }

        self._rules = defaultRules()
        saveLocked()
    }

    public func save() {
        lock.lock()
        defer { lock.unlock() }
        saveLocked()
    }

    private func saveLocked() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(_rules)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save rules.json: \(error)")
        }
    }

    public func addRule(_ rule: Rule) {
        lock.lock()
        _rules.append(rule)
        saveLocked()
        lock.unlock()
    }

    public func updateRule(_ rule: Rule) {
        lock.lock()
        if let idx = _rules.firstIndex(where: { $0.id == rule.id }) {
            _rules[idx] = rule
            saveLocked()
        }
        lock.unlock()
    }

    public func deleteRule(id: String) {
        lock.lock()
        _rules.removeAll { $0.id == id && !$0.isBuiltIn }
        saveLocked()
        lock.unlock()
    }

    public func toggleRule(id: String) {
        lock.lock()
        if let idx = _rules.firstIndex(where: { $0.id == id }) {
            _rules[idx].isEnabled.toggle()
            _rules[idx].updatedAt = Date().timeIntervalSince1970
            saveLocked()
        }
        lock.unlock()
    }

    public func resetToDefaults() {
        lock.lock()
        _rules = defaultRules()
        saveLocked()
        lock.unlock()
    }

    private func defaultRules() -> [Rule] {
        let now = Date().timeIntervalSince1970
        return [
            Rule(
                id: UUID().uuidString,
                name: "Claude Code → keep awake + AI cooling",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.claude-code",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "claude")],
                actions: [.startKeepAwake, .setCoolingPreset("aiWorkload")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Codex → keep awake + AI cooling",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.codex",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "codex")],
                actions: [.startKeepAwake, .setCoolingPreset("aiWorkload")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Cursor → keep awake + AI cooling",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.cursor",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "cursor")],
                actions: [.startKeepAwake, .setCoolingPreset("aiWorkload")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Ollama → keep awake + AI cooling",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.ollama",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "ollama")],
                actions: [.startKeepAwake, .setCoolingPreset("aiWorkload")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "LM Studio → keep awake + AI cooling",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.lm-studio",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "lmstudio")],
                actions: [.startKeepAwake, .setCoolingPreset("aiWorkload")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Docker → keep awake + balanced cooling",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.docker",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "docker")],
                actions: [.startKeepAwake, .setCoolingPreset("balanced")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Python (heavy task) → keep awake",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.python",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "python")],
                actions: [.startKeepAwake, .setCoolingPreset("aiWorkload")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Node / npm → keep awake",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.node-npm",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "node")],
                actions: [.startKeepAwake, .setCoolingPreset("balanced")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Xcode build → keep awake",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.xcode-build",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "xcodebuild")],
                actions: [.startKeepAwake, .setCoolingPreset("balanced")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "ffmpeg → keep awake",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.ffmpeg",
                cooldownSeconds: 300,
                conditions: [.processRunning(pattern: "ffmpeg")],
                actions: [.startKeepAwake, .setCoolingPreset("balanced")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Battery < 10% → notify",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.battery-warn-10",
                cooldownSeconds: 300,
                conditions: [.batteryBelow(percent: 10), .onBatteryPower],
                actions: [.notify(title: "Battery Low Warning", body: "Nightowler is monitoring your remaining battery reserve.")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Battery < 5% → sleep the Mac",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.battery-sleep-5",
                cooldownSeconds: 300,
                conditions: [.batteryBelow(percent: 5), .onBatteryPower],
                actions: [.sleepMac],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Temperature > 90°C for 5 min → max fans + notify",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.temp-fan-90",
                cooldownSeconds: 600,
                conditions: [.temperatureAbove(celsius: 90, durationSeconds: 300)],
                actions: [.setCoolingPreset("emergencyMax"), .notify(title: "Mac running hot", body: "Fans maxed to protect hardware.")],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "Temperature > 95°C for 2 min → sleep the Mac",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.temp-sleep-95",
                cooldownSeconds: 600,
                conditions: [.temperatureAbove(celsius: 95, durationSeconds: 120)],
                actions: [.sleepMac],
                createdAt: now,
                updatedAt: now
            ),
            Rule(
                id: UUID().uuidString,
                name: "No AI workload for 10 min → stop keep-awake",
                isEnabled: true,
                isBuiltIn: true,
                builtinKey: "builtin.no-workload-stop",
                cooldownSeconds: 300,
                conditions: [.noMatchingWorkloadFor(seconds: 600)],
                actions: [.stopKeepAwake],
                createdAt: now,
                updatedAt: now
            )
        ]
    }
}

