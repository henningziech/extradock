import SwiftUI

struct DockBarView: View {
    var dockState: DockState

    var body: some View {
        HStack(spacing: 0) {
            let grouped = groupedItems()

            // Pinned apps
            if !grouped.pinned.isEmpty {
                ForEach(grouped.pinned) { item in
                    DockItemView(item: item, tileSize: dockState.tileSize)
                }
            }

            // Separator between pinned and recent/others
            if !grouped.pinned.isEmpty && (!grouped.recent.isEmpty || !grouped.others.isEmpty) {
                DockSeparatorView(height: dockState.tileSize)
            }

            // Recent apps
            if !grouped.recent.isEmpty {
                ForEach(grouped.recent) { item in
                    DockItemView(item: item, tileSize: dockState.tileSize)
                }
            }

            // Separator between recent and others
            if !grouped.recent.isEmpty && !grouped.others.isEmpty {
                DockSeparatorView(height: dockState.tileSize)
            }

            // Persistent others (folders)
            if !grouped.others.isEmpty {
                ForEach(grouped.others) { item in
                    DockItemView(item: item, tileSize: dockState.tileSize)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func groupedItems() -> (pinned: [DockItem], recent: [DockItem], others: [DockItem]) {
        let pinned = dockState.items.filter { $0.section == .pinnedApps }
        let recent = dockState.items.filter { $0.section == .recentApps }
        let others = dockState.items.filter { $0.section == .persistentOthers }
        return (pinned, recent, others)
    }
}
