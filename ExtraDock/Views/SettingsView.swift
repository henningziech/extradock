// SettingsView.swift
import SwiftUI
import ServiceManagement

private struct ScreenEntry: Identifiable {
    let id: CGDirectDisplayID
    let screen: NSScreen
}

struct SettingsView: View {
    var screenMonitor: ScreenMonitor
    @State private var dockScale: Double = (UserDefaults.standard.object(forKey: "dockScale") as? Double) ?? 1.0
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var autoHideEnabled: Bool = UserDefaults.standard.bool(forKey: "autoHideEnabled")
    @State private var autoHideSeconds: Double = (UserDefaults.standard.object(forKey: "autoHideSeconds") as? Double) ?? 5.0

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
                Slider(value: $dockScale, in: 0.5...2.0, step: 0.1) {
                    Text("Scale: \(Int(dockScale * 100))%")
                }
                .onChange(of: dockScale) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "dockScale")
                    NotificationCenter.default.post(name: .extraDockScaleChanged, object: nil)
                }
            }

            Section("Behavior") {
                Toggle("Hide dock after inactivity", isOn: $autoHideEnabled)
                    .onChange(of: autoHideEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoHideEnabled")
                        NotificationCenter.default.post(name: .extraDockAutoHideChanged, object: nil)
                    }

                if autoHideEnabled {
                    Slider(value: $autoHideSeconds, in: 1...30, step: 1) {
                        Text("Hide after \(Int(autoHideSeconds))s")
                    }
                    .onChange(of: autoHideSeconds) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoHideSeconds")
                        NotificationCenter.default.post(name: .extraDockAutoHideChanged, object: nil)
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
                            launchAtLogin = !newValue
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
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

extension Notification.Name {
    static let extraDockAutoHideChanged = Notification.Name("extraDockAutoHideChanged")
    static let extraDockScaleChanged = Notification.Name("extraDockScaleChanged")
}
