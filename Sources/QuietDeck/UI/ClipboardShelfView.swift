import SwiftUI
import UniformTypeIdentifiers

struct ClipboardShelfView: View {
    @ObservedObject var store: ShelfStore
    @State private var isDropTargeted = false
    @FocusState private var isSearchFocused: Bool

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
                    .foregroundStyle(.primary.opacity(0.72))

                ZStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        Text("Clipboard")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.88))
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 6)

                        if store.filteredClipboardItems.count > 1 {
                            Text(itemCountLabel)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.52))
                        }
                    }
                    .opacity(store.isClipboardSearchPresented ? 0 : 1)
                    .scaleEffect(
                        store.isClipboardSearchPresented ? 0.98 : 1,
                        anchor: .leading
                    )

                    TextField("Search", text: $store.clipboardSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9.5, weight: .medium))
                        .focused($isSearchFocused)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(.primary.opacity(0.07), in: Capsule())
                        .accessibilityLabel("Search clipboard history")
                        .opacity(store.isClipboardSearchPresented ? 1 : 0)
                        .scaleEffect(
                            store.isClipboardSearchPresented ? 1 : 0.98,
                            anchor: .leading
                        )
                        .allowsHitTesting(store.isClipboardSearchPresented)
                }
                .frame(maxWidth: .infinity)
                .animation(
                    .smooth(duration: 0.20, extraBounce: 0),
                    value: store.isClipboardSearchPresented
                )

                Button {
                    let willShowSearch = !store.isClipboardSearchPresented
                    withAnimation(.smooth(duration: 0.20, extraBounce: 0)) {
                        store.isClipboardSearchPresented = willShowSearch
                    }
                    if willShowSearch {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            isSearchFocused = true
                        }
                    } else {
                        isSearchFocused = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                            guard !store.isClipboardSearchPresented else { return }
                            store.clipboardSearchQuery = ""
                        }
                    }
                } label: {
                    Image(
                        systemName: store.isClipboardSearchPresented
                            ? "xmark"
                            : "magnifyingglass"
                    )
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(
                    store.isClipboardSearchPresented
                        ? "Close clipboard search"
                        : "Search clipboard history"
                )
                .accessibilityLabel(
                    store.isClipboardSearchPresented
                        ? "Close clipboard search"
                        : "Search clipboard history"
                )

                Menu {
                    Button("All Items") {
                        store.clipboardCollectionFilter = nil
                    }
                    Button("Saved") {
                        store.clipboardCollectionFilter = ShelfStore.savedCollectionFilter
                    }
                    if !store.clipboardCollections.isEmpty {
                        Divider()
                        ForEach(store.clipboardCollections, id: \.self) { collection in
                            Button(collection) {
                                store.clipboardCollectionFilter = collection
                            }
                        }
                    }
                } label: {
                    Image(
                        systemName: store.clipboardCollectionFilter == nil
                            ? "line.3.horizontal.decrease"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 18, height: 18)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Filter clipboard collections")

                Button {
                    store.undoClipboardChange()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!store.canUndoClipboardChange)
                .opacity(store.canUndoClipboardChange ? 1 : 0.28)
                .help("Undo clipboard deletion")
                .accessibilityLabel("Undo clipboard deletion")

                Button {
                    store.toggleClipboardCapturePaused()
                } label: {
                    Image(
                        systemName: store.clipboardCapturePaused
                            ? "play.fill"
                            : "pause.fill"
                    )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            store.clipboardCapturePaused
                                ? Color.orange
                                : Color.primary.opacity(0.52)
                        )
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(store.clipboardCapturePaused ? "Resume clipboard capture" : "Pause clipboard capture")
                .accessibilityLabel(
                    store.clipboardCapturePaused
                        ? "Resume clipboard capture"
                        : "Pause clipboard capture"
                )
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity)

            if store.filteredClipboardItems.count > 3 {
                ZStack(alignment: .trailing) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        clipboardCards
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.22)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 28)
                    .allowsHitTesting(false)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.58))
                        .padding(.trailing, 3)
                        .allowsHitTesting(false)
                }
            } else {
                clipboardCards
            }
        }
        .frame(
            width: shelfWidth,
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
            } else if store.filteredClipboardItems.isEmpty {
                noResultsCard
            } else {
                ForEach(Array(store.filteredClipboardItems.enumerated()), id: \.element.id) { index, item in
                    clipboardCard(item, shortcutNumber: index < 9 ? index + 1 : nil)
                }
            }
        }
        .padding(.horizontal, 3)
    }

    @ViewBuilder
    private func clipboardCard(_ item: ClipboardItem, shortcutNumber: Int?) -> some View {
        ClipboardItemCard(
            item: item,
            isSelected: store.selectedClipboardItem?.id == item.id,
            usesEnhancedContrast: store.enhancedGlassContrast,
            shortcutNumber: store.isClipboardShortcutHUDPresented ? shortcutNumber : nil,
            smartActions: store.smartActions(for: item),
            collections: store.clipboardCollections,
            copy: {
                store.selectClipboardItem(item)
                store.copyClipboardItem(item)
            },
            paste: { store.pasteClipboardItem(item) },
            pin: { store.toggleClipboardItemPinned(item) },
            performSmartAction: { store.performSmartAction($0, for: item) },
            assignCollection: { store.assignClipboardItem(item, toCollection: $0) },
            setExpiration: { date, afterPaste in
                store.setClipboardItemExpiration(
                    item,
                    expiresAt: date,
                    removesAfterPaste: afterPaste
                )
            },
            select: { store.selectClipboardItem(item) },
            remove: { store.removeClipboardItem(item) },
            clear: store.clearClipboardHistory
        )
    }

    private var emptyDropCard: some View {
        Label("Drop to save", systemImage: "square.and.arrow.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.68))
            .frame(width: shelfWidth - 6, height: 38)
            .modifier(
                ClipboardGlassSurface(
                    isInteractive: false,
                    isHighlighted: isDropTargeted,
                    isSelected: false,
                    usesEnhancedContrast: store.enhancedGlassContrast
                )
            )
    }

    private var noResultsCard: some View {
        Label("No matches", systemImage: "magnifyingglass")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.68))
            .frame(width: shelfWidth - 6, height: 38)
            .modifier(
                ClipboardGlassSurface(
                    isInteractive: false,
                    isHighlighted: false,
                    isSelected: false,
                    usesEnhancedContrast: store.enhancedGlassContrast
                )
            )
    }

    private var itemCountLabel: String {
        let count = store.filteredClipboardItems.count
        return count == 1 ? "1 item" : "\(count) items"
    }

    private var shelfWidth: CGFloat {
        ClipboardShelfLayout.width(
            itemCount: store.isClipboardSearchPresented
                ? store.clipboardItems.count
                : store.filteredClipboardItems.count,
            isSearchPresented: store.isClipboardSearchPresented
        )
    }
}

private struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let usesEnhancedContrast: Bool
    let shortcutNumber: Int?
    let smartActions: [ClipboardSmartAction]
    let collections: [String]
    let copy: () -> Void
    let paste: () -> Void
    let pin: () -> Void
    let performSmartAction: (ClipboardSmartAction) -> Void
    let assignCollection: (String?) -> Void
    let setExpiration: (Date?, Bool) -> Void
    let select: () -> Void
    let remove: () -> Void
    let clear: () -> Void
    @State private var isHovering = false
    @State private var isPreviewVisible = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Button(action: copy) {
                    cardContent
                }
                .buttonStyle(.plain)
                .onDrag { item.itemProvider() }
                .help("Copy \(item.title) to the clipboard")
                .accessibilityLabel("Copy \(item.previewTitle)")
                .accessibilityValue(item.previewDetail)

                Button(action: pin) {
                    Image(systemName: item.isPinned ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.96))
                        .frame(width: 20, height: 20)
                        .background(
                            Circle().fill(
                                item.isPinned
                                    ? Color.accentColor.opacity(0.94)
                                    : Color.black.opacity(0.68)
                            )
                        )
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.42), lineWidth: 0.7)
                        }
                        .frame(width: 32, height: 42)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help(item.isPinned ? "Remove from Saved" : "Save for Search")
                .accessibilityLabel(item.isPinned ? "Remove from Saved" : "Save for Search")
            }

            if let shortcutNumber {
                Text("⌘⌥\(shortcutNumber)")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(height: 14)
                    .background(Color.accentColor, in: Capsule())
                    .padding(3)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: 112, height: 42)
        .modifier(
            ClipboardGlassSurface(
                isInteractive: true,
                isHighlighted: isHovering,
                isSelected: isSelected,
                usesEnhancedContrast: usesEnhancedContrast
            )
        )
        .contentShape(Rectangle())
        .onHover {
            isHovering = $0
            if $0 {
                select()
            }
        }
        .popover(isPresented: $isPreviewVisible, arrowEdge: .bottom) {
            ClipboardItemPreview(item: item)
        }
        .contextMenu {
            Button("Copy to Clipboard", action: copy)
            Button("Paste Now", action: paste)
            Button("Preview", action: { isPreviewVisible = true })
            if !smartActions.isEmpty {
                Menu("Smart Actions") {
                    ForEach(smartActions) { action in
                        Button {
                            performSmartAction(action)
                        } label: {
                            Label(action.title, systemImage: action.symbolName)
                        }
                    }
                }
            }
            Menu("Collection") {
                Button("No Collection") { assignCollection(nil) }
                Divider()
                ForEach(collections, id: \.self) { collection in
                    Button(collection) { assignCollection(collection) }
                }
            }
            Menu("Delete Automatically") {
                Button("Never") { setExpiration(nil, false) }
                Button("After One Paste") { setExpiration(nil, true) }
                Button("In 10 Minutes") {
                    setExpiration(Date().addingTimeInterval(10 * 60), false)
                }
                Button("In One Hour") {
                    setExpiration(Date().addingTimeInterval(60 * 60), false)
                }
                Button("Tomorrow") {
                    setExpiration(Date().addingTimeInterval(24 * 60 * 60), false)
                }
            }
            Button(item.isPinned ? "Remove from Saved" : "Save for Search", action: pin)
            Button("Remove", action: remove)
            Divider()
            Button("Clear Clipboard History", action: clear)
        }
    }

    private var cardContent: some View {
        HStack(spacing: 6) {
            if item.image != nil || isFileItem {
                preview
                    .frame(width: 25, height: 27)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.previewTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)

                Text(item.previewDetail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.54))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var isFileItem: Bool {
        if case .files = item.content {
            return true
        }
        return false
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
                    .foregroundStyle(.primary.opacity(0.88))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.07))
                )
        }
    }
}

