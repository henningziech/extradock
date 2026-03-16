// DockItem.swift
import Foundation
import AppKit

// MARK: - DockSection

enum DockSection {
    case pinnedApps
    case recentApps
    case persistentOthers
}

// MARK: - DockItem

struct DockItem: Identifiable, Equatable {
    let id: String
    var name: String
    var bundleIdentifier: String?
    var path: String
    var icon: NSImage
    var isRunning: Bool
    var section: DockSection

    init(
        id: String = UUID().uuidString,
        name: String,
        bundleIdentifier: String? = nil,
        path: String,
        icon: NSImage,
        isRunning: Bool = false,
        section: DockSection
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.icon = icon
        self.isRunning = isRunning
        self.section = section
    }

    // Equatable: compare all properties except icon (NSImage isn't easily equatable)
    static func == (lhs: DockItem, rhs: DockItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.path == rhs.path &&
        lhs.isRunning == rhs.isRunning &&
        lhs.section == rhs.section
    }
}
