# Changelog

## 1.1.0

- Redesign the macOS interface into a modern single-window dashboard with a light/dark indigo-lavender theme, live metric cards (`CA Status`, `Expiration`, `Subject Hash`, `ADB Device`), contextual status banner, and pastel Quick Actions tiles.
- Switch all UI copy, dialogs, tooltips, and validation errors to English.
- Focus on a streamlined single-certificate workflow with live subject, expiration, format/size, and Android hash (`<subject_hash_old>.0`) preview.
- Allow one-click **Install via ADB** directly after selecting a valid certificate (automatically builds into a temporary ZIP, pushes via `adb`, runs `magisk --install-module`, and cleans up). Re-checks connected devices when returning to the app window; reboot remains an explicit opt-in confirmation.
- Remember recently used certificates in the **Recent** menu.
- Prevent quitting mid-build or mid-ADB install, harden `adb devices` parsing and relative-path handling, and bundle only explicit `ModuleTemplate` files during builds.
- Removed the GitHub Actions CI workflow; run `./scripts/test.sh` and `./build.sh` locally instead.

## 1.0.1

- Split application lifetime, window/UI components and module packaging into focused Swift files.
- Extract a testable packaging service with disk-backed logs and bounded error details.
- Add integration checks, shared Swift formatting and contributor documentation.
- Update Xcode build to compile the new source structure; add a GitHub Actions CI workflow.
- Drop Intel (x86_64) support; `build.sh` now produces an arm64-only (Apple Silicon) app.

The app does not install certificates on macOS or deploy modules to Android automatically.
The release is ad hoc signed and is not Apple notarized. Android compatibility depends on
the device, ROM and Magisk configuration. Certificate pinning is not bypassed.

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
