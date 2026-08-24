import Foundation

struct ClipboardIntelligenceService {
    private static let trackingQueryNames = Set([
        "fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid"
    ])

    func actions(for item: ClipboardItem) -> [ClipboardSmartAction] {
        guard let text = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return []
        }

        var actions: [ClipboardSmartAction] = []
        if case .richText = item.content {
            actions.append(
                ClipboardSmartAction(
                    id: "paste-plain",
                    title: "Paste as Plain Text",
                    symbolName: "textformat",
                    operation: .paste(text)
                )
            )
        }

        if let url = webURL(from: text) {
            actions.append(
                ClipboardSmartAction(
                    id: "open-link",
                    title: "Open Link",
                    symbolName: "safari",
                    operation: .open(url)
                )
            )
            if let cleanedURL = removingTrackingParameters(from: url), cleanedURL != url {
                actions.append(
                    ClipboardSmartAction(
                        id: "copy-clean-link",
                        title: "Copy Link Without Tracking",
                        symbolName: "link",
                        operation: .copy(cleanedURL.absoluteString)
                    )
                )
            }
        }

        if isEmailAddress(text), let url = URL(string: "mailto:\(text)") {
            actions.append(
                ClipboardSmartAction(
                    id: "compose-email",
                    title: "Compose Email",
                    symbolName: "envelope",
                    operation: .open(url)
                )
            )
        }

        if isPhoneNumber(text),
           let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "tel:\(encoded)") {
            actions.append(
                ClipboardSmartAction(
                    id: "call-number",
                    title: "Call Number",
                    symbolName: "phone",
                    operation: .open(url)
                )
            )
        }

        if let formattedJSON = formattedJSON(from: text), formattedJSON != text {
            actions.append(
                ClipboardSmartAction(
                    id: "format-json",
                    title: "Copy Formatted JSON",
                    symbolName: "curlybraces",
                    operation: .copy(formattedJSON)
                )
            )
        }

        if let deindented = removingCommonIndentation(from: text), deindented != text {
            actions.append(
                ClipboardSmartAction(
                    id: "remove-indentation",
                    title: "Copy Without Indentation",
                    symbolName: "decrease.indent",
                    operation: .copy(deindented)
                )
            )
        }

        if let rgb = rgbDescription(for: text) {
            actions.append(
                ClipboardSmartAction(
                    id: "copy-rgb",
                    title: "Copy RGB Value",
                    symbolName: "paintpalette",
                    operation: .copy(rgb)
                )
            )
        }

        return actions
    }

    func removingTrackingParameters(from url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        let filtered = queryItems.filter { item in
            let name = item.name.lowercased()
            return !name.hasPrefix("utm_") && !Self.trackingQueryNames.contains(name)
        }
        guard filtered.count != queryItems.count else { return nil }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url
    }

    func formattedJSON(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let formatted = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ) else {
            return nil
        }
        return String(data: formatted, encoding: .utf8)
    }

    private func webURL(from text: String) -> URL? {
        let candidate: String
        if text.hasPrefix("https://") || text.hasPrefix("http://") {
            candidate = text
        } else if text.hasPrefix("www.") {
            candidate = "https://" + text
        } else {
            return nil
        }
        guard !candidate.contains(where: \.isWhitespace),
              let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    private func isEmailAddress(_ text: String) -> Bool {
        text.range(
            of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func isPhoneNumber(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber)
        guard (7...15).contains(digits.count) else { return false }
        return text.range(of: #"^\+?[0-9() .-]+$"#, options: .regularExpression) != nil
    }

    private func removingCommonIndentation(from text: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else { return nil }
        let nonemptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let indentation = nonemptyLines
            .map { $0.prefix { $0 == " " || $0 == "\t" }.count }
            .min() ?? 0
        guard indentation > 0 else { return nil }
        return lines.map { line in
            String(line.dropFirst(min(indentation, line.count)))
        }.joined(separator: "\n")
    }

    private func rgbDescription(for text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.range(of: #"^#[0-9A-F]{6}$"#, options: .regularExpression) != nil else {
            return nil
        }
        let value = String(normalized.dropFirst())
        guard let red = Int(value.prefix(2), radix: 16),
              let green = Int(value.dropFirst(2).prefix(2), radix: 16),
              let blue = Int(value.dropFirst(4).prefix(2), radix: 16) else {
            return nil
        }
        return "rgb(\(red), \(green), \(blue))"
    }
}
