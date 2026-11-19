import Cocoa

// MARK: - CertificateRowView

/// One selected certificate: icon, name, a preview/error detail line, and a
/// per-row remove button. Several of these stack vertically inside the card.
final class CertificateRowView: NSView {
    var onRemove: (() -> Void)?

    private let icon = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let textStack = NSStackView()
    private let removeButton = NSButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!,
        target: nil, action: nil)
    private let rowStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        icon.imageScaling = .scaleProportionallyDown
        icon.setAccessibilityElement(false)

        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.maximumNumberOfLines = 2

        removeButton.isBordered = false
        removeButton.imagePosition = .imageOnly
        removeButton.imageScaling = .scaleProportionallyDown
        removeButton.setAccessibilityLabel("นำไฟล์นี้ออก")
        removeButton.toolTip = "นำไฟล์นี้ออก"
        removeButton.target = self
        removeButton.action = #selector(remove)

        for view in [icon, textStack, removeButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        for view in [nameLabel, detailLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            textStack.addArrangedSubview(view)
        }

        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 10
        for view in [icon, textStack, removeButton] { rowStack.addArrangedSubview(view) }
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            removeButton.widthAnchor.constraint(equalToConstant: 16),
            removeButton.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(icon: NSImage?, name: String, detail: String, detailColor: NSColor) {
        self.icon.image = icon
        nameLabel.stringValue = name
        detailLabel.stringValue = detail
        detailLabel.textColor = detailColor
    }

    @objc private func remove() { onRemove?() }
}
