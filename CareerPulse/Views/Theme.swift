import SwiftUI

/// A selectable accent palette. The chassis (backgrounds, text, cards) and the
/// mastery semantics stay constant in every palette — known is always green,
/// new always gray, and lightness ordering stays color-blind safe. Only the
/// accent hue ("learning" + interface highlights) changes.
struct Palette: Identifiable, Equatable {
    let name: String
    let accentHex: UInt32        // stateLearning + buttons + highlights
    let accentTintHex: UInt32    // chip/tag backgrounds
    let accentWashHex: UInt32    // gradient-card wash
    let accentBorderHex: UInt32  // gradient-card border

    var id: String { name }
    var accent: Color { Color(hex: accentHex) }
    var accentTint: Color { Color(hex: accentTintHex) }
    var accentWash: Color { Color(hex: accentWashHex) }
    var accentBorder: Color { Color(hex: accentBorderHex) }

    static let ocean = Palette(name: "Ocean", accentHex: 0x3D7BE0,
                               accentTintHex: 0xEEF4FD, accentWashHex: 0xF3F7FE,
                               accentBorderHex: 0xDCE7F8)
    static let plum = Palette(name: "Plum", accentHex: 0x8B5CF6,
                              accentTintHex: 0xF3EEFD, accentWashHex: 0xF8F4FE,
                              accentBorderHex: 0xE6DAFA)
    static let forest = Palette(name: "Forest", accentHex: 0x0F9D8F,
                                accentTintHex: 0xE8F6F4, accentWashHex: 0xF0FAF8,
                                accentBorderHex: 0xCFEAE6)
    static let sunset = Palette(name: "Sunset", accentHex: 0xE8624A,
                                accentTintHex: 0xFDEFEC, accentWashHex: 0xFEF5F2,
                                accentBorderHex: 0xF8D9D0)
    static let mono = Palette(name: "Mono", accentHex: 0x374151,
                              accentTintHex: 0xEDF0F3, accentWashHex: 0xF6F7F9,
                              accentBorderHex: 0xE0E4E9)

    static let all: [Palette] = [.ocean, .plum, .forest, .sunset, .mono]

    static func named(_ name: String?) -> Palette {
        all.first { $0.name == name } ?? .ocean
    }
}

/// Design tokens. Accent-dependent tokens resolve the selected palette at
/// read time; RootTabView re-renders the tree when the palette changes.
enum Theme {
    static let paletteKey = "palette"

    static var palette: Palette {
        Palette.named(UserDefaults.standard.string(forKey: paletteKey))
    }

    // Constant chassis
    static let background = Color(hex: 0xF6F7F9)
    static let card = Color.white
    static let cardBorder = Color(hex: 0xE4E8ED)
    static let textPrimary = Color(hex: 0x17181A)
    static let textSecondary = Color(hex: 0x6B7280)
    static let textTertiary = Color(hex: 0x8A919C)

    // Constant mastery semantics
    static let stateNew = Color(hex: 0xA6ADB8)
    static let stateKnown = Color(hex: 0x2FA46B)
    static let knownTint = Color(hex: 0xEAF6F0)
    static let newTint = Color(hex: 0xF1F3F6)

    // Palette-driven accent
    static var stateLearning: Color { palette.accent }
    static var learningTint: Color { palette.accentTint }
    static var accentWash: Color { palette.accentWash }
    static var accentBorder: Color { palette.accentBorder }

    static let cardRadius: CGFloat = 18
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// White card with hairline border — the base surface for every screen.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func techPulseCard() -> some View { modifier(CardBackground()) }
}
