import Cocoa

// MARK: - DropCardView

/// The certificate card: dashed drop zone at rest, accent-tinted while a
/// file hovers over it, and a click/Space target that opens the picker.
final class DropCardView: NSView {
    var onFiles: (([URL]) -> Void)?
    var onBrowse: (() -> Void)?
    var acceptsDrops = true { didSet { if !acceptsDrops { isDropActive = false } } }
    private var isDropActive = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { acceptsDrops }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: Theme.cardCornerRadius, yRadius: Theme.cardCornerRadius)
        (isDropActive ? Theme.accent.withAlphaComponent(0.08) : Theme.card).setFill()
        path.fill()
        if isDropActive {
            Theme.accent.setStroke()
            path.lineWidth = 2
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.setLineDash([5, 4], count: 2, phase: 0)
        }
        path.stroke()
    }

    private func draggedFiles(_ sender: NSDraggingInfo) -> [URL]? {
        guard
            let files = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            !files.isEmpty
        else { return nil }
        return files
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrops, draggedFiles(sender) != nil else { return [] }
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
        guard acceptsDrops, let urls = draggedFiles(sender) else { return false }
        onFiles?(urls)
        return true
    }

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
