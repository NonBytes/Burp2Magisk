import Cocoa

// MARK: - SymbolImageView

/// SF Symbol image that re-tints itself when the appearance changes.
final class SymbolImageView: NSImageView {
    private var symbolName: String
    private var pointSize: CGFloat
    private var tint: NSColor

    init(symbol: String, pointSize: CGFloat, tint: NSColor) {
        self.symbolName = symbol
        self.pointSize = pointSize
        self.tint = tint
        super.init(frame: .zero)
        imageScaling = .scaleProportionallyDown
        contentTintColor = tint
        rebuildImage()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    required init?(image: NSImage?) { fatalError("init(image:) is not supported") }

    func configure(symbol: String, tint: NSColor) {
        self.symbolName = symbol
        self.tint = tint
        contentTintColor = tint
        rebuildImage()
    }

    private func rebuildImage() {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        self.image = image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular))
    }
}
