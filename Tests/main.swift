import Foundation

// Integration checks exercise the real bundled shell backend, without AppKit.
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw NSError(
            domain: "IntegrationTests", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message])
    }
}

func command(_ executable: String, _ arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    try require(process.terminationStatus == 0, "Command failed: \(executable)")
    return data
}

func subjectHash(_ pem: URL) throws -> String {
    let data = try command(
        "/usr/bin/openssl", ["x509", "-in", pem.path, "-subject_hash_old", "-noout"])
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

func expectFailure(_ action: () throws -> Void) throws {
    do { try action() } catch { return }
    try require(false, "Expected an error")
}

do {
    let resources = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let fixture = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    let builder = ModuleBuilder(resourcesURL: resources)
    let destination = fixture.appendingPathComponent("output archive.zip")

    for name in ["ca.pem", "ca.der", "ใบรับรอง 'quoted' $name.der"] {
        try builder.build(
            certificates: [fixture.appendingPathComponent(name)], destination: destination)
        _ = try command("/usr/bin/unzip", ["-tq", destination.path])
        let metadata = try command("/usr/bin/unzip", ["-p", destination.path, "module.prop"])
        try require(
            String(decoding: metadata, as: UTF8.self).contains("author=Burp2Magisk"),
            "Wrong module metadata")
        let hash = try subjectHash(fixture.appendingPathComponent("ca.pem"))
        let cert = try command(
            "/usr/bin/unzip", ["-p", destination.path, "system/etc/security/cacerts/\(hash).0"])
        let canonical = try command(
            "/usr/bin/openssl",
            [
                "x509", "-in", fixture.appendingPathComponent("ca.pem").path,
                "-outform", "PEM",
            ])
        try require(cert == canonical, "Archive certificate changed")
    }

    // Multiple certificates bundle into one ZIP, each under its own subject hash.
    let multiDestination = fixture.appendingPathComponent("multi.zip")
    try builder.build(
        certificates: [
            fixture.appendingPathComponent("ca.pem"), fixture.appendingPathComponent("ca2.pem"),
        ], destination: multiDestination)
    let hash1 = try subjectHash(fixture.appendingPathComponent("ca.pem"))
    let hash2 = try subjectHash(fixture.appendingPathComponent("ca2.pem"))
    try require(hash1 != hash2, "Fixture certificates must hash differently")
    _ = try command(
        "/usr/bin/unzip", ["-p", multiDestination.path, "system/etc/security/cacerts/\(hash1).0"])
    _ = try command(
        "/usr/bin/unzip", ["-p", multiDestination.path, "system/etc/security/cacerts/\(hash2).0"])
    let multiMetadata = try command("/usr/bin/unzip", ["-p", multiDestination.path, "module.prop"])
    try require(
        String(decoding: multiMetadata, as: UTF8.self).contains("2 certs"),
        "module.prop should mention the certificate count")

    // The same certificate supplied twice (even in different encodings) still
    // produces exactly one entry, rather than a duplicate-filename failure.
    let dedupedDestination = fixture.appendingPathComponent("deduped.zip")
    try builder.build(
        certificates: [
            fixture.appendingPathComponent("ca.pem"), fixture.appendingPathComponent("ca.der"),
        ], destination: dedupedDestination)
    let dedupedListing = try command("/usr/bin/unzip", ["-l", dedupedDestination.path])
    let dedupedCertEntries =
        String(decoding: dedupedListing, as: UTF8.self)
        .split(separator: "\n")
        .filter { $0.contains("cacerts/") && $0.hasSuffix(".0") }
    try require(
        dedupedCertEntries.count == 1,
        "Identical certificate supplied twice should not duplicate in the archive")

    // A batch containing any invalid certificate fails entirely and writes nothing.
    try expectFailure {
        try builder.build(
            certificates: [
                fixture.appendingPathComponent("ca.pem"),
                fixture.appendingPathComponent("leaf.pem"),
            ],
            destination: fixture.appendingPathComponent("should-not-exist.zip"))
    }
    try require(
        !FileManager.default.fileExists(
            atPath: fixture.appendingPathComponent("should-not-exist.zip").path),
        "A failed multi-certificate build must not create a partial destination")

    try expectFailure {
        try builder.build(certificates: [], destination: multiDestination)
    }

    let existing = try Data(contentsOf: destination)
    for name in ["leaf.pem", "bundle.pem", "malformed.der", "missing.der"] {
        try expectFailure {
            try builder.build(
                certificates: [fixture.appendingPathComponent(name)], destination: destination)
        }
        let after = try Data(contentsOf: destination)
        try require(after == existing, "Failed conversion overwrote destination")
    }
    try expectFailure {
        try ModuleBuilder(resourcesURL: nil).build(
            certificates: [fixture.appendingPathComponent("ca.pem")], destination: destination)
    }

    // Preview/inspection never writes any file and reports the same subject hash.
    let preview = try builder.inspect(certificate: fixture.appendingPathComponent("ca.pem"))
    try require(preview.hash == hash1, "Preview hash should match subject_hash_old")
    try require(preview.subject.contains("CN="), "Preview subject should include the CN")
    try require(!preview.expired, "Fixture CA certificate should not be expired")

    try expectFailure {
        _ = try builder.inspect(certificate: fixture.appendingPathComponent("leaf.pem"))
    }
    try expectFailure {
        _ = try builder.inspect(certificate: fixture.appendingPathComponent("malformed.der"))
    }
    try expectFailure {
        _ = try ModuleBuilder(resourcesURL: nil).inspect(
            certificate: fixture.appendingPathComponent("ca.pem"))
    }

    print(
        "PASS: DER/PEM, Unicode/quoted paths, ZIP contents, multi-certificate bundling, "
            + "duplicate dedup, invalid/non-CA/bundle/missing input, missing resources, "
            + "destination preservation, certificate preview"
    )
} catch {
    fputs("FAIL: \(error.localizedDescription)\n", stderr)
    exit(1)
}
