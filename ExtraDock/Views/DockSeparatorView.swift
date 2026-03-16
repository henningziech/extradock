import SwiftUI

struct DockSeparatorView: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white.opacity(0.3))
            .frame(width: 2, height: height * 0.6)
            .padding(.horizontal, 4)
    }
}
