import Foundation
import UserNotifications

public struct WebhookConfig: Codable, Sendable {
    public var telegramEnabled: Bool = false
    public var telegramBotToken: String = ""
    public var telegramChatID: String = ""

    public var discordEnabled: Bool = false
    public var discordWebhookURL: String = ""

    public var slackEnabled: Bool = false
    public var slackWebhookURL: String = ""

    public var genericEnabled: Bool = false
    public var genericWebhookURL: String = ""

    public init(
        telegramEnabled: Bool = false,
        telegramBotToken: String = "",
        telegramChatID: String = "",
        discordEnabled: Bool = false,
        discordWebhookURL: String = "",
        slackEnabled: Bool = false,
        slackWebhookURL: String = "",
        genericEnabled: Bool = false,
        genericWebhookURL: String = ""
    ) {
        self.telegramEnabled = telegramEnabled
        self.telegramBotToken = telegramBotToken
        self.telegramChatID = telegramChatID
        self.discordEnabled = discordEnabled
        self.discordWebhookURL = discordWebhookURL
        self.slackEnabled = slackEnabled
        self.slackWebhookURL = slackWebhookURL
        self.genericEnabled = genericEnabled
        self.genericWebhookURL = genericWebhookURL
    }
}

public final class WebhookManager: @unchecked Sendable {
    public static let shared = WebhookManager()

    private let lock = NSLock()
    private var config: WebhookConfig = WebhookConfig()
    private var lastSentTimes: [Date] = []

    public init() {
        loadConfig()
        requestNotificationPermission()
    }

    public func updateConfig(_ newConfig: WebhookConfig) {
        lock.lock()
        config = newConfig
        saveConfigLocked()
        lock.unlock()
    }

    public func getConfig() -> WebhookConfig {
        lock.lock()
        defer { lock.unlock() }
        return config
    }

    private func saveConfigLocked() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "nightowler.webhookConfig")
        }
    }

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "nightowler.webhookConfig"),
           let decoded = try? JSONDecoder().decode(WebhookConfig.self, from: data) {
            config = decoded
        }
    }

    public func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    public func sendNotification(title: String, body: String) {
        // Send local notification if running within an application bundle
        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }

        // Send to external webhooks
        sendAlerts(title: title, body: body)
    }

    public func sendAlerts(title: String, body: String) {
        lock.lock()
        let cfg = config
        let now = Date()
        // Rate limit: max 10 alerts in 10 minutes
        lastSentTimes = lastSentTimes.filter { now.timeIntervalSince($0) < 600 }
        if lastSentTimes.count >= 10 {
            lock.unlock()
            return
        }
        lastSentTimes.append(now)
        lock.unlock()

        let message = "🔔 *\(title)*\n\(body)"

        // Telegram
        if cfg.telegramEnabled, !cfg.telegramBotToken.isEmpty, !cfg.telegramChatID.isEmpty {
            sendTelegram(token: cfg.telegramBotToken, chatID: cfg.telegramChatID, message: message)
        }

        // Discord
        if cfg.discordEnabled, let url = URL(string: cfg.discordWebhookURL) {
            sendDiscord(url: url, title: title, body: body)
        }

        // Slack
        if cfg.slackEnabled, let url = URL(string: cfg.slackWebhookURL) {
            sendSlack(url: url, text: "*\(title)*\n\(body)")
        }

        // Generic Webhook
        if cfg.genericEnabled, let url = URL(string: cfg.genericWebhookURL) {
            sendGenericWebhook(url: url, title: title, body: body)
        }
    }

    private func sendTelegram(token: String, chatID: String, message: String) {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "chat_id": chatID,
            "text": message,
            "parse_mode": "Markdown"
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: req).resume()
    }

    private func sendDiscord(url: URL, title: String, body: String) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "content": "**\(title)**\n\(body)"
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: req).resume()
    }

    private func sendSlack(url: URL, text: String) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "text": text
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: req).resume()
    }

    private func sendGenericWebhook(url: URL, title: String, body: String) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "title": title,
            "body": body,
            "source": "Nightowler",
            "timestamp": Date().timeIntervalSince1970
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: req).resume()
    }
}

