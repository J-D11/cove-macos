import CoreGraphics
import Foundation

struct WindowBackedMenuBarItem: Equatable {
    let processIdentifier: pid_t
    let frame: CGRect
    let index: Int
}

enum MenuBarWindowFallback {
    static func items(candidateProcessIdentifiers: Set<pid_t>) -> [WindowBackedMenuBarItem] {
        guard !candidateProcessIdentifiers.isEmpty,
              let windowInfo = CGWindowListCopyWindowInfo(
                  [.optionAll, .excludeDesktopElements],
                  kCGNullWindowID
              ) as? [[String: Any]] else {
            return []
        }

        return items(from: windowInfo, candidateProcessIdentifiers: candidateProcessIdentifiers)
    }

    static func items(
        from windowInfo: [[String: Any]],
        candidateProcessIdentifiers: Set<pid_t>
    ) -> [WindowBackedMenuBarItem] {
        var framesByProcess: [pid_t: [CGRect]] = [:]

        for info in windowInfo {
            guard let processNumber = info[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let processIdentifier = pid_t(processNumber.intValue)
            guard candidateProcessIdentifiers.contains(processIdentifier) else { continue }

            guard let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
                  layerNumber.intValue == 24 || layerNumber.intValue == 25 else {
                continue
            }

            if let alphaNumber = info[kCGWindowAlpha as String] as? NSNumber,
               alphaNumber.doubleValue <= 0 {
                continue
            }

            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let x = number(bounds["X"]),
                  let y = number(bounds["Y"]),
                  let width = number(bounds["Width"]),
                  let height = number(bounds["Height"]),
                  width > 0,
                  width <= 500,
                  height > 0,
                  height <= 60 else {
                continue
            }

            framesByProcess[processIdentifier, default: []].append(
                CGRect(x: x, y: y, width: width, height: height)
            )
        }

        return framesByProcess
            .sorted { $0.key < $1.key }
            .flatMap { processIdentifier, frames in
                frames
                    .sorted {
                        if $0.midX == $1.midX { return $0.width < $1.width }
                        return $0.midX < $1.midX
                    }
                    .enumerated()
                    .map { index, frame in
                        WindowBackedMenuBarItem(
                            processIdentifier: processIdentifier,
                            frame: frame,
                            index: index
                        )
                    }
            }
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
