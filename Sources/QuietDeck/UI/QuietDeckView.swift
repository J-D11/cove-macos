import SwiftUI
import UniformTypeIdentifiers

struct QuietDeckView: View {
    @ObservedObject var store: ShelfStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var activeModule: SideWingModule = .clipboard
    @State private var isRailDropTargeted = false

    private var layoutMetrics: SideWingLayoutMetrics {
        SideWingGeometry.metrics(for: store.sideWingLayoutMode)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if store.isPresented {
                presentedWing
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            } else {
                edgeHandle
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .compositingGroup()
        .animation(
            reduceMotion
                ? nil
                : (store.isPresented
                    ? .smooth(duration: 0.24, extraBounce: 0)
                    : .easeOut(duration: 0.16)),
            value: store.isPresented
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cove")
    }

    @ViewBuilder
    private var presentedWing: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                presentedLayers
            }
        } else {
            presentedLayers
        }
    }

    private var presentedLayers: some View {
        ZStack(alignment: .topTrailing) {
            moduleFlyout
                .frame(
                    width: layoutMetrics.flyoutWidth,
                    height: activeFlyoutHeight
                )
                .padding(.trailing, layoutMetrics.flyoutTrailingInset)
                .padding(.top, activeFlyoutTopInset)
                .zIndex(0)

            rail
                .frame(width: layoutMetrics.railWidth)
                .zIndex(1)
        }
    }

    @ViewBuilder
    private var moduleFlyout: some View {
        if resolvedActiveModule == .clipboard {
            flyoutCore
        } else {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            Group {
                if reduceTransparency {
                    flyoutCore
                        .background {
                            shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
                        }
                        .overlay {
                            shape.strokeBorder(.white.opacity(0.30), lineWidth: 0.8)
                        }
                } else if #available(macOS 26.0, *) {
                    flyoutCore
                        .glassEffect(
                            Glass.regular.tint(
                                .white.opacity(store.enhancedGlassContrast ? 0.10 : 0.045)
                            ),
                            in: shape
                        )
                        .overlay {
                            shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.7)
                        }
                } else {
                    flyoutCore
                        .background {
                            shape.fill(.regularMaterial)
                        }
                        .overlay {
                            shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.7)
                        }
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 16, x: -5, y: 6)
        }
    }

    private var flyoutCore: some View {
        activeFlyoutContent
            .id(resolvedActiveModule)
            .padding(
                resolvedActiveModule == .clipboard
                    ? 0
                    : layoutMetrics.flyoutContentInset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                )
            )
    }

    @ViewBuilder
    private var activeFlyoutContent: some View {
        Group {
            switch resolvedActiveModule {
            case .nowPlaying:
                if let nowPlaying = store.nowPlaying {
                    SideWingNowPlayingView(
                        item: nowPlaying,
                        onOpen: store.openNowPlaying,
                        onCommand: store.performNowPlayingCommand
                    )
                } else {
                    selectedMenuContent
                }
            case .clipboard:
                if store.showsVisualClipboard {
                    SideWingClipboardView(
                        store: store,
                        itemListHeight: layoutMetrics.clipboardListHeight
                    )
                } else {
                    selectedMenuContent
                }
            case .apps:
                selectedMenuContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activeFlyoutHeight: CGFloat {
        switch resolvedActiveModule {
        case .nowPlaying:
            return layoutMetrics.nowPlayingFlyoutHeight
        case .clipboard:
            return layoutMetrics.clipboardFlyoutHeight
        case .apps:
            return layoutMetrics.appsFlyoutHeight
        }
    }

    private var activeFlyoutTopInset: CGFloat {
        switch resolvedActiveModule {
        case .nowPlaying:
            return 12
        case .clipboard:
            return hasNowPlayingModule ? 62 : 12
        case .apps:
            return hasNowPlayingModule ? 166 : 116
        }
    }

    private var resolvedActiveModule: SideWingModule {
        switch activeModule {
        case .nowPlaying where !hasNowPlayingModule:
            return store.showsVisualClipboard ? .clipboard : .apps
        case .clipboard where !store.showsVisualClipboard:
            return hasNowPlayingModule ? .nowPlaying : .apps
        default:
            return activeModule
        }
    }

    private var hasNowPlayingModule: Bool {
        store.showsNowPlaying && store.nowPlaying != nil
    }

    @ViewBuilder
    private var rail: some View {
        let shape = SideRailShape()
        Group {
            if reduceTransparency {
                railContent
                    .background {
                        shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
                    }
                    .overlay {
                        shape.stroke(.white.opacity(0.29), lineWidth: 0.8)
                    }
            } else if #available(macOS 26.0, *) {
                railContent
                    .glassEffect(
                        Glass.regular.tint(
                            .white.opacity(store.enhancedGlassContrast ? 0.11 : 0.05)
                        ),
                        in: shape
                    )
                    .overlay {
                        shape.stroke(.white.opacity(0.24), lineWidth: 0.7)
                    }
            } else {
                railContent
                    .background {
                        shape.fill(.regularMaterial)
                    }
                    .overlay {
                        shape.stroke(.white.opacity(0.21), lineWidth: 0.7)
                    }
            }
        }
        .frame(maxHeight: .infinity)
        .shadow(color: .black.opacity(0.24), radius: 15, x: -4, y: 5)
    }

    private var railContent: some View {
        VStack(spacing: 8) {
            if let nowPlaying = store.nowPlaying, store.showsNowPlaying {
                SideRailControl(
                    isSelected: resolvedActiveModule == .nowPlaying,
                    label: "Now Playing",
                    action: { selectModule(.nowPlaying) }
                ) {
                    railNowPlayingArtwork(nowPlaying)
                }
            }

            if store.showsVisualClipboard {
                SideRailControl(
                    isSelected: resolvedActiveModule == .clipboard,
                    label: "Clipboard",
                    action: { selectModule(.clipboard) }
                ) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            resolvedActiveModule == .clipboard
                                ? Color.white
                                : Color.primary.opacity(0.88)
                        )
                }
            }

            SideRailControl(
                isSelected: store.keepOpen,
                label: store.keepOpen ? "Unpin Cove" : "Pin Cove open",
                action: togglePinnedState
            ) {
                Image(nsImage: CoveMark.image(size: 21))
                    .renderingMode(.template)
                    .foregroundStyle(Color(red: 0.17, green: 0.50, blue: 1.0))
            }

            Rectangle()
                .fill(.primary.opacity(0.13))
                .frame(width: 26, height: 1)
                .padding(.vertical, 2)

            SideRailControl(
                isSelected: resolvedActiveModule == .apps,
                label: "Apps and menu items",
                action: { selectModule(.apps) }
            ) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        resolvedActiveModule == .apps
                            ? Color.white
                            : Color.primary.opacity(0.84)
                    )
            }

            railMenuItems

            Spacer(minLength: 2)

            railManagementMenu

            railDropTarget
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.trailing, SideWingGeometry.trailingOverflow)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var railMenuItems: some View {
        if !store.selectedCoveExtraMenuItems.isEmpty
            || !store.unavailableSelectedCoveExtraMenuItems.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(store.selectedCoveExtraMenuItems) { item in
                        MenuBarItemButton(item: item, presentation: .rail) {
                            store.activate(item)
                        }
                        .onDrag {
                            store.beginMenuItemReordering(item.selectionID)
                            return NSItemProvider(object: item.selectionID as NSString)
                        } preview: {
                            Color.clear.frame(width: 2, height: 2)
                        }
                        .onDrop(
                            of: [.plainText],
                            delegate: MenuBarItemReorderDropDelegate(
                                targetID: item.selectionID,
                                store: store,
                                animation: reduceMotion
                                    ? nil
                                    : .smooth(duration: 0.20, extraBounce: 0)
                            )
                        )
                        .contextMenu {
                            Button("Move Up") {
                                withAnimation(.smooth(duration: 0.20, extraBounce: 0)) {
                                    store.moveMenuItem(item.selectionID, by: -1)
                                }
                            }
                            Button("Move Down") {
                                withAnimation(.smooth(duration: 0.20, extraBounce: 0)) {
                                    store.moveMenuItem(item.selectionID, by: 1)
                                }
                            }
                        }
                    }

                    ForEach(store.unavailableSelectedCoveExtraMenuItems) { item in
                        UnavailableMenuBarItemButton(
                            item: item,
                            repair: { store.repairMenuItem(item) },
                            remove: { store.removeUnavailableMenuItem(item) }
                        )
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxHeight: layoutMetrics.menuItemListMaximumHeight)
        }
    }

    private var railManagementMenu: some View {
        Menu {
            ForEach(store.coveExtraMenuItems) { item in
                Button {
                    store.toggleMenuItemSelection(item)
                } label: {
                    Label(
                        item.name,
                        systemImage: store.selectedMenuItemIDs.contains(item.selectionID)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }

            Divider()

            Button("Refresh Items") {
                store.refresh()
            }

            if !store.accessibilityGranted {
                Button("Open Accessibility Settings") {
                    store.openAccessibilitySettings()
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.primary.opacity(0.055)))
                .overlay {
                    Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 0.65)
                }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Manage Cove items")
        .accessibilityLabel("Manage Cove items")
    }

    private var railDropTarget: some View {
        VStack(spacing: 3) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 12, weight: .semibold))
            Text("Drop")
                .font(.system(size: 7.5, weight: .semibold))
        }
        .foregroundStyle(.primary.opacity(isRailDropTargeted ? 0.92 : 0.56))
        .frame(width: 40, height: 47)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(isRailDropTargeted ? 0.12 : 0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    .primary.opacity(isRailDropTargeted ? 0.38 : 0.13),
                    style: StrokeStyle(lineWidth: 0.7, dash: [3, 3])
                )
        }
        .onDrop(
            of: [.fileURL, .image, .plainText],
            isTargeted: $isRailDropTargeted,
            perform: store.importClipboardProviders
        )
        .accessibilityLabel("Drop to save in Cove")
    }

    @ViewBuilder
    private func railNowPlayingArtwork(_ item: NowPlayingItem) -> some View {
        if let image = item.artwork {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    resolvedActiveModule == .nowPlaying
                        ? Color.white
                        : Color.primary.opacity(0.88)
                )
        }
    }

    private func selectModule(_ module: SideWingModule) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.20, extraBounce: 0)) {
            activeModule = module
        }
    }

    private func togglePinnedState() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.18, extraBounce: 0)) {
            store.keepOpen.toggle()
            if store.keepOpen {
                store.reveal(for: 30)
            } else {
                store.dismissManualReveal()
            }
        }
    }

    private var edgeHandle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18, extraBounce: 0)) {
                store.keepOpen = true
                store.reveal(for: 30)
            }
        } label: {
            Image(nsImage: CoveMark.image(size: 18))
                .renderingMode(.template)
                .foregroundStyle(Color(red: 0.17, green: 0.50, blue: 1.0))
                .frame(
                    width: SideWingGeometry.edgeHandleWidth,
                    height: SideWingGeometry.edgeHandleHeight
                )
                .background(edgeHandleSurface)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: SideWingGeometry.edgeHandleHorizontalOffset)
        .help("Open Cove")
        .accessibilityLabel("Open Cove")
    }

    @ViewBuilder
    private var edgeHandleSurface: some View {
        let shape = SideEdgeHandleShape()
        if reduceTransparency {
            shape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
                .overlay {
                    shape.stroke(.white.opacity(0.30), lineWidth: 0.8)
                }
        } else if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(
                    Glass.regular.tint(.white.opacity(0.07)),
                    in: shape
                )
                .overlay {
                    shape.stroke(.white.opacity(0.26), lineWidth: 0.75)
                }
        } else {
            shape
                .fill(.regularMaterial)
                .overlay {
                    shape.stroke(.white.opacity(0.24), lineWidth: 0.75)
                }
        }
    }

    @ViewBuilder
    private var selectedMenuContent: some View {
        Group {
            if !store.accessibilityGranted {
                permissionButton
            } else if store.coveExtraMenuItems.isEmpty
                && store.unavailableSelectedCoveExtraMenuItems.isEmpty {
                emptyScanButton
            } else if !store.selectedCoveExtraMenuItems.isEmpty
                || !store.unavailableSelectedCoveExtraMenuItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        menuButtons(store.selectedCoveExtraMenuItems, presentation: .wingGrid)

                        ForEach(store.unavailableSelectedCoveExtraMenuItems) { item in
                            UnavailableMenuBarItemButton(
                                item: item,
                                repair: { store.repairMenuItem(item) },
                                remove: { store.removeUnavailableMenuItem(item) }
                            )
                        }

                        menuItemSelectionMenu(compact: true)
                    }
                    .padding(.horizontal, 2)
                }
            } else {
                menuItemSelectionMenu(compact: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func menuItemSelectionMenu(compact: Bool) -> some View {
        Menu {
            ForEach(store.coveExtraMenuItems) { item in
                Button {
                    store.toggleMenuItemSelection(item)
                } label: {
                    Label(
                        item.name,
                        systemImage: store.selectedMenuItemIDs.contains(item.selectionID)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }

            Divider()

            Button("Refresh Items") {
                store.refresh()
            }
        } label: {
            Group {
                if compact {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34)
                } else {
                    Label("Choose menu-bar items", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.primary.opacity(0.88))
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(0.08))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: compact, vertical: true)
        .help("Choose menu-bar items shown in Cove")
        .accessibilityLabel("Choose menu-bar items")
    }

    private func menuButtons(
        _ items: [MenuBarItemModel],
        presentation: MenuBarItemPresentation = .compact
    ) -> some View {
        HStack(spacing: 7) {
            ForEach(items) { item in
                MenuBarItemButton(item: item, presentation: presentation) {
                    store.activate(item)
                }
                .onDrag {
                    store.beginMenuItemReordering(item.selectionID)
                    return NSItemProvider(object: item.selectionID as NSString)
                } preview: {
                    Color.clear
                        .frame(width: 2, height: 2)
                }
                .onDrop(
                    of: [.plainText],
                    delegate: MenuBarItemReorderDropDelegate(
                        targetID: item.selectionID,
                        store: store,
                        animation: reduceMotion
                            ? nil
                            : .smooth(duration: 0.22, extraBounce: 0)
                    )
                )
                .overlay {
                    if store.keyboardReorderItemID == item.selectionID {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 1.4)
                            .padding(1)
                            .allowsHitTesting(false)
                    }
                }
                .contextMenu {
                    Button("Move Left") {
                        withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                            store.moveMenuItem(item.selectionID, by: -1)
                        }
                    }
                    Button("Move Right") {
                        withAnimation(.smooth(duration: 0.22, extraBounce: 0)) {
                            store.moveMenuItem(item.selectionID, by: 1)
                        }
                    }
                }
                .accessibilityAction(named: "Move Left") {
                    store.moveMenuItem(item.selectionID, by: -1)
                }
                .accessibilityAction(named: "Move Right") {
                    store.moveMenuItem(item.selectionID, by: 1)
                }
            }
        }
    }

    private var permissionButton: some View {
        HStack(spacing: 8) {
            Button {
                store.requestAccessibility()
            } label: {
                Label("Allow menu access", systemImage: "hand.raised.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.primary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .help("Ask macOS to allow Cove to discover and open menu-bar items")

            Button {
                store.openAccessibilitySettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.86))
                    .frame(width: 42, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.primary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .help("Open Accessibility settings")
            .accessibilityLabel("Open Accessibility settings")
        }
    }

    private var emptyScanButton: some View {
        Button {
            store.refresh()
        } label: {
            Label("Scan menu-bar items", systemImage: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .help(store.menuAccessDiagnostic)
    }
}

private struct SideWingNowPlayingView: View {
    let item: NowPlayingItem
    let onOpen: () -> Void
    let onCommand: (NowPlayingCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Now Playing")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.94))

            HStack(spacing: 14) {
                Button(action: onOpen) {
                    artwork
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 0.7)
                        }
                        .shadow(color: .black.opacity(0.34), radius: 9, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(item.externalURL == nil)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.97))
                        .lineLimit(2)

                    Text(item.artist ?? item.album ?? sourceLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.58))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 15)

            if item.source == .spotify {
                HStack(spacing: 34) {
                    playbackButton(symbol: "backward.fill", label: "Previous") {
                        onCommand(.previous)
                    }
                    playbackButton(
                        symbol: item.isPlaying == true ? "pause.fill" : "play.fill",
                        label: item.isPlaying == true ? "Pause" : "Play"
                    ) {
                        onCommand(.togglePlayback)
                    }
                    playbackButton(symbol: "forward.fill", label: "Next") {
                        onCommand(.next)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 15)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(
                        item.source == .spotify
                            ? Color(red: 0.10, green: 0.84, blue: 0.36)
                            : Color.accentColor
                    )
                    .frame(width: 8, height: 8)

                Text(sourceLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.52))
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .help(item.helpText)
        .accessibilityElement(children: .contain)
    }

    private var sourceLabel: String {
        item.source == .spotify ? "Spotify" : "Now Playing"
    }

    private func playbackButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary.opacity(0.90))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = item.artwork {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.34, green: 0.52, blue: 1.0),
                        Color(red: 0.08, green: 0.36, blue: 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "waveform")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
            }
        }
    }
}

