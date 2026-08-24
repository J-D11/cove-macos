import AppKit
import Foundation

final class ClipboardPersistenceService {
    private struct StoredItem: Codable {
        enum Kind: String, Codable {
            case text
            case richText
            case image
            case files
        }

        let id: UUID
        let kind: Kind
        let createdAt: Date
        let sourceApplicationName: String?
        let sourceApplicationBundleIdentifier: String?
        let isPinned: Bool
        let ocrText: String?
        let collectionName: String?
        let tags: [String]?
        let expiresAt: Date?
        let removesAfterPaste: Bool?
        let text: String?
        let rtfData: Data?
        let htmlData: Data?
        let imageData: Data?
        let fileURLs: [URL]?

        init(item: ClipboardItem) {
            id = item.id
            createdAt = item.createdAt
            sourceApplicationName = item.sourceApplicationName
            sourceApplicationBundleIdentifier = item.sourceApplicationBundleIdentifier
            isPinned = item.isPinned
            ocrText = item.ocrText
            collectionName = item.collectionName
            tags = item.tags
            expiresAt = item.expiresAt
            removesAfterPaste = item.removesAfterPaste
            switch item.content {
            case .text(let value):
                kind = .text
                text = value
                rtfData = nil
                htmlData = nil
                imageData = nil
                fileURLs = nil
            case .richText(let value):
                kind = .richText
                text = value.plainText
                rtfData = value.rtfData
                htmlData = value.htmlData
                imageData = nil
                fileURLs = nil
            case .image(let value):
                kind = .image
                text = nil
                rtfData = nil
                htmlData = nil
                imageData = value.tiffRepresentation
                fileURLs = nil
            case .files(let value):
                kind = .files
                text = nil
                rtfData = nil
                htmlData = nil
                imageData = nil
                fileURLs = value
            }
        }

        var clipboardItem: ClipboardItem? {
            let content: ClipboardItem.Content
            switch kind {
            case .text:
                guard let text else { return nil }
                content = .text(text)
            case .richText:
                guard let text else { return nil }
                content = .richText(
                    RichTextContent(
                        plainText: text,
                        rtfData: rtfData,
                        htmlData: htmlData
                    )
                )
            case .image:
                guard let imageData, let image = NSImage(data: imageData) else { return nil }
                content = .image(image)
            case .files:
                guard let fileURLs, !fileURLs.isEmpty else { return nil }
                content = .files(fileURLs)
            }
            return ClipboardItem(
                id: id,
                content: content,
                createdAt: createdAt,
                sourceApplicationName: sourceApplicationName,
                sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
                isPinned: isPinned,
                ocrText: ocrText,
                collectionName: collectionName,
                tags: tags ?? [],
                expiresAt: expiresAt,
                removesAfterPaste: removesAfterPaste ?? false
            )
        }
    }

    private let fileManager: FileManager
    private let directoryURL: URL
    private var historyURL: URL {
        directoryURL.appendingPathComponent("ClipboardHistory.json")
    }

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.directoryURL = applicationSupport
                .appendingPathComponent("Cove", isDirectory: true)
        }
    }

    func load() throws -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: historyURL.path) else { return [] }
        let data = try Data(contentsOf: historyURL)
        return try JSONDecoder().decode([StoredItem].self, from: data)
            .compactMap(\.clipboardItem)
    }

    func save(_ items: [ClipboardItem]) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: directoryURL.path
        )
        let data = try JSONEncoder().encode(items.map(StoredItem.init))
        try data.write(to: historyURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: historyURL.path
        )
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: historyURL.path) else { return }
        try fileManager.removeItem(at: historyURL)
    }
}
