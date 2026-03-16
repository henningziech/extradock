import SwiftUI

struct DockItemView: View {
    let item: DockItem
    let tileSize: CGFloat

    @State private var isHovered = false
    @State private var bounceOffset: CGFloat = 0
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .top) {
            // Tooltip above icon
            if isHovered {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.75))
                    )
                    .offset(y: -24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(1)
            }

            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: tileSize - 8, height: tileSize - 8)
                        .scaleEffect(isHovered ? 1.15 : (isPressed ? 0.88 : 1.0))
                        .offset(y: bounceOffset)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                        .animation(.spring(response: 0.2, dampingFraction: 0.4), value: bounceOffset)
                        .animation(.easeInOut(duration: 0.08), value: isPressed)

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
        }
        .frame(width: tileSize, height: tileSize)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .overlay {
            RightClickHandler(
                onRightClick: { handleRightClick() },
                onLeftClick: { handleLeftClick() }
            )
        }
    }

    // MARK: - Actions

    private func handleLeftClick() {
        // Press-down effect
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            isPressed = false
        }

        // Bounce animation
        bounceOffset = -8
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            bounceOffset = 0
        }

        // Perform action
        if let bundleID = item.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }
    }

    private func handleRightClick() {
        if item.bundleIdentifier != nil {
            if let menu = DockMenuProxy.shared.buildMenu(forAppNamed: item.name) {
                let mouseLocation = NSEvent.mouseLocation
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

        override func menu(for event: NSEvent) -> NSMenu? { nil }
    }
}
