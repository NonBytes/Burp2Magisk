import Cocoa

// MARK: - AccentButton

/// Filled rounded pill button used for the contextual banner action. Draws
/// its own background so it reads as the prominent action in every appearance.
final class AccentButton: NSButton {
    private let preferredHeight: CGFloat
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    init(title: String, height: CGFloat = 30, fontSize: CGFloat = 13) {
        self.preferredHeight = height
        super.init(frame: .zero)
        isBordered = false
        self.title = title
        font = .systemFont(ofSize: fontSize, weight: .medium)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: NSSize {
        let size = (title as NSString).size(
            withAttributes: [.font: font ?? .systemFont(ofSize: 13)])
        return NSSize(width: ceil(size.width) + 28, height: preferredHeight)
    }

    override var isHighlighted: Bool { didSet { needsDisplay = true } }
    override var isEnabled: Bool { didSet { needsDisplay = true } }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func draw(_ dirtyRect: NSRect) {
        let cornerRadius: CGFloat = 9
        let path = NSBezierPath(
            roundedRect: NSRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: bounds.height - 1),
            xRadius: cornerRadius, yRadius: cornerRadius)
        let fill: NSColor
        let titleColor: NSColor
        if isEnabled {
            let base = Theme.accent
            fill =
                isHighlighted
                ? (base.shadow(withLevel: 0.3) ?? base)
                : isHovered
                    ? (base.blended(withFraction: 0.12, of: .white) ?? base)
                    : base
            titleColor = .white
        } else {
            fill = .tertiaryLabelColor.withAlphaComponent(0.25)
            titleColor = .secondaryLabelColor
        }
        fill.setFill()
        path.fill()

        if isEnabled {
            NSColor.black.withAlphaComponent(isHighlighted ? 0.18 : 0.08).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        if window?.firstResponder === self {
            let focus = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
                xRadius: cornerRadius + 1.5, yRadius: cornerRadius + 1.5)
            NSColor.keyboardFocusIndicatorColor.setStroke()
            focus.lineWidth = 3
            focus.stroke()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 13),
            .foregroundColor: titleColor,
        ]
        let text = NSAttributedString(string: title, attributes: attributes)
        let textSize = text.size()
        text.draw(
            at: NSPoint(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2 - 0.5))
    }
}
