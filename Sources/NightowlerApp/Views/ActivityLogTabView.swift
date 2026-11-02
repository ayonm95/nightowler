import SwiftUI
import NightowlerCore

struct ActivityLogTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("EVENT TIMELINE (\(state.activity.events.count))")
                    .sectionHeaderStyle()
                Spacer()
                Button("Clear Timeline") {
                    state.activity.clear()
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.borderless)
                .foregroundColor(Theme.accentCyan)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.3)

            if state.activity.events.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No events recorded in current timeline.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(state.activity.events) { ev in
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(colorForKind(ev.kind).opacity(0.15))
                                .frame(width: 22, height: 22)
                            Image(systemName: iconForKind(ev.kind))
                                .font(.system(size: 10))
                                .foregroundColor(colorForKind(ev.kind))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(titleForKind(ev.kind))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(formatTime(ev.at))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            if let r = ev.reason ?? ev.text {
                                Text(r)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }

    private func iconForKind(_ kind: String) -> String {
        switch kind {
        case "keepAwakeStarted": return "eye.fill"
        case "keepAwakeStopped": return "moon.fill"
        case "clamshellOn", "clamshellOff": return "laptopcomputer"
        case "timerStarted", "timerFinished": return "timer"
        case "thermalCritical": return "flame.fill"
        case "safetyGovernorTriggered": return "shield.fill"
        case "coolingModeChanged": return "fan.fill"
        default: return "circle.fill"
        }
    }

    private func colorForKind(_ kind: String) -> Color {
        switch kind {
        case "keepAwakeStarted": return Theme.accentCyan
        case "keepAwakeStopped": return .secondary
        case "clamshellOn": return Theme.emeraldActive
        case "clamshellOff": return .secondary
        case "thermalCritical": return Theme.crimsonAlert
        case "safetyGovernorTriggered": return Theme.warningAmber
        case "coolingModeChanged": return Theme.accentIndigo
        default: return .secondary
        }
    }

    private func titleForKind(_ kind: String) -> String {
        switch kind {
        case "keepAwakeStarted": return "Keep Awake Initiated"
        case "keepAwakeStopped": return "Keep Awake Released"
        case "clamshellOn": return "Clamshell Guard Active"
        case "clamshellOff": return "Clamshell Guard Released"
        case "timerStarted": return "Session Timer Started"
        case "timerFinished": return "Session Timer Expired"
        case "thermalCritical": return "Thermal Safety Event"
        case "safetyGovernorTriggered": return "Safety Governor Trigger"
        case "coolingModeChanged": return "Cooling Profile Changed"
        default: return kind.capitalized
        }
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        let out = DateFormatter()
        out.timeStyle = .medium
        return out.string(from: date)
    }
}
