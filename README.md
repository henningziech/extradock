# ExtraDock

A macOS menu bar app that mirrors your Dock on every connected monitor. macOS only shows the Dock on one display at a time — ExtraDock fixes that by rendering a faithful, interactive copy on all your screens.

## Features

- Mirrors pinned apps, recent apps, and persistent folders from your real Dock
- Running-app indicator dots
- Click to launch or switch to apps
- Folders open in Finder on click
- Live sync: updates within seconds when you change your Dock
- Per-monitor toggle in Settings
- Frosted glass appearance matching macOS aesthetics
- Launch at login support
- Menu-bar-only app (no Dock icon of its own)

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16+ (for building from source)

## Installation

### Quick Install (build script)

```bash
git clone https://github.com/henningziech/extradock.git
cd extradock
./install.sh
```

### Manual Build

```bash
git clone https://github.com/henningziech/extradock.git
cd extradock

# Build release
xcodebuild -project ExtraDock.xcodeproj -scheme ExtraDock -configuration Release build

# Find the built app
open ~/Library/Developer/Xcode/DerivedData/ExtraDock-*/Build/Products/Release/
```

Then drag `ExtraDock.app` to your `/Applications` folder.

### From Xcode

1. Open `ExtraDock.xcodeproj` in Xcode
2. Select the ExtraDock scheme
3. Build & Run (Cmd+R)

## Usage

1. Launch ExtraDock — it appears as a dock icon in the menu bar
2. A mirror dock bar appears at the bottom of each connected external monitor
3. Click the menu bar icon for:
   - **Settings** — toggle monitors, adjust tile size, enable launch at login
   - **Refresh Dock** — force a re-read of your Dock configuration
   - **Quit**

## How It Works

ExtraDock reads your Dock configuration from `~/Library/Preferences/com.apple.dock.plist` and monitors it for changes. It uses `NSWorkspace` to track running applications and renders everything in floating `NSPanel` windows positioned at the bottom of each screen.

## Not Sandboxed

ExtraDock needs direct access to the Dock preferences plist and process activation APIs, so it cannot be sandboxed. It is not eligible for the Mac App Store. Distribute via direct download (ideally signed with Developer ID and notarized).

## License

MIT
