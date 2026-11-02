import Foundation

public final class AppSettings: @unchecked Sendable {
    public static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    public var preventDisplaySleep: Bool {
        get { defaults.bool(forKey: "nightowler.preventDisplaySleep") }
        set { defaults.set(newValue, forKey: "nightowler.preventDisplaySleep") }
    }

    public var batteryAutoStopEnabled: Bool {
        get { defaults.object(forKey: "nightowler.batteryAutoStopEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightowler.batteryAutoStopEnabled") }
    }

    public var batteryThreshold: Int {
        get {
            let v = defaults.integer(forKey: "nightowler.batteryThreshold")
            return v > 0 ? v : 20
        }
        set { defaults.set(newValue, forKey: "nightowler.batteryThreshold") }
    }

    public var criticalBatteryThreshold: Int {
        get {
            let v = defaults.integer(forKey: "nightowler.criticalBatteryThreshold")
            return v > 0 ? v : 5
        }
        set { defaults.set(newValue, forKey: "nightowler.criticalBatteryThreshold") }
    }

    public var chargingOnly: Bool {
        get { defaults.bool(forKey: "nightowler.chargingOnly") }
        set { defaults.set(newValue, forKey: "nightowler.chargingOnly") }
    }

    public var thermalAutoStop: Bool {
        get { defaults.object(forKey: "nightowler.thermalAutoStop") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightowler.thermalAutoStop") }
    }

    public var autoMaxFanOnCritical: Bool {
        get { defaults.object(forKey: "nightowler.autoMaxFanOnCritical") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightowler.autoMaxFanOnCritical") }
    }

    public var autoSleepNoWorkEnabled: Bool {
        get { defaults.object(forKey: "nightowler.autoSleepNoWorkEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightowler.autoSleepNoWorkEnabled") }
    }

    public var autoSleepNoWorkMinutes: Int {
        get {
            let v = defaults.integer(forKey: "nightowler.autoSleepNoWorkMinutes")
            return v > 0 ? v : 10
        }
        set { defaults.set(newValue, forKey: "nightowler.autoSleepNoWorkMinutes") }
    }

    public var autoSleepNoWorkActionSleep: Bool {
        get { defaults.bool(forKey: "nightowler.autoSleepNoWorkActionSleep") }
        set { defaults.set(newValue, forKey: "nightowler.autoSleepNoWorkActionSleep") }
    }

    public var smartCoolingEnabled: Bool {
        get { defaults.object(forKey: "nightowler.smartCoolingEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightowler.smartCoolingEnabled") }
    }

    public var smartRulesEnabled: Bool {
        get { defaults.object(forKey: "nightowler.smartRulesEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "nightowler.smartRulesEnabled") }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: "nightowler.launchAtLogin") }
        set { defaults.set(newValue, forKey: "nightowler.launchAtLogin") }
    }

    public var appAppearance: String {
        get { defaults.string(forKey: "nightowler.appAppearance") ?? "dark" }
        set { defaults.set(newValue, forKey: "nightowler.appAppearance") }
    }

    public init() {}
}
