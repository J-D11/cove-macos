import SwiftUI

enum MenuBarItemPresentation {
    case compact
    case nativeStrip
    case wingGrid
    case rail
}

struct MenuBarItemButton: View {
    let item: MenuBarItemModel
    let presentation: MenuBarItemPresentation
    let action: () -> Void
    @State private var isHovering = false

    init(
        item: MenuBarItemModel,
        presentation: MenuBarItemPresentation = .compact,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.presentation = presentation
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                switch presentation {
                case .compact:
                    compactContent
                case .nativeStrip:
                    nativeStripContent
                case .wingGrid:
                    wingGridContent
                case .rail:
                    railContent
                }
            }
            .frame(width: controlWidth, height: controlHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(
                    .primary.opacity(
                        isHovering ? hoverFillOpacity : restingFillOpacity
                    )
                )
            )
            .overlay {
                if presentation == .nativeStrip {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            .primary.opacity(isHovering ? 0.17 : 0),
                            lineWidth: 0.6
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(item.name)
        .accessibilityLabel(item.name)
    }

    private var controlWidth: CGFloat? {
        switch presentation {
        case .compact, .nativeStrip:
            return nil
        case .wingGrid:
            return 44
        case .rail:
            return 40
        }
    }

    private var controlHeight: CGFloat {
        switch presentation {
        case .nativeStrip:
            return 38
        case .compact:
            return 42
        case .wingGrid:
            return 60
        case .rail:
            return 40
        }
    }

    private var cornerRadius: CGFloat {
        switch presentation {
        case .nativeStrip:
            return 7
        case .rail:
            return 20
        case .compact, .wingGrid:
            return 11
        }
    }

    private var hoverFillOpacity: Double {
        switch presentation {
        case .nativeStrip:
            return 0.11
        case .compact:
            return 0.12
        case .wingGrid:
            return 0
        case .rail:
            return 0.12
        }
    }

    private var restingFillOpacity: Double {
        0
    }

    private var compactContent: some View {
        HStack(spacing: 5) {
            itemIcon
                .frame(width: 28, height: 28)

            if let compactValue = item.compactValue {
                Text(compactValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
            }
        }
        .padding(.horizontal, item.compactValue == nil ? 5 : 8)
    }

    @ViewBuilder
    private var nativeStripContent: some View {
        if !item.prefersOwnerIconOverNativeSnapshot, let snapshot = item.nativeSnapshot {
            Image(nsImage: snapshot)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: item.nativeDisplayWidth + 4, height: 28)
                .padding(.horizontal, 1)
        } else if let metricName = metricName {
            HStack(spacing: 5) {
                itemIcon
                    .frame(width: 19, height: 19)
                Text(metricName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .padding(.horizontal, 2)
        } else {
            itemIcon
                .frame(width: 22, height: 22)
                .padding(.horizontal, 3)
        }
    }

    private var wingGridContent: some View {
        VStack(spacing: 3) {
            itemIcon
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(isHovering ? 0.11 : 0.045))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            .primary.opacity(isHovering ? 0.17 : 0.08),
                            lineWidth: 0.6
                        )
                }

            if showsWingLabel {
                Text(item.name)
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.60))
                    .lineLimit(1)
                    .frame(maxWidth: 52)
            } else {
                Color.clear
                    .frame(height: 9)
            }
        }
    }

    private var railContent: some View {
        itemIcon
            .frame(width: 22, height: 22)
            .frame(width: 40, height: 40)
            .overlay {
                Circle()
                    .strokeBorder(
                        .primary.opacity(isHovering ? 0.18 : 0.07),
                        lineWidth: 0.65
                    )
            }
    }

    private var showsWingLabel: Bool {
        !item.ownerBundleIdentifier.hasPrefix("com.apple.")
    }

    private var metricName: String? {
        let candidate = item.name.split(separator: ":", maxSplits: 1).first.map(String.init) ?? item.name
        let recognized = ["CPU", "GPU", "RAM", "Disk", "Sensors", "Network"]
        return recognized.contains(candidate) ? candidate : nil
    }

    @ViewBuilder
    private var itemIcon: some View {
        if let symbolName = item.symbolName {
            Image(systemName: symbolName)
                .font(
                    .system(
                        size: symbolIconSize,
                        weight: .semibold
                    )
                )
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary.opacity(0.94))
        } else if let ownerIcon = item.ownerIcon {
            Image(nsImage: ownerIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.94))
        }
    }

    private var symbolIconSize: CGFloat {
        switch presentation {
        case .wingGrid, .rail:
            return 21
        case .nativeStrip:
            return 19
        case .compact:
            return 18
        }
    }
}

struct UnavailableMenuBarItemButton: View {
    let item: UnavailableMenuBarItem
    let repair: () -> Void
    let remove: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: repair) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.primary.opacity(isHovering ? 0.11 : 0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(.orange.opacity(isHovering ? 0.52 : 0.24), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("\(item.name) is unavailable. Open its app and rescan.")
        .accessibilityLabel("\(item.name), unavailable")
        .accessibilityHint("Opens the app and rescans menu-bar items")
        .contextMenu {
            Button("Open App and Rescan", action: repair)
            Button("Remove from Cove", action: remove)
        }
    }
}
