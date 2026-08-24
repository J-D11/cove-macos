import SwiftUI
import UniformTypeIdentifiers

struct QuietDeckView: View {
    @ObservedObject var store: ShelfStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .bottom) {
            deckSurface
                .overlay {
                    deckShape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(
                                        store.isPresented
                                            ? (store.enhancedGlassContrast ? 0.22 : 0.15)
                                            : 0.04
                                    ),
                                    .clear,
                                    .white.opacity(
                                        store.isPresented
                                            ? (store.enhancedGlassContrast ? 0.05 : 0.025)
                                            : 0.01
                                    )
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    deckShape
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(
                                        store.isPresented
                                            ? (store.enhancedGlassContrast ? 0.48 : 0.34)
                                            : 0.18
                                    ),
                                    .white.opacity(store.isPresented ? 0.07 : 0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: store.isPresented ? 0.8 : 0.6
                        )
                }
            if store.isPresented {
                content
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.975, anchor: .top)
                            ),
                            removal: .opacity
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .compositingGroup()
        .clipShape(deckShape)
        .shadow(
            color: .black.opacity(store.isPresented ? 0.22 : 0.12),
            radius: store.isPresented ? 18 : 5,
            y: store.isPresented ? 7 : 2
        )
        .animation(
            reduceMotion
                ? nil
                : (store.isPresented
                    ? .smooth(duration: 0.18, extraBounce: 0)
                    : .easeOut(duration: 0.10)),
            value: store.isPresented
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cove")
    }

    @ViewBuilder
    private var deckSurface: some View {
        if reduceTransparency {
            deckShape
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.97))
        } else if #available(macOS 26.0, *) {
            deckShape
                .fill(.clear)
                .glassEffect(
                    Glass.regular
                        .tint(
                            .white.opacity(
                                store.isPresented
                                    ? (store.enhancedGlassContrast ? 0.12 : 0.07)
                                    : 0.02
                            )
                        ),
                    in: deckShape
                )
        } else {
            deckShape
                .fill(.regularMaterial)
        }
    }

    private var deckShape: RoundedRectangle {
        // A stable shape lets the window resize supply the corner morph. SwiftUI
        // naturally caps the radius as the collapsed shelf approaches 7 points.
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    private var content: some View {
        HStack(spacing: 8) {
            if store.showsNowPlaying, let nowPlaying = store.nowPlaying {
                NowPlayingArtworkView(
                    item: nowPlaying,
                    onOpen: store.openNowPlaying,
                    onCommand: store.performNowPlayingCommand
                )
            }

            if store.showsNowPlaying,
               store.nowPlaying != nil,
               (store.showsVisualClipboard || shouldShowMenuSection) {
                sectionDivider
            }

            if store.showsVisualClipboard {
                ClipboardShelfView(store: store)
            }

            if store.showsVisualClipboard, shouldShowMenuSection {
                sectionDivider
            } else if store.showsNowPlaying,
                      store.nowPlaying != nil,
                      !store.showsVisualClipboard,
                      shouldShowMenuSection {
                sectionDivider
            }

            selectedMenuContent
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.14))
            .frame(width: 1, height: 30)
    }

    private var shouldShowMenuSection: Bool {
        !store.accessibilityGranted
            || !store.menuItems.isEmpty
            || !store.unavailableSelectedMenuItems.isEmpty
    }

    @ViewBuilder
    private var selectedMenuContent: some View {
        Group {
            if !store.accessibilityGranted {
                permissionButton
            } else if store.menuItems.isEmpty && store.unavailableSelectedMenuItems.isEmpty {
                emptyScanButton
            } else if !store.selectedMenuItems.isEmpty || !store.unavailableSelectedMenuItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        menuButtons(store.selectedMenuItems, presentation: .nativeStrip)

                        ForEach(store.unavailableSelectedMenuItems) { item in
                            UnavailableMenuBarItemButton(
                                item: item,
                                repair: { store.repairMenuItem(item) },
                                remove: { store.removeUnavailableMenuItem(item) }
                            )
                        }
                    }
                        .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            } else {
                    Label("Choose menu-bar items", systemImage: "checklist")
                        .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.68))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func menuButtons(
        _ items: [MenuBarItemModel],
        presentation: MenuBarItemPresentation = .compact
    ) -> some View {
        HStack(spacing: presentation == .nativeStrip ? 7 : 8) {
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        Button {
            store.requestAccessibility()
        } label: {
            Label("Open menu access", systemImage: "hand.raised.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.92))
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .help("Allow Cove to discover and open menu-bar items")
    }

    private var emptyScanButton: some View {
        Button {
            store.refresh()
        } label: {
            Label("Scan again", systemImage: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.92))
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .help(store.menuAccessDiagnostic)
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
