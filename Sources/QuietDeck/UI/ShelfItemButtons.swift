import SwiftUI

enum MenuBarItemPresentation {
    case compact
    case nativeStrip
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
                }
            }
            .frame(height: 42)
            .background(
                RoundedRectangle(
                    cornerRadius: presentation == .nativeStrip ? 7 : 11,
                    style: .continuous
                )
                .fill(
                    .white.opacity(
                        isHovering
                            ? (presentation == .nativeStrip ? 0.11 : 0.12)
                            : (presentation == .nativeStrip ? 0.025 : 0)
                    )
                )
            )
            .overlay {
                if presentation == .nativeStrip {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            .white.opacity(isHovering ? 0.16 : 0.055),
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

    private var compactContent: some View {
        HStack(spacing: 5) {
            itemIcon
                .frame(width: 28, height: 28)

            if let compactValue = item.compactValue {
                Text(compactValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .padding(.horizontal, item.compactValue == nil ? 5 : 8)
    }

    @ViewBuilder
    private var nativeStripContent: some View {
        if let snapshot = item.nativeSnapshot {
            Image(nsImage: snapshot)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: item.nativeDisplayWidth + 4, height: 24)
                .padding(.horizontal, 2)
        } else if let metricName = metricName {
            HStack(spacing: 5) {
                itemIcon
                    .frame(width: 18, height: 18)
                Text(metricName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 3)
        } else {
            itemIcon
                .frame(width: 18, height: 18)
                .padding(.horizontal, 3)
        }
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
                .font(.system(size: presentation == .nativeStrip ? 16 : 18, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.white.opacity(0.94))
        } else if let ownerIcon = item.ownerIcon {
            Image(nsImage: ownerIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))
        }
    }
}
