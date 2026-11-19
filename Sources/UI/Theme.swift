import Cocoa

// MARK: - Theme

enum Theme {
    /// Restrained teal accent that stays legible in light and dark appearances.
    static let accent = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 0.27, green: 0.80, blue: 0.74, alpha: 1)
        }
        return NSColor(srgbRed: 0.09, green: 0.48, blue: 0.44, alpha: 1)
    }

    /// Elevated card surface: white on the light window, lighter gray in dark mode.
    static let card = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(srgbRed: 0.235, green: 0.235, blue: 0.255, alpha: 1)
        }
        return NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    }

    static let cardCornerRadius: CGFloat = 12
}
