import SwiftUI
import AppKit

enum AppTheme {
    static let accent = Color(red: 0.055, green: 0.624, blue: 0.624)
    static let accentMint = Color(red: 0.086, green: 0.784, blue: 0.690)
    static let accentBlue = Color(red: 0.039, green: 0.518, blue: 1.0)
    static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)
    static let orange = Color(red: 0.976, green: 0.451, blue: 0.086)

    static let ok = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let warn = Color(red: 1.0, green: 0.624, blue: 0.039)
    static let danger = Color(red: 1.0, green: 0.271, blue: 0.227)

    static let panel = Color(nsColor: .windowBackgroundColor)
    static let panelSecondary = Color(nsColor: .controlBackgroundColor)
    static let line = Color.primary.opacity(0.08)
    static let textSecondary = Color.primary.opacity(0.56)
    static let textTertiary = Color.primary.opacity(0.38)
}

struct RoundedPanel: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.line)
            )
    }
}

extension View {
    func roundedPanel(padding: CGFloat = 16) -> some View {
        modifier(RoundedPanel(padding: padding))
    }
}
