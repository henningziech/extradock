// ScreenMonitor.swift
import AppKit
import Observation

@Observable
class ScreenMonitor {
    var panels: [CGDirectDisplayID: MirrorDockPanel] = [:]
    var dockState: DockState

    private func readEnabledScreen(_ key: String) -> Bool? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "enabledScreens"),
              let value = dict[key] else { return nil }
        // Handle NSNumber (stored as 0/1) and Bool
        return (value as? NSNumber)?.boolValue
    }

    private func writeEnabledScreens(_ screens: [String: Bool]) {
        UserDefaults.standard.set(screens, forKey: "enabledScreens")
    }

    private var allEnabledScreens: [String: Bool] {
        guard let dict = UserDefaults.standard.dictionary(forKey: "enabledScreens") else { return [:] }
        var result: [String: Bool] = [:]
        for (key, value) in dict {
            if let num = value as? NSNumber {
                result[key] = num.boolValue
            }
        }
        return result
    }

    init(dockState: DockState) {
        self.dockState = dockState
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        refreshPanels()
    }

    @objc private func screensChanged() {
        refreshPanels()
    }

    func refreshPanels() {
        let currentScreens = NSScreen.screens
        let currentIDs = Set(currentScreens.compactMap { ScreenMonitor.displayID(for: $0) })

        // Remove panels for disconnected screens
        for id in panels.keys where !currentIDs.contains(id) {
            panels[id]?.close()
            panels.removeValue(forKey: id)
        }

        // Create or update panels for current screens
        for screen in currentScreens {
            guard let displayID = ScreenMonitor.displayID(for: screen) else { continue }

            if isEnabled(displayID) {
                if let panel = panels[displayID] {
                    // Screen still connected — reposition if needed
                    panel.updatePosition()
                } else {
                    // New enabled screen — create a panel
                    let panel = MirrorDockPanel(screen: screen, dockState: dockState)
                    panels[displayID] = panel
                }
            } else {
                // Screen disabled — close any existing panel
                if let panel = panels[displayID] {
                    panel.close()
                    panels.removeValue(forKey: displayID)
                }
            }
        }
    }

    func isEnabled(_ displayID: CGDirectDisplayID) -> Bool {
        if let stored = readEnabledScreen(String(displayID)) {
            return stored
        }
        // Default: enable all screens. The user can disable specific screens
        // (e.g. the one with the native Dock) via Settings.
        return true
    }

    func setEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) {
        var current = allEnabledScreens
        current[String(displayID)] = enabled
        writeEnabledScreens(current)
        refreshPanels()
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
