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
        .overlay {
            RightClickHandler(
                onRightClick: { handleRightClick() },
                onLeftClick: { handleClick() }
            )
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
        if item.bundleIdentifier != nil {
            // Build native dock menu and show it at click position
            if let menu = DockMenuProxy.shared.buildMenu(forAppNamed: item.name) {
                let mouseLocation = NSEvent.mouseLocation
                // Find the window at the mouse position to show menu in
                if let window = NSApp.windows.first(where: { $0.frame.contains(mouseLocation) }) {
                    let localPoint = window.convertPoint(fromScreen: mouseLocation)
                    menu.popUp(positioning: nil, at: localPoint, in: window.contentView)
                }
            }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        }
    }
}

// MARK: - RightClickHandler

/// NSView-based right-click interceptor for SwiftUI.
/// Passes through all events except right-click.
struct RightClickHandler: NSViewRepresentable {
    let onRightClick: () -> Void
    let onLeftClick: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        let view = RightClickView()
        view.onRightClick = onRightClick
        view.onLeftClick = onLeftClick
        return view
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.onRightClick = onRightClick
        nsView.onLeftClick = onLeftClick
    }

    class RightClickView: NSView {
        var onRightClick: (() -> Void)?
        var onLeftClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            onLeftClick?()
        }

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            nil
        }
    }
}
