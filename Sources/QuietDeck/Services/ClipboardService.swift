import AppKit
import Foundation

@MainActor
final class ClipboardService {
    var onItemCaptured: ((ClipboardItem) -> Void)?
    var shouldCapture: ((String?, [String]) -> Bool)?

    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var observedChangeCount: Int

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.observedChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        observedChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.capturePasteboardChange()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .richText(let richText):
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(richText.plainText, forType: .string)
            if let rtfData = richText.rtfData {
                pasteboardItem.setData(rtfData, forType: .rtf)
            }
            if let htmlData = richText.htmlData {
                pasteboardItem.setData(htmlData, forType: .html)
            }
            pasteboard.writeObjects([pasteboardItem])
        case .image(let image):
            pasteboard.writeObjects([image])
        case .files(let urls):
            pasteboard.writeObjects(urls.map { $0 as NSURL })
        }
        observedChangeCount = pasteboard.changeCount
    }

    func capturePasteboardChange() {
        guard pasteboard.changeCount != observedChangeCount else { return }
        observedChangeCount = pasteboard.changeCount

        let sourceApplication = NSWorkspace.shared.frontmostApplication
        let sourceBundleIdentifier = sourceApplication?.bundleIdentifier
        let typeIdentifiers = pasteboard.types?.map(\.rawValue) ?? []
        guard shouldCapture?(sourceBundleIdentifier, typeIdentifiers) ?? true else { return }
        guard let item = item(from: pasteboard, sourceApplication: sourceApplication) else { return }
        onItemCaptured?(item)
    }

    private func item(
        from pasteboard: NSPasteboard,
        sourceApplication: NSRunningApplication?
    ) -> ClipboardItem? {
        let isCove = sourceApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        let sourceApplicationName = isCove ? nil : sourceApplication?.localizedName
        let sourceApplicationBundleIdentifier = isCove ? nil : sourceApplication?.bundleIdentifier

        if let values = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL] {
            let urls = values.map { $0 as URL }
            if !urls.isEmpty {
                return ClipboardItem(
                    content: .files(urls),
                    sourceApplicationName: sourceApplicationName,
                    sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier
                )
            }
        }

        let plainText = pasteboard.string(forType: .string)
        let rtfData = pasteboard.data(forType: .rtf)
        let htmlData = pasteboard.data(forType: .html)
        if let plainText, !plainText.isEmpty, rtfData != nil || htmlData != nil {
            return ClipboardItem(
                content: .richText(
                    RichTextContent(
                        plainText: plainText,
                        rtfData: rtfData,
                        htmlData: htmlData
                    )
                ),
                sourceApplicationName: sourceApplicationName,
                sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier
            )
        }

        if let image = NSImage(pasteboard: pasteboard) {
            return ClipboardItem(
                content: .image(image),
                sourceApplicationName: sourceApplicationName,
                sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier
            )
        }

        if let plainText, !plainText.isEmpty {
            return ClipboardItem(
                content: .text(plainText),
                sourceApplicationName: sourceApplicationName,
                sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier
            )
        }

        return nil
    }
}
