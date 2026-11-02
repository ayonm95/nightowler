import Foundation
import Combine

public enum KeepAwakeMode: String, Codable, CaseIterable, Sendable {
    case off = "off"
    case on = "on"
    case chargingOnly = "chargingOnly"
    case autoWatch = "autoWatch"

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .on: return "Keep Awake"
        case .chargingOnly: return "Charging Only"
        case .autoWatch: return "Auto Workload Watch"
        }
    }
}

public final class AppState: ObservableObject, @unchecked Sendable {
    public static let shared = AppState()

    private let lock = NSLock()

    @Published public var mode: KeepAwakeMode = .off
    @Published public var isAssertionActive: Bool = false
    @Published public var isClamshellActive: Bool = false
    @Published public var sessionTimerExpiresAt: Date? = nil
    @Published public var sessionTimerDuration: TimeInterval? = nil
    @Published public var whyAwakeReason: String = "Mac sleeping normally"
    @Published public var whyStoppedReason: String = ""
    @Published public var batterySnapshot: BatterySnapshot = BatterySnapshot()
    @Published public var thermalSnapshot: ThermalSnapshot = ThermalSnapshot()
    @Published public var activeTasks: [WatchedTask] = []
    @Published public var coolingMode: FanMode = .auto
    @Published public var fanRPMs: [Int] = []
    @Published public var isHelperInstalled: Bool = false

    public let settings = AppSettings.shared
    public let capabilities = EngineCapabilities.shared
    public var license: EngineCapabilities { capabilities }
    public let power = PowerAssertionManager.shared
    public let clamshell = ClamshellManager.shared
    public let smc = SMCController.shared
    public let battery = BatteryMonitor.shared
    public let thermal = ThermalMonitor.shared
    public let watcher = ProcessWatcher.shared
    public let safety = SafetyGovernor.shared
    public let webhooks = WebhookManager.shared
    public let activity = ActivityLog.shared
    public let rules = RulesStore.shared
    public let ipc = IPCServer.shared

    @Published public var selectedTabName: String = "Overview"
    @Published public var newWatchPattern: String = ""
    @Published public var testSentNote: String? = nil

    private var sessionTimer: DispatchSourceTimer?
    private var uiUpdateTimer: DispatchSourceTimer?

    public init() {
        setupSubscriptions()
        setupIPC()
        startPeriodicUIUpdates()
        updateWhyAwakeReason()
    }

    private func setupSubscriptions() {
        battery.onBatteryChanged = { [weak self] snap in
            DispatchQueue.main.async {
                self?.batterySnapshot = snap
                self?.evaluateAutoState()
            }
        }

        thermal.onThermalChanged = { [weak self] snap in
            DispatchQueue.main.async {
                self?.thermalSnapshot = snap
            }
        }

        watcher.onTasksChanged = { [weak self] tasks in
            DispatchQueue.main.async {
                self?.activeTasks = tasks
                self?.evaluateAutoState()
            }
        }

        clamshell.onStateChanged = { [weak self] active in
            DispatchQueue.main.async {
                self?.isClamshellActive = active
                self?.updateWhyAwakeReason()
            }
        }

        safety.onEmergencyStop = { [weak self] reason, msg in
            DispatchQueue.main.async {
                self?.handleEmergencyStop(reason: reason, message: msg)
            }
        }

        RuleEngine.shared.onPerformAction = { [weak self] action, rule in
            DispatchQueue.main.async {
                self?.handleRuleAction(action, rule: rule)
            }
        }
    }

    private func startPeriodicUIUpdates() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 1.0, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let fans = self.smc.getAllFans()
            let rpms = fans.map { $0.actualRPM }
            let helperOK = HelperClient.shared.isHelperAvailable

