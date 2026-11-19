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
                return
                    "Module build resources are missing from the app bundle. Rebuild or reinstall the app."
            case .packagingFailed(let detail):
                return detail.isEmpty ? "Failed to create Magisk ZIP." : detail
            }
        }
    }

    enum InspectError: LocalizedError {
        case missingResources
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .missingResources:
                return
                    "Certificate inspection resources are missing from the app bundle. Rebuild or reinstall the app."
            case .invalid(let detail):
                return detail.isEmpty ? "Unable to inspect this certificate." : detail
            }
        }
    }

    struct CertificatePreview {
        let subject: String
        let notAfter: String
        let hash: String
        let expired: Bool
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
            output.path,
            certificate.path,
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
            throw BuildError.packagingFailed(
                try readTail(logURL, limit: 16_384).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        // The save panel owns overwrite approval. Atomic writing keeps a previous
        // destination intact if conversion or reading the new archive fails.
        let archive = try Data(
            contentsOf: output.appendingPathComponent("BurpCA-Magisk.zip"),
            options: .mappedIfSafe
        )
        try archive.write(to: destination, options: .atomic)
    }

    /// Read-only validation and summary of one certificate; writes nothing to disk.
    func inspect(certificate: URL) throws -> CertificatePreview {
        guard let resourcesURL,
            FileManager.default.isReadableFile(
                atPath: resourcesURL.appendingPathComponent("burp-ca-info.sh").path
            )
        else { throw InspectError.missingResources }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("Burp2Magisk-inspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let outputURL = temporary.appendingPathComponent("stdout.log")
        let errorURL = temporary.appendingPathComponent("stderr.log")
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            resourcesURL.appendingPathComponent("burp-ca-info.sh").path, certificate.path,
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw InspectError.invalid(
                try readTail(errorURL, limit: 4_096).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        var fields: [String: String] = [:]
        for line in try readTail(outputURL, limit: 4_096).split(separator: "\n") {
            guard let separator = line.firstIndex(of: "=") else { continue }
            fields[String(line[..<separator])] = String(line[line.index(after: separator)...])
        }
        return CertificatePreview(
            subject: (fields["SUBJECT"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            notAfter: (fields["NOT_AFTER"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            hash: (fields["HASH"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            expired: fields["EXPIRED"] == "yes")
    }

    private func readTail(_ url: URL, limit: UInt64) throws -> String {
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        let size = try reader.seekToEnd()
        try reader.seek(toOffset: size > limit ? size - limit : 0)
        return String(decoding: try reader.readToEnd() ?? Data(), as: UTF8.self)
    }
}
