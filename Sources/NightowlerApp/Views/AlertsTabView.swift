import SwiftUI
import NightowlerCore

struct AlertsTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        let configBinding = Binding<WebhookConfig>(
            get: { WebhookManager.shared.getConfig() },
            set: { WebhookManager.shared.updateConfig($0) }
        )

        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(Theme.accentCyan)
                        Text("Remote Alerts & Webhooks")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text("REMOTE DISPATCH")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.accentCyan.opacity(0.12))
                            .foregroundColor(Theme.accentCyan)
                            .cornerRadius(4)
                    }

                    Text("Instant push notifications via Telegram, Discord, Slack, or generic HTTP endpoints when long-running jobs complete or safety cutoffs fire.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .cardBackground()

                // Telegram
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Telegram Bot Alerts", isOn: Binding(
                        get: { configBinding.wrappedValue.telegramEnabled },
                        set: {
                            var cfg = configBinding.wrappedValue
                            cfg.telegramEnabled = $0
                            configBinding.wrappedValue = cfg
                        }
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentCyan))

                    if configBinding.wrappedValue.telegramEnabled {
                        VStack(spacing: 6) {
                            TextField("Telegram Bot Token", text: Binding(
                                get: { configBinding.wrappedValue.telegramBotToken },
                                set: {
                                    var cfg = configBinding.wrappedValue
                                    cfg.telegramBotToken = $0
                                    configBinding.wrappedValue = cfg
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11))

                            TextField("Telegram Chat ID", text: Binding(
                                get: { configBinding.wrappedValue.telegramChatID },
                                set: {
                                    var cfg = configBinding.wrappedValue
                                    cfg.telegramChatID = $0
                                    configBinding.wrappedValue = cfg
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11))
                        }
                    }
                }
                .cardBackground()

                // Discord
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Discord Webhook", isOn: Binding(
                        get: { configBinding.wrappedValue.discordEnabled },
                        set: {
                            var cfg = configBinding.wrappedValue
                            cfg.discordEnabled = $0
                            configBinding.wrappedValue = cfg
                        }
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentIndigo))

                    if configBinding.wrappedValue.discordEnabled {
                        TextField("Discord Webhook URL", text: Binding(
                            get: { configBinding.wrappedValue.discordWebhookURL },
                            set: {
                                var cfg = configBinding.wrappedValue
                                cfg.discordWebhookURL = $0
                                configBinding.wrappedValue = cfg
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                    }
                }
                .cardBackground()

                // Slack
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Slack Incoming Webhook", isOn: Binding(
                        get: { configBinding.wrappedValue.slackEnabled },
                        set: {
                            var cfg = configBinding.wrappedValue
                            cfg.slackEnabled = $0
                            configBinding.wrappedValue = cfg
                        }
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentIndigo))

                    if configBinding.wrappedValue.slackEnabled {
                        TextField("Slack Webhook URL", text: Binding(
                            get: { configBinding.wrappedValue.slackWebhookURL },
                            set: {
                                var cfg = configBinding.wrappedValue
                                cfg.slackWebhookURL = $0
                                configBinding.wrappedValue = cfg
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                    }
                }
                .cardBackground()

                // Generic Webhook
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Generic JSON Endpoint", isOn: Binding(
                        get: { configBinding.wrappedValue.genericEnabled },
                        set: {
                            var cfg = configBinding.wrappedValue
                            cfg.genericEnabled = $0
                            configBinding.wrappedValue = cfg
                        }
                    ))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentCyan))

                    if configBinding.wrappedValue.genericEnabled {
                        TextField("https://api.yourdomain.com/v1/webhook", text: Binding(
                            get: { configBinding.wrappedValue.genericWebhookURL },
                            set: {
                                var cfg = configBinding.wrappedValue
                                cfg.genericWebhookURL = $0
                                configBinding.wrappedValue = cfg
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                    }
                }
                .cardBackground()

                // Test Trigger Button
                VStack(spacing: 8) {
                    Button(action: {
                        state.webhooks.sendNotification(
                            title: "Nightowler Telemetry Test",
                            body: "All systems nominal! Battery: \(state.batterySnapshot.percent)%, CPU: \(state.thermalSnapshot.temperatureCelsius.map { "\(Int($0))°C" } ?? "Normal")"
                        )
                        state.testSentNote = "Test alert dispatched to configured destinations."
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            state.testSentNote = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                            Text("Send Test Notification")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentCyan)
                    .foregroundColor(.black)

                    if let note = state.testSentNote {
                        Text(note)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Theme.emeraldActive)
                    }
                }
                .cardBackground()
            }
            .padding(12)
        }
    }
}
