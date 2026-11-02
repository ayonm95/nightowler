import SwiftUI
import NightowlerCore

enum PanelTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case automation = "Auto"
    case safety = "Safety"
    case cooling = "Cooling"
    case rules = "Rules"
    case alerts = "Alerts"
    case activity = "Log"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "moon.stars.fill"
        case .automation: return "sparkles"
        case .safety: return "shield.fill"
        case .cooling: return "fan.fill"
        case .rules: return "slider.horizontal.3"
        case .alerts: return "bell.fill"
        case .activity: return "terminal.fill"
        }
    }
}

struct MenuPanelView: View {
    @ObservedObject var state: AppState

    var currentTab: PanelTab {
        PanelTab(rawValue: state.selectedTabName) ?? .overview
    }

    var isGuardianEngaged: Bool {
        state.isAssertionActive || state.isClamshellActive
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()
                .opacity(0.3)

            // Main Tab Content
            Group {
                switch currentTab {
                case .overview:
                    OverviewTabView(state: state)
                case .automation:
                    AutomationTabView(state: state)
                case .safety:
                    SafetyTabView(state: state)
                case .cooling:
                    PowerCoolingTabView(state: state)
                case .rules:
                    RulesTabView(state: state)
                case .alerts:
                    AlertsTabView(state: state)
                case .activity:
                    ActivityLogTabView(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .opacity(0.3)

            // Footer Bar
            footerBar
        }
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
    }

    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                // Brand Logo & Title
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accentIndigo, Theme.accentCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                        Image(systemName: "eye.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nightowler")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("NOCTURNAL GUARDIAN")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.7)
                    }
                }

                Spacer()

                // Live Status Pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(isGuardianEngaged ? Theme.emeraldActive : Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text(isGuardianEngaged ? "ACTIVE" : "STANDBY")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(isGuardianEngaged ? Theme.emeraldActive : .secondary)
                        .tracking(0.6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isGuardianEngaged ? Theme.emeraldActive.opacity(0.12) : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isGuardianEngaged ? Theme.emeraldActive.opacity(0.25) : Color.clear, lineWidth: 1)
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Segmented Tab Selector (Pill Bar)
            HStack(spacing: 3) {
                ForEach(PanelTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.selectedTabName = tab.rawValue
                        }
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11.5))
                            Text(tab.rawValue)
                                .font(.system(size: 9, weight: currentTab == tab ? .bold : .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundColor(currentTab == tab ? Theme.accentCyan : .secondary)
                        .background(
                            currentTab == tab
                                ? RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.accentCyan.opacity(0.12))
                                : RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private var footerBar: some View {
        HStack {
            Text("Nightowler v1.0.0 · Native Swift Engine")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()

            Button("Quit Nightowler") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10, weight: .medium))
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
}
