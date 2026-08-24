import AppKit
import CryptoKit
import Foundation

struct RichTextContent {
    let plainText: String
    let rtfData: Data?
    let htmlData: Data?
}

struct ClipboardItem: Identifiable {
    enum Content {
        case text(String)
        case richText(RichTextContent)
        case image(NSImage)
        case files([URL])
    }

    let id: UUID
    let content: Content
    let fingerprint: String
    let createdAt: Date
    let sourceApplicationName: String?
    let sourceApplicationBundleIdentifier: String?
    let isPinned: Bool
    let ocrText: String?
    let collectionName: String?
    let tags: [String]
    let expiresAt: Date?
    let removesAfterPaste: Bool

    static let multipleFileDragType = "com.astralworkslabs.cove.clipboard-files"

    init(
        id: UUID = UUID(),
        content: Content,
        createdAt: Date = Date(),
        sourceApplicationName: String? = nil,
        sourceApplicationBundleIdentifier: String? = nil,
        isPinned: Bool = false,
        ocrText: String? = nil,
        collectionName: String? = nil,
        tags: [String] = [],
        expiresAt: Date? = nil,
        removesAfterPaste: Bool = false
    ) {
        self.id = id
        self.content = content
        self.fingerprint = Self.fingerprint(for: content)
        self.createdAt = createdAt
        self.sourceApplicationName = sourceApplicationName
        self.sourceApplicationBundleIdentifier = sourceApplicationBundleIdentifier
        self.isPinned = isPinned
        self.ocrText = ocrText
        self.collectionName = collectionName
        self.tags = tags
        self.expiresAt = expiresAt
        self.removesAfterPaste = removesAfterPaste
    }

    var title: String {
        switch content {
        case .text(let text):
            return Self.singleLineTitle(text)
        case .richText(let richText):
            return Self.singleLineTitle(richText.plainText)
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
        case .richText(let richText):
            return "Rich text · \(richText.plainText.count) characters"
        case .image(let image):
            return "\(Int(image.size.width)) × \(Int(image.size.height))"
        case .files(let urls):
            guard urls.count != 1 else {
                return urls[0].deletingLastPathComponent().lastPathComponent
            }
            return "Finder items"
        }
    }

    var previewDetail: String {
        ([collectionName, detail, expirationDescription, ageDescription] as [String?])
            .compactMap { $0 }
            .joined(separator: " • ")
    }

    var ageDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var previewTitle: String {
        switch content {
        case .text(let text):
            return Self.previewText(text)
        case .richText(let richText):
            return Self.previewText(richText.plainText)
        case .image:
            guard let ocrText, !ocrText.isEmpty else { return "Image" }
            return Self.previewText(ocrText)
        case .files(let urls):
            let names = urls.prefix(2).map(\.lastPathComponent)
            let visibleNames = names.isEmpty ? "File" : names.joined(separator: ", ")
            return urls.count > 2 ? visibleNames + "…" : visibleNames
        }
    }

    var plainText: String? {
        switch content {
        case .text(let text):
            return text
        case .richText(let richText):
            return richText.plainText
        case .image, .files:
            return nil
        }
    }

    var fileURLs: [URL] {
        guard case .files(let urls) = content else { return [] }
        return urls
    }

