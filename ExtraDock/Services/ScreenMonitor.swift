// ScreenMonitor.swift
import AppKit
import CoreGraphics
import Observation

@Observable
class ScreenMonitor {
    var panels: [CGDirectDisplayID: MirrorDockPanel] = [:]
    var dockState: DockState
    private var fullscreenCheckTimer: Timer?

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
        // Also observe active app changes to detect fullscreen
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        refreshPanels()
        startFullscreenCheck()
    }

    @objc private func screensChanged() {
        refreshPanels()
    }

    @objc private func activeAppChanged() {
        checkFullscreen()
    }

    private func startFullscreenCheck() {
        // Poll every 1s to catch fullscreen transitions (YouTube, etc.)
        fullscreenCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFullscreen()
        }
    }

    private func checkFullscreen() {
        for (displayID, panel) in panels {
            guard let screen = NSScreen.screens.first(where: { ScreenMonitor.displayID(for: $0) == displayID }) else { continue }

            if isScreenOccludedByFullscreenWindow(screen) {
                if panel.isVisible {
                    panel.orderOut(nil)
                }
            } else {
                if !panel.isVisible {
                    panel.orderFront(nil)
                }
            }
        }
    }

    /// Check if any window covers the entire screen (fullscreen or maximized covering dock area)
    private func isScreenOccludedByFullscreenWindow(_ screen: NSScreen) -> Bool {
        let screenFrame = screen.frame

        // Get all on-screen windows (excluding our own and desktop elements)
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier

        for windowInfo in windowList {
            // Skip our own windows
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID else { continue }

            // Skip windows below normal level (desktop, etc.)
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0 else { continue }

            // Get window bounds (values are NSNumber, not CGFloat)
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let wx = (boundsDict["X"] as? NSNumber)?.doubleValue,
                  let wy = (boundsDict["Y"] as? NSNumber)?.doubleValue,
                  let ww = (boundsDict["Width"] as? NSNumber)?.doubleValue,
                  let wh = (boundsDict["Height"] as? NSNumber)?.doubleValue else { continue }

            // CGWindowList uses top-left origin; NSScreen uses bottom-left
            // Convert: screen top-left Y = mainScreenHeight - screen.frame.maxY
            let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
            let screenTopLeftY = Double(mainScreenHeight - screenFrame.maxY)

            // Check if this window covers the full screen (with small tolerance)
            let tolerance: Double = 4
            if wx <= Double(screenFrame.origin.x) + tolerance &&
               wy <= screenTopLeftY + tolerance &&
               ww >= Double(screenFrame.width) - tolerance &&
               wh >= Double(screenFrame.height) - tolerance {
                return true
            }
        }
        return false
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
