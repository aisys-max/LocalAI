import SwiftUI

/// Color/font tokens ported from the design system's `_ds/organic-*/styles.css`.
/// Font substitution: the design uses the Google Fonts "Caprasimo" (display) and
/// "Figtree" (body); neither ships with iOS, so headings use bold SF Rounded and
/// body/UI text uses the system font as close stand-ins.
enum Palette {
    static let bg = Color(hex: 0xF5EAD8)
    static let surface = Color(hex: 0xEBDDC5)
    static let text = Color(hex: 0x201E1D)
    static let accent = Color(hex: 0xC67139)
    static let accent2 = Color(hex: 0x7A8A5E)

    enum Neutral {
        static let n100 = Color(hex: 0xF9F4ED)
        static let n200 = Color(hex: 0xEEE7DB)
        static let n300 = Color(hex: 0xDCD3C4)
        static let n400 = Color(hex: 0xC0B6A5)
        static let n700 = Color(hex: 0x645C50)
        static let n800 = Color(hex: 0x474238)
        static let n900 = Color(hex: 0x2E2B25)
    }

    enum Accent {
        static let a100 = Color(hex: 0xFFF2EB)
        static let a800 = Color(hex: 0x643312)
        static let a900 = Color(hex: 0x402310)
    }

    enum Accent2 {
        static let a100 = Color(hex: 0xF0FAE1)
        static let a700 = Color(hex: 0x56633F)
        static let a800 = Color(hex: 0x3D472B)
    }
}

/// Resolved theme for the current appearance — mirrors `renderVals()`'s `theme` object.
struct Theme {
    let bg: Color
    let surface: Color
    let surface2: Color
    let text: Color
    let textMuted: Color
    let divider: Color
    let accent: Color
    let accent2: Color
    let onAccentText: Color
    let selectedTint: Color
    let selectedText: Color
    let destructive: Color

    static func resolve(dark: Bool) -> Theme {
        if dark {
            return Theme(
                bg: Palette.Neutral.n900,
                surface: Palette.Neutral.n800,
                surface2: Palette.Neutral.n700,
                text: Palette.Neutral.n100,
                textMuted: Palette.Neutral.n400,
                divider: Color.white.opacity(0.12),
                accent: Palette.accent,
                accent2: Palette.accent2,
                onAccentText: Palette.Accent.a900,
                selectedTint: Palette.Accent.a900,
                selectedText: Palette.accent,
                destructive: Color(hex: 0xFF6B6B)
            )
        } else {
            return Theme(
                bg: Palette.bg,
                surface: .white,
                surface2: Palette.surface,
                text: Palette.text,
                textMuted: Palette.text.opacity(0.55),
                divider: Palette.text.opacity(0.16),
                accent: Palette.accent,
                accent2: Palette.accent2,
                onAccentText: Palette.bg,
                selectedTint: Palette.Accent.a100,
                selectedText: Palette.Accent.a800,
                destructive: Color(hex: 0xD64545)
            )
        }
    }
}

enum AppFont {
    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
