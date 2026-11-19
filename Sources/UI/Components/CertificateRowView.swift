import Cocoa

// MARK: - CertificateRowView

/// Structured certificate summary panel shown inside the hero card after a
/// file is selected: tinted icon badge, filename + format/size tag, subject
/// details, file path + Android target hash, and replace/remove actions.
final class CertificateRowView: NSView {
    var onRemove: (() -> Void)?
    var onReplace: (() -> Void)?

    enum BadgeStyle {
        case neutral(String)
        case valid(String)
        case warning(String)
        case error(String)
    }

    private let iconBadge = NSView()
    private var iconBadgeColor: NSColor = Theme.tileLavender.background
    private let iconView = SymbolImageView(
        symbol: "doc.text.fill", pointSize: 18, tint: Theme.accent)

    private let nameLabel = NSTextField(labelWithString: "")
    private let metaBadge = PillTagView()
    private let statusBadge = PillTagView()
    private let subjectLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")

    private let replaceButton = NSButton(title: "Replace…", target: nil, action: nil)
    private let removeButton = NSButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!,
        target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        iconBadge.wantsLayer = true
        iconBadge.layer?.cornerRadius = 10
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconView)

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subjectLabel.font = .systemFont(ofSize: 12)
        subjectLabel.textColor = .secondaryLabelColor
        subjectLabel.lineBreakMode = .byTruncatingTail
        subjectLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        replaceButton.bezelStyle = .rounded
        replaceButton.controlSize = .small
        replaceButton.font = .systemFont(ofSize: 11, weight: .medium)
        replaceButton.target = self
        replaceButton.action = #selector(replace)
        replaceButton.toolTip = "Choose a different certificate"

        removeButton.isBordered = false
        removeButton.imagePosition = .imageOnly
        removeButton.imageScaling = .scaleProportionallyDown
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.setAccessibilityLabel("Remove certificate")
        removeButton.toolTip = "Remove certificate"
        removeButton.target = self
        removeButton.action = #selector(remove)

        let titleRow = NSStackView(views: [nameLabel, metaBadge])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        let textStack = NSStackView(views: [titleRow, subjectLabel, pathLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let actionsStack = NSStackView(views: [statusBadge, replaceButton, removeButton])
        actionsStack.orientation = .horizontal
        actionsStack.alignment = .centerY
        actionsStack.spacing = 8

        for view in [iconBadge, textStack, actionsStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        replaceButton.setContentHuggingPriority(.required, for: .horizontal)
        removeButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            iconBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: 42),
            iconBadge.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            textStack.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(
                lessThanOrEqualTo: actionsStack.leadingAnchor, constant: -14),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),

            actionsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            actionsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 18),
            removeButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isOpaque: Bool { false }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        iconBadge.layer?.backgroundColor = iconBadgeColor.cgColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        Theme.windowBackground.setFill()
        path.fill()
        Theme.cardBorder.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func setControlsEnabled(_ enabled: Bool) {
        replaceButton.isEnabled = enabled
        removeButton.isEnabled = enabled
    }

    func configure(
        name: String, meta: String, subject: String, subjectColor: NSColor,
        pathSummary: String, badge: BadgeStyle
    ) {
        nameLabel.stringValue = name
        metaBadge.configure(
            text: meta, background: Theme.tileLavender.background,
            foreground: Theme.tileLavender.content)
        metaBadge.isHidden = meta.isEmpty
        subjectLabel.stringValue = subject
        subjectLabel.textColor = subjectColor
        pathLabel.stringValue = pathSummary

        switch badge {
        case .neutral(let text):
            iconView.configure(symbol: "doc.text.fill", tint: Theme.accent)
            iconBadgeColor = Theme.tileLavender.background
            statusBadge.configure(
                text: text, background: Theme.tileBlue.background,
                foreground: Theme.tileBlue.content)
        case .valid(let text):
            iconView.configure(symbol: "checkmark.seal.fill", tint: Theme.tileMint.content)
            iconBadgeColor = Theme.tileMint.background
            statusBadge.configure(
                text: text, background: Theme.tileMint.background,
                foreground: Theme.tileMint.content)
        case .warning(let text):
            iconView.configure(
                symbol: "exclamationmark.triangle.fill", tint: Theme.tilePeach.content)
            iconBadgeColor = Theme.tilePeach.background
            statusBadge.configure(
                text: text, background: Theme.tilePeach.background,
                foreground: Theme.tilePeach.content)
        case .error(let text):
            iconView.configure(symbol: "xmark.octagon.fill", tint: .systemRed)
            iconBadgeColor = NSColor.systemRed.withAlphaComponent(0.12)
            statusBadge.configure(
                text: text, background: NSColor.systemRed.withAlphaComponent(0.12),
                foreground: .systemRed)
        }
        iconBadge.layer?.backgroundColor = iconBadgeColor.cgColor
        needsDisplay = true
    }

    @objc private func remove() { onRemove?() }
    @objc private func replace() { onReplace?() }
}

// MARK: - PillTagView

/// Compact rounded badge pill used for file format tags and CA status.
private final class PillTagView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var fillColor: NSColor = Theme.tileLavender.background

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 10.5, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        fillColor.setFill()
        path.fill()
    }

    func configure(text: String, background: NSColor, foreground: NSColor) {
        label.stringValue = text
        label.textColor = foreground
        fillColor = background
        needsDisplay = true
    }
}
