# Developing Burp2Magisk

Requires macOS 12+ and Xcode Command Line Tools. No package manager or external
dependencies are needed. Open `Burp2Magisk.xcodeproj`, select **Burp2Magisk → My Mac**
and run, or use `bash build.sh` for an arm64 (Apple Silicon) app and distribution ZIP in `dist/`.

## Where to change things

| Area | Location |
| --- | --- |
| Application lifetime and termination guard | `Sources/App/AppDelegate.swift` |
| Window layout, file selection and presentation state | `Sources/UI/MainWindowController.swift` |
| Shared colors | `Sources/UI/Theme.swift` |
| Drag/drop card, per-certificate row and buttons | `Sources/UI/Components/` |
| Background conversion, preview and atomic ZIP export | `Sources/Services/ModuleBuilder.swift` |
| DER/PEM validation and subject hash | `Resources/burp-ca-to-android.sh` |
| Read-only certificate preview (subject/expiry/hash) | `Resources/burp-ca-info.sh` |
| Magisk ZIP assembly for one or more certificates | `Resources/der-to-magisk.sh` |
| Android boot-time overlays | `Resources/ModuleTemplate/` |
| Reproducible app artwork | `scripts/IconGenerator.swift` |

`main.swift` only starts AppKit. `AppDelegate` owns the window controller. The
controller presents system file dialogs, runs `ModuleBuilder` on a worker queue
and applies results on the main queue. The builder accepts an injected resources
directory so tests can exercise packaging without opening a window. It uses
argument arrays rather than interpolating paths into shell command text.

The shell scripts remain the single implementation of certificate conversion,
preview and ZIP assembly. Do not duplicate this logic in the GUI. Temporary
directories are unique to each build. Packaging failures must preserve an
existing output. Backend logs are written to disk; only their final bytes are
read on failure. `der-to-magisk.sh` accepts one output directory followed by
one or more certificate paths; the module id is derived from the sorted set
of subject hashes so rebuilding the same certificate set keeps the same id,
while a different set gets its own. `burp-ca-info.sh` never writes a file; it
only validates and prints a certificate's subject, expiry and subject hash so
the GUI can preview a selection before building.

## Checks before a contribution

```bash
bash scripts/test.sh
xcrun swift-format lint --strict --recursive Sources scripts Tests
bash build.sh
```

The integration suite creates disposable test certificates, checks DER/PEM and
quoted/Unicode filenames, examines the actual certificate in the ZIP, bundles
multiple certificates into one ZIP, dedupes an identical certificate supplied
twice, rejects non-CA/malformed/bundled input (including when mixed into a
multi-certificate batch), verifies failed conversions preserve a prior
destination, and checks certificate preview. Fixtures and private keys are
removed automatically and are never committed. These tests do not install a
module or prove Android boot compatibility.

Format Swift with `xcrun swift-format format --in-place --recursive Sources scripts Tests`.
The repository's `.swift-format` uses four spaces and a 100-column target. Keep
files focused on one responsibility and document behavior or constraints, rather
than narrating syntax. Do not add dependencies for routine AppKit functionality.

When adding Swift files, add them to the Xcode Sources build phase too;
`build.sh` discovers all files under `Sources/` automatically. Runtime assets
must be included in both Xcode Resources and `build.sh`.

## Artwork and releases

```bash
mkdir -p work/module-cache
swiftc scripts/IconGenerator.swift -module-cache-path work/module-cache -o work/IconGenerator
work/IconGenerator Resources
iconutil -c icns work/Burp2Magisk.iconset -o Resources/Burp2Magisk.icns
```

Generated artwork is versioned; build outputs and local credentials are not.
Update `CFBundleShortVersionString`, `CFBundleVersion`, and `CHANGELOG.md` for a
new release. Rebuild, verify the arm64 binary and code signature, then publish
a new tag and assets. Never replace an old release ZIP with different contents.
