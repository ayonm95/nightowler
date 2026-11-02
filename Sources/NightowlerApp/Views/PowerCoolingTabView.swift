import SwiftUI
import NightowlerCore

struct PowerCoolingTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "fan.fill")
                            .foregroundColor(Theme.accentCyan)
                        Text("Hardware Cooling & SMC Telemetry")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text("SMC DIRECT")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.accentCyan.opacity(0.12))
                            .foregroundColor(Theme.accentCyan)
                            .cornerRadius(4)
                    }

                    Text("Direct Apple Silicon / Intel SMC hardware fan orchestration. Keeps thermal headroom stable during long unattended batch runs.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .cardBackground()

                // Fan Mode Preset Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("ACTIVE COOLING PROFILE")
                        .sectionHeaderStyle()

                    VStack(spacing: 6) {
                        fanModeOption(
                            title: "Automatic Dynamic Curve",
                            desc: "System responds dynamically to CPU workload and ambient temps",
                            mode: .auto
                        )
                        fanModeOption(
                            title: "Nocturnal Boost (~70%)",
                            desc: "Proactive acoustic cooling for background agent runs and builds",
                            mode: .boost
                        )
                        fanModeOption(
                            title: "High Performance (~85%)",
                            desc: "Intensive local LLM inference, Docker clusters, or 3D rendering",
                            mode: .high
                        )
                        fanModeOption(
                            title: "Maximum Dissipation (100%)",
                            desc: "Maximum heat exhaust for heavy workloads with the lid shut",
                            mode: .max
                        )
                        fanModeOption(
                            title: "Quiet Baseline (Min RPM)",
                            desc: "Silent acoustic operation, system hardware minimum",
                            mode: .off
                        )
                    }
                }
                .cardBackground()

                // Live Fan Tachometers
                VStack(alignment: .leading, spacing: 10) {
                    Text("LIVE HARDWARE TELEMETRY")
                        .sectionHeaderStyle()

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CPU DIE SENSOR")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            Text(state.thermalSnapshot.temperatureCelsius.map { "\(Int($0))°C" } ?? "Normal")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(tempColor)
                            Text(state.thermalSnapshot.level.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("TACHOMETER")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            Text(state.fanRPMs.first.map { "\($0) RPM" } ?? state.coolingMode.rawValue.capitalized)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.accentCyan)
                            Text(state.fanRPMs.count > 1 ? "\(state.fanRPMs.count) Fans Active" : "Hardware Linked")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
                .cardBackground()

                // Helper Status
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: state.isHelperInstalled ? "checkmark.shield.fill" : "bolt.shield")
                            .foregroundColor(state.isHelperInstalled ? Theme.emeraldActive : Theme.accentCyan)
                        Text(state.isHelperInstalled ? "Privileged Daemon: Engaged" : "Driver Mode: Direct Native")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Spacer()
                    }

                    Text(state.isHelperInstalled
                         ? "Privileged helper active. Clamshell guard and fan adjustments execute seamlessly without authorization prompts."
                         : "Nightowler is operating with direct user permissions. Clamshell management utilizes native power subsystems.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                .cardBackground()
            }
            .padding(12)
        }
    }

    private func fanModeOption(title: String, desc: String, mode: FanMode) -> some View {
        let isSelected = state.coolingMode == mode

        return Button(action: {
            state.setFanMode(mode)
        }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.accentCyan : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle()
                            .fill(Theme.accentCyan)
                            .frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(.primary)
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.accentCyan.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tempColor: Color {
        if state.thermalSnapshot.level == .critical { return Theme.crimsonAlert }
        if state.thermalSnapshot.level == .serious { return Theme.warningAmber }
        return Theme.emeraldActive
    }
}
