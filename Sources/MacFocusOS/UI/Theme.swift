import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Dull-pink light theme — the whole UI uses this palette regardless of
/// system appearance.
enum Theme {
    static let background = Color(hex: 0xF7EDF0)
    static let card = Color(hex: 0xFFFBFC)
    static let text = Color(hex: 0x43333A)
    static let secondary = Color(hex: 0x937981)
    static let border = Color.black.opacity(0.08)
    static let accent = Color(hex: 0xC97F93)
    static let aligned = Color(hex: 0x5F9E82)
    static let warn = Color(hex: 0xD89B62)
    static let misaligned = Color(hex: 0xC75B6B)
    static let gold = Color(hex: 0xB98A2F)
}

struct AppPalette {
    let background: Color
    let card: Color
    let text: Color
    let secondary: Color
    let border: Color
    let accent: Color
    let aligned: Color
    let warn: Color
    let misaligned: Color

    static func current(_ scheme: ColorScheme) -> AppPalette {
        light
    }

    static let light = AppPalette(
        background: Theme.background,
        card: Theme.card,
        text: Theme.text,
        secondary: Theme.secondary,
        border: Theme.border,
        accent: Theme.accent,
        aligned: Theme.aligned,
        warn: Theme.warn,
        misaligned: Theme.misaligned
    )
}
