# Cove

Cove is a native macOS utility that turns the right edge of the screen into a calm, attached shelf for the menu-bar controls you choose, Now Playing, and a visual clipboard.

## What works

- Hover over the slim right-edge handle to reveal Cove.
- Choose which third-party menu extras appear in Cove while standard Apple status controls stay in the menu bar.
- Drag chosen controls inside Cove to reorder them.
- Check or uncheck Now Playing independently from the menu-bar controls.
- Keep a visual history of copied plain text, rich text, images, and files with content-first previews, source context, timestamps, search, and pinned favorites.
- Search text recognized locally inside copied images, organize saved items into collections, and run context-aware actions for links, email addresses, phone numbers, JSON, code indentation, and colors.
- Drop content into Cove, drag it back out, copy a card, or paste it directly into the active app. Multi-file cards preserve their complete file list when moved between Cove surfaces.
- Give sensitive items an expiration time or remove them automatically after one paste, with one-step undo for accidental deletion or history clearing.
- Pause clipboard capture, exclude sensitive apps, ignore concealed password-manager content, and choose whether private app data is saved between launches.
- Use Command-Option-1 through Command-Option-9 for quick paste, arrow shortcuts to move the active card, and Command-Option-Return to paste it.
- Hold Command-Option to reveal shortcut badges. Add Shift to select and reorder menu items with the keyboard; VoiceOver users also get named Move Left and Move Right actions.
- Click a menu-bar proxy to open the real item.
- Keep third-party popovers open while you use them, then resume normal shelf collapsing when they close.
- Match visible menu-bar controls using their live native appearance.
- Use the installed CodexBar and ChatGPT/Codex menu symbols instead of their dark application-icon tiles.
- Temporarily reveal the shelf, explicitly pin it open, refresh it, open Settings, or request Accessibility access from the Cove menu-bar menu.
- Check for signed updates manually or let Cove check once per day and show an update indicator in its menu.
- Choose Stable or Beta updates and save per-app shelf profiles that switch menu controls, Now Playing, clipboard visibility, and clipboard collection when the active app changes.
- The panel follows Spaces and eligible fullscreen windows.

Cove uses Accessibility to discover and open menu-bar items. Choosing an item adds its proxy to the shelf; clicking the proxy forwards activation to the real menu-bar control. BetterDisplay, Input, BUSY, and Raycast also remain available as app proxies when their menu-bar icons are disabled. Raycast uses its native app icon and opens through its `raycast://` URL when a direct status-item action is unavailable.

Standard Apple controls such as Wi-Fi, Bluetooth, sound, battery, clock, and Control Center are intentionally omitted from Cove because macOS already keeps them available in the menu bar. Cove focuses its limited rail space on clipboard tools, Now Playing, Raycast, and the extra utilities the user chooses.

## Build and run

```sh
./script/build_and_run.sh
```

The command builds the Swift package, creates a stable signed bundle under Cove's user Application Support directory, exposes it through `dist/QuietDeck.app`, registers it with Launch Services, creates and verifies `dist/QuietDeck.app.zip`, and opens exactly one instance. Keeping the real bundle outside a File Provider-managed project directory prevents synced Finder metadata from invalidating strict signature checks while preserving a stable launch and Privacy & Security path. It falls back to ad-hoc signing only when no development identity is installed.

Run tests with:

```sh
swift test
```

## Public distribution

The GitHub release is signed with a Developer ID Application certificate, uses the hardened runtime, and is notarized by Apple. Users can download, extract, and open Cove normally through Gatekeeper.

Maintainers with the `CoveNotary` Keychain profile can create a notarized release with:

```sh
./script/notarize_release.sh
```

The script runs the tracked-source privacy check, builds in release mode without debug metadata, rejects personal paths, email addresses, and credential-like strings in the executable, signs with the Developer ID identity for team `XKW9265RG8`, submits the archive to Apple, staples the approval ticket, and verifies the final archive with both `codesign` and Gatekeeper. The same source privacy check runs on every GitHub push and pull request.

## First launch

Choose **Enable Menu Access** from the Cove menu-bar menu, then enable Cove in **System Settings → Privacy & Security → Accessibility**. Cove refreshes automatically after permission is granted. Open **Menu Bar Items** and check the controls you want in the shelf.

Choose **Enable Native Menu Appearance…** if you want Cove to mirror a control's live menu-bar appearance. Without it, Cove uses the owning app's icon or a system symbol.

Choose **Check for Updates…** from the Cove menu to check the selected Stable or Beta GitHub release channel, or enable daily checks in **Settings → Updates**. Cove accepts only a versioned `.app.zip` from the trusted Cove repository, verifies the archive digest when GitHub provides one, validates the bundle identity and version, checks the code signature and Gatekeeper assessment, shows download progress, and then replaces and relaunches the current app. You can open the release notes before installing. An administrator confirmation may appear when Cove is installed in a protected location such as `/Applications`.

**Show Cove** reveals the shelf temporarily. Only **Keep Shelf Open** pins the panel. With pinning off, the shelf begins closing 0.22 seconds after the pointer leaves the right-edge handle and panel. When a proxy opens a separate third-party popover, Cove holds its shelf steady for as long as that popover remains open.

Cove is not a general Dock or application launcher. The shelf contains selected menu-bar controls, known app proxies such as Raycast when their menu item is hidden, the visual clipboard, and Now Playing when those features are enabled.

**Visual Clipboard** is enabled from Cove's menu. It watches for new clipboard changes while Cove is running and keeps three to twenty recent items, with eight as the default. Click a card to copy it, use **Paste Now** or **Smart Actions** from its context menu, or use the global quick-paste shortcuts. Image text recognition uses Apple's on-device Vision framework and does not upload clipboard content. Save important cards into collections to keep them searchable beyond the recent-item limit and across launches. You can also drag supported content into Cove or drag a saved card back out. Recent-history persistence is off by default, while explicitly saved cards are stored in Cove's private Application Support directory. **Settings → Privacy** controls pausing, app exclusions, expiration, and clearing unsaved history on quit.


## Current boundary

Apple does not expose a public API for moving another process's status item into a custom panel. Cove discovers the accessible status item, displays its captured native appearance when available, and forwards activation to the real item. BetterDisplay, Input, BUSY, and Raycast have a narrow fallback for the case where their status item is hidden by macOS. Those proxies activate the owning app instead of simulating a hidden status-item click. Cove also keeps these known owners eligible for scanning when macOS runs them as background-only apps without a Dock icon.


## Inspiration and license note

Cove is free and open source under the [MIT License](LICENSE). Its Accessibility architecture was informed by the MIT-licensed SaneBar project; Cove contains an independent, smaller implementation focused on the notch shelf interaction. See `THIRD_PARTY_NOTICES.md`.
