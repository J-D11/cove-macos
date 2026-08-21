# Cove

Cove is a native macOS utility that turns the area beneath a MacBook notch into a calm shelf for the menu-bar controls you choose and optional Now Playing artwork.

## What works

- Hover near the notch to reveal the menu-bar strip.
- Choose exactly which discovered menu-bar controls appear in Cove.
- Drag chosen controls inside Cove to reorder them.
- Check or uncheck Now Playing independently from the menu-bar controls.
- Keep a session-only visual history of copied text, images, and files.
- Drop content into Cove, drag it back out, or click a card to make it ready to paste.
- Click a menu-bar proxy to open the real item.
- Keep third-party popovers open while you use them, then resume normal shelf collapsing when they close.
- Match visible menu-bar controls using their live native appearance.
- Use the installed CodexBar and ChatGPT/Codex menu symbols instead of their dark application-icon tiles.
- Temporarily reveal the shelf, explicitly pin it open, refresh it, or request Accessibility access from the Cove menu-bar menu.
- The panel follows Spaces and eligible fullscreen windows.

Cove uses Accessibility to discover and open menu-bar items. Choosing an item adds its proxy to the shelf; clicking the proxy forwards activation to the real menu-bar control. BetterDisplay, Input, BUSY, and Raycast also remain available as app proxies when their menu-bar icons are disabled. Raycast uses its native app icon and opens through its `raycast://` URL when a direct status-item action is unavailable.

## Build and run

```sh
./script/build_and_run.sh
```

The command builds the Swift package, creates a stable `dist/QuietDeck.app`, registers it with Launch Services, creates `dist/QuietDeck.app.zip`, signs it with an available Apple Development identity, verifies the app, and opens exactly one instance. The stable app path lets macOS retain Privacy & Security permissions between builds. It falls back to ad-hoc signing only when no development identity is installed.

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

**Show Cove** reveals the shelf temporarily. Only **Keep Shelf Open** pins the panel. With pinning off, the shelf begins closing 0.22 seconds after the pointer leaves the notch and panel. When a proxy opens a separate third-party popover, Cove holds its shelf steady for as long as that popover remains open.

Cove does not show Dock apps or app launchers. The shelf contains only selected menu-bar controls plus Now Playing when its separate option is checked.

**Visual Clipboard** is enabled from Cove's menu. It watches for new clipboard changes while Cove is running and keeps up to eight recent text, image, or file items in memory. Click a card to copy it back to the system clipboard, then paste normally in any app. You can also drag supported content into Cove or drag a saved card back out. Clipboard history is never written to disk and is cleared when the feature is turned off or Cove quits.


## Current boundary

Apple does not expose a public API for moving another process's status item into a custom panel. Cove discovers the accessible status item, displays its captured native appearance when available, and forwards activation to the real item. BetterDisplay, Input, and BUSY have a narrow fallback for the case where their status item is hidden by macOS; those proxies activate the owning app instead of simulating a hidden status-item click. Cove also keeps these known owners eligible for scanning when macOS runs them as background-only apps without a Dock icon.


## Inspiration and license note

Cove is free and open source under the [MIT License](LICENSE). Its Accessibility architecture was informed by the MIT-licensed SaneBar project; Cove contains an independent, smaller implementation focused on the notch shelf interaction. See `THIRD_PARTY_NOTICES.md`.
