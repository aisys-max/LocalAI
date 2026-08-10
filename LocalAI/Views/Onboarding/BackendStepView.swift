import SwiftUI

struct BackendStepView: View {
    @ObservedObject var model: AppModel
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeaderView(
                title: model.strings.choosePlatformTitle,
                subtitle: model.strings.choosePlatformBody,
                theme: theme,
                bottomPadding: 20
            )

            VStack(spacing: 12) {
                ForEach(Backend.allCases) { backend in
                    BackendCard(backend: backend, model: model, theme: theme)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

private struct BackendCard: View {
    let backend: Backend
    @ObservedObject var model: AppModel
    let theme: Theme

    private var selected: Bool { model.backend == backend }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(selected ? theme.accent : theme.divider, lineWidth: 2)
                .background(Circle().fill(selected ? theme.accent : Color.clear))
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(backend.label)
                    .font(AppFont.heading(16))
                    .foregroundColor(theme.text)
                Text(backend.description(model.language))
                    .font(AppFont.body(12.5))
                    .foregroundColor(theme.textMuted)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(selected ? theme.selectedTint : theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(selected ? theme.accent : theme.divider, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.selectBackend(backend) }
    }
}
