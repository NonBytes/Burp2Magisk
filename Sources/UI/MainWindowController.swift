import Cocoa
import UniformTypeIdentifiers

final class MainWindowController: NSObject {
    private var window: NSWindow!
    private var entries: [CertificateEntry] = []
    private(set) var isBuilding = false

    private enum StatusKind { case idle, ready, error }

    /// One selected certificate and the state of its background preview.
    private struct CertificateEntry {
        let url: URL
        var state: State
        let row: CertificateRowView

        enum State {
            case validating
            case valid(ModuleBuilder.CertificatePreview)
            case invalid(String)
        }
    }

    private static let recentDefaultsKey = "RecentCertificatePaths"
    private static let recentLimit = 6

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
    private let cardTitle = NSTextField(
        wrappingLabelWithString: "ลากไฟล์ใบรับรอง Burp มาวางที่นี่")
    private let cardSubtitle = NSTextField(
        wrappingLabelWithString: "รองรับไฟล์ .der และ .pem เลือกได้หลายไฟล์พร้อมกัน")
    private let placeholderStack = NSStackView()

    // Card: selected certificates list
    private let rowsScrollView = NSScrollView()
    private let rowsStack = NSStackView()
    private let clearButton = NSButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!,
        target: nil, action: nil)

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
    private let recentButton = NSButton(
        image: NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)!,
        target: nil, action: nil)
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
        refreshRecentButton()
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

        rowsScrollView.drawsBackground = false
        rowsScrollView.hasVerticalScroller = true
        rowsScrollView.autohidesScrollers = true
        rowsScrollView.isHidden = true

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 2

        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        clearButton.imageScaling = .scaleProportionallyDown
        clearButton.setAccessibilityLabel("ล้างไฟล์ที่เลือกทั้งหมด")
        clearButton.toolTip = "ล้างไฟล์ที่เลือกทั้งหมด"
        clearButton.target = self
        clearButton.action = #selector(clearAll)
        clearButton.isHidden = true

        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .tertiaryLabelColor

        recentButton.isBordered = false
        recentButton.imagePosition = .imageOnly
        recentButton.imageScaling = .scaleProportionallyDown
        recentButton.setAccessibilityLabel("ไฟล์ล่าสุด")
        recentButton.toolTip = "ไฟล์ล่าสุด"
        recentButton.target = self
        recentButton.action = #selector(showRecentMenu)
        recentButton.isHidden = true

        browseButton.bezelStyle = .rounded
        browseButton.controlSize = .large
        browseButton.font = .systemFont(ofSize: 13)
        browseButton.target = self
        browseButton.action = #selector(pick)
        browseButton.toolTip = "เปิดหน้าต่างเลือกไฟล์ใบรับรอง (เลือกได้หลายไฟล์)"

        buildButton.target = self
        buildButton.action = #selector(makeZip)
        buildButton.keyEquivalent = "\r"
        buildButton.isEnabled = false
        buildButton.toolTip = "สร้าง ZIP สำหรับติดตั้งผ่าน Magisk จากไฟล์ที่เลือก"

        card.onFiles = { [weak self] urls in self?.addCertificates(urls) }
        card.onBrowse = { [weak self] in self?.pick() }
        card.toolTip = "ลากไฟล์ใบรับรองมาวาง หรือคลิกเพื่อเลือกไฟล์"
        card.setAccessibilityLabel("พื้นที่รับไฟล์ใบรับรอง")
        let click = NSClickGestureRecognizer(target: self, action: #selector(pick))
        card.addGestureRecognizer(click)

        headerIcon.setAccessibilityElement(false)
        cardIcon.setAccessibilityElement(false)
        statusIcon.setAccessibilityElement(false)
        spinner.setAccessibilityLabel("กำลังตรวจ certificate และสร้าง ZIP")
    }

    // MARK: Layout

    private func installLayout(in content: NSView) {
        badge.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        headerSubtitle.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        rowsScrollView.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        recentButton.translatesAutoresizingMaskIntoConstraints = false
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
        content.addSubview(recentButton)
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

        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsScrollView.documentView = rowsStack
        card.addSubview(rowsScrollView)
        card.addSubview(clearButton)

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

            rowsScrollView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            rowsScrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            rowsScrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            rowsScrollView.trailingAnchor.constraint(
                equalTo: clearButton.leadingAnchor, constant: -8),
            rowsStack.topAnchor.constraint(equalTo: rowsScrollView.contentView.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: rowsScrollView.contentView.leadingAnchor),
            rowsStack.widthAnchor.constraint(equalTo: rowsScrollView.contentView.widthAnchor),

            clearButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            clearButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
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

            recentButton.centerYAnchor.constraint(equalTo: buildButton.centerYAnchor),
            recentButton.trailingAnchor.constraint(
                equalTo: browseButton.leadingAnchor, constant: -8),
            recentButton.widthAnchor.constraint(equalToConstant: 20),
            recentButton.heightAnchor.constraint(equalToConstant: 20),

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
        case .error:
            statusIcon.configure(symbol: "exclamationmark.triangle.fill", tint: .systemRed)
        }
    }

    private func setSuccessStatus(_ text: String) {
        statusLabel.stringValue = text
        statusIcon.configure(symbol: "checkmark.circle.fill", tint: .systemGreen)
    }

    private func setBusy(_ isBusy: Bool) {
        isBuilding = isBusy
        card.acceptsDrops = !isBusy
        card.alphaValue = isBusy ? 0.6 : 1
        browseButton.isEnabled = !isBusy
        recentButton.isEnabled = !isBusy
        buildButton.isEnabled = !isBusy && canBuild
        spinner.isHidden = !isBusy
        statusIcon.isHidden = isBusy
        if isBusy { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }

    /// Building is allowed once every selected certificate has finished
    /// validating and none of them failed.
    private var canBuild: Bool {
        !entries.isEmpty
            && entries.allSatisfy {
                if case .valid = $0.state { return true }
                return false
            }
    }

    private func refreshAggregateStatus() {
        guard !isBuilding else { return }
        guard !entries.isEmpty else {
            setStatus("เลือกไฟล์ใบรับรองเพื่อเริ่ม", kind: .idle)
            buildButton.isEnabled = false
            return
        }
        if entries.contains(where: {
            if case .validating = $0.state { return true }
            return false
        }
        ) {
            setStatus("กำลังตรวจสอบ certificate…", kind: .idle)
            buildButton.isEnabled = false
            return
        }
        let invalidCount = entries.filter {
            if case .invalid = $0.state { return true }
            return false
        }.count
        if invalidCount > 0 {
            let suffix = entries.count == 1 ? "" : " (\(invalidCount)/\(entries.count) ไฟล์)"
            setStatus("มีไฟล์ที่ตรวจไม่ผ่าน\(suffix) กรุณานำออกก่อนสร้าง ZIP", kind: .error)
            buildButton.isEnabled = false
            return
        }
        let text =
            entries.count == 1
            ? "พร้อมตรวจ CA:TRUE และสร้าง ZIP"
            : "พร้อมสร้าง ZIP รวม \(entries.count) certificate"
        setStatus(text, kind: .ready)
        buildButton.isEnabled = true
    }

    // MARK: Selection

    func addCertificates(_ urls: [URL]) {
        guard !isBuilding else { return }
        let existingPaths = Set(entries.map(\.url.path))
        var added = false
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                !isDirectory.boolValue, !existingPaths.contains(url.path)
            else { continue }
            appendEntry(for: url)
            added = true
        }
        guard added else { return }
        placeholderStack.isHidden = true
        rowsScrollView.isHidden = false
        clearButton.isHidden = false
        refreshAggregateStatus()
    }

    private func appendEntry(for url: URL) {
        let row = CertificateRowView()
        row.configure(
            icon: NSWorkspace.shared.icon(forFile: url.path),
            name: url.lastPathComponent,
            detail: "กำลังตรวจสอบ…",
            detailColor: .secondaryLabelColor)
        row.onRemove = { [weak self] in self?.removeCertificate(at: url) }
        row.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
        entries.append(CertificateEntry(url: url, state: .validating, row: row))
        inspect(url)
    }

    private func inspect(_ url: URL) {
        let builder = ModuleBuilder(resourcesURL: Bundle.main.resourceURL)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome: CertificateEntry.State
            do {
                outcome = .valid(try builder.inspect(certificate: url))
            } catch {
                outcome = .invalid(error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.applyInspection(outcome, to: url)
            }
        }
    }

    private func applyInspection(_ state: CertificateEntry.State, to url: URL) {
        guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
        entries[index].state = state
        let row = entries[index].row
        switch state {
        case .validating:
            row.configure(
                icon: NSWorkspace.shared.icon(forFile: url.path), name: url.lastPathComponent,
                detail: "กำลังตรวจสอบ…", detailColor: .secondaryLabelColor)
        case .valid(let preview):
            let expiry = preview.expired ? "หมดอายุแล้ว" : "หมดอายุ \(preview.notAfter)"
            row.configure(
                icon: NSWorkspace.shared.icon(forFile: url.path), name: url.lastPathComponent,
                detail: "\(preview.subject) · \(expiry)",
                detailColor: preview.expired ? .systemOrange : .secondaryLabelColor)
        case .invalid(let message):
            row.configure(
                icon: NSWorkspace.shared.icon(forFile: url.path), name: url.lastPathComponent,
                detail: message, detailColor: .systemRed)
        }
        refreshAggregateStatus()
    }

    private func removeCertificate(at url: URL) {
        guard !isBuilding, let index = entries.firstIndex(where: { $0.url == url }) else { return }
        entries[index].row.removeFromSuperview()
        entries.remove(at: index)
        if entries.isEmpty {
            placeholderStack.isHidden = false
            rowsScrollView.isHidden = true
            clearButton.isHidden = true
        }
        refreshAggregateStatus()
    }

    @objc func clearAll() {
        guard !isBuilding else { return }
        for entry in entries { entry.row.removeFromSuperview() }
        entries.removeAll()
        placeholderStack.isHidden = false
        rowsScrollView.isHidden = true
        clearButton.isHidden = true
        refreshAggregateStatus()
    }

    @objc func pick() {
        guard !isBuilding else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = "เลือกไฟล์ใบรับรอง"
        panel.prompt = "เลือก"
        panel.message = "เลือก Burp CA certificate แบบ DER หรือ PEM (เลือกได้หลายไฟล์)"
        if panel.runModal() == .OK { addCertificates(panel.urls) }
    }

    @objc func makeZip() {
        guard canBuild, !isBuilding else { return }
        let certificates = entries.map(\.url)
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
                try builder.build(certificates: certificates, destination: destination)
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
                    self.setSuccessStatus(
                        "สร้างสำเร็จ: \(destination.lastPathComponent)\nนำไปติดตั้งใน Magisk แล้ว reboot ด้วยตัวเอง"
                    )
                    self.rememberRecent(certificates)
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            }
        }
    }

    // MARK: Recent files

    private func rememberRecent(_ urls: [URL]) {
        var recent = UserDefaults.standard.stringArray(forKey: Self.recentDefaultsKey) ?? []
        for url in urls {
            recent.removeAll { $0 == url.path }
            recent.insert(url.path, at: 0)
        }
        if recent.count > Self.recentLimit { recent.removeLast(recent.count - Self.recentLimit) }
        UserDefaults.standard.set(recent, forKey: Self.recentDefaultsKey)
        refreshRecentButton()
    }

    private func refreshRecentButton() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.recentDefaultsKey) ?? []
        recentButton.isHidden = paths.isEmpty
    }

    @objc private func showRecentMenu() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.recentDefaultsKey) ?? []
        guard !paths.isEmpty else { return }
        let menu = NSMenu()
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let item = NSMenuItem(
                title: url.lastPathComponent, action: #selector(selectRecent(_:)), keyEquivalent: ""
            )
            item.target = self
            item.toolTip = path
            item.representedObject = url
            item.isEnabled = FileManager.default.fileExists(atPath: path)
            menu.addItem(item)
        }
        menu.popUp(
            positioning: nil, at: NSPoint(x: 0, y: recentButton.bounds.height),
            in: recentButton)
    }

    @objc private func selectRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        addCertificates([url])
    }
}
