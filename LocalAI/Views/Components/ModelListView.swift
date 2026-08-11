import SwiftUI

/// Renders a `ModelListState` as loading/error/empty/list — shared between
/// `ModelStepView` (onboarding) and `ModelPickerView` (Settings/Chat), the
/// two screens that let the user pick a Model for the current Backend.
struct ModelListContent: View {
    let state: ModelListState
    let selectedModel: String?
    let theme: Theme
    let strings: Strings
    let onSelect: (String) -> Void
    let onRetry: () -> Void
    /// A short secondary line shown under the `.failed`/`.timedOut` message —
    /// e.g. onboarding points the user at Settings, Settings/Model Picker
    /// notes that it's retrying automatically. `nil` shows nothing extra.
    var hint: String? = nil

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        case .failed:
            failureContent(message: strings.modelLoadError)
        case .timedOut:
            failureContent(message: strings.modelLoadTimeout)
        case .loaded(let models):
            if models.isEmpty {
                Text(strings.noModelsFound)
                    .font(AppFont.body(13.5))
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 10) {
                    ForEach(models, id: \.self) { m in
                        ModelRow(name: m, selected: m == selectedModel, theme: theme) {
                            onSelect(m)
                        }
                    }
                }
            }
        }
    }

    private func failureContent(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(AppFont.body(13.5))
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
            if let hint {
                Text(hint)
                    .font(AppFont.body(12))
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button(action: onRetry) {
                Text(strings.retry)
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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
