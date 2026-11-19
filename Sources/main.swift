import Cocoa
import UniformTypeIdentifiers

final class DropView: NSView {
    var onFile: ((URL) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], files.count == 1 else { return false }
        onFile?(files[0]); return true
    }
}

final class App: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var selected: URL?
    var busy = false
    let label = NSTextField(wrappingLabelWithString: "ลากไฟล์ DER / PEM มาวางที่นี่\nหรือกดเลือกไฟล์")
    let status = NSTextField(wrappingLabelWithString: "สร้าง ZIP สำหรับติดตั้งผ่าน Magisk บน Android")
    let choose = NSButton(title: "เลือกไฟล์…", target: nil, action: nil)
    let build = NSButton(title: "สร้าง Magisk ZIP…", target: nil, action: nil)
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 290), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Burp2Magisk"
        let view = DropView(frame: NSRect(x: 0, y: 0, width: 540, height: 290))
        view.onFile = { [weak self] url in self?.select(url) }
        window.contentView = view
        label.frame = NSRect(x: 28, y: 166, width: 484, height: 90)
        label.font = .systemFont(ofSize: 19)
        label.alignment = .center
        status.frame = NSRect(x: 28, y: 28, width: 484, height: 62)
        status.alignment = .center
        choose.frame = NSRect(x: 70, y: 110, width: 180, height: 34)
        build.frame = NSRect(x: 280, y: 110, width: 190, height: 34)
        choose.bezelStyle = .rounded; build.bezelStyle = .rounded
        choose.target = self; choose.action = #selector(pick)
        build.target = self; build.action = #selector(makeZip)
        build.isEnabled = false
        [label, status, choose, build].forEach { view.addSubview($0) }
        NSApp.setActivationPolicy(.regular)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { busy ? .terminateCancel : .terminateNow }
    func select(_ url: URL) {
        guard !busy else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return }
        selected = url; label.stringValue = url.lastPathComponent
        status.stringValue = "พร้อมตรวจ CA:TRUE และสร้าง ZIP"; build.isEnabled = true
    }
    @objc func pick() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.message = "เลือก Burp CA certificate แบบ DER หรือ PEM"
        if panel.runModal() == .OK, let url = panel.url { select(url) }
    }
    @objc func makeZip() {
        guard let input = selected, !busy else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "BurpCA-Magisk.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        busy = true; choose.isEnabled = false; build.isEnabled = false
        status.stringValue = "กำลังตรวจ certificate และสร้าง ZIP…"
        let resources = Bundle.main.resourceURL!
        DispatchQueue.global(qos: .userInitiated).async {
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            var errorMessage: String?
            do {
                try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let out = temporary.appendingPathComponent("result")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [resources.appendingPathComponent("der-to-magisk.sh").path, input.path, out.path]
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                process.environment = env
                let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw NSError(domain: "Builder", code: 1, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "สร้าง ZIP ไม่สำเร็จ"])
                }
                // Atomic write replaces a destination only after the save dialog approved it.
                let archive = try Data(contentsOf: out.appendingPathComponent("BurpCA-Magisk.zip"))
                try archive.write(to: destination, options: .atomic)
            } catch { errorMessage = error.localizedDescription }
            let message = errorMessage
            DispatchQueue.main.async {
                self.busy = false; self.choose.isEnabled = true; self.build.isEnabled = true
                if let message = message {
                    self.status.stringValue = "สร้างไม่สำเร็จ"
                    let alert = NSAlert(); alert.messageText = "สร้าง Magisk ZIP ไม่สำเร็จ"
                    alert.informativeText = message; alert.runModal()
                } else {
                    self.status.stringValue = "สร้างสำเร็จ: \(destination.lastPathComponent)\nนำไปติดตั้งใน Magisk แล้ว reboot ด้วยตัวเอง"
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            }
        }
    }
}
let application = NSApplication.shared
let delegate = App()
application.delegate = delegate
application.run()
