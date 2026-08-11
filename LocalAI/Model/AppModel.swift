import SwiftUI
import Combine

enum Screen {
    case onboarding, chat, history, settings, modelPicker
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
}

/// Single ObservableObject driving every screen — a direct port of the design's
/// `Component` state (`this.state`) and actions in `Local AI.dc.html`. Behavior
/// is organized by concern into `AppModel+Navigation.swift`,
/// `AppModel+Settings.swift`, `AppModel+Onboarding.swift`, `AppModel+Chat.swift`.
@MainActor
final class AppModel: ObservableObject {
    // MARK: - Navigation (AppModel+Navigation.swift)
    @Published var screen: Screen = .onboarding
    @Published var returnScreen: Screen = .chat
    @Published var legalOpenKey: LegalKey?

    // MARK: - Settings (AppModel+Settings.swift)
    @Published var backend: Backend = .ollama
    @Published var model: String
    @Published var appearance: AppearanceMode = .system
    @Published var systemColorScheme: ColorScheme = .light
    @Published var language: AppLanguage = .en
    @Published var backendServerAddresses: [Backend: String] = [:]

    // MARK: - Onboarding (AppModel+Onboarding.swift)
    @Published var onboardingStep: Int = 0

    // MARK: - Chat (AppModel+Chat.swift)
    @Published var chats: [String: Chat]
    @Published var currentChatId: String?
    @Published var draft: String = ""
    @Published var generating: Bool = false
    @Published var copiedId: String?

    var copyResetTask: Task<Void, Never>?
    let backendClient: ChatBackendClient

    init(backendClient: ChatBackendClient = OpenAICompatibleChatBackendClient()) {
        self.backendClient = backendClient
        let seeded = SeedChats.make()
        self.chats = Dictionary(uniqueKeysWithValues: seeded.map { ($0.id, $0) })
        self.model = Backend.ollama.models[0]
    }

    // MARK: - Derived

    var isDark: Bool {
        switch appearance {
        case .dark: return true
        case .light: return false
        case .system: return systemColorScheme == .dark
        }
    }

    var strings: Strings { language.strings }
}
