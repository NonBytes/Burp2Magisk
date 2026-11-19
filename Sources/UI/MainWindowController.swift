import Cocoa
import UniformTypeIdentifiers

final class MainWindowController: NSObject {
    private var window: NSWindow!
    private var entry: CertificateEntry?
    private(set) var isBuilding = false
    private(set) var isInstalling = false
    private var isActive: Bool { isBuilding || isInstalling }
    private var pendingInstallDevices: [ADBInstaller.Device] = []
    private var adbFound = false
    private var adbChecked = false
    private var adbCheckGeneration = 0
    private var inspectionGeneration = 0
    private var windowObserver: NSObjectProtocol?

    deinit {
        if let windowObserver { NotificationCenter.default.removeObserver(windowObserver) }
    }

    private enum StatusKind { case idle, ready, error }

    /// The selected certificate and the state of its background preview.
    private struct CertificateEntry {
        let url: URL
        var state: State

        enum State {
            case validating
            case valid(ModuleBuilder.CertificatePreview)
            case invalid(String)
        }
    }

    private static let recentDefaultsKey = "RecentCertificatePaths"
    private static let recentLimit = 6

    // Header
    private let headerTitle = NSTextField(labelWithString: "Burp2Magisk")
    private let headerSubtitle = NSTextField(
        wrappingLabelWithString: "Convert a Burp CA certificate into a Magisk module for Android")
    private let statusPill = StatusPillView()

    // Certificate hero card
    private let heroCard = CardView()
    private let certificateMicro = Theme.microLabel("Certificate")
    private let dropZone = DropCardView()
    private let certificateRow = CertificateRowView()

    // Metric cards
    private let metricStack = NSStackView()
    private let caMetric = MetricCardView(title: "CA Status")
    private let expiryMetric = MetricCardView(title: "Expiration")
    private let hashMetric = MetricCardView(title: "Subject Hash")
    private let adbMetric = MetricCardView(title: "ADB Device")

    // Status banner
    private let banner = CardView()
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
    private let statusLabel = NSTextField(
        wrappingLabelWithString: "Select a certificate file to begin")
    private let ctaButton = AccentButton(title: "Choose File", height: 26, fontSize: 12)

    // Quick actions
    private let quickActionsLabel = NSTextField(labelWithString: "Quick Actions")
    private let tileStack = NSStackView()
    private let chooseTile = ActionTileView(
        symbol: "doc.badge.plus", tint: Theme.tileBlue, title: "Choose File")
    private let recentTile = ActionTileView(
        symbol: "clock.arrow.circlepath", tint: Theme.tileLavender, title: "Recent")
    private let zipTile = ActionTileView(
        symbol: "archivebox.fill", tint: Theme.tileMint, title: "Create ZIP")
    private let adbTile = ActionTileView(
        symbol: "cable.connector", tint: Theme.tilePeach, title: "Install ADB")

    // MARK: Launch

    func showWindow() {
        configureViews()
        let contentRect = NSRect(x: 0, y: 0, width: 760, height: 534)
        window = NSWindow(
            contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Burp2Magisk"
        window.subtitle = "Convert Burp CA to Magisk module"
        window.contentMinSize = NSSize(width: 720, height: 518)
        let backdrop = WindowBackdropView(frame: contentRect)
        window.contentView = backdrop
        installLayout(in: backdrop)
        NSApp.setActivationPolicy(.regular)
        window.center()
        window.initialFirstResponder = dropZone
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshStatus()
        checkForADBDevice()
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let self, !self.isActive else { return }
            self.checkForADBDevice()
        }
    }

    // MARK: View configuration

