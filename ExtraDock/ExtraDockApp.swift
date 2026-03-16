// ExtraDockApp.swift — App entry point
import SwiftUI

@main
struct ExtraDockApp: App {
    @State private var dockState = DockState()
    @State private var screenMonitor: ScreenMonitor?
    @State private var plistWatcher: PlistFileWatcher?
    @State private var runningAppsMonitor: RunningAppsMonitor?

    var body: some Scene {
        MenuBarExtra("ExtraDock", systemImage: "dock.rectangle") {
            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                // Open settings window by sending the showPreferencesWindow: action
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Refresh Dock") {
                reloadDock()
            }

            Divider()

            Button("Quit ExtraDock") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        Settings {
            if let monitor = screenMonitor {
                SettingsView(screenMonitor: monitor)
            } else {
                ProgressView("Loading...")
            }
        }
    }

    init() {
        // Initial dock read
        let result = DockConfigReader.parse()
        let state = DockState()
        state.items = result.items
        state.tileSize = result.tileSize
        state.orientation = result.orientation
        _dockState = State(initialValue: state)

        // Set up screen monitor
        let monitor = ScreenMonitor(dockState: state)
        _screenMonitor = State(initialValue: monitor)

        // Set up plist watcher
        let watcher = PlistFileWatcher()
        watcher.onChange = { [state, monitor] in
            let newResult = DockConfigReader.parse()
            state.updateItems(newResult.items)
            state.tileSize = UserDefaults.standard.object(forKey: "tileSizeOverride") as? CGFloat ?? newResult.tileSize
            state.orientation = newResult.orientation
            // Reposition panels after item count may have changed
            for (_, panel) in monitor.panels {
                panel.updatePosition()
            }
        }
        _plistWatcher = State(initialValue: watcher)

        // Set up running apps monitor
        let appsMon = RunningAppsMonitor()
        appsMon.onChange = { [state] bundleIDs in
            state.updateRunningApps(bundleIDs)
        }
        _runningAppsMonitor = State(initialValue: appsMon)

        // Apply initial running state
        state.updateRunningApps(appsMon.runningBundleIDs)
    }

    private func reloadDock() {
        let result = DockConfigReader.parse()
        dockState.updateItems(result.items)
        dockState.tileSize = UserDefaults.standard.object(forKey: "tileSizeOverride") as? CGFloat ?? result.tileSize
        dockState.orientation = result.orientation
        screenMonitor?.refreshPanels()
    }
}
