import Foundation

/// Synchronous packaging boundary. Call on a worker queue, never the UI thread.
/// Resources can be injected by integration tests without launching AppKit.
struct ModuleBuilder {
    let resourcesURL: URL?

    enum BuildError: LocalizedError {
        case missingResources
        case packagingFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingResources:
                return "ไม่พบไฟล์สำหรับสร้าง module ภายในแอป กรุณา build หรือติดตั้งแอปใหม่"
            case .packagingFailed(let detail):
                return detail.isEmpty ? "สร้าง Magisk ZIP ไม่สำเร็จ" : detail
            }
        }
    }

    func build(certificate: URL, destination: URL) throws {
        guard let resourcesURL,
            FileManager.default.isReadableFile(
                atPath: resourcesURL.appendingPathComponent("der-to-magisk.sh").path
            )
        else { throw BuildError.missingResources }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("Burp2Magisk-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }

        // A log file avoids pipe-buffer deadlocks and unbounded in-memory logs.
        let logURL = temporary.appendingPathComponent("build.log")
        try Data().write(to: logURL)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }

        let output = temporary.appendingPathComponent("result", isDirectory: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            resourcesURL.appendingPathComponent("der-to-magisk.sh").path,
            certificate.path,
            output.path,
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let reader = try FileHandle(forReadingFrom: logURL)
            defer { try? reader.close() }
            let size = try reader.seekToEnd()
            try reader.seek(toOffset: size > 16_384 ? size - 16_384 : 0)
            let detail = String(decoding: try reader.readToEnd() ?? Data(), as: UTF8.self)
            throw BuildError.packagingFailed(detail)
        }

        // The save panel owns overwrite approval. Atomic writing keeps a previous
        // destination intact if conversion or reading the new archive fails.
        let archive = try Data(
            contentsOf: output.appendingPathComponent("BurpCA-Magisk.zip"),
            options: .mappedIfSafe
        )
        try archive.write(to: destination, options: .atomic)
    }
}
