// DockState.swift
import Foundation
import Observation

// MARK: - DockState

@Observable
class DockState {
    var items: [DockItem] = []
    var tileSize: CGFloat = 49
    var orientation: String = "bottom"

    // Merges new config items with current running state.
    // Items already present (by id) retain their isRunning flag;
    // newly added items get the running flag from the provided set if available.
    func updateItems(_ newItems: [DockItem]) {
        // Build a lookup of current running state by path (path is stable across reloads)
        let runningByPath: [String: Bool] = Dictionary(
            uniqueKeysWithValues: items.map { ($0.path, $0.isRunning) }
        )

        items = newItems.map { item in
            var updated = item
            if let wasRunning = runningByPath[item.path] {
                updated.isRunning = wasRunning
            }
            return updated
        }
    }

    // Updates the isRunning flag on existing items based on the provided set of bundle IDs.
    func updateRunningApps(_ bundleIDs: Set<String>) {
        items = items.map { item in
            var updated = item
            if let bid = item.bundleIdentifier {
                updated.isRunning = bundleIDs.contains(bid)
            } else {
                updated.isRunning = false
            }
            return updated
        }
    }

    // Updates badge counts from a dictionary keyed by app name.
    func updateBadges(_ badges: [String: String]) {
        items = items.map { item in
            var updated = item
            updated.badgeCount = badges[item.name]
            return updated
        }
    }
}
