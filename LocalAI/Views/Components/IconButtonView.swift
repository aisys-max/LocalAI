import SwiftUI

/// Circular icon button — ports the design's `iconBtnStyle`, reused in every
/// screen header (back chevron, settings, delete, new-chat, ellipsis, etc).
struct IconButtonView: View {
    let title: String
    let systemName: String
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemName, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(theme.text)
            .frame(width: 44, height: 44)
            .buttonStyle(.plain)
    }
}
