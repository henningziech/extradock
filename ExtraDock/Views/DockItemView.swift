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
        .help(item.name)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            handleClick()
        }
        .overlay {
            // Invisible right-click handler using NSView representable
            RightClickHandler {
                handleRightClick()
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

    private func handleRightClick() {
        // For apps: trigger the native Dock's context menu via Accessibility
        if item.bundleIdentifier != nil {
            DockMenuProxy.showNativeDockMenu(forAppNamed: item.name)
        } else {
            // For folders: open in Finder
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        }
    }
}

// MARK: - RightClickHandler

/// NSView-based right-click interceptor for SwiftUI
struct RightClickHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        let view = RightClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }

    class RightClickView: NSView {
        var action: (() -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            action?()
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            // Prevent default context menu
            return nil
        }
    }
}