    var symbolName: String {
        switch content {
        case .text:
            return "text.alignleft"
        case .richText:
            return "textformat"
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

    var isExpired: Bool {
        isExpired(at: Date())
    }

    func isExpired(at date: Date) -> Bool {
        expiresAt.map { $0 <= date } ?? false
    }

    var expirationDescription: String? {
        if removesAfterPaste {
            return "Delete after paste"
        }
        guard let expiresAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Expires " + formatter.localizedString(for: expiresAt, relativeTo: Date())
    }

    func withPinned(_ isPinned: Bool) -> ClipboardItem {
        ClipboardItem(
            id: id,
            content: content,
            createdAt: createdAt,
            sourceApplicationName: sourceApplicationName,
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            isPinned: isPinned,
            ocrText: ocrText,
            collectionName: collectionName,
            tags: tags,
            expiresAt: expiresAt,
            removesAfterPaste: removesAfterPaste
        )
    }

    func withOCRText(_ text: String?) -> ClipboardItem {
        replacing(ocrText: text)
    }

    func withCollection(_ name: String?, tags: [String]? = nil) -> ClipboardItem {
        replacing(
            isPinned: name == nil ? isPinned : true,
            collectionName: name,
            tags: tags ?? self.tags
        )
    }

    func withExpiration(expiresAt: Date?, removesAfterPaste: Bool) -> ClipboardItem {
        replacing(expiresAt: expiresAt, removesAfterPaste: removesAfterPaste)
    }

    func mergingMetadata(from existing: ClipboardItem?) -> ClipboardItem {
        guard let existing else { return self }
        let mergedOCRText = self.ocrText ?? existing.ocrText
        let mergedCollectionName = self.collectionName ?? existing.collectionName
        let mergedExpiration = self.expiresAt ?? existing.expiresAt
        return replacing(
            isPinned: isPinned || existing.isPinned,
            ocrText: .some(mergedOCRText),
            collectionName: .some(mergedCollectionName),
            tags: tags.isEmpty ? existing.tags : tags,
            expiresAt: .some(mergedExpiration),
            removesAfterPaste: removesAfterPaste || existing.removesAfterPaste
        )
    }

    func matchesSearch(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }
        let searchableValues = [
            previewTitle,
            detail,
            sourceApplicationName ?? "",
            sourceApplicationBundleIdentifier ?? "",
            ocrText ?? "",
            collectionName ?? "",
            tags.joined(separator: " "),
            fileURLs.map(\.path).joined(separator: " ")
        ]
        return searchableValues.contains {
            $0.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private func replacing(
        isPinned: Bool? = nil,
        ocrText: String?? = nil,
        collectionName: String?? = nil,
        tags: [String]? = nil,
        expiresAt: Date?? = nil,
        removesAfterPaste: Bool? = nil
    ) -> ClipboardItem {
        func resolved<Value>(_ replacement: Value??, current: Value?) -> Value? {
            switch replacement {
            case .some(let value): return value
            case .none: return current
            }
        }
        return ClipboardItem(
            id: id,
            content: content,
            createdAt: createdAt,
            sourceApplicationName: sourceApplicationName,
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            isPinned: isPinned ?? self.isPinned,
            ocrText: resolved(ocrText, current: self.ocrText),
            collectionName: resolved(collectionName, current: self.collectionName),
            tags: tags ?? self.tags,
            expiresAt: resolved(expiresAt, current: self.expiresAt),
            removesAfterPaste: removesAfterPaste ?? self.removesAfterPaste
        )
    }

    func itemProvider() -> NSItemProvider {
        switch content {
        case .text(let text):
            return NSItemProvider(object: text as NSString)
        case .richText(let richText):
            let provider = NSItemProvider(object: richText.plainText as NSString)
            if let rtfData = richText.rtfData {
                provider.registerDataRepresentation(
                    forTypeIdentifier: NSPasteboard.PasteboardType.rtf.rawValue,
                    visibility: .all
                ) { completion in
                    completion(rtfData, nil)
                    return nil
                }
            }
            if let htmlData = richText.htmlData {
                provider.registerDataRepresentation(
                    forTypeIdentifier: NSPasteboard.PasteboardType.html.rawValue,
                    visibility: .all
                ) { completion in
                    completion(htmlData, nil)
                    return nil
                }
            }
            return provider
        case .image(let image):
            return NSItemProvider(object: image)
        case .files(let urls):
            guard let firstURL = urls.first else { return NSItemProvider() }
            let provider = NSItemProvider(object: firstURL as NSURL)
            provider.suggestedName = urls.count == 1
                ? firstURL.lastPathComponent
                : "\(urls.count) files"
            let encodedURLs = try? JSONEncoder().encode(urls.map(\.absoluteString))
            provider.registerDataRepresentation(
                forTypeIdentifier: Self.multipleFileDragType,
                visibility: .all
            ) { completion in
                completion(encodedURLs, nil)
                return nil
            }
            return provider
        }
    }

    private static func singleLineTitle(_ text: String) -> String {
        let singleLine = text
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return singleLine.isEmpty ? "Text" : singleLine
    }

    private static func previewText(_ text: String) -> String {
        let normalized = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !normalized.isEmpty else { return "Empty text" }
        return normalized.count > 120
            ? String(normalized.prefix(120)) + "…"
            : normalized
    }

    private static func fingerprint(for content: Content) -> String {
        let data: Data
        let prefix: String
        switch content {
        case .text(let text):
            prefix = "text"
            data = Data(text.utf8)
        case .richText(let richText):
            prefix = "rich-text"
            data = richText.rtfData
                ?? richText.htmlData
                ?? Data(richText.plainText.utf8)
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
    static let defaultItemCount = 8
    static let minimumItemCount = 3
    static let maximumItemCount = 20

    static func inserting(
        _ item: ClipboardItem,
        into items: [ClipboardItem],
        limit: Int = defaultItemCount
    ) -> [ClipboardItem] {
        guard limit > 0 else { return items.filter(\.isPinned) }
        let existingMatch = items.first { $0.fingerprint == item.fingerprint }
        let inserted = item.mergingMetadata(from: existingMatch)
        let remaining = items.filter { $0.fingerprint != item.fingerprint }
        return trimming([inserted] + remaining, limit: limit)
    }

    static func pinning(
        _ item: ClipboardItem,
        isPinned: Bool,
        in items: [ClipboardItem],
        limit: Int
    ) -> [ClipboardItem] {
        let updated = items.map { candidate in
            candidate.id == item.id ? candidate.withPinned(isPinned) : candidate
        }
        return trimming(updated, limit: limit)
    }

    static func trimming(_ items: [ClipboardItem], limit: Int) -> [ClipboardItem] {
        let activeItems = items.filter { !$0.isExpired }
        let pinned = activeItems.filter(\.isPinned)
        let unpinned = activeItems.filter { !$0.isPinned }
        let availableUnpinnedCount = max(limit - pinned.count, 0)
        return pinned + unpinned.prefix(availableUnpinnedCount)
    }

    static func itemsToPersist(
        from items: [ClipboardItem],
        includesRecentHistory: Bool
    ) -> [ClipboardItem] {
        let activeItems = items.filter { !$0.isExpired }
        return includesRecentHistory ? activeItems : activeItems.filter(\.isPinned)
    }
}
