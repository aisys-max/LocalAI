import SwiftUI

struct InputBarView: View {
    @ObservedObject var model: AppModel
    let theme: Theme

    private var canSend: Bool {
        !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.generating
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(model.strings.inputPlaceholder, text: $model.draft, axis: .vertical)
                .font(AppFont.body(15))
                .foregroundColor(theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(theme.surface)
                        .overlay(Capsule().strokeBorder(theme.divider, lineWidth: 1))
                )
                .onSubmit { model.sendMessage() }

            Button {
                model.sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(canSend ? theme.onAccentText : theme.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(canSend ? theme.accent : theme.divider))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }
}
