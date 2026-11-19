import Cocoa

/// Owns application lifetime; the window controller owns presentation.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = MainWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController.showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        (windowController.isBuilding || windowController.isInstalling)
            ? .terminateCancel : .terminateNow
    }
}
