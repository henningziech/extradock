// DockMenuProxy.swift
// Triggers the native Dock's context menu for an app via Accessibility API
import AppKit
import ApplicationServices

struct DockMenuProxy {

    /// Trigger the native Dock's right-click menu for an app by name.
    /// The menu appears at the native Dock item's position.
    static func showNativeDockMenu(forAppNamed appName: String) {
        guard AXIsProcessTrusted() else { return }
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }

        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        // Get Dock's children
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard let role = roleRef as? String, role == kAXListRole else { continue }

            var listChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &listChildrenRef) == .success,
                  let listChildren = listChildrenRef as? [AXUIElement] else { continue }

            for item in listChildren {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                guard let title = titleRef as? String else { continue }

                if title == appName {
                    // Found the matching Dock item — trigger its context menu
                    AXUIElementPerformAction(item, kAXShowMenuAction as CFString)
                    return
                }
            }
        }
    }
}
