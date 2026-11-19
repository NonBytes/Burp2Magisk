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
            certificate: fixture.appendingPathComponent(name), destination: destination)
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

    // Preview/inspection never writes any file and reports the same subject hash.
    let hash1 = try subjectHash(fixture.appendingPathComponent("ca.pem"))
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

    // ADB device parsing never shells out; verify it accepts only authorized, online devices.
    let devices = ADBInstaller.parseDevices(
        """
        * daemon not running; starting now at tcp:5037
        * daemon started successfully
        List of devices attached
        emulator-5554\tdevice\r
        1234567890ABCDEF\tunauthorized
        PQR\toffline

        """)
    try require(devices == [ADBInstaller.Device(serial: "emulator-5554")], "Wrong device parsing")
    try require(
        ADBInstaller.parseDevices("List of devices attached\n").isEmpty, "Expected no devices")

    print(
        "PASS: DER/PEM, Unicode/quoted paths, ZIP contents, "
            + "invalid/non-CA/bundle/missing input, missing resources, "
            + "destination preservation, certificate preview, ADB device parsing"
    )
} catch {
    fputs("FAIL: \(error.localizedDescription)\n", stderr)
    exit(1)
}
