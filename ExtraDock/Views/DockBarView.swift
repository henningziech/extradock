import SwiftUI

struct DockBarView: View {
    var dockState: DockState

    var body: some View {
        HStack(spacing: 0) {
            let grouped = groupedItems()
            let size = dockState.scaledTileSize

            if !grouped.pinned.isEmpty {
                ForEach(grouped.pinned) { item in
                    DockItemView(item: item, tileSize: size)
                }
            }

            if !grouped.pinned.isEmpty && (!grouped.recent.isEmpty || !grouped.others.isEmpty) {
                DockSeparatorView(height: size)
            }

            if !grouped.recent.isEmpty {
                ForEach(grouped.recent) { item in
                    DockItemView(item: item, tileSize: size)
                }
            }

            if !grouped.recent.isEmpty && !grouped.others.isEmpty {
                DockSeparatorView(height: size)
            }

            if !grouped.others.isEmpty {
                ForEach(grouped.others) { item in
                    DockItemView(item: item, tileSize: size)
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
