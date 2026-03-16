// ExtraDockApp.swift — App entry point
import SwiftUI

@main
struct ExtraDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("ExtraDock", systemImage: "dock.rectangle") {
            Button("Settings...") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Refresh Dock") {
                appDelegate.reloadDock()
            }

            Divider()

            Button("Quit ExtraDock") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockState = DockState()
    var screenMonitor: ScreenMonitor!
    var plistWatcher: PlistFileWatcher!
    var runningAppsMonitor: RunningAppsMonitor!
    var badgeReader: BadgeReader!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initial dock read
        let result = DockConfigReader.parse()
        dockState.items = result.items
        dockState.tileSize = result.tileSize
        dockState.orientation = result.orientation

        // Set up screen monitor
        screenMonitor = ScreenMonitor(dockState: dockState)

        // Set up plist watcher
        plistWatcher = PlistFileWatcher()
        plistWatcher.onChange = { [weak self] in
            guard let self else { return }
            let newResult = DockConfigReader.parse()
            self.dockState.updateItems(newResult.items)
            self.dockState.tileSize = UserDefaults.standard.object(forKey: "tileSizeOverride") as? CGFloat ?? newResult.tileSize
            self.dockState.orientation = newResult.orientation
            for (_, panel) in self.screenMonitor.panels {
                panel.updatePosition()
            }
        }

        // Set up running apps monitor
        runningAppsMonitor = RunningAppsMonitor()
        runningAppsMonitor.onChange = { [weak self] bundleIDs in
            self?.dockState.updateRunningApps(bundleIDs)
        }

        // Apply initial running state
        dockState.updateRunningApps(runningAppsMonitor.runningBundleIDs)

        // Set up badge reader (Accessibility API)
        badgeReader = BadgeReader()
        badgeReader.onChange = { [weak self] badges in
            self?.dockState.updateBadges(badges)
        }
        badgeReader.start()
    }

    func reloadDock() {
        let result = DockConfigReader.parse()
        dockState.updateItems(result.items)
        dockState.tileSize = UserDefaults.standard.object(forKey: "tileSizeOverride") as? CGFloat ?? result.tileSize
        dockState.orientation = result.orientation
        screenMonitor.refreshPanels()
    }

    func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(screenMonitor: screenMonitor)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ExtraDock Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }
}
