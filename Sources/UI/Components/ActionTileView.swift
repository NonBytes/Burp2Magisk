import Cocoa

// MARK: - ActionTileView

/// Pastel quick-action tile: centered colored SF Symbol over a crisp label,
/// with hover, press, and disabled states.
final class ActionTileView: NSView {
    var onTap: (() -> Void)?

    private let tint: Theme.TileTint
    private let symbolView: SymbolImageView
    private let titleLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isPressed = false

    var isEnabled = true {
        didSet {
            alphaValue = isEnabled ? 1 : 0.5
            needsDisplay = true
        }
    }

    init(symbol: String, tint: Theme.TileTint, title: String) {
        self.tint = tint
        symbolView = SymbolImageView(symbol: symbol, pointSize: 20, tint: tint.content)
        super.init(frame: .zero)

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            symbolView.widthAnchor.constraint(equalToConstant: 22),
            symbolView.heightAnchor.constraint(equalToConstant: 22),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: symbolView.bottomAnchor, constant: 5),
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])

        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { isEnabled }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        let fill: NSColor
        if !isEnabled {
            fill = Theme.tileDisabledFill
        } else if isPressed {
            fill = tint.background.shadow(withLevel: 0.18) ?? tint.background
        } else if isHovered {
            fill = tint.background.blended(withFraction: 0.35, of: .white) ?? tint.background
        } else {
            fill = tint.background
        }
        fill.setFill()
        path.fill()
    }

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
        guard isEnabled else { return }
        isHovered = true
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        needsDisplay = true
    }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard isEnabled, isPressed else {
            isPressed = false
            return
        }
        isPressed = false
        needsDisplay = true
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) { onTap?() }
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49, 36, 76:  // Space, Return, Enter
            if isEnabled { onTap?() }
        default:
            super.keyDown(with: event)
        }
    }
    override func resetCursorRects() {
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }
}
