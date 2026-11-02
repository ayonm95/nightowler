import SwiftUI
import NightowlerCore

struct RulesTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(Theme.accentIndigo)
                        Text("Autonomous Rules Engine")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text("RULES ACTIVE")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.accentIndigo.opacity(0.12))
                            .foregroundColor(Theme.accentIndigo)
                            .cornerRadius(4)
                    }

                    Text("Custom reactive triggers that orchestrate keep-awake state, fan speeds, notifications, and emergency sleep based on battery, process status, and temperatures.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Toggle("Enable Reactive Rules Engine", isOn: Binding(
                        get: { state.settings.smartRulesEnabled },
                        set: { state.settings.smartRulesEnabled = $0 }
                    ))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentIndigo))
                    .padding(.top, 4)
                }
                .cardBackground()

                // Rules List
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CONFIGURED TRIGGERS (\(state.rules.rules.count))")
                            .sectionHeaderStyle()
                        Spacer()
                        Button("Reset Defaults") {
                            state.rules.resetToDefaults()
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.borderless)
                        .foregroundColor(Theme.accentCyan)
                    }

                    ForEach(state.rules.rules) { rule in
                        ruleCard(rule)
                    }
                }
                .cardBackground()
            }
            .padding(12)
        }
    }

    private func ruleCard(_ rule: Rule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rule.name)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in state.rules.toggleRule(id: rule.id) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Theme.accentIndigo))
                .labelsHidden()
            }

            HStack(spacing: 8) {
                // Conditions summary
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                    Text(conditionSummary(rule.conditions))
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Action summary badge
                Text(actionSummary(rule.actions))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Theme.accentCyan.opacity(0.12))
                    .foregroundColor(Theme.accentCyan)
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.hairlineBorder, lineWidth: 1)
        )
    }

    private func conditionSummary(_ conds: [RuleCondition]) -> String {
        guard let first = conds.first else { return "Always" }
        switch first {
        case .processRunning(let pat): return "When '\(pat)' is running"
        case .processNotRunning(let pat): return "When '\(pat)' stops"
        case .batteryBelow(let p): return "When battery < \(p)%"
        case .batteryAbove(let p): return "When battery > \(p)%"
        case .onBatteryPower: return "When on battery power"
        case .onACPower: return "When connected to AC"
        case .temperatureAbove(let c, _): return "When temp > \(Int(c))°C"
        case .noMatchingWorkloadFor(let s): return "No workload for \(s/60)m"
        }
    }

    private func actionSummary(_ actions: [RuleAction]) -> String {
        guard let first = actions.first else { return "Do nothing" }
        switch first {
        case .startKeepAwake: return "Keep Awake"
        case .stopKeepAwake: return "Stop Awake"
        case .startClosedLid: return "Clamshell On"
        case .stopClosedLid: return "Clamshell Off"
        case .setCoolingPreset(let p): return "Cooling: \(p)"
        case .setFanPercent(let p): return "Fan \(p)%"
        case .sleepMac: return "Sleep Mac"
        case .notify: return "Send Alert"
        case .sendWebhook: return "Webhook"
        }
    }
}
