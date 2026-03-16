// BadgeReader.swift
import AppKit
import ApplicationServices
import Observation

@Observable
class BadgeReader {
    private(set) var badges: [String: String] = [:]
    private(set) var isAccessibilityGranted = false
    private var pollTimer: Timer?
    private var permissionTimer: Timer?
    var onChange: (([String: String]) -> Void)?

    init() {
        // Don't check trust here — do it after app is fully launched
    }

    deinit {
        pollTimer?.invalidate()
        permissionTimer?.invalidate()
    }

    /// Call after app launch to start badge reading
    func start() {
        let trusted = AXIsProcessTrusted()
        isAccessibilityGranted = trusted

        if trusted {
            startPolling()
        } else {
            requestPermission()
        }
    }

    /// Request accessibility permission (shows system prompt if not yet granted)
    func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        isAccessibilityGranted = trusted

        if trusted {
            startPolling()
        } else {
            // Poll for permission grant (user may grant it in System Settings)
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.isAccessibilityGranted = true
                    self?.startPolling()
                }
            }
        }
    }

    private func startPolling() {
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let newBadges = readDockBadges()
        if newBadges != badges {
            badges = newBadges
            onChange?(newBadges)
        }
    }

    /// Read badge labels from the native Dock via Accessibility API
    private func readDockBadges() -> [String: String] {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return [:]
        }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        // Get children of Dock app
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &childrenRef)
        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return [:]
        }

        var badges: [String: String] = [:]

        for child in children {
            // Look for AXList (the dock item list)
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard let role = roleRef as? String, role == kAXListRole else { continue }

            // Get list children (dock items)
            var listChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &listChildrenRef) == .success,
                  let listChildren = listChildrenRef as? [AXUIElement] else { continue }

            for item in listChildren {
                // Get title (app name)
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                guard let title = titleRef as? String, !title.isEmpty else { continue }

                // Get status label (badge count)
                var statusRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusRef)
                if let status = statusRef as? String, !status.isEmpty {
                    badges[title] = status
                }
            }
        }

        return badges
    }
}
