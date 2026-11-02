import SwiftUI

public enum Theme {
    // Primary Nightowler Palette (Nocturnal Dark / Cyan / Indigo)
    public static let accentCyan = Color(red: 0.05, green: 0.82, blue: 0.95)       // #0DD1F2
    public static let accentIndigo = Color(red: 0.44, green: 0.38, blue: 1.00)     // #7061FF
    public static let accentViolet = Color(red: 0.62, green: 0.36, blue: 1.00)     // #9E5CFF
    public static let emeraldActive = Color(red: 0.16, green: 0.84, blue: 0.54)    // #29D68A
    public static let warningAmber = Color(red: 0.98, green: 0.66, blue: 0.15)     // #FAA826
    public static let crimsonAlert = Color(red: 0.96, green: 0.32, blue: 0.32)     // #F55252

    // Dark Obsidian Surfaces
    public static let backgroundDark = Color(red: 0.07, green: 0.08, blue: 0.10)
    public static let surfaceTile = Color(red: 0.12, green: 0.13, blue: 0.16)
    public static let hairlineBorder = Color.white.opacity(0.08)

    // Window Dimensions
    public static let panelWidth: CGFloat = 400
    public static let panelHeight: CGFloat = 590
}

extension View {
    public func cardBackground(cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.hairlineBorder, lineWidth: 1)
            )
    }

    public func glowCardBackground(glowColor: Color = Theme.accentCyan, cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(glowColor.opacity(0.06))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(glowColor.opacity(0.25), lineWidth: 1)
            )
    }

    public func sectionHeaderStyle() -> some View {
        self
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundColor(.secondary)
            .tracking(0.8)
    }
}
