import SwiftUI
import UniformTypeIdentifiers

struct ClipboardShelfView: View {
    @ObservedObject var store: ShelfStore
    @State private var isDropTargeted = false

    var body: some View {
        shelfContent
        .onDrop(
            of: [.fileURL, .image, .plainText],
            isTargeted: $isDropTargeted,
            perform: store.importClipboardProviders
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Visual clipboard")
    }

    private var shelfContent: some View {
        Group {
            if store.clipboardItems.count > 3 {
                ScrollView(.horizontal, showsIndicators: false) {
                    clipboardCards
                }
                .scrollClipDisabled()
            } else {
                clipboardCards
            }
        }
        .frame(width: store.clipboardItems.isEmpty ? 116 : min(CGFloat(store.clipboardItems.count), 3) * 98)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    .white.opacity(isDropTargeted ? 0.42 : 0),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        }
    }

    @ViewBuilder
    private var clipboardCards: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 7) {
                clipboardCardRow
            }
        } else {
            clipboardCardRow
        }
    }

    private var clipboardCardRow: some View {
        HStack(spacing: 7) {
            if store.clipboardItems.isEmpty {
                emptyDropCard
            } else {
                ForEach(store.clipboardItems) { item in
                    clipboardCard(item)
                }
            }
        }
        .padding(.horizontal, 3)
    }

    @ViewBuilder
    private func clipboardCard(_ item: ClipboardItem) -> some View {
        ClipboardItemCard(
            item: item,
            copy: { store.copyClipboardItem(item) },
            remove: { store.removeClipboardItem(item) },
            clear: store.clearClipboardHistory
        )
        .onDrag { item.itemProvider() }
    }

    private var emptyDropCard: some View {
        Label("Drop to save", systemImage: "square.and.arrow.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.68))
            .frame(width: 110, height: 42)
            .modifier(
                ClipboardGlassSurface(
                    isInteractive: false,
                    isHighlighted: isDropTargeted
                )
            )
    }
}

private struct ClipboardItemCard: View {
    let item: ClipboardItem
    let copy: () -> Void
    let remove: () -> Void
    let clear: () -> Void
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        Button {
            copy()
            didCopy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                didCopy = false
            }
        } label: {
            HStack(spacing: 7) {
                preview
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(didCopy ? "Copied" : item.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                    Text(didCopy ? "Ready to paste" : item.detail)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 7)
            .frame(width: 92, height: 42)
            .modifier(
                ClipboardGlassSurface(
                    isInteractive: true,
                    isHighlighted: isHovering || didCopy
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Copy \(item.title) to the clipboard")
        .accessibilityLabel("Copy \(item.title)")
        .contextMenu {
            Button("Copy to Clipboard", action: copy)
            Button("Remove", action: remove)
            Divider()
            Button("Clear Clipboard History", action: clear)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = item.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: item.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.07))
                )
        }
    }
}

private struct ClipboardGlassSurface: ViewModifier {
    let isInteractive: Bool
    let isHighlighted: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(
                isInteractive
                    ? Glass.clear
                        .tint(.white.opacity(isHighlighted ? 0.085 : 0.015))
                        .interactive()
                    : Glass.clear
                        .tint(.white.opacity(isHighlighted ? 0.085 : 0.015)),
                in: shape
            )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(
                    shape.fill(.white.opacity(isHighlighted ? 0.075 : 0.018))
                )
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHighlighted ? 0.22 : 0.10),
                                .white.opacity(0.025)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.65
                    )
                }
                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
        }
    }
}
