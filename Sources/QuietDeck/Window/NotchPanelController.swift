import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class NotchPanelController {
    private final class QuietDeckPanel: NSPanel {
        // The panel remains nonactivating, but key status lets controls such as
        // clipboard search participate in the responder chain when requested.
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let store: ShelfStore
    private let previewMode: Bool
    private var panel: QuietDeckPanel?
    private var hoverTimer: Timer?
    private var lastInsideDate = Date.distantPast
    private var displayObserver: NSObjectProtocol?
    private var targetExpanded = false
    private var targetPanelFrame: CGRect?

    init(store: ShelfStore, previewMode: Bool) {
        self.store = store
        self.previewMode = previewMode
    }

    func start() {
        targetExpanded = previewMode || ShelfPresentationPolicy.shouldPresent(
            keepOpen: store.keepOpen,
            externalMenuInteractionActive: store.externalMenuInteractionActive,
            cursorInside: false,
            lastInsideDate: lastInsideDate,
            manualRevealDeadline: store.manualRevealDeadline,
            now: Date()
        )
        store.isPresented = targetExpanded
        let initialFrame = resolvedPanelFrame(expanded: targetExpanded)
        targetPanelFrame = initialFrame
        let panel = QuietDeckPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Cove"
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // NSPanel shadows follow the rectangular window bounds instead of the
        // SwiftUI surface. Quiet Deck draws its depth inside the rounded shape.
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let hostingView = NSHostingView(rootView: QuietDeckView(store: store))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        self.panel = panel

        if previewMode {
            store.isPresented = true
        } else {
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateHoverState() }
            }
        }

        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updatePanelFrame(animated: false) }
        }
    }

    func stop() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
        }
        displayObserver = nil
        panel?.orderOut(nil)
        panel = nil
        targetPanelFrame = nil
    }

    private func updateHoverState() {
        guard let panel else { return }

        let cursor = NSEvent.mouseLocation
        let screen = targetScreen()
        let triggerFrame = NotchGeometry.triggerFrame(
            screenFrame: screen.frame,
            topInset: screen.safeAreaInsets.top,
            notchWidth: notchWidth(on: screen)
        )
        let inside = triggerFrame.contains(cursor) || panel.frame.insetBy(dx: -8, dy: -10).contains(cursor)

        let now = Date()
        if inside {
            lastInsideDate = now
        }

        let shouldPresent = store.isClipboardSearchPresented
            || ShelfPresentationPolicy.shouldPresent(
                keepOpen: store.keepOpen,
                externalMenuInteractionActive: store.externalMenuInteractionActive,
                cursorInside: inside,
                lastInsideDate: lastInsideDate,
                manualRevealDeadline: store.manualRevealDeadline,
                now: now
            )
        if shouldPresent != store.isPresented {
            store.isPresented = shouldPresent
            updatePanelFrame(animated: true)
        } else if shouldPresent {
            updatePanelFrame(animated: true)
        }
    }

    private func updatePanelFrame(animated: Bool) {
        guard let panel else { return }
        let expanded = previewMode || store.keepOpen || store.isPresented
        let targetFrame = resolvedPanelFrame(expanded: expanded)
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Compare against the requested destination, not the in-flight window
        // frame. The hover timer otherwise restarts this animation every tick.
        let frameChanged = targetPanelFrame.map { !$0.equalTo(targetFrame) } ?? true
        let stateChanged = expanded != targetExpanded
        guard frameChanged || stateChanged else { return }
        targetExpanded = expanded
        targetPanelFrame = targetFrame

        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = expanded
                    ? ShelfPresentationPolicy.appearanceAnimationDuration
                    : ShelfPresentationPolicy.disappearanceAnimationDuration
                context.timingFunction = expanded
                    ? CAMediaTimingFunction(controlPoints: 0.20, 0.88, 0.24, 1.00)
                    : CAMediaTimingFunction(controlPoints: 0.36, 0.00, 0.20, 1.00)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
        if expanded {
            panel.orderFrontRegardless()
        }
    }

    private func resolvedPanelFrame(expanded: Bool) -> CGRect {
        let screen = targetScreen()
        return NotchGeometry.panelFrame(
            screenFrame: screen.frame,
            topInset: screen.safeAreaInsets.top,
            notchWidth: notchWidth(on: screen),
            expanded: expanded,
            expandedWidth: expanded ? store.preferredExpandedWidth : nil
        )
    }

    private func targetScreen() -> NSScreen {
        NSScreen.screens.max { lhs, rhs in
            lhs.safeAreaInsets.top < rhs.safeAreaInsets.top
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func notchWidth(on screen: NSScreen) -> CGFloat? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return nil
        }
        let gap = right.minX - left.maxX
        return gap > 0 ? gap : nil
    }
}
