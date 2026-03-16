// DockMenuProxy.swift
// Reads native Dock context menu items via Accessibility API and recreates them as NSMenu
import AppKit
import ApplicationServices

class DockMenuProxy {

    static let shared = DockMenuProxy()

    // Cache: app name → (items, timestamp)
    private var cache: [String: (items: [MenuItemInfo], date: Date)] = [:]
    private let cacheTTL: TimeInterval = 60 // refresh cache every 60s

    struct MenuItemInfo {
        let title: String
        let isEnabled: Bool
        let index: Int
    }

    /// Build an NSMenu for the given app. Uses cache if available.
    func buildMenu(forAppNamed appName: String) -> NSMenu? {
        guard AXIsProcessTrusted() else { return nil }

        let items: [MenuItemInfo]
        if let cached = cache[appName], Date().timeIntervalSince(cached.date) < cacheTTL {
            items = cached.items
        } else {
            // Need to read from native Dock (causes brief flash)
            guard let freshItems = readNativeMenuItems(forAppNamed: appName), !freshItems.isEmpty else { return nil }
            cache[appName] = (items: freshItems, date: Date())
            items = freshItems
        }

        // Build NSMenu
        let menu = NSMenu()
        for item in items {
            if item.title == "<separator>" {
                menu.addItem(.separator())
            } else {
                let nsItem = NSMenuItem(title: item.title, action: #selector(DockMenuActionHandler.menuItemClicked(_:)), keyEquivalent: "")
                nsItem.target = DockMenuActionHandler.shared
                nsItem.isEnabled = item.isEnabled
                nsItem.representedObject = MenuItemRef(appName: appName, title: item.title, index: item.index)
                menu.addItem(nsItem)
            }
        }
        return menu
    }

    /// Prefetch menu items for all running apps in background (call on timer)
    func prefetchMenus(forAppNames names: [String]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self, AXIsProcessTrusted() else { return }
            for name in names {
                if let cached = self.cache[name], Date().timeIntervalSince(cached.date) < self.cacheTTL {
                    continue // still fresh
                }
                if let items = self.readNativeMenuItems(forAppNamed: name), !items.isEmpty {
                    DispatchQueue.main.async {
                        self.cache[name] = (items: items, date: Date())
                    }
                }
                // Small delay between apps to avoid rapid Dock menu flashes
                usleep(200_000)
            }
        }
    }

    // MARK: - Native menu reading

    private func readNativeMenuItems(forAppNamed appName: String) -> [MenuItemInfo]? {
        guard let dockItem = Self.findDockItem(named: appName) else { return nil }

        // Trigger native menu
        AXUIElementPerformAction(dockItem, kAXShowMenuAction as CFString)
        usleep(15_000) // 15ms for menu to populate

        // Read items
        let items = Self.readMenuItems(from: dockItem)

        // Close immediately
        Self.closeNativeMenu()

        return items
    }

    // MARK: - AX helpers

    static func findDockItem(named appName: String) -> AXUIElement? {
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

    static func readMenuItems(from dockItem: AXUIElement) -> [MenuItemInfo] {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItem, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return [] }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard let role = roleRef as? String, role == kAXMenuRole else { continue }

            var menuChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &menuChildrenRef) == .success,
                  let menuChildren = menuChildrenRef as? [AXUIElement] else { continue }

            var items: [MenuItemInfo] = []
            for (index, menuItem) in menuChildren.enumerated() {
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
        let escDown = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)
        let escUp = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)
        escDown?.post(tap: .cghidEventTap)
        escUp?.post(tap: .cghidEventTap)
    }

    /// Re-open native menu and press the item at the given index
    static func triggerNativeMenuItem(appName: String, index: Int) {
        guard let dockItem = findDockItem(named: appName) else { return }

        AXUIElementPerformAction(dockItem, kAXShowMenuAction as CFString)
        usleep(15_000)

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

// MARK: - Action handler

class DockMenuActionHandler: NSObject {
    static let shared = DockMenuActionHandler()

    @objc func menuItemClicked(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? MenuItemRef else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DockMenuProxy.triggerNativeMenuItem(appName: ref.appName, index: ref.index)
        }
    }
}