private enum SideWingModule: Hashable {
    case nowPlaying
    case clipboard
    case apps
}

private struct SideRailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius = min(22, rect.width * 0.44)
        let waistDepth = min(6, rect.width * 0.12)
        let waistHalfHeight = min(25, rect.height * 0.075)
        let waistShoulder = min(17, rect.height * 0.055)
        let centerY = rect.midY

        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: centerY + waistHalfHeight + waistShoulder))
        path.addCurve(
            to: CGPoint(x: rect.minX + waistDepth, y: centerY + waistHalfHeight),
            control1: CGPoint(x: rect.minX, y: centerY + waistHalfHeight + 10),
            control2: CGPoint(x: rect.minX + waistDepth, y: centerY + waistHalfHeight + 9)
        )
        path.addLine(to: CGPoint(x: rect.minX + waistDepth, y: centerY - waistHalfHeight))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: centerY - waistHalfHeight - waistShoulder),
            control1: CGPoint(x: rect.minX + waistDepth, y: centerY - waistHalfHeight - 9),
            control2: CGPoint(x: rect.minX, y: centerY - waistHalfHeight - 10)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct SideEdgeHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width * 0.48, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct SideRailControl<Content: View>: View {
    let isSelected: Bool
    let label: String
    let action: () -> Void
    let content: Content
    @State private var isHovering = false

    init(
        isSelected: Bool,
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.label = label
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(
                        isSelected
                            ? Color.accentColor.opacity(0.92)
                            : Color.primary.opacity(isHovering ? 0.11 : 0.045)
                    )
                )
                .overlay {
                    Circle().strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.28)
                            : Color.primary.opacity(isHovering ? 0.18 : 0.08),
                        lineWidth: 0.7
                    )
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct MenuBarItemReorderDropDelegate: DropDelegate {
    let targetID: String
    let store: ShelfStore
    let animation: Animation?

    func dropEntered(info: DropInfo) {
        withAnimation(animation) {
            store.reorderDraggedMenuItem(over: targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        store.finishMenuItemReordering()
        return true
    }
}
