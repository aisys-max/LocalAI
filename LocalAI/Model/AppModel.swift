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
    @Published var retentionPeriod: RetentionPeriod = .oneMonth
    /// Step 1 of the two-step Reset to Default confirmation (mirrors
    /// `showDeleteRangeDialog`/`showDeleteAllConfirmation`'s shape below) —
    /// a `confirmationDialog` with the single destructive option, which on
    /// selection opens `showResetToDefaultConfirmation` (step 2).
    @Published var showResetToDefaultDialog: Bool = false
    @Published var showResetToDefaultConfirmation: Bool = false

    // MARK: - Onboarding (AppModel+Onboarding.swift)
    @Published var onboardingStep: Int = 0

    // MARK: - Chat (AppModel+Chat.swift)
    /// Not auto-persisted via `didSet` — an in-flight streamed reply mutates
    /// this per chunk, and per-chunk disk writes are deliberately avoided.
    /// Saved explicitly via `persistChats()` at well-defined points instead
    /// (new Chat, sent Message, completed/failed Generation, deletions).
    @Published var chats: [String: Chat]
    @Published var currentChatId: String? {
        didSet { persistenceStore.saveCurrentChatId(currentChatId) }
    }
    @Published var draft: String = "" {
        didSet { persistenceStore.saveDraft(draft) }
    }
    @Published var generating: Bool = false
    @Published var copiedId: String?
    @Published var showDeleteRangeDialog: Bool = false
    /// Second confirmation shown only for `.all` — the sole range severe
    /// enough to need one beyond the dialog itself.
    @Published var showDeleteAllConfirmation: Bool = false

    var copyResetTask: Task<Void, Never>?
    var modelLoadTask: Task<ModelListState, Never>?
    var modelRetryLoopTask: Task<Void, Never>?
    /// The server address `loadModels()` was last invoked for — lets
    /// `resumeModelRetryLoopIfNeeded()` detect an edited address even when
    /// the previous fetch actually succeeded (state is `.loaded`, not
    /// `.failed`, so state alone can't signal a stale fetch).
    var modelListFetchedForAddress: String?
    /// The `model` value loaded from persistence at launch, cleared the
    /// first time a Model-list fetch resolves. Lets `loadModels()`
    /// distinguish "this is the persisted selection, still unconfirmed
    /// against a live list" (invalidate it if the fetched list doesn't
    /// contain it) from "the user already picked something during this
    /// session" (never clobber that, regardless of list contents).
    var modelPendingValidation: String?
    let backendClient: ChatBackendClient
    let modelCatalogClient: ModelCatalogClient
    let persistenceStore: PersistenceStore
    let modelFetchTimeoutNanoseconds: UInt64
    let modelRetryBackoffNanoseconds: UInt64

    init(
        backendClient: ChatBackendClient = OpenAICompatibleChatBackendClient(),
        modelCatalogClient: ModelCatalogClient = OpenAICompatibleModelCatalogClient(),
        persistenceStore: PersistenceStore = SwiftDataPersistenceStore(),
        modelFetchTimeoutNanoseconds: UInt64 = 30_000_000_000,
        modelRetryBackoffNanoseconds: UInt64 = 5_000_000_000
    ) {
        self.backendClient = backendClient
        self.modelCatalogClient = modelCatalogClient
        self.persistenceStore = persistenceStore
        self.modelFetchTimeoutNanoseconds = modelFetchTimeoutNanoseconds
        self.modelRetryBackoffNanoseconds = modelRetryBackoffNanoseconds
        self.chats = persistenceStore.loadChats()
        self.currentChatId = persistenceStore.loadCurrentChatId()
        self.draft = persistenceStore.loadDraft()

        let settings = persistenceStore.loadSettings()
        applySettings(settings)
        self.modelPendingValidation = settings.model

        // Pruning first, before the now-possibly-removed Chats get a
        // greeting synthesized for them (harmless either order, but no
        // point doing that work for a Chat about to be pruned).
        pruneExpiredChats()

        if !chats.isEmpty {
            screen = .chat
        }
        restoreGreetings()

        // detectInterruptedGeneration() needs `model` populated to tell a
        // real interruption apart from "no Model was ever selected" — both
        // leave the same trailing-user-Message shape on disk — so it runs
        // after the launch Model-list fetch resolves, not synchronously
        // here where `model` is still whatever was last persisted (or nil).
        let initialModelLoad = loadModels()
        Task {
            _ = await initialModelLoad.value
            await MainActor.run {
                self.detectInterruptedGeneration()
            }
        }
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
