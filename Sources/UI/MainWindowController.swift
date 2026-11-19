import Cocoa
import UniformTypeIdentifiers

final class MainWindowController: NSObject {
    private var window: NSWindow!
    private var selected: URL?
    private(set) var isBuilding = false

    private enum StatusKind { case idle, ready, success, error }

    // Header
    private let badge = BadgeView()
    private let headerIcon = ArtworkView(
        resource: "Burp2MagiskGlyph", template: true,
        fallbackSymbol: "checkmark.seal", fallbackTint: .white)
    private let headerTitle = NSTextField(labelWithString: "Burp2Magisk")
    private let headerSubtitle = NSTextField(
        wrappingLabelWithString: "แปลง Burp CA certificate เป็น Magisk module สำหรับ Android")

    // Card: placeholder
    private let card = DropCardView()
    private let cardIcon = ArtworkView(
        resource: "Burp2Magisk", template: false,
        fallbackSymbol: "doc.zipper", fallbackTint: Theme.accent)
    private let cardTitle = NSTextField(wrappingLabelWithString: "ลากไฟล์ใบรับรอง Burp มาวางที่นี่")
    private let cardSubtitle = NSTextField(wrappingLabelWithString: "รองรับไฟล์ .der และ .pem")
    private let placeholderStack = NSStackView()

