import Cocoa

// MARK: - MetricCardView

/// Compact metric tile: colored SF Symbol, uppercase micro-label, bold value,
/// and a muted sub-caption — one of the four cards in the dashboard row.
final class MetricCardView: CardView {
    private let icon = SymbolImageView(
        symbol: "questionmark.circle", pointSize: 14, tint: .secondaryLabelColor)
    private let label: NSTextField
    private let valueLabel = NSTextField(labelWithString: "—")
    private let captionLabel = NSTextField(labelWithString: "")

    init(title: String) {
        label = Theme.microLabel(title)
        super.init(frame: .zero)

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 5

        valueLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        captionLabel.font = .systemFont(ofSize: 10)
        captionLabel.textColor = .tertiaryLabelColor
        captionLabel.lineBreakMode = .byTruncatingTail
        captionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3

        for view in [icon, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            header.addArrangedSubview(view)
        }
        for view in [header, valueLabel, captionLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(view)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(symbol: String, tint: NSColor, value: String, caption: String) {
        icon.configure(symbol: symbol, tint: tint)
        valueLabel.stringValue = value
        captionLabel.stringValue = caption
    }
}
