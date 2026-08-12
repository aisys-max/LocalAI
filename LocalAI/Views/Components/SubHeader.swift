import SwiftUI

/// Shared back-chevron / title / trailing-icon header for Settings and Model Picker.
struct SubHeader: View {
    let title: String
    let theme: Theme
    let onBack: () -> Void
    let trailing: AnyView

    init(title: String, theme: Theme, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> some View) {
        self.title = title
        self.theme = theme
        self.onBack = onBack
        self.trailing = AnyView(trailing())
    }

    init(title: String, theme: Theme, onBack: @escaping () -> Void) {
        self.init(title: title, theme: theme, onBack: onBack) {
            Color.clear.frame(width: 36, height: 36)
        }
    }

    var body: some View {
        HStack {
            IconButtonView(systemName: "chevron.left", theme: theme, action: onBack)
            Spacer()
            Text(title)
                .font(AppFont.heading(18))
                .foregroundColor(theme.text)
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}