    // Card: selected file summary
    private let fileIcon = NSImageView()
    private let fileName = NSTextField(labelWithString: "")
    private let fileDetail = NSTextField(labelWithString: "")
    private let textStack = NSStackView()
    private let clearButton = NSButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!,
        target: nil, action: nil)
    private let summaryStack = NSStackView()

    // Status
    private let statusIcon = SymbolImageView(
        symbol: "info.circle.fill", pointSize: 15, tint: .secondaryLabelColor)
    private let spinner: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.sizeToFit()
        indicator.isHidden = true
        return indicator
    }()
    private let statusLabel = NSTextField(wrappingLabelWithString: "เลือกไฟล์ใบรับรองเพื่อเริ่ม")

    // Footer actions
    private let footerLabel = NSTextField(
        wrappingLabelWithString: "สร้าง ZIP สำหรับติดตั้งผ่าน Magisk บน Android")
    private let browseButton = NSButton(title: "เลือกไฟล์…", target: nil, action: nil)
    private let buildButton = AccentButton(title: "สร้าง Magisk ZIP…")

    // MARK: Launch

    func showWindow() {
        configureViews()
        let contentRect = NSRect(x: 0, y: 0, width: 620, height: 400)
        window = NSWindow(
            contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Burp2Magisk"
        window.subtitle = "แปลง Burp CA เป็น Magisk module"
        window.contentMinSize = NSSize(width: 600, height: 380)
        installLayout(in: window.contentView!)
        NSApp.setActivationPolicy(.regular)
        window.center()
        window.initialFirstResponder = card
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: View configuration

    private func configureViews() {
        headerTitle.font = .preferredFont(forTextStyle: .title2)

        headerSubtitle.font = .systemFont(ofSize: 13)
        headerSubtitle.textColor = .secondaryLabelColor

        cardTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        cardTitle.alignment = .center
        cardSubtitle.font = .systemFont(ofSize: 12)
        cardSubtitle.textColor = .secondaryLabelColor
        cardSubtitle.alignment = .center

        fileName.font = .systemFont(ofSize: 13, weight: .medium)
        fileName.lineBreakMode = .byTruncatingMiddle
        fileName.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fileName.setAccessibilityLabel("ไฟล์ที่เลือก")
        fileDetail.font = .systemFont(ofSize: 11)
        fileDetail.textColor = .secondaryLabelColor

        fileIcon.imageScaling = .scaleProportionallyDown

        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        clearButton.imageScaling = .scaleProportionallyDown
        clearButton.setAccessibilityLabel("ล้างไฟล์ที่เลือก")
        clearButton.toolTip = "ล้างไฟล์ที่เลือก"
        clearButton.target = self
        clearButton.action = #selector(clear)

        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .tertiaryLabelColor

        browseButton.bezelStyle = .rounded
        browseButton.controlSize = .large
        browseButton.font = .systemFont(ofSize: 13)
        browseButton.target = self
        browseButton.action = #selector(pick)
        browseButton.toolTip = "เปิดหน้าต่างเลือกไฟล์ใบรับรอง"

        buildButton.target = self
        buildButton.action = #selector(makeZip)
        buildButton.keyEquivalent = "\r"
        buildButton.isEnabled = false
        buildButton.toolTip = "สร้าง ZIP สำหรับติดตั้งผ่าน Magisk จากไฟล์ที่เลือก"

        card.onFile = { [weak self] url in self?.select(url) }
        card.onBrowse = { [weak self] in self?.pick() }
        card.toolTip = "ลากไฟล์ใบรับรองมาวาง หรือคลิกเพื่อเลือกไฟล์"
        card.setAccessibilityLabel("พื้นที่รับไฟล์ใบรับรอง")
        let click = NSClickGestureRecognizer(target: self, action: #selector(pick))
        card.addGestureRecognizer(click)

        headerIcon.setAccessibilityElement(false)
        cardIcon.setAccessibilityElement(false)
        statusIcon.setAccessibilityElement(false)
        fileIcon.setAccessibilityElement(false)
        spinner.setAccessibilityLabel("กำลังตรวจ certificate และสร้าง ZIP")

        summaryStack.isHidden = true
    }

    // MARK: Layout

    private func installLayout(in content: NSView) {
        badge.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        headerSubtitle.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        buildButton.translatesAutoresizingMaskIntoConstraints = false

        badge.addSubview(headerIcon)
        content.addSubview(badge)
        content.addSubview(headerTitle)
        content.addSubview(headerSubtitle)
        content.addSubview(card)
        content.addSubview(statusIcon)
        content.addSubview(spinner)
        content.addSubview(statusLabel)
        content.addSubview(footerLabel)
        content.addSubview(browseButton)
        content.addSubview(buildButton)

        placeholderStack.orientation = .vertical
        placeholderStack.alignment = .centerX
        placeholderStack.spacing = 4
        for view in [cardIcon, cardTitle, cardSubtitle] {
            view.translatesAutoresizingMaskIntoConstraints = false
            placeholderStack.addArrangedSubview(view)
        }
        placeholderStack.setCustomSpacing(10, after: cardIcon)
        card.addSubview(placeholderStack)

        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        for view in [fileName, fileDetail] {
            view.translatesAutoresizingMaskIntoConstraints = false
            textStack.addArrangedSubview(view)
        }
        summaryStack.orientation = .horizontal
        summaryStack.alignment = .centerY
        summaryStack.spacing = 10
        for view in [fileIcon, textStack, clearButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            summaryStack.addArrangedSubview(view)
        }
        card.addSubview(summaryStack)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            badge.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            badge.widthAnchor.constraint(equalToConstant: 44),
            badge.heightAnchor.constraint(equalToConstant: 44),
            headerIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            headerIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            headerIcon.widthAnchor.constraint(equalToConstant: 24),
            headerIcon.heightAnchor.constraint(equalToConstant: 24),

            headerTitle.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            headerTitle.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            headerTitle.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            headerSubtitle.leadingAnchor.constraint(equalTo: headerTitle.leadingAnchor),
            headerSubtitle.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            headerSubtitle.topAnchor.constraint(equalTo: headerTitle.bottomAnchor, constant: 1),

            card.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 20),
            card.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            card.heightAnchor.constraint(equalToConstant: 172),

            placeholderStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            placeholderStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: card.leadingAnchor, constant: 20),
            placeholderStack.trailingAnchor.constraint(
                lessThanOrEqualTo: card.trailingAnchor, constant: -20),
            cardIcon.widthAnchor.constraint(equalToConstant: 44),
            cardIcon.heightAnchor.constraint(equalToConstant: 44),
            cardTitle.widthAnchor.constraint(lessThanOrEqualToConstant: 470),

            summaryStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            summaryStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            summaryStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: card.leadingAnchor, constant: 20),
            summaryStack.trailingAnchor.constraint(
                lessThanOrEqualTo: card.trailingAnchor, constant: -20),
            fileIcon.widthAnchor.constraint(equalToConstant: 36),
            fileIcon.heightAnchor.constraint(equalToConstant: 36),
            fileName.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            clearButton.widthAnchor.constraint(equalToConstant: 18),
            clearButton.heightAnchor.constraint(equalToConstant: 18),

            statusIcon.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            statusIcon.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16),
            spinner.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            spinner.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            statusLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 16),

            footerLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            footerLabel.centerYAnchor.constraint(equalTo: buildButton.centerYAnchor),

            browseButton.centerYAnchor.constraint(equalTo: buildButton.centerYAnchor),
            browseButton.trailingAnchor.constraint(
                equalTo: buildButton.leadingAnchor, constant: -12),
            buildButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buildButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            buildButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])
    }

    // MARK: State

    private func setStatus(_ text: String, kind: StatusKind) {
        statusLabel.stringValue = text
        switch kind {
        case .idle:
            statusIcon.configure(symbol: "info.circle.fill", tint: .secondaryLabelColor)
        case .ready:
            statusIcon.configure(symbol: "checkmark.shield.fill", tint: Theme.accent)
        case .success:
            statusIcon.configure(symbol: "checkmark.circle.fill", tint: .systemGreen)
        case .error:
            statusIcon.configure(symbol: "exclamationmark.triangle.fill", tint: .systemRed)
        }
    }

    private func setBusy(_ isBusy: Bool) {
        isBuilding = isBusy
        card.acceptsDrops = !isBusy
        card.alphaValue = isBusy ? 0.6 : 1
        browseButton.isEnabled = !isBusy
        buildButton.isEnabled = !isBusy && selected != nil
        spinner.isHidden = !isBusy
        statusIcon.isHidden = isBusy
        if isBusy { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }

    func select(_ url: URL) {
        guard !isBuilding else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            !isDirectory.boolValue
        else { return }
        selected = url
        fileName.stringValue = url.lastPathComponent
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        let ext = url.pathExtension.uppercased()
        fileDetail.stringValue = ext.isEmpty ? formattedSize : "\(formattedSize) · \(ext)"
        fileIcon.image = NSWorkspace.shared.icon(forFile: url.path)
        placeholderStack.isHidden = true
        summaryStack.isHidden = false
        setStatus("พร้อมตรวจ CA:TRUE และสร้าง ZIP", kind: .ready)
        buildButton.isEnabled = true
    }

    @objc func clear() {
        guard !isBuilding else { return }
        selected = nil
        fileName.stringValue = ""
        fileDetail.stringValue = ""
        fileIcon.image = nil
        placeholderStack.isHidden = false
        summaryStack.isHidden = true
        setStatus("เลือกไฟล์ใบรับรองเพื่อเริ่ม", kind: .idle)
        buildButton.isEnabled = false
    }

    @objc func pick() {
        guard !isBuilding else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "เลือกไฟล์ใบรับรอง"
        panel.prompt = "เลือก"
        panel.message = "เลือก Burp CA certificate แบบ DER หรือ PEM"
        if panel.runModal() == .OK, let url = panel.url { select(url) }
    }

    @objc func makeZip() {
        guard let input = selected, !isBuilding else { return }
        let panel = NSSavePanel()
        panel.title = "บันทึก Magisk ZIP"
        panel.prompt = "บันทึก"
        panel.nameFieldStringValue = "BurpCA-Magisk.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        setBusy(true)
        setStatus("กำลังตรวจ certificate และสร้าง ZIP…", kind: .ready)
        let builder = ModuleBuilder(resourcesURL: Bundle.main.resourceURL)
        DispatchQueue.global(qos: .userInitiated).async {
            let errorMessage: String?
            do {
                try builder.build(certificate: input, destination: destination)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            let message = errorMessage
            DispatchQueue.main.async {
                self.setBusy(false)
                if let message = message {
                    self.setStatus("สร้างไม่สำเร็จ", kind: .error)
                    let alert = NSAlert()
                    alert.messageText = "สร้าง Magisk ZIP ไม่สำเร็จ"
                    alert.informativeText = message
                    alert.alertStyle = .warning
                    alert.runModal()
                } else {
                    self.setStatus(
                        "สร้างสำเร็จ: \(destination.lastPathComponent)\nนำไปติดตั้งใน Magisk แล้ว reboot ด้วยตัวเอง",
                        kind: .success)
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            }
        }
    }
}
