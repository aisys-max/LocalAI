import SwiftUI

/// Three dots, one highlighted at a time, advancing with `model.tick` —
/// ports the design's 500ms `tick % 3` animation.
struct TypingIndicatorView: View {
    @ObservedObject var model: AppModel
    let theme: Theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(theme.textMuted)
                    .opacity(model.tick % 3 == i ? 1 : 0.3)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .animation(.easeInOut(duration: 0.15), value: model.tick)
    }
}
