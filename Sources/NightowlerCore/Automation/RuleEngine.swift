import Foundation

public final class RuleEngine: @unchecked Sendable {
    public static let shared = RuleEngine()

    private let lock = NSLock()
    private var highTempSince: [String: Date] = [:]
    public var onPerformAction: ((RuleAction, Rule) -> Void)?

    public init() {}

    public func evaluate(
        battery: BatterySnapshot,
        thermal: ThermalSnapshot,
        activeTasks: [WatchedTask],
        lastActiveWorkloadTime: Date
    ) {
        let store = RulesStore.shared
        let rules = store.rules
        let now = Date().timeIntervalSince1970
        let nowDate = Date()

        for var rule in rules {
            guard rule.isEnabled else { continue }

            // Check cooldown
            if let lastTrigger = rule.lastTriggeredAt {
                if (now - lastTrigger) < Double(rule.cooldownSeconds) {
                    continue
                }
            }

            // Check conditions
            var allMatched = true
            for cond in rule.conditions {
                if !matchesCondition(
                    cond,
                    ruleId: rule.id,
                    battery: battery,
                    thermal: thermal,
                    activeTasks: activeTasks,
                    lastActiveWorkloadTime: lastActiveWorkloadTime,
                    nowDate: nowDate
                ) {
                    allMatched = false
                    break
                }
            }

            if allMatched {
                rule.lastTriggeredAt = now
                store.updateRule(rule)

                for action in rule.actions {
                    onPerformAction?(action, rule)
                }
            }
        }
    }

    private func matchesCondition(
        _ condition: RuleCondition,
        ruleId: String,
        battery: BatterySnapshot,
        thermal: ThermalSnapshot,
        activeTasks: [WatchedTask],
        lastActiveWorkloadTime: Date,
        nowDate: Date
    ) -> Bool {
        switch condition {
        case .processRunning(let pattern):
            return activeTasks.contains { $0.pattern.lowercased() == pattern.lowercased() || $0.name.lowercased().contains(pattern.lowercased()) }

        case .processNotRunning(let pattern):
            return !activeTasks.contains { $0.pattern.lowercased() == pattern.lowercased() || $0.name.lowercased().contains(pattern.lowercased()) }

        case .batteryBelow(let percent):
            return battery.percent < percent

        case .batteryAbove(let percent):
            return battery.percent > percent

        case .onBatteryPower:
            return !battery.isOnACPower

        case .onACPower:
            return battery.isOnACPower

        case .temperatureAbove(let celsius, let durationSeconds):
            let currentTemp = thermal.temperatureCelsius ?? (thermal.level == .critical ? 95.0 : (thermal.level == .serious ? 85.0 : 50.0))
            if currentTemp >= celsius {
                if let started = highTempSince[ruleId] {
                    return nowDate.timeIntervalSince(started) >= Double(durationSeconds)
                } else {
                    highTempSince[ruleId] = nowDate
                    return durationSeconds == 0
                }
            } else {
                highTempSince.removeValue(forKey: ruleId)
                return false
            }

        case .noMatchingWorkloadFor(let seconds):
            if !activeTasks.isEmpty {
                return false
            }
            return nowDate.timeIntervalSince(lastActiveWorkloadTime) >= Double(seconds)
        }
    }
}

