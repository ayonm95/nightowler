import Foundation

/// Defines active hardware and system capabilities for the Nightowler engine.
public final class EngineCapabilities: @unchecked Sendable {
    public static let shared = EngineCapabilities()

    /// Direct Apple Silicon / Intel SMC hardware fan speed manipulation
    public let fanControlSupported: Bool = true

    /// Autonomous process scanning for active AI coding agents, compilers, and Docker
    public let autoModeEnabled: Bool = true

    /// Guarded clamshell power management allowing headless closed-lid execution
    public let closedLidGuarded: Bool = true

    /// Multi-condition reactive trigger rules engine
    public let smartRulesEnabled: Bool = true

    /// Outbound push dispatch via Telegram, Discord, Slack, and generic webhooks
    public let webhooksEnabled: Bool = true

    /// In-memory event audit log
    public let activityLoggingEnabled: Bool = true

    /// Continuous keep-awake sessions with zero artificial runtime caps
    public let unlimitedSessions: Bool = true

    public var statusDescription: String {
        return "Nightowler Native Engine — All Guardrails Active"
    }

    public init() {}
}
