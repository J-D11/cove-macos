import AppKit
import CryptoKit
import Foundation

struct ClipboardItem: Identifiable {
    enum Content {
        case text(String)
        case image(NSImage)
        case files([URL])
    }

    let id: UUID
    let content: Content
    let fingerprint: String
    let createdAt: Date

    init(id: UUID = UUID(), content: Content, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.fingerprint = Self.fingerprint(for: content)
        self.createdAt = createdAt
    }

    var title: String {
        switch content {
        case .text(let text):
            let singleLine = text
                .split(whereSeparator: \.isNewline)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return singleLine.isEmpty ? "Text" : singleLine
        case .image:
            return "Image"
        case .files(let urls):
            guard urls.count != 1 else {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"
        }
    }

    var detail: String {
        switch content {
        case .text(let text):
            return "\(text.count) characters"
        case .image(let image):
            return "\(Int(image.size.width)) × \(Int(image.size.height))"
        case .files(let urls):
            guard urls.count != 1 else {
                return urls[0].deletingLastPathComponent().lastPathComponent
            }
            return "Finder items"
        }
    }

    var symbolName: String {
        switch content {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo.fill"
        case .files(let urls):
            guard urls.count == 1 else { return "doc.on.doc.fill" }
            return urls[0].hasDirectoryPath ? "folder.fill" : "doc.fill"
        }
    }

    var image: NSImage? {
        guard case .image(let image) = content else { return nil }
        return image
    }

    func itemProvider() -> NSItemProvider {
        switch content {
        case .text(let text):
            return NSItemProvider(object: text as NSString)
        case .image(let image):
            return NSItemProvider(object: image)
        case .files(let urls):
            guard let firstURL = urls.first else { return NSItemProvider() }
            return NSItemProvider(object: firstURL as NSURL)
        }
    }

    private static func fingerprint(for content: Content) -> String {
        let data: Data
        let prefix: String
        switch content {
        case .text(let text):
            prefix = "text"
            data = Data(text.utf8)
        case .image(let image):
            prefix = "image"
            data = image.tiffRepresentation ?? Data()
        case .files(let urls):
            prefix = "files"
            let value = urls
                .map { $0.standardizedFileURL.absoluteString }
                .sorted()
                .joined(separator: "\n")
            data = Data(value.utf8)
        }
        let digest = SHA256.hash(data: data)
        return "\(prefix):\(digest.map { String(format: "%02x", $0) }.joined())"
    }
}

enum ClipboardHistory {
    static let maximumItemCount = 8

    static func inserting(
        _ item: ClipboardItem,
        into items: [ClipboardItem],
        limit: Int = maximumItemCount
    ) -> [ClipboardItem] {
        guard limit > 0 else { return [] }
        let remaining = items.filter { $0.fingerprint != item.fingerprint }
        return Array(([item] + remaining).prefix(limit))
    }
}
