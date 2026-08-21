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

enum Theme {
    static let lightBackground = Color(hex: 0xF5F6F8)
    static let lightCard = Color(hex: 0xFFFFFF)
    static let lightWarm = Color(hex: 0xFDF6E3)
    static let lightRose = Color(hex: 0xFBF1F0)
    static let lightText = Color(hex: 0x16181C)
    static let lightSecondary = Color(hex: 0x5F6672)
    static let lightBorder = Color.black.opacity(0.07)
    static let lightAccent = Color(hex: 0x3D7BF0)
    static let lightAligned = Color(hex: 0x2F9E63)
    static let lightWarn = Color(hex: 0xE09B2D)
    static let lightMisaligned = Color(hex: 0xD95757)

    static let darkBackground = Color(hex: 0x17181C)
    static let darkCard = Color(hex: 0x1F2126)
    static let darkText = Color(hex: 0xEDEFF2)
    static let darkSecondary = Color(hex: 0x9AA1AD)
    static let darkBorder = Color.white.opacity(0.09)
    static let darkAccent = Color(hex: 0x5C9CE6)
    static let darkAligned = Color(hex: 0x4FC08A)
    static let darkWarn = Color(hex: 0xE3B341)
    static let darkMisaligned = Color(hex: 0xE56B6B)
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
        scheme == .dark ? dark : light
    }

    static let light = AppPalette(
        background: Theme.lightBackground,
        card: Theme.lightCard,
        text: Theme.lightText,
        secondary: Theme.lightSecondary,
        border: Theme.lightBorder,
        accent: Theme.lightAccent,
        aligned: Theme.lightAligned,
        warn: Theme.lightWarn,
        misaligned: Theme.lightMisaligned
    )

    static let dark = AppPalette(
        background: Theme.darkBackground,
        card: Theme.darkCard,
        text: Theme.darkText,
        secondary: Theme.darkSecondary,
        border: Theme.darkBorder,
        accent: Theme.darkAccent,
        aligned: Theme.darkAligned,
        warn: Theme.darkWarn,
        misaligned: Theme.darkMisaligned
    )
}