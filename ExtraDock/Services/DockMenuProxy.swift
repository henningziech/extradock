// DockMenuProxy.swift
// Reads native Dock context menu items via Accessibility API and recreates them as NSMenu
import AppKit
import ApplicationServices

struct DockMenuProxy {

    /// Build an NSMenu with the native Dock's context menu items for the given app.
    /// When a menu item is selected, re-triggers the native menu and presses the matching item.
    static func buildNativeMenu(forAppNamed appName: String) -> NSMenu? {
        guard AXIsProcessTrusted() else { return nil }
        guard let dockItem = findDockItem(named: appName) else { return nil }

        // Trigger native menu to read its items
        AXUIElementPerformAction(dockItem, kAXShowMenuAction as CFString)

        // Small delay for menu to appear
        usleep(100_000) // 100ms

        // Read menu items
        let menuItems = readMenuItems(from: dockItem)

        // Close the native menu by pressing Escape
        closeNativeMenu()

        guard !menuItems.isEmpty else { return nil }

        // Build NSMenu
        let menu = NSMenu()
        for menuItem in menuItems {
            if menuItem.title == "<separator>" {
                menu.addItem(.separator())
            } else {
                let nsItem = NSMenuItem(title: menuItem.title, action: #selector(DockMenuActionHandler.menuItemClicked(_:)), keyEquivalent: "")
                nsItem.target = DockMenuActionHandler.shared
                nsItem.isEnabled = menuItem.isEnabled
                nsItem.representedObject = MenuItemRef(appName: appName, title: menuItem.title, index: menuItem.index)
                menu.addItem(nsItem)
            }
        }

        return menu
    }

    // MARK: - AX helpers

    private static func findDockItem(named appName: String) -> AXUIElement? {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }

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
                if let title = titleRef as? String, title == appName {
                    return item
                }
            }
        }
        return nil
    }

    private struct MenuItemInfo {
        let title: String
        let isEnabled: Bool
        let index: Int
    }

    private static func readMenuItems(from dockItem: AXUIElement) -> [MenuItemInfo] {
        // The menu appears as a child of the dock item
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItem, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return [] }

        // Find the menu among children
        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard let role = roleRef as? String, role == kAXMenuRole else { continue }

            // Read menu items
            var menuChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &menuChildrenRef) == .success,
                  let menuChildren = menuChildrenRef as? [AXUIElement] else { continue }

            var items: [MenuItemInfo] = []
            for (index, menuItem) in menuChildren.enumerated() {
                var itemRoleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(menuItem, kAXRoleAttribute as CFString, &itemRoleRef)

                // Check for separator
                var subRoleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(menuItem, kAXSubroleAttribute as CFString, &subRoleRef)
                if let subRole = subRoleRef as? String, subRole == "AXSeparatorMenuItemSubrole" {
                    items.append(MenuItemInfo(title: "<separator>", isEnabled: false, index: index))
                    continue
                }

                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(menuItem, kAXTitleAttribute as CFString, &titleRef)
                let title = titleRef as? String ?? ""
                guard !title.isEmpty else { continue }

                var enabledRef: CFTypeRef?
                AXUIElementCopyAttributeValue(menuItem, kAXEnabledAttribute as CFString, &enabledRef)
                let enabled = (enabledRef as? Bool) ?? true

                items.append(MenuItemInfo(title: title, isEnabled: enabled, index: index))
            }
            return items
        }
        return []
    }

    private static func closeNativeMenu() {
        // Press Escape to close the native menu
        let escDown = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)
        let escUp = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)
        escDown?.post(tap: .cghidEventTap)
        escUp?.post(tap: .cghidEventTap)
    }

    /// Re-open native menu and press the item at the given index
    static func triggerNativeMenuItem(appName: String, index: Int) {
        guard let dockItem = findDockItem(named: appName) else { return }

        AXUIElementPerformAction(dockItem, kAXShowMenuAction as CFString)
        usleep(100_000) // 100ms for menu to appear

        // Find and press the menu item at the given index
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItem, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard let role = roleRef as? String, role == kAXMenuRole else { continue }

            var menuChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &menuChildrenRef) == .success,
                  let menuChildren = menuChildrenRef as? [AXUIElement] else { continue }

            if index < menuChildren.count {
                AXUIElementPerformAction(menuChildren[index], kAXPressAction as CFString)
            }
            return
        }
    }
}

// MARK: - Menu item reference

class MenuItemRef: NSObject {
    let appName: String
    let title: String
    let index: Int

    init(appName: String, title: String, index: Int) {
        self.appName = appName
        self.title = title
        self.index = index
    }
}

// MARK: - Action handler (needs to be a class for @objc)

class DockMenuActionHandler: NSObject {
    static let shared = DockMenuActionHandler()

    @objc func menuItemClicked(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? MenuItemRef else { return }
        // Dispatch async to avoid blocking the menu dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DockMenuProxy.triggerNativeMenuItem(appName: ref.appName, index: ref.index)
        }
    }
}
