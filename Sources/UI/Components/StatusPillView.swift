import Cocoa

// MARK: - StatusPillView

/// Sleek compact capsule in the header reporting the ADB connection state.
final class StatusPillView: NSView {
    private var text = "Checking…"
    private var tint: NSColor = .secondaryLabelColor

    override var isOpaque: Bool { false }

    func configure(text: String, tint: NSColor) {
        self.text = text
        self.tint = tint
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        let size = (text as NSString).size(withAttributes: Self.textAttributes)
        return NSSize(width: ceil(size.width) + 10 + 7 + 6 + 12, height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let capsule = NSBezierPath(
            roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        Theme.pillFill.setFill()
        capsule.fill()
        Theme.pillBorder.setStroke()
        capsule.lineWidth = 1
        capsule.stroke()

        let dot = NSBezierPath(
            ovalIn: NSRect(x: 10, y: (bounds.height - 7) / 2, width: 7, height: 7))
        tint.setFill()
        dot.fill()

        let size = (text as NSString).size(withAttributes: Self.textAttributes)
        (text as NSString).draw(
            at: NSPoint(x: 23, y: (bounds.height - size.height) / 2 - 0.5),
            withAttributes: Self.textAttributes)
    }

    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .medium),
        .foregroundColor: NSColor.labelColor,
    ]
}
