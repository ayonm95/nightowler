import Foundation

public enum StopReason: String, Codable, Sendable {
    case none = "none"
    case manual = "manual"
    case timerFinished = "timerFinished"
    case lowBattery = "lowBattery"
    case criticalBatterySleep = "criticalBatterySleep"
    case unplugged = "unplugged"
    case thermalCritical = "thermalCritical"
    case noWorkloadIdle = "noWorkloadIdle"
    case ruleTriggered = "ruleTriggered"
}

public final class SafetyGovernor: @unchecked Sendable {
    public static let shared = SafetyGovernor()

    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var criticalThermalStartedAt: Date?
    private var _lastStopReason: StopReason = .none
    private var _lastStopMessage: String = ""

    public var onEmergencyStop: ((StopReason, String) -> Void)?

    public var lastStopReason: (reason: StopReason, message: String) {
        lock.lock()
        defer { lock.unlock() }
        return (_lastStopReason, _lastStopMessage)
    }

    public init() {
        start()
    }

    deinit {
        stop()
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }

        if timer != nil { return }

        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        t.schedule(deadline: .now() + 1.0, repeating: 2.0)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        timer?.cancel()
        timer = nil
    }

    public func tick() {
        let settings = AppSettings.shared
        let battery = BatteryMonitor.shared.snapshot
        let thermal = ThermalMonitor.shared.snapshot
        let watcher = ProcessWatcher.shared
        let clamshell = ClamshellManager.shared
        let power = PowerAssertionManager.shared

        let isKeepingAwake = power.holdsSystemAssertion || clamshell.isClamshellActive

        guard isKeepingAwake else {
            lock.lock()
            criticalThermalStartedAt = nil
            lock.unlock()
            return
        }

        // 1. Critical Battery Cutoff (<= 5%): force sleep to prevent shutdown damage
        if battery.hasBattery && !battery.isOnACPower && battery.percent <= settings.criticalBatteryThreshold {
            let msg = "Critical battery at \(battery.percent)% (<= \(settings.criticalBatteryThreshold)%). Putting Mac to sleep to preserve battery."
            triggerStop(reason: .criticalBatterySleep, message: msg)
            WebhookManager.shared.sendNotification(title: "Emergency Battery Sleep", body: msg)
            ActivityLog.shared.logEvent(kind: "safetyGovernorTriggered", reason: msg)
            _ = clamshell.forceSleep()
            return
        }

        // 2. Low Battery Floor (e.g. <= 20%): stop keep awake
        if settings.batteryAutoStopEnabled && battery.hasBattery && !battery.isOnACPower && battery.percent <= settings.batteryThreshold {
            let msg = "Battery floor reached at \(battery.percent)% (threshold: \(settings.batteryThreshold)%). Releasing keep-awake."
            triggerStop(reason: .lowBattery, message: msg)
            WebhookManager.shared.sendNotification(title: "Low Battery Stop", body: msg)
            ActivityLog.shared.logEvent(kind: "safetyGovernorTriggered", reason: msg)
            return
        }

        // 3. Charging Only Mode: Mac unplugged
        if settings.chargingOnly && !battery.isOnACPower {
            let msg = "Mac was unplugged from AC power while Charging-Only mode was active."
            triggerStop(reason: .unplugged, message: msg)
            WebhookManager.shared.sendNotification(title: "Charging-Only Stop", body: msg)
            ActivityLog.shared.logEvent(kind: "safetyGovernorTriggered", reason: msg)
            return
        }

        // 4. Thermal Protection
        let temp = thermal.temperatureCelsius ?? (thermal.level == .critical ? 96.0 : (thermal.level == .serious ? 85.0 : 50.0))
        if settings.thermalAutoStop && (thermal.level == .critical || temp >= 95.0) {
            if settings.autoMaxFanOnCritical {
                _ = SMCController.shared.setFanMode(.max)
            }

            lock.lock()
            if criticalThermalStartedAt == nil {
                criticalThermalStartedAt = Date()
            }
            let duration = Date().timeIntervalSince(criticalThermalStartedAt!)
            lock.unlock()

            let msg = "CPU temperature critical at \(Int(temp))°C. Stopping keep-awake to protect Mac."
            ActivityLog.shared.logEvent(kind: "thermalCritical", value: temp, reason: msg)
            WebhookManager.shared.sendNotification(title: "Thermal Protection", body: msg)
            triggerStop(reason: .thermalCritical, message: msg)

            if duration > 120 {
                // If hot for more than 2 minutes, emergency sleep
                _ = clamshell.forceSleep()
            }
            return
        } else {
            lock.lock()
            criticalThermalStartedAt = nil
            lock.unlock()
        }

        // 5. Evaluate Smart Rules
        if settings.smartRulesEnabled {
            RuleEngine.shared.evaluate(
                battery: battery,
                thermal: thermal,
                activeTasks: watcher.activeTasks,
                lastActiveWorkloadTime: watcher.lastActiveAt
            )
        }
    }

    private func triggerStop(reason: StopReason, message: String) {
        lock.lock()
        _lastStopReason = reason
        _lastStopMessage = message
        lock.unlock()

        PowerAssertionManager.shared.releaseAll()
        _ = ClamshellManager.shared.disableClosedLid()
        onEmergencyStop?(reason, message)
    }
}

