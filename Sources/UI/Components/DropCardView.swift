import Cocoa

// MARK: - DropCardView

/// Dashed interactive drop zone shown inside the certificate card while no
/// certificate is selected. Accent-tinted while a file hovers over it, and a
/// click/Space/Return target that opens the file picker.
final class DropCardView: NSView {
    var onFile: ((URL) -> Void)?
    var onBrowse: (() -> Void)?
    var acceptsDrops = true { didSet { if !acceptsDrops { isDropActive = false } } }
    private var isDropActive = false { didSet { needsDisplay = true } }

    private let icon = ArtworkView(
        resource: "Burp2MagiskGlyph", template: true,
        fallbackSymbol: "doc.badge.plus", fallbackTint: Theme.accent)
    private let titleLabel = NSTextField(labelWithString: "Drop a Burp CA certificate here")
    private let subtitleLabel = NSTextField(
        labelWithString: "Supports .der and .pem — or click to choose")
    private let contentStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        icon.setAccessibilityElement(false)

        contentStack.orientation = .vertical
        contentStack.alignment = .centerX
        contentStack.spacing = 3
        for view in [icon, titleLabel, subtitleLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview(view)
        }
        contentStack.setCustomSpacing(6, after: icon)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14),
            contentStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -16),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { acceptsDrops }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        if isDropActive {
            Theme.accentSoft.setFill()
            path.fill()
            Theme.accent.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        } else {
            Theme.dropZoneBorder.setStroke()
            path.lineWidth = 1
            path.setLineDash([5, 4], count: 2, phase: 0)
            path.stroke()
        }
    }

    private func draggedFile(_ sender: NSDraggingInfo) -> URL? {
        guard
            let files = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            files.count == 1, let file = files.first
        else { return nil }
        return file
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrops, draggedFile(sender) != nil else { return [] }
        isDropActive = true
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDropActive ? .copy : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropActive = false
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropActive = false
        guard acceptsDrops, let url = draggedFile(sender) else { return false }
        onFile?(url)
        return true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard acceptsDrops, bounds.contains(point) else { return }
        onBrowse?()
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49:  // Space
            onBrowse?()
        case 36, 76:  // Return/Enter — only reached when no enabled default button consumed it
            onBrowse?()
        default:
            super.keyDown(with: event)
        }
    }
}
