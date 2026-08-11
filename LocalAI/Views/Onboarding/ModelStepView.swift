import SwiftUI

struct ModelStepView: View {
    @ObservedObject var model: AppModel
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeaderView(
                title: model.strings.chooseModelTitle,
                subtitle: model.strings.chooseModelBody,
                theme: theme,
                bottomPadding: 16
            )

            SegmentedPillControl(
                items: Backend.allCases, label: { $0.label },
                isSelected: { $0 == model.backend },
                onSelect: { model.selectBackend($0) },
                theme: theme
            )
            .padding(.bottom, 16)

            ScrollView {
                ModelListContent(
                    state: model.modelListState,
                    selectedModel: model.model,
                    theme: theme,
                    strings: model.strings,
                    onSelect: { model.selectModel($0) },
                    onRetry: { model.loadModels() }
                )
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 28)
    }
}
