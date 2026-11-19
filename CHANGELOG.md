# Changelog

## Unreleased

- Split application lifetime, window/UI components and module packaging into focused Swift files.
- Extract a testable packaging service with disk-backed logs and bounded error details.
- Add integration checks, shared Swift formatting and contributor documentation.
- Update Universal and Xcode builds to compile the new source structure.

## 1.0.0

- Native macOS Swift/AppKit interface in Thai, with certificate drag and drop.
- Converts DER/PEM CA certificates to PEM and Android legacy subject-hash filenames.
- Requires Basic Constraints CA:TRUE; rejects malformed files and certificate bundles.
- Exports a Magisk module ZIP with the project's own system/Conscrypt overlay scripts.
- Orange and green Burp2Magisk icon, including reproducible Swift artwork generator.
- Universal macOS app for Intel and Apple Silicon; macOS 12 or newer.

The app does not install certificates on macOS or deploy modules to Android automatically.
The release is ad hoc signed and is not Apple notarized. Android compatibility depends on
the device, ROM and Magisk configuration. Certificate pinning is not bypassed.
