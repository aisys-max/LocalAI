import SwiftUI

/// Top-level switch over `AppModel.screen` — ports the design's `sc-if` screen branches.
struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch model.screen {
            case .onboarding: OnboardingView(model: model)
            case .chat: ChatView(model: model)
            case .history: HistoryView(model: model)
            case .settings: SettingsView(model: model)
            case .modelPicker: ModelPickerView(model: model)
            }
        }
        .preferredColorScheme(model.appearance == .system ? nil : (model.appearance == .dark ? .dark : .light))
        .onAppear { model.systemColorScheme = colorScheme }
        .onChange(of: colorScheme) { _, newValue in model.systemColorScheme = newValue }
    }
}
