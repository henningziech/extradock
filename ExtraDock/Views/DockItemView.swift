import SwiftUI

struct DockItemView: View {
    let item: DockItem
    let tileSize: CGFloat

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: tileSize - 8, height: tileSize - 8)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)

                // Badge count
                if let badge = item.badgeCount {
                    Text(badge)
                        .font(.system(size: max(9, tileSize * 0.2), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 4, y: -2)
                }
            }

            // Running indicator dot
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
                .opacity(item.isRunning ? 1 : 0)
        }
        .frame(width: tileSize, height: tileSize)
        .help(item.name)  // tooltip
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handleClick()
        }
        .contextMenu {
            contextMenuContent()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent() -> some View {
        if item.section == .persistentOthers {
            // Folder context menu
            Button("Open in Finder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
        } else if let bundleID = item.bundleIdentifier {
            // App context menu
            if item.isRunning {
                Button("New Window") {
                    newWindow(bundleID: bundleID)
                }

                Button("Show All Windows") {
                    showAllWindows(bundleID: bundleID)
                }

                Divider()
            }

            Menu("Options") {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                }

                if item.isRunning {
                    Button("Hide") {
                        hideApp(bundleID: bundleID)
                    }
                }
            }

            if item.isRunning {
                Divider()

                Button("Quit") {
                    quitApp(bundleID: bundleID)
                }

                Button("Force Quit") {
                    forceQuitApp(bundleID: bundleID)
                }
            } else {
                Divider()

                Button("Open") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
                }
            }
        }
    }

    // MARK: - Actions

    private func handleClick() {
        if let bundleID = item.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
    }

    private func quitApp(bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            app.terminate()
        }
    }

    private func forceQuitApp(bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            app.forceTerminate()
        }
    }

    private func hideApp(bundleID: String) {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            app.hide()
        }
    }

    private func newWindow(bundleID: String) {
        // Activate the app first, then send Cmd+N via AppleScript
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let script = NSAppleScript(source: """
                    tell application "System Events"
                        keystroke "n" using command down
                    end tell
                """)
                script?.executeAndReturnError(nil)
            }
        }
    }

    private func showAllWindows(bundleID: String) {
        // Activate the app and trigger Mission Control "Application Windows"
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Control+Down Arrow triggers App Exposé
                let script = NSAppleScript(source: """
                    tell application "System Events"
                        key code 125 using control down
                    end tell
                """)
                script?.executeAndReturnError(nil)
            }
        }
    }
}
