import AppKit
import SwiftUI

class MirrorDockPanel: NSPanel {
    var dockState: DockState?
    private var hostingView: NSHostingView<DockBarView>?

    convenience init(screen: NSScreen, dockState: DockState) {
        self.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        self.dockState = dockState

        // Panel configuration
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false

        // Add visual effect background (frosted glass)
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true

        // Host the SwiftUI DockBarView
        let barView = DockBarView(dockState: dockState)
        let hosting = NSHostingView(rootView: barView)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.addSubview(visualEffect)
        container.addSubview(hosting)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.contentView = container
        self.hostingView = hosting

        updatePosition(for: screen)
        orderFront(nil)
    }

    func updatePosition(for screen: NSScreen? = nil) {
        guard let dockState = dockState else { return }
        guard let targetScreen = screen ?? self.screen else { return }

        let tileSize = dockState.tileSize
        let itemCount = CGFloat(dockState.items.count)
        let separatorCount: CGFloat = 2
        let padding: CGFloat = 16
        let separatorWidth: CGFloat = 12

        let width = itemCount * tileSize + separatorCount * separatorWidth + padding * 2
        let height = tileSize + padding

        let screenFrame = targetScreen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - width) / 2
        let y = screenFrame.origin.y

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
