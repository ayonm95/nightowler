import Foundation
import IOKit.ps

public struct BatterySnapshot: Codable, Sendable {
    public let percent: Int
    public let isCharging: Bool
    public let isCharged: Bool
    public let isOnACPower: Bool
    public let hasBattery: Bool
    public let timeRemainingMinutes: Int?

    public init(
        percent: Int = 100,
        isCharging: Bool = false,
        isCharged: Bool = false,
        isOnACPower: Bool = true,
        hasBattery: Bool = false,
        timeRemainingMinutes: Int? = nil
    ) {
        self.percent = percent
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.isOnACPower = isOnACPower
        self.hasBattery = hasBattery
        self.timeRemainingMinutes = timeRemainingMinutes
    }
}

public final class BatteryMonitor: @unchecked Sendable {
    public static let shared = BatteryMonitor()

    private let lock = NSLock()
    private var _snapshot: BatterySnapshot = BatterySnapshot()
    private var pollTimer: DispatchSourceTimer?
    public var onBatteryChanged: ((BatterySnapshot) -> Void)?

    public var snapshot: BatterySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return _snapshot
    }

    public init() {
        refresh()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        if pollTimer != nil { return }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 1.0, repeating: 5.0)
        timer.setEventHandler { [weak self] in
            self?.refresh()
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

    public func refresh() {
        let newSnapshot = readPowerSources()
        lock.lock()
        _snapshot = newSnapshot
        let handler = onBatteryChanged
        lock.unlock()

        handler?(newSnapshot)
    }

    private func readPowerSources() -> BatterySnapshot {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatterySnapshot(percent: 100, isCharging: false, isCharged: true, isOnACPower: true, hasBattery: false)
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef], !sources.isEmpty else {
            return BatterySnapshot(percent: 100, isCharging: false, isCharged: true, isOnACPower: true, hasBattery: false)
        }

        var percent = 100
        var isCharging = false
        var isCharged = false
        var isOnACPower = true
        var hasBattery = false
        var timeRemaining: Int? = nil

        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let type = desc[kIOPSTypeKey as String] as? String, type == (kIOPSInternalBatteryType as String) {
                hasBattery = true
                if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int,
                   let max = desc[kIOPSMaxCapacityKey as String] as? Int, max > 0 {
                    percent = Int((Double(cur) / Double(max)) * 100.0)
                }
                if let charging = desc[kIOPSIsChargingKey as String] as? Bool {
                    isCharging = charging
                }
                if let charged = desc[kIOPSIsChargedKey as String] as? Bool {
                    isCharged = charged
                }
                if let pstate = desc[kIOPSPowerSourceStateKey as String] as? String {
                    isOnACPower = (pstate == (kIOPSACPowerValue as String))
                }
                if let time = desc[kIOPSTimeToEmptyKey as String] as? Int, time > 0 {
                    timeRemaining = time
                }
            }
        }

        return BatterySnapshot(
            percent: percent,
            isCharging: isCharging,
            isCharged: isCharged,
            isOnACPower: isOnACPower,
            hasBattery: hasBattery,
            timeRemainingMinutes: timeRemaining
        )
    }
}

