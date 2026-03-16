import AppKit
import SwiftUI

class MirrorDockPanel: NSPanel {
    var dockState: DockState?
    private var hostingView: NSHostingView<DockBarView>?
    private var panelTrackingArea: NSTrackingArea?
    private var triggerPanel: NSPanel?
    private var isShown = true
    private var hideTimer: Timer?
    private var idleTimer: Timer?
    private var mouseMonitor: Any?
    private var settingsObserver: Any?
    private var targetScreen: NSScreen?

    private var autoHideEnabled: Bool {
        UserDefaults.standard.bool(forKey: "autoHideEnabled")
    }
    private var autoHideSeconds: TimeInterval {
        let val = UserDefaults.standard.double(forKey: "autoHideSeconds")
        return val > 0 ? val : 5.0
    }

    convenience init(screen: NSScreen, dockState: DockState) {
        self.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        self.dockState = dockState
        self.targetScreen = screen

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
        setupPanelTracking()
        if autoHideEnabled {
            setupTriggerZone(for: screen)
            startIdleMonitor()
        }
        // Listen for settings changes
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .extraDockAutoHideChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.autoHideSettingChanged()
        }
        NotificationCenter.default.addObserver(
            forName: .extraDockScaleChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let dockState = self.dockState else { return }
            dockState.scale = CGFloat(UserDefaults.standard.object(forKey: "dockScale") as? Double ?? 1.0)
            self.updatePosition()
        }
        orderFront(nil)
    }

    // MARK: - Positioning

    func updatePosition(for screen: NSScreen? = nil) {
        guard let dockState = dockState else { return }
        let resolvedScreen = screen ?? self.targetScreen ?? self.screen
        guard let resolvedScreen else { return }
        self.targetScreen = resolvedScreen

        let tileSize = dockState.scaledTileSize
        let itemCount = CGFloat(dockState.items.count)
        let separatorCount: CGFloat = 2
        let padding: CGFloat = 16 * dockState.scale
        let separatorWidth: CGFloat = 12 * dockState.scale

        let width = itemCount * tileSize + separatorCount * separatorWidth + padding * 2
        let height = tileSize + padding

        let screenFrame = resolvedScreen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - width) / 2

        if isShown {
            setFrame(NSRect(x: x, y: screenFrame.origin.y, width: width, height: height), display: true)
        } else {
            let y = resolvedScreen.frame.origin.y - height + 2
            setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }

        setupTriggerZone(for: resolvedScreen)
    }

    // MARK: - Auto-hide

    private func autoHideSettingChanged() {
        if autoHideEnabled {
            if mouseMonitor == nil {
                startIdleMonitor()
            }
            if let screen = targetScreen {
                setupTriggerZone(for: screen)
            }
            resetIdleTimer()
        } else {
            // Disable auto-hide: stop monitors, show panel, remove trigger
            idleTimer?.invalidate()
            idleTimer = nil
            if let monitor = mouseMonitor {
                NSEvent.removeMonitor(monitor)
                mouseMonitor = nil
            }
            triggerPanel?.close()
            triggerPanel = nil
            if !isShown {
                showPanel()
            }
        }
    }

    private func startIdleMonitor() {
        resetIdleTimer()
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            self?.onMouseActivity()
        }
    }

    private func onMouseActivity() {
        resetIdleTimer()

        // If hidden, check if mouse is near the bottom of our screen → show
        if !isShown, let screen = targetScreen {
            let mouseLocation = NSEvent.mouseLocation
            let triggerRect = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.origin.y,
                width: screen.frame.width,
                height: 50
            )
            if triggerRect.contains(mouseLocation) {
                showPanel()
            }
        }
    }

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        guard autoHideEnabled else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: autoHideSeconds, repeats: false) { [weak self] _ in
            guard let self, self.isShown else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.contains(mouseLocation) {
                self.hidePanel()
            }
        }
    }

    // MARK: - Trigger zone (invisible panel at bottom edge)

    private func setupTriggerZone(for screen: NSScreen) {
        triggerPanel?.close()

        let triggerHeight: CGFloat = 10
        let triggerFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: triggerHeight
        )

        let trigger = NSPanel(
            contentRect: triggerFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        trigger.level = .screenSaver
        trigger.collectionBehavior = [.canJoinAllSpaces, .stationary]
        trigger.backgroundColor = .clear
        trigger.isOpaque = false
        trigger.hasShadow = false
        trigger.ignoresMouseEvents = false
        trigger.hidesOnDeactivate = false
        trigger.alphaValue = 0.01

        let trackingView = TriggerTrackingView(frame: NSRect(origin: .zero, size: triggerFrame.size))
        trackingView.onMouseEnter = { [weak self] in
            self?.showPanel()
        }
        trigger.contentView = trackingView
        trigger.orderFront(nil)
        triggerPanel = trigger
    }

    // MARK: - Show / Hide animations

    private func showPanel() {
        guard !isShown else { return }
        hideTimer?.invalidate()
        isShown = true
        resetIdleTimer()

        guard let screen = targetScreen else { return }
        let screenFrame = screen.visibleFrame
        self.setFrameOrigin(NSPoint(x: self.frame.origin.x, y: screenFrame.origin.y))
        self.orderFront(nil)
    }

    private func hidePanel() {
        guard isShown else { return }
        isShown = false

        guard let screen = targetScreen else { return }
        let belowScreen = screen.frame.origin.y - self.frame.height + 2
        self.setFrameOrigin(NSPoint(x: self.frame.origin.x, y: belowScreen))
    }

    // MARK: - Mouse tracking on the panel itself

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        hideTimer?.invalidate()
        idleTimer?.invalidate()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        resetIdleTimer()
    }

    private func setupPanelTracking() {
        guard let contentView else { return }
        if let existing = panelTrackingArea {
            contentView.removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        panelTrackingArea = area
    }

    // MARK: - Cleanup

    override func close() {
        idleTimer?.invalidate()
        hideTimer?.invalidate()
        triggerPanel?.close()
        triggerPanel = nil
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
        super.close()
    }
}

// MARK: - TriggerTrackingView

private class TriggerTrackingView: NSView {
    var onMouseEnter: (() -> Void)?
    private var area: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = area { removeTrackingArea(existing) }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        area = newArea
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEnter?()
    }
}
