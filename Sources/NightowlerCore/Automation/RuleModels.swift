import Foundation

// MARK: - Rule Models

public enum RuleCondition: Codable, Sendable, Equatable {
    case processRunning(pattern: String)
    case processNotRunning(pattern: String)
    case batteryBelow(percent: Int)
    case batteryAbove(percent: Int)
    case onBatteryPower
    case onACPower
    case temperatureAbove(celsius: Double, durationSeconds: Int)
    case noMatchingWorkloadFor(seconds: Int)

    enum CodingKeys: String, CodingKey {
        case processRunning
        case processNotRunning
        case batteryBelow
        case batteryAbove
        case onBatteryPower
        case onACPower
        case temperatureAbove
        case noMatchingWorkloadFor
    }

    struct ProcessPatternWrapper: Codable, Equatable {
        let pattern: String
    }

    struct BatteryPercentWrapper: Codable, Equatable {
        let percent: Int
    }

    struct TempAboveWrapper: Codable, Equatable {
        let celsius: Double
        let durationSeconds: Int
    }

    struct NoWorkloadWrapper: Codable, Equatable {
        let seconds: Int
    }

    struct EmptyWrapper: Codable, Equatable {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let w = try? container.decode(ProcessPatternWrapper.self, forKey: .processRunning) {
            self = .processRunning(pattern: w.pattern)
        } else if let w = try? container.decode(ProcessPatternWrapper.self, forKey: .processNotRunning) {
            self = .processNotRunning(pattern: w.pattern)
        } else if let w = try? container.decode(BatteryPercentWrapper.self, forKey: .batteryBelow) {
            self = .batteryBelow(percent: w.percent)
        } else if let w = try? container.decode(BatteryPercentWrapper.self, forKey: .batteryAbove) {
            self = .batteryAbove(percent: w.percent)
        } else if (try? container.decode(EmptyWrapper.self, forKey: .onBatteryPower)) != nil {
            self = .onBatteryPower
        } else if (try? container.decode(EmptyWrapper.self, forKey: .onACPower)) != nil {
            self = .onACPower
        } else if let w = try? container.decode(TempAboveWrapper.self, forKey: .temperatureAbove) {
            self = .temperatureAbove(celsius: w.celsius, durationSeconds: w.durationSeconds)
        } else if let w = try? container.decode(NoWorkloadWrapper.self, forKey: .noMatchingWorkloadFor) {
            self = .noMatchingWorkloadFor(seconds: w.seconds)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown RuleCondition")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .processRunning(let pattern):
            try container.encode(ProcessPatternWrapper(pattern: pattern), forKey: .processRunning)
        case .processNotRunning(let pattern):
            try container.encode(ProcessPatternWrapper(pattern: pattern), forKey: .processNotRunning)
        case .batteryBelow(let percent):
            try container.encode(BatteryPercentWrapper(percent: percent), forKey: .batteryBelow)
        case .batteryAbove(let percent):
            try container.encode(BatteryPercentWrapper(percent: percent), forKey: .batteryAbove)
        case .onBatteryPower:
            try container.encode(EmptyWrapper(), forKey: .onBatteryPower)
        case .onACPower:
            try container.encode(EmptyWrapper(), forKey: .onACPower)
        case .temperatureAbove(let celsius, let duration):
            try container.encode(TempAboveWrapper(celsius: celsius, durationSeconds: duration), forKey: .temperatureAbove)
        case .noMatchingWorkloadFor(let seconds):
            try container.encode(NoWorkloadWrapper(seconds: seconds), forKey: .noMatchingWorkloadFor)
        }
    }
}

public enum RuleAction: Codable, Sendable, Equatable {
    case startKeepAwake
    case stopKeepAwake
    case startClosedLid
    case stopClosedLid
    case setCoolingPreset(String)
    case setFanPercent(Int)
    case sleepMac
    case notify(title: String, body: String)
    case sendWebhook(message: String)

    enum CodingKeys: String, CodingKey {
        case startKeepAwake
        case stopKeepAwake
        case startClosedLid
        case stopClosedLid
        case setCoolingPreset
        case setFanPercent
        case sleepMac
        case notify
        case sendWebhook
    }

    struct PresetWrapper: Codable, Equatable {
        let _0: String
    }

    struct FanPercentWrapper: Codable, Equatable {
        let percent: Int
    }

    struct NotifyWrapper: Codable, Equatable {
        let title: String
        let body: String
    }

    struct WebhookWrapper: Codable, Equatable {
        let message: String
    }

    struct EmptyWrapper: Codable, Equatable {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decode(EmptyWrapper.self, forKey: .startKeepAwake)) != nil {
            self = .startKeepAwake
        } else if (try? container.decode(EmptyWrapper.self, forKey: .stopKeepAwake)) != nil {
            self = .stopKeepAwake
        } else if (try? container.decode(EmptyWrapper.self, forKey: .startClosedLid)) != nil {
            self = .startClosedLid
        } else if (try? container.decode(EmptyWrapper.self, forKey: .stopClosedLid)) != nil {
            self = .stopClosedLid
        } else if let w = try? container.decode(PresetWrapper.self, forKey: .setCoolingPreset) {
            self = .setCoolingPreset(w._0)
        } else if let w = try? container.decode(FanPercentWrapper.self, forKey: .setFanPercent) {
            self = .setFanPercent(w.percent)
        } else if (try? container.decode(EmptyWrapper.self, forKey: .sleepMac)) != nil {
            self = .sleepMac
        } else if let w = try? container.decode(NotifyWrapper.self, forKey: .notify) {
            self = .notify(title: w.title, body: w.body)
        } else if let w = try? container.decode(WebhookWrapper.self, forKey: .sendWebhook) {
            self = .sendWebhook(message: w.message)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown RuleAction")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .startKeepAwake:
            try container.encode(EmptyWrapper(), forKey: .startKeepAwake)
        case .stopKeepAwake:
            try container.encode(EmptyWrapper(), forKey: .stopKeepAwake)
        case .startClosedLid:
            try container.encode(EmptyWrapper(), forKey: .startClosedLid)
        case .stopClosedLid:
            try container.encode(EmptyWrapper(), forKey: .stopClosedLid)
        case .setCoolingPreset(let preset):
            try container.encode(PresetWrapper(_0: preset), forKey: .setCoolingPreset)
        case .setFanPercent(let p):
            try container.encode(FanPercentWrapper(percent: p), forKey: .setFanPercent)
        case .sleepMac:
            try container.encode(EmptyWrapper(), forKey: .sleepMac)
        case .notify(let title, let body):
            try container.encode(NotifyWrapper(title: title, body: body), forKey: .notify)
        case .sendWebhook(let msg):
            try container.encode(WebhookWrapper(message: msg), forKey: .sendWebhook)
        }
    }
}

public struct Rule: Codable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var isEnabled: Bool
    public var isBuiltIn: Bool
    public var builtinKey: String?
    public var cooldownSeconds: Int
    public var conditions: [RuleCondition]
    public var actions: [RuleAction]
    public var createdAt: Double
    public var updatedAt: Double
    public var lastTriggeredAt: Double?

    public init(
        id: String = UUID().uuidString,
        name: String,
        isEnabled: Bool = true,
        isBuiltIn: Bool = false,
        builtinKey: String? = nil,
        cooldownSeconds: Int = 300,
        conditions: [RuleCondition] = [],
        actions: [RuleAction] = [],
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970,
        lastTriggeredAt: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
        self.builtinKey = builtinKey
        self.cooldownSeconds = cooldownSeconds
        self.conditions = conditions
        self.actions = actions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastTriggeredAt = lastTriggeredAt
    }
}

