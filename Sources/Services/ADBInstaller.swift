import Foundation

/// Optional "install to a connected Android device" integration. Detecting a
/// device only reads `adb devices`, which performs no action on the phone.
/// Pushing and installing a module, and rebooting, happen only when the
/// person explicitly asks for each of those steps; nothing here runs on its
/// own.
struct ADBInstaller {
    struct Device: Equatable {
        let serial: String
    }

    enum InstallError: LocalizedError {
        case adbNotFound
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .adbNotFound:
                return "ไม่พบ adb กรุณาติดตั้ง Android SDK Platform Tools และตั้งค่า PATH"
            case .commandFailed(let detail):
                return detail.isEmpty ? "ติดตั้งผ่าน ADB ไม่สำเร็จ" : detail
            }
        }
    }

    /// Common Platform Tools install locations, then anything already on PATH.
    static func locateADB() -> URL? {
        for path in [
            "/opt/homebrew/bin/adb", "/usr/local/bin/adb",
            NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb",
        ] where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["adb"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice
        guard (try? which.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        which.waitUntilExit()
        guard which.terminationStatus == 0 else { return nil }
        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    /// Lists authorized, online devices only; one still pending the phone's
    /// own "Allow USB debugging" prompt, or disconnected mid-transfer, could
    /// not be pushed to or installed on anyway.
    static func connectedDevices(adb: URL) -> [Device] {
        let process = Process()
        process.executableURL = adb
        process.arguments = ["devices"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }
        return parseDevices(String(decoding: data, as: UTF8.self))
    }

    /// Exposed separately so the parser can be tested without a real adb or device.
    static func parseDevices(_ output: String) -> [Device] {
        output.split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count == 2, parts[1] == "device" else { return nil }
            return Device(serial: String(parts[0]))
        }
    }

    /// Pushes the ZIP to the device and installs it with Magisk's own CLI.
    /// Never reboots; that stays the person's own explicit next step.
    func install(zip: URL, onto device: Device) throws {
        guard let adb = Self.locateADB() else { throw InstallError.adbNotFound }
        let remotePath = "/data/local/tmp/b2m-\(UUID().uuidString.prefix(8)).zip"
        defer { _ = try? run(adb, ["-s", device.serial, "shell", "rm", "-f", remotePath]) }

        try run(adb, ["-s", device.serial, "push", zip.path, remotePath])
        try run(
            adb,
            ["-s", device.serial, "shell", "su -c \"magisk --install-module \(remotePath)\""])
    }

    func reboot(_ device: Device) throws {
        guard let adb = Self.locateADB() else { throw InstallError.adbNotFound }
        try run(adb, ["-s", device.serial, "reboot"])
    }

    @discardableResult
    private func run(_ adb: URL, _ arguments: [String]) throws -> String {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("Burp2Magisk-adb-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let logURL = temporary.appendingPathComponent("adb.log")
        try Data().write(to: logURL)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }

        let process = Process()
        process.executableURL = adb
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        try process.run()
        process.waitUntilExit()

        let reader = try FileHandle(forReadingFrom: logURL)
        defer { try? reader.close() }
        let size = try reader.seekToEnd()
        try reader.seek(toOffset: size > 8_192 ? size - 8_192 : 0)
        let output = String(decoding: try reader.readToEnd() ?? Data(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else { throw InstallError.commandFailed(output) }
        return output
    }
}
