import Foundation

public enum ThermalLevel: String, Codable, Sendable {
    case nominal = "nominal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"

    public var displayName: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Elevated"
        case .critical: return "Critical"
        }
    }
}

public struct ThermalSnapshot: Codable, Sendable {
    public let level: ThermalLevel
    public let temperatureCelsius: Double?
    public let timestamp: Date

    public init(level: ThermalLevel = .nominal, temperatureCelsius: Double? = nil, timestamp: Date = Date()) {
        self.level = level
        self.temperatureCelsius = temperatureCelsius
        self.timestamp = timestamp
    }
}

public final class ThermalMonitor: @unchecked Sendable {
    public static let shared = ThermalMonitor()

    private let lock = NSLock()
    private var _snapshot = ThermalSnapshot()
    private var observer: NSObjectProtocol?
    private var pollTimer: DispatchSourceTimer?
    public var onThermalChanged: ((ThermalSnapshot) -> Void)?

    public var snapshot: ThermalSnapshot {
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

        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        }

        if pollTimer == nil {
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + 2.0, repeating: 5.0)
            timer.setEventHandler { [weak self] in
                self?.refresh()
            }
            timer.resume()
            pollTimer = timer
        }
    }

    public func stopMonitoring() {
        lock.lock()
        defer { lock.unlock() }

        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            observer = nil
        }
        pollTimer?.cancel()
        pollTimer = nil
    }

    public func refresh() {
        let state = ProcessInfo.processInfo.thermalState
        let level: ThermalLevel
        switch state {
        case .nominal:
            level = .nominal
        case .fair:
            level = .fair
        case .serious:
            level = .serious
        case .critical:
            level = .critical
        @unknown default:
            level = .nominal
        }

        let temp = SMCController.shared.getCPUTemperature()
        let newSnapshot = ThermalSnapshot(level: level, temperatureCelsius: temp, timestamp: Date())

        lock.lock()
        _snapshot = newSnapshot
        let handler = onThermalChanged
        lock.unlock()

        handler?(newSnapshot)
    }
}

