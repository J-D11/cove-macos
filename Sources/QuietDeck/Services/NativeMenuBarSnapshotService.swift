import AppKit
import CoreGraphics
import Foundation
import OSLog
import ScreenCaptureKit

@MainActor
final class NativeMenuBarSnapshotService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "NativeAppearance"
    )

    func snapshots(for items: [MenuBarItemModel]) async -> [String: NSImage]? {
        guard ScreenRecordingPermissionService.isGranted,
              let screen = targetScreen(),
              let displayID = displayID(for: screen) else {
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                logger.warning("Could not resolve the target display for native appearance")
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            if #available(macOS 14.2, *) {
                filter.includeMenuBar = true
            }

            let scale = max(screen.backingScaleFactor, 1)
            let captureHeight = min(max(screen.safeAreaInsets.top, 32), 48)
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(display.width),
                height: captureHeight
            )
            configuration.width = Int(CGFloat(display.width) * scale)
            configuration.height = Int(captureHeight * scale)
            configuration.showsCursor = false
            configuration.scalesToFit = true

            let menuBarImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let snapshots = cropSnapshots(
                from: menuBarImage,
                items: items,
                screen: screen,
                display: display,
                scale: scale,
                captureHeight: captureHeight
            )
            logger.debug("Captured native appearance for \(snapshots.count, privacy: .public) items")
            return snapshots
        } catch {
            logger.error("Native appearance capture failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func cropSnapshots(
        from image: CGImage,
        items: [MenuBarItemModel],
        screen: NSScreen,
        display: SCDisplay,
        scale: CGFloat,
        captureHeight: CGFloat
    ) -> [String: NSImage] {
        var snapshots: [String: NSImage] = [:]

        for item in items {
            guard let frame = item.accessibilityFrame,
                  frame.width > 1,
                  frame.height > 1 else {
                continue
            }

            let localFrame = CGRect(
                x: frame.minX - display.frame.minX,
                y: frame.minY - display.frame.minY,
                width: frame.width,
                height: frame.height
            )
            guard localFrame.minX > 10,
                  localFrame.maxX <= CGFloat(display.width),
                  localFrame.minY >= 0,
                  localFrame.maxY <= captureHeight else {
                continue
            }

            let paddedFrame = localFrame
                .insetBy(dx: -2, dy: 0)
                .intersection(CGRect(x: 0, y: 0, width: CGFloat(display.width), height: captureHeight))
            let pixelFrame = CGRect(
                x: paddedFrame.minX * scale,
                y: paddedFrame.minY * scale,
                width: paddedFrame.width * scale,
                height: paddedFrame.height * scale
            ).integral
            guard let crop = image.cropping(to: pixelFrame) else { continue }

            let snapshot = NSImage(
                cgImage: crop,
                size: NSSize(width: paddedFrame.width, height: paddedFrame.height)
            )
            snapshot.isTemplate = false
            snapshots[item.id] = snapshot
        }

        return snapshots
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            lhs.safeAreaInsets.top < rhs.safeAreaInsets.top
        } ?? NSScreen.main
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
