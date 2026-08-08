import SwiftUI

struct ModelStepView: View {
    @ObservedObject var model: AppModel
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.strings.chooseModelTitle)
                .font(AppFont.heading(26))
                .foregroundColor(theme.text)
                .padding(.top, 20)
                .padding(.bottom, 8)

            Text(model.strings.chooseModelBody)
                .font(AppFont.body(14))
                .foregroundColor(theme.textMuted)
                .lineSpacing(3)
                .padding(.bottom, 16)

            SegmentedPillControl(
                items: Backend.allCases, label: { $0.label },
                isSelected: { $0 == model.backend },
                onSelect: { model.selectBackend($0) },
                theme: theme
            )
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(model.backend.models, id: \.self) { m in
                        ModelRow(name: m, selected: m == model.model, theme: theme) {
                            model.selectModel(m)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 28)
    }
}

struct ModelRow: View {
    let name: String
    let selected: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        HStack {
            Text(name)
                .font(AppFont.body(14.5))
                .foregroundColor(selected ? theme.selectedText : theme.text)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.selectedText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selected ? theme.selectedTint : theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(selected ? theme.accent : theme.divider, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
