import Cocoa

// MARK: - BadgeView

/// Rounded square behind the header symbol, filled with the accent color.
final class BadgeView: NSView {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        Theme.accent.setFill()
        path.fill()
    }
}
