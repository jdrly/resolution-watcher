import AppKit
import ApplicationServices
import Foundation

final class WindowPositioner {
    private let logger: Logger
    private var promptedForAccessibility = false
    private var loggedMissingAccessibility = false

    init(logger: Logger) {
        self.logger = logger
    }

    func positionWindows(bundleIdentifier: String) -> Bool {
        guard isAccessibilityTrusted() else {
            return false
        }

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            app.bundleIdentifier == bundleIdentifier && !app.isTerminated
        }
        guard let screen = NSScreen.main else {
            logger.log("main screen missing; cannot position \(bundleIdentifier) window")
            return false
        }

        var positionedAnyWindow = false
        for app in apps {
            if positionWindows(app: app, screenFrame: screen.frame) {
                positionedAnyWindow = true
            }
        }

        return positionedAnyWindow
    }

    private func isAccessibilityTrusted() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if !promptedForAccessibility {
            promptedForAccessibility = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        if !loggedMissingAccessibility {
            loggedMissingAccessibility = true
            logger.log("accessibility permission missing; cannot position watched app window")
        }

        return false
    }

    private func positionWindows(app: NSRunningApplication, screenFrame: CGRect) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )

        guard windowsResult == .success, let windows = windowsValue as? [AXUIElement], !windows.isEmpty else {
            return false
        }

        var movedAnyWindow = false
        for window in windows {
            if positionWindow(window, screenFrame: screenFrame) {
                movedAnyWindow = true
            }
        }

        if movedAnyWindow {
            logger.log("positioned \(app.bundleIdentifier ?? String(app.processIdentifier)) window at screen origin")
        }

        return movedAnyWindow
    }

    private func positionWindow(_ window: AXUIElement, screenFrame: CGRect) -> Bool {
        var position = CGPoint(x: screenFrame.minX, y: screenFrame.minY)
        var size = CGSize(width: screenFrame.width, height: screenFrame.height)

        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }

        _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue) == .success
    }
}
