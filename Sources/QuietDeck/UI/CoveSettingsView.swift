import SwiftUI

struct CoveSettingsView: View {
    @ObservedObject var store: ShelfStore
    let checkForUpdates: () -> Void

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }

            clipboardSettings
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }

            privacySettings
                .tabItem { Label("Privacy", systemImage: "hand.raised") }

            updateSettings
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .padding(20)
        .frame(width: 560, height: 520)
    }

    private var generalSettings: some View {
        Form {
            Section("Shelf") {
                Toggle("Keep shelf open", isOn: $store.keepOpen)
                Toggle("Show Now Playing", isOn: $store.showsNowPlaying)
                Toggle("Show visual clipboard", isOn: $store.showsVisualClipboard)
                Toggle("Use stronger glass contrast", isOn: $store.enhancedGlassContrast)
            }

            Section("Per-App Profiles") {
                Toggle("Use different shelf layouts by app", isOn: $store.perAppProfilesEnabled)
                Button("Save Current Layout for \(store.activeApplicationName ?? "Current App")") {
                    store.saveCurrentShelfProfile()
                }
                .disabled(store.activeApplicationBundleIdentifier == nil)

                ForEach(store.shelfProfiles) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.applicationName)
                            Text(profile.bundleIdentifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.removeShelfProfile(profile)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var clipboardSettings: some View {
        Form {
            Section("History") {
                Stepper(
                    "Keep up to \(store.clipboardHistoryLimit) items",
                    value: $store.clipboardHistoryLimit,
                    in: ClipboardHistory.minimumItemCount...ClipboardHistory.maximumItemCount
                )
                Toggle(
                    "Keep recent history between launches",
                    isOn: $store.clipboardPersistenceEnabled
                )
                Text("Items you explicitly save remain searchable between launches even when recent-history persistence is off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear Clipboard History", role: .destructive) {
                    store.clearClipboardHistory()
                }
            }

            Section("Keyboard") {
                Toggle(
                    "Enable Command-Option clipboard shortcuts",
                    isOn: $store.quickPasteShortcutsEnabled
                )
                Text("Hold ⌘⌥ to show shortcut badges. Use ⌘⌥1 through ⌘⌥9 to paste, ⌘⌥←/→ to select, and ⌘⌥Return to paste the selection. Use ⌘⌥⇧↑/↓ to choose a menu item and ⌘⌥⇧←/→ to reorder it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Saved Collections") {
                TextField("Collections", text: collectionsBinding)
                Text("Separate collection names with commas. Assign saved items from a clipboard card's context menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var privacySettings: some View {
        Form {
            Section("Capture") {
                Toggle("Pause clipboard capture", isOn: $store.clipboardCapturePaused)
                Toggle(
                    "Exclude common password managers and terminals",
                    isOn: $store.excludeCommonSensitiveApps
                )
                Toggle("Clear unsaved history when Cove quits", isOn: $store.clipboardClearOnQuit)
            }

            Section("Additional excluded bundle identifiers") {
                TextEditor(text: $store.excludedClipboardBundleIdentifiersText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                Color(nsColor: .separatorColor).opacity(0.5)
                            )
                    }
                Text("Enter one bundle identifier per line. Concealed password-manager pasteboard content is always ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var updateSettings: some View {
        Form {
            Section("Cove Updates") {
                Toggle(
                    "Automatically check for updates",
                    isOn: $store.automaticUpdateChecksEnabled
                )
                Picker("Update channel", selection: $store.updateChannel) {
                    ForEach(CoveUpdateChannel.allCases) { channel in
                        Text(channel.title).tag(channel)
                    }
                }
                .pickerStyle(.segmented)
                Text(store.updateChannel == .stable
                     ? "Stable receives finished public releases."
                     : "Beta also receives prerelease builds for early testing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Check for Updates Now", action: checkForUpdates)
            }
        }
        .formStyle(.grouped)
    }

    private var collectionsBinding: Binding<String> {
        Binding(
            get: { store.clipboardCollections.joined(separator: ", ") },
            set: { value in
                store.clipboardCollections = value.split(separator: ",").map(String.init)
            }
        )
    }
}
