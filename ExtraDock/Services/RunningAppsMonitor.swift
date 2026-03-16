// RunningAppsMonitor.swift
import AppKit
import Observation

@Observable
class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    private var observation: NSKeyValueObservation?
    var onChange: ((Set<String>) -> Void)?

    init() {
        refresh()
        observation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    private func refresh() {
        let ids = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        if ids != runningBundleIDs {
            runningBundleIDs = ids
            onChange?(ids)
        }
    }
}
