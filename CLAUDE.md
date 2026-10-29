# rodathanh.github.io

- `index.html`: the Streakboard web page (GitHub Pages). `macos-widget/`: native macOS menu bar app + widget; build steps in its README.

## macOS app (`macos-widget/`)

- "Widget like the battery percent" means a menu bar status item (NSStatusItem), not a WidgetKit desktop widget or a window.
- The user wants the UI minimal: no username box, no Quit button (Quit is on right-click), no streak ring or day count in the panel. Ask before adding controls or text back.
- Xcode is installed but not selected: prefix builds with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Run `xcodegen generate` first; the `.xcodeproj`, Info.plists and entitlements are generated and gitignored.
- No signing identity on this Mac; the project signs ad-hoc (`-`). Fine locally, not shareable.
- To see a change: quit Streakboard, copy the Release build to `/Applications`, reopen.
- The terminal has no Screen Recording or Accessibility permission, so `screencapture` and reading the menu bar fail. Verify visuals by compiling the Shared and App sources (with `@main` stripped) into a small script that renders views to PNG via `ImageRenderer`/`NSImage`. AppKit controls (buttons, text fields, checkboxes) show up as yellow placeholders there; that is expected.
