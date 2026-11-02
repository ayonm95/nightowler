import SwiftUI
import NightowlerCore

struct OverviewTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // MARK: - Hero Status Card
                heroStatusCard

                // MARK: - Primary Mode Toggles
                VStack(spacing: 8) {
                    modeToggleCard(
                        title: "Keep Awake",
                        subtitle: state.mode == .on ? "Active · System sleep disabled" : "Normal sleep permitted when idle",
                        icon: "eye.fill",
                        isActive: state.mode == .on,
                        activeColor: Theme.accentCyan
                    ) {
                        state.setMode(state.mode == .on ? .off : .on)
                    }

                    modeToggleCard(
                        title: "Clamshell Guard",
                        subtitle: state.isClamshellActive ? "Active · Keeps running with lid closed" : "Closing laptop lid will sleep Mac",
                        icon: "laptopcomputer",
                        isActive: state.isClamshellActive,
                        activeColor: Theme.emeraldActive
                    ) {
                        state.setClamshell(enabled: !state.isClamshellActive)
                    }

                    modeToggleCard(
                        title: "Auto Workload Watch",
                        subtitle: state.mode == .autoWatch
                            ? (state.activeTasks.isEmpty ? "Watching for background tools" : "\(state.activeTasks.count) active workloads running")
                            : "Auto-detect Claude, Cursor, Docker & LLMs",
                        icon: "sparkles",
                        isActive: state.mode == .autoWatch,
                        activeColor: Theme.accentIndigo
                    ) {
                        state.setMode(state.mode == .autoWatch ? .off : .autoWatch)
                    }
                }

                // MARK: - Quick Session Timer
                timerSection

                // MARK: - Live System Telemetry
                telemetryGrid
            }
            .padding(12)
        }
    }

    // MARK: - Subviews

    private var heroStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Circle()
                        .stroke(statusColor.opacity(0.35), lineWidth: 1)
                        .frame(width: 40, height: 40)
                    Image(systemName: statusIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(state.whyAwakeReason)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            if let exp = state.sessionTimerExpiresAt {
                Divider()
                    .opacity(0.3)
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(Theme.accentCyan)
                        .font(.system(size: 11))
                    Text("Auto-releases in \(timeRemaining(to: exp))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.85))
                    Spacer()
                    Button("Cancel") {
                        state.cancelSessionTimer()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.crimsonAlert)
                }
            } else if !state.whyStoppedReason.isEmpty && state.mode == .off {
                Divider()
                    .opacity(0.3)
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.warningAmber)
                        .font(.system(size: 11))
                    Text(state.whyStoppedReason)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .glowCardBackground(glowColor: statusColor, cornerRadius: 12)
    }

    private func modeToggleCard(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? activeColor.opacity(0.18) : Color.primary.opacity(0.04))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(isActive ? activeColor : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { _ in action() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: activeColor))
                .labelsHidden()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardBackground()
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION TIMER")
                .sectionHeaderStyle()

            HStack(spacing: 5) {
                timerChip(title: "Off", duration: nil)
                timerChip(title: "30m", duration: 1800)
                timerChip(title: "1h", duration: 3600)
                timerChip(title: "2h", duration: 7200)
                timerChip(title: "4h", duration: 14400)
                timerChip(title: "8h", duration: 28800)
            }
        }
        .cardBackground()
    }

    private func timerChip(title: String, duration: TimeInterval?) -> some View {
        let isSelected: Bool
        if let d = duration {
            isSelected = state.sessionTimerDuration == d
        } else {
            isSelected = state.sessionTimerExpiresAt == nil
        }

        return Button(action: {
            if let d = duration {
                state.setSessionTimer(duration: d)
            } else {
                state.cancelSessionTimer()
            }
        }) {
            Text(title)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Theme.accentCyan : Color.primary.opacity(0.04))
                )
                .foregroundColor(isSelected ? .black : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Theme.accentCyan.opacity(0.8) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var telemetryGrid: some View {
        HStack(spacing: 8) {
            telemetryTile(
                title: "BATTERY",
                value: "\(state.batterySnapshot.percent)%",
                subtext: state.batterySnapshot.isOnACPower ? "AC Connected" : "Battery",
                icon: state.batterySnapshot.isCharging ? "bolt.batteryblock.fill" : "battery.100",
                color: state.batterySnapshot.percent <= 20 ? Theme.warningAmber : Theme.emeraldActive
            )

            telemetryTile(
                title: "CPU DIE",
                value: state.thermalSnapshot.temperatureCelsius.map { "\(Int($0))°C" } ?? state.thermalSnapshot.level.displayName,
                subtext: state.thermalSnapshot.level.displayName,
                icon: "thermometer.medium",
                color: state.thermalSnapshot.level == .critical ? Theme.crimsonAlert : (state.thermalSnapshot.level == .serious ? Theme.warningAmber : Theme.accentCyan)
            )

            telemetryTile(
                title: "COOLING",
                value: state.fanRPMs.first.map { "\($0) RPM" } ?? state.coolingMode.rawValue.capitalized,
                subtext: state.coolingMode.rawValue.capitalized,
                icon: "fan.fill",
                color: Theme.accentIndigo
            )
        }
    }

    private func telemetryTile(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
            Text(subtext)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    // MARK: - Helpers

    private var statusTitle: String {
        if state.isClamshellActive { return "Clamshell Lock Active" }
        switch state.mode {
        case .off: return "System Sleep Permitted"
        case .on: return "Nocturnal Wake Active"
        case .chargingOnly: return "AC Power Guard Active"
        case .autoWatch: return "Autonomous Watch Active"
        }
    }

    private var statusIcon: String {
        if state.isClamshellActive { return "lock.laptopcomputer" }
        switch state.mode {
        case .off: return "moon.zzz"
        case .on: return "eye.fill"
        case .chargingOnly: return "bolt.fill"
        case .autoWatch: return "sparkles"
        }
    }

    private var statusColor: Color {
        if state.isClamshellActive { return Theme.emeraldActive }
        switch state.mode {
        case .off: return .secondary
        case .on: return Theme.accentCyan
        case .chargingOnly: return Theme.accentCyan
        case .autoWatch: return Theme.accentIndigo
        }
    }

    private func timeRemaining(to date: Date) -> String {
        let diff = max(0, Int(date.timeIntervalSinceNow))
        let m = diff / 60
        let s = diff % 60
        if m >= 60 {
            let h = m / 60
            let remM = m % 60
            return "\(h)h \(remM)m"
        }
        return "\(m)m \(s)s"
    }
}
