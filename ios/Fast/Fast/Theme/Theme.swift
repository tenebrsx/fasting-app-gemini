import SwiftUI
import UIKit

enum Theme {
    // Adaptive colors matching public/styles.css dark & light tokens
    static let bg = Color.adaptive(light: 0xF2F4F9, dark: 0x0D1424)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x161F35)
    static let surface2 = Color.adaptive(light: 0xEBEEF5, dark: 0x1D2843)
    static let line = Color.adaptive(light: 0xDCE1EC, dark: 0x27324F)
    static let ink = Color.adaptive(light: 0x121A2E, dark: 0xECEFF6)
    static let mist = Color.adaptive(light: 0x5D6884, dark: 0x8E99B3)

    static let ember = Color.adaptive(light: 0xF29A12, dark: 0xFFB547)
    static let coral = Color.adaptive(light: 0xF0603D, dark: 0xFF7A59)
    static let orchid = Color.adaptive(light: 0xA74FD6, dark: 0xC770F0)
    static let sky = Color.adaptive(light: 0x3B7FEA, dark: 0x6FA8FF)
    static let teal = Color.adaptive(light: 0x16A796, dark: 0x46D6C4)

    static let danger = Color(hex: 0xFF6B7A)
    static let ok = Color(hex: 0x5FD39A)
    static let onPrimary = Color(hex: 0x1A1205)

    static let radiusLG: CGFloat = 22
    static let radiusMD: CGFloat = 14
    static let radiusSM: CGFloat = 10
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        })
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    var background: Color = Theme.ember
    var foreground: Color = Theme.onPrimary
    var isLarge: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isLarge ? 17 : 15, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: isLarge ? .infinity : nil)
            .padding(.horizontal, isLarge ? 24 : 18)
            .padding(.vertical, isLarge ? 15 : 11)
            .background(background, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoftPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surface2, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = Theme.radiusMD

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

extension View {
    func appCard(padding: CGFloat = 16, radius: CGFloat = Theme.radiusMD) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}
