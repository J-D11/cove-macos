import AppKit
import Foundation

struct MenuBarItemModel: Identifiable {
    let id: String
    let ownerBundleIdentifier: String
    let ownerPID: pid_t
    let itemIdentifier: String?
    let itemIndex: Int
    let name: String
    let symbolName: String?
    let ownerIcon: NSImage?
    let compactValue: String?
    let accessibilityFrame: CGRect?
    let xPosition: CGFloat
    let isHiddenOwnerFallback: Bool
    var nativeSnapshot: NSImage? = nil

    init(
        id: String,
        ownerBundleIdentifier: String,
        ownerPID: pid_t,
        itemIdentifier: String?,
        itemIndex: Int,
        name: String,
        symbolName: String?,
        ownerIcon: NSImage?,
        compactValue: String?,
        accessibilityFrame: CGRect?,
        xPosition: CGFloat,
        isHiddenOwnerFallback: Bool = false,
        nativeSnapshot: NSImage? = nil
    ) {
        self.id = id
        self.ownerBundleIdentifier = ownerBundleIdentifier
        self.ownerPID = ownerPID
        self.itemIdentifier = itemIdentifier
        self.itemIndex = itemIndex
        self.name = name
        self.symbolName = symbolName
        self.ownerIcon = ownerIcon
        self.compactValue = compactValue
        self.accessibilityFrame = accessibilityFrame
        self.xPosition = xPosition
        self.isHiddenOwnerFallback = isHiddenOwnerFallback
        self.nativeSnapshot = nativeSnapshot
    }

    var selectionID: String {
        if let itemIdentifier, !itemIdentifier.isEmpty {
            return "\(ownerBundleIdentifier)::\(itemIdentifier)"
        }
        return "\(ownerBundleIdentifier)::\(name.lowercased())::\(itemIndex)"
    }

    var nativeDisplayWidth: CGFloat {
        guard let width = accessibilityFrame?.width, width > 1 else { return 32 }
        return min(max(width, 24), 92)
    }

    var prefersOwnerIconOverNativeSnapshot: Bool {
        MenuExtraClassifier.prefersOwnerIconOverNativeSnapshot(
            ownerBundleIdentifier: ownerBundleIdentifier
        )
    }

    var isCoveExtra: Bool {
        !MenuExtraClassifier.isRedundantSystemControl(
            identifier: itemIdentifier,
            label: name,
            ownerBundleIdentifier: ownerBundleIdentifier
        )
    }
}

struct UnavailableMenuBarItem: Identifiable {
    let id: String
    let name: String

    var ownerBundleIdentifier: String {
        id.split(separator: "::", maxSplits: 1).first.map(String.init) ?? id
    }

    var isCoveExtra: Bool {
        !MenuExtraClassifier.isRedundantSystemControl(
            identifier: id,
            label: name,
            ownerBundleIdentifier: ownerBundleIdentifier
        )
    }
}

struct NowPlayingItem {
    enum Source {
        case system
        case spotify
    }

    let title: String
    let artist: String?
    let album: String?
    let artwork: NSImage?
    let source: Source
    let isPlaying: Bool?
    let externalURL: URL?

    init(
        title: String,
        artist: String?,
        album: String?,
        artwork: NSImage?,
        source: Source = .system,
        isPlaying: Bool? = nil,
        externalURL: URL? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.source = source
        self.isPlaying = isPlaying
        self.externalURL = externalURL
    }

    var helpText: String {
        var parts = [title]
        for candidate in [artist, album] {
            if let candidate, !candidate.isEmpty, !parts.contains(candidate) {
                parts.append(candidate)
            }
        }
        return parts.joined(separator: " · ")
    }
}

enum NowPlayingCommand {
    case previous
    case togglePlayback
    case next
}
