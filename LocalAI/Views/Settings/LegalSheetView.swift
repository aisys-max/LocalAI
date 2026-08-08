import SwiftUI

/// Ports the design's `legalOpen` modal dialog.
struct LegalSheetView: View {
    @ObservedObject var model: AppModel
    let key: LegalKey
    let theme: Theme

    private var entry: LegalEntry { model.language.legal.entry(for: key) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.title)
                .font(AppFont.heading(20))
                .foregroundColor(theme.text)
            ScrollView {
                Text(entry.body)
                    .font(AppFont.body(14))
                    .foregroundColor(theme.textMuted)
                    .lineSpacing(4)
            }
            HStack {
                Spacer()
                Button(model.strings.done) { model.closeLegal() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .foregroundColor(theme.onAccentText)
            }
        }
        .padding(20)
        .presentationDetents([.medium])
        .presentationBackground(theme.surface)
    }
}
