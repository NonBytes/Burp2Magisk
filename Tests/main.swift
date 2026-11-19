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
            certificate: fixture.appendingPathComponent(name), destination: destination)
        _ = try command("/usr/bin/unzip", ["-tq", destination.path])
        let metadata = try command("/usr/bin/unzip", ["-p", destination.path, "module.prop"])
        try require(
            String(decoding: metadata, as: UTF8.self).contains("author=Burp2Magisk"),
            "Wrong module metadata")
        let hashData = try command(
            "/usr/bin/openssl",
            [
                "x509", "-in", fixture.appendingPathComponent("ca.pem").path,
                "-subject_hash_old", "-noout",
            ])
        let hash = String(decoding: hashData, as: UTF8.self).trimmingCharacters(
            in: .whitespacesAndNewlines)
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

    let existing = try Data(contentsOf: destination)
    for name in ["leaf.pem", "bundle.pem", "malformed.der", "missing.der"] {
        try expectFailure {
            try builder.build(
                certificate: fixture.appendingPathComponent(name), destination: destination)
        }
        let after = try Data(contentsOf: destination)
        try require(after == existing, "Failed conversion overwrote destination")
    }
    try expectFailure {
        try ModuleBuilder(resourcesURL: nil).build(
            certificate: fixture.appendingPathComponent("ca.pem"), destination: destination)
    }
    print(
        "PASS: DER/PEM, Unicode/quoted paths, ZIP contents, invalid/non-CA/bundle/missing input, missing resources, destination preservation"
    )
} catch {
    fputs("FAIL: \(error.localizedDescription)\n", stderr)
    exit(1)
}