    private func configureViews() {
        headerTitle.font = .systemFont(ofSize: 20, weight: .bold)

        headerSubtitle.font = .systemFont(ofSize: 12)
        headerSubtitle.textColor = .secondaryLabelColor

        certificateRow.isHidden = true
        certificateRow.onRemove = { [weak self] in self?.clearSelection() }
        certificateRow.onReplace = { [weak self] in self?.pick() }

        dropZone.onFile = { [weak self] url in self?.selectCertificate(url) }
        dropZone.onBrowse = { [weak self] in self?.pick() }
        dropZone.setAccessibilityLabel("Certificate drop area")

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        quickActionsLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        banner.fillColor = Theme.bannerFill
        banner.borderColor = Theme.bannerBorder
        banner.cornerRadius = 12

        ctaButton.target = self
        ctaButton.keyEquivalent = "\r"
        ctaButton.toolTip = "Primary action for the current state"

        chooseTile.onTap = { [weak self] in self?.pick() }
        chooseTile.toolTip = "Choose a certificate file (.der or .pem)"
        recentTile.onTap = { [weak self] in self?.showRecentMenu() }
        recentTile.toolTip = "Recently used certificates"
        zipTile.onTap = { [weak self] in self?.makeZip() }
        zipTile.toolTip = "Build a Magisk module ZIP from the selected certificate"
        adbTile.onTap = { [weak self] in self?.installViaADB() }
        adbTile.toolTip =
            "Build and push the module ZIP over adb, then run magisk --install-module "
            + "(requires USB debugging and ADB root access on the device)"

        statusIcon.setAccessibilityElement(false)
        spinner.setAccessibilityLabel("Processing certificate")
        updateControlsForActivity()
    }

    // MARK: Layout