private struct ClipboardItemPreview: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(itemType, systemImage: item.symbolName)
                    .font(.headline)

                Spacer(minLength: 8)

                Text(item.ageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let sourceApplicationName = item.sourceApplicationName {
                Label("Copied from \(sourceApplicationName)", systemImage: "app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            previewContent
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
    }

    private var itemType: String {
        switch item.content {
        case .text:
            return "Text"
        case .richText:
            return "Rich Text"
        case .image:
            return "Image"
        case .files(let urls):
            return urls.count == 1 ? "File" : "\(urls.count) Files"
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.content {
        case .text(let text):
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 190)
        case .richText(let richText):
            ScrollView {
                Text(richText.plainText)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 190)
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 288, maxHeight: 210)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .files(let urls):
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(urls, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 20, height: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 190)
        }
    }
}

private struct ClipboardGlassSurface: ViewModifier {
    let isInteractive: Bool
    let isHighlighted: Bool
    let isSelected: Bool
    let usesEnhancedContrast: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        if reduceTransparency {
            content
                .background(
                    Color(nsColor: .windowBackgroundColor).opacity(0.97),
                    in: shape
                )
                .overlay {
                    shape.strokeBorder(
                        isSelected
                            ? Color.accentColor.opacity(0.72)
                            : Color.primary.opacity(0.18),
                        lineWidth: isSelected ? 1.2 : 0.7
                    )
                }
                .shadow(
                    color: isSelected ? Color.accentColor.opacity(0.22) : .clear,
                    radius: 7
                )
        } else if #available(macOS 26.0, *) {
            content.glassEffect(
                isInteractive
                    ? Glass.clear
                        .tint(
                            isSelected
                                ? Color.accentColor.opacity(0.16)
                                : Color.white.opacity(
                                    isHighlighted ? 0.10 : (usesEnhancedContrast ? 0.045 : 0.015)
                                )
                        )
                    : Glass.clear
                        .tint(.white.opacity(isHighlighted ? 0.10 : 0.015)),
                in: shape
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.24) : .clear,
                radius: 8
            )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(
                    shape.fill(
                        isSelected
                            ? Color.accentColor.opacity(0.10)
                            : Color.white.opacity(
                                isHighlighted ? 0.075 : (usesEnhancedContrast ? 0.04 : 0.018)
                            )
                    )
                )
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                isSelected
                                    ? Color.accentColor.opacity(0.65)
                                    : Color.white.opacity(isHighlighted ? 0.22 : 0.10),
                                .white.opacity(0.025)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: isSelected ? 1.1 : 0.65
                    )
                }
                .shadow(
                    color: isSelected
                        ? Color.accentColor.opacity(0.20)
                        : Color.black.opacity(0.08),
                    radius: isSelected ? 7 : 4,
                    y: 1
                )
        }
    }
}
