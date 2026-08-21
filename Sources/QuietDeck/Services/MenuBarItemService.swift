import AppKit
import ApplicationServices
import OSLog

struct MenuBarScanResult {
    let items: [MenuBarItemModel]
    let candidateCount: Int
    let accessibilityOwnerCount: Int
    let windowFallbackCount: Int
    let visibleFallbackCount: Int
}

@MainActor
final class MenuBarItemService {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.astralworkslabs.QuietDeck",
        category: "MenuBarScanner"
    )

    private struct ScannedElement {
        let element: AXUIElement
        let identifier: String?
        let index: Int
        let frame: CGRect?
    }
    private var didLogDiagnostics = false

    func scan() -> MenuBarScanResult {
        guard AccessibilityPermissionService.isTrusted else {
            logger.warning("Skipped menu-bar scan because Accessibility is not trusted")
            return MenuBarScanResult(
                items: [],
                candidateCount: 0,
                accessibilityOwnerCount: 0,
                windowFallbackCount: 0,
                visibleFallbackCount: 0
            )
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var results: [MenuBarItemModel] = []
        var seenIdentifiers = Set<String>()
        var accessibilityOwnerPIDs = Set<pid_t>()

        let runningApplications = NSWorkspace.shared.runningApplications.filter { application in
            guard application.processIdentifier != ownPID else { return false }
            if let bundleIdentifier = application.bundleIdentifier,
               bundleIdentifier == Bundle.main.bundleIdentifier {
                return false
            }
            return true
        }

        let runningApplicationsByPID = Dictionary(
            uniqueKeysWithValues: runningApplications.map { ($0.processIdentifier, $0) }
        )
        let windowBackedItems = MenuBarWindowFallback.items(
            candidateProcessIdentifiers: Set(runningApplicationsByPID.keys)
        )
        let windowBackedPIDs = Set(windowBackedItems.map(\.processIdentifier))

        let candidates = runningApplications.filter { application in
            // Most menu-bar helpers are accessory apps. Prohibited helpers are included when
            // WindowServer confirms that they own a status-item-layer window. Known hidden-menu
            // owners are also included when macOS runs them as background-only apps.
            application.activationPolicy != .prohibited
                || isKnownSystemOwner(application.bundleIdentifier)
                || isKnownHiddenOwner(application.bundleIdentifier)
                || windowBackedPIDs.contains(application.processIdentifier)
        }

        let applicationsByPID = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0.processIdentifier, $0) }
        )

        for application in candidates {
            guard let bundleIdentifier = resolvedBundleIdentifier(for: application) else { continue }
            let elements = menuBarElements(
                processIdentifier: application.processIdentifier,
                ownerBundleIdentifier: bundleIdentifier
            )
            if !elements.isEmpty {
                accessibilityOwnerPIDs.insert(application.processIdentifier)
            }

            for scanned in elements {
                let title = copyStringAttribute(scanned.element, kAXTitleAttribute as CFString)
                let description = copyStringAttribute(scanned.element, kAXDescriptionAttribute as CFString)
                let help = copyStringAttribute(scanned.element, kAXHelpAttribute as CFString)
                let value = copyStringAttribute(scanned.element, kAXValueAttribute as CFString)
                let label = firstUsefulString(title, description, help, value)

                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--diagnose-menu-items"),
                   !didLogDiagnostics,
                   bundleIdentifier == "eu.exelban.Stats" {
                    logger.info(
                        "Diagnostic AX owner=\(bundleIdentifier, privacy: .private(mask: .hash)) title=\(title ?? "none", privacy: .private(mask: .hash)) description=\(description ?? "none", privacy: .private(mask: .hash)) help=\(help ?? "none", privacy: .private(mask: .hash)) value=\(value ?? "none", privacy: .private(mask: .hash)) frame=\(String(describing: scanned.frame), privacy: .private(mask: .hash))"
                    )
                }
                #endif
                let name = MenuExtraClassifier.displayName(
                    identifier: scanned.identifier,
                    label: label,
                    ownerName: application.localizedName ?? bundleIdentifier
                )
                let uniqueIdentifier = scanned.identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                let id = uniqueIdentifier.map { "\(bundleIdentifier)::\($0)" }
                    ?? "\(bundleIdentifier)::\(application.processIdentifier)::item:\(scanned.index)"
                guard seenIdentifiers.insert(id).inserted else { continue }

                let ownerIcon = copiedIcon(from: application)
                let symbolName = MenuExtraClassifier.symbolName(
                    identifier: uniqueIdentifier,
                    label: name,
                    ownerBundleIdentifier: bundleIdentifier
                )

                results.append(
                    MenuBarItemModel(
                        id: id,
                        ownerBundleIdentifier: bundleIdentifier,
                        ownerPID: application.processIdentifier,
                        itemIdentifier: uniqueIdentifier,
                        itemIndex: scanned.index,
                        name: name,
                        symbolName: symbolName,
                        ownerIcon: ownerIcon,
                        compactValue: MenuExtraClassifier.compactValue(from: label),
                        accessibilityFrame: scanned.frame,
                        xPosition: scanned.frame?.minX ?? .greatestFiniteMagnitude
                    )
                )
            }
        }

        let unresolvedPIDs = Set(applicationsByPID.keys).subtracting(accessibilityOwnerPIDs)
        var windowFallbackCount = 0
        for fallback in windowBackedItems where unresolvedPIDs.contains(fallback.processIdentifier) {
            guard let application = applicationsByPID[fallback.processIdentifier],
                  let bundleIdentifier = resolvedBundleIdentifier(for: application) else {
                continue
            }

            let id = "\(bundleIdentifier)::window:\(fallback.processIdentifier):\(fallback.index)"
            guard seenIdentifiers.insert(id).inserted else { continue }
            let ownerName = application.localizedName ?? bundleIdentifier
            results.append(
                MenuBarItemModel(
                    id: id,
                    ownerBundleIdentifier: bundleIdentifier,
                    ownerPID: fallback.processIdentifier,
                    itemIdentifier: nil,
                    itemIndex: fallback.index,
                    name: ownerName,
                    symbolName: MenuExtraClassifier.symbolName(
                        identifier: nil,
                        label: ownerName,
                        ownerBundleIdentifier: bundleIdentifier
                    ),
                    ownerIcon: copiedIcon(from: application),
                    compactValue: nil,
                    accessibilityFrame: fallback.frame,
                    xPosition: fallback.frame.minX
                )
            )
            windowFallbackCount += 1
        }

        var visibleFallbackCount = 0
        for item in systemWideVisibleMenuBarItems() where seenIdentifiers.insert(item.id).inserted {
            results.append(item)
            visibleFallbackCount += 1
        }

        for application in candidates {
            guard let bundleIdentifier = resolvedBundleIdentifier(for: application),
                  let hiddenOwner = HiddenMenuBarOwnerCatalog.owner(for: bundleIdentifier),
                  !accessibilityOwnerPIDs.contains(application.processIdentifier),
                  !windowBackedPIDs.contains(application.processIdentifier) else {
                continue
            }

            let id = "\(bundleIdentifier)::hidden-owner"
            guard seenIdentifiers.insert(id).inserted else { continue }
            results.append(
                MenuBarItemModel(
                    id: id,
                    ownerBundleIdentifier: bundleIdentifier,
                    ownerPID: application.processIdentifier,
                    itemIdentifier: nil,
                    itemIndex: 0,
                    name: hiddenOwner.displayName,
                    symbolName: hiddenOwner.symbolName,
                    ownerIcon: copiedIcon(from: application),
                    compactValue: nil,
                    accessibilityFrame: nil,
                    xPosition: .greatestFiniteMagnitude,
                    isHiddenOwnerFallback: true
                )
            )
        }

        let sortedCandidates = results.sorted {
            if $0.xPosition != $1.xPosition { return $0.xPosition < $1.xPosition }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let deduplication = MenuBarItemDeduplicator.deduplicate(sortedCandidates)
        let sortedResults = deduplication.items

        logger.info(
            "Menu-bar scan candidates=\(candidates.count, privacy: .public) AXOwners=\(accessibilityOwnerPIDs.count, privacy: .public) windowFallbacks=\(windowFallbackCount, privacy: .public) visibleFallbacks=\(visibleFallbackCount, privacy: .public) duplicatesRemoved=\(deduplication.duplicateCount, privacy: .public) placeholdersRemoved=\(deduplication.placeholderCount, privacy: .public) items=\(sortedResults.count, privacy: .public)"
        )

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--diagnose-menu-items"), !didLogDiagnostics {
            didLogDiagnostics = true
            for (index, item) in sortedResults.enumerated() {
                logger.info(
                    "Diagnostic item index=\(index, privacy: .public) owner=\(item.ownerBundleIdentifier, privacy: .private(mask: .hash)) identifier=\(item.itemIdentifier ?? "none", privacy: .private(mask: .hash)) name=\(item.name, privacy: .private(mask: .hash)) symbol=\(item.symbolName ?? "app-icon", privacy: .private(mask: .hash)) x=\(item.xPosition, privacy: .private(mask: .hash))"
                )
            }
        }
        #endif

        return MenuBarScanResult(
            items: sortedResults,
            candidateCount: candidates.count,
            accessibilityOwnerCount: accessibilityOwnerPIDs.count,
            windowFallbackCount: windowFallbackCount,
            visibleFallbackCount: visibleFallbackCount
        )
    }

    @discardableResult
    func activate(_ model: MenuBarItemModel) -> Bool {
        guard AccessibilityPermissionService.isTrusted else { return false }
        if model.isHiddenOwnerFallback {
            return activateHiddenOwner(model)
        }

        let candidates = menuBarElements(
            processIdentifier: model.ownerPID,
            ownerBundleIdentifier: model.ownerBundleIdentifier
        )

        let resolved = candidates.first { candidate in
            if let identifier = model.itemIdentifier {
                return candidate.identifier == identifier
            }
            return candidate.index == model.itemIndex
        }

        if let element = resolved?.element,
           AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            return true
        }

        guard let frame = resolved?.frame ?? model.accessibilityFrame else { return false }
        return postClick(at: CGPoint(x: frame.midX, y: frame.midY))
    }

    private func activateHiddenOwner(_ model: MenuBarItemModel) -> Bool {
        if let application = NSRunningApplication(processIdentifier: model.ownerPID) {
            return application.activate(options: [.activateAllWindows])
        }

        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier?.caseInsensitiveCompare(model.ownerBundleIdentifier) == .orderedSame
        }), let bundleURL = application.bundleURL else {
            return false
        }
        return NSWorkspace.shared.open(bundleURL)
    }

    private func menuBarElements(
        processIdentifier: pid_t,
        ownerBundleIdentifier: String
    ) -> [ScannedElement] {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, 0.04)

        var roots: [AXUIElement] = []
        let extrasMenuBar = copyElementAttribute(applicationElement, "AXExtrasMenuBar" as CFString)
        let usedFallback: Bool
        if let extrasMenuBar {
            roots.append(extrasMenuBar)
            usedFallback = false
        } else {
            usedFallback = true
        }

        if roots.isEmpty, isKnownSystemOwner(ownerBundleIdentifier),
           let regularMenuBar = copyElementAttribute(applicationElement, kAXMenuBarAttribute as CFString) {
            roots.append(regularMenuBar)
        }

        var collected: [ScannedElement] = []
        for root in roots {
            let items = collectMenuBarItems(from: root)
            for (index, item) in items.enumerated() {
                let subrole = copyStringAttribute(item, kAXSubroleAttribute as CFString)
                if usedFallback, subrole != "AXMenuExtra" {
                    continue
                }

                let identifier = copyStringAttribute(item, kAXIdentifierAttribute as CFString)
                collected.append(
                    ScannedElement(
                        element: item,
                        identifier: identifier,
                        index: index,
                        frame: accessibilityFrame(of: item)
                    )
                )
            }
        }
        return collected
    }

    private func systemWideVisibleMenuBarItems() -> [MenuBarItemModel] {
        guard let screen = NSScreen.screens.max(by: { $0.safeAreaInsets.top < $1.safeAreaInsets.top }) else {
            return []
        }

        let systemWide = AXUIElementCreateSystemWide()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let y = screen.frame.minY + 15
        let startX = Int(screen.frame.minX.rounded(.down))
        let endX = Int((screen.frame.maxX - 1).rounded(.down))
        var sampledIDs = Set<String>()
        var results: [MenuBarItemModel] = []

        for x in stride(from: startX, through: endX, by: 6) {
            var element: AXUIElement?
            guard AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &element) == .success,
                  let element else {
                continue
            }

            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            guard pid != ownPID,
                  let application = NSRunningApplication(processIdentifier: pid),
                  let bundleIdentifier = resolvedBundleIdentifier(for: application) else {
                continue
            }

            let role = copyStringAttribute(element, kAXRoleAttribute as CFString)
            let subrole = copyStringAttribute(element, kAXSubroleAttribute as CFString)
            guard (role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem"),
                  subrole == "AXMenuExtra" else {
                continue
            }

            let identifier = copyStringAttribute(element, kAXIdentifierAttribute as CFString)
            let frame = accessibilityFrame(of: element)
            let label = firstUsefulString(
                copyStringAttribute(element, kAXTitleAttribute as CFString),
                copyStringAttribute(element, kAXDescriptionAttribute as CFString),
                copyStringAttribute(element, kAXHelpAttribute as CFString)
            )
            let name = MenuExtraClassifier.displayName(
                identifier: identifier,
                label: label,
                ownerName: application.localizedName ?? bundleIdentifier
            )
            let id = identifier.map { "\(bundleIdentifier)::\($0)" }
                ?? "\(bundleIdentifier)::visible:\(Int(frame?.midX ?? CGFloat(x)))"
            guard sampledIDs.insert(id).inserted else { continue }

            results.append(
                MenuBarItemModel(
                    id: id,
                    ownerBundleIdentifier: bundleIdentifier,
                    ownerPID: pid,
                    itemIdentifier: identifier,
                    itemIndex: 0,
                    name: name,
                    symbolName: MenuExtraClassifier.symbolName(
                        identifier: identifier,
                        label: name,
                        ownerBundleIdentifier: bundleIdentifier
                    ),
                    ownerIcon: copiedIcon(from: application),
                    compactValue: MenuExtraClassifier.compactValue(from: label),
                    accessibilityFrame: frame,
                    xPosition: frame?.minX ?? CGFloat(x)
                )
            )
        }

        return results
    }

    private func collectMenuBarItems(from root: AXUIElement) -> [AXUIElement] {
        var stack: [(AXUIElement, Int)] = [(root, 0)]
        var visited = Set<CFHashCode>()
        var results: [AXUIElement] = []

        while let (element, depth) = stack.popLast(), results.count < 128, visited.count < 512 {
            guard depth <= 10 else { continue }
            let identity = CFHash(element)
            guard visited.insert(identity).inserted else { continue }

            let role = copyStringAttribute(element, kAXRoleAttribute as CFString)
            if role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem" {
                results.append(element)
                continue
            }

            for child in copyChildren(of: element).reversed() {
                stack.append((child, depth + 1))
            }
        }

        return results
    }

    private func copyChildren(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }
        return Array(children.prefix(128))
    }

    private func copyElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        if let string = value as? String { return string }
        if let attributedString = value as? NSAttributedString { return attributedString.string }
        return nil
    }

    private func accessibilityFrame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        let positionAXValue = unsafeBitCast(positionValue, to: AXValue.self)
        let sizeAXValue = unsafeBitCast(sizeValue, to: AXValue.self)
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func resolvedBundleIdentifier(for application: NSRunningApplication) -> String? {
        if let bundleIdentifier = application.bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }
        if let bundleURL = application.bundleURL {
            if let bundleIdentifier = Bundle(url: bundleURL)?.bundleIdentifier,
               !bundleIdentifier.isEmpty {
                return bundleIdentifier
            }
        }
        if var candidateURL = application.executableURL?.deletingLastPathComponent() {
            while candidateURL.path != "/" {
                if candidateURL.pathExtension == "app",
                   let bundleIdentifier = Bundle(url: candidateURL)?.bundleIdentifier,
                   !bundleIdentifier.isEmpty {
                    return bundleIdentifier
                }
                candidateURL.deleteLastPathComponent()
            }
        }
        return nil
    }

    private func copiedIcon(from application: NSRunningApplication) -> NSImage? {
        if let resource = application.bundleIdentifier.flatMap({
            MenuExtraClassifier.dedicatedOwnerIconResource(ownerBundleIdentifier: $0)
        }),
           let bundleURL = application.bundleURL,
           let resourceURL = Bundle(url: bundleURL)?.url(
               forResource: resource.name,
               withExtension: resource.fileExtension
           ),
           let dedicatedIcon = NSImage(contentsOf: resourceURL) {
            dedicatedIcon.size = NSSize(width: 28, height: 28)
            dedicatedIcon.isTemplate = false
            return dedicatedIcon
        }

        guard let icon = application.icon else { return nil }
        let copy = (icon.copy() as? NSImage) ?? icon
        copy.size = NSSize(width: 28, height: 28)
        return copy
    }

    private func firstUsefulString(_ values: String?...) -> String? {
        values.compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }

    private func isKnownSystemOwner(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.apple.controlcenter" || bundleIdentifier == "com.apple.systemuiserver"
    }

    private func isKnownHiddenOwner(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return HiddenMenuBarOwnerCatalog.owner(for: bundleIdentifier) != nil
    }

    private func postClick(at point: CGPoint) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let mouseDown = CGEvent(
                  mouseEventSource: source,
                  mouseType: .leftMouseDown,
                  mouseCursorPosition: point,
                  mouseButton: .left
              ),
              let mouseUp = CGEvent(
                  mouseEventSource: source,
                  mouseType: .leftMouseUp,
                  mouseCursorPosition: point,
                  mouseButton: .left
              ) else {
            return false
        }
        mouseDown.post(tap: CGEventTapLocation.cghidEventTap)
        mouseUp.post(tap: CGEventTapLocation.cghidEventTap)
        return true
    }
}
