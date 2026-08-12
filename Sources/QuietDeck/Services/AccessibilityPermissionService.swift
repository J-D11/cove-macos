import AppKit
import ApplicationServices
import Foundation
import OSLog

enum AccessibilityPermissionService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "Accessibility"
    )

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility request completed trusted=\(trusted, privacy: .public)")
        return trusted
    }

    @discardableResult
    static func openSettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            logger.error("Could not construct the Accessibility settings URL")
            return false
        }

        let opened = NSWorkspace.shared.open(url)
        logger.info("Opened Accessibility settings success=\(opened, privacy: .public)")
        return opened
    }
}
