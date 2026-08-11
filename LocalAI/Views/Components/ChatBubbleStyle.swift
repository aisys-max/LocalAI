import SwiftUI

extension View {
    /// The chat-bubble chrome shared by `MessageBubbleView` (Chatting screen)
    /// and `HistoryChatCardView` (History preview) — accent/surface fill by
    /// role, pinned to the correct edge. Callers differ only in corner
    /// radius and max width, matching their respective bubble sizes.
    func chatBubbleStyle(isUser: Bool, theme: Theme, cornerRadius: CGFloat, maxWidth: CGFloat) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(isUser ? theme.accent : theme.surface))
            .frame(maxWidth: maxWidth, alignment: isUser ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
