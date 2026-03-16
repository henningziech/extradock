// PlistFileWatcher.swift
import Foundation
import Observation

@Observable
class PlistFileWatcher {
    var onChange: (() -> Void)?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var lastModDate: Date?

    init() {
        startFileWatcher()
        startPollFallback()
    }

    deinit {
        fileSource?.cancel()
        pollTimer?.invalidate()
    }

    private func startFileWatcher() {
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.onChange?()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileSource = source
    }

    private func startPollFallback() {
        // Poll every 2 seconds as fallback (cfprefsd may not flush to disk immediately)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        let path = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date else { return }

        if let last = lastModDate, modDate > last {
            onChange?()
        }
        lastModDate = modDate
    }
}
