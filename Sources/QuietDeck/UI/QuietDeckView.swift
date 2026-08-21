import SwiftUI
import UniformTypeIdentifiers

struct QuietDeckView: View {
    @ObservedObject var store: ShelfStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            deckShape
                .fill(.ultraThinMaterial)
                .overlay {
                    deckShape
                        .fill(
                            Color.black.opacity(store.isPresented ? 0.42 : 0.88)
                        )
                }
                .overlay {
                    deckShape
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(store.isPresented ? 0.11 : 0.025),
                                    .clear,
                                    .black.opacity(store.isPresented ? 0.12 : 0.05)
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
                                    .white.opacity(store.isPresented ? 0.24 : 0.12),
                                    .white.opacity(store.isPresented ? 0.035 : 0.025)
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
            color: .black.opacity(store.isPresented ? 0.30 : 0.16),
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
            .fill(.white.opacity(0.11))
            .frame(width: 1, height: 30)
    }

    private var shouldShowMenuSection: Bool {
        !store.accessibilityGranted || !store.menuItems.isEmpty
    }

    @ViewBuilder
    private var selectedMenuContent: some View {
        Group {
            if !store.accessibilityGranted {
                permissionButton
            } else if store.menuItems.isEmpty {
                emptyScanButton
            } else if !store.selectedMenuItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    menuButtons(store.selectedMenuItems, presentation: .nativeStrip)
                        .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            } else {
                Label("Choose menu-bar items", systemImage: "checklist")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
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
                    NSItemProvider(object: item.selectionID as NSString)
                }
                .onDrop(
                    of: [.plainText],
                    delegate: MenuBarItemReorderDropDelegate(
                        targetID: item.selectionID,
                        store: store
                    )
                )
            }
        }
    }

    private var permissionButton: some View {
        Button {
            store.requestAccessibility()
        } label: {
            Label("Open menu access", systemImage: "hand.raised.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.1))
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
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .help(store.menuAccessDiagnostic)
    }

}

private struct MenuBarItemReorderDropDelegate: DropDelegate {
    let targetID: String
    let store: ShelfStore

    func dropEntered(info: DropInfo) {
        loadDraggedID(from: info) { draggedID in
            store.moveSelectedMenuItem(draggedID, before: targetID)
        }
    }

    func performDrop(info: DropInfo) -> Bool { true }

    private func loadDraggedID(from info: DropInfo, completion: @escaping (String) -> Void) {
        guard let provider = info.itemProviders(for: [.plainText]).first else { return }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let id = object as? String else { return }
            Task { @MainActor in completion(id) }
        }
    }
}
