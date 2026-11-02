import Foundation

public struct ActivityEvent: Codable, Identifiable, Sendable {
    public let id: String
    public let at: String
    public let kind: String
    public let text: String?
    public let value: Double?
    public let reason: String?

    public init(
        id: String = UUID().uuidString,
        at: String = ISO8601DateFormatter().string(from: Date()),
        kind: String,
        text: String? = nil,
        value: Double? = nil,
        reason: String? = nil
    ) {
        self.id = id
        self.at = at
        self.kind = kind
        self.text = text
        self.value = value
        self.reason = reason
    }
}

public final class ActivityLog: @unchecked Sendable {
    public static let shared = ActivityLog()

    private let lock = NSLock()
    private var _events: [ActivityEvent] = []
    private let fileURL: URL
    private let maxEvents = 500

    public var events: [ActivityEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Nightowler")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("activity.json")

        load()
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                _events = try JSONDecoder().decode([ActivityEvent].self, from: data)
            } catch {
                _events = []
            }
        }
    }

    public func logEvent(kind: String, text: String? = nil, value: Double? = nil, reason: String? = nil) {
        let ev = ActivityEvent(kind: kind, text: text, value: value, reason: reason)
        lock.lock()
        _events.insert(ev, at: 0)
        if _events.count > maxEvents {
            _events = Array(_events.prefix(maxEvents))
        }
        saveLocked()
        lock.unlock()
    }

    private func saveLocked() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(_events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save activity.json: \(error)")
        }
    }

    public func clear() {
        lock.lock()
        _events.removeAll()
        saveLocked()
        lock.unlock()
    }
}

