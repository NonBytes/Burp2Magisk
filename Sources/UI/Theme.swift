import Cocoa

// MARK: - Theme

enum Theme {
    /// Airy cool-lavender canvas behind every card; rich dark slate in dark mode.
    static let windowBackground = dynamic(light: rgb(0xF6F7FB), dark: rgb(0x14151C))

    /// Elevated card surface: crisp white on the light canvas, lifted slate in dark.
    static let card = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x1D1F29))

    /// Hairline border drawn around elevated cards.
    static let cardBorder = dynamic(
        light: rgb(0x141A33, alpha: 0.08), dark: rgb(0xFFFFFF, alpha: 0.09))

    /// Soft diffused shadow cast by elevated cards.
    static let cardShadow = dynamic(
        light: rgb(0x3A3F6B, alpha: 0.12), dark: rgb(0x000000, alpha: 0.40))

    static let cardCornerRadius: CGFloat = 14

    /// Vibrant indigo-violet primary accent, brightened for dark mode.
    static let accent = dynamic(light: rgb(0x5B4FE9), dark: rgb(0x8B81FF))

    /// Tinted fill for an active drop zone.
    static let accentSoft = dynamic(
        light: rgb(0x5B4FE9, alpha: 0.08), dark: rgb(0x8B81FF, alpha: 0.12))

    /// Status banner surface: a whisper of violet sitting on the canvas.
    static let bannerFill = dynamic(light: rgb(0xEFEDFC), dark: rgb(0x242238))
    static let bannerBorder = dynamic(
        light: rgb(0x5B4FE9, alpha: 0.14), dark: rgb(0x8B81FF, alpha: 0.16))

    /// Compact status pill in the header.
    static let pillFill = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x232531))
    static let pillBorder = dynamic(
        light: rgb(0x141A33, alpha: 0.10), dark: rgb(0xFFFFFF, alpha: 0.10))

    /// Dashed outline of the idle certificate drop zone.
    static let dropZoneBorder = dynamic(
        light: rgb(0x5B4FE9, alpha: 0.38), dark: rgb(0x8B81FF, alpha: 0.42))

    /// Pastel tint pair for a quick-action tile.
    struct TileTint {
        let background: NSColor
        let content: NSColor
    }

    static let tileBlue = TileTint(
        background: dynamic(light: rgb(0xEAF1FE), dark: rgb(0x273349)),
        content: dynamic(light: rgb(0x3B7DED), dark: rgb(0x86ABF6)))
    static let tileLavender = TileTint(
        background: dynamic(light: rgb(0xEFEDFD), dark: rgb(0x2E2A4C)),
        content: dynamic(light: rgb(0x6A5AE0), dark: rgb(0xA79BF8)))
    static let tileMint = TileTint(
        background: dynamic(light: rgb(0xE7F7EE), dark: rgb(0x213A2E)),
        content: dynamic(light: rgb(0x1FA766), dark: rgb(0x64D0A2)))
    static let tilePeach = TileTint(
        background: dynamic(light: rgb(0xFDEEE3), dark: rgb(0x403023)),
        content: dynamic(light: rgb(0xE87E33), dark: rgb(0xF2A96E)))

    static let tileDisabledFill = dynamic(light: rgb(0xEDEEF3), dark: rgb(0x24262F))

    /// Uppercase micro-label used above hero content and metric values.
    static func microLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: "")
        field.attributedStringValue = NSAttributedString(
            string: text.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .kern: 0.6,
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        return field
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    private static func rgb(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha)
    }
}
