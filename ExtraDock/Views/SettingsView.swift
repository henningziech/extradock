// SettingsView.swift
import SwiftUI
import ServiceManagement

private struct ScreenEntry: Identifiable {
    let id: CGDirectDisplayID
    let screen: NSScreen
}

struct SettingsView: View {
    var screenMonitor: ScreenMonitor
    @State private var tileSizeOverride: Double? = UserDefaults.standard.object(forKey: "tileSizeOverride") as? Double
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private var screenEntries: [ScreenEntry] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = ScreenMonitor.displayID(for: screen) else { return nil }
            return ScreenEntry(id: displayID, screen: screen)
        }
    }

    var body: some View {
        Form {
            Section("Monitors") {
                ForEach(screenEntries) { entry in
                    Toggle(screenName(entry.screen, displayID: entry.id),
                           isOn: Binding(
                            get: { screenMonitor.isEnabled(entry.id) },
                            set: { screenMonitor.setEnabled(entry.id, enabled: $0) }
                           ))
                }
            }

            Section("Appearance") {
                Toggle("Override tile size", isOn: Binding(
                    get: { tileSizeOverride != nil },
                    set: { enabled in
                        if enabled {
                            tileSizeOverride = 49
                            UserDefaults.standard.set(49, forKey: "tileSizeOverride")
                        } else {
                            tileSizeOverride = nil
                            UserDefaults.standard.removeObject(forKey: "tileSizeOverride")
                        }
                    }
                ))

                if let size = tileSizeOverride {
                    Slider(value: Binding(
                        get: { size },
                        set: { newValue in
                            tileSizeOverride = newValue
                            UserDefaults.standard.set(newValue, forKey: "tileSizeOverride")
                        }
                    ), in: 32...80, step: 1) {
                        Text("Tile size: \(Int(size))")
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue // revert on failure
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 350)
        .padding()
    }

    private func screenName(_ screen: NSScreen, displayID: CGDirectDisplayID) -> String {
        let name = screen.localizedName
        if screen == NSScreen.main {
            return "\(name) (Main — native Dock)"
        }
        return name
    }
}
