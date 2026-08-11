import SwiftUI
import Combine

enum Screen {
    case onboarding, chat, settings, modelPicker
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
    @Published var model: String?
    @Published var modelListState: ModelListState = .loading
    /// Whether the auto-retry loop (`AppModel+Models.swift`) is currently
    /// active. Kept as its own `@Published` flag rather than a computed
    /// `modelRetryLoopTask != nil` — the Task reference changes on a
    /// different MainActor hop than `modelListState` does, so a computed
    /// property would let SwiftUI miss the moment it should re-render.
    @Published var isRetryingModels: Bool = false
    @Published var appearance: AppearanceMode = .system
    @Published var systemColorScheme: ColorScheme = .light
    @Published var language: AppLanguage = .en
    @Published var backendServerAddresses: [Backend: String] = [:]
    @Published var showDeleteRangeDialog: Bool = false
    /// The range awaiting a second confirmation — only ever set to `.all`,
    /// the sole range severe enough to need one beyond the dialog itself.
    @Published var pendingDeleteRange: ChatDeleteRange?

    // MARK: - Onboarding (AppModel+Onboarding.swift)
    @Published var onboardingStep: Int = 0

    // MARK: - Chat (AppModel+Chat.swift)
    @Published var chats: [String: Chat]
    @Published var currentChatId: String?
    @Published var draft: String = ""
    @Published var generating: Bool = false
    @Published var copiedId: String?
    @Published var showDeleteChatConfirmation: Bool = false

    var copyResetTask: Task<Void, Never>?
    var modelLoadTask: Task<ModelListState, Never>?
    var modelRetryLoopTask: Task<Void, Never>?
    /// The server address `loadModels()` was last invoked for — lets
    /// `resumeModelRetryLoopIfNeeded()` detect an edited address even when
    /// the previous fetch actually succeeded (state is `.loaded`, not
    /// `.failed`, so state alone can't signal a stale fetch).
    var modelListFetchedForAddress: String?
    let backendClient: ChatBackendClient
    let modelCatalogClient: ModelCatalogClient
    let modelFetchTimeoutNanoseconds: UInt64
    let modelRetryBackoffNanoseconds: UInt64

    init(
        backendClient: ChatBackendClient = OpenAICompatibleChatBackendClient(),
        modelCatalogClient: ModelCatalogClient = OpenAICompatibleModelCatalogClient(),
        modelFetchTimeoutNanoseconds: UInt64 = 30_000_000_000,
        modelRetryBackoffNanoseconds: UInt64 = 5_000_000_000
    ) {
        self.backendClient = backendClient
        self.modelCatalogClient = modelCatalogClient
        self.modelFetchTimeoutNanoseconds = modelFetchTimeoutNanoseconds
        self.modelRetryBackoffNanoseconds = modelRetryBackoffNanoseconds
        self.chats = [:]
        loadModels()
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
