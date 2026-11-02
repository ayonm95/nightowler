import SwiftUI
import NightowlerCore

struct SafetyTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header Banner
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.accentCyan.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.accentCyan)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Autonomous Safety Guardrails")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Active multi-sensor monitoring to prevent battery exhaustion and thermal throttling.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .cardBackground()

                // Battery Guardrails
                VStack(alignment: .leading, spacing: 10) {
                    Text("BATTERY PRESERVATION")
                        .sectionHeaderStyle()

                    Toggle("Low-Battery Auto-Release", isOn: Binding(
                        get: { state.settings.batteryAutoStopEnabled },
                        set: { state.settings.batteryAutoStopEnabled = $0 }
                    ))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentCyan))

                    if state.settings.batteryAutoStopEnabled {
                        HStack {
                            Text("Release keep-awake if battery falls below:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(state.settings.batteryThreshold)%")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.warningAmber)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(state.settings.batteryThreshold) },
                                set: { state.settings.batteryThreshold = Int($0) }
                            ),
                            in: 10...50,
                            step: 5
                        )
                        .tint(Theme.warningAmber)
                    }

                    Divider()
                        .opacity(0.3)

                    Toggle("AC Charging-Only Mode", isOn: Binding(
                        get: { state.settings.chargingOnly },
                        set: {
                            state.settings.chargingOnly = $0
                            if $0 && !state.batterySnapshot.isOnACPower {
                                state.setMode(.off)
                            }
                        }
                    ))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentCyan))

                    Text("Automatically releases wake-lock if power cable is unplugged to prevent battery drain in backpacks or overnight.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .cardBackground()

                // Thermal Guardrails
                VStack(alignment: .leading, spacing: 10) {
                    Text("THERMAL SAFEGUARDS")
                        .sectionHeaderStyle()

                    Toggle("Thermal Critical Cutoff", isOn: Binding(
                        get: { state.settings.thermalAutoStop },
                        set: { state.settings.thermalAutoStop = $0 }
                    ))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.crimsonAlert))

                    Text("Disengages wake assertions if temperature reaches 95°C to protect silicon life and battery health.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Divider()
                        .opacity(0.3)

                    Toggle("Emergency Maximum Fans on Thermal Spike", isOn: Binding(
                        get: { state.settings.autoMaxFanOnCritical },
                        set: { state.settings.autoMaxFanOnCritical = $0 }
                    ))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentCyan))

                    Text("Instantly ramps SMC fans to 100% if thermal load spikes during closed-lid compiles.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .cardBackground()

                // Display Sleep
                VStack(alignment: .leading, spacing: 10) {
                    Text("DISPLAY & PANEL POWER")
                        .sectionHeaderStyle()

                    Toggle("Prevent Display Sleep (Keep Screen Active)", isOn: Binding(
                        get: { state.settings.preventDisplaySleep },
                        set: {
                            state.settings.preventDisplaySleep = $0
                            if $0 {
                                _ = state.power.createDisplayAssertion()
                            } else {
                                state.power.releaseDisplayAssertion()
                            }
                        }
                    ))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentIndigo))

                    Text("When off, the display dims and turns off normally while CPU tasks and closed-lid processes continue running headless.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .cardBackground()
            }
            .padding(12)
        }
    }
}
