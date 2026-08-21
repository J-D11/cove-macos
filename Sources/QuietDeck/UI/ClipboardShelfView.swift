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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text("Clipboard")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Spacer(minLength: 6)

                if !store.clipboardItems.isEmpty {
                    Text("\(store.clipboardItems.count) items")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity)

            if store.clipboardItems.count > 3 {
                ScrollView(.horizontal, showsIndicators: false) {
                    clipboardCards
                }
                .scrollClipDisabled()
            } else {
                clipboardCards
            }
        }
        .frame(
            width: store.clipboardItems.isEmpty
                ? 116
                : min(CGFloat(store.clipboardItems.count), 3) * 116 + 8,
            alignment: .leading
        )
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.white.opacity(isDropTargeted ? 0.08 : 0.025))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            .white.opacity(isDropTargeted ? 0.42 : 0.06),
                            lineWidth: 0.65
                        )
                }
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
            .frame(width: 110, height: 38)
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
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    preview
                        .frame(width: 25, height: 27)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.previewTitle)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .truncationMode(.tail)

                        Text(item.detail)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.54))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 7)

                if didCopy {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.green)
                        .background(Circle().fill(.black.opacity(0.78)))
                }
            }
            .frame(width: 112, height: 42)
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
        .accessibilityLabel("Copy \(item.previewTitle)")
        .accessibilityValue(item.detail)
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
