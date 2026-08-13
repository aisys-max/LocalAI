import SwiftUI

/// Shared back-chevron / title / trailing-icon header for Settings and Model Picker.
struct SubHeader<Trailing: View>: View {
    let title: String
    let theme: Theme
    let backLabel: String
    let onBack: () -> Void
    let trailing: Trailing

    init(title: String, theme: Theme, backLabel: String, onBack: @escaping () -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.theme = theme
        self.backLabel = backLabel
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            IconButtonView(title: backLabel, systemName: "chevron.left", theme: theme, action: onBack)
            Spacer()
            Text(title)
                .font(AppFont.heading(18))
                .foregroundStyle(theme.text)
            Spacer()
            trailing
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

extension SubHeader where Trailing == Color {
    init(title: String, theme: Theme, backLabel: String, onBack: @escaping () -> Void) {
        self.init(title: title, theme: theme, backLabel: backLabel, onBack: onBack) {
            Color.clear
        }
    }
}
