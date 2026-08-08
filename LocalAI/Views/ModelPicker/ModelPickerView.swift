import SwiftUI

struct ModelPickerView: View {
    @ObservedObject var model: AppModel
    var theme: Theme { Theme.resolve(dark: model.isDark) }

    var body: some View {
        VStack(spacing: 0) {
            SubHeader(title: model.strings.modelPickerTitle, theme: theme, onBack: { model.closeModelPicker() })

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SegmentedPillControl(
                        items: Backend.allCases, label: { $0.label },
                        isSelected: { $0 == model.backend },
                        onSelect: { model.selectBackend($0) },
                        theme: theme
                    )
                    .padding(.top, 12)

                    Text(model.backend.description(model.language))
                        .font(AppFont.body(12.5))
                        .foregroundColor(theme.textMuted)
                        .lineSpacing(2)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 4)

                    VStack(spacing: 10) {
                        ForEach(model.backend.models, id: \.self) { m in
                            ModelRow(name: m, selected: m == model.model, theme: theme) {
                                model.selectModel(m)
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    Button {
                        model.closeModelPicker()
                    } label: {
                        Text(model.strings.done)
                            .font(AppFont.body(15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(theme.accent))
                            .foregroundColor(theme.onAccentText)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(theme.bg.ignoresSafeArea())
    }
}
