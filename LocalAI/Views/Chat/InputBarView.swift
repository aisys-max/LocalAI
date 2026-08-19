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
                .foregroundStyle(theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(theme.surface)
                        .overlay(Capsule().strokeBorder(theme.divider, lineWidth: 1))
                )
                .onSubmit { model.sendMessage() }

            Button(model.strings.send, systemImage: "arrow.up") {
                model.sendMessage()
            }
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(canSend ? theme.onAccentText : theme.textMuted)
            .frame(width: 32, height: 32)
            .background(Circle().fill(canSend ? theme.accent : theme.divider))
            // Keeps the visible circle at its designed 32x32 size while
            // still meeting Apple's 44x44 minimum tap target — contentShape
            // must come after the enlarging frame, or it freezes the hit
            // area at the pre-enlargement 32x32 size.
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }
}
