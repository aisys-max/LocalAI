import SwiftUI

extension View {
    /// The chat-bubble chrome used by `MessageBubbleView` (Chatting screen) —
    /// accent/surface fill by role, pinned to the correct edge.
    func chatBubbleStyle(isUser: Bool, theme: Theme, cornerRadius: CGFloat, maxWidth: CGFloat) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(isUser ? theme.accent : theme.surface))
            .frame(maxWidth: maxWidth, alignment: isUser ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
