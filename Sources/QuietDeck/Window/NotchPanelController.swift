import AppKit
import CoreGraphics
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
    private let layoutModeOverride: SideWingLayoutMode?
    private var panel: QuietDeckPanel?
    private var hoverTimer: Timer?
    private var lastInsideDate = Date.distantPast
    private var displayObserver: NSObjectProtocol?
    private var targetExpanded = false
    private var targetPanelFrame: CGRect?

    init(
        store: ShelfStore,
        previewMode: Bool,
        layoutModeOverride: SideWingLayoutMode? = nil
    ) {
        self.store = store
        self.previewMode = previewMode
        self.layoutModeOverride = layoutModeOverride
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
        // SwiftUI surface. Cove draws its depth inside the attached wing shape.
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let hostingView = NSHostingView(rootView: QuietDeckView(store: store))
        // The panel controller is the single source of truth for the window
        // frame. Letting NSHostingView also publish an intrinsic size can make
        // AppKit re-enter layout while the side wing is resizing.
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        panel.contentView = hostingView
        self.panel = panel
        // Give SwiftUI and the status-item host enough time to finish their
        // first layout before WindowServer publishes the panel scene. A single
        // run-loop turn is not deterministic during a cold LaunchServices
        // launch and can still overlap AppKit's initial layout pass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak panel] in
            panel?.orderFrontRegardless()
            // Suppress only the initial order animation. Subsequent explicit
            // frame animations need a non-none behavior or AppKit accepts the
            // animator target without ever moving the panel.
            panel?.animationBehavior = .utilityWindow
        }

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
        let triggerFrame = SideWingGeometry.triggerFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
        let inside = triggerFrame.contains(cursor)
            || panel.frame.insetBy(dx: -10, dy: -12).contains(cursor)

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
            // Let SwiftUI commit the presentation-state layout before AppKit
            // begins resizing the host window. Doing both in the same layout
            // turn can trigger AppKit's layout-recursion warning.
            DispatchQueue.main.async { [weak self] in
                self?.updatePanelFrame(animated: true)
            }
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
                    ? CAMediaTimingFunction(controlPoints: 0.16, 1.00, 0.30, 1.00)
                    : CAMediaTimingFunction(controlPoints: 0.32, 0.00, 0.20, 1.00)
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
        let layoutMode = resolvedLayoutMode(for: screen)
        store.updateSideWingLayoutMode(layoutMode)
        return SideWingGeometry.panelFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            expanded: expanded,
            expandedHeight: expanded ? store.preferredSideWingHeight : nil,
            layoutMode: layoutMode
        )
    }

    private func resolvedLayoutMode(for screen: NSScreen) -> SideWingLayoutMode {
        if let layoutModeOverride {
            return layoutModeOverride
        }

        let externalDisplayCount = NSScreen.screens.filter {
            !isBuiltInDisplay($0)
        }.count
        return SideWingGeometry.layoutMode(
            isBuiltInDisplay: isBuiltInDisplay(screen),
            externalDisplayCount: externalDisplayCount
        )
    }

    private func isBuiltInDisplay(_ screen: NSScreen) -> Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return screen.safeAreaInsets.top > 0
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }

    private func targetScreen() -> NSScreen {
        NSScreen.screens.max { lhs, rhs in
            lhs.safeAreaInsets.top < rhs.safeAreaInsets.top
        } ?? NSScreen.main ?? NSScreen.screens[0]
    }

}
