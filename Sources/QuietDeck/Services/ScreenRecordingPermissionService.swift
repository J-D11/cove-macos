import AppKit
import CoreGraphics
import Foundation
import OSLog

enum ScreenRecordingPermissionService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "ScreenRecording"
    )

    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        logger.info("Screen Recording request completed granted=\(granted, privacy: .public)")
        return granted
    }

    @discardableResult
    static func openSettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else {
            logger.error("Could not construct the Screen Recording settings URL")
            return false
        }

        let opened = NSWorkspace.shared.open(url)
        logger.info("Opened Screen Recording settings success=\(opened, privacy: .public)")
        return opened
    }
}
