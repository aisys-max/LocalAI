import SwiftUI

/// Three dots, one highlighted at a time, advancing every 500ms —
/// ports the design's 500ms `tick % 3` animation, timed locally via `TimelineView`.
struct TypingIndicatorView: View {
    let theme: Theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.5)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(theme.textMuted)
                        .opacity(tick % 3 == i ? 1 : 0.3)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .animation(.easeInOut(duration: 0.15), value: tick)
        }
    }
}
