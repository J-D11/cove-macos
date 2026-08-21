import Foundation

struct HiddenMenuBarOwner: Equatable {
    let bundleIdentifier: String
    let displayName: String
    let symbolName: String
}

enum HiddenMenuBarOwnerCatalog {
    static let owners = [
        HiddenMenuBarOwner(
            bundleIdentifier: "pro.betterdisplay.BetterDisplay",
            displayName: "BetterDisplay",
            symbolName: "display"
        ),
        HiddenMenuBarOwner(
            bundleIdentifier: "it.focusense.input-app",
            displayName: "Input",
            symbolName: "keyboard"
        ),
        HiddenMenuBarOwner(
            bundleIdentifier: "app.busy",
            displayName: "BUSY",
            symbolName: "chart.bar.fill"
        )
    ]

    static func owner(for bundleIdentifier: String) -> HiddenMenuBarOwner? {
        owners.first {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }
}
