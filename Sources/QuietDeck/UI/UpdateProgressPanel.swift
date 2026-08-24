import AppKit

@MainActor
final class UpdateProgressPanelController {
    private let panel: NSPanel
    private let statusLabel: NSTextField
    private let progressIndicator: NSProgressIndicator

    init(version: CoveVersion) {
        statusLabel = NSTextField(labelWithString: "Downloading Cove \(version)…")
        progressIndicator = NSProgressIndicator()
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 110),
            styleMask: [.titled, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Cove Update"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.center()

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center

        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.controlSize = .regular
        progressIndicator.usesThreadedAnimation = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let stack = NSStackView(views: [statusLabel, progressIndicator])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
        panel.contentView = stack
    }

    func show() {
        panel.center()
        panel.orderFrontRegardless()
    }

    func update(progress: Double?) {
        guard let progress else {
            progressIndicator.isIndeterminate = true
            statusLabel.stringValue = "Downloading Cove…"
            progressIndicator.startAnimation(nil)
            return
        }

        progressIndicator.stopAnimation(nil)
        progressIndicator.isIndeterminate = false
        progressIndicator.doubleValue = progress * 100
        statusLabel.stringValue = "Downloading Cove… \(Int(progress * 100))%"
    }

    func close() {
        panel.orderOut(nil)
    }
}
