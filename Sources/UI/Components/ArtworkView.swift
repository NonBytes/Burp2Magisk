import Cocoa

// MARK: - ArtworkView

/// Image view that shows the app artwork, tinting the template variant
/// (used inside the header badge) to the requested color.
final class ArtworkView: NSImageView {
    private let resource: String
    private let template: Bool
    private let fallbackSymbol: String
    private let fallbackTint: NSColor

    init(resource: String, template: Bool, fallbackSymbol: String, fallbackTint: NSColor) {
        self.resource = resource
        self.template = template
        self.fallbackSymbol = fallbackSymbol
        self.fallbackTint = fallbackTint
        super.init(frame: .zero)
        imageScaling = .scaleProportionallyDown
        reloadImage()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    required init?(image: NSImage?) { fatalError("init(image:) is not supported") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        reloadImage()
    }

    private func reloadImage() {
        if let artwork = AppArtwork.image(named: resource, template: template) {
            image = artwork
            contentTintColor = template ? fallbackTint : nil
        } else if let symbol = NSImage(
            systemSymbolName: fallbackSymbol, accessibilityDescription: nil)
        {
            image = symbol
            contentTintColor = fallbackTint
        }
    }
}
