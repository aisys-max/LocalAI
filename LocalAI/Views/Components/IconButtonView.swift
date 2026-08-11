import SwiftUI

/// Circular icon button — ports the design's `iconBtnStyle`, reused in every
/// screen header (back chevron, settings, delete, new-chat, ellipsis, etc).
struct IconButtonView: View {
    let systemName: String
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}
