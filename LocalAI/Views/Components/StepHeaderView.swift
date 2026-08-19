import SwiftUI

/// Onboarding step title + subtitle block, shared by `BackendStepView` and `ModelStepView`.
struct StepHeaderView: View {
    let title: String
    let subtitle: String
    let theme: Theme
    var bottomPadding: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(AppFont.heading(26))
                .foregroundStyle(theme.text)
                .padding(.top, 20)
                .padding(.bottom, 8)

            Text(subtitle)
                .font(AppFont.body(14))
                .foregroundStyle(theme.textMuted)
                .lineSpacing(3)
                .padding(.bottom, bottomPadding)
        }
    }
}
