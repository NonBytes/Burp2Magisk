import Cocoa

// MARK: - CardView

/// Crisp elevated surface: appearance-aware fill, hairline border, and a soft
/// diffused shadow. Every card-shaped surface in the window builds on this.
class CardView: NSView {
    var fillColor = Theme.card
    var borderColor = Theme.cardBorder
    var cornerRadius = Theme.cardCornerRadius

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: cornerRadius, yRadius: cornerRadius)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.shadowBlurRadius = 22
        shadow.shadowColor = Theme.cardShadow
        shadow.set()
        fillColor.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
