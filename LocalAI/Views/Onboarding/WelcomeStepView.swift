import SwiftUI

struct WelcomeStepView: View {
    @ObservedObject var model: AppModel
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI")
                .font(AppFont.heading(22))
                .foregroundStyle(theme.onAccentText)
                .frame(width: 64, height: 64)
                .background(Circle().fill(theme.accent))
                .padding(.top, 28)
                .padding(.bottom, 24)

            Text(model.strings.welcomeTitle)
                .font(AppFont.heading(34))
                .foregroundStyle(theme.text)
                .padding(.bottom, 14)

            Text(model.strings.welcomeBody)
                .font(AppFont.body(16))
                .foregroundStyle(theme.textMuted)
                .lineSpacing(4)
                .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }
}
