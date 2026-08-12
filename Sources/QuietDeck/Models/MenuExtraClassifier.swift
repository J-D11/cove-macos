import Foundation

enum MenuExtraClassifier {
    struct DedicatedOwnerIconResource: Equatable {
        let name: String
        let fileExtension: String
    }

    static func dedicatedOwnerIconResource(
        ownerBundleIdentifier: String
    ) -> DedicatedOwnerIconResource? {
        switch ownerBundleIdentifier.lowercased() {
        case "com.steipete.codexbar":
            return DedicatedOwnerIconResource(name: "ProviderIcon-codex", fileExtension: "svg")
        case "com.openai.codex":
            return DedicatedOwnerIconResource(name: "chatgptTemplate@2x", fileExtension: "png")
        default:
            return nil
        }
    }

    static func prefersOwnerIconOverNativeSnapshot(ownerBundleIdentifier: String) -> Bool {
        dedicatedOwnerIconResource(ownerBundleIdentifier: ownerBundleIdentifier) != nil
    }

    static func symbolName(identifier: String?, label: String, ownerBundleIdentifier: String) -> String? {
        let haystack = [identifier ?? "", label]
            .joined(separator: " ")
            .lowercased()

        if !ownerBundleIdentifier.hasPrefix("com.apple.") {
            let words = Set(
                haystack
                    .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                    .map(String.init)
            )
            if words.contains("cpu") { return "cpu" }
            if words.contains("gpu") { return "display" }
            if words.contains("ram") || words.contains("memory") { return "memorychip" }
            if words.contains("disk") || words.contains("storage") { return "internaldrive" }
            if words.contains("sensor") || words.contains("sensors") || words.contains("temperature") {
                return "thermometer.medium"
            }
            if words.contains("network") { return "arrow.up.arrow.down" }
            return nil
        }

        if haystack.contains("wifi") || haystack.contains("wi-fi") { return "wifi" }
        if haystack.contains("bluetooth") { return "bluetooth" }
        if haystack.contains("battery") { return "battery.75percent" }
        if haystack.contains("volume") || haystack.contains("sound") { return "speaker.wave.2.fill" }
        if haystack.contains("focus") || haystack.contains("dnd") { return "moon.fill" }
        if haystack.contains("airdrop") { return "airdrop" }
        if haystack.contains("airplay") || haystack.contains("screenmirroring") || haystack.contains("screen mirroring") {
            return "rectangle.on.rectangle"
        }
        if haystack.contains("vpn") { return "lock.shield.fill" }
        if haystack.contains("timemachine") || haystack.contains("time machine") { return "clock.arrow.circlepath" }
        if haystack.contains("siri") { return "apple.intelligence" }
        if haystack.contains("clock") || haystack.contains("date") { return "clock" }
        if haystack.contains("controlcenter") || haystack.contains("control center") { return "switch.2" }
        if haystack.contains("keyboard") || haystack.contains("input") { return "keyboard" }
        if haystack.contains("display") { return "display" }
        return "circle.grid.2x2.fill"
    }

    static func displayName(identifier: String?, label: String?, ownerName: String) -> String {
        if let label = cleaned(label), !looksInternal(label) {
            return label
        }

        let rawIdentifier = identifier?.lowercased() ?? ""
        let knownNames: [(String, String)] = [
            ("wifi", "Wi-Fi"),
            ("bluetooth", "Bluetooth"),
            ("battery", "Battery"),
            ("volume", "Sound"),
            ("sound", "Sound"),
            ("focus", "Focus"),
            ("airdrop", "AirDrop"),
            ("airplay", "AirPlay"),
            ("vpn", "VPN"),
            ("timemachine", "Time Machine"),
            ("siri", "Siri"),
            ("clock", "Clock"),
            ("controlcenter", "Control Center"),
            ("keyboard", "Keyboard"),
            ("display", "Display")
        ]

        if let match = knownNames.first(where: { rawIdentifier.contains($0.0) }) {
            return match.1
        }

        return cleaned(ownerName) ?? "Menu Item"
    }

    static func compactValue(from label: String?) -> String? {
        guard let label else { return nil }
        let range = label.range(of: #"\b\d{1,3}%"#, options: .regularExpression)
        return range.map { String(label[$0]) }
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func looksInternal(_ value: String) -> Bool {
        value.hasPrefix("_NS:") || value.contains("Item-")
    }
}
