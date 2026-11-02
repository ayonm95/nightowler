import SwiftUI
import NightowlerCore

struct AutomationTabView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Theme.accentIndigo)
                        Text("Autonomous Workload Watcher")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text("ACTIVE SCAN")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.emeraldActive.opacity(0.12))
                            .foregroundColor(Theme.emeraldActive)
                            .cornerRadius(4)
                    }

                    Text("Automatically keeps your Mac awake whenever AI coding agents (Claude, Cursor, Codex), local LLMs (Ollama, LM Studio), Docker, or developer build tasks are executing.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Toggle("Enable Autonomous Watch", isOn: Binding(
                        get: { state.mode == .autoWatch },
                        set: { val in state.setMode(val ? .autoWatch : .off) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accentIndigo))
                    .padding(.top, 4)
                }
                .cardBackground()

                // Active detected workloads
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ACTIVE WORKLOADS")
                            .sectionHeaderStyle()
                        Spacer()
                        Text("\(state.activeTasks.count) running")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    if state.activeTasks.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.secondary)
                            Text("No watched workloads currently running.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(state.activeTasks) { task in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Theme.emeraldActive)
                                    .frame(width: 7, height: 7)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(task.name)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("PID \(task.pid) · matched '\(task.pattern)'")
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                            )
                        }
                    }
                }
                .cardBackground()

                // Watch list patterns
                VStack(alignment: .leading, spacing: 8) {
                    Text("WATCH LIST PATTERNS")
                        .sectionHeaderStyle()

                    HStack(spacing: 6) {
                        TextField("e.g. jupyter, train.py, whisper", text: $state.newWatchPattern)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 11))

                        Button("Add") {
                            state.watcher.addPattern(state.newWatchPattern)
                            state.newWatchPattern = ""
                        }
                        .disabled(state.newWatchPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accentCyan)
                        .foregroundColor(.black)
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(state.watcher.patterns, id: \.self) { pat in
                            HStack(spacing: 5) {
                                Text(pat)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                                Button(action: {
                                    state.watcher.removePattern(pat)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Theme.hairlineBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .cardBackground()

                // Auto Sleep Idle Timeout
                VStack(alignment: .leading, spacing: 8) {
                    Text("IDLE GRACE TIMEOUT")
                        .sectionHeaderStyle()

                    HStack {
                        Text("Grace duration before release:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(state.settings.autoSleepNoWorkMinutes) min")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(state.settings.autoSleepNoWorkMinutes) },
                            set: { state.settings.autoSleepNoWorkMinutes = Int($0) }
                        ),
                        in: 2...60,
                        step: 1
                    )
                    .tint(Theme.accentIndigo)

                    Toggle("Sleep Mac upon expiration instead of idle wake release", isOn: Binding(
                        get: { state.settings.autoSleepNoWorkActionSleep },
                        set: { state.settings.autoSleepNoWorkActionSleep = $0 }
                    ))
                    .font(.system(size: 11))
                }
                .cardBackground()
            }
            .padding(12)
        }
    }
}

// Flowing chip layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
