// ScreenMonitor.swift
import AppKit
import Observation

@Observable
class ScreenMonitor {
    var panels: [CGDirectDisplayID: MirrorDockPanel] = [:]
    var dockState: DockState

    private var enabledScreens: [String: Bool] {
        get { UserDefaults.standard.dictionary(forKey: "enabledScreens") as? [String: Bool] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "enabledScreens") }
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

        // Debug: log screen info to file
        var debugLog = ""
        let dockScreenID = NSScreen.screens.first.flatMap { ScreenMonitor.displayID(for: $0) }
        debugLog += "dockScreenID (screens[0]): \(dockScreenID.map(String.init) ?? "nil")\n"
        debugLog += "enabledScreens stored: \(UserDefaults.standard.dictionary(forKey: "enabledScreens") ?? [:])\n"
        for (i, screen) in currentScreens.enumerated() {
            let did = ScreenMonitor.displayID(for: screen)
            let enabled = did.map { isEnabled($0) } ?? false
            debugLog += "Screen \(i): \(screen.localizedName), displayID=\(did.map(String.init) ?? "nil"), enabled=\(enabled), frame=\(screen.frame)\n"
        }
        try? debugLog.write(toFile: NSHomeDirectory() + "/extradock/debug.log", atomically: true, encoding: .utf8)

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
                    print("[ExtraDock] Created panel on \(screen.localizedName) (displayID=\(displayID))")
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
        let key = String(displayID)
        if let stored = enabledScreens[key] {
            return stored
        }
        // Default: enable all screens. The user can disable specific screens
        // (e.g. the one with the native Dock) via Settings.
        // Auto-detection of the Dock screen is unreliable across setups.
        return true
    }

    func setEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) {
        var current = enabledScreens
        current[String(displayID)] = enabled
        enabledScreens = current
        refreshPanels()
    }

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