            DispatchQueue.main.async {
                self.fanRPMs = rpms
                self.isHelperInstalled = helperOK
                self.checkSessionTimer()
                self.updateWhyAwakeReason()
            }
        }
        timer.resume()
        uiUpdateTimer = timer
    }

    // MARK: - Mode & Assertion Controls

    public func setMode(_ newMode: KeepAwakeMode) {
        lock.lock()
        mode = newMode
        lock.unlock()

        switch newMode {
        case .off:
            power.releaseAll()
            if clamshell.isClamshellActive {
                _ = clamshell.disableClosedLid()
            }
            cancelSessionTimer()
            isAssertionActive = false
            activity.logEvent(kind: "keepAwakeStopped", text: "manual stop")

        case .on:
            _ = power.createSystemAssertion(reason: "Nightowler Active Session")
            if settings.preventDisplaySleep {
                _ = power.createDisplayAssertion(reason: "Nightowler Screen Awake")
            }
            isAssertionActive = true
            activity.logEvent(kind: "keepAwakeStarted", text: "on")

        case .chargingOnly:
            if batterySnapshot.isOnACPower {
                _ = power.createSystemAssertion(reason: "Nightowler AC Powered Guard")
                if settings.preventDisplaySleep {
                    _ = power.createDisplayAssertion(reason: "Nightowler Screen Awake")
                }
                isAssertionActive = true
                activity.logEvent(kind: "keepAwakeStarted", text: "chargingOnly")
            } else {
                power.releaseAll()
                isAssertionActive = false
                whyStoppedReason = "Device not connected to AC power"
            }

        case .autoWatch:
            evaluateAutoState()
            activity.logEvent(kind: "keepAwakeStarted", text: "autoWatch")
        }

        updateWhyAwakeReason()
    }

    public func toggleKeepAwake() {
        if mode == .off {
            setMode(.on)
        } else {
            setMode(.off)
        }
    }

    public func setClamshell(enabled: Bool) {
        if enabled {
            let res = clamshell.enableClosedLid()
            if res.success {
                isClamshellActive = true
                activity.logEvent(kind: "clamshellOn")
            } else {
                whyStoppedReason = res.error ?? "Failed to enable closed-lid mode"
            }
        } else {
            _ = clamshell.disableClosedLid()
            isClamshellActive = false
            activity.logEvent(kind: "clamshellOff")
        }
        updateWhyAwakeReason()
    }

    public func setSessionTimer(duration: TimeInterval) {
        cancelSessionTimer()

        let expiresAt = Date().addingTimeInterval(duration)
        sessionTimerExpiresAt = expiresAt
        sessionTimerDuration = duration

        if mode == .off {
            setMode(.on)
        }

        activity.logEvent(kind: "timerStarted", value: duration)
        updateWhyAwakeReason()
    }

    public func cancelSessionTimer() {
        sessionTimerExpiresAt = nil
        sessionTimerDuration = nil
    }

    private func checkSessionTimer() {
        guard let exp = sessionTimerExpiresAt else { return }
        if Date() >= exp {
            cancelSessionTimer()
            setMode(.off)
            whyStoppedReason = "Session timer finished"
            activity.logEvent(kind: "timerFinished")
            webhooks.sendNotification(title: "Session Completed", body: "Nightowler keep-awake session has completed.")
        }
    }

    public func evaluateAutoState() {
        guard mode == .autoWatch else { return }

        if settings.chargingOnly && !batterySnapshot.isOnACPower {
            power.releaseAll()
            isAssertionActive = false
            whyStoppedReason = "Device running on battery (Charging-Only mode)"
            updateWhyAwakeReason()
            return
        }

        if !activeTasks.isEmpty {
            _ = power.createSystemAssertion(reason: "Nightowler Auto Watch: \(activeTasks.first?.name ?? "Workload")")
            if settings.preventDisplaySleep {
                _ = power.createDisplayAssertion()
            }
            isAssertionActive = true
        } else {
            // Check idle grace timeout
            let idleSeconds = Date().timeIntervalSince(watcher.lastActiveAt)
            let maxIdleSeconds = Double(settings.autoSleepNoWorkMinutes * 60)
            if idleSeconds >= maxIdleSeconds {
                power.releaseAll()
                isAssertionActive = false
                whyStoppedReason = "No active developer tasks (idle timeout reached)"
            } else {
                // Keep active during grace window
                _ = power.createSystemAssertion(reason: "Nightowler Auto Watch Idle Grace Window")
                isAssertionActive = true
            }
        }
        updateWhyAwakeReason()
    }

    public func setFanMode(_ mode: FanMode) {
        coolingMode = mode
        _ = smc.setFanMode(mode)
        activity.logEvent(kind: "coolingModeChanged", text: mode.rawValue)
    }

    public func handleEmergencyStop(reason: StopReason, message: String) {
        setMode(.off)
        _ = clamshell.disableClosedLid()
        whyStoppedReason = message
        updateWhyAwakeReason()
    }

    public func handleRuleAction(_ action: RuleAction, rule: Rule) {
        activity.logEvent(kind: "ruleTriggered", reason: "Rule: \(rule.name)")

        switch action {
        case .startKeepAwake:
            setMode(.on)

        case .stopKeepAwake:
            setMode(.off)

        case .startClosedLid:
            setClamshell(enabled: true)

        case .stopClosedLid:
            setClamshell(enabled: false)

        case .setCoolingPreset(let preset):
            let mode = mapCoolingPreset(preset)
            setFanMode(mode)

        case .setFanPercent(let percent):
            let mode: FanMode = percent > 85 ? .max : (percent > 65 ? .high : (percent > 40 ? .boost : .auto))
            setFanMode(mode)

        case .sleepMac:
            _ = clamshell.forceSleep()

        case .notify(let title, let body):
            webhooks.sendNotification(title: title, body: body)

        case .sendWebhook(let message):
            webhooks.sendAlerts(title: "Nightowler Rule: \(rule.name)", body: message)
        }
    }

    private func mapCoolingPreset(_ preset: String) -> FanMode {
        switch preset.lowercased() {
        case "aiworkload", "boost":
            return .boost
        case "balanced", "high":
            return .high
        case "emergencymax", "max":
            return .max
        case "quiet", "off":
            return .off
        case "auto":
            return .auto
        default:
            return FanMode(rawValue: preset.lowercased()) ?? .auto
        }
    }

    public func updateWhyAwakeReason() {
        if isClamshellActive {
            if !activeTasks.isEmpty {
                let names = activeTasks.prefix(2).map { $0.name }.joined(separator: ", ")
                whyAwakeReason = "Clamshell Active: \(names) executing"
            } else if let exp = sessionTimerExpiresAt {
                let remaining = max(0, Int(exp.timeIntervalSinceNow / 60))
                whyAwakeReason = "Clamshell Active: \(remaining)m remaining"
            } else {
                whyAwakeReason = "Clamshell Guard Active (lid closed safe)"
            }
            return
        }

        switch mode {
        case .off:
            whyAwakeReason = "Mac sleeping normally"
        case .on:
            if let exp = sessionTimerExpiresAt {
                let remaining = max(0, Int(exp.timeIntervalSinceNow / 60))
                whyAwakeReason = "Session active (\(remaining)m left)"
            } else {
                whyAwakeReason = "Manual Keep-Awake active"
            }
        case .chargingOnly:
            whyAwakeReason = "Keeping awake while charging on AC power"
        case .autoWatch:
            if !activeTasks.isEmpty {
                let names = activeTasks.prefix(2).map { $0.name }.joined(separator: ", ")
                whyAwakeReason = "Auto Mode: \(names) executing"
            } else {
                whyAwakeReason = "Auto Mode: standby, monitoring tasks"
            }
        }
    }

    // MARK: - IPC Handler

    private func setupIPC() {
        ipc.onRequest = { [weak self] req in
            guard let self = self else {
                return IPCResponse(ok: false, message: "AppState unavailable")
            }
            return self.handleIPCRequest(req)
        }
        ipc.start()
    }

    private func handleIPCRequest(_ req: IPCRequest) -> IPCResponse {
        switch req.cmd.lowercased() {
        case "status":
            var tasks: [String] = []
            lock.lock()
            tasks = activeTasks.map { $0.name }
            let curMode = mode.rawValue
            let assertActive = power.holdsSystemAssertion
            let clamActive = clamshell.isClamshellActive
            let bSnap = batterySnapshot
            let tSnap = thermalSnapshot
            let cMode = coolingMode.rawValue
            let rpms = fanRPMs
            let whyA = whyAwakeReason
            let whyS = whyStoppedReason
            lock.unlock()

            return IPCResponse(
                ok: true,
                message: "Status OK",
                mode: curMode,
                assertionActive: assertActive,
                clamshellActive: clamActive,
                batteryPercent: bSnap.percent,
                isCharging: bSnap.isCharging,
                thermal: tSnap.level.rawValue,
                temperatureCelsius: tSnap.temperatureCelsius,
                tasks: tasks,
                patterns: watcher.patterns,
                coolingMode: cMode,
                fanControlSupported: smc.isAvailable,
                fanRPMs: rpms,
                whyAwake: whyA,
                whyStopped: whyS
            )

        case "start":
            if let secs = req.seconds, secs > 0 {
                self.setSessionTimer(duration: TimeInterval(secs))
            } else {
                self.setMode(.on)
            }
            return IPCResponse(ok: true, message: "Nightowler session started")

        case "stop":
            self.setMode(.off)
            return IPCResponse(ok: true, message: "Nightowler session stopped")

        case "clamshell":
            let sub = req.args?.first?.lowercased() ?? "toggle"
            if sub == "on" {
                self.setClamshell(enabled: true)
            } else if sub == "off" {
                self.setClamshell(enabled: false)
            } else {
                self.setClamshell(enabled: !self.isClamshellActive)
            }
            if sub == "on" && !self.isClamshellActive {
                return IPCResponse(ok: false, message: self.whyStoppedReason.isEmpty ? "Failed to enable clamshell sleep prevention. Run 'nightowler setup'." : self.whyStoppedReason, clamshellActive: false)
            }
            return IPCResponse(ok: true, message: "Clamshell mode: \(self.isClamshellActive ? "ON" : "OFF")", clamshellActive: self.isClamshellActive)

        case "autowatch":
            let sub = req.args?.first?.lowercased() ?? "toggle"
            if sub == "on" {
                self.setMode(.autoWatch)
            } else if sub == "off" {
                self.setMode(.off)
            } else {
                self.setMode(self.mode == .autoWatch ? .off : .autoWatch)
            }
            return IPCResponse(ok: true, message: "Auto mode updated")

        case "timer":
            if let secs = req.seconds ?? req.args?.first.flatMap(Int.init), secs > 0 {
                DispatchQueue.main.async {
                    self.setSessionTimer(duration: TimeInterval(secs))
                }
                return IPCResponse(ok: true, message: "Timer set for \(secs)s")
            }
            return IPCResponse(ok: false, message: "Usage: nightowler timer <seconds>")

        case "watch":
            let pats = req.patterns ?? req.args ?? []
            for p in pats {
                watcher.addPattern(p)
            }
            return IPCResponse(ok: true, message: "Added watch patterns: \(pats.joined(separator: ", "))")

        case "unwatch":
            let pats = req.patterns ?? req.args ?? []
            for p in pats {
                watcher.removePattern(p)
            }
            return IPCResponse(ok: true, message: "Removed watch patterns: \(pats.joined(separator: ", "))")

        case "listpatterns", "patterns":
            return IPCResponse(ok: true, message: "Watch patterns", patterns: watcher.patterns)

        case "fan", "setcooling":
            let modeStr = req.mode ?? req.args?.first ?? "auto"
            if let fm = FanMode(rawValue: modeStr.lowercased()) {
                DispatchQueue.main.async {
                    self.setFanMode(fm)
                }
                return IPCResponse(ok: true, message: "Fan mode set to \(fm.rawValue)")
            }
            return IPCResponse(ok: false, message: "Unknown fan mode: \(modeStr). Use off|auto|boost|high|max")

        case "sleep":
            let force = req.force ?? (req.args?.contains("--force") ?? false)
            if !force && !activeTasks.isEmpty {
                return IPCResponse(ok: false, message: "Refused: Active developer tasks running. Use --force to override.")
            }
            DispatchQueue.main.async {
                _ = self.clamshell.forceSleep()
            }
            return IPCResponse(ok: true, message: "System entering sleep")

        case "notify":
            let t = req.title ?? req.args?.first ?? "Nightowler"
            let b = req.body ?? (req.args?.count ?? 0 > 1 ? req.args?[1] : "") ?? ""
            webhooks.sendNotification(title: t, body: b)
            return IPCResponse(ok: true, message: "Notification dispatched")

        case "ping":
            return IPCResponse(ok: true, message: "pong")

        default:
            return IPCResponse(ok: false, message: "Unknown command: \(req.cmd)")
        }
    }
}