    private func installLayout(in content: NSView) {
        for view in [
            headerTitle, headerSubtitle, statusPill, heroCard, metricStack, banner,
            quickActionsLabel, tileStack,
        ] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        for view in [certificateMicro, dropZone, certificateRow] {
            view.translatesAutoresizingMaskIntoConstraints = false
            heroCard.addSubview(view)
        }
        for view in [statusIcon, spinner, statusLabel, ctaButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            banner.addSubview(view)
        }

        metricStack.orientation = .horizontal
        metricStack.alignment = .top
        metricStack.spacing = 12
        metricStack.distribution = .fillEqually
        for view in [caMetric, expiryMetric, hashMetric, adbMetric] {
            view.translatesAutoresizingMaskIntoConstraints = false
            metricStack.addArrangedSubview(view)
        }

        tileStack.orientation = .horizontal
        tileStack.spacing = 12
        tileStack.distribution = .fillEqually
        for view in [chooseTile, recentTile, zipTile, adbTile] {
            view.translatesAutoresizingMaskIntoConstraints = false
            tileStack.addArrangedSubview(view)
        }

        NSLayoutConstraint.activate([
            // Header
            headerTitle.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            headerTitle.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            headerSubtitle.leadingAnchor.constraint(equalTo: headerTitle.leadingAnchor),
            headerSubtitle.topAnchor.constraint(equalTo: headerTitle.bottomAnchor, constant: 2),
            headerSubtitle.trailingAnchor.constraint(
                lessThanOrEqualTo: statusPill.leadingAnchor, constant: -12),
            statusPill.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            statusPill.centerYAnchor.constraint(equalTo: headerTitle.centerYAnchor, constant: 1),

            // Certificate hero card
            heroCard.topAnchor.constraint(equalTo: headerSubtitle.bottomAnchor, constant: 18),
            heroCard.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            heroCard.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            heroCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 146),
            certificateMicro.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),
            certificateMicro.leadingAnchor.constraint(
                equalTo: heroCard.leadingAnchor, constant: 18),
            dropZone.topAnchor.constraint(equalTo: certificateMicro.bottomAnchor, constant: 10),
            dropZone.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 18),
            dropZone.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -18),
            dropZone.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -14),
            certificateRow.topAnchor.constraint(equalTo: dropZone.topAnchor),
            certificateRow.bottomAnchor.constraint(equalTo: dropZone.bottomAnchor),
            certificateRow.leadingAnchor.constraint(equalTo: dropZone.leadingAnchor),
            certificateRow.trailingAnchor.constraint(equalTo: dropZone.trailingAnchor),

            // Metric row
            metricStack.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 12),
            metricStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            metricStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            metricStack.heightAnchor.constraint(equalToConstant: 90),

            // Status banner
            banner.topAnchor.constraint(equalTo: metricStack.bottomAnchor, constant: 12),
            banner.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            banner.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            banner.heightAnchor.constraint(equalToConstant: 42),
            statusIcon.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            statusIcon.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 16),
            statusIcon.heightAnchor.constraint(equalToConstant: 16),
            spinner.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            spinner.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 16),
            spinner.heightAnchor.constraint(equalToConstant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            statusLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: ctaButton.leadingAnchor, constant: -12),
            ctaButton.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            ctaButton.centerYAnchor.constraint(equalTo: banner.centerYAnchor),

            // Quick actions
            quickActionsLabel.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 20),
            quickActionsLabel.leadingAnchor.constraint(
                equalTo: content.leadingAnchor, constant: 24),
            tileStack.topAnchor.constraint(equalTo: quickActionsLabel.bottomAnchor, constant: 10),
            tileStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            tileStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            tileStack.heightAnchor.constraint(equalToConstant: 84),
            tileStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22),
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
        updateControlsForActivity()
    }

    private var canBuild: Bool {
        if case .valid = entry?.state { return true }
        return false
    }

    private var hasRecentFiles: Bool {
        !(UserDefaults.standard.stringArray(forKey: Self.recentDefaultsKey) ?? []).isEmpty
    }

    private func updateControlsForActivity() {
        let active = isActive
        dropZone.acceptsDrops = !active
        dropZone.alphaValue = active ? 0.55 : 1
        certificateRow.setControlsEnabled(!active)
        chooseTile.isEnabled = !active
        recentTile.isEnabled = !active && hasRecentFiles
        zipTile.isEnabled = !active && canBuild
        adbTile.isEnabled = !active && canBuild && !pendingInstallDevices.isEmpty
        spinner.isHidden = !active
        statusIcon.isHidden = active
        if active { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
        refreshStatusPill()
        updateCTA()
    }

    /// Contextual quick action on the banner: installing over ADB whenever a
    /// device is connected, otherwise creating the ZIP, otherwise choosing a file.
    private func updateCTA() {
        guard !isActive else {
            ctaButton.isHidden = true
            return
        }
        ctaButton.isHidden = false
        ctaButton.target = self
        ctaButton.keyEquivalent = "\r"
        if canBuild, !pendingInstallDevices.isEmpty {
            ctaButton.title =
                pendingInstallDevices.count == 1
                ? "Install via ADB"
                : "Install via ADB (\(pendingInstallDevices.count))"
            ctaButton.action = #selector(installViaADB)
        } else if canBuild {
            ctaButton.title = "Create ZIP"
            ctaButton.action = #selector(makeZip)
        } else {
            ctaButton.title = "Choose File"
            ctaButton.action = #selector(pick)
        }
        ctaButton.invalidateIntrinsicContentSize()
    }

    private func refreshStatusPill() {
        if isActive {
            statusPill.configure(text: "Working…", tint: Theme.accent)
        } else if !adbChecked {
            statusPill.configure(text: "Checking…", tint: .secondaryLabelColor)
        } else if !adbFound {
            statusPill.configure(text: "No ADB", tint: .secondaryLabelColor)
        } else if pendingInstallDevices.isEmpty {
            statusPill.configure(text: "No Device", tint: .secondaryLabelColor)
        } else {
            let count = pendingInstallDevices.count
            statusPill.configure(
                text: count == 1 ? "1 Device" : "\(count) Devices", tint: .systemGreen)
        }
    }

    private func refreshCertificateMetrics() {
        guard let entry else {
            caMetric.configure(
                symbol: "doc.badge.questionmark", tint: .secondaryLabelColor,
                value: "Waiting", caption: "No certificate selected")
            expiryMetric.configure(
                symbol: "calendar", tint: .secondaryLabelColor,
                value: "—", caption: "Not inspected yet")
            hashMetric.configure(
                symbol: "number", tint: .secondaryLabelColor,
                value: "—", caption: "subject_hash_old")
            return
        }
        switch entry.state {
        case .validating:
            caMetric.configure(
                symbol: "hourglass", tint: Theme.accent,
                value: "Pending", caption: "Inspecting certificate…")
            expiryMetric.configure(
                symbol: "calendar", tint: .secondaryLabelColor,
                value: "—", caption: "Inspecting…")
            hashMetric.configure(
                symbol: "number", tint: .secondaryLabelColor,
                value: "—", caption: "Inspecting…")
        case .valid(let preview):
            caMetric.configure(
                symbol: "checkmark.seal.fill", tint: .systemGreen,
                value: "CA:TRUE", caption: preview.subject)
            expiryMetric.configure(
                symbol: "calendar",
                tint: preview.expired ? .systemOrange : Theme.accent,
                value: preview.notAfter,
                caption: preview.expired ? "Certificate has expired" : "Still valid")
            hashMetric.configure(
                symbol: "number", tint: Theme.accent,
                value: preview.hash, caption: "cacerts/\(preview.hash).0")
        case .invalid(let message):
            caMetric.configure(
                symbol: "xmark.octagon.fill", tint: .systemRed,
                value: "Invalid", caption: message)
            expiryMetric.configure(
                symbol: "calendar", tint: .secondaryLabelColor,
                value: "—", caption: "Not available")
            hashMetric.configure(
                symbol: "number", tint: .secondaryLabelColor,
                value: "—", caption: "Not available")
        }
    }

    private func applyADBState() {
        adbChecked = true
        if !adbFound {
            adbMetric.configure(
                symbol: "cable.connector", tint: .secondaryLabelColor,
                value: "No adb", caption: "Install Platform Tools")
        } else if pendingInstallDevices.isEmpty {
            adbMetric.configure(
                symbol: "cable.connector", tint: .secondaryLabelColor,
                value: "None", caption: "Connect a device over USB")
        } else {
            adbMetric.configure(
                symbol: "cable.connector", tint: .systemGreen,
                value: pendingInstallDevices.count == 1
                    ? pendingInstallDevices[0].serial
                    : "\(pendingInstallDevices.count) devices",
                caption: "Ready to install")
        }
        updateControlsForActivity()
    }

    private func refreshStatus() {
        guard !isActive else { return }
        refreshCertificateMetrics()
        guard let entry else {
            setStatus("Select a certificate file to begin", kind: .idle)
            updateControlsForActivity()
            return
        }
        switch entry.state {
        case .validating:
            setStatus("Inspecting certificate…", kind: .idle)
        case .invalid:
            setStatus("Certificate validation failed. Choose another file.", kind: .error)
        case .valid:
            setStatus("Ready to create Magisk ZIP or install via ADB", kind: .ready)
            checkForADBDevice()
        }
        updateControlsForActivity()
    }

    // MARK: Selection

    func selectCertificate(_ url: URL) {
        guard !isActive else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            !isDirectory.boolValue
        else { return }

        entry = CertificateEntry(url: url, state: .validating)
        dropZone.isHidden = true
        certificateRow.isHidden = false
        certificateRow.configure(
            name: url.lastPathComponent,
            meta: fileMetaBadge(for: url),
            subject: "Inspecting certificate…",
            subjectColor: .secondaryLabelColor,
            pathSummary: abbreviatedPath(for: url),
            badge: .neutral("Inspecting…"))
        refreshStatus()
        inspect(url)
    }

    private func fileMetaBadge(for url: URL) -> String {
        let ext = url.pathExtension.uppercased()
        let sizeText: String
        if let bytes = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        {
            sizeText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } else {
            sizeText = ""
        }
        switch (ext.isEmpty, sizeText.isEmpty) {
        case (false, false): return "\(ext) · \(sizeText)"
        case (false, true): return ext
        case (true, false): return sizeText
        case (true, true): return ""
        }
    }

    private func abbreviatedPath(for url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

    private func inspect(_ url: URL) {
        inspectionGeneration += 1
        let generation = inspectionGeneration
        let builder = ModuleBuilder(resourcesURL: Bundle.main.resourceURL)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let outcome: CertificateEntry.State
            do {
                outcome = .valid(try builder.inspect(certificate: url))
            } catch {
                outcome = .invalid(error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.applyInspection(outcome, to: url, generation: generation)
            }
        }
    }

    private func applyInspection(_ state: CertificateEntry.State, to url: URL, generation: Int) {
        guard inspectionGeneration == generation, entry?.url == url else { return }
        entry?.state = state
        let meta = fileMetaBadge(for: url)
        let path = abbreviatedPath(for: url)
        switch state {
        case .validating:
            certificateRow.configure(
                name: url.lastPathComponent, meta: meta,
                subject: "Inspecting certificate…", subjectColor: .secondaryLabelColor,
                pathSummary: path, badge: .neutral("Inspecting…"))
        case .valid(let preview):
            let target = preview.hash.isEmpty ? path : "\(path)  →  \(preview.hash).0"
            certificateRow.configure(
                name: url.lastPathComponent, meta: meta,
                subject: preview.subject,
                subjectColor: .secondaryLabelColor,
                pathSummary: target,
                badge: preview.expired ? .warning("Expired") : .valid("CA:TRUE"))
        case .invalid(let message):
            certificateRow.configure(
                name: url.lastPathComponent, meta: meta,
                subject: message, subjectColor: .systemRed,
                pathSummary: path, badge: .error("Invalid"))
        }
        refreshStatus()
    }

    @objc func clearSelection() {
        guard !isActive else { return }
        inspectionGeneration += 1
        entry = nil
        dropZone.isHidden = false
        certificateRow.isHidden = true
        refreshStatus()
    }

    @objc func pick() {
        guard !isActive else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Choose Certificate"
        panel.prompt = "Choose"
        panel.message = "Select a Burp CA certificate in DER or PEM format"
        if panel.runModal() == .OK, let url = panel.url { selectCertificate(url) }
    }

    @objc func makeZip() {
        guard canBuild, !isActive, let certificate = entry?.url else { return }
        let panel = NSSavePanel()
        panel.title = "Save Magisk ZIP"
        panel.prompt = "Save"
        panel.nameFieldStringValue = "BurpCA-Magisk.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        setBusy(true)
        setStatus("Validating certificate and building ZIP…", kind: .ready)
        let builder = ModuleBuilder(resourcesURL: Bundle.main.resourceURL)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let errorMessage: String?
            do {
                try builder.build(certificate: certificate, destination: destination)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            let message = errorMessage
            DispatchQueue.main.async {
                guard let self else { return }
                self.setBusy(false)
                if let message = message {
                    self.setStatus("Build failed", kind: .error)
                    let alert = NSAlert()
                    alert.messageText = "Failed to Create Magisk ZIP"
                    alert.informativeText = message
                    alert.alertStyle = .warning
                    alert.runModal()
                } else {
                    self.setSuccessStatus(
                        "Created \(destination.lastPathComponent)\nInstall it in Magisk and reboot your device"
                    )
                    self.rememberRecent(certificate)
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
                if self.canBuild { self.checkForADBDevice() }
            }
        }
    }

    // MARK: ADB install (opt-in; nothing here runs without an explicit click)

    /// Only reads `adb devices`; performs no action on the phone. Keeps the
    /// header pill, ADB metric card, and quick actions in sync with reality.
    private func checkForADBDevice() {
        adbCheckGeneration += 1
        let generation = adbCheckGeneration
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let adb = ADBInstaller.locateADB() else {
                DispatchQueue.main.async {
                    guard let self, self.adbCheckGeneration == generation else { return }
                    self.adbFound = false
                    self.pendingInstallDevices = []
                    self.applyADBState()
                }
                return
            }
            let devices = ADBInstaller.connectedDevices(adb: adb)
            DispatchQueue.main.async {
                guard let self, self.adbCheckGeneration == generation, !self.isActive
                else { return }
                self.adbFound = true
                self.pendingInstallDevices = devices
                self.applyADBState()
            }
        }
    }

    @objc private func installViaADB() {
        guard canBuild, !isActive else { return }
        guard pendingInstallDevices.count > 1 else {
            if let device = pendingInstallDevices.first {
                performADBInstall(device: device)
            }
            return
        }
        let menu = NSMenu()
        for device in pendingInstallDevices {
            let item = NSMenuItem(
                title: device.serial, action: #selector(selectADBDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.serial
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: ctaButton.bounds.height), in: ctaButton)
    }

    @objc private func selectADBDevice(_ sender: NSMenuItem) {
        guard let serial = sender.representedObject as? String,
            let device = pendingInstallDevices.first(where: { $0.serial == serial })
        else { return }
        performADBInstall(device: device)
    }

    private func performADBInstall(device: ADBInstaller.Device) {
        guard canBuild, !isActive, let certificate = entry?.url else { return }
        let builder = ModuleBuilder(resourcesURL: Bundle.main.resourceURL)
        isInstalling = true
        updateControlsForActivity()
        setStatus("Building and installing via ADB to \(device.serial)…", kind: .ready)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let errorMessage: String?
            do {
                let temporary = FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "Burp2Magisk-adb-zip-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(
                    at: temporary, withIntermediateDirectories: false)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let zipURL = temporary.appendingPathComponent("BurpCA-Magisk.zip")
                try builder.build(certificate: certificate, destination: zipURL)
                try ADBInstaller().install(zip: zipURL, onto: device)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            DispatchQueue.main.async {
                self?.finishADBInstall(
                    error: errorMessage, device: device, certificate: certificate)
            }
        }
    }

    private func finishADBInstall(
        error: String?, device: ADBInstaller.Device, certificate: URL
    ) {
        isInstalling = false
        updateControlsForActivity()
        if let error {
            setStatus("ADB installation failed", kind: .error)
            let alert = NSAlert()
            alert.messageText = "ADB Installation Failed"
            alert.informativeText = error
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        rememberRecent(certificate)
        setSuccessStatus("Installed on \(device.serial)")
        let alert = NSAlert()
        alert.messageText = "Module Installed"
        alert.informativeText =
            "The module has been installed on \(device.serial). Reboot the device to apply changes."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reboot Now")
        alert.addButton(withTitle: "Close")
        if alert.runModal() == .alertFirstButtonReturn {
            rebootDevice(device)
        }
    }

    private func rebootDevice(_ device: ADBInstaller.Device) {
        DispatchQueue.global(qos: .userInitiated).async {
            let errorMessage: String?
            do {
                try ADBInstaller().reboot(device)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            guard let message = errorMessage else { return }
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Reboot Failed"
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    // MARK: Recent files

    private func rememberRecent(_ url: URL) {
        var recent = UserDefaults.standard.stringArray(forKey: Self.recentDefaultsKey) ?? []
        recent.removeAll { $0 == url.path }
        recent.insert(url.path, at: 0)
        if recent.count > Self.recentLimit { recent.removeLast(recent.count - Self.recentLimit) }
        UserDefaults.standard.set(recent, forKey: Self.recentDefaultsKey)
        updateControlsForActivity()
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
            positioning: nil, at: NSPoint(x: 0, y: recentTile.bounds.height), in: recentTile)
    }

    @objc private func selectRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        selectCertificate(url)
    }
}

// MARK: - WindowBackdropView

/// Fills the window with the theme canvas color; redrawn on appearance changes.
private final class WindowBackdropView: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Theme.windowBackground.setFill()
        bounds.fill()
    }
}
