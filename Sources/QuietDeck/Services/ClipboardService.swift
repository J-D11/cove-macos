import AppKit
import Foundation

@MainActor
final class ClipboardService {
    var onItemCaptured: ((ClipboardItem) -> Void)?

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
        case .image(let image):
            pasteboard.writeObjects([image])
        case .files(let urls):
            pasteboard.writeObjects(urls.map { $0 as NSURL })
        }
        observedChangeCount = pasteboard.changeCount
    }

    private func capturePasteboardChange() {
        guard pasteboard.changeCount != observedChangeCount else { return }
        observedChangeCount = pasteboard.changeCount
        guard let item = item(from: pasteboard) else { return }
        onItemCaptured?(item)
    }

    private func item(from pasteboard: NSPasteboard) -> ClipboardItem? {
        if let values = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [NSURL] {
            let urls = values.map { $0 as URL }
            if !urls.isEmpty {
                return ClipboardItem(content: .files(urls))
            }
        }

        if let image = NSImage(pasteboard: pasteboard) {
            return ClipboardItem(content: .image(image))
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardItem(content: .text(text))
        }

        return nil
    }
}
