import CoreGraphics
import Foundation

enum MenuBarTransientWindowMonitor {
    static func transientWindowIDs(ownerPID: pid_t) -> Set<CGWindowID> {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return transientWindowIDs(from: windowInfo, ownerPID: ownerPID)
    }

    static func transientWindowIDs(
        from windowInfo: [[String: Any]],
        ownerPID: pid_t
    ) -> Set<CGWindowID> {
        Set(windowInfo.compactMap { info in
            guard let processNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
                  pid_t(processNumber.intValue) == ownerPID,
                  let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
                  layerNumber.intValue > 25,
                  let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let width = number(bounds["Width"]),
                  let height = number(bounds["Height"]),
                  width >= 80,
                  height >= 80 else {
                return nil
            }

            if let alphaNumber = info[kCGWindowAlpha as String] as? NSNumber,
               alphaNumber.doubleValue <= 0 {
                return nil
            }

            return CGWindowID(windowNumber.uint32Value)
        })
    }

    private static func number(_ value: Any?) -> CGFloat? {
        switch value {
        case let number as NSNumber:
            return CGFloat(truncating: number)
        case let value as CGFloat:
            return value
        case let value as Double:
            return value
        case let value as Int:
            return CGFloat(value)
        default:
            return nil
        }
    }
}
